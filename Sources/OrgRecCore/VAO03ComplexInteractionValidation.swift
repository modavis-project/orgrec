import Foundation

/// Cross-registry validation for the optional VAO 0.3.3 complex-instrument
/// behavior and capture-lineage contracts. The records are declarative: no
/// executable code is admitted by the model.
enum VAO03ComplexInteractionValidator {
    static let statefulInteractionCapability = VAO03PlayableValidator.capabilityBase + "stateful-interaction"
    static let conditionalRoutingCapability = VAO03PlayableValidator.capabilityBase + "conditional-routing"
    static let compositeActuationCapability = VAO03PlayableValidator.capabilityBase + "composite-actuation"
    static let timedProcessCapability = VAO03PlayableValidator.capabilityBase + "timed-process"
    static let actuatorTransferCapability = VAO03PlayableValidator.capabilityBase + "actuator-transfer"
    static let captureEventAlignmentCapability = VAO03PlayableValidator.capabilityBase + "capture-event-alignment"

    static let capabilities: Set<String> = [
        statefulInteractionCapability, conditionalRoutingCapability, compositeActuationCapability,
        timedProcessCapability, actuatorTransferCapability, captureEventAlignmentCapability,
    ]

    static func identifiers(interaction: VAO03InteractionModel?, capture: VAO03CaptureDocumentation?) -> [String] {
        let interactionIDs: [String]
        if let interaction {
            interactionIDs = interaction.controls.map(\.id)
                + interaction.eventTypes.map(\.id)
                + interaction.protocolBindings.map(\.id)
                + interaction.stateVariables.map(\.id)
                + interaction.transitions.map(\.id)
                + interaction.routingRules.map(\.id)
                + interaction.processModels.map(\.id)
                + interaction.timingConstraints.map(\.id)
                + interaction.transferFunctions.map(\.id)
                + interaction.renderBindings.map(\.id)
        } else {
            interactionIDs = []
        }
        guard let capture else { return interactionIDs }
        return interactionIDs
            + capture.captureStates.map(\.id)
            + capture.eventAlignments.map(\.id)
            + capture.takeSets.map(\.id)
            + capture.derivationMaps.map(\.id)
    }

    static func validate(
        manifest: VAO03Manifest,
        entities: [String: VAO03Entity],
        realizations: [String: VAO03Realization],
        errors: inout [String]
    ) {
        let profileRecords = manifest.profiles + manifest.materializableProfiles.map {
            VAO03Profile(id: $0.id, version: $0.version, requiredCapabilities: $0.requiredCapabilities)
        }
        let playableProfiles = profileRecords.filter { $0.id == VAO03Contract.playableProfile }
        let claims = Set(playableProfiles.flatMap(\.requiredCapabilities))
        let complexClaims = claims.intersection(capabilities)
        if !complexClaims.isEmpty && manifest.interactionModel == nil {
            errors.append("Complex interaction capabilities require the closed top-level interactionModel object.")
        }
        if manifest.interactionModel != nil && playableProfiles.isEmpty {
            errors.append("An interactionModel object requires a Playable 0.3 profile claim.")
        }
        if claims.contains(captureEventAlignmentCapability) && manifest.captureDocumentation == nil {
            errors.append("The capture-event-alignment capability requires captureDocumentation.")
        }
        if manifest.captureDocumentation != nil && playableProfiles.isEmpty {
            errors.append("A captureDocumentation object requires a Playable 0.3 profile claim.")
        }

        let model = manifest.interactionModel
        let controls = indexed(model?.controls ?? [], key: \.id)
        let events = indexed(model?.eventTypes ?? [], key: \.id)
        let states = indexed(model?.stateVariables ?? [], key: \.id)
        let routes = indexed(model?.routingRules ?? [], key: \.id)
        let processes = indexed(model?.processModels ?? [], key: \.id)
        let timings = indexed(model?.timingConstraints ?? [], key: \.id)
        let renders = indexed(model?.renderBindings ?? [], key: \.id)
        let sampleMappings = indexed(manifest.playable?.sampleMappings ?? [], key: \.id)
        let sampleVariants = indexed(manifest.playable?.sampleVariants ?? [], key: \.id)
        let knownActivities = Set((manifest.paradata + manifest.analyses).compactMap {
            $0.objectValue?["id"]?.stringValue
        }).union(manifest.relations.map(\.id))

        func evidence(
            id: String, status: String, source: String,
            generatedByID: String?, reviewedByID: String?, label: String
        ) {
            if (status == "inferred" || source == "algorithmic") && generatedByID == nil {
                errors.append("\(label) \(id) is inferred or algorithmic but lacks generatedById.")
            }
            if let generatedByID, !knownActivities.contains(generatedByID) {
                errors.append("\(label) \(id) has unresolved generatedById \(generatedByID).")
            }
            if let reviewedByID, !knownActivities.contains(reviewedByID) {
                errors.append("\(label) \(id) has unresolved reviewedById \(reviewedByID).")
            }
            if status == "asserted" && source == "algorithmic" {
                errors.append("\(label) \(id) cannot describe algorithmic output as asserted source metadata.")
            }
        }

        func check(_ condition: VAO03StateCondition, owner: String) {
            if states[condition.stateVariableId] == nil {
                errors.append("\(owner) has unresolved stateVariableId \(condition.stateVariableId).")
            }
        }

        func check(_ action: VAO03DeclarativeAction, owner: String) {
            let valid: Bool
            switch action.operation {
            case "set-state", "toggle-state", "increment-state": valid = states[action.targetId] != nil
            case "emit-event": valid = events[action.targetId] != nil
            case "start-process", "stop-process": valid = processes[action.targetId] != nil
            case "route-event": valid = routes[action.targetId] != nil
            case "select-render-binding": valid = renders[action.targetId] != nil
            default: valid = false
            }
            if !valid { errors.append("\(owner) action \(action.operation) has an unresolved or incompatible targetId \(action.targetId).") }
            if let delay = action.delayConstraintId, timings[delay] == nil {
                errors.append("\(owner) action has unresolved delayConstraintId \(delay).")
            }
            if action.operation == "set-state" && action.value == nil {
                errors.append("\(owner) set-state action requires value.")
            }
            if action.operation == "increment-state" && action.value?.numberValue == nil {
                errors.append("\(owner) increment-state action requires a numeric value.")
            }
            if action.operation != "route-event" && action.keyOffset != nil {
                errors.append("\(owner) uses keyOffset on a non-routing action.")
            }
        }

        for control in model?.controls ?? [] {
            evidence(id: control.id, status: control.status, source: control.source, generatedByID: control.generatedById, reviewedByID: control.reviewedById, label: "Interaction control")
            if let entityID = control.entityId, entities[entityID] == nil { errors.append("Interaction control \(control.id) has unresolved entityId.") }
            if let minimum = control.minimumValue, let maximum = control.maximumValue, minimum > maximum { errors.append("Interaction control \(control.id) has reversed value bounds.") }
            if control.controlBehavior == "stepped" && control.stepCount == nil { errors.append("Stepped interaction control \(control.id) requires stepCount.") }
            if control.valueType == "enumerated" && (control.allowedValues?.isEmpty != false) { errors.append("Enumerated interaction control \(control.id) requires allowedValues.") }
        }
        for event in model?.eventTypes ?? [] {
            evidence(id: event.id, status: event.status, source: event.source, generatedByID: event.generatedById, reviewedByID: event.reviewedById, label: "Interaction event type")
        }
        for binding in model?.protocolBindings ?? [] {
            evidence(id: binding.id, status: binding.status, source: binding.source, generatedByID: binding.generatedById, reviewedByID: binding.reviewedById, label: "Protocol binding")
            if controls[binding.controlId] == nil { errors.append("Protocol binding \(binding.id) has unresolved controlId.") }
            if events[binding.eventTypeId] == nil { errors.append("Protocol binding \(binding.id) has unresolved eventTypeId.") }
            if ["MIDI-1.0", "MIDI-2.0"].contains(binding.protocolName) {
                guard let channelBase = binding.channelNumberingBase, let dataBase = binding.dataNumberingBase else {
                    errors.append("MIDI protocol binding \(binding.id) requires explicit channelNumberingBase and dataNumberingBase.")
                    continue
                }
                if let channel = binding.channel {
                    if !(channelBase...(channelBase + 15)).contains(channel) { errors.append("MIDI protocol binding \(binding.id) has a channel outside its declared numbering base.") }
                } else { errors.append("MIDI protocol binding \(binding.id) requires channel.") }
                if !["pitch-bend", "channel-pressure", "system-exclusive"].contains(binding.messageType) {
                    if let number = binding.number {
                        if !(dataBase...(dataBase + 127)).contains(number) { errors.append("MIDI protocol binding \(binding.id) has a number outside its declared numbering base.") }
                    } else { errors.append("MIDI protocol binding \(binding.id) requires number.") }
                }
            } else if binding.messageType == "addressed-value" && binding.address == nil {
                errors.append("Addressed protocol binding \(binding.id) requires address.")
            }
        }
        for state in model?.stateVariables ?? [] {
            evidence(id: state.id, status: state.status, source: state.source, generatedByID: state.generatedById, reviewedByID: state.reviewedById, label: "State variable")
            if let subject = state.subjectEntityId, entities[subject] == nil { errors.append("State variable \(state.id) has unresolved subjectEntityId.") }
            if let minimum = state.minimumValue, let maximum = state.maximumValue, minimum > maximum { errors.append("State variable \(state.id) has reversed value bounds.") }
            if state.valueType == "enumerated" && !(state.allowedValues ?? []).contains(state.defaultValue) { errors.append("Enumerated state variable \(state.id) has a default outside allowedValues.") }
        }
        for transition in model?.transitions ?? [] {
            evidence(id: transition.id, status: transition.status, source: transition.source, generatedByID: transition.generatedById, reviewedByID: transition.reviewedById, label: "Interaction transition")
            if events[transition.eventTypeId] == nil { errors.append("Interaction transition \(transition.id) has unresolved eventTypeId.") }
            if let controlID = transition.controlId, controls[controlID] == nil { errors.append("Interaction transition \(transition.id) has unresolved controlId.") }
            for condition in transition.conditions ?? [] { check(condition, owner: "Interaction transition \(transition.id)") }
            for action in transition.actions { check(action, owner: "Interaction transition \(transition.id)") }
        }

        var routeEdges: [String: [String]] = [:]
        for route in model?.routingRules ?? [] {
            evidence(id: route.id, status: route.status, source: route.source, generatedByID: route.generatedById, reviewedByID: route.reviewedById, label: "Routing rule")
            if entities[route.sourceEntityId] == nil || entities[route.targetEntityId] == nil { errors.append("Routing rule \(route.id) has an unresolved source or target entity.") }
            if ["copies", "transposes"].contains(route.routingBehavior) { routeEdges[route.sourceEntityId, default: []].append(route.targetEntityId) }
            if let controlID = route.sourceControlId, controls[controlID] == nil { errors.append("Routing rule \(route.id) has unresolved sourceControlId.") }
            if route.inputRange.minimum > route.inputRange.maximum { errors.append("Routing rule \(route.id) has a reversed input range.") }
            switch route.keyTransform.kind {
            case "transpose":
                guard let offset = route.keyTransform.semitoneOffset else { errors.append("Routing rule \(route.id) transpose transform requires semitoneOffset."); break }
                if route.inputRange.minimum + offset < 0 || route.inputRange.maximum + offset > 127 { errors.append("Routing rule \(route.id) transposes outside the MIDI key domain.") }
            case "fixed": if route.keyTransform.fixedOutputKeys?.isEmpty != false { errors.append("Routing rule \(route.id) fixed transform requires fixedOutputKeys.") }
            case "table":
                let keys = (route.keyTransform.entries ?? []).map(\.inputKey)
                if keys.isEmpty || Set(keys).count != keys.count { errors.append("Routing rule \(route.id) table transform needs unique entries.") }
            default: break
            }
            for condition in route.conditions ?? [] { check(condition, owner: "Routing rule \(route.id)") }
        }
        findCycles(routeEdges, label: "Interaction routing graph", errors: &errors)

        for timing in model?.timingConstraints ?? [] {
            evidence(id: timing.id, status: timing.status, source: timing.source, generatedByID: timing.generatedById, reviewedByID: timing.reviewedById, label: "Timing constraint")
            let values = [timing.minimum, timing.typical, timing.maximum].compactMap { $0 }
            if values != values.sorted() { errors.append("Timing constraint \(timing.id) has inconsistent minimum/typical/maximum ordering.") }
            for target in timing.appliesToIds ?? [] where controls[target] == nil && routes[target] == nil && processes[target] == nil && entities[target] == nil {
                errors.append("Timing constraint \(timing.id) has unresolved appliesToId \(target).")
            }
        }
        var processEdges: [String: [String]] = [:]
        for process in model?.processModels ?? [] {
            evidence(id: process.id, status: process.status, source: process.source, generatedByID: process.generatedById, reviewedByID: process.reviewedById, label: "Process model")
            processEdges[process.id] = (process.childProcessIds ?? []).filter { processes[$0] != nil }
            for child in process.childProcessIds ?? [] where processes[child] == nil { errors.append("Process model \(process.id) has unresolved child process \(child).") }
            for timing in process.timingConstraintIds ?? [] where timings[timing] == nil { errors.append("Process model \(process.id) has unresolved timing constraint \(timing).") }
            for action in process.actions { check(action, owner: "Process model \(process.id)") }
            if ["repeating", "stochastic"].contains(process.processKind) && process.terminationPolicy == "completed" { errors.append("Process model \(process.id) is potentially unbounded and needs an explicit termination mechanism.") }
            if process.terminationPolicy == "maximum-iterations" && process.maximumIterations == nil { errors.append("Process model \(process.id) requires maximumIterations.") }
            if process.terminationPolicy == "duration-bound" && timings[process.durationConstraintId ?? ""] == nil { errors.append("Process model \(process.id) requires a resolved durationConstraintId.") }
            if ["on-control-release", "external-cancel"].contains(process.terminationPolicy) && controls[process.cancellationControlId ?? ""] == nil { errors.append("Process model \(process.id) requires a resolved cancellationControlId.") }
            if process.processKind == "compound" && process.actions.count + (process.childProcessIds?.count ?? 0) < 2 { errors.append("Compound process model \(process.id) requires at least two actions or child processes.") }
        }
        findCycles(processEdges, label: "Interaction process graph", errors: &errors)

        for transfer in model?.transferFunctions ?? [] {
            evidence(id: transfer.id, status: transfer.status, source: transfer.source, generatedByID: transfer.generatedById, reviewedByID: transfer.reviewedById, label: "Transfer function")
            let inputs = transfer.points.map(\.input)
            if inputs != inputs.sorted() || Set(inputs).count != inputs.count { errors.append("Transfer function \(transfer.id) points must have unique ascending inputs.") }
            for target in transfer.appliesToIds ?? [] where controls[target] == nil && states[target] == nil && routes[target] == nil && sampleMappings[target] == nil { errors.append("Transfer function \(transfer.id) has unresolved appliesToId \(target).") }
        }
        for render in model?.renderBindings ?? [] {
            evidence(id: render.id, status: render.status, source: render.source, generatedByID: render.generatedById, reviewedByID: render.reviewedById, label: "Render binding")
            if let event = render.eventTypeId, events[event] == nil { errors.append("Render binding \(render.id) has unresolved eventTypeId.") }
            if let process = render.processModelId, processes[process] == nil { errors.append("Render binding \(render.id) has unresolved processModelId.") }
            for condition in render.conditions ?? [] { check(condition, owner: "Render binding \(render.id)") }
            for mapping in render.sampleMappingIds ?? [] where sampleMappings[mapping] == nil { errors.append("Render binding \(render.id) has unresolved sample mapping \(mapping).") }
            for variant in render.sampleVariantIds ?? [] where sampleVariants[variant] == nil { errors.append("Render binding \(render.id) has unresolved sample variant \(variant).") }
        }

        if claims.contains(statefulInteractionCapability) && (states.isEmpty || model?.transitions.isEmpty != false) { errors.append("The stateful-interaction capability requires state variables and transitions.") }
        if claims.contains(conditionalRoutingCapability) && !(model?.routingRules.contains { $0.conditions?.isEmpty == false } ?? false) { errors.append("The conditional-routing capability requires a routing rule with state conditions.") }
        if claims.contains(compositeActuationCapability) && !(model?.processModels.contains { $0.processKind == "compound" && usable($0.status) } ?? false) { errors.append("The composite-actuation capability requires a usable compound process model.") }
        if claims.contains(timedProcessCapability) && !(model?.processModels.contains { $0.timingConstraintIds?.isEmpty == false } ?? false) { errors.append("The timed-process capability requires a process bound to timing constraints.") }
        if claims.contains(actuatorTransferCapability) && !(model?.transferFunctions.contains { usable($0.status) } ?? false) { errors.append("The actuator-transfer capability requires a usable transfer function.") }

        validateCapture(
            manifest: manifest, states: states, events: events, realizations: realizations,
            knownActivities: knownActivities, claims: claims, errors: &errors
        )
        for mapping in manifest.playable?.sampleMappings ?? [] where mapping.velocitySensitivity == "transfer-function" {
            if !(model?.transferFunctions.contains { $0.appliesToIds?.contains(mapping.id) == true } ?? false) { errors.append("Sample mapping \(mapping.id) declares transfer-function velocity sensitivity without an applicable transfer function.") }
        }
    }

    private static func validateCapture(
        manifest: VAO03Manifest,
        states: [String: VAO03StateVariable],
        events: [String: VAO03InteractionEventType],
        realizations: [String: VAO03Realization],
        knownActivities: Set<String>,
        claims: Set<String>,
        errors: inout [String]
    ) {
        guard let capture = manifest.captureDocumentation else { return }
        func evidence(
            _ id: String, _ status: String, _ source: String,
            _ generatedByID: String?, _ reviewedByID: String?, _ label: String
        ) {
            if (status == "inferred" || source == "algorithmic") && generatedByID == nil {
                errors.append("\(label) \(id) is inferred or algorithmic but lacks generatedById.")
            }
            if let generatedByID, !knownActivities.contains(generatedByID) {
                errors.append("\(label) \(id) has unresolved generatedById \(generatedByID).")
            }
            if let reviewedByID, !knownActivities.contains(reviewedByID) {
                errors.append("\(label) \(id) has unresolved reviewedById \(reviewedByID).")
            }
            if status == "asserted" && source == "algorithmic" {
                errors.append("\(label) \(id) cannot describe algorithmic output as asserted source metadata.")
            }
        }
        let entities = indexed(manifest.entities, key: \.id)
        let captureStates = indexed(capture.captureStates, key: \.id)
        for state in capture.captureStates {
            evidence(state.id, state.status, state.source, state.generatedById, state.reviewedById, "Capture state")
            if entities[state.instrumentEntityId]?.kind != "instrument" { errors.append("Capture state \(state.id) does not resolve an instrument entity.") }
            let assignmentIDs = state.stateAssignments.map(\.stateVariableId)
            if Set(assignmentIDs).count != assignmentIDs.count { errors.append("Capture state \(state.id) assigns a state variable more than once.") }
            for id in assignmentIDs where states[id] == nil { errors.append("Capture state \(state.id) has unresolved state variable \(id).") }
        }
        for alignment in capture.eventAlignments {
            evidence(alignment.id, alignment.status, alignment.source, alignment.generatedById, alignment.reviewedById, "Event alignment")
            let audio = realizations[alignment.audioRealizationId]
            if audio?.technicalMetadata.kind != "audio" { errors.append("Event alignment \(alignment.id) must reference an audio realization.") }
            if realizations[alignment.eventLogRealizationId] == nil { errors.append("Event alignment \(alignment.id) has unresolved event-log realization.") }
            for mapping in alignment.eventMappings {
                if let event = mapping.eventTypeId, events[event] == nil { errors.append("Event alignment \(alignment.id) has unresolved eventTypeId \(event).") }
                if let end = mapping.endFrameExclusive {
                    if end <= mapping.startFrame { errors.append("Event alignment \(alignment.id) has an empty event frame range.") }
                    if let frameCount = audio?.technicalMetadata.frameCount, end > frameCount { errors.append("Event alignment \(alignment.id) exceeds audio frameCount.") }
                }
            }
        }
        for takeSet in capture.takeSets {
            evidence(takeSet.id, takeSet.status, takeSet.source, takeSet.generatedById, takeSet.reviewedById, "Take set")
            if captureStates[takeSet.captureStateId] == nil { errors.append("Take set \(takeSet.id) has unresolved captureStateId.") }
            for realization in takeSet.realizationIds where realizations[realization] == nil { errors.append("Take set \(takeSet.id) has unresolved realization \(realization).") }
            if takeSet.setRole == "round-robin" && takeSet.selectionStatus != "accepted" { errors.append("Round-robin take set \(takeSet.id) must be explicitly accepted.") }
        }
        var derivationEdges: [String: [String]] = [:]
        for derivation in capture.derivationMaps {
            evidence(derivation.id, derivation.status, derivation.source, derivation.generatedById, derivation.reviewedById, "Derivation map")
            let source = realizations[derivation.sourceRealizationId]
            let derived = realizations[derivation.derivedRealizationId]
            if source == nil || derived == nil { errors.append("Derivation map \(derivation.id) has an unresolved source or derived realization.") }
            else if derivation.sourceRealizationId == derivation.derivedRealizationId { errors.append("Derivation map \(derivation.id) cannot derive a realization from itself.") }
            else { derivationEdges[derivation.sourceRealizationId, default: []].append(derivation.derivedRealizationId) }
            if let range = derivation.sourceFrameRange {
                if range.endFrameExclusive <= range.startFrameInclusive { errors.append("Derivation map \(derivation.id) has an empty source frame range.") }
                if let count = source?.technicalMetadata.frameCount, range.endFrameExclusive > count { errors.append("Derivation map \(derivation.id) exceeds source frameCount.") }
            }
            if let channels = derivation.channelMap, let count = source?.technicalMetadata.channelCount, channels.contains(where: { $0 >= count }) { errors.append("Derivation map \(derivation.id) contains an out-of-range source channel.") }
            for operation in derivation.operations {
                if let activity = operation.activityId, !knownActivities.contains(activity) { errors.append("Derivation map \(derivation.id) has unresolved operation activityId \(activity).") }
            }
        }
        findCycles(derivationEdges, label: "Capture derivation graph", errors: &errors)
        if claims.contains(captureEventAlignmentCapability) && !capture.eventAlignments.contains(where: { usable($0.status) }) { errors.append("The capture-event-alignment capability requires a usable event alignment.") }
    }

    private static func usable(_ status: String) -> Bool {
        ["asserted", "reviewed", "accepted"].contains(status)
    }

    private static func indexed<Value>(_ values: [Value], key: KeyPath<Value, String>) -> [String: Value] {
        var result: [String: Value] = [:]
        for value in values where result[value[keyPath: key]] == nil { result[value[keyPath: key]] = value }
        return result
    }

    private static func findCycles(_ edges: [String: [String]], label: String, errors: inout [String]) {
        var visiting = Set<String>()
        var visited = Set<String>()
        func visit(_ id: String) {
            if visiting.contains(id) { errors.append("\(label) contains a cycle at \(id)."); return }
            if visited.contains(id) { return }
            visiting.insert(id)
            for target in edges[id] ?? [] { visit(target) }
            visiting.remove(id)
            visited.insert(id)
        }
        for id in edges.keys { visit(id) }
    }
}
