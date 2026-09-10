import AVFoundation
import Foundation
import XCTest
@testable import OrgRecCore

final class StandaloneAudioAnalysisTests: XCTestCase {
    private func audio(at url: URL, seconds: Double = 1, channels: Int = 2) throws {
        let rate = 8_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: AVAudioChannelCount(channels))!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(seconds * rate))!
        buffer.frameLength = buffer.frameCapacity
        for channel in 0..<channels {
            for index in 0..<Int(buffer.frameLength) {
                buffer.floatChannelData![channel][index] = Float(0.2 * sin(2 * .pi * Double(220 + channel * 110) * Double(index) / rate))
            }
        }
        try file.write(from: buffer)
    }

    func testExcerptPreservesSourceAndExportsExactTimeCoordinates() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.wav")
        try audio(at: source)
        let before = try sha256(of: source)
        let workspace = directory.appendingPathComponent("analysis")
        let request = StandaloneAnalysisRequest(startSeconds: 0.25, durationSeconds: 0.5, referenceChannel: 1,
            applicability: .nonPitched, configuration: .init(fftSize: 512, hopSize: 128, maximumTimeBins: 30, displayFrequencyBins: 32))
        let result = try await StandaloneAudioAnalyzer().analyze(sourceURL: source, request: request, workspace: workspace)
        XCTAssertEqual(try sha256(of: source), before)
        XCTAssertEqual(result.sourceSHA256, before)
        XCTAssertEqual(result.startFrame, 2000)
        XCTAssertEqual(result.frameCount, 4000)
        XCTAssertEqual(result.waveform.duration, 0.5, accuracy: 1e-9)
        XCTAssertEqual(result.spectrogram.analysisRun?.inputSHA256, result.excerptSHA256)
        XCTAssertEqual(result.spectrogram.analysisRun?.referenceChannel, 1)
        XCTAssertEqual(result.spectrogram.analysisRun?.artifactRelativePaths, ["waveform.json", "spectrogram.json"])
        XCTAssertNil(result.analysis.frequencyHz)
        XCTAssertTrue(result.limitations.contains { $0.contains("Only the selected excerpt") })
        let excerpt = try AVAudioFile(forReading: workspace.appendingPathComponent("excerpt.wav"))
        XCTAssertEqual(excerpt.length, 4000)
        XCTAssertEqual(excerpt.processingFormat.channelCount, 2)
        let data = try StandaloneAnalysisDataExport.json(result)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(StandaloneAnalysisDocument.self, from: data)
        XCTAssertEqual(restored.sourceSHA256, before)
        let tables = try StandaloneAnalysisDataExport.tables(result)
        XCTAssertTrue(try XCTUnwrap(tables["waveform.csv"]).contains("\"0.0\",\"0.25\""))
        XCTAssertTrue(try XCTUnwrap(tables["pitch.csv"]).contains("source_time_s"))
        XCTAssertEqual(tables.count, 6)
    }

    func testInvalidRangesChannelsAndReferenceAreRejectedAndCleanedUp() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.wav"); try audio(at: source)
        let info = try StandaloneAudioSource.inspect(source)
        for request in [
            StandaloneAnalysisRequest(startSeconds: .nan),
            .init(startSeconds: -1), .init(startSeconds: 2), .init(durationSeconds: 0),
            .init(durationSeconds: .infinity), .init(durationSeconds: 601),
            .init(referenceChannel: 2), .init(referenceChannel: -1),
            .init(expectedFrequencyHz: .nan), .init(expectedFrequencyHz: 5000)
        ] { XCTAssertThrowsError(try request.frameRange(in: info)) }
        let workspace = directory.appendingPathComponent("failed")
        do {
            _ = try await StandaloneAudioAnalyzer().analyze(sourceURL: source, request: .init(referenceChannel: 99), workspace: workspace)
            XCTFail("Invalid channel accepted")
        } catch { XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.path)) }
        let cancelledWorkspace = directory.appendingPathComponent("cancelled")
        let task = Task {
            return try await StandaloneAudioAnalyzer().analyze(sourceURL: source, request: .init(applicability: .nonPitched), workspace: cancelledWorkspace)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled operation completed") }
        catch { XCTAssertFalse(FileManager.default.fileExists(atPath: cancelledWorkspace.path)) }
    }

    func testMonophonicAnalysisRetainsPitchEvidenceWithoutOrganMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("tone.wav")
        try audio(at: source, seconds: 3, channels: 1)
        let result = try await StandaloneAudioAnalyzer().analyze(sourceURL: source,
            request: .init(durationSeconds: 3, expectedFrequencyHz: 220, applicability: .monophonic,
                           configuration: .init(fftSize: 2048, hopSize: 256)), workspace: directory.appendingPathComponent("workspace"))
        XCTAssertEqual(try XCTUnwrap(result.analysis.frequencyHz), 220, accuracy: 15)
        XCTAssertNotNil(result.analysis.pitchEstimatorComparison)
        XCTAssertFalse(result.spectrogram.pitchTrack?.isEmpty ?? true)
        XCTAssertEqual(result.request.expectedFrequencyHz, 220)
    }

    func testNonFiniteAudioIsRejectedWithoutLeavingWorkspace() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("invalid.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 8000, channels: 1)!
        do {
            let file = try AVAudioFile(forWriting: source, settings: format.settings)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100)!
            buffer.frameLength = 100
            for i in 0..<100 { buffer.floatChannelData![0][i] = i == 50 ? .nan : 0 }
            try file.write(from: buffer)
        }
        let workspace = directory.appendingPathComponent("workspace")
        do {
            _ = try await StandaloneAudioAnalyzer().analyze(sourceURL: source, request: .init(applicability: .nonPitched), workspace: workspace)
            XCTFail("Non-finite samples accepted")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("non-finite"))
            XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.path))
        }
    }

    func testCSVQuotesAndNeutralizesFormulaLikeTextWithoutChangingNumbers() {
        let csv = StandaloneAnalysisDataExport.csv([["=1+1", " @SUM(A1)", "-24.5", "a,\"b\"\nc"]])
        XCTAssertTrue(csv.contains("\"'=1+1\""))
        XCTAssertTrue(csv.contains("\"' @SUM(A1)\""))
        XCTAssertTrue(csv.contains("\"-24.5\""))
        XCTAssertTrue(csv.contains("\"a,\"\"b\"\"\nc\""))
    }
}
