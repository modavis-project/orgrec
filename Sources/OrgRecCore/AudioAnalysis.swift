import Accelerate
@preconcurrency import AVFAudio
@preconcurrency import CoreML
import Foundation

public struct WaveformSummary: Codable, Hashable, Sendable {
    public var samples: [Float]
    public var sampleRate: Double
    public var duration: Double

    public init(samples: [Float], sampleRate: Double, duration: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.duration = duration
    }
}

public struct SpectrogramData: Codable, Hashable, Sendable {
    public var magnitudes: [[Float]]
    public var timeBins: Int
    public var frequencyBins: Int
    public var maximumFrequency: Double
    public var timeStepSeconds: Double?
    public var frequencyAxisHz: [Double]?
    public var configuration: SpectrogramConfiguration?
    public var partialTracks: [PartialTrack]?
    public var pitchTrack: [PitchTrackPoint]?
    public var analysisRun: AnalysisRunRecord?

    public init(
        magnitudes: [[Float]],
        timeBins: Int,
        frequencyBins: Int,
        maximumFrequency: Double,
        timeStepSeconds: Double? = nil,
        frequencyAxisHz: [Double]? = nil,
        configuration: SpectrogramConfiguration? = nil,
        partialTracks: [PartialTrack]? = nil,
        pitchTrack: [PitchTrackPoint]? = nil,
        analysisRun: AnalysisRunRecord? = nil
    ) {
        self.magnitudes = magnitudes
        self.timeBins = timeBins
        self.frequencyBins = frequencyBins
        self.maximumFrequency = maximumFrequency
        self.timeStepSeconds = timeStepSeconds
        self.frequencyAxisHz = frequencyAxisHz
        self.configuration = configuration
        self.partialTracks = partialTracks
        self.pitchTrack = pitchTrack
        self.analysisRun = analysisRun
    }
}

public struct PitchEstimate: Sendable {
    public var frequencyHz: Double
    public var confidence: Double
    public var method: String
    public var modelVersion: String
    public var track: [PitchTrackPoint]
    public var estimatorAgreementCents: Double?

    public init(
        frequencyHz: Double,
        confidence: Double,
        method: String,
        modelVersion: String,
        track: [PitchTrackPoint] = [],
        estimatorAgreementCents: Double? = nil
    ) {
        self.frequencyHz = frequencyHz
        self.confidence = confidence
        self.method = method
        self.modelVersion = modelVersion
        self.track = track
        self.estimatorAgreementCents = estimatorAgreementCents
    }
}

public protocol PitchEstimating: Sendable {
    func estimate(samples: [Float], sampleRate: Double, expectedFrequency: Double?) async throws -> PitchEstimate?
}

public actor CREPEPitchEstimator: PitchEstimating {
    private var model: MLModel?
    private let modelURL: URL?

    public init(modelURL: URL? = CREPEPitchEstimator.discoverModel()) {
        self.modelURL = modelURL
    }

    public nonisolated static func discoverModel() -> URL? {
        if let appResource = Bundle.main.url(forResource: "crepe-tiny", withExtension: "mlmodelc") { return appResource }
        if let packaged = OrgRecResources.bundle.url(forResource: "crepe-tiny", withExtension: "mlmodelc") { return packaged }
        if let bundled = Bundle.main.url(forResource: "crepe-full", withExtension: "mlmodelc") { return bundled }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("OrgRec/Models/crepe-tiny.mlmodelc", isDirectory: true)
        if let support, FileManager.default.fileExists(atPath: support.path) { return support }
        return nil
    }

    public func estimate(samples: [Float], sampleRate: Double, expectedFrequency: Double?) async throws -> PitchEstimate? {
        guard let modelURL else { return nil }
        if model == nil {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            model = try MLModel(contentsOf: modelURL, configuration: configuration)
        }
        guard let model else { return nil }
        let mono16k = resample(samples, from: sampleRate, to: 16_000)
        guard mono16k.count >= 1024 else { return nil }
        var rawFrames: [(time: Double, frequency: Double, confidence: Double)] = []
        let inputName = model.modelDescription.inputDescriptionsByName.keys.first ?? "input"
        let outputName = model.modelDescription.outputDescriptionsByName.keys.first ?? "output"

        let hop = 160
        var start = 0
        while start + 1024 <= mono16k.count {
            let frame = Array(mono16k[start..<(start + 1024)])
            let normalized = normalize(frame)
            let input = try MLMultiArray(shape: [1, 1024], dataType: .float32)
            for index in normalized.indices { input[index] = NSNumber(value: normalized[index]) }
            let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: input])
            let prediction = try await model.prediction(from: provider)
            guard let activation = prediction.featureValue(for: outputName)?.multiArrayValue else {
                throw OrgRecError.unsupportedAudio("The installed CREPE model does not expose a multi-array activation output.")
            }
            let values = (0..<min(360, activation.count)).map { activation[$0].doubleValue }
            if let estimate = Self.decodeCREPE(values) {
                rawFrames.append((Double(start) / 16_000, estimate.frequency, estimate.confidence))
            }
            start += hop
        }
        guard !rawFrames.isEmpty else { return nil }
        let preliminary = rawFrames.filter { $0.confidence >= 0.15 }
        let center = expectedFrequency ?? median(preliminary.isEmpty ? rawFrames.map(\.frequency) : preliminary.map(\.frequency))
        let track = rawFrames.map { frame -> PitchTrackPoint in
            let cents = centsDifference(measured: frame.frequency, expected: center)
            let plausible = cents.map { abs($0) <= 700 } ?? false
            return PitchTrackPoint(
                timeSeconds: frame.time,
                frequencyHz: plausible ? frame.frequency : nil,
                confidence: frame.confidence,
                voiced: frame.confidence >= 0.25 && plausible,
                estimator: "CREPE Core ML",
                centsFromExpected: expectedFrequency.flatMap { centsDifference(measured: frame.frequency, expected: $0) }
            )
        }
        let usable = track.filter(\.voiced).compactMap(\.frequencyHz)
        guard usable.isEmpty == false else { return nil }
        let usableConfidences = track.filter(\.voiced).map(\.confidence)
        let version = model.modelDescription.metadata[MLModelMetadataKey.versionString] as? String
            ?? modelURL.lastPathComponent
        return PitchEstimate(
            frequencyHz: median(usable),
            confidence: median(usableConfidences),
            method: "CREPE Core ML",
            modelVersion: version,
            track: track
        )
    }

    private static func decodeCREPE(_ activations: [Double]) -> (frequency: Double, confidence: Double)? {
        guard let maxIndex = activations.indices.max(by: { activations[$0] < activations[$1] }) else { return nil }
        let lower = max(0, maxIndex - 4)
        let upper = min(activations.count - 1, maxIndex + 4)
        let centMapping = (0..<360).map { 1997.3794084376191 + 20 * Double($0) }
        var weighted = 0.0
        var total = 0.0
        for index in lower...upper {
            let weight = max(0, activations[index])
            weighted += centMapping[index] * weight
            total += weight
        }
        guard total > 0 else { return nil }
        let cents = weighted / total
        let frequency = 10 * pow(2, cents / 1200)
        return (frequency, activations[maxIndex])
    }
}

public struct AutocorrelationPitchEstimator: PitchEstimating {
    public init() {}

    public func estimate(samples: [Float], sampleRate: Double, expectedFrequency: Double?) async throws -> PitchEstimate? {
        guard samples.count > 2_048 else { return nil }
        let minimumFrequency = max(16, expectedFrequency.map { $0 / 1.5 } ?? (65 / 2.5))
        let maximumFrequency = min(sampleRate * 0.45, 12_000, expectedFrequency.map { $0 * 1.5 } ?? (440 * 2.1))
        let minLag = max(1, Int(sampleRate / maximumFrequency))
        let frameLength = min(samples.count, max(4_096, min(16_384, Int(sampleRate / minimumFrequency * 8))))
        let maxLag = min(frameLength / 2, Int(sampleRate / minimumFrequency))
        guard minLag < maxLag else { return nil }
        let availableStarts = max(1, samples.count - frameLength + 1)
        let maximumFrames = maxLag > 500 ? 12 : (maxLag > 100 ? 32 : 64)
        let frameCount = min(maximumFrames, max(1, Int(ceil(Double(samples.count) / Double(max(1, frameLength / 2))))))
        let starts = (0..<frameCount).map { index in
            frameCount == 1 ? max(0, (samples.count - frameLength) / 2)
                : Int(Double(index) * Double(availableStarts - 1) / Double(frameCount - 1))
        }
        var track: [PitchTrackPoint] = []
        for start in starts {
            var window = Array(samples[start..<(start + frameLength)])
            var mean: Float = 0
            vDSP_meanv(window, 1, &mean, vDSP_Length(window.count))
            var negativeMean = -mean
            vDSP_vsadd(window, 1, &negativeMean, &window, 1, vDSP_Length(window.count))
            guard let frame = Self.normalizedAutocorrelation(
                window: window,
                sampleRate: sampleRate,
                minimumLag: minLag,
                maximumLag: maxLag,
                expectedFrequency: expectedFrequency
            ) else { continue }
            track.append(PitchTrackPoint(
                timeSeconds: (Double(start) + Double(frameLength) / 2) / sampleRate,
                frequencyHz: frame.frequency,
                confidence: frame.confidence,
                voiced: frame.confidence >= 0.35,
                estimator: "Normalized autocorrelation",
                centsFromExpected: expectedFrequency.flatMap { centsDifference(measured: frame.frequency, expected: $0) }
            ))
        }
        let voiced = track.filter(\.voiced)
        guard voiced.isEmpty == false else { return nil }
        return PitchEstimate(
            frequencyHz: median(voiced.compactMap(\.frequencyHz)),
            confidence: median(voiced.map(\.confidence)),
            method: "Normalized autocorrelation fallback",
            modelVersion: "orgrec-autocorrelation/2",
            track: track
        )
    }

    private static func normalizedAutocorrelation(
        window: [Float],
        sampleRate: Double,
        minimumLag: Int,
        maximumLag: Int,
        expectedFrequency: Double?
    ) -> (frequency: Double, confidence: Double)? {
        var correlations = [Float](repeating: 0, count: maximumLag + 1)
        window.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            for lag in minimumLag...maximumLag {
                let count = window.count - lag
                var dot: Float = 0
                var leftEnergy: Float = 0
                var rightEnergy: Float = 0
                vDSP_dotpr(base, 1, base.advanced(by: lag), 1, &dot, vDSP_Length(count))
                vDSP_svesq(base, 1, &leftEnergy, vDSP_Length(count))
                vDSP_svesq(base.advanced(by: lag), 1, &rightEnergy, vDSP_Length(count))
                let denominator = sqrt(max(1e-20, leftEnergy * rightEnergy))
                correlations[lag] = dot / denominator
            }
        }
        var candidates: [Int] = []
        if maximumLag - minimumLag >= 2 {
            for lag in (minimumLag + 1)..<maximumLag
            where correlations[lag] >= correlations[lag - 1] && correlations[lag] >= correlations[lag + 1] {
                candidates.append(lag)
            }
        }
        if candidates.isEmpty, let best = (minimumLag...maximumLag).max(by: { correlations[$0] < correlations[$1] }) {
            candidates = [best]
        }
        guard let bestLag = candidates.max(by: { left, right in
            func score(_ lag: Int) -> Double {
                let correlation = Double(correlations[lag])
                guard let expectedFrequency else { return correlation - 0.000_01 * Double(lag) }
                let frequency = sampleRate / Double(lag)
                let distance = abs(centsDifference(measured: frequency, expected: expectedFrequency) ?? 1_200)
                return correlation - min(0.12, distance / 10_000)
            }
            return score(left) < score(right)
        }) else { return nil }
        let confidence = Double(correlations[bestLag])
        guard confidence > 0.08 else { return nil }
        var refinedLag = Double(bestLag)
        if bestLag > minimumLag, bestLag < maximumLag {
            let left = Double(correlations[bestLag - 1])
            let center = Double(correlations[bestLag])
            let right = Double(correlations[bestLag + 1])
            let denominator = left - 2 * center + right
            if abs(denominator) > 1e-12 {
                refinedLag += min(0.5, max(-0.5, 0.5 * (left - right) / denominator))
            }
        }
        return (sampleRate / refinedLag, min(1, max(0, confidence)))
    }
}

public actor AudioAnalyzer {
    private let crepe: CREPEPitchEstimator
    private let pyin: PYINPitchEstimator
    private let fallback: AutocorrelationPitchEstimator

    public init(
        crepe: CREPEPitchEstimator = CREPEPitchEstimator(),
        pyin: PYINPitchEstimator = PYINPitchEstimator(),
        fallback: AutocorrelationPitchEstimator = AutocorrelationPitchEstimator()
    ) {
        self.crepe = crepe
        self.pyin = pyin
        self.fallback = fallback
    }

    public func analyze(
        fileURL: URL,
        expectedFrequency: Double?,
        referenceChannel: Int = 0,
        spectrogramConfiguration: SpectrogramConfiguration = SpectrogramConfiguration(),
        pitchApplicability: PitchAnalysisApplicability = .monophonic
    ) async throws -> (AnalysisSummary, WaveformSummary, SpectrogramData) {
        let startedAt = Date()
        let read = try Self.readAudio(
            from: fileURL,
            referenceChannel: referenceChannel,
            maximumDurationSeconds: spectrogramConfiguration.maximumAnalysisDurationSeconds
        )
        let samples = read.samples
        let rate = read.sampleRate
        guard !samples.isEmpty else { throw OrgRecError.unsupportedAudio("The take contains no readable samples.") }
        let duration = Double(samples.count) / rate
        let transientHop = max(64, Int(rate * 0.01))
        let features = Self.transientFeatures(samples: samples, window: max(128, Int(rate * 0.02)), hop: transientHop)
        let transient = Self.detectTransient(features: features, hopSeconds: Double(transientHop) / rate, totalDuration: duration)
        let steadyRegion = SpectrumSegmentation.steadyRegion(
            duration: duration, sustainStart: transient.sustainStart,
            soundOffset: transient.soundOffset, keyUp: nil, maximumDuration: duration, releaseGuard: 0.12
        )
        let sustainStart = steadyRegion.start
        let sustainEnd = steadyRegion.end
        let sustainSamples = Self.segment(samples, rate: rate, start: sustainStart, end: sustainEnd)
        let pitch: PitchEstimate?
        let pitchComparison: PitchEstimatorComparison?
        if pitchApplicability == .monophonic || pitchApplicability == .indeterminate {
            let useCREPE = expectedFrequency.map { $0 <= 1_900 } ?? true
            let primary: (PitchEstimate?, PitchEstimate?)
            if useCREPE {
                async let crepeTask = crepe.estimate(samples: sustainSamples, sampleRate: rate, expectedFrequency: expectedFrequency)
                async let pyinTask = pyin.estimate(samples: sustainSamples, sampleRate: rate, expectedFrequency: expectedFrequency)
                primary = try await (crepeTask, pyinTask)
            } else {
                primary = (nil, try await pyin.estimate(samples: sustainSamples, sampleRate: rate, expectedFrequency: expectedFrequency))
            }
            let initial = PitchEstimatorComparisonEngine.resolve(
                crepe: primary.0,
                pyin: primary.1,
                expectedFrequency: expectedFrequency
            )
            let fallbackPitch: PitchEstimate?
            if initial.estimate == nil || initial.comparison.severity == .critical {
                fallbackPitch = try await fallback.estimate(
                    samples: sustainSamples, sampleRate: rate, expectedFrequency: expectedFrequency
                )
            } else {
                fallbackPitch = nil
            }
            let resolution = PitchEstimatorComparisonEngine.resolve(
                crepe: primary.0,
                pyin: primary.1,
                fallback: fallbackPitch,
                expectedFrequency: expectedFrequency
            )
            pitch = resolution.estimate
            pitchComparison = resolution.comparison
        } else {
            pitch = nil
            pitchComparison = nil
        }
        let pitchTrack: [PitchTrackPoint] = (pitch?.track ?? []).map { point in
            var shifted = point
            shifted.timeSeconds += sustainStart
            return shifted
        }
        var pitchSummary = Self.summarizePitchTrack(pitchTrack, expectedFrequency: expectedFrequency)
        pitchSummary?.estimatorAgreementCents = pitch?.estimatorAgreementCents

        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        var mean: Float = 0
        vDSP_meanv(samples, 1, &mean, vDSP_Length(samples.count))
        let clipped = samples.reduce(into: 0) { if abs($1) >= 0.999 { $0 += 1 } }
        let nearClipped = samples.reduce(into: 0) { if abs($1) >= 0.98 { $0 += 1 } }
        let signalToNoise = Self.signalToNoiseDB(features: features, transient: transient)
        var flags = steadyRegion.limitations
        if clipped > 0 { flags.append("Clipping detected") }
        else if nearClipped > max(8, samples.count / 10_000) { flags.append("Near-clipping detected") }
        if abs(mean) > 0.01 { flags.append("DC offset exceeds 1% full scale") }
        if let signalToNoise, signalToNoise < 20 { flags.append("Low signal-to-noise ratio") }
        if transient.boundaries.first(where: { $0.marker == .onset })?.state != .observed { flags.append("Onset not fully observed") }
        if transient.boundaries.first(where: { $0.marker == .soundOffset })?.state != .observed { flags.append("Sound offset not fully observed") }
        if transient.boundaries.first(where: { $0.marker == .tailEnd })?.state != .observed { flags.append("Room-tail end not fully observed") }
        if let onset = transient.onset, onset < 0.25 { flags.append("Pre-roll is shorter than 250 ms") }
        if let sustain = transient.sustainStart, let offset = transient.soundOffset, offset - sustain < 0.5 {
            flags.append("Stable sustain is shorter than 500 ms")
        }
        if read.channelRelationships.contains(where: { abs($0.levelDifferenceDB) > 20 }) {
            flags.append("Interchannel level imbalance exceeds 20 dB")
        }
        if read.channelRelationships.contains(where: \.polarityInversionSuspected) {
            flags.append("Strong interchannel polarity inversion suspected")
        }
        if pitchApplicability == .monophonic, pitch == nil { flags.append("Required monophonic pitch estimate unavailable") }
        if let confidence = pitch?.confidence, confidence < 0.65 { flags.append("Low pitch confidence") }
        if let voicedRatio = pitchSummary?.voicedRatio, voicedRatio < 0.6 { flags.append("Pitch track is sparsely voiced") }
        if let spread = pitchSummary?.interquartileRangeCents, spread > 15 { flags.append("Pitch is unstable during sustain") }
        if let errors = pitchSummary?.suspectedOctaveErrorCount, errors > 0 { flags.append("Pitch track contains suspected octave errors") }
        if let comparison = pitchComparison, comparison.severity == .critical {
            let crepeValue = comparison.estimates.first(where: { $0.estimator == "CREPE" })?.frequencyHz
            let pyinValue = comparison.estimates.first(where: { $0.estimator == "pYIN" })?.frequencyHz
            let values = [crepeValue.map { "CREPE \($0.formatted(.number.precision(.fractionLength(2)))) Hz" },
                          pyinValue.map { "pYIN \($0.formatted(.number.precision(.fractionLength(2)))) Hz" }]
                .compactMap { $0 }.joined(separator: ", ")
            flags.append("CRITICAL pitch-estimator mismatch: \(values); \(comparison.differenceCents?.formatted(.number.precision(.fractionLength(1))) ?? "—") cents")
        } else if pitchComparison?.severity == .material {
            flags.append("Material CREPE–pYIN pitch mismatch requires review")
        }
        let cents = pitch.flatMap { estimate in expectedFrequency.flatMap { centsDifference(measured: estimate.frequencyHz, expected: $0) } }
        if let cents, abs(cents) > 25 { flags.append("Pitch outside ±25 cents") }

        let runID = UUID()
        let inputHash = try sha256(of: fileURL)
        let algorithmVersion = "orgrec-analysis/5; \(pitch?.modelVersion ?? "none")"
        let parameters = Self.analysisParameters(configuration: spectrogramConfiguration)
        var run = AnalysisRunRecord(
            id: runID,
            inputSHA256: inputHash,
            algorithmVersion: algorithmVersion,
            startedAt: startedAt,
            finishedAt: .now,
            referenceChannel: read.referenceChannel,
            parameters: parameters,
            parameterSHA256: (try? OrgRecCoding.lineEncoder.encode(parameters))?.sha256Hex,
            pitchApplicability: pitchApplicability,
            warnings: flags
        )

        var analysis = AnalysisSummary(
            method: pitch?.method ?? "No pitch estimate",
            algorithmVersion: algorithmVersion,
            onsetSeconds: transient.onset,
            sustainStartSeconds: transient.sustainStart,
            soundOffsetSeconds: transient.soundOffset,
            tailEndSeconds: transient.tailEnd,
            frequencyHz: pitch?.frequencyHz,
            confidence: pitch?.confidence,
            centsDeviation: cents,
            peakDBFS: Self.decibels(Double(peak)),
            rmsDBFS: Self.decibels(Double(rms)),
            clippedSamples: clipped,
            qualityFlags: flags,
            analysisRunID: runID,
            pitchApplicability: pitchApplicability,
            pitchTrackSummary: pitchSummary,
            boundaries: transient.boundaries,
            signalToNoiseDB: signalToNoise,
            dcOffset: Double(mean),
            nearClippedSamples: nearClipped,
            channelRelationships: read.channelRelationships,
            pitchEstimatorComparison: pitchComparison
        )
        let waveform = WaveformSummary(samples: Self.downsample(samples, count: 1_200), sampleRate: rate, duration: duration)
        let fundamental = pitch?.frequencyHz ?? expectedFrequency
        var spectrogram = Self.spectrogram(
            samples: samples,
            sampleRate: rate,
            configuration: spectrogramConfiguration,
            fundamentalFrequency: fundamental,
            transient: transient
        )
        analysis.spectralSummary = spectrogram.partialTracks.map(Self.summarizePartials)
        analysis.perceptualSpectralSummary = PerceptualSpectralAnalyzer.analyze(
            samples: sustainSamples,
            sampleRate: rate,
            fundamentalFrequency: fundamental
        )
        let observedSoundOffset = transient.boundaries.first {
            $0.marker == .soundOffset && $0.state == .observed
        }?.seconds
        let observedTailEnd = transient.boundaries.first {
            $0.marker == .tailEnd && $0.state == .observed
        }?.seconds
        if let observedSoundOffset, let observedTailEnd,
           observedTailEnd - observedSoundOffset >= 0.12 {
            analysis.acousticResponseAnalysis = AcousticResponseAnalyzer.analyze(
                samples: samples,
                sampleRate: rate,
                referenceChannel: read.referenceChannel,
                qualification: .observedInstrumentRelease,
                originSample: Int((observedSoundOffset * rate).rounded())
            )
        }
        let loopDetection: LoopDetectionResult?
        do {
            let detected = try LoopPointDetector.detect(
                fileURL: fileURL,
                analysis: analysis,
                pitchTrack: pitchTrack,
                sourceAudioSHA256: inputHash
            )
            loopDetection = detected
            analysis.detectedLoopPointSets = detected.candidates
            analysis.qualityFlags.append(contentsOf: detected.qualityFlags)
        } catch {
            loopDetection = nil
            analysis.qualityFlags.append("Loop detection unavailable: \(error.localizedDescription)")
        }
        analysis.pipeSoundBehavior = PipeSoundBehaviorAnalyzer.summarize(
            analysis: analysis,
            pitchTrack: pitchTrack,
            partialTracks: spectrogram.partialTracks ?? [],
            loopDetection: loopDetection
        )
        if let perceptual = analysis.perceptualSpectralSummary {
            if analysis.pipeSoundBehavior?.amplitudeModulationRateHz == nil {
                analysis.pipeSoundBehavior?.amplitudeModulationRateHz = perceptual.amplitudeModulationRateHz
            }
            if analysis.pipeSoundBehavior?.amplitudeModulationDepthDB == nil {
                analysis.pipeSoundBehavior?.amplitudeModulationDepthDB = perceptual.amplitudeModulationDepthDB
            }
        }
        if let normalizedConfiguration = spectrogram.configuration {
            run.parameters = Self.analysisParameters(configuration: normalizedConfiguration)
        }
        run.parameters["expectedFrequencyHz"] = expectedFrequency.map { String($0) } ?? "unavailable"
        run.parameters["sourceSampleRateHz"] = String(rate)
        run.parameters["referenceChannel"] = String(read.referenceChannel)
        run.parameters["steadyRegionSeconds"] = "\(sustainStart)...\(sustainEnd)"
        run.parameterSHA256 = (try? OrgRecCoding.lineEncoder.encode(run.parameters))?.sha256Hex
        run.finishedAt = .now
        run.outputSummary = analysis
        run.warnings = analysis.qualityFlags
        run.artifactRelativePaths = [
            "Analysis/Runs/\(runID.uuidString.lowercased())/waveform.json",
            "Analysis/Runs/\(runID.uuidString.lowercased())/spectrogram.json",
        ]
        run.pitchTrackSHA256 = (try? OrgRecCoding.lineEncoder.encode(pitchTrack))?.sha256Hex
        run.partialTracksSHA256 = (try? OrgRecCoding.lineEncoder.encode(spectrogram.partialTracks ?? []))?.sha256Hex
        spectrogram.pitchTrack = pitchTrack
        spectrogram.analysisRun = run
        return (analysis, waveform, spectrogram)
    }

    private struct AudioReadResult {
        var samples: [Float]
        var sampleRate: Double
        var referenceChannel: Int
        var channelRelationships: [ChannelRelationshipEvidence]
    }

    private static func readAudio(
        from url: URL,
        referenceChannel: Int,
        maximumDurationSeconds: Double
    ) throws -> AudioReadResult {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard file.length > 0 else {
            throw OrgRecError.unsupportedAudio("The take contains no audio frames.")
        }
        let durationLimit = max(1, min(600, maximumDurationSeconds))
        let frameLimit = min(file.length, Int64(durationLimit * format.sampleRate))
        let chunkFrames = AVAudioFrameCount(min(65_536, max(1, frameLimit)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw OrgRecError.unsupportedAudio("Cannot allocate an analysis buffer for this audio format.")
        }
        let selected = max(0, min(Int(format.channelCount) - 1, referenceChannel))
        var result: [Float] = []
        result.reserveCapacity(Int(frameLimit))
        var channelEnergy = [Double](repeating: 0, count: Int(format.channelCount))
        var relationshipSamples = [[Float]](repeating: [], count: Int(format.channelCount))
        var remaining = frameLimit
        while remaining > 0 {
            let requested = AVAudioFrameCount(min(Int64(chunkFrames), remaining))
            try file.read(into: buffer, frameCount: requested)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            let count = Int(buffer.frameLength)
            result.append(contentsOf: UnsafeBufferPointer(start: channels[selected], count: count))
            for channelIndex in 0..<Int(format.channelCount) {
                var energy: Float = 0
                vDSP_svesq(channels[channelIndex], 1, &energy, vDSP_Length(count))
                channelEnergy[channelIndex] += Double(energy)
                if relationshipSamples[channelIndex].count < 131_072 {
                    let retained = min(count, 131_072 - relationshipSamples[channelIndex].count)
                    relationshipSamples[channelIndex].append(contentsOf: UnsafeBufferPointer(start: channels[channelIndex], count: retained))
                }
            }
            remaining -= Int64(count)
        }
        let relationships = channelEnergy.indices.filter { $0 != selected }.map { channelIndex in
            let referenceRMS = sqrt(channelEnergy[selected] / Double(max(1, result.count)))
            let channelRMS = sqrt(channelEnergy[channelIndex] / Double(max(1, result.count)))
            let levelDifference = 20 * log10(max(channelRMS, 1e-9) / max(referenceRMS, 1e-9))
            let correlation = bestCorrelation(
                reference: relationshipSamples[selected],
                candidate: relationshipSamples[channelIndex],
                maximumLag: 64
            )
            return ChannelRelationshipEvidence(
                channelIndex: channelIndex,
                levelDifferenceDB: levelDifference,
                correlationWithReference: correlation?.value,
                delaySamples: correlation?.lag,
                polarityInversionSuspected: (correlation?.value ?? 0) < -0.8
            )
        }
        return AudioReadResult(samples: result, sampleRate: format.sampleRate, referenceChannel: selected, channelRelationships: relationships)
    }

    private struct TransientFeatureFrame {
        var rms: Double
        var levelDB: Double
        var spectralFlux: Double
        var highFrequencyRatio: Double
    }

    private struct TransientResult {
        var onset: Double?
        var sustainStart: Double?
        var soundOffset: Double?
        var tailEnd: Double?
        var noiseFloorDB: Double
        var sustainLevelDB: Double?
        var boundaries: [AnalysisBoundaryEvidence]
    }

    private static func transientFeatures(samples: [Float], window: Int, hop: Int) -> [TransientFeatureFrame] {
        guard samples.count >= window else { return [] }
        var result: [TransientFeatureFrame] = []
        var start = 0
        var previousRMS = 0.0
        while start + window <= samples.count {
            var rms: Float = 0
            var derivativeEnergy = 0.0
            samples.withUnsafeBufferPointer { pointer in
                guard let base = pointer.baseAddress else { return }
                vDSP_rmsqv(base.advanced(by: start), 1, &rms, vDSP_Length(window))
                if window > 1 {
                    for index in (start + 1)..<(start + window) {
                        let difference = Double(pointer[index] - pointer[index - 1])
                        derivativeEnergy += difference * difference
                    }
                }
            }
            let rmsValue = Double(rms)
            let flux = max(0, rmsValue - previousRMS) / max(1e-9, previousRMS + rmsValue)
            let highFrequency = sqrt(derivativeEnergy / Double(max(1, window - 1))) / max(1e-9, 2 * rmsValue)
            result.append(TransientFeatureFrame(
                rms: rmsValue,
                levelDB: decibels(rmsValue),
                spectralFlux: flux,
                highFrequencyRatio: min(1, highFrequency)
            ))
            previousRMS = rmsValue
            start += hop
        }
        return result
    }

    private static func detectTransient(features: [TransientFeatureFrame], hopSeconds: Double, totalDuration: Double) -> TransientResult {
        guard features.count > 12 else {
            let unresolved = AnalysisMarkerKind.allCases.map {
                AnalysisBoundaryEvidence(marker: $0, state: .unresolved, contributingFeatures: ["insufficient duration"])
            }
            return TransientResult(onset: nil, sustainStart: nil, soundOffset: nil, tailEnd: nil, noiseFloorDB: -120, sustainLevelDB: nil, boundaries: unresolved)
        }
        let levels = features.map(\.levelDB)
        let noiseFloor = quantile(levels, probability: 0.15)
        let peak = levels.max() ?? noiseFloor
        guard peak > -110 else {
            return TransientResult(onset: nil, sustainStart: nil, soundOffset: nil, tailEnd: nil,
                noiseFloorDB: noiseFloor, sustainLevelDB: nil,
                boundaries: AnalysisMarkerKind.allCases.map {
                    AnalysisBoundaryEvidence(marker: $0, state: .unresolved, contributingFeatures: ["no usable signal"])
                })
        }
        let continuousSignal = peak - noiseFloor < 6 && median(levels) > -70
        let onsetThreshold = continuousSignal ? peak - 3 : max(noiseFloor + 12, peak - 26)
        let sustainThreshold = continuousSignal ? peak - 6 : max(noiseFloor + 9, peak - 36)
        let tailThreshold = continuousSignal ? peak - 12 : max(noiseFloor + 4, peak - 55)
        let onsetPersistence = max(3, Int(0.04 / hopSeconds))
        let offsetPersistence = max(8, Int(0.16 / hopSeconds))
        let tailPersistence = max(12, Int(0.25 / hopSeconds))

        func persistent(start: Int, count: Int, predicate: (TransientFeatureFrame) -> Bool) -> Bool {
            guard start >= 0, start + count <= features.count else { return false }
            return features[start..<(start + count)].allSatisfy(predicate)
        }

        let beginsActive = persistent(start: 0, count: onsetPersistence) { $0.levelDB >= onsetThreshold }
        var onsetIndex: Int?
        if !beginsActive {
            for index in 1..<max(1, features.count - onsetPersistence)
            where persistent(start: index, count: onsetPersistence, predicate: { $0.levelDB >= onsetThreshold }) {
                let rising = features[index].spectralFlux > 0.02 || features[index].levelDB - features[max(0, index - 1)].levelDB > 1
                if rising { onsetIndex = index; break }
            }
        }

        let activeStart = onsetIndex ?? 0
        var sustainIndex: Int?
        let stabilityCount = max(8, Int(0.2 / hopSeconds))
        if activeStart + stabilityCount < features.count {
            for index in activeStart..<(features.count - stabilityCount) {
                let window = Array(levels[index..<(index + stabilityCount)])
                if (window.max() ?? 0) - (window.min() ?? 0) <= 4,
                   median(window) >= sustainThreshold {
                    sustainIndex = index
                    break
                }
            }
        }

        let endsActive = persistent(start: max(0, features.count - offsetPersistence), count: offsetPersistence) {
            $0.levelDB >= sustainThreshold
        }
        var offsetIndex: Int?
        if !endsActive {
            var lastActive: Int?
            for index in activeStart..<features.count where features[index].levelDB >= sustainThreshold { lastActive = index }
            if let lastActive,
               persistent(start: min(features.count - offsetPersistence, lastActive + 1), count: offsetPersistence, predicate: { $0.levelDB < sustainThreshold }) {
                offsetIndex = lastActive + 1
            }
        }

        var tailIndex: Int?
        if let offsetIndex, offsetIndex < features.count - tailPersistence {
            for index in offsetIndex..<(features.count - tailPersistence)
            where persistent(start: index, count: tailPersistence, predicate: { $0.levelDB <= tailThreshold }) {
                tailIndex = index
                break
            }
        }

        let onsetSeconds = onsetIndex.map { min(totalDuration, Double($0) * hopSeconds) }
        let sustainSeconds = sustainIndex.map { min(totalDuration, Double($0) * hopSeconds) }
        let offsetSeconds = offsetIndex.map { min(totalDuration, Double($0) * hopSeconds) }
        let tailSeconds = tailIndex.map { min(totalDuration, Double($0) * hopSeconds) }
        let onsetState: BoundaryEvidenceState = beginsActive ? .leftCensored : (onsetIndex == nil ? .unresolved : .observed)
        let offsetState: BoundaryEvidenceState = endsActive ? .rightCensored : (offsetIndex == nil ? .unresolved : .observed)
        let tailState: BoundaryEvidenceState = tailIndex == nil ? (endsActive ? .rightCensored : .unresolved) : .observed
        let onsetConfidence = onsetIndex.map { index in
            min(1, max(0, (features[index].levelDB - noiseFloor) / 30 + features[index].spectralFlux))
        } ?? 0
        let sustainLevel = sustainIndex.map { index in
            median(levels[index..<min(levels.count, index + stabilityCount)])
        }
        let boundaries = [
            AnalysisBoundaryEvidence(marker: .onset, seconds: onsetSeconds, confidence: onsetConfidence, state: onsetState, contributingFeatures: ["adaptive RMS", "spectral flux", "high-frequency content"], timeResolutionSeconds: hopSeconds),
            AnalysisBoundaryEvidence(marker: .sustainStart, seconds: sustainSeconds, confidence: sustainIndex == nil ? 0 : 0.8, state: sustainIndex == nil ? .unresolved : .observed, contributingFeatures: ["level stability", "minimum duration"], timeResolutionSeconds: hopSeconds),
            AnalysisBoundaryEvidence(marker: .keyUp, state: .unresolved, contributingFeatures: ["operator marker not supplied to offline detector"]),
            AnalysisBoundaryEvidence(marker: .soundOffset, seconds: offsetSeconds, confidence: offsetIndex == nil ? 0 : 0.75, state: offsetState, contributingFeatures: ["adaptive sustain threshold", "hysteresis"], timeResolutionSeconds: hopSeconds),
            AnalysisBoundaryEvidence(marker: .tailEnd, seconds: tailSeconds, confidence: tailIndex == nil ? 0 : 0.7, state: tailState, contributingFeatures: ["adaptive noise floor", "tail persistence"], timeResolutionSeconds: hopSeconds),
        ]
        return TransientResult(
            onset: onsetSeconds,
            sustainStart: sustainSeconds,
            soundOffset: offsetSeconds,
            tailEnd: tailSeconds,
            noiseFloorDB: noiseFloor,
            sustainLevelDB: sustainLevel,
            boundaries: boundaries
        )
    }

    private static func segment(_ samples: [Float], rate: Double, start: Double, end: Double) -> [Float] {
        let lower = max(0, min(samples.count, Int(start * rate)))
        let upper = max(lower, min(samples.count, Int(end * rate)))
        return Array(samples[lower..<upper])
    }

    private static func spectrogram(
        samples: [Float],
        sampleRate: Double,
        configuration requested: SpectrogramConfiguration,
        fundamentalFrequency: Double?,
        transient: TransientResult
    ) -> SpectrogramData {
        var configuration = requested
        configuration.fftSize = [1_024, 2_048, 4_096, 8_192, 16_384, 32_768]
            .min(by: { abs($0 - requested.fftSize) < abs($1 - requested.fftSize) }) ?? 8_192
        configuration.hopSize = max(32, min(configuration.fftSize, requested.hopSize))
        configuration.minimumFrequencyHz = max(0, requested.minimumFrequencyHz)
        configuration.maximumFrequencyHz = min(sampleRate / 2, max(configuration.minimumFrequencyHz + 1, requested.maximumFrequencyHz))
        configuration.maximumTimeBins = max(10, min(10_000, requested.maximumTimeBins))
        configuration.displayFrequencyBins = max(64, min(2_048, requested.displayFrequencyBins))

        let fftSize = configuration.fftSize
        guard samples.count >= fftSize else {
            return SpectrogramData(
                magnitudes: [],
                timeBins: 0,
                frequencyBins: 0,
                maximumFrequency: configuration.maximumFrequencyHz,
                configuration: configuration
            )
        }
        let log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return SpectrogramData(magnitudes: [], timeBins: 0, frequencyBins: 0, maximumFrequency: configuration.maximumFrequencyHz, configuration: configuration)
        }
        defer { vDSP_destroy_fftsetup(setup) }
        let window = spectralWindow(configuration.window, size: fftSize)
        let availableFrames = max(1, 1 + (samples.count - fftSize) / configuration.hopSize)
        // Extraction has its own fixed budget. Display controls must not change
        // the partial evidence or the inferred phase boundaries.
        let frameDecimation = max(1, Int(ceil(Double(availableFrames) / Double(SpectrumSegmentation.maximumPartialFrames))))
        let hop = configuration.hopSize * frameDecimation
        let binWidth = sampleRate / Double(fftSize)
        let lowerBin = max(0, min(fftSize / 2 - 1, Int(floor(configuration.minimumFrequencyHz / binWidth))))
        let upperBin = max(lowerBin + 1, min(fftSize / 2 - 1, Int(ceil(configuration.maximumFrequencyHz / binWidth))))
        let displayFrequencies = displayFrequencyAxis(configuration: configuration)

        var spectra: [[Float]] = []
        var offset = 0
        while offset + fftSize <= samples.count && spectra.count < SpectrumSegmentation.maximumPartialFrames {
            var frame = Array(samples[offset..<(offset + fftSize)])
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(fftSize))
            var real = [Float](repeating: 0, count: fftSize / 2)
            var imag = [Float](repeating: 0, count: fftSize / 2)
            frame.withUnsafeBytes { raw in
                raw.bindMemory(to: DSPComplex.self).withMemoryRebound(to: DSPComplex.self) { complex in
                    real.withUnsafeMutableBufferPointer { realPointer in
                        imag.withUnsafeMutableBufferPointer { imagPointer in
                            var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                            vDSP_ctoz(complex.baseAddress!, 2, &split, 1, vDSP_Length(fftSize / 2))
                            vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                        }
                    }
                }
            }
            var magnitude = [Float](repeating: 0, count: fftSize / 2)
            real.withUnsafeMutableBufferPointer { realPointer in
                imag.withUnsafeMutableBufferPointer { imagPointer in
                    var split = DSPSplitComplex(realp: realPointer.baseAddress!, imagp: imagPointer.baseAddress!)
                    vDSP_zvabs(&split, 1, &magnitude, 1, vDSP_Length(magnitude.count))
                }
            }
            let db = magnitude.map { 20 * log10(max($0, 0.000_000_1)) }
            spectra.append(db)
            offset += hop
        }
        let globalPeak = spectra.flatMap { $0[lowerBin...upperBin] }.max() ?? 0
        let floor = globalPeak - Float(max(20, configuration.dynamicRangeDB))
        let displayStride = max(1, Int(ceil(Double(spectra.count) / Double(configuration.maximumTimeBins))))
        let output = stride(from: 0, to: spectra.count, by: displayStride).map { index in
            let spectrum = spectra[index]
            return displayFrequencies.map { frequency -> Float in
                let center = max(lowerBin, min(upperBin, Int((frequency / binWidth).rounded())))
                let radius = max(1, Int(ceil(Double(upperBin - lowerBin) / Double(configuration.displayFrequencyBins) / 2)))
                let start = max(lowerBin, center - radius)
                let end = min(upperBin, center + radius)
                return max(floor, (spectrum[start...end].max() ?? floor)) - globalPeak
            }
        }
        let partials = fundamentalFrequency.map {
            trackPartials(
                spectra: spectra,
                sampleRate: sampleRate,
                fftSize: fftSize,
                hopSize: hop,
                fundamental: $0,
                configuration: configuration,
                transient: transient
            )
        } ?? []
        return SpectrogramData(
            magnitudes: output,
            timeBins: output.count,
            frequencyBins: displayFrequencies.count,
            maximumFrequency: configuration.maximumFrequencyHz,
            timeStepSeconds: Double(hop * displayStride) / sampleRate,
            frequencyAxisHz: displayFrequencies,
            configuration: configuration,
            partialTracks: partials
        )
    }

    private static func displayFrequencyAxis(configuration: SpectrogramConfiguration) -> [Double] {
        let count = configuration.displayFrequencyBins
        switch configuration.frequencyScale {
        case .linear:
            return (0..<count).map {
                configuration.minimumFrequencyHz
                    + Double($0) / Double(max(1, count - 1))
                    * (configuration.maximumFrequencyHz - configuration.minimumFrequencyHz)
            }
        case .logarithmic:
            let minimum = max(1, configuration.minimumFrequencyHz)
            let ratio = configuration.maximumFrequencyHz / minimum
            return (0..<count).map { minimum * pow(ratio, Double($0) / Double(max(1, count - 1))) }
        }
    }

    private static func spectralWindow(_ type: SpectralWindow, size: Int) -> [Float] {
        var values = [Float](repeating: 0, count: size)
        switch type {
        case .hann:
            vDSP_hann_window(&values, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        case .hamming:
            for index in values.indices {
                values[index] = Float(0.54 - 0.46 * cos(2 * Double.pi * Double(index) / Double(max(1, size - 1))))
            }
        case .blackmanHarris:
            for index in values.indices {
                let phase = 2 * Double.pi * Double(index) / Double(max(1, size - 1))
                values[index] = Float(0.35875 - 0.48829 * cos(phase) + 0.14128 * cos(2 * phase) - 0.01168 * cos(3 * phase))
            }
        }
        return values
    }

    private static func trackPartials(
        spectra: [[Float]],
        sampleRate: Double,
        fftSize: Int,
        hopSize: Int,
        fundamental: Double,
        configuration: SpectrogramConfiguration,
        transient: TransientResult
    ) -> [PartialTrack] {
        guard fundamental.isFinite, fundamental > 0, !spectra.isEmpty, configuration.partialCount > 0 else { return [] }
        let binWidth = sampleRate / Double(fftSize)
        return (1...max(1, configuration.partialCount)).compactMap { harmonic in
            let expected = fundamental * Double(harmonic)
            guard expected >= configuration.minimumFrequencyHz, expected <= configuration.maximumFrequencyHz else { return nil }
            let ratio = pow(2, configuration.partialSearchCents / 1200)
            guard let region = SpectrumSegmentation.harmonicBins(
                harmonic: harmonic, fundamental: fundamental, binWidth: binWidth,
                toleranceHz: max(binWidth * 1.5, expected * (ratio - 1)),
                lowerBin: 1, upperBin: fftSize / 2 - 2
            ) else { return nil }
            let lower = region.lowerBound, upper = region.upperBound
            let noiseRegion = SpectrumSegmentation.harmonicBins(
                harmonic: harmonic, fundamental: fundamental, binWidth: binWidth,
                toleranceHz: fundamental / 2, lowerBin: 1, upperBin: fftSize / 2 - 2
            ) ?? region
            let mainLobeRadius = configuration.window == .blackmanHarris ? 4 : 2
            var points: [PartialTrackPoint] = []
            for (frameIndex, spectrum) in spectra.enumerated() {
                guard let bin = (lower...upper).max(by: { spectrum[$0] < spectrum[$1] }) else { continue }
                let left = Double(spectrum[bin - 1])
                let center = Double(spectrum[bin])
                let right = Double(spectrum[bin + 1])
                let denominator = left - 2 * center + right
                let correction = denominator == 0 ? 0 : max(-0.5, min(0.5, 0.5 * (left - right) / denominator))
                let sidebands = noiseRegion.filter { abs($0 - bin) > mainLobeRadius }.map { Double(spectrum[$0]) }
                let localNoise = quantile(sidebands.isEmpty ? Array(spectrum[region]).map(Double.init) : sidebands, probability: 0.5)
                let localSNR = center - localNoise
                points.append(PartialTrackPoint(
                    timeSeconds: Double(frameIndex * hopSize) / sampleRate,
                    frequencyHz: (Double(bin) + correction) * binWidth,
                    amplitudeDB: center,
                    localSignalToNoiseDB: localSNR,
                    isValid: localSNR >= 5
                ))
            }
            guard let peak = points.map(\.amplitudeDB).max() else { return nil }
            let quiet = points.filter { point in
                let windowEnd = point.timeSeconds + Double(fftSize) / sampleRate
                return transient.onset.map { windowEnd <= $0 } == true
                    || transient.tailEnd.map { point.timeSeconds >= $0 } == true
            }.map(\.amplitudeDB)
            let noiseFloor = quiet.count >= 3 ? quantile(quiet, probability: 0.5) : nil
            if let noiseFloor {
                for index in points.indices {
                    points[index].isValid = points[index].isValid == true && points[index].amplitudeDB >= noiseFloor + 5
                }
            }
            let onsetThreshold = peak - configuration.partialOnsetBelowPeakDB
            let offsetThreshold = peak - configuration.partialOffsetBelowPeakDB
            let persistence = max(1, configuration.partialPersistenceFrames)
            let onsetIndex = persistentIndex(points: points, threshold: onsetThreshold, count: persistence, forward: true)
            let offsetIndex = persistentIndex(points: points, threshold: offsetThreshold, count: persistence, forward: false)
            let audible = points.filter { $0.isValid == true && $0.amplitudeDB >= offsetThreshold }
            let frequencies = audible.map(\.frequencyHz)
            let medianFrequency = frequencies.isEmpty ? nil : median(frequencies)
            let frequencyMAD = medianFrequency.map { center in median(frequencies.map { abs($0 - center) }) }
            let validRatio = Double(points.filter { $0.isValid == true }.count) / Double(max(1, points.count))
            let medianSNR = median(points.compactMap(\.localSignalToNoiseDB))
            let decayPoints: [(Double, Double)]
            if let soundOffset = transient.soundOffset {
                decayPoints = points.filter { $0.timeSeconds >= soundOffset && $0.isValid == true }.map { ($0.timeSeconds, $0.amplitudeDB) }
            } else {
                decayPoints = []
            }
            return PartialTrack(
                harmonicNumber: harmonic,
                expectedFrequencyHz: expected,
                medianFrequencyHz: medianFrequency,
                medianOffsetCents: medianFrequency.flatMap { centsDifference(measured: $0, expected: expected) },
                peakDB: peak,
                onsetSeconds: onsetIndex.map { points[$0].timeSeconds },
                offsetSeconds: offsetIndex.map { points[$0].timeSeconds },
                points: points,
                noiseFloorDB: noiseFloor,
                signalToNoiseDB: medianSNR,
                validPointRatio: validRatio,
                frequencyMADHz: frequencyMAD,
                decayRateDBPerSecond: linearSlope(decayPoints),
                confidence: min(1, validRatio * min(1, max(0, medianSNR / 20)))
            )
        }
    }

    private static func persistentIndex(
        points: [PartialTrackPoint],
        threshold: Double,
        count: Int,
        forward: Bool
    ) -> Int? {
        guard points.count >= count else { return nil }
        if forward {
            for index in 0...(points.count - count) {
                if points[index..<(index + count)].allSatisfy({ $0.isValid == true && $0.amplitudeDB >= threshold }) { return index }
            }
        } else {
            for index in stride(from: points.count - count, through: 0, by: -1) {
                if points[index..<(index + count)].allSatisfy({ $0.isValid == true && $0.amplitudeDB >= threshold }) { return index + count - 1 }
            }
        }
        return nil
    }

    private static func summarizePitchTrack(
        _ track: [PitchTrackPoint],
        expectedFrequency: Double?
    ) -> PitchTrackSummary? {
        guard track.isEmpty == false else { return nil }
        let voiced = track.filter { $0.voiced && ($0.frequencyHz?.isFinite == true) }
        guard voiced.isEmpty == false else {
            return PitchTrackSummary(frameCount: track.count, voicedFrameCount: 0, voicedRatio: 0)
        }
        let frequencies = voiced.compactMap(\.frequencyHz)
        let center = median(frequencies)
        let cents = frequencies.compactMap { centsDifference(measured: $0, expected: center) }
        let sortedCents = cents.sorted()
        let q25 = quantile(sortedCents, probability: 0.25)
        let q75 = quantile(sortedCents, probability: 0.75)
        let mad = median(cents.map(abs))
        let timedCents = voiced.compactMap { point -> (Double, Double)? in
            guard let frequency = point.frequencyHz,
                  let value = centsDifference(measured: frequency, expected: center) else { return nil }
            return (point.timeSeconds, value)
        }
        let drift = linearSlope(timedCents)
        let detrended = timedCents.map { time, value in value - (drift ?? 0) * time }
        let modulationDepth = detrended.isEmpty ? nil
            : (quantile(detrended, probability: 0.95) - quantile(detrended, probability: 0.05)) / 2
        let modulationRate = modulationRateHz(values: detrended, times: timedCents.map { $0.0 })
        let octaveErrors = track.reduce(into: 0) { count, point in
            let distance = point.centsFromExpected ?? point.frequencyHz.flatMap {
                centsDifference(measured: $0, expected: expectedFrequency ?? center)
            }
            if let distance, abs(distance) >= 600 { count += 1 }
        }
        return PitchTrackSummary(
            frameCount: track.count,
            voicedFrameCount: voiced.count,
            voicedRatio: Double(voiced.count) / Double(track.count),
            medianFrequencyHz: center,
            medianConfidence: median(voiced.map(\.confidence)),
            interquartileRangeCents: q75 - q25,
            medianAbsoluteDeviationCents: mad,
            driftCentsPerSecond: drift,
            modulationRateHz: modulationRate,
            modulationDepthCents: modulationDepth,
            lowerUncertaintyCents: quantile(sortedCents, probability: 0.025),
            upperUncertaintyCents: quantile(sortedCents, probability: 0.975),
            suspectedOctaveErrorCount: octaveErrors
        )
    }

    private static func summarizePartials(_ tracks: [PartialTrack]) -> PipeSpectralSummary {
        let detected = tracks.filter { ($0.confidence ?? 0) >= 0.2 && $0.medianFrequencyHz != nil }
        guard detected.isEmpty == false else { return PipeSpectralSummary(detectedPartialCount: 0) }
        let maximumPeak = detected.compactMap(\.peakDB).max() ?? 0
        let weighted = detected.compactMap { track -> (frequency: Double, energy: Double, harmonic: Int, offset: Double?)? in
            guard let frequency = track.medianFrequencyHz, let peak = track.peakDB else { return nil }
            return (frequency, pow(10, (peak - maximumPeak) / 10), track.harmonicNumber, track.medianOffsetCents)
        }
        let totalEnergy = weighted.map { $0.energy }.reduce(0, +)
        let centroid = totalEnergy > 0 ? weighted.reduce(0) { $0 + $1.frequency * $1.energy } / totalEnergy : nil
        var cumulative = 0.0
        var rolloff: Double?
        for point in weighted.sorted(by: { $0.frequency < $1.frequency }) {
            cumulative += point.energy
            if cumulative >= totalEnergy * 0.85 { rolloff = point.frequency; break }
        }
        let odd = weighted.filter { !$0.harmonic.isMultiple(of: 2) }.map { $0.energy }.reduce(0, +)
        let even = weighted.filter { $0.harmonic.isMultiple(of: 2) }.map { $0.energy }.reduce(0, +)
        let oddEven = 10 * log10(max(odd, 1e-12) / max(even, 1e-12))
        let inharmonicityNumerator = weighted.reduce(0) { $0 + abs($1.offset ?? 0) * $1.energy }
        let onsets = detected.compactMap(\.onsetSeconds)
        let attackSpread = onsets.isEmpty ? nil : (onsets.max() ?? 0) - (onsets.min() ?? 0)
        let decayRates = detected.compactMap(\.decayRateDBPerSecond).filter { $0.isFinite }
        return PipeSpectralSummary(
            detectedPartialCount: detected.count,
            spectralCentroidHz: centroid,
            spectralRolloff85Hz: rolloff,
            oddEvenEnergyRatioDB: oddEven,
            weightedInharmonicityCents: totalEnergy > 0 ? inharmonicityNumerator / totalEnergy : nil,
            partialAttackSpreadSeconds: attackSpread,
            medianDecayRateDBPerSecond: decayRates.isEmpty ? nil : median(decayRates)
        )
    }

    private static func modulationRateHz(values: [Double], times: [Double]) -> Double? {
        guard values.count >= 20, values.count == times.count,
              let first = times.first, let last = times.last, last > first else { return nil }
        let step = (last - first) / Double(values.count - 1)
        guard step > 0 else { return nil }
        let minimumLag = max(1, Int(0.15 / step))
        let maximumLag = min(values.count / 2, Int(2.0 / step))
        guard minimumLag < maximumLag else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let centered = values.map { $0 - mean }
        var best: (lag: Int, correlation: Double)?
        for lag in minimumLag...maximumLag {
            var numerator = 0.0
            var left = 0.0
            var right = 0.0
            for index in 0..<(centered.count - lag) {
                numerator += centered[index] * centered[index + lag]
                left += centered[index] * centered[index]
                right += centered[index + lag] * centered[index + lag]
            }
            let correlation = numerator / sqrt(max(1e-12, left * right))
            if correlation > 0.2, best == nil || correlation > best!.correlation { best = (lag, correlation) }
        }
        return best.map { 1 / (Double($0.lag) * step) }
    }

    private static func linearSlope(_ values: [(Double, Double)]) -> Double? {
        guard values.count >= 3 else { return nil }
        let meanX = values.map { $0.0 }.reduce(0, +) / Double(values.count)
        let meanY = values.map { $0.1 }.reduce(0, +) / Double(values.count)
        let numerator = values.reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let denominator = values.reduce(0) { $0 + ($1.0 - meanX) * ($1.0 - meanX) }
        return denominator > 1e-12 ? numerator / denominator : nil
    }

    private static func signalToNoiseDB(features: [TransientFeatureFrame], transient: TransientResult) -> Double? {
        guard features.isEmpty == false else { return nil }
        let peak = features.map(\.levelDB).max() ?? transient.noiseFloorDB
        guard peak - transient.noiseFloorDB >= 6 else { return nil }
        let signal = transient.sustainLevelDB ?? quantile(features.map(\.levelDB), probability: 0.75)
        let value = signal - transient.noiseFloorDB
        return value.isFinite ? max(0, value) : nil
    }

    private static func bestCorrelation(
        reference: [Float],
        candidate: [Float],
        maximumLag: Int
    ) -> (value: Double, lag: Int)? {
        let count = min(reference.count, candidate.count)
        guard count > maximumLag * 2 + 32 else { return nil }
        let stride = max(1, count / 32_768)
        var best: (value: Double, lag: Int)?
        for lag in (-maximumLag)...maximumLag {
            let referenceStart = max(0, -lag)
            let candidateStart = max(0, lag)
            let usable = count - max(referenceStart, candidateStart)
            var xy = 0.0
            var xx = 0.0
            var yy = 0.0
            var index = 0
            while index < usable {
                let x = Double(reference[referenceStart + index])
                let y = Double(candidate[candidateStart + index])
                xy += x * y
                xx += x * x
                yy += y * y
                index += stride
            }
            let value = xy / sqrt(max(1e-20, xx * yy))
            if best == nil || abs(value) > abs(best!.value) { best = (value, lag) }
        }
        return best
    }

    private static func analysisParameters(configuration: SpectrogramConfiguration) -> [String: String] {
        [
            "fftSize": String(configuration.fftSize),
            "hopSize": String(configuration.hopSize),
            "window": configuration.window.rawValue,
            "frequencyScale": configuration.frequencyScale.rawValue,
            "frequencyRangeHz": "\(configuration.minimumFrequencyHz)...\(configuration.maximumFrequencyHz)",
            "dynamicRangeDB": String(configuration.dynamicRangeDB),
            "partialCount": String(configuration.partialCount),
            "partialSearchCents": String(configuration.partialSearchCents),
            "maximumDurationSeconds": String(configuration.maximumAnalysisDurationSeconds),
            "transientDetector": "adaptive-multifeature/3",
            "spectrumSegmentation": SpectrumSegmentation.version,
            "partialAnalysisFrameLimit": String(SpectrumSegmentation.maximumPartialFrames),
            "partialOnsetBelowPeakDB": String(configuration.partialOnsetBelowPeakDB),
            "partialOffsetBelowPeakDB": String(configuration.partialOffsetBelowPeakDB),
            "partialPersistenceFrames": String(configuration.partialPersistenceFrames),
            "pitchDecoder": "CREPE+pYIN-consensus/3",
            "pyinThresholdPrior": "beta(alpha=2,beta=18); 100 thresholds",
            "pyinCandidateLimit": "5 per frame",
            "pyinTemporalDecoder": "voiced/unvoiced Viterbi; 700-cent hard-jump penalty",
            "pitchMismatchMaterialCents": "25",
            "pitchMismatchCriticalCents": "50 at both confidences >= 0.55",
            "perceptualSpectrum": "Hann-STFT+ERB32+disjoint-harmonic-tristimulus/2",
            "modulationAnalysis": "detrended-sinusoidal-scan/1; 0.2...20 Hz",
            "releaseDecay": "noise-truncated-Schroeder+deltaBIC-multislope/1; descriptive-not-RT60",
        ]
    }

    private static func downsample(_ samples: [Float], count: Int) -> [Float] {
        guard samples.count > count else { return samples }
        let stride = Double(samples.count) / Double(count)
        return (0..<count).map { index in
            let lower = Int(Double(index) * stride)
            let upper = max(lower + 1, min(samples.count, Int(Double(index + 1) * stride)))
            return samples[lower..<upper].max(by: { abs($0) < abs($1) }) ?? 0
        }
    }

    private static func decibels(_ value: Double) -> Double {
        20 * log10(max(value, 0.000_001))
    }
}

private func normalize(_ samples: [Float]) -> [Float] {
    var mean: Float = 0
    var standardDeviation: Float = 0
    vDSP_normalize(samples, 1, nil, 1, &mean, &standardDeviation, vDSP_Length(samples.count))
    guard standardDeviation > 0 else { return samples }
    return samples.map { ($0 - mean) / standardDeviation }
}

private func resample(_ samples: [Float], from inputRate: Double, to outputRate: Double) -> [Float] {
    guard !samples.isEmpty, inputRate != outputRate else { return samples }
    let outputCount = max(1, Int(Double(samples.count) * outputRate / inputRate))
    if let inputFormat = AVAudioFormat(standardFormatWithSampleRate: inputRate, channels: 1),
       let outputFormat = AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 1),
       let converter = AVAudioConverter(from: inputFormat, to: outputFormat),
       let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(samples.count)),
       let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(max(samples.count, outputCount + 32))),
       let inputChannel = inputBuffer.floatChannelData?[0] {
        inputBuffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { pointer in
            if let base = pointer.baseAddress { inputChannel.update(from: base, count: samples.count) }
        }
        let converted: Void? = try? converter.convert(to: outputBuffer, from: inputBuffer)
        if converted != nil,
           let outputChannel = outputBuffer.floatChannelData?[0],
           outputBuffer.frameLength > 0 {
            return Array(UnsafeBufferPointer(start: outputChannel, count: Int(outputBuffer.frameLength)))
        }
    }
    // Defensive fallback for unusual formats. CREPE's confidence will normally
    // reject aliased frames, but production paths use AVAudioConverter above.
    let ratio = inputRate / outputRate
    return (0..<outputCount).map { index in
        let position = Double(index) * ratio
        let lower = min(samples.count - 1, Int(position))
        let upper = min(samples.count - 1, lower + 1)
        let fraction = Float(position - Double(lower))
        return samples[lower] * (1 - fraction) + samples[upper] * fraction
    }
}

private func median<S: Sequence>(_ values: S) -> Double where S.Element == Double {
    let sorted = values.sorted()
    guard !sorted.isEmpty else { return 0 }
    if sorted.count.isMultiple(of: 2) { return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2 }
    return sorted[sorted.count / 2]
}

private func quantile(_ values: [Double], probability: Double) -> Double {
    guard values.isEmpty == false else { return 0 }
    let sorted = values.sorted()
    let position = min(1, max(0, probability)) * Double(sorted.count - 1)
    let lower = Int(floor(position))
    let upper = Int(ceil(position))
    guard lower != upper else { return sorted[lower] }
    let fraction = position - Double(lower)
    return sorted[lower] * (1 - fraction) + sorted[upper] * fraction
}
