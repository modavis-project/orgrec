import Foundation

public enum VAO04RuntimeError: Error, LocalizedError, Equatable {
    case missingRandomSource(String)
    case unsupportedRandomAlgorithm(String)
    case invalidDistribution(String)
    case conflictingWrite(String)
    case maximumMicrosteps

    public var errorDescription: String? {
        switch self {
        case .missingRandomSource(let id): "Missing reproducible random source \(id)."
        case .unsupportedRandomAlgorithm(let value): "Unsupported random algorithm \(value)."
        case .invalidDistribution(let id): "Invalid probability distribution for \(id)."
        case .conflictingWrite(let id): "Rejected conflicting write to \(id)."
        case .maximumMicrosteps: "The deterministic runtime exceeded maximumMicrosteps."
        }
    }
}

public struct VAO04RuntimeResult: Codable, Sendable, Equatable {
    public var state: [String: VAOJSONValue]
    public var emittedEvents: [VAOJSONValue]
    public var renderBindingIds: [String]
}

private struct VAO04PCG32: Sendable {
    var state: UInt64
    let increment: UInt64

    init(seedHex: String, stream: Int) {
        state = 0
        increment = (UInt64(stream) << 1) | 1
        _ = next()
        state &+= UInt64(seedHex.suffix(16), radix: 16) ?? 0
        _ = next()
    }

    mutating func next() -> UInt32 {
        let old = state
        state = old &* 6_364_136_223_846_793_005 &+ increment
        let shifted = UInt32(truncatingIfNeeded: ((old >> 18) ^ old) >> 27)
        let rotation = UInt32(old >> 59)
        return (shifted >> rotation) | (shifted << ((0 &- rotation) & 31))
    }

    mutating func uniform() -> Double { Double(next()) / 4_294_967_296.0 }
}

public enum VAO04RuntimeEngine {
    private struct OrderedAction {
        var group: String; var index: Int; var action: VAO03DeclarativeAction; var transition: VAO03InteractionTransition
    }

    private static func condition(_ condition: VAO03StateCondition, state: [String: VAOJSONValue]) -> Bool {
        let actual = state[condition.stateVariableId]
        return switch condition.comparisonOperator {
        case "equals": actual == condition.value
        case "not-equals": actual != condition.value
        case "less-than": (actual?.numberValue ?? .infinity) < (condition.value.numberValue ?? -.infinity)
        case "less-or-equal": (actual?.numberValue ?? .infinity) <= (condition.value.numberValue ?? -.infinity)
        case "greater-than": (actual?.numberValue ?? -.infinity) > (condition.value.numberValue ?? .infinity)
        case "greater-or-equal": (actual?.numberValue ?? -.infinity) >= (condition.value.numberValue ?? .infinity)
        default: false
        }
    }

    public static func execute(manifest: VAO04Manifest, events: [VAO04TraceEvent], initialState: [String: VAOJSONValue] = [:]) throws -> VAO04RuntimeResult {
        guard let model = manifest.interactionModel else {
            return VAO04RuntimeResult(state: initialState, emittedEvents: [], renderBindingIds: [])
        }
        var state = Dictionary(uniqueKeysWithValues: model.stateVariables.map { ($0.id, $0.defaultValue) })
        state.merge(initialState) { _, supplied in supplied }
        let transitions = model.transitions.sorted { lhs, rhs in
            let lp = lhs.priority ?? 0, rp = rhs.priority ?? 0
            return lp == rp ? lhs.id < rhs.id : lp > rp
        }
        let processes = Dictionary(uniqueKeysWithValues: model.processModels.map { ($0.id, $0) })
        var random: [String: VAO04PCG32] = [:]
        for record in manifest.runtime.randomSources + (model.randomSources ?? []) {
            guard record.algorithm == "pcg32" else { throw VAO04RuntimeError.unsupportedRandomAlgorithm(record.algorithm) }
            random[record.id] = VAO04PCG32(seedHex: record.seed, stream: record.stream)
        }
        let orderedEvents = events.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
            if (lhs.priority ?? 0) != (rhs.priority ?? 0) { return (lhs.priority ?? 0) > (rhs.priority ?? 0) }
            if lhs.eventTypeId != rhs.eventTypeId { return lhs.eventTypeId < rhs.eventTypeId }
            return lhs.sequence < rhs.sequence
        }
        var emitted: [VAOJSONValue] = []
        var selected: [String] = []
        var microsteps = 0
        let maximum = model.executionSemantics.maximumMicrosteps ?? 10_000

        func processActions(_ process: VAO04ProcessModel) throws -> [VAO03DeclarativeAction] {
            var actions = process.actions
            for child in process.childProcessIds ?? [] {
                if let record = processes[child] { actions += try processActions(record) }
            }
            guard process.processKind == "stochastic" else { return actions }
            guard let randomID = process.randomSourceId, var generator = random[randomID] else { throw VAO04RuntimeError.missingRandomSource(process.randomSourceId ?? "") }
            defer { random[randomID] = generator }
            guard !actions.isEmpty, let distribution = process.probabilityDistribution else { throw VAO04RuntimeError.invalidDistribution(process.id) }
            if distribution.kind == "categorical" {
                let weights = actions.indices.map { distribution.parameters[String($0)] ?? 0 }
                let total = weights.reduce(0, +)
                guard total > 0 else { throw VAO04RuntimeError.invalidDistribution(process.id) }
                let threshold = generator.uniform() * total
                var running = 0.0
                for (action, weight) in zip(actions, weights) { running += weight; if threshold < running { return [action] } }
                return [actions.last!]
            }
            return [actions[min(Int(generator.uniform() * Double(actions.count)), actions.count - 1)]]
        }

        for event in orderedEvents {
            let snapshot = state
            let matching = transitions.filter { transition in
                transition.eventTypeId == event.eventTypeId
                    && (transition.controlId == nil || transition.controlId == event.controlId)
                    && (transition.conditions ?? []).allSatisfy { condition($0, state: snapshot) }
            }
            var actions: [OrderedAction] = []
            for transition in matching {
                for (index, action) in transition.actions.enumerated() {
                    actions.append(OrderedAction(group: action.executionGroup ?? "", index: index, action: action, transition: transition))
                }
            }
            actions.sort { lhs, rhs in
                if lhs.group != rhs.group { return lhs.group < rhs.group }
                if lhs.index != rhs.index { return lhs.index < rhs.index }
                return lhs.transition.id < rhs.transition.id
            }
            var writes: [String: VAOJSONValue] = [:]
            for ordered in actions {
                microsteps += 1; if microsteps > maximum { throw VAO04RuntimeError.maximumMicrosteps }
                let action = ordered.action, target = action.targetId
                switch action.operation {
                case "set-state", "toggle-state", "increment-state":
                    let current = writes[target] ?? snapshot[target]
                    let next: VAOJSONValue
                    if action.operation == "toggle-state" { next = .boolean(!(current?.booleanValue ?? false)) }
                    else if action.operation == "increment-state" { next = .number((current?.numberValue ?? 0) + (action.value?.numberValue ?? 0)) }
                    else { next = action.value ?? .null }
                    if let prior = writes[target], prior != next, ordered.transition.conflictPolicy == "reject" { throw VAO04RuntimeError.conflictingWrite(target) }
                    writes[target] = next
                case "emit-event": emitted.append(.object(["eventTypeId": .string(target), "timestamp": .number(event.timestamp), "sourceTransitionId": .string(ordered.transition.id)]))
                case "route-event": emitted.append(.object(["routeId": .string(target), "timestamp": .number(event.timestamp), "sourceTransitionId": .string(ordered.transition.id)]))
                case "start-process":
                    if let process = processes[target] {
                        for processAction in try processActions(process) {
                            emitted.append(.object(["processId": .string(target), "operation": .string(processAction.operation), "targetId": .string(processAction.targetId), "timestamp": .number(event.timestamp)]))
                        }
                    }
                case "select-render-binding": selected.append(target)
                default: break
                }
            }
            state.merge(writes) { _, new in new }
            for binding in model.renderBindings where binding.eventTypeId == nil || binding.eventTypeId == event.eventTypeId {
                if (binding.conditions ?? []).allSatisfy({ condition($0, state: state) }) { selected.append(binding.id) }
            }
        }
        var seen: Set<String> = []
        let uniqueSelected = selected.filter { seen.insert($0).inserted }
        return VAO04RuntimeResult(state: state, emittedEvents: emitted, renderBindingIds: uniqueSelected)
    }

    public static func verify(trace: VAO04ConformanceTrace, manifest: VAO04Manifest) -> [String] {
        var errors: [String] = []
        do {
            let result = try execute(manifest: manifest, events: trace.inputEvents, initialState: trace.initialState ?? [:])
            let expected = VAO04RuntimeResult(state: trace.expected.state, emittedEvents: trace.expected.emittedEvents, renderBindingIds: trace.expected.renderBindingIds)
            if result != expected { errors.append("Conformance trace \(trace.id) does not match deterministic execution.") }
        } catch { errors.append("Conformance trace \(trace.id) cannot execute: \(error.localizedDescription)") }
        return errors
    }
}
