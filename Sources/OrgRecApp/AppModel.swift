import AppKit
import AVFoundation
import Combine
import Foundation
import OrgRecCore

enum AppPage: String, CaseIterable, Identifiable {
    case projects = "Projects"
    case datasetImport = "Data Exchange"
    case organSearch = "Find Organ"
    case initialize = "Initialize"
    case roadmap = "Roadmap"
    case record = "Record"
    case analysis = "Analysis"
    case fieldQA = "Field QA"
    case setup = "Setup"
    case interactionSensors = "Interaction Sensors"
    case sync = "Sync"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .projects: "square.grid.2x2"
        case .datasetImport: "shippingbox.and.arrow.backward"
        case .organSearch: "magnifyingglass"
        case .initialize: "checklist.checked"
        case .roadmap: "list.bullet.rectangle"
        case .record: "record.circle"
        case .analysis: "waveform.path.ecg.rectangle"
        case .fieldQA: "checkmark.shield"
        case .setup: "slider.horizontal.3"
        case .interactionSensors: "gyroscope"
        case .sync: "arrow.triangle.2.circlepath"
        }
    }
}

struct RecordingProjectSummary: Identifiable, Hashable {
    var id: String { url.standardizedFileURL.path }
    var url: URL
    var projectID: UUID
    var title: String
    var organMDVSID: String
    var organName: String
    var venueName: String
    var updatedAt: Date
    var roadmapItems: Int
    var takes: Int
    var coverage: CoverageSummary
    var consistencyScore: Int
    var consistencyBlockers: Int
    var isActive: Bool
}

struct OrganProjectGroup: Identifiable {
    var id: String
    var organName: String
    var organMDVSID: String
    var projects: [RecordingProjectSummary]
}

struct TemperamentRankOption: Identifiable, Hashable {
    var id: String
    var label: String
    var division: String
    var footHeight: String
    var pitchClassCount: Int
    var takeCount: Int
}

struct TimbreRankOption: Identifiable, Hashable {
    var id: String
    var label: String
    var division: String
    var footHeight: String
    var componentKind: String
    var noteCount: Int
    var takeCount: Int
}

enum ProjectPersistenceState: Equatable {
    case clean(lastSavedAt: Date?)
    case saving
    case dirty(message: String)

    var isDirty: Bool {
        if case .dirty = self { return true }
        return false
    }

    var isSaving: Bool {
        if case .saving = self { return true }
        return false
    }

    var requiresResolution: Bool {
        switch self {
        case .clean: false
        case .saving, .dirty: true
        }
    }
}

private struct ActiveCaptureJournal: Codable {
    var take: TakeRecord
    var priorRoadmapState: RoadmapState
    var createdAt: Date
}

private struct LongTakeCaptureJournal: Codable {
    var id: UUID
    var relativeAudioPath: String
    var roadmapItemID: UUID
    var createdAt: Date
    var deviceSnapshot: AudioDeviceSnapshot
    var captureDiagnostics: CaptureDiagnostics?
}

private struct CalibrationCaptureJournal: Codable {
    var calibration: TuningCalibration
    var createdAt: Date
}

private struct PendingCapturePreflight: Codable {
    var id: UUID
    var startedAt: Date
    var sessionID: UUID
    var setupID: UUID
    var setupRevision: Int
    var relativeAudioPath: String
    var deviceSnapshot: AudioDeviceSnapshot
    var assignments: [CapturePreflightChannelAssignment]
    var bwfMetadata: BWFMetadata
    var protocolSnapshot: CapturePreflightProtocolSnapshot
}

private enum PersistenceCompletion {
    case saved(Date)
    case failed(String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var project: OrgRecProject?
    @Published var projectURL: URL?
    @Published var page: AppPage = .projects
    @Published var selectedRoadmapID: UUID? {
        didSet {
            if oldValue != selectedRoadmapID, capture.isRecording == false {
                includeInteractionSensorForNextTake = false
            }
        }
    }
    @Published var selectedTakeID: UUID?
    @Published var waveform: WaveformSummary?
    @Published var spectrogram: SpectrogramData?
    @Published private var workingOperationCount = 0
    @Published var notice: String?
    @Published var errorMessage: String?
    @Published private(set) var persistenceState: ProjectPersistenceState = .clean(lastSavedAt: nil)
    @Published var newProjectRequestID: UUID?
    @Published var navigatorURL = ""
    @Published var navigatorQuery = ""
    @Published var navigatorResults: [NavigatorOrganSummary] = []
    @Published var projectLibrary: [RecordingProjectSummary] = []
    @Published var importedVAO03Inspection: VAO03PackageInspection?
    @Published var importedVAO03WorkspaceURL: URL?
    @Published var importedVAO04Inspection: VAO04PackageInspection?
    @Published var importedVAO04WorkspaceURL: URL?
    @Published var importedVAO05Inspection: VAO05PackageInspection?
    @Published var importedVAO05WorkspaceURL: URL?
    @Published var auditReport: ProjectConsistencyReport?
    @Published var legacyInspection: LegacyDatasetInspection?
    @Published var legacyImportSourceURL: URL?
    @Published var legacyCandidateFilenames: [String] = []
    @Published var legacyImportStatus: String?
    @Published var grandOrgueInspection: GrandOrgueSampleSetInspection?
    @Published var grandOrgueODFURL: URL?
    @Published var grandOrgueSourcePageURL = ""
    @Published var grandOrgueImportStatus: String?
    @Published var podDatabaseInspection: PODDatabaseInspection?
    @Published var podDatabaseSourceURL: URL?
    @Published var podDatabaseCacheURL: URL?
    @Published var podDatabaseDownloadURL = ""
    @Published var podDatabaseStatus: String?
    @Published var isCalibrating = false
    @Published var temperamentProgress: String?
    @Published var selectedTemperamentReportID: UUID?
    @Published var timbreProgress: String?
    @Published var selectedTimbreReportID: UUID?
    @Published var longTakeSourceURL: URL?
    @Published var longTakeAnalysis: LongTakeAnalysis?
    @Published var longTakeStatus: String?
    @Published var longTakeAssignmentMode: LongTakeAssignmentMode = .ascendingFromAnchor
    @Published private(set) var isLongTakeRecording = false
    /// Explicit take-level consent. A configured or connected sensor never makes
    /// an ordinary audio take capture interaction data on its own.
    @Published var includeInteractionSensorForNextTake = false
    @Published private(set) var activeTakeIncludesInteractionSensor = false
    @Published var noiseGeocodeCandidates: [NoiseGeocodeCandidate] = []
    @Published private(set) var isSearchingNoiseVenue = false
    @Published private(set) var isAssessingNoiseContext = false
    @Published private(set) var isRunningCapturePreflight = false

    let capture = AudioCaptureEngine()
    let livePitch = LivePitchMonitor()
    let audioSystem = CoreAudioDeviceManager()
    let playback = AudioPlaybackController()
    let midiControl = MIDIControlCenter()
    let interactionSensors = InteractionSensorCenter()
    private let store = ProjectStore()
    private let analyzer = AudioAnalyzer()
    private let navigator = NavigatorClient()
    private let vaoImporter = VAOPackageImporter()
    private let vao03Reader = VAO03PackageReader()
    private let vao04Reader = VAO04PackageReader()
    private let vao05Reader = VAO05PackageReader()
    private let vao05Builder = VAO05PackageBuilder()
    private let iadImporter = IADPackageImporter()
    private let legacyImporter = LegacyAudioDatasetImporter()
    private let grandOrgueImporter = GrandOrgueSampleSetImporter()
    private let podDatabaseImporter = PODDatabaseImporter()
    private let longTakeSegmenter = LongTakeSegmenter()
    private let longTakeExporter = LongTakeAudioExporter()
    private let timbreAnalyzer = TimbreAnalysisEngine()
    private let noiseContextService = NoiseContextService()
    private var activeTakeID: UUID?
    private var activeCalibrationID: UUID?
    private var pendingLongTakeID: UUID?
    private var pendingLongTakeWasRecorded = false
    private var pendingLongTakeCaptureDiagnostics: CaptureDiagnostics?
    private var pendingLongTakeDeviceSnapshot: AudioDeviceSnapshot?
    private var pendingCapturePreflight: PendingCapturePreflight?
    private var capturePreflightAutoStopTask: Task<Void, Never>?
    private let lastProjectKey = "org.modavis.OrgRec.lastProjectPath"
    private let podDatabasePathKey = "org.modavis.OrgRec.podDatabasePath"
    private var isBootstrapping = false
    private var hasBootstrapped = false
    private var captureActivity: NSObjectProtocol?
    private let activeCaptureJournalFilename = ".active-capture.json"
    private let longTakeCaptureJournalFilename = ".long-take-capture.json"
    private let calibrationCaptureJournalFilename = ".calibration-capture.json"
    private let capturePreflightJournalFilename = ".capture-preflight.json"
    private var isStartingCapture = false
    private var isStoppingRecording = false
    private var isStoppingLongTake = false
    private var isStoppingCalibration = false
    private var isStartingCapturePreflight = false
    private var isStoppingCapturePreflight = false
    private var isHandlingCriticalCaptureStop = false
    private var analysisOperationTokens: [UUID: UUID] = [:]
    private var persistenceGeneration = 0
    private var persistenceOperationsInFlight = 0
    private var latestPersistenceCompletion: (generation: Int, outcome: PersistenceCompletion)?
    private var pendingOpenURLs: [URL] = []
    private var isProcessingOpenURLs = false

    var isWorking: Bool {
        get { workingOperationCount > 0 }
        set {
            if newValue {
                workingOperationCount += 1
            } else {
                workingOperationCount = max(0, workingOperationCount - 1)
            }
        }
    }

    var selectedRoadmapItem: RoadmapItem? {
        guard let id = selectedRoadmapID else { return nil }
        return project?.roadmap.first { $0.id == id }
    }

    var selectedTake: TakeRecord? {
        guard let id = selectedTakeID else { return nil }
        return project?.takes.first { $0.id == id }
    }

    var selectedTakeCaptureIntegrityIssue: String? {
        selectedTake.flatMap { captureIntegrityIssue(for: $0) }
    }

    /// Capture faults are evidence defects, not acoustic-analysis warnings.
    /// Reanalysis may add useful measurements but can never erase this gate.
    private func captureIntegrityIssue(for take: TakeRecord) -> String? {
        if let fault = take.captureIntegrityFaults?.first {
            return fault.message
        }
        if let diagnostics = take.captureDiagnostics {
            if diagnostics.droppedBuffers > 0 {
                return "The real-time writer dropped \(diagnostics.droppedBuffers) audio buffer(s)."
            }
            if diagnostics.discontinuityCount > 0 {
                return "The captured stream contains \(diagnostics.discontinuityCount) sample-time discontinuity event(s)."
            }
            if let fault = diagnostics.faults.first {
                return fault.message
            }
        }
        let reason = take.reviewReason?.lowercased() ?? ""
        let hardMarkers = [
            "broadcast wave metadata finalization failed",
            "interaction-sensor finalization failed",
            "opening project save failed",
            "recording finalization was interrupted",
            "no recoverable",
        ]
        if hardMarkers.contains(where: reason.contains) {
            return take.reviewReason ?? "The retained capture has an unresolved integrity fault."
        }
        return nil
    }

    var activeInteractionSensorConfiguration: InteractionSensorConfiguration? {
        guard let id = project?.activeInteractionSensorConfigurationID else { return nil }
        return project?.interactionSensorConfigurations?.first { $0.id == id }
    }

    var activeInteractionSensorCalibration: InteractionSensorCalibration? {
        guard let configuration = activeInteractionSensorConfiguration,
              let calibrationID = configuration.currentCalibrationID else { return nil }
        return project?.interactionSensorCalibrations?.first { $0.id == calibrationID }
    }

    var activeInteractionSensorMatchesSelectedTarget: Bool? {
        guard let targetID = activeInteractionSensorConfiguration?.targetComponentID,
              targetID.isEmpty == false,
              let item = selectedRoadmapItem else { return nil }
        return targetID == item.component.id
            || targetID == item.component.parentComponentID
            || targetID == item.physicalSoundTargetID
    }

    var willCaptureInteractionSensorForNextTake: Bool {
        guard let configuration = activeInteractionSensorConfiguration,
              configuration.capturePolicy != .disabled else { return false }
        return includeInteractionSensorForNextTake
    }

    func requiredCaptureState(for item: RoadmapItem) -> CaptureStateSnapshot? {
        project?.requiredCaptureState(for: item)
    }

    var longTakeCandidateItems: [RoadmapItem] {
        guard let project, let selected = selectedRoadmapItem else { return [] }
        let rankID = selected.component.parentComponentID
        return project.roadmap.filter { item in
            guard item.component.midiNote != nil, item.component.expectedFrequencyHz != nil else { return false }
            let sameSound: Bool
            if let rankID {
                sameSound = item.component.parentComponentID == rankID
            } else {
                sameSound = item.component.id == selected.component.id
                    || (item.component.label == selected.component.label && item.component.division == selected.component.division)
            }
            return sameSound
                && item.technique == selected.technique
                && item.setupID == selected.setupID
                && item.registrationID == selected.registrationID
        }.sorted {
            ($0.component.midiNote ?? .max) < ($1.component.midiNote ?? .max)
        }
    }

    var longTakeScopeLabel: String {
        guard let selected = selectedRoadmapItem else { return "No rank selected" }
        let count = longTakeCandidateItems.count
        return "\(selected.component.label) · \(selected.component.division) · \(count) roadmap notes"
    }

    var selectedLoopPointSets: [LoopPointSet] {
        (selectedTake?.loopPointSets ?? []).sorted {
            func order(_ status: LoopPointSetStatus) -> Int {
                switch status {
                case .accepted: 0
                case .asserted: 1
                case .proposed: 2
                case .rejected: 3
                case .superseded: 4
                }
            }
            if $0.status != $1.status { return order($0.status) < order($1.status) }
            return ($0.candidateRank ?? .max) < ($1.candidateRank ?? .max)
        }
    }

    var acceptedLoopPointSet: LoopPointSet? {
        guard let acceptedID = selectedTake?.acceptedLoopPointSetID else { return nil }
        return selectedTake?.loopPointSets?.first { $0.id == acceptedID && $0.status == .accepted }
    }

    var coverage: CoverageSummary {
        RoadmapEngine.coverage(project?.roadmap ?? [])
    }

    var activeSession: RecordingSession? {
        project?.recordingSessions?.last(where: { $0.endedAt == nil })
    }

    var currentCapturePreflightReport: CapturePreflightReport? {
        guard let session = activeSession,
              let setupID = selectedRoadmapItem?.setupID,
              let setup = project?.setups.first(where: { $0.id == setupID }),
              let device = audioSystem.selectedDevice else { return nil }
        return session.capturePreflightReports?.last(where: {
            $0.matches(
                sessionID: session.id,
                setupID: setup.id,
                setupRevision: setup.revision,
                deviceUID: device.uid,
                sampleRate: audioSystem.selectedSampleRate,
                inputChannels: device.inputChannels
            )
        })
    }

    var mostRecentCapturePreflightReport: CapturePreflightReport? {
        activeSession?.capturePreflightReports?.max(by: { $0.recordedAt < $1.recordedAt })
    }

    var canStartCapturePreflight: Bool {
        guard projectURL != nil,
              activeSession != nil,
              let setupID = selectedRoadmapItem?.setupID,
              let setup = project?.setups.first(where: { $0.id == setupID }),
              setup.placements.isEmpty == false,
              let device = audioSystem.selectedDevice,
              device.inputChannels > 0 else { return false }
        let channels = setup.placements.map(\.channelNumber)
        guard Set(channels).count == channels.count,
              channels.allSatisfy({ (1...device.inputChannels).contains($0) }) else { return false }
        return hasActiveCapture == false && isWorking == false
    }

    var capturePreflightContextLabel: String {
        guard let setupID = selectedRoadmapItem?.setupID,
              let setup = project?.setups.first(where: { $0.id == setupID }) else {
            return "Select a Roadmap capture with a documented microphone setup."
        }
        guard let device = audioSystem.selectedDevice else {
            return "\(setup.name) · select a Core Audio input in Setup."
        }
        return "\(setup.name) r\(setup.revision) · \(device.name) · \(Int(audioSystem.selectedSampleRate)) Hz"
    }

    var activeSessionPlan: RecordingSessionPlan? {
        guard let project else { return nil }
        if let planID = activeSession?.sessionPlanID,
           let plan = project.sessionPlans?.first(where: { $0.id == planID }) {
            return plan
        }
        return project.sessionPlans?.last(where: { $0.status == .active || $0.status == .frozen })
    }

    var roadmapSessionPlan: RecordingSessionPlan? {
        project?.sessionPlans?.last(where: { $0.status == .frozen }) ?? activeSessionPlan
    }

    var activeNoiseContext: NoiseContextAssessment? {
        if let assessment = activeSession?.noiseContextAssessment { return assessment }
        guard let assessmentID = activeSessionPlan?.noiseContextAssessmentID else { return nil }
        return project?.noiseContextAssessments?.first(where: { $0.id == assessmentID })
    }

    var activePlanQueueProgress: (completed: Int, total: Int)? {
        guard let plan = activeSessionPlan else { return nil }
        return planQueueProgress(plan)
    }

    func noiseContext(for plan: RecordingSessionPlan) -> NoiseContextAssessment? {
        if activeSession?.sessionPlanID == plan.id, let assessment = activeSession?.noiseContextAssessment {
            return assessment
        }
        guard let assessmentID = plan.noiseContextAssessmentID else { return nil }
        return project?.noiseContextAssessments?.first(where: { $0.id == assessmentID })
    }

    func planQueueProgress(_ plan: RecordingSessionPlan) -> (completed: Int, total: Int)? {
        guard let project else { return nil }
        let byID = Dictionary(project.roadmap.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let completed = plan.queue.reduce(0) { count, queued in
            count + (byID[queued.roadmapItemID]?.state == .accepted ? 1 : 0)
        }
        return (completed, plan.queue.count)
    }

    var acceptedCalibration: TuningCalibration? {
        guard let id = activeSession?.tuningCalibrationID else { return nil }
        return project?.tuningCalibrations?.first { $0.id == id && $0.status == .accepted }
    }

    var latestCalibration: TuningCalibration? {
        guard let sessionID = activeSession?.id else { return nil }
        return project?.tuningCalibrations?.last { $0.sessionID == sessionID }
    }

    var calibrationCandidates: [RoadmapItem] {
        guard let project else { return [] }
        var seen = Set<String>()
        return project.roadmap.filter { item in
            guard item.component.midiNote == 69 else { return false }
            let feet = item.component.footHeight?.lowercased() ?? ""
            guard feet.contains("8") || feet.isEmpty else { return false }
            let key = item.component.parentComponentID ?? item.component.id
            return seen.insert(key).inserted
        }
    }

    var temperamentRankOptions: [TemperamentRankOption] {
        guard let project else { return [] }
        let eligible = project.roadmap.filter { item in
            guard item.component.midiNote != nil else { return false }
            let feet = item.component.footHeight?.lowercased() ?? ""
            return feet.contains("8") && feet.contains("16") == false
        }
        return Dictionary(grouping: eligible) { $0.component.parentComponentID ?? $0.component.id }
            .compactMap { id, items in
                guard let first = items.first else { return nil }
                let takeIDs = Set(items.flatMap(\.takeIDs))
                return TemperamentRankOption(
                    id: id,
                    label: first.component.label,
                    division: first.component.division,
                    footHeight: first.component.footHeight ?? "8′",
                    pitchClassCount: Set(items.compactMap { $0.component.midiNote.map { (($0 % 12) + 12) % 12 } }).count,
                    takeCount: project.takes.filter { takeIDs.contains($0.id) }.count
                )
            }
            .filter { $0.takeCount > 0 }
            .sorted {
                if $0.pitchClassCount != $1.pitchClassCount { return $0.pitchClassCount > $1.pitchClassCount }
                return $0.label.localizedStandardCompare($1.label) == .orderedAscending
            }
    }

    var selectedTemperamentReport: TemperamentAnalysisReport? {
        if let selectedTemperamentReportID,
           let report = project?.temperamentAnalyses?.first(where: { $0.id == selectedTemperamentReportID }) {
            return report
        }
        return project?.temperamentAnalyses?.last
    }

    var timbreRankOptions: [TimbreRankOption] {
        guard let project else { return [] }
        let eligible = project.roadmap.filter { $0.component.midiNote != nil && $0.takeIDs.isEmpty == false }
        return Dictionary(grouping: eligible) { $0.component.parentComponentID ?? $0.component.id }
            .compactMap { id, items in
                guard let first = items.first else { return nil }
                let takeIDs = Set(items.flatMap(\.takeIDs))
                let usableTakes = project.takes.filter {
                    takeIDs.contains($0.id) && ![TakeStatus.failed, .rejected, .recording].contains($0.status)
                }
                guard usableTakes.isEmpty == false else { return nil }
                return TimbreRankOption(
                    id: id,
                    label: first.component.label,
                    division: first.component.division,
                    footHeight: first.component.footHeight ?? "—",
                    componentKind: first.component.kind,
                    noteCount: Set(items.compactMap(\.component.midiNote)).count,
                    takeCount: usableTakes.count
                )
            }
            .sorted {
                if $0.label != $1.label { return $0.label.localizedStandardCompare($1.label) == .orderedAscending }
                return $0.division.localizedStandardCompare($1.division) == .orderedAscending
            }
    }

    var selectedTimbreReport: TimbreAnalysisReport? {
        if let selectedTimbreReportID,
           let report = project?.timbreAnalyses?.first(where: { $0.id == selectedTimbreReportID }) {
            return report
        }
        return project?.timbreAnalyses?.last
    }

    var captureReadiness: [ConsistencyIssue] {
        guard let project else { return [] }
        var issues = ProjectConsistencyAuditor.captureReadiness(project: project, item: selectedRoadmapItem)
        guard let device = audioSystem.selectedDevice else {
            issues.append(ConsistencyIssue(
                id: "readiness.audio-device",
                severity: .blocker,
                scope: .recording,
                title: "No Core Audio input selected",
                detail: "OrgRec has no active capture endpoint.",
                remediation: "Choose and apply an input interface in Setup.",
                roadmapItemID: selectedRoadmapID
            ))
            return issues
        }
        if let setupID = selectedRoadmapItem?.setupID,
           let setup = project.setups.first(where: { $0.id == setupID }),
           let required = setup.placements.map(\.channelNumber).max(),
           required > device.inputChannels {
            issues.append(ConsistencyIssue(
                id: "readiness.interface-channels",
                severity: .blocker,
                scope: .recording,
                title: "Interface has too few input channels",
                detail: "Setup requires channel \(required); \(device.name) exposes \(device.inputChannels).",
                remediation: "Choose a larger interface or revise the microphone setup.",
                roadmapItemID: selectedRoadmapID
            ))
        }
        if let session = activeSession,
           let setupID = selectedRoadmapItem?.setupID,
           let setup = project.setups.first(where: { $0.id == setupID }),
           setup.placements.isEmpty == false,
           (setup.placements.map(\.channelNumber).max() ?? 0) <= device.inputChannels {
            if let report = currentCapturePreflightReport {
                switch report.verdict {
                case .passed:
                    break
                case .attention:
                    let warningTitles = report.findings
                        .filter { $0.severity == .warning }
                        .prefix(3)
                        .map(\.title)
                        .joined(separator: "; ")
                    issues.append(ConsistencyIssue(
                        id: "readiness.capture-preflight-attention",
                        severity: .warning,
                        scope: .recording,
                        title: "Signal path passed with cautions",
                        detail: warningTitles.isEmpty ? "The current rehearsal contains non-blocking acoustical cautions." : warningTitles,
                        remediation: "Review the per-channel rehearsal results in Field QA and repeat it if conditions can be improved.",
                        roadmapItemID: selectedRoadmapID
                    ))
                case .failed:
                    let blockerTitles = report.findings
                        .filter { $0.severity == .blocker }
                        .prefix(3)
                        .map(\.title)
                        .joined(separator: "; ")
                    issues.append(ConsistencyIssue(
                        id: "readiness.capture-preflight-failed",
                        severity: .blocker,
                        scope: .recording,
                        title: "Signal-path rehearsal failed",
                        detail: blockerTitles.isEmpty ? "The current interface and setup revision did not pass preflight." : blockerTitles,
                        remediation: "Correct the identified routing, gain, noise, or integrity fault and repeat the rehearsal in Field QA.",
                        roadmapItemID: selectedRoadmapID
                    ))
                }
            } else {
                issues.append(ConsistencyIssue(
                    id: "readiness.capture-preflight-missing",
                    severity: .blocker,
                    scope: .recording,
                    title: "Current signal path has not been rehearsed",
                    detail: "Session \(session.sessionCode) has no retained line check for \(setup.name) r\(setup.revision) on \(device.name) at \(Int(audioSystem.selectedSampleRate)) Hz.",
                    remediation: "Run the 12-second quiet-then-loud signal-path rehearsal in Field QA.",
                    roadmapItemID: selectedRoadmapID
                ))
            }
        }
        if let protocolSnapshot = selectedRoadmapItem?.spatialAcousticProtocol {
            guard let geometry = project.spatialGeometrySnapshots?.first(where: { $0.id == protocolSnapshot.geometrySnapshotID }) else {
                issues.append(ConsistencyIssue(
                    id: "readiness.p2-geometry-missing", severity: .blocker, scope: .recording,
                    title: "Spatial geometry snapshot is missing",
                    detail: "This P2 response capture cannot freeze its source and propagation geometry.",
                    remediation: "Restore or re-plan the spatial response series.", roadmapItemID: selectedRoadmapID
                ))
                return issues
            }
            if geometry.fingerprint != protocolSnapshot.geometryFingerprint {
                issues.append(ConsistencyIssue(
                    id: "readiness.p2-geometry-fingerprint", severity: .blocker, scope: .recording,
                    title: "Spatial geometry has changed",
                    detail: "The Roadmap protocol was compiled against a different geometry revision.",
                    remediation: "Re-plan the response series against the documented revision.", roadmapItemID: selectedRoadmapID
                ))
            }
            if let setupID = selectedRoadmapItem?.setupID,
               !geometry.referenceFrame.compatibleMicrophoneSetupIDs.contains(setupID) {
                issues.append(ConsistencyIssue(
                    id: "readiness.p2-coordinate-frame", severity: .blocker, scope: .recording,
                    title: "Microphone geometry uses another coordinate frame",
                    detail: "P2 source-to-receiver geometry is only comparable when source/path and microphone coordinates share the documented frame.",
                    remediation: "Choose a compatible setup or revise the geometry snapshot before recording.", roadmapItemID: selectedRoadmapID
                ))
            }
        }
        if activeSession?.noiseContextAssessment == nil {
            issues.append(ConsistencyIssue(
                id: "readiness.noise-context",
                severity: .warning,
                scope: .recording,
                title: "Surrounding noise context not assessed",
                detail: "This session has no frozen map-based or manually reviewed external-noise assessment.",
                remediation: "Use Plan session in the Roadmap, or document the conditions manually in session paradata.",
                roadmapItemID: selectedRoadmapID
            ))
        } else if let assessment = activeSession?.noiseContextAssessment,
                  assessment.actionableFindings.contains(where: { $0.planningPriority == .high && $0.disposition == .unverified }) {
            issues.append(ConsistencyIssue(
                id: "readiness.noise-context-unverified",
                severity: .warning,
                scope: .recording,
                title: "High-priority external noise remains unverified",
                detail: assessment.summary,
                remediation: "Confirm the current venue conditions and mark noise incidents during capture when they occur.",
                roadmapItemID: selectedRoadmapID
            ))
        }
        if let sensorConfiguration = activeInteractionSensorConfiguration,
           willCaptureInteractionSensorForNextTake {
            if interactionSensors.isStreaming == false || interactionSensors.activeConfigurationID != sensorConfiguration.id {
                issues.append(ConsistencyIssue(
                    id: "readiness.interaction-sensor",
                    severity: .warning,
                    scope: .recording,
                    title: "Optional interaction capture will be skipped",
                    detail: "\(sensorConfiguration.name) was selected for this take but the exact configuration is not streaming. Audio recording remains available.",
                    remediation: "Connect it in Interaction Sensors, or turn off the per-take interaction-data switch.",
                    roadmapItemID: selectedRoadmapID
                ))
            } else if interactionSensors.diagnosticChecks.contains(where: { $0.state == .fail }) {
                issues.append(ConsistencyIssue(
                    id: "readiness.interaction-sensor-health",
                    severity: .warning,
                    scope: .recording,
                    title: "Optional interaction sensor failed a live check",
                    detail: interactionSensors.diagnosticChecks.filter { $0.state == .fail }.map(\.title).joined(separator: "; "),
                    remediation: "Resolve the sensor fault or record audio without optional interaction evidence.",
                    roadmapItemID: selectedRoadmapID
                ))
            }
            if activeInteractionSensorMatchesSelectedTarget == false {
                issues.append(ConsistencyIssue(
                    id: "readiness.interaction-sensor-target",
                    severity: .warning,
                    scope: .recording,
                    title: "Sensor is configured for another mechanism",
                    detail: "\(sensorConfiguration.name) targets \(sensorConfiguration.targetComponentLabel), not the selected Roadmap item.",
                    remediation: "Use the sensor only if this is an intentional representative-mechanism comparison; otherwise turn it off for this take.",
                    roadmapItemID: selectedRoadmapID
                ))
            }
            if activeInteractionSensorCalibration == nil {
                issues.append(ConsistencyIssue(
                    id: "readiness.interaction-sensor-calibration",
                    severity: .warning,
                    scope: .recording,
                    title: "Interaction sensor has no accepted calibration",
                    detail: "The take can retain raw angular and acceleration dynamics, but calibrated travel is unavailable.",
                    remediation: "Complete the guided stationary and full-travel calibration if quantitative motion is required.",
                    roadmapItemID: selectedRoadmapID
                ))
            }
        }
        return issues
    }

    var captureIsReady: Bool {
        captureReadiness.contains { $0.severity == .blocker } == false
    }

    var canAttachNavigatorOrganToActiveProject: Bool {
        guard let project else { return false }
        return project.snapshot.endpoint == "manual://orgrec-project"
            && project.roadmap.isEmpty
            && project.takes.isEmpty
    }

    var groupedProjects: [OrganProjectGroup] {
        let groups = Dictionary(grouping: projectLibrary) { summary in
            summary.organMDVSID.isEmpty ? "name:\(summary.organName.lowercased())" : summary.organMDVSID
        }
        return groups.map { key, projects in
            let sorted = projects.sorted { $0.updatedAt > $1.updatedAt }
            return OrganProjectGroup(
                id: key,
                organName: sorted.first?.organName ?? "Unnamed organ",
                organMDVSID: sorted.first?.organMDVSID ?? "",
                projects: sorted
            )
        }.sorted { $0.organName.localizedStandardCompare($1.organName) == .orderedAscending }
    }

    func bootstrap() async {
        guard hasBootstrapped == false, isBootstrapping == false else { return }
        isBootstrapping = true
        isWorking = true
        defer {
            isWorking = false
            isBootstrapping = false
        }
        do {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("OrgRec/Projects", isDirectory: true)
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let demoURL = support.appendingPathComponent("St-Nikolai-Demo.orgrec", isDirectory: true)
            let rememberedURL = UserDefaults.standard.string(forKey: lastProjectKey).map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
            let url = rememberedURL.flatMap {
                FileManager.default.fileExists(atPath: $0.appendingPathComponent(ProjectStore.projectFilename).path) ? $0 : nil
            } ?? demoURL
            let loaded: OrgRecProject
            if FileManager.default.fileExists(atPath: url.appendingPathComponent(ProjectStore.projectFilename).path) {
                loaded = try await store.load(from: url)
            } else {
                let demo = DemoProjectFactory.make()
                try await store.createPackage(at: url, project: demo)
                loaded = demo
            }
            var recovered = await store.recoverInterruptedTakes(in: loaded, packageURL: url)
            let recoveredJournal = recoverActiveCaptureJournal(in: &recovered, packageURL: url)
            let recoveredLongTake = recoverLongTakeCaptureJournal(in: recovered, packageURL: url)
            let recoveredCalibration = recoverCalibrationCaptureJournal(in: &recovered, packageURL: url)
            let recoveredPreflight = recoverCapturePreflightJournal(in: &recovered, packageURL: url)
            if recovered.organComponents == nil {
                var seen = Set<String>()
                recovered.organComponents = recovered.roadmap.compactMap { item in
                    seen.insert(item.component.id).inserted ? item.component : nil
                }
            }
            let canUpgradePhysicalRoadmap = recovered.takes.isEmpty
                && recovered.organComponents?.isEmpty == false
                && recovered.roadmapCompilation?.compilerContract != "orgrec.modavis-roadmap-compiler/v5"
            if canUpgradePhysicalRoadmap {
                applyPhysicalRoadmapRecompilation(to: &recovered)
            } else if recovered.roadmapCompilation == nil {
                recovered.roadmapCompilation = RoadmapEngine.compileSpecification(
                    components: recovered.organComponents ?? [],
                    recipe: recovered.recipe,
                    setupIDs: recovered.setups.map(\.id),
                    relationships: recovered.componentRelationships ?? [],
                    physicalPipeMappings: recovered.physicalPipeMappings ?? [],
                    sharingAssertions: recovered.pipeSharingAssertions ?? []
                ).report
            }
            if recovered.organMDVSID == "MDVS:ORGN:DEMO", recovered.takes.isEmpty {
                for index in recovered.roadmap.indices {
                    recovered.roadmap[index].state = index == 0 ? .queued : .missing
                    recovered.roadmap[index].takeIDs = []
                }
            }
            ensureActiveSession(in: &recovered)
            refreshCaptureStateLibrary(in: &recovered)
            recovered.spatialAcousticResponseComparisons = P2AnalysisEngine.responseComparisons(project: recovered)
            project = recovered
            projectURL = url
            let recoveredSession = recovered.recordingSessions?.last(where: { $0.endedAt == nil })
            selectedRoadmapID = recoveredLongTake?.roadmapItemID
                ?? SessionPlanningEngine.nextPlannedRoadmapItem(in: recovered, session: recoveredSession)?.id
                ?? recovered.roadmap.first?.id
            selectedTakeID = recovered.takes.last?.id
            if let recoveredLongTake {
                pendingLongTakeID = recoveredLongTake.id
                pendingLongTakeWasRecorded = true
                pendingLongTakeDeviceSnapshot = recoveredLongTake.deviceSnapshot
                pendingLongTakeCaptureDiagnostics = recoveredLongTake.captureDiagnostics
                longTakeSourceURL = url.appendingPathComponent(recoveredLongTake.relativeAudioPath)
                longTakeAnalysis = nil
                longTakeStatus = "Recovered a continuous recording master. Analyze it, then create reviewable note takes."
            }
            if let selectedTakeID {
                loadAnalysisArtifacts(takeID: selectedTakeID, packageURL: url)
                try? preparePlayback(takeID: selectedTakeID)
            }
            try await store.save(recovered, at: url)
            if recoveredJournal { clearActiveCaptureJournal(in: url) }
            if recoveredCalibration { clearCalibrationCaptureJournal(in: url) }
            if recoveredPreflight { clearCapturePreflightJournal(in: url) }
            UserDefaults.standard.set(url.path, forKey: lastProjectKey)
            if let path = UserDefaults.standard.string(forKey: podDatabasePathKey) {
                let databaseURL = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: databaseURL.path),
                   let inspection = try? PODDatabaseReader.inspect(databaseURL: databaseURL),
                   inspection.isCompatible,
                   inspection.matchesPublishedArtifact {
                    podDatabaseCacheURL = databaseURL
                    podDatabaseInspection = inspection
                    podDatabaseStatus = "Loaded the verified local POD \(inspection.releaseVersion ?? "1.5") database."
                } else {
                    UserDefaults.standard.removeObject(forKey: podDatabasePathKey)
                }
            }
            await refreshProjectLibrary()
            await runConsistencyAudit()
            if recoveredJournal {
                notice = "Recovered a finalized recording that had not yet reached the project manifest. Review it before continuing."
            } else if recoveredLongTake != nil {
                notice = "Recovered a continuous recording master that was finalized before the previous session closed."
            } else if recoveredCalibration {
                notice = "Recovered an interrupted A4 calibration recording. Review or replace it before accepting a field pitch."
            } else if recoveredPreflight {
                notice = "Recovered an interrupted signal-path rehearsal as failed evidence. Repeat it before recording."
            }
            hasBootstrapped = true
        } catch {
            if project != nil {
                persistenceState = .dirty(message: error.localizedDescription)
            }
            errorMessage = error.localizedDescription
        }
    }

    func refreshProjectLibrary() async {
        do {
            let directory = try projectsDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let urls = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { $0.pathExtension.lowercased() == "orgrec" }
            var summaries: [RecordingProjectSummary] = []
            for url in urls {
                guard let candidate = try? await store.load(from: url) else { continue }
                summaries.append(projectSummary(candidate, url: url))
            }
            projectLibrary = summaries.sorted { $0.updatedAt > $1.updatedAt }
        } catch {
            errorMessage = "Could not refresh the project library: \(error.localizedDescription)"
        }
    }

    /// Finder document-open events can arrive while SwiftUI's launch task is
    /// still restoring the last project. Queue and replay them only after that
    /// bootstrap transaction has fully completed.
    func openIncomingURL(_ url: URL) async {
        pendingOpenURLs.append(url)
        guard isProcessingOpenURLs == false else { return }
        isProcessingOpenURLs = true
        defer { isProcessingOpenURLs = false }

        if hasBootstrapped == false {
            await bootstrap()
        }
        while isBootstrapping {
            try? await Task.sleep(for: .milliseconds(25))
        }
        guard hasBootstrapped else {
            pendingOpenURLs.removeAll()
            if errorMessage == nil {
                errorMessage = "OrgRec could not finish restoring its project library, so the requested document was not opened."
            }
            return
        }
        while pendingOpenURLs.isEmpty == false {
            let next = pendingOpenURLs.removeFirst()
            await importProject(from: next)
        }
    }

    func requestNewProject() {
        page = .projects
        newProjectRequestID = UUID()
    }

    func openProject(_ summary: RecordingProjectSummary, destinationPage: AppPage? = nil) async {
        let resolvedPage = destinationPage ?? (summary.roadmapItems == 0 ? .organSearch : .roadmap)
        _ = await openProject(at: summary.url, destinationPage: resolvedPage)
    }

    @discardableResult
    func openProject(
        at url: URL,
        destinationPage: AppPage = .roadmap,
        allowingCurrentOperation: Bool = false
    ) async -> Bool {
        if let reason = projectSwitchBlockReason(allowingCurrentOperation: allowingCurrentOperation) {
            errorMessage = reason
            return false
        }
        isWorking = true
        defer { isWorking = false }
        do {
            var loaded = try await store.load(from: url)
            loaded = await store.recoverInterruptedTakes(in: loaded, packageURL: url)
            let recoveredJournal = recoverActiveCaptureJournal(in: &loaded, packageURL: url)
            let recoveredLongTake = recoverLongTakeCaptureJournal(in: loaded, packageURL: url)
            let recoveredCalibration = recoverCalibrationCaptureJournal(in: &loaded, packageURL: url)
            let recoveredPreflight = recoverCapturePreflightJournal(in: &loaded, packageURL: url)
            ensureActiveSession(in: &loaded)
            loaded.spatialAcousticResponseComparisons = P2AnalysisEngine.responseComparisons(project: loaded)
            try await store.save(loaded, at: url)
            if recoveredJournal { clearActiveCaptureJournal(in: url) }
            if recoveredCalibration { clearCalibrationCaptureJournal(in: url) }
            if recoveredPreflight { clearCapturePreflightJournal(in: url) }

            playback.stop()
            longTakeSourceURL = nil
            longTakeAnalysis = nil
            longTakeStatus = nil
            pendingLongTakeID = nil
            pendingLongTakeWasRecorded = false
            pendingLongTakeCaptureDiagnostics = nil
            pendingLongTakeDeviceSnapshot = nil
            project = loaded
            projectURL = url
            persistenceState = .clean(lastSavedAt: .now)
            includeInteractionSensorForNextTake = false
            activeTakeIncludesInteractionSensor = false
            let loadedSession = loaded.recordingSessions?.last(where: { $0.endedAt == nil })
            selectedRoadmapID = recoveredLongTake?.roadmapItemID
                ?? SessionPlanningEngine.nextPlannedRoadmapItem(in: loaded, session: loadedSession)?.id
                ?? loaded.roadmap.first?.id
            selectedTakeID = loaded.takes.last?.id
            if let recoveredLongTake {
                pendingLongTakeID = recoveredLongTake.id
                pendingLongTakeWasRecorded = true
                pendingLongTakeDeviceSnapshot = recoveredLongTake.deviceSnapshot
                pendingLongTakeCaptureDiagnostics = recoveredLongTake.captureDiagnostics
                longTakeSourceURL = url.appendingPathComponent(recoveredLongTake.relativeAudioPath)
                longTakeStatus = "Recovered a continuous recording master. Analyze it, then create reviewable note takes."
            }
            waveform = nil
            spectrogram = nil
            if let selectedTakeID {
                loadAnalysisArtifacts(takeID: selectedTakeID, packageURL: url)
                try? preparePlayback(takeID: selectedTakeID)
            }
            UserDefaults.standard.set(url.path, forKey: lastProjectKey)
            page = destinationPage
            await refreshProjectLibrary()
            await runConsistencyAudit()
            if recoveredJournal {
                notice = "Opened \(loaded.title) and recovered an interrupted recording for review."
            } else if recoveredLongTake != nil {
                notice = "Opened \(loaded.title) and recovered its retained continuous recording master."
            } else if recoveredCalibration {
                notice = "Opened \(loaded.title) and recovered an interrupted A4 calibration."
            } else if recoveredPreflight {
                notice = "Opened \(loaded.title) and recovered an interrupted signal-path rehearsal as failed evidence."
            } else {
                notice = "Opened \(loaded.title)."
            }
            return true
        } catch {
            errorMessage = "Could not open the project: \(error.localizedDescription)"
            return false
        }
    }

    private func projectSwitchBlockReason(allowingCurrentOperation: Bool) -> String? {
        if hasActiveCapture || isStartingCapture {
            return "Stop and finalize the active recording before changing projects."
        }
        if persistenceState.requiresResolution {
            return "Finish or retry saving the active project before changing projects."
        }
        if hasRecoverableLongTakeMaster {
            return "Create note takes from the retained continuous master before changing projects."
        }
        if isWorking && (allowingCurrentOperation == false || workingOperationCount > 1) {
            return "Wait for the current project operation to finish before changing projects."
        }
        return nil
    }

    func createManualProject(title: String, organName: String, organMDVSID: String, venueName: String) async {
        if let reason = projectSwitchBlockReason(allowingCurrentOperation: false) {
            errorMessage = reason
            return
        }
        let cleanOrgan = organName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanOrgan.isEmpty == false else {
            errorMessage = "Enter the pipe organ's name."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let projectID = UUID()
            let localID = organMDVSID.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedID = localID.isEmpty ? "LOCAL:ORGAN:\(projectID.uuidString.prefix(12))" : localID
            let payload = Data("manual-orgrec-project:\(projectID.uuidString)".utf8)
            let emptyReport = RoadmapCompilationReport(
                sourceStopCount: 0,
                sourceCouplerCount: 0,
                sourceAccessoryCount: 0,
                explicitPipePositionCount: 0,
                generatedAtomicSoundCount: 0,
                generatedControlTestCount: 0,
                theoreticalRegistrationStateCount: "0",
                assumedCompassCount: 0,
                warnings: ["No MODAVIS specification is attached yet. Find the organ in Navigator before planning recordings."],
                referencePitchHz: 440,
                tuningPitchAssumed: true
            )
            let template = project
            let created = OrgRecProject(
                id: projectID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "\(cleanOrgan) · Recording project" : title,
                organMDVSID: resolvedID,
                organName: cleanOrgan,
                venueName: venueName.trimmingCharacters(in: .whitespacesAndNewlines),
                snapshot: MODAVISSnapshot(endpoint: "manual://orgrec-project", payloadSHA256: payload.sha256Hex),
                recipe: template?.recipe ?? CaptureRecipe(),
                devices: template?.devices ?? [],
                setups: template?.setups ?? [],
                spectrogramConfiguration: template?.spectrogramConfiguration ?? SpectrogramConfiguration(),
                organComponents: [],
                roadmapCompilation: emptyReport
            )
            let destination = uniqueManagedProjectURL(stem: title.isEmpty ? cleanOrgan : title)
            try await store.createPackage(at: destination, project: created)
            guard await openProject(at: destination, destinationPage: .organSearch, allowingCurrentOperation: true) else { return }
            notice = "Created \(created.title). Search Navigator to attach the organ specification and build its roadmap."
        } catch {
            errorMessage = "Could not create the project: \(error.localizedDescription)"
        }
    }

    func importProject(from source: URL) async {
        if let reason = projectSwitchBlockReason(allowingCurrentOperation: false) {
            errorMessage = reason
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            if source.pathExtension.lowercased() == "vao" {
                let formatVersion = try VAO05PackageReader.formatVersion(of: source)
                if formatVersion == VAO05Contract.formatVersion {
                    let destination = uniqueManagedVAOWorkspaceURL(stem: source.deletingPathExtension().lastPathComponent)
                    let inspection = try await vao05Reader.importWorkspace(from: source, to: destination)
                    importedVAO05Inspection = inspection
                    importedVAO05WorkspaceURL = destination
                    page = .projects
                    notice = "Imported and verified VAO \(VAO05Contract.formatVersion) “\(inspection.displayTitle)” with \(inspection.realizationCount) realizations, \(inspection.trackCount) multimodal tracks, and \(inspection.scientificRecordCount) scientific records."
                    return
                }
                if formatVersion == VAO04Contract.formatVersion {
                    let destination = uniqueManagedVAOWorkspaceURL(stem: source.deletingPathExtension().lastPathComponent)
                    let inspection = try await vao04Reader.importWorkspace(from: source, to: destination)
                    importedVAO04Inspection = inspection
                    importedVAO04WorkspaceURL = destination
                    page = .projects
                    notice = "Imported and verified VAO \(VAO04Contract.formatVersion) “\(inspection.displayTitle)” with \(inspection.manifest.realizations.count) realizations, \(inspection.trackCount) multimodal tracks, and \(inspection.scientificRecordCount) scientific records."
                    return
                }
                if formatVersion == VAO03Contract.formatVersion {
                    let destination = uniqueManagedVAOWorkspaceURL(stem: source.deletingPathExtension().lastPathComponent)
                    let inspection = try await vao03Reader.importWorkspace(from: source, to: destination)
                    importedVAO03Inspection = inspection
                    importedVAO03WorkspaceURL = destination
                    page = .projects
                    let scene = inspection.acousticScene
                    let playable = inspection.playableInstrument
                    let complex = inspection.complexInstrument
                    notice = "Imported and verified VAO \(VAO03Contract.formatVersion) “\(inspection.displayTitle)” with \(scene?.geometryResources.count ?? 0) geometry, \(scene?.impulseResponseResources.count ?? 0) impulse-response, \(playable?.sampleMappings.count ?? 0) playable sample-mapping, and \(complex?.routingRuleCount ?? 0) complex routing records."
                    return
                }
                if let formatVersion, formatVersion.hasPrefix("0.3") {
                    throw OrgRecError.invalidProject("OrgRec supports exact VAO \(VAO03Contract.formatVersion), not draft \(formatVersion).")
                }
                if let formatVersion, formatVersion.hasPrefix("0.4") {
                    throw OrgRecError.invalidProject("OrgRec supports exact VAO \(VAO04Contract.formatVersion), not draft \(formatVersion).")
                }
                if let formatVersion, formatVersion.hasPrefix("0.5") {
                    throw OrgRecError.invalidProject("OrgRec supports exact VAO \(VAO05Contract.formatVersion), not draft \(formatVersion).")
                }
                let destination = uniqueManagedProjectURL(stem: source.deletingPathExtension().lastPathComponent)
                _ = try await vaoImporter.importPackage(from: source, to: destination)
                guard await openProject(at: destination, destinationPage: .roadmap, allowingCurrentOperation: true) else { return }
                notice = "Imported and verified the Virtual Acoustic Object."
                return
            }
            if FileManager.default.fileExists(atPath: source.appendingPathComponent(IADContract.manifestFilename).path) {
                let destination = uniqueManagedProjectURL(stem: source.deletingPathExtension().lastPathComponent)
                _ = try await iadImporter.importPackage(from: source, to: destination)
                guard await openProject(at: destination, destinationPage: .roadmap, allowingCurrentOperation: true) else { return }
                notice = "Imported and verified the Instrumental Audio Dataset package."
                return
            }
            _ = try await store.load(from: source)
            let managed = try projectsDirectory().standardizedFileURL
            let sourceURL = source.standardizedFileURL
            let destination: URL
            if sourceURL.deletingLastPathComponent() == managed {
                destination = sourceURL
            } else {
                destination = uniqueManagedProjectURL(stem: source.deletingPathExtension().lastPathComponent)
                try FileManager.default.copyItem(at: sourceURL, to: destination)
            }
            guard await openProject(at: destination, destinationPage: .roadmap, allowingCurrentOperation: true) else { return }
            notice = sourceURL == destination ? "Opened imported project." : "Imported a copy into the OrgRec project library."
        } catch {
            errorMessage = "Could not import the project: \(error.localizedDescription)"
        }
    }

    func selectLegacyDatasetSource(_ source: URL) {
        legacyImportSourceURL = source
        legacyInspection = nil
        let supportedExtensions = Set(["wav", "wave", "aif", "aiff", "caf", "flac"])
        legacyCandidateFilenames = (try? FileManager.default.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ))?.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .map(\.lastPathComponent)
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending } ?? []
        legacyImportStatus = legacyCandidateFilenames.isEmpty
            ? "No supported audio files were found at the top level of this directory."
            : "Found \(legacyCandidateFilenames.count) candidate audio files. Choose how their names encode stops and pitches."
    }

    func inspectLegacyDataset(at source: URL, profile: LegacyDatasetProfile = .positivXR) async {
        isWorking = true
        legacyImportStatus = "Reading audio headers and validating filename semantics…"
        defer { isWorking = false }
        do {
            let inspection = try await legacyImporter.inspect(directory: source, profile: profile)
            legacyImportSourceURL = source
            legacyInspection = inspection
            legacyImportStatus = "Parsed \(inspection.files.count) of \(legacyCandidateFilenames.count) candidate files. Review every token mapping before conversion."
        } catch {
            legacyInspection = nil
            legacyImportStatus = nil
            errorMessage = "Could not inspect the audio dataset: \(error.localizedDescription)"
        }
    }

    func importLegacyDataset(analyzeRepresentativeSample: Bool) async {
        guard let source = legacyImportSourceURL, let inspection = legacyInspection else {
            errorMessage = "Choose and inspect a legacy audio dataset first."
            return
        }
        isWorking = true
        legacyImportStatus = "Checksumming and copying \(inspection.files.count) originals into an OrgRec project…"
        defer { isWorking = false }
        do {
            let destination = uniqueManagedProjectURL(stem: "\(inspection.profile.organName)-\(source.lastPathComponent)")
            _ = try await legacyImporter.importDataset(from: source, to: destination, profile: inspection.profile)
            var analyzedCount = 0
            if analyzeRepresentativeSample {
                legacyImportStatus = "Running OrgRec pitch, transient, level, and partial analysis on a stratified sample…"
                let report = try await legacyImporter.analyzeStratifiedSample(projectURL: destination)
                analyzedCount = report.results.count
            }
            guard await openProject(at: destination, destinationPage: analyzeRepresentativeSample ? .analysis : .roadmap, allowingCurrentOperation: true) else { return }
            legacyImportStatus = "Import completed. The source directory was not modified."
            notice = analyzeRepresentativeSample
                ? "Imported \(inspection.files.count) checksum-verified recordings and analyzed \(analyzedCount) representative takes."
                : "Imported \(inspection.files.count) checksum-verified recordings."
        } catch {
            legacyImportStatus = "Import failed; an incomplete destination package was removed."
            errorMessage = "Could not import the legacy dataset: \(error.localizedDescription)"
        }
    }

    func convertLegacyDatasetToVAO(
        profile: LegacyDatasetProfile,
        analyzeRepresentativeSample: Bool,
        destination: URL
    ) async {
        guard let source = legacyImportSourceURL else {
            errorMessage = "Choose an audio dataset directory first."
            return
        }
        isWorking = true
        legacyImportStatus = "Verifying the reviewed filename mappings and copying source audio…"
        defer { isWorking = false }
        do {
            let verifiedInspection = try await legacyImporter.inspect(directory: source, profile: profile)
            let unmapped = Set(verifiedInspection.files.map(\.stopCode)).subtracting(profile.stopMappings.map(\.code))
            guard unmapped.isEmpty else {
                throw OrgRecError.invalidProject("Map every filename token before conversion: \(unmapped.sorted().joined(separator: ", ")).")
            }
            legacyInspection = verifiedInspection
            let projectDestination = uniqueManagedProjectURL(stem: "\(profile.organName)-\(source.lastPathComponent)")
            var convertedProject = try await legacyImporter.importDataset(
                from: source,
                to: projectDestination,
                profile: profile
            )
            if analyzeRepresentativeSample {
                legacyImportStatus = "Analyzing representative low, middle, and high notes before VAO packaging…"
                _ = try await legacyImporter.analyzeStratifiedSample(projectURL: projectDestination)
                convertedProject = try await store.load(from: projectDestination)
            }
            legacyImportStatus = "Building and validating the VAO graph, asset index, and checksums…"
            let packageURL = try await vao05Builder.build(
                project: convertedProject,
                packageURL: projectDestination,
                destinationURL: destination
            )
            let validation = try await vao05Reader.inspect(packageURL)
            guard await openProject(at: projectDestination, destinationPage: analyzeRepresentativeSample ? .analysis : .roadmap, allowingCurrentOperation: true) else { return }
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            legacyImportStatus = "VAO created and validated. The source directory was not modified."
            notice = "Created a validated VAO \(VAO05Contract.formatVersion) from \(verifiedInspection.files.count) parsed audio files with \(validation.realizationCount) verified realizations."
        } catch {
            legacyImportStatus = "Conversion stopped without modifying the source directory."
            errorMessage = "Could not convert the audio dataset to VAO: \(error.localizedDescription)"
        }
    }

    func inspectGrandOrgueSampleSet(at odfURL: URL) async {
        isWorking = true
        grandOrgueImportStatus = "Parsing the ODF, resolving pipe references, and reading audio headers…"
        defer { isWorking = false }
        do {
            let sourceURL = grandOrgueSourcePageURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let inspection = try await grandOrgueImporter.inspect(
                odfURL: odfURL,
                sourcePageURL: sourceURL.isEmpty ? nil : sourceURL
            )
            grandOrgueODFURL = odfURL
            grandOrgueInspection = inspection
            grandOrgueImportStatus = inspection.missingSampleCount == 0
                ? "Inspection complete. Review organ identity, rights, disposition, and preservation scope."
                : "Inspection found \(inspection.missingSampleCount) unresolved samples; import is blocked."
        } catch {
            grandOrgueInspection = nil
            grandOrgueODFURL = nil
            grandOrgueImportStatus = nil
            errorMessage = "Could not inspect the GrandOrgue sample set: \(error.localizedDescription)"
        }
    }

    func inspectPODDatabase(at source: URL) async {
        isWorking = true
        podDatabaseStatus = "Checking SQLite integrity, the Release 1.5 metadata contract, schema, FTS indexes, and SHA-256 digest…"
        defer { isWorking = false }
        do {
            let inspection = try PODDatabaseReader.inspect(databaseURL: source)
            podDatabaseSourceURL = source
            podDatabaseInspection = inspection
            if inspection.isCompatible, inspection.matchesPublishedArtifact {
                podDatabaseStatus = "Verified POD \(inspection.releaseVersion ?? "1.5"): \(inspection.organCount.formatted()) organs and \(inspection.componentCount.formatted()) components."
            } else if inspection.isCompatible {
                podDatabaseStatus = "The schema is compatible, but this is not the pinned POD 1.5 OrgRec artifact; caching is blocked."
            } else {
                podDatabaseStatus = "Validation failed: " + inspection.errors.prefix(3).joined(separator: "; ")
            }
        } catch {
            podDatabaseSourceURL = source
            podDatabaseInspection = nil
            podDatabaseStatus = nil
            errorMessage = "Could not inspect the reduced POD database: \(error.localizedDescription)"
        }
    }

    func importPODDatabase() async {
        guard let source = podDatabaseSourceURL,
              let inspection = podDatabaseInspection,
              inspection.isCompatible else {
            errorMessage = "Choose and verify the reduced POD SQLite database first."
            return
        }
        isWorking = true
        podDatabaseStatus = "Copying the database into the removable local cache and verifying the exact bytes again…"
        defer { isWorking = false }
        do {
            let destination = uniqueManagedPODDatabaseURL()
            let imported = try await podDatabaseImporter.importVerifiedDatabase(from: source, to: destination)
            podDatabaseCacheURL = destination
            podDatabaseInspection = imported
            UserDefaults.standard.set(destination.path, forKey: podDatabasePathKey)
            podDatabaseStatus = "Cached the exact verified database. The selected source file was not modified."
            notice = "POD \(imported.releaseVersion ?? "1.5") is now the local OrgRec organ catalogue and roadmap source."
        } catch {
            podDatabaseStatus = "Import failed; the incomplete staging file was removed."
            errorMessage = "Could not import the reduced POD database: \(error.localizedDescription)"
        }
    }

    func downloadPODDatabase() async {
        guard let remoteURL = URL(string: podDatabaseDownloadURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Enter the complete HTTPS Zenodo database URL."
            return
        }
        isWorking = true
        podDatabaseStatus = "Downloading the POD database to a temporary file; schema and fixity checks follow before caching…"
        defer { isWorking = false }
        do {
            let destination = uniqueManagedPODDatabaseURL()
            let imported = try await podDatabaseImporter.downloadVerifiedDatabase(from: remoteURL, to: destination)
            podDatabaseCacheURL = destination
            podDatabaseSourceURL = nil
            podDatabaseInspection = imported
            UserDefaults.standard.set(destination.path, forKey: podDatabasePathKey)
            podDatabaseStatus = "Downloaded, validated, and cached POD \(imported.releaseVersion ?? "1.5")."
            notice = "The verified local POD database is ready for organ search and roadmap creation."
        } catch {
            podDatabaseStatus = "Download or verification failed; no incomplete cache was retained."
            errorMessage = "Could not retrieve the reduced POD database: \(error.localizedDescription)"
        }
    }

    func revealPODDatabaseCache() {
        guard let podDatabaseCacheURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([podDatabaseCacheURL])
    }

    func removePODDatabaseCache() {
        guard let cache = podDatabaseCacheURL else { return }
        do {
            try FileManager.default.removeItem(at: cache)
            podDatabaseCacheURL = nil
            podDatabaseInspection = nil
            UserDefaults.standard.removeObject(forKey: podDatabasePathKey)
            podDatabaseStatus = "Removed the local POD database cache. The selected source file was not modified."
        } catch {
            errorMessage = "Could not remove the local POD database cache: \(error.localizedDescription)"
        }
    }

    func importGrandOrgueSampleSet() async {
        guard let odfURL = grandOrgueODFURL, let inspection = grandOrgueInspection else {
            errorMessage = "Choose and inspect a GrandOrgue ODF first."
            return
        }
        isWorking = true
        grandOrgueImportStatus = "Hashing and preserving \(inspection.payloadFiles.count) source files…"
        defer { isWorking = false }
        do {
            let sourceURL = grandOrgueSourcePageURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let destination = uniqueManagedProjectURL(stem: "\(inspection.organName)-GrandOrgue")
            _ = try await grandOrgueImporter.importSampleSet(
                odfURL: odfURL,
                to: destination,
                sourcePageURL: sourceURL.isEmpty ? nil : sourceURL
            )
            guard await openProject(at: destination, destinationPage: .roadmap, allowingCurrentOperation: true) else { return }
            grandOrgueImportStatus = "Import complete. The self-contained GrandOrgue tree and all source checksums were preserved."
            notice = "Imported \(inspection.stops.count) stops and \(inspection.referencedSampleCount) logical pipe mappings from \(inspection.organName)."
        } catch {
            grandOrgueImportStatus = "Import failed; an incomplete destination package was removed."
            errorMessage = "Could not import the GrandOrgue sample set: \(error.localizedDescription)"
        }
    }

    func convertGrandOrgueToVAO(destination: URL) async {
        guard let odfURL = grandOrgueODFURL, let inspection = grandOrgueInspection else {
            errorMessage = "Choose and inspect a GrandOrgue ODF first."
            return
        }
        guard inspection.missingSampleCount == 0 else {
            errorMessage = "Resolve every missing ODF sample reference before conversion."
            return
        }
        isWorking = true
        grandOrgueImportStatus = "Preserving the GrandOrgue source tree and resolving ODF mappings…"
        defer { isWorking = false }
        do {
            let sourceURL = grandOrgueSourcePageURL.trimmingCharacters(in: .whitespacesAndNewlines)
            let projectDestination = uniqueManagedProjectURL(stem: "\(inspection.organName)-GrandOrgue")
            let convertedProject = try await grandOrgueImporter.importSampleSet(
                odfURL: odfURL,
                to: projectDestination,
                sourcePageURL: sourceURL.isEmpty ? nil : sourceURL
            )
            grandOrgueImportStatus = "Building and validating the VAO with its ODF-derived component graph…"
            let packageURL = try await vao05Builder.build(
                project: convertedProject,
                packageURL: projectDestination,
                destinationURL: destination
            )
            let validation = try await vao05Reader.inspect(packageURL)
            guard await openProject(at: projectDestination, destinationPage: .roadmap, allowingCurrentOperation: true) else { return }
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            grandOrgueImportStatus = "GrandOrgue conversion complete. The source tree was not modified."
            notice = "Created a validated VAO \(VAO05Contract.formatVersion) from the GrandOrgue source with \(inspection.referencedSampleCount) ODF pipe mappings and \(validation.realizationCount) verified realizations."
        } catch {
            grandOrgueImportStatus = "Conversion stopped without modifying the GrandOrgue source tree."
            errorMessage = "Could not convert the GrandOrgue sample set to VAO: \(error.localizedDescription)"
        }
    }

    func exportEditableProject(_ summary: RecordingProjectSummary, to destination: URL) async {
        do {
            guard FileManager.default.fileExists(atPath: destination.path) == false else {
                throw OrgRecError.exportValidation("The destination already exists.")
            }
            try FileManager.default.copyItem(at: summary.url, to: destination)
            notice = "Exported editable project package."
        } catch {
            errorMessage = "Could not export the project: \(error.localizedDescription)"
        }
    }

    func exportCapturePackage(_ summary: RecordingProjectSummary, to destination: URL) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let sourceProject = try await store.load(from: summary.url)
            _ = try await CapturePackageBuilder().build(
                project: sourceProject,
                packageURL: summary.url,
                destinationURL: destination
            )
            notice = "Exported and validated the IAD / Navigator package."
        } catch {
            errorMessage = "Could not export the IAD package: \(error.localizedDescription)"
        }
    }

    func exportVAO(_ summary: RecordingProjectSummary, to destination: URL) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let sourceProject = try await store.load(from: summary.url)
            _ = try await vao05Builder.build(
                project: sourceProject,
                packageURL: summary.url,
                destinationURL: destination
            )
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            notice = "Exported a validated VAO \(VAO05Contract.formatVersion) preservation closure with exact project assets, rights status, and SHA-256 fixity."
        } catch {
            errorMessage = "Could not export the VAO: \(error.localizedDescription)"
        }
    }

    func revealProject(_ summary: RecordingProjectSummary) {
        NSWorkspace.shared.activateFileViewerSelecting([summary.url])
    }

    func revealImportedVAO03Workspace() {
        guard let importedVAO03WorkspaceURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([importedVAO03WorkspaceURL])
    }

    func revealImportedVAO04Workspace() {
        guard let importedVAO04WorkspaceURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([importedVAO04WorkspaceURL])
    }

    func revealImportedVAO05Workspace() {
        guard let importedVAO05WorkspaceURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([importedVAO05WorkspaceURL])
    }

    func showOrganSearch(query: String? = nil) async {
        if let query { navigatorQuery = query }
        page = .organSearch
        if navigatorQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            await searchNavigator()
        }
    }

    func select(_ item: RoadmapItem, record: Bool = false) {
        selectedRoadmapID = item.id
        if record { page = .record }
    }

    func confirmRequiredCaptureState() async {
        guard var project, let item = selectedRoadmapItem, let required = project.requiredCaptureState(for: item) else { return }
        var states = project.captureStates ?? []
        let confirmed = CaptureStateSnapshot(
            id: required.id,
            revision: required.revision,
            name: required.name,
            source: .operatorConfirmed,
            assignments: required.assignments,
            notes: required.notes
        )
        if let index = states.firstIndex(where: { $0.id == confirmed.id }) { states[index] = confirmed }
        else { states.append(confirmed) }
        project.captureStates = states
        project.activeCaptureStateID = confirmed.id
        self.project = project
        guard await persistOrReport() else { return }
        notice = "Confirmed exact capture state \(confirmed.name) · \(confirmed.fingerprintSHA256.prefix(12))."
    }

    func saveControlBinding(_ binding: ControlBinding) async {
        guard binding.validationIssues.isEmpty else {
            errorMessage = binding.validationIssues.joined(separator: " ")
            return
        }
        guard var project else { return }
        var bindings = project.controlBindings ?? []
        if let index = bindings.firstIndex(where: { $0.id == binding.id }) { bindings[index] = binding }
        else { bindings.append(binding) }
        project.controlBindings = bindings
        self.project = project
        guard await persistOrReport() else { return }
        notice = "Saved control map for \(binding.componentLabel)."
    }

    func removeControlBinding(_ id: UUID) async {
        guard var project else { return }
        project.controlBindings?.removeAll { $0.id == id }
        self.project = project
        guard await persistOrReport() else { return }
    }

    func saveSoundingTargetPlan(
        component source: OrganComponent,
        definition: SoundingTargetDefinition,
        techniques: [CaptureTechnique],
        required: Bool
    ) async {
        guard var project else { return }
        guard definition.validationIssues.isEmpty else {
            errorMessage = definition.validationIssues.joined(separator: " ")
            return
        }
        guard techniques.isEmpty == false else {
            errorMessage = "Select at least one microphone technique."
            return
        }
        let sourceID = source.id
        let priorItems = project.roadmap.filter {
            $0.soundingTargetDefinition != nil
                && ($0.component.id == sourceID || $0.component.parentComponentID == sourceID)
        }
        let priorTakeIDs = Set(priorItems.flatMap(\.takeIDs))
        guard priorTakeIDs.isEmpty else {
            errorMessage = "This sounding target already has recorded takes. Add a new local component revision instead of changing its frozen capture contract."
            return
        }
        let priorRegistrationIDs = Set(priorItems.compactMap(\.registrationID))
        project.roadmap.removeAll { item in priorItems.contains(where: { $0.id == item.id }) }
        let stillReferencedRegistrationIDs = Set(project.roadmap.compactMap(\.registrationID))
        project.registrations.removeAll { registration in
            priorRegistrationIDs.contains(registration.id)
                && stillReferencedRegistrationIDs.contains(registration.id) == false
        }

        var component = source
        component.soundingTargetDefinition = definition
        if let index = project.organComponents?.firstIndex(where: { $0.id == component.id }) {
            project.organComponents?[index] = component
        } else {
            var components = project.organComponents ?? []
            components.append(component)
            project.organComponents = components
        }
        let shouldArmAccessory = definition.triggerMode != .keyboardKey && definition.triggerMode != .manual
        let registration = RegistrationState(
            activatedAccessories: shouldArmAccessory ? [component.locator] : [],
            notes: "Operator-planned intended sounding target; actuator noise remains a separate capture family.",
            name: component.label,
            purpose: definition.family.displayName
        )
        project.registrations.append(registration)
        var recipe = project.recipe
        recipe.techniques = techniques
        var items = RoadmapEngine.soundingTargetItems(
            component: component,
            definition: definition,
            recipe: recipe,
            setupIDs: project.setups.map(\.id),
            registrationID: registration.id
        )
        for index in items.indices { items[index].required = required }
        project.roadmap.append(contentsOf: items)
        self.project = project
        selectedRoadmapID = items.first?.id
        guard await persistOrReport() else { return }
        notice = "Saved \(definition.family.displayName.lowercased()) target \(component.label) with \(items.count) Roadmap capture obligations."
    }

    func startCapturePreflight() async {
        guard let project, let packageURL = projectURL,
              let session = activeSession,
              let setupID = selectedRoadmapItem?.setupID,
              let setup = project.setups.first(where: { $0.id == setupID }) else {
            errorMessage = "Select a Roadmap capture with an active session and documented microphone setup first."
            return
        }
        guard capture.isRecording == false,
              capture.isFinalizing == false,
              isStartingCapturePreflight == false,
              isStoppingCapturePreflight == false,
              hasActiveCapture == false,
              isWorking == false else {
            errorMessage = "The recorder or another project operation is still active."
            return
        }
        guard let device = audioSystem.selectedDevice else {
            errorMessage = "Select an input interface in Setup before rehearsing the signal path."
            return
        }
        guard setup.placements.isEmpty == false else {
            errorMessage = "The selected microphone setup has no channel placements to verify."
            return
        }
        let documentedChannels = setup.placements.map(\.channelNumber)
        guard device.inputChannels > 0,
              Set(documentedChannels).count == documentedChannels.count,
              documentedChannels.allSatisfy({ (1...device.inputChannels).contains($0) }) else {
            errorMessage = "The microphone setup must use unique channel numbers between 1 and \(device.inputChannels) for \(device.name)."
            return
        }

        isStartingCapturePreflight = true
        isWorking = true
        defer {
            isWorking = false
            isStartingCapturePreflight = false
        }
        let id = UUID()
        let relativePath = "Audio/Calibration/signal-path-\(id.uuidString.lowercased()).wav"
        let fileURL = packageURL.appendingPathComponent(relativePath)
        do {
            let available = try packageURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                .volumeAvailableCapacityForImportantUsage ?? 0
            guard available > 1_073_741_824 else {
                throw NSError(domain: "OrgRec", code: 42, userInfo: [NSLocalizedDescriptionKey: "The rehearsal requires at least 1 GiB of available space so its BWF can be finalized safely."])
            }
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try audioSystem.applyToHAL()

            let placementByChannel = Dictionary(uniqueKeysWithValues: setup.placements.map { ($0.channelNumber, $0) })
            let assignments = (1...device.inputChannels).map { channel in
                CapturePreflightChannelAssignment(
                    channelNumber: channel,
                    role: placementByChannel[channel]?.role ?? "Input \(channel)",
                    isRequired: placementByChannel[channel] != nil
                )
            }
            let roles = assignments.map(\.role)
            let referenceChannel = max(0, min(device.inputChannels - 1, (setup.referenceChannelNumber ?? 1) - 1))
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = .current
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")
            timeFormatter.timeZone = .current
            timeFormatter.dateFormat = "HH:mm:ss"
            let bwf = BWFMetadata(
                description: "Signal-path rehearsal · \(project.organName) · \(setup.name) r\(setup.revision)",
                originatorReference: "ORGREC-PREFLIGHT-\(project.id.uuidString.prefix(8))-\(id.uuidString.prefix(12))",
                originationDate: dateFormatter.string(from: now),
                originationTime: timeFormatter.string(from: now),
                codingHistory: "A=PCM,F=\(Int(audioSystem.selectedSampleRate)),W=24,M=multichannel,T=OrgRec signal-path rehearsal"
            )
            let protocolSnapshot = CapturePreflightProtocolSnapshot()
            let snapshot = device.snapshot(
                mode: audioSystem.latencyMode,
                sampleRate: audioSystem.selectedSampleRate,
                bufferFrames: audioSystem.selectedBufferFrames
            )
            pendingCapturePreflight = PendingCapturePreflight(
                id: id,
                startedAt: now,
                sessionID: session.id,
                setupID: setup.id,
                setupRevision: setup.revision,
                relativeAudioPath: relativePath,
                deviceSnapshot: snapshot,
                assignments: assignments,
                bwfMetadata: bwf,
                protocolSnapshot: protocolSnapshot
            )
            if let pendingCapturePreflight {
                try writeCapturePreflightJournal(pendingCapturePreflight, packageURL: packageURL)
            }
            _ = try await capture.start(
                to: fileURL,
                deviceID: device.id,
                channelRoles: roles,
                referenceChannelIndex: referenceChannel,
                bwfMetadata: bwf,
                criticalStopHandler: { [weak self] message in
                    self?.handleCriticalCaptureStop(message)
                }
            )
            isRunningCapturePreflight = true
            beginCriticalCaptureActivity(reason: "Rehearsing the multichannel signal path")
            capturePreflightAutoStopTask?.cancel()
            capturePreflightAutoStopTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .seconds(protocolSnapshot.targetDurationSeconds))
                } catch {
                    return
                }
                guard let self else { return }
                self.capturePreflightAutoStopTask = nil
                await self.stopCapturePreflight()
            }
            notice = "Signal-path rehearsal started: keep the organ silent for 4 seconds, then sound the loudest planned registration until OrgRec stops automatically."
        } catch {
            if capture.isRecording {
                _ = await capture.stop { _ in self.endCriticalCaptureActivity() }
            }
            isRunningCapturePreflight = false
            pendingCapturePreflight = nil
            clearCapturePreflightJournal(in: packageURL)
            capturePreflightAutoStopTask?.cancel()
            capturePreflightAutoStopTask = nil
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size == 0 {
                try? FileManager.default.removeItem(at: fileURL)
            }
            errorMessage = "Signal-path rehearsal did not start safely: \(error.localizedDescription)"
        }
    }

    func stopCapturePreflight() async {
        guard (isRunningCapturePreflight || pendingCapturePreflight != nil),
              isStoppingCapturePreflight == false else { return }
        isStoppingCapturePreflight = true
        isWorking = true
        capturePreflightAutoStopTask?.cancel()
        capturePreflightAutoStopTask = nil
        defer {
            isWorking = false
            isStoppingCapturePreflight = false
            isRunningCapturePreflight = false
            pendingCapturePreflight = nil
        }

        guard let pending = pendingCapturePreflight,
              var project,
              let packageURL = projectURL else {
            if capture.isRecording {
                _ = await capture.stop { _ in self.endCriticalCaptureActivity() }
            }
            errorMessage = "The rehearsal was finalized, but its pending project context was unavailable."
            return
        }
        let result = await capture.stop { _ in self.endCriticalCaptureActivity() }
        endCriticalCaptureActivity()
        let fileURL = packageURL.appendingPathComponent(pending.relativeAudioPath)
        let fileSize = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        var evidenceFindings: [CapturePreflightFinding] = []
        let digest: String
        do {
            digest = try sha256(of: fileURL)
        } catch {
            digest = ""
            evidenceFindings.append(CapturePreflightFinding(
                id: "checksum-read",
                kind: .evidenceIntegrity,
                severity: .blocker,
                title: "Rehearsal evidence could not be checksummed",
                detail: error.localizedDescription,
                remediation: "Check the project volume and repeat the rehearsal."
            ))
        }
        let context = CapturePreflightAnalysisContext(
            reportID: pending.id,
            recordedAt: pending.startedAt,
            sessionID: pending.sessionID,
            setupID: pending.setupID,
            setupRevision: pending.setupRevision,
            deviceSnapshot: pending.deviceSnapshot,
            relativeAudioPath: pending.relativeAudioPath,
            fileSize: fileSize,
            sha256: digest,
            sampleRate: result.sampleRate > 0 ? result.sampleRate : pending.deviceSnapshot.sampleRate,
            frameCount: result.frameCount,
            assignments: pending.assignments,
            captureDiagnostics: result.diagnostics,
            bwfMetadata: pending.bwfMetadata,
            bwfFinalizationSucceeded: result.bwfFinalizationSucceeded == true,
            protocolSnapshot: pending.protocolSnapshot
        )
        let report: CapturePreflightReport
        do {
            report = try await Task.detached(priority: .userInitiated) {
                var analyzed = try CapturePreflightAnalyzer.analyze(fileURL: fileURL, context: context)
                if evidenceFindings.isEmpty == false {
                    analyzed.findings.append(contentsOf: evidenceFindings)
                    analyzed.verdict = .failed
                }
                return analyzed
            }.value
        } catch {
            let unreadable = CapturePreflightFinding(
                id: "analysis-read",
                kind: .evidenceIntegrity,
                severity: .blocker,
                title: "Rehearsal audio could not be analyzed",
                detail: error.localizedDescription,
                remediation: "Inspect the retained BWF and repeat the rehearsal before recording."
            )
            report = CapturePreflightAnalyzer.evaluate(
                samples: [],
                context: context,
                additionalFindings: evidenceFindings + [unreadable]
            )
        }

        guard var sessions = project.recordingSessions,
              let sessionIndex = sessions.firstIndex(where: { $0.id == pending.sessionID }) else {
            errorMessage = "The rehearsal was retained at \(pending.relativeAudioPath), but its recording session no longer exists."
            return
        }
        var reports = sessions[sessionIndex].capturePreflightReports ?? []
        reports.append(report)
        sessions[sessionIndex].capturePreflightReports = reports
        project.recordingSessions = sessions
        self.project = project
        do {
            try await persist()
            clearCapturePreflightJournal(in: packageURL)
            await runConsistencyAudit()
            switch report.verdict {
            case .passed:
                notice = "Signal path verified on every assigned channel; the evidence and SHA-256 report were retained with this session."
            case .attention:
                notice = "Signal path is usable with \(report.findings.filter { $0.severity == .warning }.count) caution(s). Review the channel table before recording."
            case .failed:
                notice = "Signal-path rehearsal failed with \(report.findings.filter { $0.severity == .blocker }.count) blocking fault(s). Correct them and repeat the rehearsal."
            }
        } catch {
            errorMessage = "The rehearsal was analyzed and remains in memory, but its report could not be saved: \(error.localizedDescription)"
        }
    }

    func startRecording() async {
        guard var project, let packageURL = projectURL, let item = selectedRoadmapItem else {
            errorMessage = "Choose a roadmap item before recording."
            return
        }
        guard capture.isRecording == false,
              capture.isFinalizing == false,
              isStartingCapture == false,
              isStoppingRecording == false,
              isWorking == false else {
            errorMessage = "A recording is already active, finalizing, or another project operation is still running."
            return
        }
        isStartingCapture = true
        defer { isStartingCapture = false }
        let blockers = captureReadiness.filter { $0.severity == .blocker }
        guard blockers.isEmpty else {
            errorMessage = "Recording is not ready: " + blockers.map(\.title).joined(separator: "; ")
            page = .fieldQA
            return
        }
        let id = UUID()
        let relativePath = "Audio/Originals/\(id.uuidString.lowercased()).wav"
        let fileURL = packageURL.appendingPathComponent(relativePath)
        activeTakeIncludesInteractionSensor = false
        do {
            guard let device = audioSystem.selectedDevice else {
                throw NSError(domain: "OrgRec", code: 3, userInfo: [NSLocalizedDescriptionKey: "Select an input interface in Setup before recording."])
            }
            let available = try packageURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                .volumeAvailableCapacityForImportantUsage ?? 0
            guard available > 2_147_483_648 else {
                throw NSError(domain: "OrgRec", code: 4, userInfo: [NSLocalizedDescriptionKey: "Recording requires at least 2 GiB of available space on the project volume."])
            }
            try audioSystem.applyToHAL()
            let setup = item.setupID.flatMap { setupID in project.setups.first { $0.id == setupID } }
            let registration = item.registrationID.flatMap { registrationID in
                project.registrations.first { $0.id == registrationID }
            }
            let requiredCaptureState = project.requiredCaptureState(for: item)
            let spatialGeometry = item.spatialAcousticProtocol.flatMap { captureProtocol in
                project.spatialGeometrySnapshots?.first { $0.id == captureProtocol.geometrySnapshotID && $0.fingerprint == captureProtocol.geometryFingerprint }
            }
            guard let session = project.recordingSessions?.last(where: { $0.endedAt == nil }) else {
                throw NSError(domain: "OrgRec", code: 8, userInfo: [NSLocalizedDescriptionKey: "Create an active recording session in Field QA."])
            }
            let requiredChannel = setup?.placements.map(\.channelNumber).max() ?? 0
            guard requiredChannel <= device.inputChannels else {
                throw NSError(
                    domain: "OrgRec",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "The selected setup requires input channel \(requiredChannel), but \(device.name) exposes only \(device.inputChannels) input channels."]
                )
            }
            var roles = (0..<device.inputChannels).map { "Input \($0 + 1)" }
            for placement in setup?.placements ?? [] where roles.indices.contains(placement.channelNumber - 1) {
                roles[placement.channelNumber - 1] = placement.role
            }
            let referenceChannelNumber = setup?.referenceChannelNumber ?? 1
            guard (1...device.inputChannels).contains(referenceChannelNumber) else {
                throw NSError(domain: "OrgRec", code: 36, userInfo: [NSLocalizedDescriptionKey: "The analysis reference channel is outside the selected input device."])
            }
            let referenceChannel = referenceChannelNumber - 1
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = .current
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")
            timeFormatter.timeZone = .current
            timeFormatter.dateFormat = "HH:mm:ss"
            let bwf = BWFMetadata(
                description: "\(project.organName) · \(item.component.label) \(item.component.noteName ?? "") · \(item.technique.rawValue)",
                originatorReference: "ORGREC-\(project.id.uuidString.prefix(8))-\(id.uuidString.prefix(12))",
                originationDate: dateFormatter.string(from: now),
                originationTime: timeFormatter.string(from: now),
                codingHistory: "A=PCM,F=\(Int(audioSystem.selectedSampleRate)),W=24,M=multichannel,T=OrgRec"
            )
            let number = project.takes.filter { $0.roadmapItemID == item.id }.count + 1
            let calibration = session.tuningCalibrationID.flatMap { calibrationID in
                project.tuningCalibrations?.first { $0.id == calibrationID && $0.status == .accepted }
            }
            var take = TakeRecord(
                id: id,
                roadmapItemID: item.id,
                takeNumber: number,
                relativeAudioPath: relativePath,
                sampleRate: audioSystem.selectedSampleRate,
                channelCount: device.inputChannels,
                audioDeviceSnapshot: device.snapshot(
                    mode: audioSystem.latencyMode,
                    sampleRate: audioSystem.selectedSampleRate,
                    bufferFrames: audioSystem.selectedBufferFrames
                ),
                spectrogramConfiguration: project.spectrogramConfiguration ?? SpectrogramConfiguration(),
                bwfMetadata: bwf,
                analysisReferenceChannel: referenceChannel,
                provenance: TakeProvenanceSnapshot(
                    session: session,
                    recipe: project.recipe,
                    microphoneSetup: setup,
                    registration: registration,
                    component: item.component,
                    releaseBinding: project.snapshot.release,
                    navigatorPayloadSHA256: project.snapshot.payloadSHA256,
                    organMDVSID: project.organMDVSID,
                    tuningCalibration: calibration,
                    expectedFrequencyHz: item.component.expectedFrequencyHz,
                    physicalSoundTargetID: item.physicalSoundTargetID,
                    activationRoutes: item.activationRoutes,
                    actualActivationRouteID: item.primaryActivationRouteID,
                    instrumentNoiseProtocol: item.instrumentNoiseProtocol,
                    soundingTargetDefinition: item.soundingTargetDefinition,
                    captureStateSnapshot: requiredCaptureState,
                    controlBindings: project.controlBindings?.filter { binding in
                        binding.componentID == item.component.id
                            || binding.componentID == item.component.parentComponentID
                            || requiredCaptureState?.assignments.contains(where: { $0.subjectComponentID == binding.componentID }) == true
                    },
                    complexCaptureProtocol: item.complexCaptureProtocol,
                    spatialGeometrySnapshot: spatialGeometry,
                    spatialAcousticProtocol: item.spatialAcousticProtocol,
                    effectAnalysisProtocol: item.inferredNonPitchedEffectAnalysisProtocol
                ),
                instrumentNoiseParadata: item.instrumentNoiseProtocol.map {
                    InstrumentNoiseTakeParadata(
                        protocolSnapshot: $0,
                        repetitionNumber: number,
                        actualVelocityLabel: $0.velocity?.label,
                        actualNormalizedVelocity: $0.velocity?.normalizedValue
                    )
                },
                captureStateSnapshot: requiredCaptureState,
                complexCaptureParadata: item.complexCaptureProtocol.map {
                    ComplexCaptureTakeParadata(protocolSnapshot: $0, repetitionNumber: number)
                },
                spatialAcousticParadata: item.spatialAcousticProtocol.map {
                    SpatialAcousticTakeParadata(protocolSnapshot: $0, repetitionNumber: number)
                }
            )
            let priorRoadmapState = item.state
            try writeActiveCaptureJournal(
                take: take,
                priorRoadmapState: priorRoadmapState,
                packageURL: packageURL
            )
            midiControl.beginCapture(takeID: id, bindings: project.controlBindings ?? [])
            if willCaptureInteractionSensorForNextTake,
               let sensorConfiguration = project.activeInteractionSensorConfigurationID.flatMap({ activeID in
                project.interactionSensorConfigurations?.first { $0.id == activeID }
            }), sensorConfiguration.capturePolicy != .disabled {
                let calibration = sensorConfiguration.currentCalibrationID.flatMap { calibrationID in
                    project.interactionSensorCalibrations?.first { $0.id == calibrationID }
                }
                let correctStream = interactionSensors.isStreaming
                    && interactionSensors.activeConfigurationID == sensorConfiguration.id
                if correctStream {
                    do {
                        try interactionSensors.beginCapture(
                            packageURL: packageURL,
                            takeID: id,
                            configuration: sensorConfiguration,
                            calibration: calibration
                        )
                    } catch {
                        notice = "Audio will continue without optional interaction-sensor evidence: \(error.localizedDescription)"
                    }
                } else {
                    notice = "Audio is recording without interaction data because the optional sensor was not streaming."
                }
            }
            let format = try await capture.start(
                to: fileURL,
                deviceID: device.id,
                channelRoles: roles,
                referenceChannelIndex: referenceChannel,
                bwfMetadata: bwf,
                pitchSampleHandler: { [weak livePitch] samples, rate in
                    livePitch?.consume(samples: samples, sampleRate: rate)
                },
                criticalStopHandler: { [weak self] message in
                    self?.handleCriticalCaptureStop(message)
                }
            )
            beginCriticalCaptureActivity(reason: "Recording pipe-organ audio")
            take.sampleRate = format.sampleRate
            take.channelCount = format.channelCount
            activeTakeIncludesInteractionSensor = interactionSensors.isCapturingTake
            livePitch.configure(item: item, project: project)
            project.takes.append(take)
            if let index = project.roadmap.firstIndex(where: { $0.id == item.id }) {
                project.roadmap[index].state = .recorded
                project.roadmap[index].takeIDs.append(id)
            }
            activeTakeID = id
            selectedTakeID = id
            self.project = project
            try await persist()
            // Keep the journal for the entire live capture. It is cleared only
            // after stop, BWF finalization, and the finalized manifest commit.
        } catch {
            let startError = error.localizedDescription
            if capture.isRecording {
                let result = await capture.stop { _ in
                    self.endCriticalCaptureActivity()
                    self.midiControl.cancelCapture()
                    self.interactionSensors.cancelCapture()
                }
                if var current = self.project,
                   let index = current.takes.firstIndex(where: { $0.id == id }) {
                    current.takes[index].endedAt = .now
                    current.takes[index].status = .failed
                    current.takes[index].frameCount = result.frameCount
                    current.takes[index].sampleRate = result.sampleRate
                    current.takes[index].channelCount = result.channelCount
                    current.takes[index].captureDiagnostics = result.diagnostics
                    var integrityFaults = current.takes[index].captureIntegrityFaults ?? []
                    integrityFaults.append(CaptureFault(
                        kind: .projectCommitFailure,
                        message: "The opening project transaction failed after audio capture started: \(startError)"
                    ))
                    if result.bwfFinalizationSucceeded != true {
                        integrityFaults.append(CaptureFault(
                            kind: .metadataFinalization,
                            message: "Broadcast Wave metadata finalization also failed during the aborted opening transaction."
                        ))
                    }
                    current.takes[index].captureIntegrityFaults = integrityFaults
                    current.takes[index].reviewReason = "Recording was finalized immediately because its opening project save failed: \(startError)"
                    current.takes[index].fileSize = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                    current.takes[index].sha256 = try? sha256(of: fileURL)
                    if let roadmapIndex = current.roadmap.firstIndex(where: { $0.id == item.id }) {
                        current.roadmap[roadmapIndex].state = .queued
                    }
                    self.project = current
                    try? writeActiveCaptureJournal(
                        take: current.takes[index],
                        priorRoadmapState: item.state,
                        packageURL: packageURL
                    )
                    _ = await persistOrReport(showAlert: false)
                }
            } else {
                clearActiveCaptureJournal(in: packageURL)
            }
            midiControl.cancelCapture()
            interactionSensors.cancelCapture()
            activeTakeIncludesInteractionSensor = false
            activeTakeID = nil
            errorMessage = "Recording did not start safely: \(startError)"
        }
    }

    func stopRecording() async {
        if isRunningCapturePreflight || pendingCapturePreflight != nil {
            await stopCapturePreflight()
            return
        }
        if isCalibrating {
            await stopPitchCalibration()
            return
        }
        if isLongTakeRecording {
            await stopLongTakeRecording()
            return
        }
        guard capture.isRecording, isStoppingRecording == false else { return }
        isStoppingRecording = true
        isWorking = true
        defer {
            isWorking = false
            isStoppingRecording = false
        }
        guard var project, let packageURL = projectURL, let id = activeTakeID,
              let takeIndex = project.takes.firstIndex(where: { $0.id == id }) else {
            _ = await capture.stop { _ in
                self.endCriticalCaptureActivity()
                self.midiControl.cancelCapture()
                self.interactionSensors.cancelCapture()
            }
            activeTakeID = nil
            activeTakeIncludesInteractionSensor = false
            includeInteractionSensorForNextTake = false
            livePitch.reset()
            errorMessage = "The recorder was finalized, but its active take metadata was unavailable. Reopen the project to run recovery."
            return
        }
        let fileURL = packageURL.appendingPathComponent(project.takes[takeIndex].relativeAudioPath)
        var eventLog: ControlEventLog?
        var hasAuxiliaryFinalizationWarning = false
        let result = await capture.stop { boundary in
            self.endCriticalCaptureActivity()
            eventLog = self.midiControl.endCapture()
            if self.interactionSensors.isCapturingTake {
                do {
                    if let sensorRecord = try self.interactionSensors.endCapture(
                        packageURL: packageURL,
                        audioStartHostNanoseconds: boundary.audioStartHostTimeNanoseconds
                    ) {
                        project.takes[takeIndex].interactionSensorCaptures = [sensorRecord]
                        if let derived = self.interactionSensors.lastFinalizedDerivedData,
                           derived.preview.count >= 2,
                           let firstDeviceTime = derived.preview.first?.deviceMicroseconds {
                            let usesProgress = derived.preview.contains { $0.progress != nil }
                            let points = derived.preview.map { point in
                                ActuationCurvePoint(
                                    time: point.audioSeconds
                                        ?? Double(point.deviceMicroseconds - firstDeviceTime) / 1_000_000,
                                    value: usesProgress ? (point.progress ?? 0) : point.angleDegrees
                                )
                            }
                            let curve = ActuationCurve(
                                kind: .custom,
                                timeBasis: .seconds,
                                interpolation: .linear,
                                points: points,
                                durationSeconds: points.last?.time,
                                evidenceSource: .sensorObserved,
                                deviceID: sensorRecord.configurationSnapshot.sensorDeviceID,
                                deviceLabel: sensorRecord.configurationSnapshot.name,
                                samplingRateHz: sensorRecord.configurationSnapshot.nominalSampleRateHz / 10,
                                calibrationReference: sensorRecord.calibrationSnapshot?.id.uuidString.lowercased(),
                                uncertainty: sensorRecord.clockAlignment.baseUncertaintySeconds,
                                notes: usesProgress
                                    ? "Downsampled calibrated action progress on the audio timeline; immutable raw IMU packets remain authoritative."
                                    : "Downsampled relative hinge angle in degrees on the audio timeline; immutable raw IMU packets remain authoritative."
                            )
                            project.takes[takeIndex].instrumentNoiseParadata?.observedActuationCurve = curve
                            project.takes[takeIndex].complexCaptureParadata?.observedActuationCurve = curve
                        }
                    }
                } catch {
                    hasAuxiliaryFinalizationWarning = true
                    let faultMessage = "Interaction-sensor finalization failed: \(error.localizedDescription)"
                    var integrityFaults = project.takes[takeIndex].captureIntegrityFaults ?? []
                    integrityFaults.append(CaptureFault(
                        kind: .auxiliaryEvidenceFailure,
                        message: faultMessage
                    ))
                    project.takes[takeIndex].captureIntegrityFaults = integrityFaults
                    project.takes[takeIndex].reviewReason = [
                        project.takes[takeIndex].reviewReason,
                        faultMessage,
                    ].compactMap { $0 }.joined(separator: " ")
                    self.notice = "Audio was retained, but the experimental sensor capture needs review: \(error.localizedDescription)"
                }
            }
        }
        project.takes[takeIndex].endedAt = .now
        project.takes[takeIndex].frameCount = result.frameCount
        project.takes[takeIndex].sampleRate = result.sampleRate
        project.takes[takeIndex].channelCount = result.channelCount
        project.takes[takeIndex].captureDiagnostics = result.diagnostics
        project.takes[takeIndex].controlEventLog = eventLog
        if let eventLog {
            project.takes[takeIndex].audioControlAlignment = AudioControlAlignment.sharedHostClock(
                eventLog: eventLog,
                audioStartHostTimeTicks: result.audioStartHostTimeTicks,
                audioStartHostTimeNanoseconds: result.audioStartHostTimeNanoseconds,
                audioStartSampleTime: result.audioStartSampleTime,
                sampleRate: result.sampleRate,
                frameCount: result.frameCount
            )
            let metadataDirectory = packageURL.appendingPathComponent("Metadata/ControlEvents", isDirectory: true)
            try? FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
            let sidecarURL = metadataDirectory.appendingPathComponent("\(id.uuidString.lowercased()).json")
            if let sidecar = try? OrgRecCoding.encoder.encode(eventLog) {
                try? sidecar.write(to: sidecarURL, options: .atomic)
            }
        }
        project.takes[takeIndex].livePitchEvidence = livePitch.finalEvidence
        if result.bwfFinalizationSucceeded == true {
            project.takes[takeIndex].status = .analyzing
        } else {
            project.takes[takeIndex].status = .failed
            var integrityFaults = project.takes[takeIndex].captureIntegrityFaults ?? []
            integrityFaults.append(CaptureFault(
                kind: .metadataFinalization,
                message: "Broadcast Wave metadata finalization failed; the retained audio must not be accepted until it is recaptured."
            ))
            project.takes[takeIndex].captureIntegrityFaults = integrityFaults
            project.takes[takeIndex].reviewReason = [
                project.takes[takeIndex].reviewReason,
                "Broadcast Wave metadata finalization failed; the retained audio must not be accepted until the container is repaired or recaptured.",
            ].compactMap { $0 }.joined(separator: " ")
        }
        project.takes[takeIndex].sha256 = try? sha256(of: fileURL)
        project.takes[takeIndex].fileSize = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        self.project = project
        if hasAuxiliaryFinalizationWarning == false, let message = result.bwfMessage {
            notice = message
        }
        activeTakeID = nil
        activeTakeIncludesInteractionSensor = false
        includeInteractionSensorForNextTake = false
        livePitch.reset()
        guard await persistOrReport() else {
            let prior = project.roadmap.first(where: { $0.id == project.takes[takeIndex].roadmapItemID })?.state ?? .queued
            try? writeActiveCaptureJournal(
                take: project.takes[takeIndex],
                priorRoadmapState: prior,
                packageURL: packageURL
            )
            return
        }
        clearActiveCaptureJournal(in: packageURL)
        guard result.bwfFinalizationSucceeded == true else {
            errorMessage = "The audio was retained and indexed, but Broadcast Wave metadata finalization failed. This take is marked failed and will not be analyzed automatically."
            return
        }
        await analyze(takeID: id)
    }

    func inspectLongTake(at source: URL) async {
        guard hasRecoverableLongTakeMaster == false else {
            errorMessage = "Create note takes from the retained continuous master before replacing it with another import."
            return
        }
        await analyzeLongTake(at: source, recordedInOrgRec: false)
    }

    func reanalyzeLongTake() async {
        guard let source = longTakeSourceURL else { return }
        await analyzeLongTake(at: source, recordedInOrgRec: pendingLongTakeWasRecorded)
    }

    func clearLongTakePreview(allowRecordedMaster: Bool = false) {
        guard isLongTakeRecording == false else { return }
        if pendingLongTakeWasRecorded && allowRecordedMaster == false {
            notice = "The recorded continuous master remains available until its note takes are created."
            return
        }
        if let projectURL { clearLongTakeCaptureJournal(in: projectURL) }
        longTakeSourceURL = nil
        longTakeAnalysis = nil
        longTakeStatus = nil
        pendingLongTakeID = nil
        pendingLongTakeWasRecorded = false
        pendingLongTakeCaptureDiagnostics = nil
        pendingLongTakeDeviceSnapshot = nil
    }

    func startLongTakeRecording() async {
        guard let project, let packageURL = projectURL, let item = selectedRoadmapItem else {
            errorMessage = "Choose the first roadmap note for the long take before recording."
            return
        }
        guard capture.isRecording == false,
              capture.isFinalizing == false,
              isWorking == false,
              isStoppingLongTake == false else {
            errorMessage = "Stop or finish the current recording operation before starting a long take."
            return
        }
        guard isStartingCapture == false else {
            errorMessage = "Another recording is already starting."
            return
        }
        isStartingCapture = true
        defer { isStartingCapture = false }
        let blockers = captureReadiness.filter { $0.severity == .blocker }
        guard blockers.isEmpty else {
            errorMessage = "Recording is not ready: " + blockers.map(\.title).joined(separator: "; ")
            page = .fieldQA
            return
        }
        do {
            guard let device = audioSystem.selectedDevice else {
                throw NSError(domain: "OrgRec", code: 30, userInfo: [NSLocalizedDescriptionKey: "Select an input interface in Setup before recording."])
            }
            let available = try packageURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                .volumeAvailableCapacityForImportantUsage ?? 0
            guard available > 2_147_483_648 else {
                throw NSError(domain: "OrgRec", code: 31, userInfo: [NSLocalizedDescriptionKey: "Long-take recording requires at least 2 GiB of available space on the project volume."])
            }
            try audioSystem.applyToHAL()
            let setup = item.setupID.flatMap { setupID in project.setups.first { $0.id == setupID } }
            let requiredChannel = setup?.placements.map(\.channelNumber).max() ?? 0
            guard requiredChannel <= device.inputChannels else {
                throw NSError(domain: "OrgRec", code: 32, userInfo: [NSLocalizedDescriptionKey: "The selected microphone setup requires more channels than the active interface provides."])
            }
            var roles = (0..<device.inputChannels).map { "Input \($0 + 1)" }
            for placement in setup?.placements ?? [] where roles.indices.contains(placement.channelNumber - 1) {
                roles[placement.channelNumber - 1] = placement.role
            }
            let referenceChannelNumber = setup?.referenceChannelNumber ?? 1
            guard (1...device.inputChannels).contains(referenceChannelNumber) else {
                throw NSError(
                    domain: "OrgRec",
                    code: 36,
                    userInfo: [NSLocalizedDescriptionKey: "The analysis reference channel \(referenceChannelNumber) is outside the \(device.inputChannels)-channel input device."]
                )
            }
            let referenceChannel = referenceChannelNumber - 1
            let id = UUID()
            let relativePath = "Audio/LongTakes/\(id.uuidString.lowercased()).wav"
            let fileURL = packageURL.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let now = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = .current
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timeFormatter = DateFormatter()
            timeFormatter.locale = Locale(identifier: "en_US_POSIX")
            timeFormatter.timeZone = .current
            timeFormatter.dateFormat = "HH:mm:ss"
            let bwf = BWFMetadata(
                description: "\(project.organName) · long take · \(item.component.label) · starting \(item.component.noteName ?? "selected note")",
                originatorReference: "ORGREC-LONG-\(project.id.uuidString.prefix(8))-\(id.uuidString.prefix(12))",
                originationDate: dateFormatter.string(from: now),
                originationTime: timeFormatter.string(from: now),
                codingHistory: "A=PCM,F=\(Int(audioSystem.selectedSampleRate)),W=24,M=multichannel,T=OrgRec long take"
            )
            let deviceSnapshot = device.snapshot(
                mode: audioSystem.latencyMode,
                sampleRate: audioSystem.selectedSampleRate,
                bufferFrames: audioSystem.selectedBufferFrames
            )
            try writeLongTakeCaptureJournal(
                LongTakeCaptureJournal(
                    id: id,
                    relativeAudioPath: relativePath,
                    roadmapItemID: item.id,
                    createdAt: now,
                    deviceSnapshot: deviceSnapshot,
                    captureDiagnostics: nil
                ),
                packageURL: packageURL
            )
            _ = try await capture.start(
                to: fileURL,
                deviceID: device.id,
                channelRoles: roles,
                referenceChannelIndex: referenceChannel,
                bwfMetadata: bwf,
                criticalStopHandler: { [weak self] message in
                    self?.handleCriticalCaptureStop(message)
                }
            )
            beginCriticalCaptureActivity(reason: "Recording a continuous pipe-organ take")
            pendingLongTakeID = id
            pendingLongTakeWasRecorded = true
            pendingLongTakeCaptureDiagnostics = nil
            pendingLongTakeDeviceSnapshot = deviceSnapshot
            longTakeSourceURL = fileURL
            longTakeAnalysis = nil
            longTakeStatus = "Recording one continuous take. Leave a short quiet gap between notes."
            isLongTakeRecording = true
        } catch {
            var partialDiagnostics: CaptureDiagnostics?
            if capture.isRecording {
                partialDiagnostics = await capture.stop().diagnostics
                endCriticalCaptureActivity()
            }
            if var journal = readLongTakeCaptureJournal(in: packageURL) {
                let retainedURL = packageURL.appendingPathComponent(journal.relativeAudioPath)
                let values = try? retainedURL.resourceValues(forKeys: [.isRegularFileKey])
                if values?.isRegularFile == true, readableAudioHasFrames(retainedURL) {
                    journal.captureDiagnostics = partialDiagnostics
                    try? writeLongTakeCaptureJournal(journal, packageURL: packageURL)
                    pendingLongTakeID = journal.id
                    pendingLongTakeWasRecorded = true
                    pendingLongTakeDeviceSnapshot = journal.deviceSnapshot
                    pendingLongTakeCaptureDiagnostics = partialDiagnostics
                    longTakeSourceURL = retainedURL
                    longTakeStatus = "The start sequence failed, but its finalized continuous recording master was retained for recovery."
                } else {
                    clearLongTakeCaptureJournal(in: packageURL)
                }
            } else {
                clearLongTakeCaptureJournal(in: packageURL)
            }
            errorMessage = error.localizedDescription
        }
    }

    func stopLongTakeRecording() async {
        guard isLongTakeRecording,
              isStoppingLongTake == false,
              let source = longTakeSourceURL else { return }
        isStoppingLongTake = true
        isWorking = true
        defer {
            isWorking = false
            isStoppingLongTake = false
        }
        let result = await capture.stop { _ in
            self.endCriticalCaptureActivity()
            self.isLongTakeRecording = false
        }
        endCriticalCaptureActivity()
        isLongTakeRecording = false
        pendingLongTakeCaptureDiagnostics = result.diagnostics
        if let projectURL,
           let journal = readLongTakeCaptureJournal(in: projectURL) {
            var finalizedJournal = journal
            finalizedJournal.captureDiagnostics = result.diagnostics
            do {
                try writeLongTakeCaptureJournal(finalizedJournal, packageURL: projectURL)
            } catch {
                errorMessage = "The recording master was finalized, but its recovery journal could not be updated: \(error.localizedDescription)"
            }
        }
        if result.bwfFinalizationSucceeded != true {
            errorMessage = "The continuous audio master was retained, but Broadcast Wave metadata finalization failed. Its diagnostics remain attached to every derived note for review."
        }
        longTakeStatus = "Recording stopped. Detecting notes and matching the roadmap…"
        await analyzeLongTake(at: source, recordedInOrgRec: true)
    }

    func importLongTakeSegments() async {
        guard var project, let packageURL = projectURL,
              let sourceURL = longTakeSourceURL, let analysis = longTakeAnalysis else {
            errorMessage = "Analyze a long recording before importing its notes."
            return
        }
        guard capture.isRecording == false else {
            errorMessage = "Stop recording before importing split notes."
            return
        }
        let assigned = analysis.segments.filter { segment in
            guard let itemID = segment.assignedRoadmapItemID else { return false }
            return project.roadmap.contains { $0.id == itemID }
        }
        guard assigned.isEmpty == false else {
            errorMessage = "No detected region has a valid roadmap assignment."
            return
        }
        isWorking = true
        longTakeStatus = "Preserving the source master and writing \(assigned.count) independent WAV files…"
        defer { isWorking = false }
        var createdURLs: [URL] = []
        var didStageProjectForSave = false
        do {
            ensureActiveSession(in: &project)
            guard let session = project.recordingSessions?.last(where: { $0.endedAt == nil }) else {
                throw NSError(domain: "OrgRec", code: 33, userInfo: [NSLocalizedDescriptionKey: "An active recording session is required for import provenance."])
            }
            let longTakeID = pendingLongTakeID ?? UUID()
            pendingLongTakeID = longTakeID
            let longTakeDirectory = packageURL.appendingPathComponent("Audio/LongTakes", isDirectory: true)
            try FileManager.default.createDirectory(at: longTakeDirectory, withIntermediateDirectories: true)
            let packagePrefix = packageURL.standardizedFileURL.path + "/"
            let standardizedSource = sourceURL.standardizedFileURL
            let sourceRelativePath: String
            let preservedSourceURL: URL
            if pendingLongTakeWasRecorded, standardizedSource.path.hasPrefix(packagePrefix) {
                sourceRelativePath = String(standardizedSource.path.dropFirst(packagePrefix.count))
                preservedSourceURL = standardizedSource
            } else {
                let stem = safeFilename(sourceURL.deletingPathExtension().lastPathComponent)
                let fileName = "\(longTakeID.uuidString.lowercased())-\(stem.isEmpty ? "import" : stem).\(sourceURL.pathExtension.isEmpty ? "wav" : sourceURL.pathExtension.lowercased())"
                sourceRelativePath = "Audio/LongTakes/\(fileName)"
                preservedSourceURL = packageURL.appendingPathComponent(sourceRelativePath)
                guard FileManager.default.fileExists(atPath: preservedSourceURL.path) == false else {
                    throw NSError(domain: "OrgRec", code: 34, userInfo: [NSLocalizedDescriptionKey: "The preserved long-take destination already exists."])
                }
                try FileManager.default.copyItem(at: sourceURL, to: preservedSourceURL)
                createdURLs.append(preservedSourceURL)
            }
            let sourceHash = try sha256(of: sourceURL)
            let preservedHash = try sha256(of: preservedSourceURL)
            guard sourceHash == preservedHash else {
                throw NSError(domain: "OrgRec", code: 35, userInfo: [NSLocalizedDescriptionKey: "The preserved long-take checksum does not match the selected source."])
            }

            struct PendingSplit {
                var segment: LongTakeSegment
                var item: RoadmapItem
                var takeID: UUID
                var relativePath: String
                var destination: URL
            }
            var pending: [PendingSplit] = []
            var destinations: [UUID: URL] = [:]
            for segment in assigned {
                guard let itemID = segment.assignedRoadmapItemID,
                      let item = project.roadmap.first(where: { $0.id == itemID }) else { continue }
                let takeID = UUID()
                let relativePath = "Audio/Originals/\(takeID.uuidString.lowercased()).wav"
                let destination = packageURL.appendingPathComponent(relativePath)
                pending.append(PendingSplit(segment: segment, item: item, takeID: takeID, relativePath: relativePath, destination: destination))
                destinations[segment.id] = destination
            }
            createdURLs.append(contentsOf: pending.map(\.destination))
            let exports = try await longTakeExporter.export(
                sourceURL: preservedSourceURL,
                segments: pending.map(\.segment),
                destinations: destinations
            )
            let exportBySegment = Dictionary(uniqueKeysWithValues: exports.map { ($0.segmentID, $0) })
            var generatedIDs: [UUID] = []
            for split in pending {
                guard let exported = exportBySegment[split.segment.id] else { continue }
                let setup = split.item.setupID.flatMap { setupID in project.setups.first { $0.id == setupID } }
                let registration = split.item.registrationID.flatMap { registrationID in
                    project.registrations.first { $0.id == registrationID }
                }
                let calibration = session.tuningCalibrationID.flatMap { calibrationID in
                    project.tuningCalibrations?.first { $0.id == calibrationID && $0.status == .accepted }
                }
                let number = project.takes.filter { $0.roadmapItemID == split.item.id }.count + 1
                let warnings = split.segment.warnings
                let bwfFailure = pendingLongTakeCaptureDiagnostics?.faults.first {
                    $0.kind == .writerFailure && $0.message.localizedCaseInsensitiveContains("Broadcast Wave")
                }
                let reviewReason = ([
                    "Automatically split and classified from a continuous long take; verify onset, release, and note identity.",
                    bwfFailure.map { "The source master failed Broadcast Wave metadata finalization: \($0.message)" },
                ].compactMap { $0 } + warnings).joined(separator: " ")
                let take = TakeRecord(
                    id: split.takeID,
                    roadmapItemID: split.item.id,
                    takeNumber: number,
                    status: .needsReview,
                    startedAt: analysis.analyzedAt,
                    endedAt: analysis.analyzedAt,
                    relativeAudioPath: split.relativePath,
                    sampleRate: exported.sampleRate,
                    channelCount: exported.channelCount,
                    frameCount: exported.frameCount,
                    fileSize: Int64((try? split.destination.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0),
                    sha256: try sha256(of: split.destination),
                    audioDeviceSnapshot: pendingLongTakeDeviceSnapshot,
                    spectrogramConfiguration: project.spectrogramConfiguration ?? SpectrogramConfiguration(),
                    captureDiagnostics: pendingLongTakeCaptureDiagnostics,
                    analysisReferenceChannel: analysis.referenceChannel,
                    notes: "Source long take: \(analysis.sourceFilename), region \(split.segment.sequenceNumber), \(split.segment.exportStartSeconds.formatted(.number.precision(.fractionLength(3))))–\(split.segment.exportEndSeconds.formatted(.number.precision(.fractionLength(3)))) s.",
                    reviewReason: reviewReason,
                    provenance: TakeProvenanceSnapshot(
                        session: session,
                        recipe: project.recipe,
                        microphoneSetup: setup,
                        registration: registration,
                        component: split.item.component,
                        releaseBinding: project.snapshot.release,
                        navigatorPayloadSHA256: project.snapshot.payloadSHA256,
                        organMDVSID: project.organMDVSID,
                        tuningCalibration: calibration,
                        expectedFrequencyHz: split.item.component.expectedFrequencyHz,
                        physicalSoundTargetID: split.item.physicalSoundTargetID,
                        activationRoutes: split.item.activationRoutes,
                        actualActivationRouteID: split.item.primaryActivationRouteID
                    ),
                    longTakeSource: LongTakeSliceProvenance(
                        longTakeID: longTakeID,
                        sourceRelativeAudioPath: sourceRelativePath,
                        sourceSHA256: sourceHash,
                        sourceStartSeconds: split.segment.exportStartSeconds,
                        sourceEndSeconds: split.segment.exportEndSeconds,
                        detectedOnsetSeconds: split.segment.onsetSeconds,
                        detectedSoundOffsetSeconds: split.segment.soundOffsetSeconds,
                        sourceStartFrame: split.segment.exportStartFrame,
                        sourceEndFrame: split.segment.exportEndFrame,
                        detectedOnsetFrame: split.segment.onsetFrame,
                        detectedSoundOffsetFrame: split.segment.soundOffsetFrame,
                        assignmentMode: analysis.assignmentMode,
                        assignmentConfidence: split.segment.assignmentConfidence,
                        analyzerVersion: analysis.analyzerVersion
                    )
                )
                project.takes.append(take)
                generatedIDs.append(take.id)
                if let roadmapIndex = project.roadmap.firstIndex(where: { $0.id == split.item.id }) {
                    project.roadmap[roadmapIndex].takeIDs.append(take.id)
                    project.roadmap[roadmapIndex].state = .needsReview
                }
            }
            let sourceValues = try preservedSourceURL.resourceValues(forKeys: [.fileSizeKey])
            var sources = project.longTakeSources ?? []
            guard sources.contains(where: { $0.id == longTakeID }) == false else {
                throw OrgRecError.invalidProject("This continuous recording master has already been imported.")
            }
            sources.append(LongTakeSourceRecord(
                id: longTakeID,
                sourceFilename: analysis.sourceFilename,
                relativeAudioPath: sourceRelativePath,
                sha256: sourceHash,
                fileSize: Int64(sourceValues.fileSize ?? 0),
                sampleRate: analysis.sampleRate,
                channelCount: analysis.channelCount,
                frameCount: Int64((analysis.sourceDurationSeconds * analysis.sampleRate).rounded()),
                analysis: analysis,
                generatedTakeIDs: generatedIDs,
                sourceWasRecordedInOrgRec: pendingLongTakeWasRecorded
            ))
            project.longTakeSources = sources
            project.collectionAnalysis = CollectionAnalysisEngine.analyze(project: project)
            self.project = project
            didStageProjectForSave = true
            selectedTakeID = generatedIDs.last
            try await persist()
            if pendingLongTakeWasRecorded { clearLongTakeCaptureJournal(in: packageURL) }
            if let selectedTakeID { try? preparePlayback(takeID: selectedTakeID) }
            await runConsistencyAudit()
            notice = "Imported \(generatedIDs.count) split notes from \(analysis.sourceFilename). Each is marked for human review."
            clearLongTakePreview(allowRecordedMaster: true)
        } catch {
            if didStageProjectForSave == false {
                for url in createdURLs where FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                }
                longTakeStatus = "Import failed; files created by this attempt were removed."
            } else {
                longTakeStatus = "The note takes and source master are retained, but the project save must be retried."
            }
            errorMessage = "Could not import the long recording: \(error.localizedDescription)"
        }
    }

    private func analyzeLongTake(at source: URL, recordedInOrgRec: Bool) async {
        guard let selected = selectedRoadmapItem else {
            errorMessage = "Select the first expected roadmap note before analyzing a long recording."
            return
        }
        guard capture.isRecording == false else {
            errorMessage = "Stop recording before analyzing a long take."
            return
        }
        let candidates = longTakeCandidateItems.compactMap { item -> LongTakePitchCandidate? in
            guard let midi = item.component.midiNote, let frequency = item.component.expectedFrequencyHz else { return nil }
            return LongTakePitchCandidate(
                roadmapItemID: item.id,
                midiNote: midi,
                expectedFrequencyHz: frequency,
                label: item.component.noteName ?? "MIDI \(midi)"
            )
        }
        guard candidates.isEmpty == false else {
            errorMessage = "This roadmap sound has no pitched note positions available for classification."
            return
        }
        let setup = selected.setupID.flatMap { setupID in project?.setups.first { $0.id == setupID } }
        let referenceChannel = max(0, (setup?.referenceChannelNumber ?? 1) - 1)
        isWorking = true
        longTakeSourceURL = source
        pendingLongTakeWasRecorded = recordedInOrgRec
        if recordedInOrgRec == false { pendingLongTakeID = nil }
        longTakeStatus = "Measuring the room-noise floor, finding note boundaries, and classifying stable pitches…"
        defer { isWorking = false }
        do {
            let analysis = try await longTakeSegmenter.analyze(
                fileURL: source,
                candidates: candidates,
                anchorRoadmapItemID: selected.id,
                assignmentMode: longTakeAssignmentMode,
                referenceChannel: referenceChannel
            )
            longTakeAnalysis = analysis
            longTakeStatus = "Detected \(analysis.segments.count) note region(s); \(analysis.assignedSegmentCount) are assigned and \(analysis.reviewSegmentCount) need attention."
        } catch {
            longTakeAnalysis = nil
            longTakeStatus = nil
            errorMessage = "Could not analyze the long recording: \(error.localizedDescription)"
        }
    }

    func analyze(takeID: UUID) async {
        guard var project, let packageURL = projectURL,
              let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }),
              let item = project.roadmap.first(where: { $0.id == project.takes[takeIndex].roadmapItemID }) else { return }
        let operationToken = UUID()
        analysisOperationTokens[takeID] = operationToken
        let sourceAudioSHA256 = project.takes[takeIndex].sha256
        isWorking = true
        defer {
            if analysisOperationTokens[takeID] == operationToken {
                analysisOperationTokens[takeID] = nil
            }
            isWorking = false
        }
        let url = packageURL.appendingPathComponent(project.takes[takeIndex].relativeAudioPath)
        do {
            let configuration = project.takes[takeIndex].spectrogramConfiguration
                ?? project.spectrogramConfiguration
                ?? SpectrogramConfiguration()
            let result = try await analyzer.analyze(
                fileURL: url,
                expectedFrequency: item.component.expectedFrequencyHz,
                referenceChannel: project.takes[takeIndex].analysisReferenceChannel ?? 0,
                spectrogramConfiguration: configuration,
                pitchApplicability: item.inferredPitchApplicability
            )
            var analysis = result.0
            if let operatorKeyUp = project.annotations
                .filter({ $0.takeID == takeID && $0.code == "operator_key_up" })
                .sorted(by: { $0.createdAt < $1.createdAt })
                .last {
                analysis.keyUpSeconds = operatorKeyUp.atSeconds
            }
            updateInteractionSensorAudioCoupling(
                project: &project,
                takeIndex: takeIndex,
                analysis: &analysis,
                packageURL: packageURL
            )
            if let diagnostics = project.takes[takeIndex].captureDiagnostics {
                if diagnostics.droppedBuffers > 0 { analysis.qualityFlags.append("Audio writer queue overrun") }
                if diagnostics.discontinuityCount > 0 { analysis.qualityFlags.append("Sample-time discontinuity") }
                if diagnostics.faults.contains(where: { $0.kind == .writerFailure }) { analysis.qualityFlags.append("Audio writer failure") }
                if diagnostics.faults.contains(where: { $0.kind == .deviceChanged || $0.kind == .formatChanged }) {
                    analysis.qualityFlags.append("Core Audio device or format changed")
                }
            }
            if project.takes[takeIndex].livePitchEvidence?.contains(where: { $0.decision == .probableWrongNote }) == true {
                analysis.qualityFlags.append("Live monitor detected a probable wrong intended note")
            }
            let sourceHash = project.takes[takeIndex].sha256 ?? (try? sha256(of: url))
            if analysis.keyUpSeconds != result.0.keyUpSeconds {
                let rerun = try? LoopPointDetector.detect(
                    fileURL: url,
                    analysis: analysis,
                    pitchTrack: result.2.pitchTrack ?? [],
                    sourceAudioSHA256: sourceHash
                )
                if let rerun {
                    analysis.detectedLoopPointSets = rerun.candidates
                    analysis.pipeSoundBehavior = PipeSoundBehaviorAnalyzer.summarize(
                        analysis: analysis,
                        pitchTrack: result.2.pitchTrack ?? [],
                        partialTracks: result.2.partialTracks ?? [],
                        loopDetection: rerun
                    )
                }
            }
            let previousLoopSets: [LoopPointSet] = project.takes[takeIndex].loopPointSets ?? []
            let retainedReviewed: [LoopPointSet]
            if let sourceHash {
                retainedReviewed = previousLoopSets.filter { set in
                    set.status != LoopPointSetStatus.proposed && set.sourceAudioSHA256 == sourceHash
                }
            } else {
                retainedReviewed = []
            }
            project.takes[takeIndex].loopPointSets = retainedReviewed + (analysis.detectedLoopPointSets ?? [])
            if let acceptedID = project.takes[takeIndex].acceptedLoopPointSetID,
               retainedReviewed.first(where: { $0.id == acceptedID })?.status != LoopPointSetStatus.accepted {
                project.takes[takeIndex].acceptedLoopPointSetID = nil
            }
            let integrityIssue = captureIntegrityIssue(for: project.takes[takeIndex])
            if let captureReviewReason = project.takes[takeIndex].reviewReason?.trimmingCharacters(in: .whitespacesAndNewlines),
               captureReviewReason.isEmpty == false {
                let flag = "Capture finalization requires review: \(captureReviewReason)"
                if analysis.qualityFlags.contains(flag) == false {
                    analysis.qualityFlags.append(flag)
                }
            }
            project.takes[takeIndex].analysis = analysis
            project.takes[takeIndex].spectrogramConfiguration = result.2.configuration
            project.takes[takeIndex].partialTracks = result.2.partialTracks
            project.takes[takeIndex].pitchTrack = result.2.pitchTrack
            if let complex = item.complexCaptureProtocol {
                if project.takes[takeIndex].complexCaptureParadata == nil {
                    project.takes[takeIndex].complexCaptureParadata = ComplexCaptureTakeParadata(
                        protocolSnapshot: complex,
                        repetitionNumber: project.takes[takeIndex].takeNumber
                    )
                }
                var paradata = project.takes[takeIndex].complexCaptureParadata!
                if complex.physicalActuation != nil {
                    paradata.actuatorResponseObservation = ComplexCaptureAnalysisEngine.actuatorObservation(
                        take: project.takes[takeIndex], protocolSnapshot: complex, analysis: analysis
                    )
                }
                if complex.tremulant != nil {
                    paradata.tremulantAnalysis = ComplexCaptureAnalysisEngine.tremulantAnalysis(
                        take: project.takes[takeIndex], protocolSnapshot: complex, analysis: analysis
                    )
                }
                if complex.operationalBaseline != nil {
                    let referenceChannel = project.takes[takeIndex].analysisReferenceChannel ?? 0
                    paradata.operationalBaselineAnalysis = try await Task.detached {
                        try OperationalBaselineAnalyzer.analyze(
                            fileURL: url,
                            referenceChannel: referenceChannel,
                            maximumDurationSeconds: complex.operationalBaseline?.minimumDurationSeconds ?? 180
                        )
                    }.value
                    if let baselineWarnings = paradata.operationalBaselineAnalysis?.warnings {
                        analysis.qualityFlags.append(contentsOf: baselineWarnings)
                    }
                }
                project.takes[takeIndex].complexCaptureParadata = paradata
            }
            if let effect = try P2AnalysisEngine.analyzeEffect(
                fileURL: url, take: project.takes[takeIndex], item: item,
                referenceChannel: project.takes[takeIndex].analysisReferenceChannel ?? 0,
                annotations: project.annotations.filter { $0.takeID == takeID }
            ) {
                project.takes[takeIndex].effectAnalysis = effect
                analysis.qualityFlags.append(contentsOf: effect.warnings.filter { $0.localizedCaseInsensitiveContains("clipping") })
            }
            if let spatialProtocol = item.spatialAcousticProtocol,
               let geometry = project.spatialGeometrySnapshots?.first(where: { $0.id == spatialProtocol.geometrySnapshotID }),
               let observation = try P2AnalysisEngine.analyzeSpatial(
                   fileURL: url, take: project.takes[takeIndex], item: item, geometry: geometry
               ) {
                if project.takes[takeIndex].spatialAcousticParadata == nil {
                    project.takes[takeIndex].spatialAcousticParadata = SpatialAcousticTakeParadata(
                        protocolSnapshot: spatialProtocol, repetitionNumber: project.takes[takeIndex].takeNumber
                    )
                }
                project.takes[takeIndex].spatialAcousticParadata?.observation = observation
                analysis.qualityFlags.append(contentsOf: observation.warnings.filter { $0.localizedCaseInsensitiveContains("clipping") })
            }
            if var run = result.2.analysisRun {
                run.outputSummary = analysis
                run.warnings = analysis.qualityFlags
                var history = project.takes[takeIndex].analysisRuns ?? []
                history.append(run)
                project.takes[takeIndex].analysisRuns = history
            }
            project.takes[takeIndex].analysis = analysis
            project.takes[takeIndex].status = integrityIssue == nil
                ? (analysis.qualityFlags.isEmpty ? .recorded : .needsReview)
                : .failed
            if let roadmapIndex = project.roadmap.firstIndex(where: { $0.id == item.id }) {
                project.roadmap[roadmapIndex].state = integrityIssue == nil && analysis.qualityFlags.isEmpty
                    ? .recorded
                    : .needsReview
            }
            project.collectionAnalysis = CollectionAnalysisEngine.analyze(project: project)
            project.actuatorResponseFunctions = ComplexCaptureAnalysisEngine.responseFunctions(project: project)
            project.spatialAcousticResponseComparisons = P2AnalysisEngine.responseComparisons(project: project)
            guard analysisOperationTokens[takeID] == operationToken,
                  var currentProject = self.project,
                  let currentTakeIndex = currentProject.takes.firstIndex(where: { $0.id == takeID }),
                  currentProject.takes[currentTakeIndex].sha256 == sourceAudioSHA256 else {
                return
            }
            var analyzedTake = project.takes[takeIndex]
            let currentTake = currentProject.takes[currentTakeIndex]
            analyzedTake.markerCorrections = currentTake.markerCorrections
            analyzedTake.reviewHistory = currentTake.reviewHistory
            analyzedTake.loopPointReviews = currentTake.loopPointReviews
            if (currentTake.status == .accepted || currentTake.status == .rejected),
               captureIntegrityIssue(for: currentTake) == nil {
                analyzedTake.status = currentTake.status
                analyzedTake.reviewReason = currentTake.reviewReason
            }
            currentProject.takes[currentTakeIndex] = analyzedTake
            if let roadmapIndex = currentProject.roadmap.firstIndex(where: { $0.id == item.id }),
               currentProject.roadmap[roadmapIndex].state != .accepted,
               currentProject.roadmap[roadmapIndex].state != .rejected,
               currentProject.roadmap[roadmapIndex].state != .exempt {
                currentProject.roadmap[roadmapIndex].state = analyzedTake.status == .recorded
                    ? .recorded
                    : .needsReview
            }
            currentProject.collectionAnalysis = CollectionAnalysisEngine.analyze(project: currentProject)
            currentProject.actuatorResponseFunctions = ComplexCaptureAnalysisEngine.responseFunctions(project: currentProject)
            currentProject.spatialAcousticResponseComparisons = P2AnalysisEngine.responseComparisons(project: currentProject)
            self.project = currentProject
            selectedTakeID = takeID
            waveform = result.1
            spectrogram = result.2
            try saveAnalysisArtifacts(takeID: takeID, waveform: result.1, spectrogram: result.2, packageURL: packageURL)
            page = .analysis
            try? preparePlayback(takeID: takeID)
            try await persist()
            await runConsistencyAudit()
        } catch {
            let analysisError = error.localizedDescription
            if analysisOperationTokens[takeID] == operationToken,
               var currentProject = self.project,
               let currentTakeIndex = currentProject.takes.firstIndex(where: { $0.id == takeID }),
               currentProject.takes[currentTakeIndex].sha256 == sourceAudioSHA256,
               currentProject.takes[currentTakeIndex].status != .accepted,
               currentProject.takes[currentTakeIndex].status != .rejected {
                currentProject.takes[currentTakeIndex].status = .failed
                currentProject.takes[currentTakeIndex].reviewReason = [
                    currentProject.takes[currentTakeIndex].reviewReason,
                    "Analysis failed: \(analysisError)",
                ].compactMap { $0 }.joined(separator: " ")
                self.project = currentProject
            }
            _ = await persistOrReport(showAlert: false)
            errorMessage = analysisError
        }
    }

    private func updateInteractionSensorAudioCoupling(
        project: inout OrgRecProject,
        takeIndex: Int,
        analysis: inout AnalysisSummary,
        packageURL: URL
    ) {
        guard var captures = project.takes[takeIndex].interactionSensorCaptures,
              captures.isEmpty == false else { return }
        let boundaryUncertainty = (analysis.boundaries ?? []).compactMap { boundary -> Double? in
            guard boundary.marker == .onset || boundary.marker == .soundOffset else { return nil }
            return boundary.timeResolutionSeconds.map { $0 / 2 }
        }.max() ?? 0

        for captureIndex in captures.indices {
            guard let relativePath = captures[captureIndex].derivedRelativePath else { continue }
            let derivedURL = packageURL.appendingPathComponent(relativePath)
            guard let data = try? Data(contentsOf: derivedURL),
                  var derived = try? OrgRecCoding.decoder.decode(InteractionSensorDerivedData.self, from: data),
                  let coupling = InteractionSensorProcessing.coupleMotionToAudio(
                      events: derived.motionEvents,
                      acousticOnsetSeconds: analysis.onsetSeconds,
                      acousticSoundOffsetSeconds: analysis.soundOffsetSeconds,
                      operatorKeyUpSeconds: analysis.keyUpSeconds,
                      timingUncertaintySeconds: captures[captureIndex].clockAlignment.baseUncertaintySeconds + boundaryUncertainty
                  ) else { continue }
            captures[captureIndex].audioCoupling = coupling
            derived.audioCoupling = coupling

            if analysis.keyUpSeconds == nil,
               captures[captureIndex].configurationSnapshot.resolvedUseCase == .representativeKeyAction,
               let inferredRelease = coupling.releaseMotionStartAudioSeconds {
                analysis.keyUpSeconds = inferredRelease
            }
            if let encoded = try? OrgRecCoding.encoder.encode(derived) {
                try? encoded.write(to: derivedURL, options: .atomic)
            }
            let metadataURL = packageURL.appendingPathComponent(captures[captureIndex].metadataRelativePath)
            if let encoded = try? OrgRecCoding.encoder.encode(captures[captureIndex]) {
                try? encoded.write(to: metadataURL, options: .atomic)
            }
        }
        project.takes[takeIndex].interactionSensorCaptures = captures
    }

    func analyzeTemperament(rankComponentID: String, refreshCatalog: Bool = false) async {
        guard var project, let packageURL = projectURL else { return }
        guard capture.isRecording == false else {
            errorMessage = "Stop the current recording before running a temperament analysis."
            return
        }
        let rankItems = project.roadmap.filter {
            ($0.component.parentComponentID ?? $0.component.id) == rankComponentID && $0.component.midiNote != nil
        }
        guard let firstItem = rankItems.first else {
            errorMessage = "The selected rank has no note-level roadmap positions."
            return
        }
        let pitchClasses = Set(rankItems.compactMap { $0.component.midiNote.map { (($0 % 12) + 12) % 12 } })
        guard pitchClasses.count >= 8 else {
            errorMessage = "At least eight pitch classes are required; this rank contains only \(pitchClasses.count)."
            return
        }
        isWorking = true
        temperamentProgress = "Retrieving MODAVIS temperament vectors…"
        defer {
            isWorking = false
            temperamentProgress = nil
        }
        do {
            var catalog = project.temperamentCatalog
            if refreshCatalog || catalog == nil {
                guard let baseURL = project.snapshot.navigatorBaseURL ?? validatedNavigatorBaseURL() else {
                    throw NSError(domain: "OrgRec.Temperament", code: 1, userInfo: [NSLocalizedDescriptionKey: "Enter a valid Navigator URL."])
                }
                do {
                    var fetched = try await navigator.fetchTemperamentCatalog(baseURL: baseURL)
                    if fetched.modavisRelease == "unknown" { fetched.modavisRelease = project.snapshot.release.requestedRelease }
                    catalog = fetched
                    project.temperamentCatalog = fetched
                } catch {
                    guard catalog != nil else { throw error }
                    notice = "Navigator was unavailable; the frozen temperament catalog cache is being used."
                }
            }
            guard let catalog else {
                throw NSError(domain: "OrgRec.Temperament", code: 2, userInfo: [NSLocalizedDescriptionKey: "No MODAVIS temperament catalog is available."])
            }

            var chosen: [(RoadmapItem, Int)] = []
            var chosenTakeIDs = Set<UUID>()
            let byMIDI = Dictionary(grouping: rankItems) { $0.component.midiNote! }
            for midi in byMIDI.keys.sorted() {
                let candidates = (byMIDI[midi] ?? []).flatMap { item in
                    item.takeIDs.compactMap { takeID in project.takes.firstIndex(where: { $0.id == takeID }).map { (item, $0) } }
                }.filter { _, index in
                    ![TakeStatus.failed, .rejected, .recording].contains(project.takes[index].status)
                }
                let ranked = candidates.sorted { left, right in
                    let l = project.takes[left.1]
                    let r = project.takes[right.1]
                    let lScore = (l.analysis?.frequencyHz == nil ? 0 : 10) + (l.status == .accepted ? 2 : 0) + Int((l.analysis?.confidence ?? 0) * 10)
                    let rScore = (r.analysis?.frequencyHz == nil ? 0 : 10) + (r.status == .accepted ? 2 : 0) + Int((r.analysis?.confidence ?? 0) * 10)
                    return lScore > rScore
                }
                for candidate in ranked where chosenTakeIDs.insert(project.takes[candidate.1].id).inserted {
                    chosen.append(candidate)
                }
            }
            let recordedPitchClasses = Set(chosen.compactMap { $0.0.component.midiNote.map { (($0 % 12) + 12) % 12 } })
            guard recordedPitchClasses.count >= 8 else {
                throw NSError(domain: "OrgRec.Temperament", code: 3, userInfo: [NSLocalizedDescriptionKey: "The selected rank has only \(recordedPitchClasses.count) usable recorded pitch classes."])
            }

            for (position, pair) in chosen.enumerated() {
                let (item, takeIndex) = pair
                if project.takes[takeIndex].analysis?.frequencyHz == nil || project.takes[takeIndex].analysis?.confidence == nil {
                    temperamentProgress = "Analyzing \(item.component.noteName ?? "note") · \(position + 1) of \(chosen.count)…"
                    let url = packageURL.appendingPathComponent(project.takes[takeIndex].relativeAudioPath)
                    let output = try await analyzer.analyze(
                        fileURL: url,
                        expectedFrequency: item.component.expectedFrequencyHz,
                        referenceChannel: project.takes[takeIndex].analysisReferenceChannel ?? 0,
                        spectrogramConfiguration: SpectrogramConfiguration(
                            fftSize: 8_192,
                            maximumTimeBins: 300,
                            maximumAnalysisDurationSeconds: 30,
                            displayFrequencyBins: 160,
                            partialCount: 16
                        )
                    )
                    project.takes[takeIndex].analysis = output.0
                    project.takes[takeIndex].spectrogramConfiguration = output.2.configuration
                    project.takes[takeIndex].partialTracks = output.2.partialTracks
                    project.takes[takeIndex].pitchTrack = output.2.pitchTrack
                    if var run = output.2.analysisRun {
                        run.outputSummary = output.0
                        run.warnings = output.0.qualityFlags
                        var history = project.takes[takeIndex].analysisRuns ?? []
                        history.append(run)
                        project.takes[takeIndex].analysisRuns = history
                    }
                    if project.takes[takeIndex].status != .accepted {
                        project.takes[takeIndex].status = .needsReview
                    }
                    if position.isMultiple(of: 6) {
                        self.project = project
                        try await persist()
                    }
                }
            }

            let samples = chosen.compactMap { item, takeIndex -> TemperamentFrequencySample? in
                guard let midi = item.component.midiNote,
                      project.takes[takeIndex].analysis?.pitchEstimatorComparison?.severity != .critical,
                      let frequency = project.takes[takeIndex].analysis?.frequencyHz,
                      let confidence = project.takes[takeIndex].analysis?.confidence else { return nil }
                return TemperamentFrequencySample(
                    takeID: project.takes[takeIndex].id,
                    midiNote: midi,
                    footHeight: item.component.footHeight,
                    frequencyHz: frequency,
                    confidence: confidence,
                    uncertaintyCents: project.takes[takeIndex].analysis?.pitchTrackSummary.flatMap { summary in
                        guard let lower = summary.lowerUncertaintyCents, let upper = summary.upperUncertaintyCents else { return nil }
                        return max(0.5, (upper - lower) / 3.92)
                    },
                    pitchMADcents: project.takes[takeIndex].analysis?.pitchTrackSummary?.medianAbsoluteDeviationCents,
                    estimator: project.takes[takeIndex].analysis?.method
                )
            }
            let reference: (Double, TemperamentA4Source)
            if let accepted = acceptedCalibration?.normalizedA4Hz {
                reference = (accepted, .acceptedSessionCalibration)
            } else {
                let measuredA = samples.filter { $0.midiNote == 69 && $0.confidence >= 0.35 }.map(\.frequencyHz).sorted()
                if let value = medianValue(measuredA) {
                    reference = (value, .measuredFromSelectedRank)
                } else if let documented = project.documentedPitchStandard?.frequencyHz ?? project.organCharacteristics?.referencePitchHz {
                    reference = (documented, .documentedPrior)
                } else {
                    reference = (440, .assumed440)
                }
            }
            temperamentProgress = "Comparing \(samples.count) pitch measurements with \(catalog.entries.count) MODAVIS temperaments…"
            let report = TemperamentAnalysisEngine.analyze(
                samples: samples,
                referenceA4Hz: reference.0,
                referenceA4Source: reference.1,
                rankComponentID: rankComponentID,
                rankLabel: "\(firstItem.component.label) · \(firstItem.component.division)",
                documentedTemperament: project.organCharacteristics?.temperament.flatMap {
                    $0.localizedCaseInsensitiveContains("unknown") ? nil : $0
                },
                catalog: catalog
            )
            var reports = project.temperamentAnalyses ?? []
            reports.append(report)
            project.temperamentAnalyses = reports
            project.temperamentConsensus = TemperamentConsensusEngine.analyze(reports: reports)
            project.collectionAnalysis = CollectionAnalysisEngine.analyze(project: project)
            project.temperamentCatalog = catalog
            self.project = project
            selectedTemperamentReportID = report.id
            try await persist()
            await runConsistencyAudit()
            notice = "Temperament comparison completed: \(report.observations.count) pitch classes, \(catalog.entries.count) MODAVIS candidates, \(report.inferenceStrength.rawValue) evidence."
        } catch {
            self.project = project
            let analysisError = error.localizedDescription
            _ = await persistOrReport(showAlert: false)
            errorMessage = "Temperament analysis failed: \(analysisError)"
        }
    }

    func analyzeTimbre(rankComponentID: String, mode: TimbreAnalysisMode) async {
        guard var project, let packageURL = projectURL else { return }
        guard capture.isRecording == false else {
            errorMessage = "Stop the current recording before running timbre analysis."
            return
        }
        let rankItems = project.roadmap.filter {
            ($0.component.parentComponentID ?? $0.component.id) == rankComponentID && $0.component.midiNote != nil
        }
        guard let firstItem = rankItems.first else {
            errorMessage = "The selected rank has no note-level roadmap positions."
            return
        }
        let rankLabel = "\(firstItem.component.label) · \(firstItem.component.division) · \(firstItem.component.footHeight ?? "—")"
        let scope = TimbreAnalysisEngine.scopeAssessment(
            rankLabel: rankLabel,
            componentKind: firstItem.component.kind
        )
        isWorking = true
        timbreProgress = "Preparing steady-state rank analysis…"
        defer {
            isWorking = false
            timbreProgress = nil
        }

        if scope.0 == .notApplicable {
            let report = TimbreAnalysisEngine.report(
                mode: mode,
                rankComponentID: rankComponentID,
                rankLabel: rankLabel,
                observations: [],
                scopeApplicability: scope.0,
                scopeWarnings: scope.1
            )
            var reports = project.timbreAnalyses ?? []
            reports.append(report)
            project.timbreAnalyses = reports
            self.project = project
            selectedTimbreReportID = report.id
            do {
                try await persist()
                notice = "Timbre analysis recorded a not-applicable scope result; see the methodology note."
            } catch {
                errorMessage = "Could not save the timbre report: \(error.localizedDescription)"
            }
            return
        }

        var selected: [(RoadmapItem, TakeRecord)] = []
        var usedTakeIDs = Set<UUID>()
        let byMIDI = Dictionary(grouping: rankItems) { $0.component.midiNote! }
        for midi in byMIDI.keys.sorted() {
            let candidates = (byMIDI[midi] ?? []).flatMap { item in
                item.takeIDs.compactMap { takeID in
                    project.takes.first(where: { $0.id == takeID }).map { (item, $0) }
                }
            }.filter { _, take in
                ![TakeStatus.failed, .rejected, .recording].contains(take.status)
            }.sorted { left, right in
                func score(_ take: TakeRecord) -> Int {
                    (take.status == .accepted ? 100 : 0)
                        + (take.analysis?.frequencyHz == nil ? 0 : 30)
                        + Int((take.analysis?.confidence ?? 0) * 20)
                        + (take.sha256 == nil ? 0 : 5)
                }
                return score(left.1) > score(right.1)
            }
            if let choice = candidates.first(where: { usedTakeIDs.insert($0.1.id).inserted }) {
                selected.append(choice)
            }
        }
        guard selected.isEmpty == false else {
            errorMessage = "No usable recordings are attached to this rank."
            return
        }

        var observations: [PipeTimbreObservation] = []
        var warnings = scope.1
        for (index, pair) in selected.enumerated() {
            let (item, take) = pair
            timbreProgress = "LTAS for \(item.component.noteName ?? "note \(item.component.midiNote ?? 0)") · \(index + 1) of \(selected.count)…"
            let input = TimbreAnalysisInput(
                fileURL: packageURL.appendingPathComponent(take.relativeAudioPath),
                takeID: take.id,
                roadmapItemID: item.id,
                midiNote: item.component.midiNote,
                noteName: item.component.noteName,
                expectedFrequencyHz: item.component.expectedFrequencyHz,
                measuredFrequencyHz: take.analysis?.frequencyHz,
                measuredConfidence: take.analysis?.confidence,
                sourceAudioSHA256: take.sha256,
                sourceAnalysisRunID: take.analysis?.analysisRunID,
                referenceChannel: take.analysisReferenceChannel ?? 0,
                sustainStartSeconds: take.analysis?.sustainStartSeconds,
                soundOffsetSeconds: take.analysis?.soundOffsetSeconds,
                keyUpSeconds: take.analysis?.keyUpSeconds
            )
            do {
                observations.append(try await timbreAnalyzer.analyze(input: input, mode: mode))
            } catch {
                warnings.append("\(item.component.noteName ?? "MIDI \(item.component.midiNote ?? 0)"): \(error.localizedDescription)")
            }
        }
        let report = TimbreAnalysisEngine.report(
            mode: mode,
            rankComponentID: rankComponentID,
            rankLabel: rankLabel,
            observations: observations,
            scopeApplicability: scope.0,
            scopeWarnings: warnings
        )
        var reports = project.timbreAnalyses ?? []
        reports.append(report)
        project.timbreAnalyses = reports
        self.project = project
        selectedTimbreReportID = report.id
        do {
            try await persist()
            await runConsistencyAudit()
            if observations.isEmpty {
                errorMessage = "No pipe produced a usable timbre observation. The saved report contains the individual failures."
            } else {
                notice = "Timbre analysis completed for \(observations.count) of \(selected.count) pipes; result is \(report.applicability.rawValue)."
            }
        } catch {
            errorMessage = "Could not save the timbre report: \(error.localizedDescription)"
        }
    }

    private func medianValue(_ values: [Double]) -> Double? {
        guard values.isEmpty == false else { return nil }
        let middle = values.count / 2
        return values.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
    }

    func setReview(accepted: Bool, reason: String = "") async {
        guard var project, let takeID = selectedTakeID,
              let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }),
              let roadmapIndex = project.roadmap.firstIndex(where: { $0.id == project.takes[takeIndex].roadmapItemID }) else { return }
        if accepted, let issue = captureIntegrityIssue(for: project.takes[takeIndex]) {
            errorMessage = "This take cannot be accepted because its capture integrity is unresolved: \(issue) Reject it and record a replacement."
            return
        }
        if accepted,
           let protocolSnapshot = project.roadmap[roadmapIndex].complexCaptureProtocol,
           let issue = complexCaptureAcceptanceIssue(
               take: project.takes[takeIndex],
               protocolSnapshot: protocolSnapshot
           ) {
            errorMessage = issue
            return
        }
        if accepted, let issue = p2AcceptanceIssue(take: project.takes[takeIndex], item: project.roadmap[roadmapIndex]) {
            errorMessage = issue
            return
        }
        if accepted,
           project.takes[takeIndex].analysis?.pitchEstimatorComparison?.severity == .critical,
           reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Document a scientific reason before accepting a critical CREPE–pYIN mismatch."
            return
        }
        project.takes[takeIndex].status = accepted ? .accepted : .rejected
        let author = activeSession?.operatorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedAuthor = (author?.isEmpty == false ? author! : NSFullUserName())
        let resolvedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (accepted ? "Scientific review accepted automated and visual evidence" : "Scientific review requested a retake")
            : reason
        project.takes[takeIndex].reviewReason = [
            project.takes[takeIndex].reviewReason,
            resolvedReason,
        ].compactMap { $0 }.joined(separator: " ")
        var history = project.takes[takeIndex].reviewHistory ?? []
        history.append(ReviewDecision(
            decision: accepted ? "accepted" : "rejected",
            author: resolvedAuthor,
            reason: resolvedReason,
            analysisAlgorithmVersion: project.takes[takeIndex].analysis?.algorithmVersion
        ))
        project.takes[takeIndex].reviewHistory = history
        if var response = project.takes[takeIndex].complexCaptureParadata?.actuatorResponseObservation {
            response.takeStatus = project.takes[takeIndex].status
            project.takes[takeIndex].complexCaptureParadata?.actuatorResponseObservation = response
        }
        if var observation = project.takes[takeIndex].spatialAcousticParadata?.observation {
            observation.takeStatus = project.takes[takeIndex].status
            project.takes[takeIndex].spatialAcousticParadata?.observation = observation
        }
        project.actuatorResponseFunctions = ComplexCaptureAnalysisEngine.responseFunctions(project: project)
        project.spatialAcousticResponseComparisons = P2AnalysisEngine.responseComparisons(project: project)
        let targetCount = project.roadmap[roadmapIndex].minimumAcceptedTakeCount
        let linkedTakeIDs = Set(project.roadmap[roadmapIndex].takeIDs)
        let acceptedCount = project.takes.filter {
            linkedTakeIDs.contains($0.id) && $0.status == .accepted
        }.count
        if acceptedCount >= targetCount {
            project.roadmap[roadmapIndex].state = .accepted
        } else {
            project.roadmap[roadmapIndex].state = accepted ? .missing : .rejected
        }
        let session = project.recordingSessions?.last(where: { $0.endedAt == nil })
        selectedRoadmapID = SessionPlanningEngine.nextPlannedRoadmapItem(in: project, session: session)?.id
            ?? project.roadmap.first?.id
        self.project = project
        guard await persistOrReport() else { return }
        await runConsistencyAudit()
        if accepted, acceptedCount < targetCount {
            notice = "Take accepted (\(acceptedCount) of \(targetCount)); record another repetition to capture variability."
        } else {
            notice = accepted ? "Take accepted and roadmap coverage updated." : "Take rejected; the roadmap item is ready for a retake."
        }
    }

    private func complexCaptureAcceptanceIssue(
        take: TakeRecord,
        protocolSnapshot: ComplexCaptureProtocol
    ) -> String? {
        guard let paradata = take.complexCaptureParadata else {
            return "This P1 take has no structured protocol paradata and cannot be accepted."
        }
        switch protocolSnapshot.kind {
        case .physicalActuatorResponse:
            if paradata.actuatorResponseObservation == nil {
                return "Analyze the actuator response before acceptance so this take contributes a measured input-to-output point."
            }
        case .declarativeProcess:
            if let process = protocolSnapshot.processModel {
                let began = Set(paradata.events.filter { $0.kind == .processStageBegin }.compactMap(\.stageID))
                let ended = Set(paradata.events.filter { $0.kind == .processStageEnd }.compactMap(\.stageID))
                let missing = Set(process.stages.map(\.id)).subtracting(began.intersection(ended))
                if !missing.isEmpty {
                    return "Mark begin and end for every process stage before acceptance. Missing: \(missing.sorted().joined(separator: ", "))."
                }
                if paradata.events.contains(where: { $0.kind == .processCancelled }) {
                    return "A cancelled process remains valid paradata but cannot satisfy a completed Roadmap obligation; record another take."
                }
            }
        case .discreteShutterMapping:
            let observed = paradata.events.contains {
                $0.kind == .shutterStateObserved && $0.shutterStateID == protocolSnapshot.targetShutterStateID
            }
            if !observed { return "Mark the planned discrete shutter state before accepting this take." }
        case .tremulantResponse:
            guard let response = paradata.tremulantAnalysis else {
                return "Analyze the tremulant response before acceptance."
            }
            if [.activationTransition, .deactivationTransition].contains(protocolSnapshot.tremulant?.condition),
               response.commandTimeSeconds == nil {
                return "Mark or provide an aligned control event for the tremulant transition before acceptance."
            }
        case .operationalBaseline:
            guard let baseline = paradata.operationalBaselineAnalysis else {
                return "Analyze the operational baseline before acceptance."
            }
            let required = protocolSnapshot.operationalBaseline?.minimumDurationSeconds ?? 120
            if baseline.analyzedDurationSeconds + 0.01 < required {
                return "Record at least \(Int(required)) seconds before accepting this operating-noise layer."
            }
            if !paradata.events.contains(where: { $0.kind == .baselineStable }) {
                return "Mark stable operation before accepting this operating-noise layer."
            }
        }
        return nil
    }

    private func p2AcceptanceIssue(take: TakeRecord, item: RoadmapItem) -> String? {
        if item.inferredNonPitchedEffectAnalysisProtocol != nil, take.effectAnalysis == nil {
            return "Analyze this non-pitched effect before acceptance so latency, level, event timing, periodicity, and variability are documented."
        }
        if let protocolSnapshot = item.spatialAcousticProtocol {
            guard let paradata = take.spatialAcousticParadata,
                  paradata.protocolSnapshot.id == protocolSnapshot.id,
                  paradata.observation != nil else {
                return "Analyze the P2 in-situ response before acceptance."
            }
            if !paradata.events.contains(where: { $0.kind == .stateConfirmed }) {
                return "Confirm the planned shutter/enclosure state during capture before accepting this response take."
            }
            if !paradata.events.contains(where: { $0.kind == .sourceTriggered }) &&
                paradata.observation?.onsetLatencySeconds == nil {
                return "Mark the source trigger or retain a synchronized control event before accepting this response take."
            }
        }
        return nil
    }

    func reanalyzeSelected(with configuration: SpectrogramConfiguration) async {
        guard var project else { return }
        project.spectrogramConfiguration = configuration
        if let takeID = selectedTakeID,
           let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }) {
            project.takes[takeIndex].spectrogramConfiguration = configuration
        }
        self.project = project
        guard await persistOrReport() else { return }
        if let takeID = selectedTakeID,
           project.takes.contains(where: { $0.id == takeID }) {
            await analyze(takeID: takeID)
        } else {
            notice = "Spectral profile saved for subsequent recordings."
        }
    }

    func updateProject(_ mutation: (inout OrgRecProject) -> Void) async {
        guard var project else { return }
        mutation(&project)
        self.project = project
        guard await persistOrReport() else { return }
    }

    func saveInteractionSensorConfiguration(_ configuration: InteractionSensorConfiguration) async {
        var configuration = configuration
        if configuration.capturePolicy == .required { configuration.capturePolicy = .optional }
        await updateProject { project in
            var configurations = project.interactionSensorConfigurations ?? []
            if let index = configurations.firstIndex(where: { $0.id == configuration.id }) {
                configurations[index] = configuration
            } else {
                configurations.append(configuration)
            }
            project.interactionSensorConfigurations = configurations
            project.activeInteractionSensorConfigurationID = configuration.id
            if let deviceID = configuration.sensorDeviceID,
               project.devices.contains(where: { $0.id == deviceID }) == false {
                project.devices.append(DeviceInstance(
                    id: deviceID,
                    kind: .sensor,
                    manufacturer: "InvenSense / experimental node",
                    model: configuration.name,
                    serialNumber: configuration.nodeIdentifier,
                    details: [
                        "protocol": configuration.protocolIdentifier,
                        "firmware": configuration.firmwareIdentifier,
                        "experimental": "true",
                    ]
                ))
            }
        }
        notice = "Experimental interaction-sensor configuration saved."
    }

    func acceptInteractionSensorCalibration(_ calibration: InteractionSensorCalibration) async {
        await updateProject { project in
            var calibrations = project.interactionSensorCalibrations ?? []
            calibrations.removeAll { $0.id == calibration.id }
            calibrations.append(calibration)
            project.interactionSensorCalibrations = calibrations
            if var configurations = project.interactionSensorConfigurations,
               let index = configurations.firstIndex(where: { $0.id == calibration.configurationID }) {
                configurations[index].currentCalibrationID = calibration.id
                configurations[index].validationState = .provisional
                project.interactionSensorConfigurations = configurations
            }
        }
        interactionSensors.applyCalibration(calibration)
        notice = "Calibration accepted provisionally. Validate it against an independent reference before scientific use."
    }

    func saveInteractionSensorValidation(_ session: InteractionSensorValidationSession) async {
        await updateProject { project in
            var sessions = project.interactionSensorValidations ?? []
            sessions.append(session)
            project.interactionSensorValidations = sessions
            if var configurations = project.interactionSensorConfigurations,
               let index = configurations.firstIndex(where: { $0.id == session.configurationID }) {
                configurations[index].validationState = session.summary.passedExperimentalGate ? .acceptedForExperiment : .provisional
                project.interactionSensorConfigurations = configurations
            }
        }
        notice = session.summary.passedExperimentalGate
            ? "Validation session saved; this calibration passed the provisional experimental gate."
            : "Validation session saved with unresolved experimental limitations."
    }

    func searchNoiseVenue(_ query: String) async {
        isSearchingNoiseVenue = true
        defer { isSearchingNoiseVenue = false }
        do {
            noiseGeocodeCandidates = try await noiseContextService.geocode(query)
            if noiseGeocodeCandidates.isEmpty {
                notice = "No OpenStreetMap venue candidates were found. You can enter the coordinates manually."
            }
        } catch {
            errorMessage = "Could not search OpenStreetMap: \(error.localizedDescription)"
        }
    }

    func assessNoiseContext(anchor: VenueAnchor, radiusMeters: Double) async -> NoiseContextAssessment? {
        isAssessingNoiseContext = true
        defer { isAssessingNoiseContext = false }
        do {
            return try await noiseContextService.assess(anchor: anchor, radiusMeters: radiusMeters)
        } catch {
            errorMessage = "Could not assess the surrounding noise context: \(error.localizedDescription)"
            return nil
        }
    }

    func saveSessionPlan(
        _ submittedPlan: RecordingSessionPlan,
        noiseAssessment submittedAssessment: NoiseContextAssessment?,
        startImmediately: Bool
    ) async {
        guard var project else { return }
        let eligibleIDs = Set(project.roadmap.map(\.id))
        guard submittedPlan.queue.isEmpty == false,
              submittedPlan.queue.allSatisfy({ eligibleIDs.contains($0.roadmapItemID) }) else {
            errorMessage = "The session plan must contain roadmap items from the current project."
            return
        }
        guard submittedPlan.organMDVSID == project.organMDVSID,
              submittedPlan.navigatorSnapshotSHA256 == project.snapshot.payloadSHA256 else {
            errorMessage = "The plan was prepared for a different organ specification snapshot. Reopen the planner."
            return
        }

        if let existing = project.sessionPlans?.first(where: { $0.id == submittedPlan.id }),
           existing.status == .active,
           startImmediately == false {
            errorMessage = "An active plan revision must continue as a new active session so its immutable paradata remain consistent."
            return
        }

        var assessment = submittedAssessment
        if var resolved = assessment {
            resolved.venueAnchor.confirmedAt = resolved.venueAnchor.confirmedAt ?? .now
            if resolved.venueAnchor.confirmedBy?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                resolved.venueAnchor.confirmedBy = submittedPlan.operatorName
            }
            var assessments = project.noiseContextAssessments ?? []
            if let index = assessments.firstIndex(where: { $0.id == resolved.id }) {
                resolved.revision = assessments[index].revision + 1
                resolved.supersedesAssessmentID = assessments[index].id
                resolved.id = UUID()
            }
            assessments.append(resolved)
            project.noiseContextAssessments = assessments
            project.venueAnchor = resolved.venueAnchor
            assessment = resolved
        }

        var plan = submittedPlan
        var plans = project.sessionPlans ?? []
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plan.revision = plans[index].revision + 1
            plan.supersedesPlanID = plans[index].id
            plan.id = UUID()
            plans[index].status = .completed
        }
        plan.noiseContextAssessmentID = assessment?.id
        plan.status = startImmediately ? .active : .frozen
        plan.frozenAt = .now
        if plan.status == .frozen {
            for index in plans.indices where plans[index].status == .frozen {
                plans[index].status = .completed
            }
        }
        plans.append(plan)
        project.sessionPlans = plans

        if startImmediately {
            var sessions = project.recordingSessions ?? []
            if let index = sessions.lastIndex(where: { $0.endedAt == nil }) {
                if let previousPlanID = sessions[index].sessionPlanID,
                   let planIndex = plans.firstIndex(where: { $0.id == previousPlanID && $0.id != plan.id }) {
                    plans[planIndex].status = .completed
                }
                sessions[index].endedAt = .now
            }
            sessions.append(makeSession(project: project, plan: plan, noiseAssessment: assessment))
            project.recordingSessions = sessions
            project.sessionPlans = plans
            selectedRoadmapID = SessionPlanningEngine.nextPlannedRoadmapItem(in: project, session: sessions.last)?.id
                ?? plan.queue.sorted(by: { $0.order < $1.order }).first?.roadmapItemID
            page = .roadmap
        }

        self.project = project
        do {
            try await persist()
            await runConsistencyAudit()
            notice = startImmediately
                ? "The planned recording session is active; its reviewed noise context is frozen into session paradata."
                : "Session plan saved with a revisioned surrounding-noise assessment."
        } catch {
            errorMessage = "Could not save the session plan: \(error.localizedDescription)"
        }
    }

    func startSessionPlan(_ planID: UUID) async {
        guard var project,
              var plans = project.sessionPlans,
              let planIndex = plans.firstIndex(where: { $0.id == planID }),
              let assessmentID = plans[planIndex].noiseContextAssessmentID,
              let assessment = project.noiseContextAssessments?.first(where: { $0.id == assessmentID }) else {
            errorMessage = "The plan needs a saved surrounding-noise assessment before it can start."
            return
        }
        var sessions = project.recordingSessions ?? []
        if let sessionIndex = sessions.lastIndex(where: { $0.endedAt == nil }) {
            if let previousPlanID = sessions[sessionIndex].sessionPlanID,
               let previousPlanIndex = plans.firstIndex(where: { $0.id == previousPlanID && $0.id != planID }) {
                plans[previousPlanIndex].status = .completed
            }
            sessions[sessionIndex].endedAt = .now
        }
        plans[planIndex].status = .active
        let plan = plans[planIndex]
        sessions.append(makeSession(project: project, plan: plan, noiseAssessment: assessment))
        project.sessionPlans = plans
        project.recordingSessions = sessions
        selectedRoadmapID = SessionPlanningEngine.nextPlannedRoadmapItem(in: project, session: sessions.last)?.id
            ?? plan.queue.sorted(by: { $0.order < $1.order }).first?.roadmapItemID
        self.project = project
        do {
            try await persist()
            await runConsistencyAudit()
            notice = "The planned recording session is active; its reviewed noise context is frozen into session paradata."
        } catch {
            errorMessage = "Could not start the session plan: \(error.localizedDescription)"
        }
    }

    func saveSession(_ session: RecordingSession) async {
        guard hasActiveCapture == false else {
            errorMessage = "Session paradata cannot be replaced while an audio capture is active. Stop and finalize it first."
            return
        }
        guard var project else { return }
        var sessions = project.recordingSessions ?? []
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            var updated = session
            // The editor works from a value snapshot. Preserve evidence that
            // may have been appended after that snapshot was opened.
            updated.capturePreflightReports = sessions[index].capturePreflightReports
            sessions[index] = updated
        } else {
            sessions.append(session)
        }
        project.recordingSessions = sessions
        self.project = project
        guard await persistOrReport() else { return }
        await runConsistencyAudit()
        notice = "Recording-session paradata saved."
    }

    func startNewSession() async {
        guard hasActiveCapture == false else {
            errorMessage = "Finish the active audio capture before closing this recording session."
            return
        }
        guard var project else { return }
        var sessions = project.recordingSessions ?? []
        if let index = sessions.lastIndex(where: { $0.endedAt == nil }) {
            sessions[index].endedAt = .now
        }
        sessions.append(makeSession(project: project))
        project.recordingSessions = sessions
        self.project = project
        guard await persistOrReport() else { return }
        await runConsistencyAudit()
        notice = "New recording session started."
    }

    func startPitchCalibration(using item: RoadmapItem) async {
        guard var project, let packageURL = projectURL, let session = activeSession else {
            errorMessage = "Open a project with an active recording session first."
            return
        }
        guard capture.isRecording == false,
              capture.isFinalizing == false,
              isWorking == false,
              isStoppingCalibration == false,
              item.component.midiNote == 69 else {
            errorMessage = "Calibration requires an A4 roadmap item and a fully idle recorder."
            return
        }
        guard isStartingCapture == false else {
            errorMessage = "Another recording is already starting."
            return
        }
        isStartingCapture = true
        defer { isStartingCapture = false }
        guard let device = audioSystem.selectedDevice else {
            errorMessage = "Select and apply an input interface in Setup first."
            return
        }
        let id = UUID()
        let relativePath = "Audio/Calibration/\(id.uuidString.lowercased()).wav"
        let fileURL = packageURL.appendingPathComponent(relativePath)
        let setup = item.setupID.flatMap { setupID in project.setups.first { $0.id == setupID } }
        let referenceChannelNumber = setup?.referenceChannelNumber ?? 1
        guard (1...device.inputChannels).contains(referenceChannelNumber) else {
            errorMessage = "The calibration reference channel \(referenceChannelNumber) is outside the \(device.inputChannels)-channel input device."
            return
        }
        let referenceChannel = referenceChannelNumber - 1
        var roles = (0..<device.inputChannels).map { "Input \($0 + 1)" }
        for placement in setup?.placements ?? [] where roles.indices.contains(placement.channelNumber - 1) {
            roles[placement.channelNumber - 1] = placement.role
        }
        let prior = project.documentedPitchStandard?.frequencyHz ?? 440
        let calibration = TuningCalibration(
            id: id,
            sessionID: session.id,
            referenceComponent: item.component.locator,
            documentedA4Hz: project.documentedPitchStandard?.frequencyHz,
            relativeAudioPath: relativePath,
            referenceChannelIndex: referenceChannel,
            environment: session.environment,
            notes: "A4 field reference; use one stable unison 8′ stop without tremulant, celeste, or couplers."
        )
        do {
            try audioSystem.applyToHAL()
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try writeCalibrationCaptureJournal(calibration: calibration, packageURL: packageURL)
            let isoStamp = ISO8601DateFormatter().string(from: .now)
            _ = try await capture.start(
                to: fileURL,
                deviceID: device.id,
                channelRoles: roles,
                referenceChannelIndex: referenceChannel,
                bwfMetadata: BWFMetadata(
                    description: "OrgRec tuning calibration · A4 · \(item.component.label)",
                    originatorReference: "ORGREC-CAL-\(id.uuidString.prefix(12))",
                    originationDate: String(isoStamp.prefix(10)),
                    originationTime: String(isoStamp.dropFirst(11).prefix(8)),
                    codingHistory: "A=PCM,F=\(Int(audioSystem.selectedSampleRate)),W=24,M=multichannel,T=OrgRec calibration"
                ),
                criticalStopHandler: { [weak self] message in
                    self?.handleCriticalCaptureStop(message)
                }
            )
            beginCriticalCaptureActivity(reason: "Recording the field A4 calibration")
            var calibrations = project.tuningCalibrations ?? []
            calibrations.append(calibration)
            project.tuningCalibrations = calibrations
            self.project = project
            activeCalibrationID = id
            isCalibrating = true
            notice = "Calibration recording started. Hold A4 steadily for at least three seconds."
            _ = prior // documents the intentional prior used by the analysis below
            try await persist()
        } catch {
            var partialResult: CaptureResult?
            if capture.isRecording {
                partialResult = await capture.stop { _ in self.endCriticalCaptureActivity() }
            }
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            if values?.isRegularFile != true || readableAudioHasFrames(fileURL) == false {
                clearCalibrationCaptureJournal(in: packageURL)
            } else {
                var recoverableCalibration = calibration
                recoverableCalibration.audioSHA256 = try? sha256(of: fileURL)
                recoverableCalibration.audioFileSize = Int64(values?.fileSize ?? 0)
                if let partialResult, partialResult.bwfFinalizationSucceeded != true {
                    recoverableCalibration.notes += " Broadcast Wave metadata finalization failed during the opening transaction; no pitch estimate was accepted."
                }
                try? writeCalibrationCaptureJournal(
                    calibration: recoverableCalibration,
                    packageURL: packageURL
                )
            }
            isCalibrating = false
            activeCalibrationID = nil
            errorMessage = error.localizedDescription
        }
    }

    func stopPitchCalibration() async {
        guard isStoppingCalibration == false else { return }
        isStoppingCalibration = true
        defer { isStoppingCalibration = false }
        guard var project, let packageURL = projectURL, let id = activeCalibrationID,
              let index = project.tuningCalibrations?.firstIndex(where: { $0.id == id }),
              let relativePath = project.tuningCalibrations?[index].relativeAudioPath else {
            if capture.isRecording {
                _ = await capture.stop { _ in self.endCriticalCaptureActivity() }
            } else {
                endCriticalCaptureActivity()
            }
            isCalibrating = false
            activeCalibrationID = nil
            errorMessage = "The calibration recorder was finalized, but its active metadata was unavailable. Reopen the project to recover retained evidence."
            return
        }
        isWorking = true
        defer { isWorking = false }
        let sourceProjectID = project.id
        let sourceProjectURL = packageURL.standardizedFileURL
        let captureResult = await capture.stop { _ in
            self.endCriticalCaptureActivity()
            self.isCalibrating = false
        }
        endCriticalCaptureActivity()
        isCalibrating = false
        activeCalibrationID = nil
        let fileURL = packageURL.appendingPathComponent(relativePath)
        if captureResult.bwfFinalizationSucceeded != true {
            project.tuningCalibrations?[index].audioSHA256 = try? sha256(of: fileURL)
            project.tuningCalibrations?[index].audioFileSize = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            project.tuningCalibrations?[index].notes += " Broadcast Wave metadata finalization failed; no pitch estimate was accepted."
            if let finalizedCalibration = project.tuningCalibrations?[index] {
                do {
                    try writeCalibrationCaptureJournal(
                        calibration: finalizedCalibration,
                        packageURL: packageURL
                    )
                } catch {
                    notice = "The calibration audio remains on disk, but its recovery journal could not record the BWF failure: \(error.localizedDescription)"
                }
            }
            guard self.project?.id == sourceProjectID,
                  self.projectURL?.standardizedFileURL == sourceProjectURL else { return }
            self.project = project
            if await persistOrReport() {
                clearCalibrationCaptureJournal(in: packageURL)
            }
            errorMessage = "The calibration audio was retained, but its Broadcast Wave metadata could not be finalized. Record a new field A4 before acceptance."
            return
        }
        do {
            let expected = project.documentedPitchStandard?.frequencyHz ?? 440
            let result = try await analyzer.analyze(
                fileURL: fileURL,
                expectedFrequency: expected,
                referenceChannel: project.tuningCalibrations?[index].referenceChannelIndex ?? 0,
                spectrogramConfiguration: SpectrogramConfiguration(maximumAnalysisDurationSeconds: 20)
            )
            let criticalMismatch = result.0.pitchEstimatorComparison?.severity == .critical
            let measured = criticalMismatch ? nil : result.0.frequencyHz
            project.tuningCalibrations?[index].measuredFrequencyHz = measured
            project.tuningCalibrations?[index].normalizedA4Hz = measured
            project.tuningCalibrations?[index].confidence = result.0.confidence
            project.tuningCalibrations?[index].centsFromDocumented = measured.flatMap { PitchMatcher.cents(measured: $0, expected: expected) }
            project.tuningCalibrations?[index].method = result.0.method
            project.tuningCalibrations?[index].algorithmVersion = result.0.algorithmVersion
            project.tuningCalibrations?[index].audioSHA256 = try? sha256(of: fileURL)
            project.tuningCalibrations?[index].audioFileSize = Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            if criticalMismatch, let comparison = result.0.pitchEstimatorComparison {
                let values = comparison.estimates.map { "\($0.estimator) \($0.frequencyHz.formatted(.number.precision(.fractionLength(2)))) Hz" }.joined(separator: ", ")
                project.tuningCalibrations?[index].notes += " Critical pitch-estimator mismatch (\(values)); calibration withheld."
            }
            guard self.project?.id == sourceProjectID,
                  self.projectURL?.standardizedFileURL == sourceProjectURL else {
                errorMessage = "Calibration analysis finished after the active project changed, so its result was not applied. The original project retains the recovery journal."
                return
            }
            self.project = project
            try await persist()
            clearCalibrationCaptureJournal(in: packageURL)
            notice = criticalMismatch
                ? "Calibration withheld because CREPE and pYIN critically disagree. Inspect the audio and record A4 again."
                : (measured == nil ? "Calibration captured, but no stable A4 was detected. Reject it and retry." : "A4 estimate is ready for review. Accept it to initialize this session.")
        } catch {
            project.tuningCalibrations?[index].notes += " Analysis failed: \(error.localizedDescription)"
            guard self.project?.id == sourceProjectID,
                  self.projectURL?.standardizedFileURL == sourceProjectURL else { return }
            self.project = project
            let analysisError = error.localizedDescription
            _ = await persistOrReport(showAlert: false)
            errorMessage = "Calibration analysis failed: \(analysisError)"
        }
    }

    func acceptPitchCalibration(_ calibrationID: UUID) async {
        guard var project,
              let calibrationIndex = project.tuningCalibrations?.firstIndex(where: { $0.id == calibrationID }),
              let a4 = project.tuningCalibrations?[calibrationIndex].normalizedA4Hz,
              let confidence = project.tuningCalibrations?[calibrationIndex].confidence,
              confidence >= 0.35,
              (350...550).contains(a4) else {
            errorMessage = "A valid 350–550 Hz estimate with sufficient confidence is required."
            return
        }
        project.tuningCalibrations?[calibrationIndex].status = .accepted
        project.tuningCalibrations?[calibrationIndex].acceptedAt = .now
        project.tuningCalibrations?[calibrationIndex].acceptedBy = activeSession?.operatorName.isEmpty == false ? activeSession?.operatorName : NSFullUserName()
        if let sessionID = project.tuningCalibrations?[calibrationIndex].sessionID,
           let sessionIndex = project.recordingSessions?.firstIndex(where: { $0.id == sessionID }) {
            project.recordingSessions?[sessionIndex].tuningCalibrationID = calibrationID
        }
        RoadmapEngine.applyFieldReferencePitch(a4, to: &project)
        self.project = project
        guard await persistOrReport() else { return }
        await runConsistencyAudit()
        notice = "Session A4 = \(a4.formatted(.number.precision(.fractionLength(2)))) Hz accepted; all future expected frequencies were recalculated."
    }

    func rejectPitchCalibration(_ calibrationID: UUID) async {
        guard var project, let index = project.tuningCalibrations?.firstIndex(where: { $0.id == calibrationID }) else { return }
        project.tuningCalibrations?[index].status = .rejected
        self.project = project
        guard await persistOrReport() else { return }
        notice = "Calibration rejected. Record A4 again."
    }

    func runConsistencyAudit() async {
        guard let project else { auditReport = nil; return }
        let packageURL = projectURL
        auditReport = await Task.detached(priority: .utility) {
            ProjectConsistencyAuditor.audit(project: project, packageURL: packageURL)
        }.value
    }

    func confirmPhysicalOverlap(_ candidate: PhysicalOverlapCandidate) async {
        guard var project else { return }
        guard project.takes.isEmpty else {
            errorMessage = "Physical-pipe groupings cannot replace a roadmap after recording has begun. Create a new project revision or preserve the existing take-linked roadmap."
            return
        }
        guard project.sessionPlans?.isEmpty != false else {
            errorMessage = "Physical-pipe groupings cannot replace a roadmap after session planning has begun. Create a new project revision so frozen plan identifiers and paradata remain immutable."
            return
        }
        guard let first = project.organComponents?.first(where: { $0.id == candidate.firstStopComponentID }),
              let second = project.organComponents?.first(where: { $0.id == candidate.secondStopComponentID }) else {
            errorMessage = "The suspected shared stops are no longer present in the frozen specification."
            return
        }
        let assertion = PipeSharingAssertion(
            stops: [
                StopPipeOffset(stopComponentID: first.id, soundingSemitoneOffset: candidate.firstSoundingSemitoneOffset),
                StopPipeOffset(stopComponentID: second.id, soundingSemitoneOffset: candidate.secondSoundingSemitoneOffset),
            ],
            soundingMIDILow: candidate.soundingMIDILow,
            soundingMIDIHigh: candidate.soundingMIDIHigh,
            snapshotSHA256: project.snapshot.payloadSHA256,
            author: NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Local reviewer" : NSFullUserName(),
            note: "Confirmed that \(first.label) and \(second.label) share the indicated physical rank over the reviewed overlap."
        )
        project.pipeSharingAssertions = (project.pipeSharingAssertions ?? []) + [assertion]
        applyPhysicalRoadmapRecompilation(to: &project)
        self.project = project
        selectedRoadmapID = RoadmapEngine.nextItem(in: project.roadmap)?.id ?? project.roadmap.first?.id
        guard await persistOrReport() else { return }
        await runConsistencyAudit()
        notice = "Confirmed \(candidate.overlappingAddressCount) shared physical positions between \(first.label) and \(second.label); duplicate capture obligations were removed."
    }

    func removePipeSharingAssertion(_ assertionID: UUID) async {
        guard var project else { return }
        guard project.takes.isEmpty else {
            errorMessage = "A reviewed physical-pipe grouping cannot be removed after recording has begun because takes are bound to its roadmap targets."
            return
        }
        guard project.sessionPlans?.isEmpty != false else {
            errorMessage = "Physical-pipe groupings cannot replace a roadmap after session planning has begun. Create a new project revision so frozen plan identifiers and paradata remain immutable."
            return
        }
        project.pipeSharingAssertions?.removeAll { $0.id == assertionID }
        applyPhysicalRoadmapRecompilation(to: &project)
        self.project = project
        selectedRoadmapID = RoadmapEngine.nextItem(in: project.roadmap)?.id ?? project.roadmap.first?.id
        guard await persistOrReport() else { return }
        await runConsistencyAudit()
        notice = "The local shared-rank assertion was removed and the independent capture obligations were restored."
    }

    private func applyPhysicalRoadmapRecompilation(to project: inout OrgRecProject) {
        let previousRoadmap = project.roadmap.filter { $0.coverageKind != .customRegistration }
        let previousRegistrations = project.registrations
        let customItems = project.roadmap.filter { $0.coverageKind == .customRegistration }
        let supplementalItems = project.roadmap.filter {
            $0.coverageKind == .instrumentNoise
                || $0.complexCaptureProtocol != nil
                || $0.spatialAcousticProtocol != nil
        }
        let supplementalRegistrationIDs = Set((customItems + supplementalItems).compactMap(\.registrationID))
        let supplementalRegistrations = project.registrations.filter { supplementalRegistrationIDs.contains($0.id) }
        var compilation = RoadmapEngine.compileSpecification(
            components: project.organComponents ?? [],
            recipe: project.recipe,
            setupIDs: project.setups.map(\.id),
            relationships: project.componentRelationships ?? [],
            physicalPipeMappings: project.physicalPipeMappings ?? [],
            sharingAssertions: project.pipeSharingAssertions ?? []
        )

        let previousRegistrationsByIdentity = Dictionary(grouping: previousRegistrations, by: registrationIdentity)
        var registrationReplacements: [UUID: UUID] = [:]
        for index in compilation.registrations.indices {
            let generatedID = compilation.registrations[index].id
            let identity = registrationIdentity(compilation.registrations[index])
            if let preserved = previousRegistrationsByIdentity[identity]?.first {
                compilation.registrations[index].id = preserved.id
                compilation.registrations[index].revision = preserved.revision
                registrationReplacements[generatedID] = preserved.id
            }
        }
        for targetIndex in compilation.physicalSoundTargets.indices {
            for routeIndex in compilation.physicalSoundTargets[targetIndex].routes.indices {
                let generatedID = compilation.physicalSoundTargets[targetIndex].routes[routeIndex].registrationID
                compilation.physicalSoundTargets[targetIndex].routes[routeIndex].registrationID = registrationReplacements[generatedID] ?? generatedID
            }
        }
        for index in compilation.roadmap.indices {
            if let generatedID = compilation.roadmap[index].registrationID {
                compilation.roadmap[index].registrationID = registrationReplacements[generatedID] ?? generatedID
            }
            if var routes = compilation.roadmap[index].activationRoutes {
                for routeIndex in routes.indices {
                    let generatedID = routes[routeIndex].registrationID
                    routes[routeIndex].registrationID = registrationReplacements[generatedID] ?? generatedID
                }
                compilation.roadmap[index].activationRoutes = routes
            }
        }

        var previousItemsByIdentity = Dictionary(grouping: previousRoadmap, by: roadmapIdentity)
        for index in compilation.roadmap.indices {
            let identity = roadmapIdentity(compilation.roadmap[index])
            guard var matches = previousItemsByIdentity[identity], matches.isEmpty == false else { continue }
            let preserved = matches.removeFirst()
            previousItemsByIdentity[identity] = matches
            compilation.roadmap[index].id = preserved.id
            compilation.roadmap[index].state = preserved.state
            compilation.roadmap[index].takeIDs = preserved.takeIDs
        }
        let compiledIdentities = Set(compilation.roadmap.map(roadmapIdentity))
        let retainedSupplementalItems = supplementalItems.filter {
            compiledIdentities.contains(roadmapIdentity($0)) == false
        }
        project.registrations = compilation.registrations + supplementalRegistrations
        project.roadmap = compilation.roadmap + retainedSupplementalItems + customItems
        project.roadmapCompilation = compilation.report
        project.physicalSoundTargets = compilation.physicalSoundTargets
        project.physicalOverlapCandidates = compilation.overlapCandidates
        project.captureStates = (project.captureStates ?? []) + compilation.captureStates
        refreshCaptureStateLibrary(in: &project)
    }

    private func registrationIdentity(_ registration: RegistrationState) -> String {
        [
            registration.activatedStops.map(\.id).sorted().joined(separator: ","),
            registration.activatedCouplers.map(\.id).sorted().joined(separator: ","),
            registration.activatedAccessories.map(\.id).sorted().joined(separator: ","),
            registration.name ?? "",
            registration.purpose ?? "",
        ].joined(separator: "|")
    }

    private func roadmapIdentity(_ item: RoadmapItem) -> String {
        [
            item.component.id,
            item.technique.rawValue,
            item.setupID?.uuidString ?? "",
            item.coverageKind?.rawValue ?? "",
        ].joined(separator: "|")
    }

    func openIssue(_ issue: ConsistencyIssue) {
        if let roadmapItemID = issue.roadmapItemID { selectedRoadmapID = roadmapItemID }
        if let takeID = issue.takeID {
            selectedTakeID = takeID
            if issue.scope == .analysis || issue.scope == .review { page = .analysis; return }
        }
        switch issue.scope {
        case .session, .integrity: page = .fieldQA
        case .setup, .recording: page = .setup
        case .modavis, .roadmap: page = .roadmap
        case .analysis, .review: page = .analysis
        }
    }

    func correctedMarker(_ marker: AnalysisMarkerKind) -> Double? {
        guard let take = selectedTake else { return nil }
        if let correction = take.markerCorrections?
            .filter({ $0.marker == marker })
            .max(by: { $0.createdAt < $1.createdAt }) {
            return correction.correctedSeconds
        }
        return automatedMarker(marker, analysis: take.analysis)
    }

    func saveMarkerCorrections(
        _ values: [AnalysisMarkerKind: Double],
        author: String,
        reason: String
    ) async {
        guard var project, let takeID = selectedTakeID,
              let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }) else { return }
        let duration = max(0, project.takes[takeIndex].endedAt?.timeIntervalSince(project.takes[takeIndex].startedAt) ?? playback.duration)
        var corrections = project.takes[takeIndex].markerCorrections ?? []
        var proposed: [AnalysisMarkerKind: Double] = Dictionary(uniqueKeysWithValues: AnalysisMarkerKind.allCases.compactMap { marker in
            let current = corrections.filter { $0.marker == marker }.max(by: { $0.createdAt < $1.createdAt })?.correctedSeconds
                ?? automatedMarker(marker, analysis: project.takes[takeIndex].analysis)
            return current.map { (marker, $0) }
        })
        for (marker, raw) in values { proposed[marker] = max(0, min(duration, raw)) }
        let ordered = AnalysisMarkerKind.allCases.compactMap { proposed[$0] }
        guard zip(ordered, ordered.dropFirst()).allSatisfy({ $0 <= $1 }) else {
            errorMessage = "Transient corrections must remain chronological: onset ≤ sustain start ≤ key-up ≤ sound offset ≤ tail end."
            return
        }
        let changes = values.contains { marker, raw in
            let value = max(0, min(duration, raw))
            return proposed[marker] != nil && abs((corrections.filter { $0.marker == marker }.max(by: { $0.createdAt < $1.createdAt })?.correctedSeconds
                ?? automatedMarker(marker, analysis: project.takes[takeIndex].analysis) ?? -.infinity) - value) > 0.000_5
        }
        guard changes else {
            notice = "No marker values changed."
            return
        }
        let resolvedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard resolvedReason.isEmpty == false else {
            errorMessage = "Give an evidence-based reason before saving marker corrections."
            return
        }
        for marker in AnalysisMarkerKind.allCases {
            guard let raw = values[marker] else { continue }
            let value = max(0, min(duration, raw))
            let current = corrections.filter { $0.marker == marker }.max(by: { $0.createdAt < $1.createdAt })?.correctedSeconds
                ?? automatedMarker(marker, analysis: project.takes[takeIndex].analysis)
            guard current == nil || abs((current ?? 0) - value) > 0.000_5 else { continue }
            corrections.append(MarkerCorrection(
                marker: marker,
                automatedSeconds: automatedMarker(marker, analysis: project.takes[takeIndex].analysis),
                correctedSeconds: value,
                author: author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSFullUserName() : author,
                reason: resolvedReason
            ))
        }
        project.takes[takeIndex].markerCorrections = corrections
        self.project = project
        guard await persistOrReport() else { return }
        notice = "Manual marker corrections saved without replacing automated results."
    }

    func acceptLoopPointSet(
        sourceID: UUID,
        startSeconds: Double,
        endSeconds: Double,
        crossfadeSeconds: Double,
        envelope: SustainPlaybackEnvelope,
        mode: AudioLoopMode,
        exitPolicy: LoopExitPolicy,
        author: String,
        reason: String
    ) async {
        guard var project, let takeID = selectedTakeID,
              let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }),
              let sourceIndex = project.takes[takeIndex].loopPointSets?.firstIndex(where: { $0.id == sourceID }),
              let source = project.takes[takeIndex].loopPointSets?[sourceIndex],
              var region = source.sustainRegion else { return }
        let resolvedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedReason.isEmpty else {
            errorMessage = "Give an evidence-based reason before accepting loop points."
            return
        }
        let rate = source.sampleRate
        region.id = UUID()
        region.startFrameInclusive = Int64((max(0, startSeconds) * rate).rounded())
        region.endFrameExclusive = Int64((max(0, endSeconds) * rate).rounded())
        region.crossfadeFrames = Int64((max(0, crossfadeSeconds) * rate).rounded())
        region.mode = mode
        region.exitPolicy = exitPolicy
        let resolvedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSFullUserName() : author
        let now = Date()
        var accepted = source
        accepted.id = UUID()
        accepted.status = .accepted
        accepted.regions = [region]
        accepted.envelope = envelope
        accepted.wasRevisionOf = source.id
        accepted.reviewedAt = now
        accepted.reviewedBy = resolvedAuthor
        accepted.reviewReason = resolvedReason
        accepted.candidateRank = nil
        let errors = LoopPointSetValidator.errors(for: accepted)
        guard errors.isEmpty else {
            errorMessage = errors.joined(separator: " ")
            return
        }
        var sets = project.takes[takeIndex].loopPointSets ?? []
        for index in sets.indices where sets[index].status == .accepted {
            sets[index].status = .superseded
        }
        sets.append(accepted)
        var reviews = project.takes[takeIndex].loopPointReviews ?? []
        reviews.append(LoopPointReview(
            loopPointSetID: source.id,
            resultingLoopPointSetID: accepted.id,
            decision: "accepted-revision",
            author: resolvedAuthor,
            reason: resolvedReason,
            decidedAt: now
        ))
        project.takes[takeIndex].loopPointSets = sets
        project.takes[takeIndex].acceptedLoopPointSetID = accepted.id
        project.takes[takeIndex].loopPointReviews = reviews
        self.project = project
        playback.configureLoopPointSet(accepted)
        guard await persistOrReport() else { return }
        notice = "Loop point set accepted as a reviewed, exact-frame revision."
    }

    func rejectLoopPointSet(sourceID: UUID, author: String, reason: String) async {
        guard var project, let takeID = selectedTakeID,
              let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }),
              project.takes[takeIndex].loopPointSets?.contains(where: { $0.id == sourceID }) == true else { return }
        let resolvedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resolvedReason.isEmpty else {
            errorMessage = "Give an evidence-based reason before rejecting a loop candidate."
            return
        }
        let resolvedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? NSFullUserName() : author
        var reviews = project.takes[takeIndex].loopPointReviews ?? []
        reviews.append(LoopPointReview(
            loopPointSetID: sourceID,
            decision: "rejected",
            author: resolvedAuthor,
            reason: resolvedReason
        ))
        project.takes[takeIndex].loopPointReviews = reviews
        self.project = project
        guard await persistOrReport() else { return }
        notice = "Loop candidate rejection recorded; automated evidence was retained."
    }

    func addAnnotationAtPlayhead(code: String, text: String) async {
        guard var project, let takeID = selectedTakeID else { return }
        project.annotations.append(TimedAnnotation(
            takeID: takeID,
            atSeconds: playback.currentTime,
            code: code,
            severity: "info",
            text: text
        ))
        self.project = project
        guard await persistOrReport() else { return }
    }

    func markLiveEvent(code: String, text: String) async {
        guard var project, let takeID = activeTakeID else { return }
        project.annotations.append(TimedAnnotation(
            takeID: takeID,
            atSeconds: capture.elapsed,
            code: code,
            severity: "info",
            text: text
        ))
        self.project = project
        guard await persistOrReport() else { return }
        notice = "\(text) marked at \(capture.elapsed.formatted(.number.precision(.fractionLength(3)))) s."
    }

    func markInstrumentNoiseEvent(
        _ marker: InstrumentNoiseEventMarker,
        observedValue: Double? = nil
    ) async {
        guard var project,
              let takeID = activeTakeID,
              let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }),
              let roadmap = project.roadmap.first(where: { $0.id == project.takes[takeIndex].roadmapItemID }),
              let protocolSnapshot = roadmap.instrumentNoiseProtocol else { return }
        let elapsed = capture.elapsed
        let label: String = switch marker {
        case .actionBegin: "Instrument action began"
        case .actionEnd: "Instrument action ended"
        case .actuationSample: "Actuation sample observed"
        case .notableVariation: "Notable instrument-noise variation"
        }
        let quantityText = observedValue.flatMap { value in
            protocolSnapshot.actuationProfile.map {
                " · \(value.formatted(.number.precision(.fractionLength(0...4)))) \($0.unit)"
            }
        } ?? ""
        project.annotations.append(TimedAnnotation(
            takeID: takeID,
            atSeconds: elapsed,
            code: "instrument_noise_\(marker.rawValue)",
            severity: marker == .notableVariation ? "warning" : "info",
            text: "\(label): \(protocolSnapshot.name) · \(protocolSnapshot.variantLabel)\(quantityText)",
            instrumentNoiseEvent: InstrumentNoiseEventAnnotation(
                protocolSnapshot: protocolSnapshot,
                marker: marker,
                observedActuationValue: observedValue,
                actuationUnit: observedValue == nil ? nil : protocolSnapshot.actuationProfile?.unit
            )
        ))
        if project.takes[takeIndex].instrumentNoiseParadata == nil {
            project.takes[takeIndex].instrumentNoiseParadata = InstrumentNoiseTakeParadata(
                protocolSnapshot: protocolSnapshot,
                repetitionNumber: project.takes[takeIndex].takeNumber
            )
        }
        var paradata = project.takes[takeIndex].instrumentNoiseParadata!
        let plannedCurve = protocolSnapshot.actuationProfile?.commandedCurve
        switch marker {
        case .actionBegin:
            paradata.actionBeginSeconds = elapsed
            paradata.actionEndSeconds = nil
            paradata.actualDurationSeconds = nil
            if let initialValue = observedValue ?? plannedCurve?.points.first?.value {
                paradata.observedActuationCurve = ActuationCurve(
                    kind: .custom,
                    timeBasis: .seconds,
                    interpolation: .linear,
                    points: [ActuationCurvePoint(time: 0, value: initialValue)],
                    evidenceSource: .operatorObserved,
                    deviceLabel: "OrgRec operator-timed observation",
                    notes: "Values were entered by the operator during capture; they are not sensor measurements."
                )
            }
        case .actionEnd:
            paradata.actionEndSeconds = elapsed
            if let begin = paradata.actionBeginSeconds {
                let duration = max(0, elapsed - begin)
                paradata.actualDurationSeconds = duration
                if let finalValue = observedValue ?? plannedCurve?.points.last?.value {
                    paradata.observedActuationCurve = appendingActuationPoint(
                        to: paradata.observedActuationCurve,
                        relativeTime: duration,
                        value: finalValue,
                        durationSeconds: duration
                    )
                }
            }
        case .actuationSample:
            let begin = paradata.actionBeginSeconds ?? elapsed
            if paradata.actionBeginSeconds == nil { paradata.actionBeginSeconds = begin }
            if let sampleValue = observedValue {
                paradata.observedActuationCurve = appendingActuationPoint(
                    to: paradata.observedActuationCurve,
                    relativeTime: max(0, elapsed - begin),
                    value: sampleValue,
                    durationSeconds: nil
                )
            }
        case .notableVariation:
            break
        }
        project.takes[takeIndex].instrumentNoiseParadata = paradata
        self.project = project
        guard await persistOrReport() else { return }
        notice = "\(label) marked at \(elapsed.formatted(.number.precision(.fractionLength(3)))) s with structured classification."
    }

    func markComplexCaptureEvent(
        _ kind: ComplexCaptureEventKind,
        stageID: String? = nil,
        shutterStateID: String? = nil,
        observedValue: Double? = nil,
        unit: String? = nil,
        notes: String = ""
    ) async {
        guard var project,
              let takeID = activeTakeID,
              let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }),
              let item = project.roadmap.first(where: { $0.id == project.takes[takeIndex].roadmapItemID }),
              let protocolSnapshot = item.complexCaptureProtocol else { return }
        let event = ComplexCaptureEvent(
            atSeconds: capture.elapsed,
            kind: kind,
            stageID: stageID,
            shutterStateID: shutterStateID,
            observedValue: observedValue,
            unit: unit,
            notes: notes
        )
        if project.takes[takeIndex].complexCaptureParadata == nil {
            project.takes[takeIndex].complexCaptureParadata = ComplexCaptureTakeParadata(
                protocolSnapshot: protocolSnapshot,
                repetitionNumber: project.takes[takeIndex].takeNumber
            )
        }
        project.takes[takeIndex].complexCaptureParadata?.events.append(event)
        let annotation = ComplexCaptureEventAnnotation(
            protocolID: protocolSnapshot.id,
            protocolKind: protocolSnapshot.kind,
            event: event
        )
        project.annotations.append(TimedAnnotation(
            takeID: takeID,
            atSeconds: event.atSeconds,
            code: "complex_capture_\(kind.rawValue)",
            severity: [.notableVariation, .processCancelled].contains(kind) ? "warning" : "info",
            text: [protocolSnapshot.name, kind.rawValue, stageID, shutterStateID, notes].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
            complexCaptureEvent: annotation
        ))
        self.project = project
        guard await persistOrReport() else { return }
        notice = "\(kind.rawValue) marked at \(event.atSeconds.formatted(.number.precision(.fractionLength(3)))) s."
    }

    func markSpatialAcousticEvent(_ kind: SpatialAcousticEventKind, notes: String = "") async {
        guard var project, let takeID = activeTakeID,
              let takeIndex = project.takes.firstIndex(where: { $0.id == takeID }),
              let item = project.roadmap.first(where: { $0.id == project.takes[takeIndex].roadmapItemID }),
              let protocolSnapshot = item.spatialAcousticProtocol else { return }
        let event = SpatialAcousticEvent(atSeconds: capture.elapsed, kind: kind, notes: notes)
        if project.takes[takeIndex].spatialAcousticParadata == nil {
            project.takes[takeIndex].spatialAcousticParadata = SpatialAcousticTakeParadata(
                protocolSnapshot: protocolSnapshot, repetitionNumber: project.takes[takeIndex].takeNumber
            )
        }
        project.takes[takeIndex].spatialAcousticParadata?.events.append(event)
        project.annotations.append(TimedAnnotation(
            takeID: takeID, atSeconds: event.atSeconds, code: "spatial_acoustic_\(kind.rawValue)",
            severity: kind == .notableVariation ? "warning" : "info",
            text: [protocolSnapshot.name, kind.displayName, notes].filter { !$0.isEmpty }.joined(separator: " · "),
            spatialAcousticEvent: SpatialAcousticEventAnnotation(protocolID: protocolSnapshot.id, event: event)
        ))
        self.project = project
        guard await persistOrReport() else { return }
        notice = "\(kind.displayName) marked at \(event.atSeconds.formatted(.number.precision(.fractionLength(3)))) s."
    }

    private func appendingActuationPoint(
        to existing: ActuationCurve?,
        relativeTime: Double,
        value: Double,
        durationSeconds: Double?
    ) -> ActuationCurve {
        var curve = existing ?? ActuationCurve(
            kind: .custom,
            timeBasis: .seconds,
            interpolation: .linear,
            points: [],
            evidenceSource: .operatorObserved,
            deviceLabel: "OrgRec operator-timed observation",
            notes: "Values were entered by the operator during capture; they are not sensor measurements."
        )
        let time = max(0, relativeTime)
        if let last = curve.points.last, time <= last.time {
            curve.points[curve.points.count - 1] = ActuationCurvePoint(time: last.time, value: value)
        } else {
            curve.points.append(ActuationCurvePoint(time: time, value: value))
        }
        if let durationSeconds { curve.durationSeconds = durationSeconds }
        return curve
    }

    func markNoiseIncident(category: NoiseSourceCategory, label: String) async {
        guard var project,
              let takeID = activeTakeID,
              let sessionIndex = project.recordingSessions?.lastIndex(where: { $0.endedAt == nil }) else { return }
        let elapsed = capture.elapsed
        let code = "environment_noise_\(category.rawValue)"
        project.annotations.append(TimedAnnotation(
            takeID: takeID,
            atSeconds: elapsed,
            code: code,
            severity: "warning",
            text: label
        ))
        var observations = project.recordingSessions?[sessionIndex].noiseObservations ?? []
        observations.append(NoiseObservation(
            category: category,
            label: label,
            takeID: takeID,
            atSeconds: elapsed,
            recordedBy: activeSession?.operatorName ?? "operator"
        ))
        project.recordingSessions?[sessionIndex].noiseObservations = observations
        self.project = project
        guard await persistOrReport() else { return }
        notice = "\(label) recorded in session paradata and marked on the take at \(elapsed.formatted(.number.precision(.fractionLength(3)))) s."
    }

    func searchNavigator() async {
        if let databaseURL = podDatabaseCacheURL {
            isWorking = true
            defer { isWorking = false }
            do {
                navigatorResults = try PODDatabaseReader.search(databaseURL: databaseURL, query: navigatorQuery)
                    .map(\.navigatorSummary)
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }
        guard let baseURL = validatedNavigatorBaseURL() else {
            errorMessage = "Import the local POD 1.5 database or enter a complete HTTP or HTTPS Navigator base URL."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            navigatorResults = try await navigator.search(baseURL: baseURL, query: navigatorQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importNavigatorOrgan(_ organ: NavigatorOrganSummary) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let profile: NavigatorRoadmapProfile
            if let databaseURL = podDatabaseCacheURL {
                profile = try PODDatabaseReader.roadmapProfile(
                    databaseURL: databaseURL,
                    organID: organ.mdvsID,
                    databaseSHA256: podDatabaseInspection?.sha256
                )
            } else {
                guard let baseURL = validatedNavigatorBaseURL() else {
                    throw NSError(
                        domain: "OrgRec.Navigator",
                        code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "Import the local POD 1.5 database or enter a complete Navigator base URL."]
                    )
                }
                guard let fetched = try await navigator.fetchRoadmap(baseURL: baseURL, organID: organ.mdvsID) else {
                    notice = "Navigator snapshot is unchanged."
                    return
                }
                profile = fetched
            }
            guard let project else { return }
            let compilation = RoadmapEngine.compileSpecification(
                components: profile.components,
                recipe: project.recipe,
                setupIDs: project.setups.map(\.id),
                relationships: profile.componentRelationships,
                physicalPipeMappings: profile.physicalPipeMappings
            )
            guard compilation.roadmap.isEmpty == false else {
                throw NSError(
                    domain: "OrgRec.Navigator",
                    code: 20,
                    userInfo: [NSLocalizedDescriptionKey: "Navigator returned the organ, but its specification contained no recordable stops or pipe positions. OrgRec did not replace the existing roadmap."]
                )
            }
            let attachInPlace = canAttachNavigatorOrganToActiveProject
            var imported = OrgRecProject(
                id: attachInPlace ? project.id : UUID(),
                title: attachInPlace ? project.title : "\(organ.title) · OrgRec field project",
                organMDVSID: organ.mdvsID,
                organName: organ.title,
                venueName: project.venueName.isEmpty ? (organ.location ?? "") : project.venueName,
                createdAt: attachInPlace ? project.createdAt : Date(),
                snapshot: profile.snapshot,
                recipe: project.recipe,
                devices: project.devices,
                setups: project.setups,
                registrations: compilation.registrations,
                roadmap: compilation.roadmap,
                spectrogramConfiguration: project.spectrogramConfiguration,
                organComponents: profile.components,
                roadmapCompilation: compilation.report,
                navigatorPayloadRelativePath: "Manifests/modavis-navigator-payload.json",
                organCharacteristics: profile.characteristics,
                recordingSessions: attachInPlace ? project.recordingSessions : nil,
                documentedPitchStandard: profile.documentedPitchStandard,
                tuningCalibrations: attachInPlace ? project.tuningCalibrations : nil,
                componentRelationships: profile.componentRelationships,
                physicalPipeMappings: profile.physicalPipeMappings,
                physicalSoundTargets: compilation.physicalSoundTargets,
                physicalOverlapCandidates: compilation.overlapCandidates,
                controlBindings: attachInPlace ? project.controlBindings : nil,
                captureStates: compilation.captureStates
            )
            ensureActiveSession(in: &imported)
            let destination: URL
            if attachInPlace, let projectURL {
                destination = projectURL
                try await store.save(imported, at: destination)
            } else {
                destination = uniqueManagedProjectURL(stem: organ.title.isEmpty ? organ.mdvsID : organ.title)
                try await store.createPackage(at: destination, project: imported)
            }
            try await store.storeNavigatorPayload(
                profile.rawPayload,
                expectedSHA256: profile.snapshot.payloadSHA256,
                relativePath: imported.navigatorPayloadRelativePath!,
                at: destination
            )
            self.project = imported
            projectURL = destination
            UserDefaults.standard.set(destination.path, forKey: lastProjectKey)
            selectedRoadmapID = imported.roadmap.first?.id
            selectedTakeID = nil
            waveform = nil
            spectrogram = nil
            playback.stop()
            page = .initialize
            await refreshProjectLibrary()
            let action = attachInPlace ? "Attached the MODAVIS specification and compiled" : "Created the organ project and compiled"
            let pitchNotice = profile.documentedPitchStandard.map {
                " MODAVIS \($0.modavisRelease) A4 = \($0.frequencyHz.formatted(.number.precision(.fractionLength(2)))) Hz was inserted automatically as documented evidence."
            } ?? " No documented A4 was found; field calibration is still required."
            notice = "\(action) \(compilation.report.logicalSoundAddressCount ?? compilation.report.generatedAtomicSoundCount) logical addresses into \(compilation.report.physicalSoundTargetCount ?? compilation.report.generatedAtomicSoundCount) physical sound targets and \(compilation.roadmap.count) roadmap captures.\(pitchNotice)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func projectsDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("OrgRec/Projects", isDirectory: true)
    }

    private func validatedNavigatorBaseURL() -> URL? {
        guard let components = URLComponents(string: navigatorURL),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false else { return nil }
        return components.url
    }

    private func vaoWorkspacesDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("OrgRec/VAOWorkspaces", isDirectory: true)
    }

    private func podDatabasesDirectory() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("OrgRec/Datasets/POD", isDirectory: true)
    }

    private func uniqueManagedPODDatabaseURL() -> URL {
        let parent = (try? podDatabasesDirectory()) ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let stem = "modavis-pod-1.5-orgrec"
        var candidate = parent.appendingPathComponent("\(stem).sqlite")
        var revision = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(stem)-\(revision).sqlite")
            revision += 1
        }
        return candidate
    }

    private func uniqueManagedVAOWorkspaceURL(stem unsafe: String) -> URL {
        let parent = (try? vaoWorkspacesDirectory()) ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "- "))
        let slug = unsafe.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let base = String(slug).split(separator: "-").filter { !$0.isEmpty }.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var candidate = parent.appendingPathComponent("\(base.isEmpty ? "VAO" : base).vao-workspace", isDirectory: true)
        var revision = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(base.isEmpty ? "VAO" : base)-\(revision).vao-workspace", isDirectory: true)
            revision += 1
        }
        return candidate
    }

    private func uniqueManagedProjectURL(stem unsafe: String) -> URL {
        let parent = (try? projectsDirectory()) ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "- "))
        let slug = unsafe.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let base = String(slug).split(separator: "-").filter { $0.isEmpty == false }.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var candidate = parent.appendingPathComponent("\(base.isEmpty ? "Organ" : base).orgrec", isDirectory: true)
        var revision = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = parent.appendingPathComponent("\(base.isEmpty ? "Organ" : base)-\(revision).orgrec", isDirectory: true)
            revision += 1
        }
        return candidate
    }

    private func projectSummary(_ project: OrgRecProject, url: URL) -> RecordingProjectSummary {
        let consistency = ProjectConsistencyAuditor.audit(project: project)
        return RecordingProjectSummary(
            url: url,
            projectID: project.id,
            title: project.title,
            organMDVSID: project.organMDVSID,
            organName: project.organName,
            venueName: project.venueName,
            updatedAt: project.updatedAt,
            roadmapItems: project.roadmap.count,
            takes: project.takes.count,
            coverage: RoadmapEngine.coverage(project.roadmap),
            consistencyScore: consistency.score,
            consistencyBlockers: consistency.blockerCount,
            isActive: url.standardizedFileURL == projectURL?.standardizedFileURL
        )
    }

    func addCustomRegistration(
        name: String,
        componentIDs: Set<String>,
        midiLow: Int,
        midiHigh: Int,
        step: Int
    ) async {
        guard var project, midiLow <= midiHigh else {
            errorMessage = "Enter a valid MIDI note range."
            return
        }
        let components = project.organComponents ?? []
        let selected = components.filter { componentIDs.contains($0.id) }
        let stops = selected.filter { $0.kind == "stop" }
        let couplers = selected.filter { $0.kind == "coupler" }
        let accessories = selected.filter { $0.kind == "accessory" }
        guard stops.isEmpty == false else {
            errorMessage = "A custom sounding registration requires at least one speaking stop."
            return
        }
        let planned = RoadmapEngine.customRegistration(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom registration" : name,
            stops: stops,
            couplers: couplers,
            accessories: accessories,
            midiRange: max(0, midiLow)...min(127, midiHigh),
            step: max(1, step),
            recipe: project.recipe,
            setupIDs: project.setups.map(\.id)
        )
        guard planned.1.isEmpty == false else {
            errorMessage = "The registration did not produce any roadmap items."
            return
        }
        project.registrations.append(planned.0)
        project.roadmap.append(contentsOf: planned.1)
        self.project = project
        selectedRoadmapID = planned.1.first?.id
        do {
            try await persist()
            notice = "Added \(planned.1.count) captures for \(planned.0.name ?? "custom registration")."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addInstrumentNoisePlan(
        componentID: String?,
        customComponentLabel: String,
        kind: InstrumentNoiseKind,
        actions: Set<InstrumentNoiseAction>,
        velocityPresets: Set<InstrumentNoiseVelocityPreset>,
        configurations: [InstrumentNoiseConfiguration],
        minimumAcceptedTakeCount: Int,
        captureDurationSeconds: Double,
        technique: CaptureTechnique,
        required: Bool,
        sourceScope: AcousticSourceScope,
        mechanisms: Set<AcousticMechanism>,
        role: AcousticEventRole,
        actuationProfile: ActuationProfile
    ) async {
        guard var project else { return }
        let components = project.organComponents ?? []
        let sourceComponent: OrganComponent
        if let componentID, let existing = components.first(where: { $0.id == componentID }) {
            sourceComponent = existing
        } else {
            let label = customComponentLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard label.isEmpty == false else {
                errorMessage = "Name the organ mechanism or choose a source component."
                return
            }
            let localID = "orgrec:instrument-mechanism:\(Data("\(project.organMDVSID)|\(label.lowercased())".utf8).sha256Hex)"
            sourceComponent = OrganComponent(
                id: localID,
                kind: "instrument_auxiliary",
                label: label,
                division: "Organ-wide",
                locator: ComponentLocator(
                    id: localID,
                    organMDVSID: project.organMDVSID,
                    sourceRecordID: "operator-defined-instrument-mechanism",
                    sourcePath: "orgrec.instrumentNoiseProtocols",
                    snapshotSHA256: project.snapshot.payloadSHA256,
                    kind: "instrument_auxiliary",
                    label: label,
                    trust: .sourceBound
                ),
                sourceDetails: ["orgrec:operatorDefined": "true"]
            )
        }
        let orderedActions = InstrumentNoiseAction.allCases.filter { actions.contains($0) }
        let orderedVelocities = InstrumentNoiseVelocityPreset.allCases.filter { velocityPresets.contains($0) }
        let items = RoadmapEngine.instrumentNoiseItems(
            component: sourceComponent,
            kind: kind,
            actions: orderedActions,
            velocityPresets: orderedVelocities,
            configurations: configurations,
            minimumAcceptedTakeCount: minimumAcceptedTakeCount,
            captureDurationSeconds: captureDurationSeconds,
            recipeID: project.recipe.id,
            techniques: [technique],
            setupIDs: project.setups.map(\.id),
            required: required,
            sourceScope: sourceScope,
            mechanisms: AcousticMechanism.allCases.filter { mechanisms.contains($0) },
            role: role,
            actuationProfile: actuationProfile
        )
        guard items.isEmpty == false else {
            errorMessage = "Select at least one action and recording technique."
            return
        }
        let existingIdentities = Set(project.roadmap.map(roadmapIdentity))
        let additions = items.filter { existingIdentities.contains(roadmapIdentity($0)) == false }
        guard additions.isEmpty == false else {
            errorMessage = "These instrument-noise protocol variants are already in the Roadmap."
            return
        }
        project.roadmap.append(contentsOf: additions)
        if components.contains(where: { $0.id == sourceComponent.id }) == false {
            project.organComponents = components + [sourceComponent]
        }
        project.roadmapCompilation?.generatedInstrumentNoiseCount = project.roadmap.filter { $0.instrumentNoiseProtocol != nil }.count
        self.project = project
        selectedRoadmapID = additions.first?.id
        do {
            try await persist()
            await runConsistencyAudit()
            notice = "Added \(additions.count) instrument-noise capture variants; each retains \(minimumAcceptedTakeCount) accepted repetition target\(minimumAcceptedTakeCount == 1 ? "" : "s")."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addComplexCapturePlan(_ request: ComplexCapturePlanRequest) async {
        guard var project else { return }
        guard request.techniques.isEmpty == false else { errorMessage = "Select at least one microphone technique."; return }
        let components = project.organComponents ?? []
        let source: OrganComponent
        if let id = request.sourceComponentID, let existing = components.first(where: { $0.id == id }) {
            source = existing
        } else {
            let label = request.customComponentLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard label.isEmpty == false else { errorMessage = "Choose or name the source component."; return }
            let localID = "orgrec:complex-capture:\(Data("\(project.organMDVSID)|\(request.kind.rawValue)|\(label.lowercased())".utf8).sha256Hex)"
            source = OrganComponent(
                id: localID, kind: request.kind.rawValue, label: label, division: "Organ-wide",
                locator: ComponentLocator(
                    id: localID, organMDVSID: project.organMDVSID,
                    sourceRecordID: "operator-defined-complex-capture", sourcePath: "orgrec.complexCaptureProtocols",
                    snapshotSHA256: project.snapshot.payloadSHA256, kind: request.kind.rawValue,
                    label: label, trust: .sourceBound
                ),
                sourceDetails: ["orgrec:operatorDefined": "true", "orgrec:complexCaptureKind": request.kind.rawValue]
            )
        }
        var registrations: [RegistrationState] = []
        var generated: [RoadmapItem] = []
        switch request.kind {
        case .physicalActuatorResponse, .declarativeProcess:
            guard let definition = request.soundingTargetDefinition else { errorMessage = "Choose the intended sounding-target family and behavior."; return }
            let protocols: [ComplexCaptureProtocol]
            if request.kind == .physicalActuatorResponse {
                guard request.physicalActuationVariants.isEmpty == false else { errorMessage = "Add at least one physical actuation variant."; return }
                protocols = request.physicalActuationVariants.map { variant in
                    ComplexCaptureProtocol(
                        kind: .physicalActuatorResponse, name: "\(source.label) · \(variant.label)", sourceComponentID: source.id,
                        minimumAcceptedTakeCount: request.minimumAcceptedTakeCount, physicalActuation: variant,
                        instructions: "Use the independently documented physical inputs: \(variant.summary). Do not infer physical intensity from MIDI velocity. Mark the action, retain the entire acoustic response, and repeat for measured transfer-function evidence."
                    )
                }
            } else {
                guard let process = request.processModel else { errorMessage = "Define the process stages and termination conditions."; return }
                guard process.validationIssues.isEmpty else { errorMessage = process.validationIssues.joined(separator: " "); return }
                protocols = [ComplexCaptureProtocol(
                    kind: .declarativeProcess, name: process.name, sourceComponentID: source.id,
                    minimumAcceptedTakeCount: request.minimumAcceptedTakeCount, processModel: process,
                    instructions: "Perform the checksum-stable declarative process \(process.name), mark each stage, preserve ordering and timing, and use only its documented termination or cancellation path."
                )]
            }
            let invalid = protocols.flatMap(\.validationIssues)
            guard invalid.isEmpty else { errorMessage = invalid.joined(separator: " "); return }
            let registration = RegistrationState(
                activatedAccessories: definition.triggerMode == .keyboardKey || definition.triggerMode == .manual ? [] : [source.locator],
                notes: "P1 complex-capture registration; intended sound and actuator behavior remain distinct.",
                name: source.label, purpose: request.kind.displayName
            )
            registrations = [registration]
            var recipe = project.recipe; recipe.techniques = request.techniques
            generated = RoadmapEngine.complexSoundingTargetItems(
                component: source, definition: definition, protocols: protocols, recipe: recipe,
                setupIDs: project.setups.map(\.id), registrationID: registration.id, required: request.required
            )
        case .discreteShutterMapping:
            guard let topology = request.shutterTopology else { errorMessage = "Define the discrete shutters and pedal mapping."; return }
            guard topology.validationIssues.isEmpty else { errorMessage = topology.validationIssues.joined(separator: " "); return }
            generated = RoadmapEngine.shutterMappingItems(
                component: source, topology: topology, minimumAcceptedTakeCount: request.minimumAcceptedTakeCount,
                recipe: project.recipe, techniques: request.techniques, setupIDs: project.setups.map(\.id), required: request.required
            )
        case .tremulantResponse:
            let affected = components.filter { request.tremulantAffectedComponentIDs.contains($0.id) }
            guard affected.isEmpty == false else { errorMessage = "Select at least one affected speaking stop or rank."; return }
            let plan = RoadmapEngine.tremulantResponsePlan(
                tremulant: source, affectedStops: affected, scope: request.tremulantCoverageScope,
                minimumAcceptedTakeCount: request.minimumAcceptedTakeCount, recipe: project.recipe,
                techniques: request.techniques, setupIDs: project.setups.map(\.id), required: request.required
            )
            registrations = plan.registrations; generated = plan.items
        case .operationalBaseline:
            guard let baseline = request.operationalBaseline else { errorMessage = "Define the operational baseline state and duration."; return }
            guard baseline.validationIssues.isEmpty else { errorMessage = baseline.validationIssues.joined(separator: " "); return }
            generated = RoadmapEngine.operationalBaselineItems(
                component: source, baseline: baseline, recipe: project.recipe,
                techniques: request.techniques, setupIDs: project.setups.map(\.id), required: request.required
            )
        }
        guard generated.isEmpty == false else { errorMessage = "The P1 plan did not produce Roadmap obligations."; return }
        let existing = Set(project.roadmap.map(roadmapIdentity))
        let additions = generated.filter { !existing.contains(roadmapIdentity($0)) }
        guard additions.isEmpty == false else { errorMessage = "Equivalent P1 capture obligations are already in the Roadmap."; return }
        if components.contains(where: { $0.id == source.id }) == false { project.organComponents = components + [source] }
        project.registrations.append(contentsOf: registrations)
        project.roadmap.append(contentsOf: additions)
        self.project = project; selectedRoadmapID = additions.first?.id
        do {
            try await persist(); await runConsistencyAudit()
            notice = "Added \(additions.count) \(request.kind.displayName.lowercased()) Roadmap obligation\(additions.count == 1 ? "" : "s") with typed P1 provenance."
        } catch { errorMessage = error.localizedDescription }
    }

    func addSpatialAcousticPlan(_ request: SpatialAcousticPlanRequest) async {
        guard var project else { return }
        let geometryIssues = request.geometry.validationIssues
        guard geometryIssues.isEmpty else { errorMessage = geometryIssues.joined(separator: " "); return }
        guard request.techniques.isEmpty == false else { errorMessage = "Select at least one microphone technique."; return }
        guard request.states.count >= 2 else { errorMessage = "A response series needs a reference and at least one comparison state."; return }
        guard Set(request.states.map(\.id)).count == request.states.count,
              request.states.contains(where: { $0.id == request.referenceStateID }) else {
            errorMessage = "Response-state identifiers must be unique and one state must be the reference."; return
        }
        guard request.geometry.elements.contains(where: { $0.id == request.sourceElementID && [.rank, .effect].contains($0.kind) }) else {
            errorMessage = "Choose a rank or effect geometry element as the acoustic source."; return
        }
        let validElementIDs = Set(request.geometry.elements.map(\.id))
        guard request.pathElementIDs.allSatisfy(validElementIDs.contains) else { errorMessage = "A propagation-path element is missing from the geometry snapshot."; return }
        guard request.geometry.referenceFrame.compatibleMicrophoneSetupIDs.isEmpty == false else {
            errorMessage = "Link at least one microphone setup to the geometry coordinate frame."; return
        }
        let components = project.organComponents ?? []
        let source: OrganComponent
        if let id = request.sourceComponentID, let existing = components.first(where: { $0.id == id }) {
            source = existing
        } else {
            let label = request.customSourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard label.isEmpty == false else { errorMessage = "Choose or name the acoustic source."; return }
            let id = "orgrec:spatial-source:\(Data("\(project.organMDVSID)|\(label.lowercased())".utf8).sha256Hex)"
            source = OrganComponent(
                id: id, kind: "spatial_acoustic_source", label: label, division: "Spatial acoustic responses",
                locator: ComponentLocator(
                    id: id, organMDVSID: project.organMDVSID, sourceRecordID: "operator-defined-spatial-source",
                    sourcePath: "orgrec.spatialGeometrySnapshots", snapshotSHA256: project.snapshot.payloadSHA256,
                    kind: "spatial_acoustic_source", label: label, trust: .sourceBound
                ),
                sourceDetails: ["orgrec:operatorDefined": "true", "orgrec:p2SpatialSource": "true"]
            )
        }
        let compiled = RoadmapEngine.spatialAcousticResponseItems(request: request, component: source, recipe: project.recipe)
        guard compiled.items.isEmpty == false else { errorMessage = "The P2 plan produced no Roadmap obligations."; return }
        let existing = Set(project.roadmap.map(roadmapIdentity))
        let additions = compiled.items.filter { !existing.contains(roadmapIdentity($0)) }
        guard additions.isEmpty == false else { errorMessage = "Equivalent P2 response obligations are already in the Roadmap."; return }
        var geometries = project.spatialGeometrySnapshots ?? []
        if let index = geometries.firstIndex(where: { $0.id == request.geometry.id }) { geometries[index] = request.geometry }
        else { geometries.append(request.geometry) }
        project.spatialGeometrySnapshots = geometries
        project.activeSpatialGeometrySnapshotID = request.geometry.id
        project.captureStates = (project.captureStates ?? []) + compiled.states
        if !components.contains(where: { $0.id == source.id }) { project.organComponents = components + [source] }
        project.roadmap.append(contentsOf: additions)
        refreshCaptureStateLibrary(in: &project)
        self.project = project; selectedRoadmapID = additions.first?.id
        do {
            try await persist(); await runConsistencyAudit()
            notice = "Added \(additions.count) P2 in-situ response obligations across \(request.states.count) states. Geometry and exact capture state will be frozen into every take."
        } catch { errorMessage = error.localizedDescription }
    }

    func addExhaustiveRegistrationSubsets(
        name: String,
        componentIDs: Set<String>,
        midiLow: Int,
        midiHigh: Int,
        step: Int
    ) async {
        guard var project, midiLow <= midiHigh else {
            errorMessage = "Enter a valid MIDI note range."
            return
        }
        let selected = (project.organComponents ?? []).filter { componentIDs.contains($0.id) }
        let stops = selected.filter { $0.kind == "stop" }
        let couplers = selected.filter { $0.kind == "coupler" }
        let accessories = selected.filter { $0.kind == "accessory" }
        guard let plans = RoadmapEngine.exhaustiveRegistrationSubsets(
            namePrefix: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Combination" : name,
            stops: stops,
            couplers: couplers,
            accessories: accessories,
            midiRange: max(0, midiLow)...min(127, midiHigh),
            step: max(1, step),
            recipe: project.recipe,
            setupIDs: project.setups.map(\.id)
        ) else {
            errorMessage = "Exhaustive generation requires at least one stop and at most 10 selected switches. Any larger individual registration can still be added normally."
            return
        }
        let items = plans.flatMap(\.1)
        guard items.count <= 50_000 else {
            errorMessage = "This subset would create \(items.count) captures. Narrow the note range, increase the step, or select fewer switches; the safety limit is 50,000."
            return
        }
        project.registrations.append(contentsOf: plans.map(\.0))
        project.roadmap.append(contentsOf: items)
        self.project = project
        selectedRoadmapID = items.first?.id
        do {
            try await persist()
            notice = "Added every one of \(plans.count) sound-producing switch combinations (\(items.count) captures)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportCapturePackage(to destination: URL) async {
        guard let project, let projectURL else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await CapturePackageBuilder().build(project: project, packageURL: projectURL, destinationURL: destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            notice = "IAD package exported with MODAVIS indexes, checksums, and the frozen snapshot."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportVAO(to destination: URL) async {
        guard let project, let projectURL else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await vao05Builder.build(project: project, packageURL: projectURL, destinationURL: destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            notice = "VAO \(VAO05Contract.formatVersion) exported as a complete, verified preservation closure."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func activeCaptureJournalURL(in packageURL: URL) -> URL {
        packageURL.appendingPathComponent(activeCaptureJournalFilename, isDirectory: false)
    }

    private func longTakeCaptureJournalURL(in packageURL: URL) -> URL {
        packageURL.appendingPathComponent(longTakeCaptureJournalFilename, isDirectory: false)
    }

    private func calibrationCaptureJournalURL(in packageURL: URL) -> URL {
        packageURL.appendingPathComponent(calibrationCaptureJournalFilename, isDirectory: false)
    }

    private func capturePreflightJournalURL(in packageURL: URL) -> URL {
        packageURL.appendingPathComponent(capturePreflightJournalFilename, isDirectory: false)
    }

    private func readableAudioHasFrames(_ url: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: url) else { return false }
        return file.length > 0
            && file.fileFormat.sampleRate > 0
            && file.fileFormat.channelCount > 0
    }

    private func writeActiveCaptureJournal(
        take: TakeRecord,
        priorRoadmapState: RoadmapState,
        packageURL: URL
    ) throws {
        let journal = ActiveCaptureJournal(take: take, priorRoadmapState: priorRoadmapState, createdAt: .now)
        try OrgRecCoding.encoder.encode(journal)
            .write(to: activeCaptureJournalURL(in: packageURL), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func clearActiveCaptureJournal(in packageURL: URL) {
        try? FileManager.default.removeItem(at: activeCaptureJournalURL(in: packageURL))
    }

    @discardableResult
    private func clearReconciledActiveCaptureJournal(in packageURL: URL) -> UUID? {
        let journalURL = activeCaptureJournalURL(in: packageURL)
        guard let data = try? Data(contentsOf: journalURL),
              let journal = try? OrgRecCoding.decoder.decode(ActiveCaptureJournal.self, from: data),
              let take = project?.takes.first(where: { $0.id == journal.take.id }),
              take.endedAt != nil else { return nil }
        let analysisCandidate = take.status == .analyzing ? take.id : nil
        clearActiveCaptureJournal(in: packageURL)
        return analysisCandidate
    }

    private func writeLongTakeCaptureJournal(
        _ journal: LongTakeCaptureJournal,
        packageURL: URL
    ) throws {
        try OrgRecCoding.encoder.encode(journal)
            .write(to: longTakeCaptureJournalURL(in: packageURL), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func readLongTakeCaptureJournal(in packageURL: URL) -> LongTakeCaptureJournal? {
        guard let data = try? Data(contentsOf: longTakeCaptureJournalURL(in: packageURL)) else { return nil }
        return try? OrgRecCoding.decoder.decode(LongTakeCaptureJournal.self, from: data)
    }

    private func clearLongTakeCaptureJournal(in packageURL: URL) {
        try? FileManager.default.removeItem(at: longTakeCaptureJournalURL(in: packageURL))
    }

    private func writeCalibrationCaptureJournal(
        calibration: TuningCalibration,
        packageURL: URL
    ) throws {
        let journal = CalibrationCaptureJournal(calibration: calibration, createdAt: .now)
        try OrgRecCoding.encoder.encode(journal)
            .write(to: calibrationCaptureJournalURL(in: packageURL), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func clearCalibrationCaptureJournal(in packageURL: URL) {
        try? FileManager.default.removeItem(at: calibrationCaptureJournalURL(in: packageURL))
    }

    private func writeCapturePreflightJournal(
        _ pending: PendingCapturePreflight,
        packageURL: URL
    ) throws {
        try OrgRecCoding.encoder.encode(pending)
            .write(to: capturePreflightJournalURL(in: packageURL), options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func clearCapturePreflightJournal(in packageURL: URL) {
        try? FileManager.default.removeItem(at: capturePreflightJournalURL(in: packageURL))
    }

    private func clearReconciledCapturePreflightJournal(in packageURL: URL) {
        let journalURL = capturePreflightJournalURL(in: packageURL)
        guard let data = try? Data(contentsOf: journalURL),
              let pending = try? OrgRecCoding.decoder.decode(PendingCapturePreflight.self, from: data),
              project?.recordingSessions?.contains(where: { session in
                  session.capturePreflightReports?.contains(where: { $0.id == pending.id }) == true
              }) == true else { return }
        clearCapturePreflightJournal(in: packageURL)
    }

    private func recoverCapturePreflightJournal(
        in project: inout OrgRecProject,
        packageURL: URL
    ) -> Bool {
        let journalURL = capturePreflightJournalURL(in: packageURL)
        guard let data = try? Data(contentsOf: journalURL),
              let pending = try? OrgRecCoding.decoder.decode(PendingCapturePreflight.self, from: data) else {
            return false
        }
        if project.recordingSessions?.contains(where: { session in
            session.capturePreflightReports?.contains(where: { $0.id == pending.id }) == true
        }) == true {
            clearCapturePreflightJournal(in: packageURL)
            return false
        }
        let expectedPath = "Audio/Calibration/signal-path-\(pending.id.uuidString.lowercased()).wav"
        guard pending.relativeAudioPath == expectedPath,
              project.setups.contains(where: { $0.id == pending.setupID }),
              let sessionIndex = project.recordingSessions?.firstIndex(where: { $0.id == pending.sessionID }) else {
            clearCapturePreflightJournal(in: packageURL)
            return false
        }

        let audioDirectory = packageURL.appendingPathComponent("Audio", isDirectory: true)
        let calibrationDirectory = audioDirectory.appendingPathComponent("Calibration", isDirectory: true)
        let audioURL = packageURL.appendingPathComponent(expectedPath)
        for url in [audioDirectory, calibrationDirectory] {
            guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey]),
                  values.isSymbolicLink != true else {
                clearCapturePreflightJournal(in: packageURL)
                return false
            }
        }
        guard let values = try? audioURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              readableAudioHasFrames(audioURL),
              let file = try? AVAudioFile(forReading: audioURL) else {
            quarantineInterruptedPreflight(at: audioURL, packageURL: packageURL)
            clearCapturePreflightJournal(in: packageURL)
            return false
        }

        let interrupted = CapturePreflightFinding(
            id: "interrupted-transaction",
            kind: .captureIntegrity,
            severity: .blocker,
            title: "Rehearsal transaction was interrupted",
            detail: "OrgRec recovered the audio after the app stopped before BWF finalization and the atomic report commit were proven.",
            remediation: "Retain this failed evidence for audit, then repeat the complete rehearsal."
        )
        let context = CapturePreflightAnalysisContext(
            reportID: pending.id,
            recordedAt: pending.startedAt,
            sessionID: pending.sessionID,
            setupID: pending.setupID,
            setupRevision: pending.setupRevision,
            deviceSnapshot: pending.deviceSnapshot,
            relativeAudioPath: pending.relativeAudioPath,
            fileSize: Int64(values.fileSize ?? 0),
            sha256: (try? sha256(of: audioURL)) ?? "",
            sampleRate: file.processingFormat.sampleRate,
            frameCount: file.length,
            assignments: pending.assignments,
            captureDiagnostics: nil,
            bwfMetadata: pending.bwfMetadata,
            bwfFinalizationSucceeded: false,
            protocolSnapshot: pending.protocolSnapshot
        )
        let report: CapturePreflightReport
        do {
            var analyzed = try CapturePreflightAnalyzer.analyze(fileURL: audioURL, context: context)
            analyzed.findings.append(interrupted)
            analyzed.verdict = .failed
            report = analyzed
        } catch {
            let unreadable = CapturePreflightFinding(
                id: "recovery-analysis",
                kind: .evidenceIntegrity,
                severity: .blocker,
                title: "Recovered rehearsal could not be analyzed",
                detail: error.localizedDescription,
                remediation: "Inspect the retained audio and repeat the rehearsal."
            )
            report = CapturePreflightAnalyzer.evaluate(
                samples: [],
                context: context,
                additionalFindings: [interrupted, unreadable]
            )
        }
        var reports = project.recordingSessions?[sessionIndex].capturePreflightReports ?? []
        reports.append(report)
        project.recordingSessions?[sessionIndex].capturePreflightReports = reports
        return true
    }

    private func quarantineInterruptedPreflight(at audioURL: URL, packageURL: URL) {
        guard FileManager.default.fileExists(atPath: audioURL.path),
              let values = try? audioURL.resourceValues(forKeys: [.isSymbolicLinkKey]),
              values.isSymbolicLink != true else { return }
        let directory = packageURL.appendingPathComponent("Manifests/Recovery", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var destination = directory.appendingPathComponent(audioURL.lastPathComponent + ".partial")
            if FileManager.default.fileExists(atPath: destination.path) {
                destination = directory.appendingPathComponent(audioURL.lastPathComponent + "-\(UUID().uuidString.lowercased()).partial")
            }
            try FileManager.default.moveItem(at: audioURL, to: destination)
        } catch {
            // Preserve the original bytes in place when quarantine cannot be completed.
        }
    }

    private func recoverCalibrationCaptureJournal(
        in project: inout OrgRecProject,
        packageURL: URL
    ) -> Bool {
        let journalURL = calibrationCaptureJournalURL(in: packageURL)
        guard let data = try? Data(contentsOf: journalURL),
              let journal = try? OrgRecCoding.decoder.decode(CalibrationCaptureJournal.self, from: data) else {
            return false
        }
        let expectedPath = "Audio/Calibration/\(journal.calibration.id.uuidString.lowercased()).wav"
        guard journal.calibration.relativeAudioPath == expectedPath else {
            clearCalibrationCaptureJournal(in: packageURL)
            return false
        }
        let audioDirectory = packageURL.appendingPathComponent("Audio", isDirectory: true)
        let calibrationDirectory = audioDirectory.appendingPathComponent("Calibration", isDirectory: true)
        let audioURL = packageURL.appendingPathComponent(expectedPath)
        for url in [audioDirectory, calibrationDirectory, audioURL] {
            guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey]),
                  values.isSymbolicLink != true else {
                clearCalibrationCaptureJournal(in: packageURL)
                return false
            }
            if url == audioURL,
               (values.isRegularFile != true || readableAudioHasFrames(audioURL) == false) {
                clearCalibrationCaptureJournal(in: packageURL)
                return false
            }
        }
        var calibration = journal.calibration
        calibration.audioSHA256 = try? sha256(of: audioURL)
        calibration.audioFileSize = Int64((try? audioURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        calibration.notes += " Recovered after calibration capture was interrupted; estimate and acceptance were intentionally withheld."
        var calibrations = project.tuningCalibrations ?? []
        if let index = calibrations.firstIndex(where: { $0.id == calibration.id }) {
            guard calibrations[index].status == .pending,
                  calibrations[index].method == "Pending field measurement",
                  calibrations[index].audioSHA256 == nil else {
                clearCalibrationCaptureJournal(in: packageURL)
                return false
            }
            calibrations[index] = calibration
        } else {
            calibrations.append(calibration)
        }
        project.tuningCalibrations = calibrations
        return true
    }

    private func recoverLongTakeCaptureJournal(
        in project: OrgRecProject,
        packageURL: URL
    ) -> LongTakeCaptureJournal? {
        guard let journal = readLongTakeCaptureJournal(in: packageURL) else { return nil }
        let expectedPath = "Audio/LongTakes/\(journal.id.uuidString.lowercased()).wav"
        if project.longTakeSources?.contains(where: { $0.id == journal.id }) == true {
            clearLongTakeCaptureJournal(in: packageURL)
            return nil
        }
        guard journal.relativeAudioPath == expectedPath,
              project.roadmap.contains(where: { $0.id == journal.roadmapItemID }) else {
            clearLongTakeCaptureJournal(in: packageURL)
            return nil
        }
        let audioDirectory = packageURL.appendingPathComponent("Audio", isDirectory: true)
        let longTakeDirectory = audioDirectory.appendingPathComponent("LongTakes", isDirectory: true)
        let audioURL = packageURL.appendingPathComponent(journal.relativeAudioPath)
        for url in [audioDirectory, longTakeDirectory, audioURL] {
            guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey]),
                  values.isSymbolicLink != true else {
                clearLongTakeCaptureJournal(in: packageURL)
                return nil
            }
            if url == audioURL,
               (values.isRegularFile != true || readableAudioHasFrames(audioURL) == false) {
                clearLongTakeCaptureJournal(in: packageURL)
                return nil
            }
        }
        return journal
    }

    private func recoverActiveCaptureJournal(in project: inout OrgRecProject, packageURL: URL) -> Bool {
        let journalURL = activeCaptureJournalURL(in: packageURL)
        guard let data = try? Data(contentsOf: journalURL),
              let journal = try? OrgRecCoding.decoder.decode(ActiveCaptureJournal.self, from: data) else {
            return false
        }
        let expectedPath = "Audio/Originals/\(journal.take.id.uuidString.lowercased()).wav"
        guard journal.take.relativeAudioPath == expectedPath,
              project.roadmap.contains(where: { $0.id == journal.take.roadmapItemID }) else {
            clearActiveCaptureJournal(in: packageURL)
            return false
        }
        if let existing = project.takes.first(where: { $0.id == journal.take.id }) {
            let isUnfinished = existing.endedAt == nil
                || ([TakeStatus.recording, .recorded, .analyzing].contains(existing.status)
                    && existing.analysis == nil
                    && (existing.reviewHistory?.isEmpty ?? true))
            guard isUnfinished else {
                clearActiveCaptureJournal(in: packageURL)
                return false
            }
        }
        let audioDirectory = packageURL.appendingPathComponent("Audio", isDirectory: true)
        let originalsDirectory = audioDirectory.appendingPathComponent("Originals", isDirectory: true)
        let audioURL = packageURL.appendingPathComponent(expectedPath)
        for url in [audioDirectory, originalsDirectory, audioURL] {
            guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey]),
                  values.isSymbolicLink != true else {
                clearActiveCaptureJournal(in: packageURL)
                return false
            }
            if url == audioURL,
               (values.isRegularFile != true || readableAudioHasFrames(audioURL) == false) {
                clearActiveCaptureJournal(in: packageURL)
                return false
            }
        }
        var take = journal.take
        let journalProvesFinalization = take.endedAt != nil
            && take.frameCount > 0
            && take.captureDiagnostics != nil
        if take.status != .failed {
            take.status = journalProvesFinalization ? .recovered : .failed
        }
        var integrityFaults = take.captureIntegrityFaults ?? []
        if journalProvesFinalization == false {
            integrityFaults.append(CaptureFault(
                kind: .interruptedCapture,
                message: "Recording finalization was interrupted; Broadcast Wave integrity is not established."
            ))
        }
        let retainedReason = take.reviewReason?.lowercased() ?? ""
        if retainedReason.contains("interaction-sensor finalization failed"),
           integrityFaults.contains(where: { $0.kind == .auxiliaryEvidenceFailure }) == false {
            integrityFaults.append(CaptureFault(
                kind: .auxiliaryEvidenceFailure,
                message: take.reviewReason ?? "Interaction-sensor finalization failed."
            ))
        }
        if retainedReason.contains("broadcast wave metadata finalization failed"),
           integrityFaults.contains(where: { $0.kind == .metadataFinalization }) == false {
            integrityFaults.append(CaptureFault(
                kind: .metadataFinalization,
                message: take.reviewReason ?? "Broadcast Wave metadata finalization failed."
            ))
        }
        if retainedReason.contains("opening project save failed"),
           integrityFaults.contains(where: { $0.kind == .projectCommitFailure }) == false {
            integrityFaults.append(CaptureFault(
                kind: .projectCommitFailure,
                message: take.reviewReason ?? "The opening project save failed after capture started."
            ))
        }
        take.captureIntegrityFaults = integrityFaults.isEmpty ? nil : integrityFaults
        take.endedAt = take.endedAt ?? .now
        take.fileSize = Int64((try? audioURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        take.sha256 = try? sha256(of: audioURL)
        take.reviewReason = [
            take.reviewReason,
            journalProvesFinalization
                ? "Recovered a finalized capture after its manifest commit was interrupted; reanalysis and human review are required."
                : "Recovered from the durable active-capture journal because recording finalization was interrupted; BWF integrity is not established and the take must be replaced.",
        ].compactMap { $0 }.joined(separator: " ")
        if let existingIndex = project.takes.firstIndex(where: { $0.id == take.id }) {
            project.takes[existingIndex] = take
        } else {
            project.takes.append(take)
        }
        if let index = project.roadmap.firstIndex(where: { $0.id == take.roadmapItemID }) {
            if project.roadmap[index].takeIDs.contains(take.id) == false {
                project.roadmap[index].takeIDs.append(take.id)
            }
            project.roadmap[index].state = .needsReview
        }
        return true
    }

    private func persist() async throws {
        guard var project, let projectURL else { return }
        refreshCaptureStateLibrary(in: &project)
        project.collectionAnalysis = CollectionAnalysisEngine.refreshed(project: project)
        self.project = project
        persistenceGeneration += 1
        let generation = persistenceGeneration
        persistenceOperationsInFlight += 1
        latestPersistenceCompletion = nil
        persistenceState = .saving
        do {
            try await store.save(project, at: projectURL)
            finishPersistenceAttempt(generation: generation, outcome: .saved(.now))
        } catch {
            finishPersistenceAttempt(generation: generation, outcome: .failed(error.localizedDescription))
            throw error
        }
    }

    /// Save continuations are allowed to resume on the main actor in either
    /// order. Only the newest generation determines the final UI state once
    /// every outstanding atomic write has drained.
    private func finishPersistenceAttempt(generation: Int, outcome: PersistenceCompletion) {
        persistenceOperationsInFlight = max(0, persistenceOperationsInFlight - 1)
        if generation == persistenceGeneration {
            latestPersistenceCompletion = (generation, outcome)
        }
        guard persistenceOperationsInFlight == 0 else {
            persistenceState = .saving
            return
        }
        guard let completion = latestPersistenceCompletion,
              completion.generation == persistenceGeneration else {
            persistenceState = .dirty(message: "The most recent project save did not report a final outcome. Retry before closing OrgRec.")
            return
        }
        switch completion.outcome {
        case let .saved(date):
            persistenceState = .clean(lastSavedAt: date)
        case let .failed(message):
            persistenceState = .dirty(message: message)
        }
    }

    @discardableResult
    private func persistOrReport(showAlert: Bool = true) async -> Bool {
        do {
            try await persist()
            return true
        } catch {
            if showAlert {
                errorMessage = "OrgRec could not save the project: \(error.localizedDescription) Your changes remain open in memory. Retry saving before closing the app."
            }
            return false
        }
    }

    func retryPersistence() async {
        guard await waitForPersistenceToSettle() else { return }
        guard persistenceState.isDirty else { return }
        isWorking = true
        defer { isWorking = false }
        if await persistOrReport() {
            let pendingAnalysisID = projectURL.flatMap { clearReconciledActiveCaptureJournal(in: $0) }
            if let projectURL { clearReconciledCapturePreflightJournal(in: projectURL) }
            let longTakeWasCommitted = pendingLongTakeID.map { longTakeID in
                project?.longTakeSources?.contains(where: { $0.id == longTakeID }) == true
            } ?? false
            if longTakeWasCommitted {
                clearLongTakePreview(allowRecordedMaster: true)
            }
            notice = "Project changes saved."
            if let pendingAnalysisID {
                await analyze(takeID: pendingAnalysisID)
            }
        }
    }

    private func waitForPersistenceToSettle() async -> Bool {
        for _ in 0..<600 {
            if persistenceState.isSaving == false { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        errorMessage = "The project save did not finish within 30 seconds. OrgRec will remain open so no pending changes are discarded."
        return false
    }

    var hasActiveCapture: Bool {
        capture.isRecording
            || capture.isFinalizing
            || isStartingCapture
            || isStartingCapturePreflight
            || isStoppingRecording
            || isStoppingLongTake
            || isStoppingCalibration
            || isStoppingCapturePreflight
            || isCalibrating
            || isLongTakeRecording
            || isRunningCapturePreflight
            || activeTakeID != nil
            || activeCalibrationID != nil
            || pendingCapturePreflight != nil
    }

    var hasRecoverableLongTakeMaster: Bool {
        pendingLongTakeWasRecorded && longTakeSourceURL != nil
    }

    private func beginCriticalCaptureActivity(reason: String) {
        guard captureActivity == nil else { return }
        captureActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled],
            reason: reason
        )
    }

    private func endCriticalCaptureActivity() {
        guard let captureActivity else { return }
        ProcessInfo.processInfo.endActivity(captureActivity)
        self.captureActivity = nil
    }

    private func handleCriticalCaptureStop(_ message: String) {
        guard capture.isRecording, isHandlingCriticalCaptureStop == false else { return }
        isHandlingCriticalCaptureStop = true
        errorMessage = message
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.isCalibrating {
                await self.stopPitchCalibration()
            } else if self.isLongTakeRecording {
                await self.stopLongTakeRecording()
            } else if self.isRunningCapturePreflight || self.pendingCapturePreflight != nil {
                await self.stopCapturePreflight()
            } else {
                await self.stopRecording()
            }
            self.isHandlingCriticalCaptureStop = false
        }
    }

    /// Finalizes the real-time writer before the application closes or the Mac sleeps.
    /// Analysis may continue briefly, but no active audio buffer is left orphaned.
    func finalizeActiveCaptureForLifecycle(reason: String) async -> Bool {
        guard hasActiveCapture else {
            guard await waitForWorkingOperationsToSettle() else { return false }
            guard await waitForPersistenceToSettle() else { return false }
            if persistenceState.isDirty { await retryPersistence() }
            return persistenceState.requiresResolution == false && isWorking == false
        }
        notice = "Finalizing the active capture before \(reason)…"
        if isStartingCapture || isStartingCapturePreflight {
            guard await waitForCaptureTransitionToSettle() else { return false }
        }
        if isCalibrating {
            await stopPitchCalibration()
        } else if isLongTakeRecording {
            await stopLongTakeRecording()
        } else if isRunningCapturePreflight || pendingCapturePreflight != nil {
            await stopCapturePreflight()
        } else if capture.isRecording || activeTakeID != nil {
            await stopRecording()
        }
        guard await waitForCaptureTransitionToSettle() else { return false }
        guard await waitForWorkingOperationsToSettle() else { return false }
        endCriticalCaptureActivity()
        guard await waitForPersistenceToSettle() else { return false }
        if persistenceState.isDirty { await retryPersistence() }
        return hasActiveCapture == false && persistenceState.requiresResolution == false
    }

    private func waitForWorkingOperationsToSettle() async -> Bool {
        for _ in 0..<1_200 {
            if isWorking == false { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        errorMessage = "The current project operation did not reach a safe boundary within 60 seconds. OrgRec will remain open rather than interrupt it."
        return false
    }

    private func waitForCaptureTransitionToSettle() async -> Bool {
        for _ in 0..<1_200 {
            let transitionIsActive = capture.isFinalizing
                || isStartingCapture
                || isStartingCapturePreflight
                || isStoppingRecording
                || isStoppingLongTake
                || isStoppingCalibration
                || isStoppingCapturePreflight
            if transitionIsActive == false { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        errorMessage = "The recording pipeline did not finish within 60 seconds. OrgRec will remain open so the capture cannot be interrupted during finalization."
        return false
    }

    private func refreshCaptureStateLibrary(in project: inout OrgRecProject) {
        let registrationsByID = Dictionary(uniqueKeysWithValues: project.registrations.map { ($0.id, $0) })
        let existing = project.captureStates ?? []
        var byFingerprint = Dictionary(existing.map { ($0.fingerprintSHA256, $0) }, uniquingKeysWith: { first, _ in first })
        if let activeID = project.activeCaptureStateID,
           let active = existing.first(where: { $0.id == activeID }) {
            byFingerprint[active.fingerprintSHA256] = active
        }
        for index in project.roadmap.indices {
            let item = project.roadmap[index]
            let registration = item.registrationID.flatMap { registrationsByID[$0] }
            let generated = project.requiredCaptureState(for: item) ?? RoadmapEngine.requiredCaptureState(
                for: item,
                registration: registration,
                components: project.organComponents ?? []
            )
            let canonical = byFingerprint[generated.fingerprintSHA256] ?? generated
            byFingerprint[canonical.fingerprintSHA256] = canonical
            project.roadmap[index].requiredCaptureStateID = canonical.id
            project.roadmap[index].requiredCaptureStateFingerprint = canonical.fingerprintSHA256
            project.roadmap[index].requiredCaptureState = nil
        }
        project.captureStates = byFingerprint.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func ensureActiveSession(in project: inout OrgRecProject) {
        guard project.recordingSessions?.contains(where: { $0.endedAt == nil }) != true else { return }
        var sessions = project.recordingSessions ?? []
        sessions.append(makeSession(project: project))
        project.recordingSessions = sessions
    }

    private func makeSession(
        project: OrgRecProject,
        plan: RecordingSessionPlan? = nil,
        noiseAssessment: NoiseContextAssessment? = nil
    ) -> RecordingSession {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let environment = project.setups.first?.environment ?? EnvironmentReading()
        let assessment = noiseAssessment ?? project.noiseContextAssessments?.last
        let planNotes = [plan?.accessNotes, plan?.preflightNotes]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
        return RecordingSession(
            sessionCode: "ORGREC-\(formatter.string(from: .now))",
            operatorName: plan?.operatorName ?? NSFullUserName(),
            institution: plan?.institution ?? "",
            purpose: plan?.purpose ?? "\(project.organName) · systematic pipe-organ recording",
            timezoneIdentifier: plan?.timezoneIdentifier ?? TimeZone.current.identifier,
            venueCondition: assessment?.summary ?? "",
            environment: environment,
            notes: planNotes,
            sessionPlanID: plan?.id,
            sessionPlanRevision: plan?.revision,
            noiseContextAssessment: assessment
        )
    }

    private func preparePlayback(takeID: UUID) throws {
        guard let project, let projectURL,
              let take = project.takes.first(where: { $0.id == takeID }) else { return }
        try playback.load(projectURL.appendingPathComponent(take.relativeAudioPath))
        let accepted = take.acceptedLoopPointSetID.flatMap { acceptedID in
            take.loopPointSets?.first { $0.id == acceptedID && $0.status == .accepted }
        }
        playback.configureLoopPointSet(accepted)
    }

    private func automatedMarker(_ marker: AnalysisMarkerKind, analysis: AnalysisSummary?) -> Double? {
        switch marker {
        case .onset: analysis?.onsetSeconds
        case .sustainStart: analysis?.sustainStartSeconds
        case .keyUp: analysis?.keyUpSeconds
        case .soundOffset: analysis?.soundOffsetSeconds
        case .tailEnd: analysis?.tailEndSeconds
        }
    }

    private func saveAnalysisArtifacts(
        takeID: UUID,
        waveform: WaveformSummary,
        spectrogram: SpectrogramData,
        packageURL: URL
    ) throws {
        let directory = packageURL.appendingPathComponent("Analysis/Derivatives", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stem = takeID.uuidString.lowercased()
        try OrgRecCoding.encoder.encode(waveform).write(
            to: directory.appendingPathComponent("\(stem)-waveform.json"),
            options: .atomic
        )
        try OrgRecCoding.encoder.encode(spectrogram).write(
            to: directory.appendingPathComponent("\(stem)-spectrogram.json"),
            options: .atomic
        )
        if let run = spectrogram.analysisRun {
            let runDirectory = packageURL
                .appendingPathComponent("Analysis/Runs", isDirectory: true)
                .appendingPathComponent(run.id.uuidString.lowercased(), isDirectory: true)
            try FileManager.default.createDirectory(at: runDirectory, withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(waveform).write(
                to: runDirectory.appendingPathComponent("waveform.json"),
                options: .atomic
            )
            try OrgRecCoding.encoder.encode(spectrogram).write(
                to: runDirectory.appendingPathComponent("spectrogram.json"),
                options: .atomic
            )
        }
    }

    private func loadAnalysisArtifacts(takeID: UUID, packageURL: URL) {
        let directory = packageURL.appendingPathComponent("Analysis/Derivatives", isDirectory: true)
        let stem = takeID.uuidString.lowercased()
        waveform = try? OrgRecCoding.decoder.decode(
            WaveformSummary.self,
            from: Data(contentsOf: directory.appendingPathComponent("\(stem)-waveform.json"))
        )
        spectrogram = try? OrgRecCoding.decoder.decode(
            SpectrogramData.self,
            from: Data(contentsOf: directory.appendingPathComponent("\(stem)-spectrogram.json"))
        )
    }
}
