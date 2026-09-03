import Foundation

public enum IADContract {
    public static let version = "org.modavis.instrumental-audio-dataset/1.0"
    public static let manifestFilename = "iad-manifest.json"
    public static let projectionMode = "candidate-proposals"
}

public struct IADOrganReference: Codable, Hashable, Sendable {
    public var mdvsID: String
    public var name: String
    public var venueName: String
}

public struct IADManifestPaths: Codable, Hashable, Sendable {
    public var sessions = "manifests/sessions.jsonl"
    public var takes = "manifests/takes.jsonl"
    public var files = "manifests/files.jsonl"
    public var channels = "manifests/channels.jsonl"
    public var segments = "manifests/segments.jsonl"
    public var devices = "manifests/devices.jsonl"
    public var registrations = "manifests/registrations.jsonl"
    public var observations = "manifests/observations.jsonl"
    public var paradata = "manifests/paradata.jsonl"
    public var calibrations: String? = "manifests/calibrations.jsonl"
    public var temperamentAnalyses: String? = "manifests/temperament-analyses.jsonl"

    public init() {}

    public var all: [String] {
        [sessions, takes, files, channels, segments, devices, registrations, observations, paradata]
            + [calibrations, temperamentAnalyses].compactMap { $0 }
    }
}

public struct IADObjectCounts: Codable, Hashable, Sendable {
    public var sessions: Int
    public var takes: Int
    public var files: Int
    public var channels: Int
    public var segments: Int
    public var devices: Int
    public var registrations: Int
    public var observations: Int
    public var paradata: Int
    public var calibrations: Int?
    public var temperamentAnalyses: Int?

    public init(
        sessions: Int,
        takes: Int,
        files: Int,
        channels: Int,
        segments: Int,
        devices: Int,
        registrations: Int,
        observations: Int,
        paradata: Int,
        calibrations: Int? = nil,
        temperamentAnalyses: Int? = nil
    ) {
        self.sessions = sessions
        self.takes = takes
        self.files = files
        self.channels = channels
        self.segments = segments
        self.devices = devices
        self.registrations = registrations
        self.observations = observations
        self.paradata = paradata
        self.calibrations = calibrations
        self.temperamentAnalyses = temperamentAnalyses
    }
}

public struct IADCalibrationRecord: Codable, Hashable, Sendable {
    public var localCalibrationID: UUID
    public var targetTables: [String]
    public var projectionStatus: String
    public var calibration: TuningCalibration
    public var audioRelativePath: String?

    public init(calibration: TuningCalibration, audioRelativePath: String?) {
        self.localCalibrationID = calibration.id
        self.targetTables = ["prov.activity", "measurement.observation", "audio.recording_session"]
        self.projectionStatus = IADContract.projectionMode
        self.calibration = calibration
        self.audioRelativePath = audioRelativePath
    }
}

public struct IADTemperamentAnalysisRecord: Codable, Hashable, Sendable {
    public var localAnalysisID: UUID
    public var targetTables: [String]
    public var projectionStatus: String
    public var analysis: TemperamentAnalysisReport

    public init(analysis: TemperamentAnalysisReport) {
        self.localAnalysisID = analysis.id
        self.targetTables = ["measurement.observation", "paradata.generic"]
        self.projectionStatus = IADContract.projectionMode
        self.analysis = analysis
    }
}

public struct IADPayloadFile: Codable, Hashable, Sendable {
    public var relativePath: String
    public var sha256: String
    public var byteSize: Int64
    public var mediaType: String
    public var role: String
}

public struct IADDatasetManifest: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var software: OrgRecSoftwareMetadata?
    public var datasetID: UUID
    public var generatedAt: Date
    public var title: String
    public var producer: String
    public var projectID: UUID
    public var organ: IADOrganReference
    public var releaseBinding: ReleaseBinding
    public var navigatorPayloadSHA256: String
    public var modavisSnapshotSHA256: String
    public var projectionMode: String
    public var manifests: IADManifestPaths
    public var counts: IADObjectCounts
    public var files: [IADPayloadFile]
    public var integrity: [String: String]

    public init(
        datasetID: UUID,
        software: OrgRecSoftwareMetadata? = OrgRecSoftware.current,
        generatedAt: Date = .now,
        title: String,
        projectID: UUID,
        organ: IADOrganReference,
        releaseBinding: ReleaseBinding,
        navigatorPayloadSHA256: String,
        modavisSnapshotSHA256: String,
        manifests: IADManifestPaths = IADManifestPaths(),
        counts: IADObjectCounts,
        files: [IADPayloadFile],
        integrity: [String: String]
    ) {
        self.contractVersion = IADContract.version
        self.software = software
        self.datasetID = datasetID
        self.generatedAt = generatedAt
        self.title = title
        self.producer = "OrgRec"
        self.projectID = projectID
        self.organ = organ
        self.releaseBinding = releaseBinding
        self.navigatorPayloadSHA256 = navigatorPayloadSHA256
        self.modavisSnapshotSHA256 = modavisSnapshotSHA256
        self.projectionMode = IADContract.projectionMode
        self.manifests = manifests
        self.counts = counts
        self.files = files
        self.integrity = integrity
    }
}

public struct IADSessionRecord: Codable, Hashable, Sendable {
    public var localSessionID: UUID
    public var targetTables: [String]
    public var projectionStatus: String
    public var sessionCode: String
    public var organStateMDVSID: String
    public var venueLabel: String
    public var startedAt: Date
    public var endedAt: Date?
    public var operatorName: String
    public var institution: String
    public var purpose: String
    public var rightsStatement: String
    public var timezoneIdentifier: String
    public var clockSource: String
    public var venueCondition: String?
    public var environmentalConditions: EnvironmentReading
    public var notes: String
    public var sessionPlanID: UUID?
    public var sessionPlanRevision: Int?
    public var surroundingNoiseAssessment: NoiseContextAssessment?
    public var observedNoiseIncidents: [NoiseObservation]?
    public var capturePreflightReports: [IADCapturePreflightRecord]? = nil
}

public struct IADCapturePreflightRecord: Codable, Hashable, Sendable {
    public var localPreflightID: UUID
    public var targetTables: [String]
    public var projectionStatus: String
    public var report: CapturePreflightReport
    public var audioRelativePath: String

    public init(report: CapturePreflightReport, audioRelativePath: String) {
        self.localPreflightID = report.id
        self.targetTables = ["prov.activity", "measurement.observation", "paradata.generic", "media.asset"]
        self.projectionStatus = IADContract.projectionMode
        self.report = report
        self.audioRelativePath = audioRelativePath
    }
}

public struct IADFileRecord: Codable, Hashable, Sendable {
    public var localFileID: UUID
    public var targetTables: [String]
    public var projectionStatus: String
    public var relativePath: String
    public var name: String
    public var byteSize: Int64
    public var sha256: String
    public var mimeType: String
    public var container: String
    public var encoding: String
    public var bitDepth: Int
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int64
}

public struct IADTakeRecord: Codable, Hashable, Sendable {
    public var localTakeID: UUID
    public var targetTable: String
    public var projectionStatus: String
    public var localSessionID: UUID
    public var localFileID: UUID
    public var localMicrophoneSetupID: UUID?
    public var takeNumber: Int
    public var recordedAt: Date
    public var durationSeconds: Double?
    public var status: TakeStatus
    public var performanceInstruction: String
    public var roadmapItemID: UUID
    public var componentLocator: ComponentLocator
    public var localRegistrationID: UUID?
    public var physicalSoundTargetID: String? = nil
    public var equivalentComponentLocators: [ComponentLocator]? = nil
    public var activationRoutes: [PhysicalActivationRoute]? = nil
    public var longTakeSource: LongTakeSliceProvenance? = nil
    public var instrumentNoiseProtocol: InstrumentNoiseCaptureProtocol? = nil
    public var instrumentNoiseParadata: InstrumentNoiseTakeParadata? = nil
    public var soundingTargetDefinition: SoundingTargetDefinition? = nil
    public var captureStateSnapshot: CaptureStateSnapshot? = nil
    public var controlEventLog: ControlEventLog? = nil
    public var audioControlAlignment: AudioControlAlignment? = nil
    public var complexCaptureProtocol: ComplexCaptureProtocol? = nil
    public var complexCaptureParadata: ComplexCaptureTakeParadata? = nil
    public var spatialGeometrySnapshot: SpatialGeometrySnapshot? = nil
    public var spatialAcousticProtocol: SpatialAcousticCaptureProtocol? = nil
    public var spatialAcousticParadata: SpatialAcousticTakeParadata? = nil
    public var effectAnalysisProtocol: NonPitchedEffectAnalysisProtocol? = nil
    public var effectAnalysis: EffectAnalysisResult? = nil
}

public struct IADChannelRecord: Codable, Hashable, Sendable {
    public var localChannelID: String
    public var targetTable: String
    public var projectionStatus: String
    public var localFileID: UUID
    public var channelNumber: Int
    public var role: String
    public var label: String
    public var microphoneLocalID: UUID?
    public var gainDB: Double?
    public var phantomPower: Bool?
}

public struct IADSegmentRecord: Codable, Hashable, Sendable {
    public var localSegmentID: String
    public var targetTable: String
    public var projectionStatus: String
    public var localFileID: UUID
    public var segmentType: String
    public var startSeconds: Double
    public var endSeconds: Double
    public var source: String
}

public struct IADDeviceRecord: Codable, Hashable, Sendable {
    public var localDeviceID: UUID
    public var targetTables: [String]
    public var projectionStatus: String
    public var kind: DeviceInstance.Kind
    public var manufacturer: String
    public var model: String
    public var serialNumber: String
    public var existingMODAVISManifestationID: String?
    public var details: [String: String]
}

public struct IADRegistrationRecord: Codable, Hashable, Sendable {
    public var localRegistrationID: UUID
    public var projectionStatus: String
    public var revision: Int
    public var name: String?
    public var purpose: String?
    public var activatedStops: [ComponentLocator]
    public var activatedCouplers: [ComponentLocator]
    public var activatedAccessories: [ComponentLocator]
    public var notes: String
}

public struct IADObservationRecord: Codable, Hashable, Sendable {
    public var localObservationID: String
    public var targetTable: String
    public var projectionStatus: String
    public var localTakeID: UUID
    public var measuredComponent: ComponentLocator
    public var property: String
    public var numericValue: Double
    public var unit: String
    public var method: String
    public var algorithmVersion: String
    public var analyzedAt: Date
    public var uncertainty: Double?
    public var confidence: Double?
    public var analysisRunID: UUID?
}

public struct IADParadataRecord: Codable, Hashable, Sendable {
    public var localParadataID: String
    public var targetTable: String
    public var projectionStatus: String
    public var localTakeID: UUID
    public var analysisRelativePath: String?
    public var annotationRelativePath: String?
    public var bwfRelativePath: String?
    public var provenanceContract: String?
    public var analysisMethod: String?
    public var algorithmVersion: String?
    public var reviewDecisionCount: Int
    public var captureFaultCount: Int
    public var software: OrgRecSoftwareMetadata?
    public var controlEventRelativePath: String? = nil
    public var controlEventCount: Int? = nil
    public var alignmentStatus: AudioControlAlignmentStatus? = nil
    public var captureStateFingerprint: String? = nil
}

public struct IADValidationReport: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var checkedAt: Date
    public var errors: [String]
    public var warnings: [String]
    public var verifiedFileCount: Int
    public var isValid: Bool { errors.isEmpty }
}

public enum IADPackageValidator {
    public static func validate(packageURL: URL) throws -> IADValidationReport {
        let fm = FileManager.default
        let resolvedRoot = packageURL.standardizedFileURL.resolvingSymlinksInPath()
        var errors: [String] = []
        var warnings: [String] = []
        let manifestURL = packageURL.appendingPathComponent(IADContract.manifestFilename)
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw OrgRecError.invalidProject("The selected directory has no \(IADContract.manifestFilename).")
        }
        let manifest = try OrgRecCoding.decoder.decode(
            IADDatasetManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        if manifest.contractVersion != IADContract.version {
            errors.append("Unsupported IAD contract \(manifest.contractVersion).")
        }
        if manifest.projectionMode != IADContract.projectionMode {
            errors.append("The package does not declare candidate-only MODAVIS projection semantics.")
        }
        if manifest.navigatorPayloadSHA256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil {
            errors.append("navigatorPayloadSHA256 is not a SHA-256 value.")
        }
        if Set(manifest.manifests.all).count != manifest.manifests.all.count {
            errors.append("Manifest JSONL paths are not unique.")
        }
        let project: OrgRecProject
        do {
            project = try OrgRecCoding.decoder.decode(
                OrgRecProject.self,
                from: Data(contentsOf: packageURL.appendingPathComponent("project.json"))
            )
            if project.id != manifest.projectID { errors.append("The IAD and project identifiers differ.") }
            if project.organMDVSID != manifest.organ.mdvsID { errors.append("The IAD and project organ identifiers differ.") }
            if project.snapshot.payloadSHA256 != manifest.navigatorPayloadSHA256 { errors.append("The frozen Navigator hash differs from project.json.") }
            if project.snapshot.release != manifest.releaseBinding { errors.append("The IAD and project release bindings differ.") }
            for take in project.takes where isSafePackageRelativePath(take.relativeAudioPath) == false || take.relativeAudioPath.hasPrefix("Audio/Originals/") == false {
                errors.append("Project take \(take.id) has an unsafe original-audio path.")
            }
            for source in project.longTakeSources ?? []
            where isSafePackageRelativePath(source.relativeAudioPath) == false || source.relativeAudioPath.hasPrefix("Audio/LongTakes/") == false {
                errors.append("Long take \(source.id) has an unsafe source-audio path.")
            }
            for calibration in project.tuningCalibrations ?? [] {
                if let path = calibration.relativeAudioPath,
                   isSafePackageRelativePath(path) == false || path.hasPrefix("Audio/Calibration/") == false {
                    errors.append("Calibration \(calibration.id) has an unsafe audio path.")
                }
            }
            for session in project.recordingSessions ?? [] {
                for report in session.capturePreflightReports ?? []
                where isSafePackageRelativePath(report.relativeAudioPath) == false
                    || report.relativeAudioPath.hasPrefix("Audio/Calibration/") == false {
                    errors.append("Capture preflight \(report.id) has an unsafe audio path.")
                }
            }
            if let payloadPath = project.navigatorPayloadRelativePath,
               isSafePackageRelativePath(payloadPath) == false || payloadPath.hasPrefix("Manifests/") == false {
                errors.append("The frozen Navigator payload path is unsafe.")
            }
        } catch {
            errors.append("project.json cannot be decoded: \(error.localizedDescription)")
            throw OrgRecError.invalidProject(errors.last!)
        }
        var verified = 0
        if Set(manifest.files.map(\.relativePath)).count != manifest.files.count {
            errors.append("The payload index contains duplicate paths.")
        }
        for entry in manifest.files {
            guard isSafePackageRelativePath(entry.relativePath) else {
                errors.append("Unsafe package path: \(entry.relativePath)")
                continue
            }
            let url = packageURL.appendingPathComponent(entry.relativePath)
            let resolvedURL = url.standardizedFileURL.resolvingSymlinksInPath()
            guard resolvedURL.path.hasPrefix(resolvedRoot.path + "/") else {
                errors.append("Payload resolves outside the IAD package: \(entry.relativePath)")
                continue
            }
            guard fm.fileExists(atPath: url.path) else {
                errors.append("Missing payload: \(entry.relativePath)")
                continue
            }
            let attributes = try fm.attributesOfItem(atPath: url.path)
            if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                errors.append("Symbolic links are not allowed in IAD payloads: \(entry.relativePath)")
                continue
            }
            if entry.byteSize < 0 || entry.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil
                || entry.mediaType.isEmpty || entry.role.isEmpty {
                errors.append("Invalid payload descriptor: \(entry.relativePath)")
            }
            let actualSize = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? -1)
            if actualSize != entry.byteSize { errors.append("Byte-size mismatch: \(entry.relativePath)") }
            let actualHash = try sha256(of: url)
            if actualHash != entry.sha256 { errors.append("SHA-256 mismatch: \(entry.relativePath)") }
            if manifest.integrity[entry.relativePath] != entry.sha256 {
                errors.append("Integrity index mismatch: \(entry.relativePath)")
            }
            verified += 1
        }
        let listed = Set(manifest.files.map(\.relativePath))
        if listed != Set(manifest.integrity.keys) {
            errors.append("The payload inventory and integrity index contain different paths.")
        }
        for path in manifest.manifests.all where listed.contains(path) == false {
            errors.append("JSONL manifest is absent from the payload index: \(path)")
        }
        if listed.contains("project.json") == false { errors.append("project.json is not indexed.") }
        if listed.contains("modavis-snapshot.json") == false { errors.append("modavis-snapshot.json is not indexed.") }
        if manifest.integrity["modavis-snapshot.json"] != manifest.modavisSnapshotSHA256 {
            errors.append("The declared MODAVIS snapshot hash is not in the integrity index.")
        }
        if listed.contains("modavis-navigator-payload.json"),
           manifest.integrity["modavis-navigator-payload.json"] != manifest.navigatorPayloadSHA256 {
            errors.append("The frozen Navigator payload hash is inconsistent.")
        }
        let sessions: [IADSessionRecord] = decodeLines(packageURL, manifest.manifests.sessions, errors: &errors)
        let takes: [IADTakeRecord] = decodeLines(packageURL, manifest.manifests.takes, errors: &errors)
        let files: [IADFileRecord] = decodeLines(packageURL, manifest.manifests.files, errors: &errors)
        let channels: [IADChannelRecord] = decodeLines(packageURL, manifest.manifests.channels, errors: &errors)
        let segments: [IADSegmentRecord] = decodeLines(packageURL, manifest.manifests.segments, errors: &errors)
        let devices: [IADDeviceRecord] = decodeLines(packageURL, manifest.manifests.devices, errors: &errors)
        let registrations: [IADRegistrationRecord] = decodeLines(packageURL, manifest.manifests.registrations, errors: &errors)
        let observations: [IADObservationRecord] = decodeLines(packageURL, manifest.manifests.observations, errors: &errors)
        let paradata: [IADParadataRecord] = decodeLines(packageURL, manifest.manifests.paradata, errors: &errors)
        let calibrations: [IADCalibrationRecord] = manifest.manifests.calibrations.map {
            decodeLines(packageURL, $0, errors: &errors)
        } ?? []
        let temperamentAnalyses: [IADTemperamentAnalysisRecord] = manifest.manifests.temperamentAnalyses.map {
            decodeLines(packageURL, $0, errors: &errors)
        } ?? []
        let actualCounts = IADObjectCounts(
            sessions: sessions.count, takes: takes.count, files: files.count,
            channels: channels.count, segments: segments.count, devices: devices.count,
            registrations: registrations.count, observations: observations.count, paradata: paradata.count,
            calibrations: manifest.manifests.calibrations == nil ? nil : calibrations.count,
            temperamentAnalyses: manifest.manifests.temperamentAnalyses == nil ? nil : temperamentAnalyses.count
        )
        if actualCounts != manifest.counts { errors.append("The declared object counts do not match the JSONL indexes.") }
        if sessions.contains(where: { $0.projectionStatus != IADContract.projectionMode || $0.targetTables != ["prov.activity", "audio.recording_session"] }) {
            errors.append("A session record has invalid MODAVIS projection semantics.")
        }
        if sessions.flatMap({ $0.capturePreflightReports ?? [] }).contains(where: {
            $0.projectionStatus != IADContract.projectionMode || $0.targetTables.contains("measurement.observation") == false
        }) {
            errors.append("A capture-preflight record has invalid MODAVIS projection semantics.")
        }
        if files.contains(where: { $0.projectionStatus != IADContract.projectionMode || $0.targetTables.contains("media.bitstream") == false || isSafePackageRelativePath($0.relativePath) == false }) {
            errors.append("A media record has invalid MODAVIS projection semantics or path.")
        }
        if takes.contains(where: { $0.projectionStatus != IADContract.projectionMode || $0.targetTable != "audio.recording_take" || $0.takeNumber < 1 }) {
            errors.append("A take record has invalid MODAVIS projection semantics.")
        }
        if channels.contains(where: { $0.projectionStatus != IADContract.projectionMode || $0.targetTable != "audio.channel" || $0.channelNumber < 1 }) {
            errors.append("A channel record has invalid MODAVIS projection semantics.")
        }
        if segments.contains(where: { $0.projectionStatus != IADContract.projectionMode || $0.targetTable != "audio.segment" }) {
            errors.append("A segment record has invalid MODAVIS projection semantics.")
        }
        if devices.contains(where: { $0.projectionStatus != IADContract.projectionMode }) || registrations.contains(where: { $0.projectionStatus != IADContract.projectionMode }) {
            errors.append("A device or registration record does not declare candidate projection semantics.")
        }
        if observations.contains(where: {
            $0.projectionStatus != IADContract.projectionMode
                || $0.targetTable != "measurement.observation"
                || $0.numericValue.isFinite == false
                || ($0.uncertainty.map { $0.isFinite == false || $0 < 0 } ?? false)
                || ($0.confidence.map { !(0...1).contains($0) } ?? false)
        }) {
            errors.append("An observation record has invalid MODAVIS projection semantics.")
        }
        if paradata.contains(where: { $0.projectionStatus != IADContract.projectionMode || $0.targetTable != "paradata.generic" }) {
            errors.append("A paradata record has invalid MODAVIS projection semantics.")
        }
        if calibrations.contains(where: { $0.projectionStatus != IADContract.projectionMode }) {
            errors.append("A tuning-calibration record does not declare candidate projection semantics.")
        }
        if temperamentAnalyses.contains(where: { $0.projectionStatus != IADContract.projectionMode }) {
            errors.append("A temperament-analysis record does not declare candidate projection semantics.")
        }
        let sessionIDs = Set(sessions.map(\.localSessionID))
        let fileIDs = Set(files.map(\.localFileID))
        let takeIDs = Set(takes.map(\.localTakeID))
        let preflightIDs = sessions.flatMap { $0.capturePreflightReports ?? [] }.map(\.localPreflightID)
        if sessionIDs.count != sessions.count { errors.append("Duplicate local session identifier.") }
        if fileIDs.count != files.count { errors.append("Duplicate local file identifier.") }
        if takeIDs.count != takes.count { errors.append("Duplicate local take identifier.") }
        if Set(preflightIDs).count != preflightIDs.count { errors.append("Duplicate capture-preflight identifier.") }
        if Set(takes.map { "\($0.localSessionID.uuidString):\($0.roadmapItemID.uuidString):\($0.takeNumber)" }).count != takes.count {
            errors.append("Take numbers are not unique within their recording-session and roadmap-item scope.")
        }
        if Set(files.map(\.relativePath)).count != files.count { errors.append("Media records contain duplicate paths.") }
        if Set(channels.map(\.localChannelID)).count != channels.count { errors.append("Duplicate channel identifier.") }
        if Set(segments.map(\.localSegmentID)).count != segments.count { errors.append("Duplicate segment identifier.") }
        if Set(observations.map(\.localObservationID)).count != observations.count { errors.append("Duplicate observation identifier.") }
        if Set(paradata.map(\.localParadataID)).count != paradata.count { errors.append("Duplicate paradata identifier.") }
        if Set(devices.map(\.localDeviceID)).count != devices.count { errors.append("Duplicate device identifier.") }
        if Set(registrations.map(\.localRegistrationID)).count != registrations.count { errors.append("Duplicate registration identifier.") }
        if Set(calibrations.map(\.localCalibrationID)).count != calibrations.count { errors.append("Duplicate tuning-calibration identifier.") }
        if Set(temperamentAnalyses.map(\.localAnalysisID)).count != temperamentAnalyses.count { errors.append("Duplicate temperament-analysis identifier.") }
        let filesByID = Dictionary(files.map { ($0.localFileID, $0) }, uniquingKeysWith: { first, _ in first })
        let registrationIDs = Set(registrations.map(\.localRegistrationID))
        let setupIDs = Set(project.setups.map(\.id))
        for take in takes {
            if sessionIDs.contains(take.localSessionID) == false { errors.append("Take \(take.localTakeID) references an unknown session.") }
            if fileIDs.contains(take.localFileID) == false { errors.append("Take \(take.localTakeID) references an unknown media file.") }
            if project.takes.contains(where: { $0.id == take.localTakeID }) == false { errors.append("Take \(take.localTakeID) is absent from project.json.") }
            if take.componentLocator.snapshotSHA256 != manifest.navigatorPayloadSHA256 { errors.append("Take \(take.localTakeID) is bound to another Navigator snapshot.") }
            if take.equivalentComponentLocators?.contains(where: { $0.snapshotSHA256 != manifest.navigatorPayloadSHA256 }) == true {
                errors.append("Take \(take.localTakeID) has an equivalent component bound to another Navigator snapshot.")
            }
            if let setupID = take.localMicrophoneSetupID, setupIDs.contains(setupID) == false { errors.append("Take \(take.localTakeID) references an unknown microphone setup.") }
            if let registrationID = take.localRegistrationID, registrationIDs.contains(registrationID) == false { errors.append("Take \(take.localTakeID) references an unknown registration.") }
        }
        for file in files {
            if manifest.integrity[file.relativePath] != file.sha256 { errors.append("Media record hash is not in the integrity index: \(file.relativePath)") }
            if let descriptor = manifest.files.first(where: { $0.relativePath == file.relativePath }),
               descriptor.byteSize != file.byteSize || descriptor.sha256 != file.sha256 {
                errors.append("Media and payload descriptors differ: \(file.relativePath)")
            }
        }
        for channel in channels {
            guard let file = filesByID[channel.localFileID] else {
                errors.append("Channel \(channel.localChannelID) references an unknown media file.")
                continue
            }
            if channel.channelNumber > file.channelCount { errors.append("Channel \(channel.localChannelID) exceeds its media channel count.") }
        }
        for segment in segments {
            if fileIDs.contains(segment.localFileID) == false { errors.append("Segment \(segment.localSegmentID) references an unknown media file.") }
            if segment.startSeconds < 0 || segment.endSeconds <= segment.startSeconds { errors.append("Segment \(segment.localSegmentID) has invalid bounds.") }
        }
        for observation in observations where takeIDs.contains(observation.localTakeID) == false {
            errors.append("Observation \(observation.localObservationID) references an unknown take.")
        }
        for item in paradata where takeIDs.contains(item.localTakeID) == false {
            errors.append("Paradata \(item.localParadataID) references an unknown take.")
        }
        for calibration in calibrations {
            if sessionIDs.contains(calibration.calibration.sessionID) == false {
                errors.append("Calibration \(calibration.localCalibrationID) references an unknown session.")
            }
            if project.tuningCalibrations?.contains(where: { $0.id == calibration.localCalibrationID }) != true {
                errors.append("Calibration \(calibration.localCalibrationID) is absent from project.json.")
            }
            if let audioPath = calibration.audioRelativePath, listed.contains(audioPath) == false {
                errors.append("Calibration \(calibration.localCalibrationID) references unindexed audio.")
            }
        }
        for session in sessions {
            for preflight in session.capturePreflightReports ?? [] {
                if preflight.report.sessionID != session.localSessionID {
                    errors.append("Capture preflight \(preflight.localPreflightID) references another session.")
                }
                if preflight.localPreflightID != preflight.report.id {
                    errors.append("Capture preflight \(preflight.localPreflightID) has an inconsistent report identifier.")
                }
                if listed.contains(preflight.audioRelativePath) == false {
                    errors.append("Capture preflight \(preflight.localPreflightID) references unindexed audio.")
                }
                if let file = filesByID[preflight.localPreflightID],
                   file.relativePath != preflight.audioRelativePath || file.sha256 != preflight.report.sha256 {
                    errors.append("Capture preflight \(preflight.localPreflightID) media does not match its report.")
                } else if filesByID[preflight.localPreflightID] == nil {
                    errors.append("Capture preflight \(preflight.localPreflightID) has no media record.")
                }
                if project.recordingSessions?.first(where: { $0.id == session.localSessionID })?
                    .capturePreflightReports?.contains(where: { $0.id == preflight.localPreflightID }) != true {
                    errors.append("Capture preflight \(preflight.localPreflightID) is absent from project.json.")
                }
            }
        }
        for record in temperamentAnalyses {
            if project.temperamentAnalyses?.contains(where: { $0.id == record.localAnalysisID }) != true {
                errors.append("Temperament analysis \(record.localAnalysisID) is absent from project.json.")
            }
            if record.analysis.observations.count < 8 && record.analysis.inferenceStrength != .insufficient {
                errors.append("Temperament analysis \(record.localAnalysisID) overstates sparse evidence.")
            }
        }
        let captureURL = packageURL.appendingPathComponent("capture-package.json")
        if fm.fileExists(atPath: captureURL.path) {
            do {
                let capture = try OrgRecCoding.decoder.decode(CapturePackageManifest.self, from: Data(contentsOf: captureURL))
                if capture.projectID != manifest.projectID { errors.append("The capture and IAD project identifiers differ.") }
                if capture.iadManifestSHA256 != (try sha256(of: manifestURL)) { errors.append("The capture package has an invalid IAD manifest hash.") }
                if capture.iadManifestRelativePath != IADContract.manifestFilename { errors.append("The capture package points to an unexpected IAD manifest.") }
                for entry in capture.takes {
                    let paths = [entry.audioRelativePath, entry.analysisRelativePath, entry.annotationRelativePath]
                        .compactMap { $0 } + entry.derivedRelativePaths
                    if paths.contains(where: { isSafePackageRelativePath($0) == false }) {
                        errors.append("Capture take \(entry.takeID) contains an unsafe path.")
                    }
                    if takeIDs.contains(entry.takeID) == false { errors.append("Capture take \(entry.takeID) is absent from the IAD take index.") }
                    if manifest.integrity[entry.audioRelativePath] != entry.audioSHA256 {
                        errors.append("Capture take \(entry.takeID) has an inconsistent audio hash.")
                    }
                }
            } catch {
                errors.append("capture-package.json cannot be decoded: \(error.localizedDescription)")
            }
        } else {
            errors.append("capture-package.json is missing.")
        }
        if manifest.organ.mdvsID.hasPrefix("LOCAL:") { warnings.append("The organ still has a local, non-MODAVIS identity.") }
        return IADValidationReport(
            contractVersion: manifest.contractVersion,
            checkedAt: .now,
            errors: errors,
            warnings: warnings,
            verifiedFileCount: verified
        )
    }

    private static func decodeLines<T: Decodable>(
        _ packageURL: URL,
        _ relativePath: String,
        errors: inout [String]
    ) -> [T] {
        guard isSafePackageRelativePath(relativePath) else {
            errors.append("Unsafe JSONL path: \(relativePath)")
            return []
        }
        do {
            let data = try Data(contentsOf: packageURL.appendingPathComponent(relativePath))
            let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
            return try lines.enumerated().map { index, line in
                do { return try OrgRecCoding.decoder.decode(T.self, from: Data(line)) }
                catch { throw OrgRecError.invalidProject("\(relativePath), line \(index + 1): \(error.localizedDescription)") }
            }
        } catch {
            errors.append(error.localizedDescription)
            return []
        }
    }
}

public actor IADPackageImporter {
    public init() {}

    public func importPackage(from source: URL, to destination: URL) async throws -> OrgRecProject {
        let report = try IADPackageValidator.validate(packageURL: source)
        guard report.isValid else {
            throw OrgRecError.invalidProject("IAD validation failed: " + report.errors.prefix(3).joined(separator: "; "))
        }
        let fm = FileManager.default
        guard fm.fileExists(atPath: destination.path) == false else {
            throw OrgRecError.invalidProject("The import destination already exists.")
        }
        let project = try OrgRecCoding.decoder.decode(
            OrgRecProject.self,
            from: Data(contentsOf: source.appendingPathComponent("project.json"))
        )
        let capture = try OrgRecCoding.decoder.decode(
            CapturePackageManifest.self,
            from: Data(contentsOf: source.appendingPathComponent("capture-package.json"))
        )
        do {
            try await ProjectStore().createPackage(at: destination, project: project)
            let importedMetadata = destination.appendingPathComponent("Manifests/ImportedIAD", isDirectory: true)
            try fm.createDirectory(at: importedMetadata, withIntermediateDirectories: true)
            for name in [IADContract.manifestFilename, "capture-package.json", "consistency-report.json"] {
                let sourceFile = source.appendingPathComponent(name)
                if fm.fileExists(atPath: sourceFile.path) {
                    try fm.copyItem(at: sourceFile, to: importedMetadata.appendingPathComponent(name))
                }
            }
            let projectionSource = source.appendingPathComponent("manifests", isDirectory: true)
            if fm.fileExists(atPath: projectionSource.path) {
                try fm.copyItem(at: projectionSource, to: importedMetadata.appendingPathComponent("manifests", isDirectory: true))
            }
            if let payloadPath = project.navigatorPayloadRelativePath,
               fm.fileExists(atPath: source.appendingPathComponent("modavis-navigator-payload.json").path) {
                let target = destination.appendingPathComponent(payloadPath)
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source.appendingPathComponent("modavis-navigator-payload.json"), to: target)
            }
            for entry in capture.takes {
                guard let take = project.takes.first(where: { $0.id == entry.takeID }) else { continue }
                guard isSafePackageRelativePath(entry.audioRelativePath),
                      isSafePackageRelativePath(take.relativeAudioPath),
                      take.relativeAudioPath.hasPrefix("Audio/Originals/") else {
                    throw OrgRecError.invalidProject("The package contains an unsafe audio path.")
                }
                let audioTarget = destination.appendingPathComponent(take.relativeAudioPath)
                try fm.createDirectory(at: audioTarget.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source.appendingPathComponent(entry.audioRelativePath), to: audioTarget)
                if let analysisPath = entry.analysisRelativePath, isSafePackageRelativePath(analysisPath) {
                    try fm.copyItem(
                        at: source.appendingPathComponent(analysisPath),
                        to: destination.appendingPathComponent("Analysis/Pitch/\(entry.takeID.uuidString.lowercased()).json")
                    )
                }
                for path in entry.derivedRelativePaths {
                    guard isSafePackageRelativePath(path) else {
                        throw OrgRecError.invalidProject("The package contains an unsafe derivative path.")
                    }
                    if path.hasSuffix(".bwf.json") {
                        try fm.copyItem(
                            at: source.appendingPathComponent(path),
                            to: audioTarget.deletingPathExtension().appendingPathExtension("bwf.json")
                        )
                    } else if path.hasSuffix("-waveform.json") || path.hasSuffix("-spectrogram.json") {
                        let target = destination.appendingPathComponent("Analysis/Derivatives/\(URL(fileURLWithPath: path).lastPathComponent)")
                        try fm.copyItem(at: source.appendingPathComponent(path), to: target)
                    }
                }
            }
            for longTake in project.longTakeSources ?? [] {
                guard isSafePackageRelativePath(longTake.relativeAudioPath),
                      longTake.relativeAudioPath.hasPrefix("Audio/LongTakes/") else {
                    throw OrgRecError.invalidProject("The package contains an unsafe long-take source path.")
                }
                let sourceExtension = URL(fileURLWithPath: longTake.relativeAudioPath).pathExtension.isEmpty
                    ? "wav"
                    : URL(fileURLWithPath: longTake.relativeAudioPath).pathExtension.lowercased()
                let exportedPath = "audio/long-take-\(longTake.id.uuidString.lowercased()).\(sourceExtension)"
                guard capture.integrity[exportedPath] == longTake.sha256,
                      fm.fileExists(atPath: source.appendingPathComponent(exportedPath).path) else {
                    throw OrgRecError.invalidProject("Long-take source \(longTake.id.uuidString) is missing or has the wrong checksum.")
                }
                let target = destination.appendingPathComponent(longTake.relativeAudioPath)
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source.appendingPathComponent(exportedPath), to: target)
            }
            for calibration in project.tuningCalibrations ?? [] {
                guard let localPath = calibration.relativeAudioPath else { continue }
                let exportedPath = "audio/calibration-\(calibration.id.uuidString.lowercased()).wav"
                guard capture.integrity[exportedPath] != nil,
                      fm.fileExists(atPath: source.appendingPathComponent(exportedPath).path) else {
                    if calibration.status == .accepted {
                        throw OrgRecError.invalidProject("Accepted calibration audio is missing from the IAD package.")
                    }
                    continue
                }
                let target = destination.appendingPathComponent(localPath)
                try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: source.appendingPathComponent(exportedPath), to: target)
            }
            for session in project.recordingSessions ?? [] {
                for preflight in session.capturePreflightReports ?? [] {
                    guard preflight.sessionID == session.id,
                          isSafePackageRelativePath(preflight.relativeAudioPath),
                          preflight.relativeAudioPath.hasPrefix("Audio/Calibration/") else {
                        throw OrgRecError.invalidProject("The package contains an unsafe or misbound capture-preflight record.")
                    }
                    let fileExtension = URL(fileURLWithPath: preflight.relativeAudioPath).pathExtension.isEmpty
                        ? "wav"
                        : URL(fileURLWithPath: preflight.relativeAudioPath).pathExtension.lowercased()
                    let exportedPath = "audio/preflight-\(preflight.id.uuidString.lowercased()).\(fileExtension)"
                    guard capture.integrity[exportedPath] == preflight.sha256,
                          fm.fileExists(atPath: source.appendingPathComponent(exportedPath).path) else {
                        throw OrgRecError.invalidProject("Capture-preflight audio \(preflight.id.uuidString) is missing or has the wrong checksum.")
                    }
                    let target = destination.appendingPathComponent(preflight.relativeAudioPath)
                    try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try fm.copyItem(at: source.appendingPathComponent(exportedPath), to: target)
                }
            }
            try OrgRecCoding.encoder.encode(report).write(
                to: destination.appendingPathComponent("Manifests/iad-import-validation.json"),
                options: .atomic
            )
            return project
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }
    }
}
