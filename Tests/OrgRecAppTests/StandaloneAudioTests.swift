import AVFoundation
import Foundation
import ImageIO
import PDFKit
import XCTest
@testable import OrgRecApp
import OrgRecCore

final class StandaloneAudioTests: XCTestCase {
    func testStandaloneExportIsCompleteReadableAndRefusesExistingFolders() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("standalone-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("sound<&>.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1)!
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32000)!
            buffer.frameLength = 32000
            for index in 0..<32000 {
                let t = Double(index) / 8000
                let envelope = t < 0.4 ? 0 : min(1, (t - 0.4) / 0.1) * exp(-max(0, t - 2.8) * 12)
                buffer.floatChannelData![0][index] = Float(envelope * (0.3 * sin(t * 2 * .pi * 220) + 0.1 * sin(t * 2 * .pi * 440)))
            }
            try file.write(from: buffer)
        }
        let workspace = directory.appendingPathComponent("workspace")
        let document = try await StandaloneAudioAnalyzer().analyze(sourceURL: url,
            request: .init(durationSeconds: 4, applicability: .indeterminate, configuration: .init(fftSize: 2048, hopSize: 256, maximumTimeBins: 120, displayFrequencyBins: 80)), workspace: workspace)
        let destination = directory.appendingPathComponent("export")
        try StandaloneAudioExport.write(document, workspace: workspace, kind: .bundle, destination: destination)
        for name in ["analysis.json", "spectrogram.json", "waveform.json", "report.pdf", "excerpt.wav", "provenance.json", "README.txt", "SHA256SUMS", "pitch.csv", "waveform.png", "spectrogram.svg"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathComponent(name).path), name)
        }
        let pdf = try XCTUnwrap(PDFDocument(url: destination.appendingPathComponent("report.pdf")))
        XCTAssertGreaterThan(pdf.pageCount, 3)
        XCTAssertTrue(pdf.string?.contains("INTERPRETATION") == true)
        XCTAssertTrue(pdf.string?.contains(document.sourceSHA256) == true)
        let image = try XCTUnwrap(CGImageSourceCreateWithURL(destination.appendingPathComponent("waveform.png") as CFURL, nil))
        let decoded = try XCTUnwrap(CGImageSourceCreateImageAtIndex(image, 0, nil))
        XCTAssertEqual(decoded.width, 2000)
        let svg = try String(contentsOf: destination.appendingPathComponent("spectrogram.svg"), encoding: .utf8)
        XCTAssertTrue(svg.contains("sound&lt;&amp;&gt;.wav"))
        XCTAssertFalse(svg.contains("sound<&>.wav"))
        let partialSVG = try String(contentsOf: destination.appendingPathComponent("partials.svg"), encoding: .utf8)
        XCTAssertTrue(partialSVG.contains("track confidence ≥ 0.2"))
        XCTAssertTrue(partialSVG.contains(">440</text>"))
        XCTAssertFalse(partialSVG.contains(">3968</text>"))
        XCTAssertEqual(try sha256(of: destination.appendingPathComponent("excerpt.wav")), document.excerptSHA256)
        let sums = try String(contentsOf: destination.appendingPathComponent("SHA256SUMS"), encoding: .utf8)
        for line in sums.split(separator: "\n") {
            let pieces = line.components(separatedBy: "  ")
            XCTAssertEqual(try sha256(of: destination.appendingPathComponent(pieces[1])), pieces[0])
        }
        XCTAssertThrowsError(try StandaloneAudioExport.write(document, workspace: workspace, kind: .bundle, destination: destination))
        XCTAssertEqual(try sha256(of: url), document.sourceSHA256)
        if let path = ProcessInfo.processInfo.environment["ORGREC_STANDALONE_QA_DIR"] {
            let retained = URL(fileURLWithPath: path).appendingPathComponent("rendered-example")
            try FileManager.default.copyItem(at: destination, to: retained)
            for index in [0, pdf.pageCount - 1] {
                let image = try XCTUnwrap(pdf.page(at: index)).thumbnail(of: CGSize(width: 1500, height: 1050), for: .mediaBox)
                let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
                try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: retained.appendingPathComponent("report-page-\(index + 1).png"))
            }
        }
    }

    @MainActor func testLongSourceRequiresExplicitExcerptAndKeepsOldResultOnInvalidInput() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("long.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1)!
        do {
            let file = try AVAudioFile(forWriting: source, settings: format.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8000)!
            buffer.frameLength = 8000
            for i in 0..<8000 { buffer.floatChannelData![0][i] = Float(0.1 * sin(Double(i) * 2 * .pi * 220 / 8000)) }
            for _ in 0..<121 { try file.write(from: buffer) }
        }
        let app = AppModel()
        let model = app.standaloneAudio
        defer { model.clearResult() }
        await model.load(source)
        XCTAssertNil(model.document)
        XCTAssertEqual(model.request.durationSeconds, 120)
        XCTAssertFalse(model.isWorking)
        model.request.durationSeconds = 0.5
        model.request.startSeconds = 5
        model.request.applicability = .nonPitched
        await model.analyze()
        let previous = try XCTUnwrap(model.document)
        XCTAssertFalse(model.hasChangedSettings)
        model.request.startSeconds = 6
        XCTAssertTrue(model.hasChangedSettings)
        await model.load(directory.appendingPathComponent("missing.wav"))
        XCTAssertEqual(model.document?.analysis.analysisRunID, previous.analysis.analysisRunID)
        XCTAssertEqual(model.sourceURL, source)
        XCTAssertNotNil(model.error)
        XCTAssertNil(app.project)
        XCTAssertNil(app.projectURL)
    }

    @MainActor func testStandaloneStateDoesNotRequireOrCreateProject() {
        let model = AppModel()
        XCTAssertNil(model.project)
        XCTAssertNil(model.projectURL)
        model.page = .audioAnalysis
        XCTAssertFalse(model.standaloneAudio.accept([]))
        XCTAssertFalse(model.standaloneAudio.accept([URL(string: "https://example.org/audio.wav")!]))
        XCTAssertNil(model.project)
        XCTAssertNil(model.projectURL)
    }
}
