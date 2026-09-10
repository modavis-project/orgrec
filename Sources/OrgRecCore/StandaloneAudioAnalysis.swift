import AVFoundation
import CoreFoundation
import Foundation

public struct StandaloneAudioSource: Codable, Hashable, Sendable {
    public var filename: String
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int64
    public var duration: Double { Double(frameCount) / sampleRate }
    /// Bounds the decoded excerpt used by analysis and interactive playback.
    public var maximumExcerptDuration: Double {
        min(600, Double(128 * 1_024 * 1_024) / (sampleRate * Double(channelCount) * 4))
    }

    public static func inspect(_ url: URL) throws -> Self {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard file.length > 0, format.sampleRate.isFinite, format.sampleRate > 0,
              format.channelCount > 0, format.channelCount <= 64 else {
            throw OrgRecError.unsupportedAudio("Choose a nonempty audio file with at most 64 channels.")
        }
        return Self(filename: url.lastPathComponent, sampleRate: format.sampleRate,
                    channelCount: Int(format.channelCount), frameCount: file.length)
    }
}

public struct StandaloneAnalysisRequest: Codable, Hashable, Sendable {
    public var startSeconds: Double
    public var durationSeconds: Double
    public var referenceChannel: Int
    public var expectedFrequencyHz: Double?
    public var applicability: PitchAnalysisApplicability
    public var configuration: SpectrogramConfiguration

    public init(startSeconds: Double = 0, durationSeconds: Double = 120, referenceChannel: Int = 0,
                expectedFrequencyHz: Double? = nil, applicability: PitchAnalysisApplicability = .indeterminate,
                configuration: SpectrogramConfiguration = .init()) {
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
        self.referenceChannel = referenceChannel
        self.expectedFrequencyHz = expectedFrequencyHz
        self.applicability = applicability
        self.configuration = configuration
    }

    public func frameRange(in source: StandaloneAudioSource) throws -> Range<Int64> {
        guard startSeconds.isFinite, durationSeconds.isFinite, startSeconds >= 0,
              durationSeconds > 0, startSeconds < source.duration,
              durationSeconds <= source.maximumExcerptDuration + 0.000_001,
              (0..<source.channelCount).contains(referenceChannel) else {
            throw OrgRecError.unsupportedAudio("Choose a valid channel and excerpt within the file, no longer than \(Int(source.maximumExcerptDuration)) seconds.")
        }
        if let frequency = expectedFrequencyHz {
            guard frequency.isFinite, frequency >= 10, frequency <= min(20_000, source.sampleRate / 2) else {
                throw OrgRecError.unsupportedAudio("The optional reference frequency must be between 10 Hz and the smaller of 20 kHz or Nyquist.")
            }
        }
        let lower = Int64((startSeconds * source.sampleRate).rounded(.down))
        let upper = min(source.frameCount, lower + Int64((durationSeconds * source.sampleRate).rounded(.down)))
        guard upper > lower else { throw OrgRecError.unsupportedAudio("The selected excerpt contains no audio frames.") }
        return lower..<upper
    }
}

public struct StandaloneAnalysisDocument: Codable, Sendable {
    public var formatVersion = "orgrec-standalone-analysis/1"
    public var software = OrgRecSoftware.current
    public var source: StandaloneAudioSource
    public var sourceSHA256: String
    public var excerptSHA256: String
    public var startFrame: Int64
    public var frameCount: Int64
    public var request: StandaloneAnalysisRequest
    public var limitations: [String]
    public var analysis: AnalysisSummary
    public var waveform: WaveformSummary
    public var spectrogram: SpectrogramData
    public var sourceStartSeconds: Double { Double(startFrame) / source.sampleRate }
    public var duration: Double { Double(frameCount) / source.sampleRate }
}

/// Owns no project state. The caller owns the temporary workspace after success.
public actor StandaloneAudioAnalyzer {
    public init() {}

    public func analyze(sourceURL: URL, request: StandaloneAnalysisRequest, workspace: URL) async throws -> StandaloneAnalysisDocument {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: workspace.path) else {
            throw OrgRecError.invalidProject("The analysis workspace already exists.")
        }
        try manager.createDirectory(at: workspace, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var succeeded = false
        defer { if !succeeded { try? manager.removeItem(at: workspace) } }
        try Task.checkCancellation()
        let source = try StandaloneAudioSource.inspect(sourceURL)
        let range = try request.frameRange(in: source)
        let originalHash = try sha256(of: sourceURL)
        let excerptURL = workspace.appendingPathComponent("excerpt.wav")
        try Self.writeExcerpt(from: sourceURL, to: excerptURL, frames: range)
        try Task.checkCancellation()
        let excerptHash = try sha256(of: excerptURL)
        var configuration = request.configuration
        configuration.maximumAnalysisDurationSeconds = Double(range.count) / source.sampleRate
        let permitsPitch = request.applicability == .monophonic || request.applicability == .indeterminate
        let result = try await AudioAnalyzer().analyze(
            fileURL: excerptURL, expectedFrequency: permitsPitch ? request.expectedFrequencyHz : nil,
            referenceChannel: request.referenceChannel, spectrogramConfiguration: configuration,
            pitchApplicability: request.applicability
        )
        try Task.checkCancellation()
        guard try sha256(of: sourceURL) == originalHash else {
            throw OrgRecError.unsupportedAudio("The source changed during analysis. Select it again and retry.")
        }
        var spectrogram = result.2
        spectrogram.analysisRun?.artifactRelativePaths = ["waveform.json", "spectrogram.json"]
        var normalizedRequest = request
        normalizedRequest.startSeconds = Double(range.lowerBound) / source.sampleRate
        normalizedRequest.durationSeconds = Double(range.count) / source.sampleRate
        normalizedRequest.configuration = spectrogram.configuration ?? configuration
        normalizedRequest.expectedFrequencyHz = permitsPitch ? request.expectedFrequencyHz : nil
        var limitations = [
            "Plots and analysis fields use excerpt-relative times. CSV tables also provide source-relative timestamps; add the source start time when interpreting other excerpt-relative values.",
            "Segmentation and sustain descriptors assume an isolated sound event. For music or multiple notes, select an individual event before interpreting these results.",
            "Release decay describes the recorded sound and room together; it is not a calibrated room reverberation measurement.",
            "Temperament, rank or collection comparisons, spatial geometry and recording-hardware diagnostics require additional recordings or acquisition metadata and are unavailable here.",
            "Sound pressure levels cannot be inferred from dBFS without calibration. Automated boundaries and loop candidates have not been reviewed."
        ]
        if request.applicability == .indeterminate {
            limitations.append("The sound type is unknown. Pitch and harmonic interpretations are exploratory until a single pitched source is confirmed.")
        } else if !permitsPitch {
            limitations.append("Single-source pitch estimation is disabled for the selected sound type. Pitch-dependent results are unavailable.")
        }
        if normalizedRequest.expectedFrequencyHz == nil {
            limitations.append("No reference frequency is applied; tuning deviation from an intended note is unavailable.")
        }
        if range.lowerBound > 0 || range.upperBound < source.frameCount {
            limitations.append("Only the selected excerpt was analysed, not the entire source recording.")
        }
        let document = StandaloneAnalysisDocument(source: source, sourceSHA256: originalHash,
            excerptSHA256: excerptHash, startFrame: range.lowerBound, frameCount: Int64(range.count),
            request: normalizedRequest, limitations: limitations, analysis: result.0,
            waveform: result.1, spectrogram: spectrogram)
        succeeded = true
        return document
    }

    private static func writeExcerpt(from source: URL, to destination: URL, frames: Range<Int64>) throws {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        var settings = format.settings
        settings[AVLinearPCMIsNonInterleaved] = false
        let output = try AVAudioFile(forWriting: destination, settings: settings,
                                     commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 65_536) else {
            throw OrgRecError.unsupportedAudio("Cannot allocate the excerpt buffer.")
        }
        input.framePosition = frames.lowerBound
        var remaining = frames.count
        while remaining > 0 {
            try Task.checkCancellation()
            try input.read(into: buffer, frameCount: AVAudioFrameCount(min(65_536, remaining)))
            guard buffer.frameLength > 0 else { throw OrgRecError.unsupportedAudio("The source ended before the selected excerpt.") }
            if let channels = buffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    guard UnsafeBufferPointer(start: channels[channel], count: Int(buffer.frameLength)).allSatisfy({ $0.isFinite }) else {
                        throw OrgRecError.unsupportedAudio("The selected excerpt contains non-finite samples. Repair or replace the source audio before analysis.")
                    }
                }
            }
            try output.write(from: buffer)
            remaining -= Int(buffer.frameLength)
        }
    }
}

public struct AnalysisValueRow: Identifiable, Sendable {
    public var id: String { path }
    public var path: String
    public var value: String
}

public enum StandaloneAnalysisDataExport {
    public static func json<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return try encoder.encode(value)
    }

    public static func rows<T: Encodable>(_ value: T) throws -> [AnalysisValueRow] {
        let object = try JSONSerialization.jsonObject(with: json(value), options: [.fragmentsAllowed])
        func flatten(_ object: Any, path: String) -> [AnalysisValueRow] {
            if let dictionary = object as? [String: Any] {
                return dictionary.keys.sorted().flatMap { flatten(dictionary[$0]!, path: path.isEmpty ? $0 : path + "." + $0) }
            }
            if let array = object as? [Any] {
                return array.enumerated().flatMap { flatten($0.element, path: path + "[\($0.offset)]") }
            }
            if let number = object as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
                return [.init(path: path, value: number.boolValue ? "true" : "false")]
            }
            return [.init(path: path, value: object is NSNull ? "unavailable" : String(describing: object))]
        }
        return flatten(object, path: "")
    }

    /// Quotes every cell and neutralizes spreadsheet formulas in textual fields.
    public static func csv(_ rows: [[String]]) -> String {
        rows.map { row in row.map { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
            let formula = ["=", "+", "-", "@"].contains { trimmed.hasPrefix($0) } && Double(trimmed) == nil
            return "\"" + (formula ? "'" : "") + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }.joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    public static func tables(_ document: StandaloneAnalysisDocument) throws -> [String: String] {
        func number(_ value: Double?) -> String { value.map(String.init(describing:)) ?? "" }
        var tables: [String: String] = [:]
        tables["measurements.csv"] = csv([["field", "value"]] + (try rows(document.analysis)).map { [$0.path, $0.value] })
        tables["pitch.csv"] = csv([["excerpt_time_s", "source_time_s", "frequency_hz", "confidence", "voiced", "estimator"]] + (document.spectrogram.pitchTrack ?? []).map {
            [number($0.timeSeconds), number($0.timeSeconds + document.sourceStartSeconds), number($0.frequencyHz), number($0.confidence), String($0.voiced), $0.estimator]
        })
        tables["partials.csv"] = csv([["harmonic", "excerpt_time_s", "source_time_s", "frequency_hz", "amplitude_db", "valid"]] + (document.spectrogram.partialTracks ?? []).flatMap { track in track.points.map {
            [String(track.harmonicNumber), number($0.timeSeconds), number($0.timeSeconds + document.sourceStartSeconds), number($0.frequencyHz), number($0.amplitudeDB), $0.isValid.map(String.init) ?? ""]
        } })
        tables["boundaries.csv"] = csv([["boundary", "excerpt_time_s", "source_time_s", "state"]] + (document.analysis.boundaries ?? []).map {
            [$0.marker.rawValue, number($0.seconds), number($0.seconds.map { $0 + document.sourceStartSeconds }), $0.state.rawValue]
        })
        tables["waveform.csv"] = csv([["excerpt_time_s", "source_time_s", "amplitude"]] + document.waveform.samples.enumerated().map {
            let time = Double($0.offset) / Double(max(1, document.waveform.samples.count - 1)) * document.waveform.duration
            return [number(time), number(time + document.sourceStartSeconds), String($0.element)]
        })
        tables["spectrogram.csv"] = csv([["excerpt_time_s", "source_time_s", "frequency_hz", "relative_level_db"]] + document.spectrogram.magnitudes.enumerated().flatMap { time, bins in bins.enumerated().map { frequency, level in
            let seconds = Double(time) * (document.spectrogram.timeStepSeconds ?? 0)
            let hz = document.spectrogram.frequencyAxisHz.flatMap { $0.indices.contains(frequency) ? $0[frequency] : nil }
            return [number(seconds), number(seconds + document.sourceStartSeconds), number(hz), String(level)]
        } })
        return tables
    }
}
