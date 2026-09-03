import Foundation

public struct RankFingerprintParameters: Codable, Hashable, Sendable {
    public var minimumObservations: Int
    public var minimumSegmentObservations: Int
    public var maximumTransitions: Int
    public var maximumAdjacentGapSemitones: Int
    public var minimumBICImprovement: Double
    public var significanceLevel: Double
    public var permutationCount: Int
    public var randomSeed: UInt64

    public init(
        minimumObservations: Int = 8,
        minimumSegmentObservations: Int = 4,
        maximumTransitions: Int = 2,
        maximumAdjacentGapSemitones: Int = 4,
        minimumBICImprovement: Double = 10,
        significanceLevel: Double = 0.05,
        permutationCount: Int = 199,
        randomSeed: UInt64 = 0x4f52475245434650
    ) {
        self.minimumObservations = minimumObservations
        self.minimumSegmentObservations = minimumSegmentObservations
        self.maximumTransitions = maximumTransitions
        self.maximumAdjacentGapSemitones = maximumAdjacentGapSemitones
        self.minimumBICImprovement = minimumBICImprovement
        self.significanceLevel = significanceLevel
        self.permutationCount = permutationCount
        self.randomSeed = randomSeed
    }
}

public struct RankFingerprintPoint: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { observationID }
    public var observationID: UUID
    public var midiNote: Int
    public var normalizedSpectralCentroid: Double
    public var weightedAverageSlopeDBPerOctave: Double
    public var evenToOddEnergyRatioDB: Double?
    public var relativePartialLevelsDB: [Double?]
}

public struct RankFingerprintTrend: Codable, Hashable, Identifiable, Sendable {
    public var id: String { feature }
    public var feature: String
    public var interceptAtMIDIMiddle: Double
    public var linearChangePerOctave: Double
    public var quadraticChangePerOctaveSquared: Double
    public var residualRMSE: Double
}

public struct RankConstructionTransition: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(lowerMIDINote)-\(upperMIDINote)" }
    public var lowerMIDINote: Int
    public var upperMIDINote: Int
    public var lowerNoteName: String
    public var upperNoteName: String
    public var bicImprovementForSelectedSegmentation: Double
    public var familyWisePermutationPValue: Double
    public var standardizedEffectSize: Double
    public var evidenceStrength: String
    public var interpretation: String
}

public struct PitchDependentRankFingerprint: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var algorithmVersion: String
    public var generatedAt: Date
    public var rankComponentID: String
    public var rankLabel: String
    public var featureSchemaVersion: String
    public var parameters: RankFingerprintParameters
    public var parameterSHA256: String
    public var points: [RankFingerprintPoint]
    public var trends: [RankFingerprintTrend]
    public var bassFingerprint: [String: Double]?
    public var middleFingerprint: [String: Double]?
    public var trebleFingerprint: [String: Double]?
    public var transitions: [RankConstructionTransition]
    public var selectedSegmentCount: Int
    public var baselineBIC: Double?
    public var selectedBIC: Double?
    public var applicability: TimbreAnalysisApplicability
    public var warnings: [String]

    public init(
        contractVersion: String = "orgrec-pitch-dependent-rank-fingerprint/1",
        algorithmVersion: String = "orgrec-multivariate-segmented-rank-trajectory/1",
        generatedAt: Date = .now,
        rankComponentID: String,
        rankLabel: String,
        featureSchemaVersion: String,
        parameters: RankFingerprintParameters,
        parameterSHA256: String,
        points: [RankFingerprintPoint],
        trends: [RankFingerprintTrend],
        bassFingerprint: [String: Double]?,
        middleFingerprint: [String: Double]?,
        trebleFingerprint: [String: Double]?,
        transitions: [RankConstructionTransition],
        selectedSegmentCount: Int,
        baselineBIC: Double?,
        selectedBIC: Double?,
        applicability: TimbreAnalysisApplicability,
        warnings: [String]
    ) {
        self.contractVersion = contractVersion
        self.algorithmVersion = algorithmVersion
        self.generatedAt = generatedAt
        self.rankComponentID = rankComponentID
        self.rankLabel = rankLabel
        self.featureSchemaVersion = featureSchemaVersion
        self.parameters = parameters
        self.parameterSHA256 = parameterSHA256
        self.points = points
        self.trends = trends
        self.bassFingerprint = bassFingerprint
        self.middleFingerprint = middleFingerprint
        self.trebleFingerprint = trebleFingerprint
        self.transitions = transitions
        self.selectedSegmentCount = selectedSegmentCount
        self.baselineBIC = baselineBIC
        self.selectedBIC = selectedBIC
        self.applicability = applicability
        self.warnings = warnings
    }
}

public enum RankFingerprintAnalyzer {
    private static let featureNames = ["centroid", "slopeDBPerOctave", "evenOddDB"]
        + (1...8).map { "partial\($0)RelativeDB" }

    private struct WorkingPoint {
        var source: RankFingerprintPoint
        var raw: [Double]
        var standardized: [Double]
    }

    private struct Segmentation {
        var segmentCount: Int
        var boundaries: [Int]
        var residualSumSquares: Double
        var bic: Double
    }

    public static func analyze(
        rankComponentID: String,
        rankLabel: String,
        observations: [PipeTimbreObservation],
        parameters: RankFingerprintParameters = RankFingerprintParameters()
    ) -> PitchDependentRankFingerprint {
        let candidatePoints = observations.compactMap { observation -> RankFingerprintPoint? in
            guard let midi = observation.midiNote,
                  let centroid = observation.normalizedSpectralCentroid,
                  let slope = observation.weightedAverageSlopeDBPerOctave,
                  centroid.isFinite, slope.isFinite else { return nil }
            let partials = Dictionary(uniqueKeysWithValues: observation.partials.map { ($0.harmonicNumber, $0.relativeLevelDB) })
            return RankFingerprintPoint(
                observationID: observation.id,
                midiNote: midi,
                normalizedSpectralCentroid: centroid,
                weightedAverageSlopeDBPerOctave: slope,
                evenToOddEnergyRatioDB: observation.evenToOddEnergyRatioDB,
                relativePartialLevelsDB: (1...8).map { partials[$0] }
            )
        }.sorted {
            if $0.midiNote != $1.midiNote { return $0.midiNote < $1.midiNote }
            let leftEvidence = $0.relativePartialLevelsDB.compactMap { $0 }.count
            let rightEvidence = $1.relativePartialLevelsDB.compactMap { $0 }.count
            if leftEvidence != rightEvidence { return leftEvidence > rightEvidence }
            return $0.observationID.uuidString < $1.observationID.uuidString
        }
        let groupedPoints = Dictionary(grouping: candidatePoints, by: \.midiNote)
        let points = groupedPoints.keys.sorted().compactMap { groupedPoints[$0]?.first }
        let duplicateCount = candidatePoints.count - points.count
        let duplicateWarnings = duplicateCount > 0
            ? ["Discarded \(duplicateCount) duplicate key observation(s) after deterministically retaining the candidate with the most partial evidence; the exported trajectory has one point per key."]
            : []
        let parameterHash = ((try? OrgRecCoding.lineEncoder.encode(parameters)) ?? Data()).sha256Hex
        let parameterErrors = parameterValidationErrors(parameters)
        if !parameterErrors.isEmpty {
            return PitchDependentRankFingerprint(
                rankComponentID: rankComponentID,
                rankLabel: rankLabel,
                featureSchemaVersion: TimbreRankFeatureVectorizer.version,
                parameters: parameters,
                parameterSHA256: parameterHash,
                points: points,
                trends: trends(points),
                bassFingerprint: bandFingerprint(points, band: .bass),
                middleFingerprint: bandFingerprint(points, band: .middle),
                trebleFingerprint: bandFingerprint(points, band: .treble),
                transitions: [],
                selectedSegmentCount: points.isEmpty ? 0 : 1,
                baselineBIC: nil,
                selectedBIC: nil,
                applicability: points.isEmpty ? .notApplicable : .limited,
                warnings: duplicateWarnings + ["Transition detection parameters are invalid: \(parameterErrors.joined(separator: "; ")). The descriptive trajectory is retained without a transition claim."]
            )
        }
        guard points.count >= parameters.minimumObservations else {
            return PitchDependentRankFingerprint(
                rankComponentID: rankComponentID,
                rankLabel: rankLabel,
                featureSchemaVersion: TimbreRankFeatureVectorizer.version,
                parameters: parameters,
                parameterSHA256: parameterHash,
                points: points,
                trends: trends(points),
                bassFingerprint: bandFingerprint(points, band: .bass),
                middleFingerprint: bandFingerprint(points, band: .middle),
                trebleFingerprint: bandFingerprint(points, band: .treble),
                transitions: [],
                selectedSegmentCount: points.isEmpty ? 0 : 1,
                baselineBIC: nil,
                selectedBIC: nil,
                applicability: points.count >= 3 ? .limited : .notApplicable,
                warnings: duplicateWarnings + ["At least \(parameters.minimumObservations) usable pitch-ordered pipes are required for construction-transition detection; the descriptive fingerprint is retained."]
            )
        }

        let rawRows = points.map(rawVector)
        let normalization = robustNormalization(rawRows)
        let working = zip(points, rawRows).map { point, raw in
            WorkingPoint(
                source: point,
                raw: raw,
                standardized: zip(raw, zip(normalization.centers, normalization.scales)).map { ($0 - $1.0) / $1.1 }
            )
        }
        let allowedBoundaries = Set((1..<working.count).filter {
            working[$0].source.midiNote - working[$0 - 1].source.midiNote <= parameters.maximumAdjacentGapSemitones
        })
        let segmentations = bestSegmentations(
            rows: working.map(\.standardized),
            midi: working.map { Double($0.source.midiNote) },
            allowedBoundaries: allowedBoundaries,
            parameters: parameters
        )
        guard let baseline = segmentations.first(where: { $0.segmentCount == 1 }) else {
            return inapplicableResult(rankComponentID: rankComponentID, rankLabel: rankLabel, points: points, parameters: parameters, parameterHash: parameterHash, priorWarnings: duplicateWarnings)
        }
        let selected = segmentations.min(by: { $0.bic < $1.bic }) ?? baseline
        let bicImprovement = baseline.bic - selected.bic
        var warnings: [String] = duplicateWarnings
        let wideGaps = (1..<working.count).filter { !allowedBoundaries.contains($0) }
        if !wideGaps.isEmpty {
            warnings.append("\(wideGaps.count) pitch gap(s) exceeded \(parameters.maximumAdjacentGapSemitones) semitones; no construction boundary can be asserted across them.")
        }

        var transitions: [RankConstructionTransition] = []
        if selected.segmentCount > 1, bicImprovement >= parameters.minimumBICImprovement {
            let pValue = familyWisePermutationPValue(
                observedBICImprovement: bicImprovement,
                working: working,
                allowedBoundaries: allowedBoundaries,
                parameters: parameters
            )
            if pValue <= parameters.significanceLevel {
                for boundary in selected.boundaries {
                    let lower = working[boundary - 1]
                    let upper = working[boundary]
                    let effect = localEffectSize(rows: working.map(\.standardized), boundary: boundary, minimumSegment: parameters.minimumSegmentObservations)
                    transitions.append(RankConstructionTransition(
                        lowerMIDINote: lower.source.midiNote,
                        upperMIDINote: upper.source.midiNote,
                        lowerNoteName: noteName(lower.source.midiNote),
                        upperNoteName: noteName(upper.source.midiNote),
                        bicImprovementForSelectedSegmentation: bicImprovement,
                        familyWisePermutationPValue: pValue,
                        standardizedEffectSize: effect,
                        evidenceStrength: evidenceStrength(deltaBIC: bicImprovement, pValue: pValue),
                        interpretation: "A discontinuity in the multivariate pitch trajectory is supported here. Review source metadata, rank breaks, pipe construction, voicing, sample processing, and recording perspective before assigning a physical cause."
                    ))
                }
            } else {
                warnings.append("The best segmented trajectory improved BIC by \(format(bicImprovement, 1)), but its family-wise permutation p-value \(format(pValue, 3)) did not meet α=\(format(parameters.significanceLevel, 2)); no transition is asserted.")
            }
        } else if selected.segmentCount > 1 {
            warnings.append("The best segmented trajectory did not exceed the predeclared ΔBIC threshold of \(format(parameters.minimumBICImprovement, 1)); no transition is asserted.")
        }
        if transitions.isEmpty && warnings.isEmpty {
            warnings.append("No statistically supported construction transition was detected. This is not evidence that pipe construction is uniform or fully documented.")
        }
        return PitchDependentRankFingerprint(
            rankComponentID: rankComponentID,
            rankLabel: rankLabel,
            featureSchemaVersion: TimbreRankFeatureVectorizer.version,
            parameters: parameters,
            parameterSHA256: parameterHash,
            points: points,
            trends: trends(points),
            bassFingerprint: bandFingerprint(points, band: .bass),
            middleFingerprint: bandFingerprint(points, band: .middle),
            trebleFingerprint: bandFingerprint(points, band: .treble),
            transitions: transitions,
            selectedSegmentCount: selected.segmentCount,
            baselineBIC: baseline.bic,
            selectedBIC: selected.bic,
            applicability: .applicable,
            warnings: warnings
        )
    }

    private static func inapplicableResult(
        rankComponentID: String,
        rankLabel: String,
        points: [RankFingerprintPoint],
        parameters: RankFingerprintParameters,
        parameterHash: String,
        priorWarnings: [String]
    ) -> PitchDependentRankFingerprint {
        PitchDependentRankFingerprint(
            rankComponentID: rankComponentID,
            rankLabel: rankLabel,
            featureSchemaVersion: TimbreRankFeatureVectorizer.version,
            parameters: parameters,
            parameterSHA256: parameterHash,
            points: points,
            trends: trends(points),
            bassFingerprint: bandFingerprint(points, band: .bass),
            middleFingerprint: bandFingerprint(points, band: .middle),
            trebleFingerprint: bandFingerprint(points, band: .treble),
            transitions: [],
            selectedSegmentCount: 1,
            baselineBIC: nil,
            selectedBIC: nil,
            applicability: .limited,
            warnings: priorWarnings + ["The pitch trajectory could not be segmented under the declared minimum-segment and pitch-gap constraints."]
        )
    }

    private static func parameterValidationErrors(_ parameters: RankFingerprintParameters) -> [String] {
        var errors: [String] = []
        if parameters.minimumObservations < 3 { errors.append("minimumObservations must be at least 3") }
        if parameters.minimumSegmentObservations < 2 { errors.append("minimumSegmentObservations must be at least 2") }
        if parameters.minimumObservations < parameters.minimumSegmentObservations * 2 {
            errors.append("minimumObservations must permit at least two minimum-size segments")
        }
        if parameters.maximumTransitions < 0 { errors.append("maximumTransitions must not be negative") }
        if parameters.maximumAdjacentGapSemitones < 1 { errors.append("maximumAdjacentGapSemitones must be positive") }
        if !parameters.minimumBICImprovement.isFinite || parameters.minimumBICImprovement < 0 {
            errors.append("minimumBICImprovement must be finite and non-negative")
        }
        if !parameters.significanceLevel.isFinite || !(0..<1).contains(parameters.significanceLevel) {
            errors.append("significanceLevel must lie strictly between 0 and 1")
        }
        if parameters.permutationCount < 1 { errors.append("permutationCount must be positive") }
        return errors
    }

    private static func rawVector(_ point: RankFingerprintPoint) -> [Double] {
        [
            point.normalizedSpectralCentroid,
            point.weightedAverageSlopeDBPerOctave,
            min(60, max(-60, point.evenToOddEnergyRatioDB ?? 0)),
        ] + point.relativePartialLevelsDB.map { min(6, max(-80, $0 ?? -80)) }
    }

    private static func robustNormalization(_ rows: [[Double]]) -> (centers: [Double], scales: [Double]) {
        guard let dimension = rows.first?.count else { return ([], []) }
        var centers: [Double] = []
        var scales: [Double] = []
        for index in 0..<dimension {
            let values = rows.map { $0[index] }
            let center = median(values)
            let mad = median(values.map { abs($0 - center) }) * 1.4826
            let mean = values.reduce(0, +) / Double(values.count)
            let standardDeviation = sqrt(values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(max(1, values.count - 1)))
            centers.append(center)
            scales.append(max(1e-6, mad > 1e-6 ? mad : (standardDeviation > 1e-6 ? standardDeviation : 1)))
        }
        return (centers, scales)
    }

    private static func bestSegmentations(
        rows: [[Double]],
        midi: [Double],
        allowedBoundaries: Set<Int>,
        parameters: RankFingerprintParameters
    ) -> [Segmentation] {
        let n = rows.count
        let minimum = parameters.minimumSegmentObservations
        let maximumSegments = min(parameters.maximumTransitions + 1, n / minimum)
        guard maximumSegments >= 1 else { return [] }
        var cost = [[Double]](repeating: [Double](repeating: .infinity, count: n + 1), count: n)
        if n >= minimum {
            for start in 0...(n - minimum) {
                for end in (start + minimum)...n {
                    cost[start][end] = regressionCost(rows: Array(rows[start..<end]), x: Array(midi[start..<end]))
                }
            }
        }
        var dp = [[[Double]]](repeating: [[Double]](), count: maximumSegments + 1)
        var previous = [[[Int]]](repeating: [[Int]](), count: maximumSegments + 1)
        for segments in 0...maximumSegments {
            dp[segments] = [[Double](repeating: .infinity, count: n + 1)]
            previous[segments] = [[Int](repeating: -1, count: n + 1)]
        }
        dp[1][0][0] = 0
        for end in minimum...n { dp[1][0][end] = cost[0][end] }
        if maximumSegments >= 2 {
            for segments in 2...maximumSegments {
                for end in (segments * minimum)...n {
                    let lower = (segments - 1) * minimum
                    let upper = end - minimum
                    guard lower <= upper else { continue }
                    for boundary in lower...upper where allowedBoundaries.contains(boundary) {
                        let candidate = dp[segments - 1][0][boundary] + cost[boundary][end]
                        if candidate < dp[segments][0][end] {
                            dp[segments][0][end] = candidate
                            previous[segments][0][end] = boundary
                        }
                    }
                }
            }
        }
        let observationCount = max(1, n * (rows.first?.count ?? 1))
        return (1...maximumSegments).compactMap { segments -> Segmentation? in
            let rss = dp[segments][0][n]
            guard rss.isFinite else { return nil }
            var boundaries: [Int] = []
            var end = n
            if segments > 1 {
                for current in stride(from: segments, through: 2, by: -1) {
                    let boundary = previous[current][0][end]
                    guard boundary > 0 else { return nil }
                    boundaries.append(boundary)
                    end = boundary
                }
            }
            let parameterCount = segments * 2 * (rows.first?.count ?? 1)
            let bic = Double(observationCount) * log(max(1e-12, rss / Double(observationCount)))
                + Double(parameterCount) * log(Double(observationCount))
            return Segmentation(segmentCount: segments, boundaries: boundaries.sorted(), residualSumSquares: rss, bic: bic)
        }
    }

    private static func regressionCost(rows: [[Double]], x: [Double]) -> Double {
        guard let dimension = rows.first?.count, rows.count >= 2 else { return .infinity }
        let center = x.reduce(0, +) / Double(x.count)
        let denominator = x.reduce(0) { $0 + pow($1 - center, 2) }
        var total = 0.0
        for feature in 0..<dimension {
            let y = rows.map { $0[feature] }
            let mean = y.reduce(0, +) / Double(y.count)
            let slope = denominator > 1e-12
                ? zip(x, y).reduce(0) { $0 + ($1.0 - center) * ($1.1 - mean) } / denominator
                : 0
            total += zip(x, y).reduce(0) { $0 + pow($1.1 - (mean + slope * ($1.0 - center)), 2) }
        }
        return max(1e-12, total)
    }

    private static func familyWisePermutationPValue(
        observedBICImprovement: Double,
        working: [WorkingPoint],
        allowedBoundaries: Set<Int>,
        parameters: RankFingerprintParameters
    ) -> Double {
        let rows = working.map(\.standardized)
        let midi = working.map { Double($0.source.midiNote) }
        let fitted = globalFitted(rows: rows, x: midi)
        let residuals = zip(rows, fitted).map { zip($0.0, $0.1).map(-) }
        var random = DeterministicRandom(state: parameters.randomSeed ^ UInt64(working.count))
        var atLeastObserved = 0
        for _ in 0..<max(1, parameters.permutationCount) {
            let permuted = random.shuffledIndices(count: residuals.count)
            let synthetic = fitted.indices.map { index in
                zip(fitted[index], residuals[permuted[index]]).map(+)
            }
            let models = bestSegmentations(rows: synthetic, midi: midi, allowedBoundaries: allowedBoundaries, parameters: parameters)
            if let baseline = models.first(where: { $0.segmentCount == 1 }),
               let best = models.min(by: { $0.bic < $1.bic }),
               baseline.bic - best.bic >= observedBICImprovement - 1e-9 {
                atLeastObserved += 1
            }
        }
        return Double(atLeastObserved + 1) / Double(max(1, parameters.permutationCount) + 1)
    }

    private static func globalFitted(rows: [[Double]], x: [Double]) -> [[Double]] {
        guard let dimension = rows.first?.count else { return [] }
        let center = x.reduce(0, +) / Double(x.count)
        let denominator = x.reduce(0) { $0 + pow($1 - center, 2) }
        var coefficients: [(Double, Double)] = []
        for feature in 0..<dimension {
            let y = rows.map { $0[feature] }
            let mean = y.reduce(0, +) / Double(y.count)
            let slope = denominator > 1e-12
                ? zip(x, y).reduce(0) { $0 + ($1.0 - center) * ($1.1 - mean) } / denominator
                : 0
            coefficients.append((mean, slope))
        }
        return x.map { value in coefficients.map { $0.0 + $0.1 * (value - center) } }
    }

    private static func localEffectSize(rows: [[Double]], boundary: Int, minimumSegment: Int) -> Double {
        let leftStart = max(0, boundary - max(minimumSegment, 6))
        let rightEnd = min(rows.count, boundary + max(minimumSegment, 6))
        let left = meanVector(Array(rows[leftStart..<boundary]))
        let right = meanVector(Array(rows[boundary..<rightEnd]))
        return sqrt(zip(left, right).reduce(0) { $0 + pow($1.0 - $1.1, 2) })
    }

    private static func trends(_ points: [RankFingerprintPoint]) -> [RankFingerprintTrend] {
        guard points.count >= 3 else { return [] }
        let rows = points.map(rawVector)
        let centerMIDI = Double(points.map(\.midiNote).min()! + points.map(\.midiNote).max()!) / 2
        let x = points.map { (Double($0.midiNote) - centerMIDI) / 12 }
        return featureNames.indices.compactMap { feature -> RankFingerprintTrend? in
            let y = rows.map { $0[feature] }
            guard let fit = quadraticFit(x: x, y: y) else { return nil }
            return RankFingerprintTrend(
                feature: featureNames[feature],
                interceptAtMIDIMiddle: fit.0,
                linearChangePerOctave: fit.1,
                quadraticChangePerOctaveSquared: fit.2,
                residualRMSE: fit.3
            )
        }
    }

    private enum PitchBand { case bass, middle, treble }

    private static func bandFingerprint(_ points: [RankFingerprintPoint], band: PitchBand) -> [String: Double]? {
        guard !points.isEmpty else { return nil }
        let ordered = points.sorted { $0.midiNote < $1.midiNote }
        let firstCut = max(1, ordered.count / 3)
        let secondCut = min(ordered.count - 1, 2 * ordered.count / 3)
        let selected: ArraySlice<RankFingerprintPoint>
        switch band {
        case .bass: selected = ordered[0..<firstCut]
        case .middle: selected = ordered[firstCut..<max(firstCut + 1, secondCut)]
        case .treble: selected = ordered[secondCut..<ordered.count]
        }
        guard !selected.isEmpty else { return nil }
        let vectors = selected.map(rawVector)
        return Dictionary(uniqueKeysWithValues: featureNames.indices.map { index in
            (featureNames[index], median(vectors.map { $0[index] }))
        })
    }

    private static func quadraticFit(x: [Double], y: [Double]) -> (Double, Double, Double, Double)? {
        guard x.count == y.count, x.count >= 3 else { return nil }
        let n = Double(x.count)
        let sx = x.reduce(0, +)
        let sx2 = x.reduce(0) { $0 + $1 * $1 }
        let sx3 = x.reduce(0) { $0 + $1 * $1 * $1 }
        let sx4 = x.reduce(0) { $0 + pow($1, 4) }
        let sy = y.reduce(0, +)
        let sxy = zip(x, y).reduce(0) { $0 + $1.0 * $1.1 }
        let sx2y = zip(x, y).reduce(0) { $0 + $1.0 * $1.0 * $1.1 }
        guard let coefficients = solve3x3(
            [[n, sx, sx2], [sx, sx2, sx3], [sx2, sx3, sx4]],
            [sy, sxy, sx2y]
        ) else { return nil }
        let rmse = sqrt(zip(x, y).reduce(0) { $0 + pow($1.1 - (coefficients[0] + coefficients[1] * $1.0 + coefficients[2] * $1.0 * $1.0), 2) } / n)
        return (coefficients[0], coefficients[1], coefficients[2], rmse)
    }

    private static func solve3x3(_ matrix: [[Double]], _ vector: [Double]) -> [Double]? {
        var a = matrix
        var b = vector
        for column in 0..<3 {
            guard let pivot = (column..<3).max(by: { abs(a[$0][column]) < abs(a[$1][column]) }),
                  abs(a[pivot][column]) > 1e-12 else { return nil }
            if pivot != column { a.swapAt(pivot, column); b.swapAt(pivot, column) }
            let scale = a[column][column]
            for index in column..<3 { a[column][index] /= scale }
            b[column] /= scale
            for row in 0..<3 where row != column {
                let factor = a[row][column]
                for index in column..<3 { a[row][index] -= factor * a[column][index] }
                b[row] -= factor * b[column]
            }
        }
        return b
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private static func meanVector(_ rows: [[Double]]) -> [Double] {
        guard let dimension = rows.first?.count, !rows.isEmpty else { return [] }
        return (0..<dimension).map { feature in rows.map { $0[feature] }.reduce(0, +) / Double(rows.count) }
    }

    private static func evidenceStrength(deltaBIC: Double, pValue: Double) -> String {
        if deltaBIC >= 20, pValue <= 0.01 { return "very-strong" }
        if deltaBIC >= 10, pValue <= 0.05 { return "strong" }
        return "limited"
    }

    private static func noteName(_ midi: Int) -> String {
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        return "\(names[(midi % 12 + 12) % 12])\(midi / 12 - 1)"
    }

    private static func format(_ value: Double, _ decimals: Int) -> String {
        String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), decimals, value)
    }
}

private struct DeterministicRandom {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func shuffledIndices(count: Int) -> [Int] {
        guard count > 1 else { return Array(0..<count) }
        var result = Array(0..<count)
        for index in stride(from: count - 1, through: 1, by: -1) {
            let other = Int(next() % UInt64(index + 1))
            result.swapAt(index, other)
        }
        return result
    }
}
