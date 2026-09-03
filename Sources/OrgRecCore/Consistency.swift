import Foundation

public struct RecordingSession: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var sessionCode: String
    public var startedAt: Date
    public var endedAt: Date?
    public var operatorName: String
    public var institution: String
    public var purpose: String
    public var rightsStatement: String
    public var timezoneIdentifier: String
    public var clockSource: String
    public var venueCondition: String
    public var environment: EnvironmentReading
    public var notes: String
    public var tuningCalibrationID: UUID?
    public var sessionPlanID: UUID?
    public var sessionPlanRevision: Int?
    public var noiseContextAssessment: NoiseContextAssessment?
    public var noiseObservations: [NoiseObservation]?
    /// Immutable, session-scoped evidence that the exact interface and
    /// microphone-setup revision were rehearsed before field capture.
    public var capturePreflightReports: [CapturePreflightReport]?

    public init(
        id: UUID = UUID(),
        sessionCode: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        operatorName: String = "",
        institution: String = "",
        purpose: String = "Pipe-organ acoustic documentation",
        rightsStatement: String = "",
        timezoneIdentifier: String = TimeZone.current.identifier,
        clockSource: String = "macOS system clock",
        venueCondition: String = "",
        environment: EnvironmentReading = EnvironmentReading(),
        notes: String = "",
        tuningCalibrationID: UUID? = nil,
        sessionPlanID: UUID? = nil,
        sessionPlanRevision: Int? = nil,
        noiseContextAssessment: NoiseContextAssessment? = nil,
        noiseObservations: [NoiseObservation]? = nil,
        capturePreflightReports: [CapturePreflightReport]? = nil
    ) {
        self.id = id
        self.sessionCode = sessionCode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.operatorName = operatorName
        self.institution = institution
        self.purpose = purpose
        self.rightsStatement = rightsStatement
        self.timezoneIdentifier = timezoneIdentifier
        self.clockSource = clockSource
        self.venueCondition = venueCondition
        self.environment = environment
        self.notes = notes
        self.tuningCalibrationID = tuningCalibrationID
        self.sessionPlanID = sessionPlanID
        self.sessionPlanRevision = sessionPlanRevision
        self.noiseContextAssessment = noiseContextAssessment
        self.noiseObservations = noiseObservations
        self.capturePreflightReports = capturePreflightReports
    }
}

public struct TakeProvenanceSnapshot: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var sessionID: UUID
    public var sessionCode: String
    public var operatorName: String
    public var institution: String
    public var purpose: String
    public var rightsStatement: String
    public var timezoneIdentifier: String
    public var clockSource: String
    public var venueCondition: String
    public var environment: EnvironmentReading
    public var recipe: CaptureRecipe
    public var microphoneSetup: MicrophoneSetup?
    public var registration: RegistrationState?
    public var component: OrganComponent
    public var releaseBinding: ReleaseBinding
    public var navigatorPayloadSHA256: String
    public var organMDVSID: String
    public var applicationVersion: String
    public var tuningCalibration: TuningCalibration?
    public var expectedFrequencyHz: Double?
    public var physicalSoundTargetID: String?
    public var activationRoutes: [PhysicalActivationRoute]?
    public var actualActivationRouteID: String?
    public var sessionPlanID: UUID?
    public var sessionPlanRevision: Int?
    public var noiseContextAssessment: NoiseContextAssessment?
    public var instrumentNoiseProtocol: InstrumentNoiseCaptureProtocol?
    public var soundingTargetDefinition: SoundingTargetDefinition?
    public var captureStateSnapshot: CaptureStateSnapshot?
    public var controlBindings: [ControlBinding]?
    public var complexCaptureProtocol: ComplexCaptureProtocol?
    public var spatialGeometrySnapshot: SpatialGeometrySnapshot?
    public var spatialAcousticProtocol: SpatialAcousticCaptureProtocol?
    public var effectAnalysisProtocol: NonPitchedEffectAnalysisProtocol?

    public init(
        contractVersion: String = "orgrec.take-provenance/v1",
        session: RecordingSession,
        recipe: CaptureRecipe,
        microphoneSetup: MicrophoneSetup?,
        registration: RegistrationState?,
        component: OrganComponent,
        releaseBinding: ReleaseBinding,
        navigatorPayloadSHA256: String,
        organMDVSID: String,
        applicationVersion: String = OrgRecSoftware.current.displayName,
        tuningCalibration: TuningCalibration? = nil,
        expectedFrequencyHz: Double? = nil,
        physicalSoundTargetID: String? = nil,
        activationRoutes: [PhysicalActivationRoute]? = nil,
        actualActivationRouteID: String? = nil,
        instrumentNoiseProtocol: InstrumentNoiseCaptureProtocol? = nil,
        soundingTargetDefinition: SoundingTargetDefinition? = nil,
        captureStateSnapshot: CaptureStateSnapshot? = nil,
        controlBindings: [ControlBinding]? = nil,
        complexCaptureProtocol: ComplexCaptureProtocol? = nil,
        spatialGeometrySnapshot: SpatialGeometrySnapshot? = nil,
        spatialAcousticProtocol: SpatialAcousticCaptureProtocol? = nil,
        effectAnalysisProtocol: NonPitchedEffectAnalysisProtocol? = nil
    ) {
        self.contractVersion = contractVersion
        self.sessionID = session.id
        self.sessionCode = session.sessionCode
        self.operatorName = session.operatorName
        self.institution = session.institution
        self.purpose = session.purpose
        self.rightsStatement = session.rightsStatement
        self.timezoneIdentifier = session.timezoneIdentifier
        self.clockSource = session.clockSource
        self.venueCondition = session.venueCondition
        self.environment = session.environment
        self.recipe = recipe
        self.microphoneSetup = microphoneSetup
        self.registration = registration
        self.component = component
        self.releaseBinding = releaseBinding
        self.navigatorPayloadSHA256 = navigatorPayloadSHA256
        self.organMDVSID = organMDVSID
        self.applicationVersion = applicationVersion
        self.tuningCalibration = tuningCalibration
        self.expectedFrequencyHz = expectedFrequencyHz
        self.physicalSoundTargetID = physicalSoundTargetID
        self.activationRoutes = activationRoutes
        self.actualActivationRouteID = actualActivationRouteID
        self.sessionPlanID = session.sessionPlanID
        self.sessionPlanRevision = session.sessionPlanRevision
        self.noiseContextAssessment = session.noiseContextAssessment
        self.instrumentNoiseProtocol = instrumentNoiseProtocol
        self.soundingTargetDefinition = soundingTargetDefinition
        self.captureStateSnapshot = captureStateSnapshot
        self.controlBindings = controlBindings
        self.complexCaptureProtocol = complexCaptureProtocol
        self.spatialGeometrySnapshot = spatialGeometrySnapshot
        self.spatialAcousticProtocol = spatialAcousticProtocol
        self.effectAnalysisProtocol = effectAnalysisProtocol
    }
}

public struct ReviewDecision: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var decidedAt: Date
    public var decision: String
    public var author: String
    public var reason: String
    public var analysisAlgorithmVersion: String?

    public init(
        id: UUID = UUID(),
        decidedAt: Date = .now,
        decision: String,
        author: String,
        reason: String,
        analysisAlgorithmVersion: String? = nil
    ) {
        self.id = id
        self.decidedAt = decidedAt
        self.decision = decision
        self.author = author
        self.reason = reason
        self.analysisAlgorithmVersion = analysisAlgorithmVersion
    }
}

public enum ConsistencySeverity: String, Codable, CaseIterable, Sendable {
    case blocker
    case warning
    case information
}

public enum ConsistencyScope: String, Codable, Sendable {
    case modavis
    case roadmap
    case session
    case setup
    case recording
    case analysis
    case integrity
    case review
}

public struct ConsistencyIssue: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var severity: ConsistencySeverity
    public var scope: ConsistencyScope
    public var title: String
    public var detail: String
    public var remediation: String
    public var roadmapItemID: UUID?
    public var takeID: UUID?

    public init(
        id: String,
        severity: ConsistencySeverity,
        scope: ConsistencyScope,
        title: String,
        detail: String,
        remediation: String,
        roadmapItemID: UUID? = nil,
        takeID: UUID? = nil
    ) {
        self.id = id
        self.severity = severity
        self.scope = scope
        self.title = title
        self.detail = detail
        self.remediation = remediation
        self.roadmapItemID = roadmapItemID
        self.takeID = takeID
    }
}

public struct ProjectConsistencyReport: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var generatedAt: Date
    public var projectID: UUID
    public var score: Int
    public var checksPerformed: Int
    public var issues: [ConsistencyIssue]

    public init(
        contractVersion: String = "orgrec.consistency-report/v1",
        generatedAt: Date = .now,
        projectID: UUID,
        score: Int,
        checksPerformed: Int,
        issues: [ConsistencyIssue]
    ) {
        self.contractVersion = contractVersion
        self.generatedAt = generatedAt
        self.projectID = projectID
        self.score = score
        self.checksPerformed = checksPerformed
        self.issues = issues
    }

    public var blockerCount: Int { issues.filter { $0.severity == .blocker }.count }
    public var warningCount: Int { issues.filter { $0.severity == .warning }.count }
    public var informationCount: Int { issues.filter { $0.severity == .information }.count }
    public var isExportReady: Bool { blockerCount == 0 }
}

public enum ProjectConsistencyAuditor {
    public static func captureReadiness(project: OrgRecProject, item: RoadmapItem?) -> [ConsistencyIssue] {
        var issues: [ConsistencyIssue] = []
        guard let item else {
            return [issue("readiness.no-item", .blocker, .roadmap, "No capture selected", "A roadmap item is required before recording.", "Choose the next missing roadmap item.")]
        }
        guard let session = project.recordingSessions?.last(where: { $0.endedAt == nil }) else {
            issues.append(issue("readiness.no-session", .blocker, .session, "No active recording session", "The take would have no operator or session context.", "Create or resume a session in Field QA.", item: item.id))
            return issues
        }
        if session.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue("readiness.operator", .blocker, .session, "Operator is missing", "Scientific responsibility for the capture is not documented.", "Enter the operator in Field QA.", item: item.id))
        }
        if session.purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue("readiness.purpose", .warning, .session, "Session purpose is missing", "The intended use of the recording is unclear.", "Document the campaign purpose in Field QA.", item: item.id))
        }
        if session.environment.temperatureCelsius == nil || session.environment.relativeHumidityPercent == nil {
            issues.append(issue("readiness.environment", .warning, .session, "Temperature or humidity is missing", "Pipe pitch and decay are sensitive to the recording environment.", "Measure and enter temperature and relative humidity.", item: item.id))
        }
        let acceptedCalibration = session.tuningCalibrationID.flatMap { calibrationID in
            project.tuningCalibrations?.first { $0.id == calibrationID && $0.status == .accepted }
        }
        let requiresPitchCalibration: Bool
        if let protocolSnapshot = item.complexCaptureProtocol {
            switch protocolSnapshot.kind {
            case .operationalBaseline, .discreteShutterMapping:
                requiresPitchCalibration = false
            case .tremulantResponse:
                requiresPitchCalibration = true
            case .physicalActuatorResponse, .declarativeProcess:
                requiresPitchCalibration = item.component.midiNote != nil
                    || item.component.expectedFrequencyHz != nil
                    || item.soundingTargetDefinition?.family == .tonalPercussion
                    || item.soundingTargetDefinition?.family == .pipeSpeech
            }
        } else {
            requiresPitchCalibration = item.instrumentNoiseProtocol == nil
                && (item.soundingTargetDefinition == nil || item.soundingTargetDefinition?.family == .tonalPercussion || item.soundingTargetDefinition?.family == .pipeSpeech)
        }
        if acceptedCalibration == nil && requiresPitchCalibration {
            let prior = project.documentedPitchStandard.map {
                "MODAVIS documents A4 = \($0.frequencyHz.formatted(.number.precision(.fractionLength(2)))) Hz, but this is not a field measurement."
            } ?? "MODAVIS does not provide a usable documented A4 value."
            issues.append(issue(
                "readiness.pitch-calibration",
                .blocker,
                .session,
                "A4 field calibration is required",
                "\(prior) Expected-frequency and wrong-key checks require a session-scoped measurement.",
                "Open Initialize, record a stable A4 on a unison 8′ stop, review the estimate, and accept it.",
                item: item.id
            ))
        }
        guard let setupID = item.setupID,
              let setup = project.setups.first(where: { $0.id == setupID }) else {
            issues.append(issue("readiness.setup", .blocker, .setup, "No microphone setup assigned", "The take cannot be reproduced without geometry and channel routing.", "Assign a versioned setup to this technique.", item: item.id))
            return issues
        }
        if setup.placements.isEmpty {
            issues.append(issue("readiness.placements", .blocker, .setup, "Microphone placement is empty", "No channel has a documented microphone position.", "Add at least one microphone placement to setup revision \(setup.revision).", item: item.id))
        }
        let channels = setup.placements.map(\.channelNumber)
        if Set(channels).count != channels.count || channels.contains(where: { $0 < 1 }) {
            issues.append(issue("readiness.channels", .blocker, .setup, "Invalid channel routing", "Placement channel numbers must be unique and positive.", "Correct duplicate or invalid channel numbers.", item: item.id))
        }
        let referenceChannelNumber = setup.referenceChannelNumber ?? 1
        if referenceChannelNumber < 1 || channels.contains(referenceChannelNumber) == false {
            let documentedChannels = channels.sorted().map(String.init).joined(separator: ", ")
            issues.append(issue(
                "readiness.reference-channel",
                .blocker,
                .setup,
                "Invalid analysis reference channel",
                "Setup revision \(setup.revision) selects channel \(referenceChannelNumber), but its documented placement channels are \(documentedChannels.isEmpty ? "none" : documentedChannels).",
                "Choose a positive reference channel that has a documented microphone placement.",
                item: item.id
            ))
        }
        if setup.documentationPaths.isEmpty {
            issues.append(issue("readiness.setup-docs", .warning, .setup, "Setup has no photograph or plan", "Coordinates are present, but their field realization is not visually documented.", "Attach a setup photograph or floor plan.", item: item.id))
        }
        if let registrationID = item.registrationID,
           project.registrations.contains(where: { $0.id == registrationID }) == false {
            issues.append(issue("readiness.registration", .blocker, .roadmap, "Registration snapshot is missing", "The requested stops and controls cannot be reconstructed.", "Repair or regenerate this roadmap item.", item: item.id))
        }
        if item.component.locator.snapshotSHA256 != project.snapshot.payloadSHA256 {
            issues.append(issue("readiness.locator", .blocker, .modavis, "Component binding is stale", "The roadmap locator is not bound to the active frozen MODAVIS payload.", "Regenerate the roadmap from the active specification.", item: item.id))
        }
        if item.activationRoutes?.contains(where: { $0.component.locator.snapshotSHA256 != project.snapshot.payloadSHA256 }) == true {
            issues.append(issue("readiness.physical-routes", .blocker, .modavis, "Shared-pipe route binding is stale", "An equivalent console address belongs to another frozen Navigator snapshot.", "Review or regenerate the physical-pipe grouping.", item: item.id))
        }
        if project.roadmapCompilation?.tuningPitchAssumed == true && acceptedCalibration == nil && requiresPitchCalibration {
            issues.append(issue("readiness.pitch-assumed", .warning, .modavis, "Reference pitch is assumed", "Expected frequencies use A4 = 440 Hz because MODAVIS had no documented pitch.", "Record a reference pipe and review CREPE deviation before batch capture.", item: item.id))
        }
        if let profile = item.instrumentNoiseProtocol?.actuationProfile,
           profile.validationIssues.isEmpty == false {
            issues.append(issue(
                "readiness.actuation-curve",
                .blocker,
                .roadmap,
                "Actuation profile is invalid",
                profile.validationIssues.joined(separator: " "),
                "Correct the commanded action curve in the instrument-noise planner before recording.",
                item: item.id
            ))
        }
        if let protocolSnapshot = item.complexCaptureProtocol,
           protocolSnapshot.validationIssues.isEmpty == false {
            issues.append(issue(
                "readiness.complex-capture",
                .blocker,
                .roadmap,
                "Complex-capture protocol is invalid",
                protocolSnapshot.validationIssues.joined(separator: " "),
                "Correct the P1 capture protocol in the Roadmap planner before recording.",
                item: item.id
            ))
        }
        if let required = project.requiredCaptureState(for: item) {
            let active = project.activeCaptureStateID.flatMap { activeID in
                project.captureStates?.first { $0.id == activeID }
            }
            if active?.isStateEquivalent(to: required) != true {
                issues.append(issue(
                    "readiness.capture-state",
                    .blocker,
                    .roadmap,
                    "Required instrument state is not confirmed",
                    "Expected \(required.name), fingerprint \(required.fingerprintSHA256.prefix(12)).",
                    "Review and confirm the exact typed capture state before recording.",
                    item: item.id
                ))
            }
        }
        return issues
    }

    public static func audit(project: OrgRecProject, packageURL: URL? = nil) -> ProjectConsistencyReport {
        var issues: [ConsistencyIssue] = []
        var checks = 12
        let fm = FileManager.default
        let roadmapByID = project.roadmap.reduce(into: [UUID: RoadmapItem]()) { result, item in
            result[item.id] = result[item.id] ?? item
        }
        // Keep only collection indices here. TakeRecord deliberately retains a
        // large body of immutable evidence; copying it through a dictionary
        // reduction can exhaust the comparatively small cooperative-task stack
        // as new optional evidence contracts are added.
        let takeIndexByID = project.takes.indices.reduce(into: [UUID: Int]()) { result, index in
            let id = project.takes[index].id
            result[id] = result[id] ?? index
        }
        let longTakeSources = project.longTakeSources ?? []
        let longTakeByID = longTakeSources.reduce(into: [UUID: LongTakeSourceRecord]()) { result, source in
            result[source.id] = result[source.id] ?? source
        }
        let allPreflightReports = (project.recordingSessions ?? []).flatMap { $0.capturePreflightReports ?? [] }
        if Set(allPreflightReports.map(\.id)).count != allPreflightReports.count {
            issues.append(issue("preflight.duplicate-id", .blocker, .integrity, "Duplicate signal-path rehearsal identifiers", "Two retained reports share one immutable identity.", "Restore unique rehearsal records before export."))
        }
        for binding in project.controlBindings ?? [] where binding.validationIssues.isEmpty == false {
            issues.append(issue(
                "control-binding.\(binding.id)",
                .blocker,
                .roadmap,
                "Control mapping is incomplete or invalid",
                binding.validationIssues.joined(separator: " "),
                "Open Control Map, relearn or correct the binding, and verify its numbering base."
            ))
        }
        let spatialGeometries = project.spatialGeometrySnapshots ?? []
        if Set(spatialGeometries.map(\.id)).count != spatialGeometries.count {
            issues.append(issue("p2.geometry.duplicate-id", .blocker, .integrity, "Duplicate spatial-geometry identifiers", "Two geometry revisions share the same identifier.", "Restore unique immutable geometry snapshots."))
        }
        for geometry in spatialGeometries where !geometry.validationIssues.isEmpty {
            issues.append(issue("p2.geometry.\(geometry.id)", .blocker, .roadmap, "Spatial geometry is invalid", geometry.validationIssues.joined(separator: " "), "Correct the source/path geometry before recording or comparison."))
        }

        if project.organMDVSID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(issue("project.organ-id", .blocker, .modavis, "Organ identity is missing", "The project cannot be joined back to an organ.", "Attach a MODAVIS organ or assign an explicit local identity."))
        }
        if project.snapshot.endpoint != "manual://orgrec-project" && project.snapshot.payloadSHA256.count != 64 {
            issues.append(issue("project.snapshot-hash", .blocker, .integrity, "Invalid Navigator payload hash", "The frozen response does not have a SHA-256 identifier.", "Retrieve the organ again from Navigator."))
        }
        if project.roadmap.isEmpty {
            issues.append(issue("project.roadmap-empty", .blocker, .roadmap, "Recording roadmap is empty", "No MODAVIS-derived or locally planned captures exist.", "Attach an organ specification and compile its roadmap."))
        }
        if project.takes.isEmpty {
            issues.append(issue("project.takes-empty", .blocker, .recording, "Project has no recorded takes", "A metadata-only package is not a Navigator capture submission.", "Record and review at least one roadmap item."))
        }
        if let packageURL, let relative = project.navigatorPayloadRelativePath {
            checks += 2
            let payloadURL = packageURL.appendingPathComponent(relative)
            if fm.fileExists(atPath: payloadURL.path) == false {
                issues.append(issue("project.payload-missing", .blocker, .integrity, "Frozen Navigator payload is missing", relative, "Restore the payload or retrieve the specification again."))
            } else if let data = try? Data(contentsOf: payloadURL), data.sha256Hex != project.snapshot.payloadSHA256 {
                issues.append(issue("project.payload-drift", .blocker, .integrity, "Navigator payload checksum mismatch", "The stored response changed after project creation.", "Quarantine the project and restore the original payload."))
            }
        }
        if Set(project.roadmap.map(\.id)).count != project.roadmap.count {
            issues.append(issue("roadmap.duplicate-id", .blocker, .roadmap, "Duplicate roadmap identifiers", "Two captures share an internal identity.", "Regenerate the affected roadmap."))
        }
        let physicalTargets = project.physicalSoundTargets ?? []
        let physicalTargetIDs = Set(physicalTargets.map(\.id))
        if physicalTargetIDs.count != physicalTargets.count {
            issues.append(issue("roadmap.physical-target-duplicate", .blocker, .roadmap, "Duplicate physical sound target identifiers", "Two physical target groups share an identity.", "Regenerate the physical-pipe-aware roadmap."))
        }
        for target in physicalTargets {
            if target.routes.isEmpty || target.routes.contains(where: { $0.id == target.primaryRouteID }) == false {
                issues.append(issue("roadmap.physical-target.\(target.id)", .blocker, .roadmap, "Invalid physical sound target", "The target has no usable primary activation route.", "Regenerate or review the physical-pipe grouping."))
            }
            if Set(target.routes.map(\.id)).count != target.routes.count {
                issues.append(issue("roadmap.physical-target-routes.\(target.id)", .blocker, .roadmap, "Duplicate activation routes", "A physical target contains the same console address more than once.", "Regenerate the roadmap."))
            }
        }
        for item in project.roadmap {
            if let targetID = item.physicalSoundTargetID, physicalTargets.isEmpty == false, physicalTargetIDs.contains(targetID) == false {
                issues.append(issue("roadmap.\(item.id).physical-target", .blocker, .roadmap, "Roadmap references a missing physical target", targetID, "Restore the physical target or regenerate the roadmap.", item: item.id))
            }
            if let primaryRouteID = item.primaryActivationRouteID,
               item.activationRoutes?.contains(where: { $0.id == primaryRouteID }) != true {
                issues.append(issue("roadmap.\(item.id).activation-route", .blocker, .roadmap, "Roadmap primary activation route is missing", primaryRouteID, "Regenerate the physical-pipe-aware roadmap.", item: item.id))
            }
        }
        if let documented = project.organCharacteristics?.documentedStopCount,
           let parsed = project.roadmapCompilation?.sourceStopCount,
           documented != parsed {
            issues.append(issue("modavis.stop-reconciliation", .warning, .modavis, "Documented and parsed stop counts differ", "MODAVIS reports \(documented) stops, while OrgRec parsed \(parsed).", "Review source-native specification evidence before declaring complete coverage."))
        }
        if let manuals = project.organCharacteristics?.manualCount,
           let keyboards = project.organCharacteristics?.keyboardCount,
           manuals > keyboards {
            issues.append(issue("modavis.manual-reconciliation", .warning, .modavis, "Not every documented manual has a parsed keyboard", "MODAVIS reports \(manuals) manuals and OrgRec found \(keyboards) keyboard components.", "Review the component hierarchy and source-native specification."))
        }
        if (project.roadmapCompilation?.assumedCompassCount ?? 0) > 0 {
            issues.append(issue("modavis.assumed-compass", .warning, .modavis, "Some stop compasses are assumed", "\(project.roadmapCompilation?.assumedCompassCount ?? 0) stops use fallback playing ranges.", "Confirm compasses at the console and document exceptions."))
        }
        if project.recordingSessions?.isEmpty != false {
            issues.append(issue("session.none", .blocker, .session, "No recording session", "Takes require an operator and environmental context.", "Create a session in Field QA."))
        }
        let deviceIDs = Set(project.devices.map(\.id))
        for device in project.devices {
            checks += 2
            if device.serialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue("device.\(device.id).serial", .warning, .setup, "Device serial number is missing", device.displayName, "Record the serial number or a stable local inventory identifier."))
            }
            if device.kind == .microphone && device.modavisManifestationID == nil {
                issues.append(issue("device.\(device.id).manifestation", .information, .modavis, "Microphone is not linked to a MODAVIS manifestation", device.displayName, "Link it when equipment manifestation records become available through Navigator."))
            }
        }
        for setup in project.setups {
            checks += 4
            if let interfaceID = setup.interfaceDeviceID, deviceIDs.contains(interfaceID) == false {
                issues.append(issue("setup.\(setup.id).interface", .blocker, .setup, "Setup references a missing interface", setup.name, "Select an inventoried audio interface."))
            }
            for placement in setup.placements where deviceIDs.contains(placement.microphoneID) == false {
                issues.append(issue("setup.\(setup.id).mic.\(placement.id)", .blocker, .setup, "Placement references a missing microphone", "\(setup.name), channel \(placement.channelNumber)", "Choose an inventoried microphone."))
            }
            let channels = setup.placements.map(\.channelNumber)
            let referenceChannelNumber = setup.referenceChannelNumber ?? 1
            if referenceChannelNumber < 1 || channels.contains(referenceChannelNumber) == false {
                let documentedChannels = channels.sorted().map(String.init).joined(separator: ", ")
                issues.append(issue(
                    "setup.\(setup.id).reference-channel",
                    .blocker,
                    .setup,
                    "Invalid analysis reference channel",
                    "\(setup.name) selects channel \(referenceChannelNumber), but its documented placement channels are \(documentedChannels.isEmpty ? "none" : documentedChannels).",
                    "Choose a positive reference channel that has a documented microphone placement."
                ))
            }
            if setup.documentationPaths.isEmpty {
                issues.append(issue("setup.\(setup.id).documentation", .warning, .setup, "Microphone setup lacks visual documentation", "\(setup.name), revision \(setup.revision)", "Attach at least one photograph or floor plan."))
            }
        }
        for session in project.recordingSessions ?? [] {
            checks += 7
            if session.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue("session.\(session.id).operator", .blocker, .session, "Session operator is missing", session.sessionCode, "Enter the responsible operator."))
            }
            if TimeZone(identifier: session.timezoneIdentifier) == nil {
                issues.append(issue("session.\(session.id).timezone", .warning, .session, "Invalid session timezone", session.timezoneIdentifier, "Choose an IANA timezone identifier."))
            }
            if session.environment.temperatureCelsius == nil || session.environment.relativeHumidityPercent == nil {
                issues.append(issue("session.\(session.id).environment", .warning, .session, "Incomplete environmental paradata", session.sessionCode, "Record temperature and relative humidity."))
            }
            if session.rightsStatement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(issue("session.\(session.id).rights", .warning, .session, "Rights or consent statement is missing", session.sessionCode, "Document the capture and reuse permission basis."))
            }
            if session.noiseContextAssessment == nil {
                issues.append(issue("session.\(session.id).noise-context", .warning, .session, "Surrounding noise context is undocumented", session.sessionCode, "Plan or manually document external noise sources and venue conditions for this session."))
            } else if let assessment = session.noiseContextAssessment,
                      assessment.querySHA256.count != 64,
                      assessment.sourceName != "Operator assessment" {
                issues.append(issue("session.\(session.id).noise-query-fixity", .warning, .session, "Noise-context query fingerprint is invalid", session.sessionCode, "Refresh and review the surrounding-noise assessment before the next session."))
            }
            if let planID = session.sessionPlanID,
               project.sessionPlans?.contains(where: { $0.id == planID }) != true {
                issues.append(issue("session.\(session.id).plan", .blocker, .session, "Session references a missing plan", planID.uuidString, "Restore the referenced plan revision or remove the invalid reference."))
            }
            let preflightReports = session.capturePreflightReports ?? []
            if Set(preflightReports.map(\.id)).count != preflightReports.count {
                issues.append(issue("session.\(session.id).preflight-duplicate", .blocker, .integrity, "Duplicate signal-path rehearsal identifiers", session.sessionCode, "Restore unique immutable rehearsal reports."))
            }
            for report in preflightReports {
                checks += 7
                if report.fileSize <= 0 || report.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil {
                    issues.append(issue("preflight.\(report.id).descriptor", .blocker, .integrity, "Signal-path rehearsal evidence descriptor is invalid", report.relativeAudioPath, "Restore the positive byte size and lowercase SHA-256 recorded at finalization."))
                }
                if report.sampleRate <= 0 || report.frameCount <= 0 || report.channels.contains(where: \.isRequired) == false {
                    issues.append(issue("preflight.\(report.id).analysis", .blocker, .integrity, "Signal-path rehearsal analysis is incomplete", "The report lacks a positive audio extent or an assigned-channel result.", "Repeat the rehearsal and retain the complete analysis report."))
                }
                if report.sessionID != session.id {
                    issues.append(issue("preflight.\(report.id).session", .blocker, .integrity, "Signal-path rehearsal belongs to another session", report.sessionID.uuidString, "Restore the report under its originating session."))
                }
                if project.setups.contains(where: { $0.id == report.setupID }) == false {
                    issues.append(issue("preflight.\(report.id).setup", .blocker, .integrity, "Signal-path rehearsal references a missing setup", report.setupID.uuidString, "Restore the versioned microphone setup used by this rehearsal."))
                }
                if isSafePackageRelativePath(report.relativeAudioPath) == false || report.relativeAudioPath.hasPrefix("Audio/Calibration/") == false {
                    issues.append(issue("preflight.\(report.id).path", .blocker, .integrity, "Signal-path rehearsal path is unsafe", report.relativeAudioPath, "Restore the evidence under Audio/Calibration."))
                }
                let expectedVerdict: CapturePreflightVerdict = report.findings.contains(where: { $0.severity == .blocker })
                    ? .failed
                    : (report.findings.contains(where: { $0.severity == .warning }) ? .attention : .passed)
                if report.verdict != expectedVerdict {
                    issues.append(issue("preflight.\(report.id).verdict", .blocker, .integrity, "Signal-path rehearsal verdict is inconsistent", "Stored \(report.verdict.rawValue); findings imply \(expectedVerdict.rawValue).", "Restore or regenerate the immutable analysis report."))
                }
                if let packageURL {
                    let audioURL = packageURL.appendingPathComponent(report.relativeAudioPath)
                    let values = try? audioURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                    if values?.isRegularFile != true || values?.isSymbolicLink == true {
                        issues.append(issue("preflight.\(report.id).audio", .blocker, .integrity, "Signal-path rehearsal audio is missing", report.relativeAudioPath, "Restore the checksum-identified rehearsal master."))
                    } else {
                        if Int64(values?.fileSize ?? 0) != report.fileSize {
                            issues.append(issue("preflight.\(report.id).size", .blocker, .integrity, "Signal-path rehearsal file size changed", report.relativeAudioPath, "Quarantine the changed file and restore the recorded version."))
                        }
                        if let actual = try? sha256(of: audioURL), actual != report.sha256 {
                            issues.append(issue("preflight.\(report.id).hash", .blocker, .integrity, "Signal-path rehearsal checksum mismatch", report.relativeAudioPath, "Quarantine the changed file and restore the SHA-256-identified version."))
                        }
                    }
                }
            }
        }
        let roadmapIDs = Set(project.roadmap.map(\.id))
        let assessmentIDs = Set((project.noiseContextAssessments ?? []).map(\.id))
        for plan in project.sessionPlans ?? [] {
            checks += 4
            if plan.organMDVSID != project.organMDVSID || plan.navigatorSnapshotSHA256 != project.snapshot.payloadSHA256 {
                issues.append(issue("session-plan.\(plan.id).snapshot", .blocker, .session, "Session plan targets a different organ snapshot", plan.title, "Rebuild the plan against the current frozen organ specification."))
            }
            if plan.queue.isEmpty {
                issues.append(issue("session-plan.\(plan.id).queue", .warning, .session, "Session plan queue is empty", plan.title, "Select at least one eligible Roadmap obligation."))
            }
            if plan.queue.contains(where: { roadmapIDs.contains($0.roadmapItemID) == false }) {
                issues.append(issue("session-plan.\(plan.id).roadmap", .blocker, .session, "Session plan references missing Roadmap items", plan.title, "Revise the plan against the current Roadmap."))
            }
            if let assessmentID = plan.noiseContextAssessmentID, assessmentIDs.contains(assessmentID) == false {
                issues.append(issue("session-plan.\(plan.id).noise-context", .blocker, .session, "Session plan references a missing noise assessment", plan.title, "Refresh and save the surrounding-noise assessment."))
            }
        }
        if Set(longTakeSources.map(\.id)).count != longTakeSources.count {
            issues.append(issue("long-take.duplicate-id", .blocker, .integrity, "Duplicate long-take identifiers", "Two source masters share an internal identity.", "Repair the long-take source records before export."))
        }
        for source in longTakeSources {
            checks += 5
            if isSafePackageRelativePath(source.relativeAudioPath) == false || source.relativeAudioPath.hasPrefix("Audio/LongTakes/") == false {
                issues.append(issue("long-take.\(source.id).path", .blocker, .integrity, "Long-take source path is unsafe", source.relativeAudioPath, "Restore the source under Audio/LongTakes."))
            }
            for takeID in source.generatedTakeIDs where takeIndexByID[takeID].map({ project.takes[$0].longTakeSource?.longTakeID }) != source.id {
                issues.append(issue("long-take.\(source.id).take.\(takeID)", .blocker, .integrity, "Long-take output backlink is unresolved", takeID.uuidString, "Restore the split take and its source-region provenance."))
            }
            if let packageURL {
                let sourceURL = packageURL.appendingPathComponent(source.relativeAudioPath)
                if fm.fileExists(atPath: sourceURL.path) == false {
                    issues.append(issue("long-take.\(source.id).audio", .blocker, .integrity, "Long-take source master is missing", source.relativeAudioPath, "Restore the checksum-identified source master."))
                } else if let actual = try? sha256(of: sourceURL), actual != source.sha256 {
                    issues.append(issue("long-take.\(source.id).hash", .blocker, .integrity, "Long-take source checksum mismatch", source.relativeAudioPath, "Quarantine the changed source and restore the recorded checksum version."))
                }
            }
        }
        for item in project.roadmap {
            checks += 4
            if item.component.locator.organMDVSID != project.organMDVSID {
                issues.append(issue("roadmap.\(item.id).organ", .blocker, .modavis, "Roadmap item belongs to another organ", item.component.locator.organMDVSID, "Regenerate the roadmap.", item: item.id))
            }
            if item.component.locator.snapshotSHA256 != project.snapshot.payloadSHA256 {
                issues.append(issue("roadmap.\(item.id).snapshot", .blocker, .modavis, "Roadmap locator snapshot mismatch", item.component.label, "Regenerate the roadmap from the frozen payload.", item: item.id))
            }
            if let setupID = item.setupID, project.setups.contains(where: { $0.id == setupID }) == false {
                issues.append(issue("roadmap.\(item.id).setup", .blocker, .setup, "Roadmap references a missing setup", item.component.label, "Assign an existing setup revision.", item: item.id))
            }
            for takeID in item.takeIDs where takeIndexByID[takeID] == nil {
                issues.append(issue("roadmap.\(item.id).take.\(takeID)", .blocker, .integrity, "Roadmap references a missing take", takeID.uuidString, "Restore the take record or remove the broken reference.", item: item.id))
            }
            if item.state == .accepted {
                let hasAcceptedTake = item.takeIDs.contains { takeIndexByID[$0].map { project.takes[$0].status } == .accepted }
                if hasAcceptedTake == false {
                    issues.append(issue("roadmap.\(item.id).accepted-evidence", .blocker, .review, "Accepted roadmap item has no accepted take", "\(item.component.label) \(item.component.noteName ?? "") · \(item.technique.rawValue)", "Review and accept a linked take, or return the item to missing.", item: item.id))
                }
            }
            if let profile = item.instrumentNoiseProtocol?.actuationProfile,
               profile.validationIssues.isEmpty == false {
                issues.append(issue(
                    "roadmap.\(item.id).actuation-curve",
                    .blocker,
                    .roadmap,
                    "Instrument-noise actuation profile is invalid",
                    profile.validationIssues.joined(separator: " "),
                    "Replace the invalid profile with a valid, strictly time-ordered command trajectory.",
                    item: item.id
                ))
            }
            if let protocolSnapshot = item.complexCaptureProtocol,
               protocolSnapshot.validationIssues.isEmpty == false {
                issues.append(issue(
                    "roadmap.\(item.id).complex-capture",
                    .blocker,
                    .roadmap,
                    "P1 complex-capture protocol is invalid",
                    protocolSnapshot.validationIssues.joined(separator: " "),
                    "Repair or recreate the typed capture obligation before recording.",
                    item: item.id
                ))
            }
            if let protocolSnapshot = item.spatialAcousticProtocol {
                if let geometry = spatialGeometries.first(where: { $0.id == protocolSnapshot.geometrySnapshotID }) {
                    if geometry.fingerprint != protocolSnapshot.geometryFingerprint {
                        issues.append(issue("roadmap.\(item.id).p2-geometry-fingerprint", .blocker, .integrity, "P2 protocol geometry fingerprint is stale", protocolSnapshot.name, "Restore the exact geometry revision or re-plan the entire comparison series.", item: item.id))
                    }
                    let elementIDs = Set(geometry.elements.map(\.id))
                    if !elementIDs.contains(protocolSnapshot.sourceElementID) || !protocolSnapshot.pathElementIDs.allSatisfy(elementIDs.contains) {
                        issues.append(issue("roadmap.\(item.id).p2-geometry-elements", .blocker, .roadmap, "P2 protocol references missing geometry elements", protocolSnapshot.name, "Repair the source and propagation-path element bindings.", item: item.id))
                    }
                    if let setupID = item.setupID, !geometry.referenceFrame.compatibleMicrophoneSetupIDs.contains(setupID) {
                        issues.append(issue("roadmap.\(item.id).p2-setup-frame", .blocker, .setup, "P2 setup is outside the documented coordinate frame", protocolSnapshot.name, "Use a compatible setup so source-to-receiver geometry remains reproducible.", item: item.id))
                    }
                } else {
                    issues.append(issue("roadmap.\(item.id).p2-geometry", .blocker, .integrity, "P2 protocol references a missing geometry snapshot", protocolSnapshot.name, "Restore the frozen geometry snapshot.", item: item.id))
                }
            }
            if let definition = item.soundingTargetDefinition, definition.validationIssues.isEmpty == false {
                issues.append(issue(
                    "roadmap.\(item.id).sounding-target",
                    .blocker,
                    .roadmap,
                    "Intended sounding target is invalid",
                    definition.validationIssues.joined(separator: " "),
                    "Correct the target family, constituent list, and capture protocol.",
                    item: item.id
                ))
            }
        }
        for take in project.takes {
            checks += 15
            guard let item = roadmapByID[take.roadmapItemID] else {
                issues.append(issue("take.\(take.id).roadmap", .blocker, .integrity, "Take is orphaned from the roadmap", take.id.uuidString, "Restore its roadmap item.", take: take.id))
                continue
            }
            if item.takeIDs.contains(take.id) == false {
                issues.append(issue("take.\(take.id).backlink", .blocker, .integrity, "Missing roadmap-to-take link", item.component.label, "Repair the roadmap take list.", item: item.id, take: take.id))
            }
            if take.status == .accepted && item.state != .accepted {
                issues.append(issue("take.\(take.id).accepted-state", .blocker, .review, "Accepted take does not update roadmap coverage", item.component.label, "Repair the roadmap state through take review.", item: item.id, take: take.id))
            }
            if take.provenance == nil {
                issues.append(issue("take.\(take.id).provenance", .warning, .recording, "Legacy take has no immutable provenance snapshot", "Setup and session changes could alter its interpretation.", "Document legacy context in the take notes; new captures freeze it automatically.", item: item.id, take: take.id))
            } else if take.provenance?.navigatorPayloadSHA256 != project.snapshot.payloadSHA256 {
                issues.append(issue("take.\(take.id).snapshot", .blocker, .modavis, "Take provenance uses another MODAVIS snapshot", take.provenance?.navigatorPayloadSHA256 ?? "", "Review the take against its original project snapshot.", item: item.id, take: take.id))
            }
            if let required = project.requiredCaptureState(for: item) {
                if let frozen = take.captureStateSnapshot ?? take.provenance?.captureStateSnapshot {
                    if frozen.isStateEquivalent(to: required) == false {
                        issues.append(issue("take.\(take.id).capture-state", .blocker, .recording, "Take used a different instrument state", "Required \(required.fingerprintSHA256.prefix(12)); frozen \(frozen.fingerprintSHA256.prefix(12)).", "Reject and retake after confirming the exact Roadmap state.", item: item.id, take: take.id))
                    }
                } else {
                    issues.append(issue("take.\(take.id).capture-state-legacy", .warning, .recording, "Take has no typed capture-state snapshot", "The Roadmap now defines state \(required.fingerprintSHA256.prefix(12)), but this older take did not freeze it.", "Verify the state from other provenance before accepting the take.", item: item.id, take: take.id))
                }
            }
            if let eventLog = take.controlEventLog {
                if eventLog.takeID != take.id {
                    issues.append(issue("take.\(take.id).control-log-binding", .blocker, .integrity, "Control-event log belongs to another take", eventLog.takeID.uuidString, "Restore the correctly bound event log.", item: item.id, take: take.id))
                }
                if let alignment = take.audioControlAlignment {
                    if alignment.eventLogID != eventLog.id || alignment.mappings.count != eventLog.events.count {
                        issues.append(issue("take.\(take.id).control-alignment-binding", .blocker, .integrity, "Control-event alignment is incomplete", "Event log and frame mapping identifiers/counts do not agree.", "Recalculate the alignment from the immutable event log.", item: item.id, take: take.id))
                    }
                } else {
                    issues.append(issue("take.\(take.id).control-alignment", .blocker, .recording, "Control events are not aligned to audio", "\(eventLog.events.count) events exist without frame mappings.", "Recalculate alignment from the preserved shared-clock timestamps.", item: item.id, take: take.id))
                }
            }
            for sensorCapture in take.interactionSensorCaptures ?? [] {
                checks += 9
                // Interaction capture is always optional for the audio take. Once
                // evidence is attached, integrity failures still matter, but an
                // older "required" configuration must not turn sensor-quality
                // findings into audio-capture blockers.
                let evidenceSeverity: ConsistencySeverity = .warning
                if sensorCapture.takeID != take.id {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).binding", .blocker, .integrity, "Interaction-sensor capture belongs to another take", sensorCapture.takeID.uuidString, "Restore the correctly bound sensor capture record.", item: item.id, take: take.id))
                }
                if sensorCapture.health.receivedPackets == 0 {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).empty", .blocker, .recording, "Interaction-sensor capture contains no decoded packets", sensorCapture.rawRelativePath, "Inspect the serial protocol and repeat the take.", item: item.id, take: take.id))
                }
                if sensorCapture.health.retentionFraction < 0.999 {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).retention", evidenceSeverity, .recording, "Interaction-sensor packet retention is below the provisional gate", sensorCapture.health.retentionFraction.formatted(.percent.precision(.fractionLength(3))), "Resolve serial loss or document a wider uncertainty before accepting sensor-derived timing.", item: item.id, take: take.id))
                }
                let faultCount = sensorCapture.health.crcErrors + sensorCapture.health.i2cErrors + sensorCapture.health.resetDiscontinuities
                if faultCount > 0 {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).faults", evidenceSeverity, .recording, "Interaction-sensor stream has integrity faults", "\(sensorCapture.health.crcErrors) CRC, \(sensorCapture.health.i2cErrors) I²C, \(sensorCapture.health.resetDiscontinuities) resets.", "Reject the affected motion segment or repeat the take after resolving power, wiring, and timing faults.", item: item.id, take: take.id))
                }
                if sensorCapture.health.saturations > 0 {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).saturation", evidenceSeverity, .recording, "Interaction sensor approached full scale", "\(sensorCapture.health.saturations) near-limit samples.", "Select a wider gyro or acceleration range and repeat the movement.", item: item.id, take: take.id))
                }
                if sensorCapture.clockAlignment.status == .unavailable || sensorCapture.clockAlignment.segments.isEmpty {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).alignment", evidenceSeverity, .recording, "Interaction-sensor timebase is not aligned to audio", sensorCapture.clockAlignment.notes, "Restore timing anchors or use a shared hardware synchronization pulse.", item: item.id, take: take.id))
                }
                if sensorCapture.calibrationSnapshot == nil {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).calibration", .warning, .recording, "Interaction-sensor capture has no calibration snapshot", sensorCapture.configurationSnapshot.targetComponentLabel, "Use raw dynamics only, or repeat the take with a mounted-mechanism calibration.", item: item.id, take: take.id))
                }
                if sensorCapture.configurationSnapshot.validationState != .acceptedForExperiment {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).validation", .warning, .review, "Interaction-sensor configuration has not passed the provisional validation gate", sensorCapture.configurationSnapshot.validationState.displayName, "Validate the exact sensor, mount, mechanism, and calibration against an independent physical reference.", item: item.id, take: take.id))
                }
                if sensorCapture.configurationSnapshot.resolvedUseCase == .representativeKeyAction,
                   take.analysis?.onsetSeconds != nil,
                   sensorCapture.audioCoupling == nil {
                    issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).audio-coupling", .warning, .analysis, "Interaction motion is not coupled to the analyzed pipe response", "The raw evidence is retained, but no activation/onset and release/offset timing summary could be derived.", "Review event direction and the sensor-to-audio alignment; retain the audio take even if optional interaction evidence is unusable.", item: item.id, take: take.id))
                }
                if let packageURL {
                    let rawURL = packageURL.appendingPathComponent(sensorCapture.rawRelativePath)
                    if fm.fileExists(atPath: rawURL.path) == false {
                        issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).raw", .blocker, .integrity, "Interaction-sensor raw evidence is missing", sensorCapture.rawRelativePath, "Restore the immutable raw packet stream.", item: item.id, take: take.id))
                    } else if let actual = try? sha256(of: rawURL), actual != sensorCapture.rawSHA256 {
                        issues.append(issue("take.\(take.id).sensor.\(sensorCapture.id).hash", .blocker, .integrity, "Interaction-sensor raw checksum mismatch", sensorCapture.rawRelativePath, "Quarantine the changed file and restore its recorded checksum version.", item: item.id, take: take.id))
                    }
                }
            }
            if let protocolSnapshot = item.complexCaptureProtocol {
                if let paradata = take.complexCaptureParadata {
                    if paradata.protocolSnapshot.id != protocolSnapshot.id
                        || paradata.protocolSnapshot.kind != protocolSnapshot.kind {
                        issues.append(issue("take.\(take.id).complex-protocol-binding", .blocker, .integrity, "Complex-capture paradata belongs to another protocol", paradata.protocolSnapshot.name, "Restore the frozen protocol that was active for this take.", item: item.id, take: take.id))
                    }
                    if protocolSnapshot.kind == .operationalBaseline,
                       let baseline = paradata.operationalBaselineAnalysis,
                       baseline.analyzedDurationSeconds < (protocolSnapshot.operationalBaseline?.minimumDurationSeconds ?? 120) {
                        issues.append(issue("take.\(take.id).baseline-duration", .blocker, .recording, "Operational baseline is too short", "Analyzed \(baseline.analyzedDurationSeconds.formatted(.number.precision(.fractionLength(1)))) s; required \((protocolSnapshot.operationalBaseline?.minimumDurationSeconds ?? 120).formatted(.number.precision(.fractionLength(0)))) s.", "Record the full multi-minute subsystem-state baseline without denoising.", item: item.id, take: take.id))
                    }
                    if protocolSnapshot.kind == .operationalBaseline,
                       paradata.operationalBaselineAnalysis == nil,
                       take.status == .accepted {
                        issues.append(issue("take.\(take.id).baseline-analysis", .blocker, .analysis, "Accepted baseline has no noise-statistics analysis", protocolSnapshot.name, "Analyze level distribution and spectrum before acceptance.", item: item.id, take: take.id))
                    }
                    if protocolSnapshot.kind == .physicalActuatorResponse,
                       paradata.actuatorResponseObservation == nil,
                       take.status == .accepted {
                        issues.append(issue("take.\(take.id).actuator-response", .blocker, .analysis, "Accepted actuator take has no measured response point", protocolSnapshot.name, "Analyze the take and preserve its input-to-output observation before acceptance.", item: item.id, take: take.id))
                    }
                    if protocolSnapshot.kind == .tremulantResponse,
                       paradata.tremulantAnalysis == nil,
                       take.status == .accepted {
                        issues.append(issue("take.\(take.id).tremulant-analysis", .blocker, .analysis, "Accepted tremulant take has no modulation analysis", protocolSnapshot.name, "Analyze modulation rate, depth, transition, and settling evidence before acceptance.", item: item.id, take: take.id))
                    }
                } else {
                    issues.append(issue("take.\(take.id).complex-paradata", take.status == .accepted ? .blocker : .warning, .recording, "P1 take has no structured complex-capture paradata", protocolSnapshot.name, "Restore or repeat the take so its protocol, event markers, and derived evidence are preserved.", item: item.id, take: take.id))
                }
            }
            if let protocolSnapshot = item.spatialAcousticProtocol {
                if let paradata = take.spatialAcousticParadata {
                    if paradata.protocolSnapshot.id != protocolSnapshot.id
                        || paradata.protocolSnapshot.geometryFingerprint != protocolSnapshot.geometryFingerprint {
                        issues.append(issue("take.\(take.id).p2-protocol-binding", .blocker, .integrity, "Spatial-response paradata belongs to another protocol or geometry", protocolSnapshot.name, "Restore the frozen P2 protocol active for this take.", item: item.id, take: take.id))
                    }
                    if take.provenance?.spatialGeometrySnapshot?.fingerprint != protocolSnapshot.geometryFingerprint {
                        issues.append(issue("take.\(take.id).p2-geometry-provenance", .blocker, .integrity, "Take does not freeze its spatial geometry", protocolSnapshot.name, "Restore or repeat the take with immutable P2 geometry provenance.", item: item.id, take: take.id))
                    }
                    if take.status == .accepted && paradata.observation == nil {
                        issues.append(issue("take.\(take.id).p2-observation", .blocker, .analysis, "Accepted P2 response has no acoustic observation", protocolSnapshot.name, "Analyze level, latency, impulse width, and third-octave response before acceptance.", item: item.id, take: take.id))
                    }
                    if take.status == .accepted,
                       protocolSnapshot.effectiveExcitation.responseQualification != nil,
                       paradata.observation?.acousticResponseAnalysis == nil {
                        issues.append(issue("take.\(take.id).p2-room-response", .blocker, .analysis, "Declared impulse response has no qualified room-acoustic analysis", protocolSnapshot.effectiveExcitation.displayName, "Reanalyze the deconvolved or impulsive response; if the source was an organ sound, revise the protocol qualification instead of reporting RT metrics.", item: item.id, take: take.id))
                    }
                    if let response = paradata.observation?.acousticResponseAnalysis,
                       response.broadband.usableDecayRangeDB < 25 {
                        issues.append(issue("take.\(take.id).p2-room-range", .warning, .analysis, "Room response has limited decay range", "\(response.broadband.usableDecayRangeDB.formatted(.number.precision(.fractionLength(1)))) dB is usable above the estimated noise intersection.", "Improve source level or reduce background noise, retain a longer tail, and repeat the response measurement.", item: item.id, take: take.id))
                    }
                    if take.status == .accepted && !paradata.events.contains(where: { $0.kind == .stateConfirmed }) {
                        issues.append(issue("take.\(take.id).p2-state-confirmation", .blocker, .recording, "Accepted P2 response has no observed state confirmation", protocolSnapshot.targetState.label, "Confirm the physical shutter/enclosure state during capture.", item: item.id, take: take.id))
                    }
                } else {
                    issues.append(issue("take.\(take.id).p2-paradata", take.status == .accepted ? .blocker : .warning, .recording, "P2 take has no structured spatial-response paradata", protocolSnapshot.name, "Restore or repeat the take with state and source-event paradata.", item: item.id, take: take.id))
                }
            }
            if item.inferredNonPitchedEffectAnalysisProtocol != nil,
               take.status == .accepted,
               take.effectAnalysis == nil {
                issues.append(issue("take.\(take.id).p2-effect-analysis", .blocker, .analysis, "Accepted non-pitched effect has no P2 analytics", item.component.label, "Analyze latency, level, impulse width, repetition, periodicity, stochasticity, and stage timing before acceptance.", item: item.id, take: take.id))
            }
            if take.sampleRate <= 0 || take.channelCount <= 0 || take.frameCount < 0 {
                issues.append(issue("take.\(take.id).format", .blocker, .recording, "Invalid audio format metadata", "\(take.sampleRate) Hz, \(take.channelCount) channels, \(take.frameCount) frames", "Recover metadata from the original BWF.", item: item.id, take: take.id))
            }
            if let source = take.longTakeSource {
                if let master = longTakeByID[source.longTakeID] {
                    if master.relativeAudioPath != source.sourceRelativeAudioPath || master.sha256 != source.sourceSHA256 {
                        issues.append(issue("take.\(take.id).long-take-binding", .blocker, .integrity, "Split take source binding is inconsistent", source.sourceRelativeAudioPath, "Restore the matching long-take source record and checksum.", item: item.id, take: take.id))
                    }
                    if source.sourceStartSeconds < 0 || source.sourceEndSeconds <= source.sourceStartSeconds || source.sourceEndSeconds > master.analysis.sourceDurationSeconds + 0.001 {
                        issues.append(issue("take.\(take.id).long-take-region", .blocker, .integrity, "Split take source region is invalid", "\(source.sourceStartSeconds)…\(source.sourceEndSeconds) s", "Re-split the take from the preserved source master.", item: item.id, take: take.id))
                    }
                    if let startFrame = source.sourceStartFrame,
                       let endFrame = source.sourceEndFrame,
                       let onsetFrame = source.detectedOnsetFrame,
                       let offsetFrame = source.detectedSoundOffsetFrame {
                        let validFrames = startFrame >= 0
                            && endFrame > startFrame
                            && endFrame <= master.frameCount
                            && onsetFrame >= startFrame
                            && offsetFrame >= onsetFrame
                            && offsetFrame <= endFrame
                        let frameTolerance = 1.5 / max(1, master.sampleRate)
                        let secondsMatchFrames = abs(source.sourceStartSeconds - Double(startFrame) / master.sampleRate) <= frameTolerance
                            && abs(source.sourceEndSeconds - Double(endFrame) / master.sampleRate) <= frameTolerance
                            && abs(source.detectedOnsetSeconds - Double(onsetFrame) / master.sampleRate) <= frameTolerance
                            && abs(source.detectedSoundOffsetSeconds - Double(offsetFrame) / master.sampleRate) <= frameTolerance
                        if validFrames == false || secondsMatchFrames == false {
                            issues.append(issue("take.\(take.id).long-take-frames", .blocker, .integrity, "Split take exact-frame provenance is invalid", "\(startFrame)…\(endFrame) frames", "Re-split the take from the preserved source master.", item: item.id, take: take.id))
                        }
                    }
                } else {
                    issues.append(issue("take.\(take.id).long-take-source", .blocker, .integrity, "Split take references a missing source master", source.longTakeID.uuidString, "Restore the long-take source record.", item: item.id, take: take.id))
                }
                if source.assignmentConfidence < 0.7 && take.status == .accepted {
                    issues.append(issue("take.\(take.id).long-take-confidence", .warning, .review, "Low-confidence split was accepted", source.assignmentConfidence.formatted(.percent.precision(.fractionLength(0))), "Confirm note identity and both boundaries in Analysis.", item: item.id, take: take.id))
                }
            }
            let loopSets = take.loopPointSets ?? []
            for set in loopSets {
                let errors = LoopPointSetValidator.errors(for: set)
                if !errors.isEmpty {
                    issues.append(issue("take.\(take.id).loop.\(set.id)", .blocker, .analysis, "Invalid loop point set", errors.joined(separator: " "), "Review or regenerate the loop set from the checksum-verified audio.", item: item.id, take: take.id))
                }
                if let audioHash = take.sha256, set.sourceAudioSHA256 != audioHash {
                    issues.append(issue("take.\(take.id).loop-source.\(set.id)", .blocker, .integrity, "Loop point set belongs to another audio revision", set.sourceAudioSHA256, "Discard the stale proposal or restore its source audio before export.", item: item.id, take: take.id))
                }
            }
            if let acceptedID = take.acceptedLoopPointSetID,
               loopSets.first(where: { $0.id == acceptedID })?.status != .accepted {
                issues.append(issue("take.\(take.id).loop-accepted-reference", .blocker, .review, "Accepted loop reference is unresolved", acceptedID.uuidString, "Accept a valid reviewed loop revision or clear the stale reference.", item: item.id, take: take.id))
            }
            if let packageURL {
                let audioURL = packageURL.appendingPathComponent(take.relativeAudioPath)
                if fm.fileExists(atPath: audioURL.path) == false {
                    issues.append(issue("take.\(take.id).audio", .blocker, .integrity, "Original audio is missing", take.relativeAudioPath, "Restore the original BWF before export.", item: item.id, take: take.id))
                } else if let expected = take.sha256, let actual = try? sha256(of: audioURL), expected != actual {
                    issues.append(issue("take.\(take.id).hash", .blocker, .integrity, "Original audio checksum mismatch", take.relativeAudioPath, "Quarantine the changed file and restore its recorded checksum version.", item: item.id, take: take.id))
                }
            }
            if let diagnostics = take.captureDiagnostics {
                if diagnostics.droppedBuffers > 0 || diagnostics.discontinuityCount > 0 || diagnostics.faults.isEmpty == false {
                    issues.append(issue("take.\(take.id).drop", .blocker, .recording, "Capture continuity failed", "\(diagnostics.droppedBuffers) dropped buffers; \(diagnostics.discontinuityCount) discontinuities.", "Reject and retake after increasing the buffer or reducing channel load.", item: item.id, take: take.id))
                }
                let clipped = diagnostics.channels.reduce(0) { $0 + $1.clippedSamples }
                if clipped > 0 {
                    issues.append(issue("take.\(take.id).clip", .warning, .recording, "Clipped samples detected", "\(clipped) samples reached full scale.", "Lower preamp gain and retake if clipping affects the pipe transient.", item: item.id, take: take.id))
                }
            }
            if let faults = take.captureIntegrityFaults, faults.isEmpty == false {
                issues.append(issue(
                    "take.\(take.id).capture-integrity",
                    .blocker,
                    .integrity,
                    "Capture transaction integrity failed",
                    faults.map(\.message).joined(separator: " "),
                    "Reject this take and record a replacement; acoustic reanalysis cannot repair capture evidence.",
                    item: item.id,
                    take: take.id
                ))
            }
            if let analysis = take.analysis {
                if let error = analysis.perceptualSpectralSummary?.validationErrors.first {
                    issues.append(issue("take.\(take.id).perceptual-spectrum-invalid", .blocker, .integrity, "Perceptual spectral evidence is invalid", error, "Reanalyze the checksum-verified original audio.", item: item.id, take: take.id))
                }
                if let error = analysis.acousticResponseAnalysis?.validationErrors.first {
                    issues.append(issue("take.\(take.id).acoustic-response-invalid", .blocker, .integrity, "Acoustic decay evidence is invalid", error, "Reanalyze the checksum-verified original audio.", item: item.id, take: take.id))
                }
                if analysis.pitchApplicability == .monophonic, analysis.frequencyHz == nil {
                    issues.append(issue("take.\(take.id).pitch-missing", .blocker, .analysis, "Required monophonic pitch is unavailable", "The analysis produced no usable fundamental-frequency observation.", "Review the reference channel and sustain region, then reanalyze or retake.", item: item.id, take: take.id))
                }
                if let runID = analysis.analysisRunID {
                    if let run = take.analysisRuns?.first(where: { $0.id == runID }) {
                        if let audioHash = take.sha256, run.inputSHA256 != audioHash {
                            issues.append(issue("take.\(take.id).analysis-input", .blocker, .integrity, "Analysis input hash differs from the take", run.inputSHA256, "Reanalyze the checksum-verified original audio.", item: item.id, take: take.id))
                        }
                        if let expectedParameters = run.parameterSHA256,
                           let actualParameters = (try? OrgRecCoding.lineEncoder.encode(run.parameters))?.sha256Hex,
                           expectedParameters != actualParameters {
                            issues.append(issue("take.\(take.id).analysis-parameters", .blocker, .integrity, "Analysis parameter hash mismatch", runID.uuidString, "Restore the immutable run record or reanalyze the original audio.", item: item.id, take: take.id))
                        }
                    } else {
                        issues.append(issue("take.\(take.id).analysis-run", .warning, .analysis, "Analysis summary has no immutable run record", runID.uuidString, "Reanalyze once to create a parameterized v2 run record.", item: item.id, take: take.id))
                    }
                }
                if let cents = analysis.centsDeviation, abs(cents) > 50 {
                    issues.append(issue("take.\(take.id).pitch", .warning, .analysis, "Measured pitch differs strongly from the roadmap", "\(cents.formatted(.number.precision(.fractionLength(1)))) cents deviation.", "Confirm the stop, key, reference pitch, and temperament.", item: item.id, take: take.id))
                }
                if analysis.pitchEstimatorComparison?.severity == .critical {
                    let difference = analysis.pitchEstimatorComparison?.differenceCents?.formatted(.number.precision(.fractionLength(1))) ?? "unknown"
                    issues.append(issue("take.\(take.id).pitch-estimator-mismatch", .warning, .analysis, "CREPE and pYIN critically disagree", "Independent estimates differ by \(difference) cents and were not averaged.", "Inspect the sustain, octave relationship, estimator confidences, and audio; document any acceptance decision.", item: item.id, take: take.id))
                }
                let markers = correctedMarkers(take: take, analysis: analysis)
                let ordered = markers.compactMap { $0 }
                if zip(ordered, ordered.dropFirst()).contains(where: { $0 > $1 }) {
                    issues.append(issue("take.\(take.id).markers", .warning, .analysis, "Transient markers are not chronological", "Expected onset ≤ sustain ≤ key-up ≤ sound offset ≤ tail end.", "Adjudicate markers in Analysis.", item: item.id, take: take.id))
                }
            } else if take.status == .accepted {
                issues.append(issue("take.\(take.id).analysis", .blocker, .analysis, "Accepted take has no analysis", "No transient or frequency evidence is stored.", "Analyze the take before acceptance.", item: item.id, take: take.id))
            }
            if (take.status == .accepted || take.status == .rejected), take.reviewHistory?.isEmpty != false {
                issues.append(issue("take.\(take.id).review", .warning, .review, "Review decision has no audit event", take.status.rawValue, "Record author and reason during the next review.", item: item.id, take: take.id))
            }
        }
        if let collection = project.collectionAnalysis,
           !CollectionAnalysisEngine.isCurrent(collection, for: project) {
            issues.append(issue(
                "analysis.collection.stale",
                .warning,
                .analysis,
                "Collection analysis is stale",
                "Its source fingerprint no longer matches the current roadmap, takes, review states, or recording sessions.",
                "Refresh the collection analysis before interpreting or exporting aggregate results."
            ))
        }
        let acceptedTakeIDs = Set(project.takes.filter { $0.status == .accepted }.map(\.id))
        for comparison in project.spatialAcousticResponseComparisons ?? [] {
            checks += 3
            if comparison.referenceTakeIDs.isEmpty || comparison.targetTakeIDs.isEmpty {
                issues.append(issue("p2.comparison.\(comparison.id).evidence", .blocker, .analysis, "Spatial response comparison has incomplete evidence", comparison.id, "Accept at least one compatible reference and target-state take."))
            }
            if !(comparison.referenceTakeIDs + comparison.targetTakeIDs).allSatisfy(acceptedTakeIDs.contains) {
                issues.append(issue("p2.comparison.\(comparison.id).review", .blocker, .review, "Spatial response comparison includes an unaccepted take", comparison.id, "Refresh the response comparison from accepted takes only."))
            }
            if spatialGeometries.first(where: { $0.id == comparison.geometrySnapshotID })?.fingerprint != comparison.geometryFingerprint {
                issues.append(issue("p2.comparison.\(comparison.id).geometry", .blocker, .integrity, "Spatial response comparison geometry is unresolved", comparison.id, "Restore the matching frozen geometry snapshot and regenerate comparisons."))
            }
        }
        let penalty = issues.reduce(0) { partial, item in
            partial + (item.severity == .blocker ? 15 : item.severity == .warning ? 4 : 1)
        }
        return ProjectConsistencyReport(
            projectID: project.id,
            score: max(0, 100 - min(100, penalty)),
            checksPerformed: checks,
            issues: issues.sorted {
                severityRank($0.severity) == severityRank($1.severity)
                    ? $0.scope.rawValue < $1.scope.rawValue
                    : severityRank($0.severity) < severityRank($1.severity)
            }
        )
    }

    private static func correctedMarkers(take: TakeRecord, analysis: AnalysisSummary) -> [Double?] {
        func value(_ marker: AnalysisMarkerKind, automated: Double?) -> Double? {
            take.markerCorrections?.filter { $0.marker == marker }.max { $0.createdAt < $1.createdAt }?.correctedSeconds ?? automated
        }
        return [
            value(.onset, automated: analysis.onsetSeconds),
            value(.sustainStart, automated: analysis.sustainStartSeconds),
            value(.keyUp, automated: analysis.keyUpSeconds),
            value(.soundOffset, automated: analysis.soundOffsetSeconds),
            value(.tailEnd, automated: analysis.tailEndSeconds),
        ]
    }

    private static func severityRank(_ severity: ConsistencySeverity) -> Int {
        switch severity { case .blocker: 0; case .warning: 1; case .information: 2 }
    }

    private static func issue(
        _ id: String,
        _ severity: ConsistencySeverity,
        _ scope: ConsistencyScope,
        _ title: String,
        _ detail: String,
        _ remediation: String,
        item: UUID? = nil,
        take: UUID? = nil
    ) -> ConsistencyIssue {
        ConsistencyIssue(id: id, severity: severity, scope: scope, title: title, detail: detail, remediation: remediation, roadmapItemID: item, takeID: take)
    }
}
