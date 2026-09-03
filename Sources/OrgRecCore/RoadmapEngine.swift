import Foundation

public struct RoadmapCompilation: Sendable {
    public var roadmap: [RoadmapItem]
    public var registrations: [RegistrationState]
    public var report: RoadmapCompilationReport
    public var physicalSoundTargets: [PhysicalSoundTarget]
    public var overlapCandidates: [PhysicalOverlapCandidate]
    public var captureStates: [CaptureStateSnapshot]
}

public enum RoadmapEngine {
    public static func generate(
        components: [OrganComponent],
        recipe: CaptureRecipe,
        setupIDs: [UUID] = []
    ) -> [RoadmapItem] {
        components.flatMap { component in
            recipe.techniques.map { technique in
                let setupID: UUID?
                switch technique {
                case .closePair: setupID = setupIDs.first
                case .naveORTF: setupID = setupIDs.dropFirst().first ?? setupIDs.first
                case .rearOmni: setupID = setupIDs.dropFirst(2).first ?? setupIDs.last
                case .releaseTail: setupID = setupIDs.dropFirst().first ?? setupIDs.first
                }
                return RoadmapItem(component: component, technique: technique, recipeID: recipe.id, setupID: setupID)
            }
        }
    }

    public static func compileSpecification(
        components: [OrganComponent],
        recipe: CaptureRecipe,
        setupIDs: [UUID] = [],
        relationships: [OrganComponentRelationship] = [],
        physicalPipeMappings: [PhysicalPipeMapping] = [],
        sharingAssertions: [PipeSharingAssertion] = []
    ) -> RoadmapCompilation {
        let stops = components.filter { normalizedKind($0.kind) == "stop" }
        let couplers = components.filter { normalizedKind($0.kind) == "coupler" }
        let accessories = components.filter { normalizedKind($0.kind) == "accessory" }
        let divisions = components.filter { normalizedKind($0.kind) == "division" }
        let keyboards = components.filter { normalizedKind($0.kind) == "keyboard" }
        let ranks = components.filter { normalizedKind($0.kind) == "rank" }
        let explicitPositions = components.filter {
            let kind = normalizedKind($0.kind)
            return (kind == "pipe_position" || kind == "pipe") && $0.midiNote != nil
        }
        let mappingByAddress = Dictionary(
            physicalPipeMappings.map { (addressKey(stopID: $0.stopComponentID, midi: $0.keyMIDI), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let rankByStop = sharedRankIDs(stops: stops, relationships: relationships)
        let validAssertions = sharingAssertions.filter { assertion in
            stops.first?.locator.snapshotSHA256 == assertion.snapshotSHA256
        }
        var registrations: [RegistrationState] = []
        var resolvedRoutes: [(signature: String, route: PhysicalActivationRoute, coverage: RoadmapCoverageKind)] = []
        var usedExplicitPositionIDs = Set<String>()
        var assumedCompassCount = 0

        for stop in stops {
            let registration = RegistrationState(
                activatedStops: [stop.locator],
                notes: "Source-backed isolated speaking stop.",
                name: stop.label,
                purpose: "Isolated stop across its playable compass"
            )
            registrations.append(registration)
            let range: ClosedRange<Int>
            if let low = stop.playableMIDILow, let high = stop.playableMIDIHigh, low <= high {
                range = max(0, low)...min(127, high)
            } else {
                assumedCompassCount += 1
                range = stop.division.localizedCaseInsensitiveContains("pedal") ? 36...67 : 36...96
            }
            for midi in stride(from: range.lowerBound, through: range.upperBound, by: max(1, recipe.chromaticStep)) {
                let explicit = explicitPositions.first {
                    $0.midiNote == midi && ($0.parentComponentID == stop.id ||
                        ($0.parentComponentID == nil && $0.label == stop.label && $0.division == stop.division))
                }
                let position = explicit ?? functionalPosition(for: stop, midi: midi)
                if let explicit { usedExplicitPositionIDs.insert(explicit.id) }
                let identity = resolvePhysicalIdentity(
                    stop: stop,
                    midi: midi,
                    position: position,
                    mapping: mappingByAddress[addressKey(stopID: stop.id, midi: midi)],
                    sharedRankID: rankByStop[stop.id],
                    assertions: validAssertions
                )
                let route = PhysicalActivationRoute(
                    id: addressKey(stopID: stop.id, midi: midi),
                    component: position,
                    registrationID: registration.id,
                    physicalPipeComponentIDs: identity.physicalIDs,
                    evidence: identity.evidence,
                    evidenceDescription: identity.description
                )
                resolvedRoutes.append((identity.signature, route, .isolatedStop))
            }
        }

        for position in explicitPositions where usedExplicitPositionIDs.contains(position.id) == false {
            let registration = RegistrationState(
                activatedStops: [position.locator],
                notes: "Navigator supplied an explicit pipe or functional position.",
                name: position.label,
                purpose: "Explicit pipe-position capture"
            )
            registrations.append(registration)
            let physicalID = position.locator.canonicalMDVSID ?? position.locator.pipePositionReference ?? position.id
            let evidence: PhysicalIdentityEvidence = position.locator.canonicalMDVSID == nil ? .uniqueFunctionalAddress : .canonicalPipe
            let signature = evidence.isConfirmedSharedIdentity ? "pipes|\(physicalID)" : "address|\(position.id)"
            let route = PhysicalActivationRoute(
                id: "explicit|\(position.id)",
                component: position,
                registrationID: registration.id,
                physicalPipeComponentIDs: [physicalID],
                evidence: evidence,
                evidenceDescription: evidence == .canonicalPipe ? "Canonical physical pipe supplied by Navigator." : "Explicit functional position without proven physical equivalence."
            )
            resolvedRoutes.append((signature, route, .explicitPipe))
        }

        let groupedRoutes = Dictionary(grouping: resolvedRoutes, by: \.signature)
        let physicalTargets = groupedRoutes.keys.sorted().compactMap { signature -> PhysicalSoundTarget? in
            guard let entries = groupedRoutes[signature], entries.isEmpty == false else { return nil }
            let routes = entries.map(\.route).sorted(by: preferredRoute)
            guard let primary = routes.first else { return nil }
            let evidence = routes.map(\.evidence).min(by: evidencePriority) ?? .uniqueFunctionalAddress
            return PhysicalSoundTarget(
                id: "physical-target:\(Data(signature.utf8).sha256Hex)",
                physicalPipeComponentIDs: primary.physicalPipeComponentIDs,
                routes: routes,
                primaryRouteID: primary.id,
                evidence: evidence
            )
        }
        var roadmap = physicalTargets.flatMap { target in
            targetItems(target: target, recipe: recipe, setupIDs: setupIDs)
        }
        let overlapCandidates = suspectedOverlapCandidates(
            stops: stops,
            sharedRankByStop: rankByStop,
            assertions: validAssertions
        )

        let intendedSoundingTargets = components.compactMap { component -> (OrganComponent, SoundingTargetDefinition)? in
            guard let definition = soundingTargetDefinition(for: component), definition.family != .pipeSpeech else { return nil }
            var target = component
            target.soundingTargetDefinition = definition
            return (target, definition)
        }
        let intendedComponentIDs = Set(intendedSoundingTargets.map { $0.0.id })
        var intendedSoundItemCount = 0
        for (target, definition) in intendedSoundingTargets {
            let sourceKind = normalizedKind(target.kind)
            let registration = RegistrationState(
                activatedAccessories: sourceKind == "accessory" ? [target.locator] : [],
                notes: "This is an intended sounding target, not actuator or mechanism noise.",
                name: target.label,
                purpose: definition.family.displayName
            )
            registrations.append(registration)
            let generated = soundingTargetItems(
                component: target,
                definition: definition,
                recipe: recipe,
                setupIDs: setupIDs,
                registrationID: registration.id
            )
            intendedSoundItemCount += generated.count
            roadmap.append(contentsOf: generated)
        }

        var controlSoundCount = 0
        for control in couplers + accessories.filter({ intendedComponentIDs.contains($0.id) == false }) {
            guard let baseStop = controlBaseStop(control, stops: stops) else { continue }
            let isCoupler = normalizedKind(control.kind) == "coupler"
            let registration = RegistrationState(
                activatedStops: [baseStop.locator],
                activatedCouplers: isCoupler ? [control.locator] : [],
                activatedAccessories: isCoupler ? [] : [control.locator],
                notes: "Compare with the isolated base-stop take to document the control's audible effect.",
                name: "\(control.label) · \(baseStop.label)",
                purpose: isCoupler ? "Coupler effect" : "Accessory effect"
            )
            registrations.append(registration)
            for midi in representativeNotes(for: baseStop) {
                var test = functionalPosition(for: baseStop, midi: midi)
                test.id = "control:\(control.id):\(midi)"
                test.kind = isCoupler ? "coupler_test" : "accessory_test"
                test.label = control.label
                test.parentComponentID = control.id
                test.locator = control.locator
                controlSoundCount += 1
                roadmap.append(contentsOf: items(
                    component: test,
                    recipe: recipe,
                    setupIDs: setupIDs,
                    registrationID: registration.id,
                    coverageKind: isCoupler ? .couplerEffect : .accessoryEffect,
                    instructions: "Activate \(baseStop.label) plus \(control.label); play \(noteName(midi)), then compare with the isolated stop."
                ))
            }
        }

        // Instrument-operation noises are independent acoustic targets. They
        // are suggested (optional) by default and can be promoted, expanded,
        // or replaced with organ-specific variants in the planning wizard.
        let instrumentNoiseRoadmap = recommendedInstrumentNoiseItems(
            components: components,
            recipe: recipe,
            setupIDs: setupIDs
        )
        roadmap.append(contentsOf: instrumentNoiseRoadmap)

        let registrationsByID = Dictionary(uniqueKeysWithValues: registrations.map { ($0.id, $0) })
        var captureStateByFingerprint: [String: CaptureStateSnapshot] = [:]
        roadmap = roadmap.map { source in
            var item = source
            let registration = item.registrationID.flatMap { registrationsByID[$0] }
            let generated = requiredCaptureState(for: item, registration: registration, components: components)
            let state = captureStateByFingerprint[generated.fingerprintSHA256] ?? generated
            captureStateByFingerprint[state.fingerprintSHA256] = state
            item.requiredCaptureStateID = state.id
            item.requiredCaptureStateFingerprint = state.fingerprintSHA256
            item.requiredCaptureState = nil
            return item
        }

        let switchCount = stops.count + couplers.count + accessories.count
        var warnings: [String] = []
        if assumedCompassCount > 0 {
            warnings.append("\(assumedCompassCount) stop compasses were absent; OrgRec assumed C2–C7 for manuals and C2–G4 for pedal stops. Confirm these ranges before fieldwork.")
        }
        if stops.isEmpty && explicitPositions.isEmpty {
            warnings.append("No speaking stops or explicit pipe positions could be compiled from the Navigator response.")
        }
        if switchCount > 20 {
            warnings.append("The full registration power set is intentionally not pre-expanded. Use the custom registration planner for any desired state.")
        }
        let documentedPitch = components.compactMap(\.referencePitchHz).first
        let temperament = components.compactMap(\.temperament).first
        if documentedPitch == nil {
            warnings.append("No tuning pitch was documented; expected frequencies assume A4 = 440 Hz and must be confirmed by CREPE.")
        }
        var report = RoadmapCompilationReport(
            sourceStopCount: stops.count,
            sourceCouplerCount: couplers.count,
            sourceAccessoryCount: accessories.count,
            sourceDivisionCount: divisions.count,
            sourceKeyboardCount: keyboards.count,
            sourceRankCount: ranks.count,
            explicitPipePositionCount: explicitPositions.count,
            generatedAtomicSoundCount: physicalTargets.count,
            generatedControlTestCount: controlSoundCount,
            theoreticalRegistrationStateCount: decimalPowerSetCount(switchCount),
            assumedCompassCount: assumedCompassCount,
            warnings: warnings,
            referencePitchHz: documentedPitch ?? 440,
            tuningPitchAssumed: documentedPitch == nil,
            temperament: temperament,
            logicalSoundAddressCount: resolvedRoutes.count,
            physicalSoundTargetCount: physicalTargets.count,
            sharedAliasCount: max(0, resolvedRoutes.count - physicalTargets.count),
            unresolvedSharedCandidateCount: overlapCandidates.count,
            generatedInstrumentNoiseCount: instrumentNoiseRoadmap.count,
            generatedIntendedSoundTargetCount: intendedSoundItemCount
        )
        if overlapCandidates.isEmpty == false {
            let addressCount = overlapCandidates.reduce(0) { $0 + $1.overlappingAddressCount }
            report.warnings.append("\(overlapCandidates.count) possible shared-rank overlap range(s), covering \(addressCount) logical addresses, require review; OrgRec kept them separate.")
        }
        return RoadmapCompilation(
            roadmap: roadmap,
            registrations: registrations,
            report: report,
            physicalSoundTargets: physicalTargets,
            overlapCandidates: overlapCandidates,
            captureStates: captureStateByFingerprint.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        )
    }

    /// Creates one unambiguous roadmap target per action × velocity ×
    /// configuration × microphone-technique variant. Several accepted takes
    /// may be required for each target to retain natural mechanical variation.
    public static func instrumentNoiseItems(
        component: OrganComponent,
        kind: InstrumentNoiseKind,
        actions: [InstrumentNoiseAction],
        velocityPresets: [InstrumentNoiseVelocityPreset] = [],
        configurations: [InstrumentNoiseConfiguration] = [InstrumentNoiseConfiguration()],
        minimumAcceptedTakeCount: Int = 3,
        captureDurationSeconds: Double = 6,
        recipeID: UUID,
        techniques: [CaptureTechnique],
        setupIDs: [UUID] = [],
        required: Bool = true,
        sourceScope: AcousticSourceScope? = nil,
        mechanisms: [AcousticMechanism]? = nil,
        role: AcousticEventRole = .intendedTarget,
        actuationProfile: ActuationProfile? = nil
    ) -> [RoadmapItem] {
        guard actions.isEmpty == false, techniques.isEmpty == false else { return [] }
        let resolvedConfigurations = configurations.isEmpty ? [InstrumentNoiseConfiguration()] : configurations
        return actions.flatMap { action -> [RoadmapItem] in
            let usesVelocity = actionUsesVelocity(action)
            let velocities: [InstrumentControlVelocity?] = usesVelocity && velocityPresets.isEmpty == false
                ? velocityPresets.map { InstrumentControlVelocity(preset: $0, targetDurationSeconds: suggestedDuration(for: kind, action: action, preset: $0)) }
                : [nil]
            return velocities.flatMap { velocity in
                resolvedConfigurations.flatMap { configuration in
                    let classification = classification(for: kind, action: action)
                    let resolvedActuationProfile = actuationProfileForAction(
                        template: actuationProfile,
                        kind: kind,
                        action: action,
                        velocity: velocity
                    )
                    let protocolSnapshot = InstrumentNoiseCaptureProtocol(
                        kind: kind,
                        name: "\(component.label) · \(kind.displayName)",
                        sourceComponentID: component.id,
                        sourceScope: sourceScope ?? classification.scope,
                        mechanisms: mechanisms ?? classification.mechanisms,
                        temporalBehavior: classification.temporal,
                        operatingPhase: classification.phase,
                        role: role,
                        action: action,
                        velocity: velocity,
                        configuration: configuration,
                        minimumAcceptedTakeCount: minimumAcceptedTakeCount,
                        captureDurationSeconds: captureDurationSeconds,
                        actuationProfile: resolvedActuationProfile,
                        instructions: instrumentNoiseInstructions(
                            component: component,
                            kind: kind,
                            action: action,
                            velocity: velocity,
                            configuration: configuration,
                            actuationProfile: resolvedActuationProfile,
                            repetitions: minimumAcceptedTakeCount
                        )
                    )
                    let velocityKey = velocity?.label.lowercased() ?? "unmetered"
                    let configurationKey = configuration.label.lowercased()
                    let stableKey = [component.id, kind.rawValue, action.rawValue, velocityKey, configurationKey]
                        .joined(separator: "|")
                    var target = component
                    target.id = "instrument-noise:\(Data(stableKey.utf8).sha256Hex)"
                    target.kind = "instrument_noise"
                    target.label = "\(component.label) · \(kind.displayName)"
                    target.division = "Instrument noises · \(component.division)"
                    target.noteName = protocolSnapshot.variantLabel
                    target.midiNote = nil
                    target.expectedFrequencyHz = nil
                    target.parentComponentID = component.id
                    var details = component.sourceDetails ?? [:]
                    details["orgrec:instrumentNoiseKind"] = kind.rawValue
                    details["orgrec:instrumentNoiseAction"] = action.rawValue
                    details["orgrec:sourceComponentID"] = component.id
                    target.sourceDetails = details
                    return techniques.map { technique in
                        RoadmapItem(
                            component: target,
                            technique: technique,
                            recipeID: recipeID,
                            setupID: setupID(for: technique, in: setupIDs),
                            required: required,
                            coverageKind: .instrumentNoise,
                            instructions: protocolSnapshot.instructions,
                            instrumentNoiseProtocol: protocolSnapshot
                        )
                    }
                }
            }
        }
    }

    /// Optional, conservative recommendations derived from source components.
    /// The planner can add exact key numbers, jalousie banks, pedal linkages,
    /// custom speeds, and further configurations without changing this source.
    public static func recommendedInstrumentNoiseItems(
        components: [OrganComponent],
        recipe: CaptureRecipe,
        setupIDs: [UUID] = []
    ) -> [RoadmapItem] {
        guard let technique = recipe.techniques.first(where: { $0 == .closePair }) ?? recipe.techniques.first else { return [] }
        var result: [RoadmapItem] = []
        for component in components {
            let kind = normalizedKind(component.kind)
            let searchable = "\(component.label) \(component.division) \((component.sourceDetails ?? [:]).values.joined(separator: " "))".lowercased()
            if kind == "keyboard" {
                let isPedal = searchable.contains("pedal")
                result += instrumentNoiseItems(
                    component: component,
                    kind: isPedal ? .pedalAction : .keyAction,
                    actions: isPedal ? [.pedalPress, .pedalRelease] : [.activation, .release],
                    velocityPresets: [.slow, .normal, .fast],
                    minimumAcceptedTakeCount: 3,
                    recipeID: recipe.id,
                    techniques: [technique],
                    setupIDs: setupIDs,
                    required: false
                )
            } else if kind == "stop" {
                result += instrumentNoiseItems(
                    component: component,
                    kind: .stopAction,
                    actions: [.activation, .deactivation],
                    velocityPresets: [.normal],
                    minimumAcceptedTakeCount: 2,
                    recipeID: recipe.id,
                    techniques: [technique],
                    setupIDs: setupIDs,
                    required: false
                )
            } else if kind == "coupler" {
                result += instrumentNoiseItems(
                    component: component,
                    kind: .couplerAction,
                    actions: [.activation, .deactivation],
                    velocityPresets: [.normal],
                    minimumAcceptedTakeCount: 2,
                    recipeID: recipe.id,
                    techniques: [technique],
                    setupIDs: setupIDs,
                    required: false
                )
            } else if kind == "accessory" {
                if containsAny(searchable, ["swell", "sweller", "schweller", "expression", "jalous", "shutter"]) {
                    let opening = InstrumentNoiseConfiguration(label: "Pedal and shutters", fromPosition: "closed", toPosition: "open", pedalActuationIncluded: true)
                    let closing = InstrumentNoiseConfiguration(label: "Pedal and shutters", fromPosition: "open", toPosition: "closed", pedalActuationIncluded: true)
                    result += instrumentNoiseItems(
                        component: component,
                        kind: .swellerJalousie,
                        actions: [.opening],
                        velocityPresets: [.slow, .normal, .fast],
                        configurations: [opening],
                        minimumAcceptedTakeCount: 3,
                        captureDurationSeconds: 8,
                        recipeID: recipe.id,
                        techniques: [technique],
                        setupIDs: setupIDs,
                        required: false
                    )
                    result += instrumentNoiseItems(
                        component: component,
                        kind: .swellerJalousie,
                        actions: [.closing],
                        velocityPresets: [.slow, .normal, .fast],
                        configurations: [closing],
                        minimumAcceptedTakeCount: 3,
                        captureDurationSeconds: 8,
                        recipeID: recipe.id,
                        techniques: [technique],
                        setupIDs: setupIDs,
                        required: false
                    )
                    result += instrumentNoiseItems(
                        component: component,
                        kind: .swellerJalousie,
                        actions: [.pedalPress, .pedalRelease],
                        velocityPresets: [.normal],
                        configurations: [InstrumentNoiseConfiguration(label: "Pedal linkage", pedalActuationIncluded: true)],
                        minimumAcceptedTakeCount: 3,
                        recipeID: recipe.id,
                        techniques: [technique],
                        setupIDs: setupIDs,
                        required: false
                    )
                } else if containsAny(searchable, ["blower", "motor", "ventilator", "wind machine", "windmaschine"]) {
                    result += instrumentNoiseItems(
                        component: component,
                        kind: searchable.contains("wind machine") || searchable.contains("windmaschine") ? .windSystem : .blower,
                        actions: [.startup, .steadyOperation, .shutdown],
                        minimumAcceptedTakeCount: 2,
                        captureDurationSeconds: 12,
                        recipeID: recipe.id,
                        techniques: [technique],
                        setupIDs: setupIDs,
                        required: false
                    )
                } else if containsAny(searchable, ["tremul", "tremolo"]) {
                    result += instrumentNoiseItems(
                        component: component,
                        kind: .tremulant,
                        actions: [.activation, .steadyOperation, .deactivation],
                        velocityPresets: [.normal],
                        minimumAcceptedTakeCount: 2,
                        recipeID: recipe.id,
                        techniques: [technique],
                        setupIDs: setupIDs,
                        required: false
                    )
                } else {
                    result += instrumentNoiseItems(
                        component: component,
                        kind: .accessoryAction,
                        actions: [.activation, .deactivation],
                        velocityPresets: [.normal],
                        minimumAcceptedTakeCount: 2,
                        recipeID: recipe.id,
                        techniques: [technique],
                        setupIDs: setupIDs,
                        required: false
                    )
                }
            }
        }
        return result
    }

    public static func customRegistration(
        name: String,
        stops: [OrganComponent],
        couplers: [OrganComponent],
        accessories: [OrganComponent],
        midiRange: ClosedRange<Int>,
        step: Int,
        recipe: CaptureRecipe,
        setupIDs: [UUID]
    ) -> (RegistrationState, [RoadmapItem]) {
        let registration = RegistrationState(
            activatedStops: stops.map(\.locator),
            activatedCouplers: couplers.map(\.locator),
            activatedAccessories: accessories.map(\.locator),
            notes: "User-planned registration derived from the frozen MODAVIS specification.",
            name: name,
            purpose: "Custom hypothetical registration"
        )
        guard let anchor = stops.first ?? couplers.first ?? accessories.first else { return (registration, []) }
        var result: [RoadmapItem] = []
        for midi in stride(from: max(0, midiRange.lowerBound), through: min(127, midiRange.upperBound), by: max(1, step)) {
            var component = functionalPosition(for: anchor, midi: midi)
            component.id = "registration:\(registration.id.uuidString.lowercased()):\(midi)"
            component.kind = "registration"
            component.label = name
            component.division = "Custom registration"
            component.parentComponentID = nil
            result.append(contentsOf: items(
                component: component,
                recipe: recipe,
                setupIDs: setupIDs,
                registrationID: registration.id,
                coverageKind: .customRegistration,
                instructions: "Activate the documented custom registration and play \(noteName(midi))."
            ))
        }
        return (registration, result)
    }

    public static func exhaustiveRegistrationSubsets(
        namePrefix: String,
        stops: [OrganComponent],
        couplers: [OrganComponent],
        accessories: [OrganComponent],
        midiRange: ClosedRange<Int>,
        step: Int,
        recipe: CaptureRecipe,
        setupIDs: [UUID]
    ) -> [(RegistrationState, [RoadmapItem])]? {
        let controls = couplers + accessories
        let switchCount = stops.count + controls.count
        guard stops.isEmpty == false, switchCount <= 10 else { return nil }
        var result: [(RegistrationState, [RoadmapItem])] = []
        let upperMask = 1 << switchCount
        for mask in 1..<upperMask {
            let activeStops = stops.enumerated().compactMap { index, component in
                mask & (1 << index) != 0 ? component : nil
            }
            guard activeStops.isEmpty == false else { continue }
            let activeControls = controls.enumerated().compactMap { index, component in
                mask & (1 << (stops.count + index)) != 0 ? component : nil
            }
            let activeCouplers = activeControls.filter { normalizedKind($0.kind) == "coupler" }
            let activeAccessories = activeControls.filter { normalizedKind($0.kind) == "accessory" }
            let labels = (activeStops + activeCouplers + activeAccessories).map(\.label).joined(separator: " + ")
            result.append(customRegistration(
                name: "\(namePrefix): \(labels)",
                stops: activeStops,
                couplers: activeCouplers,
                accessories: activeAccessories,
                midiRange: midiRange,
                step: step,
                recipe: recipe,
                setupIDs: setupIDs
            ))
        }
        return result
    }

    public static func exhaustiveSubsetCount(stopCount: Int, controlCount: Int) -> Int? {
        let total = stopCount + controlCount
        guard stopCount > 0, total <= 10 else { return nil }
        return ((1 << stopCount) - 1) * (1 << controlCount)
    }

    public static func coverage(_ items: [RoadmapItem]) -> CoverageSummary {
        let required = items.filter { $0.required && $0.state != .exempt && $0.state != .unresolved }
        return CoverageSummary(
            accepted: items.filter { $0.state == .accepted }.count,
            review: items.filter { $0.state == .needsReview || $0.state == .recorded || $0.state == .rejected }.count,
            missing: items.filter { $0.state == .missing || $0.state == .queued }.count,
            exempt: items.filter { $0.state == .exempt }.count,
            unresolved: items.filter { $0.state == .unresolved }.count,
            applicableRequired: required.count,
            acceptedRequired: required.filter { $0.state == .accepted }.count
        )
    }

    public static func nextItem(in items: [RoadmapItem]) -> RoadmapItem? {
        items.first { $0.required && ($0.state == .queued || $0.state == .missing || $0.state == .rejected) }
    }

    /// Applies an accepted field A4 to future roadmap expectations. Existing
    /// takes retain their frozen provenance snapshots.
    public static func applyFieldReferencePitch(_ a4Hz: Double, to project: inout OrgRecProject) {
        guard (350...550).contains(a4Hz) else { return }
        for index in project.roadmap.indices {
            guard let midi = project.roadmap[index].component.midiNote else { continue }
            project.roadmap[index].component.referencePitchHz = a4Hz
            project.roadmap[index].component.expectedFrequencyHz = soundingFrequency(
                keyMidi: midi,
                footHeight: project.roadmap[index].component.footHeight,
                referencePitchHz: a4Hz
            )
            if project.roadmap[index].activationRoutes != nil {
                for routeIndex in project.roadmap[index].activationRoutes!.indices {
                    guard let routeMIDI = project.roadmap[index].activationRoutes![routeIndex].component.midiNote else { continue }
                    project.roadmap[index].activationRoutes![routeIndex].component.referencePitchHz = a4Hz
                    project.roadmap[index].activationRoutes![routeIndex].component.expectedFrequencyHz = soundingFrequency(
                        keyMidi: routeMIDI,
                        footHeight: project.roadmap[index].activationRoutes![routeIndex].component.footHeight,
                        referencePitchHz: a4Hz
                    )
                }
            }
        }
        if project.organComponents != nil {
            for index in project.organComponents!.indices {
                project.organComponents![index].referencePitchHz = a4Hz
                if let midi = project.organComponents![index].midiNote {
                    project.organComponents![index].expectedFrequencyHz = soundingFrequency(
                        keyMidi: midi,
                        footHeight: project.organComponents![index].footHeight,
                        referencePitchHz: a4Hz
                    )
                }
            }
        }
        if project.physicalSoundTargets != nil {
            for targetIndex in project.physicalSoundTargets!.indices {
                for routeIndex in project.physicalSoundTargets![targetIndex].routes.indices {
                    guard let midi = project.physicalSoundTargets![targetIndex].routes[routeIndex].component.midiNote else { continue }
                    project.physicalSoundTargets![targetIndex].routes[routeIndex].component.referencePitchHz = a4Hz
                    project.physicalSoundTargets![targetIndex].routes[routeIndex].component.expectedFrequencyHz = soundingFrequency(
                        keyMidi: midi,
                        footHeight: project.physicalSoundTargets![targetIndex].routes[routeIndex].component.footHeight,
                        referencePitchHz: a4Hz
                    )
                }
            }
        }
        project.roadmapCompilation?.referencePitchHz = a4Hz
        project.roadmapCompilation?.tuningPitchAssumed = false
        project.roadmapCompilation?.warnings.removeAll {
            $0.localizedCaseInsensitiveContains("tuning pitch") || $0.localizedCaseInsensitiveContains("A4 = 440")
        }
    }

    private struct ResolvedPhysicalIdentity {
        var signature: String
        var physicalIDs: [String]
        var evidence: PhysicalIdentityEvidence
        var description: String
    }

    private static func resolvePhysicalIdentity(
        stop: OrganComponent,
        midi: Int,
        position: OrganComponent,
        mapping: PhysicalPipeMapping?,
        sharedRankID: String?,
        assertions: [PipeSharingAssertion]
    ) -> ResolvedPhysicalIdentity {
        if let mapping, mapping.physicalPipeComponentIDs.isEmpty == false {
            let ids = Array(Set(mapping.physicalPipeComponentIDs)).sorted()
            let confirmed = mapping.evidence.isConfirmedSharedIdentity
            return ResolvedPhysicalIdentity(
                signature: confirmed ? "pipes|\(ids.joined(separator: "|"))" : "address|\(stop.id)|\(midi)",
                physicalIDs: ids,
                evidence: mapping.evidence,
                description: "Navigator mapped this console address to \(ids.count) physical pipe component(s)."
            )
        }
        if let canonical = position.locator.canonicalMDVSID {
            return ResolvedPhysicalIdentity(
                signature: "pipes|\(canonical)",
                physicalIDs: [canonical],
                evidence: .canonicalPipe,
                description: "Navigator supplied a canonical physical pipe identifier."
            )
        }
        if let sharedRankID, let offset = soundingSemitoneOffset(for: stop) {
            let rankPosition = midi + offset
            let physicalID = "rank-position|\(sharedRankID)|\(rankPosition)"
            return ResolvedPhysicalIdentity(
                signature: physicalID,
                physicalIDs: [physicalID],
                evidence: .sharedRankPosition,
                description: "Navigator links this stop to rank \(sharedRankID); rank position \(rankPosition) is source-derived."
            )
        }
        if let offset = soundingSemitoneOffset(for: stop) {
            let soundingMIDI = midi + offset
            if let reviewed = reviewedAssertionIdentity(stopID: stop.id, offset: offset, soundingMIDI: soundingMIDI, assertions: assertions) {
                return ResolvedPhysicalIdentity(
                    signature: reviewed.id,
                    physicalIDs: [reviewed.id],
                    evidence: .reviewedAssertion,
                    description: reviewed.description
                )
            }
        }
        return ResolvedPhysicalIdentity(
            signature: "address|\(stop.id)|\(midi)",
            physicalIDs: [],
            evidence: .uniqueFunctionalAddress,
            description: "No source-backed physical equivalence was available; this address remains independent."
        )
    }

    private static func reviewedAssertionIdentity(
        stopID: String,
        offset: Int,
        soundingMIDI: Int,
        assertions: [PipeSharingAssertion]
    ) -> (id: String, description: String)? {
        let applicable = assertions.filter {
            ($0.soundingMIDILow...$0.soundingMIDIHigh).contains(soundingMIDI)
        }
        guard applicable.contains(where: { assertion in
            assertion.stops.contains { $0.stopComponentID == stopID && $0.soundingSemitoneOffset == offset }
        }) else { return nil }
        var group: Set<String> = [stopID]
        var changed = true
        while changed {
            changed = false
            for assertion in applicable {
                let ids = Set(assertion.stops.map(\.stopComponentID))
                guard group.isDisjoint(with: ids) == false else { continue }
                let previous = group.count
                group.formUnion(ids)
                if group.count != previous { changed = true }
            }
        }
        guard group.count > 1 else { return nil }
        let groupSignature = group.sorted().joined(separator: "|") + "|" + (applicable.first?.snapshotSHA256 ?? "")
        let id = "reviewed-position|\(Data(groupSignature.utf8).sha256Hex)|\(soundingMIDI)"
        let reviewers = Set(applicable.filter {
            group.isDisjoint(with: Set($0.stops.map(\.stopComponentID))) == false
        }.map(\.author)).sorted().joined(separator: ", ")
        return (id, "Snapshot-bound shared-rank assertion reviewed by \(reviewers).")
    }

    private static func sharedRankIDs(
        stops: [OrganComponent],
        relationships: [OrganComponentRelationship]
    ) -> [String: String] {
        let stopIDs = Set(stops.map(\.id))
        var result: [String: String] = [:]
        var rankTargetsByStop: [String: Set<String>] = [:]
        var adjacency: [String: Set<String>] = [:]
        for relationship in relationships {
            let kind = normalizedRelationshipKind(relationship.kind)
            guard kind.contains("rank") || kind.contains("borrow") || kind.contains("extension") || kind.contains("duplex") || kind.contains("share") else { continue }
            let sourceIsStop = stopIDs.contains(relationship.sourceComponentID)
            let targetIsStop = stopIDs.contains(relationship.targetComponentID)
            if sourceIsStop && targetIsStop {
                adjacency[relationship.sourceComponentID, default: []].insert(relationship.targetComponentID)
                adjacency[relationship.targetComponentID, default: []].insert(relationship.sourceComponentID)
            } else if sourceIsStop {
                rankTargetsByStop[relationship.sourceComponentID, default: []].insert(relationship.targetComponentID)
            } else if targetIsStop {
                rankTargetsByStop[relationship.targetComponentID, default: []].insert(relationship.sourceComponentID)
            }
        }
        for (stopID, rankIDs) in rankTargetsByStop where rankIDs.count == 1 {
            result[stopID] = rankIDs.first
        }
        var visited = Set<String>()
        for start in adjacency.keys.sorted() where visited.contains(start) == false {
            var stack = [start]
            var group: [String] = []
            while let current = stack.popLast() {
                guard visited.insert(current).inserted else { continue }
                group.append(current)
                stack.append(contentsOf: adjacency[current] ?? [])
            }
            guard group.count > 1 else { continue }
            let groupID = "shared-rank-relation:\(Data(group.sorted().joined(separator: "|").utf8).sha256Hex)"
            for stopID in group { result[stopID] = groupID }
        }
        return result
    }

    private static func normalizedRelationshipKind(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
    }

    private static func addressKey(stopID: String, midi: Int) -> String {
        "\(stopID)|\(midi)"
    }

    private static func evidencePriority(_ lhs: PhysicalIdentityEvidence, _ rhs: PhysicalIdentityEvidence) -> Bool {
        func value(_ evidence: PhysicalIdentityEvidence) -> Int {
            switch evidence {
            case .canonicalPipe: 0
            case .explicitSharedPipe: 1
            case .sharedRankPosition: 2
            case .reviewedAssertion: 3
            case .uniqueFunctionalAddress: 4
            }
        }
        return value(lhs) < value(rhs)
    }

    private static func preferredRoute(_ lhs: PhysicalActivationRoute, _ rhs: PhysicalActivationRoute) -> Bool {
        let leftOffset = abs(soundingSemitoneOffset(for: lhs.component) ?? 999)
        let rightOffset = abs(soundingSemitoneOffset(for: rhs.component) ?? 999)
        if leftOffset != rightOffset { return leftOffset < rightOffset }
        let division = lhs.component.division.localizedStandardCompare(rhs.component.division)
        if division != .orderedSame { return division == .orderedAscending }
        let label = lhs.component.label.localizedStandardCompare(rhs.component.label)
        if label != .orderedSame { return label == .orderedAscending }
        return (lhs.component.midiNote ?? -1) < (rhs.component.midiNote ?? -1)
    }

    private static func targetItems(
        target: PhysicalSoundTarget,
        recipe: CaptureRecipe,
        setupIDs: [UUID]
    ) -> [RoadmapItem] {
        guard let primary = target.routes.first(where: { $0.id == target.primaryRouteID }) ?? target.routes.first else { return [] }
        let aliases = target.routes.filter { $0.id != primary.id }
        let aliasText = aliases.isEmpty ? "" : " Shared with \(aliases.map { "\($0.component.label) \($0.component.noteName ?? "")" }.joined(separator: ", "))."
        let coverage: RoadmapCoverageKind = primary.id.hasPrefix("explicit|") ? .explicitPipe : .isolatedStop
        return recipe.techniques.map { technique in
            RoadmapItem(
                component: primary.component,
                technique: technique,
                recipeID: recipe.id,
                setupID: setupID(for: technique, in: setupIDs),
                registrationID: primary.registrationID,
                coverageKind: coverage,
                instructions: "Activate only \(primary.component.label) in \(primary.component.division); play \(primary.component.noteName ?? "the documented position").\(aliasText)",
                physicalSoundTargetID: target.id,
                primaryActivationRouteID: primary.id,
                activationRoutes: target.routes
            )
        }
    }

    private static func suspectedOverlapCandidates(
        stops: [OrganComponent],
        sharedRankByStop: [String: String],
        assertions: [PipeSharingAssertion]
    ) -> [PhysicalOverlapCandidate] {
        var result: [PhysicalOverlapCandidate] = []
        for firstIndex in stops.indices {
            for secondIndex in stops.indices where secondIndex > firstIndex {
                let first = stops[firstIndex]
                let second = stops[secondIndex]
                guard first.division.localizedCaseInsensitiveCompare(second.division) == .orderedSame,
                      normalizedStopFamily(first.label) == normalizedStopFamily(second.label),
                      normalizedStopFamily(first.label).isEmpty == false,
                      let firstOffset = soundingSemitoneOffset(for: first),
                      let secondOffset = soundingSemitoneOffset(for: second),
                      firstOffset != secondOffset else { continue }
                if let firstRank = sharedRankByStop[first.id], firstRank == sharedRankByStop[second.id] { continue }
                let firstRange = playableRange(for: first)
                let secondRange = playableRange(for: second)
                let low = max(firstRange.lowerBound + firstOffset, secondRange.lowerBound + secondOffset)
                let high = min(firstRange.upperBound + firstOffset, secondRange.upperBound + secondOffset)
                guard low <= high else { continue }
                let reviewed = assertions.filter { assertion in
                    let ids = Set(assertion.stops.map(\.stopComponentID))
                    return assertion.snapshotSHA256 == first.locator.snapshotSHA256
                        && ids.contains(first.id) && ids.contains(second.id)
                }.compactMap { assertion -> ClosedRange<Int>? in
                    let reviewedLow = max(low, assertion.soundingMIDILow)
                    let reviewedHigh = min(high, assertion.soundingMIDIHigh)
                    return reviewedLow <= reviewedHigh ? reviewedLow...reviewedHigh : nil
                }
                for unresolved in subtract(reviewed: reviewed, from: low...high) {
                    let signature = "\(first.id)|\(second.id)|\(unresolved.lowerBound)|\(unresolved.upperBound)"
                    result.append(PhysicalOverlapCandidate(
                        id: "overlap-candidate:\(Data(signature.utf8).sha256Hex)",
                        firstStopComponentID: first.id,
                        secondStopComponentID: second.id,
                        firstSoundingSemitoneOffset: firstOffset,
                        secondSoundingSemitoneOffset: secondOffset,
                        soundingMIDILow: unresolved.lowerBound,
                        soundingMIDIHigh: unresolved.upperBound,
                        overlappingAddressCount: unresolved.upperBound - unresolved.lowerBound + 1,
                        reason: "The stops share a normalized family name and have octave-related pitches, but Navigator does not prove that they use the same rank."
                    ))
                }
            }
        }
        return result
    }

    private static func subtract(reviewed: [ClosedRange<Int>], from full: ClosedRange<Int>) -> [ClosedRange<Int>] {
        var remaining = [full]
        for covered in reviewed.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            remaining = remaining.flatMap { candidate -> [ClosedRange<Int>] in
                if covered.upperBound < candidate.lowerBound || covered.lowerBound > candidate.upperBound { return [candidate] }
                var pieces: [ClosedRange<Int>] = []
                if covered.lowerBound > candidate.lowerBound {
                    pieces.append(candidate.lowerBound...(covered.lowerBound - 1))
                }
                if covered.upperBound < candidate.upperBound {
                    pieces.append((covered.upperBound + 1)...candidate.upperBound)
                }
                return pieces
            }
        }
        return remaining
    }

    private static func playableRange(for stop: OrganComponent) -> ClosedRange<Int> {
        if let low = stop.playableMIDILow, let high = stop.playableMIDIHigh, low <= high {
            return max(0, low)...min(127, high)
        }
        return stop.division.localizedCaseInsensitiveContains("pedal") ? 36...67 : 36...96
    }

    private static func normalizedStopFamily(_ raw: String) -> String {
        var value = raw.lowercased()
            .replacingOccurrences(of: "prinzipal", with: "principal")
            .replacingOccurrences(of: "principaal", with: "principal")
        value = value.replacingOccurrences(of: "[0-9′'’\"./\\-]+", with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: "\\b(ft|feet|foot)\\b", with: " ", options: .regularExpression)
        return value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    private static func soundingSemitoneOffset(for component: OrganComponent) -> Int? {
        for key in ["soundingSemitoneOffset", "sounding_semitone_offset", "transpositionSemitones", "transposition_semitones"] {
            if let raw = component.sourceDetails?[key], let value = Int(raw) { return value }
        }
        guard let raw = component.footHeight?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.isEmpty == false,
              let footage = try? OrganFootage(parsing: raw) else { return nil }
        return footage.nearestSemitoneOffset()
    }

    private static func items(
        component: OrganComponent,
        recipe: CaptureRecipe,
        setupIDs: [UUID],
        registrationID: UUID?,
        coverageKind: RoadmapCoverageKind,
        instructions: String
    ) -> [RoadmapItem] {
        recipe.techniques.map { technique in
            RoadmapItem(
                component: component,
                technique: technique,
                recipeID: recipe.id,
                setupID: setupID(for: technique, in: setupIDs),
                registrationID: registrationID,
                coverageKind: coverageKind,
                instructions: instructions
            )
        }
    }

    public static func soundingTargetItems(
        component: OrganComponent,
        definition: SoundingTargetDefinition,
        recipe: CaptureRecipe,
        setupIDs: [UUID],
        registrationID: UUID
    ) -> [RoadmapItem] {
        let coverage: RoadmapCoverageKind = switch definition.family {
        case .pipeSpeech: .isolatedStop
        case .tonalPercussion: .tonalPercussion
        case .atonalPercussion: .atonalPercussion
        case .sustainedEffect: .sustainedEffect
        case .oneShotEffect: .oneShotEffect
        case .repeatingEffect: .repeatingEffect
        case .sequencedEffect: .sequencedEffect
        case .compositeEffect: .compositeEffect
        case .otherSoundingElement: .otherSoundingElement
        }
        let targets: [OrganComponent]
        if component.midiNote == nil,
           definition.triggerMode == .keyboardKey,
           let low = component.playableMIDILow,
           let high = component.playableMIDIHigh,
           low <= high {
            targets = stride(from: max(0, low), through: min(127, high), by: max(1, recipe.chromaticStep)).map { midi in
                var result = component
                result.id = "sounding-target:\(component.id):\(midi)"
                result.parentComponentID = component.id
                result.midiNote = midi
                result.noteName = noteName(midi)
                if definition.family == .tonalPercussion {
                    result.expectedFrequencyHz = soundingFrequency(keyMidi: midi, footHeight: component.footHeight, referencePitchHz: component.referencePitchHz)
                } else {
                    result.expectedFrequencyHz = nil
                }
                return result
            }
        } else {
            targets = [component]
        }
        let repetitions = definition.minimumAcceptedTakeCount
        return targets.flatMap { target in
            recipe.techniques.map { technique in
                let action: String
                switch definition.temporalBehavior {
                case .discrete: action = "Trigger once, allow the complete natural decay, and leave room tone before repeating."
                case .sustained: action = "Activate, hold for the planned duration, then deactivate and capture the complete release."
                case .repeating: action = "Capture startup, stable repeating operation, stop, and the complete release."
                case .sequenced: action = "Perform the documented sequence without changing its ordering or timing configuration."
                case .composite: action = "Trigger the documented component chain and preserve the order and overlap of every constituent."
                }
                return RoadmapItem(
                    component: target,
                    technique: technique,
                    recipeID: recipe.id,
                    setupID: setupID(for: technique, in: setupIDs),
                    registrationID: registrationID,
                    coverageKind: coverage,
                    instructions: "Intended \(definition.family.displayName.lowercased()) target. \(action) Capture at least \(repetitions) accepted take\(repetitions == 1 ? "" : "s") to retain natural variation.",
                    soundingTargetDefinition: definition,
                    effectAnalysisProtocol: [.atonalPercussion, .sustainedEffect, .oneShotEffect, .repeatingEffect, .sequencedEffect, .compositeEffect, .otherSoundingElement].contains(definition.family)
                        ? NonPitchedEffectAnalysisProtocol(
                            sourceComponentID: target.parentComponentID ?? target.id,
                            temporalBehavior: definition.temporalBehavior,
                            notes: "P2 effect-specific analytics are required; tonal pipe analytics are intentionally not substituted."
                        ) : nil
                )
            }
        }
    }

    /// Conservative, source-aware classification. An `accessory` is promoted
    /// only when the source explicitly marks it as sounding or its label is an
    /// established theatre-organ sound/effect term. Ordinary stops, couplers,
    /// shutters, blowers, and console mechanisms remain in their existing lanes.
    public static func soundingTargetDefinition(for component: OrganComponent) -> SoundingTargetDefinition? {
        if let explicit = component.soundingTargetDefinition { return explicit }
        let kind = normalizedKind(component.kind)
        let details = component.sourceDetails ?? [:]
        let searchable = ([component.label, component.division] + details.values).joined(separator: " ").lowercased()
        let explicitSounding = ["isSoundingTarget", "is_sounding_target", "soundingTarget", "sounding_target"]
            .contains { key in
                guard let value = details[key]?.lowercased() else { return false }
                return ["true", "1", "yes", "intended"].contains(value)
            }
        let tonalTerms = ["xylophone", "glockenspiel", "chimes", "harp", "marimba", "celesta", "tuned percussion", "orchestre bells", "orchestra bells"]
        let atonalTerms = ["cymbal", "drum", "tambourine", "castanet", "triangle", "wood block", "tom tom", "snare", "bass drum", "gong", "crash"]
        let sustainedTerms = ["siren", "boat whistle", "klaxon", "horn", "whistle", "steam", "surf", "wind effect"]
        let oneShotTerms = ["door bell", "doorbell", "telephone", "bird", "shot", "thunder", "horses", "auto horn", "gong"]
        let repeatingTerms = ["roll", "repeating", "motor", "trill", "tremolo effect"]
        let family: SoundingTargetFamily?
        switch kind {
        case "tonal_percussion", "tuned_percussion": family = .tonalPercussion
        case "atonal_percussion", "untuned_percussion": family = .atonalPercussion
        case "percussion": family = containsAny(searchable, tonalTerms) ? .tonalPercussion : .atonalPercussion
        case "sustained_effect": family = .sustainedEffect
        case "one_shot_effect": family = .oneShotEffect
        case "repeating_effect": family = .repeatingEffect
        case "sequenced_effect": family = .sequencedEffect
        case "composite_effect", "chained_effect": family = .compositeEffect
        case "sound_effect", "effect", "sounding_element":
            if containsAny(searchable, tonalTerms) { family = .tonalPercussion }
            else if containsAny(searchable, atonalTerms) { family = .atonalPercussion }
            else if containsAny(searchable, repeatingTerms) { family = .repeatingEffect }
            else if containsAny(searchable, sustainedTerms) { family = .sustainedEffect }
            else if containsAny(searchable, oneShotTerms) { family = .oneShotEffect }
            else { family = .otherSoundingElement }
        case "accessory" where explicitSounding || containsAny(searchable, tonalTerms + atonalTerms + sustainedTerms + oneShotTerms):
            if containsAny(searchable, tonalTerms) { family = .tonalPercussion }
            else if containsAny(searchable, atonalTerms) { family = .atonalPercussion }
            else if containsAny(searchable, sustainedTerms) { family = .sustainedEffect }
            else { family = .oneShotEffect }
        default: family = nil
        }
        guard let family else { return nil }
        let behavior: SoundingTargetTemporalBehavior = switch family {
        case .sustainedEffect: .sustained
        case .repeatingEffect: .repeating
        case .sequencedEffect: .sequenced
        case .compositeEffect: .composite
        default: .discrete
        }
        let trigger: SoundingTargetTriggerMode
        if component.playableMIDILow != nil || component.midiNote != nil { trigger = .keyboardKey }
        else if family == .compositeEffect { trigger = .composite }
        else if searchable.contains("pedal") { trigger = .pedal }
        else if kind == "accessory" { trigger = .stopTab }
        else { trigger = .manual }
        let members = (details["memberComponentIDs"] ?? details["member_component_ids"] ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let repetitions: Int = switch family {
        case .tonalPercussion, .sustainedEffect: 2
        default: 3
        }
        return SoundingTargetDefinition(
            family: family,
            temporalBehavior: behavior,
            triggerMode: trigger,
            memberComponentIDs: members,
            minimumAcceptedTakeCount: Int(details["minimumAcceptedTakeCount"] ?? "") ?? repetitions,
            plannedDurationSeconds: Double(details["plannedDurationSeconds"] ?? ""),
            captureRelease: true,
            notes: details["captureNotes"] ?? ""
        )
    }

    public static func requiredCaptureState(
        for item: RoadmapItem,
        registration: RegistrationState?,
        components: [OrganComponent]
    ) -> CaptureStateSnapshot {
        let activeStops = Set(registration?.activatedStops.map(\.id) ?? [])
        let activeCouplers = Set(registration?.activatedCouplers.map(\.id) ?? [])
        let activeAccessories = Set(registration?.activatedAccessories.map(\.id) ?? [])
        var assignments: [CaptureStateAssignment] = components.compactMap { component in
            switch normalizedKind(component.kind) {
            case "stop": return .enabled(component: component, dimension: .stop, enabled: activeStops.contains(component.locator.id))
            case "coupler": return .enabled(component: component, dimension: .coupler, enabled: activeCouplers.contains(component.locator.id))
            case "accessory": return .enabled(component: component, dimension: .accessory, enabled: activeAccessories.contains(component.locator.id))
            default: return nil
            }
        }
        let representedLocatorIDs = Set(assignments.map(\.subjectComponentID))
        for locator in registration?.activatedStops ?? [] where representedLocatorIDs.contains(locator.id) == false {
            assignments.append(CaptureStateAssignment(
                subjectComponentID: locator.id,
                subjectLabel: locator.label,
                dimension: .stop,
                valueKind: .boolean,
                booleanValue: true,
                evidence: "roadmap-registration-unmatched-locator"
            ))
        }
        for locator in registration?.activatedCouplers ?? [] where representedLocatorIDs.contains(locator.id) == false {
            assignments.append(CaptureStateAssignment(
                subjectComponentID: locator.id,
                subjectLabel: locator.label,
                dimension: .coupler,
                valueKind: .boolean,
                booleanValue: true,
                evidence: "roadmap-registration-unmatched-locator"
            ))
        }
        for locator in registration?.activatedAccessories ?? [] where representedLocatorIDs.contains(locator.id) == false {
            assignments.append(CaptureStateAssignment(
                subjectComponentID: locator.id,
                subjectLabel: locator.label,
                dimension: .accessory,
                valueKind: .boolean,
                booleanValue: true,
                evidence: "roadmap-registration-unmatched-locator"
            ))
        }
        if let definition = item.soundingTargetDefinition {
            assignments.append(CaptureStateAssignment(
                subjectComponentID: item.component.parentComponentID ?? item.component.id,
                subjectLabel: item.component.label,
                dimension: .soundingTarget,
                valueKind: .text,
                textValue: "armed:\(definition.triggerMode.rawValue)",
                evidence: "roadmap-sounding-target"
            ))
        }
        if let noise = item.instrumentNoiseProtocol {
            assignments.append(CaptureStateAssignment(
                subjectComponentID: noise.sourceComponentID,
                subjectLabel: noise.name,
                dimension: noise.kind == .swellerJalousie ? .shutter : .custom,
                valueKind: .text,
                textValue: [noise.configuration.label, noise.configuration.fromPosition, noise.configuration.toPosition].compactMap { $0 }.joined(separator: " → "),
                evidence: "instrument-noise-protocol"
            ))
        }
        if let complex = item.complexCaptureProtocol {
            switch complex.kind {
            case .physicalActuatorResponse:
                if let variant = complex.physicalActuation {
                    assignments.append(CaptureStateAssignment(
                        subjectComponentID: complex.sourceComponentID,
                        subjectLabel: complex.name,
                        dimension: .controller,
                        valueKind: .text,
                        textValue: "physical-actuation:\(variant.label):\(variant.summary)",
                        evidence: "complex-capture-physical-actuation"
                    ))
                }
            case .declarativeProcess:
                if let process = complex.processModel {
                    assignments.append(CaptureStateAssignment(
                        subjectComponentID: complex.sourceComponentID,
                        subjectLabel: complex.name,
                        dimension: .routing,
                        valueKind: .text,
                        textValue: "process-armed:\(process.id.uuidString.lowercased())",
                        evidence: "complex-capture-process"
                    ))
                }
            case .discreteShutterMapping:
                let label = complex.shutterTopology?.states.first(where: { $0.id == complex.targetShutterStateID })?.label ?? complex.targetShutterStateID ?? "unresolved"
                assignments.append(CaptureStateAssignment(
                    subjectComponentID: complex.sourceComponentID,
                    subjectLabel: complex.name,
                    dimension: .shutter,
                    valueKind: .discrete,
                    textValue: label,
                    evidence: "discrete-pedal-shutter-map"
                ))
            case .tremulantResponse:
                if let tremulant = complex.tremulant {
                    let initiallyOn = [.steadyWithTremulant, .deactivationTransition].contains(tremulant.condition)
                    assignments.removeAll { $0.subjectComponentID == tremulant.tremulantComponentID && ($0.dimension == .accessory || $0.dimension == .tremulant) }
                    assignments.append(CaptureStateAssignment(
                        subjectComponentID: tremulant.tremulantComponentID,
                        subjectLabel: complex.name,
                        dimension: .tremulant,
                        valueKind: .boolean,
                        booleanValue: initiallyOn,
                        evidence: "paired-tremulant-protocol-initial-state"
                    ))
                }
            case .operationalBaseline:
                assignments.append(contentsOf: complex.operationalBaseline?.requiredStateAssignments ?? [])
            }
        }
        return CaptureStateSnapshot(
            name: registration?.name ?? item.component.label,
            source: .roadmapCompiler,
            assignments: assignments,
            notes: registration?.notes ?? item.instructions ?? ""
        )
    }

    private static func actionUsesVelocity(_ action: InstrumentNoiseAction) -> Bool {
        switch action {
        case .activation, .release, .deactivation, .opening, .closing, .pedalPress, .pedalRelease, .movement:
            true
        case .startup, .steadyOperation, .shutdown, .idleBaseline:
            false
        }
    }

    private static func suggestedDuration(
        for kind: InstrumentNoiseKind,
        action: InstrumentNoiseAction,
        preset: InstrumentNoiseVelocityPreset
    ) -> Double? {
        if kind == .swellerJalousie || action == .opening || action == .closing || action == .movement {
            switch preset {
            case .slow: return 5
            case .normal: return 2.5
            case .fast: return 0.8
            }
        }
        switch preset {
        case .slow: return 0.8
        case .normal: return 0.35
        case .fast: return 0.12
        }
    }

    private static func classification(
        for kind: InstrumentNoiseKind,
        action: InstrumentNoiseAction
    ) -> (scope: AcousticSourceScope, mechanisms: [AcousticMechanism], temporal: AcousticTemporalBehavior, phase: AcousticOperatingPhase) {
        let scope: AcousticSourceScope = switch kind {
        case .blower, .windSystem: .instrumentAuxiliary
        default: .instrument
        }
        let mechanisms: [AcousticMechanism] = switch kind {
        case .keyAction, .stopAction, .couplerAction, .accessoryAction, .pedalAction:
            [.mechanical, .structuralContact]
        case .blower:
            [.electrical, .mechanical, .aerodynamicFlow]
        case .windSystem:
            [.pneumatic, .aerodynamicFlow, .mechanical]
        case .swellerJalousie:
            [.mechanical, .aerodynamicFlow, .structuralContact]
        case .tremulant:
            [.mechanical, .pneumatic, .aerodynamicFlow]
        case .other:
            [.mechanical]
        }
        let temporal: AcousticTemporalBehavior = switch action {
        case .activation, .pedalPress: .attackTransient
        case .release, .deactivation, .pedalRelease: .releaseTransient
        case .startup: .startup
        case .steadyOperation, .idleBaseline: .continuous
        case .shutdown: .shutdown
        case .opening, .closing, .movement: .ramp
        }
        let phase: AcousticOperatingPhase = switch action {
        case .activation, .pedalPress: .activation
        case .release, .deactivation, .pedalRelease: .deactivation
        case .startup: .startup
        case .steadyOperation: .steadyOperation
        case .shutdown: .shutdown
        case .opening, .closing, .movement: .transition
        case .idleBaseline: .idleBaseline
        }
        return (scope, mechanisms, temporal, phase)
    }

    private static func instrumentNoiseInstructions(
        component: OrganComponent,
        kind: InstrumentNoiseKind,
        action: InstrumentNoiseAction,
        velocity: InstrumentControlVelocity?,
        configuration: InstrumentNoiseConfiguration,
        actuationProfile: ActuationProfile?,
        repetitions: Int
    ) -> String {
        var clauses = [
            "Isolate \(component.label) and record its \(action.displayName.lowercased()) noise without a speaking pipe unless the mechanism requires it.",
        ]
        if let velocity {
            var velocityText = "Use \(velocity.label.lowercased()) actuation"
            if let midi = velocity.midiVelocity { velocityText += " (reference MIDI velocity \(midi))" }
            if let duration = velocity.targetDurationSeconds {
                velocityText += ", targeting \(duration.formatted(.number.precision(.fractionLength(0...2)))) s"
            }
            clauses.append(velocityText + ".")
        }
        if configuration.label != "Standard configuration" || configuration.fromPosition != nil || configuration.toPosition != nil {
            var configurationText = "Configuration: \(configuration.label)"
            if let from = configuration.fromPosition, let to = configuration.toPosition {
                configurationText += ", \(from) → \(to)"
            }
            if configuration.pedalActuationIncluded { configurationText += "; include pedal/linkage actuation" }
            clauses.append(configurationText + ".")
        }
        if let actuationProfile {
            let curve = actuationProfile.commandedCurve
            clauses.append(
                "Commanded \(actuationProfile.quantityLabel.lowercased()) curve: \(curve.kind.displayName.lowercased()), "
                + "\(curve.points.count) control points in \(actuationProfile.unit), evidence \(curve.evidenceSource.displayName.lowercased())."
            )
        }
        clauses.append("Retain at least \(max(1, repetitions)) accepted take\(repetitions == 1 ? "" : "s") to document variability.")
        clauses.append("Capture room tone, mark action begin/end, and keep the decay after the mechanism stops.")
        return clauses.joined(separator: " ")
    }

    private static func actuationProfileForAction(
        template: ActuationProfile?,
        kind: InstrumentNoiseKind,
        action: InstrumentNoiseAction,
        velocity: InstrumentControlVelocity?
    ) -> ActuationProfile? {
        // Static operating-state recordings have no activating gesture. Do
        // not attach the planner's forward trajectory to them accidentally.
        guard action != .steadyOperation && action != .idleBaseline else { return nil }
        var profile = template ?? defaultActuationProfile(kind: kind, action: action, velocity: velocity)
        let duration = velocity?.targetDurationSeconds ?? profile.commandedCurve.durationSeconds
        profile.commandedCurve.durationSeconds = duration
        let shouldMirror = [.release, .deactivation, .closing, .pedalRelease, .shutdown].contains(action)
            && [.position, .displacement, .switchState].contains(profile.quantity)
        if shouldMirror,
           let minimum = profile.minimumValue,
           let maximum = profile.maximumValue {
            profile.commandedCurve.points = profile.commandedCurve.points.map {
                ActuationCurvePoint(time: $0.time, value: minimum + maximum - $0.value)
            }
        }
        return profile
    }

    private static func defaultActuationProfile(
        kind: InstrumentNoiseKind,
        action: InstrumentNoiseAction,
        velocity: InstrumentControlVelocity?
    ) -> ActuationProfile {
        let quantity: ActuationQuantity = switch kind {
        case .keyAction, .stopAction, .couplerAction, .accessoryAction, .swellerJalousie, .pedalAction:
            .position
        case .blower, .windSystem, .tremulant, .other:
            .actionProgress
        }
        let shape: ActuationCurveKind = switch kind {
        case .stopAction, .couplerAction, .accessoryAction: .stepped
        case .keyAction, .pedalAction, .swellerJalousie: .smoothSCurve
        case .blower, .windSystem, .tremulant, .other: .linear
        }
        return ActuationProfile(
            quantity: quantity,
            unit: "normalized 0–1",
            minimumValue: 0,
            maximumValue: 1,
            commandedCurve: ActuationCurve.preset(
                kind: shape,
                startValue: 0,
                endValue: 1,
                durationSeconds: velocity?.targetDurationSeconds,
                evidenceSource: .operatorPlanned
            ),
            notes: "Default normalized command profile; replace with a physical quantity or measured trace when available."
        )
    }

    private static func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0) }
    }

    private static func setupID(for technique: CaptureTechnique, in setupIDs: [UUID]) -> UUID? {
        switch technique {
        case .closePair: setupIDs.first
        case .naveORTF: setupIDs.dropFirst().first ?? setupIDs.first
        case .rearOmni: setupIDs.dropFirst(2).first ?? setupIDs.last
        case .releaseTail: setupIDs.dropFirst().first ?? setupIDs.first
        }
    }

    private static func functionalPosition(for stop: OrganComponent, midi: Int) -> OrganComponent {
        let reference = "pipepos:orgrec:v1:\(stop.id):\(midi)"
        let locator = ComponentLocator(
            id: reference,
            organMDVSID: stop.locator.organMDVSID,
            pipePositionReference: reference,
            sourceRecordID: stop.locator.sourceRecordID,
            sourcePath: "\(stop.locator.sourcePath ?? "specifications.stops")/notes/\(midi)",
            snapshotSHA256: stop.locator.snapshotSHA256,
            kind: "pipe_position",
            label: "\(stop.label) \(noteName(midi))",
            trust: .functionalPosition
        )
        return OrganComponent(
            id: reference,
            kind: "pipe_position",
            label: stop.label,
            division: stop.division,
            footHeight: stop.footHeight,
            noteName: noteName(midi),
            midiNote: midi,
            expectedFrequencyHz: soundingFrequency(
                keyMidi: midi,
                footHeight: stop.footHeight,
                referencePitchHz: stop.referencePitchHz
            ),
            locator: locator,
            parentComponentID: stop.id,
            playableMIDILow: stop.playableMIDILow,
            playableMIDIHigh: stop.playableMIDIHigh,
            sourceDetails: stop.sourceDetails,
            referencePitchHz: stop.referencePitchHz,
            temperament: stop.temperament
        )
    }

    private static func representativeNotes(for stop: OrganComponent) -> [Int] {
        let low = stop.playableMIDILow ?? (stop.division.localizedCaseInsensitiveContains("pedal") ? 36 : 36)
        let high = stop.playableMIDIHigh ?? (stop.division.localizedCaseInsensitiveContains("pedal") ? 67 : 96)
        return Array(Set([low, low + (high - low) / 2, high])).sorted()
    }

    private static func controlBaseStop(_ control: OrganComponent, stops: [OrganComponent]) -> OrganComponent? {
        let details = control.sourceDetails ?? [:]
        let targets = [details["source"], details["destination"], details["division"], details["manual"]]
            .compactMap { $0?.lowercased() }
        return stops.first { stop in targets.contains { stop.division.lowercased().contains($0) || $0.contains(stop.division.lowercased()) } }
            ?? stops.first
    }

    private static func normalizedKind(_ kind: String) -> String {
        kind.replacingOccurrences(of: "-", with: "_").lowercased()
            .replacingOccurrences(of: "pipeposition", with: "pipe_position")
    }

    private static func atomicKey(_ component: OrganComponent) -> String? {
        guard let midi = component.midiNote else { return nil }
        return atomicKey(label: component.label, division: component.division, midi: midi)
    }

    private static func atomicKey(label: String, division: String, midi: Int) -> String {
        "\(division.lowercased())|\(label.lowercased())|\(midi)"
    }

    private static func noteName(_ midi: Int) -> String {
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        return "\(names[(midi % 12 + 12) % 12])\(midi / 12 - 1)"
    }

    public static func soundingFrequency(keyMidi: Int, footHeight: String?, referencePitchHz: Double?) -> Double? {
        OrganFootage.nominalFrequency(
            keyMidi: keyMidi,
            footHeight: footHeight,
            referencePitchHz: referencePitchHz
        )
    }

    private static func decimalPowerSetCount(_ exponent: Int) -> String {
        guard exponent > 0 else { return "0" }
        var digits = [1]
        for _ in 0..<exponent {
            var carry = 0
            for index in digits.indices {
                let value = digits[index] * 2 + carry
                digits[index] = value % 10
                carry = value / 10
            }
            if carry > 0 { digits.append(carry) }
        }
        var index = 0
        while index < digits.count {
            if digits[index] > 0 { digits[index] -= 1; break }
            digits[index] = 9
            index += 1
        }
        return digits.reversed().map(String.init).joined()
    }

    public static func demoComponents(
        organMDVSID: String,
        snapshotSHA256: String,
        noteRange: ClosedRange<Int> = 36...47
    ) -> [OrganComponent] {
        let noteNames = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        let divisions = [
            ("Hauptwerk", ["Principal 8′", "Octave 4′", "Mixture IV"]),
            ("Rückpositiv", ["Gedackt 8′", "Principal 4′"]),
            ("Pedal", ["Subbass 16′", "Octavbass 8′"]),
        ]
        var result: [OrganComponent] = []
        for (divisionIndex, division) in divisions.enumerated() {
            for (stopIndex, stop) in division.1.enumerated() {
                for midi in noteRange where (midi - noteRange.lowerBound) % 2 == 0 {
                    let note = "\(noteNames[midi % 12])\(midi / 12 - 1)"
                    let stable = "\(divisionIndex)-\(stopIndex)-\(midi)"
                    let reference = "pipepos:v2:demo-\(stable)"
                    let locator = ComponentLocator(
                        id: reference,
                        organMDVSID: organMDVSID,
                        pipePositionReference: reference,
                        sourceRecordID: "demo:organ",
                        sourcePath: "specifications.divisions[\(divisionIndex)].stops[\(stopIndex)].notes[\(midi)]",
                        snapshotSHA256: snapshotSHA256,
                        kind: "pipe_position",
                        label: "\(stop) \(note)",
                        trust: .functionalPosition
                    )
                    result.append(OrganComponent(
                        id: stable,
                        kind: "pipe_position",
                        label: stop,
                        division: division.0,
                        footHeight: stop.split(separator: " ").last.map(String.init),
                        noteName: note,
                        midiNote: midi,
                        expectedFrequencyHz: OrganFootage.nominalFrequency(
                            keyMidi: midi,
                            footHeight: stop.split(separator: " ").last.map(String.init),
                            referencePitchHz: 440
                        ),
                        locator: locator
                    ))
                }
            }
        }
        return result
    }
}

public enum DemoProjectFactory {
    public static func make() -> OrgRecProject {
        let snapshotHash = Data("orgrec-demo-modavis-release-1.1".utf8).sha256Hex
        let snapshot = MODAVISSnapshot(
            endpoint: "bundle://demo-roadmap-v1.json",
            payloadSHA256: snapshotHash
        )
        let recipe = CaptureRecipe()
        let interface = DeviceInstance(
            kind: .audioInterface,
            manufacturer: "Reference",
            model: "8-channel Core Audio Interface",
            details: ["connectivity": "USB-C / Thunderbolt", "clock": "Internal", "bitDepth": "24"]
        )
        let micLeft = DeviceInstance(
            kind: .microphone,
            manufacturer: "Reference",
            model: "Cardioid condenser A-L",
            serialNumber: "LOCAL-A-L",
            details: ["polarPattern": "Cardioid", "transducer": "Condenser"]
        )
        let micRight = DeviceInstance(
            kind: .microphone,
            manufacturer: "Reference",
            model: "Cardioid condenser A-R",
            serialNumber: "LOCAL-A-R",
            details: ["polarPattern": "Cardioid", "transducer": "Condenser"]
        )
        let micOmni = DeviceInstance(
            kind: .microphone,
            manufacturer: "Reference",
            model: "Omnidirectional condenser B",
            serialNumber: "LOCAL-B",
            details: ["polarPattern": "Omnidirectional", "transducer": "Condenser"]
        )
        let close = MicrophoneSetup(
            name: "Close pair",
            arrayGeometry: "A/B 60 cm",
            interfaceDeviceID: interface.id,
            placements: [
                MicrophonePlacement(microphoneID: micLeft.id, channelNumber: 1, role: "Close left", xMeters: -0.3, yMeters: 2.2, zMeters: 2.7, gainDB: 28, phantomPower: true),
                MicrophonePlacement(microphoneID: micRight.id, channelNumber: 2, role: "Close right", xMeters: 0.3, yMeters: 2.2, zMeters: 2.7, gainDB: 28, phantomPower: true),
            ],
            environment: EnvironmentReading(temperatureCelsius: 18.6, relativeHumidityPercent: 57, pressureHPa: 1008)
        )
        let nave = MicrophoneSetup(
            name: "Nave ORTF",
            arrayGeometry: "ORTF 17 cm / 110°",
            interfaceDeviceID: interface.id,
            placements: [
                MicrophonePlacement(microphoneID: micLeft.id, channelNumber: 1, role: "ORTF left", xMeters: -0.085, yMeters: 7.4, zMeters: 3.1, yawDegrees: -55, pitchDegrees: 4, gainDB: 34, phantomPower: true),
                MicrophonePlacement(microphoneID: micRight.id, channelNumber: 2, role: "ORTF right", xMeters: 0.085, yMeters: 7.4, zMeters: 3.1, yawDegrees: 55, pitchDegrees: 4, gainDB: 34, phantomPower: true),
            ],
            environment: EnvironmentReading(temperatureCelsius: 18.6, relativeHumidityPercent: 57, pressureHPa: 1008)
        )
        let rear = MicrophoneSetup(
            name: "Rear omni",
            arrayGeometry: "Single omni",
            interfaceDeviceID: interface.id,
            placements: [
                MicrophonePlacement(microphoneID: micOmni.id, channelNumber: 3, role: "Rear room", xMeters: 0, yMeters: 15, zMeters: 2.8, gainDB: 38, phantomPower: true),
            ],
            environment: EnvironmentReading(temperatureCelsius: 18.6, relativeHumidityPercent: 57, pressureHPa: 1008),
            referenceChannelNumber: 3
        )
        let organID = "MDVS:ORGN:DEMO"
        let components = RoadmapEngine.demoComponents(organMDVSID: organID, snapshotSHA256: snapshotHash)
        let compilation = RoadmapEngine.compileSpecification(components: components, recipe: recipe, setupIDs: [close.id, nave.id, rear.id])
        var roadmap = compilation.roadmap
        if roadmap.isEmpty == false { roadmap[0].state = .queued }
        return OrgRecProject(
            title: "St. Nikolai · Demo field project",
            organMDVSID: organID,
            organName: "St. Nikolai Organ",
            venueName: "St. Nikolai",
            snapshot: snapshot,
            recipe: recipe,
            devices: [interface, micLeft, micRight, micOmni],
            setups: [close, nave, rear],
            registrations: compilation.registrations,
            roadmap: roadmap,
            organComponents: components,
            roadmapCompilation: compilation.report,
            physicalSoundTargets: compilation.physicalSoundTargets,
            physicalOverlapCandidates: compilation.overlapCandidates
        )
    }
}
