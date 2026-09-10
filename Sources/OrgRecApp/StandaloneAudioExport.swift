import AppKit
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import OrgRecCore
import UniformTypeIdentifiers

enum StandaloneExportKind: String, CaseIterable, Identifiable, Sendable {
    case bundle, pdf, json, csv, plots
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bundle: "Complete analysis folder…"
        case .pdf: "PDF report…"
        case .json: "Complete JSON…"
        case .csv: "CSV tables…"
        case .plots: "Publication plots (PNG and SVG)…"
        }
    }
    var suffix: String {
        switch self { case .pdf: ".pdf"; case .json: ".json"; case .bundle: "-results"; case .csv: "-tables"; case .plots: "-plots" }
    }
    var contentType: UTType? {
        switch self { case .pdf: .pdf; case .json: .json; default: nil }
    }
}

/// One set of plot primitives is used for vector, raster and report exports.
struct StandalonePlot {
    struct Color {
        var r: Double; var g: Double; var b: Double
        var cg: CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
        var hex: String { String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255)) }
        static let ink = Color(r: 0.12, g: 0.15, b: 0.18)
        static let accent = Color(r: 0.7, g: 0.2, b: 0.14)
        static let grid = Color(r: 0.85, g: 0.87, b: 0.88)
    }
    enum Element {
        case rect(CGRect, Color)
        case line(CGPoint, CGPoint, Color, Double)
        case text(String, CGPoint, Double, Color)
    }
    var name: String
    var elements: [Element] = []
    let width = 1000.0
    let height = 580.0

    static func make(_ document: StandaloneAnalysisDocument) -> [Self] {
        let left = 90.0, top = 90.0, w = 800.0, h = 355.0
        func base(_ name: String, title: String, unit: String) -> Self {
            var plot = Self(name: name)
            plot.elements += [.text(title, CGPoint(x: left, y: 30), 21, .ink),
                              .text(String(document.source.filename.prefix(70)) + (document.source.filename.count > 70 ? "…" : ""), CGPoint(x: left, y: 52), 12, .ink),
                              .text(unit, CGPoint(x: left, y: 76), 12, .ink)]
            for tick in 0...5 {
                let x = left + Double(tick) / 5 * w
                plot.elements += [.line(CGPoint(x: x, y: top), CGPoint(x: x, y: top + h), .grid, 0.6),
                                  .text(String(format: "%.2f", Double(tick) / 5 * document.duration), CGPoint(x: x - 12, y: top + h + 22), 11, .ink)]
            }
            plot.elements += [.line(CGPoint(x: left, y: top), CGPoint(x: left, y: top + h), .ink, 1),
                              .line(CGPoint(x: left, y: top + h), CGPoint(x: left + w, y: top + h), .ink, 1),
                              .text("Time within excerpt (s)", CGPoint(x: 370, y: top + h + 45), 13, .ink),
                              .text(String(format: "Source interval %.3f–%.3f s · Channel %d · %@", document.sourceStartSeconds, document.sourceStartSeconds + document.duration, document.request.referenceChannel + 1, document.request.applicability.rawValue), CGPoint(x: left, y: 515), 12, .ink),
                              .text("Run: \(document.analysis.analysisRunID?.uuidString ?? "unknown") · OrgRec \(document.software.version) (\(document.software.build))", CGPoint(x: left, y: 538), 11, .ink)]
            return plot
        }
        var waveform = base("waveform", title: "Waveform and detected boundaries", unit: "Envelope summary · digital amplitude (full scale)")
        let waveformScale = max(1.0, document.waveform.samples.map { abs(Double($0)) }.max() ?? 1)
        for amplitude in [-waveformScale, 0, waveformScale] {
            let y = top + (1 - amplitude / waveformScale) / 2 * h
            waveform.elements += [.line(CGPoint(x: left, y: y), CGPoint(x: left + w, y: y), .grid, 0.6), .text(String(format: "%.1f", amplitude), CGPoint(x: 51, y: y + 4), 11, .ink)]
        }
        let samples = document.waveform.samples
        for index in 1..<max(1, samples.count) {
            let x1 = left + Double(index - 1) / Double(samples.count - 1) * w
            let x2 = left + Double(index) / Double(samples.count - 1) * w
            waveform.elements.append(.line(CGPoint(x: x1, y: top + (1 - Double(samples[index - 1]) / waveformScale) / 2 * h), CGPoint(x: x2, y: top + (1 - Double(samples[index]) / waveformScale) / 2 * h), .ink, 0.8))
        }
        for (index, boundary) in (document.analysis.boundaries ?? []).enumerated() {
            guard boundary.state == .observed, let seconds = boundary.seconds, seconds >= 0, seconds <= document.duration else { continue }
            let x = left + seconds / document.duration * w
            waveform.elements += [.line(CGPoint(x: x, y: top), CGPoint(x: x, y: top + h), .accent, 1), .text(boundary.marker.rawValue, CGPoint(x: min(780, x + 3), y: top + 15 + Double(index % 4) * 15), 10, .accent)]
        }
        var spectral = base("spectrogram", title: "Spectrogram · peak-aggregated display cells", unit: "Frequency (Hz) · \(document.spectrogram.configuration?.frequencyScale.rawValue ?? "stored axis")")
        let data = document.spectrogram
        let range = data.configuration?.dynamicRangeDB ?? 100
        let timeStride = max(1, Int(ceil(Double(data.magnitudes.count) / 500)))
        let frequencyStride = max(1, Int(ceil(Double(data.frequencyBins) / 200)))
        let heatStart = spectral.elements.count
        for t in stride(from: 0, to: data.magnitudes.count, by: timeStride) {
            for f in stride(from: 0, to: min(data.frequencyBins, data.magnitudes[t].count), by: frequencyStride) {
                let level = (t..<min(data.magnitudes.count, t + timeStride)).flatMap { ti in
                    (f..<min(data.magnitudes[ti].count, f + frequencyStride)).map { Double(data.magnitudes[ti][$0]) }
                }.max() ?? -range
                let value = max(0, min(1, (level + range) / range))
                let color = heat(value)
                spectral.elements.append(.rect(CGRect(x: left + Double(t) * (data.timeStepSeconds ?? 0) / document.duration * w,
                    y: top + h - Double(min(data.frequencyBins, f + frequencyStride)) / Double(max(1, data.frequencyBins)) * h,
                    width: max(0, min(w - Double(t) * (data.timeStepSeconds ?? 0) / document.duration * w, Double(timeStride) * (data.timeStepSeconds ?? 0) / document.duration * w + 0.1)),
                    height: Double(frequencyStride) / Double(max(1, data.frequencyBins)) * h + 0.1), color))
            }
        }
        // Render heat cells below the axes and labels.
        let cells = Array(spectral.elements[heatStart...])
        spectral.elements.removeSubrange(heatStart...)
        spectral.elements.insert(contentsOf: cells, at: 0)
        if let axis = data.frequencyAxisHz, !axis.isEmpty {
            for tick in 0...4 {
                let index = min(axis.count - 1, tick * (axis.count - 1) / 4)
                spectral.elements.append(.text(String(format: "%.0f", axis[index]), CGPoint(x: 30, y: top + h - Double(index) / Double(max(1, axis.count - 1)) * h + 4), 11, .ink))
            }
        }
        for index in 0..<100 {
            spectral.elements.append(.rect(CGRect(x: 920, y: top + Double(99 - index) / 100 * h, width: 14, height: h / 100 + 0.2), heat(Double(index) / 99)))
        }
        spectral.elements += [.text("0", CGPoint(x: 939, y: top + 8), 11, .ink), .text(String(format: "−%.0f", range), CGPoint(x: 935, y: top + h), 11, .ink), .text("Rel. dB", CGPoint(x: 910, y: top - 14), 11, .ink)]
        var pitch = base("pitch", title: "Pitch evidence", unit: "Frequency (Hz) · voiced points only; estimator confidence is not calibrated accuracy")
        let voiced = (data.pitchTrack ?? []).filter { $0.voiced && ($0.frequencyHz?.isFinite == true) }
        let frequencies = voiced.compactMap(\.frequencyHz)
        let low = (frequencies.min() ?? 0) * 0.98
        let high = max(low + 1, (frequencies.max() ?? 1) * 1.02)
        for tick in 0...4 {
            let hz = low + Double(tick) / 4 * (high - low)
            let y = top + h - Double(tick) / 4 * h
            pitch.elements += [.line(CGPoint(x: left, y: y), CGPoint(x: left + w, y: y), .grid, 0.6), .text(String(format: "%.1f", hz), CGPoint(x: 20, y: y + 4), 11, .ink)]
        }
        for point in voiced {
            guard let hz = point.frequencyHz else { continue }
            let x = left + point.timeSeconds / document.duration * w
            let y = top + h - (hz - low) / (high - low) * h
            pitch.elements.append(.rect(CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4), .accent))
        }
        if voiced.isEmpty { pitch.elements.append(.text("No applicable voiced pitch evidence", CGPoint(x: 310, y: 260), 16, .ink)) }
        var partials = base("partials", title: "Inferred partial trajectories", unit: "Frequency (Hz) · track confidence ≥ 0.2; valid points only · full evidence in data exports")
        let displayedTracks = (data.partialTracks ?? []).filter { ($0.confidence ?? 0) >= 0.2 && $0.medianFrequencyHz != nil }
        let validPoints = displayedTracks.flatMap { $0.points }.filter { $0.isValid == true && $0.frequencyHz.isFinite }
        let upperHz = max(1, validPoints.map(\.frequencyHz).max() ?? 1)
        for tick in 0...4 {
            let hz = Double(tick) / 4 * upperHz
            let y = top + h - Double(tick) / 4 * h
            partials.elements += [.line(CGPoint(x: left, y: y), CGPoint(x: left + w, y: y), .grid, 0.6), .text(String(format: "%.0f", hz), CGPoint(x: 24, y: y + 4), 11, .ink)]
        }
        for track in displayedTracks {
            let color = Color(r: 0.2 + Double(track.harmonicNumber % 3) * 0.2, g: 0.2 + Double(track.harmonicNumber % 5) * 0.1, b: 0.25)
            for point in track.points where point.isValid == true && point.frequencyHz.isFinite {
                let x = left + point.timeSeconds / document.duration * w
                let y = top + h - point.frequencyHz / upperHz * h
                partials.elements.append(.rect(CGRect(x: x - 1, y: y - 1, width: 2, height: 2), color))
            }
        }
        if validPoints.isEmpty { partials.elements.append(.text("No applicable valid partial evidence", CGPoint(x: 300, y: 260), 16, .ink)) }
        return [waveform, spectral, pitch, partials]
    }

    private static func heat(_ value: Double) -> Color {
        Color(r: min(1, value * 1.6), g: max(0, min(1, (value - 0.25) * 1.35)), b: max(0.08, 0.3 - value * 0.2))
    }

    static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    func svg() -> String {
        var lines = ["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1000\" height=\"580\" viewBox=\"0 0 1000 580\"><rect width=\"1000\" height=\"580\" fill=\"white\"/>"]
        for element in elements {
            switch element {
            case let .rect(r, c): lines.append("<rect x=\"\(r.minX)\" y=\"\(r.minY)\" width=\"\(r.width)\" height=\"\(r.height)\" fill=\"\(c.hex)\"/>")
            case let .line(a, b, c, width): lines.append("<path d=\"M \(a.x) \(a.y) L \(b.x) \(b.y)\" fill=\"none\" stroke=\"\(c.hex)\" stroke-width=\"\(width)\"/>")
            case let .text(text, point, size, c): lines.append("<text x=\"\(point.x)\" y=\"\(point.y)\" font-family=\"Helvetica,Arial,sans-serif\" font-size=\"\(size)\" fill=\"\(c.hex)\">\(Self.escaped(text))</text>")
            }
        }
        return lines.joined(separator: "\n") + "\n</svg>\n"
    }

    func draw(in context: CGContext) {
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for element in elements {
            switch element {
            case let .rect(rect, color): context.setFillColor(color.cg); context.fill(rect)
            case let .line(a, b, color, width):
                context.setStrokeColor(color.cg); context.setLineWidth(width)
                context.move(to: a); context.addLine(to: b); context.strokePath()
            case let .text(text, point, size, color): Self.drawText(text, at: point, size: size, color: color, context: context)
            }
        }
    }

    static func drawText(_ text: String, at point: CGPoint, size: Double, color: Color = .ink, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil),
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cg
        ]
        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        context.scaleBy(x: 1, y: -1)
        context.textPosition = .zero
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes)), context)
        context.restoreGState()
    }

    func png() throws -> Data {
        guard let context = CGContext(data: nil, width: 2000, height: 1160, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw OrgRecError.invalidProject("Cannot allocate the plot image.")
        }
        context.translateBy(x: 0, y: 1160); context.scaleBy(x: 2, y: -2)
        draw(in: context)
        let data = NSMutableData()
        guard let image = context.makeImage(), let output = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw OrgRecError.invalidProject("Cannot encode the plot image.")
        }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else { throw OrgRecError.invalidProject("PNG export failed.") }
        return data as Data
    }
}

enum StandaloneAudioExport {
    static func write(_ document: StandaloneAnalysisDocument, workspace: URL, kind: StandaloneExportKind, destination: URL) throws {
        if kind == .json {
            try StandaloneAnalysisDataExport.json(document).write(to: destination, options: .atomic)
            return
        }
        if kind == .pdf {
            try pdf(document).write(to: destination, options: .atomic)
            return
        }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else {
            throw OrgRecError.invalidProject("Choose a new folder name. Existing folders are not replaced.")
        }
        let stage = destination.deletingLastPathComponent().appendingPathComponent(".orgrec-export-\(UUID().uuidString)")
        try manager.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: stage) }
        if kind == .bundle || kind == .csv {
            for (filename, contents) in try StandaloneAnalysisDataExport.tables(document) {
                try contents.write(to: stage.appendingPathComponent(filename), atomically: true, encoding: .utf8)
            }
        }
        if kind == .bundle || kind == .plots {
            for plot in StandalonePlot.make(document) {
                try plot.svg().write(to: stage.appendingPathComponent(plot.name + ".svg"), atomically: true, encoding: .utf8)
                try plot.png().write(to: stage.appendingPathComponent(plot.name + ".png"))
            }
        }
        if kind == .bundle {
            try StandaloneAnalysisDataExport.json(document).write(to: stage.appendingPathComponent("analysis.json"))
            try StandaloneAnalysisDataExport.json(document.waveform).write(to: stage.appendingPathComponent("waveform.json"))
            try StandaloneAnalysisDataExport.json(document.spectrogram).write(to: stage.appendingPathComponent("spectrogram.json"))
            try pdf(document).write(to: stage.appendingPathComponent("report.pdf"))
            let excerpt = workspace.appendingPathComponent("excerpt.wav")
            guard try sha256(of: excerpt) == document.excerptSHA256 else {
                throw OrgRecError.invalidProject("The analyzed excerpt changed. Reanalyze before exporting.")
            }
            try manager.copyItem(at: excerpt, to: stage.appendingPathComponent("excerpt.wav"))
        }
        // Provenance accompanies partial exports too, without duplicating large matrices.
        var provenance = ["sourceFilename": document.source.filename, "sourceSHA256": document.sourceSHA256,
                          "excerptSHA256": document.excerptSHA256, "sourceStartFrame": String(document.startFrame),
                          "excerptFrameCount": String(document.frameCount), "sourceSampleRateHz": String(document.source.sampleRate),
                          "referenceChannelZeroBased": String(document.request.referenceChannel),
                          "analysisRunID": document.analysis.analysisRunID?.uuidString ?? "unknown",
                          "softwareVersion": document.software.version, "softwareBuild": document.software.build]
        for (key, value) in document.spectrogram.analysisRun?.parameters ?? [:] { provenance["parameter." + key] = value }
        try StandaloneAnalysisDataExport.json(provenance).write(to: stage.appendingPathComponent("provenance.json"))
        let notes = "OrgRec standalone audio analysis\n\n" + (document.limitations + document.analysis.qualityFlags).joined(separator: "\n\n") + "\n\nCSV times are in seconds. Empty fields mean unavailable. Waveform data are a reduced display summary, not the raw audio. Spectrogram levels are relative dB. Plots use the stored display grid; numerical exports retain every stored bin and point.\n"
        try notes.write(to: stage.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        let files = try manager.contentsOfDirectory(at: stage, includingPropertiesForKeys: nil).sorted { $0.lastPathComponent < $1.lastPathComponent }
        let sums = try files.map { "\(try sha256(of: $0))  \($0.lastPathComponent)" }.joined(separator: "\n") + "\n"
        try sums.write(to: stage.appendingPathComponent("SHA256SUMS"), atomically: true, encoding: .utf8)
        try manager.moveItem(at: stage, to: destination)
    }

    static func pdf(_ document: StandaloneAnalysisDocument) throws -> Data {
        let bytes = NSMutableData()
        var media = CGRect(x: 0, y: 0, width: 1000, height: 700)
        guard let consumer = CGDataConsumer(data: bytes), let context = CGContext(consumer: consumer, mediaBox: &media, nil) else {
            throw OrgRecError.invalidProject("Cannot create the PDF report.")
        }
        var page = 0
        func begin() {
            context.beginPDFPage(nil); page += 1
            context.saveGState(); context.translateBy(x: 0, y: 700); context.scaleBy(x: 1, y: -1)
            StandalonePlot.drawText("OrgRec audio analysis · page \(page)", at: CGPoint(x: 55, y: 674), size: 10, context: context)
        }
        func end() { context.restoreGState(); context.endPDFPage() }
        func value(_ number: Double?, unit: String) -> String {
            number.map { String(format: "%.3f", $0) + " " + unit } ?? "unavailable"
        }
        let introduction = [
            "OrgRec · Standalone audio analysis",
            "Source: \(document.source.filename)",
            String(format: "Source duration %.3f s · %.0f Hz · %d channels", document.source.duration, document.source.sampleRate, document.source.channelCount),
            String(format: "Analyzed source interval %.3f–%.3f s · channel %d", document.sourceStartSeconds, document.sourceStartSeconds + document.duration, document.request.referenceChannel + 1),
            "Sound type: \(document.request.applicability.rawValue)",
            "OrgRec \(document.software.version) build \(document.software.build) · \(document.analysis.algorithmVersion)",
            "Run: \(document.analysis.analysisRunID?.uuidString ?? "unknown")",
            "Original SHA-256: \(document.sourceSHA256)",
            "Excerpt SHA-256: \(document.excerptSHA256)",
            "", "MEASUREMENT OVERVIEW",
            "Pitch: \(value(document.analysis.frequencyHz, unit: "Hz")) · Reference deviation: \(value(document.analysis.centsDeviation, unit: "cents"))",
            "Peak: \(value(document.analysis.peakDBFS, unit: "dBFS")) · RMS: \(value(document.analysis.rmsDBFS, unit: "dBFS")) · Signal to noise: \(value(document.analysis.signalToNoiseDB, unit: "dB"))",
            "Onset: \(value(document.analysis.onsetSeconds, unit: "s")) · Sound offset: \(value(document.analysis.soundOffsetSeconds, unit: "s")) · Tail end: \(value(document.analysis.tailEndSeconds, unit: "s"))",
            "Clipped samples: \(document.analysis.clippedSamples) · Unreviewed loop candidates: \(document.analysis.detectedLoopPointSets?.count ?? 0)",
            "", "INTERPRETATION AND QUALITY"
        ] + document.limitations + document.analysis.qualityFlags
        func textPages(_ paragraphs: [String]) {
            begin(); var y = 45.0
            for paragraph in paragraphs {
                let isTitle = paragraph == "OrgRec · Standalone audio analysis"
                let isHeading = ["MEASUREMENT OVERVIEW", "INTERPRETATION AND QUALITY", "ANALYSIS PARAMETERS", "COMPLETE MEASUREMENT SUMMARY"].contains(paragraph)
                let size = isTitle ? 22.0 : (isHeading ? 15.0 : 11.0)
                let text = paragraph as NSString
                let attributed = NSAttributedString(string: paragraph, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, size, nil)])
                let typesetter = CTTypesetterCreateWithAttributedString(attributed)
                var offset = 0
                if paragraph.isEmpty { y += 8 }
                while offset < text.length {
                    let count = max(1, CTTypesetterSuggestLineBreak(typesetter, offset, 890))
                    let line = text.substring(with: NSRange(location: offset, length: min(count, text.length - offset))).trimmingCharacters(in: .whitespacesAndNewlines)
                    if y > 640 { end(); begin(); y = 45 }
                    StandalonePlot.drawText(line, at: CGPoint(x: 55, y: y), size: size, context: context)
                    y += size + 5
                    offset += count
                }
                y += 6
            }
            end()
        }
        textPages(introduction)
        for plot in StandalonePlot.make(document) { begin(); plot.draw(in: context); end() }
        let parameters = (document.spectrogram.analysisRun?.parameters ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
        let values = try StandaloneAnalysisDataExport.rows(document.analysis).map { "\($0.path): \($0.value)" }
        textPages(["ANALYSIS PARAMETERS"] + parameters + ["", "COMPLETE MEASUREMENT SUMMARY", "Missing optional fields were not estimated. Time values are relative to the excerpt."] + values)
        context.closePDF()
        return bytes as Data
    }
}
