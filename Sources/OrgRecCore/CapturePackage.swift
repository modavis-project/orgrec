import Foundation

public struct CapturePackageManifest: Codable, Hashable, Sendable {
    public var schemaVersion: String
    public var software: OrgRecSoftwareMetadata?
    public var generatedAt: Date
    public var projectID: UUID
    public var projectTitle: String
    public var releaseBinding: ReleaseBinding
    public var modavisSnapshotSHA256: String
    public var coverage: CoverageSummary
    public var takes: [TakeManifestEntry]
    public var integrity: [String: String]
    public var consistencyReportRelativePath: String?
    public var consistencyScore: Int?
    public var iadManifestRelativePath: String?
    public var iadManifestSHA256: String?

    public init(
        schemaVersion: String = "orgrec-capture-package/2.0",
        software: OrgRecSoftwareMetadata? = OrgRecSoftware.current,
        generatedAt: Date = .now,
        projectID: UUID,
        projectTitle: String,
        releaseBinding: ReleaseBinding,
        modavisSnapshotSHA256: String,
        coverage: CoverageSummary,
        takes: [TakeManifestEntry],
        integrity: [String: String],
        consistencyReportRelativePath: String? = nil,
        consistencyScore: Int? = nil,
        iadManifestRelativePath: String? = nil,
        iadManifestSHA256: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.software = software
        self.generatedAt = generatedAt
        self.projectID = projectID
        self.projectTitle = projectTitle
        self.releaseBinding = releaseBinding
        self.modavisSnapshotSHA256 = modavisSnapshotSHA256
        self.coverage = coverage
        self.takes = takes
        self.integrity = integrity
        self.consistencyReportRelativePath = consistencyReportRelativePath
        self.consistencyScore = consistencyScore
        self.iadManifestRelativePath = iadManifestRelativePath
        self.iadManifestSHA256 = iadManifestSHA256
    }
}

public struct TakeManifestEntry: Codable, Hashable, Sendable {
    public var takeID: UUID
    public var roadmapItemID: UUID
    public var status: TakeStatus
    public var audioRelativePath: String
    public var audioSHA256: String?
    public var analysisRelativePath: String?
    public var annotationRelativePath: String?
    public var derivedRelativePaths: [String]
    public var recordedAt: Date
    public var durationSeconds: Double?
    public var controlEventRelativePath: String?
    public var captureStateFingerprint: String?
    public var interactionSensorRelativePaths: [String]? = nil
}

public struct TakeControlEventPackage: Codable, Hashable, Sendable {
    public var eventLog: ControlEventLog
    public var audioAlignment: AudioControlAlignment?
    public var captureStateSnapshot: CaptureStateSnapshot?
}

public struct TakeAnalysisPackage: Codable, Hashable, Sendable {
    public var analysis: AnalysisSummary
    public var spectrogramConfiguration: SpectrogramConfiguration?
    public var partialTracks: [PartialTrack]?
    public var markerCorrections: [MarkerCorrection]
    public var captureDiagnostics: CaptureDiagnostics?
    public var captureIntegrityFaults: [CaptureFault]?
    public var audioDeviceSnapshot: AudioDeviceSnapshot?
    public var bwfMetadata: BWFMetadata?
    public var analysisReferenceChannel: Int?
    public var provenance: TakeProvenanceSnapshot?
    public var reviewHistory: [ReviewDecision]?
    public var livePitchEvidence: [LivePitchEvidence]?
    public var pitchTrack: [PitchTrackPoint]?
    public var analysisRuns: [AnalysisRunRecord]?
    public var loopPointSets: [LoopPointSet]?
    public var acceptedLoopPointSetID: UUID?
    public var loopPointReviews: [LoopPointReview]?
    public var longTakeSource: LongTakeSliceProvenance?
    public var instrumentNoiseParadata: InstrumentNoiseTakeParadata? = nil
    public var captureStateSnapshot: CaptureStateSnapshot? = nil
    public var complexCaptureProtocol: ComplexCaptureProtocol? = nil
    public var complexCaptureParadata: ComplexCaptureTakeParadata? = nil
    public var spatialGeometrySnapshot: SpatialGeometrySnapshot? = nil
    public var spatialAcousticProtocol: SpatialAcousticCaptureProtocol? = nil
    public var spatialAcousticParadata: SpatialAcousticTakeParadata? = nil
    public var effectAnalysisProtocol: NonPitchedEffectAnalysisProtocol? = nil
    public var effectAnalysis: EffectAnalysisResult? = nil
    public var controlEventLog: ControlEventLog? = nil
    public var audioControlAlignment: AudioControlAlignment? = nil
    public var interactionSensorCaptures: [InteractionSensorCaptureRecord]? = nil
}

public actor CapturePackageBuilder {
    public init() {}

    @discardableResult
    public func build(
        project: OrgRecProject,
        packageURL: URL,
        destinationURL: URL
    ) throws -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationURL.path) {
            throw OrgRecError.exportValidation("Export already exists: \(destinationURL.lastPathComponent)")
        }

        let consistency = ProjectConsistencyAuditor.audit(project: project, packageURL: packageURL)
        guard consistency.isExportReady else {
            let titles = consistency.issues.filter { $0.severity == .blocker }.prefix(3).map(\.title).joined(separator: "; ")
            throw OrgRecError.exportValidation("Resolve \(consistency.blockerCount) consistency blocker(s) before Navigator export: \(titles)")
        }

        try fm.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        let audioDestination = destinationURL.appendingPathComponent("audio", isDirectory: true)
        let analysisDestination = destinationURL.appendingPathComponent("analysis", isDirectory: true)
        let annotationDestination = destinationURL.appendingPathComponent("annotations", isDirectory: true)
        let controlEventDestination = destinationURL.appendingPathComponent("control-events", isDirectory: true)
        let sensorRawDestination = destinationURL.appendingPathComponent("sensors/raw", isDirectory: true)
        let sensorMetadataDestination = destinationURL.appendingPathComponent("sensors/metadata", isDirectory: true)
        let sensorDerivedDestination = destinationURL.appendingPathComponent("sensors/derived", isDirectory: true)
        let manifestsDestination = destinationURL.appendingPathComponent("manifests", isDirectory: true)
        try fm.createDirectory(at: audioDestination, withIntermediateDirectories: true)
        try fm.createDirectory(at: analysisDestination, withIntermediateDirectories: true)
        try fm.createDirectory(at: annotationDestination, withIntermediateDirectories: true)
        try fm.createDirectory(at: controlEventDestination, withIntermediateDirectories: true)
        try fm.createDirectory(at: sensorRawDestination, withIntermediateDirectories: true)
        try fm.createDirectory(at: sensorMetadataDestination, withIntermediateDirectories: true)
        try fm.createDirectory(at: sensorDerivedDestination, withIntermediateDirectories: true)
        try fm.createDirectory(at: manifestsDestination, withIntermediateDirectories: true)

        var integrity: [String: String] = [:]
        var entries: [TakeManifestEntry] = []
        var fileRecords: [IADFileRecord] = []
        var takeRecords: [IADTakeRecord] = []
        var channelRecords: [IADChannelRecord] = []
        var segmentRecords: [IADSegmentRecord] = []
        var observationRecords: [IADObservationRecord] = []
        var paradataRecords: [IADParadataRecord] = []

        guard let defaultSessionID = project.recordingSessions?.first?.id else {
            throw OrgRecError.exportValidation("The IAD package requires at least one recording session.")
        }

        for take in project.takes {
            guard isSafePackageRelativePath(take.relativeAudioPath), take.relativeAudioPath.hasPrefix("Audio/Originals/") else {
                throw OrgRecError.exportValidation("Take \(take.id.uuidString) has an unsafe original-audio path.")
            }
            var derivedPaths: [String] = []
            let audioSource = packageURL.appendingPathComponent(take.relativeAudioPath)
            let audioName = "\(take.id.uuidString.lowercased()).wav"
            let audioTarget = audioDestination.appendingPathComponent(audioName)
            if fm.fileExists(atPath: audioSource.path) {
                try fm.copyItem(at: audioSource, to: audioTarget)
                integrity["audio/\(audioName)"] = try sha256(of: audioTarget)
            }
            guard let audioHash = integrity["audio/\(audioName)"] else {
                throw OrgRecError.exportValidation("Original audio is missing for take \(take.id.uuidString).")
            }
            for set in take.loopPointSets ?? [] {
                let errors = LoopPointSetValidator.errors(for: set)
                if !errors.isEmpty {
                    throw OrgRecError.exportValidation("Loop point set \(set.id.uuidString.lowercased()) is invalid: \(errors.joined(separator: " "))")
                }
                if set.sourceAudioSHA256 != audioHash {
                    throw OrgRecError.exportValidation("Loop point set \(set.id.uuidString.lowercased()) does not match the exported audio SHA-256.")
                }
            }
            let bwfSource = audioSource.deletingPathExtension().appendingPathExtension("bwf.json")
            if fm.fileExists(atPath: bwfSource.path) {
                let bwfName = "\(take.id.uuidString.lowercased()).bwf.json"
                let bwfTarget = audioDestination.appendingPathComponent(bwfName)
                try fm.copyItem(at: bwfSource, to: bwfTarget)
                let relative = "audio/\(bwfName)"
                integrity[relative] = try sha256(of: bwfTarget)
                derivedPaths.append(relative)
            }

            var analysisPath: String?
            if let analysis = take.analysis {
                let name = "\(take.id.uuidString.lowercased()).json"
                let url = analysisDestination.appendingPathComponent(name)
                let package = TakeAnalysisPackage(
                    analysis: analysis,
                    spectrogramConfiguration: take.spectrogramConfiguration,
                    partialTracks: take.partialTracks,
                    markerCorrections: take.markerCorrections ?? [],
                    captureDiagnostics: take.captureDiagnostics,
                    captureIntegrityFaults: take.captureIntegrityFaults,
                    audioDeviceSnapshot: take.audioDeviceSnapshot,
                    bwfMetadata: take.bwfMetadata,
                    analysisReferenceChannel: take.analysisReferenceChannel,
                    provenance: take.provenance,
                    reviewHistory: take.reviewHistory,
                    livePitchEvidence: take.livePitchEvidence,
                    pitchTrack: take.pitchTrack,
                    analysisRuns: take.analysisRuns,
                    loopPointSets: take.loopPointSets,
                    acceptedLoopPointSetID: take.acceptedLoopPointSetID,
                    loopPointReviews: take.loopPointReviews,
                    longTakeSource: take.longTakeSource,
                    instrumentNoiseParadata: take.instrumentNoiseParadata,
                    captureStateSnapshot: take.captureStateSnapshot,
                    complexCaptureProtocol: take.provenance?.complexCaptureProtocol
                        ?? take.complexCaptureParadata?.protocolSnapshot
                        ?? project.roadmap.first(where: { $0.id == take.roadmapItemID })?.complexCaptureProtocol,
                    complexCaptureParadata: take.complexCaptureParadata,
                    spatialGeometrySnapshot: take.provenance?.spatialGeometrySnapshot,
                    spatialAcousticProtocol: take.provenance?.spatialAcousticProtocol
                        ?? take.spatialAcousticParadata?.protocolSnapshot
                        ?? project.roadmap.first(where: { $0.id == take.roadmapItemID })?.spatialAcousticProtocol,
                    spatialAcousticParadata: take.spatialAcousticParadata,
                    effectAnalysisProtocol: take.provenance?.effectAnalysisProtocol,
                    effectAnalysis: take.effectAnalysis,
                    controlEventLog: take.controlEventLog,
                    audioControlAlignment: take.audioControlAlignment,
                    interactionSensorCaptures: take.interactionSensorCaptures
                )
                let data = try OrgRecCoding.encoder.encode(package)
                try data.write(to: url, options: .atomic)
                analysisPath = "analysis/\(name)"
                integrity[analysisPath!] = data.sha256Hex
            }

            var controlEventPath: String?
            if let eventLog = take.controlEventLog {
                let name = "\(take.id.uuidString.lowercased()).json"
                let url = controlEventDestination.appendingPathComponent(name)
                let payload = TakeControlEventPackage(
                    eventLog: eventLog,
                    audioAlignment: take.audioControlAlignment,
                    captureStateSnapshot: take.captureStateSnapshot
                )
                let data = try OrgRecCoding.encoder.encode(payload)
                try data.write(to: url, options: .atomic)
                controlEventPath = "control-events/\(name)"
                integrity[controlEventPath!] = data.sha256Hex
                derivedPaths.append(controlEventPath!)
            }

            var interactionSensorPaths: [String] = []
            for sensorCapture in take.interactionSensorCaptures ?? [] {
                guard isSafePackageRelativePath(sensorCapture.rawRelativePath),
                      sensorCapture.rawRelativePath.hasPrefix("Sensors/Raw/") else {
                    throw OrgRecError.exportValidation("Interaction-sensor capture \(sensorCapture.id.uuidString) has an unsafe raw path.")
                }
                let rawSource = packageURL.appendingPathComponent(sensorCapture.rawRelativePath)
                guard fm.fileExists(atPath: rawSource.path) else {
                    throw OrgRecError.exportValidation("Interaction-sensor raw evidence is missing for capture \(sensorCapture.id.uuidString).")
                }
                let actualRawHash = try sha256(of: rawSource)
                guard actualRawHash == sensorCapture.rawSHA256 else {
                    throw OrgRecError.exportValidation("Interaction-sensor raw evidence no longer matches its recorded SHA-256 for capture \(sensorCapture.id.uuidString).")
                }
                let rawRelative = "sensors/raw/\(rawSource.lastPathComponent)"
                let rawTarget = destinationURL.appendingPathComponent(rawRelative)
                try fm.copyItem(at: rawSource, to: rawTarget)
                integrity[rawRelative] = actualRawHash
                interactionSensorPaths.append(rawRelative)
                derivedPaths.append(rawRelative)

                let metadataName = "\(sensorCapture.id.uuidString.lowercased()).json"
                let metadataRelative = "sensors/metadata/\(metadataName)"
                let metadataData = try OrgRecCoding.encoder.encode(sensorCapture)
                try metadataData.write(to: sensorMetadataDestination.appendingPathComponent(metadataName), options: .atomic)
                integrity[metadataRelative] = metadataData.sha256Hex
                interactionSensorPaths.append(metadataRelative)
                derivedPaths.append(metadataRelative)

                if let derivedSourceRelative = sensorCapture.derivedRelativePath {
                    guard isSafePackageRelativePath(derivedSourceRelative), derivedSourceRelative.hasPrefix("Sensors/Derived/") else {
                        throw OrgRecError.exportValidation("Interaction-sensor capture \(sensorCapture.id.uuidString) has an unsafe derived path.")
                    }
                    let derivedSource = packageURL.appendingPathComponent(derivedSourceRelative)
                    if fm.fileExists(atPath: derivedSource.path) {
                        let derivedRelative = "sensors/derived/\(derivedSource.lastPathComponent)"
                        let derivedTarget = destinationURL.appendingPathComponent(derivedRelative)
                        try fm.copyItem(at: derivedSource, to: derivedTarget)
                        integrity[derivedRelative] = try sha256(of: derivedTarget)
                        interactionSensorPaths.append(derivedRelative)
                        derivedPaths.append(derivedRelative)
                    }
                }
            }
            for suffix in ["waveform", "spectrogram"] {
                let source = packageURL.appendingPathComponent("Analysis/Derivatives/\(take.id.uuidString.lowercased())-\(suffix).json")
                guard fm.fileExists(atPath: source.path) else { continue }
                let name = "\(take.id.uuidString.lowercased())-\(suffix).json"
                let target = analysisDestination.appendingPathComponent(name)
                try fm.copyItem(at: source, to: target)
                let relative = "analysis/\(name)"
                integrity[relative] = try sha256(of: target)
                derivedPaths.append(relative)
            }
            for run in take.analysisRuns ?? [] {
                for sourceRelative in run.artifactRelativePaths ?? [] where isSafePackageRelativePath(sourceRelative) {
                    let source = packageURL.appendingPathComponent(sourceRelative)
                    guard fm.fileExists(atPath: source.path) else { continue }
                    let relative = "analysis/runs/\(run.id.uuidString.lowercased())/\(source.lastPathComponent)"
                    let target = destinationURL.appendingPathComponent(relative)
                    try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.copyItem(at: source, to: target)
                    integrity[relative] = try sha256(of: target)
                    derivedPaths.append(relative)
                }
            }

            let annotations = project.annotations.filter { $0.takeID == take.id }
            var annotationPath: String?
            if !annotations.isEmpty {
                let name = "\(take.id.uuidString.lowercased()).json"
                let url = annotationDestination.appendingPathComponent(name)
                let data = try OrgRecCoding.encoder.encode(annotations)
                try data.write(to: url, options: .atomic)
                annotationPath = "annotations/\(name)"
                integrity[annotationPath!] = data.sha256Hex
            }

            entries.append(
                TakeManifestEntry(
                    takeID: take.id,
                    roadmapItemID: take.roadmapItemID,
                    status: take.status,
                    audioRelativePath: "audio/\(audioName)",
                    audioSHA256: integrity["audio/\(audioName)"],
                    analysisRelativePath: analysisPath,
                    annotationRelativePath: annotationPath,
                    derivedRelativePaths: derivedPaths,
                    recordedAt: take.startedAt,
                    durationSeconds: take.endedAt.map { $0.timeIntervalSince(take.startedAt) },
                    controlEventRelativePath: controlEventPath,
                    captureStateFingerprint: take.captureStateSnapshot?.fingerprintSHA256,
                    interactionSensorRelativePaths: interactionSensorPaths.isEmpty ? nil : interactionSensorPaths
                )
            )

            let roadmap = project.roadmap.first { $0.id == take.roadmapItemID }
            guard let roadmap else {
                throw OrgRecError.exportValidation("Take \(take.id.uuidString) has no roadmap record.")
            }
            let setup = roadmap.setupID.flatMap { setupID in project.setups.first { $0.id == setupID } }
            let sessionID = take.provenance?.sessionID ?? defaultSessionID
            let actualSize = Int64((try audioTarget.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            fileRecords.append(IADFileRecord(
                localFileID: take.id,
                targetTables: ["core.entity", "media.asset", "media.bitstream", "media.storage_object", "media.file"],
                projectionStatus: IADContract.projectionMode,
                relativePath: "audio/\(audioName)",
                name: audioName,
                byteSize: actualSize,
                sha256: audioHash,
                mimeType: "audio/wav",
                container: take.captureDiagnostics?.container ?? "WAVE/BWF",
                encoding: take.captureDiagnostics?.encoding ?? "linear PCM little-endian",
                bitDepth: take.captureDiagnostics?.bitDepth ?? 24,
                sampleRate: take.sampleRate,
                channelCount: take.channelCount,
                frameCount: take.frameCount
            ))
            takeRecords.append(IADTakeRecord(
                localTakeID: take.id,
                targetTable: "audio.recording_take",
                projectionStatus: IADContract.projectionMode,
                localSessionID: sessionID,
                localFileID: take.id,
                localMicrophoneSetupID: roadmap.setupID,
                takeNumber: take.takeNumber,
                recordedAt: take.startedAt,
                durationSeconds: take.sampleRate > 0 && take.frameCount > 0
                    ? Double(take.frameCount) / take.sampleRate
                    : take.endedAt.map { $0.timeIntervalSince(take.startedAt) },
                status: take.status,
                performanceInstruction: roadmap.instructions ?? roadmap.component.label,
                roadmapItemID: roadmap.id,
                componentLocator: roadmap.component.locator,
                localRegistrationID: roadmap.registrationID,
                physicalSoundTargetID: roadmap.physicalSoundTargetID,
                equivalentComponentLocators: roadmap.activationRoutes?.map(\.component.locator),
                activationRoutes: roadmap.activationRoutes,
                longTakeSource: take.longTakeSource,
                instrumentNoiseProtocol: roadmap.instrumentNoiseProtocol,
                instrumentNoiseParadata: take.instrumentNoiseParadata,
                soundingTargetDefinition: roadmap.soundingTargetDefinition,
                captureStateSnapshot: take.captureStateSnapshot,
                controlEventLog: take.controlEventLog,
                audioControlAlignment: take.audioControlAlignment,
                complexCaptureProtocol: take.provenance?.complexCaptureProtocol
                    ?? take.complexCaptureParadata?.protocolSnapshot
                    ?? roadmap.complexCaptureProtocol,
                complexCaptureParadata: take.complexCaptureParadata,
                spatialGeometrySnapshot: take.provenance?.spatialGeometrySnapshot,
                spatialAcousticProtocol: take.provenance?.spatialAcousticProtocol
                    ?? take.spatialAcousticParadata?.protocolSnapshot
                    ?? roadmap.spatialAcousticProtocol,
                spatialAcousticParadata: take.spatialAcousticParadata,
                effectAnalysisProtocol: take.provenance?.effectAnalysisProtocol,
                effectAnalysis: take.effectAnalysis
            ))
            let diagnosticsByChannel = Dictionary(
                (take.captureDiagnostics?.channels ?? []).map { ($0.channelIndex, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            for channelNumber in 1...max(1, take.channelCount) {
                let placement = setup?.placements.first { $0.channelNumber == channelNumber }
                let diagnostic = diagnosticsByChannel[channelNumber]
                channelRecords.append(IADChannelRecord(
                    localChannelID: "\(take.id.uuidString.lowercased()):\(channelNumber)",
                    targetTable: "audio.channel",
                    projectionStatus: IADContract.projectionMode,
                    localFileID: take.id,
                    channelNumber: channelNumber,
                    role: placement?.role ?? diagnostic?.role ?? "unspecified",
                    label: placement?.role ?? diagnostic?.role ?? "Channel \(channelNumber)",
                    microphoneLocalID: placement?.microphoneID,
                    gainDB: placement?.gainDB,
                    phantomPower: placement?.phantomPower
                ))
            }
            segmentRecords.append(contentsOf: Self.segments(for: take))
            observationRecords.append(contentsOf: Self.observations(for: take, component: roadmap.component.locator))
            paradataRecords.append(IADParadataRecord(
                localParadataID: "paradata:\(take.id.uuidString.lowercased())",
                targetTable: "paradata.generic",
                projectionStatus: IADContract.projectionMode,
                localTakeID: take.id,
                analysisRelativePath: analysisPath,
                annotationRelativePath: annotationPath,
                bwfRelativePath: derivedPaths.first { $0.hasSuffix(".bwf.json") },
                provenanceContract: take.provenance?.contractVersion,
                analysisMethod: take.analysis?.method,
                algorithmVersion: take.analysis?.algorithmVersion,
                reviewDecisionCount: take.reviewHistory?.count ?? 0,
                captureFaultCount: take.captureDiagnostics?.faults.count ?? 0,
                software: OrgRecSoftware.current,
                controlEventRelativePath: controlEventPath,
                controlEventCount: take.controlEventLog?.events.count,
                alignmentStatus: take.audioControlAlignment?.status,
                captureStateFingerprint: take.captureStateSnapshot?.fingerprintSHA256
            ))
        }

        for source in project.longTakeSources ?? [] {
            guard isSafePackageRelativePath(source.relativeAudioPath), source.relativeAudioPath.hasPrefix("Audio/LongTakes/") else {
                throw OrgRecError.exportValidation("Long take \(source.id.uuidString) has an unsafe source path.")
            }
            let sourceURL = packageURL.appendingPathComponent(source.relativeAudioPath)
            guard fm.fileExists(atPath: sourceURL.path) else {
                throw OrgRecError.exportValidation("Long-take source audio is missing for \(source.id.uuidString).")
            }
            let actualHash = try sha256(of: sourceURL)
            guard actualHash == source.sha256 else {
                throw OrgRecError.exportValidation("Long-take source audio no longer matches its recorded checksum.")
            }
            let sourceExtension = sourceURL.pathExtension.isEmpty ? "wav" : sourceURL.pathExtension.lowercased()
            let exportedPath = "audio/long-take-\(source.id.uuidString.lowercased()).\(sourceExtension)"
            let exportedURL = destinationURL.appendingPathComponent(exportedPath)
            try fm.copyItem(at: sourceURL, to: exportedURL)
            integrity[exportedPath] = actualHash
            fileRecords.append(IADFileRecord(
                localFileID: source.id,
                targetTables: ["core.entity", "media.asset", "media.bitstream", "media.storage_object", "media.file"],
                projectionStatus: IADContract.projectionMode,
                relativePath: exportedPath,
                name: source.sourceFilename,
                byteSize: source.fileSize,
                sha256: actualHash,
                mimeType: Self.mediaType(for: exportedPath),
                container: sourceExtension == "wav" ? "WAVE" : "AIFF",
                encoding: source.analysis.encoding ?? "uncompressed source PCM",
                bitDepth: source.analysis.bitDepth ?? 0,
                sampleRate: source.sampleRate,
                channelCount: source.channelCount,
                frameCount: source.frameCount
            ))
            segmentRecords.append(contentsOf: source.analysis.segments.map { segment in
                IADSegmentRecord(
                    localSegmentID: "long-take:\(source.id.uuidString.lowercased()):\(segment.id.uuidString.lowercased())",
                    targetTable: "audio.segment",
                    projectionStatus: IADContract.projectionMode,
                    localFileID: source.id,
                    segmentType: "automatically-detected-note-candidate",
                    startSeconds: segment.exportStartSeconds,
                    endSeconds: segment.exportEndSeconds,
                    source: source.analysis.analyzerVersion
                )
            })
        }

        var preflightRecordsBySession: [UUID: [IADCapturePreflightRecord]] = [:]
        for session in project.recordingSessions ?? [] {
            for report in session.capturePreflightReports ?? [] {
                guard report.sessionID == session.id else {
                    throw OrgRecError.exportValidation("Capture preflight \(report.id.uuidString) belongs to another recording session.")
                }
                guard isSafePackageRelativePath(report.relativeAudioPath), report.relativeAudioPath.hasPrefix("Audio/Calibration/") else {
                    throw OrgRecError.exportValidation("Capture preflight \(report.id.uuidString) has an unsafe evidence path.")
                }
                let source = packageURL.appendingPathComponent(report.relativeAudioPath)
                let values = try source.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else {
                    throw OrgRecError.exportValidation("Capture preflight audio is missing for \(report.id.uuidString).")
                }
                let actualHash = try sha256(of: source)
                guard actualHash == report.sha256,
                      Int64(values.fileSize ?? 0) == report.fileSize else {
                    throw OrgRecError.exportValidation("Capture preflight audio no longer matches report \(report.id.uuidString).")
                }
                let fileExtension = source.pathExtension.isEmpty ? "wav" : source.pathExtension.lowercased()
                let exportedPath = "audio/preflight-\(report.id.uuidString.lowercased()).\(fileExtension)"
                let target = destinationURL.appendingPathComponent(exportedPath)
                try fm.copyItem(at: source, to: target)
                integrity[exportedPath] = actualHash
                fileRecords.append(IADFileRecord(
                    localFileID: report.id,
                    targetTables: ["core.entity", "media.asset", "media.bitstream", "media.storage_object", "media.file", "paradata.generic"],
                    projectionStatus: IADContract.projectionMode,
                    relativePath: exportedPath,
                    name: target.lastPathComponent,
                    byteSize: report.fileSize,
                    sha256: actualHash,
                    mimeType: Self.mediaType(for: exportedPath),
                    container: report.captureDiagnostics?.container ?? "WAVE/BWF",
                    encoding: report.captureDiagnostics?.encoding ?? "linear PCM little-endian",
                    bitDepth: report.captureDiagnostics?.bitDepth ?? 24,
                    sampleRate: report.sampleRate,
                    channelCount: report.channels.count,
                    frameCount: report.frameCount
                ))
                preflightRecordsBySession[session.id, default: []].append(
                    IADCapturePreflightRecord(report: report, audioRelativePath: exportedPath)
                )
            }
        }

        var calibrationRecords: [IADCalibrationRecord] = []
        for calibration in project.tuningCalibrations ?? [] {
            var exportedPath: String?
            if let localPath = calibration.relativeAudioPath {
                guard isSafePackageRelativePath(localPath), localPath.hasPrefix("Audio/Calibration/") else {
                    throw OrgRecError.exportValidation("Calibration \(calibration.id) has an unsafe audio path.")
                }
                let source = packageURL.appendingPathComponent(localPath)
                if fm.fileExists(atPath: source.path) {
                    let relative = "audio/calibration-\(calibration.id.uuidString.lowercased()).wav"
                    try fm.copyItem(at: source, to: destinationURL.appendingPathComponent(relative))
                    integrity[relative] = try sha256(of: destinationURL.appendingPathComponent(relative))
                    exportedPath = relative
                } else if calibration.status == .accepted {
                    throw OrgRecError.exportValidation("Accepted calibration audio is missing for \(calibration.id).")
                }
            }
            calibrationRecords.append(IADCalibrationRecord(calibration: calibration, audioRelativePath: exportedPath))
        }

        let snapshotData = try OrgRecCoding.encoder.encode(project.snapshot)
        let snapshotURL = destinationURL.appendingPathComponent("modavis-snapshot.json")
        try snapshotData.write(to: snapshotURL, options: .atomic)
        integrity["modavis-snapshot.json"] = snapshotData.sha256Hex

        if let relativePath = project.navigatorPayloadRelativePath {
            guard isSafePackageRelativePath(relativePath), relativePath.hasPrefix("Manifests/") else {
                throw OrgRecError.exportValidation("The frozen Navigator payload path is unsafe.")
            }
            let payloadSource = packageURL.appendingPathComponent(relativePath)
            guard fm.fileExists(atPath: payloadSource.path) else {
                throw OrgRecError.exportValidation("The frozen Navigator payload is missing from the project package.")
            }
            let payloadData = try Data(contentsOf: payloadSource)
            guard payloadData.sha256Hex == project.snapshot.payloadSHA256 else {
                throw OrgRecError.exportValidation("The frozen Navigator payload no longer matches its recorded SHA-256.")
            }
            let payloadTarget = destinationURL.appendingPathComponent("modavis-navigator-payload.json")
            try payloadData.write(to: payloadTarget, options: .atomic)
            integrity["modavis-navigator-payload.json"] = payloadData.sha256Hex
        }

        let projectData = try OrgRecCoding.encoder.encode(project)
        let projectURL = destinationURL.appendingPathComponent("project.json")
        try projectData.write(to: projectURL, options: .atomic)
        integrity["project.json"] = projectData.sha256Hex

        let consistencyData = try OrgRecCoding.encoder.encode(consistency)
        let consistencyPath = "consistency-report.json"
        try consistencyData.write(to: destinationURL.appendingPathComponent(consistencyPath), options: .atomic)
        integrity[consistencyPath] = consistencyData.sha256Hex

        let sessionRecords = (project.recordingSessions ?? []).map { session in
            IADSessionRecord(
                localSessionID: session.id,
                targetTables: ["prov.activity", "audio.recording_session"],
                projectionStatus: IADContract.projectionMode,
                sessionCode: session.sessionCode,
                organStateMDVSID: project.organMDVSID,
                venueLabel: project.venueName,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                operatorName: session.operatorName,
                institution: session.institution,
                purpose: session.purpose,
                rightsStatement: session.rightsStatement,
                timezoneIdentifier: session.timezoneIdentifier,
                clockSource: session.clockSource,
                venueCondition: session.venueCondition,
                environmentalConditions: session.environment,
                notes: session.notes,
                sessionPlanID: session.sessionPlanID,
                sessionPlanRevision: session.sessionPlanRevision,
                surroundingNoiseAssessment: session.noiseContextAssessment,
                observedNoiseIncidents: session.noiseObservations,
                capturePreflightReports: preflightRecordsBySession[session.id]
            )
        }
        let deviceRecords = project.devices.map { device in
            let deviceTables: [String]
            switch device.kind {
            case .microphone: deviceTables = ["devices.microphone"]
            case .audioInterface: deviceTables = ["devices.interface"]
            case .controller, .sensor: deviceTables = []
            }
            return IADDeviceRecord(
                localDeviceID: device.id,
                targetTables: ["core.entity", "core.manifestation"] + deviceTables,
                projectionStatus: IADContract.projectionMode,
                kind: device.kind,
                manufacturer: device.manufacturer,
                model: device.model,
                serialNumber: device.serialNumber,
                existingMODAVISManifestationID: device.modavisManifestationID,
                details: device.details
            )
        }
        let registrationRecords = project.registrations.map { registration in
            IADRegistrationRecord(
                localRegistrationID: registration.id,
                projectionStatus: IADContract.projectionMode,
                revision: registration.revision,
                name: registration.name,
                purpose: registration.purpose,
                activatedStops: registration.activatedStops,
                activatedCouplers: registration.activatedCouplers,
                activatedAccessories: registration.activatedAccessories,
                notes: registration.notes
            )
        }
        let paths = IADManifestPaths()
        let temperamentAnalysisRecords = (project.temperamentAnalyses ?? []).map(IADTemperamentAnalysisRecord.init)
        try writeJSONLines(sessionRecords.sorted { $0.localSessionID.uuidString < $1.localSessionID.uuidString }, to: destinationURL.appendingPathComponent(paths.sessions), integrity: &integrity, relativePath: paths.sessions)
        try writeJSONLines(takeRecords.sorted { $0.localTakeID.uuidString < $1.localTakeID.uuidString }, to: destinationURL.appendingPathComponent(paths.takes), integrity: &integrity, relativePath: paths.takes)
        try writeJSONLines(fileRecords.sorted { $0.localFileID.uuidString < $1.localFileID.uuidString }, to: destinationURL.appendingPathComponent(paths.files), integrity: &integrity, relativePath: paths.files)
        try writeJSONLines(channelRecords.sorted { $0.localChannelID < $1.localChannelID }, to: destinationURL.appendingPathComponent(paths.channels), integrity: &integrity, relativePath: paths.channels)
        try writeJSONLines(segmentRecords.sorted { $0.localSegmentID < $1.localSegmentID }, to: destinationURL.appendingPathComponent(paths.segments), integrity: &integrity, relativePath: paths.segments)
        try writeJSONLines(deviceRecords.sorted { $0.localDeviceID.uuidString < $1.localDeviceID.uuidString }, to: destinationURL.appendingPathComponent(paths.devices), integrity: &integrity, relativePath: paths.devices)
        try writeJSONLines(registrationRecords.sorted { $0.localRegistrationID.uuidString < $1.localRegistrationID.uuidString }, to: destinationURL.appendingPathComponent(paths.registrations), integrity: &integrity, relativePath: paths.registrations)
        try writeJSONLines(observationRecords.sorted { $0.localObservationID < $1.localObservationID }, to: destinationURL.appendingPathComponent(paths.observations), integrity: &integrity, relativePath: paths.observations)
        try writeJSONLines(paradataRecords.sorted { $0.localParadataID < $1.localParadataID }, to: destinationURL.appendingPathComponent(paths.paradata), integrity: &integrity, relativePath: paths.paradata)
        if let calibrationPath = paths.calibrations {
            try writeJSONLines(calibrationRecords.sorted { $0.localCalibrationID.uuidString < $1.localCalibrationID.uuidString }, to: destinationURL.appendingPathComponent(calibrationPath), integrity: &integrity, relativePath: calibrationPath)
        }
        if let temperamentPath = paths.temperamentAnalyses {
            try writeJSONLines(temperamentAnalysisRecords.sorted { $0.localAnalysisID.uuidString < $1.localAnalysisID.uuidString }, to: destinationURL.appendingPathComponent(temperamentPath), integrity: &integrity, relativePath: temperamentPath)
        }

        let payloadFiles = try integrity.keys.sorted().map { path in
            let url = destinationURL.appendingPathComponent(path)
            return IADPayloadFile(
                relativePath: path,
                sha256: integrity[path]!,
                byteSize: Int64(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0),
                mediaType: Self.mediaType(for: path),
                role: Self.payloadRole(for: path)
            )
        }
        let iadManifest = IADDatasetManifest(
            datasetID: project.id,
            title: project.title,
            projectID: project.id,
            organ: IADOrganReference(mdvsID: project.organMDVSID, name: project.organName, venueName: project.venueName),
            releaseBinding: project.snapshot.release,
            navigatorPayloadSHA256: project.snapshot.payloadSHA256,
            modavisSnapshotSHA256: snapshotData.sha256Hex,
            manifests: paths,
            counts: IADObjectCounts(
                sessions: sessionRecords.count,
                takes: takeRecords.count,
                files: fileRecords.count,
                channels: channelRecords.count,
                segments: segmentRecords.count,
                devices: deviceRecords.count,
                registrations: registrationRecords.count,
                observations: observationRecords.count,
                paradata: paradataRecords.count,
                calibrations: calibrationRecords.count,
                temperamentAnalyses: temperamentAnalysisRecords.count
            ),
            files: payloadFiles,
            integrity: integrity
        )
        let iadData = try OrgRecCoding.encoder.encode(iadManifest)
        try iadData.write(to: destinationURL.appendingPathComponent(IADContract.manifestFilename), options: .atomic)
        integrity[IADContract.manifestFilename] = iadData.sha256Hex

        let manifest = CapturePackageManifest(
            projectID: project.id,
            projectTitle: project.title,
            releaseBinding: project.snapshot.release,
            modavisSnapshotSHA256: snapshotData.sha256Hex,
            coverage: RoadmapEngine.coverage(project.roadmap),
            takes: entries,
            integrity: integrity,
            consistencyReportRelativePath: consistencyPath,
            consistencyScore: consistency.score,
            iadManifestRelativePath: IADContract.manifestFilename,
            iadManifestSHA256: iadData.sha256Hex
        )
        let manifestData = try OrgRecCoding.encoder.encode(manifest)
        try manifestData.write(
            to: destinationURL.appendingPathComponent("capture-package.json"),
            options: .atomic
        )
        do {
            let validation = try IADPackageValidator.validate(packageURL: destinationURL)
            guard validation.isValid else {
                try? fm.removeItem(at: destinationURL)
                throw OrgRecError.exportValidation("Generated IAD package failed validation: " + validation.errors.prefix(3).joined(separator: "; "))
            }
        } catch {
            try? fm.removeItem(at: destinationURL)
            throw error
        }
        return destinationURL
    }

    private func writeJSONLines<T: Encodable>(_ records: [T], to url: URL, integrity: inout [String: String], relativePath: String) throws {
        var data = Data()
        for record in records {
            data.append(try OrgRecCoding.lineEncoder.encode(record))
            data.append(0x0A)
        }
        try data.write(to: url, options: .atomic)
        integrity[relativePath] = data.sha256Hex
    }

    private static func finalMarker(_ kind: AnalysisMarkerKind, take: TakeRecord) -> Double? {
        if let corrected = take.markerCorrections?.filter({ $0.marker == kind }).max(by: { $0.createdAt < $1.createdAt }) {
            return corrected.correctedSeconds
        }
        switch kind {
        case .onset: return take.analysis?.onsetSeconds
        case .sustainStart: return take.analysis?.sustainStartSeconds
        case .keyUp: return take.analysis?.keyUpSeconds
        case .soundOffset: return take.analysis?.soundOffsetSeconds
        case .tailEnd: return take.analysis?.tailEndSeconds
        }
    }

    private static func segments(for take: TakeRecord) -> [IADSegmentRecord] {
        let boundaries: [(String, Double?, Double?)] = [
            ("attack", finalMarker(.onset, take: take), finalMarker(.sustainStart, take: take)),
            ("sustain", finalMarker(.sustainStart, take: take), finalMarker(.keyUp, take: take)),
            ("release", finalMarker(.keyUp, take: take), finalMarker(.soundOffset, take: take)),
            ("tail", finalMarker(.soundOffset, take: take), finalMarker(.tailEnd, take: take)),
        ]
        var records: [IADSegmentRecord] = boundaries.compactMap { type, start, end in
            guard let start, let end, start >= 0, end > start else { return nil }
            return IADSegmentRecord(
                localSegmentID: "\(take.id.uuidString.lowercased()):\(type)",
                targetTable: "audio.segment",
                projectionStatus: IADContract.projectionMode,
                localFileID: take.id,
                segmentType: type,
                startSeconds: start,
                endSeconds: end,
                source: take.markerCorrections?.isEmpty == false ? "reviewed-markers" : "automated-analysis"
            )
        }
        if let acceptedID = take.acceptedLoopPointSetID,
           let set = take.loopPointSets?.first(where: { $0.id == acceptedID }),
           let region = set.sustainRegion {
            records.append(IADSegmentRecord(
                localSegmentID: "\(take.id.uuidString.lowercased()):sustain-loop:\(set.id.uuidString.lowercased())",
                targetTable: "audio.segment",
                projectionStatus: IADContract.projectionMode,
                localFileID: take.id,
                segmentType: "sustain-loop",
                startSeconds: region.startSeconds(sampleRate: set.sampleRate),
                endSeconds: region.endSeconds(sampleRate: set.sampleRate),
                source: "reviewed-loop-point-set"
            ))
        }
        return records
    }

    private static func observations(for take: TakeRecord, component: ComponentLocator) -> [IADObservationRecord] {
        guard let analysis = take.analysis else { return [] }
        let pitchUncertainty = analysis.pitchTrackSummary.flatMap { summary -> Double? in
            guard let lower = summary.lowerUncertaintyCents, let upper = summary.upperUncertaintyCents else { return nil }
            return (upper - lower) / 2
        }
        var values: [(String, Double?, String, Double?, Double?)] = [
            ("fundamental-frequency", analysis.frequencyHz, "Hz", nil, analysis.confidence),
            ("pitch-deviation", analysis.centsDeviation, "cent", pitchUncertainty, analysis.confidence),
            ("pitch-iqr", analysis.pitchTrackSummary?.interquartileRangeCents, "cent", nil, nil),
            ("pitch-drift", analysis.pitchTrackSummary?.driftCentsPerSecond, "cent/s", nil, nil),
            ("signal-to-noise", analysis.signalToNoiseDB, "dB", nil, nil),
            ("dc-offset", analysis.dcOffset, "full-scale-ratio", nil, nil),
            ("spectral-centroid", analysis.spectralSummary?.spectralCentroidHz, "Hz", nil, nil),
            ("spectral-rolloff-85", analysis.spectralSummary?.spectralRolloff85Hz, "Hz", nil, nil),
            ("odd-even-energy-ratio", analysis.spectralSummary?.oddEvenEnergyRatioDB, "dB", nil, nil),
            ("weighted-inharmonicity", analysis.spectralSummary?.weightedInharmonicityCents, "cent", nil, nil),
            ("spectral-spread", analysis.perceptualSpectralSummary?.spectralSpreadHz, "Hz", nil, nil),
            ("spectral-flatness", analysis.perceptualSpectralSummary?.spectralFlatness, "ratio", nil, nil),
            ("spectral-entropy", analysis.perceptualSpectralSummary?.spectralEntropy, "ratio", nil, nil),
            ("spectral-crest", analysis.perceptualSpectralSummary?.spectralCrestDB, "dB", nil, nil),
            ("spectral-flux", analysis.perceptualSpectralSummary?.spectralFlux, "ratio", nil, nil),
            ("auditory-centroid-erb", analysis.perceptualSpectralSummary?.auditoryCentroidERB, "ERB-rate", nil, nil),
            ("auditory-spread-erb", analysis.perceptualSpectralSummary?.auditorySpreadERB, "ERB-rate", nil, nil),
            ("harmonic-energy-ratio", analysis.perceptualSpectralSummary?.harmonicEnergyRatio, "ratio", nil, nil),
            ("harmonic-spectral-slope", analysis.perceptualSpectralSummary?.harmonicSpectralSlopeDBPerOctave, "dB/octave", nil, nil),
            ("harmonic-spectral-deviation", analysis.perceptualSpectralSummary?.harmonicSpectralDeviationDB, "dB", nil, nil),
            ("tristimulus-1", analysis.perceptualSpectralSummary?.tristimulus1, "ratio", nil, nil),
            ("tristimulus-2", analysis.perceptualSpectralSummary?.tristimulus2, "ratio", nil, nil),
            ("tristimulus-3", analysis.perceptualSpectralSummary?.tristimulus3, "ratio", nil, nil),
            ("spectral-centroid-modulation-rate", analysis.perceptualSpectralSummary?.spectralCentroidModulationRateHz, "Hz", nil, analysis.perceptualSpectralSummary?.spectralCentroidModulationConfidence),
            ("spectral-centroid-modulation-depth", analysis.perceptualSpectralSummary?.spectralCentroidModulationDepthERB, "ERB-rate", nil, analysis.perceptualSpectralSummary?.spectralCentroidModulationConfidence),
            ("peak-level", analysis.peakDBFS, "dBFS", nil, nil),
            ("rms-level", analysis.rmsDBFS, "dBFS", nil, nil),
            ("pipe-attack-duration", analysis.pipeSoundBehavior?.attackDurationSeconds, "s", nil, nil),
            ("pipe-attack-periods", analysis.pipeSoundBehavior?.attackDurationFundamentalPeriods, "period", nil, nil),
            ("sustain-stationarity", analysis.pipeSoundBehavior?.sustainStationarity, "ratio", nil, nil),
            ("amplitude-modulation-rate", analysis.pipeSoundBehavior?.amplitudeModulationRateHz, "Hz", nil, nil),
            ("amplitude-modulation-depth", analysis.pipeSoundBehavior?.amplitudeModulationDepthDB, "dB", nil, nil),
            ("frequency-modulation-rate", analysis.pipeSoundBehavior?.frequencyModulationRateHz, "Hz", nil, nil),
            ("frequency-modulation-depth", analysis.pipeSoundBehavior?.frequencyModulationDepthCents, "cent", nil, nil),
            ("pipe-release-duration", analysis.pipeSoundBehavior?.releaseDurationSeconds, "s", nil, nil),
            ("room-tail-duration", analysis.pipeSoundBehavior?.roomTailDurationSeconds, "s", nil, nil),
            ("observed-decay-edt", analysis.acousticResponseAnalysis?.broadband.edt?.extrapolatedDecayTimeSeconds, "s", analysis.acousticResponseAnalysis?.broadband.edt?.standardUncertaintySeconds, nil),
            ("observed-decay-t20", analysis.acousticResponseAnalysis?.broadband.t20?.extrapolatedDecayTimeSeconds, "s", analysis.acousticResponseAnalysis?.broadband.t20?.standardUncertaintySeconds, nil),
            ("observed-decay-t30", analysis.acousticResponseAnalysis?.broadband.t30?.extrapolatedDecayTimeSeconds, "s", analysis.acousticResponseAnalysis?.broadband.t30?.standardUncertaintySeconds, nil),
            ("observed-decay-usable-range", analysis.acousticResponseAnalysis?.broadband.usableDecayRangeDB, "dB", nil, nil),
            ("observed-decay-early-slope-time", analysis.acousticResponseAnalysis?.broadband.multiSlope?.earlyDecayTimeSeconds, "s", nil, nil),
            ("observed-decay-late-slope-time", analysis.acousticResponseAnalysis?.broadband.multiSlope?.lateDecayTimeSeconds, "s", nil, nil),
            ("observed-decay-multislope-delta-bic", analysis.acousticResponseAnalysis?.broadband.multiSlope?.deltaBIC, "ratio", nil, nil),
            ("loop-seam-score", take.loopPointSets?.first(where: { $0.id == take.acceptedLoopPointSetID })?.sustainRegion?.score?.total
                ?? analysis.detectedLoopPointSets?.first?.sustainRegion?.score?.total, "normalized-penalty", nil, nil),
        ]
        values.append(("pitch-estimator-difference", analysis.pitchEstimatorComparison?.differenceCents, "cent", nil, nil))
        for estimate in analysis.pitchEstimatorComparison?.estimates ?? [] {
            let slug = estimate.estimator.lowercased().replacingOccurrences(of: " ", with: "-")
            values.append(("fundamental-frequency-\(slug)", estimate.frequencyHz, "Hz", nil, estimate.confidence))
        }
        return values.compactMap { property, value, unit, uncertainty, confidence in
            guard let value, value.isFinite else { return nil }
            return IADObservationRecord(
                localObservationID: "\(take.id.uuidString.lowercased()):\(property)",
                targetTable: "measurement.observation",
                projectionStatus: IADContract.projectionMode,
                localTakeID: take.id,
                measuredComponent: component,
                property: property,
                numericValue: value,
                unit: unit,
                method: analysis.method,
                algorithmVersion: analysis.algorithmVersion,
                analyzedAt: analysis.analyzedAt,
                uncertainty: uncertainty,
                confidence: confidence,
                analysisRunID: analysis.analysisRunID
            )
        }
    }

    private static func mediaType(for path: String) -> String {
        if path.hasSuffix(".wav") { return "audio/wav" }
        if path.hasSuffix(".aif") || path.hasSuffix(".aiff") { return "audio/aiff" }
        if path.hasSuffix(".jsonl") { return "application/x-ndjson" }
        return "application/json"
    }

    private static func payloadRole(for path: String) -> String {
        if path.hasPrefix("audio/preflight-") { return "capture-preflight-evidence" }
        if path.hasPrefix("audio/calibration-") { return "tuning-calibration-audio" }
        if path.hasPrefix("audio/long-take-") { return "continuous-source-master" }
        if path.hasPrefix("audio/") { return "original-or-bwf-metadata" }
        if path.hasPrefix("analysis/") { return "analysis" }
        if path.hasPrefix("annotations/") { return "annotation" }
        if path.hasPrefix("manifests/") { return "modavis-projection-index" }
        if path.contains("modavis") { return "modavis-binding" }
        if path == "project.json" { return "source-project" }
        if path == "consistency-report.json" { return "quality-report" }
        return "metadata"
    }
}
