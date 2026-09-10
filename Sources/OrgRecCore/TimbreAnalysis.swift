import Accelerate
import AVFAudio
import Foundation

public enum TimbreAnalysisMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case characterization
    case familySuggestion

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .characterization: "Characterize rank"
        case .familySuggestion: "Suggest tone family"
        }
    }
}

public enum TimbreAnalysisApplicability: String, Codable, CaseIterable, Sendable {
    case applicable
    case limited
    case notApplicable
}

public enum PipeTimbreFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case flute
    case diapason
    case string
    case reed
    case compound
    case indeterminate

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .flute: "Flute"
        case .diapason: "Diapason / principal"
        case .string: "String"
        case .reed: "Reed"
        case .compound: "Compound stop"
        case .indeterminate: "Indeterminate"
        }
    }
}

/// The six visual patterns named by Hergert & Haverkamp (2023). They are
/// descriptors of the lowest five harmonic partials, not organ-stop classes.
public enum FirstFivePartialPrototype: String, Codable, CaseIterable, Identifiable, Sendable {
    case dominantFundamental
    case weakEvenChalumeau
    case weakSecond
    case weakFourth
    case richInHarmonics
    case strongSecondOctavial
    case indeterminate

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dominantFundamental: "Dominant fundamental"
        case .weakEvenChalumeau: "Weak even partials (chalumeau-like)"
        case .weakSecond: "Weak second partial"
        case .weakFourth: "Weak fourth partial"
        case .richInHarmonics: "Rich in harmonics"
        case .strongSecondOctavial: "Strong second partial (octavial)"
        case .indeterminate: "Indeterminate"
        }
    }
}

public enum TimbreFundamentalSource: String, Codable, Sendable {
    case measuredConsensus
    case roadmapExpectation
}

public struct TimbrePublicationReference: Codable, Hashable, Identifiable, Sendable {
    public var id: String { doi }
    public var shortCitation: String
    public var title: String
    public var doi: String
    public var contribution: String

    public init(shortCitation: String, title: String, doi: String, contribution: String) {
        self.shortCitation = shortCitation
        self.title = title
        self.doi = doi
        self.contribution = contribution
    }
}

public struct TimbreFamilyProfilePoint: Codable, Hashable, Identifiable, Sendable {
    public var id: PipeTimbreFamily { family }
    public var family: PipeTimbreFamily
    public var centroidCenter: Double
    public var slopeCenterDBPerOctave: Double
    public var centroidScale: Double
    public var slopeScaleDBPerOctave: Double

    public init(
        family: PipeTimbreFamily,
        centroidCenter: Double,
        slopeCenterDBPerOctave: Double,
        centroidScale: Double,
        slopeScaleDBPerOctave: Double
    ) {
        self.family = family
        self.centroidCenter = centroidCenter
        self.slopeCenterDBPerOctave = slopeCenterDBPerOctave
        self.centroidScale = centroidScale
        self.slopeScaleDBPerOctave = slopeScaleDBPerOctave
    }
}

public struct TimbreAnalysisParameters: Codable, Hashable, Sendable {
    public var targetSampleRateHz: Double
    public var fftSizes: [Int]
    public var targetFundamentalCycles: Double
    public var minimumWindowSeconds: Double
    public var maximumWindowSeconds: Double
    public var frameOverlapFraction: Double
    public var maximumAveragedFrames: Int
    public var maximumStableDurationSeconds: Double
    public var maximumPartialCount: Int
    public var maximumPartialFrequencyHz: Double
    public var localSignalToNoiseThresholdDB: Double
    public var minimumMeasuredPitchConfidence: Double
    public var minimumDetectedPartials: Int
    public var minimumRankObservationCount: Int
    public var slopeExponent: Double
    public var slopeSignConvention: String
    public var centroidDomain: ClosedRange<Double>
    public var slopeDomainDBPerOctave: ClosedRange<Double>
    public var maximumProfileDistance: Double
    public var dominantFundamentalMarginDB: Double
    public var weakEvenMarginDB: Double
    public var weakIsolatedPartialMarginDB: Double
    public var strongSecondPairMarginDB: Double
    public var octavialThirdSuppressionDB: Double
    public var richPartialRangeDB: Double
    public var richPartialMinimumCount: Int
    public var adjacentTransitionMaximumSemitones: Int
    public var adjacentTransitionThreshold: Double
    public var limitedObservationWeight: Double
    public var familyProfile: [TimbreFamilyProfilePoint]

    public init(
        targetSampleRateHz: Double,
        fftSizes: [Int],
        targetFundamentalCycles: Double,
        minimumWindowSeconds: Double,
        maximumWindowSeconds: Double,
        frameOverlapFraction: Double,
        maximumAveragedFrames: Int,
        maximumStableDurationSeconds: Double,
        maximumPartialCount: Int,
        maximumPartialFrequencyHz: Double,
        localSignalToNoiseThresholdDB: Double,
        minimumMeasuredPitchConfidence: Double,
        minimumDetectedPartials: Int,
        minimumRankObservationCount: Int,
        slopeExponent: Double,
        slopeSignConvention: String,
        centroidDomain: ClosedRange<Double>,
        slopeDomainDBPerOctave: ClosedRange<Double>,
        maximumProfileDistance: Double,
        dominantFundamentalMarginDB: Double,
        weakEvenMarginDB: Double,
        weakIsolatedPartialMarginDB: Double,
        strongSecondPairMarginDB: Double,
        octavialThirdSuppressionDB: Double,
        richPartialRangeDB: Double,
        richPartialMinimumCount: Int,
        adjacentTransitionMaximumSemitones: Int,
        adjacentTransitionThreshold: Double,
        limitedObservationWeight: Double,
        familyProfile: [TimbreFamilyProfilePoint]
    ) {
        self.targetSampleRateHz = targetSampleRateHz
        self.fftSizes = fftSizes
        self.targetFundamentalCycles = targetFundamentalCycles
        self.minimumWindowSeconds = minimumWindowSeconds
        self.maximumWindowSeconds = maximumWindowSeconds
        self.frameOverlapFraction = frameOverlapFraction
        self.maximumAveragedFrames = maximumAveragedFrames
        self.maximumStableDurationSeconds = maximumStableDurationSeconds
        self.maximumPartialCount = maximumPartialCount
        self.maximumPartialFrequencyHz = maximumPartialFrequencyHz
        self.localSignalToNoiseThresholdDB = localSignalToNoiseThresholdDB
        self.minimumMeasuredPitchConfidence = minimumMeasuredPitchConfidence
        self.minimumDetectedPartials = minimumDetectedPartials
        self.minimumRankObservationCount = minimumRankObservationCount
        self.slopeExponent = slopeExponent
        self.slopeSignConvention = slopeSignConvention
        self.centroidDomain = centroidDomain
        self.slopeDomainDBPerOctave = slopeDomainDBPerOctave
        self.maximumProfileDistance = maximumProfileDistance
        self.dominantFundamentalMarginDB = dominantFundamentalMarginDB
        self.weakEvenMarginDB = weakEvenMarginDB
        self.weakIsolatedPartialMarginDB = weakIsolatedPartialMarginDB
        self.strongSecondPairMarginDB = strongSecondPairMarginDB
        self.octavialThirdSuppressionDB = octavialThirdSuppressionDB
        self.richPartialRangeDB = richPartialRangeDB
        self.richPartialMinimumCount = richPartialMinimumCount
        self.adjacentTransitionMaximumSemitones = adjacentTransitionMaximumSemitones
        self.adjacentTransitionThreshold = adjacentTransitionThreshold
        self.limitedObservationWeight = limitedObservationWeight
        self.familyProfile = familyProfile
    }
}

public enum TimbreMethodology {
    public static let contractVersion = "orgrec-timbre-analysis/2"
    public static let algorithmVersion = "orgrec-harmonic-ltas/2"
    public static let familyProfileVersion = "orgrec-hergert-family-profile/1"
    public static let targetSampleRate = 48_000.0
    public static let slopeExponent = 1.729
    public static let maximumPartialCount = 20
    public static let familyProfile: [TimbreFamilyProfilePoint] = [
        TimbreFamilyProfilePoint(family: .flute, centroidCenter: 1.10, slopeCenterDBPerOctave: -21, centroidScale: 0.38, slopeScaleDBPerOctave: 7),
        TimbreFamilyProfilePoint(family: .diapason, centroidCenter: 1.50, slopeCenterDBPerOctave: -12, centroidScale: 0.48, slopeScaleDBPerOctave: 6),
        TimbreFamilyProfilePoint(family: .string, centroidCenter: 2.55, slopeCenterDBPerOctave: -4, centroidScale: 0.85, slopeScaleDBPerOctave: 6),
        TimbreFamilyProfilePoint(family: .reed, centroidCenter: 4.00, slopeCenterDBPerOctave: -4, centroidScale: 1.65, slopeScaleDBPerOctave: 8),
    ]
    public static let parameters = TimbreAnalysisParameters(
        targetSampleRateHz: 48_000,
        fftSizes: [8_192, 16_384, 32_768, 65_536],
        targetFundamentalCycles: 24,
        minimumWindowSeconds: 0.17,
        maximumWindowSeconds: 1.365,
        frameOverlapFraction: 0.5,
        maximumAveragedFrames: 160,
        maximumStableDurationSeconds: 10,
        maximumPartialCount: 20,
        maximumPartialFrequencyHz: 20_000,
        localSignalToNoiseThresholdDB: 6,
        minimumMeasuredPitchConfidence: 0.35,
        minimumDetectedPartials: 5,
        minimumRankObservationCount: 3,
        slopeExponent: 1.729,
        slopeSignConvention: "positive-for-ascending-adjacent-partials",
        centroidDomain: 0.95...12,
        slopeDomainDBPerOctave: -70...45,
        maximumProfileDistance: 3.25,
        dominantFundamentalMarginDB: 6,
        weakEvenMarginDB: 6,
        weakIsolatedPartialMarginDB: 8,
        strongSecondPairMarginDB: 6,
        octavialThirdSuppressionDB: 8,
        richPartialRangeDB: 15,
        richPartialMinimumCount: 4,
        adjacentTransitionMaximumSemitones: 4,
        adjacentTransitionThreshold: 2.5,
        limitedObservationWeight: 0.35,
        familyProfile: familyProfile
    )
    public static let parameterSHA256 = (try? OrgRecCoding.lineEncoder.encode(parameters))?.sha256Hex ?? "unavailable"

    public static let publications: [TimbrePublicationReference] = [
        TimbrePublicationReference(
            shortCitation: "Hergert & Höper (2023)",
            title: "Envelope Functions for Sound Spectra of Pipe Organ Ranks and the Influence of Pitch on Tonal Timbre",
            doi: "10.1121/2.0001673",
            contribution: "Steady-state LTAS, up to 20 harmonic partials, the unitless spectral centroid c/f₁, the q = 1.729 weighted adjacent-partial slope, pitch trajectories, and the evidence for broad tone-family regions."
        ),
        TimbrePublicationReference(
            shortCitation: "Hergert & Haverkamp (2023)",
            title: "Tonal Timbre Variations of Historical Recorders and Transverse Flutes Compared to Pipe Organ Ranks",
            doi: "10.61782/fa.2023.0327",
            contribution: "The lowest-five-partial pattern vocabulary: dominant fundamental, weak even partials, weak second, weak fourth, harmonically rich, and strong-second/octavial spectra; also the warning that two scalar timbre measures do not distinguish every pattern."
        ),
        TimbrePublicationReference(
            shortCitation: "Hergert (2023)",
            title: "Design Principles of Pipe Organ Mixtures – viewed from a psychoacoustic Position",
            doi: "10.1121/2.0001671",
            contribution: "The compound-stop scope gate: mixture registrations require analysis of pitch salience, ERB interactions, composition, and breaks, so a single-fundamental rank-family classifier is not applied."
        ),
        TimbrePublicationReference(
            shortCitation: "Hergert & Hale (2023)",
            title: "A Review of Technical Inventions to include deep Bass Tones into Pipe Organs despite Space Constraints",
            doi: "10.1121/2.0001672",
            contribution: "Interpretation of abrupt bass-to-treble timbre transitions: shortened, hybrid, resultant, or otherwise changed bass constructions can create real discontinuities and must be reviewed rather than smoothed away."
        ),
        TimbrePublicationReference(
            shortCitation: "Hergert (2024)",
            title: "Targeted detuning aiming for sensory pleasantness – A case study of Pipe Organs and Accordions",
            doi: "10.1051/aacus/2024020",
            contribution: "The detuned/celeste scope gate: beating and fluctuation strength are temporal, multi-source phenomena and are not evidence for a single-pipe spectral family."
        ),
    ]
}

public struct TimbrePartialMeasurement: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { harmonicNumber }
    public var harmonicNumber: Int
    public var frequencyHz: Double
    public var relativeLevelDB: Double
    public var energyFraction: Double
    public var localSignalToNoiseDB: Double

    public init(
        harmonicNumber: Int,
        frequencyHz: Double,
        relativeLevelDB: Double,
        energyFraction: Double,
        localSignalToNoiseDB: Double
    ) {
        self.harmonicNumber = harmonicNumber
        self.frequencyHz = frequencyHz
        self.relativeLevelDB = relativeLevelDB
        self.energyFraction = energyFraction
        self.localSignalToNoiseDB = localSignalToNoiseDB
    }
}

public struct TimbreFamilyCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: PipeTimbreFamily { family }
    public var family: PipeTimbreFamily
    public var relativeSupport: Double
    public var normalizedDistance: Double
    public var relativeSupportStandardDeviation: Double?
    public var effectiveObservationCount: Double?
    public var explanation: String

    public init(
        family: PipeTimbreFamily,
        relativeSupport: Double,
        normalizedDistance: Double,
        relativeSupportStandardDeviation: Double? = nil,
        effectiveObservationCount: Double? = nil,
        explanation: String
    ) {
        self.family = family
        self.relativeSupport = relativeSupport
        self.normalizedDistance = normalizedDistance
        self.relativeSupportStandardDeviation = relativeSupportStandardDeviation
        self.effectiveObservationCount = effectiveObservationCount
        self.explanation = explanation
    }

    private enum CodingKeys: String, CodingKey {
        case family
        case relativeSupport
        case legacyProbability = "probability"
        case normalizedDistance
        case relativeSupportStandardDeviation
        case effectiveObservationCount
        case explanation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        family = try container.decode(PipeTimbreFamily.self, forKey: .family)
        relativeSupport = try container.decodeIfPresent(Double.self, forKey: .relativeSupport)
            ?? container.decode(Double.self, forKey: .legacyProbability)
        normalizedDistance = try container.decode(Double.self, forKey: .normalizedDistance)
        relativeSupportStandardDeviation = try container.decodeIfPresent(Double.self, forKey: .relativeSupportStandardDeviation)
        effectiveObservationCount = try container.decodeIfPresent(Double.self, forKey: .effectiveObservationCount)
        explanation = try container.decode(String.self, forKey: .explanation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(family, forKey: .family)
        try container.encode(relativeSupport, forKey: .relativeSupport)
        try container.encode(normalizedDistance, forKey: .normalizedDistance)
        try container.encodeIfPresent(relativeSupportStandardDeviation, forKey: .relativeSupportStandardDeviation)
        try container.encodeIfPresent(effectiveObservationCount, forKey: .effectiveObservationCount)
        try container.encode(explanation, forKey: .explanation)
    }
}

public struct PipeTimbreObservation: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var takeID: UUID
    public var roadmapItemID: UUID
    public var midiNote: Int?
    public var noteName: String?
    public var sourceAudioSHA256: String
    public var sourceAnalysisRunID: UUID?
    public var referenceChannel: Int
    public var segmentStartSeconds: Double
    public var segmentEndSeconds: Double
    public var resampledRateHz: Double
    public var fftSize: Int
    public var averagedFrameCount: Int
    public var fundamentalFrequencyHz: Double
    public var fundamentalSource: TimbreFundamentalSource
    public var partials: [TimbrePartialMeasurement]
    public var normalizedSpectralCentroid: Double?
    public var weightedAverageSlopeDBPerOctave: Double?
    public var evenToOddEnergyRatioDB: Double?
    public var firstFivePrototype: FirstFivePartialPrototype
    public var familyCandidates: [TimbreFamilyCandidate]
    public var applicability: TimbreAnalysisApplicability
    public var outOfDistribution: Bool?
    public var warnings: [String]

    public init(
        id: UUID = UUID(),
        takeID: UUID,
        roadmapItemID: UUID,
        midiNote: Int?,
        noteName: String?,
        sourceAudioSHA256: String,
        sourceAnalysisRunID: UUID?,
        referenceChannel: Int,
        segmentStartSeconds: Double,
        segmentEndSeconds: Double,
        resampledRateHz: Double,
        fftSize: Int,
        averagedFrameCount: Int,
        fundamentalFrequencyHz: Double,
        fundamentalSource: TimbreFundamentalSource,
        partials: [TimbrePartialMeasurement],
        normalizedSpectralCentroid: Double?,
        weightedAverageSlopeDBPerOctave: Double?,
        evenToOddEnergyRatioDB: Double?,
        firstFivePrototype: FirstFivePartialPrototype,
        familyCandidates: [TimbreFamilyCandidate],
        applicability: TimbreAnalysisApplicability,
        outOfDistribution: Bool? = nil,
        warnings: [String]
    ) {
        self.id = id
        self.takeID = takeID
        self.roadmapItemID = roadmapItemID
        self.midiNote = midiNote
        self.noteName = noteName
        self.sourceAudioSHA256 = sourceAudioSHA256
        self.sourceAnalysisRunID = sourceAnalysisRunID
        self.referenceChannel = referenceChannel
        self.segmentStartSeconds = segmentStartSeconds
        self.segmentEndSeconds = segmentEndSeconds
        self.resampledRateHz = resampledRateHz
        self.fftSize = fftSize
        self.averagedFrameCount = averagedFrameCount
        self.fundamentalFrequencyHz = fundamentalFrequencyHz
        self.fundamentalSource = fundamentalSource
        self.partials = partials
        self.normalizedSpectralCentroid = normalizedSpectralCentroid
        self.weightedAverageSlopeDBPerOctave = weightedAverageSlopeDBPerOctave
        self.evenToOddEnergyRatioDB = evenToOddEnergyRatioDB
        self.firstFivePrototype = firstFivePrototype
        self.familyCandidates = familyCandidates
        self.applicability = applicability
        self.outOfDistribution = outOfDistribution
        self.warnings = warnings
    }
}

public struct TimbreAnalysisReport: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var algorithmVersion: String
    public var familyProfileVersion: String
    public var id: UUID
    public var analyzedAt: Date
    public var mode: TimbreAnalysisMode
    public var rankComponentID: String
    public var rankLabel: String
    public var observations: [PipeTimbreObservation]
    public var familyCandidates: [TimbreFamilyCandidate]
    /// Held-out-instrument calibrated result from the optional empirical model.
    /// The legacy distance support remains separately encoded for backwards
    /// comparison and must never be presented as a calibrated probability.
    public var empiricalClassification: EmpiricalTimbreClassification?
    public var pitchDependentFingerprint: PitchDependentRankFingerprint?
    public var applicability: TimbreAnalysisApplicability
    public var warnings: [String]
    public var publicationDOIs: [String]
    public var parameters: TimbreAnalysisParameters?
    public var parameterSHA256: String?
    public var software: OrgRecSoftwareMetadata?

    public init(
        contractVersion: String = TimbreMethodology.contractVersion,
        algorithmVersion: String = TimbreMethodology.algorithmVersion,
        familyProfileVersion: String = TimbreMethodology.familyProfileVersion,
        id: UUID = UUID(),
        analyzedAt: Date = .now,
        mode: TimbreAnalysisMode,
        rankComponentID: String,
        rankLabel: String,
        observations: [PipeTimbreObservation],
        familyCandidates: [TimbreFamilyCandidate],
        empiricalClassification: EmpiricalTimbreClassification? = nil,
        pitchDependentFingerprint: PitchDependentRankFingerprint? = nil,
        applicability: TimbreAnalysisApplicability,
        warnings: [String],
        publicationDOIs: [String] = TimbreMethodology.publications.map(\.doi),
        parameters: TimbreAnalysisParameters? = TimbreMethodology.parameters,
        parameterSHA256: String? = TimbreMethodology.parameterSHA256,
        software: OrgRecSoftwareMetadata? = OrgRecSoftware.current
    ) {
        self.contractVersion = contractVersion
        self.algorithmVersion = algorithmVersion
        self.familyProfileVersion = familyProfileVersion
        self.id = id
        self.analyzedAt = analyzedAt
        self.mode = mode
        self.rankComponentID = rankComponentID
        self.rankLabel = rankLabel
        self.observations = observations
        self.familyCandidates = familyCandidates
        self.empiricalClassification = empiricalClassification
        self.pitchDependentFingerprint = pitchDependentFingerprint
        self.applicability = applicability
        self.warnings = warnings
        self.publicationDOIs = publicationDOIs
        self.parameters = parameters
        self.parameterSHA256 = parameterSHA256
        self.software = software
    }
}

public struct TimbreAnalysisInput: Sendable {
    public var fileURL: URL
    public var takeID: UUID
    public var roadmapItemID: UUID
    public var midiNote: Int?
    public var noteName: String?
    public var expectedFrequencyHz: Double?
    public var measuredFrequencyHz: Double?
    public var measuredConfidence: Double?
    public var sourceAudioSHA256: String?
    public var sourceAnalysisRunID: UUID?
    public var referenceChannel: Int
    public var sustainStartSeconds: Double?
    public var soundOffsetSeconds: Double?
    public var keyUpSeconds: Double?

    public init(
        fileURL: URL,
        takeID: UUID,
        roadmapItemID: UUID,
        midiNote: Int?,
        noteName: String?,
        expectedFrequencyHz: Double?,
        measuredFrequencyHz: Double?,
        measuredConfidence: Double?,
        sourceAudioSHA256: String?,
        sourceAnalysisRunID: UUID?,
        referenceChannel: Int,
        sustainStartSeconds: Double?,
        soundOffsetSeconds: Double?,
        keyUpSeconds: Double?
    ) {
        self.fileURL = fileURL
        self.takeID = takeID
        self.roadmapItemID = roadmapItemID
        self.midiNote = midiNote
        self.noteName = noteName
        self.expectedFrequencyHz = expectedFrequencyHz
        self.measuredFrequencyHz = measuredFrequencyHz
        self.measuredConfidence = measuredConfidence
        self.sourceAudioSHA256 = sourceAudioSHA256
        self.sourceAnalysisRunID = sourceAnalysisRunID
        self.referenceChannel = referenceChannel
        self.sustainStartSeconds = sustainStartSeconds
        self.soundOffsetSeconds = soundOffsetSeconds
        self.keyUpSeconds = keyUpSeconds
    }
}

public struct TimbreFeatureResult: Hashable, Sendable {
    public var normalizedSpectralCentroid: Double?
    public var weightedAverageSlopeDBPerOctave: Double?
    public var evenToOddEnergyRatioDB: Double?
    public var firstFivePrototype: FirstFivePartialPrototype

    public init(
        normalizedSpectralCentroid: Double?,
        weightedAverageSlopeDBPerOctave: Double?,
        evenToOddEnergyRatioDB: Double?,
        firstFivePrototype: FirstFivePartialPrototype
    ) {
        self.normalizedSpectralCentroid = normalizedSpectralCentroid
        self.weightedAverageSlopeDBPerOctave = weightedAverageSlopeDBPerOctave
        self.evenToOddEnergyRatioDB = evenToOddEnergyRatioDB
        self.firstFivePrototype = firstFivePrototype
    }
}

public struct TimbreFamilyClassificationResult: Hashable, Sendable {
    public var candidates: [TimbreFamilyCandidate]
    public var outOfDistributionReason: String?

    public init(candidates: [TimbreFamilyCandidate], outOfDistributionReason: String?) {
        self.candidates = candidates
        self.outOfDistributionReason = outOfDistributionReason
    }
}

public enum TimbreFeatureCalculator {
    /// Calculates the Hergert timbre coordinates directly from harmonic levels.
    /// A nil entry represents a partial below the local noise threshold.
    public static func calculate(relativePartialLevelsDB levels: [Double?]) -> TimbreFeatureResult {
        let usable = levels.enumerated().compactMap { index, level -> (Int, Double, Double)? in
            guard let level, level.isFinite else { return nil }
            return (index + 1, level, pow(10, level / 10))
        }
        let total = usable.reduce(0) { $0 + $1.2 }
        let centroid = total > 0 ? usable.reduce(0) { $0 + Double($1.0) * $1.2 } / total : nil

        var slopeNumerator = 0.0
        var slopeDenominator = 0.0
        if levels.count >= 2 {
            for lowerIndex in 0..<(levels.count - 1) {
                guard let lower = levels[lowerIndex], let upper = levels[lowerIndex + 1] else { continue }
                let n = lowerIndex + 1
                let octaveDistance = log2(Double(n + 1) / Double(n))
                guard octaveDistance > 0 else { continue }
                let weight = pow(Double(n), -TimbreMethodology.slopeExponent)
                // Plot-consistent sign convention for Eq. 13: an ascending
                // adjacent pair is positive; a descending pair is negative.
                slopeNumerator += weight * (upper - lower) / octaveDistance
                slopeDenominator += weight
            }
        }
        let slope = slopeDenominator > 0 ? slopeNumerator / slopeDenominator : nil
        let odd = usable.filter { !$0.0.isMultiple(of: 2) }.reduce(0) { $0 + $1.2 }
        let even = usable.filter { $0.0.isMultiple(of: 2) }.reduce(0) { $0 + $1.2 }
        let evenToOdd = odd > 0 && even > 0 ? 10 * log10(even / odd) : nil
        return TimbreFeatureResult(
            normalizedSpectralCentroid: centroid,
            weightedAverageSlopeDBPerOctave: slope,
            evenToOddEnergyRatioDB: evenToOdd,
            firstFivePrototype: prototype(levels: Array(levels.prefix(5)))
        )
    }

    public static func prototype(levels original: [Double?]) -> FirstFivePartialPrototype {
        var levels = original
        if levels.count < 5 { levels.append(contentsOf: repeatElement(nil, count: 5 - levels.count)) }
        guard levels.compactMap({ $0 }).count >= 4 else { return .indeterminate }
        let l = levels.map { $0 ?? -120 }
        let highestOther = l[1...4].max() ?? -120
        let parameters = TimbreMethodology.parameters
        if l[0] - highestOther >= parameters.dominantFundamentalMarginDB { return .dominantFundamental }
        let oddMean = (l[0] + l[2] + l[4]) / 3
        let evenMean = (l[1] + l[3]) / 2
        if oddMean - evenMean >= parameters.weakEvenMarginDB { return .weakEvenChalumeau }
        if ((l[0] + l[2]) / 2) - l[1] >= parameters.weakIsolatedPartialMarginDB { return .weakSecond }
        if ((l[2] + l[4]) / 2) - l[3] >= parameters.weakIsolatedPartialMarginDB { return .weakFourth }
        if min(l[0], l[1]) >= (l[0...4].max() ?? 0) - parameters.strongSecondPairMarginDB,
           (l[0...1].max() ?? 0) - l[2] >= parameters.octavialThirdSuppressionDB {
            return .strongSecondOctavial
        }
        let peak = l.max() ?? 0
        if l.filter({ $0 >= peak - parameters.richPartialRangeDB }).count >= parameters.richPartialMinimumCount {
            return .richInHarmonics
        }
        return .indeterminate
    }
}

public actor TimbreAnalysisEngine {
    public init() {}

    public func analyze(input: TimbreAnalysisInput, mode: TimbreAnalysisMode) throws -> PipeTimbreObservation {
        let parameters = TimbreMethodology.parameters
        let measuredIsUsable = (input.measuredConfidence ?? 0) >= parameters.minimumMeasuredPitchConfidence
            && input.measuredConfidence?.isFinite == true
            && input.measuredFrequencyHz?.isFinite == true && (input.measuredFrequencyHz ?? 0) > 0
        guard let fundamental = measuredIsUsable ? input.measuredFrequencyHz : input.expectedFrequencyHz,
              fundamental.isFinite, fundamental > 0 else {
            throw OrgRecError.unsupportedAudio("Timbre analysis requires a measured or documented fundamental frequency.")
        }
        let source: TimbreFundamentalSource = measuredIsUsable ? .measuredConsensus : .roadmapExpectation
        let file = try AVAudioFile(forReading: input.fileURL)
        let format = file.processingFormat
        let duration = Double(file.length) / format.sampleRate
        guard duration > 0 else { throw OrgRecError.unsupportedAudio("The recording is empty.") }
        let selectedChannel = max(0, min(Int(format.channelCount) - 1, input.referenceChannel))
        let region = SpectrumSegmentation.steadyRegion(
            duration: duration,
            sustainStart: input.sustainStartSeconds,
            soundOffset: input.soundOffsetSeconds,
            keyUp: input.keyUpSeconds,
            maximumDuration: parameters.maximumStableDurationSeconds
        )
        let samples = try Self.read(file: file, channel: selectedChannel, start: region.start, end: region.end)
        guard samples.count >= 512 else {
            throw OrgRecError.unsupportedAudio("The stable sustain is too short for timbre analysis.")
        }
        let resampled = Self.resample(samples, from: format.sampleRate, to: TimbreMethodology.targetSampleRate)
        let fftSize = Self.adaptiveFFTSize(fundamental: fundamental, availableSamples: resampled.count)
        let spectrum = try Self.averagePowerSpectrum(samples: resampled, fftSize: fftSize)
        let extracted = Self.extractPartials(
            power: spectrum.power,
            sampleRate: TimbreMethodology.targetSampleRate,
            fftSize: fftSize,
            fundamental: fundamental
        )
        let accepted = extracted.filter { $0.snrDB >= parameters.localSignalToNoiseThresholdDB }
        let maximumLevel = accepted.map(\.levelDB).max() ?? 0
        let totalEnergy = accepted.reduce(0) { $0 + $1.power }
        let measurements = accepted.map { item in
            TimbrePartialMeasurement(
                harmonicNumber: item.harmonic,
                frequencyHz: item.frequency,
                relativeLevelDB: item.levelDB - maximumLevel,
                energyFraction: totalEnergy > 0 ? item.power / totalEnergy : 0,
                localSignalToNoiseDB: item.snrDB
            )
        }
        let byHarmonic = Dictionary(uniqueKeysWithValues: measurements.map { ($0.harmonicNumber, $0.relativeLevelDB) })
        let levels: [Double?] = (1...TimbreMethodology.maximumPartialCount).map { byHarmonic[$0] }
        let features = TimbreFeatureCalculator.calculate(relativePartialLevelsDB: levels)
        var warnings = region.limitations
        if source == .roadmapExpectation {
            warnings.append("The measured pitch was unavailable or low-confidence; harmonic bins use the roadmap frequency.")
        }
        if measurements.count < parameters.minimumDetectedPartials {
            warnings.append("Fewer than \(parameters.minimumDetectedPartials) harmonic partials exceeded the local \(Self.fixed(parameters.localSignalToNoiseThresholdDB, decimals: 0)) dB noise threshold.")
        }
        let applicable = features.normalizedSpectralCentroid != nil && features.weightedAverageSlopeDBPerOctave != nil
        var applicability: TimbreAnalysisApplicability = applicable
            ? (measurements.count >= parameters.minimumDetectedPartials && source == .measuredConsensus && region.limitations.isEmpty ? .applicable : .limited)
            : .notApplicable
        let classification = Self.classify(features: features)
        var candidates = mode == .familySuggestion && applicability != .notApplicable
            ? classification.candidates
            : []
        var outOfDistribution = false
        if mode == .familySuggestion, applicability != .notApplicable,
           let reason = classification.outOfDistributionReason {
            outOfDistribution = true
            applicability = .limited
            candidates = []
            warnings.append("Outside the supported family-profile domain: \(reason) No family support is reported.")
        }
        return PipeTimbreObservation(
            takeID: input.takeID,
            roadmapItemID: input.roadmapItemID,
            midiNote: input.midiNote,
            noteName: input.noteName,
            sourceAudioSHA256: try input.sourceAudioSHA256 ?? sha256(of: input.fileURL),
            sourceAnalysisRunID: input.sourceAnalysisRunID,
            referenceChannel: selectedChannel,
            segmentStartSeconds: region.start,
            segmentEndSeconds: region.end,
            resampledRateHz: TimbreMethodology.targetSampleRate,
            fftSize: fftSize,
            averagedFrameCount: spectrum.frameCount,
            fundamentalFrequencyHz: fundamental,
            fundamentalSource: source,
            partials: measurements,
            normalizedSpectralCentroid: features.normalizedSpectralCentroid,
            weightedAverageSlopeDBPerOctave: features.weightedAverageSlopeDBPerOctave,
            evenToOddEnergyRatioDB: features.evenToOddEnergyRatioDB,
            firstFivePrototype: features.firstFivePrototype,
            familyCandidates: candidates,
            applicability: applicability,
            outOfDistribution: mode == .familySuggestion ? outOfDistribution : nil,
            warnings: warnings
        )
    }

    public nonisolated static func report(
        mode: TimbreAnalysisMode,
        rankComponentID: String,
        rankLabel: String,
        observations: [PipeTimbreObservation],
        scopeApplicability: TimbreAnalysisApplicability = .applicable,
        scopeWarnings: [String] = [],
        empiricalModel: EmpiricalTimbreClassifierModel? = nil,
        fingerprintParameters: RankFingerprintParameters = RankFingerprintParameters()
    ) -> TimbreAnalysisReport {
        var warnings = scopeWarnings
        let ordered = observations.sorted { ($0.midiNote ?? .max) < ($1.midiNote ?? .max) }
        let parameters = TimbreMethodology.parameters
        if ordered.count < parameters.minimumRankObservationCount {
            warnings.append("Fewer than \(parameters.minimumRankObservationCount) usable pipes were analyzed; a rank-level trajectory cannot be established.")
        }
        var skippedWidePitchGap = false
        for pair in zip(ordered, ordered.dropFirst()) {
            guard let leftC = pair.0.normalizedSpectralCentroid,
                  let rightC = pair.1.normalizedSpectralCentroid,
                  let leftS = pair.0.weightedAverageSlopeDBPerOctave,
                  let rightS = pair.1.weightedAverageSlopeDBPerOctave else { continue }
            guard let leftMIDI = pair.0.midiNote, let rightMIDI = pair.1.midiNote else { continue }
            let semitoneGap = rightMIDI - leftMIDI
            guard semitoneGap > 0 else { continue }
            guard semitoneGap <= parameters.adjacentTransitionMaximumSemitones else {
                skippedWidePitchGap = true
                continue
            }
            let rawJump = hypot((rightC - leftC) / 1.2, (rightS - leftS) / 8)
            let pitchNormalizedJump = rawJump / sqrt(Double(semitoneGap))
            if pitchNormalizedJump > parameters.adjacentTransitionThreshold {
                let left = pair.0.noteName ?? pair.0.midiNote.map(String.init) ?? "one pipe"
                let right = pair.1.noteName ?? pair.1.midiNote.map(String.init) ?? "the next pipe"
                warnings.append("Abrupt timbre transition between \(left) and \(right); review voicing and any construction change in this rank.")
            }
        }
        if skippedWidePitchGap {
            warnings.append("A pitch gap exceeded \(parameters.adjacentTransitionMaximumSemitones) semitones; no adjacent-pipe transition claim was made across that gap.")
        }
        let familyCandidates: [TimbreFamilyCandidate]
        if mode == .familySuggestion && scopeApplicability != .notApplicable {
            let families: [PipeTimbreFamily] = [.flute, .diapason, .string, .reed]
            let means = families.compactMap { family -> (PipeTimbreFamily, Double, Double, Double, Double)? in
                let values = observations.compactMap { observation -> (Double, Double, Double)? in
                    guard let candidate = observation.familyCandidates.first(where: { $0.family == family }) else { return nil }
                    let weight: Double
                    switch observation.applicability {
                    case .applicable: weight = 1
                    case .limited: weight = parameters.limitedObservationWeight
                    case .notApplicable: weight = 0
                    }
                    return weight > 0 ? (candidate.relativeSupport, candidate.normalizedDistance, weight) : nil
                }
                guard values.isEmpty == false else { return nil }
                let weightSum = values.reduce(0) { $0 + $1.2 }
                let support = values.reduce(0) { $0 + $1.0 * $1.2 } / weightSum
                let distance = values.reduce(0) { $0 + $1.1 * $1.2 } / weightSum
                let variance = values.reduce(0) { $0 + $1.2 * pow($1.0 - support, 2) } / weightSum
                let weightSquares = values.reduce(0) { $0 + $1.2 * $1.2 }
                let effectiveCount = weightSum * weightSum / max(weightSquares, 1e-12)
                return (family, support, distance, sqrt(max(0, variance)), effectiveCount)
            }
            let total = means.reduce(0) { $0 + $1.1 }
            familyCandidates = means.map { family, support, distance, standardDeviation, effectiveCount in
                TimbreFamilyCandidate(
                    family: family,
                    relativeSupport: total > 0 ? support / total : 0,
                    normalizedDistance: distance,
                    relativeSupportStandardDeviation: total > 0 ? standardDeviation / total : nil,
                    effectiveObservationCount: effectiveCount,
                    explanation: "Quality-weighted mean support; limited observations have weight \(fixed(parameters.limitedObservationWeight, decimals: 2))."
                )
            }.sorted { $0.relativeSupport > $1.relativeSupport }
        } else {
            familyCandidates = []
        }
        let observationApplicability: TimbreAnalysisApplicability
        if observations.isEmpty || observations.allSatisfy({ $0.applicability == .notApplicable }) {
            observationApplicability = .notApplicable
        } else if observations.count < parameters.minimumRankObservationCount || observations.contains(where: { $0.applicability != .applicable }) {
            observationApplicability = .limited
        } else {
            observationApplicability = .applicable
        }
        let applicability: TimbreAnalysisApplicability
        if scopeApplicability == .notApplicable || observationApplicability == .notApplicable { applicability = .notApplicable }
        else if scopeApplicability == .limited || observationApplicability == .limited { applicability = .limited }
        else { applicability = .applicable }
        let empirical = mode == .familySuggestion && scopeApplicability != .notApplicable
            ? (empiricalModel ?? (try? EmpiricalTimbreClassifierModel.bundled()) ?? nil)?.classify(observations: ordered)
            : nil
        let fingerprint = scopeApplicability == .notApplicable ? nil : RankFingerprintAnalyzer.analyze(
            rankComponentID: rankComponentID,
            rankLabel: rankLabel,
            observations: ordered,
            parameters: fingerprintParameters
        )
        if mode == .familySuggestion, scopeApplicability != .notApplicable, empirical == nil {
            warnings.append("No compatible empirical timbre model is installed; only the legacy uncalibrated distance support is available.")
        } else if let reason = empirical?.reason {
            warnings.append("Empirical classifier abstained: \(reason)")
        }
        warnings.append(contentsOf: fingerprint?.warnings ?? [])
        return TimbreAnalysisReport(
            mode: mode,
            rankComponentID: rankComponentID,
            rankLabel: rankLabel,
            observations: ordered,
            familyCandidates: familyCandidates,
            empiricalClassification: empirical,
            pitchDependentFingerprint: fingerprint,
            applicability: applicability,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public nonisolated static func classify(features: TimbreFeatureResult) -> TimbreFamilyClassificationResult {
        let candidates = familyCandidates(features: features)
        let reason = outOfDistributionReason(features: features, candidates: candidates)
        return TimbreFamilyClassificationResult(
            candidates: reason == nil ? candidates : [],
            outOfDistributionReason: reason
        )
    }

    public nonisolated static func scopeAssessment(rankLabel: String, componentKind: String) -> (TimbreAnalysisApplicability, [String]) {
        let value = "\(rankLabel) \(componentKind)".lowercased()
        if OrganologyClassifier.isCompoundStop(label: rankLabel, kind: componentKind) {
            return (.notApplicable, ["Compound/mixture ranks are outside the single-fundamental family profile; analyze their composition, breaks, ERB interaction, and pitch salience instead."])
        }
        let detunedTerms = ["celeste", "céleste", "schweb", "unda maris", "voix céleste"]
        if detunedTerms.contains(where: value.contains) {
            return (.notApplicable, ["Detuned/celeste ranks require joint temporal beating and fluctuation-strength analysis, not a single-pipe family suggestion."])
        }
        return (.applicable, [])
    }

    private static func read(file: AVAudioFile, channel: Int, start: Double, end: Double) throws -> [Float] {
        let rate = file.processingFormat.sampleRate
        let startFrame = max(Int64(0), min(file.length, Int64((start * rate).rounded(.down))))
        let endFrame = max(startFrame, min(file.length, Int64((end * rate).rounded(.up))))
        let total = endFrame - startFrame
        guard total > 0 else { return [] }
        file.framePosition = startFrame
        var output: [Float] = []
        output.reserveCapacity(Int(total))
        var remaining = total
        while remaining > 0 {
            let count = AVAudioFrameCount(min(65_536, remaining))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: count) else {
                throw OrgRecError.unsupportedAudio("Cannot allocate the timbre-analysis audio buffer.")
            }
            try file.read(into: buffer, frameCount: count)
            guard buffer.frameLength > 0, let pointer = buffer.floatChannelData?[channel] else { break }
            output.append(contentsOf: UnsafeBufferPointer(start: pointer, count: Int(buffer.frameLength)))
            remaining -= Int64(buffer.frameLength)
        }
        return output
    }

    private static func adaptiveFFTSize(fundamental: Double, availableSamples: Int) -> Int {
        let parameters = TimbreMethodology.parameters
        let desired = Int(ceil(parameters.targetSampleRateHz * min(
            parameters.maximumWindowSeconds,
            max(parameters.minimumWindowSeconds, parameters.targetFundamentalCycles / fundamental)
        )))
        let choices = parameters.fftSizes
        let available = choices.filter { $0 <= availableSamples }
        return available.min(by: { abs($0 - desired) < abs($1 - desired) }) ?? max(512, 1 << Int(floor(log2(Double(availableSamples)))))
    }

    private static func averagePowerSpectrum(samples: [Float], fftSize: Int) throws -> (power: [Double], frameCount: Int) {
        guard samples.count >= fftSize, fftSize >= 512 else {
            throw OrgRecError.unsupportedAudio("The stable sustain is too short for the adaptive LTAS window.")
        }
        let log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw OrgRecError.unsupportedAudio("Cannot initialize the LTAS Fourier transform.")
        }
        defer { vDSP_destroy_fftsetup(setup) }
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        let hop = max(1, Int(Double(fftSize) * (1 - TimbreMethodology.parameters.frameOverlapFraction)))
        let possible = 1 + (samples.count - fftSize) / hop
        let decimation = max(1, Int(ceil(Double(possible) / Double(TimbreMethodology.parameters.maximumAveragedFrames))))
        var accumulated = [Double](repeating: 0, count: fftSize / 2)
        var frameCount = 0
        for frameIndex in stride(from: 0, to: possible, by: decimation) {
            let offset = frameIndex * hop
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
            for index in accumulated.indices {
                accumulated[index] += Double(real[index] * real[index] + imag[index] * imag[index])
            }
            frameCount += 1
        }
        guard frameCount > 0 else { throw OrgRecError.unsupportedAudio("No stable LTAS frames could be averaged.") }
        return (accumulated.map { $0 / Double(frameCount) }, frameCount)
    }

    private struct ExtractedPartial {
        var harmonic: Int
        var frequency: Double
        var power: Double
        var levelDB: Double
        var snrDB: Double
    }

    private static func extractPartials(power: [Double], sampleRate: Double, fftSize: Int, fundamental: Double) -> [ExtractedPartial] {
        let binWidth = sampleRate / Double(fftSize)
        var result: [ExtractedPartial] = []
        let parameters = TimbreMethodology.parameters
        for harmonic in 1...parameters.maximumPartialCount {
            let target = fundamental * Double(harmonic)
            guard target < min(parameters.maximumPartialFrequencyHz, sampleRate * 0.47) else { break }
            let center = Int((target / binWidth).rounded())
            let radius = max(1, Int(ceil(max(binWidth * 1.5, fundamental * 0.035) / binWidth)))
            guard let region = SpectrumSegmentation.harmonicBins(
                harmonic: harmonic, fundamental: fundamental, binWidth: binWidth,
                toleranceHz: Double(radius) * binWidth, lowerBin: 1, upperBin: power.count - 2
            ) else { continue }
            let lower = region.lowerBound, upper = region.upperBound
            guard let peakBin = (lower...upper).max(by: { power[$0] < power[$1] }) else { continue }
            let peakPower = max(power[peakBin], 1e-24)
            let noiseLower = max(1, center - radius * 5)
            let noiseUpper = min(power.count - 2, center + radius * 5)
            let noiseValues = (noiseLower...noiseUpper).filter { abs($0 - peakBin) > radius }.map { power[$0] }.sorted()
            let noise = noiseValues.isEmpty ? 1e-24 : max(noiseValues[noiseValues.count / 2], 1e-24)
            // Integrate the Hann main lobe to avoid bin-phase scalloping in
            // relative harmonic power; never integrate a neighboring harmonic.
            guard let ownership = SpectrumSegmentation.harmonicBins(
                harmonic: harmonic, fundamental: fundamental, binWidth: binWidth,
                toleranceHz: fundamental / 2, lowerBin: 1, upperBin: power.count - 2
            ) else { continue }
            let lobe = max(ownership.lowerBound, peakBin - 2)...min(ownership.upperBound, peakBin + 2)
            let integratedPower = max(1e-24, power[lobe].reduce(0, +) - Double(lobe.count) * noise)
            let left = log(max(1e-24, power[peakBin - 1]))
            let centerPower = log(peakPower)
            let right = log(max(1e-24, power[peakBin + 1]))
            let denominator = left - 2 * centerPower + right
            let correction = abs(denominator) > 1e-12 ? min(0.5, max(-0.5, 0.5 * (left - right) / denominator)) : 0
            result.append(ExtractedPartial(
                harmonic: harmonic,
                frequency: (Double(peakBin) + correction) * binWidth,
                power: integratedPower,
                levelDB: 10 * log10(integratedPower),
                snrDB: 10 * log10(peakPower / noise)
            ))
        }
        return result
    }

    private nonisolated static func familyCandidates(features: TimbreFeatureResult) -> [TimbreFamilyCandidate] {
        guard let centroid = features.normalizedSpectralCentroid,
              let slope = features.weightedAverageSlopeDBPerOctave else { return [] }
        // Centers are a transparent OrgRec decision profile placed in the broad
        // family regions reported by Hergert & Höper; they are not fitted class
        // probabilities and intentionally do not name an exact stop.
        let raw = TimbreMethodology.familyProfile.map { point -> (PipeTimbreFamily, Double, Double) in
            var distance = hypot(
                (centroid - point.centroidCenter) / point.centroidScale,
                (slope - point.slopeCenterDBPerOctave) / point.slopeScaleDBPerOctave
            )
            switch (point.family, features.firstFivePrototype) {
            case (.flute, .dominantFundamental), (.flute, .weakEvenChalumeau), (.flute, .strongSecondOctavial): distance *= 0.75
            case (.string, .richInHarmonics): distance *= 0.82
            default: break
            }
            return (point.family, distance, exp(-0.5 * distance * distance))
        }
        let total = raw.reduce(0) { $0 + $1.2 }
        return raw.map { family, distance, likelihood in
            TimbreFamilyCandidate(
                family: family,
                relativeSupport: total > 0 ? likelihood / total : 0,
                normalizedDistance: distance,
                explanation: "Distance in the c/f₁–s plane using \(TimbreMethodology.familyProfileVersion); exact stop identity is not inferred."
            )
        }.sorted { $0.relativeSupport > $1.relativeSupport }
    }

    private nonisolated static func outOfDistributionReason(
        features: TimbreFeatureResult,
        candidates: [TimbreFamilyCandidate]
    ) -> String? {
        let parameters = TimbreMethodology.parameters
        guard let centroid = features.normalizedSpectralCentroid,
              let slope = features.weightedAverageSlopeDBPerOctave else {
            return "the two required timbre coordinates are incomplete"
        }
        guard parameters.centroidDomain.contains(centroid) else {
            return "c/f₁ = \(fixed(centroid, decimals: 2)) is outside \(fixed(parameters.centroidDomain.lowerBound, decimals: 2))–\(fixed(parameters.centroidDomain.upperBound, decimals: 2))"
        }
        guard parameters.slopeDomainDBPerOctave.contains(slope) else {
            return "s = \(fixed(slope, decimals: 1)) dB/oct is outside \(fixed(parameters.slopeDomainDBPerOctave.lowerBound, decimals: 1))–\(fixed(parameters.slopeDomainDBPerOctave.upperBound, decimals: 1)) dB/oct"
        }
        guard let nearest = candidates.map(\.normalizedDistance).min() else {
            return "no profile distance could be calculated"
        }
        return nearest > parameters.maximumProfileDistance
            ? "nearest normalized profile distance \(fixed(nearest, decimals: 2)) exceeds \(fixed(parameters.maximumProfileDistance, decimals: 2))"
            : nil
    }

    private nonisolated static func fixed(_ value: Double, decimals: Int) -> String {
        String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), decimals, value)
    }

    private static func resample(_ samples: [Float], from inputRate: Double, to outputRate: Double) -> [Float] {
        guard samples.isEmpty == false, abs(inputRate - outputRate) > 0.5 else { return samples }
        let outputCount = max(1, Int(Double(samples.count) * outputRate / inputRate))
        if let inputFormat = AVAudioFormat(standardFormatWithSampleRate: inputRate, channels: 1),
           let outputFormat = AVAudioFormat(standardFormatWithSampleRate: outputRate, channels: 1),
           let converter = AVAudioConverter(from: inputFormat, to: outputFormat),
           let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(samples.count)),
           let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: AVAudioFrameCount(max(samples.count, outputCount + 128))),
           let inputChannel = inputBuffer.floatChannelData?[0] {
            inputBuffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { pointer in
                if let base = pointer.baseAddress { inputChannel.update(from: base, count: samples.count) }
            }
            if (try? converter.convert(to: outputBuffer, from: inputBuffer)) != nil,
               let outputChannel = outputBuffer.floatChannelData?[0], outputBuffer.frameLength > 0 {
                return Array(UnsafeBufferPointer(start: outputChannel, count: Int(outputBuffer.frameLength)))
            }
        }
        let ratio = inputRate / outputRate
        return (0..<outputCount).map { index in
            let position = Double(index) * ratio
            let lower = min(samples.count - 1, Int(position))
            let upper = min(samples.count - 1, lower + 1)
            let fraction = Float(position - Double(lower))
            return samples[lower] * (1 - fraction) + samples[upper] * fraction
        }
    }
}
