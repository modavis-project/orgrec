import CryptoKit
import Foundation

public enum TimbreCorpusSplit: String, Codable, CaseIterable, Sendable {
    case training
    case calibration
    case test
}

public struct TimbreLabelAssignment: Codable, Hashable, Sendable {
    public var family: PipeTimbreFamily
    public var normalizedSourceLabel: String
    public var matchedRule: String
    public var status: String

    public init(
        family: PipeTimbreFamily,
        normalizedSourceLabel: String,
        matchedRule: String,
        status: String = "documentary-label-derived"
    ) {
        self.family = family
        self.normalizedSourceLabel = normalizedSourceLabel
        self.matchedRule = matchedRule
        self.status = status
    }
}

public enum TimbreDocumentaryLabelNormalizer {
    public static let version = "orgrec-organ-stop-label-rules/3"

    public static func assignment(for sourceLabel: String) -> TimbreLabelAssignment? {
        let label = normalized(sourceLabel)
        guard !label.isEmpty else { return nil }
        let excluded = [
            "mixture", "mixtur", "fourniture", "scharf", "scharff", "cymbel", "cymbal",
            "plein jeu", "cornet", "sesquialtera", "rausch", "ripieno", "compound",
            "celeste", "celeste", "schweb", "unda maris", "voix celeste",
            "noise", "stopnoise", "stop knob", "stopknob", "key noise", "tracker noise",
            "blower", "wind noise", "action noise", "switch noise",
        ]
        guard let excludedTerm = excluded.first(where: { contains(label, term: $0) }) else {
            return classifiedAssignment(label)
        }
        _ = excludedTerm
        return nil
    }

    private static func classifiedAssignment(_ label: String) -> TimbreLabelAssignment? {
        let reedTerms = [
            "reed", "regal", "regale", "trumpet", "trompet", "trompette", "trompeta",
            "posaune", "bombard", "bombarde", "clarion", "clairon", "tuba", "fagott",
            "fagot", "bassoon", "basson", "basun", "hautbois", "oboe", "cromorne", "krummhorn", "crumhorn",
            "dulzian", "dulcian", "rankett", "vox humana", "voix humaine", "zink",
            "cornettino", "schalmei", "chalumeau", "orlos", "bajoncillo",
        ]
        if let term = reedTerms.first(where: { contains(label, term: $0) }) {
            return TimbreLabelAssignment(family: .reed, normalizedSourceLabel: label, matchedRule: "reed:\(term)")
        }

        let stringTerms = [
            "string", "gamba", "gambe", "viola", "violon", "violoncell", "violoncelle", "violoncello",
            "salicional", "salicet", "dulciana", "dolce", "aeoline", "aoline", "eoline",
            "fugara", "spitzgamba", "voix angelique",
        ]
        if let term = stringTerms.first(where: { contains(label, term: $0) }) {
            return TimbreLabelAssignment(family: .string, normalizedSourceLabel: label, matchedRule: "string:\(term)")
        }

        let principalTerms = [
            "principal", "prinzipal", "praestant", "prestant", "diapason", "open diapason",
            "montre", "octave", "octav", "oktav", "oktava", "fifteenth", "doublette", "superoctave",
            "super octave", "twelfth", "quinte", "quint", "nasat principal",
        ]
        if let term = principalTerms.first(where: { contains(label, term: $0) }) {
            return TimbreLabelAssignment(family: .diapason, normalizedSourceLabel: label, matchedRule: "diapason:\(term)")
        }

        let fluteTerms = [
            "flute", "flote", "floete", "fluit", "flauto", "gedackt", "gedeckt", "gedact", "gedakt",
            "bourdon", "bordun", "bordon", "stopped", "rohrflote", "rohr flute", "rohrgedeckt",
            "hollow flute", "holflote", "hohlflote", "copula", "copel", "copula", "chimney flute",
            "waldflote", "blockflote", "recordare", "melodia", "harmonic flute", "harmonique",
            "rorflojt", "rörflöjt", "piccolo", "subbass", "subbas", "sub bass", "soubasse", "pommer", "quintadena", "quintaton",
        ]
        if let term = fluteTerms.first(where: { contains(label, term: $0) }) {
            return TimbreLabelAssignment(family: .flute, normalizedSourceLabel: label, matchedRule: "flute:\(term)")
        }
        return nil
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(
                of: "(?<=[a-z])(?=[0-9])|(?<=[0-9])(?=[a-z])",
                with: " ",
                options: .regularExpression
            )
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func contains(_ label: String, term: String) -> Bool {
        let normalizedTerm = normalized(term)
        return " \(label) ".contains(" \(normalizedTerm) ") || label == normalizedTerm
    }
}

public struct EmpiricalTimbreRankRecord: Codable, Sendable {
    public var instrumentID: String
    public var instrumentName: String
    public var rankID: String
    public var rankLabel: String
    public var division: String?
    public var footage: String?
    public var labelAssignment: TimbreLabelAssignment
    public var observations: [PipeTimbreObservation]
    public var sourceDefinitionSHA256: String

    public init(
        instrumentID: String,
        instrumentName: String,
        rankID: String,
        rankLabel: String,
        division: String? = nil,
        footage: String? = nil,
        labelAssignment: TimbreLabelAssignment,
        observations: [PipeTimbreObservation],
        sourceDefinitionSHA256: String
    ) {
        self.instrumentID = instrumentID
        self.instrumentName = instrumentName
        self.rankID = rankID
        self.rankLabel = rankLabel
        self.division = division
        self.footage = footage
        self.labelAssignment = labelAssignment
        self.observations = observations
        self.sourceDefinitionSHA256 = sourceDefinitionSHA256
    }
}

public enum TimbreRankFeatureVectorizer {
    public static let version = "orgrec-rank-timbre-features/1"
    private static let baseNames = ["centroid", "slopeDBPerOctave", "evenOddDB"]
        + (1...8).map { "partial\($0)RelativeDB" }
    public static let featureNames = baseNames.map { "median.\($0)" }
        + baseNames.map { "iqr.\($0)" }
        + ["pitchSlope.centroid", "pitchSlope.slopeDBPerOctave", "pitchSlope.evenOddDB"]
        + FirstFivePartialPrototype.allCases.map { "prototypeFraction.\($0.rawValue)" }

    public static func vector(observations: [PipeTimbreObservation]) -> [Double]? {
        let usable = observations.compactMap { observation -> (Int, [Double], FirstFivePartialPrototype)? in
            guard let midi = observation.midiNote,
                  let centroid = observation.normalizedSpectralCentroid,
                  let slope = observation.weightedAverageSlopeDBPerOctave,
                  centroid.isFinite, slope.isFinite else { return nil }
            let levels = Dictionary(uniqueKeysWithValues: observation.partials.map { ($0.harmonicNumber, $0.relativeLevelDB) })
            let base = [centroid, slope, clipped(observation.evenToOddEnergyRatioDB ?? 0, -60, 60)]
                + (1...8).map { clipped(levels[$0] ?? -80, -80, 6) }
            return (midi, base, observation.firstFivePrototype)
        }.sorted { $0.0 < $1.0 }
        guard usable.count >= 3 else { return nil }

        var result: [Double] = []
        for index in baseNames.indices { result.append(percentile(usable.map { $0.1[index] }, 0.5)) }
        for index in baseNames.indices {
            result.append(percentile(usable.map { $0.1[index] }, 0.75) - percentile(usable.map { $0.1[index] }, 0.25))
        }
        for index in 0..<3 {
            result.append(linearSlope(usable.map { (Double($0.0) / 12, $0.1[index]) }) ?? 0)
        }
        for prototype in FirstFivePartialPrototype.allCases {
            result.append(Double(usable.filter { $0.2 == prototype }.count) / Double(usable.count))
        }
        precondition(result.count == featureNames.count)
        return result
    }

    private static func clipped(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(upper, max(lower, value.isFinite ? value : 0))
    }

    private static func percentile(_ values: [Double], _ fraction: Double) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let position = min(Double(sorted.count - 1), max(0, fraction * Double(sorted.count - 1)))
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        if lower == upper { return sorted[lower] }
        return sorted[lower] * (Double(upper) - position) + sorted[upper] * (position - Double(lower))
    }

    private static func linearSlope(_ points: [(Double, Double)]) -> Double? {
        guard points.count >= 3 else { return nil }
        let meanX = points.map(\.0).reduce(0, +) / Double(points.count)
        let meanY = points.map(\.1).reduce(0, +) / Double(points.count)
        let numerator = points.reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) }
        let denominator = points.reduce(0) { $0 + pow($1.0 - meanX, 2) }
        return denominator > 1e-12 ? numerator / denominator : nil
    }
}

public struct TimbreClassifierSplitAssignment: Codable, Hashable, Sendable {
    public var instrumentID: String
    public var split: TimbreCorpusSplit
}

public struct TimbreClassifierMetrics: Codable, Sendable {
    public var split: TimbreCorpusSplit
    public var rankCount: Int
    public var instrumentCount: Int
    public var accuracy: Double
    public var macroF1: Double
    public var logLoss: Double
    public var brierScore: Double
    public var expectedCalibrationError: Double
    public var acceptedCoverage: Double
    public var acceptedAccuracy: Double?
    public var confusion: [String: [String: Int]]
}

public struct CalibratedTimbreNode: Codable, Sendable {
    public var id: String
    public var outcomes: [String]
    public var weights: [[Double]]
    public var temperature: Double
    public var calibrationRankCount: Int

    public func probabilities(for standardizedFeatures: [Double]) -> [String: Double] {
        let input = [1.0] + standardizedFeatures
        let logits = weights.map { row in zip(row, input).reduce(0) { $0 + $1.0 * $1.1 } }
        let scaled = logits.map { $0 / max(0.05, temperature) }
        let maximum = scaled.max() ?? 0
        let exponentials = scaled.map { exp(min(60, $0 - maximum)) }
        let total = max(1e-15, exponentials.reduce(0, +))
        return Dictionary(uniqueKeysWithValues: zip(outcomes, exponentials.map { $0 / total }))
    }
}

public struct EmpiricalTimbreCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: PipeTimbreFamily { family }
    public var family: PipeTimbreFamily
    public var calibratedProbability: Double
    public var hierarchyPath: [String]
}

public struct EmpiricalTimbreClassification: Codable, Hashable, Sendable {
    public var modelVersion: String
    public var trainingCorpusSHA256: String?
    public var taxonomyVersion: String
    public var featureSchemaVersion: String
    public var candidates: [EmpiricalTimbreCandidate]
    public var selectedFamily: PipeTimbreFamily?
    public var abstained: Bool
    public var outOfDistribution: Bool
    public var outOfDistributionDistance: Double
    public var outOfDistributionThreshold: Double
    public var minimumAcceptedProbability: Double
    public var reason: String?
}

public struct EmpiricalTimbreClassifierModel: Codable, Sendable {
    public var contractVersion: String
    public var modelVersion: String
    public var taxonomyVersion: String
    public var labelRuleVersion: String
    public var featureSchemaVersion: String
    public var trainedAt: Date
    public var trainingCorpusSHA256: String
    public var sourceCorpusDescription: String
    public var featureNames: [String]
    public var featureMeans: [Double]
    public var featureScales: [Double]
    public var rootNode: CalibratedTimbreNode
    public var flueNode: CalibratedTimbreNode
    public var familyCentroids: [String: [Double]]
    public var outOfDistributionThreshold: Double
    public var minimumAcceptedProbability: Double
    public var splitAssignments: [TimbreClassifierSplitAssignment]
    public var metrics: [TimbreClassifierMetrics]
    public var limitations: [String]

    public init(
        contractVersion: String = "orgrec-empirical-hierarchical-timbre-model/1",
        modelVersion: String,
        taxonomyVersion: String = "orgrec-pipe-timbre-hierarchy/1",
        labelRuleVersion: String = TimbreDocumentaryLabelNormalizer.version,
        featureSchemaVersion: String = TimbreRankFeatureVectorizer.version,
        trainedAt: Date = .now,
        trainingCorpusSHA256: String,
        sourceCorpusDescription: String,
        featureNames: [String],
        featureMeans: [Double],
        featureScales: [Double],
        rootNode: CalibratedTimbreNode,
        flueNode: CalibratedTimbreNode,
        familyCentroids: [String: [Double]],
        outOfDistributionThreshold: Double,
        minimumAcceptedProbability: Double,
        splitAssignments: [TimbreClassifierSplitAssignment],
        metrics: [TimbreClassifierMetrics],
        limitations: [String]
    ) {
        self.contractVersion = contractVersion
        self.modelVersion = modelVersion
        self.taxonomyVersion = taxonomyVersion
        self.labelRuleVersion = labelRuleVersion
        self.featureSchemaVersion = featureSchemaVersion
        self.trainedAt = trainedAt
        self.trainingCorpusSHA256 = trainingCorpusSHA256
        self.sourceCorpusDescription = sourceCorpusDescription
        self.featureNames = featureNames
        self.featureMeans = featureMeans
        self.featureScales = featureScales
        self.rootNode = rootNode
        self.flueNode = flueNode
        self.familyCentroids = familyCentroids
        self.outOfDistributionThreshold = outOfDistributionThreshold
        self.minimumAcceptedProbability = minimumAcceptedProbability
        self.splitAssignments = splitAssignments
        self.metrics = metrics
        self.limitations = limitations
    }

    public func classify(observations: [PipeTimbreObservation]) -> EmpiricalTimbreClassification? {
        guard let raw = TimbreRankFeatureVectorizer.vector(observations: observations),
              raw.count == featureMeans.count, raw.count == featureScales.count else { return nil }
        let features = zip(raw, zip(featureMeans, featureScales)).map { value, normalization in
            (value - normalization.0) / max(1e-9, normalization.1)
        }
        let root = rootNode.probabilities(for: features)
        let flue = flueNode.probabilities(for: features)
        let flueProbability = root["flue"] ?? 0
        let familyProbabilities: [(PipeTimbreFamily, Double, [String])] = [
            (.flute, flueProbability * (flue[PipeTimbreFamily.flute.rawValue] ?? 0), ["root", "flue", "flute"]),
            (.diapason, flueProbability * (flue[PipeTimbreFamily.diapason.rawValue] ?? 0), ["root", "flue", "diapason"]),
            (.string, flueProbability * (flue[PipeTimbreFamily.string.rawValue] ?? 0), ["root", "flue", "string"]),
            (.reed, root["reed"] ?? 0, ["root", "reed"]),
        ]
        let total = max(1e-15, familyProbabilities.reduce(0) { $0 + $1.1 })
        let candidates = familyProbabilities.map {
            EmpiricalTimbreCandidate(family: $0.0, calibratedProbability: $0.1 / total, hierarchyPath: $0.2)
        }.sorted { $0.calibratedProbability > $1.calibratedProbability }
        let distance = familyCentroids.values.map { centroid in
            sqrt(zip(features, centroid).reduce(0) { $0 + pow($1.0 - $1.1, 2) })
        }.min() ?? .infinity
        let outOfDistribution = !distance.isFinite || distance > outOfDistributionThreshold
        let lowConfidence = (candidates.first?.calibratedProbability ?? 0) < minimumAcceptedProbability
        let abstained = outOfDistribution || lowConfidence
        let reason: String?
        if outOfDistribution {
            reason = "Rank feature distance \(fixed(distance, 2)) exceeds empirical threshold \(fixed(outOfDistributionThreshold, 2))."
        } else if lowConfidence {
            reason = "Maximum calibrated probability \(fixed(candidates.first?.calibratedProbability ?? 0, 3)) is below the validation-selected threshold \(fixed(minimumAcceptedProbability, 3))."
        } else {
            reason = nil
        }
        return EmpiricalTimbreClassification(
            modelVersion: modelVersion,
            trainingCorpusSHA256: trainingCorpusSHA256,
            taxonomyVersion: taxonomyVersion,
            featureSchemaVersion: featureSchemaVersion,
            candidates: candidates,
            selectedFamily: abstained ? nil : candidates.first?.family,
            abstained: abstained,
            outOfDistribution: outOfDistribution,
            outOfDistributionDistance: distance,
            outOfDistributionThreshold: outOfDistributionThreshold,
            minimumAcceptedProbability: minimumAcceptedProbability,
            reason: reason
        )
    }

    public static func bundled() throws -> EmpiricalTimbreClassifierModel? {
        guard let url = OrgRecResources.bundle.url(forResource: "empirical-timbre-model-v1", withExtension: "json") else { return nil }
        return try OrgRecCoding.decoder.decode(Self.self, from: Data(contentsOf: url))
    }
}

public struct EmpiricalTimbreTrainingOptions: Sendable {
    public var splitSeed: String
    public var maximumIterations: Int
    public var learningRate: Double
    public var l2Penalty: Double
    public var calibrationTargetAccuracy: Double
    public var calibrationMinimumCoverage: Double

    public init(
        splitSeed: String = "orgrec-timbre-split-1",
        maximumIterations: Int = 2_000,
        learningRate: Double = 0.08,
        l2Penalty: Double = 0.005,
        calibrationTargetAccuracy: Double = 0.80,
        calibrationMinimumCoverage: Double = 0.50
    ) {
        self.splitSeed = splitSeed
        self.maximumIterations = maximumIterations
        self.learningRate = learningRate
        self.l2Penalty = l2Penalty
        self.calibrationTargetAccuracy = calibrationTargetAccuracy
        self.calibrationMinimumCoverage = calibrationMinimumCoverage
    }
}

public enum EmpiricalTimbreTrainer {
    private struct Example {
        var instrumentID: String
        var rankID: String
        var family: PipeTimbreFamily
        var features: [Double]
        var split: TimbreCorpusSplit
    }

    public static func train(
        ranks: [EmpiricalTimbreRankRecord],
        corpusSHA256: String,
        sourceDescription: String,
        modelVersion: String,
        options: EmpiricalTimbreTrainingOptions = EmpiricalTimbreTrainingOptions()
    ) throws -> EmpiricalTimbreClassifierModel {
        let usable = ranks.compactMap { rank -> (EmpiricalTimbreRankRecord, [Double])? in
            guard [.flute, .diapason, .string, .reed].contains(rank.labelAssignment.family),
                  let features = TimbreRankFeatureVectorizer.vector(observations: rank.observations) else { return nil }
            return (rank, features)
        }
        guard usable.count >= 16 else {
            throw OrgRecError.invalidProject("At least 16 labelled rank fingerprints are required to fit the empirical classifier.")
        }
        let assignments = groupedAssignments(usable.map { ($0.0.instrumentID, $0.0.labelAssignment.family) }, seed: options.splitSeed)
        var examples = usable.map { rank, features in
            Example(
                instrumentID: rank.instrumentID,
                rankID: rank.rankID,
                family: rank.labelAssignment.family,
                features: features,
                split: assignments[rank.instrumentID] ?? .training
            )
        }
        for split in TimbreCorpusSplit.allCases where !examples.contains(where: { $0.split == split }) {
            throw OrgRecError.invalidProject("Grouped split construction produced no \(split.rawValue) instruments; add more independent instruments or change the split seed.")
        }
        let training = examples.filter { $0.split == .training }
        let means = columnStatistics(training.map(\.features)).means
        let scales = columnStatistics(training.map(\.features)).scales
        for index in examples.indices {
            examples[index].features = standardized(examples[index].features, means: means, scales: scales)
        }
        let standardizedTraining = examples.filter { $0.split == .training }
        let calibration = examples.filter { $0.split == .calibration }

        let requiredFamilies: Set<PipeTimbreFamily> = [.flute, .diapason, .string, .reed]
        guard Set(standardizedTraining.map(\.family)) == requiredFamilies else {
            throw OrgRecError.invalidProject("The training-instrument split does not contain all four timbre families; use another split seed or add instruments.")
        }
        guard calibration.contains(where: { $0.family == .reed }),
              calibration.contains(where: { $0.family != .reed }) else {
            throw OrgRecError.invalidProject("Calibration instruments must include both flue and reed ranks.")
        }

        let rootOutcomes = ["flue", "reed"]
        let rootLabels: (Example) -> String = { $0.family == .reed ? "reed" : "flue" }
        let rootWeights = trainSoftmax(
            examples: standardizedTraining.map { ($0.features, rootLabels($0)) },
            outcomes: rootOutcomes,
            options: options
        )
        let rootTemperature = fitTemperature(
            examples: calibration.map { ($0.features, rootLabels($0)) },
            outcomes: rootOutcomes,
            weights: rootWeights
        )
        let flueOutcomes = [PipeTimbreFamily.flute.rawValue, PipeTimbreFamily.diapason.rawValue, PipeTimbreFamily.string.rawValue]
        let flueTraining = standardizedTraining.filter { $0.family != .reed }
        let flueCalibration = calibration.filter { $0.family != .reed }
        guard Set(flueTraining.map { $0.family.rawValue }) == Set(flueOutcomes),
              Set(flueCalibration.map { $0.family.rawValue }).count >= 2 else {
            throw OrgRecError.invalidProject("Flue-family training requires flute, diapason, and string training ranks plus at least two flue classes in calibration.")
        }
        let flueWeights = trainSoftmax(
            examples: flueTraining.map { ($0.features, $0.family.rawValue) },
            outcomes: flueOutcomes,
            options: options
        )
        let flueTemperature = fitTemperature(
            examples: flueCalibration.map { ($0.features, $0.family.rawValue) },
            outcomes: flueOutcomes,
            weights: flueWeights
        )
        let rootNode = CalibratedTimbreNode(
            id: "root-production-principle",
            outcomes: rootOutcomes,
            weights: rootWeights,
            temperature: rootTemperature,
            calibrationRankCount: calibration.count
        )
        let flueNode = CalibratedTimbreNode(
            id: "flue-family",
            outcomes: flueOutcomes,
            weights: flueWeights,
            temperature: flueTemperature,
            calibrationRankCount: flueCalibration.count
        )
        var centroids: [String: [Double]] = [:]
        for family in requiredFamilies {
            centroids[family.rawValue] = meanVector(standardizedTraining.filter { $0.family == family }.map(\.features))
        }
        let calibrationDistances = calibration.compactMap { example -> Double? in
            guard let centroid = centroids[example.family.rawValue] else { return nil }
            return euclidean(example.features, centroid)
        }
        let oodThreshold = conformalUpperQuantile(calibrationDistances.isEmpty
            ? standardizedTraining.compactMap { example in centroids[example.family.rawValue].map { euclidean(example.features, $0) } }
            : calibrationDistances, alpha: 0.01)

        var provisional = EmpiricalTimbreClassifierModel(
            modelVersion: modelVersion,
            trainingCorpusSHA256: corpusSHA256,
            sourceCorpusDescription: sourceDescription,
            featureNames: TimbreRankFeatureVectorizer.featureNames,
            featureMeans: means,
            featureScales: scales,
            rootNode: rootNode,
            flueNode: flueNode,
            familyCentroids: centroids,
            outOfDistributionThreshold: oodThreshold,
            minimumAcceptedProbability: 0,
            splitAssignments: assignments.map { TimbreClassifierSplitAssignment(instrumentID: $0.key, split: $0.value) }.sorted { $0.instrumentID < $1.instrumentID },
            metrics: [],
            limitations: [
                "The target labels are derived from documentary stop names by auditable rules; they are weak labels, not destructive pipe measurements or universal organological ground truth.",
                "Calibration and evaluation are grouped by catalogued physical instrument. Results do not establish exact stop identity, construction, material, builder, or date.",
                "Room, microphone, sample processing, temperament, and producer-specific mastering can remain confounders.",
            ]
        )
        let validationPredictions = calibration.compactMap { prediction(for: $0, model: provisional) }
        provisional.minimumAcceptedProbability = selectedAbstentionThreshold(
            predictions: validationPredictions,
            targetAccuracy: options.calibrationTargetAccuracy,
            minimumCoverage: options.calibrationMinimumCoverage
        )
        provisional.metrics = TimbreCorpusSplit.allCases.map { split in
            metrics(examples: examples.filter { $0.split == split }, model: provisional, split: split)
        }
        return provisional
    }

    private static func groupedAssignments(
        _ rows: [(String, PipeTimbreFamily)],
        seed: String
    ) -> [String: TimbreCorpusSplit] {
        let groups = Dictionary(grouping: rows, by: \.0).mapValues { values in
            Dictionary(grouping: values.map(\.1), by: { $0 }).mapValues(\.count)
        }
        let totalByFamily = Dictionary(grouping: rows.map(\.1), by: { $0 }).mapValues(\.count)
        let fractions: [TimbreCorpusSplit: Double] = [.training: 0.70, .calibration: 0.15, .test: 0.15]
        var counts: [TimbreCorpusSplit: [PipeTimbreFamily: Int]] = [:]
        var groupCounts: [TimbreCorpusSplit: Int] = [:]
        var result: [String: TimbreCorpusSplit] = [:]
        let ordered = groups.keys.sorted { lhs, rhs in
            let leftRarity = groups[lhs, default: [:]].reduce(0.0) { $0 + Double($1.value) / Double(max(1, totalByFamily[$1.key, default: 1])) }
            let rightRarity = groups[rhs, default: [:]].reduce(0.0) { $0 + Double($1.value) / Double(max(1, totalByFamily[$1.key, default: 1])) }
            if leftRarity != rightRarity { return leftRarity > rightRarity }
            return stableHash("\(seed)|\(lhs)") < stableHash("\(seed)|\(rhs)")
        }
        for group in ordered {
            let best = TimbreCorpusSplit.allCases.min { left, right in
                assignmentCost(group: groups[group, default: [:]], split: left, counts: counts, groupCounts: groupCounts, totals: totalByFamily, totalGroups: groups.count, fractions: fractions)
                    < assignmentCost(group: groups[group, default: [:]], split: right, counts: counts, groupCounts: groupCounts, totals: totalByFamily, totalGroups: groups.count, fractions: fractions)
            } ?? .training
            result[group] = best
            groupCounts[best, default: 0] += 1
            for (family, count) in groups[group, default: [:]] { counts[best, default: [:]][family, default: 0] += count }
        }
        return result
    }

    private static func assignmentCost(
        group: [PipeTimbreFamily: Int],
        split: TimbreCorpusSplit,
        counts: [TimbreCorpusSplit: [PipeTimbreFamily: Int]],
        groupCounts: [TimbreCorpusSplit: Int],
        totals: [PipeTimbreFamily: Int],
        totalGroups: Int,
        fractions: [TimbreCorpusSplit: Double]
    ) -> Double {
        var trial = counts
        for (family, count) in group { trial[split, default: [:]][family, default: 0] += count }
        var cost = 0.0
        for partition in TimbreCorpusSplit.allCases {
            for family in [PipeTimbreFamily.flute, .diapason, .string, .reed] {
                let target = max(1, Double(totals[family, default: 0]) * fractions[partition, default: 0])
                let delta = Double(trial[partition, default: [:]][family, default: 0]) - target
                cost += delta * delta / target
            }
        }
        let targetGroups = max(1, Double(totalGroups) * fractions[split, default: 0])
        let nextGroups = Double(groupCounts[split, default: 0] + 1)
        cost += 0.5 * pow((nextGroups - targetGroups) / targetGroups, 2)
        return cost
    }

    private static func columnStatistics(_ rows: [[Double]]) -> (means: [Double], scales: [Double]) {
        guard let count = rows.first?.count else { return ([], []) }
        var means = [Double](repeating: 0, count: count)
        for row in rows { for index in 0..<count { means[index] += row[index] / Double(rows.count) } }
        var scales = [Double](repeating: 0, count: count)
        for row in rows { for index in 0..<count { scales[index] += pow(row[index] - means[index], 2) } }
        scales = scales.map { sqrt($0 / Double(max(1, rows.count - 1))) }.map { max(1e-6, $0) }
        return (means, scales)
    }

    private static func standardized(_ values: [Double], means: [Double], scales: [Double]) -> [Double] {
        zip(values, zip(means, scales)).map { ($0 - $1.0) / max(1e-9, $1.1) }
    }

    private static func trainSoftmax(
        examples: [([Double], String)],
        outcomes: [String],
        options: EmpiricalTimbreTrainingOptions
    ) -> [[Double]] {
        let dimension = (examples.first?.0.count ?? 0) + 1
        var weights = [[Double]](repeating: [Double](repeating: 0, count: dimension), count: outcomes.count)
        let counts = Dictionary(grouping: examples.map(\.1), by: { $0 }).mapValues(\.count)
        for iteration in 0..<options.maximumIterations {
            var gradient = [[Double]](repeating: [Double](repeating: 0, count: dimension), count: outcomes.count)
            var totalWeight = 0.0
            for example in examples {
                let input = [1.0] + example.0
                let logits = weights.map { zip($0, input).reduce(0) { $0 + $1.0 * $1.1 } }
                let probabilities = softmax(logits)
                let classWeight = Double(examples.count) / Double(max(1, outcomes.count * counts[example.1, default: 1]))
                totalWeight += classWeight
                for classIndex in outcomes.indices {
                    let target = outcomes[classIndex] == example.1 ? 1.0 : 0.0
                    for featureIndex in input.indices {
                        gradient[classIndex][featureIndex] += classWeight * (probabilities[classIndex] - target) * input[featureIndex]
                    }
                }
            }
            let rate = options.learningRate / sqrt(1 + Double(iteration) / 100)
            for classIndex in weights.indices {
                for featureIndex in weights[classIndex].indices {
                    let regularization = featureIndex == 0 ? 0 : options.l2Penalty * weights[classIndex][featureIndex]
                    weights[classIndex][featureIndex] -= rate * (gradient[classIndex][featureIndex] / max(1, totalWeight) + regularization)
                }
            }
        }
        return weights
    }

    private static func fitTemperature(
        examples: [([Double], String)],
        outcomes: [String],
        weights: [[Double]]
    ) -> Double {
        guard !examples.isEmpty else { return 1 }
        func loss(logTemperature: Double) -> Double {
            let temperature = exp(logTemperature)
            return examples.reduce(0) { partial, example in
                let input = [1.0] + example.0
                let logits = weights.map { row in zip(row, input).reduce(0) { $0 + $1.0 * $1.1 } / temperature }
                let probabilities = softmax(logits)
                let index = outcomes.firstIndex(of: example.1) ?? 0
                return partial - log(max(1e-15, probabilities[index]))
            } / Double(examples.count)
        }
        var lower = log(0.05)
        var upper = log(10.0)
        let ratio = (sqrt(5.0) - 1) / 2
        for _ in 0..<80 {
            let left = upper - ratio * (upper - lower)
            let right = lower + ratio * (upper - lower)
            if loss(logTemperature: left) < loss(logTemperature: right) { upper = right } else { lower = left }
        }
        return exp((lower + upper) / 2)
    }

    private static func prediction(for example: Example, model: EmpiricalTimbreClassifierModel) -> (truth: PipeTimbreFamily, candidates: [EmpiricalTimbreCandidate], distance: Double)? {
        let root = model.rootNode.probabilities(for: example.features)
        let flue = model.flueNode.probabilities(for: example.features)
        let f = root["flue"] ?? 0
        let pairs: [(PipeTimbreFamily, Double, [String])] = [
            (.flute, f * (flue["flute"] ?? 0), ["root", "flue", "flute"]),
            (.diapason, f * (flue["diapason"] ?? 0), ["root", "flue", "diapason"]),
            (.string, f * (flue["string"] ?? 0), ["root", "flue", "string"]),
            (.reed, root["reed"] ?? 0, ["root", "reed"]),
        ]
        let total = max(1e-15, pairs.reduce(0) { $0 + $1.1 })
        let candidates = pairs.map { EmpiricalTimbreCandidate(family: $0.0, calibratedProbability: $0.1 / total, hierarchyPath: $0.2) }
            .sorted { $0.calibratedProbability > $1.calibratedProbability }
        let distance = model.familyCentroids.values.map { euclidean(example.features, $0) }.min() ?? .infinity
        return (example.family, candidates, distance)
    }

    private static func selectedAbstentionThreshold(
        predictions: [(truth: PipeTimbreFamily, candidates: [EmpiricalTimbreCandidate], distance: Double)],
        targetAccuracy: Double,
        minimumCoverage: Double
    ) -> Double {
        guard !predictions.isEmpty else { return 0.5 }
        let candidates = Set(predictions.compactMap { $0.candidates.first?.calibratedProbability }).sorted()
        var selected = 0.5
        var bestCoverage = -1.0
        for threshold in candidates {
            let accepted = predictions.filter { ($0.candidates.first?.calibratedProbability ?? 0) >= threshold }
            let coverage = Double(accepted.count) / Double(predictions.count)
            guard coverage >= minimumCoverage, !accepted.isEmpty else { continue }
            let accuracy = Double(accepted.filter { $0.candidates.first?.family == $0.truth }.count) / Double(accepted.count)
            if accuracy >= targetAccuracy, coverage > bestCoverage {
                selected = threshold
                bestCoverage = coverage
            }
        }
        if bestCoverage < 0 {
            selected = percentile(predictions.compactMap { $0.candidates.first?.calibratedProbability }, 0.25)
        }
        return min(0.99, max(0.25, selected))
    }

    private static func metrics(examples: [Example], model: EmpiricalTimbreClassifierModel, split: TimbreCorpusSplit) -> TimbreClassifierMetrics {
        let predictions = examples.compactMap { prediction(for: $0, model: model) }
        guard !predictions.isEmpty else {
            return TimbreClassifierMetrics(split: split, rankCount: 0, instrumentCount: 0, accuracy: 0, macroF1: 0, logLoss: 0, brierScore: 0, expectedCalibrationError: 0, acceptedCoverage: 0, acceptedAccuracy: nil, confusion: [:])
        }
        let families: [PipeTimbreFamily] = [.flute, .diapason, .string, .reed]
        var confusion: [String: [String: Int]] = [:]
        var correct = 0
        var logLoss = 0.0
        var brier = 0.0
        var confidences: [(Double, Bool)] = []
        var accepted: [(truth: PipeTimbreFamily, candidates: [EmpiricalTimbreCandidate], distance: Double)] = []
        for prediction in predictions {
            let top = prediction.candidates.first
            let isCorrect = top?.family == prediction.truth
            if isCorrect { correct += 1 }
            confusion[prediction.truth.rawValue, default: [:]][top?.family.rawValue ?? "none", default: 0] += 1
            let probability = prediction.candidates.first(where: { $0.family == prediction.truth })?.calibratedProbability ?? 0
            logLoss -= log(max(1e-15, probability))
            for family in families {
                let p = prediction.candidates.first(where: { $0.family == family })?.calibratedProbability ?? 0
                brier += pow(p - (family == prediction.truth ? 1 : 0), 2)
            }
            confidences.append((top?.calibratedProbability ?? 0, isCorrect))
            if prediction.distance <= model.outOfDistributionThreshold,
               (top?.calibratedProbability ?? 0) >= model.minimumAcceptedProbability { accepted.append(prediction) }
        }
        let f1s = families.map { family -> Double in
            let tp = confusion[family.rawValue]?[family.rawValue, default: 0] ?? 0
            let fp = families.filter { $0 != family }.reduce(0) { $0 + (confusion[$1.rawValue]?[family.rawValue, default: 0] ?? 0) }
            let fn = confusion[family.rawValue, default: [:]].filter { $0.key != family.rawValue }.map(\.value).reduce(0, +)
            let precision = Double(tp) / Double(max(1, tp + fp))
            let recall = Double(tp) / Double(max(1, tp + fn))
            return precision + recall > 0 ? 2 * precision * recall / (precision + recall) : 0
        }
        return TimbreClassifierMetrics(
            split: split,
            rankCount: examples.count,
            instrumentCount: Set(examples.map(\.instrumentID)).count,
            accuracy: Double(correct) / Double(predictions.count),
            macroF1: f1s.reduce(0, +) / Double(f1s.count),
            logLoss: logLoss / Double(predictions.count),
            brierScore: brier / Double(predictions.count),
            expectedCalibrationError: calibrationError(confidences),
            acceptedCoverage: Double(accepted.count) / Double(predictions.count),
            acceptedAccuracy: accepted.isEmpty ? nil : Double(accepted.filter { $0.candidates.first?.family == $0.truth }.count) / Double(accepted.count),
            confusion: confusion
        )
    }

    private static func calibrationError(_ values: [(Double, Bool)]) -> Double {
        guard !values.isEmpty else { return 0 }
        return (0..<10).reduce(0) { total, bin in
            let lower = Double(bin) / 10
            let upper = Double(bin + 1) / 10
            let items = values.filter { $0.0 >= lower && ($0.0 < upper || bin == 9) }
            guard !items.isEmpty else { return total }
            let confidence = items.map(\.0).reduce(0, +) / Double(items.count)
            let accuracy = Double(items.filter(\.1).count) / Double(items.count)
            return total + Double(items.count) / Double(values.count) * abs(confidence - accuracy)
        }
    }

    private static func softmax(_ logits: [Double]) -> [Double] {
        let maximum = logits.max() ?? 0
        let values = logits.map { exp(min(60, $0 - maximum)) }
        let total = max(1e-15, values.reduce(0, +))
        return values.map { $0 / total }
    }

    private static func meanVector(_ rows: [[Double]]) -> [Double] {
        guard let count = rows.first?.count, !rows.isEmpty else { return [] }
        var result = [Double](repeating: 0, count: count)
        for row in rows { for index in 0..<count { result[index] += row[index] / Double(rows.count) } }
        return result
    }

    private static func euclidean(_ left: [Double], _ right: [Double]) -> Double {
        sqrt(zip(left, right).reduce(0) { $0 + pow($1.0 - $1.1, 2) })
    }

    private static func conformalUpperQuantile(_ values: [Double], alpha: Double) -> Double {
        guard !values.isEmpty else { return .infinity }
        let sorted = values.sorted()
        let rank = min(sorted.count, max(1, Int(ceil((Double(sorted.count) + 1) * (1 - alpha)))))
        return sorted[rank - 1]
    }

    private static func percentile(_ values: [Double], _ fraction: Double) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[min(sorted.count - 1, max(0, Int((fraction * Double(sorted.count - 1)).rounded())))]
    }

    private static func stableHash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private func fixed(_ value: Double, _ decimals: Int) -> String {
    value.isFinite ? String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), decimals, value) : "not finite"
}
