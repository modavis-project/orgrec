import Foundation

public enum CaptureTechnique: String, Codable, CaseIterable, Identifiable, Sendable {
    case closePair = "Close pair"
    case naveORTF = "Nave ORTF"
    case rearOmni = "Rear omni"
    case releaseTail = "Release tail"

    public var id: String { rawValue }
}

public enum RoadmapState: String, Codable, CaseIterable, Sendable {
    case missing
    case queued
    case recorded
    case needsReview
    case accepted
    case rejected
    case exempt
    case unresolved
}

public enum TakeStatus: String, Codable, Sendable {
    case recording
    case recorded
    case analyzing
    case needsReview
    case accepted
    case rejected
    case recovered
    case failed
}

public enum LocatorTrust: String, Codable, Sendable {
    case canonicalMDVS
    case functionalPosition
    case sourceBound
}

public struct ReleaseBinding: Codable, Hashable, Sendable {
    public var requestedRelease: String
    public var releaseState: String
    public var canonicalSourceRelease: String
    public var protectedFingerprintSHA256: String
    public var navigatorContractVersion: String

    public init(
        requestedRelease: String = "1.1",
        releaseState: String = "release_1_1_enrichment_not_justified",
        canonicalSourceRelease: String = "1.0",
        protectedFingerprintSHA256: String = "70a3ff6dd2f629e6da9fb713acfe9e9358cd7db85612a9789931ded5663031c7",
        navigatorContractVersion: String = "modavis.navigator.orgrec-roadmap/v1"
    ) {
        self.requestedRelease = requestedRelease
        self.releaseState = releaseState
        self.canonicalSourceRelease = canonicalSourceRelease
        self.protectedFingerprintSHA256 = protectedFingerprintSHA256
        self.navigatorContractVersion = navigatorContractVersion
    }
}

public struct MODAVISSnapshot: Codable, Hashable, Sendable {
    public var id: UUID
    public var retrievedAt: Date
    public var navigatorBaseURL: URL?
    public var endpoint: String
    public var eTag: String?
    public var payloadSHA256: String
    public var release: ReleaseBinding

    public init(
        id: UUID = UUID(),
        retrievedAt: Date = Date(),
        navigatorBaseURL: URL? = nil,
        endpoint: String,
        eTag: String? = nil,
        payloadSHA256: String,
        release: ReleaseBinding = ReleaseBinding()
    ) {
        self.id = id
        self.retrievedAt = retrievedAt
        self.navigatorBaseURL = navigatorBaseURL
        self.endpoint = endpoint
        self.eTag = eTag
        self.payloadSHA256 = payloadSHA256
        self.release = release
    }
}

public struct ComponentLocator: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var organMDVSID: String
    public var canonicalMDVSID: String?
    public var pipePositionReference: String?
    public var sourceRecordID: String?
    public var sourcePath: String?
    public var snapshotSHA256: String
    public var kind: String
    public var label: String
    public var trust: LocatorTrust

    public init(
        id: String,
        organMDVSID: String,
        canonicalMDVSID: String? = nil,
        pipePositionReference: String? = nil,
        sourceRecordID: String? = nil,
        sourcePath: String? = nil,
        snapshotSHA256: String,
        kind: String,
        label: String,
        trust: LocatorTrust
    ) {
        self.id = id
        self.organMDVSID = organMDVSID
        self.canonicalMDVSID = canonicalMDVSID
        self.pipePositionReference = pipePositionReference
        self.sourceRecordID = sourceRecordID
        self.sourcePath = sourcePath
        self.snapshotSHA256 = snapshotSHA256
        self.kind = kind
        self.label = label
        self.trust = trust
    }
}

public struct OrganComponent: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: String
    public var label: String
    public var division: String
    public var footHeight: String?
    public var noteName: String?
    public var midiNote: Int?
    public var expectedFrequencyHz: Double?
    public var locator: ComponentLocator
    public var parentComponentID: String?
    public var playableMIDILow: Int?
    public var playableMIDIHigh: Int?
    public var sourceDetails: [String: String]?
    public var referencePitchHz: Double?
    public var temperament: String?
    public var soundingTargetDefinition: SoundingTargetDefinition?

    public init(
        id: String,
        kind: String,
        label: String,
        division: String,
        footHeight: String? = nil,
        noteName: String? = nil,
        midiNote: Int? = nil,
        expectedFrequencyHz: Double? = nil,
        locator: ComponentLocator,
        parentComponentID: String? = nil,
        playableMIDILow: Int? = nil,
        playableMIDIHigh: Int? = nil,
        sourceDetails: [String: String]? = nil,
        referencePitchHz: Double? = nil,
        temperament: String? = nil,
        soundingTargetDefinition: SoundingTargetDefinition? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.division = division
        self.footHeight = footHeight
        self.noteName = noteName
        self.midiNote = midiNote
        self.expectedFrequencyHz = expectedFrequencyHz
        self.locator = locator
        self.parentComponentID = parentComponentID
        self.playableMIDILow = playableMIDILow
        self.playableMIDIHigh = playableMIDIHigh
        self.sourceDetails = sourceDetails
        self.referencePitchHz = referencePitchHz
        self.temperament = temperament
        self.soundingTargetDefinition = soundingTargetDefinition
    }
}

public enum PhysicalIdentityEvidence: String, Codable, CaseIterable, Sendable {
    case canonicalPipe
    case explicitSharedPipe
    case sharedRankPosition
    case reviewedAssertion
    case uniqueFunctionalAddress

    public var isConfirmedSharedIdentity: Bool {
        switch self {
        case .canonicalPipe, .explicitSharedPipe, .sharedRankPosition, .reviewedAssertion: true
        case .uniqueFunctionalAddress: false
        }
    }
}

/// A source-backed component edge retained from the frozen Navigator snapshot.
public struct OrganComponentRelationship: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var sourceComponentID: String
    public var targetComponentID: String
    public var kind: String
    public var sourcePath: String?
    public var evidence: String?

    public init(id: String, sourceComponentID: String, targetComponentID: String, kind: String, sourcePath: String? = nil, evidence: String? = nil) {
        self.id = id
        self.sourceComponentID = sourceComponentID
        self.targetComponentID = targetComponentID
        self.kind = kind
        self.sourcePath = sourcePath
        self.evidence = evidence
    }
}

/// A source mapping from a console address to one physical pipe or a complete
/// physical pipe set. Complete sets keep compound stops from being incorrectly
/// merged merely because some of their pipes overlap.
public struct PhysicalPipeMapping: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var stopComponentID: String
    public var keyMIDI: Int
    public var physicalPipeComponentIDs: [String]
    public var rankComponentID: String?
    public var rankPosition: Int?
    public var evidence: PhysicalIdentityEvidence
    public var sourcePath: String?

    public init(id: String, stopComponentID: String, keyMIDI: Int, physicalPipeComponentIDs: [String], rankComponentID: String? = nil, rankPosition: Int? = nil, evidence: PhysicalIdentityEvidence = .canonicalPipe, sourcePath: String? = nil) {
        self.id = id
        self.stopComponentID = stopComponentID
        self.keyMIDI = keyMIDI
        self.physicalPipeComponentIDs = physicalPipeComponentIDs
        self.rankComponentID = rankComponentID
        self.rankPosition = rankPosition
        self.evidence = evidence
        self.sourcePath = sourcePath
    }
}

public struct StopPipeOffset: Codable, Hashable, Sendable {
    public var stopComponentID: String
    public var soundingSemitoneOffset: Int

    public init(stopComponentID: String, soundingSemitoneOffset: Int) {
        self.stopComponentID = stopComponentID
        self.soundingSemitoneOffset = soundingSemitoneOffset
    }
}

/// A local, reversible assertion for source documents that omit a known shared
/// rank. Assertions are bound to a snapshot and never carry into a new revision.
public struct PipeSharingAssertion: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var stops: [StopPipeOffset]
    public var soundingMIDILow: Int
    public var soundingMIDIHigh: Int
    public var snapshotSHA256: String
    public var author: String
    public var note: String
    public var reviewedAt: Date

    public init(id: UUID = UUID(), stops: [StopPipeOffset], soundingMIDILow: Int, soundingMIDIHigh: Int, snapshotSHA256: String, author: String, note: String, reviewedAt: Date = .now) {
        self.id = id
        self.stops = stops
        self.soundingMIDILow = soundingMIDILow
        self.soundingMIDIHigh = soundingMIDIHigh
        self.snapshotSHA256 = snapshotSHA256
        self.author = author
        self.note = note
        self.reviewedAt = reviewedAt
    }
}

public struct PhysicalActivationRoute: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var component: OrganComponent
    public var registrationID: UUID
    public var physicalPipeComponentIDs: [String]
    public var evidence: PhysicalIdentityEvidence
    public var evidenceDescription: String

    public init(id: String, component: OrganComponent, registrationID: UUID, physicalPipeComponentIDs: [String], evidence: PhysicalIdentityEvidence, evidenceDescription: String) {
        self.id = id
        self.component = component
        self.registrationID = registrationID
        self.physicalPipeComponentIDs = physicalPipeComponentIDs
        self.evidence = evidence
        self.evidenceDescription = evidenceDescription
    }
}

public struct PhysicalSoundTarget: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var physicalPipeComponentIDs: [String]
    public var routes: [PhysicalActivationRoute]
    public var primaryRouteID: String
    public var evidence: PhysicalIdentityEvidence

    public init(id: String, physicalPipeComponentIDs: [String], routes: [PhysicalActivationRoute], primaryRouteID: String, evidence: PhysicalIdentityEvidence) {
        self.id = id
        self.physicalPipeComponentIDs = physicalPipeComponentIDs
        self.routes = routes
        self.primaryRouteID = primaryRouteID
        self.evidence = evidence
    }
}

public struct PhysicalOverlapCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var firstStopComponentID: String
    public var secondStopComponentID: String
    public var firstSoundingSemitoneOffset: Int
    public var secondSoundingSemitoneOffset: Int
    public var soundingMIDILow: Int
    public var soundingMIDIHigh: Int
    public var overlappingAddressCount: Int
    public var reason: String

    public init(id: String, firstStopComponentID: String, secondStopComponentID: String, firstSoundingSemitoneOffset: Int, secondSoundingSemitoneOffset: Int, soundingMIDILow: Int, soundingMIDIHigh: Int, overlappingAddressCount: Int, reason: String) {
        self.id = id
        self.firstStopComponentID = firstStopComponentID
        self.secondStopComponentID = secondStopComponentID
        self.firstSoundingSemitoneOffset = firstSoundingSemitoneOffset
        self.secondSoundingSemitoneOffset = secondSoundingSemitoneOffset
        self.soundingMIDILow = soundingMIDILow
        self.soundingMIDIHigh = soundingMIDIHigh
        self.overlappingAddressCount = overlappingAddressCount
        self.reason = reason
    }
}

public struct OrganSpecificationCharacteristics: Codable, Hashable, Sendable {
    public var referencePitchHz: Double?
    public var temperament: String?
    public var manualCount: Int?
    public var documentedStopCount: Int?
    public var divisionCount: Int?
    public var keyboardCount: Int?
    public var rankCount: Int?
    public var pipePositionCount: Int?
    public var couplerCount: Int?
    public var accessoryCount: Int?
    public var builder: String?
    public var buildDateLabel: String?
    public var actionType: String?
    public var windPressure: String?
    public var sourceCount: Int?
    public var sourceURLs: [String]?

    public init(
        referencePitchHz: Double? = nil,
        temperament: String? = nil,
        manualCount: Int? = nil,
        documentedStopCount: Int? = nil,
        divisionCount: Int? = nil,
        keyboardCount: Int? = nil,
        rankCount: Int? = nil,
        pipePositionCount: Int? = nil,
        couplerCount: Int? = nil,
        accessoryCount: Int? = nil,
        builder: String? = nil,
        buildDateLabel: String? = nil,
        actionType: String? = nil,
        windPressure: String? = nil,
        sourceCount: Int? = nil,
        sourceURLs: [String]? = nil
    ) {
        self.referencePitchHz = referencePitchHz
        self.temperament = temperament
        self.manualCount = manualCount
        self.documentedStopCount = documentedStopCount
        self.divisionCount = divisionCount
        self.keyboardCount = keyboardCount
        self.rankCount = rankCount
        self.pipePositionCount = pipePositionCount
        self.couplerCount = couplerCount
        self.accessoryCount = accessoryCount
        self.builder = builder
        self.buildDateLabel = buildDateLabel
        self.actionType = actionType
        self.windPressure = windPressure
        self.sourceCount = sourceCount
        self.sourceURLs = sourceURLs
    }
}

// MARK: - Instrument and operational noise capture

/// Where an audible event originates. This is intentionally independent from
/// its physical mechanism and time behaviour: a blower can, for example, be an
/// instrument auxiliary, electrical, mechanical, aerodynamic, and continuous.
public enum AcousticSourceScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case instrument
    case instrumentAuxiliary
    case recordingSystem
    case buildingServices
    case venueActivity
    case externalEnvironment
    case human
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .instrument: "Instrument"
        case .instrumentAuxiliary: "Instrument auxiliary"
        case .recordingSystem: "Recording system"
        case .buildingServices: "Building services"
        case .venueActivity: "Venue activity"
        case .externalEnvironment: "External environment"
        case .human: "Human"
        case .unknown: "Unknown"
        }
    }
}

public enum AcousticMechanism: String, Codable, CaseIterable, Identifiable, Sendable {
    case soundingElement
    case mechanical
    case pneumatic
    case aerodynamicFlow
    case electrical
    case electromagnetic
    case structuralContact
    case human
    case environmental
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .soundingElement: "Sounding element"
        case .mechanical: "Mechanical"
        case .pneumatic: "Pneumatic"
        case .aerodynamicFlow: "Wind / flow"
        case .electrical: "Electrical"
        case .electromagnetic: "Electromagnetic"
        case .structuralContact: "Structural / contact"
        case .human: "Human"
        case .environmental: "Environmental"
        case .unknown: "Unknown"
        }
    }
}

public enum AcousticTemporalBehavior: String, Codable, CaseIterable, Identifiable, Sendable {
    case impulse
    case attackTransient
    case releaseTransient
    case intermittent
    case periodic
    case continuous
    case ramp
    case startup
    case shutdown
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .impulse: "Impulse"
        case .attackTransient: "Attack transient"
        case .releaseTransient: "Release transient"
        case .intermittent: "Intermittent"
        case .periodic: "Periodic"
        case .continuous: "Continuous"
        case .ramp: "Ramp / sweep"
        case .startup: "Startup"
        case .shutdown: "Shutdown"
        case .unknown: "Unknown"
        }
    }
}

public enum AcousticOperatingPhase: String, Codable, CaseIterable, Identifiable, Sendable {
    case idleBaseline
    case activation
    case deactivation
    case transition
    case steadyOperation
    case startup
    case shutdown
    case fault

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .idleBaseline: "Idle baseline"
        case .activation: "Activation"
        case .deactivation: "Deactivation"
        case .transition: "Transition"
        case .steadyOperation: "Steady operation"
        case .startup: "Startup"
        case .shutdown: "Shutdown"
        case .fault: "Suspected fault"
        }
    }
}

public enum AcousticEventRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case intendedTarget
    case characteristicByproduct
    case contextualCondition
    case interference
    case fault
    case uncertain

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .intendedTarget: "Intended target"
        case .characteristicByproduct: "Characteristic by-product"
        case .contextualCondition: "Context"
        case .interference: "Interference"
        case .fault: "Fault"
        case .uncertain: "Uncertain"
        }
    }
}

public enum InstrumentNoiseKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case keyAction
    case stopAction
    case couplerAction
    case accessoryAction
    case blower
    case windSystem
    case swellerJalousie
    case tremulant
    case pedalAction
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .keyAction: "Key action"
        case .stopAction: "Stop action"
        case .couplerAction: "Coupler action"
        case .accessoryAction: "Accessory action"
        case .blower: "Blower / wind motor"
        case .windSystem: "Wind and flow system"
        case .swellerJalousie: "Sweller / jalousie"
        case .tremulant: "Tremulant"
        case .pedalAction: "Pedal action"
        case .other: "Other instrument noise"
        }
    }
}

public enum InstrumentNoiseAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case activation
    case release
    case deactivation
    case startup
    case steadyOperation
    case shutdown
    case opening
    case closing
    case pedalPress
    case pedalRelease
    case movement
    case idleBaseline

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .activation: "Activation / engage"
        case .release: "Release"
        case .deactivation: "Deactivation / return"
        case .startup: "Startup"
        case .steadyOperation: "Steady operation"
        case .shutdown: "Shutdown"
        case .opening: "Opening"
        case .closing: "Closing"
        case .pedalPress: "Pedal press"
        case .pedalRelease: "Pedal release"
        case .movement: "Movement"
        case .idleBaseline: "Idle baseline"
        }
    }
}

public enum InstrumentNoiseVelocityPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case slow
    case normal
    case fast

    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
    public var normalizedValue: Double {
        switch self {
        case .slow: 0.25
        case .normal: 0.60
        case .fast: 1.0
        }
    }
    public var midiVelocity: Int {
        switch self {
        case .slow: 32
        case .normal: 80
        case .fast: 127
        }
    }
}

public struct InstrumentControlVelocity: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var label: String
    public var normalizedValue: Double?
    public var midiVelocity: Int?
    public var targetDurationSeconds: Double?

    public init(
        id: UUID = UUID(),
        label: String,
        normalizedValue: Double? = nil,
        midiVelocity: Int? = nil,
        targetDurationSeconds: Double? = nil
    ) {
        self.id = id
        self.label = label
        self.normalizedValue = normalizedValue.map { min(max($0, 0), 1) }
        self.midiVelocity = midiVelocity.map { min(max($0, 1), 127) }
        self.targetDurationSeconds = targetDurationSeconds.map { max(0, $0) }
    }

    public init(preset: InstrumentNoiseVelocityPreset, targetDurationSeconds: Double? = nil) {
        self.init(
            label: preset.displayName,
            normalizedValue: preset.normalizedValue,
            midiVelocity: preset.midiVelocity,
            targetDurationSeconds: targetDurationSeconds
        )
    }
}

public enum ActuationQuantity: String, Codable, CaseIterable, Identifiable, Sendable {
    case actionProgress
    case position
    case displacement
    case force
    case movementVelocity
    case windPressure
    case airflow
    case electricalCommand
    case midiVelocity
    case switchState
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .actionProgress: "Action progress"
        case .position: "Position / openness"
        case .displacement: "Displacement"
        case .force: "Force"
        case .movementVelocity: "Movement velocity"
        case .windPressure: "Wind pressure"
        case .airflow: "Air flow"
        case .electricalCommand: "Electrical command"
        case .midiVelocity: "MIDI velocity"
        case .switchState: "Switch state"
        case .custom: "Custom quantity"
        }
    }

    public var suggestedUnit: String {
        switch self {
        case .actionProgress, .position, .switchState: "normalized 0–1"
        case .displacement: "mm"
        case .force: "N"
        case .movementVelocity: "mm/s"
        case .windPressure: "Pa"
        case .airflow: "m³/s"
        case .electricalCommand: "%"
        case .midiVelocity: "MIDI 1–127"
        case .custom: "custom"
        }
    }
}

public enum ActuationCurveKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case linear
    case easeIn
    case easeOut
    case smoothSCurve
    case stepped
    case impulse
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .linear: "Linear"
        case .easeIn: "Ease in"
        case .easeOut: "Ease out"
        case .smoothSCurve: "Smooth S-curve"
        case .stepped: "Stepped"
        case .impulse: "Impulse"
        case .custom: "Custom points"
        }
    }
}

public enum ActuationTimeBasis: String, Codable, CaseIterable, Identifiable, Sendable {
    case normalized
    case seconds

    public var id: String { rawValue }
}

public enum ActuationInterpolation: String, Codable, CaseIterable, Identifiable, Sendable {
    case linear
    case monotoneCubic
    case step
    case none

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .linear: "Linear"
        case .monotoneCubic: "Monotone cubic"
        case .step: "Step / hold"
        case .none: "Discrete samples"
        }
    }
}

public enum ActuationEvidenceSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case operatorPlanned
    case controllerCommanded
    case sensorObserved
    case operatorObserved
    case inferred

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .operatorPlanned: "Operator-planned"
        case .controllerCommanded: "Controller-commanded"
        case .sensorObserved: "Sensor-observed"
        case .operatorObserved: "Operator-observed"
        case .inferred: "Inferred"
        }
    }
}

public struct ActuationCurvePoint: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Normalized 0–1 time or elapsed seconds, as declared by the parent curve.
    public var time: Double
    public var value: Double

    public init(id: UUID = UUID(), time: Double, value: Double) {
        self.id = id
        self.time = time
        self.value = value
    }
}

/// A commanded or observed actuation trajectory. Evidence fields prevent an
/// operator sketch from being mistaken for a measured sensor trace.
public struct ActuationCurve: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: ActuationCurveKind
    public var timeBasis: ActuationTimeBasis
    public var interpolation: ActuationInterpolation
    public var points: [ActuationCurvePoint]
    public var durationSeconds: Double?
    public var evidenceSource: ActuationEvidenceSource
    public var deviceID: UUID?
    public var deviceLabel: String?
    public var samplingRateHz: Double?
    public var calibrationReference: String?
    public var uncertainty: Double?
    public var notes: String

    public init(
        id: UUID = UUID(),
        kind: ActuationCurveKind,
        timeBasis: ActuationTimeBasis = .normalized,
        interpolation: ActuationInterpolation = .linear,
        points: [ActuationCurvePoint],
        durationSeconds: Double? = nil,
        evidenceSource: ActuationEvidenceSource,
        deviceID: UUID? = nil,
        deviceLabel: String? = nil,
        samplingRateHz: Double? = nil,
        calibrationReference: String? = nil,
        uncertainty: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.timeBasis = timeBasis
        self.interpolation = interpolation
        self.points = points.sorted { $0.time < $1.time }
        self.durationSeconds = durationSeconds
        self.evidenceSource = evidenceSource
        self.deviceID = deviceID
        self.deviceLabel = deviceLabel
        self.samplingRateHz = samplingRateHz
        self.calibrationReference = calibrationReference
        self.uncertainty = uncertainty
        self.notes = notes
    }

    public var validationIssues: [String] {
        var issues: [String] = []
        if points.count < 2 { issues.append("An actuation curve requires at least two points.") }
        if points.contains(where: { $0.time.isFinite == false || $0.value.isFinite == false }) {
            issues.append("Actuation curve points must be finite numbers.")
        }
        if zip(points, points.dropFirst()).contains(where: { pair in pair.0.time >= pair.1.time }) {
            issues.append("Actuation curve times must increase strictly.")
        }
        if timeBasis == .normalized && points.contains(where: { !(0...1).contains($0.time) }) {
            issues.append("Normalized actuation times must remain between 0 and 1.")
        }
        if let durationSeconds, durationSeconds <= 0 || durationSeconds.isFinite == false {
            issues.append("Actuation duration must be a positive finite value.")
        }
        if let samplingRateHz, samplingRateHz <= 0 || samplingRateHz.isFinite == false {
            issues.append("Actuation sampling rate must be a positive finite value.")
        }
        if let uncertainty, uncertainty < 0 || uncertainty.isFinite == false {
            issues.append("Actuation uncertainty must be a non-negative finite value.")
        }
        if [.controllerCommanded, .sensorObserved].contains(evidenceSource),
           deviceID == nil,
           deviceLabel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append("Controller- or sensor-derived curves require a device identity.")
        }
        return issues
    }

    public static func preset(
        kind: ActuationCurveKind,
        startValue: Double,
        endValue: Double,
        durationSeconds: Double?,
        evidenceSource: ActuationEvidenceSource = .operatorPlanned
    ) -> ActuationCurve {
        let sampleTimes: [Double]
        switch kind {
        case .stepped: sampleTimes = [0, 0.499, 0.5, 1]
        case .impulse: sampleTimes = [0, 0.08, 0.16, 1]
        default: sampleTimes = stride(from: 0.0, through: 1.0, by: 0.125).map { $0 }
        }
        let points = sampleTimes.map { time -> ActuationCurvePoint in
            let progress: Double = switch kind {
            case .linear, .custom: time
            case .easeIn: time * time
            case .easeOut: 1 - pow(1 - time, 2)
            case .smoothSCurve: time * time * (3 - 2 * time)
            case .stepped: time < 0.5 ? 0 : 1
            case .impulse: time <= 0.08 ? time / 0.08 : (time <= 0.16 ? (0.16 - time) / 0.08 : 0)
            }
            return ActuationCurvePoint(time: time, value: startValue + (endValue - startValue) * progress)
        }
        return ActuationCurve(
            kind: kind,
            timeBasis: .normalized,
            interpolation: kind == .stepped ? .step : .linear,
            points: points,
            durationSeconds: durationSeconds,
            evidenceSource: evidenceSource
        )
    }
}

public struct ActuationProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var quantity: ActuationQuantity
    public var customQuantityLabel: String?
    public var unit: String
    public var minimumValue: Double?
    public var maximumValue: Double?
    public var commandedCurve: ActuationCurve
    public var notes: String

    public init(
        id: UUID = UUID(),
        quantity: ActuationQuantity = .actionProgress,
        customQuantityLabel: String? = nil,
        unit: String = "normalized 0–1",
        minimumValue: Double? = 0,
        maximumValue: Double? = 1,
        commandedCurve: ActuationCurve,
        notes: String = ""
    ) {
        self.id = id
        self.quantity = quantity
        self.customQuantityLabel = customQuantityLabel
        self.unit = unit
        self.minimumValue = minimumValue
        self.maximumValue = maximumValue
        self.commandedCurve = commandedCurve
        self.notes = notes
    }

    public var quantityLabel: String {
        quantity == .custom ? (customQuantityLabel ?? quantity.displayName) : quantity.displayName
    }

    public var validationIssues: [String] {
        var issues = commandedCurve.validationIssues
        if unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("An actuation quantity requires a unit.")
        }
        if quantity == .custom,
           customQuantityLabel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            issues.append("A custom actuation quantity requires a label.")
        }
        if let minimumValue, minimumValue.isFinite == false {
            issues.append("The minimum actuation value must be finite.")
        }
        if let maximumValue, maximumValue.isFinite == false {
            issues.append("The maximum actuation value must be finite.")
        }
        if let minimumValue, let maximumValue, minimumValue >= maximumValue {
            issues.append("The maximum actuation value must be greater than the minimum.")
        }
        if let minimumValue,
           commandedCurve.points.contains(where: { $0.value < minimumValue }) {
            issues.append("Actuation curve values fall below the documented minimum.")
        }
        if let maximumValue,
           commandedCurve.points.contains(where: { $0.value > maximumValue }) {
            issues.append("Actuation curve values exceed the documented maximum.")
        }
        return issues
    }
}

public struct InstrumentNoiseConfiguration: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var label: String
    public var fromPosition: String?
    public var toPosition: String?
    public var pedalActuationIncluded: Bool
    public var details: [String: String]

    public init(
        id: UUID = UUID(),
        label: String = "Standard configuration",
        fromPosition: String? = nil,
        toPosition: String? = nil,
        pedalActuationIncluded: Bool = false,
        details: [String: String] = [:]
    ) {
        self.id = id
        self.label = label
        self.fromPosition = fromPosition
        self.toPosition = toPosition
        self.pedalActuationIncluded = pedalActuationIncluded
        self.details = details
    }
}

/// A single independently recordable protocol variant. Separate roadmap items
/// are created for direction, velocity, and configuration combinations so that
/// every take remains unambiguous and variability can be retained.
public struct InstrumentNoiseCaptureProtocol: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var version: Int
    public var kind: InstrumentNoiseKind
    public var name: String
    public var sourceComponentID: String
    public var sourceScope: AcousticSourceScope
    public var mechanisms: [AcousticMechanism]
    public var temporalBehavior: AcousticTemporalBehavior
    public var operatingPhase: AcousticOperatingPhase
    public var role: AcousticEventRole
    public var action: InstrumentNoiseAction
    public var velocity: InstrumentControlVelocity?
    public var configuration: InstrumentNoiseConfiguration
    public var minimumAcceptedTakeCount: Int
    public var captureDurationSeconds: Double
    public var actuationProfile: ActuationProfile?
    public var instructions: String

    public init(
        id: UUID = UUID(),
        version: Int = 1,
        kind: InstrumentNoiseKind,
        name: String,
        sourceComponentID: String,
        sourceScope: AcousticSourceScope = .instrument,
        mechanisms: [AcousticMechanism] = [.mechanical],
        temporalBehavior: AcousticTemporalBehavior,
        operatingPhase: AcousticOperatingPhase,
        role: AcousticEventRole = .intendedTarget,
        action: InstrumentNoiseAction,
        velocity: InstrumentControlVelocity? = nil,
        configuration: InstrumentNoiseConfiguration = InstrumentNoiseConfiguration(),
        minimumAcceptedTakeCount: Int = 1,
        captureDurationSeconds: Double = 6,
        actuationProfile: ActuationProfile? = nil,
        instructions: String = ""
    ) {
        self.id = id
        self.version = version
        self.kind = kind
        self.name = name
        self.sourceComponentID = sourceComponentID
        self.sourceScope = sourceScope
        self.mechanisms = mechanisms.isEmpty ? [.unknown] : Array(Set(mechanisms)).sorted { $0.rawValue < $1.rawValue }
        self.temporalBehavior = temporalBehavior
        self.operatingPhase = operatingPhase
        self.role = role
        self.action = action
        self.velocity = velocity
        self.configuration = configuration
        self.minimumAcceptedTakeCount = max(1, minimumAcceptedTakeCount)
        self.captureDurationSeconds = max(1, captureDurationSeconds)
        self.actuationProfile = actuationProfile
        self.instructions = instructions
    }

    public var variantLabel: String {
        [action.displayName, velocity?.label, configuration.label]
            .compactMap { value in
                guard let value, value.isEmpty == false, value != "Standard configuration" else { return nil }
                return value
            }
            .joined(separator: " · ")
    }
}

public enum InstrumentNoiseEventMarker: String, Codable, CaseIterable, Identifiable, Sendable {
    case actionBegin
    case actionEnd
    case actuationSample
    case notableVariation

    public var id: String { rawValue }
}

public struct InstrumentNoiseEventAnnotation: Codable, Hashable, Sendable {
    public var protocolID: UUID
    public var marker: InstrumentNoiseEventMarker
    public var kind: InstrumentNoiseKind
    public var action: InstrumentNoiseAction
    public var sourceScope: AcousticSourceScope
    public var mechanisms: [AcousticMechanism]
    public var temporalBehavior: AcousticTemporalBehavior
    public var operatingPhase: AcousticOperatingPhase
    public var role: AcousticEventRole
    public var observedActuationValue: Double?
    public var actuationUnit: String?

    public init(
        protocolSnapshot: InstrumentNoiseCaptureProtocol,
        marker: InstrumentNoiseEventMarker,
        observedActuationValue: Double? = nil,
        actuationUnit: String? = nil
    ) {
        self.protocolID = protocolSnapshot.id
        self.marker = marker
        self.kind = protocolSnapshot.kind
        self.action = protocolSnapshot.action
        self.sourceScope = protocolSnapshot.sourceScope
        self.mechanisms = protocolSnapshot.mechanisms
        self.temporalBehavior = protocolSnapshot.temporalBehavior
        self.operatingPhase = protocolSnapshot.operatingPhase
        self.role = protocolSnapshot.role
        self.observedActuationValue = observedActuationValue
        self.actuationUnit = actuationUnit
    }
}

public struct InstrumentNoiseTakeParadata: Codable, Hashable, Sendable {
    public var protocolSnapshot: InstrumentNoiseCaptureProtocol
    public var repetitionNumber: Int
    public var actionBeginSeconds: Double?
    public var actionEndSeconds: Double?
    public var actualVelocityLabel: String?
    public var actualNormalizedVelocity: Double?
    public var actualDurationSeconds: Double?
    public var observedActuationCurve: ActuationCurve?
    public var notes: String

    public init(
        protocolSnapshot: InstrumentNoiseCaptureProtocol,
        repetitionNumber: Int,
        actionBeginSeconds: Double? = nil,
        actionEndSeconds: Double? = nil,
        actualVelocityLabel: String? = nil,
        actualNormalizedVelocity: Double? = nil,
        actualDurationSeconds: Double? = nil,
        observedActuationCurve: ActuationCurve? = nil,
        notes: String = ""
    ) {
        self.protocolSnapshot = protocolSnapshot
        self.repetitionNumber = max(1, repetitionNumber)
        self.actionBeginSeconds = actionBeginSeconds
        self.actionEndSeconds = actionEndSeconds
        self.actualVelocityLabel = actualVelocityLabel
        self.actualNormalizedVelocity = actualNormalizedVelocity.map { min(max($0, 0), 1) }
        self.actualDurationSeconds = actualDurationSeconds
        self.observedActuationCurve = observedActuationCurve
        self.notes = notes
    }
}

public struct CaptureRecipe: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var version: Int
    public var techniques: [CaptureTechnique]
    public var preRollSeconds: Double
    public var sustainSeconds: Double
    public var releaseSeconds: Double
    public var chromaticStep: Int

    public init(
        id: UUID = UUID(),
        name: String = "Isolated stop documentation",
        version: Int = 1,
        techniques: [CaptureTechnique] = CaptureTechnique.allCases,
        preRollSeconds: Double = 1,
        sustainSeconds: Double = 4,
        releaseSeconds: Double = 4,
        chromaticStep: Int = 1
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.techniques = techniques
        self.preRollSeconds = preRollSeconds
        self.sustainSeconds = sustainSeconds
        self.releaseSeconds = releaseSeconds
        self.chromaticStep = chromaticStep
    }
}

public struct RegistrationState: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var revision: Int
    public var activatedStops: [ComponentLocator]
    public var activatedCouplers: [ComponentLocator]
    public var activatedAccessories: [ComponentLocator]
    public var notes: String
    public var name: String?
    public var purpose: String?

    public init(
        id: UUID = UUID(),
        revision: Int = 1,
        activatedStops: [ComponentLocator] = [],
        activatedCouplers: [ComponentLocator] = [],
        activatedAccessories: [ComponentLocator] = [],
        notes: String = "",
        name: String? = nil,
        purpose: String? = nil
    ) {
        self.id = id
        self.revision = revision
        self.activatedStops = activatedStops
        self.activatedCouplers = activatedCouplers
        self.activatedAccessories = activatedAccessories
        self.notes = notes
        self.name = name
        self.purpose = purpose
    }
}

public enum RoadmapCoverageKind: String, Codable, CaseIterable, Sendable {
    case isolatedStop
    case explicitPipe
    case couplerEffect
    case accessoryEffect
    case customRegistration
    case instrumentNoise
    case tonalPercussion
    case atonalPercussion
    case sustainedEffect
    case oneShotEffect
    case repeatingEffect
    case sequencedEffect
    case compositeEffect
    case otherSoundingElement
    case physicalIntensityResponse
    case processBehavior
    case shutterMapping
    case tremulantResponse
    case operationalBaseline
    case spatialAcousticResponse
}

public struct RoadmapCompilationReport: Codable, Hashable, Sendable {
    public var compilerContract: String
    public var sourceStopCount: Int
    public var sourceCouplerCount: Int
    public var sourceAccessoryCount: Int
    public var sourceDivisionCount: Int?
    public var sourceKeyboardCount: Int?
    public var sourceRankCount: Int?
    public var explicitPipePositionCount: Int
    public var generatedAtomicSoundCount: Int
    public var generatedControlTestCount: Int
    public var theoreticalRegistrationStateCount: String
    public var assumedCompassCount: Int
    public var warnings: [String]
    public var referencePitchHz: Double?
    public var tuningPitchAssumed: Bool?
    public var temperament: String?
    public var logicalSoundAddressCount: Int?
    public var physicalSoundTargetCount: Int?
    public var sharedAliasCount: Int?
    public var unresolvedSharedCandidateCount: Int?
    public var generatedInstrumentNoiseCount: Int?
    public var generatedIntendedSoundTargetCount: Int?

    public init(
        compilerContract: String = "orgrec.modavis-roadmap-compiler/v5",
        sourceStopCount: Int,
        sourceCouplerCount: Int,
        sourceAccessoryCount: Int,
        sourceDivisionCount: Int? = nil,
        sourceKeyboardCount: Int? = nil,
        sourceRankCount: Int? = nil,
        explicitPipePositionCount: Int,
        generatedAtomicSoundCount: Int,
        generatedControlTestCount: Int,
        theoreticalRegistrationStateCount: String,
        assumedCompassCount: Int,
        warnings: [String] = [],
        referencePitchHz: Double? = nil,
        tuningPitchAssumed: Bool? = nil,
        temperament: String? = nil,
        logicalSoundAddressCount: Int? = nil,
        physicalSoundTargetCount: Int? = nil,
        sharedAliasCount: Int? = nil,
        unresolvedSharedCandidateCount: Int? = nil,
        generatedInstrumentNoiseCount: Int? = nil,
        generatedIntendedSoundTargetCount: Int? = nil
    ) {
        self.compilerContract = compilerContract
        self.sourceStopCount = sourceStopCount
        self.sourceCouplerCount = sourceCouplerCount
        self.sourceAccessoryCount = sourceAccessoryCount
        self.sourceDivisionCount = sourceDivisionCount
        self.sourceKeyboardCount = sourceKeyboardCount
        self.sourceRankCount = sourceRankCount
        self.explicitPipePositionCount = explicitPipePositionCount
        self.generatedAtomicSoundCount = generatedAtomicSoundCount
        self.generatedControlTestCount = generatedControlTestCount
        self.theoreticalRegistrationStateCount = theoreticalRegistrationStateCount
        self.assumedCompassCount = assumedCompassCount
        self.warnings = warnings
        self.referencePitchHz = referencePitchHz
        self.tuningPitchAssumed = tuningPitchAssumed
        self.temperament = temperament
        self.logicalSoundAddressCount = logicalSoundAddressCount
        self.physicalSoundTargetCount = physicalSoundTargetCount
        self.sharedAliasCount = sharedAliasCount
        self.unresolvedSharedCandidateCount = unresolvedSharedCandidateCount
        self.generatedInstrumentNoiseCount = generatedInstrumentNoiseCount
        self.generatedIntendedSoundTargetCount = generatedIntendedSoundTargetCount
    }
}

public struct DeviceInstance: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case audioInterface, microphone, controller, sensor }

    public var id: UUID
    public var kind: Kind
    public var manufacturer: String
    public var model: String
    public var serialNumber: String
    public var modavisManifestationID: String?
    public var details: [String: String]

    public init(
        id: UUID = UUID(),
        kind: Kind,
        manufacturer: String,
        model: String,
        serialNumber: String = "",
        modavisManifestationID: String? = nil,
        details: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.manufacturer = manufacturer
        self.model = model
        self.serialNumber = serialNumber
        self.modavisManifestationID = modavisManifestationID
        self.details = details
    }

    public var displayName: String {
        [manufacturer, model].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

public struct MicrophonePlacement: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var microphoneID: UUID
    public var channelNumber: Int
    public var role: String
    public var xMeters: Double
    public var yMeters: Double
    public var zMeters: Double
    public var yawDegrees: Double
    public var pitchDegrees: Double
    public var rollDegrees: Double
    public var gainDB: Double
    public var phantomPower: Bool

    public init(
        id: UUID = UUID(),
        microphoneID: UUID,
        channelNumber: Int,
        role: String,
        xMeters: Double,
        yMeters: Double,
        zMeters: Double,
        yawDegrees: Double = 0,
        pitchDegrees: Double = 0,
        rollDegrees: Double = 0,
        gainDB: Double = 0,
        phantomPower: Bool = false
    ) {
        self.id = id
        self.microphoneID = microphoneID
        self.channelNumber = channelNumber
        self.role = role
        self.xMeters = xMeters
        self.yMeters = yMeters
        self.zMeters = zMeters
        self.yawDegrees = yawDegrees
        self.pitchDegrees = pitchDegrees
        self.rollDegrees = rollDegrees
        self.gainDB = gainDB
        self.phantomPower = phantomPower
    }
}

public struct EnvironmentReading: Codable, Hashable, Sendable {
    public var temperatureCelsius: Double?
    public var relativeHumidityPercent: Double?
    public var pressureHPa: Double?
    public var notes: String

    public init(temperatureCelsius: Double? = nil, relativeHumidityPercent: Double? = nil, pressureHPa: Double? = nil, notes: String = "") {
        self.temperatureCelsius = temperatureCelsius
        self.relativeHumidityPercent = relativeHumidityPercent
        self.pressureHPa = pressureHPa
        self.notes = notes
    }
}

public struct MicrophoneSetup: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var revision: Int
    public var name: String
    public var coordinateOrigin: String
    public var arrayGeometry: String
    public var interfaceDeviceID: UUID?
    public var placements: [MicrophonePlacement]
    public var environment: EnvironmentReading
    public var documentationPaths: [String]
    public var referenceChannelNumber: Int?

    public init(
        id: UUID = UUID(),
        revision: Int = 1,
        name: String,
        coordinateOrigin: String = "Organ façade center",
        arrayGeometry: String = "",
        interfaceDeviceID: UUID? = nil,
        placements: [MicrophonePlacement] = [],
        environment: EnvironmentReading = EnvironmentReading(),
        documentationPaths: [String] = [],
        referenceChannelNumber: Int? = 1
    ) {
        self.id = id
        self.revision = revision
        self.name = name
        self.coordinateOrigin = coordinateOrigin
        self.arrayGeometry = arrayGeometry
        self.interfaceDeviceID = interfaceDeviceID
        self.placements = placements
        self.environment = environment
        self.documentationPaths = documentationPaths
        self.referenceChannelNumber = referenceChannelNumber
    }
}

public struct RoadmapItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var component: OrganComponent
    public var technique: CaptureTechnique
    public var recipeID: UUID
    public var setupID: UUID?
    public var registrationID: UUID?
    public var state: RoadmapState
    public var required: Bool
    public var takeIDs: [UUID]
    public var coverageKind: RoadmapCoverageKind?
    public var instructions: String?
    public var physicalSoundTargetID: String?
    public var primaryActivationRouteID: String?
    public var activationRoutes: [PhysicalActivationRoute]?
    public var instrumentNoiseProtocol: InstrumentNoiseCaptureProtocol?
    public var soundingTargetDefinition: SoundingTargetDefinition?
    public var complexCaptureProtocol: ComplexCaptureProtocol?
    public var spatialAcousticProtocol: SpatialAcousticCaptureProtocol?
    public var effectAnalysisProtocol: NonPitchedEffectAnalysisProtocol?
    public var requiredCaptureStateID: UUID?
    public var requiredCaptureStateFingerprint: String?
    /// Legacy/portable inline form. New projects use the normalized project
    /// state library plus `requiredCaptureStateID` and fingerprint.
    public var requiredCaptureState: CaptureStateSnapshot?

    public init(
        id: UUID = UUID(),
        component: OrganComponent,
        technique: CaptureTechnique,
        recipeID: UUID,
        setupID: UUID? = nil,
        registrationID: UUID? = nil,
        state: RoadmapState = .missing,
        required: Bool = true,
        takeIDs: [UUID] = [],
        coverageKind: RoadmapCoverageKind? = nil,
        instructions: String? = nil,
        physicalSoundTargetID: String? = nil,
        primaryActivationRouteID: String? = nil,
        activationRoutes: [PhysicalActivationRoute]? = nil,
        instrumentNoiseProtocol: InstrumentNoiseCaptureProtocol? = nil,
        soundingTargetDefinition: SoundingTargetDefinition? = nil,
        complexCaptureProtocol: ComplexCaptureProtocol? = nil,
        spatialAcousticProtocol: SpatialAcousticCaptureProtocol? = nil,
        effectAnalysisProtocol: NonPitchedEffectAnalysisProtocol? = nil,
        requiredCaptureStateID: UUID? = nil,
        requiredCaptureStateFingerprint: String? = nil,
        requiredCaptureState: CaptureStateSnapshot? = nil
    ) {
        self.id = id
        self.component = component
        self.technique = technique
        self.recipeID = recipeID
        self.setupID = setupID
        self.registrationID = registrationID
        self.state = state
        self.required = required
        self.takeIDs = takeIDs
        self.coverageKind = coverageKind
        self.instructions = instructions
        self.physicalSoundTargetID = physicalSoundTargetID
        self.primaryActivationRouteID = primaryActivationRouteID
        self.activationRoutes = activationRoutes
        self.instrumentNoiseProtocol = instrumentNoiseProtocol
        self.soundingTargetDefinition = soundingTargetDefinition
        self.complexCaptureProtocol = complexCaptureProtocol
        self.spatialAcousticProtocol = spatialAcousticProtocol
        self.effectAnalysisProtocol = effectAnalysisProtocol
        self.requiredCaptureStateID = requiredCaptureStateID
        self.requiredCaptureStateFingerprint = requiredCaptureStateFingerprint
        self.requiredCaptureState = requiredCaptureState
    }

    public var minimumAcceptedTakeCount: Int {
        spatialAcousticProtocol?.minimumAcceptedTakeCount ?? complexCaptureProtocol?.minimumAcceptedTakeCount ?? instrumentNoiseProtocol?.minimumAcceptedTakeCount ?? soundingTargetDefinition?.minimumAcceptedTakeCount ?? 1
    }
}

public enum PitchAnalysisApplicability: String, Codable, CaseIterable, Sendable {
    case monophonic
    case polyphonic
    case nonPitched
    case indeterminate
}

public enum BoundaryEvidenceState: String, Codable, CaseIterable, Sendable {
    case observed
    case leftCensored
    case rightCensored
    case unresolved
    case notApplicable
}

public struct AnalysisBoundaryEvidence: Codable, Hashable, Identifiable, Sendable {
    public var id: AnalysisMarkerKind { marker }
    public var marker: AnalysisMarkerKind
    public var seconds: Double?
    public var confidence: Double
    public var state: BoundaryEvidenceState
    public var contributingFeatures: [String]
    public var timeResolutionSeconds: Double?

    public init(
        marker: AnalysisMarkerKind,
        seconds: Double? = nil,
        confidence: Double = 0,
        state: BoundaryEvidenceState = .unresolved,
        contributingFeatures: [String] = [],
        timeResolutionSeconds: Double? = nil
    ) {
        self.marker = marker
        self.seconds = seconds
        self.confidence = confidence
        self.state = state
        self.contributingFeatures = contributingFeatures
        self.timeResolutionSeconds = timeResolutionSeconds
    }
}

public struct PitchTrackPoint: Codable, Hashable, Sendable {
    public var timeSeconds: Double
    public var frequencyHz: Double?
    public var confidence: Double
    public var voiced: Bool
    public var estimator: String
    public var centsFromExpected: Double?

    public init(
        timeSeconds: Double,
        frequencyHz: Double?,
        confidence: Double,
        voiced: Bool,
        estimator: String,
        centsFromExpected: Double? = nil
    ) {
        self.timeSeconds = timeSeconds
        self.frequencyHz = frequencyHz
        self.confidence = confidence
        self.voiced = voiced
        self.estimator = estimator
        self.centsFromExpected = centsFromExpected
    }
}

public struct PitchTrackSummary: Codable, Hashable, Sendable {
    public var frameCount: Int
    public var voicedFrameCount: Int
    public var voicedRatio: Double
    public var medianFrequencyHz: Double?
    public var medianConfidence: Double?
    public var interquartileRangeCents: Double?
    public var medianAbsoluteDeviationCents: Double?
    public var driftCentsPerSecond: Double?
    public var modulationRateHz: Double?
    public var modulationDepthCents: Double?
    public var lowerUncertaintyCents: Double?
    public var upperUncertaintyCents: Double?
    public var suspectedOctaveErrorCount: Int
    public var estimatorAgreementCents: Double?

    public init(
        frameCount: Int,
        voicedFrameCount: Int,
        voicedRatio: Double,
        medianFrequencyHz: Double? = nil,
        medianConfidence: Double? = nil,
        interquartileRangeCents: Double? = nil,
        medianAbsoluteDeviationCents: Double? = nil,
        driftCentsPerSecond: Double? = nil,
        modulationRateHz: Double? = nil,
        modulationDepthCents: Double? = nil,
        lowerUncertaintyCents: Double? = nil,
        upperUncertaintyCents: Double? = nil,
        suspectedOctaveErrorCount: Int = 0,
        estimatorAgreementCents: Double? = nil
    ) {
        self.frameCount = frameCount
        self.voicedFrameCount = voicedFrameCount
        self.voicedRatio = voicedRatio
        self.medianFrequencyHz = medianFrequencyHz
        self.medianConfidence = medianConfidence
        self.interquartileRangeCents = interquartileRangeCents
        self.medianAbsoluteDeviationCents = medianAbsoluteDeviationCents
        self.driftCentsPerSecond = driftCentsPerSecond
        self.modulationRateHz = modulationRateHz
        self.modulationDepthCents = modulationDepthCents
        self.lowerUncertaintyCents = lowerUncertaintyCents
        self.upperUncertaintyCents = upperUncertaintyCents
        self.suspectedOctaveErrorCount = suspectedOctaveErrorCount
        self.estimatorAgreementCents = estimatorAgreementCents
    }
}

public enum PitchEstimatorMismatchSeverity: String, Codable, CaseIterable, Sendable {
    case agreement
    case material
    case critical
    case unavailable
}

public struct PitchEstimatorEvidence: Codable, Hashable, Identifiable, Sendable {
    public var id: String { estimator }
    public var estimator: String
    public var frequencyHz: Double
    public var confidence: Double
    public var algorithmVersion: String
    public var voicedFrameRatio: Double?

    public init(
        estimator: String,
        frequencyHz: Double,
        confidence: Double,
        algorithmVersion: String,
        voicedFrameRatio: Double? = nil
    ) {
        self.estimator = estimator
        self.frequencyHz = frequencyHz
        self.confidence = confidence
        self.algorithmVersion = algorithmVersion
        self.voicedFrameRatio = voicedFrameRatio
    }
}

/// A retained comparison rather than a silently fused result. `differenceCents`
/// specifically compares CREPE and pYIN when both are available.
public struct PitchEstimatorComparison: Codable, Hashable, Sendable {
    public var estimates: [PitchEstimatorEvidence]
    public var differenceCents: Double?
    public var severity: PitchEstimatorMismatchSeverity
    public var selectedEstimator: String?
    public var selectedFrequencyHz: Double?
    public var rationale: String

    public init(
        estimates: [PitchEstimatorEvidence],
        differenceCents: Double? = nil,
        severity: PitchEstimatorMismatchSeverity,
        selectedEstimator: String? = nil,
        selectedFrequencyHz: Double? = nil,
        rationale: String
    ) {
        self.estimates = estimates
        self.differenceCents = differenceCents
        self.severity = severity
        self.selectedEstimator = selectedEstimator
        self.selectedFrequencyHz = selectedFrequencyHz
        self.rationale = rationale
    }
}

public struct ChannelRelationshipEvidence: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { channelIndex }
    public var channelIndex: Int
    public var levelDifferenceDB: Double
    public var correlationWithReference: Double?
    public var delaySamples: Int?
    public var polarityInversionSuspected: Bool

    public init(
        channelIndex: Int,
        levelDifferenceDB: Double,
        correlationWithReference: Double? = nil,
        delaySamples: Int? = nil,
        polarityInversionSuspected: Bool = false
    ) {
        self.channelIndex = channelIndex
        self.levelDifferenceDB = levelDifferenceDB
        self.correlationWithReference = correlationWithReference
        self.delaySamples = delaySamples
        self.polarityInversionSuspected = polarityInversionSuspected
    }
}

public struct AnalysisRunRecord: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var inputSHA256: String
    public var algorithmVersion: String
    public var startedAt: Date
    public var finishedAt: Date
    public var referenceChannel: Int
    public var parameters: [String: String]
    public var parameterSHA256: String?
    public var pitchApplicability: PitchAnalysisApplicability
    public var warnings: [String]
    public var outputSummary: AnalysisSummary?
    public var artifactRelativePaths: [String]?
    public var pitchTrackSHA256: String?
    public var partialTracksSHA256: String?
    public var software: OrgRecSoftwareMetadata?

    public init(
        contractVersion: String = "orgrec-analysis-run/2",
        id: UUID = UUID(),
        inputSHA256: String,
        algorithmVersion: String = "orgrec-analysis/2",
        startedAt: Date,
        finishedAt: Date = .now,
        referenceChannel: Int,
        parameters: [String: String],
        parameterSHA256: String? = nil,
        pitchApplicability: PitchAnalysisApplicability,
        warnings: [String] = [],
        outputSummary: AnalysisSummary? = nil,
        artifactRelativePaths: [String]? = nil,
        pitchTrackSHA256: String? = nil,
        partialTracksSHA256: String? = nil,
        software: OrgRecSoftwareMetadata? = OrgRecSoftware.current
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.inputSHA256 = inputSHA256
        self.algorithmVersion = algorithmVersion
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.referenceChannel = referenceChannel
        self.parameters = parameters
        self.parameterSHA256 = parameterSHA256
        self.pitchApplicability = pitchApplicability
        self.warnings = warnings
        self.outputSummary = outputSummary
        self.artifactRelativePaths = artifactRelativePaths
        self.pitchTrackSHA256 = pitchTrackSHA256
        self.partialTracksSHA256 = partialTracksSHA256
        self.software = software
    }
}

public struct PipeSpectralSummary: Codable, Hashable, Sendable {
    public var detectedPartialCount: Int
    public var spectralCentroidHz: Double?
    public var spectralRolloff85Hz: Double?
    public var oddEvenEnergyRatioDB: Double?
    public var weightedInharmonicityCents: Double?
    public var partialAttackSpreadSeconds: Double?
    public var medianDecayRateDBPerSecond: Double?

    public init(
        detectedPartialCount: Int,
        spectralCentroidHz: Double? = nil,
        spectralRolloff85Hz: Double? = nil,
        oddEvenEnergyRatioDB: Double? = nil,
        weightedInharmonicityCents: Double? = nil,
        partialAttackSpreadSeconds: Double? = nil,
        medianDecayRateDBPerSecond: Double? = nil
    ) {
        self.detectedPartialCount = detectedPartialCount
        self.spectralCentroidHz = spectralCentroidHz
        self.spectralRolloff85Hz = spectralRolloff85Hz
        self.oddEvenEnergyRatioDB = oddEvenEnergyRatioDB
        self.weightedInharmonicityCents = weightedInharmonicityCents
        self.partialAttackSpreadSeconds = partialAttackSpreadSeconds
        self.medianDecayRateDBPerSecond = medianDecayRateDBPerSecond
    }
}

public enum LoopPointSetStatus: String, Codable, CaseIterable, Sendable {
    case proposed
    case asserted
    case accepted
    case rejected
    case superseded
}

public enum AudioLoopRole: String, Codable, CaseIterable, Sendable {
    case sustain
    case release
}

public enum AudioLoopMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case forward
    case alternating
    case backward

    public var id: String { rawValue }
}

public enum LoopExitPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case crossfadeToRecordedRelease
    case envelopeRelease
    case finishCycleThenRelease

    public var id: String { rawValue }
}

public enum LoopabilityClass: String, Codable, CaseIterable, Sendable {
    case notAssessed
    case stablePeriodic
    case modulated
    case drifting
    case quasiPeriodic
    case unsuitable
}

public enum PlaybackEnvelopeCurve: String, Codable, CaseIterable, Identifiable, Sendable {
    case equalPower
    case linear

    public var id: String { rawValue }
}

/// Runtime articulation is deliberately separate from loop coordinates: a
/// researcher can accept the same evidence-backed region for several playback
/// envelopes without changing the underlying sample selection.
public struct SustainPlaybackEnvelope: Codable, Hashable, Sendable {
    public var attackSeconds: Double
    public var releaseSeconds: Double
    public var sustainLevel: Double
    public var curve: PlaybackEnvelopeCurve

    public init(
        attackSeconds: Double = 0.008,
        releaseSeconds: Double = 0.35,
        sustainLevel: Double = 1,
        curve: PlaybackEnvelopeCurve = .equalPower
    ) {
        self.attackSeconds = attackSeconds
        self.releaseSeconds = releaseSeconds
        self.sustainLevel = sustainLevel
        self.curve = curve
    }
}

/// Components are retained alongside the aggregate score so future weighting
/// changes can re-rank a detector run without pretending it produced new raw
/// evidence. All values are normalized penalties where zero is ideal.
public struct LoopScoreBreakdown: Codable, Hashable, Sendable {
    public var waveformMismatch: Double
    public var derivativeMismatch: Double
    public var spectralMismatch: Double
    public var partialPhaseMismatch: Double
    public var levelMismatch: Double
    public var pitchMismatch: Double
    public var stationarityPenalty: Double
    public var channelMismatch: Double
    public var repetitionPenalty: Double
    public var total: Double

    public init(
        waveformMismatch: Double,
        derivativeMismatch: Double,
        spectralMismatch: Double,
        partialPhaseMismatch: Double,
        levelMismatch: Double,
        pitchMismatch: Double,
        stationarityPenalty: Double,
        channelMismatch: Double,
        repetitionPenalty: Double,
        total: Double
    ) {
        self.waveformMismatch = waveformMismatch
        self.derivativeMismatch = derivativeMismatch
        self.spectralMismatch = spectralMismatch
        self.partialPhaseMismatch = partialPhaseMismatch
        self.levelMismatch = levelMismatch
        self.pitchMismatch = pitchMismatch
        self.stationarityPenalty = stationarityPenalty
        self.channelMismatch = channelMismatch
        self.repetitionPenalty = repetitionPenalty
        self.total = total
    }
}

/// Half-open sample-clock region `[startFrameInclusive, endFrameExclusive)`.
/// Seconds are derived for presentation only; exact frame coordinates remain
/// authoritative and map to WAVE `smpl` by subtracting one from the end frame.
public struct AudioLoopRegion: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var role: AudioLoopRole
    public var startFrameInclusive: Int64
    public var endFrameExclusive: Int64
    public var mode: AudioLoopMode
    public var repeatCount: Int?
    public var crossfadeFrames: Int64
    public var exitPolicy: LoopExitPolicy
    public var releaseStartFrame: Int64?
    public var score: LoopScoreBreakdown?

    public init(
        id: UUID = UUID(),
        role: AudioLoopRole = .sustain,
        startFrameInclusive: Int64,
        endFrameExclusive: Int64,
        mode: AudioLoopMode = .forward,
        repeatCount: Int? = nil,
        crossfadeFrames: Int64 = 0,
        exitPolicy: LoopExitPolicy = .crossfadeToRecordedRelease,
        releaseStartFrame: Int64? = nil,
        score: LoopScoreBreakdown? = nil
    ) {
        self.id = id
        self.role = role
        self.startFrameInclusive = startFrameInclusive
        self.endFrameExclusive = endFrameExclusive
        self.mode = mode
        self.repeatCount = repeatCount
        self.crossfadeFrames = crossfadeFrames
        self.exitPolicy = exitPolicy
        self.releaseStartFrame = releaseStartFrame
        self.score = score
    }

    public var frameCount: Int64 { max(0, endFrameExclusive - startFrameInclusive) }

    public func startSeconds(sampleRate: Double) -> Double {
        sampleRate > 0 ? Double(startFrameInclusive) / sampleRate : 0
    }

    public func endSeconds(sampleRate: Double) -> Double {
        sampleRate > 0 ? Double(endFrameExclusive) / sampleRate : 0
    }
}

public struct LoopPointSet: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var sourceAudioSHA256: String
    public var sampleRate: Double
    public var channelCount: Int
    public var totalFrames: Int64
    public var status: LoopPointSetStatus
    public var loopability: LoopabilityClass
    public var regions: [AudioLoopRegion]
    public var envelope: SustainPlaybackEnvelope
    public var candidateRank: Int?
    public var confidence: Double
    public var algorithm: String
    public var algorithmVersion: String
    public var parameters: [String: String]
    public var generatedAt: Date
    public var wasRevisionOf: UUID?
    public var reviewedAt: Date?
    public var reviewedBy: String?
    public var reviewReason: String?
    public var qualityFlags: [String]

    public init(
        contractVersion: String = "orgrec-loop-point-set/1",
        id: UUID = UUID(),
        sourceAudioSHA256: String,
        sampleRate: Double,
        channelCount: Int,
        totalFrames: Int64,
        status: LoopPointSetStatus = .proposed,
        loopability: LoopabilityClass,
        regions: [AudioLoopRegion],
        envelope: SustainPlaybackEnvelope = SustainPlaybackEnvelope(),
        candidateRank: Int? = nil,
        confidence: Double,
        algorithm: String = "OrgRec multichannel periodic seam search",
        algorithmVersion: String = "orgrec-loop-detector/1",
        parameters: [String: String] = [:],
        generatedAt: Date = .now,
        wasRevisionOf: UUID? = nil,
        reviewedAt: Date? = nil,
        reviewedBy: String? = nil,
        reviewReason: String? = nil,
        qualityFlags: [String] = []
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.sourceAudioSHA256 = sourceAudioSHA256
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.totalFrames = totalFrames
        self.status = status
        self.loopability = loopability
        self.regions = regions
        self.envelope = envelope
        self.candidateRank = candidateRank
        self.confidence = confidence
        self.algorithm = algorithm
        self.algorithmVersion = algorithmVersion
        self.parameters = parameters
        self.generatedAt = generatedAt
        self.wasRevisionOf = wasRevisionOf
        self.reviewedAt = reviewedAt
        self.reviewedBy = reviewedBy
        self.reviewReason = reviewReason
        self.qualityFlags = qualityFlags
    }

    public var sustainRegion: AudioLoopRegion? { regions.first { $0.role == .sustain } }
}

public struct LoopPointReview: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var loopPointSetID: UUID
    public var resultingLoopPointSetID: UUID?
    public var decision: String
    public var author: String
    public var reason: String
    public var decidedAt: Date

    public init(
        id: UUID = UUID(),
        loopPointSetID: UUID,
        resultingLoopPointSetID: UUID? = nil,
        decision: String,
        author: String,
        reason: String,
        decidedAt: Date = .now
    ) {
        self.id = id
        self.loopPointSetID = loopPointSetID
        self.resultingLoopPointSetID = resultingLoopPointSetID
        self.decision = decision
        self.author = author
        self.reason = reason
        self.decidedAt = decidedAt
    }
}

/// Phase-resolved descriptors summarize behaviour rather than only global
/// level or pitch. Fields remain optional when the corresponding phase is
/// censored or the capture lacks enough evidence.
public struct PipeSoundBehaviorSummary: Codable, Hashable, Sendable {
    public var attackDurationSeconds: Double?
    public var attackDurationFundamentalPeriods: Double?
    public var partialOnsetOrder: [Int]
    public var sustainStationarity: Double?
    public var amplitudeModulationRateHz: Double?
    public var amplitudeModulationDepthDB: Double?
    public var frequencyModulationRateHz: Double?
    public var frequencyModulationDepthCents: Double?
    public var releaseDurationSeconds: Double?
    public var roomTailDurationSeconds: Double?
    public var partialDecayRateMADDBPerSecond: Double?
    public var meanInterchannelCorrelation: Double?
    public var loopability: LoopabilityClass?

    public init(
        attackDurationSeconds: Double? = nil,
        attackDurationFundamentalPeriods: Double? = nil,
        partialOnsetOrder: [Int] = [],
        sustainStationarity: Double? = nil,
        amplitudeModulationRateHz: Double? = nil,
        amplitudeModulationDepthDB: Double? = nil,
        frequencyModulationRateHz: Double? = nil,
        frequencyModulationDepthCents: Double? = nil,
        releaseDurationSeconds: Double? = nil,
        roomTailDurationSeconds: Double? = nil,
        partialDecayRateMADDBPerSecond: Double? = nil,
        meanInterchannelCorrelation: Double? = nil,
        loopability: LoopabilityClass? = nil
    ) {
        self.attackDurationSeconds = attackDurationSeconds
        self.attackDurationFundamentalPeriods = attackDurationFundamentalPeriods
        self.partialOnsetOrder = partialOnsetOrder
        self.sustainStationarity = sustainStationarity
        self.amplitudeModulationRateHz = amplitudeModulationRateHz
        self.amplitudeModulationDepthDB = amplitudeModulationDepthDB
        self.frequencyModulationRateHz = frequencyModulationRateHz
        self.frequencyModulationDepthCents = frequencyModulationDepthCents
        self.releaseDurationSeconds = releaseDurationSeconds
        self.roomTailDurationSeconds = roomTailDurationSeconds
        self.partialDecayRateMADDBPerSecond = partialDecayRateMADDBPerSecond
        self.meanInterchannelCorrelation = meanInterchannelCorrelation
        self.loopability = loopability
    }
}

public struct AnalysisSummary: Codable, Hashable, Sendable {
    public var method: String
    public var algorithmVersion: String
    public var onsetSeconds: Double?
    public var sustainStartSeconds: Double?
    public var keyUpSeconds: Double?
    public var soundOffsetSeconds: Double?
    public var tailEndSeconds: Double?
    public var frequencyHz: Double?
    public var confidence: Double?
    public var centsDeviation: Double?
    public var peakDBFS: Double?
    public var rmsDBFS: Double?
    public var clippedSamples: Int
    public var qualityFlags: [String]
    public var analyzedAt: Date
    public var contractVersion: String?
    public var analysisRunID: UUID?
    public var pitchApplicability: PitchAnalysisApplicability?
    public var pitchTrackSummary: PitchTrackSummary?
    public var boundaries: [AnalysisBoundaryEvidence]?
    public var signalToNoiseDB: Double?
    public var dcOffset: Double?
    public var nearClippedSamples: Int?
    public var channelRelationships: [ChannelRelationshipEvidence]?
    public var spectralSummary: PipeSpectralSummary?
    /// Auditory, broadband, harmonic, and slow-modulation descriptors from the
    /// stable sustain. Optional for backward compatibility and for captures
    /// without a defensible stable interval.
    public var perceptualSpectralSummary: PerceptualSpectralSummary?
    public var pitchEstimatorComparison: PitchEstimatorComparison?
    public var pipeSoundBehavior: PipeSoundBehaviorSummary?
    /// For ordinary note takes this is explicitly qualified as an observed
    /// pipe-plus-room release, never as a standards-compliant reverberation
    /// time. Declared impulse responses use the same evidence-rich contract.
    public var acousticResponseAnalysis: AcousticResponseAnalysis?
    public var detectedLoopPointSets: [LoopPointSet]?

    public init(
        method: String,
        algorithmVersion: String,
        onsetSeconds: Double? = nil,
        sustainStartSeconds: Double? = nil,
        keyUpSeconds: Double? = nil,
        soundOffsetSeconds: Double? = nil,
        tailEndSeconds: Double? = nil,
        frequencyHz: Double? = nil,
        confidence: Double? = nil,
        centsDeviation: Double? = nil,
        peakDBFS: Double? = nil,
        rmsDBFS: Double? = nil,
        clippedSamples: Int = 0,
        qualityFlags: [String] = [],
        analyzedAt: Date = Date(),
        contractVersion: String? = "orgrec-analysis-summary/2",
        analysisRunID: UUID? = nil,
        pitchApplicability: PitchAnalysisApplicability? = nil,
        pitchTrackSummary: PitchTrackSummary? = nil,
        boundaries: [AnalysisBoundaryEvidence]? = nil,
        signalToNoiseDB: Double? = nil,
        dcOffset: Double? = nil,
        nearClippedSamples: Int? = nil,
        channelRelationships: [ChannelRelationshipEvidence]? = nil,
        spectralSummary: PipeSpectralSummary? = nil,
        perceptualSpectralSummary: PerceptualSpectralSummary? = nil,
        pitchEstimatorComparison: PitchEstimatorComparison? = nil,
        pipeSoundBehavior: PipeSoundBehaviorSummary? = nil,
        acousticResponseAnalysis: AcousticResponseAnalysis? = nil,
        detectedLoopPointSets: [LoopPointSet]? = nil
    ) {
        self.method = method
        self.algorithmVersion = algorithmVersion
        self.onsetSeconds = onsetSeconds
        self.sustainStartSeconds = sustainStartSeconds
        self.keyUpSeconds = keyUpSeconds
        self.soundOffsetSeconds = soundOffsetSeconds
        self.tailEndSeconds = tailEndSeconds
        self.frequencyHz = frequencyHz
        self.confidence = confidence
        self.centsDeviation = centsDeviation
        self.peakDBFS = peakDBFS
        self.rmsDBFS = rmsDBFS
        self.clippedSamples = clippedSamples
        self.qualityFlags = qualityFlags
        self.analyzedAt = analyzedAt
        self.contractVersion = contractVersion
        self.analysisRunID = analysisRunID
        self.pitchApplicability = pitchApplicability
        self.pitchTrackSummary = pitchTrackSummary
        self.boundaries = boundaries
        self.signalToNoiseDB = signalToNoiseDB
        self.dcOffset = dcOffset
        self.nearClippedSamples = nearClippedSamples
        self.channelRelationships = channelRelationships
        self.spectralSummary = spectralSummary
        self.perceptualSpectralSummary = perceptualSpectralSummary
        self.pitchEstimatorComparison = pitchEstimatorComparison
        self.pipeSoundBehavior = pipeSoundBehavior
        self.acousticResponseAnalysis = acousticResponseAnalysis
        self.detectedLoopPointSets = detectedLoopPointSets
    }
}

public enum SpectralWindow: String, Codable, CaseIterable, Identifiable, Sendable {
    case hann = "Hann"
    case hamming = "Hamming"
    case blackmanHarris = "Blackman–Harris"

    public var id: String { rawValue }
}

public enum SpectralFrequencyScale: String, Codable, CaseIterable, Identifiable, Sendable {
    case linear = "Linear"
    case logarithmic = "Logarithmic"

    public var id: String { rawValue }
}

public struct SpectrogramConfiguration: Codable, Hashable, Sendable {
    public var fftSize: Int
    public var hopSize: Int
    public var window: SpectralWindow
    public var frequencyScale: SpectralFrequencyScale
    public var minimumFrequencyHz: Double
    public var maximumFrequencyHz: Double
    public var dynamicRangeDB: Double
    public var maximumTimeBins: Int
    public var maximumAnalysisDurationSeconds: Double
    public var displayFrequencyBins: Int
    public var partialCount: Int
    public var partialSearchCents: Double
    public var partialOnsetBelowPeakDB: Double
    public var partialOffsetBelowPeakDB: Double
    public var partialPersistenceFrames: Int

    public init(
        fftSize: Int = 8_192,
        hopSize: Int = 512,
        window: SpectralWindow = .blackmanHarris,
        frequencyScale: SpectralFrequencyScale = .logarithmic,
        minimumFrequencyHz: Double = 20,
        maximumFrequencyHz: Double = 20_000,
        dynamicRangeDB: Double = 100,
        maximumTimeBins: Int = 1_200,
        maximumAnalysisDurationSeconds: Double = 120,
        displayFrequencyBins: Int = 320,
        partialCount: Int = 32,
        partialSearchCents: Double = 55,
        partialOnsetBelowPeakDB: Double = 30,
        partialOffsetBelowPeakDB: Double = 45,
        partialPersistenceFrames: Int = 3
    ) {
        self.fftSize = fftSize
        self.hopSize = hopSize
        self.window = window
        self.frequencyScale = frequencyScale
        self.minimumFrequencyHz = minimumFrequencyHz
        self.maximumFrequencyHz = maximumFrequencyHz
        self.dynamicRangeDB = dynamicRangeDB
        self.maximumTimeBins = maximumTimeBins
        self.maximumAnalysisDurationSeconds = maximumAnalysisDurationSeconds
        self.displayFrequencyBins = displayFrequencyBins
        self.partialCount = partialCount
        self.partialSearchCents = partialSearchCents
        self.partialOnsetBelowPeakDB = partialOnsetBelowPeakDB
        self.partialOffsetBelowPeakDB = partialOffsetBelowPeakDB
        self.partialPersistenceFrames = partialPersistenceFrames
    }
}

public struct PartialTrackPoint: Codable, Hashable, Sendable {
    public var timeSeconds: Double
    public var frequencyHz: Double
    public var amplitudeDB: Double
    public var localSignalToNoiseDB: Double?
    public var isValid: Bool?
}

public struct PartialTrack: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { harmonicNumber }
    public var harmonicNumber: Int
    public var expectedFrequencyHz: Double
    public var medianFrequencyHz: Double?
    public var medianOffsetCents: Double?
    public var peakDB: Double?
    public var onsetSeconds: Double?
    public var offsetSeconds: Double?
    public var points: [PartialTrackPoint]
    public var noiseFloorDB: Double?
    public var signalToNoiseDB: Double?
    public var validPointRatio: Double?
    public var frequencyMADHz: Double?
    public var decayRateDBPerSecond: Double?
    public var confidence: Double?
}

public struct AudioDeviceSnapshot: Codable, Hashable, Sendable {
    public var uid: String
    public var name: String
    public var manufacturer: String
    public var transport: String
    public var inputChannels: Int
    public var sampleRate: Double
    public var bufferFrames: Int
    public var deviceLatencyFrames: Int
    public var safetyOffsetFrames: Int
    public var estimatedInputLatencyMilliseconds: Double
    public var lowLatencyMode: String

    public init(
        uid: String,
        name: String,
        manufacturer: String,
        transport: String,
        inputChannels: Int,
        sampleRate: Double,
        bufferFrames: Int,
        deviceLatencyFrames: Int,
        safetyOffsetFrames: Int,
        estimatedInputLatencyMilliseconds: Double,
        lowLatencyMode: String
    ) {
        self.uid = uid
        self.name = name
        self.manufacturer = manufacturer
        self.transport = transport
        self.inputChannels = inputChannels
        self.sampleRate = sampleRate
        self.bufferFrames = bufferFrames
        self.deviceLatencyFrames = deviceLatencyFrames
        self.safetyOffsetFrames = safetyOffsetFrames
        self.estimatedInputLatencyMilliseconds = estimatedInputLatencyMilliseconds
        self.lowLatencyMode = lowLatencyMode
    }
}

public enum CaptureFaultKind: String, Codable, CaseIterable, Sendable {
    case queueOverrun
    case sampleDiscontinuity
    case writerFailure
    case metadataFinalization
    case auxiliaryEvidenceFailure
    case interruptedCapture
    case projectCommitFailure
    case lowDiskSpace
    case deviceChanged
    case formatChanged
}

public struct CaptureFault: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: CaptureFaultKind
    public var detectedAt: Date
    public var framePosition: Int64?
    public var message: String

    public init(
        id: UUID = UUID(),
        kind: CaptureFaultKind,
        detectedAt: Date = .now,
        framePosition: Int64? = nil,
        message: String
    ) {
        self.id = id
        self.kind = kind
        self.detectedAt = detectedAt
        self.framePosition = framePosition
        self.message = message
    }
}

public struct ChannelCaptureStatistics: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { channelIndex }
    public var channelIndex: Int
    public var role: String
    public var peakDBFS: Double
    /// Integrated RMS over every successfully written sample in this channel.
    public var rmsDBFS: Double
    public var clippedSamples: Int64
    /// Count of successfully written samples whose instantaneous magnitude is
    /// below −80 dBFS. This is independent of audio callback partitioning.
    public var silentFrames: Int64
    public var isReferenceChannel: Bool

    public init(
        channelIndex: Int,
        role: String,
        peakDBFS: Double = -120,
        rmsDBFS: Double = -120,
        clippedSamples: Int64 = 0,
        silentFrames: Int64 = 0,
        isReferenceChannel: Bool = false
    ) {
        self.channelIndex = channelIndex
        self.role = role
        self.peakDBFS = peakDBFS
        self.rmsDBFS = rmsDBFS
        self.clippedSamples = clippedSamples
        self.silentFrames = silentFrames
        self.isReferenceChannel = isReferenceChannel
    }
}

public struct CaptureDiagnostics: Codable, Hashable, Sendable {
    public var writerContract: String
    public var container: String
    public var encoding: String
    public var bitDepth: Int
    public var queuedBufferCapacity: Int
    public var receivedBuffers: Int64
    public var writtenBuffers: Int64
    public var writtenFrames: Int64
    public var droppedBuffers: Int64
    public var discontinuityCount: Int
    public var minimumAvailableDiskBytes: Int64?
    public var channels: [ChannelCaptureStatistics]
    public var faults: [CaptureFault]

    public init(
        writerContract: String = "orgrec.bounded-realtime-writer/v2",
        container: String = "WAVE/BWF",
        encoding: String = "linear PCM little-endian",
        bitDepth: Int = 24,
        queuedBufferCapacity: Int = 128,
        receivedBuffers: Int64 = 0,
        writtenBuffers: Int64 = 0,
        writtenFrames: Int64 = 0,
        droppedBuffers: Int64 = 0,
        discontinuityCount: Int = 0,
        minimumAvailableDiskBytes: Int64? = nil,
        channels: [ChannelCaptureStatistics] = [],
        faults: [CaptureFault] = []
    ) {
        self.writerContract = writerContract
        self.container = container
        self.encoding = encoding
        self.bitDepth = bitDepth
        self.queuedBufferCapacity = queuedBufferCapacity
        self.receivedBuffers = receivedBuffers
        self.writtenBuffers = writtenBuffers
        self.writtenFrames = writtenFrames
        self.droppedBuffers = droppedBuffers
        self.discontinuityCount = discontinuityCount
        self.minimumAvailableDiskBytes = minimumAvailableDiskBytes
        self.channels = channels
        self.faults = faults
    }
}

public struct BWFMetadata: Codable, Hashable, Sendable {
    public var description: String
    public var originator: String
    public var originatorReference: String
    public var originationDate: String
    public var originationTime: String
    public var timeReferenceSamples: UInt64
    public var codingHistory: String

    public init(
        description: String,
        originator: String = "OrgRec",
        originatorReference: String,
        originationDate: String,
        originationTime: String,
        timeReferenceSamples: UInt64 = 0,
        codingHistory: String
    ) {
        self.description = description
        self.originator = originator
        self.originatorReference = originatorReference
        self.originationDate = originationDate
        self.originationTime = originationTime
        self.timeReferenceSamples = timeReferenceSamples
        self.codingHistory = codingHistory
    }
}

public enum AnalysisMarkerKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case onset = "Onset"
    case sustainStart = "Sustain start"
    case keyUp = "Key-up"
    case soundOffset = "Sound offset"
    case tailEnd = "Tail end"

    public var id: String { rawValue }
}

public struct MarkerCorrection: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var marker: AnalysisMarkerKind
    public var automatedSeconds: Double?
    public var correctedSeconds: Double
    public var author: String
    public var reason: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        marker: AnalysisMarkerKind,
        automatedSeconds: Double?,
        correctedSeconds: Double,
        author: String,
        reason: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.marker = marker
        self.automatedSeconds = automatedSeconds
        self.correctedSeconds = correctedSeconds
        self.author = author
        self.reason = reason
        self.createdAt = createdAt
    }
}

public struct TakeRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var roadmapItemID: UUID
    public var takeNumber: Int
    public var status: TakeStatus
    public var startedAt: Date
    public var endedAt: Date?
    public var relativeAudioPath: String
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int64
    public var fileSize: Int64
    public var sha256: String?
    public var analysis: AnalysisSummary?
    public var audioDeviceSnapshot: AudioDeviceSnapshot?
    public var spectrogramConfiguration: SpectrogramConfiguration?
    public var partialTracks: [PartialTrack]?
    public var captureDiagnostics: CaptureDiagnostics?
    /// Immutable capture-transaction gates that acoustic reanalysis and
    /// curatorial prose must never erase.
    public var captureIntegrityFaults: [CaptureFault]?
    public var bwfMetadata: BWFMetadata?
    public var markerCorrections: [MarkerCorrection]?
    public var analysisReferenceChannel: Int?
    public var notes: String
    public var reviewReason: String?
    public var provenance: TakeProvenanceSnapshot?
    public var reviewHistory: [ReviewDecision]?
    public var livePitchEvidence: [LivePitchEvidence]?
    public var pitchTrack: [PitchTrackPoint]?
    public var analysisRuns: [AnalysisRunRecord]?
    public var loopPointSets: [LoopPointSet]?
    public var acceptedLoopPointSetID: UUID?
    public var loopPointReviews: [LoopPointReview]?
    public var longTakeSource: LongTakeSliceProvenance?
    public var instrumentNoiseParadata: InstrumentNoiseTakeParadata?
    public var captureStateSnapshot: CaptureStateSnapshot?
    public var controlEventLog: ControlEventLog?
    public var audioControlAlignment: AudioControlAlignment?
    public var complexCaptureParadata: ComplexCaptureTakeParadata?
    public var spatialAcousticParadata: SpatialAcousticTakeParadata?
    public var effectAnalysis: EffectAnalysisResult?
    /// Optional because interaction sensors are an experimental, backward-compatible layer.
    public var interactionSensorCaptures: [InteractionSensorCaptureRecord]?

    public init(
        id: UUID = UUID(),
        roadmapItemID: UUID,
        takeNumber: Int,
        status: TakeStatus = .recording,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        relativeAudioPath: String,
        sampleRate: Double,
        channelCount: Int,
        frameCount: Int64 = 0,
        fileSize: Int64 = 0,
        sha256: String? = nil,
        analysis: AnalysisSummary? = nil,
        audioDeviceSnapshot: AudioDeviceSnapshot? = nil,
        spectrogramConfiguration: SpectrogramConfiguration? = nil,
        partialTracks: [PartialTrack]? = nil,
        captureDiagnostics: CaptureDiagnostics? = nil,
        captureIntegrityFaults: [CaptureFault]? = nil,
        bwfMetadata: BWFMetadata? = nil,
        markerCorrections: [MarkerCorrection]? = nil,
        analysisReferenceChannel: Int? = nil,
        notes: String = "",
        reviewReason: String? = nil,
        provenance: TakeProvenanceSnapshot? = nil,
        reviewHistory: [ReviewDecision]? = nil,
        livePitchEvidence: [LivePitchEvidence]? = nil,
        pitchTrack: [PitchTrackPoint]? = nil,
        analysisRuns: [AnalysisRunRecord]? = nil,
        loopPointSets: [LoopPointSet]? = nil,
        acceptedLoopPointSetID: UUID? = nil,
        loopPointReviews: [LoopPointReview]? = nil,
        longTakeSource: LongTakeSliceProvenance? = nil,
        instrumentNoiseParadata: InstrumentNoiseTakeParadata? = nil,
        captureStateSnapshot: CaptureStateSnapshot? = nil,
        controlEventLog: ControlEventLog? = nil,
        audioControlAlignment: AudioControlAlignment? = nil,
        complexCaptureParadata: ComplexCaptureTakeParadata? = nil,
        spatialAcousticParadata: SpatialAcousticTakeParadata? = nil,
        effectAnalysis: EffectAnalysisResult? = nil,
        interactionSensorCaptures: [InteractionSensorCaptureRecord]? = nil
    ) {
        self.id = id
        self.roadmapItemID = roadmapItemID
        self.takeNumber = takeNumber
        self.status = status
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.relativeAudioPath = relativeAudioPath
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.fileSize = fileSize
        self.sha256 = sha256
        self.analysis = analysis
        self.audioDeviceSnapshot = audioDeviceSnapshot
        self.spectrogramConfiguration = spectrogramConfiguration
        self.partialTracks = partialTracks
        self.captureDiagnostics = captureDiagnostics
        self.captureIntegrityFaults = captureIntegrityFaults
        self.bwfMetadata = bwfMetadata
        self.markerCorrections = markerCorrections
        self.analysisReferenceChannel = analysisReferenceChannel
        self.notes = notes
        self.reviewReason = reviewReason
        self.provenance = provenance
        self.reviewHistory = reviewHistory
        self.livePitchEvidence = livePitchEvidence
        self.pitchTrack = pitchTrack
        self.analysisRuns = analysisRuns
        self.loopPointSets = loopPointSets
        self.acceptedLoopPointSetID = acceptedLoopPointSetID
        self.loopPointReviews = loopPointReviews
        self.longTakeSource = longTakeSource
        self.instrumentNoiseParadata = instrumentNoiseParadata
        self.captureStateSnapshot = captureStateSnapshot
        self.controlEventLog = controlEventLog
        self.audioControlAlignment = audioControlAlignment
        self.complexCaptureParadata = complexCaptureParadata
        self.spatialAcousticParadata = spatialAcousticParadata
        self.effectAnalysis = effectAnalysis
        self.interactionSensorCaptures = interactionSensorCaptures
    }
}

public struct TimedAnnotation: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var takeID: UUID
    public var atSeconds: Double
    public var code: String
    public var severity: String
    public var text: String
    public var createdAt: Date
    public var instrumentNoiseEvent: InstrumentNoiseEventAnnotation?
    public var complexCaptureEvent: ComplexCaptureEventAnnotation?
    public var spatialAcousticEvent: SpatialAcousticEventAnnotation?

    public init(id: UUID = UUID(), takeID: UUID, atSeconds: Double, code: String, severity: String, text: String, createdAt: Date = Date(), instrumentNoiseEvent: InstrumentNoiseEventAnnotation? = nil, complexCaptureEvent: ComplexCaptureEventAnnotation? = nil, spatialAcousticEvent: SpatialAcousticEventAnnotation? = nil) {
        self.id = id
        self.takeID = takeID
        self.atSeconds = atSeconds
        self.code = code
        self.severity = severity
        self.text = text
        self.createdAt = createdAt
        self.instrumentNoiseEvent = instrumentNoiseEvent
        self.complexCaptureEvent = complexCaptureEvent
        self.spatialAcousticEvent = spatialAcousticEvent
    }
}

public struct SyncReceipt: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var attemptedAt: Date
    public var targetURL: URL?
    public var packageSHA256: String
    public var idempotencyKey: String
    public var status: String
    public var submissionID: String?
    public var error: String?

    public init(id: UUID = UUID(), attemptedAt: Date = Date(), targetURL: URL?, packageSHA256: String, idempotencyKey: String, status: String, submissionID: String? = nil, error: String? = nil) {
        self.id = id
        self.attemptedAt = attemptedAt
        self.targetURL = targetURL
        self.packageSHA256 = packageSHA256
        self.idempotencyKey = idempotencyKey
        self.status = status
        self.submissionID = submissionID
        self.error = error
    }
}

public struct ImportedVAOReference: Codable, Hashable, Sendable {
    public var packageId: String
    public var revision: Int
    public var formatVersion: String
    public var packageSHA256: String
    public var sourceArchiveRelativePath: String
    public var importedAt: Date

    public init(packageId: String, revision: Int, formatVersion: String, packageSHA256: String, sourceArchiveRelativePath: String, importedAt: Date = Date()) {
        self.packageId = packageId
        self.revision = revision
        self.formatVersion = formatVersion
        self.packageSHA256 = packageSHA256
        self.sourceArchiveRelativePath = sourceArchiveRelativePath
        self.importedAt = importedAt
    }
}

public struct OrgRecProject: Codable, Sendable {
    public var schemaVersion: Int
    public var id: UUID
    public var title: String
    public var organMDVSID: String
    public var organName: String
    public var venueName: String
    public var createdAt: Date
    public var updatedAt: Date
    public var snapshot: MODAVISSnapshot
    public var recipe: CaptureRecipe
    public var devices: [DeviceInstance]
    public var setups: [MicrophoneSetup]
    public var registrations: [RegistrationState]
    public var roadmap: [RoadmapItem]
    public var takes: [TakeRecord]
    public var annotations: [TimedAnnotation]
    public var syncReceipts: [SyncReceipt]
    public var spectrogramConfiguration: SpectrogramConfiguration?
    public var organComponents: [OrganComponent]?
    public var roadmapCompilation: RoadmapCompilationReport?
    public var navigatorPayloadRelativePath: String?
    public var organCharacteristics: OrganSpecificationCharacteristics?
    public var recordingSessions: [RecordingSession]?
    public var documentedPitchStandard: DocumentedPitchStandard?
    public var tuningCalibrations: [TuningCalibration]?
    public var temperamentCatalog: TemperamentCatalogSnapshot?
    public var temperamentAnalyses: [TemperamentAnalysisReport]?
    public var temperamentConsensus: TemperamentConsensusReport?
    public var collectionAnalysis: CollectionAnalysisReport?
    public var timbreAnalyses: [TimbreAnalysisReport]?
    public var componentRelationships: [OrganComponentRelationship]?
    public var physicalPipeMappings: [PhysicalPipeMapping]?
    public var pipeSharingAssertions: [PipeSharingAssertion]?
    public var physicalSoundTargets: [PhysicalSoundTarget]?
    public var physicalOverlapCandidates: [PhysicalOverlapCandidate]?
    public var importedVAO: ImportedVAOReference?
    public var longTakeSources: [LongTakeSourceRecord]?
    public var software: OrgRecSoftwareMetadata?
    public var venueAnchor: VenueAnchor?
    public var noiseContextAssessments: [NoiseContextAssessment]?
    public var sessionPlans: [RecordingSessionPlan]?
    public var controlBindings: [ControlBinding]?
    public var captureStates: [CaptureStateSnapshot]?
    public var activeCaptureStateID: UUID?
    public var actuatorResponseFunctions: [ActuatorResponseFunction]?
    public var spatialGeometrySnapshots: [SpatialGeometrySnapshot]?
    public var activeSpatialGeometrySnapshotID: UUID?
    public var spatialAcousticResponseComparisons: [SpatialAcousticResponseComparison]?
    /// Experimental interaction-sensor setup and evaluation records. Optional fields keep schema-v1 projects decodable.
    public var interactionSensorConfigurations: [InteractionSensorConfiguration]?
    public var interactionSensorCalibrations: [InteractionSensorCalibration]?
    public var interactionSensorValidations: [InteractionSensorValidationSession]?
    public var activeInteractionSensorConfigurationID: UUID?

    public init(
        schemaVersion: Int = 1,
        id: UUID = UUID(),
        title: String,
        organMDVSID: String,
        organName: String,
        venueName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        snapshot: MODAVISSnapshot,
        recipe: CaptureRecipe,
        devices: [DeviceInstance] = [],
        setups: [MicrophoneSetup] = [],
        registrations: [RegistrationState] = [],
        roadmap: [RoadmapItem] = [],
        takes: [TakeRecord] = [],
        annotations: [TimedAnnotation] = [],
        syncReceipts: [SyncReceipt] = [],
        spectrogramConfiguration: SpectrogramConfiguration? = SpectrogramConfiguration(),
        organComponents: [OrganComponent]? = nil,
        roadmapCompilation: RoadmapCompilationReport? = nil,
        navigatorPayloadRelativePath: String? = nil,
        organCharacteristics: OrganSpecificationCharacteristics? = nil,
        recordingSessions: [RecordingSession]? = nil,
        documentedPitchStandard: DocumentedPitchStandard? = nil,
        tuningCalibrations: [TuningCalibration]? = nil,
        temperamentCatalog: TemperamentCatalogSnapshot? = nil,
        temperamentAnalyses: [TemperamentAnalysisReport]? = nil,
        temperamentConsensus: TemperamentConsensusReport? = nil,
        collectionAnalysis: CollectionAnalysisReport? = nil,
        timbreAnalyses: [TimbreAnalysisReport]? = nil,
        componentRelationships: [OrganComponentRelationship]? = nil,
        physicalPipeMappings: [PhysicalPipeMapping]? = nil,
        pipeSharingAssertions: [PipeSharingAssertion]? = nil,
        physicalSoundTargets: [PhysicalSoundTarget]? = nil,
        physicalOverlapCandidates: [PhysicalOverlapCandidate]? = nil,
        importedVAO: ImportedVAOReference? = nil,
        longTakeSources: [LongTakeSourceRecord]? = nil,
        software: OrgRecSoftwareMetadata? = OrgRecSoftware.current,
        venueAnchor: VenueAnchor? = nil,
        noiseContextAssessments: [NoiseContextAssessment]? = nil,
        sessionPlans: [RecordingSessionPlan]? = nil,
        controlBindings: [ControlBinding]? = nil,
        captureStates: [CaptureStateSnapshot]? = nil,
        activeCaptureStateID: UUID? = nil,
        actuatorResponseFunctions: [ActuatorResponseFunction]? = nil,
        spatialGeometrySnapshots: [SpatialGeometrySnapshot]? = nil,
        activeSpatialGeometrySnapshotID: UUID? = nil,
        spatialAcousticResponseComparisons: [SpatialAcousticResponseComparison]? = nil,
        interactionSensorConfigurations: [InteractionSensorConfiguration]? = nil,
        interactionSensorCalibrations: [InteractionSensorCalibration]? = nil,
        interactionSensorValidations: [InteractionSensorValidationSession]? = nil,
        activeInteractionSensorConfigurationID: UUID? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.title = title
        self.organMDVSID = organMDVSID
        self.organName = organName
        self.venueName = venueName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.snapshot = snapshot
        self.recipe = recipe
        self.devices = devices
        self.setups = setups
        self.registrations = registrations
        self.roadmap = roadmap
        self.takes = takes
        self.annotations = annotations
        self.syncReceipts = syncReceipts
        self.spectrogramConfiguration = spectrogramConfiguration
        self.organComponents = organComponents
        self.roadmapCompilation = roadmapCompilation
        self.navigatorPayloadRelativePath = navigatorPayloadRelativePath
        self.organCharacteristics = organCharacteristics
        self.recordingSessions = recordingSessions
        self.documentedPitchStandard = documentedPitchStandard
        self.tuningCalibrations = tuningCalibrations
        self.temperamentCatalog = temperamentCatalog
        self.temperamentAnalyses = temperamentAnalyses
        self.temperamentConsensus = temperamentConsensus
        self.collectionAnalysis = collectionAnalysis
        self.timbreAnalyses = timbreAnalyses
        self.componentRelationships = componentRelationships
        self.physicalPipeMappings = physicalPipeMappings
        self.pipeSharingAssertions = pipeSharingAssertions
        self.physicalSoundTargets = physicalSoundTargets
        self.physicalOverlapCandidates = physicalOverlapCandidates
        self.importedVAO = importedVAO
        self.longTakeSources = longTakeSources
        self.software = software
        self.venueAnchor = venueAnchor
        self.noiseContextAssessments = noiseContextAssessments
        self.sessionPlans = sessionPlans
        self.controlBindings = controlBindings
        self.captureStates = captureStates
        self.activeCaptureStateID = activeCaptureStateID
        self.actuatorResponseFunctions = actuatorResponseFunctions
        self.spatialGeometrySnapshots = spatialGeometrySnapshots
        self.activeSpatialGeometrySnapshotID = activeSpatialGeometrySnapshotID
        self.spatialAcousticResponseComparisons = spatialAcousticResponseComparisons
        self.interactionSensorConfigurations = interactionSensorConfigurations
        self.interactionSensorCalibrations = interactionSensorCalibrations
        self.interactionSensorValidations = interactionSensorValidations
        self.activeInteractionSensorConfigurationID = activeInteractionSensorConfigurationID
    }
}

public struct CoverageSummary: Codable, Hashable, Sendable {
    public var accepted: Int
    public var review: Int
    public var missing: Int
    public var exempt: Int
    public var unresolved: Int
    public var applicableRequired: Int
    public var acceptedRequired: Int?

    public init(
        accepted: Int,
        review: Int,
        missing: Int,
        exempt: Int,
        unresolved: Int,
        applicableRequired: Int,
        acceptedRequired: Int? = nil
    ) {
        self.accepted = accepted
        self.review = review
        self.missing = missing
        self.exempt = exempt
        self.unresolved = unresolved
        self.applicableRequired = applicableRequired
        self.acceptedRequired = acceptedRequired
    }

    public var fraction: Double {
        guard applicableRequired > 0 else { return 0 }
        return min(1, max(0, Double(acceptedRequired ?? min(accepted, applicableRequired)) / Double(applicableRequired)))
    }
}
