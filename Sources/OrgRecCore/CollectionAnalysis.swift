import Foundation

public struct CollectionAnalysisParameters: Codable, Hashable, Sendable {
    public var minimumAggregateQualityScore: Double
    public var moderateQualityScore: Double
    public var highQualityScore: Double
    public var minimumAnomalyGroupSize: Int
    public var anomalyWarningScore: Double
    public var anomalyCriticalScore: Double
    public var similarityThreshold: Double
    public var minimumSimilarityHarmonics: Int
    public var maximumSimilarityCandidates: Int
    public var minimumDriftRepeatedTargets: Int
    public var minimumDriftPairComparisons: Int
    public var minimumDriftSpanHours: Double

    public init(
        minimumAggregateQualityScore: Double = 0.45,
        moderateQualityScore: Double = 0.60,
        highQualityScore: Double = 0.80,
        minimumAnomalyGroupSize: Int = 4,
        anomalyWarningScore: Double = 3.5,
        anomalyCriticalScore: Double = 5.0,
        similarityThreshold: Double = 0.97,
        minimumSimilarityHarmonics: Int = 6,
        maximumSimilarityCandidates: Int = 100,
        minimumDriftRepeatedTargets: Int = 2,
        minimumDriftPairComparisons: Int = 3,
        minimumDriftSpanHours: Double = 0.25
    ) {
        self.minimumAggregateQualityScore = minimumAggregateQualityScore
        self.moderateQualityScore = moderateQualityScore
        self.highQualityScore = highQualityScore
        self.minimumAnomalyGroupSize = minimumAnomalyGroupSize
        self.anomalyWarningScore = anomalyWarningScore
        self.anomalyCriticalScore = anomalyCriticalScore
        self.similarityThreshold = similarityThreshold
        self.minimumSimilarityHarmonics = minimumSimilarityHarmonics
        self.maximumSimilarityCandidates = maximumSimilarityCandidates
        self.minimumDriftRepeatedTargets = minimumDriftRepeatedTargets
        self.minimumDriftPairComparisons = minimumDriftPairComparisons
        self.minimumDriftSpanHours = minimumDriftSpanHours
    }
}

public enum AnalysisEvidenceTier: String, Codable, CaseIterable, Sendable {
    case high
    case moderate
    case limited
    case excluded
}

public struct TakeEvidenceAssessment: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { takeID }
    public var takeID: UUID
    public var rankComponentID: String
    public var midiNote: Int
    public var qualityScore: Double
    public var tier: AnalysisEvidenceTier
    public var includedInAggregates: Bool
    public var availableQualityDimensions: Int
    public var exclusionReasons: [String]
    public var qualityFlags: [String]
}

public struct AnalysisExclusionCount: Codable, Hashable, Identifiable, Sendable {
    public var id: String { reason }
    public var reason: String
    public var count: Int
}

public struct CollectionEvidenceSummary: Codable, Hashable, Sendable {
    public var eligibleTakeCount: Int
    public var analyzedTakeCount: Int
    public var aggregateTakeCount: Int
    public var highQualityCount: Int
    public var moderateQualityCount: Int
    public var limitedQualityCount: Int
    public var excludedCount: Int
    public var aggregateCoverage: Double
    public var medianQualityScore: Double?
    public var exclusions: [AnalysisExclusionCount]
}

public struct RankTuningPoint: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { midiNote }
    public var midiNote: Int
    public var medianDeviationCents: Double
    public var medianAbsoluteDeviationCents: Double
    public var takeIDs: [UUID]
    public var qualityWeightedDeviationCents: Double?
    public var lowerObservedBoundCents: Double?
    public var upperObservedBoundCents: Double?
    public var effectiveSampleSize: Double?
    public var medianEvidenceQuality: Double?
    public var standardUncertaintyCents: Double?

    public init(
        midiNote: Int,
        medianDeviationCents: Double,
        medianAbsoluteDeviationCents: Double,
        takeIDs: [UUID],
        qualityWeightedDeviationCents: Double? = nil,
        lowerObservedBoundCents: Double? = nil,
        upperObservedBoundCents: Double? = nil,
        effectiveSampleSize: Double? = nil,
        medianEvidenceQuality: Double? = nil,
        standardUncertaintyCents: Double? = nil
    ) {
        self.midiNote = midiNote
        self.medianDeviationCents = medianDeviationCents
        self.medianAbsoluteDeviationCents = medianAbsoluteDeviationCents
        self.takeIDs = takeIDs
        self.qualityWeightedDeviationCents = qualityWeightedDeviationCents
        self.lowerObservedBoundCents = lowerObservedBoundCents
        self.upperObservedBoundCents = upperObservedBoundCents
        self.effectiveSampleSize = effectiveSampleSize
        self.medianEvidenceQuality = medianEvidenceQuality
        self.standardUncertaintyCents = standardUncertaintyCents
    }
}

public struct RankTuningProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: String { rankComponentID }
    public var rankComponentID: String
    public var rankLabel: String
    public var points: [RankTuningPoint]
    public var stretchCentsPerOctave: Double?
    public var outlierTakeIDs: [UUID]
    public var stretchLowerBoundCentsPerOctave: Double?
    public var stretchUpperBoundCentsPerOctave: Double?
    public var observedKeySpanCoverage: Double?
    public var medianEvidenceQuality: Double?
    public var slopeMethod: String?
    public var groupingBasis: String?

    public init(
        rankComponentID: String,
        rankLabel: String,
        points: [RankTuningPoint],
        stretchCentsPerOctave: Double?,
        outlierTakeIDs: [UUID],
        stretchLowerBoundCentsPerOctave: Double? = nil,
        stretchUpperBoundCentsPerOctave: Double? = nil,
        observedKeySpanCoverage: Double? = nil,
        medianEvidenceQuality: Double? = nil,
        slopeMethod: String? = nil,
        groupingBasis: String? = nil
    ) {
        self.rankComponentID = rankComponentID
        self.rankLabel = rankLabel
        self.points = points
        self.stretchCentsPerOctave = stretchCentsPerOctave
        self.outlierTakeIDs = outlierTakeIDs
        self.stretchLowerBoundCentsPerOctave = stretchLowerBoundCentsPerOctave
        self.stretchUpperBoundCentsPerOctave = stretchUpperBoundCentsPerOctave
        self.observedKeySpanCoverage = observedKeySpanCoverage
        self.medianEvidenceQuality = medianEvidenceQuality
        self.slopeMethod = slopeMethod
        self.groupingBasis = groupingBasis
    }
}

public struct SessionPitchDriftReport: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { sessionID }
    public var sessionID: UUID
    public var sessionCode: String
    public var analyzedTakeCount: Int
    public var driftCentsPerHour: Double?
    public var medianDeviationCents: Double?
    public var temperatureCelsius: Double?
    public var driftLowerBoundCentsPerHour: Double?
    public var driftUpperBoundCentsPerHour: Double?
    public var durationHours: Double?
    public var medianEvidenceQuality: Double?
    public var slopeMethod: String?
    public var repeatedTargetCount: Int?
    public var pairComparisonCount: Int?
    public var applicability: String?

    public init(
        sessionID: UUID,
        sessionCode: String,
        analyzedTakeCount: Int,
        driftCentsPerHour: Double?,
        medianDeviationCents: Double?,
        temperatureCelsius: Double?,
        driftLowerBoundCentsPerHour: Double? = nil,
        driftUpperBoundCentsPerHour: Double? = nil,
        durationHours: Double? = nil,
        medianEvidenceQuality: Double? = nil,
        slopeMethod: String? = nil,
        repeatedTargetCount: Int? = nil,
        pairComparisonCount: Int? = nil,
        applicability: String? = nil
    ) {
        self.sessionID = sessionID
        self.sessionCode = sessionCode
        self.analyzedTakeCount = analyzedTakeCount
        self.driftCentsPerHour = driftCentsPerHour
        self.medianDeviationCents = medianDeviationCents
        self.temperatureCelsius = temperatureCelsius
        self.driftLowerBoundCentsPerHour = driftLowerBoundCentsPerHour
        self.driftUpperBoundCentsPerHour = driftUpperBoundCentsPerHour
        self.durationHours = durationHours
        self.medianEvidenceQuality = medianEvidenceQuality
        self.slopeMethod = slopeMethod
        self.repeatedTargetCount = repeatedTargetCount
        self.pairComparisonCount = pairComparisonCount
        self.applicability = applicability
    }
}

public struct AcousticSimilarityCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: String { [firstTakeID.uuidString, secondTakeID.uuidString].sorted().joined(separator: ":") }
    public var firstTakeID: UUID
    public var secondTakeID: UUID
    public var cosineSimilarity: Double
    public var sameIntendedMIDINote: Bool
    public var reason: String
    public var sharedPartialCount: Int?
    public var evidenceScore: Double?
}

public enum AcousticAnomalySeverity: String, Codable, CaseIterable, Sendable {
    case warning
    case critical
}

public struct AcousticAnomalyFeatureScore: Codable, Hashable, Identifiable, Sendable {
    public var id: String { feature }
    public var feature: String
    public var value: Double
    public var robustCenter: Double
    public var robustZScore: Double
}

public struct AcousticAnomalyCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { takeID }
    public var takeID: UUID
    public var rankComponentID: String
    public var rankLabel: String
    public var midiNote: Int
    public var robustDistance: Double
    public var severity: AcousticAnomalySeverity
    public var evidenceDimensionCount: Int
    public var qualityScore: Double
    public var featureScores: [AcousticAnomalyFeatureScore]
    public var interpretation: String
}

public struct CollectionAnalysisReport: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var analyzedAt: Date
    public var sourceAnalysisRunIDs: [UUID]
    public var rankTuningProfiles: [RankTuningProfile]
    public var sessionPitchDrift: [SessionPitchDriftReport]
    public var acousticSimilarityCandidates: [AcousticSimilarityCandidate]
    public var notes: [String]
    public var parameters: CollectionAnalysisParameters?
    public var parameterSHA256: String?
    public var sourceFingerprintSHA256: String?
    public var evidenceSummary: CollectionEvidenceSummary?
    public var takeEvidence: [TakeEvidenceAssessment]?
    public var acousticAnomalyCandidates: [AcousticAnomalyCandidate]?
    public var assessedTakeIDs: [UUID]?
    public var contributingTakeIDs: [UUID]?

    public init(
        contractVersion: String = "orgrec-collection-analysis/2",
        id: UUID = UUID(),
        analyzedAt: Date = .now,
        sourceAnalysisRunIDs: [UUID],
        rankTuningProfiles: [RankTuningProfile],
        sessionPitchDrift: [SessionPitchDriftReport],
        acousticSimilarityCandidates: [AcousticSimilarityCandidate],
        notes: [String],
        parameters: CollectionAnalysisParameters? = nil,
        parameterSHA256: String? = nil,
        sourceFingerprintSHA256: String? = nil,
        evidenceSummary: CollectionEvidenceSummary? = nil,
        takeEvidence: [TakeEvidenceAssessment]? = nil,
        acousticAnomalyCandidates: [AcousticAnomalyCandidate]? = nil,
        assessedTakeIDs: [UUID]? = nil,
        contributingTakeIDs: [UUID]? = nil
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.analyzedAt = analyzedAt
        self.sourceAnalysisRunIDs = sourceAnalysisRunIDs
        self.rankTuningProfiles = rankTuningProfiles
        self.sessionPitchDrift = sessionPitchDrift
        self.acousticSimilarityCandidates = acousticSimilarityCandidates
        self.notes = notes
        self.parameters = parameters
        self.parameterSHA256 = parameterSHA256
        self.sourceFingerprintSHA256 = sourceFingerprintSHA256
        self.evidenceSummary = evidenceSummary
        self.takeEvidence = takeEvidence
        self.acousticAnomalyCandidates = acousticAnomalyCandidates
        self.assessedTakeIDs = assessedTakeIDs
        self.contributingTakeIDs = contributingTakeIDs
    }
}

public enum CollectionAnalysisEngine {
    private struct SourceFingerprintEnvelope: Encodable {
        var parameters: CollectionAnalysisParameters
        var roadmap: [RoadmapItem]
        var takes: [TakeRecord]
        var sessions: [RecordingSession]
    }

    private struct AnalyzedTake {
        var take: TakeRecord
        var item: RoadmapItem
        var cents: Double
        var quality: TakeEvidenceAssessment
    }

    private struct HarmonicFingerprint {
        var analyzed: AnalyzedTake
        var amplitudes: [Int: Double]
    }

    private struct RankGrouping {
        var id: String
        var label: String
        var basis: String
    }

    private struct PitchEvidenceWeight {
        var value: Double
        var quality: Double
        var standardUncertainty: Double
        var lowerBound: Double
        var upperBound: Double
    }

    public static func analyze(
        project: OrgRecProject,
        parameters: CollectionAnalysisParameters = CollectionAnalysisParameters(),
        id: UUID = UUID(),
        analyzedAt: Date = .now
    ) -> CollectionAnalysisReport? {
        guard parametersAreValid(parameters) else { return nil }
        let roadmapByID = Dictionary(uniqueKeysWithValues: project.roadmap.map { ($0.id, $0) })
        let eligible = project.takes.compactMap { take -> (TakeRecord, RoadmapItem)? in
            guard let item = roadmapByID[take.roadmapItemID], item.component.midiNote != nil else { return nil }
            return (take, item)
        }
        guard eligible.isEmpty == false else { return nil }

        let assessments = eligible.map { evidenceAssessment(take: $0.0, item: $0.1, parameters: parameters) }
        let assessmentByTake = Dictionary(uniqueKeysWithValues: assessments.map { ($0.takeID, $0) })
        let analyzed = eligible.compactMap { take, item -> AnalyzedTake? in
            guard let assessment = assessmentByTake[take.id], assessment.includedInAggregates,
                  let cents = take.analysis?.centsDeviation, cents.isFinite else { return nil }
            return AnalyzedTake(take: take, item: item, cents: cents, quality: assessment)
        }
        let summary = evidenceSummary(assessments)
        let parameterHash = ((try? OrgRecCoding.lineEncoder.encode(parameters)) ?? Data()).sha256Hex
        let sourceFingerprint = sourceFingerprintSHA256(project: project, parameters: parameters)

        let rankGroups = Dictionary(grouping: analyzed) { rankGrouping(for: $0.item).id }
        let rankProfiles = rankGroups.compactMap { rankID, values -> RankTuningProfile? in
            let grouping = values.map { rankGrouping(for: $0.item) }.sorted {
                if $0.label != $1.label { return $0.label < $1.label }
                return $0.id < $1.id
            }[0]
            let noteGroups = Dictionary(grouping: values) { $0.item.component.midiNote ?? Int.min }
                .filter { $0.key != Int.min }
            guard noteGroups.isEmpty == false else { return nil }
            let points = noteGroups.keys.sorted().map { midi -> RankTuningPoint in
                let group = noteGroups[midi] ?? []
                let cents = group.map(\.cents)
                let evidence = group.map(pitchEvidenceWeight)
                let weights = clippedInverseVarianceWeights(evidence)
                let center = median(cents)
                return RankTuningPoint(
                    midiNote: midi,
                    medianDeviationCents: center,
                    medianAbsoluteDeviationCents: median(cents.map { abs($0 - center) }),
                    takeIDs: group.map(\.take.id).sorted { $0.uuidString < $1.uuidString },
                    qualityWeightedDeviationCents: weightedQuantile(cents, weights: weights, probability: 0.5),
                    lowerObservedBoundCents: weightedQuantile(evidence.map(\.lowerBound), weights: weights, probability: 0.025),
                    upperObservedBoundCents: weightedQuantile(evidence.map(\.upperBound), weights: weights, probability: 0.975),
                    effectiveSampleSize: effectiveSampleSize(weights),
                    medianEvidenceQuality: median(group.map(\.quality.qualityScore)),
                    standardUncertaintyCents: aggregateStandardUncertainty(evidence, weights: weights)
                )
            }
            let slopes = pairwiseSlopes(points.compactMap { point -> (Double, Double)? in
                guard let value = point.qualityWeightedDeviationCents else { return nil }
                return (Double(point.midiNote) / 12, value)
            })
            let slope = repeatedMedianSlope(points)
            let fittedPoints = points.compactMap { point -> (x: Double, y: Double)? in
                guard let y = point.qualityWeightedDeviationCents else { return nil }
                return (Double(point.midiNote) / 12, y)
            }
            let intercept = slope.map { slope in median(fittedPoints.map { $0.y - slope * $0.x }) }
            let residuals = zip(values, values.map { value -> Double in
                guard let slope, let intercept else { return value.cents - median(values.map(\.cents)) }
                return value.cents - (intercept + slope * Double(value.item.component.midiNote ?? 0) / 12)
            })
            let residualCenter = median(residuals.map { $0.1 })
            let residualMAD = median(residuals.map { abs($0.1 - residualCenter) })
            let threshold = max(15, 3.5 * 1.4826 * max(0.25, residualMAD))
            let outliers = residuals.filter { abs($0.1 - residualCenter) > threshold }.map { $0.0.take.id }
            let spanCoverage: Double?
            if let lower = points.map(\.midiNote).min(), let upper = points.map(\.midiNote).max() {
                spanCoverage = Double(points.count) / Double(max(1, upper - lower + 1))
            } else {
                spanCoverage = nil
            }
            return RankTuningProfile(
                rankComponentID: rankID,
                rankLabel: grouping.label,
                points: points,
                stretchCentsPerOctave: slope,
                outlierTakeIDs: outliers.sorted { $0.uuidString < $1.uuidString },
                stretchLowerBoundCentsPerOctave: quantile(slopes, probability: 0.025),
                stretchUpperBoundCentsPerOctave: quantile(slopes, probability: 0.975),
                observedKeySpanCoverage: spanCoverage,
                medianEvidenceQuality: median(values.map(\.quality.qualityScore)),
                slopeMethod: slopes.isEmpty ? nil : "Siegel repeated-median center; bounds are the observed 2.5–97.5% pairwise-slope interval",
                groupingBasis: grouping.basis
            )
        }.sorted {
            let comparison = $0.rankLabel.localizedStandardCompare($1.rankLabel)
            return comparison == .orderedSame ? $0.rankComponentID < $1.rankComponentID : comparison == .orderedAscending
        }

        let sessionsByID = Dictionary(uniqueKeysWithValues: (project.recordingSessions ?? []).map { ($0.id, $0) })
        let sessionGroups = Dictionary(grouping: analyzed.compactMap { value -> (UUID, AnalyzedTake)? in
            guard let sessionID = value.take.provenance?.sessionID else { return nil }
            return (sessionID, value)
        }) { $0.0 }
        let driftReports = sessionGroups.map { sessionID, values -> SessionPitchDriftReport in
            let session = sessionsByID[sessionID]
            let orderedValues = values.sorted { $0.1.take.id.uuidString < $1.1.take.id.uuidString }
            let origin = session?.startedAt ?? orderedValues.map { $0.1.take.startedAt }.min() ?? .distantPast
            let strata = Dictionary(grouping: orderedValues.map(\.1)) { driftStratum(for: $0) }
            let perTargetSlopes = strata.values.compactMap { observations -> Double? in
                let points = observations.map { ($0.take.startedAt.timeIntervalSince(origin) / 3_600, $0.cents) }
                let slopes = pairwiseSlopes(points, minimumPointCount: 2)
                return slopes.isEmpty ? nil : median(slopes)
            }
            let pairComparisonCount = strata.values.reduce(0) { partial, observations in
                partial + pairwiseSlopes(
                    observations.map { ($0.take.startedAt.timeIntervalSince(origin) / 3_600, $0.cents) },
                    minimumPointCount: 2
                ).count
            }
            let hours = orderedValues.map { $0.1.take.startedAt.timeIntervalSince(origin) / 3_600 }
            let duration = hours.isEmpty ? 0 : (hours.max() ?? 0) - (hours.min() ?? 0)
            let supportsDrift = perTargetSlopes.count >= parameters.minimumDriftRepeatedTargets
                && pairComparisonCount >= parameters.minimumDriftPairComparisons
                && duration >= parameters.minimumDriftSpanHours
            return SessionPitchDriftReport(
                sessionID: sessionID,
                sessionCode: session?.sessionCode ?? orderedValues.first?.1.take.provenance?.sessionCode ?? sessionID.uuidString,
                analyzedTakeCount: orderedValues.count,
                driftCentsPerHour: supportsDrift ? median(perTargetSlopes) : nil,
                medianDeviationCents: median(orderedValues.map { $0.1.cents }),
                temperatureCelsius: session?.environment.temperatureCelsius ?? orderedValues.first?.1.take.provenance?.environment.temperatureCelsius,
                driftLowerBoundCentsPerHour: supportsDrift ? quantile(perTargetSlopes, probability: 0.025) : nil,
                driftUpperBoundCentsPerHour: supportsDrift ? quantile(perTargetSlopes, probability: 0.975) : nil,
                durationHours: duration,
                medianEvidenceQuality: median(orderedValues.map { $0.1.quality.qualityScore }),
                slopeMethod: supportsDrift ? "Median of within-target pair slopes; bounds are the observed 2.5–97.5% target-slope interval" : nil,
                repeatedTargetCount: perTargetSlopes.count,
                pairComparisonCount: pairComparisonCount,
                applicability: supportsDrift ? "applicable" : "indeterminate"
            )
        }.sorted {
            let comparison = $0.sessionCode.localizedStandardCompare($1.sessionCode)
            return comparison == .orderedSame ? $0.sessionID.uuidString < $1.sessionID.uuidString : comparison == .orderedAscending
        }

        let fingerprints = analyzed.compactMap(harmonicFingerprint)
        var similarities: [AcousticSimilarityCandidate] = []
        if fingerprints.count >= 2 {
            for left in 0..<(fingerprints.count - 1) {
                for right in (left + 1)..<fingerprints.count {
                    let first = fingerprints[left]
                    let second = fingerprints[right]
                    let sameNote = first.analyzed.item.component.midiNote == second.analyzed.item.component.midiNote
                    let distinctTargets = driftStratum(for: first.analyzed) != driftStratum(for: second.analyzed)
                    let comparableContext = first.analyzed.item.setupID == second.analyzed.item.setupID
                        && (first.analyzed.take.analysisReferenceChannel ?? 0) == (second.analyzed.take.analysisReferenceChannel ?? 0)
                    guard sameNote, let comparison = cosine(first.amplitudes, second.amplitudes),
                          distinctTargets, comparableContext,
                          comparison.count >= parameters.minimumSimilarityHarmonics,
                          comparison.similarity >= parameters.similarityThreshold else { continue }
                    let quality = sqrt(first.analyzed.quality.qualityScore * second.analyzed.quality.qualityScore)
                    let evidenceScore = comparison.similarity * quality * min(1, Double(comparison.count) / 8)
                    let orderedIDs = [first.analyzed.take.id, second.analyzed.take.id].sorted { $0.uuidString < $1.uuidString }
                    similarities.append(AcousticSimilarityCandidate(
                        firstTakeID: orderedIDs[0],
                        secondTakeID: orderedIDs[1],
                        cosineSimilarity: comparison.similarity,
                        sameIntendedMIDINote: true,
                        reason: "Review candidate based on aligned relative harmonic levels; provenance and physical-pipe evidence are required before asserting identity.",
                        sharedPartialCount: comparison.count,
                        evidenceScore: evidenceScore
                    ))
                }
            }
        }
        similarities.sort {
            if ($0.evidenceScore ?? 0) != ($1.evidenceScore ?? 0) { return ($0.evidenceScore ?? 0) > ($1.evidenceScore ?? 0) }
            if $0.cosineSimilarity != $1.cosineSimilarity { return $0.cosineSimilarity > $1.cosineSimilarity }
            return $0.id < $1.id
        }
        let anomalies = acousticAnomalies(rankGroups: rankGroups, parameters: parameters)

        var notes = [
            "Collection results are evidence-qualified derived observations and never merge physical sound targets automatically.",
            "Quality scores gate aggregation but do not erase excluded analyses; every eligible take retains a machine-readable assessment.",
            "Robust slope bounds describe the observed pairwise-slope distribution and are not population confidence intervals.",
        ]
        if summary.excludedCount > 0 {
            notes.append("\(summary.excludedCount) of \(summary.eligibleTakeCount) eligible take(s) were excluded from aggregate inference; reason counts are retained.")
        }
        if summary.aggregateCoverage < 0.5 {
            notes.append("Aggregate evidence coverage is below 50%; collection-level trends are limited.")
        }
        if analyzed.count < 12 { notes.append("Fewer than 12 evidence-qualified pitched takes are available; collection trends remain exploratory.") }
        return CollectionAnalysisReport(
            id: id,
            analyzedAt: analyzedAt,
            sourceAnalysisRunIDs: Array(Set(analyzed.compactMap { $0.take.analysis?.analysisRunID })).sorted { $0.uuidString < $1.uuidString },
            rankTuningProfiles: rankProfiles,
            sessionPitchDrift: driftReports,
            acousticSimilarityCandidates: Array(similarities.prefix(parameters.maximumSimilarityCandidates)),
            notes: notes,
            parameters: parameters,
            parameterSHA256: parameterHash,
            sourceFingerprintSHA256: sourceFingerprint,
            evidenceSummary: summary,
            takeEvidence: assessments.sorted { $0.takeID.uuidString < $1.takeID.uuidString },
            acousticAnomalyCandidates: anomalies,
            assessedTakeIDs: assessments.map(\.takeID).sorted { $0.uuidString < $1.uuidString },
            contributingTakeIDs: analyzed.map(\.take.id).sorted { $0.uuidString < $1.uuidString }
        )
    }

    public static func sourceFingerprintSHA256(
        project: OrgRecProject,
        parameters: CollectionAnalysisParameters = CollectionAnalysisParameters()
    ) -> String {
        let source = SourceFingerprintEnvelope(
            parameters: parameters,
            roadmap: project.roadmap.sorted { $0.id.uuidString < $1.id.uuidString },
            takes: project.takes.sorted { $0.id.uuidString < $1.id.uuidString },
            sessions: (project.recordingSessions ?? []).sorted { $0.id.uuidString < $1.id.uuidString }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        return ((try? encoder.encode(source)) ?? Data("unencodable-collection-analysis-source".utf8)).sha256Hex
    }

    public static func isCurrent(_ report: CollectionAnalysisReport, for project: OrgRecProject) -> Bool {
        guard let parameters = report.parameters, let fingerprint = report.sourceFingerprintSHA256 else { return false }
        return fingerprint == sourceFingerprintSHA256(project: project, parameters: parameters)
    }

    /// Retains an identical report when its complete analytical source is
    /// unchanged, and creates a new immutable revision when evidence changes.
    public static func refreshed(
        project: OrgRecProject,
        parameters: CollectionAnalysisParameters? = nil
    ) -> CollectionAnalysisReport? {
        let resolvedParameters = parameters ?? project.collectionAnalysis?.parameters ?? CollectionAnalysisParameters()
        if let existing = project.collectionAnalysis,
           existing.parameters == resolvedParameters,
           isCurrent(existing, for: project) {
            return existing
        }
        return analyze(project: project, parameters: resolvedParameters)
    }

    private static func evidenceAssessment(
        take: TakeRecord,
        item: RoadmapItem,
        parameters: CollectionAnalysisParameters
    ) -> TakeEvidenceAssessment {
        let rankID = rankGrouping(for: item).id
        let midi = item.component.midiNote ?? -1
        guard let analysis = take.analysis else {
            return excludedAssessment(take: take, rankID: rankID, midi: midi, reason: "missing-analysis")
        }
        guard let cents = analysis.centsDeviation, cents.isFinite else {
            return excludedAssessment(take: take, rankID: rankID, midi: midi, reason: "missing-finite-pitch-deviation", flags: analysis.qualityFlags)
        }
        if analysis.pitchApplicability == .polyphonic || analysis.pitchApplicability == .nonPitched {
            return excludedAssessment(take: take, rankID: rankID, midi: midi, reason: "pitch-analysis-not-monophonic", flags: analysis.qualityFlags)
        }
        if analysis.pitchEstimatorComparison?.severity == .critical {
            return excludedAssessment(take: take, rankID: rankID, midi: midi, reason: "critical-estimator-mismatch", flags: analysis.qualityFlags)
        }
        if take.status == .rejected || take.status == .failed {
            return excludedAssessment(take: take, rankID: rankID, midi: midi, reason: "rejected-or-failed-take", flags: analysis.qualityFlags)
        }
        if take.status == .recording || take.status == .analyzing {
            return excludedAssessment(take: take, rankID: rankID, midi: midi, reason: "take-not-finalized", flags: analysis.qualityFlags)
        }

        var dimensions: [(Double, Double)] = []
        if let confidence = analysis.confidence, confidence.isFinite {
            dimensions.append((clamp01(confidence), 0.35))
        }
        if let voiced = analysis.pitchTrackSummary?.voicedRatio, voiced.isFinite {
            dimensions.append((clamp01(voiced), 0.15))
        }
        if let comparison = analysis.pitchEstimatorComparison {
            let score: Double = switch comparison.severity {
            case .agreement: 1
            case .material: 0.45
            case .critical: 0
            case .unavailable: 0.65
            }
            dimensions.append((score, 0.15))
        }
        if let snr = analysis.signalToNoiseDB, snr.isFinite {
            dimensions.append((clamp01((snr - 10) / 30), 0.10))
        }
        let partialCount = max(take.partialTracks?.filter { ($0.confidence ?? 1) >= 0.25 }.count ?? 0, analysis.spectralSummary?.detectedPartialCount ?? 0)
        if partialCount > 0 {
            dimensions.append((min(1, Double(partialCount) / 8), 0.10))
        }
        dimensions.append((analysis.clippedSamples == 0 ? 1 : 0, 0.10))
        let reviewScore: Double = switch take.status {
        case .accepted: 1
        case .recorded: 0.8
        case .needsReview, .recovered: 0.45
        case .analyzing, .recording: 0.25
        case .rejected, .failed: 0
        }
        dimensions.append((reviewScore, 0.05))
        let denominator = dimensions.reduce(0) { $0 + $1.1 }
        var score = denominator > 0 ? dimensions.reduce(0) { $0 + $1.0 * $1.1 } / denominator : 0
        score -= min(0.30, Double(analysis.qualityFlags.count) * 0.04)
        if analysis.clippedSamples > 0 { score -= 0.15 }
        score = clamp01(score)
        let tier: AnalysisEvidenceTier
        if score >= parameters.highQualityScore {
            tier = .high
        } else if score >= parameters.moderateQualityScore {
            tier = .moderate
        } else if score >= parameters.minimumAggregateQualityScore {
            tier = .limited
        } else {
            tier = .excluded
        }
        var reasons: [String] = []
        if tier == .excluded { reasons.append("quality-score-below-aggregate-threshold") }
        var flags = analysis.qualityFlags
        if analysis.pitchEstimatorComparison?.severity == .material { flags.append("Material estimator disagreement reduced evidence quality.") }
        return TakeEvidenceAssessment(
            takeID: take.id,
            rankComponentID: rankID,
            midiNote: midi,
            qualityScore: score,
            tier: tier,
            includedInAggregates: tier != .excluded,
            availableQualityDimensions: dimensions.count,
            exclusionReasons: reasons,
            qualityFlags: Array(Set(flags)).sorted()
        )
    }

    private static func excludedAssessment(
        take: TakeRecord,
        rankID: String,
        midi: Int,
        reason: String,
        flags: [String] = []
    ) -> TakeEvidenceAssessment {
        TakeEvidenceAssessment(
            takeID: take.id,
            rankComponentID: rankID,
            midiNote: midi,
            qualityScore: 0,
            tier: .excluded,
            includedInAggregates: false,
            availableQualityDimensions: 0,
            exclusionReasons: [reason],
            qualityFlags: flags
        )
    }

    private static func evidenceSummary(_ assessments: [TakeEvidenceAssessment]) -> CollectionEvidenceSummary {
        let analyzed = assessments.filter { !$0.exclusionReasons.contains("missing-analysis") && !$0.exclusionReasons.contains("missing-finite-pitch-deviation") }
        let aggregate = assessments.filter(\.includedInAggregates)
        let reasonGroups = Dictionary(grouping: assessments.flatMap(\.exclusionReasons), by: { $0 })
        return CollectionEvidenceSummary(
            eligibleTakeCount: assessments.count,
            analyzedTakeCount: analyzed.count,
            aggregateTakeCount: aggregate.count,
            highQualityCount: assessments.filter { $0.tier == .high }.count,
            moderateQualityCount: assessments.filter { $0.tier == .moderate }.count,
            limitedQualityCount: assessments.filter { $0.tier == .limited }.count,
            excludedCount: assessments.filter { $0.tier == .excluded }.count,
            aggregateCoverage: assessments.isEmpty ? 0 : Double(aggregate.count) / Double(assessments.count),
            medianQualityScore: aggregate.isEmpty ? nil : median(aggregate.map(\.qualityScore)),
            exclusions: reasonGroups.map { AnalysisExclusionCount(reason: $0.key, count: $0.value.count) }.sorted { $0.reason < $1.reason }
        )
    }

    private static func harmonicFingerprint(_ value: AnalyzedTake) -> HarmonicFingerprint? {
        guard let partials = value.take.partialTracks else { return nil }
        let peaks = partials.compactMap { partial -> (Int, Double)? in
            guard (1...16).contains(partial.harmonicNumber), let peak = partial.peakDB, peak.isFinite,
                  (partial.confidence ?? 1) >= 0.25 else { return nil }
            return (partial.harmonicNumber, peak)
        }
        guard peaks.count >= 3, let maximum = peaks.map({ $0.1 }).max() else { return nil }
        var amplitudes: [Int: Double] = [:]
        for (harmonic, peak) in peaks {
            amplitudes[harmonic] = max(amplitudes[harmonic] ?? 0, pow(10, (peak - maximum) / 20))
        }
        guard amplitudes.count >= 3 else { return nil }
        return HarmonicFingerprint(analyzed: value, amplitudes: amplitudes)
    }

    private static func acousticAnomalies(
        rankGroups: [String: [AnalyzedTake]],
        parameters: CollectionAnalysisParameters
    ) -> [AcousticAnomalyCandidate] {
        var candidates: [AcousticAnomalyCandidate] = []
        for (rankID, values) in rankGroups where values.count >= parameters.minimumAnomalyGroupSize {
            let featureValues = Dictionary(uniqueKeysWithValues: values.map { ($0.take.id, acousticFeatures($0)) })
            let featureNames = Set(featureValues.values.flatMap(\.keys))
            var distributions: [String: (center: Double, scale: Double)] = [:]
            for feature in featureNames {
                let observed = values.compactMap { featureValues[$0.take.id]?[feature] }
                guard observed.count >= parameters.minimumAnomalyGroupSize else { continue }
                let center = median(observed)
                let mad = median(observed.map { abs($0 - center) })
                distributions[feature] = (center, max(featureScaleFloor(feature), mad))
            }
            for value in values {
                let scores = distributions.compactMap { feature, distribution -> AcousticAnomalyFeatureScore? in
                    guard let observed = featureValues[value.take.id]?[feature] else { return nil }
                    let scale = feature == "tuning-deviation-cents"
                        ? max(distribution.scale, pitchEvidenceWeight(value).standardUncertainty)
                        : distribution.scale
                    return AcousticAnomalyFeatureScore(
                        feature: feature,
                        value: observed,
                        robustCenter: distribution.center,
                        robustZScore: 0.674_489_75 * (observed - distribution.center) / scale
                    )
                }
                guard !scores.isEmpty else { continue }
                let distance = sqrt(scores.reduce(0) { $0 + $1.robustZScore * $1.robustZScore } / Double(scores.count))
                guard distance >= parameters.anomalyWarningScore else { continue }
                let strongest = scores.sorted {
                    abs($0.robustZScore) == abs($1.robustZScore)
                        ? $0.feature < $1.feature
                        : abs($0.robustZScore) > abs($1.robustZScore)
                }
                let labels = strongest.prefix(3).map { "\($0.feature) z=\($0.robustZScore.formatted(.number.precision(.fractionLength(2))))" }
                candidates.append(AcousticAnomalyCandidate(
                    takeID: value.take.id,
                    rankComponentID: rankID,
                    rankLabel: value.item.component.label,
                    midiNote: value.item.component.midiNote ?? -1,
                    robustDistance: distance,
                    severity: distance >= parameters.anomalyCriticalScore ? .critical : .warning,
                    evidenceDimensionCount: scores.count,
                    qualityScore: value.quality.qualityScore,
                    featureScores: strongest,
                    interpretation: "Multivariate within-rank review candidate (\(labels.joined(separator: ", "))); not a fault or construction diagnosis."
                ))
            }
        }
        return candidates.sorted {
            if $0.severity != $1.severity { return $0.severity == .critical }
            if $0.robustDistance != $1.robustDistance { return $0.robustDistance > $1.robustDistance }
            return $0.takeID.uuidString < $1.takeID.uuidString
        }
    }

    private static func acousticFeatures(_ value: AnalyzedTake) -> [String: Double] {
        guard let analysis = value.take.analysis else { return [:] }
        var result = ["tuning-deviation-cents": value.cents]
        if let frequency = analysis.frequencyHz, frequency > 0, frequency.isFinite {
            if let centroid = analysis.spectralSummary?.spectralCentroidHz, centroid.isFinite {
                result["spectral-centroid-f0-ratio"] = centroid / frequency
            }
            if let rolloff = analysis.spectralSummary?.spectralRolloff85Hz, rolloff.isFinite {
                result["spectral-rolloff-f0-ratio"] = rolloff / frequency
            }
        }
        if let value = analysis.spectralSummary?.oddEvenEnergyRatioDB, value.isFinite { result["odd-even-energy-ratio-db"] = value }
        if let value = analysis.spectralSummary?.weightedInharmonicityCents, value.isFinite { result["weighted-inharmonicity-cents"] = value }
        if let value = analysis.pipeSoundBehavior?.attackDurationFundamentalPeriods, value.isFinite { result["attack-duration-fundamental-periods"] = value }
        if let value = analysis.pipeSoundBehavior?.sustainStationarity, value.isFinite { result["sustain-stationarity"] = value }
        if let value = analysis.pipeSoundBehavior?.amplitudeModulationDepthDB, value.isFinite { result["amplitude-modulation-depth-db"] = value }
        if let value = analysis.pipeSoundBehavior?.frequencyModulationDepthCents, value.isFinite { result["frequency-modulation-depth-cents"] = value }
        return result
    }

    private static func featureScaleFloor(_ feature: String) -> Double {
        switch feature {
        case "tuning-deviation-cents": 1
        case "spectral-centroid-f0-ratio", "spectral-rolloff-f0-ratio": 0.05
        case "odd-even-energy-ratio-db", "amplitude-modulation-depth-db": 0.5
        case "weighted-inharmonicity-cents", "frequency-modulation-depth-cents": 0.5
        case "attack-duration-fundamental-periods": 0.25
        case "sustain-stationarity": 0.02
        default: 1e-6
        }
    }

    private static func rankGrouping(for item: RoadmapItem) -> RankGrouping {
        if let parent = item.component.parentComponentID, !parent.isEmpty {
            return RankGrouping(id: parent, label: item.component.label, basis: "declared-parent-component")
        }
        if item.coverageKind == .customRegistration, let registrationID = item.registrationID {
            return RankGrouping(
                id: "urn:uuid:\(registrationID.uuidString.lowercased())",
                label: item.component.label,
                basis: "registration-anchor"
            )
        }
        let signature = [
            item.component.locator.organMDVSID,
            item.component.division.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            item.component.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            item.component.footHeight?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "",
        ].joined(separator: "|")
        return RankGrouping(
            id: "urn:orgrec:inferred-rank:\(Data(signature.utf8).sha256Hex)",
            label: item.component.label,
            basis: "inferred-division-label-footage-signature"
        )
    }

    /// Drift is estimated only from repeated measurements of a comparable
    /// acoustic target in one setup/channel stratum. Different notes are never
    /// regressed against clock time.
    private static func driftStratum(for value: AnalyzedTake) -> String {
        let target = value.item.physicalSoundTargetID
            ?? "\(rankGrouping(for: value.item).id)|midi:\(value.item.component.midiNote ?? -1)"
        return [
            target,
            value.item.setupID?.uuidString.lowercased() ?? "setup:unspecified",
            "channel:\(value.take.analysisReferenceChannel ?? 0)",
        ].joined(separator: "|")
    }

    private static func pitchEvidenceWeight(_ value: AnalyzedTake) -> PitchEvidenceWeight {
        let analysis = value.take.analysis
        var uncertaintyCandidates: [Double] = []
        var lower = value.cents
        var upper = value.cents
        if let summary = analysis?.pitchTrackSummary {
            if let low = summary.lowerUncertaintyCents, let high = summary.upperUncertaintyCents,
               low.isFinite, high.isFinite, high >= low {
                lower = low
                upper = high
                uncertaintyCandidates.append(max(0.25, (high - low) / 3.92))
            }
            if let mad = summary.medianAbsoluteDeviationCents, mad.isFinite, mad >= 0 {
                uncertaintyCandidates.append(max(0.25, 1.4826 * mad))
            }
        }
        if let difference = analysis?.pitchEstimatorComparison?.differenceCents, difference.isFinite {
            uncertaintyCandidates.append(max(0.25, abs(difference) / 2))
        }
        if let confidence = analysis?.confidence, confidence.isFinite {
            uncertaintyCandidates.append(max(0.25, (1 - clamp01(confidence)) * 20))
        }
        let uncertainty = max(0.25, uncertaintyCandidates.max() ?? 5)
        if lower == value.cents, upper == value.cents {
            lower = value.cents - 1.96 * uncertainty
            upper = value.cents + 1.96 * uncertainty
        }
        return PitchEvidenceWeight(
            value: value.cents,
            quality: max(0.001, value.quality.qualityScore),
            standardUncertainty: uncertainty,
            lowerBound: lower,
            upperBound: upper
        )
    }

    private static func clippedInverseVarianceWeights(_ evidence: [PitchEvidenceWeight]) -> [Double] {
        let raw = evidence.map { $0.quality / max(0.0625, $0.standardUncertainty * $0.standardUncertainty) }
        guard let minimum = raw.filter({ $0 > 0 }).min() else { return raw }
        return raw.map { min($0, minimum * 25) }
    }

    private static func aggregateStandardUncertainty(
        _ evidence: [PitchEvidenceWeight],
        weights: [Double]
    ) -> Double? {
        guard evidence.count == weights.count, !evidence.isEmpty else { return nil }
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        let normalizedVariance = zip(evidence, weights).reduce(0) {
            $0 + $1.1 * $1.0.standardUncertainty * $1.0.standardUncertainty
        } / total
        let effective = effectiveSampleSize(weights) ?? 1
        return sqrt(normalizedVariance / max(1, effective))
    }

    private static func repeatedMedianSlope(_ points: [RankTuningPoint]) -> Double? {
        let values = points.compactMap { point -> (Double, Double)? in
            guard let value = point.qualityWeightedDeviationCents else { return nil }
            return (Double(point.midiNote) / 12, value)
        }
        guard values.count >= 3 else { return nil }
        let perPoint = values.indices.compactMap { index -> Double? in
            let slopes = values.indices.compactMap { other -> Double? in
                guard index != other else { return nil }
                let delta = values[other].0 - values[index].0
                guard abs(delta) > 1e-12 else { return nil }
                let slope = (values[other].1 - values[index].1) / delta
                return slope.isFinite ? slope : nil
            }
            return slopes.isEmpty ? nil : median(slopes)
        }
        return perPoint.isEmpty ? nil : median(perPoint)
    }

    private static func parametersAreValid(_ value: CollectionAnalysisParameters) -> Bool {
        (0...1).contains(value.minimumAggregateQualityScore)
            && (0...1).contains(value.moderateQualityScore)
            && (0...1).contains(value.highQualityScore)
            && value.minimumAggregateQualityScore <= value.moderateQualityScore
            && value.moderateQualityScore <= value.highQualityScore
            && value.minimumAnomalyGroupSize >= 3
            && value.anomalyWarningScore > 0
            && value.anomalyCriticalScore >= value.anomalyWarningScore
            && (0...1).contains(value.similarityThreshold)
            && value.minimumSimilarityHarmonics >= 3
            && value.maximumSimilarityCandidates > 0
            && value.minimumDriftRepeatedTargets >= 1
            && value.minimumDriftPairComparisons >= 1
            && value.minimumDriftSpanHours >= 0
    }

    private static func clamp01(_ value: Double) -> Double { min(1, max(0, value)) }

    private static func median(_ values: [Double]) -> Double {
        quantile(values, probability: 0.5) ?? 0
    }

    private static func quantile(_ values: [Double], probability: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let position = clamp01(probability) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        if lower == upper { return sorted[lower] }
        let fraction = position - Double(lower)
        return sorted[lower] * (1 - fraction) + sorted[upper] * fraction
    }

    private static func weightedQuantile(_ values: [Double], weights: [Double], probability: Double) -> Double? {
        guard values.count == weights.count, !values.isEmpty else { return nil }
        let pairs = zip(values, weights).filter { $0.0.isFinite && $0.1.isFinite && $0.1 > 0 }.sorted { $0.0 < $1.0 }
        let total = pairs.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return nil }
        let target = clamp01(probability) * total
        var cumulative = 0.0
        for pair in pairs {
            cumulative += pair.1
            if cumulative >= target { return pair.0 }
        }
        return pairs.last?.0
    }

    private static func effectiveSampleSize(_ weights: [Double]) -> Double? {
        let positive = weights.filter { $0.isFinite && $0 > 0 }
        let total = positive.reduce(0, +)
        let squares = positive.reduce(0) { $0 + $1 * $1 }
        return squares > 0 ? total * total / squares : nil
    }

    private static func pairwiseSlopes(
        _ values: [(Double, Double)],
        minimumPointCount: Int = 3
    ) -> [Double] {
        guard values.count >= minimumPointCount else { return [] }
        var result: [Double] = []
        for left in 0..<(values.count - 1) {
            for right in (left + 1)..<values.count {
                let delta = values[right].0 - values[left].0
                if abs(delta) > 1e-12 {
                    let slope = (values[right].1 - values[left].1) / delta
                    if slope.isFinite { result.append(slope) }
                }
            }
        }
        return result
    }

    private static func cosine(_ left: [Int: Double], _ right: [Int: Double]) -> (similarity: Double, count: Int)? {
        let harmonics = Set(left.keys).intersection(right.keys).sorted()
        guard harmonics.count >= 3 else { return nil }
        var dot = 0.0
        var leftEnergy = 0.0
        var rightEnergy = 0.0
        for harmonic in harmonics {
            guard let l = left[harmonic], let r = right[harmonic] else { continue }
            dot += l * r
            leftEnergy += l * l
            rightEnergy += r * r
        }
        let denominator = sqrt(leftEnergy * rightEnergy)
        return denominator > 0 ? (dot / denominator, harmonics.count) : nil
    }
}
