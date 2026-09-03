import SwiftUI
import OrgRecCore

// MARK: - P1 planning

struct ComplexCapturePlannerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var kind: ComplexCaptureKind = .physicalActuatorResponse
    @State private var sourceComponentID = ""
    @State private var customSourceLabel = ""
    @State private var techniques: Set<CaptureTechnique> = [.closePair]
    @State private var minimumTakes = 3
    @State private var required = true

    @State private var targetFamily: SoundingTargetFamily = .atonalPercussion
    @State private var targetBehavior: SoundingTargetTemporalBehavior = .discrete
    @State private var triggerMode: SoundingTargetTriggerMode = .keyboardKey
    @State private var plannedDuration = 8.0
    @State private var actuationDrafts = [PhysicalActuationDraft()]

    @State private var processName = "Documented effect process"
    @State private var processKind: CaptureProcessKind = .sequential
    @State private var processOrdering: CaptureProcessOrdering = .sequential
    @State private var processStages = [ProcessStageDraft(label: "Activate", action: .activate), ProcessStageDraft(label: "Observe / sustain", action: .observe)]
    @State private var timingDistribution: TimingDistributionKind = .uniform
    @State private var maximumIterations = 8
    @State private var maximumProcessDuration = 30.0
    @State private var terminationKind: ProcessTerminationKind = .completed
    @State private var cancellationBindingID = ""
    @State private var manualCancellation = true

    @State private var shutterCount = 4
    @State private var shutterName = "Expression shutters"
    @State private var pedalComponentID = ""
    @State private var openingMapping = "0:0, 0.25:1, 0.5:2, 0.75:3, 1:4"
    @State private var closingMapping = "0:0, 0.25:1, 0.5:2, 0.75:3, 1:4"
    @State private var distinctClosingMap = false

    @State private var affectedTremulantComponents = Set<String>()
    @State private var tremulantScope: TremulantCoverageScope = .representative

    @State private var baselineKind: OperationalBaselineKind = .blowerSteady
    @State private var baselineDuration = 180.0
    @State private var baselineStates = "Blower=on\nWind system=steady\nVentilation=off"
    @State private var baselineNotes = "Preserve as an unprocessed virtualization layer."

    private var components: [OrganComponent] {
        (model.project?.organComponents ?? []).sorted {
            if $0.division != $1.division { return $0.division.localizedStandardCompare($1.division) == .orderedAscending }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    private var soundingComponents: [OrganComponent] {
        components.filter {
            let value = $0.kind.lowercased()
            return value.contains("stop") || value.contains("rank") || $0.playableMIDILow != nil || $0.playableMIDIHigh != nil
        }
    }

    private var selectedTechniques: [CaptureTechnique] {
        CaptureTechnique.allCases.filter(techniques.contains)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan complex instrument capture").font(.title2.bold())
                    Text("P1 · physical response, processes, discrete shutters, tremulants, and operating layers")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add to Roadmap") { addPlan() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
            }
            .padding(20)
            Divider()

            Form {
                Section("Capture family") {
                    Picker("Protocol", selection: $kind) {
                        ForEach(ComplexCaptureKind.allCases) { value in Text(value.displayName).tag(value) }
                    }
                    .pickerStyle(.segmented)
                    Text(protocolExplanation).font(.caption).foregroundStyle(.secondary)
                }

                Section("Source and coverage") {
                    Picker("Source component", selection: $sourceComponentID) {
                        Text("Operator-defined source").tag("")
                        ForEach(components) { component in
                            Text("\(component.division) · \(component.label)").tag(component.id)
                        }
                    }
                    if sourceComponentID.isEmpty { TextField("Source name", text: $customSourceLabel) }
                    Stepper("Accepted takes per obligation: \(minimumTakes)", value: $minimumTakes, in: 1...20)
                    Toggle("Required Roadmap coverage", isOn: $required)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Microphone techniques").font(.caption.bold())
                        HStack {
                            ForEach(model.project?.recipe.techniques ?? CaptureTechnique.allCases) { technique in
                                Toggle(technique.rawValue, isOn: setBinding(technique, in: $techniques)).toggleStyle(.checkbox)
                            }
                        }
                    }
                }

                switch kind {
                case .physicalActuatorResponse:
                    soundingTargetSection
                    physicalActuationSection
                case .declarativeProcess:
                    soundingTargetSection
                    processSection
                case .discreteShutterMapping:
                    shutterSection
                case .tremulantResponse:
                    tremulantSection
                case .operationalBaseline:
                    baselineSection
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 900, minHeight: 720)
        .onAppear {
            if techniques.intersection(Set(model.project?.recipe.techniques ?? [])).isEmpty,
               let first = model.project?.recipe.techniques.first { techniques = [first] }
        }
    }

    private var soundingTargetSection: some View {
        Section("Intended sounding result") {
            Picker("Family", selection: $targetFamily) {
                ForEach(SoundingTargetFamily.allCases) { family in Text(family.displayName).tag(family) }
            }
            Picker("Temporal behavior", selection: $targetBehavior) {
                Text("Discrete / one-shot").tag(SoundingTargetTemporalBehavior.discrete)
                Text("Sustained").tag(SoundingTargetTemporalBehavior.sustained)
                Text("Repeating").tag(SoundingTargetTemporalBehavior.repeating)
                Text("Sequenced").tag(SoundingTargetTemporalBehavior.sequenced)
                Text("Composite").tag(SoundingTargetTemporalBehavior.composite)
            }
            Picker("Trigger", selection: $triggerMode) {
                ForEach([SoundingTargetTriggerMode.keyboardKey, .stopTab, .piston, .pedal, .continuousController, .externalControl, .manual, .composite], id: \.self) {
                    Text($0.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized).tag($0)
                }
            }
            LabeledContent("Planned acoustic duration") {
                HStack { Slider(value: $plannedDuration, in: 0.2...60); Text("\(plannedDuration.formatted(.number.precision(.fractionLength(1)))) s").monospacedDigit() }
                    .frame(width: 360)
            }
            Text("The sounding result is modeled separately from the actuator inputs and mechanical/electrical noise.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var physicalActuationSection: some View {
        Section("Independent physical inputs and variants") {
            Text("MIDI velocity is retained only as a controller dimension. Gate duration, early deactivation, route, force, pressure, controller value, and pedal path remain independent.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach($actuationDrafts) { $draft in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Variant label", text: $draft.label).font(.headline)
                        if actuationDrafts.count > 1 {
                            Button(role: .destructive) { actuationDrafts.removeAll { $0.id == draft.id } } label: { Image(systemName: "trash") }
                        }
                    }
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                        GridRow { Text("MIDI velocity"); TextField("blank if irrelevant", text: $draft.midiVelocity) }
                        GridRow { Text("Gate duration (s)"); TextField("e.g. 0.18", text: $draft.gateDuration) }
                        GridRow { Text("Deactivation offset (s)"); TextField("relative offset", text: $draft.deactivationOffset) }
                        GridRow {
                            Text("Offset reference")
                            Picker("", selection: $draft.deactivationReference) {
                                ForEach(DeactivationOffsetReference.allCases) { Text($0.displayName).tag($0) }
                            }.labelsHidden()
                        }
                        GridRow { Text("Actuator route"); TextField("key, stop tab, pneumatic relay…", text: $draft.route) }
                        GridRow { Text("Force (N)"); TextField("measured/planned", text: $draft.force) }
                        GridRow { Text("Pressure (Pa)"); TextField("measured/planned", text: $draft.pressure) }
                        GridRow { Text("Controller value"); HStack { TextField("value", text: $draft.controllerValue); TextField("unit", text: $draft.controllerUnit) } }
                        GridRow { Text("Pedal/action path"); TextField("time:value points, e.g. 0:0, .4:.2, 1:1", text: $draft.pedalPathPoints) }
                        GridRow { Text("Path duration (s)"); TextField("optional", text: $draft.pedalPathDuration) }
                    }
                    .textFieldStyle(.roundedBorder)
                }
                .padding(10)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            Button("Add input variant", systemImage: "plus") { actuationDrafts.append(PhysicalActuationDraft(label: "Variant \(actuationDrafts.count + 1)")) }
            Text("Each variant compiles to separate repeated takes. Accepted takes become points in a measured input-to-output transfer function.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var processSection: some View {
        Section("Declarative process") {
            TextField("Process name", text: $processName)
            HStack {
                Picker("Behavior", selection: $processKind) { ForEach(CaptureProcessKind.allCases) { Text($0.displayName).tag($0) } }
                Picker("Ordering", selection: $processOrdering) { ForEach(CaptureProcessOrdering.allCases) { Text($0.displayName).tag($0) } }
                Picker("Timing distribution", selection: $timingDistribution) { ForEach(TimingDistributionKind.allCases) { Text($0.displayName).tag($0) } }
            }
            ForEach($processStages) { $stage in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        TextField("Stage label", text: $stage.label)
                        Picker("Action", selection: $stage.action) { ForEach(CaptureProcessStageAction.allCases) { Text($0.displayName).tag($0) } }.frame(width: 180)
                        if processStages.count > 1 { Button(role: .destructive) { processStages.removeAll { $0.id == stage.id } } label: { Image(systemName: "trash") } }
                    }
                    HStack {
                        Text("Duration min / typical / max (s)").font(.caption)
                        TextField("min", text: $stage.minimumDuration)
                        TextField("typ", text: $stage.typicalDuration)
                        TextField("max", text: $stage.maximumDuration)
                        Stepper("Repeats \(stage.minimumRepeats)…\(stage.maximumRepeats)", value: $stage.maximumRepeats, in: stage.minimumRepeats...100)
                    }
                    TextField("Child stage numbers, comma-separated (optional)", text: $stage.childStageNumbers)
                }
                .textFieldStyle(.roundedBorder).padding(8)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
            Button("Add stage", systemImage: "plus") { processStages.append(ProcessStageDraft(label: "Stage \(processStages.count + 1)", action: .observe)) }
            HStack {
                Picker("Termination", selection: $terminationKind) { ForEach(ProcessTerminationKind.allCases) { Text($0.displayName).tag($0) } }
                Stepper("Hard iteration limit \(maximumIterations)", value: $maximumIterations, in: 1...1_000)
                LabeledContent("Duration limit") { HStack { Slider(value: $maximumProcessDuration, in: 1...600); Text("\(Int(maximumProcessDuration)) s") }.frame(width: 220) }
            }
            Toggle("Provide manual cancellation control", isOn: $manualCancellation)
            if !(model.project?.controlBindings ?? []).isEmpty {
                Picker("Bound cancellation control", selection: $cancellationBindingID) {
                    Text("No hardware binding").tag("")
                    ForEach(model.project?.controlBindings ?? []) { binding in Text(binding.label).tag(binding.id.uuidString) }
                }
            }
            Text("Repeating, irregular, and stochastic processes require a hard bound and a cancellation path. Cyclic child graphs are rejected.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var shutterSection: some View {
        Section("Discrete shutter topology") {
            TextField("Topology name", text: $shutterName)
            Stepper("Ordered shutters: \(shutterCount)", value: $shutterCount, in: 1...32)
            Picker("Expression pedal / control", selection: $pedalComponentID) {
                Text("Not bound to specification").tag("")
                ForEach(components) { Text("\($0.division) · \($0.label)").tag($0.id) }
            }
            TextField("Opening map · pedal position:open shutter count", text: $openingMapping)
            Toggle("Document a distinct closing map (hysteresis)", isOn: $distinctClosingMap)
            if distinctClosingMap { TextField("Closing map · pedal position:open shutter count", text: $closingMapping) }
            Text("Example: 0:0, .25:1, .5:2, .75:3, 1:4. OrgRec creates explicit per-shutter states and one Roadmap obligation per mapped detent and direction.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var tremulantSection: some View {
        Section("Affected pipe sounds") {
            Picker("Coverage", selection: $tremulantScope) { ForEach(TremulantCoverageScope.allCases) { Text($0.displayName).tag($0) } }
            Text(tremulantScope == .representative ? "Low, middle, and high notes per affected stop/rank." : "Every chromatic Roadmap note per affected stop/rank.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(soundingComponents) { component in
                        Toggle("\(component.division) · \(component.label)", isOn: setBinding(component.id, in: $affectedTremulantComponents)).toggleStyle(.checkbox)
                    }
                }
            }
            .frame(height: 190)
            Text("For every selected stop, OrgRec compiles paired without/steady-with takes plus activation and deactivation transitions, then measures modulation rate, depth, transition, and settling.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var baselineSection: some View {
        Section("Long operating-noise protocol") {
            Picker("Layer", selection: $baselineKind) { ForEach(OperationalBaselineKind.allCases) { Text($0.displayName).tag($0) } }
            LabeledContent("Minimum duration") {
                HStack { Slider(value: $baselineDuration, in: 120...1_800, step: 30); Text("\(Int(baselineDuration)) s").monospacedDigit() }.frame(width: 400)
            }
            Text("Required subsystem states · one Label=value per line")
                .font(.caption.bold())
            TextEditor(text: $baselineStates).font(.body.monospaced()).frame(height: 100)
            TextField("Protocol notes", text: $baselineNotes)
            Label("Original audio is preserved as a virtualization layer. Automatic denoising is prohibited; L10/L50/L90, RMS, crest factor, variability, and octave-band spectra are computed.", systemImage: "waveform.path.ecg")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var canSubmit: Bool {
        !selectedTechniques.isEmpty
            && (!sourceComponentID.isEmpty || !customSourceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && (kind != .tremulantResponse || !affectedTremulantComponents.isEmpty)
    }

    private var protocolExplanation: String {
        switch kind {
        case .physicalActuatorResponse: "Capture how independent physical inputs change the produced sound; do not substitute MIDI velocity for physical intensity."
        case .declarativeProcess: "Describe bounded one-shot, sustained, periodic, irregular, sequential, composite, or stochastic behavior with explicit stages."
        case .discreteShutterMapping: "Represent the jalousie as ordered discrete shutters and document pedal-to-state mappings in both directions."
        case .tremulantResponse: "Record tremulant influence in affected pipe sounds as paired steady states and both transitions."
        case .operationalBaseline: "Record multi-minute blower, wind, electrical, ventilation, idle, or room layers in explicit subsystem states."
        }
    }

    private func addPlan() {
        model.errorMessage = nil
        let sourceID = sourceComponentID.isEmpty ? nil : sourceComponentID
        let definition: SoundingTargetDefinition? = [.physicalActuatorResponse, .declarativeProcess].contains(kind) ? SoundingTargetDefinition(
            family: targetFamily, temporalBehavior: targetBehavior, triggerMode: triggerMode,
            memberComponentIDs: sourceID.map { [$0] } ?? [], minimumAcceptedTakeCount: minimumTakes,
            plannedDurationSeconds: plannedDuration, captureRelease: true,
            notes: "P1 target; physical inputs and unintended noises remain separately classified."
        ) : nil
        let variants = kind == .physicalActuatorResponse ? actuationDrafts.compactMap(physicalVariant) : []
        let process = kind == .declarativeProcess ? processModel() : nil
        let topology = kind == .discreteShutterMapping ? shutterTopology(sourceID: sourceID) : nil
        let baseline = kind == .operationalBaseline ? operationalBaseline() : nil
        let request = ComplexCapturePlanRequest(
            kind: kind, sourceComponentID: sourceID, customComponentLabel: customSourceLabel,
            soundingTargetDefinition: definition, physicalActuationVariants: variants,
            processModel: process, shutterTopology: topology,
            tremulantAffectedComponentIDs: Array(affectedTremulantComponents), tremulantCoverageScope: tremulantScope,
            operationalBaseline: baseline, minimumAcceptedTakeCount: minimumTakes,
            techniques: selectedTechniques, required: required
        )
        Task { @MainActor in
            await model.addComplexCapturePlan(request)
            if model.errorMessage == nil { dismiss() }
        }
    }

    private func physicalVariant(_ draft: PhysicalActuationDraft) -> PhysicalActuationVariant? {
        let points = parseCurve(draft.pedalPathPoints)
        let path: ActuationCurve? = points.count >= 2 ? ActuationCurve(
            kind: .custom, timeBasis: .normalized, interpolation: .linear, points: points,
            durationSeconds: Double(draft.pedalPathDuration), evidenceSource: .operatorPlanned,
            deviceLabel: "P1 planner", notes: "Commanded pedal/action path; not a sensor observation."
        ) : nil
        let variant = PhysicalActuationVariant(
            label: draft.label, midiVelocity: Int(draft.midiVelocity), gateDurationSeconds: Double(draft.gateDuration),
            deactivationOffsetSeconds: Double(draft.deactivationOffset), deactivationOffsetReference: draft.deactivationReference,
            actuatorRoute: nonEmpty(draft.route), forceNewtons: Double(draft.force), pressurePascals: Double(draft.pressure),
            controllerValue: Double(draft.controllerValue), controllerUnit: nonEmpty(draft.controllerUnit), pedalPath: path,
            evidence: .operatorPlanned, notes: "Independent physical actuation inputs."
        )
        return variant.validationIssues.isEmpty ? variant : nil
    }

    private func processModel() -> CaptureProcessModel {
        let stageIDs = processStages.indices.map { "stage-\($0 + 1)" }
        let stages = processStages.enumerated().map { index, draft in
            let minimum = Double(draft.minimumDuration) ?? 0
            let typical = max(minimum, Double(draft.typicalDuration) ?? minimum)
            let maximum = max(typical, Double(draft.maximumDuration) ?? typical)
            let timing = ProcessTimingEnvelope(minimumSeconds: minimum, typicalSeconds: typical, maximumSeconds: maximum, distribution: minimum == maximum ? .fixed : timingDistribution)
            let children = draft.childStageNumbers.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace }).compactMap { Int($0) }.filter { $0 > 0 && $0 <= stageIDs.count }.map { stageIDs[$0 - 1] }
            return CaptureProcessStage(
                id: stageIDs[index], label: draft.label, action: draft.action, ordering: processOrdering,
                childStageIDs: children, duration: timing, minimumRepeats: draft.minimumRepeats,
                maximumRepeats: draft.maximumRepeats, notes: "Stage \(index + 1) of the operator-authored P1 process."
            )
        }
        let bindingID = UUID(uuidString: cancellationBindingID)
        var terminations = [ProcessTerminationCondition(kind: terminationKind, threshold: terminationKind == .elapsedDuration ? maximumProcessDuration : nil, unit: terminationKind == .elapsedDuration ? "s" : nil, controlBindingID: bindingID, description: "Planned process termination")]
        if manualCancellation { terminations.append(ProcessTerminationCondition(kind: .manual, description: "Operator cancellation control in Record view")) }
        let childIDs = Set(stages.flatMap(\.childStageIDs))
        let rootIDs = stageIDs.filter { !childIDs.contains($0) }
        return CaptureProcessModel(
            name: processName, kind: processKind, ordering: processOrdering,
            rootStageIDs: rootIDs.isEmpty ? Array(stageIDs.prefix(1)) : rootIDs,
            stages: stages, terminationConditions: terminations,
            maximumIterations: processKind.mayRepeat ? maximumIterations : nil,
            maximumDurationSeconds: maximumProcessDuration, cancellationControlBindingID: bindingID,
            notes: "Min/typ/max timing and cancellation remain explicit in take paradata."
        )
    }

    private func shutterTopology(sourceID: String?) -> DiscreteShutterTopology? {
        let source = sourceID ?? "orgrec:shutter-enclosure:\(Data(customSourceLabel.utf8).base64EncodedString())"
        let shutters = (0..<shutterCount).map { ShutterElement(id: "shutter-\($0 + 1)", label: "Shutter \($0 + 1)", sequenceIndex: $0) }
        let states = (0...shutterCount).map { count in
            DiscreteShutterState(id: "open-\(count)", label: count == 0 ? "Closed" : "\(count) of \(shutterCount) open", shutterOpenness: Dictionary(uniqueKeysWithValues: shutters.map { ($0.id, $0.sequenceIndex < count ? 1 : 0) }))
        }
        func map(_ text: String, direction: PedalTravelDirection) -> [PedalShutterMappingPoint] {
            text.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline }).compactMap { token in
                let values = token.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard values.count == 2, let position = Double(values[0]), let count = Int(values[1]), (0...shutterCount).contains(count) else { return nil }
                return PedalShutterMappingPoint(pedalPosition: position, shutterStateID: "open-\(count)", direction: direction)
            }
        }
        let mapping = distinctClosingMap ? map(openingMapping, direction: .opening) + map(closingMapping, direction: .closing) : map(openingMapping, direction: .both)
        return DiscreteShutterTopology(name: shutterName, enclosureComponentID: source, pedalComponentID: nonEmpty(pedalComponentID), shutters: shutters, states: states, pedalMapping: mapping, evidence: "operator-documented", notes: "Sequential shutter topology; no global continuous-openness assumption.")
    }

    private func operationalBaseline() -> OperationalBaselineProtocol {
        let states = baselineStates.split(whereSeparator: \.isNewline).compactMap { line -> CaptureStateAssignment? in
            let pair = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2, !pair[0].isEmpty else { return nil }
            let key = "orgrec:subsystem:\(pair[0].lowercased().replacingOccurrences(of: " ", with: "-"))"
            let lower = pair[1].lowercased()
            let boolean = ["on", "true", "yes", "1"].contains(lower) ? true : (["off", "false", "no", "0"].contains(lower) ? false : nil)
            return CaptureStateAssignment(subjectComponentID: key, subjectLabel: pair[0], dimension: baselineDimension(label: pair[0]), valueKind: boolean == nil ? .text : .boolean, booleanValue: boolean, textValue: boolean == nil ? pair[1] : nil, evidence: "operator-planned P1 baseline")
        }
        return OperationalBaselineProtocol(
            kind: baselineKind, subsystemComponentIDs: states.map(\.subjectComponentID), requiredStateAssignments: states,
            minimumDurationSeconds: baselineDuration, minimumAcceptedTakeCount: minimumTakes,
            preservationRole: .virtualizationLayer, automaticDenoisingPermitted: false, notes: baselineNotes
        )
    }

    private func baselineDimension(label: String) -> CaptureStateDimension {
        let value = label.lowercased()
        if value.contains("blower") { return .blower }
        if value.contains("wind") { return .windSystem }
        if value.contains("shutter") || value.contains("jalous") { return .shutter }
        if value.contains("enclos") { return .enclosure }
        return .custom
    }

    private func parseCurve(_ text: String) -> [ActuationCurvePoint] {
        text.split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline }).compactMap { token in
            let pair = token.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard pair.count == 2, let time = Double(pair[0]), let value = Double(pair[1]) else { return nil }
            return ActuationCurvePoint(time: time, value: value)
        }
    }

    private func nonEmpty(_ value: String) -> String? {
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private func setBinding<Element: Hashable>(_ value: Element, in binding: Binding<Set<Element>>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue.contains(value) }, set: { selected in
            if selected { binding.wrappedValue.insert(value) } else { binding.wrappedValue.remove(value) }
        })
    }
}

private struct PhysicalActuationDraft: Identifiable {
    var id = UUID()
    var label = "Normal action"
    var midiVelocity = ""
    var gateDuration = ""
    var deactivationOffset = ""
    var deactivationReference: DeactivationOffsetReference = .activationCommand
    var route = ""
    var force = ""
    var pressure = ""
    var controllerValue = ""
    var controllerUnit = ""
    var pedalPathPoints = ""
    var pedalPathDuration = ""
}

private struct ProcessStageDraft: Identifiable {
    var id = UUID()
    var label: String
    var action: CaptureProcessStageAction
    var minimumDuration = "0.5"
    var typicalDuration = "1"
    var maximumDuration = "2"
    var minimumRepeats = 1
    var maximumRepeats = 1
    var childStageNumbers = ""
}

// MARK: - P1 recording guidance and event capture

struct ComplexCaptureProtocolSummary: View {
    let protocolSnapshot: ComplexCaptureProtocol
    let acceptedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(protocolSnapshot.kind.displayName, systemImage: icon).font(.callout.bold())
            Text(protocolSnapshot.name).font(.callout)
            ProgressView(value: Double(min(acceptedCount, protocolSnapshot.minimumAcceptedTakeCount)), total: Double(protocolSnapshot.minimumAcceptedTakeCount))
            Text("\(acceptedCount) of \(protocolSnapshot.minimumAcceptedTakeCount) accepted repetitions · \(protocolSnapshot.contractVersion)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if let variant = protocolSnapshot.physicalActuation { Text(variant.summary).font(.caption).foregroundStyle(.secondary) }
            if let process = protocolSnapshot.processModel { Text("\(process.kind.displayName) · \(process.stages.count) stages · hard limit \(process.maximumDurationSeconds?.formatted() ?? "—") s").font(.caption).foregroundStyle(.secondary) }
            if let topology = protocolSnapshot.shutterTopology { Text("\(topology.shutters.count) ordered shutters · state \(protocolSnapshot.targetShutterStateID ?? "—") · \(protocolSnapshot.pedalTravelDirection?.displayName ?? "both")").font(.caption).foregroundStyle(.secondary) }
            if let trem = protocolSnapshot.tremulant { Text("\(trem.condition.displayName) · \(trem.coverageScope.displayName) rank coverage").font(.caption).foregroundStyle(.secondary) }
            if let baseline = protocolSnapshot.operationalBaseline {
                Text("\(baseline.kind.displayName) · ≥\(Int(baseline.minimumDurationSeconds)) s · unprocessed \(baseline.preservationRole.rawValue)").font(.caption).foregroundStyle(.secondary)
                Label("Automatic denoising prohibited", systemImage: "waveform.badge.exclamationmark").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(OrgRecTheme.ai.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
    }

    private var icon: String {
        switch protocolSnapshot.kind {
        case .physicalActuatorResponse: "dial.high"
        case .declarativeProcess: "point.3.connected.trianglepath.dotted"
        case .discreteShutterMapping: "rectangle.split.3x1"
        case .tremulantResponse: "waveform.path"
        case .operationalBaseline: "waveform.badge.magnifyingglass"
        }
    }
}

struct ComplexCaptureControl: View {
    @EnvironmentObject private var model: AppModel
    let protocolSnapshot: ComplexCaptureProtocol
    @State private var observedValue = ""
    @State private var observedUnit = ""
    @State private var pedalPosition = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(protocolSnapshot.instructions).font(.caption).foregroundStyle(.secondary)
            switch protocolSnapshot.kind {
            case .physicalActuatorResponse:
                if let variant = protocolSnapshot.physicalActuation {
                    ForEach(variant.inputs) { input in
                        HStack { Text(input.kind.displayName).font(.caption.bold()); Spacer(); Text(input.numericValue.map { "\($0.formatted()) \(input.unit ?? "")" } ?? input.textValue ?? "—").font(.caption.monospacedDigit()) }
                    }
                }
                HStack { Button("Mark action begin") { mark(.actionBegin) }; Button("Mark action end") { mark(.actionEnd) } }
                HStack { TextField("Observed value", text: $observedValue); TextField("unit", text: $observedUnit); Button("Mark observation") { mark(.notableVariation, value: Double(observedValue), unit: observedUnit) } }.textFieldStyle(.roundedBorder)
            case .declarativeProcess:
                if let process = protocolSnapshot.processModel {
                    ForEach(process.stages) { stage in
                        HStack { Text(stage.label).font(.caption).frame(maxWidth: .infinity, alignment: .leading); Button("Begin") { mark(.processStageBegin, stage: stage.id) }; Button("End") { mark(.processStageEnd, stage: stage.id) } }
                    }
                    HStack { Button("Mark action begin") { mark(.actionBegin) }; Button("Completed") { mark(.actionEnd) }; Button("Cancel process", role: .destructive) { mark(.processCancelled) } }
                }
            case .discreteShutterMapping:
                if let topology = protocolSnapshot.shutterTopology {
                    Slider(value: $pedalPosition, in: 0...1)
                    let direction = protocolSnapshot.pedalTravelDirection == .closing ? PedalTravelDirection.closing : .opening
                    let state = topology.state(at: pedalPosition, direction: direction)
                    HStack { Text("Pedal \(pedalPosition.formatted(.percent.precision(.fractionLength(0))))").monospacedDigit(); Spacer(); Text(state?.label ?? "Unmapped").bold(); Button("Mark state") { mark(.shutterStateObserved, state: state?.id, value: pedalPosition, unit: "normalized 0–1") } }
                }
            case .tremulantResponse:
                if let trem = protocolSnapshot.tremulant {
                    Text(trem.condition.displayName).font(.caption.bold())
                    switch trem.condition {
                    case .withoutTremulant: Button("Mark tremulant verified off") { mark(.tremulantDeactivated) }
                    case .steadyWithTremulant: Button("Mark stable modulation") { mark(.tremulantSteady) }
                    case .activationTransition: Button("Mark tremulant activation") { mark(.tremulantActivated) }
                    case .deactivationTransition: Button("Mark tremulant deactivation") { mark(.tremulantDeactivated) }
                    }
                }
            case .operationalBaseline:
                if let baseline = protocolSnapshot.operationalBaseline {
                    Text("Hold state for at least \(Int(baseline.minimumDurationSeconds)) s. Current take: \(model.capture.elapsed.formatted(.number.precision(.fractionLength(1)))) s").font(.caption.monospacedDigit())
                    ProgressView(value: min(model.capture.elapsed / baseline.minimumDurationSeconds, 1))
                    HStack { Button("Mark stable operation") { mark(.baselineStable) }; Button("Mark variation") { mark(.notableVariation) } }
                }
            }
        }
    }

    private func mark(_ kind: ComplexCaptureEventKind, stage: String? = nil, state: String? = nil, value: Double? = nil, unit: String? = nil) {
        Task { await model.markComplexCaptureEvent(kind, stageID: stage, shutterStateID: state, observedValue: value, unit: unit) }
    }
}

// MARK: - P1 analysis review

struct ComplexCaptureTakeReview: View {
    let paradata: ComplexCaptureTakeParadata

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Complex-capture evidence").font(.headline)
                    Text("\(paradata.protocolSnapshot.kind.displayName) · take \(paradata.repetitionNumber) · \(paradata.protocolSnapshot.contractVersion)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(paradata.events.count) structured events").font(.caption.monospacedDigit().bold()).foregroundStyle(OrgRecTheme.ai)
            }
            if let observation = paradata.actuatorResponseObservation { actuatorReview(observation) }
            if let response = paradata.tremulantAnalysis { tremulantReview(response) }
            if let baseline = paradata.operationalBaselineAnalysis { baselineReview(baseline) }
            if !paradata.events.isEmpty {
                Divider()
                ForEach(paradata.events.sorted { $0.atSeconds < $1.atSeconds }) { event in
                    HStack { Text(event.atSeconds.formatted(.number.precision(.fractionLength(3))) + " s").font(.caption.monospacedDigit()).frame(width: 70, alignment: .leading); Text(event.kind.rawValue); Spacer(); Text([event.stageID, event.shutterStateID, event.observedValue.map { "\($0.formatted()) \(event.unit ?? "")" }, event.notes].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
    }

    private func actuatorReview(_ value: ActuatorResponseObservation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Measured input-to-output point").font(.caption.bold())
            Text(value.inputs.map { input in input.numericValue.map { "\(input.kind.displayName)=\($0.formatted()) \(input.unit ?? "")" } ?? "\(input.kind.displayName)=\(input.textValue ?? "—")" }.joined(separator: " · ")).font(.caption)
            HStack { evidenceMetric("Peak", value.peakLevelDBFS, "dBFS"); evidenceMetric("RMS", value.rmsLevelDBFS, "dBFS"); evidenceMetric("Latency", value.acousticOnsetLatencySeconds, "s"); evidenceMetric("Duration", value.acousticDurationSeconds, "s") }
        }
    }

    private func tremulantReview(_ value: TremulantResponseAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tremulant response").font(.caption.bold())
            HStack { evidenceMetric("AM rate", value.amplitudeModulationRateHz, "Hz"); evidenceMetric("AM depth", value.amplitudeModulationDepthDB, "dB"); evidenceMetric("FM rate", value.frequencyModulationRateHz, "Hz"); evidenceMetric("FM depth", value.frequencyModulationDepthCents, "¢"); evidenceMetric("Transition", value.transitionTimeSeconds, "s"); evidenceMetric("Settling", value.settlingTimeSeconds, "s") }
            ForEach(value.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func baselineReview(_ value: OperationalBaselineAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Operational noise statistics · \(value.measurementUnit)").font(.caption.bold())
            HStack { evidenceMetric("Duration", value.analyzedDurationSeconds, "s"); evidenceMetric("Peak", value.peakDBFS, "dBFS"); evidenceMetric("RMS", value.rmsDBFS, "dBFS"); evidenceMetric("L10", value.l10DBFS, "dBFS"); evidenceMetric("L50", value.l50DBFS, "dBFS"); evidenceMetric("L90", value.l90DBFS, "dBFS"); evidenceMetric("Variability", value.shortTermLevelStandardDeviationDB, "dB") }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(value.octaveBandLevels) { band in
                    VStack(spacing: 2) {
                        Rectangle().fill(OrgRecTheme.ai.opacity(0.75)).frame(width: 18, height: max(2, CGFloat((band.levelDBFS + 120) / 120) * 62))
                        Text(band.centerFrequencyHz >= 1_000 ? "\(band.centerFrequencyHz / 1_000, specifier: "%.0f")k" : "\(band.centerFrequencyHz, specifier: "%.0f")").font(.caption2.monospacedDigit())
                    }
                }
            }
            ForEach(value.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func evidenceMetric(_ label: String, _ value: Double?, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(value.map { "\($0.formatted(.number.precision(.fractionLength(0...3)))) \(unit)" } ?? "—").font(.caption.monospacedDigit().bold()); Text(label).font(.caption2).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActuatorResponseFunctionsPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let functions = model.project?.actuatorResponseFunctions, !functions.isEmpty {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(functions) { function in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(function.componentLabel).font(.callout.bold())
                                Spacer()
                                Text("\(function.observations.count) points · \(function.status.rawValue)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Text(function.inputDimensions.map(\.displayName).joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(function.transferEstimates ?? []) { estimate in
                                HStack(alignment: .firstTextBaseline) {
                                    Text("\(estimate.inputDimension.displayName) → \(estimate.outputDimension)")
                                        .font(.caption.bold()).frame(maxWidth: .infinity, alignment: .leading)
                                    Text("y = \(estimate.slope.formatted(.number.precision(.fractionLength(0...5))))x \(estimate.intercept >= 0 ? "+" : "−") \(abs(estimate.intercept).formatted(.number.precision(.fractionLength(0...5))))")
                                        .font(.caption.monospacedDigit())
                                    Text("n=\(estimate.sampleCount) · R² \(estimate.coefficientOfDetermination?.formatted(.number.precision(.fractionLength(3))) ?? "—")")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                            if (function.transferEstimates ?? []).isEmpty {
                                Text("Record at least two distinct numeric input values to estimate an input→output relation. Raw observations remain preserved.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(9)
                        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Label("Actuator transfer functions", systemImage: "function")
                        .font(.headline)
                    Spacer()
                    Text("\(functions.count) source\(functions.count == 1 ? "" : "s")")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .orgRecCard()
        }
    }
}
