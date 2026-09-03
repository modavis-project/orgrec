import SwiftUI
import OrgRecCore

struct InteractionSensorLabView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        InteractionSensorLabContent(sensor: model.interactionSensors, midi: model.midiControl)
            .environmentObject(model)
    }
}

private struct InteractionSensorLabContent: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var sensor: InteractionSensorCenter
    @ObservedObject var midi: MIDIControlCenter

    @State private var draft = InteractionSensorConfiguration(sensorDeviceID: UUID())
    @State private var referenceTravel = ""
    @State private var calibrationReferenceMethod = "measured key or pedal geometry"
    @State private var validationReference: InteractionValidationReference = .measuredGeometry
    @State private var validationTravel = ""
    @State private var validationDuration = ""
    @State private var validationNotes = ""
    @State private var validationEnvironment = ""

    private var components: [OrganComponent] {
        var byID: [String: OrganComponent] = [:]
        for component in model.project?.organComponents ?? [] { byID[component.id] = component }
        for item in model.project?.roadmap ?? [] { byID[item.component.id] = item.component }
        return byID.values.sorted {
            ($0.division, $0.label, $0.midiNote ?? -1) < ($1.division, $1.label, $1.midiNote ?? -1)
        }
    }

    private var acceptedCalibration: InteractionSensorCalibration? {
        guard let id = draft.currentCalibrationID else { return nil }
        return model.project?.interactionSensorCalibrations?.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                workflowStrip
                configurationCard
                connectionAndLiveFeedback
                calibrationCard
                midiEvaluationCard
                validationCard
                captureEvidenceCard
            }
            .padding(24)
        }
        .onAppear(perform: loadProjectConfiguration)
        .onChange(of: model.project?.activeInteractionSensorConfigurationID) { _, _ in loadProjectConfiguration() }
        .onReceive(midi.$lastIncomingObservation) { observation in
            guard let observation,
                  observation.message.messageType == .noteOn,
                  let note = observation.message.number,
                  let velocity = observation.message.value,
                  velocity > 0 else { return }
            sensor.observeMIDINote(note: note, velocity: velocity, hostNanoseconds: observation.hostTimeNanoseconds)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Experimental interaction sensing")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                Text("Guided setup, immediate motion feedback, synchronized take capture, and validation for constrained organ controls.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label("Experimental evidence", systemImage: "testtube.2")
                .font(.caption.bold())
                .foregroundStyle(OrgRecTheme.shu)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(OrgRecTheme.shu.opacity(0.10), in: Capsule())
        }
    }

    private var workflowStrip: some View {
        HStack(spacing: 0) {
            workflowStep("1", "Configure", complete: draft.validationIssues.isEmpty)
            workflowLine
            workflowStep("2", "Connect & check", complete: sensor.isStreaming && !sensor.diagnosticChecks.contains { $0.state == .fail })
            workflowLine
            workflowStep("3", "Calibrate motion", complete: acceptedCalibration != nil || sensor.draftCalibration != nil)
            workflowLine
            workflowStep("4", "Validate", complete: sensor.validationSummary.passedExperimentalGate)
            workflowLine
            workflowStep("5", "Capture takes", complete: (model.selectedTake?.interactionSensorCaptures?.isEmpty == false))
        }
        .orgRecCard(inset: 14)
    }

    private func workflowStep(_ number: String, _ title: String, complete: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(complete ? OrgRecTheme.ai : OrgRecTheme.recessed).frame(width: 27, height: 27)
                if complete { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(OrgRecTheme.washi) }
                else { Text(number).font(.caption.bold()).foregroundStyle(.secondary) }
            }
            Text(title).font(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var workflowLine: some View {
        Rectangle().fill(OrgRecTheme.hairline).frame(width: 24, height: 1).offset(y: -10)
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("1 · Configure the mechanism", systemImage: "slider.horizontal.3").font(.headline)
                Spacer()
                Picker("Capture", selection: $draft.capturePolicy) {
                    Text(InteractionSensorCapturePolicy.disabled.displayName).tag(InteractionSensorCapturePolicy.disabled)
                    Text(InteractionSensorCapturePolicy.optional.displayName).tag(InteractionSensorCapturePolicy.optional)
                }
                .labelsHidden().frame(width: 170)
            }
            Text("One active node is supported. Keep it on a representative mechanism rather than moving it across the keyboard. A connection never adds interaction data automatically: every standard take has its own opt-in switch in Record.")
                .font(.callout).foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    Text("Name").foregroundStyle(.secondary)
                    TextField("Experimental IMU", text: $draft.name)
                    Text("Use case").foregroundStyle(.secondary)
                    Picker("", selection: Binding(
                        get: { draft.resolvedUseCase },
                        set: { draft.useCase = $0 }
                    )) {
                        ForEach(InteractionSensorUseCase.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden()
                }
                GridRow {
                    Text("Movement model").foregroundStyle(.secondary)
                    Picker("", selection: $draft.movementModel) {
                        ForEach(InteractionMovementModel.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden()
                    Text("Node ID").foregroundStyle(.secondary)
                    TextField("imu-node-1", text: $draft.nodeIdentifier)
                }
                GridRow {
                    Text("Organ control").foregroundStyle(.secondary)
                    Picker("", selection: $draft.targetComponentID) {
                        Text("Unassigned").tag(nil as String?)
                        ForEach(components) { component in
                            Text([component.division, component.label, component.noteName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .tag(Optional(component.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: draft.targetComponentID) { _, id in
                        if let component = components.first(where: { $0.id == id }) { draft.targetComponentLabel = component.label }
                    }
                    Text("Target").foregroundStyle(.secondary)
                    Text(draft.targetComponentID == nil ? "Manual take selection" : draft.targetComponentLabel)
                        .font(.caption).foregroundStyle(.secondary)
                }
                GridRow {
                    Text("Transport").foregroundStyle(.secondary)
                    Picker("", selection: $draft.transport) {
                        Text("Simulation").tag(InteractionSensorTransport.simulation)
                        Text("USB serial").tag(InteractionSensorTransport.serial)
                    }.labelsHidden()
                    Text("Sample rate").foregroundStyle(.secondary)
                    HStack {
                        TextField("200", value: $draft.nominalSampleRateHz, format: .number.precision(.fractionLength(0...1)))
                        Text("Hz").foregroundStyle(.secondary)
                    }
                }
                if draft.transport == .serial {
                    GridRow {
                        Text("Serial port").foregroundStyle(.secondary)
                        Picker("", selection: $draft.portPath) {
                            Text("Select…").tag(nil as String?)
                            ForEach(sensor.availableSerialPorts, id: \.self) { Text($0).tag(Optional($0)) }
                        }.labelsHidden()
                        Text("Baud rate").foregroundStyle(.secondary)
                        TextField("230400", value: $draft.baudRate, format: .number)
                    }
                }
                GridRow {
                    Text("Hinge radius").foregroundStyle(.secondary)
                    OptionalNumberField(value: $draft.hingeRadiusMillimeters, placeholder: "optional", suffix: "mm")
                    Text("Known stop stroke").foregroundStyle(.secondary)
                    OptionalNumberField(value: $draft.knownStrokeMillimeters, placeholder: "optional", suffix: "mm")
                }
            }
            Text(draft.resolvedUseCase.guidance)
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Independent endpoint switches are fitted", isOn: $draft.endpointInputsExpected)

            if !draft.validationIssues.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(draft.validationIssues, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(OrgRecTheme.shu) }
                }
            }

            HStack {
                Button("Refresh serial ports") { sensor.refreshSerialPorts() }
                Spacer()
                Button("Save configuration") { Task { await saveDraft() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!draft.validationIssues.filter { !$0.contains("endpoint") }.isEmpty)
            }
        }
        .orgRecCard()
    }

    private var connectionAndLiveFeedback: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("2 · Connect and inspect live behavior", systemImage: "gyroscope").font(.headline)
                Spacer()
                Circle().fill(sensor.isStreaming ? OrgRecTheme.ai : OrgRecTheme.shu).frame(width: 8, height: 8)
                Text(sensor.connectionState.label).font(.caption.bold())
                Button(sensor.isStreaming ? "Disconnect" : "Connect draft") {
                    if sensor.isStreaming { sensor.disconnect() }
                    else { connectDraft() }
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    SensorLiveTrace(points: sensor.livePoints)
                        .frame(minHeight: 190)
                    HStack(spacing: 22) {
                        liveMetric("Angle", String(format: "%.2f°", sensor.latestAngleDegrees))
                        liveMetric("Hinge rate", String(format: "%.1f °/s", sensor.latestProjectedAngularVelocityDPS))
                        liveMetric("Acceleration", sensor.latestSample.map { String(format: "%.3f g", $0.accelerationG.magnitude) } ?? "—")
                        liveMetric("Temperature", sensor.latestSample.map { String(format: "%.1f °C", $0.temperatureCelsius) } ?? "—")
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Immediate checks").font(.subheadline.bold())
                    ForEach(sensor.diagnosticChecks) { check in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: checkSymbol(check.state)).foregroundStyle(checkColor(check.state)).frame(width: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(check.title).font(.caption.bold())
                                Text(check.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(width: 330, alignment: .leading)
            }

            if let progress = sensor.latestProgress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Calibrated action progress").font(.caption); Spacer(); Text(progress.formatted(.percent.precision(.fractionLength(0)))).font(.caption.monospacedDigit()) }
                    ProgressView(value: progress).tint(OrgRecTheme.shu)
                }
            }
        }
        .orgRecCard()
    }

    private var calibrationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("3 · Calibrate the mounted mechanism", systemImage: "scope").font(.headline)
            Text("Calibration is specific to this sensor, mount, control, temperature, and range. Remounting invalidates it.")
                .font(.callout).foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 16) {
                guideStage(number: 1, title: "Hold still", detail: "Leave the control at neutral for at least two seconds, then capture gyro bias and gravity.") {
                    Button(sensor.isCapturingStationary ? "Hold still…" : (sensor.stationaryWindowReady ? "Capture neutral again" : "Begin 2 s neutral capture")) {
                        sensor.beginStationaryCalibrationWindow()
                    }
                    .disabled(!sensor.isStreaming || sensor.isCapturingStationary)
                    Text(sensor.stationaryCaptureStatus).font(.caption2).foregroundStyle(sensor.stationaryWindowReady ? OrgRecTheme.ai : .secondary)
                }
                guideStage(number: 2, title: "Exercise full travel", detail: "Begin with the positive action (press, engage, or open), then return to neutral at least three times using slow and fast strokes. The first deliberate movement defines positive direction for later onset/release association.") {
                    if sensor.isLearningMovement {
                        Button("Finish learning") {
                            _ = sensor.finishMovementLearning(
                                referenceTravelDegrees: Double(referenceTravel),
                                referenceMethod: Double(referenceTravel) == nil ? nil : calibrationReferenceMethod
                            )
                        }.buttonStyle(.borderedProminent)
                    } else {
                        Button("Start movement learning") { sensor.beginMovementLearning() }
                            .disabled(!sensor.stationaryWindowReady)
                    }
                }
                guideStage(number: 3, title: "Add a physical reference", detail: "Optional but recommended: enter independently measured angular travel. MIDI velocity is not this reference.") {
                    HStack {
                        TextField("degrees", text: $referenceTravel).frame(width: 80)
                        TextField("method", text: $calibrationReferenceMethod)
                    }
                }
            }

            if let calibration = sensor.draftCalibration ?? acceptedCalibration {
                Divider()
                HStack(alignment: .top, spacing: 20) {
                    calibrationMetric("Quality", calibration.qualityScore.formatted(.percent.precision(.fractionLength(0))))
                    calibrationMetric("Axis variance", calibration.axisExplainedVariance?.formatted(.percent.precision(.fractionLength(0))) ?? "—")
                    calibrationMetric("Gyro noise", String(format: "%.3f °/s RMS", calibration.gyroNoiseRMSDPS))
                    calibrationMetric("Estimated travel", calibration.estimatedTravelDegrees.map { String(format: "%.2f°", $0) } ?? "—")
                    calibrationMetric("Gravity correction", calibration.gravityIsObservable ? "Observable" : "Not observable")
                    Spacer()
                    if sensor.draftCalibration != nil {
                        Button("Accept provisionally") {
                            Task {
                                if let calibration = sensor.draftCalibration {
                                    draft.currentCalibrationID = calibration.id
                                    await model.acceptInteractionSensorCalibration(calibration)
                                    await model.saveInteractionSensorConfiguration(draft)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                ForEach(calibration.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(OrgRecTheme.shu) }
            }
        }
        .orgRecCard()
    }

    private var midiEvaluationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("MIDI-assisted velocity evaluation", systemImage: "pianokeys").font(.headline)
                Spacer()
                Button("Refresh MIDI") { midi.refreshEndpoints() }
            }
            Text("Useful idea—with an important boundary. A connected MIDI piano can automatically associate note-on velocity and contact time with each IMU movement. This evaluates whether MIDI velocity predicts measured speed on that exact key action. It cannot calibrate physical angle, displacement, force, or absolute speed, and a mapping learned on a piano must not be transferred to an organ.")
                .font(.callout).foregroundStyle(.secondary)

            HStack {
                Picker("MIDI input", selection: $midi.selectedSourceID) {
                    Text("No MIDI input").tag(nil as String?)
                    ForEach(midi.sources) { source in Text(source.displayName).tag(Optional(source.id)) }
                }
                Text(midi.status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear comparison") { sensor.clearEvaluation() }
            }
            HStack(spacing: 24) {
                calibrationMetric("Paired presses", "\(sensor.midiEvaluation.trialCount)")
                calibrationMetric("Distinct velocities", "\(sensor.midiEvaluation.distinctVelocityCount)")
                calibrationMetric("R²", sensor.midiEvaluation.rSquared.map { String(format: "%.3f", $0) } ?? "—")
                calibrationMetric("RMSE", sensor.midiEvaluation.rmseDPS.map { String(format: "%.1f °/s", $0) } ?? "—")
                calibrationMetric("Comparative predictor", sensor.midiEvaluation.suitableAsComparativePredictor ? "Supported" : "Not established")
            }
            Text(sensor.midiEvaluation.conclusion).font(.caption).foregroundStyle(sensor.midiEvaluation.suitableAsComparativePredictor ? OrgRecTheme.ai : OrgRecTheme.shu)
        }
        .orgRecCard()
    }

    private var validationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("4 · Validate against an independent reference", systemImage: "checkmark.shield").font(.headline)
            Text("After each completed motion, enter the corresponding encoder, laser, high-speed-video, or measured-geometry result. MIDI-only trials validate timing association, not physical displacement.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Picker("Reference", selection: $validationReference) {
                    ForEach(InteractionValidationReference.allCases) { Text($0.displayName).tag($0) }
                }.frame(width: 230)
                TextField("Reference travel (degrees)", text: $validationTravel).frame(width: 200)
                TextField("Reference duration (seconds)", text: $validationDuration).frame(width: 210)
                TextField("Trial note", text: $validationNotes)
                Button("Add latest motion") {
                    if !sensor.addValidationTrial(
                        reference: validationReference,
                        referenceTravelDegrees: Double(validationTravel),
                        referenceDurationSeconds: Double(validationDuration),
                        notes: validationNotes
                    ) {
                        model.errorMessage = "Complete a detected movement before adding a validation trial."
                    }
                }
                .disabled(sensor.motionEvents.isEmpty)
            }
            let summary = sensor.validationSummary
            HStack(spacing: 24) {
                calibrationMetric("Trials", "\(summary.trialCount)")
                calibrationMetric("Independent", "\(summary.independentReferenceTrialCount)")
                calibrationMetric("Travel RMSE", summary.travelRMSEDegrees.map { String(format: "%.3f°", $0) } ?? "—")
                calibrationMetric("Duration RMSE", summary.durationRMSESeconds.map { String(format: "%.4f s", $0) } ?? "—")
                calibrationMetric("Provisional gate", summary.passedExperimentalGate ? "Passed" : "Not passed")
            }
            ForEach(summary.findings, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(.secondary) }
            HStack {
                TextField("Environment / mount / reference setup", text: $validationEnvironment)
                Spacer()
                Button("Save validation session") {
                    if let session = sensor.validationSession(environment: validationEnvironment, notes: validationNotes) {
                        Task { await model.saveInteractionSensorValidation(session) }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(summary.trialCount == 0)
            }
        }
        .orgRecCard()
    }

    private var captureEvidenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("5 · Take capture and retained evidence", systemImage: "externaldrive.badge.checkmark").font(.headline)
                Spacer()
                if sensor.isCapturingTake { Label("Capturing raw IMU stream", systemImage: "record.circle").foregroundStyle(OrgRecTheme.shu) }
            }
            Text("Interaction data is retained only when the operator enables it for that specific standard take. A configured or connected node alone never creates a sensor file. Opted-in takes retain the raw stream, SHA-256, calibration snapshot, health counters, motion events, audio-timeline previews, and clock uncertainty.")
                .font(.callout).foregroundStyle(.secondary)
            Text("The useful pipe-organ sequence is room tone → positive control travel → held sound → negative travel/release → complete acoustic tail. Long-take segmentation and imported captures remain outside this experimental contract.")
                .font(.caption).foregroundStyle(OrgRecTheme.shu)
            if let captures = model.selectedTake?.interactionSensorCaptures, !captures.isEmpty {
                ForEach(captures) { capture in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(capture.configurationSnapshot.name).font(.subheadline.bold())
                            Text(capture.rawRelativePath).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        liveMetric("Packets", "\(capture.health.receivedPackets)")
                        liveMetric("Retained", capture.health.retentionFraction.formatted(.percent.precision(.fractionLength(2))))
                        liveMetric("Events", "\(capture.motionEventCount)")
                        liveMetric("Clock uncertainty", String(format: "%.1f ms", capture.clockAlignment.baseUncertaintySeconds * 1_000))
                    }
                    if let coupling = capture.audioCoupling {
                        HStack(spacing: 24) {
                            liveMetric("Onset after motion start", coupling.onsetAfterMotionStartSeconds.map(formatMilliseconds) ?? "—")
                            liveMetric("Onset after motion end", coupling.onsetAfterMotionEndSeconds.map(formatMilliseconds) ?? "—")
                            liveMetric("Held interval", coupling.heldIntervalSeconds.map { String(format: "%.2f s", $0) } ?? "—")
                            liveMetric("Sound after release", coupling.soundOffsetAfterReleaseStartSeconds.map { String(format: "%.2f s", $0) } ?? "—")
                        }
                        Text(coupling.interpretation).font(.caption2).foregroundStyle(.secondary)
                        ForEach(coupling.warnings, id: \.self) { warning in
                            Text("• \(warning)").font(.caption2).foregroundStyle(OrgRecTheme.shu)
                        }
                    }
                    Divider()
                }
            } else {
                Text("No interaction-sensor evidence is attached to the selected take.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .orgRecCard()
    }

    private func guideStage<Content: View>(number: Int, title: String, detail: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("\(number)").font(.caption.bold()).foregroundStyle(OrgRecTheme.washi).frame(width: 23, height: 23).background(OrgRecTheme.ai, in: Circle()); Text(title).font(.subheadline.bold()) }
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 2)
            content()
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .topLeading)
        .background(OrgRecTheme.recessed, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
    }

    private func liveMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(value).font(.system(.body, design: .rounded, weight: .semibold)).monospacedDigit(); Text(label).font(.caption2).foregroundStyle(.secondary) }
    }

    private func calibrationMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(label).font(.caption).foregroundStyle(.secondary); Text(value).font(.subheadline.bold()).monospacedDigit() }
    }

    private func formatMilliseconds(_ seconds: Double) -> String {
        String(format: "%+.1f ms", seconds * 1_000)
    }

    private func checkSymbol(_ state: InteractionSensorCheckState) -> String {
        switch state { case .pass: "checkmark.circle.fill"; case .warning: "exclamationmark.triangle.fill"; case .fail: "xmark.octagon.fill"; case .pending: "circle.dotted" }
    }

    private func checkColor(_ state: InteractionSensorCheckState) -> Color {
        switch state { case .pass: OrgRecTheme.ai; case .warning, .fail: OrgRecTheme.shu; case .pending: OrgRecTheme.secondaryText }
    }

    private func loadProjectConfiguration() {
        if let configuration = model.activeInteractionSensorConfiguration {
            draft = configuration
            if draft.capturePolicy == .required { draft.capturePolicy = .optional }
            sensor.applyCalibration(model.activeInteractionSensorCalibration)
        } else {
            draft = InteractionSensorConfiguration(sensorDeviceID: UUID())
        }
    }

    private func saveDraft() async {
        if draft.sensorDeviceID == nil { draft.sensorDeviceID = UUID() }
        if draft.capturePolicy == .required { draft.capturePolicy = .optional }
        await model.saveInteractionSensorConfiguration(draft)
    }

    private func connectDraft() {
        do { try sensor.connect(configuration: draft, calibration: acceptedCalibration) }
        catch { model.errorMessage = error.localizedDescription }
    }
}

private struct OptionalNumberField: View {
    @Binding var value: Double?
    let placeholder: String
    let suffix: String

    var body: some View {
        HStack {
            TextField(placeholder, text: Binding(
                get: { value.map { String(format: "%.3f", $0) } ?? "" },
                set: { value = Double($0.replacingOccurrences(of: ",", with: ".")) }
            ))
            Text(suffix).foregroundStyle(.secondary)
        }
    }
}

private struct SensorLiveTrace: View {
    let points: [InteractionSensorLivePoint]

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(x: 8, y: 8, width: max(1, size.width - 16), height: max(1, size.height - 16))
            var border = Path(); border.addRoundedRect(in: rect, cornerSize: CGSize(width: 4, height: 4))
            context.stroke(border, with: .color(OrgRecTheme.hairline), lineWidth: 1)
            guard points.count > 1 else {
                context.draw(Text("Connect a sensor or simulation to inspect movement immediately").font(.caption).foregroundColor(OrgRecTheme.secondaryText), at: CGPoint(x: rect.midX, y: rect.midY))
                return
            }
            let angles = points.map(\.angleDegrees)
            let velocities = points.map(\.angularVelocityDPS)
            draw(values: angles, range: paddedRange(angles, minimumSpan: 5), rect: rect, color: OrgRecTheme.shu, context: &context)
            draw(values: velocities, range: paddedRange(velocities, minimumSpan: 50), rect: rect, color: OrgRecTheme.ai.opacity(0.65), context: &context)
            context.draw(Text("angle").font(.caption2).foregroundColor(OrgRecTheme.shu), at: CGPoint(x: rect.minX + 24, y: rect.minY + 10))
            context.draw(Text("angular rate").font(.caption2).foregroundColor(OrgRecTheme.ai), at: CGPoint(x: rect.minX + 90, y: rect.minY + 10))
        }
        .background(OrgRecTheme.recessed, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
    }

    private func paddedRange(_ values: [Double], minimumSpan: Double) -> ClosedRange<Double> {
        let low = values.min() ?? 0, high = values.max() ?? 0
        let span = max(minimumSpan, high - low)
        let midpoint = (low + high) / 2
        return (midpoint - span * 0.55)...(midpoint + span * 0.55)
    }

    private func draw(values: [Double], range: ClosedRange<Double>, rect: CGRect, color: Color, context: inout GraphicsContext) {
        guard values.count > 1 else { return }
        var path = Path()
        for index in values.indices {
            let x = rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1)
            let normalized = (values[index] - range.lowerBound) / max(0.000_001, range.upperBound - range.lowerBound)
            let y = rect.maxY - rect.height * CGFloat(min(max(normalized, 0), 1))
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
    }
}
