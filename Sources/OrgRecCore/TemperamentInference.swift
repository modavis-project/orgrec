import Foundation

public struct TemperamentCatalogEntry: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var label: String?
    public var groupKey: String?
    public var groupLabel: String?
    public var isPreciseVariant: Bool
    public var toneOrder: [String]
    public var centValues: [Double]
    public var sourceRecordID: String?
    public var sourceURL: URL?
    public var commentaryURL: URL?
    public var navigatorPath: String?

    public init(
        id: String,
        title: String,
        label: String? = nil,
        groupKey: String? = nil,
        groupLabel: String? = nil,
        isPreciseVariant: Bool = false,
        toneOrder: [String],
        centValues: [Double],
        sourceRecordID: String? = nil,
        sourceURL: URL? = nil,
        commentaryURL: URL? = nil,
        navigatorPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.label = label
        self.groupKey = groupKey
        self.groupLabel = groupLabel
        self.isPreciseVariant = isPreciseVariant
        self.toneOrder = toneOrder
        self.centValues = centValues
        self.sourceRecordID = sourceRecordID
        self.sourceURL = sourceURL
        self.commentaryURL = commentaryURL
        self.navigatorPath = navigatorPath
    }
}

public struct TemperamentCatalogSnapshot: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var fetchedAt: Date
    public var navigatorBaseURL: URL
    public var modavisRelease: String
    public var payloadSHA256: String
    public var totalAvailable: Int
    public var entries: [TemperamentCatalogEntry]

    public init(
        contractVersion: String = "orgrec.modavis-temperament-catalog/v1",
        fetchedAt: Date = .now,
        navigatorBaseURL: URL,
        modavisRelease: String,
        payloadSHA256: String,
        totalAvailable: Int,
        entries: [TemperamentCatalogEntry]
    ) {
        self.contractVersion = contractVersion
        self.fetchedAt = fetchedAt
        self.navigatorBaseURL = navigatorBaseURL
        self.modavisRelease = modavisRelease
        self.payloadSHA256 = payloadSHA256
        self.totalAvailable = totalAvailable
        self.entries = entries
    }
}

public struct TemperamentFrequencySample: Codable, Hashable, Sendable {
    public var takeID: UUID
    public var midiNote: Int
    public var footHeight: String?
    public var frequencyHz: Double
    public var confidence: Double
    public var uncertaintyCents: Double?
    public var pitchMADcents: Double?
    public var estimator: String?

    public init(
        takeID: UUID,
        midiNote: Int,
        footHeight: String?,
        frequencyHz: Double,
        confidence: Double,
        uncertaintyCents: Double? = nil,
        pitchMADcents: Double? = nil,
        estimator: String? = nil
    ) {
        self.takeID = takeID
        self.midiNote = midiNote
        self.footHeight = footHeight
        self.frequencyHz = frequencyHz
        self.confidence = confidence
        self.uncertaintyCents = uncertaintyCents
        self.pitchMADcents = pitchMADcents
        self.estimator = estimator
    }
}

public struct TemperamentPitchClassObservation: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { pitchClass }
    public var pitchClass: Int
    public var toneName: String
    public var sampleCount: Int
    public var medianResidualCents: Double
    public var medianAbsoluteDeviationCents: Double
    public var meanConfidence: Double
    public var midiNotes: [Int]
    public var takeIDs: [UUID]
    public var effectiveWeight: Double?
    public var uncertaintyCents: Double?
    public var octaveSpan: Int?
}

public struct TemperamentVectorPoint: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { pitchClass }
    public var pitchClass: Int
    public var toneName: String
    public var observedCents: Double
    public var candidateCents: Double
    public var errorCents: Double
}

public struct TemperamentCandidateMatch: Codable, Hashable, Identifiable, Sendable {
    public var id: String { catalogEntryID }
    public var catalogEntryID: String
    public var title: String
    public var label: String?
    public var groupLabel: String?
    public var isPreciseVariant: Bool
    public var robustRMSECents: Double
    public var medianAbsoluteErrorCents: Double
    public var maximumAbsoluteErrorCents: Double
    public var fittedOffsetCents: Double
    public var matchedPitchClassCount: Int
    public var vector: [TemperamentVectorPoint]
    public var navigatorPath: String?
    public var sourceURL: URL?
    public var commentaryURL: URL?
    public var weightedRMSECents: Double?
    public var sensitivitySupport: Double?
}

public enum TemperamentInferenceStrength: String, Codable, CaseIterable, Sendable {
    case insufficient
    case tentative
    case suggestive
    case strong
}

public enum TemperamentA4Source: String, Codable, Sendable {
    case acceptedSessionCalibration
    case measuredFromSelectedRank
    case documentedPrior
    case assumed440
}

public struct TemperamentAnalysisReport: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var analyzedAt: Date
    public var rankComponentID: String
    public var rankLabel: String
    public var referenceA4Hz: Double
    public var referenceA4Source: TemperamentA4Source
    public var documentedTemperament: String?
    public var observations: [TemperamentPitchClassObservation]
    public var matches: [TemperamentCandidateMatch]
    public var inferenceStrength: TemperamentInferenceStrength
    public var runnerUpMarginCents: Double?
    public var analyzedTakeCount: Int
    public var rejectedSampleCount: Int
    public var catalogRelease: String
    public var catalogPayloadSHA256: String
    public var catalogFetchedAt: Date
    public var notes: [String]
    public var medianDispersionCents: Double?
    public var stretchCentsPerOctave: Double?
    public var sensitivitySupport: Double?
    public var equalTemperamentImprovementCents: Double?
    public var outlierTakeIDs: [UUID]?

    public init(
        contractVersion: String = "orgrec.temperament-analysis/v1",
        id: UUID = UUID(),
        analyzedAt: Date = .now,
        rankComponentID: String,
        rankLabel: String,
        referenceA4Hz: Double,
        referenceA4Source: TemperamentA4Source,
        documentedTemperament: String?,
        observations: [TemperamentPitchClassObservation],
        matches: [TemperamentCandidateMatch],
        inferenceStrength: TemperamentInferenceStrength,
        runnerUpMarginCents: Double?,
        analyzedTakeCount: Int,
        rejectedSampleCount: Int,
        catalogRelease: String,
        catalogPayloadSHA256: String,
        catalogFetchedAt: Date,
        notes: [String],
        medianDispersionCents: Double? = nil,
        stretchCentsPerOctave: Double? = nil,
        sensitivitySupport: Double? = nil,
        equalTemperamentImprovementCents: Double? = nil,
        outlierTakeIDs: [UUID]? = nil
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.analyzedAt = analyzedAt
        self.rankComponentID = rankComponentID
        self.rankLabel = rankLabel
        self.referenceA4Hz = referenceA4Hz
        self.referenceA4Source = referenceA4Source
        self.documentedTemperament = documentedTemperament
        self.observations = observations
        self.matches = matches
        self.inferenceStrength = inferenceStrength
        self.runnerUpMarginCents = runnerUpMarginCents
        self.analyzedTakeCount = analyzedTakeCount
        self.rejectedSampleCount = rejectedSampleCount
        self.catalogRelease = catalogRelease
        self.catalogPayloadSHA256 = catalogPayloadSHA256
        self.catalogFetchedAt = catalogFetchedAt
        self.notes = notes
        self.medianDispersionCents = medianDispersionCents
        self.stretchCentsPerOctave = stretchCentsPerOctave
        self.sensitivitySupport = sensitivitySupport
        self.equalTemperamentImprovementCents = equalTemperamentImprovementCents
        self.outlierTakeIDs = outlierTakeIDs
    }
}

public struct TemperamentConsensusCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: String { catalogEntryID }
    public var catalogEntryID: String
    public var title: String
    public var supportingRankCount: Int
    public var meanWeightedRMSECents: Double
}

public struct TemperamentConsensusReport: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var analyzedAt: Date
    public var sourceReportIDs: [UUID]
    public var candidates: [TemperamentConsensusCandidate]
    public var rankAgreement: Double
    public var notes: [String]

    public init(
        contractVersion: String = "orgrec.temperament-consensus/v1",
        id: UUID = UUID(),
        analyzedAt: Date = .now,
        sourceReportIDs: [UUID],
        candidates: [TemperamentConsensusCandidate],
        rankAgreement: Double,
        notes: [String]
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.analyzedAt = analyzedAt
        self.sourceReportIDs = sourceReportIDs
        self.candidates = candidates
        self.rankAgreement = rankAgreement
        self.notes = notes
    }
}

public enum TemperamentAnalysisEngine {
    private static let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    public static func analyze(
        samples: [TemperamentFrequencySample],
        referenceA4Hz: Double,
        referenceA4Source: TemperamentA4Source,
        rankComponentID: String,
        rankLabel: String,
        documentedTemperament: String?,
        catalog: TemperamentCatalogSnapshot,
        maximumMatches: Int = 10
    ) -> TemperamentAnalysisReport {
        var rejected = 0
        let usable: [(sample: TemperamentFrequencySample, residual: Double, uncertainty: Double, weight: Double)] = samples.compactMap { sample in
            guard sample.frequencyHz > 0, sample.confidence >= 0.35,
                  let expected = expectedFrequency(midiNote: sample.midiNote, footHeight: sample.footHeight, a4Hz: referenceA4Hz) else {
                rejected += 1
                return nil
            }
            let residual = 1_200 * log2(sample.frequencyHz / expected)
            guard residual.isFinite, abs(residual) <= 150 else {
                rejected += 1
                return nil
            }
            let uncertainty = max(0.5, sample.uncertaintyCents ?? sample.pitchMADcents ?? max(1, (1 - sample.confidence) * 20))
            let weight = max(0.01, sample.confidence) / (uncertainty * uncertainty)
            return (sample, residual, uncertainty, weight)
        }
        let grouped = Dictionary(grouping: usable) { (($0.sample.midiNote % 12) + 12) % 12 }
        var observations = grouped.keys.sorted().compactMap { pitchClass -> TemperamentPitchClassObservation? in
            guard let values = grouped[pitchClass], values.isEmpty == false else { return nil }
            let residuals = values.map(\.residual)
            let center = median(residuals)
            let mad = median(residuals.map { abs($0 - center) })
            return TemperamentPitchClassObservation(
                pitchClass: pitchClass,
                toneName: names[pitchClass],
                sampleCount: values.count,
                medianResidualCents: center,
                medianAbsoluteDeviationCents: mad,
                meanConfidence: values.map { $0.sample.confidence }.reduce(0, +) / Double(values.count),
                midiNotes: Array(Set(values.map { $0.sample.midiNote })).sorted(),
                takeIDs: values.map { $0.sample.takeID },
                effectiveWeight: values.map(\.weight).reduce(0, +),
                uncertaintyCents: sqrt(values.map { $0.uncertainty * $0.uncertainty }.reduce(0, +) / Double(values.count)),
                octaveSpan: (values.map { $0.sample.midiNote }.max() ?? 0) / 12 - (values.map { $0.sample.midiNote }.min() ?? 0) / 12 + 1
            )
        }
        // A4 is the global pitch anchor. Removing the observed A-class residual
        // prevents a rank-wide offset from masquerading as temperament shape.
        if let aResidual = observations.first(where: { $0.pitchClass == 9 })?.medianResidualCents {
            for index in observations.indices { observations[index].medianResidualCents -= aResidual }
        }

        var allMatches = catalog.entries.compactMap { match(entry: $0, observations: observations) }
        allMatches.sort {
            let left = $0.weightedRMSECents ?? $0.robustRMSECents
            let right = $1.weightedRMSECents ?? $1.robustRMSECents
            if left != right { return left < right }
            return $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
        var sensitivityCounts: [String: Int] = [:]
        var sensitivityTrials = 0
        if observations.count > 8 {
            for omitted in observations.indices {
                let subset = observations.enumerated().filter { $0.offset != omitted }.map(\.element)
                let ranked = catalog.entries.compactMap { match(entry: $0, observations: subset) }.sorted {
                    ($0.weightedRMSECents ?? $0.robustRMSECents) < ($1.weightedRMSECents ?? $1.robustRMSECents)
                }
                if let winner = ranked.first {
                    sensitivityCounts[winner.catalogEntryID, default: 0] += 1
                    sensitivityTrials += 1
                }
            }
        }
        for index in allMatches.indices {
            allMatches[index].sensitivitySupport = sensitivityTrials == 0 ? nil
                : Double(sensitivityCounts[allMatches[index].catalogEntryID, default: 0]) / Double(sensitivityTrials)
        }
        let bestSupport = allMatches.first?.sensitivitySupport
        let equalFit = allMatches.first(where: {
            $0.catalogEntryID.localizedCaseInsensitiveContains("equal") || $0.title.localizedCaseInsensitiveContains("equal")
        }).map { $0.weightedRMSECents ?? $0.robustRMSECents }
        let matches = Array(allMatches.prefix(max(1, maximumMatches)))
        let margin = matches.count > 1
            ? (matches[1].weightedRMSECents ?? matches[1].robustRMSECents) - (matches[0].weightedRMSECents ?? matches[0].robustRMSECents)
            : nil
        let totalSamples = observations.reduce(0) { $0 + $1.sampleCount }
        let dispersion = median(observations.map(\.medianAbsoluteDeviationCents))
        let meanConfidence = usable.isEmpty ? 0 : usable.map { $0.sample.confidence }.reduce(0, +) / Double(usable.count)
        let bestFit = matches.first.map { $0.weightedRMSECents ?? $0.robustRMSECents } ?? .infinity
        let bestEqualImprovement = equalFit.map { $0 - bestFit }
        let pitchClassCenters = Dictionary(uniqueKeysWithValues: observations.map { ($0.pitchClass, $0.medianResidualCents) })
        let stretchPairs = usable.compactMap { value -> (Double, Double)? in
            let pitchClass = ((value.sample.midiNote % 12) + 12) % 12
            guard let center = pitchClassCenters[pitchClass] else { return nil }
            return (Double(value.sample.midiNote) / 12, value.residual - center)
        }
        let stretch = linearSlope(stretchPairs)
        let outlierTakeIDs = usable.compactMap { value -> UUID? in
            let pitchClass = ((value.sample.midiNote % 12) + 12) % 12
            guard let observation = observations.first(where: { $0.pitchClass == pitchClass }) else { return nil }
            let threshold = max(12, 3 * max(1, observation.medianAbsoluteDeviationCents))
            return abs(value.residual - (pitchClassCenters[pitchClass] ?? 0)) > threshold ? value.sample.takeID : nil
        }
        let strength: TemperamentInferenceStrength
        if observations.count < 8 || matches.isEmpty {
            strength = .insufficient
        } else if observations.count < 12 || bestFit > 12 || (margin ?? 0) < 1 || dispersion > 10 || meanConfidence < 0.55 {
            strength = .tentative
        } else if totalSamples >= 24, bestFit <= 5, (margin ?? 0) >= 2.5,
                  dispersion <= 5, meanConfidence >= 0.7, (bestSupport ?? 1) >= 0.8 {
            strength = .strong
        } else {
            strength = .suggestive
        }
        var notes = [
            "Nearest acoustic fit only; it does not replace a documented or curator-approved temperament assertion.",
            "Rank regulation, temperature, stretch, voicing, and pipe condition can produce deviations unrelated to temperament.",
        ]
        if observations.count < 12 { notes.append("Only \(observations.count) of 12 pitch classes are represented; record or analyze the missing classes.") }
        if totalSamples < 24 { notes.append("Fewer than two observations per pitch class are available on average; cross-rank or cross-octave replication is recommended.") }
        if dispersion > 5 { notes.append("Median within-class dispersion is \(dispersion.formatted(.number.precision(.fractionLength(1)))) cents; the result is sensitive to regulation or measurement variance.") }
        if let bestSupport, bestSupport < 0.8 { notes.append("The leading candidate wins only \((bestSupport * 100).formatted(.number.precision(.fractionLength(0))))% of leave-one-class-out trials.") }
        if outlierTakeIDs.isEmpty == false { notes.append("\(outlierTakeIDs.count) take(s) are outliers relative to their pitch-class center and should be reviewed.") }
        return TemperamentAnalysisReport(
            rankComponentID: rankComponentID,
            rankLabel: rankLabel,
            referenceA4Hz: referenceA4Hz,
            referenceA4Source: referenceA4Source,
            documentedTemperament: documentedTemperament,
            observations: observations,
            matches: matches,
            inferenceStrength: strength,
            runnerUpMarginCents: margin,
            analyzedTakeCount: samples.count,
            rejectedSampleCount: rejected,
            catalogRelease: catalog.modavisRelease,
            catalogPayloadSHA256: catalog.payloadSHA256,
            catalogFetchedAt: catalog.fetchedAt,
            notes: notes,
            medianDispersionCents: dispersion,
            stretchCentsPerOctave: stretch,
            sensitivitySupport: bestSupport,
            equalTemperamentImprovementCents: bestEqualImprovement,
            outlierTakeIDs: outlierTakeIDs
        )
    }

    private static func match(entry: TemperamentCatalogEntry, observations: [TemperamentPitchClassObservation]) -> TemperamentCandidateMatch? {
        let germanNotation = entry.toneOrder.contains(where: { $0.lowercased() == "h" || $0.lowercased().contains("is") })
        var grouped: [Int: [Double]] = [:]
        for (tone, cents) in zip(entry.toneOrder, entry.centValues) {
            guard let pitchClass = pitchClass(tone, germanNotation: germanNotation), cents.isFinite else { continue }
            grouped[pitchClass, default: []].append(cents)
        }
        let vector = grouped.mapValues(median)
        let comparable = observations.filter { vector[$0.pitchClass] != nil }
        guard comparable.count >= 8 else { return nil }
        let offsets = comparable.map { $0.medianResidualCents - vector[$0.pitchClass]! }
        let fittedOffset = median(offsets)
        let points = comparable.map { observation -> TemperamentVectorPoint in
            let candidate = vector[observation.pitchClass]! + fittedOffset
            return TemperamentVectorPoint(
                pitchClass: observation.pitchClass,
                toneName: observation.toneName,
                observedCents: observation.medianResidualCents,
                candidateCents: candidate,
                errorCents: observation.medianResidualCents - candidate
            )
        }
        let errors = points.map(\.errorCents)
        let clippedSquares = errors.map { min(abs($0), 20) }.map { $0 * $0 }
        let rmse = sqrt(clippedSquares.reduce(0, +) / Double(clippedSquares.count))
        let weights = comparable.map { max(0.0001, $0.effectiveWeight ?? Double($0.sampleCount)) }
        let weightedSquares = zip(errors, weights).map { min(abs($0.0), 30) * min(abs($0.0), 30) * $0.1 }
        let weightedRMSE = sqrt(weightedSquares.reduce(0, +) / weights.reduce(0, +))
        return TemperamentCandidateMatch(
            catalogEntryID: entry.id,
            title: entry.title,
            label: entry.label,
            groupLabel: entry.groupLabel,
            isPreciseVariant: entry.isPreciseVariant,
            robustRMSECents: rmse,
            medianAbsoluteErrorCents: median(errors.map(abs)),
            maximumAbsoluteErrorCents: errors.map(abs).max() ?? 0,
            fittedOffsetCents: fittedOffset,
            matchedPitchClassCount: points.count,
            vector: points,
            navigatorPath: entry.navigatorPath,
            sourceURL: entry.sourceURL,
            commentaryURL: entry.commentaryURL,
            weightedRMSECents: weightedRMSE,
            sensitivitySupport: nil
        )
    }

    private static func expectedFrequency(midiNote: Int, footHeight: String?, a4Hz: Double) -> Double? {
        guard (300...600).contains(a4Hz) else { return nil }
        return OrganFootage.nominalFrequency(
            keyMidi: midiNote,
            footHeight: footHeight,
            referencePitchHz: a4Hz
        )
    }

    private static func pitchClass(_ raw: String, germanNotation: Bool) -> Int? {
        var tone = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        tone = tone.replacingOccurrences(of: "♯", with: "#").replacingOccurrences(of: "♭", with: "b")
            .replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
        let direct: [String: Int] = [
            "c": 0, "bis": 0, "b#": 0,
            "c#": 1, "cis": 1, "db": 1, "des": 1,
            "d": 2, "d#": 3, "dis": 3, "eb": 3, "es": 3,
            "e": 4, "fb": 4, "fes": 4, "e#": 5, "eis": 5,
            "f": 5, "f#": 6, "fis": 6, "gb": 6, "ges": 6,
            "g": 7, "g#": 8, "gis": 8, "ab": 8, "as": 8,
            "a": 9, "a#": 10, "ais": 10, "bb": 10,
            "h": 11, "cb": 11, "ces": 11,
        ]
        if tone == "b" { return germanNotation ? 10 : 11 }
        return direct[tone]
    }

    private static func median(_ values: [Double]) -> Double {
        guard values.isEmpty == false else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func linearSlope(_ values: [(Double, Double)]) -> Double? {
        guard values.count >= 3 else { return nil }
        let meanX = values.map { $0.0 }.reduce(0, +) / Double(values.count)
        let meanY = values.map { $0.1 }.reduce(0, +) / Double(values.count)
        let numerator = values.reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let denominator = values.reduce(0) { $0 + ($1.0 - meanX) * ($1.0 - meanX) }
        return denominator > 1e-12 ? numerator / denominator : nil
    }
}

public enum TemperamentConsensusEngine {
    public static func analyze(reports: [TemperamentAnalysisReport]) -> TemperamentConsensusReport? {
        let usable = reports.filter { $0.inferenceStrength != .insufficient && $0.matches.isEmpty == false }
        guard usable.isEmpty == false else { return nil }
        let grouped = Dictionary(grouping: usable.flatMap { report in
            report.matches.prefix(5).map { (report, $0) }
        }) { $0.1.catalogEntryID }
        let candidates = grouped.map { id, values -> TemperamentConsensusCandidate in
            let uniqueRanks = Set(values.map { $0.0.rankComponentID }).count
            let errors = values.map { $0.1.weightedRMSECents ?? $0.1.robustRMSECents }
            return TemperamentConsensusCandidate(
                catalogEntryID: id,
                title: values.first?.1.title ?? id,
                supportingRankCount: uniqueRanks,
                meanWeightedRMSECents: errors.reduce(0, +) / Double(errors.count)
            )
        }.sorted {
            if $0.supportingRankCount != $1.supportingRankCount { return $0.supportingRankCount > $1.supportingRankCount }
            return $0.meanWeightedRMSECents < $1.meanWeightedRMSECents
        }
        let topIDs = usable.compactMap { $0.matches.first?.catalogEntryID }
        let topCount = Dictionary(grouping: topIDs, by: { $0 }).values.map(\.count).max() ?? 0
        let agreement = Double(topCount) / Double(max(1, topIDs.count))
        var notes = ["Consensus is derived from independent rank reports; it does not create a canonical temperament assertion."]
        if usable.count < 2 { notes.append("Only one usable rank is available; cross-rank agreement cannot yet be evaluated.") }
        else if agreement < 0.75 { notes.append("Ranks disagree on the leading catalogue candidate; inspect regulation, condition, and estimator uncertainty.") }
        return TemperamentConsensusReport(
            sourceReportIDs: usable.map(\.id),
            candidates: candidates,
            rankAgreement: agreement,
            notes: notes
        )
    }
}
