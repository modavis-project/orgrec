import AVFAudio
import Foundation

public enum LegacyFilenameConvention: String, Codable, CaseIterable, Identifiable, Sendable {
    case stopThenMIDI
    case recordStopMIDI
    case midiThenStop
    case stopThenNoteName

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .stopThenMIDI: "Stop, then MIDI note"
        case .recordStopMIDI: "Record ID, stop, then MIDI note"
        case .midiThenStop: "MIDI note, then stop"
        case .stopThenNoteName: "Stop, then note name"
        }
    }

    public var example: String {
        switch self {
        case .stopThenMIDI: "Principal8_060.wav"
        case .recordStopMIDI: "collection42_Principal8_060.wav"
        case .midiThenStop: "060_Principal8.wav"
        case .stopThenNoteName: "Principal8_C4.wav"
        }
    }

    public var filenamePattern: String {
        let extensionPattern = #"\.(?:wav|wave|aif|aiff|caf|flac)$"#
        let variant = #"(?:[ _-]+(?<variant>(?:v|rr|take)[A-Za-z0-9-]*))?"#
        switch self {
        case .stopThenMIDI:
            return #"^(?<stop>.+)[ _-]+(?<midi>[0-9]{1,3})"# + variant + extensionPattern
        case .recordStopMIDI:
            return #"^(?<record>[^ _-]+)[ _-]+(?<stop>.+)[ _-]+(?<midi>[0-9]{1,3})"# + variant + extensionPattern
        case .midiThenStop:
            return #"^(?<midi>[0-9]{1,3})[ _-]+(?<stop>.+?)"# + variant + extensionPattern
        case .stopThenNoteName:
            return #"^(?<stop>.+)[ _-]+(?<note>[A-Ga-g](?:#|b|s)?-?[0-9])"# + variant + extensionPattern
        }
    }
}

public struct LegacyStopMapping: Codable, Hashable, Identifiable, Sendable {
    public var id: String { code }
    public var code: String
    public var label: String
    public var footHeight: String?
    public var soundingSemitoneOffset: Int
    public var interpretationNote: String

    public init(
        code: String,
        label: String,
        footHeight: String? = nil,
        soundingSemitoneOffset: Int = 0,
        interpretationNote: String = ""
    ) {
        self.code = code
        self.label = label
        self.footHeight = footHeight
        self.soundingSemitoneOffset = soundingSemitoneOffset
        self.interpretationNote = interpretationNote
    }
}

public struct LegacyDatasetProfile: Codable, Hashable, Sendable {
    public var profileContract: String
    public var sourceNamespace: String
    public var sourceRecordKey: String?
    public var sourceRecordIdentifier: String
    public var organName: String
    public var venueName: String
    public var divisionName: String
    public var filenamePattern: String
    public var filenameConvention: LegacyFilenameConvention?
    public var midiNoteOffset: Int?
    public var referencePitchHz: Double
    public var referencePitchIsAssumed: Bool
    public var temperament: String
    public var stopMappings: [LegacyStopMapping]
    public var sourceURLs: [String]
    public var rightsStatement: String?
    public var builder: String?
    public var modelingNotes: [String]

    public init(
        profileContract: String = "orgrec.legacy-audio-profile/v1",
        sourceNamespace: String,
        sourceRecordKey: String? = "local_id",
        sourceRecordIdentifier: String,
        organName: String,
        venueName: String,
        divisionName: String = "Manual",
        filenamePattern: String = #"^(?<record>[0-9]+)_(?<stop>[a-zA-Z0-9]+)_(?<midi>[0-9]+)(?:_(?<variant>[0-9]+))?\.wav$"#,
        filenameConvention: LegacyFilenameConvention? = nil,
        midiNoteOffset: Int? = nil,
        referencePitchHz: Double = 440,
        referencePitchIsAssumed: Bool = true,
        temperament: String = "Unknown; 12-TET values are analysis priors only",
        stopMappings: [LegacyStopMapping],
        sourceURLs: [String] = [],
        rightsStatement: String? = nil,
        builder: String? = nil,
        modelingNotes: [String] = []
    ) {
        self.profileContract = profileContract
        self.sourceNamespace = sourceNamespace
        self.sourceRecordKey = sourceRecordKey
        self.sourceRecordIdentifier = sourceRecordIdentifier
        self.organName = organName
        self.venueName = venueName
        self.divisionName = divisionName
        self.filenamePattern = filenamePattern
        self.filenameConvention = filenameConvention
        self.midiNoteOffset = midiNoteOffset
        self.referencePitchHz = referencePitchHz
        self.referencePitchIsAssumed = referencePitchIsAssumed
        self.temperament = temperament
        self.stopMappings = stopMappings
        self.sourceURLs = sourceURLs
        self.rightsStatement = rightsStatement
        self.builder = builder
        self.modelingNotes = modelingNotes
    }

    public static func audioDataset(
        sourceNamespace: String,
        sourceRecordIdentifier: String,
        organName: String,
        venueName: String,
        divisionName: String,
        convention: LegacyFilenameConvention,
        midiNoteOffset: Int = 0,
        stopMappings: [LegacyStopMapping],
        sourceURLs: [String] = [],
        rightsStatement: String? = nil,
        builder: String? = nil
    ) -> LegacyDatasetProfile {
        LegacyDatasetProfile(
            profileContract: "orgrec.audio-dataset-profile/v1",
            sourceNamespace: sourceNamespace,
            sourceRecordKey: nil,
            sourceRecordIdentifier: sourceRecordIdentifier,
            organName: organName,
            venueName: venueName,
            divisionName: divisionName,
            filenamePattern: convention.filenamePattern,
            filenameConvention: convention,
            midiNoteOffset: midiNoteOffset,
            stopMappings: stopMappings,
            sourceURLs: sourceURLs,
            rightsStatement: rightsStatement,
            builder: builder,
            modelingNotes: [
                "Audio semantics were parsed from the reviewed filename convention ‘\(convention.label)’.",
                "Filename-derived component labels and pitch positions remain source-bound interpretations until independently reconciled."
            ]
        )
    }

    public static let positivXR = LegacyDatasetProfile(
        sourceNamespace: "musixplora",
        sourceRecordKey: "mxp_id",
        sourceRecordIdentifier: "4010243",
        organName: "Cuntz Positiv",
        venueName: "Musikinstrumentenmuseum der Universität Leipzig",
        stopMappings: [
            LegacyStopMapping(code: "ged", label: "Gedackt", footHeight: "8′", interpretationNote: "Expanded from filename token ‘ged’; register name and pitch require curatorial confirmation."),
            LegacyStopMapping(code: "princ2", label: "Principal", footHeight: "2′", soundingSemitoneOffset: 24, interpretationNote: "Expanded from filename token ‘princ2’."),
            LegacyStopMapping(code: "princ4", label: "Principal", footHeight: "4′", soundingSemitoneOffset: 12, interpretationNote: "Expanded from filename token ‘princ4’."),
            LegacyStopMapping(code: "qui223", label: "Quint", footHeight: "2 2/3′", soundingSemitoneOffset: 19, interpretationNote: "Expanded from filename token ‘qui223’."),
            LegacyStopMapping(code: "reg8", label: "Regal", footHeight: "8′", interpretationNote: "Expanded from filename token ‘reg8’."),
        ],
        sourceURLs: [
            "https://www.uni-leipzig.de/universitaet/service/medien-und-kommunikation/adventskalender/21-dezember",
            "https://mimo-international.com/MIMO/MIMO/doc/IFD/OAI_ULEI_M0000257/positiv",
        ],
        modelingNotes: [
            "4010243 is a source-system record identifier, not a MODAVIS canonical MDVS identifier.",
            "The dataset documents 45 keys per stop with a short/broken bass octave; absent chromatic bass keys must not be synthesized.",
            "Acquisition date, operator, microphones, placement, venue conditions, rights, reference pitch, and temperament are not encoded by the filenames.",
        ]
    )
}

public struct LegacyAudioFileRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: String { filename }
    public var filename: String
    public var sourceRecordIdentifier: String
    public var stopCode: String
    public var midiNote: Int
    public var sourcePitchToken: String?
    public var variant: String?
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int64
    public var durationSeconds: Double
    public var fileSize: Int64
    public var formatDescription: String
    public var containerDescription: String?
    public var encodingDescription: String?
    public var bitDepth: Int?
    public var sha256: String?

    public init(
        filename: String,
        sourceRecordIdentifier: String,
        stopCode: String,
        midiNote: Int,
        sourcePitchToken: String? = nil,
        variant: String?,
        sampleRate: Double,
        channelCount: Int,
        frameCount: Int64,
        durationSeconds: Double,
        fileSize: Int64,
        formatDescription: String,
        containerDescription: String? = nil,
        encodingDescription: String? = nil,
        bitDepth: Int? = nil,
        sha256: String? = nil
    ) {
        self.filename = filename
        self.sourceRecordIdentifier = sourceRecordIdentifier
        self.stopCode = stopCode
        self.midiNote = midiNote
        self.sourcePitchToken = sourcePitchToken
        self.variant = variant
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.durationSeconds = durationSeconds
        self.fileSize = fileSize
        self.formatDescription = formatDescription
        self.containerDescription = containerDescription
        self.encodingDescription = encodingDescription
        self.bitDepth = bitDepth
        self.sha256 = sha256
    }
}

public struct LegacyDatasetInspection: Codable, Hashable, Sendable {
    public var inspectionContract: String
    public var sourceDirectory: String
    public var profile: LegacyDatasetProfile
    public var files: [LegacyAudioFileRecord]
    public var ignoredEntries: [String]
    public var warnings: [String]

    public init(
        inspectionContract: String = "orgrec.legacy-audio-inspection/v1",
        sourceDirectory: String,
        profile: LegacyDatasetProfile,
        files: [LegacyAudioFileRecord],
        ignoredEntries: [String],
        warnings: [String]
    ) {
        self.inspectionContract = inspectionContract
        self.sourceDirectory = sourceDirectory
        self.profile = profile
        self.files = files
        self.ignoredEntries = ignoredEntries
        self.warnings = warnings
    }

    public var stopCodes: [String] { Array(Set(files.map(\.stopCode))).sorted() }
    public var totalBytes: Int64 { files.reduce(0) { $0 + $1.fileSize } }
    public var sourceRecordIdentifiers: [String] { Array(Set(files.map(\.sourceRecordIdentifier))).sorted() }
}

public struct LegacyDatasetImportManifest: Codable, Hashable, Sendable {
    public var contract: String
    public var importedAt: Date
    public var sourceDirectoryName: String
    public var sourceDirectoryPathAtImport: String
    public var sourceMutationPolicy: String
    public var profile: LegacyDatasetProfile
    public var files: [LegacyAudioFileRecord]
    public var ignoredEntries: [String]
    public var warnings: [String]

    public init(
        contract: String = "orgrec.legacy-audio-import-manifest/v1",
        importedAt: Date = .now,
        sourceDirectoryName: String,
        sourceDirectoryPathAtImport: String,
        sourceMutationPolicy: String = "Source files were read-only inputs. OrgRec copied and checksum-verified originals without modifying the source dataset.",
        profile: LegacyDatasetProfile,
        files: [LegacyAudioFileRecord],
        ignoredEntries: [String],
        warnings: [String]
    ) {
        self.contract = contract
        self.importedAt = importedAt
        self.sourceDirectoryName = sourceDirectoryName
        self.sourceDirectoryPathAtImport = sourceDirectoryPathAtImport
        self.sourceMutationPolicy = sourceMutationPolicy
        self.profile = profile
        self.files = files
        self.ignoredEntries = ignoredEntries
        self.warnings = warnings
    }
}

public struct LegacyDatasetAnalysisResult: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { takeID }
    public var takeID: UUID
    public var filename: String
    public var stopCode: String
    public var midiNote: Int
    public var expectedFrequencyHz: Double
    public var summary: AnalysisSummary
}

public struct LegacyDatasetAnalysisReport: Codable, Hashable, Sendable {
    public var contract: String
    public var generatedAt: Date
    public var selectionRule: String
    public var results: [LegacyDatasetAnalysisResult]
    public var tuningInference: LegacyDatasetTuningInference?
    public var findings: [String]

    public init(
        contract: String = "orgrec.legacy-dataset-analysis/v1",
        generatedAt: Date = .now,
        selectionRule: String,
        results: [LegacyDatasetAnalysisResult],
        tuningInference: LegacyDatasetTuningInference? = nil,
        findings: [String] = []
    ) {
        self.contract = contract
        self.generatedAt = generatedAt
        self.selectionRule = selectionRule
        self.results = results
        self.tuningInference = tuningInference
        self.findings = findings
    }
}

public struct LegacyDatasetTuningInference: Codable, Hashable, Sendable {
    public var status: String
    public var assumedReferencePitchHz: Double
    public var reliableSampleCount: Int
    public var medianCentsFromAssumption: Double
    public var estimatedReferencePitchHz: Double
    public var rule: String

    public init(
        status: String = "analysis-inference-not-source-metadata",
        assumedReferencePitchHz: Double,
        reliableSampleCount: Int,
        medianCentsFromAssumption: Double,
        estimatedReferencePitchHz: Double,
        rule: String
    ) {
        self.status = status
        self.assumedReferencePitchHz = assumedReferencePitchHz
        self.reliableSampleCount = reliableSampleCount
        self.medianCentsFromAssumption = medianCentsFromAssumption
        self.estimatedReferencePitchHz = estimatedReferencePitchHz
        self.rule = rule
    }
}

public actor LegacyAudioDatasetImporter {
    public static let manifestRelativePath = "Manifests/legacy-source-dataset.json"
    public static let analysisReportRelativePath = "Analysis/legacy-analysis-report.json"

    public init() {}

    public func inspect(directory: URL, profile: LegacyDatasetProfile = .positivXR) throws -> LegacyDatasetInspection {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw OrgRecError.invalidProject("Legacy dataset directory does not exist: \(directory.path)")
        }
        let regex = try NSRegularExpression(pattern: profile.filenamePattern, options: [.caseInsensitive])
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ).sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        var files: [LegacyAudioFileRecord] = []
        var ignored: [String] = []
        var warnings: [String] = []

        for url in entries {
            let name = url.lastPathComponent
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            guard let match = regex.firstMatch(in: name, range: range),
                  let stop = Self.capture("stop", match: match, in: name, pattern: profile.filenamePattern) else {
                ignored.append(name)
                continue
            }
            let record = Self.capture("record", match: match, in: name, pattern: profile.filenamePattern)
                .flatMap { $0.isEmpty ? nil : $0 }
                ?? profile.sourceRecordIdentifier
            if profile.sourceRecordKey != nil, record != profile.sourceRecordIdentifier {
                warnings.append("\(name): source record \(record) differs from profile record \(profile.sourceRecordIdentifier).")
                continue
            }
            let pitchToken = Self.capture("midi", match: match, in: name, pattern: profile.filenamePattern)
                ?? Self.capture("note", match: match, in: name, pattern: profile.filenamePattern)
            guard let pitchToken else {
                warnings.append("\(name): the filename matched, but no pitch token could be read.")
                continue
            }
            let parsedMIDI = Int(pitchToken) ?? Self.midiNote(from: pitchToken)
            guard let parsedMIDI else {
                warnings.append("\(name): ‘\(pitchToken)’ is not a recognized MIDI number or scientific note name.")
                continue
            }
            let midi = parsedMIDI + (profile.midiNoteOffset ?? 0)
            guard (0...127).contains(midi) else {
                warnings.append("\(name): interpreted MIDI note \(midi) falls outside 0…127; review the pitch-number offset.")
                continue
            }
            let properties = try Self.audioProperties(for: url)
            let size = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            files.append(LegacyAudioFileRecord(
                filename: name,
                sourceRecordIdentifier: record,
                stopCode: stop,
                midiNote: midi,
                sourcePitchToken: pitchToken,
                variant: Self.capture("variant", match: match, in: name, pattern: profile.filenamePattern),
                sampleRate: properties.sampleRate,
                channelCount: properties.channelCount,
                frameCount: properties.frameCount,
                durationSeconds: properties.sampleRate > 0 ? Double(properties.frameCount) / properties.sampleRate : 0,
                fileSize: size,
                formatDescription: properties.description,
                containerDescription: properties.container,
                encodingDescription: properties.encoding,
                bitDepth: properties.bitDepth
            ))
        }

        guard files.isEmpty == false else {
            throw OrgRecError.invalidProject("No audio files matched the legacy filename profile.")
        }
        let mappedCodes = Set(profile.stopMappings.map(\.code))
        let observedCodes = Set(files.map(\.stopCode))
        for code in observedCodes.subtracting(mappedCodes).sorted() {
            warnings.append("Stop token ‘\(code)’ has no semantic mapping and cannot be imported.")
        }
        let formats = Set(files.map { "\($0.sampleRate)/\($0.channelCount)/\($0.formatDescription)" })
        if formats.count > 1 { warnings.append("Audio format is not uniform across the dataset.") }
        for code in observedCodes.sorted() {
            let records = files.filter { $0.stopCode == code }
            let identities = records.map { "\($0.midiNote)|\($0.variant ?? "")" }
            if Set(identities).count != identities.count {
                warnings.append("Stop ‘\(code)’ contains duplicate MIDI-and-variant identifiers.")
            }
            for (midi, variants) in Dictionary(grouping: records, by: \.midiNote) where variants.count > 1 {
                let labels = variants.compactMap(\.variant)
                if labels.count != variants.count || Set(labels).count != variants.count {
                    warnings.append("Stop ‘\(code)’ repeats MIDI \(midi) without a unique variant token for every file.")
                }
            }
        }
        return LegacyDatasetInspection(
            sourceDirectory: directory.standardizedFileURL.path,
            profile: profile,
            files: files,
            ignoredEntries: ignored,
            warnings: warnings
        )
    }

    public func importDataset(
        from sourceDirectory: URL,
        to destination: URL,
        profile: LegacyDatasetProfile = .positivXR
    ) async throws -> OrgRecProject {
        guard FileManager.default.fileExists(atPath: destination.path) == false else {
            throw OrgRecError.invalidProject("Import destination already exists: \(destination.path)")
        }
        var inspection = try inspect(directory: sourceDirectory, profile: profile)
        let unmapped = Set(inspection.files.map(\.stopCode)).subtracting(profile.stopMappings.map(\.code))
        guard unmapped.isEmpty else {
            throw OrgRecError.invalidProject("No stop mapping exists for: \(unmapped.sorted().joined(separator: ", ")).")
        }

        for index in inspection.files.indices {
            let source = sourceDirectory.appendingPathComponent(inspection.files[index].filename)
            inspection.files[index].sha256 = try sha256(of: source)
        }
        let manifest = LegacyDatasetImportManifest(
            sourceDirectoryName: sourceDirectory.lastPathComponent,
            sourceDirectoryPathAtImport: sourceDirectory.standardizedFileURL.path,
            profile: profile,
            files: inspection.files,
            ignoredEntries: inspection.ignoredEntries,
            warnings: inspection.warnings
        )
        let manifestData = try OrgRecCoding.encoder.encode(manifest)
        let snapshotHash = manifestData.sha256Hex
        let project = Self.makeProject(inspection: inspection, snapshotHash: snapshotHash)

        do {
            try await ProjectStore().createPackage(at: destination, project: project)
            let manifestURL = destination.appendingPathComponent(Self.manifestRelativePath)
            try manifestData.write(to: manifestURL, options: .atomic)
            for record in inspection.files {
                let source = sourceDirectory.appendingPathComponent(record.filename)
                let target = destination.appendingPathComponent("Audio/Originals/\(record.filename)")
                try FileManager.default.copyItem(at: source, to: target)
                let copiedHash = try sha256(of: target)
                guard copiedHash == record.sha256 else {
                    throw OrgRecError.invalidProject("Checksum mismatch after copying \(record.filename).")
                }
            }
            _ = try await ProjectStore().load(from: destination)
            return project
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    public func analyzeStratifiedSample(
        projectURL: URL,
        positionsPerStop: Int = 3
    ) async throws -> LegacyDatasetAnalysisReport {
        let store = ProjectStore()
        var project = try await store.load(from: projectURL)
        let grouped = Dictionary(grouping: project.takes) { take -> String in
            project.roadmap.first(where: { $0.id == take.roadmapItemID })?.component.sourceDetails?["legacyStopCode"] ?? "unknown"
        }
        var selected: [TakeRecord] = []
        for code in grouped.keys.sorted() {
            let ordered = (grouped[code] ?? []).sorted { lhs, rhs in
                let left = project.roadmap.first(where: { $0.id == lhs.roadmapItemID })?.component.midiNote ?? 0
                let right = project.roadmap.first(where: { $0.id == rhs.roadmapItemID })?.component.midiNote ?? 0
                return left < right
            }
            let indices = Self.stratifiedIndices(count: ordered.count, requested: positionsPerStop)
            selected.append(contentsOf: indices.map { ordered[$0] })
        }
        let analyzer = AudioAnalyzer()
        var results: [LegacyDatasetAnalysisResult] = []
        let configuration = SpectrogramConfiguration(
            fftSize: 8_192,
            hopSize: 1_024,
            maximumTimeBins: 400,
            maximumAnalysisDurationSeconds: 30,
            displayFrequencyBins: 200,
            partialCount: 16
        )
        for take in selected {
            guard let takeIndex = project.takes.firstIndex(where: { $0.id == take.id }),
                  let roadmapIndex = project.roadmap.firstIndex(where: { $0.id == take.roadmapItemID }),
                  let expected = project.roadmap[roadmapIndex].component.expectedFrequencyHz else { continue }
            let component = project.roadmap[roadmapIndex].component
            let url = projectURL.appendingPathComponent(take.relativeAudioPath)
            let output = try await analyzer.analyze(
                fileURL: url,
                expectedFrequency: expected,
                referenceChannel: take.analysisReferenceChannel ?? 0,
                spectrogramConfiguration: configuration
            )
            var summary = output.0
            if summary.qualityFlags.contains("Legacy import: recording context requires review") == false {
                summary.qualityFlags.append("Legacy import: recording context requires review")
            }
            project.takes[takeIndex].analysis = summary
            project.takes[takeIndex].spectrogramConfiguration = output.2.configuration
            project.takes[takeIndex].partialTracks = output.2.partialTracks
            project.takes[takeIndex].pitchTrack = output.2.pitchTrack
            if var run = output.2.analysisRun {
                run.outputSummary = summary
                run.warnings = summary.qualityFlags
                var history = project.takes[takeIndex].analysisRuns ?? []
                history.append(run)
                project.takes[takeIndex].analysisRuns = history
            }
            project.takes[takeIndex].status = .needsReview
            project.roadmap[roadmapIndex].state = .needsReview
            results.append(LegacyDatasetAnalysisResult(
                takeID: take.id,
                filename: URL(fileURLWithPath: take.relativeAudioPath).lastPathComponent,
                stopCode: component.sourceDetails?["legacyStopCode"] ?? "unknown",
                midiNote: component.midiNote ?? -1,
                expectedFrequencyHz: expected,
                summary: summary
            ))
        }
        project.collectionAnalysis = CollectionAnalysisEngine.analyze(project: project)
        let reliableCents = results.compactMap { result -> Double? in
            guard let confidence = result.summary.confidence,
                  confidence >= 0.65,
                  let cents = result.summary.centsDeviation,
                  abs(cents) < 200 else { return nil }
            return cents
        }.sorted()
        let tuningInference: LegacyDatasetTuningInference?
        if reliableCents.count >= 3 {
            let middle = reliableCents.count / 2
            let medianCents = reliableCents.count.isMultiple(of: 2)
                ? (reliableCents[middle - 1] + reliableCents[middle]) / 2
                : reliableCents[middle]
            tuningInference = LegacyDatasetTuningInference(
                assumedReferencePitchHz: project.organCharacteristics?.referencePitchHz ?? 440,
                reliableSampleCount: reliableCents.count,
                medianCentsFromAssumption: medianCents,
                estimatedReferencePitchHz: (project.organCharacteristics?.referencePitchHz ?? 440) * pow(2, medianCents / 1_200),
                rule: "Median cents deviation of estimates with confidence ≥0.65 and |deviation| <200 cents. Review against a documented tuning source before updating organ metadata."
            )
        } else {
            tuningInference = nil
        }
        let boundaryWarningCount = results.filter {
            $0.summary.onsetSeconds == nil || $0.summary.soundOffsetSeconds == nil
        }.count
        let widebandFallbackCount = results.filter { $0.summary.method == "Normalized autocorrelation fallback" }.count
        let pyinCount = results.filter { $0.summary.pitchEstimatorComparison?.estimates.contains(where: { $0.estimator == "pYIN" }) == true }.count
        let report = LegacyDatasetAnalysisReport(
            selectionRule: "Low, median, and high observed key per stop (or evenly spaced positions when configured otherwise); channel 1; maximum 30 seconds.",
            results: results,
            tuningInference: tuningInference,
            findings: [
                "\(boundaryWarningCount) of \(results.count) analyzed files lack a reliable onset or sound offset inside the captured boundaries; retain boundary warnings.",
                "\(pyinCount) of \(results.count) pitch estimates include probabilistic YIN evidence alongside CREPE where its input range is applicable.",
                "\(widebandFallbackCount) of \(results.count) pitch estimates used the wideband autocorrelation fallback with explicit method provenance.",
                "The tuning estimate is a cross-file analysis inference and does not replace unknown source metadata.",
            ]
        )
        try OrgRecCoding.encoder.encode(report).write(
            to: projectURL.appendingPathComponent(Self.analysisReportRelativePath),
            options: .atomic
        )
        try await store.save(project, at: projectURL)
        return report
    }

    public func refreshImportedProjectMetadata(at projectURL: URL) async throws -> OrgRecProject {
        let manifestURL = projectURL.appendingPathComponent(Self.manifestRelativePath)
        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try OrgRecCoding.decoder.decode(LegacyDatasetImportManifest.self, from: manifestData)
        for record in manifest.files {
            let audio = projectURL.appendingPathComponent("Audio/Originals/\(record.filename)")
            guard FileManager.default.fileExists(atPath: audio.path),
                  try sha256(of: audio) == record.sha256 else {
                throw OrgRecError.invalidProject("Imported original is missing or changed: \(record.filename)")
            }
        }
        let inspection = LegacyDatasetInspection(
            sourceDirectory: manifest.sourceDirectoryPathAtImport,
            profile: manifest.profile,
            files: manifest.files,
            ignoredEntries: manifest.ignoredEntries,
            warnings: manifest.warnings
        )
        let refreshed = Self.makeProject(inspection: inspection, snapshotHash: manifestData.sha256Hex)
        try await ProjectStore().save(refreshed, at: projectURL)
        return refreshed
    }

    private static func makeProject(inspection: LegacyDatasetInspection, snapshotHash: String) -> OrgRecProject {
        let profile = inspection.profile
        let organID = "SOURCE:\(profile.sourceNamespace):\(profile.sourceRecordIdentifier)"
        let sourceRecordID = "sr:\(profile.sourceNamespace):\(profile.sourceRecordKey ?? "local_id"):\(profile.sourceRecordIdentifier)"
        let snapshot = MODAVISSnapshot(
            endpoint: "legacy-audio://\(profile.sourceNamespace)/\(profile.sourceRecordIdentifier)",
            payloadSHA256: snapshotHash
        )
        let recipe = CaptureRecipe(
            name: "Imported isolated-stop recordings",
            version: 1,
            techniques: [.closePair],
            preRollSeconds: 0,
            sustainSeconds: 0,
            releaseSeconds: 0
        )
        let session = RecordingSession(
            sessionCode: "LEGACY-IMPORT-\(profile.sourceRecordIdentifier)",
            startedAt: .now,
            endedAt: .now,
            operatorName: "Unknown",
            institution: "Unknown",
            purpose: "Existing audio dataset ingest",
            rightsStatement: profile.rightsStatement?.nonEmpty ?? "Unknown; resolve before dissemination",
            clockSource: "Not documented in source dataset",
            venueCondition: "Not documented in source dataset",
            notes: "This session describes the import event, not the unknown historical recording session."
        )
        var components: [OrganComponent] = []
        var registrations: [RegistrationState] = []
        var stopComponents: [String: OrganComponent] = [:]
        var registrationByStop: [String: RegistrationState] = [:]

        for mapping in profile.stopMappings where inspection.files.contains(where: { $0.stopCode == mapping.code }) {
            let observedNotes = inspection.files.filter { $0.stopCode == mapping.code }.map(\.midiNote).sorted()
            let id = "\(organID):stop:\(mapping.code)"
            let locator = ComponentLocator(
                id: id,
                organMDVSID: organID,
                sourceRecordID: sourceRecordID,
                sourcePath: "legacyAudio.stop[\(mapping.code)]",
                snapshotSHA256: snapshotHash,
                kind: "stop",
                label: Self.stopDisplayLabel(mapping),
                trust: .sourceBound
            )
            let stop = OrganComponent(
                id: id,
                kind: "stop",
                label: Self.stopDisplayLabel(mapping),
                division: profile.divisionName,
                footHeight: mapping.footHeight,
                locator: locator,
                playableMIDILow: observedNotes.min(),
                playableMIDIHigh: observedNotes.max(),
                sourceDetails: [
                    "legacyStopCode": mapping.code,
                    "semanticStatus": "inferred-from-filename",
                    "interpretationNote": mapping.interpretationNote,
                    "observedMIDIKeys": observedNotes.map(String.init).joined(separator: ","),
                ],
                referencePitchHz: profile.referencePitchHz,
                temperament: profile.temperament
            )
            components.append(stop)
            stopComponents[mapping.code] = stop
            let registration = RegistrationState(
                activatedStops: [locator],
                notes: "Inferred isolated-stop state for legacy filename token ‘\(mapping.code)’; requires curatorial confirmation.",
                name: Self.stopDisplayLabel(mapping),
                purpose: "Legacy isolated-stop recording"
            )
            registrations.append(registration)
            registrationByStop[mapping.code] = registration
        }

        var roadmap: [RoadmapItem] = []
        var takes: [TakeRecord] = []
        for record in inspection.files {
            guard let mapping = profile.stopMappings.first(where: { $0.code == record.stopCode }),
                  let stop = stopComponents[record.stopCode],
                  let registration = registrationByStop[record.stopCode] else { continue }
            let pipeID = "\(stop.id):midi:\(record.midiNote)" + (record.variant.map { ":variant:\($0)" } ?? "")
            let expected = Self.equalTemperamentFrequency(
                midiNote: record.midiNote + mapping.soundingSemitoneOffset,
                referencePitchHz: profile.referencePitchHz
            )
            let sourcePath = "legacyAudio.file[\(record.filename)]"
            let locator = ComponentLocator(
                id: pipeID,
                organMDVSID: organID,
                pipePositionReference: "orgrec.legacy-pipe-position/v1?stop=\(record.stopCode)&midi=\(record.midiNote)",
                sourceRecordID: sourceRecordID,
                sourcePath: sourcePath,
                snapshotSHA256: snapshotHash,
                kind: "pipePosition",
                label: "\(Self.stopDisplayLabel(mapping)) · \(Self.noteName(record.midiNote))",
                trust: .sourceBound
            )
            let component = OrganComponent(
                id: pipeID,
                kind: "pipePosition",
                label: locator.label,
                division: profile.divisionName,
                footHeight: mapping.footHeight,
                noteName: Self.noteName(record.midiNote),
                midiNote: record.midiNote,
                expectedFrequencyHz: expected,
                locator: locator,
                parentComponentID: stop.id,
                sourceDetails: [
                    "legacyStopCode": record.stopCode,
                    "legacyFilename": record.filename,
                    "sourcePitchToken": record.sourcePitchToken ?? String(record.midiNote),
                    "semanticStatus": "source-bound-with-inferred-stop-label",
                    "expectedFrequencyStatus": "analysis-prior-from-assumed-A4-and-stop-footage",
                ],
                referencePitchHz: profile.referencePitchHz,
                temperament: profile.temperament
            )
            components.append(component)
            let roadmapItem = RoadmapItem(
                component: component,
                technique: .closePair,
                recipeID: recipe.id,
                registrationID: registration.id,
                state: .needsReview,
                takeIDs: [],
                coverageKind: .explicitPipe,
                instructions: "Imported from \(record.filename); verify stop interpretation, pitch prior, channel meaning, and provenance."
            )
            let take = TakeRecord(
                roadmapItemID: roadmapItem.id,
                takeNumber: 1,
                status: .needsReview,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                relativeAudioPath: "Audio/Originals/\(record.filename)",
                sampleRate: record.sampleRate,
                channelCount: record.channelCount,
                frameCount: record.frameCount,
                fileSize: record.fileSize,
                sha256: record.sha256,
                captureDiagnostics: CaptureDiagnostics(
                    writerContract: "orgrec.audio-dataset-import/v1",
                    container: record.containerDescription ?? "Source audio container",
                    encoding: record.encodingDescription ?? record.formatDescription,
                    bitDepth: record.bitDepth ?? 0,
                    queuedBufferCapacity: 0,
                    receivedBuffers: 0,
                    writtenBuffers: 0,
                    writtenFrames: record.frameCount,
                    channels: (1...record.channelCount).map {
                        ChannelCaptureStatistics(channelIndex: $0, role: "Legacy channel \($0) (role unknown)")
                    }
                ),
                analysisReferenceChannel: 0,
                notes: "Bit-preserved source audio file. Any unavailable acquisition metadata remains unknown.",
                reviewReason: "Imported metadata and inferred filename semantics require scientific and rights review.",
                provenance: TakeProvenanceSnapshot(
                    session: session,
                    recipe: recipe,
                    microphoneSetup: nil,
                    registration: registration,
                    component: component,
                    releaseBinding: snapshot.release,
                    navigatorPayloadSHA256: snapshotHash,
                    organMDVSID: organID,
                    applicationVersion: "\(OrgRecSoftware.current.displayName); audio-dataset-importer/1"
                )
            )
            var linkedItem = roadmapItem
            linkedItem.takeIDs = [take.id]
            roadmap.append(linkedItem)
            takes.append(take)
        }

        let uniqueNotes = Set(inspection.files.map(\.midiNote))
        let warnings = inspection.warnings + profile.modelingNotes + [
            "Observed key set: \(uniqueNotes.sorted().map(String.init).joined(separator: ", ")).",
            "Stop-name expansions and sounding-pitch offsets are import mappings, not canonical MODAVIS assertions.",
        ]
        let compilation = RoadmapCompilationReport(
            compilerContract: "orgrec.legacy-audio-roadmap-compiler/v1",
            sourceStopCount: stopComponents.count,
            sourceCouplerCount: 0,
            sourceAccessoryCount: 0,
            sourceDivisionCount: 1,
            sourceKeyboardCount: 1,
            sourceRankCount: stopComponents.count,
            explicitPipePositionCount: roadmap.count,
            generatedAtomicSoundCount: roadmap.count,
            generatedControlTestCount: 0,
            theoreticalRegistrationStateCount: String(registrations.count),
            assumedCompassCount: 0,
            warnings: warnings,
            referencePitchHz: profile.referencePitchHz,
            tuningPitchAssumed: profile.referencePitchIsAssumed,
            temperament: profile.temperament
        )
        return OrgRecProject(
            title: "\(profile.organName) · \(URL(fileURLWithPath: inspection.sourceDirectory).lastPathComponent)",
            organMDVSID: organID,
            organName: profile.organName,
            venueName: profile.venueName,
            snapshot: snapshot,
            recipe: recipe,
            registrations: registrations,
            roadmap: roadmap,
            takes: takes,
            spectrogramConfiguration: SpectrogramConfiguration(),
            organComponents: components,
            roadmapCompilation: compilation,
            navigatorPayloadRelativePath: manifestRelativePath,
            organCharacteristics: OrganSpecificationCharacteristics(
                referencePitchHz: profile.referencePitchHz,
                temperament: profile.temperament,
                manualCount: 1,
                documentedStopCount: stopComponents.count,
                divisionCount: 1,
                keyboardCount: 1,
                rankCount: stopComponents.count,
                pipePositionCount: roadmap.count,
                builder: profile.builder?.nonEmpty,
                sourceCount: profile.sourceURLs.count,
                sourceURLs: profile.sourceURLs
            ),
            recordingSessions: [session]
        )
    }

    private static func capture(_ name: String, match: NSTextCheckingResult, in text: String, pattern: String) -> String? {
        guard pattern.contains("?<\(name)>") else { return nil }
        let range = match.range(withName: name)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }

    private static func midiNote(from noteName: String) -> Int? {
        let normalized = noteName
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
        let pattern = #"^([A-Ga-g])([#bs]?)(-?[0-9])$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
              let letterRange = Range(match.range(at: 1), in: normalized),
              let accidentalRange = Range(match.range(at: 2), in: normalized),
              let octaveRange = Range(match.range(at: 3), in: normalized),
              let octave = Int(normalized[octaveRange]) else { return nil }
        let pitchClasses: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard var pitchClass = pitchClasses[Character(String(normalized[letterRange]).uppercased())] else { return nil }
        let accidental = String(normalized[accidentalRange]).lowercased()
        if accidental == "#" || accidental == "s" { pitchClass += 1 }
        if accidental == "b" { pitchClass -= 1 }
        return (octave + 1) * 12 + pitchClass
    }

    private struct AudioProperties {
        var sampleRate: Double
        var channelCount: Int
        var frameCount: Int64
        var description: String
        var container: String
        var encoding: String
        var bitDepth: Int?
    }

    private static func audioProperties(for url: URL) throws -> AudioProperties {
        let fileExtension = url.pathExtension.lowercased()
        if ["wav", "wave"].contains(fileExtension), let properties = try waveProperties(for: url) {
            return properties
        }
        let audio = try AVAudioFile(forReading: url)
        let format = audio.fileFormat
        let technical = technicalFormat(for: format, fileExtension: fileExtension)
        return AudioProperties(
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            frameCount: audio.length,
            description: technical.description,
            container: technical.container,
            encoding: technical.encoding,
            bitDepth: technical.bitDepth
        )
    }

    private static func waveProperties(for url: URL) throws -> AudioProperties? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        guard let header = try handle.read(upToCount: 12), header.count == 12 else { return nil }
        let containerID = ascii(header, 0..<4)
        guard ["RIFF", "RF64", "RIFX"].contains(containerID), ascii(header, 8..<12) == "WAVE" else { return nil }
        let bigEndian = containerID == "RIFX"
        var offset: UInt64 = 12
        var rf64DataSize: UInt64?
        var format: (code: UInt16, channels: UInt16, sampleRate: UInt32, blockAlign: UInt16, bitsPerSample: UInt16)?
        var dataSize: UInt64?

        while offset <= fileSize, fileSize - offset >= 8 {
            try handle.seek(toOffset: offset)
            guard let chunkHeader = try handle.read(upToCount: 8), chunkHeader.count == 8 else { return nil }
            let chunkID = ascii(chunkHeader, 0..<4)
            let size32 = uint32(chunkHeader, at: 4, bigEndian: bigEndian)
            var declaredSize = UInt64(size32)
            let dataOffset = offset + 8

            if chunkID == "ds64", containerID == "RF64" {
                guard declaredSize >= 28, declaredSize <= fileSize - dataOffset else { return nil }
                try handle.seek(toOffset: dataOffset)
                guard let payload = try handle.read(upToCount: 28), payload.count == 28 else { return nil }
                rf64DataSize = uint64(payload, at: 8, bigEndian: false)
            }
            if size32 == UInt32.max {
                guard containerID == "RF64", chunkID == "data", let resolvedSize = rf64DataSize else { return nil }
                declaredSize = resolvedSize
            }
            if chunkID == "fmt " {
                guard declaredSize >= 16, declaredSize <= 65_536, declaredSize <= fileSize - dataOffset else { return nil }
                try handle.seek(toOffset: dataOffset)
                guard let payload = try handle.read(upToCount: Int(declaredSize)), payload.count == Int(declaredSize) else { return nil }
                var code = uint16(payload, at: 0, bigEndian: bigEndian)
                if code == 0xfffe, payload.count >= 40 {
                    code = uint16(payload, at: 24, bigEndian: bigEndian)
                }
                format = (
                    code,
                    uint16(payload, at: 2, bigEndian: bigEndian),
                    uint32(payload, at: 4, bigEndian: bigEndian),
                    uint16(payload, at: 12, bigEndian: bigEndian),
                    uint16(payload, at: 14, bigEndian: bigEndian)
                )
            } else if chunkID == "data" {
                dataSize = declaredSize
            }
            if format != nil, dataSize != nil { break }
            let paddedSize = declaredSize + (declaredSize & 1)
            guard dataOffset <= fileSize, paddedSize <= fileSize - dataOffset else { return nil }
            offset = dataOffset + paddedSize
        }

        guard let format, let dataSize, format.channels > 0, format.sampleRate > 0, format.blockAlign > 0 else { return nil }
        let frameCount = dataSize / UInt64(format.blockAlign)
        guard frameCount <= UInt64(Int64.max) else { return nil }
        let encoding: String
        switch format.code {
        case 1:
            encoding = format.bitsPerSample == 8 ? "Unsigned integer PCM" : "Signed integer PCM"
        case 3:
            encoding = "IEEE 754 \(format.bitsPerSample)-bit floating point"
        default:
            return nil
        }
        let container = containerID == "RIFF" ? "RIFF/WAVE" : "\(containerID)/WAVE"
        return AudioProperties(
            sampleRate: Double(format.sampleRate),
            channelCount: Int(format.channels),
            frameCount: Int64(frameCount),
            description: "\(container) · \(encoding)",
            container: container,
            encoding: encoding,
            bitDepth: Int(format.bitsPerSample)
        )
    }

    private static func ascii(_ data: Data, _ range: Range<Int>) -> String {
        String(decoding: data[range], as: UTF8.self)
    }

    private static func uint16(_ data: Data, at offset: Int, bigEndian: Bool) -> UInt16 {
        let bytes = Array(data[offset..<(offset + 2)])
        return bigEndian
            ? (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            : UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }

    private static func uint32(_ data: Data, at offset: Int, bigEndian: Bool) -> UInt32 {
        let bytes = Array(data[offset..<(offset + 4)])
        if bigEndian {
            return bytes.reduce(0) { ($0 << 8) | UInt32($1) }
        }
        return bytes.enumerated().reduce(0) { $0 | (UInt32($1.element) << UInt32($1.offset * 8)) }
    }

    private static func uint64(_ data: Data, at offset: Int, bigEndian: Bool) -> UInt64 {
        let bytes = Array(data[offset..<(offset + 8)])
        if bigEndian {
            return bytes.reduce(0) { ($0 << 8) | UInt64($1) }
        }
        return bytes.enumerated().reduce(0) { $0 | (UInt64($1.element) << UInt64($1.offset * 8)) }
    }

    private static func technicalFormat(
        for format: AVAudioFormat,
        fileExtension: String
    ) -> (description: String, container: String, encoding: String, bitDepth: Int?) {
        let container: String
        switch fileExtension.lowercased() {
        case "wav", "wave": container = "RIFF/WAVE"
        case "aif", "aiff": container = "AIFF"
        case "caf": container = "Core Audio Format"
        case "flac": container = "FLAC"
        default: container = fileExtension.uppercased()
        }
        let encoding: String
        let bitDepth: Int?
        switch format.commonFormat {
        case .pcmFormatFloat32:
            encoding = "IEEE 754 32-bit floating point"
            bitDepth = 32
        case .pcmFormatFloat64:
            encoding = "IEEE 754 64-bit floating point"
            bitDepth = 64
        case .pcmFormatInt16:
            encoding = "Signed integer PCM"
            bitDepth = 16
        case .pcmFormatInt32:
            encoding = "Signed integer PCM"
            bitDepth = 32
        default:
            encoding = "Audio encoding reported by Core Audio"
            bitDepth = nil
        }
        let interleaving = format.isInterleaved ? "" : " (non-interleaved)"
        return ("\(container) · \(encoding)\(interleaving)", container, encoding, bitDepth)
    }

    private static func stopDisplayLabel(_ mapping: LegacyStopMapping) -> String {
        guard let footHeight = mapping.footHeight, footHeight.isEmpty == false else { return mapping.label }
        return "\(mapping.label) \(footHeight)"
    }

    private static func equalTemperamentFrequency(midiNote: Int, referencePitchHz: Double) -> Double {
        referencePitchHz * pow(2, Double(midiNote - 69) / 12)
    }

    private static func noteName(_ midi: Int) -> String {
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        let normalized = ((midi % 12) + 12) % 12
        return "\(names[normalized])\(midi / 12 - 1)"
    }

    private static func stratifiedIndices(count: Int, requested: Int) -> [Int] {
        guard count > 0, requested > 0 else { return [] }
        if requested == 1 { return [count / 2] }
        if requested >= count { return Array(0..<count) }
        return Array(Set((0..<requested).map { Int((Double($0) * Double(count - 1) / Double(requested - 1)).rounded()) })).sorted()
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
