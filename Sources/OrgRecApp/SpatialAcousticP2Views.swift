import SwiftUI
import OrgRecCore

struct SpatialAcousticPlannerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var sourceComponentID = ""
    @State private var customSourceLabel = ""
    @State private var geometryName = "Organ chamber geometry"
    @State private var origin = "Organ façade center at floor level"
    @State private var xAxis = "positive to audience right"
    @State private var yAxis = "positive toward the nave"
    @State private var zAxis = "positive upward"
    @State private var evidence: SpatialEvidenceSource = .operatorEstimated
    @State private var uncertainty = 0.25
    @State private var selectedSetupIDs = Set<UUID>()
    @State private var elements = [P2GeometryDraft.defaultsSource, .defaultsEnclosure, .defaultsShutter, .defaultsScreen]
    @State private var sourceElementID = P2GeometryDraft.defaultsSource.id
    @State private var pathElementIDs = Set([P2GeometryDraft.defaultsEnclosure.id, P2GeometryDraft.defaultsShutter.id, P2GeometryDraft.defaultsScreen.id])
    @State private var states = [
        P2ResponseStateDraft(id: "open", label: "Open reference", assignments: "Expression shutters=open\nChamber screen=installed"),
        P2ResponseStateDraft(id: "closed", label: "Closed", assignments: "Expression shutters=closed\nChamber screen=installed")
    ]
    @State private var referenceStateID = "open"
    @State private var minimumTakes = 2
    @State private var duration = 10.0
    @State private var techniques = Set<CaptureTechnique>()
    @State private var required = true
    @State private var excitation: SpatialAcousticExcitation = .instrumentResponse

    private var components: [OrganComponent] {
        (model.project?.organComponents ?? []).sorted {
            "\($0.division)|\($0.label)".localizedStandardCompare("\($1.division)|\($1.label)") == .orderedAscending
        }
    }
    private var selectedTechniques: [CaptureTechnique] { CaptureTechnique.allCases.filter(techniques.contains) }
    private var canSubmit: Bool {
        (!sourceComponentID.isEmpty || !customSourceLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && selectedSetupIDs.isEmpty == false && selectedTechniques.isEmpty == false
            && elements.contains(where: { $0.id == sourceElementID && [.rank, .effect].contains($0.kind) })
            && states.count >= 2 && states.contains(where: { $0.id == referenceStateID })
            && states.allSatisfy { !$0.id.isEmpty && !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("P2 spatial response planner").font(.title2.bold())
                    Text("Document source/path geometry, then compile comparable in-situ response states.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Add response series") { addPlan() }
                    .buttonStyle(.borderedProminent).disabled(!canSubmit)
            }
            .padding(20)
            Divider()
            Form {
                Section("Scientific interpretation") {
                    Label("The result is an in-situ state-dependent response—not an isolated shutter transfer function.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(OrgRecTheme.shu)
                    Text("Source position and spectrum, enclosure, screen, shutter state, room, gain, and microphone geometry must remain controlled. OrgRec only compares accepted takes with the same series, geometry fingerprint, setup, technique, and reference channel.")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Excitation and analysis qualification", selection: $excitation) {
                        ForEach(SpatialAcousticExcitation.allCases) { value in
                            Text(value.displayName).tag(value)
                        }
                    }
                    Text(excitation.explanation)
                        .font(.caption).foregroundStyle(.secondary)
                    if excitation == .deconvolvedSweepResponse {
                        Label("Provide the deconvolved impulse response—not the raw sine sweep.", systemImage: "waveform.badge.exclamationmark")
                            .font(.caption).foregroundStyle(OrgRecTheme.shu)
                    }
                }
                Section("Acoustic source and microphone frame") {
                    Picker("Source component", selection: $sourceComponentID) {
                        Text("Operator-defined source").tag("")
                        ForEach(components) { Text("\($0.division) · \($0.label)").tag($0.id) }
                    }
                    if sourceComponentID.isEmpty { TextField("Source name", text: $customSourceLabel) }
                    TextField("Geometry name", text: $geometryName)
                    TextField("Coordinate origin", text: $origin)
                    Grid(alignment: .leading) {
                        GridRow { Text("X axis"); TextField("Direction", text: $xAxis) }
                        GridRow { Text("Y axis"); TextField("Direction", text: $yAxis) }
                        GridRow { Text("Z axis"); TextField("Direction", text: $zAxis) }
                    }
                    HStack {
                        Picker("Evidence", selection: $evidence) { ForEach(SpatialEvidenceSource.allCases) { Text($0.displayName).tag($0) } }
                        LabeledContent("Position uncertainty") {
                            HStack { Slider(value: $uncertainty, in: 0...5, step: 0.01); Text("\(uncertainty.formatted(.number.precision(.fractionLength(2)))) m").monospacedDigit() }.frame(width: 280)
                        }
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Microphone setups sharing this origin and axes").font(.caption.bold())
                        if model.project?.setups.isEmpty != false { Text("Create a microphone setup first.").foregroundStyle(OrgRecTheme.shu) }
                        ForEach(model.project?.setups ?? []) { setup in
                            Toggle("\(setup.name) · revision \(setup.revision)", isOn: setBinding(setup.id, in: $selectedSetupIDs)).toggleStyle(.checkbox)
                        }
                    }
                }
                Section("Ranks, effects, shutters, enclosures, and screens") {
                    GeometryPlanPreview(elements: elements.map(\.element)).frame(height: 170)
                    ForEach($elements) { $element in
                        P2GeometryDraftRow(element: $element, allElements: elements, sourceElementID: $sourceElementID, pathElementIDs: $pathElementIDs, canDelete: elements.count > 1) {
                            elements.removeAll { $0.id == element.id }; pathElementIDs.remove(element.id)
                            if sourceElementID == element.id { sourceElementID = elements.first(where: { [.rank, .effect].contains($0.kind) })?.id ?? "" }
                        }
                    }
                    Button("Add geometry element", systemImage: "plus") { elements.append(P2GeometryDraft()) }
                    Text("Coordinates and extents are metres in the frame above. Parent relationships document containment; source and propagation-path roles are explicit.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Response states") {
                    ForEach($states) { $state in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                TextField("Stable state ID", text: $state.id).frame(width: 150)
                                TextField("State label", text: $state.label)
                                Toggle("Reference", isOn: Binding(get: { referenceStateID == state.id }, set: { if $0 { referenceStateID = state.id } })).toggleStyle(.checkbox)
                                if states.count > 2 { Button(role: .destructive) { states.removeAll { $0.localID == state.localID } } label: { Image(systemName: "trash") } }
                            }
                            Text("Exact assignments · one Label=value per line").font(.caption.bold())
                            TextEditor(text: $state.assignments).font(.body.monospaced()).frame(height: 64)
                        }
                        .padding(9).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                    }
                    Button("Add response state", systemImage: "plus") { states.append(P2ResponseStateDraft(id: "state-\(states.count + 1)", label: "State \(states.count + 1)", assignments: "")) }
                }
                Section("Coverage") {
                    HStack {
                        Stepper("Accepted takes per state: \(minimumTakes)", value: $minimumTakes, in: 1...20)
                        LabeledContent("Capture duration") { HStack { Slider(value: $duration, in: 1...120); Text("\(duration.formatted(.number.precision(.fractionLength(0)))) s") }.frame(width: 260) }
                        Toggle("Required", isOn: $required)
                    }
                    HStack {
                        ForEach(model.project?.recipe.techniques ?? CaptureTechnique.allCases) { technique in
                            Toggle(technique.rawValue, isOn: setBinding(technique, in: $techniques)).toggleStyle(.checkbox)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 980, minHeight: 780)
        .onAppear {
            if selectedSetupIDs.isEmpty { selectedSetupIDs = Set(model.project?.setups.map(\.id) ?? []) }
            if techniques.isEmpty { techniques = Set(model.project?.recipe.techniques ?? []) }
        }
    }

    private func addPlan() {
        let frame = SpatialGeometryReferenceFrame(originDescription: origin, xAxisDescription: xAxis, yAxisDescription: yAxis, zAxisDescription: zAxis, compatibleMicrophoneSetupIDs: Array(selectedSetupIDs), evidence: evidence, uncertaintyMeters: uncertainty)
        let geometry = SpatialGeometrySnapshot(name: geometryName, referenceFrame: frame, elements: elements.map(\.element), notes: "P2 operator-authored organ source and acoustic-path geometry.")
        let responseStates = states.map { draft in
            SpatialResponseState(id: draft.id.trimmingCharacters(in: .whitespacesAndNewlines), label: draft.label.trimmingCharacters(in: .whitespacesAndNewlines), assignments: parseAssignments(draft.assignments), notes: "Operator-defined P2 response state.")
        }
        let request = SpatialAcousticPlanRequest(
            geometry: geometry, sourceComponentID: sourceComponentID.isEmpty ? nil : sourceComponentID,
            customSourceLabel: customSourceLabel, sourceElementID: sourceElementID,
            pathElementIDs: elements.filter { pathElementIDs.contains($0.id) }.map(\.id), states: responseStates,
            referenceStateID: referenceStateID, minimumAcceptedTakeCount: minimumTakes,
            plannedDurationSeconds: duration, techniques: selectedTechniques,
            orderedSetupIDs: (model.project?.setups ?? []).map(\.id).filter(selectedSetupIDs.contains), required: required,
            excitation: excitation
        )
        Task { @MainActor in await model.addSpatialAcousticPlan(request); if model.errorMessage == nil { dismiss() } }
    }

    private func parseAssignments(_ text: String) -> [CaptureStateAssignment] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let parts = line.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
            let label = parts[0], value = parts[1]
            return CaptureStateAssignment(
                subjectComponentID: "p2-state:\(Data(label.lowercased().utf8).sha256Hex.prefix(16))", subjectLabel: label,
                dimension: label.localizedCaseInsensitiveContains("screen") || label.localizedCaseInsensitiveContains("enclosure") ? .enclosure : .shutter,
                valueKind: .discrete, textValue: value, evidence: "operator-planned-p2-response"
            )
        }
    }

    private func setBinding<T: Hashable>(_ value: T, in set: Binding<Set<T>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { enabled in if enabled { set.wrappedValue.insert(value) } else { set.wrappedValue.remove(value) } })
    }
}

private struct P2GeometryDraft: Identifiable, Hashable {
    var id = "geometry-\(UUID().uuidString.lowercased())"
    var componentID = ""
    var label = "New element"
    var kind: SpatialGeometryElementKind = .screen
    var parentID = ""
    var x = 0.0, y = 0.0, z = 0.0
    var yaw = 0.0, pitch = 0.0, roll = 0.0
    var width = 0.0, height = 0.0, depth = 0.0
    var distribution: SpatialSourceDistribution = .area
    var material = ""
    var openAreaRatio = 0.0
    var thickness = 0.0
    var evidence: SpatialEvidenceSource = .operatorEstimated
    var uncertainty = 0.25
    var notes = ""
    var element: SpatialGeometryElement {
        SpatialGeometryElement(id: id, componentID: componentID.isEmpty ? nil : componentID, label: label, kind: kind,
                               parentElementID: parentID.isEmpty ? nil : parentID,
                               position: SpatialPoint3D(xMeters: x, yMeters: y, zMeters: z),
                               orientation: SpatialOrientation3D(yawDegrees: yaw, pitchDegrees: pitch, rollDegrees: roll),
                               extent: SpatialExtent3D(widthMeters: width, heightMeters: height, depthMeters: depth), distribution: distribution,
                               material: material, openAreaRatio: [.screen, .shutter].contains(kind) ? openAreaRatio : nil,
                               thicknessMeters: thickness > 0 ? thickness : nil, evidence: evidence, uncertaintyMeters: uncertainty, notes: notes)
    }
    static let defaultsSource = P2GeometryDraft(id: "source-rank", label: "Source rank / effect", kind: .rank, x: 0, y: -1, z: 4, width: 3, height: 3, depth: 1, distribution: .volume)
    static let defaultsEnclosure = P2GeometryDraft(id: "enclosure", label: "Expression enclosure", kind: .enclosure, x: 0, y: -0.5, z: 3, width: 5, height: 5, depth: 3, distribution: .volume, material: "wood/masonry")
    static let defaultsShutter = P2GeometryDraft(id: "shutters", label: "Expression shutters", kind: .shutter, parentID: "enclosure", x: 0, y: 1, z: 4, width: 4, height: 2, distribution: .area, material: "wood", openAreaRatio: 1)
    static let defaultsScreen = P2GeometryDraft(id: "screen", label: "Façade / chamber screen", kind: .screen, x: 0, y: 1.5, z: 4, width: 5, height: 5, distribution: .area, material: "wood/fabric", openAreaRatio: 0.5)
}

private struct P2ResponseStateDraft: Identifiable {
    let localID = UUID()
    var id: String
    var label: String
    var assignments: String
}

private struct P2GeometryDraftRow: View {
    @Binding var element: P2GeometryDraft
    let allElements: [P2GeometryDraft]
    @Binding var sourceElementID: String
    @Binding var pathElementIDs: Set<String>
    let canDelete: Bool
    let delete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                TextField("Label", text: $element.label).font(.headline)
                Picker("Kind", selection: $element.kind) { ForEach(SpatialGeometryElementKind.allCases) { Text($0.displayName).tag($0) } }.frame(width: 150)
                Toggle("Source", isOn: Binding(get: { sourceElementID == element.id }, set: { if $0 { sourceElementID = element.id } })).toggleStyle(.checkbox).disabled(![.rank, .effect].contains(element.kind))
                Toggle("Path", isOn: Binding(get: { pathElementIDs.contains(element.id) }, set: { if $0 { pathElementIDs.insert(element.id) } else { pathElementIDs.remove(element.id) } })).toggleStyle(.checkbox).disabled([.rank, .effect].contains(element.kind))
                if canDelete { Button(role: .destructive, action: delete) { Image(systemName: "trash") } }
            }
            HStack {
                Picker("Parent", selection: $element.parentID) { Text("No parent").tag(""); ForEach(allElements.filter { $0.id != element.id }) { Text($0.label).tag($0.id) } }.frame(width: 210)
                Picker("Distribution", selection: $element.distribution) { ForEach(SpatialSourceDistribution.allCases) { Text($0.displayName).tag($0) } }.frame(width: 150)
                TextField("Material", text: $element.material)
            }
            Grid(alignment: .leading, horizontalSpacing: 8) {
                GridRow { Text("Position x/y/z"); number($element.x); number($element.y); number($element.z); Text("m").foregroundStyle(.secondary) }
                GridRow { Text("Extent w/h/d"); number($element.width); number($element.height); number($element.depth); Text("m").foregroundStyle(.secondary) }
                GridRow { Text("Yaw/pitch/roll"); number($element.yaw); number($element.pitch); number($element.roll); Text("°").foregroundStyle(.secondary) }
                GridRow { Text("Open area / thickness"); number($element.openAreaRatio); number($element.thickness); Text(""); Text("ratio / m").foregroundStyle(.secondary) }
            }
        }
        .padding(9).background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }
    private func number(_ value: Binding<Double>) -> some View { TextField("0", value: value, format: .number).textFieldStyle(.roundedBorder).frame(width: 82) }
}

struct GeometryPlanPreview: View {
    let elements: [SpatialGeometryElement]
    var body: some View {
        Canvas { context, size in
            guard !elements.isEmpty else { return }
            let xs = elements.map { $0.position.xMeters }, ys = elements.map { $0.position.yMeters }
            let minX = (xs.min() ?? 0) - 1, maxX = (xs.max() ?? 0) + 1, minY = (ys.min() ?? 0) - 1, maxY = (ys.max() ?? 0) + 1
            func point(_ element: SpatialGeometryElement) -> CGPoint {
                CGPoint(x: 18 + (element.position.xMeters - minX) / max(0.001, maxX - minX) * (size.width - 36),
                        y: size.height - 18 - (element.position.yMeters - minY) / max(0.001, maxY - minY) * (size.height - 36))
            }
            for element in elements {
                let p = point(element), color: Color = [.rank, .effect].contains(element.kind) ? OrgRecTheme.ai : OrgRecTheme.shu
                let radius = [.rank, .effect].contains(element.kind) ? 7.0 : 5.0
                context.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
                context.draw(Text(element.label).font(.caption2).foregroundStyle(.primary), at: CGPoint(x: p.x + 6, y: p.y - 8), anchor: .leading)
            }
        }
        .background(.quaternary.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topLeading) { Text("Plan view · x/y metres").font(.caption2).foregroundStyle(.secondary).padding(7) }
    }
}

struct SpatialAcousticProtocolSummary: View {
    let protocolSnapshot: SpatialAcousticCaptureProtocol
    let acceptedCount: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("P2 in-situ spatial response", systemImage: "cube.transparent").font(.headline)
            Text("\(protocolSnapshot.targetState.label)\(protocolSnapshot.isReferenceState ? " · reference" : "") · \(acceptedCount)/\(protocolSnapshot.minimumAcceptedTakeCount) accepted")
            Text("Geometry \(protocolSnapshot.geometryFingerprint.prefix(12)) · source \(protocolSnapshot.sourceElementID) · path \(protocolSnapshot.pathElementIDs.joined(separator: " → "))")
                .font(.caption.monospaced()).foregroundStyle(.secondary)
            Text(protocolSnapshot.limitationStatement).font(.caption).foregroundStyle(OrgRecTheme.shu)
        }
    }
}

struct SpatialAcousticCaptureControl: View {
    @EnvironmentObject private var model: AppModel
    let protocolSnapshot: SpatialAcousticCaptureProtocol
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            P2ProtocolStep(number: "1", text: "Physically set and verify \(protocolSnapshot.targetState.label).")
            P2ProtocolStep(number: "2", text: "Mark state confirmed, then mark/trigger the identical acoustic source.")
            P2ProtocolStep(number: "3", text: "Hold/complete the response for \(Int(protocolSnapshot.plannedDurationSeconds)) s; retain the tail.")
            if model.capture.isRecording {
                HStack {
                    Button("Confirm state") { mark(.stateConfirmed) }
                    Button("Mark source trigger") { mark(.sourceTriggered) }
                    Button("Mark stable") { mark(.responseStable) }
                    Button("Mark variation") { mark(.notableVariation) }
                }
            }
        }
    }
    private func mark(_ kind: SpatialAcousticEventKind) { Task { await model.markSpatialAcousticEvent(kind) } }
}

private struct P2ProtocolStep: View {
    let number: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text(number).font(.caption.monospacedDigit().bold()).foregroundStyle(.white)
                .frame(width: 23, height: 23).background(OrgRecTheme.ai, in: Circle())
            Text(text).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SpatialAcousticTakeReview: View {
    let paradata: SpatialAcousticTakeParadata
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("P2 spatial-response evidence").font(.headline)
            HStack { metric("State", paradata.protocolSnapshot.targetState.label); metric("Repetition", "\(paradata.repetitionNumber)"); metric("Events", "\(paradata.events.count)"); metric("Excitation", paradata.protocolSnapshot.effectiveExcitation.displayName) }
            if let value = paradata.observation {
                HStack { metric("Peak", db(value.peakDBFS)); metric("RMS", db(value.rmsDBFS)); metric("Latency", seconds(value.onsetLatencySeconds)); metric("Impulse width", seconds(value.effectiveImpulseWidthSeconds)); metric("Distance", value.sourceToReferenceMicrophoneDistanceMeters.map { "\($0.formatted(.number.precision(.fractionLength(2)))) m" } ?? "—") }
                P2BandBarChart(levels: value.thirdOctaveBandLevels)
                if let response = value.acousticResponseAnalysis {
                    P2RoomResponseEvidence(analysis: response)
                } else if paradata.protocolSnapshot.effectiveExcitation.responseQualification != nil {
                    Label("No qualified room-response metrics were produced; inspect the response duration, direct arrival, and noise floor.", systemImage: "waveform.badge.exclamationmark")
                        .font(.caption).foregroundStyle(OrgRecTheme.shu)
                }
                ForEach(value.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(OrgRecTheme.shu) }
            } else { Label("Run analysis to create the response observation.", systemImage: "waveform.badge.magnifyingglass") }
        }
    }
    private func metric(_ label: String, _ value: String) -> some View { VStack(alignment: .leading) { Text(label).font(.caption).foregroundStyle(.secondary); Text(value).monospacedDigit() }.frame(maxWidth: .infinity, alignment: .leading) }
    private func db(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(1)))) dBFS" }
    private func seconds(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(3)))) s" } ?? "—" }
}

private struct P2RoomResponseEvidence: View {
    let analysis: AcousticResponseAnalysis
    private let columns = [GridItem(.adaptive(minimum: 122), spacing: 7)]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Label("Qualified room-response metrics", systemImage: "building.columns.circle")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(analysis.broadband.usableDecayRangeDB.formatted(.number.precision(.fractionLength(1)))) dB usable")
                    .font(.caption.monospacedDigit())
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 7) {
                cell("EDT", fit(analysis.broadband.edt))
                cell("T20", fit(analysis.broadband.t20))
                cell("T30", fit(analysis.broadband.t30))
                cell("C₅₀", decibels(analysis.broadband.clarity50DB))
                cell("C₈₀", decibels(analysis.broadband.clarity80DB))
                cell("D₅₀", analysis.broadband.definition50?.formatted(.percent.precision(.fractionLength(0))) ?? "—")
                cell("Center time", seconds(analysis.broadband.centerTimeSeconds))
                cell("D/R", decibels(analysis.broadband.directToReverberantRatioDB))
            }
            if let multi = analysis.broadband.multiSlope {
                Label("Multi-slope decay: \(multi.earlyDecayTimeSeconds.formatted(.number.precision(.fractionLength(2)))) s → \(multi.lateDecayTimeSeconds.formatted(.number.precision(.fractionLength(2)))) s · ΔBIC \(multi.deltaBIC.formatted(.number.precision(.fractionLength(1))))", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                    .font(.caption.bold()).foregroundStyle(OrgRecTheme.shu)
            }
            if !analysis.octaveBands.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 5) {
                        ForEach(analysis.octaveBands) { band in
                            VStack(spacing: 2) {
                                Text(label(band.centerFrequencyHz)).font(.caption2.bold())
                                Text(band.t20.map { "\($0.extrapolatedDecayTimeSeconds.formatted(.number.precision(.fractionLength(2)))) s" } ?? "—")
                                    .font(.caption.monospacedDigit())
                            }
                            .frame(width: 62).padding(5)
                            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
                .accessibilityLabel("Octave-band T20 estimates")
            }
            Text(analysis.conformanceStatement).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(9).background(OrgRecTheme.ai.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
    }
    private func cell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit().bold()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func fit(_ value: AcousticDecayFit?) -> String { value.map { "\($0.extrapolatedDecayTimeSeconds.formatted(.number.precision(.fractionLength(2)))) s · R² \($0.coefficientOfDetermination.formatted(.number.precision(.fractionLength(2))))" } ?? "—" }
    private func seconds(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(3)))) s" } ?? "—" }
    private func decibels(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(1)))) dB" } ?? "—" }
    private func label(_ value: Double?) -> String {
        guard let value else { return "BB" }
        return value >= 1_000 ? "\((value / 1_000).formatted(.number.precision(.fractionLength(0...1))))k" : value.formatted(.number.precision(.fractionLength(0)))
    }
}

struct EffectAnalysisReview: View {
    let result: EffectAnalysisResult
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("P2 non-pitched effect analytics").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 6) {
                GridRow { cell("Latency", seconds(result.latencySeconds)); cell("Peak", db(result.peakDBFS)); cell("RMS", db(result.rmsDBFS)); cell("Impulse width", seconds(result.effectiveImpulseWidthSeconds)) }
                GridRow { cell("Events", "\(result.repetitionEventCount)"); cell("Rate", hz(result.repetitionRateHz)); cell("Periodicity", result.periodicityConfidence.map { "\($0.formatted(.percent.precision(.fractionLength(0)))) @ \(hz(result.periodicityRateHz))" } ?? "—"); cell("Stochasticity", result.stochasticityIndex?.formatted(.number.precision(.fractionLength(3))) ?? "—") }
                GridRow { cell("Interval μ", seconds(result.intervalMeanSeconds)); cell("Interval σ", seconds(result.intervalStandardDeviationSeconds)); cell("CV", result.intervalCoefficientOfVariation?.formatted(.number.precision(.fractionLength(3))) ?? "—"); cell("Entropy", result.temporalEntropy?.formatted(.number.precision(.fractionLength(3))) ?? "—") }
            }
            if !result.chainStageTimings.isEmpty {
                Divider(); Text("Chain stages").font(.subheadline.bold())
                ForEach(result.chainStageTimings) { timing in Text("\(timing.label): \(seconds(timing.durationSeconds)) · Δ \(seconds(timing.deviationSeconds)) · \(timing.evidence.rawValue)").font(.caption.monospacedDigit()) }
            }
            ForEach(result.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(OrgRecTheme.shu) }
        }
    }
    private func cell(_ label: String, _ value: String) -> some View { VStack(alignment: .leading) { Text(label).font(.caption).foregroundStyle(.secondary); Text(value).monospacedDigit() }.frame(minWidth: 120, alignment: .leading) }
    private func seconds(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(3)))) s" } ?? "—" }
    private func db(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(1)))) dBFS" }
    private func hz(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(2)))) Hz" } ?? "—" }
}

struct SpatialResponseComparisonsPanel: View {
    let comparisons: [SpatialAcousticResponseComparison]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("P2 state-dependent response comparisons").font(.headline)
            ForEach(comparisons) { comparison in
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(comparison.stateID) vs \(comparison.referenceStateID) · \(comparison.captureTechnique.rawValue)").font(.subheadline.bold())
                    Text("RMS Δ \(delta(comparison.rmsLevelDeltaDB)) · peak Δ \(delta(comparison.peakLevelDeltaDB)) · latency Δ \(seconds(comparison.onsetLatencyDeltaSeconds)) · n \(comparison.referenceTakeIDs.count)/\(comparison.targetTakeIDs.count)")
                        .font(.caption.monospacedDigit())
                    if comparison.referenceRMSStandardDeviationDB != nil || comparison.targetRMSStandardDeviationDB != nil {
                        Text("RMS variability σ: reference \(spread(comparison.referenceRMSStandardDeviationDB)) · target \(spread(comparison.targetRMSStandardDeviationDB))")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    P2DeltaBarChart(deltas: comparison.thirdOctaveBandDeltas)
                    Text(comparison.limitationStatement).font(.caption2).foregroundStyle(.secondary)
                }
                .padding(9).background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    private func delta(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))) dB" } ?? "—" }
    private func seconds(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(3)).sign(strategy: .always()))) s" } ?? "—" }
    private func spread(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(2)))) dB" } ?? "—" }
}

private struct P2BandBarChart: View {
    let levels: [SpectralBandLevel]
    var body: some View { GeometryReader { proxy in HStack(alignment: .bottom, spacing: 1) { ForEach(levels) { band in Rectangle().fill(OrgRecTheme.ai.opacity(0.75)).frame(width: max(1, proxy.size.width / CGFloat(max(1, levels.count)) - 1), height: max(1, proxy.size.height * CGFloat(min(1, max(0, (band.levelDBFS + 100) / 100))))) } } }.frame(height: 62).accessibilityLabel("Third-octave level spectrum") }
}
private struct P2DeltaBarChart: View {
    let deltas: [SpatialBandDelta]
    var body: some View {
        Canvas { context, size in
            let midpoint = size.height / 2
            var baseline = Path(); baseline.move(to: CGPoint(x: 0, y: midpoint)); baseline.addLine(to: CGPoint(x: size.width, y: midpoint))
            context.stroke(baseline, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
            let slot = size.width / CGFloat(max(1, deltas.count))
            for (index, delta) in deltas.enumerated() {
                let height = CGFloat(min(1, abs(delta.levelDeltaDB) / 30)) * midpoint
                let rect = CGRect(x: CGFloat(index) * slot + 0.5, y: delta.levelDeltaDB >= 0 ? midpoint - height : midpoint,
                                  width: max(1, slot - 1), height: max(1, height))
                context.fill(Path(rect), with: .color(delta.levelDeltaDB >= 0 ? OrgRecTheme.ai : OrgRecTheme.shu))
            }
        }
        .frame(height: 70)
        .accessibilityLabel("Third-octave level deltas")
    }
}
