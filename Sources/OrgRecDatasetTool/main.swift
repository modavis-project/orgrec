import CryptoKit
import Foundation
import OrgRecCore

private struct PositivXRTimbreValidationFailure: Codable {
    var filename: String
    var stopCode: String
    var midiNote: Int
    var referenceChannel: Int
    var message: String
}

private struct PositivXRTimbreValidationResult: Codable {
    var filename: String
    var stopCode: String
    var midiNote: Int
    var soundingSemitoneOffset: Int
    var referenceChannel: Int
    var processingSeconds: Double
    var observation: PipeTimbreObservation
}

private struct PositivXRChannelSensitivity: Codable {
    var pairedFileCount: Int
    var centroidMedianAbsoluteDifference: Double?
    var centroid95thPercentileAbsoluteDifference: Double?
    var slopeMedianAbsoluteDifferenceDBPerOctave: Double?
    var slope95thPercentileAbsoluteDifferenceDBPerOctave: Double?
    var topFamilyAgreementRate: Double?
    var outOfDistributionDisagreementCount: Int
}

private struct PositivXRTimbreValidationSummary: Codable {
    var sourceFileCount: Int
    var requestedObservationCount: Int
    var completedObservationCount: Int
    var failedObservationCount: Int
    var applicableObservationCount: Int
    var limitedObservationCount: Int
    var notApplicableObservationCount: Int
    var outOfDistributionObservationCount: Int
    var observationsWithoutFamilySupport: Int
    var totalProcessingSeconds: Double
    var meanProcessingSecondsPerObservation: Double?
}

private struct PositivXRTimbreValidationReport: Codable {
    var contract: String
    var generatedAt: Date
    var software: OrgRecSoftwareMetadata
    var methodologyContract: String
    var methodologyAlgorithm: String
    var parameterSHA256: String
    var parameters: TimbreAnalysisParameters
    var sourceDirectory: String
    var sourceMutationPolicy: String
    var referenceA4Hz: Double
    var fundamentalPolicy: String
    var analyzedReferenceChannels: [Int]
    var summary: PositivXRTimbreValidationSummary
    var channelSensitivity: PositivXRChannelSensitivity
    var rankReports: [TimbreAnalysisReport]
    var results: [PositivXRTimbreValidationResult]
    var failures: [PositivXRTimbreValidationFailure]
    var interpretationCaveats: [String]
}

@main
struct OrgRecDatasetTool {
    static func main() async {
        do {
            try await run()
        } catch {
            FileHandle.standardError.write(Data("OrgRecDatasetTool: \(error.localizedDescription)\n".utf8))
            Foundation.exit(1)
        }
    }

    private static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let command = arguments.first else {
            printUsage()
            return
        }
        let importer = LegacyAudioDatasetImporter()
        switch command {
        case "inspect":
            guard arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let output = URL(fileURLWithPath: arguments[2])
            let inspection = try await importer.inspect(directory: source, profile: .positivXR)
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(inspection).write(to: output, options: .atomic)
            print("Inspected \(inspection.files.count) files across \(inspection.stopCodes.count) stops (\(inspection.totalBytes) bytes).")
            print("Wrote \(output.path)")
        case "import":
            guard arguments.count == 3 || arguments.count == 4 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let destination = URL(fileURLWithPath: arguments[2], isDirectory: true)
            let analyze = arguments.dropFirst(3).contains("--analyze")
            print("Checksumming and importing source originals…")
            let project = try await importer.importDataset(from: source, to: destination, profile: .positivXR)
            print("Imported \(project.takes.count) takes to \(destination.path)")
            if analyze {
                print("Analyzing a stratified sample…")
                let report = try await importer.analyzeStratifiedSample(projectURL: destination)
                print("Analyzed \(report.results.count) takes; report: \(destination.appendingPathComponent(LegacyAudioDatasetImporter.analysisReportRelativePath).path)")
            }
        case "analyze":
            guard arguments.count == 2 else { printUsage(); return }
            let project = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let report = try await importer.analyzeStratifiedSample(projectURL: project)
            print("Analyzed \(report.results.count) takes; report: \(project.appendingPathComponent(LegacyAudioDatasetImporter.analysisReportRelativePath).path)")
        case "audit":
            guard arguments.count == 2 || arguments.count == 3 else { printUsage(); return }
            let projectURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let project = try await ProjectStore().load(from: projectURL)
            let report = ProjectConsistencyAuditor.audit(project: project, packageURL: projectURL)
            if arguments.count == 3 {
                let output = URL(fileURLWithPath: arguments[2])
                try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
                try OrgRecCoding.encoder.encode(report).write(to: output, options: .atomic)
                print("Wrote \(output.path)")
            }
            print("Audit score \(report.score)/100: \(report.blockerCount) blockers, \(report.warningCount) warnings, \(report.informationCount) information notices (\(report.checksPerformed) checks).")
            for issue in report.issues { print("[\(issue.severity.rawValue)] \(issue.title): \(issue.detail)") }
        case "refresh":
            guard arguments.count == 2 else { printUsage(); return }
            let project = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let refreshed = try await importer.refreshImportedProjectMetadata(at: project)
            print("Refreshed and checksum-verified metadata for \(refreshed.takes.count) takes at \(project.path)")
        case "export":
            guard arguments.count == 3 else { printUsage(); return }
            let projectURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let destination = URL(fileURLWithPath: arguments[2], isDirectory: true)
            let project = try await ProjectStore().load(from: projectURL)
            try await CapturePackageBuilder().build(project: project, packageURL: projectURL, destinationURL: destination)
            let report = try IADPackageValidator.validate(packageURL: destination)
            guard report.isValid else { throw OrgRecError.exportValidation(report.errors.joined(separator: "; ")) }
            print("Exported and validated \(report.verifiedFileCount) indexed payloads at \(destination.path)")
        case "vao-export":
            guard arguments.count == 3 else { printUsage(); return }
            let projectURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let destination = URL(fileURLWithPath: arguments[2])
            let project = try await ProjectStore().load(from: projectURL)
            _ = try await VAO05PackageBuilder().build(
                project: project,
                packageURL: projectURL,
                destinationURL: destination
            )
            let inspection = try await VAO05PackageReader().inspect(destination)
            guard inspection.isValid else {
                throw OrgRecError.exportValidation(inspection.errors.joined(separator: "; "))
            }
            print("Exported and validated VAO 0.5.0 preservation closure with \(inspection.realizationCount) realizations at \(destination.path)")
        case "vao-import":
            guard arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let destination = URL(fileURLWithPath: arguments[2], isDirectory: true)
            if try VAO05PackageReader.formatVersion(of: source) == VAO05Contract.formatVersion {
                let inspection = try await VAO05PackageReader().importWorkspace(from: source, to: destination)
                print("Validated and imported \(inspection.displayTitle) as a VAO 0.5.0 workspace at \(destination.path)")
            } else {
                let project = try await VAOPackageImporter().importPackage(from: source, to: destination)
                print("Validated and restored historical VAO project \(project.organName) with \(project.takes.count) takes at \(destination.path)")
            }
        case "vao-validate":
            guard arguments.count == 2 || arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            guard try VAO05PackageReader.formatVersion(of: source) == VAO05Contract.formatVersion else {
                throw OrgRecError.invalidProject("vao-validate requires VAO 0.5.0; use the versioned Python tools for historical conformance packages.")
            }
            let inspection = try await VAO05PackageReader().inspect(source)
            if arguments.count == 3 {
                let output = URL(fileURLWithPath: arguments[2])
                try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
                try OrgRecCoding.encoder.encode(inspection).write(to: output, options: .atomic)
            }
            guard inspection.isValid else {
                throw OrgRecError.invalidProject(inspection.errors.joined(separator: "; "))
            }
            print("Passed OrgRec's native VAO 0.5.0 integrity checks with \(inspection.realizationCount) realizations and \(inspection.verifiedPayloadBytes) verified payload bytes.")
        case "vao-inspect":
            guard arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let output = URL(fileURLWithPath: arguments[2])
            let inspection = try await VAO05PackageReader().inspect(source)
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(inspection).write(to: output, options: .atomic)
            print("Inspected VAO 0.5.0 \(inspection.manifest.id); wrote \(output.path)")
        case "vao-workspace-import":
            guard arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let destination = URL(fileURLWithPath: arguments[2], isDirectory: true)
            let inspection = try await VAO05PackageReader().importWorkspace(from: source, to: destination)
            print("Imported \(inspection.displayTitle) as a verified VAO 0.5.0 workspace at \(destination.path)")
        case "vao-extract-asset":
            guard arguments.count == 4 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let destination = URL(fileURLWithPath: arguments[3])
            try await VAO05PackageReader().extractRealization(id: arguments[2], from: source, to: destination)
            print("Extracted and verified realization \(arguments[2]) to \(destination.path)")
        case "vao-copy":
            guard arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let destination = URL(fileURLWithPath: arguments[2])
            let inspection = try await VAO05PackageReader().inspect(source)
            guard inspection.isValid else {
                throw OrgRecError.invalidProject(inspection.errors.joined(separator: "; "))
            }
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw OrgRecError.invalidProject("The VAO copy destination already exists.")
            }
            try FileManager.default.copyItem(at: source, to: destination)
            _ = try await VAO05PackageReader().inspect(destination)
            print("Copied and revalidated the immutable VAO 0.5.0 package to \(destination.path)")
        case "pod-db-validate":
            guard arguments.count == 2 || arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let inspection = try PODDatabaseReader.inspect(databaseURL: source)
            if arguments.count == 3 {
                let output = URL(fileURLWithPath: arguments[2])
                try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
                try OrgRecCoding.encoder.encode(inspection).write(to: output, options: .atomic)
            }
            guard inspection.isCompatible else {
                throw OrgRecError.invalidProject(inspection.errors.joined(separator: "; "))
            }
            guard inspection.matchesPublishedArtifact else {
                throw OrgRecError.invalidProject("The database is schema-compatible but does not match the pinned POD 1.5 OrgRec artifact size and SHA-256 digest.")
            }
            print("Compatible POD \(inspection.releaseVersion ?? "unknown") OrgRec database: \(inspection.organCount) organs, \(inspection.componentCount) components, \(inspection.fileSize) bytes.")
            print("SHA-256 \(inspection.sha256)")
        case "pod-db-import":
            guard arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let destination = URL(fileURLWithPath: arguments[2])
            let inspection = try await PODDatabaseImporter().importVerifiedDatabase(from: source, to: destination)
            print("Imported and revalidated POD \(inspection.releaseVersion ?? "unknown") database at \(destination.path)")
            print("SHA-256 \(inspection.sha256)")
        case "pod-db-download":
            guard arguments.count >= 3, let remoteURL = URL(string: arguments[1]) else { printUsage(); return }
            let destination = URL(fileURLWithPath: arguments[2])
            let expectedSHA256 = option("--sha256", in: arguments)
            let expectedBytes = option("--bytes", in: arguments).flatMap(Int64.init)
            let inspection = try await PODDatabaseImporter().downloadVerifiedDatabase(
                from: remoteURL,
                to: destination,
                expectedSHA256: expectedSHA256,
                expectedByteSize: expectedBytes
            )
            print("Downloaded, validated, and cached POD \(inspection.releaseVersion ?? "unknown") database at \(destination.path)")
            print("SHA-256 \(inspection.sha256)")
        case "pod-db-search":
            guard arguments.count >= 3 else { printUsage(); return }
            let database = URL(fileURLWithPath: arguments[1])
            let query = arguments[2]
            let limit = option("--limit", in: arguments).flatMap(Int.init) ?? 30
            let results = try PODDatabaseReader.search(databaseURL: database, query: query, limit: limit)
            for result in results {
                let builder = result.builders.map { " · \($0)" } ?? ""
                let stops = result.stopCount.map { " · \($0) stops" } ?? ""
                print("\(result.mdvsID)\t\(result.title)\(builder)\(stops)")
            }
            print("\(results.count) result(s)")
        case "roundtrip":
            guard arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let destination = URL(fileURLWithPath: arguments[2], isDirectory: true)
            let report = try IADPackageValidator.validate(packageURL: source)
            guard report.isValid else { throw OrgRecError.exportValidation(report.errors.joined(separator: "; ")) }
            let project = try await IADPackageImporter().importPackage(from: source, to: destination)
            print("Validated and reconstructed \(project.takes.count) takes at \(destination.path)")
        case "native-corpus-inspect":
            guard arguments.count >= 3 else { printUsage(); return }
            let output = URL(fileURLWithPath: arguments[1])
            let optionIndex = arguments.firstIndex(where: { $0.hasPrefix("--") }) ?? arguments.endIndex
            let roots = arguments[2..<optionIndex].map { URL(fileURLWithPath: $0, isDirectory: true) }
            guard !roots.isEmpty else { printUsage(); return }
            let wavLimit = option("--wav-smpl-limit", in: arguments).flatMap(Int.init) ?? 0
            let inspection = try await NativeSampleCorpusInspector().inspect(
                roots: roots,
                maximumWAVMetadataFiles: max(0, wavLimit)
            )
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(inspection).write(to: output, options: .atomic)
            print("Indexed \(inspection.regularFileCount) files (\(inspection.totalBytes) bytes) and \(inspection.definitions.count) sampler definitions.")
            print("Inspected \(inspection.wavMetadata.inspectedFileCount) WAVE files; \(inspection.wavMetadata.samplerChunkFileCount) contained smpl metadata with \(inspection.wavMetadata.declaredLoopCount) loop records.")
            print("Wrote \(output.path)")
        case "grandorgue-inspect":
            guard arguments.count >= 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let output = URL(fileURLWithPath: arguments[2])
            let sourceURL = option("--source-url", in: arguments)
            let inspection = try await GrandOrgueSampleSetImporter().inspect(odfURL: source, sourcePageURL: sourceURL)
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(inspection).write(to: output, options: .atomic)
            print("Inspected \(inspection.organName): \(inspection.stops.count) stops, \(inspection.referencedSampleCount) source sample mappings, \(inspection.uniqueReferencedAudioCount) referenced audio files.")
            print("Complete payload: \(inspection.payloadFiles.count) files (\(inspection.totalPayloadBytes) bytes); missing samples: \(inspection.missingSampleCount).")
            print("Wrote \(output.path)")
        case "grandorgue-import":
            guard arguments.count >= 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let destination = URL(fileURLWithPath: arguments[2], isDirectory: true)
            let sourceURL = option("--source-url", in: arguments)
            let project = try await GrandOrgueSampleSetImporter().importSampleSet(
                odfURL: source,
                to: destination,
                sourcePageURL: sourceURL
            )
            print("Imported \(project.organName) with \(project.takes.count) playable source variants at \(destination.path)")
        case "grandorgue-vao":
            guard arguments.count >= 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let destination = URL(fileURLWithPath: arguments[2])
            let sourceURL = option("--source-url", in: arguments)
            let retainedProject = option("--project", in: arguments).map { URL(fileURLWithPath: $0, isDirectory: true) }
            let temporaryProject = FileManager.default.temporaryDirectory
                .appendingPathComponent("OrgRec-GrandOrgue-\(UUID().uuidString).orgrec", isDirectory: true)
            let projectURL = retainedProject ?? temporaryProject
            defer {
                if retainedProject == nil { try? FileManager.default.removeItem(at: temporaryProject) }
            }
            let project = try await GrandOrgueSampleSetImporter().importSampleSet(
                odfURL: source,
                to: projectURL,
                sourcePageURL: sourceURL
            )
            _ = try await VAO05PackageBuilder().build(project: project, packageURL: projectURL, destinationURL: destination)
            let inspection = try await VAO05PackageReader().inspect(destination)
            guard inspection.isValid else { throw OrgRecError.exportValidation(inspection.errors.joined(separator: "; ")) }
            print("Converted \(project.organName) to a validated VAO 0.5.0 preservation closure with \(inspection.realizationCount) realizations at \(destination.path)")
            if retainedProject != nil { print("Retained the editable OrgRec project at \(projectURL.path)") }
        case "long-take-inspect":
            guard arguments.count >= 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1])
            let output = URL(fileURLWithPath: arguments[2])
            let referenceChannel = option("--reference-channel", in: arguments).flatMap(Int.init) ?? 1
            let analysis = try await LongTakeSegmenter().analyze(
                fileURL: source,
                assignmentMode: .nearestPitch,
                referenceChannel: max(0, referenceChannel - 1)
            )
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(analysis).write(to: output, options: .atomic)
            print("Detected \(analysis.segments.count) sustained note region(s); \(analysis.reviewSegmentCount) need review.")
            let floorText = String(format: "%.1f", analysis.noiseFloorDBFS)
            let thresholdText = String(format: "%.1f", analysis.activityThresholdDBFS)
            print("Noise floor \(floorText) dBFS; activity threshold \(thresholdText) dBFS.")
            let exactOnsets = analysis.segments.filter { $0.onsetFrame != nil && $0.exportStartFrame != nil }.count
            let fallbackOnsets = analysis.segments.filter { $0.onsetDetectionMethod?.hasSuffix("fallback") == true }.count
            print("Fine onset pass resolved \(exactOnsets) exact-frame cut(s); \(fallbackOnsets) used the conservative fallback.")
            let harmonicTails = analysis.segments.filter { $0.tailDetectionMethod == "frequency-local-harmonic-decay" }.count
            let censoredTails = analysis.segments.filter { $0.tailDetectionMethod?.hasSuffix("censored") == true }.count
            print("Harmonic decay resolved \(harmonicTails) tail end(s); \(censoredTails) reached a following note or analysis limit.")
            print("Wrote \(output.path)")
        case "positivxr-timbre-validate":
            guard arguments.count == 3 else { printUsage(); return }
            let source = URL(fileURLWithPath: arguments[1], isDirectory: true)
            let output = URL(fileURLWithPath: arguments[2])
            let report = try await validatePositivXRTimbre(source: source)
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(report).write(to: output, options: .atomic)
            print("Completed \(report.summary.completedObservationCount)/\(report.summary.requestedObservationCount) channel analyses for \(report.summary.sourceFileCount) PositivXR files in \(String(format: "%.1f", report.summary.totalProcessingSeconds)) seconds.")
            print("Failures: \(report.summary.failedObservationCount); OOD: \(report.summary.outOfDistributionObservationCount); channel-pair top-family agreement: \(report.channelSensitivity.topFamilyAgreementRate.map { String(format: "%.1f%%", $0 * 100) } ?? "not available").")
            print("Wrote \(output.path)")
        case "retrieved-corpus-build":
            guard arguments.count >= 4 else { printUsage(); return }
            let inventory = URL(fileURLWithPath: arguments[1])
            let catalog = URL(fileURLWithPath: arguments[2])
            let output = URL(fileURLWithPath: arguments[3])
            let rightsPolicy: RetrievedCorpusRightsPolicy
            if arguments.contains("--include-unreviewed-rights") {
                rightsPolicy = .localResearchIncludingUnreviewed
            } else if arguments.contains("--include-project-gpl") {
                rightsPolicy = .creativeCommonsAndProjectGPL
            } else {
                rightsPolicy = .explicitCreativeCommons
            }
            let options = RetrievedCorpusBuildOptions(
                rightsPolicy: rightsPolicy,
                requireSingleRealPipeOrgan: !arguments.contains("--include-modeled"),
                maximumInstruments: option("--max-instruments", in: arguments).flatMap(Int.init),
                maximumRanksPerInstrument: option("--max-ranks", in: arguments).flatMap(Int.init),
                maximumPipesPerRank: option("--max-pipes", in: arguments).flatMap(Int.init) ?? 9,
                minimumPipesPerRank: option("--min-pipes", in: arguments).flatMap(Int.init) ?? 3,
                referenceChannel: max(0, (option("--reference-channel", in: arguments).flatMap(Int.init) ?? 1) - 1)
            )
            let corpus = try await RetrievedSampleCorpusBuilder().build(
                inventoryURL: inventory,
                catalogURL: catalog,
                checkpointURL: output,
                options: options,
                progress: { print($0) }
            )
            let familyCounts = Dictionary(grouping: corpus.ranks, by: { $0.labelAssignment.family }).mapValues(\.count)
            print("Corpus complete: \(corpus.instruments.count) instruments, \(corpus.ranks.count) ranks, \(corpus.ranks.reduce(0) { $0 + $1.observations.count }) pipe observations.")
            print("Families: \(familyCounts.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: ", ")).")
            print("Fingerprint: \(corpus.fingerprint)")
            print("Wrote \(output.path)")
        case "comparative-study-export":
            guard arguments.count >= 3 else { printUsage(); return }
            let corpusURL = URL(fileURLWithPath: arguments[1])
            let outputDirectory = URL(fileURLWithPath: arguments[2], isDirectory: true)
            let corpus = try OrgRecCoding.decoder.decode(RetrievedTimbreCorpus.self, from: Data(contentsOf: corpusURL))
            let parameters = ComparativeTimbreStudyParameters(
                splitSeed: option("--split-seed", in: arguments) ?? "orgrec-comparative-stop-timbre-split/1",
                minimumIndependentInstrumentsPerExactName: option("--minimum-name-instruments", in: arguments).flatMap(Int.init) ?? 3,
                familyPermutationCount: option("--family-permutations", in: arguments).flatMap(Int.init) ?? 999,
                classifierPermutationCount: option("--classifier-permutations", in: arguments).flatMap(Int.init) ?? 199
            )
            let study = try ComparativeTimbreStudyBuilder.build(
                corpus: corpus,
                sourceCorpusURL: corpusURL,
                parameters: parameters
            )
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let studyURL = outputDirectory.appendingPathComponent("comparative-corpus.json")
            try OrgRecCoding.encoder.encode(study).write(to: studyURL, options: .atomic)
            try rankCSV(study).write(
                to: outputDirectory.appendingPathComponent("rank-features.csv"),
                atomically: true,
                encoding: .utf8
            )
            try pipeCSV(study).write(
                to: outputDirectory.appendingPathComponent("pipe-features.csv"),
                atomically: true,
                encoding: .utf8
            )
            try exclusionCSV(study).write(
                to: outputDirectory.appendingPathComponent("exclusions.csv"),
                atomically: true,
                encoding: .utf8
            )
            let familyCounts = Dictionary(grouping: study.ranks, by: \.documentaryFamily).mapValues(\.count)
            print("Comparative export complete: \(study.assignments.count) instruments, \(study.ranks.count) ranks, \(study.pipes.count) pipe observations.")
            print("Families: \(familyCounts.map { "\($0.key.rawValue)=\($0.value)" }.sorted().joined(separator: ", ")).")
            print("Fingerprint: \(study.fingerprint)")
            print("Wrote \(outputDirectory.path)")
        case "timbre-model-train":
            guard arguments.count >= 3 else { printUsage(); return }
            let corpusURL = URL(fileURLWithPath: arguments[1])
            let output = URL(fileURLWithPath: arguments[2])
            let corpus = try OrgRecCoding.decoder.decode(RetrievedTimbreCorpus.self, from: Data(contentsOf: corpusURL))
            let version = option("--version", in: arguments) ?? "orgrec-empirical-timbre-\(ISO8601DateFormatter().string(from: .now))"
            let model = try EmpiricalTimbreTrainer.train(
                ranks: corpus.ranks,
                corpusSHA256: corpus.fingerprint,
                sourceDescription: "Retrieved pipe-organ corpus indexed by \(corpus.inventoryPath); rights policy \(corpus.options.rightsPolicy.rawValue); \(corpus.instruments.count) instrument groups and \(corpus.ranks.count) usable rank fingerprints.",
                modelVersion: version,
                options: EmpiricalTimbreTrainingOptions(splitSeed: option("--split-seed", in: arguments) ?? "orgrec-timbre-split-1")
            )
            try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(model).write(to: output, options: .atomic)
            let verified = try OrgRecCoding.decoder.decode(EmpiricalTimbreClassifierModel.self, from: Data(contentsOf: output))
            guard verified.featureNames == TimbreRankFeatureVectorizer.featureNames else {
                throw OrgRecError.invalidProject("The persisted model feature schema did not round-trip.")
            }
            for metrics in model.metrics {
                print("\(metrics.split.rawValue): \(metrics.instrumentCount) instruments / \(metrics.rankCount) ranks · accuracy \(String(format: "%.3f", metrics.accuracy)) · macro-F1 \(String(format: "%.3f", metrics.macroF1)) · ECE \(String(format: "%.3f", metrics.expectedCalibrationError)) · accepted coverage \(String(format: "%.3f", metrics.acceptedCoverage)).")
            }
            print("Calibrated temperatures: root \(String(format: "%.4f", model.rootNode.temperature)); flue \(String(format: "%.4f", model.flueNode.temperature)).")
            print("OOD threshold \(String(format: "%.3f", model.outOfDistributionThreshold)); abstention threshold \(String(format: "%.3f", model.minimumAcceptedProbability)).")
            print("Wrote \(output.path)")
        default:
            printUsage()
        }
    }

    private static func validatePositivXRTimbre(source: URL) async throws -> PositivXRTimbreValidationReport {
        let referenceA4 = 462.95
        let profile = LegacyDatasetProfile.positivXR
        let inspection = try await LegacyAudioDatasetImporter().inspect(directory: source, profile: profile)
        let mappings = Dictionary(uniqueKeysWithValues: profile.stopMappings.map { ($0.code, $0) })
        let engine = TimbreAnalysisEngine()
        let startedAt = Date()
        var results: [PositivXRTimbreValidationResult] = []
        var failures: [PositivXRTimbreValidationFailure] = []

        for (fileIndex, file) in inspection.files.enumerated() {
            guard let mapping = mappings[file.stopCode] else {
                for channel in 0..<max(1, file.channelCount) {
                    failures.append(PositivXRTimbreValidationFailure(
                        filename: file.filename,
                        stopCode: file.stopCode,
                        midiNote: file.midiNote,
                        referenceChannel: channel,
                        message: "No reviewed PositivXR stop mapping exists."
                    ))
                }
                continue
            }
            let fileURL = source.appendingPathComponent(file.filename)
            let digest = try sha256(of: fileURL)
            let soundingMIDI = file.midiNote + mapping.soundingSemitoneOffset
            let expectedFrequency = midiFrequency(soundingMIDI, a4: referenceA4)
            let channels = Array(0..<max(1, min(2, file.channelCount)))
            for channel in channels {
                let observationStartedAt = Date()
                do {
                    let observation = try await engine.analyze(
                        input: TimbreAnalysisInput(
                            fileURL: fileURL,
                            takeID: stableUUID("positivxr|\(file.filename)|take"),
                            roadmapItemID: stableUUID("positivxr|\(file.filename)|roadmap"),
                            midiNote: file.midiNote,
                            noteName: midiNoteName(file.midiNote),
                            expectedFrequencyHz: expectedFrequency,
                            measuredFrequencyHz: nil,
                            measuredConfidence: nil,
                            sourceAudioSHA256: digest,
                            sourceAnalysisRunID: nil,
                            referenceChannel: channel,
                            sustainStartSeconds: nil,
                            soundOffsetSeconds: nil,
                            keyUpSeconds: nil
                        ),
                        mode: .familySuggestion
                    )
                    results.append(PositivXRTimbreValidationResult(
                        filename: file.filename,
                        stopCode: file.stopCode,
                        midiNote: file.midiNote,
                        soundingSemitoneOffset: mapping.soundingSemitoneOffset,
                        referenceChannel: channel,
                        processingSeconds: Date().timeIntervalSince(observationStartedAt),
                        observation: observation
                    ))
                } catch {
                    failures.append(PositivXRTimbreValidationFailure(
                        filename: file.filename,
                        stopCode: file.stopCode,
                        midiNote: file.midiNote,
                        referenceChannel: channel,
                        message: error.localizedDescription
                    ))
                }
            }
            if (fileIndex + 1).isMultiple(of: 25) || fileIndex + 1 == inspection.files.count {
                print("PositivXR timbre validation: \(fileIndex + 1)/\(inspection.files.count) files")
            }
        }

        var rankReports: [TimbreAnalysisReport] = []
        for mapping in profile.stopMappings {
            for channel in [0, 1] {
                let observations = results
                    .filter { $0.stopCode == mapping.code && $0.referenceChannel == channel }
                    .map(\.observation)
                guard observations.isEmpty == false else { continue }
                rankReports.append(TimbreAnalysisEngine.report(
                    mode: .familySuggestion,
                    rankComponentID: "positivxr:\(mapping.code)",
                    rankLabel: "\(mapping.label) \(mapping.footHeight ?? "") · reference channel \(channel + 1)",
                    observations: observations
                ))
            }
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        let completed = results.count
        let summary = PositivXRTimbreValidationSummary(
            sourceFileCount: inspection.files.count,
            requestedObservationCount: inspection.files.reduce(0) { $0 + max(1, min(2, $1.channelCount)) },
            completedObservationCount: completed,
            failedObservationCount: failures.count,
            applicableObservationCount: results.filter { $0.observation.applicability == .applicable }.count,
            limitedObservationCount: results.filter { $0.observation.applicability == .limited }.count,
            notApplicableObservationCount: results.filter { $0.observation.applicability == .notApplicable }.count,
            outOfDistributionObservationCount: results.filter { $0.observation.outOfDistribution == true }.count,
            observationsWithoutFamilySupport: results.filter { $0.observation.familyCandidates.isEmpty }.count,
            totalProcessingSeconds: elapsed,
            meanProcessingSecondsPerObservation: completed > 0 ? elapsed / Double(completed) : nil
        )
        return PositivXRTimbreValidationReport(
            contract: "orgrec-positivxr-timbre-validation/1",
            generatedAt: .now,
            software: OrgRecSoftware.current,
            methodologyContract: TimbreMethodology.contractVersion,
            methodologyAlgorithm: TimbreMethodology.algorithmVersion,
            parameterSHA256: TimbreMethodology.parameterSHA256,
            parameters: TimbreMethodology.parameters,
            sourceDirectory: source.standardizedFileURL.path,
            sourceMutationPolicy: "read-only; source audio was not modified",
            referenceA4Hz: referenceA4,
            fundamentalPolicy: "A4=462.95 Hz inferred by the earlier stratified dual-estimator analysis; per-file fundamental bins use the mapped rank footage and this fixed reference. This validation does not relabel that prior as a new measured pitch.",
            analyzedReferenceChannels: [0, 1],
            summary: summary,
            channelSensitivity: channelSensitivity(results),
            rankReports: rankReports,
            results: results.sorted { ($0.stopCode, $0.midiNote, $0.referenceChannel) < ($1.stopCode, $1.midiNote, $1.referenceChannel) },
            failures: failures,
            interpretationCaveats: [
                "Family relative support is an OrgRec engineering profile, not a calibrated probability and not a documentary stop identification.",
                "The corpus has no encoded microphone, placement, room, environmental, acquisition, rights, temperament, or independently documented reference-pitch metadata.",
                "Because this validation uses the fixed calibrated expectation rather than a fresh per-file measured pitch, successful observations are intentionally limited evidence.",
                "Reference-channel sensitivity is descriptive; the two channels are not asserted to be independent microphones or ground truth.",
            ]
        )
    }

    private static func channelSensitivity(_ results: [PositivXRTimbreValidationResult]) -> PositivXRChannelSensitivity {
        let groups = Dictionary(grouping: results, by: \.filename)
        let pairs = groups.values.compactMap { group -> (PipeTimbreObservation, PipeTimbreObservation)? in
            guard let left = group.first(where: { $0.referenceChannel == 0 })?.observation,
                  let right = group.first(where: { $0.referenceChannel == 1 })?.observation else { return nil }
            return (left, right)
        }
        let centroidDifferences = pairs.compactMap { left, right -> Double? in
            guard let a = left.normalizedSpectralCentroid, let b = right.normalizedSpectralCentroid else { return nil }
            return abs(a - b)
        }
        let slopeDifferences = pairs.compactMap { left, right -> Double? in
            guard let a = left.weightedAverageSlopeDBPerOctave, let b = right.weightedAverageSlopeDBPerOctave else { return nil }
            return abs(a - b)
        }
        let comparableFamilies = pairs.compactMap { left, right -> Bool? in
            guard let a = left.familyCandidates.first?.family, let b = right.familyCandidates.first?.family else { return nil }
            return a == b
        }
        return PositivXRChannelSensitivity(
            pairedFileCount: pairs.count,
            centroidMedianAbsoluteDifference: percentile(centroidDifferences, fraction: 0.5),
            centroid95thPercentileAbsoluteDifference: percentile(centroidDifferences, fraction: 0.95),
            slopeMedianAbsoluteDifferenceDBPerOctave: percentile(slopeDifferences, fraction: 0.5),
            slope95thPercentileAbsoluteDifferenceDBPerOctave: percentile(slopeDifferences, fraction: 0.95),
            topFamilyAgreementRate: comparableFamilies.isEmpty ? nil : Double(comparableFamilies.filter { $0 }.count) / Double(comparableFamilies.count),
            outOfDistributionDisagreementCount: pairs.filter { ($0.0.outOfDistribution == true) != ($0.1.outOfDistribution == true) }.count
        )
    }

    private static func percentile(_ values: [Double], fraction: Double) -> Double? {
        let sorted = values.sorted()
        guard sorted.isEmpty == false else { return nil }
        let position = min(Double(sorted.count - 1), max(0, fraction * Double(sorted.count - 1)))
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        guard lower != upper else { return sorted[lower] }
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    private static func midiNoteName(_ midi: Int) -> String {
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        return "\(names[(midi % 12 + 12) % 12])\(midi / 12 - 1)"
    }

    private static func stableUUID(_ value: String) -> UUID {
        let digest = SHA256.hash(data: Data(value.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func option(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func rankCSV(_ study: ComparativeTimbreStudyCorpus) -> String {
        let metadata = [
            "record_id", "instrument_id", "instrument_name", "producer", "role", "rank_id",
            "source_label", "canonical_stop_name", "division", "footage", "documentary_family",
            "documentary_label_rule", "pipe_observation_count", "fingerprint_applicability",
            "fingerprint_selected_segment_count", "fingerprint_transition_count",
        ]
        var lines = [(metadata + study.featureNames).map(csvField).joined(separator: ",")]
        for rank in study.ranks {
            let values = [
                rank.recordID, rank.instrumentID, rank.instrumentName, rank.producer, rank.role.rawValue,
                rank.rankID, rank.sourceLabel, rank.canonicalStopName, rank.division ?? "", rank.footage ?? "",
                rank.documentaryFamily.rawValue, rank.documentaryLabelRule, String(rank.pipeObservationCount),
                rank.fingerprintApplicability.rawValue, String(rank.fingerprintSelectedSegmentCount),
                String(rank.fingerprintTransitionCount),
            ] + rank.featureValues.map(number)
            lines.append(values.map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func pipeCSV(_ study: ComparativeTimbreStudyCorpus) -> String {
        let metadata = [
            "record_id", "rank_record_id", "instrument_id", "rank_id", "source_label",
            "canonical_stop_name", "documentary_family", "midi_note", "normalized_spectral_centroid",
            "weighted_average_slope_db_per_octave", "even_to_odd_energy_ratio_db",
        ]
        let partials = (1...TimbreMethodology.maximumPartialCount).map { "partial_\($0)_relative_db" }
        let tail = ["first_five_prototype", "applicability", "source_audio_sha256"]
        var lines = [(metadata + partials + tail).map(csvField).joined(separator: ",")]
        for pipe in study.pipes {
            let metadataValues: [String] = [
                pipe.recordID, pipe.rankRecordID, pipe.instrumentID, pipe.rankID, pipe.sourceLabel,
                pipe.canonicalStopName, pipe.documentaryFamily.rawValue, pipe.midiNote.map(String.init) ?? "",
                pipe.normalizedSpectralCentroid.map(number) ?? "",
                pipe.weightedAverageSlopeDBPerOctave.map(number) ?? "",
                pipe.evenToOddEnergyRatioDB.map(number) ?? "",
            ]
            let partialValues = pipe.relativePartialLevelsDB.map { $0.map(number) ?? "" }
            let tailValues = [
                pipe.firstFivePrototype.rawValue, pipe.applicability.rawValue, pipe.sourceAudioSHA256,
            ]
            let values = metadataValues + partialValues + tailValues
            lines.append(values.map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func exclusionCSV(_ study: ComparativeTimbreStudyCorpus) -> String {
        var lines = [["entity_id", "scope", "reason"].map(csvField).joined(separator: ",")]
        for exclusion in study.exclusions {
            lines.append([exclusion.entityID, exclusion.scope, exclusion.reason].map(csvField).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.17g", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func printUsage() {
        print("""
        Usage:
          OrgRecDatasetTool inspect <source-directory> <inspection.json>
          OrgRecDatasetTool import <source-directory> <destination.orgrec> [--analyze]
          OrgRecDatasetTool analyze <project.orgrec>
          OrgRecDatasetTool audit <project.orgrec> [report.json]
          OrgRecDatasetTool refresh <project.orgrec>
          OrgRecDatasetTool export <project.orgrec> <destination.orgrec-capture>
          OrgRecDatasetTool vao-export <project.orgrec> <destination.vao>
          OrgRecDatasetTool vao-import <source.vao> <destination-directory>
          OrgRecDatasetTool vao-validate <source.vao> [report.json]
          OrgRecDatasetTool vao-inspect <source.vao> <inspection.json>
          OrgRecDatasetTool vao-workspace-import <source.vao> <destination-directory>
          OrgRecDatasetTool vao-extract-asset <source.vao> <realization-id> <destination-file>
          OrgRecDatasetTool vao-copy <source.vao> <destination.vao>
          OrgRecDatasetTool pod-db-validate <database.sqlite> [inspection.json]
          OrgRecDatasetTool pod-db-import <database.sqlite> <cache.sqlite>
          OrgRecDatasetTool pod-db-download <https-url> <cache.sqlite> [--sha256 <digest>] [--bytes <count>]
          OrgRecDatasetTool pod-db-search <database.sqlite> <query> [--limit <count>]
          OrgRecDatasetTool roundtrip <source.orgrec-capture> <destination.orgrec>
          OrgRecDatasetTool native-corpus-inspect <inspection.json> <root> [root ...] [--wav-smpl-limit <n>]
          OrgRecDatasetTool grandorgue-inspect <source.organ> <inspection.json> [--source-url <url>]
          OrgRecDatasetTool grandorgue-import <source.organ> <destination.orgrec> [--source-url <url>]
          OrgRecDatasetTool grandorgue-vao <source.organ> <destination.vao> [--project <destination.orgrec>] [--source-url <url>]
          OrgRecDatasetTool long-take-inspect <source.wav> <analysis.json> [--reference-channel <1-based-index>]
          OrgRecDatasetTool positivxr-timbre-validate <source-directory> <report.json>
          OrgRecDatasetTool retrieved-corpus-build <inventory.csv> <catalog.csv> <corpus.json>
            [--include-project-gpl | --include-unreviewed-rights] [--include-modeled]
            [--max-instruments <n>] [--max-ranks <n>] [--max-pipes <n>] [--min-pipes <n>]
            [--reference-channel <1-based-index>]
          OrgRecDatasetTool comparative-study-export <corpus.json> <output-directory>
            [--split-seed <seed>] [--minimum-name-instruments <n>]
            [--family-permutations <n>] [--classifier-permutations <n>]
          OrgRecDatasetTool timbre-model-train <corpus.json> <model.json>
            [--version <identifier>] [--split-seed <seed>]
        """)
    }
}
