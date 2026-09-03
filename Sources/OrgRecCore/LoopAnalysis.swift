import Accelerate
import AVFAudio
import Foundation

public struct LoopDetectionConfiguration: Codable, Hashable, Sendable {
    public var candidateCount: Int
    public var minimumLoopSeconds: Double
    public var maximumLoopSeconds: Double
    public var sustainSafetyMarginSeconds: Double
    public var comparisonWindowSeconds: Double
    public var crossfadeSeconds: Double
    public var maximumSearchSeconds: Double

    public init(
        candidateCount: Int = 5,
        minimumLoopSeconds: Double = 0.35,
        maximumLoopSeconds: Double = 3,
        sustainSafetyMarginSeconds: Double = 0.12,
        comparisonWindowSeconds: Double = 0.025,
        crossfadeSeconds: Double = 0.03,
        maximumSearchSeconds: Double = 12
    ) {
        self.candidateCount = candidateCount
        self.minimumLoopSeconds = minimumLoopSeconds
        self.maximumLoopSeconds = maximumLoopSeconds
        self.sustainSafetyMarginSeconds = sustainSafetyMarginSeconds
        self.comparisonWindowSeconds = comparisonWindowSeconds
        self.crossfadeSeconds = crossfadeSeconds
        self.maximumSearchSeconds = maximumSearchSeconds
    }
}

public struct LoopDetectionResult: Codable, Hashable, Sendable {
    public var loopability: LoopabilityClass
    public var candidates: [LoopPointSet]
    public var eligibleStartFrame: Int64?
    public var eligibleEndFrameExclusive: Int64?
    public var sustainStationarity: Double?
    public var amplitudeModulationRateHz: Double?
    public var amplitudeModulationDepthDB: Double?
    public var qualityFlags: [String]
}

public enum LoopPointSetValidator {
    public static func errors(for set: LoopPointSet) -> [String] {
        var errors: [String] = []
        if set.sourceAudioSHA256.count != 64 || !set.sourceAudioSHA256.allSatisfy({ $0.isHexDigit }) {
            errors.append("The source audio SHA-256 is invalid.")
        }
        if !set.sampleRate.isFinite || set.sampleRate <= 0 { errors.append("The loop sample rate must be positive.") }
        if set.channelCount <= 0 { errors.append("The loop channel count must be positive.") }
        if set.totalFrames <= 0 { errors.append("The source frame count must be positive.") }
        if !(0...1).contains(set.confidence) { errors.append("Loop confidence must be between zero and one.") }
        if set.regions.isEmpty { errors.append("A loop point set must contain at least one region.") }
        for region in set.regions {
            if region.startFrameInclusive < 0 || region.endFrameExclusive > set.totalFrames {
                errors.append("Loop region \(region.id) lies outside the source asset.")
            }
            if region.endFrameExclusive <= region.startFrameInclusive {
                errors.append("Loop region \(region.id) has an empty or inverted interval.")
            }
            if region.crossfadeFrames < 0 || region.crossfadeFrames * 2 >= region.frameCount {
                errors.append("Loop region \(region.id) has an invalid crossfade length.")
            }
            if let release = region.releaseStartFrame, !(0..<set.totalFrames).contains(release) {
                errors.append("Loop region \(region.id) has an invalid release start frame.")
            }
            if region.exitPolicy != .envelopeRelease && region.releaseStartFrame == nil {
                errors.append("Loop region \(region.id) requires a recorded release start for its exit policy.")
            }
            if let count = region.repeatCount, count < 1 {
                errors.append("Loop region \(region.id) repeat count must be positive or absent for indefinite sustain.")
            }
        }
        let sustainCount = set.regions.filter { $0.role == .sustain }.count
        if sustainCount != 1 { errors.append("A playable loop point set must contain exactly one sustain region.") }
        if set.status == .accepted {
            if set.reviewedAt == nil { errors.append("An accepted loop point set requires a review time.") }
            if set.reviewedBy?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                errors.append("An accepted loop point set requires a reviewer.")
            }
            if set.reviewReason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                errors.append("An accepted loop point set requires a review reason.")
            }
        }
        let envelope = set.envelope
        if !envelope.attackSeconds.isFinite || envelope.attackSeconds < 0 || envelope.attackSeconds > 10 {
            errors.append("Envelope attack must be between zero and ten seconds.")
        }
        if !envelope.releaseSeconds.isFinite || envelope.releaseSeconds <= 0 || envelope.releaseSeconds > 30 {
            errors.append("Envelope release must be greater than zero and no more than thirty seconds.")
        }
        if !envelope.sustainLevel.isFinite || !(0...1).contains(envelope.sustainLevel) {
            errors.append("Envelope sustain level must be between zero and one.")
        }
        return errors
    }
}

/// Pure DSP used by the real-time audition path and unit tests. The returned
/// forward cycle begins with an equal-power tail/head overlap and omits the
/// duplicated head/crossfade frames, so repeated scheduling has length
/// `sourceLength - crossfadeFrames`.
public enum SustainLoopRenderer {
    public static func renderForwardCycle(
        channels: [[Float]],
        crossfadeFrames: Int
    ) throws -> [[Float]] {
        guard let frameCount = channels.first?.count, frameCount > 1,
              channels.allSatisfy({ $0.count == frameCount }) else {
            throw OrgRecError.unsupportedAudio("Sustain-loop rendering requires equally sized, non-empty channels.")
        }
        let crossfade = max(0, crossfadeFrames)
        guard crossfade * 2 < frameCount else {
            throw OrgRecError.unsupportedAudio("The loop crossfade must be shorter than half the region.")
        }
        return channels.map { channel in
            var result: [Float] = []
            result.reserveCapacity(frameCount - crossfade)
            if crossfade > 0 {
                for index in 0..<crossfade {
                    let progress = (Double(index) + 0.5) / Double(crossfade)
                    let tailGain = Float(cos(progress * .pi / 2))
                    let headGain = Float(sin(progress * .pi / 2))
                    result.append(channel[frameCount - crossfade + index] * tailGain + channel[index] * headGain)
                }
            }
            if frameCount - crossfade > crossfade {
                result.append(contentsOf: channel[crossfade..<(frameCount - crossfade)])
            }
            return result
        }
    }
}

/// Finds reproducible loop candidates inside the measured sustain. Coarse
/// period-aligned proposals are refined at the sample clock and scored against
/// all channels. The detector never marks a candidate as accepted.
public enum LoopPointDetector {
    private struct AudioSlice {
        var channels: [[Float]]
        var sampleRate: Double
        var channelCount: Int
        var totalFrames: Int64
        var globalStartFrame: Int64
    }

    private struct ScoredPair {
        var start: Int
        var end: Int
        var score: LoopScoreBreakdown
    }

    public static func detect(
        fileURL: URL,
        analysis: AnalysisSummary,
        pitchTrack: [PitchTrackPoint] = [],
        sourceAudioSHA256: String? = nil,
        configuration: LoopDetectionConfiguration = LoopDetectionConfiguration()
    ) throws -> LoopDetectionResult {
        let file = try AVAudioFile(forReading: fileURL)
        let rate = file.processingFormat.sampleRate
        let totalFrames = file.length
        let duration = Double(totalFrames) / rate
        let margin = max(0, configuration.sustainSafetyMarginSeconds)
        let inferredStart = analysis.sustainStartSeconds ?? analysis.onsetSeconds.map { $0 + 0.2 } ?? 0
        let inferredEnd = analysis.keyUpSeconds ?? analysis.soundOffsetSeconds ?? duration
        var eligibleStart = max(0, inferredStart + margin)
        var eligibleEnd = min(duration, inferredEnd - margin)
        if eligibleEnd - eligibleStart > configuration.maximumSearchSeconds {
            let middle = (eligibleStart + eligibleEnd) / 2
            eligibleStart = max(eligibleStart, middle - configuration.maximumSearchSeconds / 2)
            eligibleEnd = min(eligibleEnd, eligibleStart + configuration.maximumSearchSeconds)
        }
        let minimumRequired = max(configuration.minimumLoopSeconds + 2 * configuration.comparisonWindowSeconds, 0.2)
        guard eligibleEnd - eligibleStart >= minimumRequired else {
            return LoopDetectionResult(
                loopability: .unsuitable,
                candidates: [],
                eligibleStartFrame: nil,
                eligibleEndFrameExclusive: nil,
                sustainStationarity: nil,
                amplitudeModulationRateHz: nil,
                amplitudeModulationDepthDB: nil,
                qualityFlags: ["Stable sustain is too short for defensible loop detection."]
            )
        }

        let startFrame = Int64((eligibleStart * rate).rounded(.up))
        let endFrame = min(totalFrames, Int64((eligibleEnd * rate).rounded(.down)))
        let audio = try read(file: file, startFrame: startFrame, endFrameExclusive: endFrame)
        guard let reference = audio.channels.first, reference.count > 256 else {
            return LoopDetectionResult(
                loopability: .unsuitable,
                candidates: [],
                eligibleStartFrame: startFrame,
                eligibleEndFrameExclusive: endFrame,
                sustainStationarity: nil,
                amplitudeModulationRateHz: nil,
                amplitudeModulationDepthDB: nil,
                qualityFlags: ["The eligible sustain contains too few readable PCM frames."]
            )
        }

        let dynamics = sustainDynamics(reference, sampleRate: rate)
        let loopability = classify(
            stationarity: dynamics.stationarity,
            modulationRate: dynamics.modulationRate,
            modulationDepth: dynamics.modulationDepth,
            pitchDrift: analysis.pitchTrackSummary?.driftCentsPerSecond
        )
        let fundamental = analysis.frequencyHz ?? analysis.pitchTrackSummary?.medianFrequencyHz
        let periodFrames = fundamental.flatMap { $0 > 0 ? max(2, Int((rate / $0).rounded())) : nil }
        let window = max(32, min(reference.count / 8, Int(configuration.comparisonWindowSeconds * rate)))
        let minimumLoop = max(window * 3, Int(configuration.minimumLoopSeconds * rate))
        let maximumLoop = min(reference.count - window * 2, Int(configuration.maximumLoopSeconds * rate))
        guard maximumLoop >= minimumLoop else {
            return LoopDetectionResult(
                loopability: .unsuitable,
                candidates: [],
                eligibleStartFrame: startFrame,
                eligibleEndFrameExclusive: endFrame,
                sustainStationarity: dynamics.stationarity,
                amplitudeModulationRateHz: dynamics.modulationRate,
                amplitudeModulationDepthDB: dynamics.modulationDepth,
                qualityFlags: ["The stable sustain cannot accommodate the configured comparison and loop lengths."]
            )
        }

        let lengths = candidateLengths(
            sampleRate: rate,
            minimum: minimumLoop,
            maximum: maximumLoop,
            periodFrames: periodFrames,
            modulationRate: dynamics.modulationRate
        )
        let hop = max(periodFrames ?? 1, Int(rate * 0.018))
        var coarse: [ScoredPair] = []
        for length in lengths {
            var start = window
            while start + length + window < reference.count {
                let end = start + length
                coarse.append(ScoredPair(
                    start: start,
                    end: end,
                    score: score(
                        channels: audio.channels,
                        start: start,
                        end: end,
                        window: window,
                        sampleRate: rate,
                        fundamental: fundamental,
                        pitchTrack: pitchTrack,
                        globalStartFrame: startFrame,
                        minimumLoopFrames: minimumLoop
                    )
                ))
                start += hop
            }
        }
        coarse.sort { $0.score.total < $1.score.total }

        var refined: [ScoredPair] = []
        for proposal in coarse.prefix(max(8, configuration.candidateCount * 3)) {
            let radius = max(4, (periodFrames ?? Int(rate * 0.01)) / 2)
            let step = max(1, radius / 12)
            var best = proposal
            var delta = -radius
            while delta <= radius {
                let start = proposal.start + delta
                if start >= window, start + window < proposal.end {
                    let candidate = ScoredPair(
                        start: start,
                        end: proposal.end,
                        score: score(
                            channels: audio.channels, start: start, end: proposal.end, window: window,
                            sampleRate: rate, fundamental: fundamental, pitchTrack: pitchTrack,
                            globalStartFrame: startFrame, minimumLoopFrames: minimumLoop
                        )
                    )
                    if candidate.score.total < best.score.total { best = candidate }
                }
                delta += step
            }
            delta = -radius
            while delta <= radius {
                let end = best.end + delta
                if end + window < reference.count, end - best.start >= minimumLoop {
                    let candidate = ScoredPair(
                        start: best.start,
                        end: end,
                        score: score(
                            channels: audio.channels, start: best.start, end: end, window: window,
                            sampleRate: rate, fundamental: fundamental, pitchTrack: pitchTrack,
                            globalStartFrame: startFrame, minimumLoopFrames: minimumLoop
                        )
                    )
                    if candidate.score.total < best.score.total { best = candidate }
                }
                delta += step
            }
            if !refined.contains(where: {
                abs($0.start - best.start) < max(8, periodFrames ?? 32)
                    && abs($0.end - best.end) < max(8, periodFrames ?? 32)
            }) {
                refined.append(best)
            }
        }
        refined.sort { $0.score.total < $1.score.total }

        let digest = try sourceAudioSHA256 ?? sha256(of: fileURL)
        let requestedCrossfade = Int64(max(0, configuration.crossfadeSeconds * rate))
        let releaseStart = analysis.keyUpSeconds.map { min(totalFrames - 1, max(0, Int64(($0 * rate).rounded()))) }
        let parameters = parameterRecord(configuration, periodFrames: periodFrames)
        let candidates = refined.prefix(max(1, configuration.candidateCount)).enumerated().map { index, pair in
            let globalStart = startFrame + Int64(pair.start)
            let globalEnd = startFrame + Int64(pair.end)
            let crossfade = min(requestedCrossfade, max(0, (globalEnd - globalStart) / 4))
            let confidence = max(0, min(1, exp(-2.2 * pair.score.total) * max(0.35, dynamics.stationarity ?? 0.5)))
            let flags = loopability == .drifting
                ? ["Sustain drift may remain audible across repeated cycles."]
                : (loopability == .modulated ? ["Candidate spans should be auditioned for complete modulation cycles."] : [])
            return LoopPointSet(
                sourceAudioSHA256: digest,
                sampleRate: rate,
                channelCount: audio.channelCount,
                totalFrames: totalFrames,
                loopability: loopability,
                regions: [AudioLoopRegion(
                    startFrameInclusive: globalStart,
                    endFrameExclusive: globalEnd,
                    crossfadeFrames: crossfade,
                    exitPolicy: releaseStart == nil ? .envelopeRelease : .crossfadeToRecordedRelease,
                    releaseStartFrame: releaseStart,
                    score: pair.score
                )],
                envelope: SustainPlaybackEnvelope(),
                candidateRank: index + 1,
                confidence: confidence,
                parameters: parameters,
                qualityFlags: flags
            )
        }
        var flags: [String] = []
        if candidates.isEmpty { flags.append("No loop candidate passed the configured duration and context gates.") }
        if loopability == .unsuitable { flags.append("The sustain is insufficiently stationary for automatic acceptance.") }
        return LoopDetectionResult(
            loopability: loopability,
            candidates: candidates,
            eligibleStartFrame: startFrame,
            eligibleEndFrameExclusive: endFrame,
            sustainStationarity: dynamics.stationarity,
            amplitudeModulationRateHz: dynamics.modulationRate,
            amplitudeModulationDepthDB: dynamics.modulationDepth,
            qualityFlags: flags
        )
    }

    private static func read(file: AVAudioFile, startFrame: Int64, endFrameExclusive: Int64) throws -> AudioSlice {
        let format = file.processingFormat
        let count = max(0, endFrameExclusive - startFrame)
        guard count > 0, count <= Int64(UInt32.max) else {
            throw OrgRecError.unsupportedAudio("The loop-analysis interval is empty or too large for an in-memory PCM buffer.")
        }
        file.framePosition = startFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else {
            throw OrgRecError.unsupportedAudio("Cannot allocate a loop-analysis PCM buffer.")
        }
        try file.read(into: buffer, frameCount: AVAudioFrameCount(count))
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else {
            throw OrgRecError.unsupportedAudio("Loop analysis requires readable floating-point PCM channels.")
        }
        let length = Int(buffer.frameLength)
        let channels = (0..<Int(format.channelCount)).map {
            Array(UnsafeBufferPointer(start: channelData[$0], count: length))
        }
        return AudioSlice(
            channels: channels,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            totalFrames: file.length,
            globalStartFrame: startFrame
        )
    }

    private static func candidateLengths(
        sampleRate: Double,
        minimum: Int,
        maximum: Int,
        periodFrames: Int?,
        modulationRate: Double?
    ) -> [Int] {
        var targets = [0.45, 0.7, 1, 1.5, 2.25, 3].map { Int($0 * sampleRate) }
        if let rate = modulationRate, rate > 0.1 {
            targets.append(Int(sampleRate / rate))
            targets.append(Int(2 * sampleRate / rate))
        }
        return Array(Set(targets.compactMap { raw -> Int? in
            let aligned: Int
            if let periodFrames {
                aligned = max(periodFrames, Int((Double(raw) / Double(periodFrames)).rounded()) * periodFrames)
            } else {
                aligned = raw
            }
            return (minimum...maximum).contains(aligned) ? aligned : nil
        })).sorted()
    }

    private static func score(
        channels: [[Float]],
        start: Int,
        end: Int,
        window: Int,
        sampleRate: Double,
        fundamental: Double?,
        pitchTrack: [PitchTrackPoint],
        globalStartFrame: Int64,
        minimumLoopFrames: Int
    ) -> LoopScoreBreakdown {
        var waveformValues: [Double] = []
        var derivativeValues: [Double] = []
        var levelValues: [Double] = []
        var spectralValues: [Double] = []
        var phaseValues: [Double] = []
        let half = window / 2
        for channel in channels {
            let leftStart = max(1, start - half)
            let rightStart = max(1, end - half)
            let usable = min(window, min(channel.count - leftStart, channel.count - rightStart))
            guard usable > 16 else { continue }
            let stride = max(1, usable / 512)
            var error = 0.0, derivativeError = 0.0, energy = 0.0, leftEnergy = 0.0, rightEnergy = 0.0
            var count = 0
            var offset = 0
            while offset < usable {
                let left = Double(channel[leftStart + offset])
                let right = Double(channel[rightStart + offset])
                let difference = left - right
                error += difference * difference
                energy += 0.5 * (left * left + right * right)
                leftEnergy += left * left
                rightEnergy += right * right
                if offset > 0 {
                    let leftDerivative = left - Double(channel[leftStart + offset - 1])
                    let rightDerivative = right - Double(channel[rightStart + offset - 1])
                    let delta = leftDerivative - rightDerivative
                    derivativeError += delta * delta
                }
                count += 1
                offset += stride
            }
            waveformValues.append(sqrt(error / Double(max(1, count))) / max(1e-7, sqrt(energy / Double(max(1, count)))))
            derivativeValues.append(sqrt(derivativeError / Double(max(1, count - 1))) / max(1e-7, sqrt(energy / Double(max(1, count)))))
            levelValues.append(min(2, abs(10 * log10(max(rightEnergy, 1e-12) / max(leftEnergy, 1e-12))) / 12))
            let spectral = harmonicDifference(
                channel: channel, leftStart: leftStart, rightStart: rightStart, count: usable,
                sampleRate: sampleRate, fundamental: fundamental
            )
            spectralValues.append(spectral.magnitude)
            phaseValues.append(spectral.phase)
        }
        let waveform = mean(waveformValues)
        let derivative = min(2, mean(derivativeValues))
        let level = mean(levelValues)
        let spectral = mean(spectralValues)
        let phase = mean(phaseValues)
        let channelMismatch = standardDeviation(waveformValues)
        let pitch = pitchMismatch(
            pitchTrack: pitchTrack,
            startSeconds: Double(globalStartFrame + Int64(start)) / sampleRate,
            endSeconds: Double(globalStartFrame + Int64(end)) / sampleRate,
            loopFrames: end - start,
            sampleRate: sampleRate,
            fundamental: fundamental
        )
        let stationarity = stationarityPenalty(channels.first ?? [], start: start, end: end)
        let repetition = max(0, 1 - Double(end - start) / Double(max(1, minimumLoopFrames * 2)))
        let total = 0.24 * waveform
            + 0.12 * derivative
            + 0.17 * spectral
            + 0.12 * phase
            + 0.08 * level
            + 0.08 * pitch
            + 0.10 * stationarity
            + 0.05 * channelMismatch
            + 0.04 * repetition
        return LoopScoreBreakdown(
            waveformMismatch: waveform,
            derivativeMismatch: derivative,
            spectralMismatch: spectral,
            partialPhaseMismatch: phase,
            levelMismatch: level,
            pitchMismatch: pitch,
            stationarityPenalty: stationarity,
            channelMismatch: channelMismatch,
            repetitionPenalty: repetition,
            total: total
        )
    }

    private static func harmonicDifference(
        channel: [Float], leftStart: Int, rightStart: Int, count: Int,
        sampleRate: Double, fundamental: Double?
    ) -> (magnitude: Double, phase: Double) {
        guard let fundamental, fundamental > 0 else { return (0.5, 0.5) }
        let harmonicCount = max(1, min(12, Int(sampleRate / 2 / fundamental)))
        var magnitudeDifference = 0.0
        var phaseDifference = 0.0
        var weightSum = 0.0
        let stride = max(1, count / 512)
        for harmonic in 1...harmonicCount {
            let frequency = fundamental * Double(harmonic)
            var leftReal = 0.0, leftImaginary = 0.0, rightReal = 0.0, rightImaginary = 0.0
            var samples = 0
            var offset = 0
            while offset < count {
                let window = 0.5 - 0.5 * cos(2 * .pi * Double(offset) / Double(max(1, count - 1)))
                let angle = 2 * Double.pi * frequency * Double(offset) / sampleRate
                let cosine = cos(angle), sine = sin(angle)
                let left = Double(channel[leftStart + offset]) * window
                let right = Double(channel[rightStart + offset]) * window
                leftReal += left * cosine; leftImaginary -= left * sine
                rightReal += right * cosine; rightImaginary -= right * sine
                samples += 1
                offset += stride
            }
            guard samples > 0 else { continue }
            let leftMagnitude = hypot(leftReal, leftImaginary)
            let rightMagnitude = hypot(rightReal, rightImaginary)
            let weight = max(leftMagnitude, rightMagnitude)
            guard weight > 1e-8 else { continue }
            magnitudeDifference += weight * abs(leftMagnitude - rightMagnitude) / max(weight, 1e-8)
            let phaseDelta = atan2(sin(atan2(rightImaginary, rightReal) - atan2(leftImaginary, leftReal)),
                                   cos(atan2(rightImaginary, rightReal) - atan2(leftImaginary, leftReal)))
            phaseDifference += weight * abs(phaseDelta) / Double.pi
            weightSum += weight
        }
        guard weightSum > 0 else { return (0.5, 0.5) }
        return (magnitudeDifference / weightSum, phaseDifference / weightSum)
    }

    private static func pitchMismatch(
        pitchTrack: [PitchTrackPoint], startSeconds: Double, endSeconds: Double,
        loopFrames: Int, sampleRate: Double, fundamental: Double?
    ) -> Double {
        func nearest(_ time: Double) -> Double? {
            pitchTrack.filter { $0.voiced && $0.frequencyHz != nil }.min {
                abs($0.timeSeconds - time) < abs($1.timeSeconds - time)
            }?.frequencyHz
        }
        var penalty = 0.0
        if let left = nearest(startSeconds), let right = nearest(endSeconds), left > 0, right > 0 {
            penalty += min(2, abs(1_200 * log2(right / left)) / 50)
        }
        if let fundamental, fundamental > 0 {
            let cycles = Double(loopFrames) * fundamental / sampleRate
            penalty += min(1, abs(cycles - cycles.rounded()) * 2)
        }
        return min(2, penalty)
    }

    private static func stationarityPenalty(_ samples: [Float], start: Int, end: Int) -> Double {
        guard end - start >= 64 else { return 1 }
        let block = max(16, (end - start) / 12)
        var rms: [Double] = []
        var position = start
        while position + block <= end {
            var value: Float = 0
            samples.withUnsafeBufferPointer { pointer in
                if let base = pointer.baseAddress {
                    vDSP_rmsqv(base.advanced(by: position), 1, &value, vDSP_Length(block))
                }
            }
            rms.append(Double(value))
            position += block
        }
        let average = mean(rms)
        return min(2, standardDeviation(rms) / max(average, 1e-8))
    }

    private static func sustainDynamics(_ samples: [Float], sampleRate: Double) -> (stationarity: Double?, modulationRate: Double?, modulationDepth: Double?) {
        let window = max(64, Int(sampleRate * 0.025))
        let hop = max(32, Int(sampleRate * 0.01))
        guard samples.count >= window * 3 else { return (nil, nil, nil) }
        var levels: [Double] = []
        var start = 0
        while start + window <= samples.count {
            var rms: Float = 0
            samples.withUnsafeBufferPointer { pointer in
                if let base = pointer.baseAddress {
                    vDSP_rmsqv(base.advanced(by: start), 1, &rms, vDSP_Length(window))
                }
            }
            levels.append(20 * log10(max(Double(rms), 1e-9)))
            start += hop
        }
        let spread = percentile(levels, 0.9) - percentile(levels, 0.1)
        let stationarity = max(0, min(1, 1 - standardDeviation(levels) / 12))
        let centered = levels.map { $0 - mean(levels) }
        let frameRate = sampleRate / Double(hop)
        let minimumLag = max(1, Int(frameRate / 12))
        let maximumLag = min(centered.count / 2, Int(frameRate / 0.25))
        var best: (lag: Int, correlation: Double)?
        if maximumLag > minimumLag {
            let energy = centered.reduce(0) { $0 + $1 * $1 }
            if energy > 1e-8 {
                for lag in minimumLag...maximumLag {
                    var numerator = 0.0, left = 0.0, right = 0.0
                    for index in lag..<centered.count {
                        let a = centered[index - lag], b = centered[index]
                        numerator += a * b; left += a * a; right += b * b
                    }
                    let correlation = numerator / sqrt(max(1e-12, left * right))
                    if best == nil || correlation > best!.correlation { best = (lag, correlation) }
                }
            }
        }
        let rate = best.flatMap { $0.correlation >= 0.28 ? frameRate / Double($0.lag) : nil }
        return (stationarity, rate, spread.isFinite ? max(0, spread) : nil)
    }

    private static func classify(
        stationarity: Double?, modulationRate: Double?, modulationDepth: Double?, pitchDrift: Double?
    ) -> LoopabilityClass {
        if abs(pitchDrift ?? 0) > 4 { return .drifting }
        if modulationRate != nil, (modulationDepth ?? 0) >= 0.5 { return .modulated }
        if (stationarity ?? 0) >= 0.78 { return .stablePeriodic }
        if (stationarity ?? 0) >= 0.48 { return .quasiPeriodic }
        return .unsuitable
    }

    private static func parameterRecord(_ configuration: LoopDetectionConfiguration, periodFrames: Int?) -> [String: String] {
        [
            "candidateCount": String(configuration.candidateCount),
            "minimumLoopSeconds": String(configuration.minimumLoopSeconds),
            "maximumLoopSeconds": String(configuration.maximumLoopSeconds),
            "sustainSafetyMarginSeconds": String(configuration.sustainSafetyMarginSeconds),
            "comparisonWindowSeconds": String(configuration.comparisonWindowSeconds),
            "crossfadeSeconds": String(configuration.crossfadeSeconds),
            "fundamentalPeriodFrames": periodFrames.map(String.init) ?? "unavailable",
            "coordinateConvention": "start-inclusive/end-exclusive",
            "channelPolicy": "shared-frame-coordinates/all-channel-scoring",
        ]
    }
}

public enum PipeSoundBehaviorAnalyzer {
    public static func summarize(
        analysis: AnalysisSummary,
        pitchTrack: [PitchTrackPoint],
        partialTracks: [PartialTrack],
        loopDetection: LoopDetectionResult? = nil
    ) -> PipeSoundBehaviorSummary {
        let attack = interval(analysis.onsetSeconds, analysis.sustainStartSeconds)
        let release = interval(analysis.keyUpSeconds, analysis.soundOffsetSeconds)
        let tail = interval(analysis.soundOffsetSeconds, analysis.tailEndSeconds)
        let partialOrder = partialTracks.compactMap { track -> (Int, Double)? in
            track.onsetSeconds.map { (track.harmonicNumber, $0) }
        }.sorted { $0.1 < $1.1 }.prefix(16).map(\.0)
        let decayRates = partialTracks.compactMap(\.decayRateDBPerSecond).filter(\.isFinite)
        let correlations = (analysis.channelRelationships ?? []).compactMap(\.correlationWithReference)
        return PipeSoundBehaviorSummary(
            attackDurationSeconds: attack,
            attackDurationFundamentalPeriods: attack.flatMap { duration in
                analysis.frequencyHz.map { duration * $0 }
            },
            partialOnsetOrder: partialOrder,
            sustainStationarity: loopDetection?.sustainStationarity,
            amplitudeModulationRateHz: loopDetection?.amplitudeModulationRateHz,
            amplitudeModulationDepthDB: loopDetection?.amplitudeModulationDepthDB,
            frequencyModulationRateHz: analysis.pitchTrackSummary?.modulationRateHz,
            frequencyModulationDepthCents: analysis.pitchTrackSummary?.modulationDepthCents,
            releaseDurationSeconds: release,
            roomTailDurationSeconds: tail,
            partialDecayRateMADDBPerSecond: decayRates.isEmpty ? nil : medianAbsoluteDeviation(decayRates),
            meanInterchannelCorrelation: correlations.isEmpty ? nil : mean(correlations),
            loopability: loopDetection?.loopability
        )
    }

    private static func interval(_ start: Double?, _ end: Double?) -> Double? {
        guard let start, let end, end >= start else { return nil }
        return end - start
    }
}

private func mean(_ values: [Double]) -> Double {
    values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
}

private func standardDeviation(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let average = mean(values)
    return sqrt(values.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count - 1))
}

private func percentile(_ values: [Double], _ probability: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let ordered = values.sorted()
    let position = max(0, min(1, probability)) * Double(ordered.count - 1)
    let lower = Int(floor(position)), upper = Int(ceil(position))
    if lower == upper { return ordered[lower] }
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - Double(lower))
}

private func medianAbsoluteDeviation(_ values: [Double]) -> Double {
    let center = percentile(values, 0.5)
    return percentile(values.map { abs($0 - center) }, 0.5)
}
