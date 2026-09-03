import CryptoKit
import Foundation

public enum ComparativeStudyRole: String, Codable, CaseIterable, Sendable {
    case development
    case calibration
    case test
}

public struct ComparativeTimbreStudyParameters: Codable, Hashable, Sendable {
    public var splitSeed: String
    public var calibrationFraction: Double
    public var testFraction: Double
    public var minimumIndependentInstrumentsPerExactName: Int
    public var primaryFeatureNames: [String]
    public var normalizedCentroidDomain: [Double]
    public var slopeDomainDBPerOctave: [Double]
    public var familyPermutationCount: Int
    public var classifierPermutationCount: Int

    public init(
        splitSeed: String = "orgrec-comparative-stop-timbre-split/1",
        calibrationFraction: Double = 0.2,
        testFraction: Double = 0.2,
        minimumIndependentInstrumentsPerExactName: Int = 3,
        primaryFeatureNames: [String] = [
            "median.centroid",
            "median.slopeDBPerOctave",
            "median.evenOddDB",
        ],
        normalizedCentroidDomain: [Double] = [
            TimbreMethodology.parameters.centroidDomain.lowerBound,
            TimbreMethodology.parameters.centroidDomain.upperBound,
        ],
        slopeDomainDBPerOctave: [Double] = [
            TimbreMethodology.parameters.slopeDomainDBPerOctave.lowerBound,
            TimbreMethodology.parameters.slopeDomainDBPerOctave.upperBound,
        ],
        familyPermutationCount: Int = 999,
        classifierPermutationCount: Int = 199
    ) {
        self.splitSeed = splitSeed
        self.calibrationFraction = calibrationFraction
        self.testFraction = testFraction
        self.minimumIndependentInstrumentsPerExactName = max(2, minimumIndependentInstrumentsPerExactName)
        self.primaryFeatureNames = primaryFeatureNames
        self.normalizedCentroidDomain = normalizedCentroidDomain
        self.slopeDomainDBPerOctave = slopeDomainDBPerOctave
        self.familyPermutationCount = max(0, familyPermutationCount)
        self.classifierPermutationCount = max(0, classifierPermutationCount)
    }
}

public struct ComparativeStudyAssignment: Codable, Hashable, Sendable {
    public var instrumentID: String
    public var role: ComparativeStudyRole

    public init(instrumentID: String, role: ComparativeStudyRole) {
        self.instrumentID = instrumentID
        self.role = role
    }
}

public struct ComparativeRankFeatureRecord: Codable, Hashable, Sendable {
    public var recordID: String
    public var instrumentID: String
    public var instrumentName: String
    public var producer: String
    public var role: ComparativeStudyRole
    public var rankID: String
    public var sourceLabel: String
    public var canonicalStopName: String
    public var division: String?
    public var footage: String?
    public var documentaryFamily: PipeTimbreFamily
    public var documentaryLabelRule: String
    public var pipeObservationCount: Int
    public var featureValues: [Double]
    public var fingerprintApplicability: TimbreAnalysisApplicability
    public var fingerprintSelectedSegmentCount: Int
    public var fingerprintTransitionCount: Int

    public init(
        recordID: String,
        instrumentID: String,
        instrumentName: String,
        producer: String,
        role: ComparativeStudyRole,
        rankID: String,
        sourceLabel: String,
        canonicalStopName: String,
        division: String?,
        footage: String?,
        documentaryFamily: PipeTimbreFamily,
        documentaryLabelRule: String,
        pipeObservationCount: Int,
        featureValues: [Double],
        fingerprintApplicability: TimbreAnalysisApplicability,
        fingerprintSelectedSegmentCount: Int,
        fingerprintTransitionCount: Int
    ) {
        self.recordID = recordID
        self.instrumentID = instrumentID
        self.instrumentName = instrumentName
        self.producer = producer
        self.role = role
        self.rankID = rankID
        self.sourceLabel = sourceLabel
        self.canonicalStopName = canonicalStopName
        self.division = division
        self.footage = footage
        self.documentaryFamily = documentaryFamily
        self.documentaryLabelRule = documentaryLabelRule
        self.pipeObservationCount = pipeObservationCount
        self.featureValues = featureValues
        self.fingerprintApplicability = fingerprintApplicability
        self.fingerprintSelectedSegmentCount = fingerprintSelectedSegmentCount
        self.fingerprintTransitionCount = fingerprintTransitionCount
    }
}

public struct ComparativePipeFeatureRecord: Codable, Hashable, Sendable {
    public var recordID: String
    public var rankRecordID: String
    public var instrumentID: String
    public var rankID: String
    public var sourceLabel: String
    public var canonicalStopName: String
    public var documentaryFamily: PipeTimbreFamily
    public var midiNote: Int?
    public var normalizedSpectralCentroid: Double?
    public var weightedAverageSlopeDBPerOctave: Double?
    public var evenToOddEnergyRatioDB: Double?
    public var relativePartialLevelsDB: [Double?]
    public var firstFivePrototype: FirstFivePartialPrototype
    public var applicability: TimbreAnalysisApplicability
    public var sourceAudioSHA256: String

    public init(
        recordID: String,
        rankRecordID: String,
        instrumentID: String,
        rankID: String,
        sourceLabel: String,
        canonicalStopName: String,
        documentaryFamily: PipeTimbreFamily,
        midiNote: Int?,
        normalizedSpectralCentroid: Double?,
        weightedAverageSlopeDBPerOctave: Double?,
        evenToOddEnergyRatioDB: Double?,
        relativePartialLevelsDB: [Double?],
        firstFivePrototype: FirstFivePartialPrototype,
        applicability: TimbreAnalysisApplicability,
        sourceAudioSHA256: String
    ) {
        self.recordID = recordID
        self.rankRecordID = rankRecordID
        self.instrumentID = instrumentID
        self.rankID = rankID
        self.sourceLabel = sourceLabel
        self.canonicalStopName = canonicalStopName
        self.documentaryFamily = documentaryFamily
        self.midiNote = midiNote
        self.normalizedSpectralCentroid = normalizedSpectralCentroid
        self.weightedAverageSlopeDBPerOctave = weightedAverageSlopeDBPerOctave
        self.evenToOddEnergyRatioDB = evenToOddEnergyRatioDB
        self.relativePartialLevelsDB = relativePartialLevelsDB
        self.firstFivePrototype = firstFivePrototype
        self.applicability = applicability
        self.sourceAudioSHA256 = sourceAudioSHA256
    }
}

public struct ComparativeTimbreStudyCorpus: Codable, Sendable {
    public var contractVersion: String
    public var generatedAt: Date
    public var software: OrgRecSoftwareMetadata
    public var sourceCorpusPath: String
    public var sourceCorpusFileSHA256: String
    public var sourceCorpusFingerprint: String
    public var sourceCorpusContractVersion: String
    public var timbreMethodologyContractVersion: String
    public var timbreAlgorithmVersion: String
    public var labelRuleVersion: String
    public var featureSchemaVersion: String
    public var featureNames: [String]
    public var rankFingerprintContractVersion: String
    public var parameters: ComparativeTimbreStudyParameters
    public var parameterSHA256: String
    public var sourceInstrumentCount: Int
    public var sourceRankCount: Int
    public var sourcePipeObservationCount: Int
    public var assignments: [ComparativeStudyAssignment]
    public var ranks: [ComparativeRankFeatureRecord]
    public var pipes: [ComparativePipeFeatureRecord]
    public var exclusions: [RetrievedCorpusExclusion]
    public var warnings: [String]
    public var scientificReferences: [String]

    public var fingerprint: String {
        var copy = self
        copy.generatedAt = Date(timeIntervalSince1970: 0)
        return ((try? OrgRecCoding.lineEncoder.encode(copy)) ?? Data()).sha256Hex
    }
}

/// Conservative, deterministic harmonization for grouping spelling variants.
/// The source label is always retained and remains the authoritative documentary value.
public enum ComparativeStopNameNormalizer {
    public static let version = "orgrec-comparative-stop-name-normalizer/1"

    public static func canonicalName(_ value: String) -> String {
        var normalized = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "ß", with: "ss")
        normalized = normalized.replacingOccurrences(
            of: "(?<=[A-Za-z])(?=[0-9])|(?<=[0-9])(?=[A-Za-z])",
            with: " ",
            options: .regularExpression
        )
        var tokens = normalized.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let divisionPrefixes: Set<String> = [
            "ped", "pedal", "pedale", "pedalwerk", "hw", "hauptwerk", "great", "sw", "swell",
            "ow", "oberwerk", "rp", "ruckpositiv", "positiv", "positive", "choir", "manual",
        ]
        while let first = tokens.first, divisionPrefixes.contains(first) { tokens.removeFirst() }
        let footageTokens: Set<String> = ["32", "16", "8", "4", "2", "1"]
        while let last = tokens.last, footageTokens.contains(last) { tokens.removeLast() }
        return tokens.joined(separator: " ")
    }
}

public enum ComparativeTimbreStudyBuilder {
    public static let contractVersion = "orgrec-comparative-stop-timbre-study/1"
    public static let rankFingerprintContractVersion = "orgrec-pitch-dependent-rank-fingerprint/1"

    public static func build(
        corpus: RetrievedTimbreCorpus,
        sourceCorpusURL: URL,
        parameters: ComparativeTimbreStudyParameters = ComparativeTimbreStudyParameters()
    ) throws -> ComparativeTimbreStudyCorpus {
        guard parameters.calibrationFraction >= 0,
              parameters.testFraction >= 0,
              parameters.calibrationFraction + parameters.testFraction < 1 else {
            throw OrgRecError.invalidProject("Comparative-study split fractions must be nonnegative and sum to less than one.")
        }
        guard !parameters.primaryFeatureNames.isEmpty,
              parameters.primaryFeatureNames.allSatisfy(TimbreRankFeatureVectorizer.featureNames.contains) else {
            throw OrgRecError.invalidProject("Every primary comparative endpoint must be present in the OrgRec rank feature schema.")
        }
        guard validDomain(parameters.normalizedCentroidDomain), validDomain(parameters.slopeDomainDBPerOctave) else {
            throw OrgRecError.invalidProject("Comparative-study primary endpoint domains must contain two finite ascending bounds.")
        }

        let instrumentIDs = Array(Set(corpus.ranks.map(\.instrumentID))).sorted()
        guard !instrumentIDs.isEmpty else {
            throw OrgRecError.invalidProject("The retrieved corpus has no ranks to export for comparative analysis.")
        }
        let assignments = splitAssignments(instrumentIDs: instrumentIDs, parameters: parameters)
        let roleByInstrument = Dictionary(uniqueKeysWithValues: assignments.map { ($0.instrumentID, $0.role) })
        let instrumentByID = Dictionary(uniqueKeysWithValues: corpus.instruments.map { ($0.entityID, $0) })
        var rankRecords: [ComparativeRankFeatureRecord] = []
        var pipeRecords: [ComparativePipeFeatureRecord] = []
        var exportExclusions = corpus.exclusions

        for rank in corpus.ranks.sorted(by: rankOrder) {
            guard let featureValues = TimbreRankFeatureVectorizer.vector(observations: rank.observations) else {
                exportExclusions.append(RetrievedCorpusExclusion(
                    entityID: rank.instrumentID,
                    scope: "rank:\(rank.rankID)",
                    reason: "Comparative export excluded the rank because fewer than three usable pipe observations remained."
                ))
                continue
            }
            let recordID = "\(rank.instrumentID)::\(rank.rankID)"
            let canonicalName = ComparativeStopNameNormalizer.canonicalName(rank.rankLabel)
            let fingerprint = RankFingerprintAnalyzer.analyze(
                rankComponentID: rank.rankID,
                rankLabel: rank.rankLabel,
                observations: rank.observations
            )
            rankRecords.append(ComparativeRankFeatureRecord(
                recordID: recordID,
                instrumentID: rank.instrumentID,
                instrumentName: rank.instrumentName,
                producer: instrumentByID[rank.instrumentID]?.producer ?? "",
                role: roleByInstrument[rank.instrumentID] ?? .development,
                rankID: rank.rankID,
                sourceLabel: rank.rankLabel,
                canonicalStopName: canonicalName,
                division: rank.division,
                footage: rank.footage,
                documentaryFamily: rank.labelAssignment.family,
                documentaryLabelRule: rank.labelAssignment.matchedRule,
                pipeObservationCount: rank.observations.count,
                featureValues: featureValues,
                fingerprintApplicability: fingerprint.applicability,
                fingerprintSelectedSegmentCount: fingerprint.selectedSegmentCount,
                fingerprintTransitionCount: fingerprint.transitions.count
            ))
            for observation in rank.observations.sorted(by: observationOrder) {
                let levels = Dictionary(uniqueKeysWithValues: observation.partials.map { ($0.harmonicNumber, $0.relativeLevelDB) })
                pipeRecords.append(ComparativePipeFeatureRecord(
                    recordID: observation.id.uuidString,
                    rankRecordID: recordID,
                    instrumentID: rank.instrumentID,
                    rankID: rank.rankID,
                    sourceLabel: rank.rankLabel,
                    canonicalStopName: canonicalName,
                    documentaryFamily: rank.labelAssignment.family,
                    midiNote: observation.midiNote,
                    normalizedSpectralCentroid: observation.normalizedSpectralCentroid,
                    weightedAverageSlopeDBPerOctave: observation.weightedAverageSlopeDBPerOctave,
                    evenToOddEnergyRatioDB: observation.evenToOddEnergyRatioDB,
                    relativePartialLevelsDB: (1...TimbreMethodology.maximumPartialCount).map { levels[$0] },
                    firstFivePrototype: observation.firstFivePrototype,
                    applicability: observation.applicability,
                    sourceAudioSHA256: observation.sourceAudioSHA256
                ))
            }
        }
        guard !rankRecords.isEmpty else {
            throw OrgRecError.invalidProject("No retrieved ranks met the comparative rank-feature requirements.")
        }

        let parameterData = try OrgRecCoding.lineEncoder.encode(parameters)
        var warnings = corpus.warnings
        warnings.append("Documentary family labels are weak supervision inferred from stop names; they are not independent expert ground truth.")
        warnings.append("Virtual-organ packages differ in producer processing, room acoustics, recording chain, normalization, looping, and sample selection. Instrument-grouped inference is required and causal organ-construction claims are not supported.")
        warnings.append("Canonical stop names are conservative machine harmonizations. Exact-name comparisons require at least \(parameters.minimumIndependentInstrumentsPerExactName) independent instruments and must retain source-label provenance.")
        return ComparativeTimbreStudyCorpus(
            contractVersion: contractVersion,
            generatedAt: .now,
            software: OrgRecSoftware.current,
            sourceCorpusPath: sourceCorpusURL.standardizedFileURL.path,
            sourceCorpusFileSHA256: try sha256(of: sourceCorpusURL),
            sourceCorpusFingerprint: corpus.fingerprint,
            sourceCorpusContractVersion: corpus.contractVersion,
            timbreMethodologyContractVersion: TimbreMethodology.contractVersion,
            timbreAlgorithmVersion: TimbreMethodology.algorithmVersion,
            labelRuleVersion: TimbreDocumentaryLabelNormalizer.version,
            featureSchemaVersion: TimbreRankFeatureVectorizer.version,
            featureNames: TimbreRankFeatureVectorizer.featureNames,
            rankFingerprintContractVersion: rankFingerprintContractVersion,
            parameters: parameters,
            parameterSHA256: parameterData.sha256Hex,
            sourceInstrumentCount: corpus.instruments.count,
            sourceRankCount: corpus.ranks.count,
            sourcePipeObservationCount: corpus.ranks.reduce(0) { $0 + $1.observations.count },
            assignments: assignments,
            ranks: rankRecords,
            pipes: pipeRecords,
            exclusions: exportExclusions,
            warnings: warnings,
            scientificReferences: [
                "Hergert F, Höper N. Envelope Functions for Sound Spectra of Pipe Organ Ranks and the Influence of Pitch on Tonal Timbre. Proc Mtgs Acoust. 2022;49:035012. doi:10.1121/2.0001673.",
                "Peeters G, Giordano BL, Susini P, Misdariis N, McAdams S. The Timbre Toolbox. J Acoust Soc Am. 2011;130(5):2902–2916. doi:10.1121/1.3642604.",
                "Schwarz G. Estimating the dimension of a model. Ann Stat. 1978;6(2):461–464. doi:10.1214/aos/1176344136.",
                "Benjamini Y, Hochberg Y. Controlling the false discovery rate. J R Stat Soc B. 1995;57(1):289–300. doi:10.1111/j.2517-6161.1995.tb02031.x.",
                "Freedman DA, Lane D. A Nonstochastic Interpretation of Reported Significance Levels. J Bus Econ Stat. 1983;1(4):292–298. doi:10.1080/07350015.1983.10509354.",
            ]
        )
    }

    private static func splitAssignments(
        instrumentIDs: [String],
        parameters: ComparativeTimbreStudyParameters
    ) -> [ComparativeStudyAssignment] {
        let ordered = instrumentIDs.sorted {
            stableDigest("\(parameters.splitSeed)\u{0}\($0)") < stableDigest("\(parameters.splitSeed)\u{0}\($1)")
        }
        guard ordered.count >= 3 else {
            return ordered.map { ComparativeStudyAssignment(instrumentID: $0, role: .development) }
        }
        var testCount = max(1, Int((Double(ordered.count) * parameters.testFraction).rounded()))
        var calibrationCount = max(1, Int((Double(ordered.count) * parameters.calibrationFraction).rounded()))
        while testCount + calibrationCount >= ordered.count {
            if testCount > calibrationCount { testCount -= 1 } else { calibrationCount -= 1 }
        }
        return ordered.enumerated().map { index, instrumentID in
            let role: ComparativeStudyRole
            if index < testCount {
                role = .test
            } else if index < testCount + calibrationCount {
                role = .calibration
            } else {
                role = .development
            }
            return ComparativeStudyAssignment(instrumentID: instrumentID, role: role)
        }.sorted { $0.instrumentID < $1.instrumentID }
    }

    private static func stableDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func validDomain(_ domain: [Double]) -> Bool {
        domain.count == 2 && domain.allSatisfy(\.isFinite) && domain[0] < domain[1]
    }

    private static func rankOrder(_ lhs: EmpiricalTimbreRankRecord, _ rhs: EmpiricalTimbreRankRecord) -> Bool {
        if lhs.instrumentID != rhs.instrumentID { return lhs.instrumentID < rhs.instrumentID }
        if lhs.rankLabel != rhs.rankLabel { return lhs.rankLabel < rhs.rankLabel }
        return lhs.rankID < rhs.rankID
    }

    private static func observationOrder(_ lhs: PipeTimbreObservation, _ rhs: PipeTimbreObservation) -> Bool {
        if lhs.midiNote != rhs.midiNote { return (lhs.midiNote ?? Int.max) < (rhs.midiNote ?? Int.max) }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
