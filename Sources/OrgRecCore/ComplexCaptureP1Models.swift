import Accelerate
import AVFoundation
import Foundation

// MARK: - Physical actuation and measured response

/// Input dimensions remain independent. In particular, a MIDI velocity is a
/// controller value and is never used as a synonym for physical intensity.
public enum PhysicalActuationInputKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case midiVelocity
    case gateDuration
    case deactivationOffset
    case actuatorRoute
    case force
    case pressure
    case pedalPath
    case controllerValue
    case custom

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .midiVelocity: "MIDI velocity"
        case .gateDuration: "Activation / gate duration"
        case .deactivationOffset: "Deactivation offset"
        case .actuatorRoute: "Actuator route"
        case .force: "Actuator force"
        case .pressure: "Actuator pressure"
        case .pedalPath: "Pedal path"
        case .controllerValue: "Controller value"
        case .custom: "Custom physical input"
        }
    }
}

public enum DeactivationOffsetReference: String, Codable, CaseIterable, Identifiable, Sendable {
    case activationCommand
    case acousticOnset
    case processStageStart
    case operatorMarker
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .activationCommand: "Activation command"
        case .acousticOnset: "Acoustic onset"
        case .processStageStart: "Process-stage start"
        case .operatorMarker: "Operator marker"
        }
    }
}

public struct PhysicalActuationInput: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: PhysicalActuationInputKind
    public var label: String
    public var numericValue: Double?
    public var textValue: String?
    public var unit: String?
    public var reference: String?
    public var evidence: ActuationEvidenceSource
    public var uncertainty: Double?

    public init(
        kind: PhysicalActuationInputKind,
        label: String = "",
        numericValue: Double? = nil,
        textValue: String? = nil,
        unit: String? = nil,
        reference: String? = nil,
        evidence: ActuationEvidenceSource = .operatorPlanned,
        uncertainty: Double? = nil
    ) {
        self.kind = kind
        self.label = label.isEmpty ? kind.displayName : label
        self.numericValue = numericValue
        self.textValue = textValue
        self.unit = unit
        self.reference = reference
        self.evidence = evidence
        self.uncertainty = uncertainty
        let keyParts: [String] = [kind.rawValue, self.label, numericValue.map { String($0) } ?? "", textValue ?? "", unit ?? "", reference ?? ""]
        let key = keyParts.joined(separator: "|")
        self.id = "physical-input:\(Data(key.utf8).sha256Hex)"
    }

    public var validationIssues: [String] {
        var issues: [String] = []
        if numericValue?.isFinite == false { issues.append("\(label) must be finite.") }
        if let uncertainty, uncertainty < 0 || uncertainty.isFinite == false {
            issues.append("\(label) uncertainty must be a non-negative finite value.")
        }
        switch kind {
        case .midiVelocity:
            if let numericValue, !(1...127).contains(numericValue) { issues.append("MIDI velocity must be 1…127.") }
        case .gateDuration, .force, .pressure:
            if let numericValue, numericValue <= 0 { issues.append("\(label) must be positive.") }
        case .deactivationOffset:
            if numericValue == nil { issues.append("Deactivation offset requires a numeric value.") }
            if reference?.isEmpty != false { issues.append("Deactivation offset requires an explicit reference event.") }
        case .actuatorRoute:
            if textValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { issues.append("Actuator route requires an identifier or label.") }
        case .pedalPath:
            if textValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { issues.append("Pedal path requires a trajectory reference.") }
        case .controllerValue, .custom:
            if numericValue == nil && textValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                issues.append("\(label) requires a value.")
            }
        }
        return issues
    }
}

public struct PhysicalActuationVariant: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var label: String
    public var inputs: [PhysicalActuationInput]
    public var pedalPath: ActuationCurve?
    public var notes: String

    public init(
        contractVersion: String = "orgrec.physical-actuation/v1",
        id: UUID = UUID(),
        label: String,
        midiVelocity: Int? = nil,
        gateDurationSeconds: Double? = nil,
        deactivationOffsetSeconds: Double? = nil,
        deactivationOffsetReference: DeactivationOffsetReference? = nil,
        actuatorRoute: String? = nil,
        forceNewtons: Double? = nil,
        pressurePascals: Double? = nil,
        controllerValue: Double? = nil,
        controllerUnit: String? = nil,
        pedalPath: ActuationCurve? = nil,
        customInputs: [PhysicalActuationInput] = [],
        evidence: ActuationEvidenceSource = .operatorPlanned,
        notes: String = ""
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.label = label
        var values = customInputs
        if let midiVelocity { values.append(.init(kind: .midiVelocity, numericValue: Double(midiVelocity), unit: "MIDI 1–127", evidence: evidence)) }
        if let gateDurationSeconds { values.append(.init(kind: .gateDuration, numericValue: gateDurationSeconds, unit: "s", reference: "activation-command", evidence: evidence)) }
        if let deactivationOffsetSeconds {
            values.append(.init(kind: .deactivationOffset, numericValue: deactivationOffsetSeconds, unit: "s", reference: (deactivationOffsetReference ?? .activationCommand).rawValue, evidence: evidence))
        }
        if let actuatorRoute { values.append(.init(kind: .actuatorRoute, textValue: actuatorRoute, evidence: evidence)) }
        if let forceNewtons { values.append(.init(kind: .force, numericValue: forceNewtons, unit: "N", evidence: evidence)) }
        if let pressurePascals { values.append(.init(kind: .pressure, numericValue: pressurePascals, unit: "Pa", evidence: evidence)) }
        if let controllerValue { values.append(.init(kind: .controllerValue, numericValue: controllerValue, unit: controllerUnit ?? "controller units", evidence: evidence)) }
        if let pedalPath { values.append(.init(kind: .pedalPath, textValue: pedalPath.id.uuidString.lowercased(), unit: pedalPath.timeBasis.rawValue, evidence: pedalPath.evidenceSource)) }
        self.inputs = values.sorted { $0.kind.rawValue < $1.kind.rawValue }
        self.pedalPath = pedalPath
        self.notes = notes
    }

    public func input(_ kind: PhysicalActuationInputKind) -> PhysicalActuationInput? { inputs.first { $0.kind == kind } }
    public var midiVelocity: Int? { input(.midiVelocity)?.numericValue.map { Int($0.rounded()) } }
    public var gateDurationSeconds: Double? { input(.gateDuration)?.numericValue }
    public var actuatorRoute: String? { input(.actuatorRoute)?.textValue }
    public var validationIssues: [String] {
        var issues = inputs.flatMap(\.validationIssues)
        if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("An actuation variant requires a label.") }
        if inputs.isEmpty { issues.append("An actuation variant requires at least one independent input dimension.") }
        if let pedalPath { issues.append(contentsOf: pedalPath.validationIssues) }
        return Array(Set(issues)).sorted()
    }
    public var summary: String {
        inputs.map { input in
            if let value = input.numericValue { return "\(input.label) \(value.formatted(.number.precision(.fractionLength(0...4)))) \(input.unit ?? "")" }
            return "\(input.label) \(input.textValue ?? "")"
        }.joined(separator: " · ")
    }
}

public enum ActuatorResponseFunctionStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case measured
    case reviewed
}

public struct ActuatorResponseObservation: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var takeID: UUID
    public var variantID: UUID
    public var inputs: [PhysicalActuationInput]
    public var peakLevelDBFS: Double?
    public var rmsLevelDBFS: Double?
    public var acousticOnsetLatencySeconds: Double?
    public var acousticDurationSeconds: Double?
    public var processOutcome: String?
    public var timingUncertaintySeconds: Double?
    public var measuredAt: Date
    public var takeStatus: TakeStatus

    public init(
        id: UUID = UUID(), takeID: UUID, variantID: UUID, inputs: [PhysicalActuationInput],
        peakLevelDBFS: Double?, rmsLevelDBFS: Double?, acousticOnsetLatencySeconds: Double?,
        acousticDurationSeconds: Double?, processOutcome: String? = nil,
        timingUncertaintySeconds: Double? = nil, measuredAt: Date = .now, takeStatus: TakeStatus
    ) {
        self.id = id; self.takeID = takeID; self.variantID = variantID; self.inputs = inputs
        self.peakLevelDBFS = peakLevelDBFS; self.rmsLevelDBFS = rmsLevelDBFS
        self.acousticOnsetLatencySeconds = acousticOnsetLatencySeconds; self.acousticDurationSeconds = acousticDurationSeconds
        self.processOutcome = processOutcome; self.timingUncertaintySeconds = timingUncertaintySeconds
        self.measuredAt = measuredAt; self.takeStatus = takeStatus
    }
}

public struct ActuatorTransferEstimate: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var inputDimension: PhysicalActuationInputKind
    public var inputUnit: String?
    public var outputDimension: String
    public var outputUnit: String
    public var sampleCount: Int
    public var minimumInput: Double
    public var maximumInput: Double
    public var slope: Double
    public var intercept: Double
    public var coefficientOfDetermination: Double?
    public var method: String
    public var contributingTakeIDs: [UUID]

    public init(
        inputDimension: PhysicalActuationInputKind,
        inputUnit: String?,
        outputDimension: String,
        outputUnit: String,
        sampleCount: Int,
        minimumInput: Double,
        maximumInput: Double,
        slope: Double,
        intercept: Double,
        coefficientOfDetermination: Double?,
        method: String = "ordinary least squares over retained measured points",
        contributingTakeIDs: [UUID]
    ) {
        let key = "\(inputDimension.rawValue)|\(outputDimension)|\(inputUnit ?? "")|\(outputUnit)"
        self.id = "actuator-transfer:\(Data(key.utf8).sha256Hex)"
        self.inputDimension = inputDimension
        self.inputUnit = inputUnit
        self.outputDimension = outputDimension
        self.outputUnit = outputUnit
        self.sampleCount = sampleCount
        self.minimumInput = minimumInput
        self.maximumInput = maximumInput
        self.slope = slope
        self.intercept = intercept
        self.coefficientOfDetermination = coefficientOfDetermination
        self.method = method
        self.contributingTakeIDs = contributingTakeIDs
    }
}

public struct ActuatorResponseFunction: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: String
    public var componentID: String
    public var componentLabel: String
    public var inputDimensions: [PhysicalActuationInputKind]
    public var outputDimensions: [String]
    public var observations: [ActuatorResponseObservation]
    public var transferEstimates: [ActuatorTransferEstimate]? = nil
    public var status: ActuatorResponseFunctionStatus
    public var notes: String

    public init(componentID: String, componentLabel: String, observations: [ActuatorResponseObservation], status: ActuatorResponseFunctionStatus = .measured, notes: String = "") {
        self.contractVersion = "orgrec.actuator-response-function/v1"
        self.id = "actuator-response:\(Data(componentID.utf8).sha256Hex)"
        self.componentID = componentID; self.componentLabel = componentLabel
        self.inputDimensions = Array(Set(observations.flatMap { $0.inputs.map(\.kind) })).sorted { $0.rawValue < $1.rawValue }
        self.outputDimensions = ["peak-level-dBFS", "rms-level-dBFS", "acoustic-onset-latency-seconds", "acoustic-duration-seconds", "process-outcome"]
        self.observations = observations.sorted { $0.measuredAt < $1.measuredAt }
        self.transferEstimates = Self.estimates(observations: observations)
        self.status = status; self.notes = notes
    }

    private static func estimates(observations: [ActuatorResponseObservation]) -> [ActuatorTransferEstimate] {
        let outputs: [(name: String, unit: String, value: (ActuatorResponseObservation) -> Double?)] = [
            ("peak-level-dBFS", "dBFS", { $0.peakLevelDBFS }),
            ("rms-level-dBFS", "dBFS", { $0.rmsLevelDBFS }),
            ("acoustic-onset-latency-seconds", "s", { $0.acousticOnsetLatencySeconds }),
            ("acoustic-duration-seconds", "s", { $0.acousticDurationSeconds }),
        ]
        var estimates: [ActuatorTransferEstimate] = []
        for inputKind in PhysicalActuationInputKind.allCases {
            for output in outputs {
                var points: [(x: Double, y: Double, takeID: UUID, unit: String?)] = []
                for observation in observations {
                    guard let input = observation.inputs.first(where: { $0.kind == inputKind }),
                          let x = input.numericValue,
                          let y = output.value(observation),
                          x.isFinite, y.isFinite else { continue }
                    points.append((x, y, observation.takeID, input.unit))
                }
                guard points.count >= 2, Set(points.map(\.x)).count >= 2 else { continue }
                let count = Double(points.count)
                let meanX = points.reduce(0) { $0 + $1.x } / count
                let meanY = points.reduce(0) { $0 + $1.y } / count
                let ssXX = points.reduce(0) { $0 + pow($1.x - meanX, 2) }
                guard ssXX > 0 else { continue }
                let slope = points.reduce(0) { $0 + ($1.x - meanX) * ($1.y - meanY) } / ssXX
                let intercept = meanY - slope * meanX
                let residual = points.reduce(0) { $0 + pow($1.y - (intercept + slope * $1.x), 2) }
                let total = points.reduce(0) { $0 + pow($1.y - meanY, 2) }
                let rSquared: Double?
                if total > 1e-12 { rSquared = max(0, min(1, 1 - residual / total)) }
                else { rSquared = residual <= 1e-12 ? 1 : nil }
                estimates.append(ActuatorTransferEstimate(
                    inputDimension: inputKind,
                    inputUnit: points.compactMap(\.unit).first,
                    outputDimension: output.name,
                    outputUnit: output.unit,
                    sampleCount: points.count,
                    minimumInput: points.map(\.x).min() ?? 0,
                    maximumInput: points.map(\.x).max() ?? 0,
                    slope: slope,
                    intercept: intercept,
                    coefficientOfDetermination: rSquared,
                    contributingTakeIDs: points.map(\.takeID)
                ))
            }
        }
        return estimates.sorted {
            $0.inputDimension.rawValue == $1.inputDimension.rawValue
                ? $0.outputDimension < $1.outputDimension
                : $0.inputDimension.rawValue < $1.inputDimension.rawValue
        }
    }
}

// MARK: - Declarative, bounded processes

public enum CaptureProcessKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case oneShot, sustained, periodic, irregular, sequential, composite, stochastic
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
    public var mayRepeat: Bool { [.periodic, .irregular, .stochastic].contains(self) }
}

public enum CaptureProcessOrdering: String, Codable, CaseIterable, Identifiable, Sendable {
    case sequential, concurrent, overlapping, conditional, randomized
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public enum TimingDistributionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case fixed, uniform, normal, logNormal, empirical, unknown
    public var id: String { rawValue }
    public var displayName: String { rawValue == "logNormal" ? "Log-normal" : rawValue.capitalized }
}

public struct ProcessTimingEnvelope: Codable, Hashable, Sendable {
    public var minimumSeconds: Double
    public var typicalSeconds: Double
    public var maximumSeconds: Double
    public var distribution: TimingDistributionKind
    public var sampleCount: Int?
    public var evidence: String

    public init(minimumSeconds: Double, typicalSeconds: Double, maximumSeconds: Double, distribution: TimingDistributionKind = .fixed, sampleCount: Int? = nil, evidence: String = "operator-planned") {
        self.minimumSeconds = minimumSeconds; self.typicalSeconds = typicalSeconds; self.maximumSeconds = maximumSeconds
        self.distribution = distribution; self.sampleCount = sampleCount; self.evidence = evidence
    }
    public var validationIssues: [String] {
        var result: [String] = []
        if [minimumSeconds, typicalSeconds, maximumSeconds].contains(where: { !$0.isFinite || $0 < 0 }) { result.append("Process timing values must be non-negative finite seconds.") }
        if minimumSeconds > typicalSeconds || typicalSeconds > maximumSeconds { result.append("Process timing must satisfy minimum ≤ typical ≤ maximum.") }
        if distribution == .fixed && (minimumSeconds != typicalSeconds || typicalSeconds != maximumSeconds) { result.append("Fixed timing requires equal minimum, typical, and maximum values.") }
        if let sampleCount, sampleCount < 1 { result.append("Empirical timing sample count must be positive.") }
        return result
    }
}

public enum CaptureProcessStageAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case activate, deactivate, strike, hold, wait, repeatChildren, observe, cancel, custom
    public var id: String { rawValue }
    public var displayName: String { rawValue.replacingOccurrences(of: "Children", with: " children").capitalized }
}

public struct CaptureProcessStage: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var componentID: String?
    public var action: CaptureProcessStageAction
    public var ordering: CaptureProcessOrdering
    public var childStageIDs: [String]
    public var startDelay: ProcessTimingEnvelope
    public var duration: ProcessTimingEnvelope?
    public var repetitionInterval: ProcessTimingEnvelope?
    public var minimumRepeats: Int
    public var maximumRepeats: Int
    public var probability: Double?
    public var notes: String

    public init(id: String, label: String, componentID: String? = nil, action: CaptureProcessStageAction, ordering: CaptureProcessOrdering = .sequential, childStageIDs: [String] = [], startDelay: ProcessTimingEnvelope = .init(minimumSeconds: 0, typicalSeconds: 0, maximumSeconds: 0), duration: ProcessTimingEnvelope? = nil, repetitionInterval: ProcessTimingEnvelope? = nil, minimumRepeats: Int = 1, maximumRepeats: Int = 1, probability: Double? = nil, notes: String = "") {
        self.id = id; self.label = label; self.componentID = componentID; self.action = action; self.ordering = ordering
        self.childStageIDs = childStageIDs; self.startDelay = startDelay; self.duration = duration; self.repetitionInterval = repetitionInterval
        self.minimumRepeats = minimumRepeats; self.maximumRepeats = maximumRepeats; self.probability = probability; self.notes = notes
    }
}

public enum ProcessTerminationKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case completed, controlRelease, elapsedDuration, iterationCount, acousticSilence, externalCancellation, manual
    public var id: String { rawValue }
    public var displayName: String { rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
}

public struct ProcessTerminationCondition: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var kind: ProcessTerminationKind
    public var threshold: Double?
    public var unit: String?
    public var controlBindingID: UUID?
    public var description: String
    public init(id: UUID = UUID(), kind: ProcessTerminationKind, threshold: Double? = nil, unit: String? = nil, controlBindingID: UUID? = nil, description: String = "") {
        self.id = id; self.kind = kind; self.threshold = threshold; self.unit = unit; self.controlBindingID = controlBindingID; self.description = description
    }
}

public struct CaptureProcessModel: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var name: String
    public var kind: CaptureProcessKind
    public var ordering: CaptureProcessOrdering
    public var rootStageIDs: [String]
    public var stages: [CaptureProcessStage]
    public var terminationConditions: [ProcessTerminationCondition]
    public var maximumIterations: Int?
    public var maximumDurationSeconds: Double?
    public var cancellationControlBindingID: UUID?
    public var notes: String

    public init(contractVersion: String = "orgrec.capture-process/v1", id: UUID = UUID(), name: String, kind: CaptureProcessKind, ordering: CaptureProcessOrdering, rootStageIDs: [String], stages: [CaptureProcessStage], terminationConditions: [ProcessTerminationCondition], maximumIterations: Int? = nil, maximumDurationSeconds: Double? = nil, cancellationControlBindingID: UUID? = nil, notes: String = "") {
        self.contractVersion = contractVersion; self.id = id; self.name = name; self.kind = kind; self.ordering = ordering
        self.rootStageIDs = rootStageIDs; self.stages = stages; self.terminationConditions = terminationConditions
        self.maximumIterations = maximumIterations; self.maximumDurationSeconds = maximumDurationSeconds
        self.cancellationControlBindingID = cancellationControlBindingID; self.notes = notes
    }

    public var validationIssues: [String] {
        var issues: [String] = []
        let ids = stages.map(\.id)
        let idSet = Set(ids)
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("A process requires a name.") }
        if stages.isEmpty { issues.append("A process requires at least one stage.") }
        if idSet.count != ids.count || ids.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { issues.append("Process stage identifiers must be non-empty and unique.") }
        if rootStageIDs.isEmpty || rootStageIDs.contains(where: { !idSet.contains($0) }) { issues.append("Every process requires valid root stages.") }
        for stage in stages {
            issues.append(contentsOf: stage.startDelay.validationIssues)
            if let duration = stage.duration { issues.append(contentsOf: duration.validationIssues) }
            if let interval = stage.repetitionInterval { issues.append(contentsOf: interval.validationIssues) }
            if stage.minimumRepeats < 0 || stage.maximumRepeats < max(1, stage.minimumRepeats) { issues.append("Stage \(stage.id) has invalid repeat bounds.") }
            if stage.childStageIDs.contains(where: { !idSet.contains($0) }) { issues.append("Stage \(stage.id) references an unknown child stage.") }
            if let probability = stage.probability, !(0...1).contains(probability) { issues.append("Stage \(stage.id) probability must be 0…1.") }
        }
        var visiting = Set<String>(), visited = Set<String>()
        func hasCycle(_ id: String) -> Bool {
            if visiting.contains(id) { return true }
            if visited.contains(id) { return false }
            visiting.insert(id)
            let children = stages.first(where: { $0.id == id })?.childStageIDs ?? []
            if children.contains(where: hasCycle) { return true }
            visiting.remove(id); visited.insert(id); return false
        }
        if ids.contains(where: hasCycle) { issues.append("Process child stages must form an acyclic graph.") }
        if let maximumIterations, maximumIterations < 1 { issues.append("Maximum iterations must be positive.") }
        if let maximumDurationSeconds, maximumDurationSeconds <= 0 || !maximumDurationSeconds.isFinite { issues.append("Maximum process duration must be positive and finite.") }
        if kind.mayRepeat && maximumIterations == nil && maximumDurationSeconds == nil { issues.append("Repeating, irregular, and stochastic processes require a hard iteration or duration bound.") }
        if kind.mayRepeat && cancellationControlBindingID == nil && !terminationConditions.contains(where: { [.controlRelease, .externalCancellation, .manual].contains($0.kind) }) {
            issues.append("Repeating, irregular, and stochastic processes require an explicit cancellation path.")
        }
        if terminationConditions.isEmpty { issues.append("A process requires at least one termination condition.") }
        return Array(Set(issues)).sorted()
    }
}

// MARK: - Discrete shutters and pedal mapping

public struct ShutterElement: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var sequenceIndex: Int
    public init(id: String, label: String, sequenceIndex: Int) { self.id = id; self.label = label; self.sequenceIndex = sequenceIndex }
}

public struct DiscreteShutterState: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var label: String
    /// Per-shutter openness, where 0 is closed and 1 is fully open.
    public var shutterOpenness: [String: Double]
    public init(id: String, label: String, shutterOpenness: [String: Double]) { self.id = id; self.label = label; self.shutterOpenness = shutterOpenness }
}

public enum PedalTravelDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case opening, closing, both
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public struct PedalShutterMappingPoint: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var pedalPosition: Double
    public var shutterStateID: String
    public var direction: PedalTravelDirection
    public var uncertainty: Double?
    public init(id: UUID = UUID(), pedalPosition: Double, shutterStateID: String, direction: PedalTravelDirection = .both, uncertainty: Double? = nil) {
        self.id = id; self.pedalPosition = pedalPosition; self.shutterStateID = shutterStateID; self.direction = direction; self.uncertainty = uncertainty
    }
}

public struct DiscreteShutterTopology: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var name: String
    public var enclosureComponentID: String
    public var pedalComponentID: String?
    public var shutters: [ShutterElement]
    public var states: [DiscreteShutterState]
    public var pedalMapping: [PedalShutterMappingPoint]
    public var evidence: String
    public var notes: String

    public init(contractVersion: String = "orgrec.discrete-shutter-topology/v1", id: UUID = UUID(), name: String, enclosureComponentID: String, pedalComponentID: String? = nil, shutters: [ShutterElement], states: [DiscreteShutterState], pedalMapping: [PedalShutterMappingPoint], evidence: String = "operator-documented", notes: String = "") {
        self.contractVersion = contractVersion; self.id = id; self.name = name; self.enclosureComponentID = enclosureComponentID
        self.pedalComponentID = pedalComponentID; self.shutters = shutters.sorted { $0.sequenceIndex < $1.sequenceIndex }
        self.states = states; self.pedalMapping = pedalMapping.sorted { $0.pedalPosition < $1.pedalPosition }; self.evidence = evidence; self.notes = notes
    }

    public var validationIssues: [String] {
        var issues: [String] = []
        let shutterIDs = Set(shutters.map(\.id)), stateIDs = Set(states.map(\.id))
        if shutters.isEmpty { issues.append("A shutter topology requires at least one shutter.") }
        if shutterIDs.count != shutters.count { issues.append("Shutter identifiers must be unique.") }
        if states.isEmpty { issues.append("A shutter topology requires at least one discrete state.") }
        if stateIDs.count != states.count { issues.append("Shutter-state identifiers must be unique.") }
        for state in states {
            if Set(state.shutterOpenness.keys) != shutterIDs { issues.append("State \(state.label) must specify every shutter exactly once.") }
            if state.shutterOpenness.values.contains(where: { !(0...1).contains($0) || !$0.isFinite }) { issues.append("Shutter openness must be normalized 0…1.") }
        }
        if pedalMapping.isEmpty { issues.append("Document at least one pedal-to-shutter-state mapping point.") }
        if pedalMapping.contains(where: { !(0...1).contains($0.pedalPosition) || !stateIDs.contains($0.shutterStateID) }) { issues.append("Pedal mapping points must use positions 0…1 and known shutter states.") }
        let grouped = Dictionary(grouping: pedalMapping, by: { "\($0.direction.rawValue)|\(String(format: "%.9f", $0.pedalPosition))" })
        if grouped.values.contains(where: { $0.count > 1 }) { issues.append("A pedal position may map to only one state per travel direction.") }
        return Array(Set(issues)).sorted()
    }

    public func state(at pedalPosition: Double, direction: PedalTravelDirection) -> DiscreteShutterState? {
        let position = min(max(pedalPosition, 0), 1)
        let candidates = pedalMapping.filter { $0.direction == .both || $0.direction == direction }
        let point: PedalShutterMappingPoint?
        if direction == .closing { point = candidates.filter { $0.pedalPosition >= position }.min { $0.pedalPosition < $1.pedalPosition } ?? candidates.last }
        else { point = candidates.filter { $0.pedalPosition <= position }.max { $0.pedalPosition < $1.pedalPosition } ?? candidates.first }
        return point.flatMap { selected in states.first { $0.id == selected.shutterStateID } }
    }
}

// MARK: - Tremulant and operational baselines

public enum TremulantCaptureCondition: String, Codable, CaseIterable, Identifiable, Sendable {
    case withoutTremulant, steadyWithTremulant, activationTransition, deactivationTransition
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .withoutTremulant: "Without tremulant"
        case .steadyWithTremulant: "Steady with tremulant"
        case .activationTransition: "Activation transition"
        case .deactivationTransition: "Deactivation transition"
        }
    }
}

public enum TremulantCoverageScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case representative, complete
    public var id: String { rawValue }
    public var displayName: String { rawValue.capitalized }
}

public struct TremulantCaptureProtocol: Codable, Hashable, Sendable {
    public var tremulantComponentID: String
    public var affectedComponentID: String
    public var condition: TremulantCaptureCondition
    public var coverageScope: TremulantCoverageScope
    public var analyzeAmplitudeModulation: Bool
    public var analyzeFrequencyModulation: Bool
    public var analyzeSettlingAndTransition: Bool
    public var notes: String
    public init(tremulantComponentID: String, affectedComponentID: String, condition: TremulantCaptureCondition, coverageScope: TremulantCoverageScope, analyzeAmplitudeModulation: Bool = true, analyzeFrequencyModulation: Bool = true, analyzeSettlingAndTransition: Bool = true, notes: String = "") {
        self.tremulantComponentID = tremulantComponentID; self.affectedComponentID = affectedComponentID; self.condition = condition; self.coverageScope = coverageScope
        self.analyzeAmplitudeModulation = analyzeAmplitudeModulation; self.analyzeFrequencyModulation = analyzeFrequencyModulation
        self.analyzeSettlingAndTransition = analyzeSettlingAndTransition; self.notes = notes
    }
}

public struct TremulantResponseAnalysis: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var amplitudeModulationRateHz: Double?
    public var amplitudeModulationDepthDB: Double?
    public var frequencyModulationRateHz: Double?
    public var frequencyModulationDepthCents: Double?
    public var commandTimeSeconds: Double?
    public var modulationDetectedTimeSeconds: Double?
    public var transitionTimeSeconds: Double?
    public var settlingTimeSeconds: Double?
    public var timingUncertaintySeconds: Double?
    public var method: String
    public var warnings: [String]
}

public enum OperationalBaselineKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case roomInstrumentOff, poweredBlowerOff, blowerSteady, windSystemSteady, electricalSystem, ventilation, instrumentIdle, custom
    public var id: String { rawValue }
    public var displayName: String { rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
}

public enum BaselinePreservationRole: String, Codable, CaseIterable, Sendable {
    case virtualizationLayer
    case contextualReference
    case faultEvidence
}

public struct OperationalBaselineProtocol: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var kind: OperationalBaselineKind
    public var subsystemComponentIDs: [String]
    public var requiredStateAssignments: [CaptureStateAssignment]
    public var minimumDurationSeconds: Double
    public var minimumAcceptedTakeCount: Int
    public var preservationRole: BaselinePreservationRole
    public var automaticDenoisingPermitted: Bool
    public var requiredStatistics: [String]
    public var notes: String
    public init(contractVersion: String = "orgrec.operational-baseline/v1", kind: OperationalBaselineKind, subsystemComponentIDs: [String], requiredStateAssignments: [CaptureStateAssignment], minimumDurationSeconds: Double = 180, minimumAcceptedTakeCount: Int = 1, preservationRole: BaselinePreservationRole = .virtualizationLayer, automaticDenoisingPermitted: Bool = false, requiredStatistics: [String] = ["peak", "rms", "L10", "L50", "L90", "crest-factor", "short-term-variability", "octave-band-spectrum"], notes: String = "") {
        self.contractVersion = contractVersion; self.kind = kind; self.subsystemComponentIDs = subsystemComponentIDs
        self.requiredStateAssignments = requiredStateAssignments; self.minimumDurationSeconds = max(120, minimumDurationSeconds)
        self.minimumAcceptedTakeCount = max(1, minimumAcceptedTakeCount); self.preservationRole = preservationRole
        self.automaticDenoisingPermitted = automaticDenoisingPermitted; self.requiredStatistics = requiredStatistics; self.notes = notes
    }
    public var validationIssues: [String] {
        var issues: [String] = []
        if minimumDurationSeconds < 120 { issues.append("An operational baseline must be at least two minutes long.") }
        if automaticDenoisingPermitted { issues.append("Operational masters must remain available without automatic denoising.") }
        if requiredStatistics.isEmpty { issues.append("An operational baseline requires spectral/noise statistics.") }
        return issues
    }
}

public struct OperationalBandLevel: Codable, Hashable, Identifiable, Sendable {
    public var id: String { "\(centerFrequencyHz)" }
    public var centerFrequencyHz: Double
    public var lowerFrequencyHz: Double
    public var upperFrequencyHz: Double
    public var levelDBFS: Double
}

public struct OperationalBaselineAnalysis: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var analyzedDurationSeconds: Double
    public var windowDurationSeconds: Double
    public var peakDBFS: Double
    public var rmsDBFS: Double
    public var l10DBFS: Double
    public var l50DBFS: Double
    public var l90DBFS: Double
    public var crestFactorDB: Double
    public var shortTermLevelStandardDeviationDB: Double
    public var stationary: Bool
    public var octaveBandLevels: [OperationalBandLevel]
    public var referenceChannel: Int
    public var calibrationReference: String?
    public var measurementUnit: String
    public var method: String
    public var analyzedAt: Date
    public var warnings: [String]
}

// MARK: - Unified P1 capture contract and take paradata

public enum ComplexCaptureKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case physicalActuatorResponse, declarativeProcess, discreteShutterMapping, tremulantResponse, operationalBaseline
    public var id: String { rawValue }
    public var displayName: String { rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
}

public struct ComplexCaptureProtocol: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var kind: ComplexCaptureKind
    public var name: String
    public var sourceComponentID: String
    public var minimumAcceptedTakeCount: Int
    public var physicalActuation: PhysicalActuationVariant?
    public var processModel: CaptureProcessModel?
    public var shutterTopology: DiscreteShutterTopology?
    public var targetShutterStateID: String?
    public var pedalTravelDirection: PedalTravelDirection?
    public var tremulant: TremulantCaptureProtocol?
    public var operationalBaseline: OperationalBaselineProtocol?
    public var instructions: String

    public init(contractVersion: String = "orgrec.complex-capture/v1", id: UUID = UUID(), kind: ComplexCaptureKind, name: String, sourceComponentID: String, minimumAcceptedTakeCount: Int = 1, physicalActuation: PhysicalActuationVariant? = nil, processModel: CaptureProcessModel? = nil, shutterTopology: DiscreteShutterTopology? = nil, targetShutterStateID: String? = nil, pedalTravelDirection: PedalTravelDirection? = nil, tremulant: TremulantCaptureProtocol? = nil, operationalBaseline: OperationalBaselineProtocol? = nil, instructions: String = "") {
        self.contractVersion = contractVersion; self.id = id; self.kind = kind; self.name = name; self.sourceComponentID = sourceComponentID
        self.minimumAcceptedTakeCount = max(1, minimumAcceptedTakeCount); self.physicalActuation = physicalActuation; self.processModel = processModel
        self.shutterTopology = shutterTopology; self.targetShutterStateID = targetShutterStateID; self.pedalTravelDirection = pedalTravelDirection
        self.tremulant = tremulant; self.operationalBaseline = operationalBaseline; self.instructions = instructions
    }
    public var validationIssues: [String] {
        var issues: [String] = []
        switch kind {
        case .physicalActuatorResponse:
            if physicalActuation == nil { issues.append("Physical actuator response requires an actuation variant.") }
        case .declarativeProcess:
            if processModel == nil { issues.append("Declarative process capture requires a process model.") }
        case .discreteShutterMapping:
            if shutterTopology == nil || targetShutterStateID == nil { issues.append("Discrete shutter capture requires a topology and target state.") }
        case .tremulantResponse:
            if tremulant == nil { issues.append("Tremulant response capture requires a typed condition.") }
        case .operationalBaseline:
            if operationalBaseline == nil { issues.append("Operational baseline capture requires a baseline protocol.") }
        }
        issues.append(contentsOf: physicalActuation?.validationIssues ?? [])
        issues.append(contentsOf: processModel?.validationIssues ?? [])
        issues.append(contentsOf: shutterTopology?.validationIssues ?? [])
        issues.append(contentsOf: operationalBaseline?.validationIssues ?? [])
        return Array(Set(issues)).sorted()
    }
}

/// Transient request authored by the P1 planner. It is Codable so a future
/// wizard can save drafts, but only compiled Roadmap protocols are normative.
public struct ComplexCapturePlanRequest: Codable, Hashable, Sendable {
    public var kind: ComplexCaptureKind
    public var sourceComponentID: String?
    public var customComponentLabel: String
    public var soundingTargetDefinition: SoundingTargetDefinition?
    public var physicalActuationVariants: [PhysicalActuationVariant]
    public var processModel: CaptureProcessModel?
    public var shutterTopology: DiscreteShutterTopology?
    public var tremulantAffectedComponentIDs: [String]
    public var tremulantCoverageScope: TremulantCoverageScope
    public var operationalBaseline: OperationalBaselineProtocol?
    public var minimumAcceptedTakeCount: Int
    public var techniques: [CaptureTechnique]
    public var required: Bool
    public init(kind: ComplexCaptureKind, sourceComponentID: String? = nil, customComponentLabel: String = "", soundingTargetDefinition: SoundingTargetDefinition? = nil, physicalActuationVariants: [PhysicalActuationVariant] = [], processModel: CaptureProcessModel? = nil, shutterTopology: DiscreteShutterTopology? = nil, tremulantAffectedComponentIDs: [String] = [], tremulantCoverageScope: TremulantCoverageScope = .representative, operationalBaseline: OperationalBaselineProtocol? = nil, minimumAcceptedTakeCount: Int = 2, techniques: [CaptureTechnique], required: Bool = true) {
        self.kind = kind; self.sourceComponentID = sourceComponentID; self.customComponentLabel = customComponentLabel
        self.soundingTargetDefinition = soundingTargetDefinition; self.physicalActuationVariants = physicalActuationVariants
        self.processModel = processModel; self.shutterTopology = shutterTopology; self.tremulantAffectedComponentIDs = tremulantAffectedComponentIDs
        self.tremulantCoverageScope = tremulantCoverageScope; self.operationalBaseline = operationalBaseline
        self.minimumAcceptedTakeCount = max(1, minimumAcceptedTakeCount); self.techniques = techniques; self.required = required
    }
}

public enum ComplexCaptureEventKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case actionBegin, actionEnd, processStageBegin, processStageEnd, processCancelled
    case shutterStateObserved, tremulantActivated, tremulantSteady, tremulantDeactivated
    case baselineStable, notableVariation
    public var id: String { rawValue }
}

public struct ComplexCaptureEvent: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var atSeconds: Double
    public var kind: ComplexCaptureEventKind
    public var stageID: String?
    public var shutterStateID: String?
    public var observedValue: Double?
    public var unit: String?
    public var notes: String
    public init(id: UUID = UUID(), atSeconds: Double, kind: ComplexCaptureEventKind, stageID: String? = nil, shutterStateID: String? = nil, observedValue: Double? = nil, unit: String? = nil, notes: String = "") {
        self.id = id; self.atSeconds = atSeconds; self.kind = kind; self.stageID = stageID; self.shutterStateID = shutterStateID
        self.observedValue = observedValue; self.unit = unit; self.notes = notes
    }
}

public struct ComplexCaptureEventAnnotation: Codable, Hashable, Sendable {
    public var protocolID: UUID
    public var protocolKind: ComplexCaptureKind
    public var event: ComplexCaptureEvent

    public init(protocolID: UUID, protocolKind: ComplexCaptureKind, event: ComplexCaptureEvent) {
        self.protocolID = protocolID
        self.protocolKind = protocolKind
        self.event = event
    }
}

public struct ComplexCaptureTakeParadata: Codable, Hashable, Sendable {
    public var protocolSnapshot: ComplexCaptureProtocol
    public var repetitionNumber: Int
    public var events: [ComplexCaptureEvent]
    public var actuatorResponseObservation: ActuatorResponseObservation?
    public var tremulantAnalysis: TremulantResponseAnalysis?
    public var operationalBaselineAnalysis: OperationalBaselineAnalysis?
    public var observedActuationCurve: ActuationCurve?
    public var notes: String
    public init(protocolSnapshot: ComplexCaptureProtocol, repetitionNumber: Int, events: [ComplexCaptureEvent] = [], actuatorResponseObservation: ActuatorResponseObservation? = nil, tremulantAnalysis: TremulantResponseAnalysis? = nil, operationalBaselineAnalysis: OperationalBaselineAnalysis? = nil, observedActuationCurve: ActuationCurve? = nil, notes: String = "") {
        self.protocolSnapshot = protocolSnapshot; self.repetitionNumber = max(1, repetitionNumber); self.events = events
        self.actuatorResponseObservation = actuatorResponseObservation; self.tremulantAnalysis = tremulantAnalysis
        self.operationalBaselineAnalysis = operationalBaselineAnalysis; self.observedActuationCurve = observedActuationCurve; self.notes = notes
    }
}

// MARK: - P1 Roadmap compiler

public extension RoadmapEngine {
    static func complexSoundingTargetItems(
        component: OrganComponent,
        definition: SoundingTargetDefinition,
        protocols: [ComplexCaptureProtocol],
        recipe: CaptureRecipe,
        setupIDs: [UUID],
        registrationID: UUID,
        required: Bool = true
    ) -> [RoadmapItem] {
        let base = soundingTargetItems(component: component, definition: definition, recipe: recipe, setupIDs: setupIDs, registrationID: registrationID)
        return protocols.flatMap { protocolSnapshot in
            base.map { source in
                var item = source
                let stable = "\(source.component.id)|\(source.technique.rawValue)|\(protocolSnapshot.id.uuidString.lowercased())"
                item.id = stableUUID(stable)
                item.component.id = "complex-target:\(Data(stable.utf8).sha256Hex)"
                item.component.parentComponentID = source.component.parentComponentID ?? component.id
                let variant = protocolSnapshot.physicalActuation?.label ?? protocolSnapshot.processModel?.name ?? protocolSnapshot.name
                item.component.noteName = [source.component.noteName, variant].compactMap { $0 }.joined(separator: " · ")
                item.complexCaptureProtocol = protocolSnapshot
                item.coverageKind = protocolSnapshot.kind == .physicalActuatorResponse ? .physicalIntensityResponse : .processBehavior
                item.required = required
                item.instructions = protocolSnapshot.instructions
                return item
            }
        }
    }

    static func shutterMappingItems(
        component: OrganComponent,
        topology: DiscreteShutterTopology,
        minimumAcceptedTakeCount: Int,
        recipe: CaptureRecipe,
        techniques: [CaptureTechnique],
        setupIDs: [UUID],
        required: Bool = true
    ) -> [RoadmapItem] {
        let points = Dictionary(grouping: topology.pedalMapping, by: { "\($0.direction.rawValue)|\($0.shutterStateID)" }).values.compactMap(\.first)
        return points.flatMap { point in
            guard let state = topology.states.first(where: { $0.id == point.shutterStateID }) else { return [RoadmapItem]() }
            let protocolSnapshot = ComplexCaptureProtocol(
                kind: .discreteShutterMapping,
                name: "\(topology.name) · \(state.label)",
                sourceComponentID: component.id,
                minimumAcceptedTakeCount: minimumAcceptedTakeCount,
                shutterTopology: topology,
                targetShutterStateID: state.id,
                pedalTravelDirection: point.direction,
                instructions: "Begin at the preceding documented pedal detent, move \(point.direction.displayName.lowercased()) to pedal position \(point.pedalPosition.formatted(.percent.precision(.fractionLength(0)))), mark the observed discrete state \(state.label), and retain pedal/linkage/shutter sound through the tail."
            )
            return techniques.map { technique in
                var target = component
                let key = "\(component.id)|\(state.id)|\(point.direction.rawValue)|\(technique.rawValue)"
                target.id = "shutter-map:\(Data(key.utf8).sha256Hex)"
                target.kind = "discrete_shutter_mapping"
                target.label = topology.name
                target.division = "Instrument mechanics · Shutters"
                target.noteName = "\(state.label) · \(point.direction.displayName) · pedal \(point.pedalPosition.formatted(.percent.precision(.fractionLength(0))))"
                target.parentComponentID = component.id
                return RoadmapItem(
                    id: stableUUID(key), component: target, technique: technique, recipeID: recipe.id,
                    setupID: setupForP1(technique, setupIDs: setupIDs), required: required,
                    coverageKind: .shutterMapping, instructions: protocolSnapshot.instructions,
                    complexCaptureProtocol: protocolSnapshot
                )
            }
        }
    }

    static func operationalBaselineItems(
        component: OrganComponent,
        baseline: OperationalBaselineProtocol,
        recipe: CaptureRecipe,
        techniques: [CaptureTechnique],
        setupIDs: [UUID],
        required: Bool = true
    ) -> [RoadmapItem] {
        let protocolSnapshot = ComplexCaptureProtocol(
            kind: .operationalBaseline, name: "\(component.label) · \(baseline.kind.displayName)",
            sourceComponentID: component.id, minimumAcceptedTakeCount: baseline.minimumAcceptedTakeCount,
            operationalBaseline: baseline,
            instructions: "Hold the documented subsystem state unchanged for at least \(Int(baseline.minimumDurationSeconds)) seconds. Mark stable operation and every variation. Preserve the master as a separable virtualization layer; do not automatically denoise it."
        )
        return techniques.map { technique in
            var target = component
            let key = "\(component.id)|\(baseline.kind.rawValue)|\(technique.rawValue)|\(baseline.minimumDurationSeconds)"
            target.id = "operational-baseline:\(Data(key.utf8).sha256Hex)"; target.kind = "operational_baseline"
            target.label = component.label; target.division = "Operational baselines"; target.noteName = "\(baseline.kind.displayName) · \(Int(baseline.minimumDurationSeconds)) s"
            target.midiNote = nil; target.expectedFrequencyHz = nil; target.parentComponentID = component.id
            return RoadmapItem(id: stableUUID(key), component: target, technique: technique, recipeID: recipe.id, setupID: setupForP1(technique, setupIDs: setupIDs), required: required, coverageKind: .operationalBaseline, instructions: protocolSnapshot.instructions, complexCaptureProtocol: protocolSnapshot)
        }
    }

    static func tremulantResponsePlan(
        tremulant: OrganComponent,
        affectedStops: [OrganComponent],
        scope: TremulantCoverageScope,
        minimumAcceptedTakeCount: Int,
        recipe: CaptureRecipe,
        techniques: [CaptureTechnique],
        setupIDs: [UUID],
        required: Bool = true
    ) -> (registrations: [RegistrationState], items: [RoadmapItem]) {
        var registrations: [RegistrationState] = [], items: [RoadmapItem] = []
        for stop in affectedStops {
            let notes: [Int]
            if scope == .complete {
                let low = max(0, stop.playableMIDILow ?? (stop.division.localizedCaseInsensitiveContains("pedal") ? 36 : 36))
                let high = min(127, stop.playableMIDIHigh ?? (stop.division.localizedCaseInsensitiveContains("pedal") ? 67 : 96))
                notes = Array(stride(from: low, through: high, by: max(1, recipe.chromaticStep)))
            } else {
                let low = max(0, stop.playableMIDILow ?? 36), high = min(127, stop.playableMIDIHigh ?? (stop.division.localizedCaseInsensitiveContains("pedal") ? 67 : 96))
                notes = Array(Set([low, low + (high - low) / 2, high])).sorted()
            }
            for condition in TremulantCaptureCondition.allCases {
                let initiallyOn = [.steadyWithTremulant, .deactivationTransition].contains(condition)
                let registration = RegistrationState(
                    activatedStops: [stop.locator], activatedAccessories: initiallyOn ? [tremulant.locator] : [],
                    notes: "Paired tremulant protocol; initial state is explicit and transitions occur while the note is sounding.",
                    name: "\(stop.label) · \(tremulant.label) · \(condition.displayName)", purpose: "Tremulant response"
                )
                registrations.append(registration)
                for midi in notes {
                    let tremProtocol = TremulantCaptureProtocol(tremulantComponentID: tremulant.id, affectedComponentID: stop.id, condition: condition, coverageScope: scope)
                    let complex = ComplexCaptureProtocol(
                        kind: .tremulantResponse, name: "\(tremulant.label) · \(stop.label)", sourceComponentID: tremulant.id,
                        minimumAcceptedTakeCount: minimumAcceptedTakeCount, tremulant: tremProtocol,
                        instructions: tremulantInstruction(condition: condition, stop: stop.label, tremulant: tremulant.label)
                    )
                    for technique in techniques {
                        var target = stop
                        let key = "\(tremulant.id)|\(stop.id)|\(midi)|\(condition.rawValue)|\(technique.rawValue)"
                        target.id = "tremulant-response:\(Data(key.utf8).sha256Hex)"; target.kind = "tremulant_response"
                        target.label = "\(stop.label) · \(tremulant.label)"; target.division = "Tremulant responses · \(stop.division)"
                        target.midiNote = midi; target.noteName = "\(noteNameForP1(midi)) · \(condition.displayName)"; target.parentComponentID = stop.id
                        target.expectedFrequencyHz = OrganFootage.nominalFrequency(
                            keyMidi: midi,
                            footHeight: stop.footHeight,
                            referencePitchHz: stop.referencePitchHz
                        )
                        items.append(RoadmapItem(
                            id: stableUUID(key), component: target, technique: technique, recipeID: recipe.id,
                            setupID: setupForP1(technique, setupIDs: setupIDs), registrationID: registration.id,
                            required: required, coverageKind: .tremulantResponse, instructions: complex.instructions,
                            complexCaptureProtocol: complex
                        ))
                    }
                }
            }
        }
        return (registrations, items)
    }

    private static func tremulantInstruction(condition: TremulantCaptureCondition, stop: String, tremulant: String) -> String {
        switch condition {
        case .withoutTremulant: "Play and hold \(stop) with \(tremulant) explicitly off; retain a clean paired baseline."
        case .steadyWithTremulant: "Start with \(tremulant) on; hold \(stop) long enough to measure stable amplitude/frequency modulation and release."
        case .activationTransition: "Start with \(tremulant) off, hold \(stop), mark and activate the tremulant, then continue through stable modulation and release."
        case .deactivationTransition: "Start with \(tremulant) on, hold \(stop), mark and deactivate the tremulant, then continue through settling and release."
        }
    }
    private static func setupForP1(_ technique: CaptureTechnique, setupIDs: [UUID]) -> UUID? {
        switch technique {
        case .closePair: setupIDs.first
        case .naveORTF: setupIDs.dropFirst().first ?? setupIDs.first
        case .rearOmni: setupIDs.dropFirst(2).first ?? setupIDs.last
        case .releaseTail: setupIDs.dropFirst().first ?? setupIDs.first
        }
    }
    private static func noteNameForP1(_ midi: Int) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        return "\(names[(midi % 12 + 12) % 12])\(midi / 12 - 1)"
    }
    private static func stableUUID(_ value: String) -> UUID {
        let hex = String(Data(value.utf8).sha256Hex.prefix(32))
        let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
        return UUID(uuidString: formatted) ?? UUID()
    }
}

// MARK: - Analysis engines

public enum ComplexCaptureAnalysisEngine {
    public static func actuatorObservation(take: TakeRecord, protocolSnapshot: ComplexCaptureProtocol, analysis: AnalysisSummary) -> ActuatorResponseObservation? {
        guard let variant = protocolSnapshot.physicalActuation else { return nil }
        let activationMapping = take.controlEventLog?.events.compactMap { event -> AudioControlEventFrameMapping? in
            guard [.activation, .trigger].contains(event.role),
                  event.componentID == protocolSnapshot.sourceComponentID else { return nil }
            return take.audioControlAlignment?.mappings.first { $0.eventID == event.id }
        }.sorted { $0.audioTimeSeconds < $1.audioTimeSeconds }.first
        let marker = take.complexCaptureParadata?.events.first { $0.kind == .actionBegin }?.atSeconds
        let commandTime = activationMapping?.audioTimeSeconds ?? marker
        let latency = commandTime.flatMap { command in analysis.onsetSeconds.map { $0 - command } }
        let duration = analysis.onsetSeconds.flatMap { onset in analysis.soundOffsetSeconds.map { max(0, $0 - onset) } }
        return ActuatorResponseObservation(
            takeID: take.id, variantID: variant.id, inputs: variant.inputs,
            peakLevelDBFS: analysis.peakDBFS, rmsLevelDBFS: analysis.rmsDBFS,
            acousticOnsetLatencySeconds: latency, acousticDurationSeconds: duration,
            processOutcome: protocolSnapshot.processModel.map { "completed:\($0.name)" },
            timingUncertaintySeconds: activationMapping?.uncertaintySeconds,
            takeStatus: take.status
        )
    }

    public static func tremulantAnalysis(take: TakeRecord, protocolSnapshot: ComplexCaptureProtocol, analysis: AnalysisSummary) -> TremulantResponseAnalysis? {
        guard let tremulant = protocolSnapshot.tremulant else { return nil }
        let desiredRole: ControlEventRole = tremulant.condition == .deactivationTransition ? .deactivation : .activation
        let mapping = take.controlEventLog?.events.compactMap { event -> AudioControlEventFrameMapping? in
            guard event.role == desiredRole,
                  event.componentID == tremulant.tremulantComponentID else { return nil }
            return take.audioControlAlignment?.mappings.first { $0.eventID == event.id }
        }.sorted { $0.audioTimeSeconds < $1.audioTimeSeconds }.first
        let markerKind: ComplexCaptureEventKind = tremulant.condition == .deactivationTransition ? .tremulantDeactivated : .tremulantActivated
        let commandTime = mapping?.audioTimeSeconds ?? take.complexCaptureParadata?.events.first(where: { $0.kind == markerKind })?.atSeconds
        let behavior = analysis.pipeSoundBehavior
        let track = (take.pitchTrack ?? []).filter { $0.voiced && $0.centsFromExpected != nil }
        let window = 1.0
        let step = 0.2
        var windows: [(time: Double, depth: Double)] = []
        if let last = track.last?.timeSeconds {
            var start = track.first?.timeSeconds ?? 0
            while start + window <= last {
                let values = track.filter { $0.timeSeconds >= start && $0.timeSeconds < start + window }.compactMap(\.centsFromExpected)
                if values.count >= 5 { windows.append((start + window / 2, percentile(values, 0.95) - percentile(values, 0.05))) }
                start += step
            }
        }
        let steadyCandidates: [Double]
        if tremulant.condition == .deactivationTransition, let commandTime {
            steadyCandidates = windows.filter { $0.time < commandTime }.map(\.depth)
        } else if let commandTime {
            steadyCandidates = windows.filter { $0.time > commandTime }.map(\.depth)
        } else {
            steadyCandidates = windows.map(\.depth)
        }
        let steadyDepth = steadyCandidates.sorted().dropFirst(max(0, steadyCandidates.count / 2)).first
            ?? behavior?.frequencyModulationDepthCents
        var detected: Double?, settled: Double?
        if let commandTime, let steadyDepth, steadyDepth > 0 {
            if tremulant.condition == .deactivationTransition {
                detected = windows.first { $0.time >= commandTime && $0.depth <= steadyDepth * 0.7 }?.time
                settled = windows.first { candidate in candidate.time >= commandTime && candidate.depth <= max(2, steadyDepth * 0.2) }?.time
            } else {
                detected = windows.first { $0.time >= commandTime && $0.depth >= max(2, steadyDepth * 0.3) }?.time
                settled = windows.first { candidate in candidate.time >= commandTime && abs(candidate.depth - steadyDepth) <= max(2, steadyDepth * 0.2) }?.time
            }
        }
        var warnings: [String] = []
        if commandTime == nil && [.activationTransition, .deactivationTransition].contains(tremulant.condition) { warnings.append("No aligned tremulant command or operator marker was available.") }
        if track.isEmpty && tremulant.analyzeFrequencyModulation { warnings.append("No voiced pitch track was available for transition analysis.") }
        return TremulantResponseAnalysis(
            contractVersion: "orgrec.tremulant-response-analysis/v1",
            amplitudeModulationRateHz: behavior?.amplitudeModulationRateHz,
            amplitudeModulationDepthDB: behavior?.amplitudeModulationDepthDB,
            frequencyModulationRateHz: behavior?.frequencyModulationRateHz,
            frequencyModulationDepthCents: behavior?.frequencyModulationDepthCents,
            commandTimeSeconds: commandTime, modulationDetectedTimeSeconds: detected,
            transitionTimeSeconds: commandTime.flatMap { command in detected.map { max(0, $0 - command) } },
            settlingTimeSeconds: commandTime.flatMap { command in settled.map { max(0, $0 - command) } },
            timingUncertaintySeconds: mapping?.uncertaintySeconds,
            method: "OrgRec modulation summary plus one-second rolling pitch-depth envelopes",
            warnings: warnings
        )
    }

    public static func responseFunctions(project: OrgRecProject) -> [ActuatorResponseFunction] {
        let records: [(String, String, ActuatorResponseObservation)] = project.takes.compactMap { take in
            guard let paradata = take.complexCaptureParadata,
                  let observation = paradata.actuatorResponseObservation else { return nil }
            return (paradata.protocolSnapshot.sourceComponentID, paradata.protocolSnapshot.name, observation)
        }
        return Dictionary(grouping: records, by: { $0.0 }).map { componentID, entries in
            let statuses = entries.map { $0.2.takeStatus }
            let status: ActuatorResponseFunctionStatus = statuses.allSatisfy { $0 == .accepted } ? .reviewed : .measured
            return ActuatorResponseFunction(componentID: componentID, componentLabel: entries.first?.1 ?? componentID, observations: entries.map { $0.2 }, status: status)
        }.sorted { $0.componentLabel.localizedStandardCompare($1.componentLabel) == .orderedAscending }
    }

    private static func percentile(_ values: [Double], _ probability: Double) -> Double {
        let sorted = values.sorted(); guard !sorted.isEmpty else { return 0 }
        let position = min(max(probability, 0), 1) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down)), upper = Int(position.rounded(.up))
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }
}

public enum OperationalBaselineAnalyzer {
    public static func analyze(fileURL: URL, referenceChannel: Int, maximumDurationSeconds: Double = 1_800) throws -> OperationalBaselineAnalysis {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        guard file.length > 0, format.channelCount > 0 else { throw OrgRecError.unsupportedAudio("The baseline contains no readable audio.") }
        let selected = max(0, min(Int(format.channelCount) - 1, referenceChannel))
        let windowSeconds = 0.1
        let windowFrames = max(256, Int(format.sampleRate * windowSeconds))
        let readFrames = AVAudioFrameCount(max(windowFrames, 65_536))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: readFrames) else { throw OrgRecError.unsupportedAudio("Cannot allocate baseline analysis buffer.") }
        let limit = min(file.length, Int64(max(120, min(1_800, maximumDurationSeconds)) * format.sampleRate))
        var remaining = limit, samplesInWindow: [Float] = [], levels: [Double] = []
        var sumSquares = 0.0, sampleCount = 0, peak = 0.0
        let fftSize = 4_096
        var bandPowers = [Double](repeating: 0, count: octaveBands.count), spectralFrames = 0
        var spectralCarry: [Float] = []
        while remaining > 0 {
            let requested = AVAudioFrameCount(min(Int64(readFrames), remaining))
            try file.read(into: buffer, frameCount: requested)
            guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { break }
            let chunk = Array(UnsafeBufferPointer(start: channels[selected], count: Int(buffer.frameLength)))
            for sample in chunk { let value = Double(sample); sumSquares += value * value; peak = max(peak, abs(value)) }
            sampleCount += chunk.count; samplesInWindow.append(contentsOf: chunk); spectralCarry.append(contentsOf: chunk)
            while samplesInWindow.count >= windowFrames {
                let slice = samplesInWindow.prefix(windowFrames); let power = slice.reduce(0.0) { $0 + Double($1 * $1) } / Double(windowFrames)
                levels.append(db(sqrt(power))); samplesInWindow.removeFirst(windowFrames)
            }
            while spectralCarry.count >= fftSize {
                let powers = octavePowers(Array(spectralCarry.prefix(fftSize)), sampleRate: format.sampleRate)
                for index in powers.indices { bandPowers[index] += powers[index] }
                spectralFrames += 1; spectralCarry.removeFirst(fftSize)
                if spectralFrames % 8 != 0 { spectralCarry.removeFirst(min(fftSize, spectralCarry.count)) }
            }
            remaining -= Int64(chunk.count)
        }
        guard sampleCount > 0 else { throw OrgRecError.unsupportedAudio("The baseline contains no readable samples.") }
        let rms = sqrt(sumSquares / Double(sampleCount)), sorted = levels.sorted()
        let mean = levels.reduce(0, +) / Double(max(1, levels.count))
        let std = sqrt(levels.reduce(0) { $0 + pow($1 - mean, 2) } / Double(max(1, levels.count)))
        let bands = octaveBands.enumerated().map { index, band in
            OperationalBandLevel(centerFrequencyHz: band.center, lowerFrequencyHz: band.lower, upperFrequencyHz: band.upper, levelDBFS: db(sqrt(bandPowers[index] / Double(max(1, spectralFrames)))))
        }
        let duration = Double(sampleCount) / format.sampleRate
        var warnings: [String] = []
        if duration < 120 { warnings.append("The recording is shorter than the two-minute operational-baseline minimum.") }
        if peak >= 0.999 { warnings.append("Clipping occurred in the baseline.") }
        return OperationalBaselineAnalysis(
            contractVersion: "orgrec.operational-baseline-analysis/v1", analyzedDurationSeconds: duration,
            windowDurationSeconds: windowSeconds, peakDBFS: db(peak), rmsDBFS: db(rms),
            l10DBFS: quantile(sorted, 0.90), l50DBFS: quantile(sorted, 0.50), l90DBFS: quantile(sorted, 0.10),
            crestFactorDB: db(peak) - db(rms), shortTermLevelStandardDeviationDB: std, stationary: std <= 3,
            octaveBandLevels: bands, referenceChannel: selected, calibrationReference: nil, measurementUnit: "uncalibrated dBFS",
            method: "100 ms level distribution and Hann-windowed 4096-point octave-band power accumulation",
            analyzedAt: .now, warnings: warnings
        )
    }

    private static let octaveBands: [(center: Double, lower: Double, upper: Double)] = [31.5, 63, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000].map {
        ($0, $0 / sqrt(2), $0 * sqrt(2))
    }
    private static func octavePowers(_ source: [Float], sampleRate: Double) -> [Double] {
        let count = source.count, log2n = vDSP_Length(log2(Double(count)))
        guard count.isMultiple(of: 2), let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return [Double](repeating: 0, count: octaveBands.count) }
        defer { vDSP_destroy_fftsetup(setup) }
        var window = [Float](repeating: 0, count: count), samples = source
        vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_NORM)); vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(count))
        var real = [Float](repeating: 0, count: count / 2), imag = real
        samples.withUnsafeBytes { raw in raw.bindMemory(to: DSPComplex.self).withMemoryRebound(to: DSPComplex.self) { complex in
            real.withUnsafeMutableBufferPointer { rp in imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!); vDSP_ctoz(complex.baseAddress!, 2, &split, 1, vDSP_Length(count / 2)); vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }}
        }}
        let binWidth = sampleRate / Double(count)
        return octaveBands.map { band in
            let lower = max(1, Int(floor(band.lower / binWidth))), upper = min(count / 2 - 1, Int(ceil(band.upper / binWidth)))
            guard lower <= upper else { return 0 }
            var sum = 0.0
            for index in lower...upper {
                let realValue = Double(real[index])
                let imaginaryValue = Double(imag[index])
                sum += realValue * realValue + imaginaryValue * imaginaryValue
            }
            let normalization = Double(count) * Double(count)
            return sum / normalization
        }
    }
    private static func quantile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return -.infinity }
        let x = min(max(p, 0), 1) * Double(sorted.count - 1), l = Int(x.rounded(.down)), u = Int(x.rounded(.up))
        return sorted[l] + (sorted[u] - sorted[l]) * (x - Double(l))
    }
    private static func db(_ amplitude: Double) -> Double { 20 * log10(max(amplitude, 1e-12)) }
}
