import Foundation
import OrgRecCore

private struct PitchCandidate: Sendable {
    var id: UUID
    var frequency: Double
}

private actor LivePitchProcessor {
    private var samples: [Float] = []
    private var sampleRate: Double = 0
    private var isEstimating = false
    private let estimator = AutocorrelationPitchEstimator()

    func reset() {
        samples.removeAll(keepingCapacity: true)
        sampleRate = 0
        isEstimating = false
    }

    func append(_ chunk: [Float], sampleRate: Double, expected: Double) async -> PitchEstimate? {
        guard sampleRate > 0, chunk.isEmpty == false else { return nil }
        self.sampleRate = sampleRate
        samples.append(contentsOf: chunk)
        let maximum = min(65_536, max(16_384, Int(sampleRate * 1.2)))
        if samples.count > maximum { samples.removeFirst(samples.count - maximum) }
        let required = min(maximum, max(8_192, Int(sampleRate * 0.35)))
        guard samples.count >= required, isEstimating == false else { return nil }
        var rms: Float = 0
        for value in samples.suffix(required) { rms += value * value }
        rms = sqrt(rms / Float(required))
        guard rms > 0.0005 else { return PitchEstimate(frequencyHz: 0, confidence: 0, method: "Silence gate", modelVersion: "orgrec-live-pitch/1") }
        isEstimating = true
        let window = Array(samples.suffix(required))
        let estimate = try? await estimator.estimate(samples: window, sampleRate: sampleRate, expectedFrequency: expected)
        isEstimating = false
        samples.removeFirst(min(samples.count, required / 3))
        return estimate
    }
}

@MainActor
final class LivePitchMonitor: ObservableObject {
    @Published private(set) var evidence: LivePitchEvidence?
    @Published private(set) var history: [LivePitchEvidence] = []

    private let processor = LivePitchProcessor()
    private var targetID: UUID?
    private var expectedFrequency: Double?
    private var calibrationID: UUID?
    private var referenceA4: Double = 440
    private var candidates: [PitchCandidate] = []
    private var recentFrequencies: [Double] = []
    private var stableSince: Date?

    func configure(item: RoadmapItem, project: OrgRecProject) {
        targetID = item.id
        expectedFrequency = item.component.expectedFrequencyHz
        calibrationID = project.recordingSessions?.last(where: { $0.endedAt == nil })?.tuningCalibrationID
        referenceA4 = project.tuningCalibrations?
            .first(where: { $0.id == calibrationID && $0.status == .accepted })?.normalizedA4Hz
            ?? project.documentedPitchStandard?.frequencyHz
            ?? 440
        let parent = item.component.parentComponentID
        candidates = project.roadmap.compactMap { candidate in
            guard candidate.id != item.id,
                  candidate.component.parentComponentID == parent,
                  let frequency = candidate.component.expectedFrequencyHz else { return nil }
            return PitchCandidate(id: candidate.id, frequency: frequency)
        }
        history = []
        recentFrequencies = []
        stableSince = nil
        evidence = item.component.expectedFrequencyHz.map {
            LivePitchEvidence(calibrationID: calibrationID, roadmapItemID: item.id, expectedFrequencyHz: $0)
        }
        Task { await processor.reset() }
    }

    func reset() {
        targetID = nil
        expectedFrequency = nil
        candidates = []
        history = []
        recentFrequencies = []
        stableSince = nil
        evidence = nil
        Task { await processor.reset() }
    }

    nonisolated func consume(samples: [Float], sampleRate: Double) {
        Task { @MainActor [weak self] in self?.ingest(samples: samples, sampleRate: sampleRate) }
    }

    private func ingest(samples: [Float], sampleRate: Double) {
        guard let expectedFrequency, let targetID else { return }
        Task { [weak self] in
            guard let self,
                  let estimate = await self.processor.append(samples, sampleRate: sampleRate, expected: expectedFrequency) else { return }
            self.publish(estimate, targetID: targetID, expectedFrequency: expectedFrequency)
        }
    }

    private func publish(_ estimate: PitchEstimate, targetID: UUID, expectedFrequency: Double) {
        let measured = estimate.frequencyHz > 0 ? estimate.frequencyHz : nil
        if let measured {
            recentFrequencies.append(measured)
            if recentFrequencies.count > 5 { recentFrequencies.removeFirst() }
        } else {
            recentFrequencies.removeAll()
        }
        let stableMeasured: Double?
        if recentFrequencies.count >= 3 {
            let sorted = recentFrequencies.sorted()
            let median = sorted[sorted.count / 2]
            let spread = sorted.compactMap { PitchMatcher.cents(measured: $0, expected: median) }.map(abs).max() ?? 0
            stableMeasured = spread <= 25 ? median : nil
        } else {
            stableMeasured = nil
        }
        let closest = stableMeasured.flatMap { measured in
            candidates.min { abs(log($0.frequency / measured)) < abs(log($1.frequency / measured)) }
        }
        let decision: LivePitchDecision
        if measured == nil { decision = .noSignal }
        else if stableMeasured == nil { decision = .acquiring }
        else {
            decision = PitchMatcher.decision(
                measuredFrequency: stableMeasured,
                confidence: estimate.confidence,
                expectedFrequency: expectedFrequency,
                nearestAlternativeFrequency: closest?.frequency
            )
        }
        if [.matched, .tuningWarning, .probableWrongNote].contains(decision) {
            stableSince = stableSince ?? .now
        } else {
            stableSince = nil
        }
        let result = LivePitchEvidence(
            calibrationID: calibrationID,
            roadmapItemID: targetID,
            expectedFrequencyHz: expectedFrequency,
            measuredFrequencyHz: stableMeasured ?? measured,
            centsDeviation: (stableMeasured ?? measured).flatMap { PitchMatcher.cents(measured: $0, expected: expectedFrequency) },
            confidence: estimate.confidence,
            detectedMIDINote: (stableMeasured ?? measured).map { Int((69 + 12 * log2($0 / referenceA4)).rounded()) },
            nearestRoadmapItemID: closest?.id,
            decision: decision,
            stableDurationSeconds: stableSince.map { Date().timeIntervalSince($0) } ?? 0,
            method: estimate.method,
            algorithmVersion: estimate.modelVersion
        )
        evidence = result
        if decision != .acquiring && decision != .noSignal {
            history.append(result)
            if history.count > 30 { history.removeFirst(history.count - 30) }
        }
    }

    var finalEvidence: [LivePitchEvidence] {
        if let evidence, history.last != evidence { return history + [evidence] }
        return history
    }
}
