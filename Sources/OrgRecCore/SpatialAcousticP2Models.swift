import Accelerate
@preconcurrency import AVFAudio
import Foundation

// MARK: - P2 spatial geometry

public struct SpatialPoint3D: Codable, Hashable, Sendable {
    public var xMeters: Double
    public var yMeters: Double
    public var zMeters: Double
    public init(xMeters: Double = 0, yMeters: Double = 0, zMeters: Double = 0) {
        self.xMeters = xMeters; self.yMeters = yMeters; self.zMeters = zMeters
    }
    public func distance(to other: Self) -> Double {
        sqrt(pow(xMeters - other.xMeters, 2) + pow(yMeters - other.yMeters, 2) + pow(zMeters - other.zMeters, 2))
    }
}

public struct SpatialOrientation3D: Codable, Hashable, Sendable {
    public var yawDegrees: Double
    public var pitchDegrees: Double
    public var rollDegrees: Double
    public init(yawDegrees: Double = 0, pitchDegrees: Double = 0, rollDegrees: Double = 0) {
        self.yawDegrees = yawDegrees; self.pitchDegrees = pitchDegrees; self.rollDegrees = rollDegrees
    }
}

public struct SpatialExtent3D: Codable, Hashable, Sendable {
    public var widthMeters: Double
    public var heightMeters: Double
    public var depthMeters: Double
    public init(widthMeters: Double = 0, heightMeters: Double = 0, depthMeters: Double = 0) {
        self.widthMeters = max(0, widthMeters); self.heightMeters = max(0, heightMeters); self.depthMeters = max(0, depthMeters)
    }
}

public enum SpatialGeometryElementKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case rank, effect, shutter, enclosure, screen
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum SpatialSourceDistribution: String, Codable, CaseIterable, Identifiable, Sendable {
    case point, line, area, volume
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum SpatialEvidenceSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case measured, architecturalDrawing, photographDerived, operatorEstimated, imported
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .measured: "Measured"
        case .architecturalDrawing: "Architectural drawing"
        case .photographDerived: "Derived from photographs"
        case .operatorEstimated: "Operator estimate"
        case .imported: "Imported documentation"
        }
    }
}

public struct SpatialGeometryReferenceFrame: Codable, Hashable, Sendable {
    public var originDescription: String
    public var xAxisDescription: String
    public var yAxisDescription: String
    public var zAxisDescription: String
    public var compatibleMicrophoneSetupIDs: [UUID]
    public var evidence: SpatialEvidenceSource
    public var uncertaintyMeters: Double?
    public var notes: String
    public init(
        originDescription: String = "Organ façade center at floor level",
        xAxisDescription: String = "positive to audience right",
        yAxisDescription: String = "positive toward the nave",
        zAxisDescription: String = "positive upward",
        compatibleMicrophoneSetupIDs: [UUID] = [],
        evidence: SpatialEvidenceSource = .operatorEstimated,
        uncertaintyMeters: Double? = nil,
        notes: String = ""
    ) {
        self.originDescription = originDescription; self.xAxisDescription = xAxisDescription
        self.yAxisDescription = yAxisDescription; self.zAxisDescription = zAxisDescription
        self.compatibleMicrophoneSetupIDs = compatibleMicrophoneSetupIDs.sorted { $0.uuidString < $1.uuidString }
        self.evidence = evidence; self.uncertaintyMeters = uncertaintyMeters; self.notes = notes
    }
}

public struct SpatialGeometryElement: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var componentID: String?
    public var label: String
    public var kind: SpatialGeometryElementKind
    public var parentElementID: String?
    public var position: SpatialPoint3D
    public var orientation: SpatialOrientation3D
    public var extent: SpatialExtent3D
    public var distribution: SpatialSourceDistribution
    public var material: String
    public var openAreaRatio: Double?
    public var thicknessMeters: Double?
    public var evidence: SpatialEvidenceSource
    public var uncertaintyMeters: Double?
    public var notes: String

    public init(
        id: String,
        componentID: String? = nil,
        label: String,
        kind: SpatialGeometryElementKind,
        parentElementID: String? = nil,
        position: SpatialPoint3D = SpatialPoint3D(),
        orientation: SpatialOrientation3D = SpatialOrientation3D(),
        extent: SpatialExtent3D = SpatialExtent3D(),
        distribution: SpatialSourceDistribution = .point,
        material: String = "",
        openAreaRatio: Double? = nil,
        thicknessMeters: Double? = nil,
        evidence: SpatialEvidenceSource = .operatorEstimated,
        uncertaintyMeters: Double? = nil,
        notes: String = ""
    ) {
        self.id = id; self.componentID = componentID; self.label = label; self.kind = kind
        self.parentElementID = parentElementID; self.position = position; self.orientation = orientation
        self.extent = extent; self.distribution = distribution; self.material = material
        self.openAreaRatio = openAreaRatio; self.thicknessMeters = thicknessMeters
        self.evidence = evidence; self.uncertaintyMeters = uncertaintyMeters; self.notes = notes
    }
}

public struct SpatialGeometrySnapshot: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var revision: Int
    public var name: String
    public var referenceFrame: SpatialGeometryReferenceFrame
    public var elements: [SpatialGeometryElement]
    public var documentedAt: Date
    public var notes: String

    public init(contractVersion: String = "orgrec.spatial-geometry/v1", id: UUID = UUID(), revision: Int = 1, name: String, referenceFrame: SpatialGeometryReferenceFrame, elements: [SpatialGeometryElement], documentedAt: Date = .now, notes: String = "") {
        self.contractVersion = contractVersion; self.id = id; self.revision = max(1, revision); self.name = name
        self.referenceFrame = referenceFrame; self.elements = elements; self.documentedAt = documentedAt; self.notes = notes
    }

    public var fingerprint: String {
        let frame = [referenceFrame.originDescription, referenceFrame.xAxisDescription, referenceFrame.yAxisDescription,
                     referenceFrame.zAxisDescription, referenceFrame.evidence.rawValue,
                     referenceFrame.uncertaintyMeters.map(canonical) ?? "",
                     referenceFrame.compatibleMicrophoneSetupIDs.map(\.uuidString).sorted().joined(separator: ",")].joined(separator: "\u{1f}")
        let entries = elements.sorted { $0.id < $1.id }.map { element in
            [element.id, element.componentID ?? "", element.label, element.kind.rawValue, element.parentElementID ?? "",
             canonical(element.position.xMeters), canonical(element.position.yMeters), canonical(element.position.zMeters),
             canonical(element.orientation.yawDegrees), canonical(element.orientation.pitchDegrees), canonical(element.orientation.rollDegrees),
             canonical(element.extent.widthMeters), canonical(element.extent.heightMeters), canonical(element.extent.depthMeters),
             element.distribution.rawValue, element.material, element.openAreaRatio.map(canonical) ?? "",
             element.thicknessMeters.map(canonical) ?? "", element.evidence.rawValue,
             element.uncertaintyMeters.map(canonical) ?? ""].joined(separator: "\u{1f}")
        }.joined(separator: "\u{1e}")
        return Data("\(contractVersion)|\(id.uuidString.lowercased())|\(revision)|\(frame)|\(entries)".utf8).sha256Hex
    }

    public var validationIssues: [String] {
        var issues: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Geometry snapshot requires a name.") }
        if referenceFrame.originDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Geometry origin must be documented.") }
        if Set(elements.map(\.id)).count != elements.count { issues.append("Geometry element identifiers must be unique.") }
        for element in elements {
            if element.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || element.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Every geometry element requires an identifier and label.") }
            if let parent = element.parentElementID, !elements.contains(where: { $0.id == parent }) { issues.append("Geometry element \(element.label) references a missing parent.") }
            if let ratio = element.openAreaRatio, !(0...1).contains(ratio) { issues.append("Open-area ratios must be between zero and one.") }
            if let uncertainty = element.uncertaintyMeters, uncertainty < 0 { issues.append("Geometry uncertainty cannot be negative.") }
            var visited = Set([element.id])
            var parent = element.parentElementID
            while let current = parent {
                if !visited.insert(current).inserted { issues.append("Geometry containment relationships must be acyclic."); break }
                parent = elements.first(where: { $0.id == current })?.parentElementID
            }
        }
        return Array(Set(issues)).sorted()
    }

    private func canonical(_ value: Double) -> String { String(format: "%.9g", value) }
}

// MARK: - State-dependent in-situ response capture

public enum SpatialAcousticExcitation: String, Codable, CaseIterable, Identifiable, Sendable {
    case instrumentResponse
    case impulsiveSource
    case deconvolvedSweepResponse

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .instrumentResponse: "Organ sound / action"
        case .impulsiveSource: "Impulsive acoustic source"
        case .deconvolvedSweepResponse: "Deconvolved sweep response"
        }
    }
    public var explanation: String {
        switch self {
        case .instrumentResponse:
            "Compares the complete in-situ organ response. Decay remains pipe-plus-room evidence; no ISO reverberation metric is asserted."
        case .impulsiveSource:
            "Analyzes a captured impulsive-source response with qualified room-decay and early-energy estimates."
        case .deconvolvedSweepResponse:
            "Analyzes an already deconvolved impulse response. Do not select this for the raw sweep recording."
        }
    }
    public var responseQualification: AcousticResponseQualification? {
        switch self {
        case .instrumentResponse: nil
        case .impulsiveSource: .impulsiveSourceResponse
        case .deconvolvedSweepResponse: .deconvolvedImpulseResponse
        }
    }
}

public struct SpatialResponseState: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var assignments: [CaptureStateAssignment]
    public var notes: String
    public init(id: String, label: String, assignments: [CaptureStateAssignment], notes: String = "") {
        self.id = id; self.label = label; self.assignments = assignments; self.notes = notes
    }
}

public struct SpatialAcousticCaptureProtocol: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var responseSeriesID: UUID
    public var name: String
    public var geometrySnapshotID: UUID
    public var geometryFingerprint: String
    public var sourceElementID: String
    public var pathElementIDs: [String]
    public var referenceStateID: String
    public var targetState: SpatialResponseState
    public var minimumAcceptedTakeCount: Int
    public var plannedDurationSeconds: Double
    public var instructions: String
    public var limitationStatement: String
    /// Optional so projects created before response qualification remain
    /// decodable. Absence means an ordinary in-situ instrument response.
    public var excitation: SpatialAcousticExcitation?

    public init(
        contractVersion: String = "orgrec.spatial-acoustic-capture/v1",
        id: UUID = UUID(), responseSeriesID: UUID, name: String, geometrySnapshotID: UUID,
        geometryFingerprint: String, sourceElementID: String, pathElementIDs: [String],
        referenceStateID: String, targetState: SpatialResponseState,
        minimumAcceptedTakeCount: Int = 2, plannedDurationSeconds: Double = 10,
        instructions: String = "",
        limitationStatement: String = "In-situ state-dependent response: source spectrum and position, enclosure, screen, shutter state, room, and microphone geometry remain jointly present.",
        excitation: SpatialAcousticExcitation = .instrumentResponse
    ) {
        self.contractVersion = contractVersion; self.id = id; self.responseSeriesID = responseSeriesID; self.name = name
        self.geometrySnapshotID = geometrySnapshotID; self.geometryFingerprint = geometryFingerprint
        self.sourceElementID = sourceElementID; self.pathElementIDs = pathElementIDs
        self.referenceStateID = referenceStateID; self.targetState = targetState
        self.minimumAcceptedTakeCount = max(1, minimumAcceptedTakeCount); self.plannedDurationSeconds = max(1, plannedDurationSeconds)
        self.instructions = instructions; self.limitationStatement = limitationStatement
        self.excitation = excitation
    }

    public var isReferenceState: Bool { targetState.id == referenceStateID }
    public var effectiveExcitation: SpatialAcousticExcitation { excitation ?? .instrumentResponse }
}

public struct SpatialAcousticPlanRequest: Codable, Hashable, Sendable {
    public var geometry: SpatialGeometrySnapshot
    public var sourceComponentID: String?
    public var customSourceLabel: String
    public var sourceElementID: String
    public var pathElementIDs: [String]
    public var states: [SpatialResponseState]
    public var referenceStateID: String
    public var minimumAcceptedTakeCount: Int
    public var plannedDurationSeconds: Double
    public var techniques: [CaptureTechnique]
    public var orderedSetupIDs: [UUID]?
    public var required: Bool
    public var excitation: SpatialAcousticExcitation?
    public init(geometry: SpatialGeometrySnapshot, sourceComponentID: String? = nil, customSourceLabel: String = "", sourceElementID: String, pathElementIDs: [String], states: [SpatialResponseState], referenceStateID: String, minimumAcceptedTakeCount: Int = 2, plannedDurationSeconds: Double = 10, techniques: [CaptureTechnique], orderedSetupIDs: [UUID]? = nil, required: Bool = true, excitation: SpatialAcousticExcitation = .instrumentResponse) {
        self.geometry = geometry; self.sourceComponentID = sourceComponentID; self.customSourceLabel = customSourceLabel
        self.sourceElementID = sourceElementID; self.pathElementIDs = pathElementIDs; self.states = states
        self.referenceStateID = referenceStateID; self.minimumAcceptedTakeCount = max(1, minimumAcceptedTakeCount)
        self.plannedDurationSeconds = max(1, plannedDurationSeconds); self.techniques = techniques
        self.orderedSetupIDs = orderedSetupIDs; self.required = required; self.excitation = excitation
    }

    public var effectiveExcitation: SpatialAcousticExcitation { excitation ?? .instrumentResponse }
}

public enum SpatialAcousticEventKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case sourceTriggered, stateConfirmed, responseStable, notableVariation
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .sourceTriggered: "Source triggered"
        case .stateConfirmed: "State confirmed"
        case .responseStable: "Response stable"
        case .notableVariation: "Notable variation"
        }
    }
}

public struct SpatialAcousticEvent: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var atSeconds: Double
    public var kind: SpatialAcousticEventKind
    public var notes: String
    public init(id: UUID = UUID(), atSeconds: Double, kind: SpatialAcousticEventKind, notes: String = "") {
        self.id = id; self.atSeconds = atSeconds; self.kind = kind; self.notes = notes
    }
}

public struct SpatialAcousticEventAnnotation: Codable, Hashable, Sendable {
    public var protocolID: UUID
    public var event: SpatialAcousticEvent
    public init(protocolID: UUID, event: SpatialAcousticEvent) { self.protocolID = protocolID; self.event = event }
}

public struct SpectralBandLevel: Codable, Hashable, Identifiable, Sendable {
    public var id: Double { centerFrequencyHz }
    public var centerFrequencyHz: Double
    public var lowerFrequencyHz: Double
    public var upperFrequencyHz: Double
    public var levelDBFS: Double
}

public struct SpatialAcousticObservation: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var takeID: UUID
    public var responseSeriesID: UUID
    public var stateID: String
    public var geometrySnapshotID: UUID
    public var geometryFingerprint: String
    public var sourceElementID: String
    public var pathElementIDs: [String]
    public var microphoneSetupID: UUID?
    public var captureTechnique: CaptureTechnique
    public var referenceChannel: Int
    public var sourceToReferenceMicrophoneDistanceMeters: Double?
    public var peakDBFS: Double
    public var rmsDBFS: Double
    public var onsetLatencySeconds: Double?
    public var effectiveImpulseWidthSeconds: Double?
    public var thirdOctaveBandLevels: [SpectralBandLevel]
    public var analyzedDurationSeconds: Double
    public var takeStatus: TakeStatus
    public var analyzedAt: Date
    public var method: String
    public var warnings: [String]
    public var acousticResponseAnalysis: AcousticResponseAnalysis? = nil
}

public struct SpatialBandDelta: Codable, Hashable, Identifiable, Sendable {
    public var id: Double { centerFrequencyHz }
    public var centerFrequencyHz: Double
    public var levelDeltaDB: Double
    public var referenceMeanDBFS: Double? = nil
    public var targetMeanDBFS: Double? = nil
    public var referenceStandardDeviationDB: Double? = nil
    public var targetStandardDeviationDB: Double? = nil
}

public struct SpatialAcousticResponseComparison: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(responseSeriesID.uuidString)|\(microphoneSetupID?.uuidString ?? "none")|\(captureTechnique.rawValue)|\(referenceChannel)|\(stateID)" }
    public var contractVersion: String
    public var responseSeriesID: UUID
    public var stateID: String
    public var referenceStateID: String
    public var sourceElementID: String
    public var pathElementIDs: [String]
    public var geometrySnapshotID: UUID
    public var geometryFingerprint: String
    public var microphoneSetupID: UUID?
    public var captureTechnique: CaptureTechnique
    public var referenceChannel: Int
    public var referenceTakeIDs: [UUID]
    public var targetTakeIDs: [UUID]
    public var peakLevelDeltaDB: Double?
    public var rmsLevelDeltaDB: Double?
    public var referenceRMSStandardDeviationDB: Double? = nil
    public var targetRMSStandardDeviationDB: Double? = nil
    public var onsetLatencyDeltaSeconds: Double?
    public var impulseWidthDeltaSeconds: Double?
    public var thirdOctaveBandDeltas: [SpatialBandDelta]
    public var limitationStatement: String
    public var generatedAt: Date
}

public struct SpatialAcousticTakeParadata: Codable, Hashable, Sendable {
    public var protocolSnapshot: SpatialAcousticCaptureProtocol
    public var repetitionNumber: Int
    public var events: [SpatialAcousticEvent]
    public var observation: SpatialAcousticObservation?
    public var notes: String
    public init(protocolSnapshot: SpatialAcousticCaptureProtocol, repetitionNumber: Int, events: [SpatialAcousticEvent] = [], observation: SpatialAcousticObservation? = nil, notes: String = "") {
        self.protocolSnapshot = protocolSnapshot; self.repetitionNumber = max(1, repetitionNumber)
        self.events = events; self.observation = observation; self.notes = notes
    }
}

// MARK: - Effect-specific analysis

public struct NonPitchedEffectAnalysisProtocol: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var sourceComponentID: String
    public var temporalBehavior: SoundingTargetTemporalBehavior
    public var measureLatency: Bool
    public var measureImpulseWidth: Bool
    public var measureRepetition: Bool
    public var measurePeriodicity: Bool
    public var measureStochasticity: Bool
    public var measureChainStageTiming: Bool
    public var notes: String
    public init(contractVersion: String = "orgrec.nonpitched-effect-analysis-protocol/v1", sourceComponentID: String, temporalBehavior: SoundingTargetTemporalBehavior, measureLatency: Bool = true, measureImpulseWidth: Bool = true, measureRepetition: Bool = true, measurePeriodicity: Bool = true, measureStochasticity: Bool = true, measureChainStageTiming: Bool = true, notes: String = "") {
        self.contractVersion = contractVersion; self.sourceComponentID = sourceComponentID; self.temporalBehavior = temporalBehavior
        self.measureLatency = measureLatency; self.measureImpulseWidth = measureImpulseWidth; self.measureRepetition = measureRepetition
        self.measurePeriodicity = measurePeriodicity; self.measureStochasticity = measureStochasticity
        self.measureChainStageTiming = measureChainStageTiming; self.notes = notes
    }
}

public enum EffectTimingEvidence: String, Codable, CaseIterable, Sendable { case synchronizedControl, operatorMarker, acousticDetection, unavailable }

public struct EffectChainStageTiming: Codable, Hashable, Identifiable, Sendable {
    public var id: String { stageID }
    public var stageID: String
    public var label: String
    public var beginSeconds: Double?
    public var endSeconds: Double?
    public var durationSeconds: Double?
    public var plannedTypicalSeconds: Double?
    public var deviationSeconds: Double?
    public var evidence: EffectTimingEvidence
    public var uncertaintySeconds: Double?
}

public struct EffectAnalysisResult: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var takeID: UUID
    public var protocolSnapshot: NonPitchedEffectAnalysisProtocol
    public var referenceChannel: Int
    public var analyzedDurationSeconds: Double
    public var commandTimeSeconds: Double?
    public var commandTimingEvidence: EffectTimingEvidence
    public var commandTimeUncertaintySeconds: Double?
    public var acousticOnsetSeconds: Double?
    public var latencySeconds: Double?
    public var peakDBFS: Double
    public var rmsDBFS: Double
    public var effectiveImpulseWidthSeconds: Double?
    public var repetitionEventCount: Int
    public var repetitionRateHz: Double?
    public var intervalMeanSeconds: Double?
    public var intervalStandardDeviationSeconds: Double?
    public var intervalCoefficientOfVariation: Double?
    public var intervalMinimumSeconds: Double?
    public var intervalMaximumSeconds: Double?
    public var periodicityRateHz: Double?
    public var periodicityConfidence: Double?
    public var stochasticityIndex: Double?
    public var temporalEntropy: Double?
    public var chainStageTimings: [EffectChainStageTiming]
    public var method: String
    public var analyzedAt: Date
    public var warnings: [String]
}

public extension RoadmapItem {
    var inferredNonPitchedEffectAnalysisProtocol: NonPitchedEffectAnalysisProtocol? {
        if let explicit = effectAnalysisProtocol { return explicit }
        if let definition = soundingTargetDefinition,
           [.atonalPercussion, .sustainedEffect, .oneShotEffect, .repeatingEffect, .sequencedEffect, .compositeEffect, .otherSoundingElement].contains(definition.family) {
            return NonPitchedEffectAnalysisProtocol(sourceComponentID: component.parentComponentID ?? component.id, temporalBehavior: definition.temporalBehavior)
        }
        if soundingTargetDefinition == nil,
           component.midiNote == nil,
           component.expectedFrequencyHz == nil,
           let process = complexCaptureProtocol?.processModel {
            return NonPitchedEffectAnalysisProtocol(sourceComponentID: complexCaptureProtocol?.sourceComponentID ?? component.id, temporalBehavior: .sequenced, notes: "Inferred from P1 declarative process \(process.name).")
        }
        return nil
    }
}

// MARK: - P2 Roadmap compiler

public extension RoadmapEngine {
    static func spatialAcousticResponseItems(request: SpatialAcousticPlanRequest, component: OrganComponent, recipe: CaptureRecipe) -> (states: [CaptureStateSnapshot], items: [RoadmapItem]) {
        let seriesID = stableUUIDP2("\(request.geometry.id.uuidString)|\(request.geometry.fingerprint)|\(request.sourceElementID)|\(request.referenceStateID)")
        var snapshots: [CaptureStateSnapshot] = []
        var items: [RoadmapItem] = []
        for state in request.states {
            let snapshot = CaptureStateSnapshot(name: "Spatial response · \(state.label)", source: .operatorPlanned, assignments: state.assignments, notes: state.notes)
            snapshots.append(snapshot)
            for technique in request.techniques {
                let protocolSnapshot = SpatialAcousticCaptureProtocol(
                    id: stableUUIDP2("\(seriesID.uuidString)|\(state.id)|\(technique.rawValue)"), responseSeriesID: seriesID,
                    name: "\(component.label) · \(state.label)", geometrySnapshotID: request.geometry.id,
                    geometryFingerprint: request.geometry.fingerprint, sourceElementID: request.sourceElementID,
                    pathElementIDs: request.pathElementIDs, referenceStateID: request.referenceStateID, targetState: state,
                    minimumAcceptedTakeCount: request.minimumAcceptedTakeCount, plannedDurationSeconds: request.plannedDurationSeconds,
                    instructions: "Confirm \(state.label), trigger the same source/action and retain the full response. Keep source, room, setup, gain and route unchanged across the series.",
                    excitation: request.effectiveExcitation
                )
                var target = component
                let key = "\(seriesID.uuidString)|\(state.id)|\(technique.rawValue)"
                target.id = "spatial-response:\(Data(key.utf8).sha256Hex)"
                target.kind = "spatial_acoustic_response"
                target.label = component.label
                target.division = "Spatial acoustic responses"
                target.noteName = state.label + (protocolSnapshot.isReferenceState ? " · reference" : "")
                target.parentComponentID = component.id
                items.append(RoadmapItem(
                    id: stableUUIDP2(key), component: target, technique: technique, recipeID: recipe.id,
                    setupID: setupForP2(technique, setupIDs: request.orderedSetupIDs ?? request.geometry.referenceFrame.compatibleMicrophoneSetupIDs),
                    required: request.required, coverageKind: .spatialAcousticResponse,
                    instructions: protocolSnapshot.instructions + " " + protocolSnapshot.limitationStatement,
                    spatialAcousticProtocol: protocolSnapshot, effectAnalysisProtocol: nil,
                    requiredCaptureStateID: snapshot.id, requiredCaptureStateFingerprint: snapshot.fingerprintSHA256,
                    requiredCaptureState: snapshot
                ))
            }
        }
        return (snapshots, items)
    }

    private static func setupForP2(_ technique: CaptureTechnique, setupIDs: [UUID]) -> UUID? {
        switch technique {
        case .closePair: setupIDs.first
        case .naveORTF: setupIDs.dropFirst().first ?? setupIDs.first
        case .rearOmni: setupIDs.dropFirst(2).first ?? setupIDs.last
        case .releaseTail: setupIDs.dropFirst().first ?? setupIDs.first
        }
    }
    private static func stableUUIDP2(_ value: String) -> UUID {
        let hex = String(Data(value.utf8).sha256Hex.prefix(32))
        let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: formatted) ?? UUID()
    }
}

// MARK: - P2 analysis

public enum P2AnalysisEngine {
    public static func analyzeEffect(fileURL: URL, take: TakeRecord, item: RoadmapItem, referenceChannel: Int, annotations: [TimedAnnotation] = []) throws -> EffectAnalysisResult? {
        guard let protocolSnapshot = item.inferredNonPitchedEffectAnalysisProtocol else { return nil }
        let features = try P2AudioFeatureExtractor.extract(fileURL: fileURL, referenceChannel: referenceChannel)
        let command = commandTime(take: take, sourceComponentID: protocolSnapshot.sourceComponentID, annotations: annotations)
        let onset = take.analysis?.onsetSeconds ?? features.detectedOnsetSeconds
        let intervals = zip(features.eventTimes.dropFirst(), features.eventTimes).map(-)
        let mean = intervals.isEmpty ? nil : intervals.reduce(0, +) / Double(intervals.count)
        let standardDeviation = mean.map { center in sqrt(intervals.reduce(0) { $0 + pow($1 - center, 2) } / Double(max(1, intervals.count))) }
        let coefficient = mean.flatMap { $0 > 0 ? (standardDeviation ?? 0) / $0 : nil }
        let periodicity = periodicity(envelope: features.envelope, hopSeconds: features.hopSeconds, expectedIntervalSeconds: mean)
        let entropy = temporalEntropy(intervals)
        let stochasticity: Double?
        if intervals.count >= 2 {
            stochasticity = min(1, max(0, 0.45 * min(1, coefficient ?? 0) + 0.35 * (entropy ?? 0) + 0.20 * (1 - (periodicity?.confidence ?? 0))))
        } else { stochasticity = nil }
        var warnings = features.warnings
        if protocolSnapshot.measureLatency && command.time == nil { warnings.append("No synchronized source command or operator source-trigger marker is available; latency is not reported.") }
        if protocolSnapshot.measureRepetition && features.eventTimes.count < 2 { warnings.append("Fewer than two reliable acoustic events were detected; repetition statistics are not applicable.") }
        return EffectAnalysisResult(
            contractVersion: "orgrec.effect-analysis/v1", takeID: take.id, protocolSnapshot: protocolSnapshot,
            referenceChannel: features.referenceChannel, analyzedDurationSeconds: features.duration,
            commandTimeSeconds: command.time, commandTimingEvidence: command.evidence, commandTimeUncertaintySeconds: command.uncertainty,
            acousticOnsetSeconds: onset, latencySeconds: command.time.flatMap { time in onset.map { $0 - time } },
            peakDBFS: features.peakDBFS, rmsDBFS: features.rmsDBFS,
            effectiveImpulseWidthSeconds: protocolSnapshot.measureImpulseWidth ? features.effectiveImpulseWidthSeconds : nil,
            repetitionEventCount: features.eventTimes.count,
            repetitionRateHz: mean.flatMap { $0 > 0 ? 1 / $0 : nil }, intervalMeanSeconds: mean,
            intervalStandardDeviationSeconds: standardDeviation, intervalCoefficientOfVariation: coefficient,
            intervalMinimumSeconds: intervals.min(), intervalMaximumSeconds: intervals.max(),
            periodicityRateHz: protocolSnapshot.measurePeriodicity ? periodicity?.rate : nil,
            periodicityConfidence: protocolSnapshot.measurePeriodicity ? periodicity?.confidence : nil,
            stochasticityIndex: protocolSnapshot.measureStochasticity ? stochasticity : nil,
            temporalEntropy: protocolSnapshot.measureStochasticity ? entropy : nil,
            chainStageTimings: protocolSnapshot.measureChainStageTiming ? stageTimings(take: take, item: item) : [],
            method: "20 ms RMS envelope, adaptive peak detection, normalized envelope autocorrelation, temporal-interval statistics, Hann-windowed 4096-point third-octave accumulation",
            analyzedAt: .now, warnings: warnings
        )
    }

    public static func analyzeSpatial(fileURL: URL, take: TakeRecord, item: RoadmapItem, geometry: SpatialGeometrySnapshot) throws -> SpatialAcousticObservation? {
        guard let captureProtocol = item.spatialAcousticProtocol else { return nil }
        let referenceChannel = take.analysisReferenceChannel ?? 0
        let features = try P2AudioFeatureExtractor.extract(fileURL: fileURL, referenceChannel: referenceChannel)
        let command = commandTime(take: take, sourceComponentID: captureProtocol.sourceElementID, annotations: [])
        let onset = take.analysis?.onsetSeconds ?? features.detectedOnsetSeconds
        var warnings = features.warnings
        if geometry.fingerprint != captureProtocol.geometryFingerprint { warnings.append("The geometry snapshot fingerprint differs from the frozen capture protocol.") }
        let setup = take.provenance?.microphoneSetup
        let setupCompatible = setup.map { geometry.referenceFrame.compatibleMicrophoneSetupIDs.contains($0.id) } ?? false
        if setup != nil && !setupCompatible { warnings.append("The microphone setup does not declare the same coordinate frame; source-to-receiver distance is unavailable.") }
        let distance: Double?
        if setupCompatible,
           let source = geometry.elements.first(where: { $0.id == captureProtocol.sourceElementID }),
           let channel = setup?.referenceChannelNumber,
           let microphone = setup?.placements.first(where: { $0.channelNumber == channel }) {
            distance = source.position.distance(to: SpatialPoint3D(xMeters: microphone.xMeters, yMeters: microphone.yMeters, zMeters: microphone.zMeters))
        } else { distance = nil }
        let responseAnalysis: AcousticResponseAnalysis?
        if let qualification = captureProtocol.effectiveExcitation.responseQualification {
            responseAnalysis = try AcousticResponseAnalyzer.analyze(
                fileURL: fileURL,
                referenceChannel: referenceChannel,
                qualification: qualification
            )
            if responseAnalysis == nil {
                warnings.append("The declared impulse response did not contain enough usable evidence for room-decay analysis.")
            } else {
                warnings.append(contentsOf: responseAnalysis?.warnings ?? [])
            }
        } else {
            responseAnalysis = nil
        }
        return SpatialAcousticObservation(
            contractVersion: "orgrec.spatial-acoustic-observation/v1", takeID: take.id,
            responseSeriesID: captureProtocol.responseSeriesID, stateID: captureProtocol.targetState.id,
            geometrySnapshotID: geometry.id, geometryFingerprint: geometry.fingerprint,
            sourceElementID: captureProtocol.sourceElementID, pathElementIDs: captureProtocol.pathElementIDs,
            microphoneSetupID: setup?.id ?? item.setupID, captureTechnique: item.technique,
            referenceChannel: features.referenceChannel, sourceToReferenceMicrophoneDistanceMeters: distance,
            peakDBFS: features.peakDBFS, rmsDBFS: features.rmsDBFS,
            onsetLatencySeconds: command.time.flatMap { time in onset.map { $0 - time } },
            effectiveImpulseWidthSeconds: features.effectiveImpulseWidthSeconds,
            thirdOctaveBandLevels: features.thirdOctaveBands, analyzedDurationSeconds: features.duration,
            takeStatus: take.status, analyzedAt: .now,
            method: "In-situ 20 ms RMS envelope and Hann-windowed 4096-point third-octave spectrum on the frozen reference channel; declared impulse responses add qualified noise-truncated Schroeder decay analysis",
            warnings: warnings,
            acousticResponseAnalysis: responseAnalysis
        )
    }

    public static func responseComparisons(project: OrgRecProject) -> [SpatialAcousticResponseComparison] {
        struct Key: Hashable { var series: UUID; var setup: UUID?; var technique: CaptureTechnique; var geometry: String; var referenceChannel: Int }
        let observations: [(SpatialAcousticCaptureProtocol, SpatialAcousticObservation)] = project.takes.compactMap { take in
            guard take.status == .accepted, let paradata = take.spatialAcousticParadata, var observation = paradata.observation else { return nil }
            observation.takeStatus = take.status
            return (paradata.protocolSnapshot, observation)
        }
        let groups = Dictionary(grouping: observations) { pair in
            Key(series: pair.0.responseSeriesID, setup: pair.1.microphoneSetupID, technique: pair.1.captureTechnique, geometry: pair.1.geometryFingerprint, referenceChannel: pair.1.referenceChannel)
        }
        return groups.values.flatMap { group -> [SpatialAcousticResponseComparison] in
            guard let first = group.first else { return [] }
            let referenceStateID = first.0.referenceStateID
            let references = group.filter { $0.1.stateID == referenceStateID }.map(\.1)
            guard !references.isEmpty else { return [] }
            return Dictionary(grouping: group.map(\.1), by: \.stateID).compactMap { stateID, targets in
                guard stateID != referenceStateID else { return nil }
                let bandCenters = Set(references.flatMap { $0.thirdOctaveBandLevels.map(\.centerFrequencyHz) })
                    .intersection(Set(targets.flatMap { $0.thirdOctaveBandLevels.map(\.centerFrequencyHz) })).sorted()
                let deltas = bandCenters.compactMap { center -> SpatialBandDelta? in
                    guard let ref = mean(references.compactMap { $0.thirdOctaveBandLevels.first(where: { $0.centerFrequencyHz == center })?.levelDBFS }),
                          let target = mean(targets.compactMap { $0.thirdOctaveBandLevels.first(where: { $0.centerFrequencyHz == center })?.levelDBFS }) else { return nil }
                    let referenceLevels = references.compactMap { $0.thirdOctaveBandLevels.first(where: { $0.centerFrequencyHz == center })?.levelDBFS }
                    let targetLevels = targets.compactMap { $0.thirdOctaveBandLevels.first(where: { $0.centerFrequencyHz == center })?.levelDBFS }
                    return SpatialBandDelta(centerFrequencyHz: center, levelDeltaDB: target - ref,
                                            referenceMeanDBFS: ref, targetMeanDBFS: target,
                                            referenceStandardDeviationDB: standardDeviation(referenceLevels),
                                            targetStandardDeviationDB: standardDeviation(targetLevels))
                }
                return SpatialAcousticResponseComparison(
                    contractVersion: "orgrec.spatial-acoustic-comparison/v1", responseSeriesID: first.0.responseSeriesID,
                    stateID: stateID, referenceStateID: referenceStateID, sourceElementID: first.0.sourceElementID,
                    pathElementIDs: first.0.pathElementIDs, geometrySnapshotID: first.0.geometrySnapshotID,
                    geometryFingerprint: first.0.geometryFingerprint, microphoneSetupID: first.1.microphoneSetupID,
                    captureTechnique: first.1.captureTechnique, referenceChannel: first.1.referenceChannel,
                    referenceTakeIDs: references.map(\.takeID).sorted { $0.uuidString < $1.uuidString },
                    targetTakeIDs: targets.map(\.takeID).sorted { $0.uuidString < $1.uuidString },
                    peakLevelDeltaDB: delta(targets.map(\.peakDBFS), references.map(\.peakDBFS)),
                    rmsLevelDeltaDB: delta(targets.map(\.rmsDBFS), references.map(\.rmsDBFS)),
                    referenceRMSStandardDeviationDB: standardDeviation(references.map(\.rmsDBFS)),
                    targetRMSStandardDeviationDB: standardDeviation(targets.map(\.rmsDBFS)),
                    onsetLatencyDeltaSeconds: delta(targets.compactMap(\.onsetLatencySeconds), references.compactMap(\.onsetLatencySeconds)),
                    impulseWidthDeltaSeconds: delta(targets.compactMap(\.effectiveImpulseWidthSeconds), references.compactMap(\.effectiveImpulseWidthSeconds)),
                    thirdOctaveBandDeltas: deltas, limitationStatement: first.0.limitationStatement, generatedAt: .now
                )
            }
        }.sorted { $0.id < $1.id }
    }

    private static func commandTime(take: TakeRecord, sourceComponentID: String, annotations: [TimedAnnotation]) -> (time: Double?, evidence: EffectTimingEvidence, uncertainty: Double?) {
        if let marker = take.spatialAcousticParadata?.events.first(where: { $0.kind == .sourceTriggered }) {
            return (marker.atSeconds, .operatorMarker, 0.02)
        }
        if let marker = take.complexCaptureParadata?.events.first(where: { $0.kind == .actionBegin }) {
            return (marker.atSeconds, .operatorMarker, 0.02)
        }
        if let marker = annotations.filter({ $0.takeID == take.id && ["operator_effect_trigger", "operator_key_down"].contains($0.code) }).min(by: { $0.atSeconds < $1.atSeconds }) {
            return (marker.atSeconds, .operatorMarker, 0.02)
        }
        if let log = take.controlEventLog, let alignment = take.audioControlAlignment {
            let candidate = log.events.first { event in
                (event.componentID == sourceComponentID || event.componentID == take.provenance?.component.id)
                    && [.activation, .trigger].contains(event.role)
            }
            if let candidate, let mapping = alignment.mappings.first(where: { $0.eventID == candidate.id && $0.withinRecordedAudio }) {
                return (mapping.audioTimeSeconds, .synchronizedControl, mapping.uncertaintySeconds)
            }
        }
        return (nil, .unavailable, nil)
    }

    private static func stageTimings(take: TakeRecord, item: RoadmapItem) -> [EffectChainStageTiming] {
        guard let process = item.complexCaptureProtocol?.processModel else { return [] }
        let events = take.complexCaptureParadata?.events ?? []
        return process.stages.map { stage in
            let begin = events.first { $0.kind == .processStageBegin && $0.stageID == stage.id }?.atSeconds
            let end = events.first { $0.kind == .processStageEnd && $0.stageID == stage.id }?.atSeconds
            let duration = begin.flatMap { start in end.map { $0 - start } }
            let planned = stage.duration?.typicalSeconds
            return EffectChainStageTiming(stageID: stage.id, label: stage.label, beginSeconds: begin, endSeconds: end,
                                          durationSeconds: duration, plannedTypicalSeconds: planned,
                                          deviationSeconds: duration.flatMap { actual in planned.map { actual - $0 } },
                                          evidence: begin == nil && end == nil ? .unavailable : .operatorMarker,
                                          uncertaintySeconds: begin == nil && end == nil ? nil : 0.02)
        }
    }

    private static func periodicity(envelope: [Double], hopSeconds: Double, expectedIntervalSeconds: Double?) -> (rate: Double, confidence: Double)? {
        guard envelope.count >= 20, hopSeconds > 0 else { return nil }
        let centeredMean = envelope.reduce(0, +) / Double(envelope.count)
        let centered = envelope.map { $0 - centeredMean }
        let minimumLag = max(2, Int(0.04 / hopSeconds)), maximumLag = min(envelope.count / 2, Int(5 / hopSeconds))
        guard minimumLag < maximumLag else { return nil }
        if let expectedIntervalSeconds {
            let lag = min(maximumLag, max(minimumLag, Int((expectedIntervalSeconds / hopSeconds).rounded())))
            var dot = 0.0, left = 0.0, right = 0.0
            for index in 0..<(centered.count - lag) {
                dot += centered[index] * centered[index + lag]; left += centered[index] * centered[index]; right += centered[index + lag] * centered[index + lag]
            }
            let confidence = dot / sqrt(max(1e-24, left * right))
            return (1 / (Double(lag) * hopSeconds), min(1, max(0, confidence)))
        }
        var bestLag = 0, best = -Double.infinity
        for lag in minimumLag...maximumLag {
            var dot = 0.0, left = 0.0, right = 0.0
            for index in 0..<(centered.count - lag) {
                dot += centered[index] * centered[index + lag]; left += centered[index] * centered[index]; right += centered[index + lag] * centered[index + lag]
            }
            let correlation = dot / sqrt(max(1e-24, left * right))
            if correlation > best { best = correlation; bestLag = lag }
        }
        guard bestLag > 0 else { return nil }
        return (1 / (Double(bestLag) * hopSeconds), min(1, max(0, best)))
    }

    private static func temporalEntropy(_ intervals: [Double]) -> Double? {
        guard intervals.count >= 2, let minimum = intervals.min(), let maximum = intervals.max(), maximum > minimum else { return intervals.count >= 2 ? 0 : nil }
        let bins = min(8, max(2, Int(sqrt(Double(intervals.count)).rounded(.up))))
        var counts = [Double](repeating: 0, count: bins)
        for value in intervals { counts[min(bins - 1, Int((value - minimum) / (maximum - minimum) * Double(bins)))] += 1 }
        let entropy = counts.filter { $0 > 0 }.reduce(0.0) { result, count in let p = count / Double(intervals.count); return result - p * log(p) }
        return entropy / log(Double(bins))
    }

    private static func mean(_ values: [Double]) -> Double? { values.isEmpty ? nil : values.reduce(0, +) / Double(values.count) }
    private static func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 2, let center = mean(values) else { return nil }
        return sqrt(values.reduce(0) { $0 + pow($1 - center, 2) } / Double(values.count - 1))
    }
    private static func delta(_ targets: [Double], _ references: [Double]) -> Double? { guard let target = mean(targets), let reference = mean(references) else { return nil }; return target - reference }
}

private enum P2AudioFeatureExtractor {
    struct Features {
        var referenceChannel: Int; var duration: Double; var peakDBFS: Double; var rmsDBFS: Double
        var envelope: [Double]; var hopSeconds: Double; var detectedOnsetSeconds: Double?
        var effectiveImpulseWidthSeconds: Double?; var eventTimes: [Double]
        var thirdOctaveBands: [SpectralBandLevel]; var warnings: [String]
    }
    private static let centers: [Double] = [31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1_000, 1_250, 1_600, 2_000, 2_500, 3_150, 4_000, 5_000, 6_300, 8_000, 10_000, 12_500, 16_000]

    static func extract(fileURL: URL, referenceChannel: Int, maximumDurationSeconds: Double = 1_800) throws -> Features {
        let file = try AVAudioFile(forReading: fileURL), format = file.processingFormat
        guard file.length > 0, format.channelCount > 0 else { throw OrgRecError.unsupportedAudio("The P2 take contains no readable audio.") }
        let selected = max(0, min(Int(format.channelCount) - 1, referenceChannel))
        let windowFrames = max(128, Int(format.sampleRate * 0.02)), hopSeconds = Double(windowFrames) / format.sampleRate
        let bufferFrames: AVAudioFrameCount = 65_536
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrames) else { throw OrgRecError.unsupportedAudio("Cannot allocate the P2 analysis buffer.") }
        let limit = min(file.length, Int64(max(1, min(1_800, maximumDurationSeconds)) * format.sampleRate))
        var remaining = limit, sampleCount = 0, peak = 0.0, sumSquares = 0.0
        var envelopeCarry: [Float] = [], envelope: [Double] = [], spectralCarry: [Float] = []
        let fftSize = 4_096; var bandPowers = [Double](repeating: 0, count: centers.count), spectralFrames = 0
        while remaining > 0 {
            let requested = AVAudioFrameCount(min(Int64(bufferFrames), remaining)); try file.read(into: buffer, frameCount: requested)
            guard buffer.frameLength > 0, let channels = buffer.floatChannelData else { break }
            let chunk = Array(UnsafeBufferPointer(start: channels[selected], count: Int(buffer.frameLength)))
            for sample in chunk { let value = Double(sample); peak = max(peak, abs(value)); sumSquares += value * value }
            sampleCount += chunk.count; envelopeCarry.append(contentsOf: chunk); spectralCarry.append(contentsOf: chunk)
            while envelopeCarry.count >= windowFrames {
                let slice = envelopeCarry.prefix(windowFrames); envelope.append(sqrt(slice.reduce(0.0) { $0 + Double($1 * $1) } / Double(windowFrames)))
                envelopeCarry.removeFirst(windowFrames)
            }
            while spectralCarry.count >= fftSize {
                let powers = bandPower(Array(spectralCarry.prefix(fftSize)), sampleRate: format.sampleRate)
                for index in powers.indices { bandPowers[index] += powers[index] }
                spectralFrames += 1; spectralCarry.removeFirst(fftSize)
            }
            remaining -= Int64(chunk.count)
        }
        guard sampleCount > 0 else { throw OrgRecError.unsupportedAudio("The P2 take contains no readable samples.") }
        let duration = Double(sampleCount) / format.sampleRate, rms = sqrt(sumSquares / Double(sampleCount))
        let sorted = envelope.sorted(); let floor = quantile(sorted, 0.20), high = quantile(sorted, 0.95)
        let threshold = max(floor * 3, floor + 0.18 * max(0, high - floor), 1e-7)
        let onsetIndex = envelope.firstIndex { $0 >= threshold }
        let eventIndices = detectEvents(envelope: envelope, threshold: threshold, refractoryFrames: max(2, Int(0.04 / hopSeconds)))
        let width: Double?
        if let primary = eventIndices.first ?? onsetIndex {
            let localPeak = envelope[primary...].prefix(max(1, Int(5 / hopSeconds))).max() ?? envelope[primary]
            let widthThreshold = max(floor * 1.5, localPeak * 0.1)
            let start = (0...primary).reversed().first { envelope[$0] < widthThreshold }.map { $0 + 1 } ?? 0
            let end = (primary..<envelope.count).first { envelope[$0] < widthThreshold } ?? envelope.count - 1
            width = Double(max(0, end - start)) * hopSeconds
        } else { width = nil }
        let bands = centers.enumerated().compactMap { index, center -> SpectralBandLevel? in
            let lower = center / pow(2, 1.0 / 6), upper = center * pow(2, 1.0 / 6)
            guard lower < format.sampleRate / 2 else { return nil }
            let amplitude = sqrt(bandPowers[index] / Double(max(1, spectralFrames)))
            return SpectralBandLevel(centerFrequencyHz: center, lowerFrequencyHz: lower, upperFrequencyHz: min(upper, format.sampleRate / 2), levelDBFS: db(amplitude))
        }
        var warnings: [String] = []
        if peak >= 0.999 { warnings.append("Clipping occurred in the P2 analysis channel.") }
        if spectralFrames == 0 { warnings.append("The take was too short for a third-octave spectrum.") }
        return Features(referenceChannel: selected, duration: duration, peakDBFS: db(peak), rmsDBFS: db(rms), envelope: envelope,
                        hopSeconds: hopSeconds, detectedOnsetSeconds: onsetIndex.map { Double($0) * hopSeconds }, effectiveImpulseWidthSeconds: width,
                        eventTimes: eventIndices.map { Double($0) * hopSeconds }, thirdOctaveBands: bands, warnings: warnings)
    }

    private static func detectEvents(envelope: [Double], threshold: Double, refractoryFrames: Int) -> [Int] {
        guard envelope.count >= 3 else { return [] }
        var result: [Int] = [], last = -refractoryFrames
        for index in 1..<(envelope.count - 1) where envelope[index] >= threshold && envelope[index] >= envelope[index - 1] && envelope[index] >= envelope[index + 1] {
            if index - last >= refractoryFrames { result.append(index); last = index }
            else if let previous = result.last, envelope[index] > envelope[previous] { result[result.count - 1] = index; last = index }
        }
        return result
    }

    private static func bandPower(_ source: [Float], sampleRate: Double) -> [Double] {
        let count = source.count, log2n = vDSP_Length(log2(Double(count)))
        guard count.isMultiple(of: 2), let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [Double](repeating: 0, count: centers.count) }
        defer { vDSP_destroy_fftsetup(setup) }
        var window = [Float](repeating: 0, count: count), samples = source
        vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_NORM)); vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(count))
        var real = [Float](repeating: 0, count: count / 2), imag = real
        samples.withUnsafeBytes { raw in raw.bindMemory(to: DSPComplex.self).withMemoryRebound(to: DSPComplex.self) { complex in
            real.withUnsafeMutableBufferPointer { rp in imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!); vDSP_ctoz(complex.baseAddress!, 2, &split, 1, vDSP_Length(count / 2)); vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }}
        }}
        let binWidth = sampleRate / Double(count), normalization = Double(count * count)
        return centers.map { center in
            let lower = max(1, Int(floor((center / pow(2, 1.0 / 6)) / binWidth)))
            let upper = min(count / 2 - 1, Int(ceil((center * pow(2, 1.0 / 6)) / binWidth)))
            guard lower <= upper else { return 0 }
            return (lower...upper).reduce(0.0) { result, index in result + (Double(real[index]) * Double(real[index]) + Double(imag[index]) * Double(imag[index])) } / normalization
        }
    }
    private static func quantile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let x = min(max(p, 0), 1) * Double(sorted.count - 1), lower = Int(x.rounded(.down)), upper = Int(x.rounded(.up))
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (x - Double(lower))
    }
    private static func db(_ amplitude: Double) -> Double { 20 * log10(max(amplitude, 1e-12)) }
}
