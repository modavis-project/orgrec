import Foundation

/// A source-backed pitch statement imported from MODAVIS. This is evidence about
/// the organ specification, not proof of the organ's pitch on a recording day.
public struct DocumentedPitchStandard: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var frequencyHz: Double
    public var rawValue: String
    public var evidenceStatus: String?
    public var sourcePath: String?
    public var sourceRecordID: String?
    public var modavisRelease: String
    public var automaticallyImported: Bool

    public init(
        contractVersion: String = "orgrec.documented-pitch/v1",
        frequencyHz: Double,
        rawValue: String,
        evidenceStatus: String? = nil,
        sourcePath: String? = nil,
        sourceRecordID: String? = nil,
        modavisRelease: String,
        automaticallyImported: Bool = true
    ) {
        self.contractVersion = contractVersion
        self.frequencyHz = frequencyHz
        self.rawValue = rawValue
        self.evidenceStatus = evidenceStatus
        self.sourcePath = sourcePath
        self.sourceRecordID = sourceRecordID
        self.modavisRelease = modavisRelease
        self.automaticallyImported = automaticallyImported
    }
}

public enum TuningCalibrationStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case accepted
    case rejected
    case waived
}

/// Session-scoped field evidence used to normalize intended key frequencies.
public struct TuningCalibration: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var sessionID: UUID
    public var createdAt: Date
    public var status: TuningCalibrationStatus
    public var referenceMIDINote: Int
    public var referenceNoteName: String
    public var referenceComponent: ComponentLocator?
    public var documentedA4Hz: Double?
    public var measuredFrequencyHz: Double?
    public var normalizedA4Hz: Double?
    public var confidence: Double?
    public var centsFromDocumented: Double?
    public var method: String
    public var algorithmVersion: String
    public var relativeAudioPath: String?
    public var referenceChannelIndex: Int
    public var environment: EnvironmentReading
    public var audioSHA256: String?
    public var audioFileSize: Int64?
    public var acceptedAt: Date?
    public var acceptedBy: String?
    public var notes: String

    public init(
        contractVersion: String = "orgrec.tuning-calibration/v1",
        id: UUID = UUID(),
        sessionID: UUID,
        createdAt: Date = .now,
        status: TuningCalibrationStatus = .pending,
        referenceMIDINote: Int = 69,
        referenceNoteName: String = "A4",
        referenceComponent: ComponentLocator? = nil,
        documentedA4Hz: Double? = nil,
        measuredFrequencyHz: Double? = nil,
        normalizedA4Hz: Double? = nil,
        confidence: Double? = nil,
        centsFromDocumented: Double? = nil,
        method: String = "Pending field measurement",
        algorithmVersion: String = "orgrec-calibration/1",
        relativeAudioPath: String? = nil,
        referenceChannelIndex: Int = 0,
        environment: EnvironmentReading = EnvironmentReading(),
        audioSHA256: String? = nil,
        audioFileSize: Int64? = nil,
        acceptedAt: Date? = nil,
        acceptedBy: String? = nil,
        notes: String = ""
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.sessionID = sessionID
        self.createdAt = createdAt
        self.status = status
        self.referenceMIDINote = referenceMIDINote
        self.referenceNoteName = referenceNoteName
        self.referenceComponent = referenceComponent
        self.documentedA4Hz = documentedA4Hz
        self.measuredFrequencyHz = measuredFrequencyHz
        self.normalizedA4Hz = normalizedA4Hz
        self.confidence = confidence
        self.centsFromDocumented = centsFromDocumented
        self.method = method
        self.algorithmVersion = algorithmVersion
        self.relativeAudioPath = relativeAudioPath
        self.referenceChannelIndex = referenceChannelIndex
        self.environment = environment
        self.audioSHA256 = audioSHA256
        self.audioFileSize = audioFileSize
        self.acceptedAt = acceptedAt
        self.acceptedBy = acceptedBy
        self.notes = notes
    }
}

public enum LivePitchDecision: String, Codable, CaseIterable, Sendable {
    case noSignal
    case acquiring
    case matched
    case tuningWarning
    case probableWrongNote
    case ambiguous
}

public struct LivePitchEvidence: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var calibrationID: UUID?
    public var roadmapItemID: UUID
    public var expectedFrequencyHz: Double
    public var measuredFrequencyHz: Double?
    public var centsDeviation: Double?
    public var confidence: Double
    public var detectedMIDINote: Int?
    public var nearestRoadmapItemID: UUID?
    public var decision: LivePitchDecision
    public var stableDurationSeconds: Double
    public var observedAt: Date
    public var method: String
    public var algorithmVersion: String

    public init(
        contractVersion: String = "orgrec.live-pitch-evidence/v1",
        calibrationID: UUID?,
        roadmapItemID: UUID,
        expectedFrequencyHz: Double,
        measuredFrequencyHz: Double? = nil,
        centsDeviation: Double? = nil,
        confidence: Double = 0,
        detectedMIDINote: Int? = nil,
        nearestRoadmapItemID: UUID? = nil,
        decision: LivePitchDecision = .acquiring,
        stableDurationSeconds: Double = 0,
        observedAt: Date = .now,
        method: String = "Live autocorrelation",
        algorithmVersion: String = "orgrec-live-pitch/1"
    ) {
        self.contractVersion = contractVersion
        self.calibrationID = calibrationID
        self.roadmapItemID = roadmapItemID
        self.expectedFrequencyHz = expectedFrequencyHz
        self.measuredFrequencyHz = measuredFrequencyHz
        self.centsDeviation = centsDeviation
        self.confidence = confidence
        self.detectedMIDINote = detectedMIDINote
        self.nearestRoadmapItemID = nearestRoadmapItemID
        self.decision = decision
        self.stableDurationSeconds = stableDurationSeconds
        self.observedAt = observedAt
        self.method = method
        self.algorithmVersion = algorithmVersion
    }
}

public enum PitchMatcher {
    public static func cents(measured: Double, expected: Double) -> Double? {
        guard measured > 0, expected > 0 else { return nil }
        return 1_200 * log2(measured / expected)
    }

    public static func normalizedA4(measuredFrequency: Double, referenceMIDINote: Int) -> Double {
        measuredFrequency / pow(2, Double(referenceMIDINote - 69) / 12)
    }

    public static func decision(
        measuredFrequency: Double?,
        confidence: Double,
        expectedFrequency: Double,
        nearestAlternativeFrequency: Double? = nil
    ) -> LivePitchDecision {
        guard let measuredFrequency, measuredFrequency > 0 else { return .noSignal }
        guard confidence >= 0.35 else { return .ambiguous }
        guard let targetCents = cents(measured: measuredFrequency, expected: expectedFrequency) else { return .ambiguous }
        let target = abs(targetCents)
        if target <= 35 { return .matched }
        if let alternative = nearestAlternativeFrequency,
           let alternativeCents = cents(measured: measuredFrequency, expected: alternative),
           abs(alternativeCents) <= 35,
           target >= 60 {
            return .probableWrongNote
        }
        return target <= 60 ? .tuningWarning : .probableWrongNote
    }
}
