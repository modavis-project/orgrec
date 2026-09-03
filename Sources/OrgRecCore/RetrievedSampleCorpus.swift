import AVFAudio
import CryptoKit
import Foundation

public enum RetrievedCorpusRightsPolicy: String, Codable, CaseIterable, Sendable {
    /// Only inventory records explicitly labelled as an open Creative Commons licence.
    case explicitCreativeCommons
    /// Also includes project-stated GPL packages. This is opt-in because a project
    /// licence statement may not establish the rights status of every source sample.
    case creativeCommonsAndProjectGPL
    /// Local analysis only. The resulting model must not be redistributed until
    /// every included source has been reviewed for the intended use.
    case localResearchIncludingUnreviewed
}

public struct RetrievedCorpusBuildOptions: Codable, Hashable, Sendable {
    public var rightsPolicy: RetrievedCorpusRightsPolicy
    public var requireSingleRealPipeOrgan: Bool
    public var maximumInstruments: Int?
    public var maximumRanksPerInstrument: Int?
    public var maximumPipesPerRank: Int
    public var minimumPipesPerRank: Int
    public var referenceChannel: Int

    public init(
        rightsPolicy: RetrievedCorpusRightsPolicy = .explicitCreativeCommons,
        requireSingleRealPipeOrgan: Bool = true,
        maximumInstruments: Int? = nil,
        maximumRanksPerInstrument: Int? = nil,
        maximumPipesPerRank: Int = 9,
        minimumPipesPerRank: Int = 3,
        referenceChannel: Int = 0
    ) {
        self.rightsPolicy = rightsPolicy
        self.requireSingleRealPipeOrgan = requireSingleRealPipeOrgan
        self.maximumInstruments = maximumInstruments
        self.maximumRanksPerInstrument = maximumRanksPerInstrument
        self.maximumPipesPerRank = max(3, maximumPipesPerRank)
        self.minimumPipesPerRank = max(3, minimumPipesPerRank)
        self.referenceChannel = max(0, referenceChannel)
    }
}

public struct RetrievedCorpusInstrumentSummary: Codable, Hashable, Sendable {
    public var entityID: String
    public var instrumentName: String
    public var producer: String
    public var recordingBasis: String
    public var licenseClass: String
    public var sourceURL: String
    public var sourceDefinitionPath: String
    public var sourceDefinitionSHA256: String
    public var includedRankCount: Int
    public var includedPipeCount: Int
}

public struct RetrievedCorpusExclusion: Codable, Hashable, Sendable {
    public var entityID: String
    public var scope: String
    public var reason: String
}

public struct RetrievedTimbreCorpus: Codable, Sendable {
    public var contractVersion: String
    public var generatedAt: Date
    public var software: OrgRecSoftwareMetadata
    public var inventoryPath: String
    public var inventorySHA256: String
    public var catalogPath: String
    public var catalogSHA256: String
    public var sourceMutationPolicy: String
    public var options: RetrievedCorpusBuildOptions
    public var instruments: [RetrievedCorpusInstrumentSummary]
    public var ranks: [EmpiricalTimbreRankRecord]
    public var exclusions: [RetrievedCorpusExclusion]
    public var warnings: [String]

    public init(
        contractVersion: String = "orgrec-retrieved-timbre-corpus/1",
        generatedAt: Date = .now,
        software: OrgRecSoftwareMetadata = OrgRecSoftware.current,
        inventoryPath: String,
        inventorySHA256: String,
        catalogPath: String,
        catalogSHA256: String,
        sourceMutationPolicy: String = "The acquired corpus was read-only. Native packages were inspected in place or expanded only into a disposable temporary directory. No source sample, definition, manifest, or directory was changed.",
        options: RetrievedCorpusBuildOptions,
        instruments: [RetrievedCorpusInstrumentSummary] = [],
        ranks: [EmpiricalTimbreRankRecord] = [],
        exclusions: [RetrievedCorpusExclusion] = [],
        warnings: [String] = []
    ) {
        self.contractVersion = contractVersion
        self.generatedAt = generatedAt
        self.software = software
        self.inventoryPath = inventoryPath
        self.inventorySHA256 = inventorySHA256
        self.catalogPath = catalogPath
        self.catalogSHA256 = catalogSHA256
        self.sourceMutationPolicy = sourceMutationPolicy
        self.options = options
        self.instruments = instruments
        self.ranks = ranks
        self.exclusions = exclusions
        self.warnings = warnings
    }

    public var fingerprint: String {
        var copy = self
        copy.generatedAt = Date(timeIntervalSince1970: 0)
        return ((try? OrgRecCoding.lineEncoder.encode(copy)) ?? Data()).sha256Hex
    }
}

public actor RetrievedSampleCorpusBuilder {
    public typealias Progress = @Sendable (String) -> Void

    private struct InventoryRecord {
        var entityID: String
        var instrumentName: String
        var producer: String
        var licenseClass: String
        var sourceURL: String
        var volume: String
        var path: String
        var pathExists: Bool
        var representative: Bool
        var nativePlatform: String
    }

    private struct CatalogRecord {
        var entityID: String
        var recordingBasis: String
        var entityGranularity: String
    }

    private let crepe = CREPEPitchEstimator()
    private let pyin = PYINPitchEstimator(configuration: .init(maximumFrames: 48))
    private let autocorrelation = AutocorrelationPitchEstimator()
    private let timbre = TimbreAnalysisEngine()

    public init() {}

    public func build(
        inventoryURL: URL,
        catalogURL: URL,
        checkpointURL: URL,
        options: RetrievedCorpusBuildOptions = RetrievedCorpusBuildOptions(),
        progress: Progress? = nil
    ) async throws -> RetrievedTimbreCorpus {
        let inventoryHash = try sha256(of: inventoryURL)
        let catalogHash = try sha256(of: catalogURL)
        let inventory = try Self.inventoryRecords(url: inventoryURL)
        let catalog = Dictionary(uniqueKeysWithValues: try Self.catalogRecords(url: catalogURL).map { ($0.entityID, $0) })
        var corpus: RetrievedTimbreCorpus
        if FileManager.default.fileExists(atPath: checkpointURL.path),
           let existing = try? OrgRecCoding.decoder.decode(RetrievedTimbreCorpus.self, from: Data(contentsOf: checkpointURL)),
           existing.inventorySHA256 == inventoryHash,
           existing.catalogSHA256 == catalogHash,
           existing.options == options {
            corpus = existing
            progress?("Resuming corpus checkpoint with \(existing.instruments.count) completed instruments and \(existing.ranks.count) ranks.")
        } else {
            corpus = RetrievedTimbreCorpus(
                inventoryPath: inventoryURL.standardizedFileURL.path,
                inventorySHA256: inventoryHash,
                catalogPath: catalogURL.standardizedFileURL.path,
                catalogSHA256: catalogHash,
                options: options
            )
        }
        let completed = Set(corpus.instruments.map(\.entityID))
        progress?("Inventory parser read \(inventory.count) rows; \(inventory.filter(\.representative).count) are distinct representatives.")
        var eligible = inventory.filter { $0.representative && $0.nativePlatform.lowercased().contains("grandorgue") }
        progress?("\(eligible.count) representative rows declare GrandOrgue compatibility.")
        eligible = eligible.filter { rightsAllowed($0.licenseClass, policy: options.rightsPolicy) }
        progress?("\(eligible.count) rows remain after the \(options.rightsPolicy.rawValue) rights filter.")
        if options.requireSingleRealPipeOrgan {
            eligible = eligible.filter { catalog[$0.entityID]?.recordingBasis == "Single real pipe organ" }
            progress?("\(eligible.count) rows remain after requiring a single-real-pipe-organ recording basis.")
        }
        eligible.sort { $0.entityID < $1.entityID }
        if let maximum = options.maximumInstruments { eligible = Array(eligible.prefix(maximum)) }
        if options.rightsPolicy == .localResearchIncludingUnreviewed {
            corpus.warnings.append("Unreviewed-rights sources were enabled for local research. Do not redistribute the corpus artifact or fitted weights until purpose-specific rights review is complete.")
        } else if options.rightsPolicy == .creativeCommonsAndProjectGPL {
            corpus.warnings.append("Project-stated GPL sources were enabled. Confirm that each package's sample audio—not only its program or definition—is covered before distributing fitted weights.")
        }

        for (instrumentIndex, record) in eligible.enumerated() where !completed.contains(record.entityID) {
            progress?("Resolving \(record.entityID) \(record.instrumentName) (\(instrumentIndex + 1)/\(eligible.count))…")
            var temporaryRoot: URL?
            let processingRoot = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-corpus-audio-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: processingRoot, withIntermediateDirectories: true)
            do {
                let source = try resolveSource(record: record)
                let resolved: (odf: URL, cleanup: URL?)
                if source.pathExtension.lowercased() == "orgue" {
                    let extraction = try extractNativePackage(source)
                    temporaryRoot = extraction
                    let odfs = try findFiles(withExtension: "organ", below: extraction)
                    guard let selected = selectCanonicalDefinition(odfs, instrumentName: record.instrumentName) else {
                        throw OrgRecError.invalidProject("The native .orgue package contains no GrandOrgue definition.")
                    }
                    resolved = (selected, extraction)
                } else if source.pathExtension.lowercased() == "organ" {
                    resolved = (source, nil)
                } else {
                    let odfs = try findFiles(withExtension: "organ", below: source)
                    guard let selected = selectCanonicalDefinition(odfs, instrumentName: record.instrumentName) else {
                        throw OrgRecError.invalidProject("No GrandOrgue .organ definition was found below the resolved dataset directory.")
                    }
                    resolved = (selected, nil)
                }
                let inspection = try await GrandOrgueSampleSetImporter().inspect(odfURL: resolved.odf, sourcePageURL: record.sourceURL)
                let root = URL(fileURLWithPath: inspection.sourceDirectory, isDirectory: true)
                var rankRecords: [EmpiricalTimbreRankRecord] = []
                var rankExclusions: [RetrievedCorpusExclusion] = []
                var labelledStops = inspection.stops.compactMap { stop -> (GrandOrgueStopSummary, TimbreLabelAssignment)? in
                    if (stop.rankSectionNames?.count ?? 0) > 1 {
                        rankExclusions.append(RetrievedCorpusExclusion(entityID: record.entityID, scope: "rank:\(stop.id)", reason: "The stop binds \(stop.rankSectionNames?.count ?? 0) ranks. Compound/mutation layers are preserved but excluded from single-rank four-family supervision."))
                        return nil
                    }
                    guard let label = TimbreDocumentaryLabelNormalizer.assignment(for: stop.name) else {
                        rankExclusions.append(RetrievedCorpusExclusion(entityID: record.entityID, scope: "rank:\(stop.id)", reason: "The documentary stop label ‘\(stop.name)’ is ambiguous, compound, detuned, or outside the four-family label rules."))
                        return nil
                    }
                    return (stop, label)
                }.sorted { $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending }
                if let maximum = options.maximumRanksPerInstrument, labelledStops.count > maximum {
                    let grouped = Dictionary(grouping: labelledStops, by: { $0.1.family })
                    var selected: [(GrandOrgueStopSummary, TimbreLabelAssignment)] = []
                    var offset = 0
                    let families: [PipeTimbreFamily] = [.flute, .diapason, .string, .reed]
                    while selected.count < maximum {
                        var appended = false
                        for family in families where selected.count < maximum {
                            if let value = grouped[family], value.indices.contains(offset) {
                                selected.append(value[offset])
                                appended = true
                            }
                        }
                        if !appended { break }
                        offset += 1
                    }
                    labelledStops = selected
                }
                for (rankIndex, item) in labelledStops.enumerated() {
                    let (stop, label) = item
                    let allSamples = inspection.samples.filter {
                        $0.stopID == stop.id
                            && $0.sourceRelativePath != nil
                            && ($0.sampleRole == nil || $0.sampleRole == "attack-sustain")
                    }.sorted { $0.midiNote < $1.midiNote }
                    let selected = stratified(allSamples, maximum: options.maximumPipesPerRank)
                    progress?("\(record.entityID) · \(stop.name): \(selected.count) stratified pipes (rank \(rankIndex + 1)/\(labelledStops.count))…")
                    var observations: [PipeTimbreObservation] = []
                    for sample in selected {
                        guard let relativePath = sample.sourceRelativePath else { continue }
                        let file = root.appendingPathComponent(relativePath)
                        do {
                            let analysisFile = try materializedAudio(source: file, processingRoot: processingRoot)
                            guard let harmonicRatio = sample.harmonicNumber.flatMap({ $0 > 0 ? $0 / 8 : nil })
                                ?? OrganFootage.nominalRatio(footHeight: sample.footHeight) else {
                                rankExclusions.append(RetrievedCorpusExclusion(
                                    entityID: record.entityID,
                                    scope: "sample:\(sample.id)",
                                    reason: "The documented footage was invalid or compound, so no single expected-frequency prior was inferred."
                                ))
                                continue
                            }
                            let tuningRatio = pow(2, (sample.pitchTuningCents ?? 0) / 1_200)
                            let expected = midiFrequency(sample.midiNote) * harmonicRatio * tuningRatio
                            let pitchEvidence = try await pitchEstimate(fileURL: analysisFile, expectedFrequency: expected, referenceChannel: options.referenceChannel)
                            guard let pitch = pitchEvidence.estimate,
                                  pitch.confidence >= 0.30,
                                  pitchEvidence.comparison.severity != .critical else {
                                rankExclusions.append(RetrievedCorpusExclusion(entityID: record.entityID, scope: "sample:\(sample.id)", reason: "No reliable fundamental estimate or a critical estimator disagreement prevented harmonic feature extraction."))
                                continue
                            }
                            let digest = try sha256(of: file)
                            let observation = try await timbre.analyze(
                                input: TimbreAnalysisInput(
                                    fileURL: analysisFile,
                                    takeID: Self.stableUUID("\(record.entityID)|\(sample.id)|take"),
                                    roadmapItemID: Self.stableUUID("\(record.entityID)|\(sample.id)|roadmap"),
                                    midiNote: sample.midiNote,
                                    noteName: Self.noteName(sample.midiNote),
                                    expectedFrequencyHz: expected,
                                    measuredFrequencyHz: pitch.frequencyHz,
                                    measuredConfidence: pitch.confidence,
                                    sourceAudioSHA256: digest,
                                    sourceAnalysisRunID: nil,
                                    referenceChannel: options.referenceChannel,
                                    sustainStartSeconds: nil,
                                    soundOffsetSeconds: nil,
                                    keyUpSeconds: nil
                                ),
                                mode: .characterization
                            )
                            if observation.normalizedSpectralCentroid != nil,
                               observation.weightedAverageSlopeDBPerOctave != nil { observations.append(observation) }
                        } catch {
                            rankExclusions.append(RetrievedCorpusExclusion(entityID: record.entityID, scope: "sample:\(sample.id)", reason: error.localizedDescription))
                        }
                    }
                    if observations.count >= options.minimumPipesPerRank {
                        rankRecords.append(EmpiricalTimbreRankRecord(
                            instrumentID: record.entityID,
                            instrumentName: record.instrumentName,
                            rankID: "\(record.entityID)|\(stop.id)",
                            rankLabel: stop.name,
                            division: stop.division,
                            footage: stop.footHeight,
                            labelAssignment: label,
                            observations: observations,
                            sourceDefinitionSHA256: inspection.odfSHA256
                        ))
                    } else {
                        rankExclusions.append(RetrievedCorpusExclusion(entityID: record.entityID, scope: "rank:\(stop.id)", reason: "Only \(observations.count) usable pipe observations remained; at least \(options.minimumPipesPerRank) are required."))
                    }
                }
                corpus.ranks.append(contentsOf: rankRecords)
                corpus.exclusions.append(contentsOf: rankExclusions)
                corpus.instruments.append(RetrievedCorpusInstrumentSummary(
                    entityID: record.entityID,
                    instrumentName: record.instrumentName,
                    producer: record.producer,
                    recordingBasis: catalog[record.entityID]?.recordingBasis ?? "unknown",
                    licenseClass: record.licenseClass,
                    sourceURL: record.sourceURL,
                    sourceDefinitionPath: source.standardizedFileURL.path,
                    sourceDefinitionSHA256: inspection.odfSHA256,
                    includedRankCount: rankRecords.count,
                    includedPipeCount: rankRecords.reduce(0) { $0 + $1.observations.count }
                ))
                corpus.generatedAt = .now
                try checkpoint(corpus, at: checkpointURL)
                progress?("Checkpointed \(record.entityID): \(rankRecords.count) ranks, \(rankRecords.reduce(0) { $0 + $1.observations.count }) pipe observations.")
            } catch {
                corpus.exclusions.append(RetrievedCorpusExclusion(entityID: record.entityID, scope: "instrument", reason: error.localizedDescription))
                corpus.generatedAt = .now
                try checkpoint(corpus, at: checkpointURL)
                progress?("Excluded \(record.entityID): \(error.localizedDescription)")
            }
            if let temporaryRoot { try? FileManager.default.removeItem(at: temporaryRoot) }
            try? FileManager.default.removeItem(at: processingRoot)
        }
        corpus.instruments.sort { $0.entityID < $1.entityID }
        corpus.ranks.sort { ($0.instrumentID, $0.rankID) < ($1.instrumentID, $1.rankID) }
        corpus.exclusions = Array(Set(corpus.exclusions.map { "\($0.entityID)|\($0.scope)|\($0.reason)" })).sorted().map { value in
            let fields = value.split(separator: "|", maxSplits: 2).map(String.init)
            return RetrievedCorpusExclusion(entityID: fields[0], scope: fields[1], reason: fields[2])
        }
        corpus.warnings = Array(Set(corpus.warnings)).sorted()
        try checkpoint(corpus, at: checkpointURL)
        return corpus
    }

    private func pitchEstimate(fileURL: URL, expectedFrequency: Double, referenceChannel: Int) async throws -> PitchEstimatorResolution {
        let signal = try Self.readPitchRegion(fileURL: fileURL, referenceChannel: referenceChannel)
        async let crepeEstimate = crepe.estimate(samples: signal.samples, sampleRate: signal.sampleRate, expectedFrequency: expectedFrequency)
        async let pyinEstimate = pyin.estimate(samples: signal.samples, sampleRate: signal.sampleRate, expectedFrequency: expectedFrequency)
        async let fallbackEstimate = autocorrelation.estimate(samples: signal.samples, sampleRate: signal.sampleRate, expectedFrequency: expectedFrequency)
        return try await PitchEstimatorComparisonEngine.resolve(
            crepe: crepeEstimate,
            pyin: pyinEstimate,
            fallback: fallbackEstimate,
            expectedFrequency: expectedFrequency
        )
    }

    private func materializedAudio(source: URL, processingRoot: URL) throws -> URL {
        if (try? AVAudioFile(forReading: source)) != nil { return source }
        let prefix = try sha256(of: source).prefix(20)
        let output = processingRoot.appendingPathComponent("\(prefix).wav")
        if FileManager.default.fileExists(atPath: output.path) { return output }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-i", source.path, "-map", "0:a:0", "-c:a", "pcm_s24le", output.path]
        let diagnostics = Pipe()
        process.standardOutput = diagnostics
        process.standardError = diagnostics
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0, (try? AVAudioFile(forReading: output)) != nil else {
            let detail = String(data: diagnostics.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown decoder error"
            throw OrgRecError.unsupportedAudio("AVFoundation could not decode \(source.lastPathComponent), and the FFmpeg codec adapter failed: \(detail)")
        }
        return output
    }

    private static func readPitchRegion(fileURL: URL, referenceChannel: Int) throws -> (samples: [Float], sampleRate: Double) {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        guard format.channelCount > 0, format.sampleRate > 0, file.length > 2_048 else {
            throw OrgRecError.unsupportedAudio("The source audio is empty or has no readable channel.")
        }
        let durationFrames = min(AVAudioFramePosition(format.sampleRate * 4), file.length)
        let preferredStart = AVAudioFramePosition(Double(file.length) * 0.25)
        let start = min(max(0, file.length - durationFrames), preferredStart)
        file.framePosition = start
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(durationFrames)) else {
            throw OrgRecError.unsupportedAudio("Could not allocate the corpus pitch-analysis buffer.")
        }
        try file.read(into: buffer, frameCount: AVAudioFrameCount(durationFrames))
        let channel = min(Int(format.channelCount) - 1, max(0, referenceChannel))
        guard let data = buffer.floatChannelData?[channel] else {
            throw OrgRecError.unsupportedAudio("The selected corpus reference channel is not floating-point readable.")
        }
        return (Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength))), format.sampleRate)
    }

    private static func inventoryRecords(url: URL) throws -> [InventoryRecord] {
        try CSVTable(url: url).rows.compactMap { row in
            guard let entityID = row["entity_id"], !entityID.isEmpty else { return nil }
            return InventoryRecord(
                entityID: entityID,
                instrumentName: row["sampled_instrument_name"] ?? row["entity_name"] ?? entityID,
                producer: row["producer"] ?? "unknown",
                licenseClass: row["license_class"] ?? "unknown",
                sourceURL: row["source_url"] ?? "",
                volume: row["volume"] ?? "",
                path: row["path"] ?? "",
                pathExists: row["path_exists"]?.lowercased() == "yes",
                representative: row["counted_distinct_representative"]?.lowercased() == "yes",
                nativePlatform: row["native_platform"] ?? ""
            )
        }
    }

    private static func catalogRecords(url: URL) throws -> [CatalogRecord] {
        var result: [String: CatalogRecord] = [:]
        for row in try CSVTable(url: url).rows {
            guard let entityID = row["entity_id"], !entityID.isEmpty else { continue }
            let record = CatalogRecord(
                entityID: entityID,
                recordingBasis: row["recording_basis"] ?? "unknown",
                entityGranularity: row["entity_granularity"] ?? "unknown"
            )
            if result[entityID] == nil || record.entityGranularity == "dataset_or_product" { result[entityID] = record }
        }
        return Array(result.values)
    }

    private func rightsAllowed(_ license: String, policy: RetrievedCorpusRightsPolicy) -> Bool {
        let value = license.lowercased()
        switch policy {
        case .explicitCreativeCommons:
            return value.contains("open license") && (value.contains("creative commons") || value.contains("cc by"))
        case .creativeCommonsAndProjectGPL:
            return (value.contains("open license") && (value.contains("creative commons") || value.contains("cc by"))) || value.contains("gnu gpl")
        case .localResearchIncludingUnreviewed:
            return true
        }
    }

    private func resolveSource(record: InventoryRecord) throws -> URL {
        let recorded = URL(fileURLWithPath: record.path)
        if !record.path.isEmpty, FileManager.default.fileExists(atPath: recorded.path) {
            if ["orgue", "organ"].contains(recorded.pathExtension.lowercased()) { return recorded }
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: recorded.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let nativePackages = try findFiles(withExtension: "orgue", below: recorded)
                if let package = selectCanonicalPackage(nativePackages, instrumentName: record.instrumentName),
                   canonicalScore(package, instrumentName: record.instrumentName) > 0 {
                    return package
                }
                return recorded
            }
        }
        throw OrgRecError.invalidProject(
            "The inventory path for \(record.entityID) is absent. Remap the inventory to the mounted dataset before building the corpus."
        )
    }

    private func extractNativePackage(_ source: URL) throws -> URL {
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-corpus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", source.path, target.path]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown extraction failure"
            try? FileManager.default.removeItem(at: target)
            throw OrgRecError.invalidProject("Could not inspect native package \(source.lastPathComponent): \(detail)")
        }
        return target
    }

    private func findFiles(withExtension pathExtension: String, below root: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            return root.pathExtension.lowercased() == pathExtension ? [root] : []
        }
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == pathExtension && !url.lastPathComponent.hasPrefix("._") {
            result.append(url)
        }
        return result.sorted { $0.path < $1.path }
    }

    private func selectCanonicalPackage(_ values: [URL], instrumentName: String) -> URL? {
        values.max { canonicalScore($0, instrumentName: instrumentName) < canonicalScore($1, instrumentName: instrumentName) }
    }

    private func selectCanonicalDefinition(_ values: [URL], instrumentName: String) -> URL? {
        values.max { canonicalScore($0, instrumentName: instrumentName) < canonicalScore($1, instrumentName: instrumentName) }
    }

    private func canonicalScore(_ url: URL, instrumentName: String) -> Int {
        let path = normalizedWords(url.deletingPathExtension().lastPathComponent)
        let instrumentWords = Set(normalizedWords(instrumentName).split(separator: " ").map(String.init).filter { $0.count >= 4 && !["organ", "church", "orgue"].contains($0) })
        let pathWords = Set(path.split(separator: " ").map(String.init))
        var score = instrumentWords.intersection(pathWords).count * 20
        score += instrumentWords.filter { word in pathWords.contains(where: { $0.contains(word) || word.contains($0) }) }.count * 12
        if path.contains("original") || path.contains("orig") { score += 4 }
        if path.contains("english") || path.contains(" eng") { score += 2 }
        if path.contains("large") || path.contains("full") { score += 2 }
        for penalty in ["tablet", "tablette", "small", "medium", "patch", "extension", " ext", "demo"] where path.contains(penalty) { score -= 5 }
        return score
    }

    private func normalizedWords(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func stratified<T>(_ values: [T], maximum: Int) -> [T] {
        guard maximum > 0 else { return [] }
        guard values.count > maximum else { return values }
        if maximum == 1 { return [values[values.count / 2]] }
        let indices = (0..<maximum).map { index in
            Int((Double(index) * Double(values.count - 1) / Double(maximum - 1)).rounded())
        }
        return Array(Set(indices)).sorted().map { values[$0] }
    }

    private func checkpoint(_ corpus: RetrievedTimbreCorpus, at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try OrgRecCoding.encoder.encode(corpus).write(to: url, options: .atomic)
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

    private static func noteName(_ midi: Int) -> String {
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        return "\(names[(midi % 12 + 12) % 12])\(midi / 12 - 1)"
    }
}

private struct CSVTable {
    var rows: [[String: String]]

    init(url: URL) throws {
        var text = try String(contentsOf: url, encoding: .utf8)
        if text.first == "\u{feff}" { text.removeFirst() }
        // Swift treats CRLF as one extended grapheme cluster, so normalize it
        // before the character-level RFC 4180 state machine below.
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        let records = Self.parse(text)
        guard let header = records.first else { rows = []; return }
        rows = records.dropFirst().map { values in
            Dictionary(uniqueKeysWithValues: header.enumerated().map { index, key in
                (key, index < values.count ? values[index] : "")
            })
        }
    }

    private static func parse(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var quoted = false
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if quoted {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"": quoted = true
                case ",": record.append(field); field = ""
                case "\n":
                    record.append(field); field = ""
                    if !record.allSatisfy(\.isEmpty) { records.append(record) }
                    record = []
                case "\r": break
                default: field.append(character)
                }
            }
            index = text.index(after: index)
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }
}
