import Accelerate
import Foundation

/// Probabilistic YIN for monophonic organ-pipe evidence. Each frame retains
/// several YIN troughs, integrates them over a beta-distributed threshold
/// prior, and Viterbi-decodes voiced/unvoiced candidate sequences.
public actor PYINPitchEstimator: PitchEstimating {
    public struct Configuration: Sendable {
        public var thresholdCount: Int
        public var betaAlpha: Double
        public var betaBeta: Double
        public var maximumCandidatesPerFrame: Int
        public var maximumFrames: Int

        public init(
            thresholdCount: Int = 100,
            betaAlpha: Double = 2,
            betaBeta: Double = 18,
            maximumCandidatesPerFrame: Int = 5,
            maximumFrames: Int = 160
        ) {
            self.thresholdCount = thresholdCount
            self.betaAlpha = betaAlpha
            self.betaBeta = betaBeta
            self.maximumCandidatesPerFrame = maximumCandidatesPerFrame
            self.maximumFrames = maximumFrames
        }
    }

    private struct Candidate: Sendable {
        var frequency: Double
        var probability: Double
        var periodicity: Double
    }

    private struct State: Sendable {
        var candidate: Candidate?
        var observationProbability: Double
    }

    private let configuration: Configuration

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func estimate(
        samples: [Float],
        sampleRate: Double,
        expectedFrequency: Double?
    ) async throws -> PitchEstimate? {
        guard samples.count >= 2_048, sampleRate > 0 else { return nil }
        // When a roadmap expectation exists, retain a two-octave search span so
        // retakes and skipped positions cannot force the estimator to the assigned
        // pitch. The unconstrained fallback stays broad without paying the very high
        // autocorrelation cost of sub-audible lags; documented 32-foot candidates use
        // the expected-frequency branch and still reach 12 Hz.
        let minimumFrequency = max(12, expectedFrequency.map { $0 / 2.1 } ?? 30)
        let maximumFrequency = min(sampleRate * 0.45, 12_000, expectedFrequency.map { $0 * 2.1 } ?? 5_000)
        let minimumLag = max(2, Int(floor(sampleRate / maximumFrequency)))
        let maximumLag = max(minimumLag + 2, Int(ceil(sampleRate / minimumFrequency)))
        let desiredLength = max(2_048, maximumLag * 5)
        let frameLength = min(samples.count, min(32_768, nextPowerOfTwo(desiredLength)))
        guard frameLength > maximumLag + 8 else { return nil }
        let hop = max(160, min(frameLength / 4, Int(sampleRate * 0.02)))
        let availableFrameCount = max(1, 1 + (samples.count - frameLength) / hop)
        let decimation = max(1, Int(ceil(Double(availableFrameCount) / Double(max(1, configuration.maximumFrames)))))
        let effectiveHop = hop * decimation
        let thresholds = thresholdPrior()

        var frameStates: [[State]] = []
        var frameTimes: [Double] = []
        var start = 0
        while start + frameLength <= samples.count {
            var frame = Array(samples[start..<(start + frameLength)])
            removeMeanAndWindow(&frame)
            let candidates = frameCandidates(
                frame,
                sampleRate: sampleRate,
                minimumLag: minimumLag,
                maximumLag: maximumLag,
                thresholds: thresholds
            )
            let periodicity = candidates.map(\.periodicity).max() ?? 0
            let voicedProbability = min(0.995, max(0.005, periodicity))
            let candidateTotal = candidates.map(\.probability).reduce(0, +)
            var states = candidates.map { candidate -> State in
                let normalized = candidateTotal > 0 ? candidate.probability / candidateTotal : 0
                return State(candidate: candidate, observationProbability: max(1e-8, normalized * voicedProbability))
            }
            states.append(State(candidate: nil, observationProbability: max(1e-8, 1 - voicedProbability)))
            frameStates.append(states)
            frameTimes.append((Double(start) + Double(frameLength) / 2) / sampleRate)
            start += effectiveHop
        }
        guard frameStates.isEmpty == false else { return nil }
        let path = viterbi(states: frameStates, hopSeconds: Double(effectiveHop) / sampleRate)
        let track = zip(frameTimes, path).map { time, state -> PitchTrackPoint in
            PitchTrackPoint(
                timeSeconds: time,
                frequencyHz: state.candidate?.frequency,
                confidence: state.candidate == nil ? 1 - state.observationProbability : state.observationProbability,
                voiced: state.candidate != nil && state.observationProbability >= 0.2,
                estimator: "pYIN",
                centsFromExpected: state.candidate.flatMap { candidate in
                    expectedFrequency.flatMap { centsDifference(measured: candidate.frequency, expected: $0) }
                }
            )
        }
        let voiced = track.filter(\.voiced)
        guard voiced.count >= max(2, track.count / 8) else { return nil }
        let frequency = pyinMedian(voiced.compactMap(\.frequencyHz))
        let confidence = min(1, pyinMedian(voiced.map(\.confidence)) * sqrt(Double(voiced.count) / Double(track.count)))
        return PitchEstimate(
            frequencyHz: frequency,
            confidence: confidence,
            method: "Probabilistic YIN",
            modelVersion: "orgrec-pyin/1",
            track: track
        )
    }

    private func thresholdPrior() -> [(threshold: Double, probability: Double)] {
        let count = max(10, configuration.thresholdCount)
        var values: [(Double, Double)] = (0..<count).map { index in
            let threshold = (Double(index) + 0.5) / Double(count)
            let weight = pow(threshold, configuration.betaAlpha - 1) * pow(1 - threshold, configuration.betaBeta - 1)
            return (threshold, weight)
        }
        let total = values.map(\.1).reduce(0, +)
        if total > 0 {
            for index in values.indices { values[index].1 /= total }
        }
        return values
    }

    private func frameCandidates(
        _ frame: [Float],
        sampleRate: Double,
        minimumLag: Int,
        maximumLag: Int,
        thresholds: [(threshold: Double, probability: Double)]
    ) -> [Candidate] {
        let analysisLength = frame.count - maximumLag
        guard analysisLength > 16 else { return [] }
        var prefixEnergy = [Double](repeating: 0, count: frame.count + 1)
        for index in frame.indices {
            let value = Double(frame[index])
            prefixEnergy[index + 1] = prefixEnergy[index] + value * value
        }
        var difference = [Double](repeating: 0, count: maximumLag + 1)
        frame.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            for lag in 1...maximumLag {
                var dot: Float = 0
                vDSP_dotpr(base, 1, base.advanced(by: lag), 1, &dot, vDSP_Length(analysisLength))
                let left = prefixEnergy[analysisLength]
                let right = prefixEnergy[lag + analysisLength] - prefixEnergy[lag]
                difference[lag] = max(0, left + right - 2 * Double(dot))
            }
        }
        var cumulative = 0.0
        var normalized = [Double](repeating: 1, count: maximumLag + 1)
        for lag in 1...maximumLag {
            cumulative += difference[lag]
            normalized[lag] = cumulative > 0 ? difference[lag] * Double(lag) / cumulative : 1
        }
        var minima = (minimumLag...maximumLag).filter { lag in
            let left = normalized[max(1, lag - 1)]
            let right = normalized[min(maximumLag, lag + 1)]
            return normalized[lag] <= left && normalized[lag] < right
        }
        if minima.isEmpty, let best = (minimumLag...maximumLag).min(by: { normalized[$0] < normalized[$1] }) {
            minima = [best]
        }
        var mass: [Int: Double] = [:]
        for item in thresholds {
            if let lag = minima.first(where: { normalized[$0] < item.threshold }) {
                mass[lag, default: 0] += item.probability
            } else if let best = minima.min(by: { normalized[$0] < normalized[$1] }) {
                mass[best, default: 0] += item.probability * 0.01
            }
        }
        return mass.map { lag, probability in
            var refined = Double(lag)
            if lag > minimumLag, lag < maximumLag {
                let left = normalized[lag - 1]
                let center = normalized[lag]
                let right = normalized[lag + 1]
                let denominator = left - 2 * center + right
                if abs(denominator) > 1e-12 {
                    refined += min(0.5, max(-0.5, 0.5 * (left - right) / denominator))
                }
            }
            return Candidate(
                frequency: sampleRate / refined,
                probability: probability,
                periodicity: min(1, max(0, 1 - normalized[lag]))
            )
        }
        .sorted { lhs, rhs in
            let leftScore = lhs.probability * lhs.periodicity
            let rightScore = rhs.probability * rhs.periodicity
            return leftScore > rightScore
        }
        .prefix(max(1, configuration.maximumCandidatesPerFrame))
        .map { $0 }
    }

    private func viterbi(states: [[State]], hopSeconds: Double) -> [State] {
        guard let first = states.first else { return [] }
        var scores = first.map { log(max(1e-12, $0.observationProbability)) }
        var backPointers: [[Int]] = [Array(repeating: 0, count: first.count)]
        for frameIndex in 1..<states.count {
            let previous = states[frameIndex - 1]
            let current = states[frameIndex]
            var nextScores = [Double](repeating: -.infinity, count: current.count)
            var pointers = [Int](repeating: 0, count: current.count)
            for currentIndex in current.indices {
                for previousIndex in previous.indices {
                    let score = scores[previousIndex]
                        + transition(from: previous[previousIndex], to: current[currentIndex], hopSeconds: hopSeconds)
                        + log(max(1e-12, current[currentIndex].observationProbability))
                    if score > nextScores[currentIndex] {
                        nextScores[currentIndex] = score
                        pointers[currentIndex] = previousIndex
                    }
                }
            }
            scores = nextScores
            backPointers.append(pointers)
        }
        var index = scores.indices.max(by: { scores[$0] < scores[$1] }) ?? 0
        var path = [State](repeating: states.last![index], count: states.count)
        if states.count > 1 {
            for frameIndex in stride(from: states.count - 1, through: 1, by: -1) {
                path[frameIndex] = states[frameIndex][index]
                index = backPointers[frameIndex][index]
            }
        }
        path[0] = states[0][index]
        return path
    }

    private func transition(from: State, to: State, hopSeconds: Double) -> Double {
        switch (from.candidate, to.candidate) {
        case (nil, nil): return -0.04
        case (nil, _), (_, nil): return -2.8
        case let (previous?, current?):
            let cents = abs(1_200 * log2(current.frequency / previous.frequency))
            let expectedMotion = max(35, hopSeconds * 2_400)
            return cents > 700 ? -14 : -cents / expectedMotion
        }
    }

    private func removeMeanAndWindow(_ frame: inout [Float]) {
        var mean: Float = 0
        vDSP_meanv(frame, 1, &mean, vDSP_Length(frame.count))
        for index in frame.indices {
            let window = 0.5 - 0.5 * cos(2 * Double.pi * Double(index) / Double(max(1, frame.count - 1)))
            frame[index] = (frame[index] - mean) * Float(window)
        }
    }

    private func nextPowerOfTwo(_ value: Int) -> Int {
        var result = 1
        while result < value { result <<= 1 }
        return result
    }
}

private func pyinMedian(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    guard sorted.isEmpty == false else { return 0 }
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
}

public struct PitchEstimatorResolution: Sendable {
    public var estimate: PitchEstimate?
    public var comparison: PitchEstimatorComparison

    public init(estimate: PitchEstimate?, comparison: PitchEstimatorComparison) {
        self.estimate = estimate
        self.comparison = comparison
    }
}

public enum PitchEstimatorComparisonEngine {
    public static func resolve(
        crepe: PitchEstimate?,
        pyin: PitchEstimate?,
        fallback: PitchEstimate? = nil,
        expectedFrequency: Double? = nil
    ) -> PitchEstimatorResolution {
        let evidence = [crepe, pyin, fallback].compactMap { estimate -> PitchEstimatorEvidence? in
            guard let estimate else { return nil }
            let voicedRatio = estimate.track.isEmpty ? nil
                : Double(estimate.track.filter(\.voiced).count) / Double(estimate.track.count)
            return PitchEstimatorEvidence(
                estimator: canonicalName(estimate),
                frequencyHz: estimate.frequencyHz,
                confidence: estimate.confidence,
                algorithmVersion: estimate.modelVersion,
                voicedFrameRatio: voicedRatio
            )
        }
        guard let crepe, let pyin,
              let signedDifference = centsDifference(measured: pyin.frequencyHz, expected: crepe.frequencyHz) else {
            let selected = bestAvailable([crepe, pyin, fallback], expectedFrequency: expectedFrequency)
            return PitchEstimatorResolution(
                estimate: selected,
                comparison: PitchEstimatorComparison(
                    estimates: evidence,
                    severity: .unavailable,
                    selectedEstimator: selected.map(canonicalName),
                    selectedFrequencyHz: selected?.frequencyHz,
                    rationale: evidence.isEmpty
                        ? "No estimator produced usable monophonic evidence."
                        : "CREPE–pYIN comparison unavailable; retained the strongest usable estimator without claiming consensus."
                )
            )
        }
        let difference = abs(signedDifference)
        if difference <= 25 {
            let totalWeight = max(0.01, crepe.confidence + pyin.confidence)
            let frequency = exp((log(crepe.frequencyHz) * crepe.confidence + log(pyin.frequencyHz) * pyin.confidence) / totalWeight)
            let trackSource = crepe.confidence >= pyin.confidence ? crepe : pyin
            let confidence = sqrt(crepe.confidence * pyin.confidence) * max(0.75, 1 - difference / 100)
            let estimate = PitchEstimate(
                frequencyHz: frequency,
                confidence: confidence,
                method: "CREPE + pYIN consensus",
                modelVersion: "\(crepe.modelVersion); \(pyin.modelVersion)",
                track: trackSource.track,
                estimatorAgreementCents: difference
            )
            return PitchEstimatorResolution(
                estimate: estimate,
                comparison: PitchEstimatorComparison(
                    estimates: evidence,
                    differenceCents: difference,
                    severity: .agreement,
                    selectedEstimator: "CREPE + pYIN consensus",
                    selectedFrequencyHz: frequency,
                    rationale: "Independent estimates agree within 25 cents and were confidence-weighted in log-frequency space."
                )
            )
        }

        let bothStrong = min(crepe.confidence, pyin.confidence) >= 0.55
        let severity: PitchEstimatorMismatchSeverity = difference > 50 && bothStrong ? .critical : .material
        var selected = bestAvailable([crepe, pyin], expectedFrequency: expectedFrequency) ?? crepe
        var rationale = severity == .critical
            ? "High-confidence CREPE and pYIN estimates differ by more than 50 cents; values were not averaged."
            : "CREPE and pYIN differ materially; the stronger estimate was retained without averaging."
        if let fallback, fallback.confidence >= 0.35 {
            let crepeDistance = abs(centsDifference(measured: fallback.frequencyHz, expected: crepe.frequencyHz) ?? 9_999)
            let pyinDistance = abs(centsDifference(measured: fallback.frequencyHz, expected: pyin.frequencyHz) ?? 9_999)
            if abs(crepeDistance - pyinDistance) >= 25 {
                selected = crepeDistance < pyinDistance ? crepe : pyin
                rationale += " Normalized autocorrelation independently supported \(canonicalName(selected))."
            } else {
                rationale += " Normalized autocorrelation did not resolve the discrepancy."
            }
        }
        selected.confidence *= severity == .critical ? 0.5 : 0.75
        selected.method = "\(canonicalName(selected)) retained; \(severity.rawValue) CREPE–pYIN mismatch"
        selected.modelVersion = "\(crepe.modelVersion); \(pyin.modelVersion)"
        selected.estimatorAgreementCents = difference
        return PitchEstimatorResolution(
            estimate: selected,
            comparison: PitchEstimatorComparison(
                estimates: evidence,
                differenceCents: difference,
                severity: severity,
                selectedEstimator: canonicalName(selected),
                selectedFrequencyHz: selected.frequencyHz,
                rationale: rationale
            )
        )
    }

    private static func bestAvailable(
        _ estimates: [PitchEstimate?],
        expectedFrequency: Double?
    ) -> PitchEstimate? {
        estimates.compactMap { $0 }.max { lhs, rhs in
            score(lhs, expectedFrequency: expectedFrequency) < score(rhs, expectedFrequency: expectedFrequency)
        }
    }

    private static func score(_ estimate: PitchEstimate, expectedFrequency: Double?) -> Double {
        let priorPenalty = expectedFrequency.flatMap {
            centsDifference(measured: estimate.frequencyHz, expected: $0)
        }.map { min(0.2, abs($0) / 6_000) } ?? 0
        return estimate.confidence - priorPenalty
    }

    private static func canonicalName(_ estimate: PitchEstimate) -> String {
        if estimate.method.localizedCaseInsensitiveContains("crepe") { return "CREPE" }
        if estimate.method.localizedCaseInsensitiveContains("yin") { return "pYIN" }
        if estimate.method.localizedCaseInsensitiveContains("autocorrelation") { return "Normalized autocorrelation" }
        return estimate.method
    }
}
