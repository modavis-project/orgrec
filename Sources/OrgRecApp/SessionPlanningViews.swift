import OrgRecCore
import SwiftUI

struct SessionPlanRoadmapBanner: View {
    @EnvironmentObject private var model: AppModel
    let plan: RecordingSessionPlan
    let edit: () -> Void
    let showMap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: plan.status == .active ? "record.circle.fill" : "calendar.badge.checkmark")
                .font(.title2)
                .foregroundStyle(plan.status == .active ? OrgRecTheme.shu : OrgRecTheme.ai)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(plan.title).font(.headline)
                    Text(plan.status.rawValue.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
                    Text("rev. \(plan.revision)").font(.caption2.monospaced()).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    if let progress = model.planQueueProgress(plan) {
                        Text("\(progress.completed)/\(progress.total) accepted")
                    }
                    Text(duration(plan.estimatedTotalSeconds))
                    if let assessment = model.noiseContext(for: plan) {
                        Text("\(assessment.actionableFindings.count) noise indicators")
                    }
                    Text(plan.plannedStart.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Map", action: showMap).disabled(model.noiseContext(for: plan) == nil)
            Button("Revise", action: edit)
            if plan.status == .frozen {
                Button("Start session") { Task { await model.startSessionPlan(plan.id) } }
                    .buttonStyle(.borderedProminent)
            } else if let next = nextItem {
                Button("Open next") { model.select(next) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .orgRecCard(inset: 13)
    }

    private var nextItem: RoadmapItem? {
        guard let project = model.project else { return nil }
        return SessionPlanningEngine.nextPlannedRoadmapItem(in: project, session: model.activeSession)
    }

    private func duration(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min estimated" : "\(minutes) min estimated"
    }
}

struct NoiseContextCaptureCard: View {
    @EnvironmentObject private var model: AppModel
    @State private var showMap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Surrounding noise", systemImage: "waveform.badge.magnifyingglass")
                        .font(.headline)
                    if let assessment = model.activeNoiseContext {
                        Text(assessment.summary).font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text("No map-based assessment is frozen into this session. Document conditions in Field QA or plan the next session from the Roadmap.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Map") { showMap = true }.disabled(model.activeNoiseContext == nil)
            }
            if let assessment = model.activeNoiseContext {
                HStack(spacing: 10) {
                    ForEach(Array(assessment.actionableFindings.prefix(4))) { finding in
                        Label(
                            finding.distanceMeters.map { "\(finding.label) · \(Int($0.rounded())) m" } ?? finding.label,
                            systemImage: finding.planningPriority == .high ? "exclamationmark.triangle.fill" : "mappin"
                        )
                        .font(.caption)
                        .foregroundStyle(finding.planningPriority == .high ? OrgRecTheme.shu : .secondary)
                        .lineLimit(1)
                    }
                    Spacer()
                }
            }
            if model.capture.isRecording, model.isLongTakeRecording == false {
                Divider()
                HStack {
                    Text("Mark audible incident").font(.caption.bold())
                    Button("Traffic") { mark(.mainRoad, "Audible road traffic") }
                    Button("Rail/tram") { mark(.railOrTram, "Audible rail or tram movement") }
                    Button("Siren") { mark(.emergencyOrHealthcare, "Audible emergency siren") }
                    Button("Construction") { mark(.construction, "Audible construction activity") }
                    Button("Crowd/event") { mark(.sportsOrEvents, "Audible crowd, bell, or event activity") }
                }
                .controlSize(.small)
            }
        }
        .orgRecCard()
        .sheet(isPresented: $showMap) {
            if let assessment = model.activeNoiseContext { NoiseContextMapSheet(assessment: assessment) }
        }
    }

    private func mark(_ category: NoiseSourceCategory, _ label: String) {
        Task { await model.markNoiseIncident(category: category, label: label) }
    }
}

struct RecordingSessionPlannerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let editingPlanID: UUID?

    @State private var step: PlannerStep = .session
    @State private var planID = UUID()
    @State private var title = ""
    @State private var purpose = "Systematic pipe-organ recording"
    @State private var operatorName = NSFullUserName()
    @State private var institution = ""
    @State private var plannedStart = Date()
    @State private var plannedEnd = Date().addingTimeInterval(4 * 3_600)
    @State private var accessNotes = ""
    @State private var preflightNotes = ""
    @State private var selectedRoadmapIDs = Set<UUID>()
    @State private var queue: [SessionPlanQueueItem] = []
    @State private var contingencyPercent = 15.0
    @State private var venueQuery = ""
    @State private var venueLocationContext = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var venueAnchor: VenueAnchor?
    @State private var assessment: NoiseContextAssessment?
    @State private var radiusMeters = 750.0
    @State private var manualNoiseLabel = ""
    @State private var manualNoiseCategory: NoiseSourceCategory = .manual
    @State private var manualNoisePriority: NoisePlanningPriority = .medium
    @State private var showMap = false
    @State private var didLoad = false
    @State private var scopeRecoveryNotice = ""

    init(editingPlanID: UUID? = nil) {
        self.editingPlanID = editingPlanID
    }

    private var project: OrgRecProject? { model.project }
    private var eligibleItems: [RoadmapItem] {
        project.map(SessionPlanningEngine.plannableRoadmapItems) ?? []
    }
    private var selectedItems: [RoadmapItem] {
        eligibleItems.filter { selectedRoadmapIDs.contains($0.id) }
    }
    private var orderedQueue: [SessionPlanQueueItem] { queue.sorted { $0.order < $1.order } }
    private var editingPlan: RecordingSessionPlan? {
        guard let editingPlanID else { return nil }
        return project?.sessionPlans?.first { $0.id == editingPlanID }
    }
    private var estimates: (totalSeconds: Double, audioBytes: Int64) {
        guard let project else { return (0, 0) }
        return SessionPlanningEngine.estimates(
            queue: orderedQueue,
            roadmap: project.roadmap,
            sampleRate: model.audioSystem.selectedSampleRate,
            channelCount: max(1, model.audioSystem.selectedDevice?.inputChannels ?? inferredChannelCount),
            contingencyFraction: contingencyPercent / 100
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                stepRail
                Divider()
                Group { content }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(22)
            }
            Divider()
            footer
        }
        .frame(minWidth: 960, minHeight: 690)
        .task { loadOnce() }
        .sheet(isPresented: $showMap) {
            if let assessment { NoiseContextMapSheet(assessment: assessment) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(editingPlanID == nil ? "Plan a recording session" : "Revise recording-session plan")
                    .japaneseSectionTitle()
                Text("Freeze scope, sequence, logistics, and surrounding-noise evidence before fieldwork.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if let project {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(project.organName).font(.callout.bold())
                    Text(project.venueName).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }

    private var stepRail: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(PlannerStep.allCases) { candidate in
                Button {
                    if canVisit(candidate) { step = candidate }
                } label: {
                    HStack(spacing: 9) {
                        Text("\(candidate.rawValue + 1)")
                            .font(.caption.bold())
                            .frame(width: 24, height: 24)
                            .background(candidate == step ? OrgRecTheme.shu : OrgRecTheme.recessed, in: Circle())
                            .foregroundStyle(candidate == step ? Color.white : OrgRecTheme.sumi)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(candidate.title).font(.callout.bold())
                            Text(candidate.detail).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(candidate == step ? OrgRecTheme.shu.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Text("Planning warnings are based on mapped features and operator review. They are not acoustic measurements or a guarantee of quiet conditions.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 220)
        .background(OrgRecTheme.recessed.opacity(0.55))
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .session: sessionStep
        case .scope: scopeStep
        case .venue: venueStep
        case .noise: noiseStep
        case .queue: queueStep
        case .review: reviewStep
        }
    }

    private var sessionStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepTitle("Session intent and access", "Describe the field visit independently of individual takes.")
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
                    GridRow { Text("Title"); TextField("Night recording", text: $title) }
                    GridRow { Text("Purpose"); TextField("Scientific purpose", text: $purpose, axis: .vertical).lineLimit(2...4) }
                    GridRow { Text("Operator"); TextField("Required", text: $operatorName) }
                    GridRow { Text("Institution"); TextField("Optional", text: $institution) }
                    GridRow { Text("Start"); DatePicker("", selection: $plannedStart).labelsHidden() }
                    GridRow { Text("End"); DatePicker("", selection: $plannedEnd).labelsHidden() }
                    GridRow { Text("Access"); TextField("Keys, permissions, building access, contacts", text: $accessNotes, axis: .vertical).lineLimit(2...5) }
                }
                .textFieldStyle(.roundedBorder)
                Text("The planned times remain planning metadata; actual session start/end timestamps are recorded separately.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var scopeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Roadmap scope", "Select obligations for this visit without changing their scientific roadmap state.")
            HStack {
                Text("\(selectedRoadmapIDs.count) of \(eligibleItems.count) available items selected")
                    .font(.callout.bold())
                Spacer()
                Button("Select all") { selectedRoadmapIDs = Set(eligibleItems.map(\.id)); rebuildQueue() }
                Button("Clear") { selectedRoadmapIDs.removeAll(); rebuildQueue() }
            }
            if scopeRecoveryNotice.isEmpty == false {
                Label(scopeRecoveryNotice, systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundStyle(OrgRecTheme.shu)
                    .orgRecCard(inset: 10)
            }
            List {
                ForEach(groupedEligibleItems, id: \.division) { group in
                    Section(group.division) {
                        ForEach(group.items) { item in
                            Button {
                                if selectedRoadmapIDs.contains(item.id) { selectedRoadmapIDs.remove(item.id) }
                                else { selectedRoadmapIDs.insert(item.id) }
                                rebuildQueue()
                            } label: {
                                HStack {
                                    Image(systemName: selectedRoadmapIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selectedRoadmapIDs.contains(item.id) ? OrgRecTheme.ai : .secondary)
                                    Text(item.component.label)
                                    Text(item.component.noteName ?? "").foregroundStyle(.secondary)
                                    if item.required == false {
                                        Text("Optional").font(.caption2.bold()).foregroundStyle(OrgRecTheme.shu)
                                    }
                                    if item.minimumAcceptedTakeCount > 1 {
                                        Text("×\(item.minimumAcceptedTakeCount) takes")
                                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(item.technique.rawValue).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var venueStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepTitle("Confirm the organ venue", "A building-level coordinate anchors the preliminary surrounding-noise search.")
                HStack {
                    TextField("Venue or street address", text: $venueQuery)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { searchVenue() }
                    TextField("City, region, or country", text: $venueLocationContext)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { searchVenue() }
                    Button {
                        searchVenue()
                    } label: {
                        if model.isSearchingNoiseVenue { ProgressView().controlSize(.small) }
                        else { Label("Search", systemImage: "magnifyingglass") }
                    }
                    .disabled(venueQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSearchingNoiseVenue)
                }
                Text("Include city, postal code, region, or country when the venue name is not unique. OrgRec combines both fields and sends the user-triggered search to OpenStreetMap Nominatim at its public-service rate limit.")
                    .font(.caption2).foregroundStyle(.secondary)

                ForEach(model.noiseGeocodeCandidates) { candidate in
                    Button {
                        venueAnchor = candidate.venueAnchor(label: project?.venueName ?? candidate.displayName, confirmedBy: operatorName)
                        latitudeText = String(candidate.coordinate.latitude)
                        longitudeText = String(candidate.coordinate.longitude)
                        assessment = nil
                    } label: {
                        HStack(alignment: .top) {
                            Image(systemName: venueAnchor?.sourceIdentifier == "\(candidate.osmType)/\(candidate.osmIdentifier)" ? "checkmark.circle.fill" : "mappin.circle")
                                .foregroundStyle(OrgRecTheme.shu)
                            VStack(alignment: .leading) {
                                Text(candidate.displayName).font(.callout.bold())
                                Text("\(candidate.coordinate.latitude, format: .number.precision(.fractionLength(5))), \(candidate.coordinate.longitude, format: .number.precision(.fractionLength(5)))")
                                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                Text("Exact or manually verified coordinates").font(.headline)
                HStack {
                    TextField("Latitude", text: $latitudeText).textFieldStyle(.roundedBorder)
                    TextField("Longitude", text: $longitudeText).textFieldStyle(.roundedBorder)
                    Button("Use coordinates") { confirmManualCoordinates() }
                        .disabled(Double(latitudeText) == nil || Double(longitudeText) == nil)
                }

                if let venueAnchor {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Confirmed venue anchor", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(OrgRecTheme.ai)
                        Text(venueAnchor.displayAddress)
                        Text("\(venueAnchor.coordinate.latitude, format: .number.precision(.fractionLength(6))), \(venueAnchor.coordinate.longitude, format: .number.precision(.fractionLength(6))) · \(venueAnchor.precision.rawValue)")
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    .orgRecCard()
                }
            }
        }
    }

    private var noiseStep: some View {
        VStack(alignment: .leading, spacing: 13) {
            stepTitle("Review surrounding noise", "Query mapped transport, civic, construction, industrial, aviation, and event features around the confirmed building.")
            HStack {
                Slider(value: $radiusMeters, in: 250...1_500, step: 50)
                Text("\(Int(radiusMeters)) m").font(.callout.monospacedDigit()).frame(width: 64)
                Button {
                    guard let venueAnchor else { return }
                    Task {
                        if let result = await model.assessNoiseContext(anchor: venueAnchor, radiusMeters: radiusMeters) {
                            assessment = result
                        }
                    }
                } label: {
                    if model.isAssessingNoiseContext { ProgressView().controlSize(.small) }
                    else { Label(assessment == nil ? "Assess" : "Refresh", systemImage: "map") }
                }
                .buttonStyle(.borderedProminent)
                .disabled(venueAnchor == nil || model.isAssessingNoiseContext)
                Button("View map") { showMap = true }.disabled(assessment == nil)
            }
            if let assessment {
                HStack {
                    Label(assessment.summary, systemImage: "waveform.badge.magnifyingglass")
                        .font(.callout).foregroundStyle(OrgRecTheme.ai)
                    Spacer()
                    Text(assessment.retrievedAt, style: .time).font(.caption).foregroundStyle(.secondary)
                }
                .orgRecCard(inset: 12)

                List {
                    ForEach(assessment.findings.indices, id: \.self) { index in
                        noiseFindingEditor(index: index)
                    }
                }
                .listStyle(.inset)

                HStack {
                    TextField("Add a locally known source", text: $manualNoiseLabel).textFieldStyle(.roundedBorder)
                    Picker("", selection: $manualNoiseCategory) {
                        ForEach(NoiseSourceCategory.allCases) { Text($0.displayName).tag($0) }
                    }.labelsHidden().frame(width: 190)
                    Picker("", selection: $manualNoisePriority) {
                        ForEach(NoisePlanningPriority.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }.labelsHidden().frame(width: 105)
                    Button("Add") { addManualFinding() }
                        .disabled(manualNoiseLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                TextField("Operator notes about bells, HVAC, pedestrian activity, markets, events, or quiet windows", text: assessmentManualNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...4)
                TextField("Official/local noise-map or construction-register check (source and result)", text: officialLayerNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...4)
            } else {
                ContentUnavailableView("No assessment yet", systemImage: "map", description: Text("Confirm the venue and run the OpenStreetMap assessment. You can then dismiss, confirm, annotate, or supplement every finding."))
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private var queueStep: some View {
        VStack(alignment: .leading, spacing: 13) {
            stepTitle("Order and estimate", "The queue minimizes setup and registration changes; move individual items when venue logistics require it.")
            HStack(spacing: 18) {
                Label(durationText(estimates.totalSeconds), systemImage: "clock")
                Label(ByteCountFormatter.string(fromByteCount: estimates.audioBytes, countStyle: .file), systemImage: "externaldrive")
                Spacer()
                Text("Contingency \(Int(contingencyPercent))%")
                Slider(value: $contingencyPercent, in: 0...50, step: 5).frame(width: 150)
            }
            .font(.callout)
            List {
                ForEach(Array(orderedQueue.enumerated()), id: \.element.id) { index, queued in
                    if let item = project?.roadmap.first(where: { $0.id == queued.roadmapItemID }) {
                        HStack {
                            Text("\(index + 1)").font(.caption.monospacedDigit()).frame(width: 28, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(item.component.label) \(item.component.noteName ?? "")").font(.callout.bold())
                                Text("\(item.component.division) · \(item.technique.rawValue)" + (item.minimumAcceptedTakeCount > 1 ? " · \(item.minimumAcceptedTakeCount) planned takes" : ""))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { moveQueueItem(from: index, offset: -1) } label: { Image(systemName: "arrow.up") }
                                .disabled(index == 0)
                            Button { moveQueueItem(from: index, offset: 1) } label: { Image(systemName: "arrow.down") }
                                .disabled(index == orderedQueue.count - 1)
                        }
                    }
                }
            }
            .listStyle(.inset)
            Text("Estimate includes 20 minutes preparation, 10 minutes per setup change, operator overhead per take, contingency, and 24-bit PCM audio plus 10% container allowance.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var reviewStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepTitle("Freeze the field plan", "The session and every subsequent take retain the reviewed assessment, query fingerprint, source attribution, and dispositions.")
                summaryRow("Session", value: title)
                summaryRow("Window", value: "\(plannedStart.formatted(date: .abbreviated, time: .shortened)) – \(plannedEnd.formatted(date: .abbreviated, time: .shortened))")
                summaryRow("Operator", value: operatorName + (institution.isEmpty ? "" : " · \(institution)"))
                summaryRow("Roadmap scope", value: "\(queue.count) items · \(durationText(estimates.totalSeconds)) · \(ByteCountFormatter.string(fromByteCount: estimates.audioBytes, countStyle: .file))")
                summaryRow("Venue anchor", value: venueAnchor?.displayAddress ?? "Missing")
                summaryRow("Noise context", value: assessment?.summary ?? "Missing")
                TextField("Preflight and contingency notes", text: $preflightNotes, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(3...7)
                Label("Saving creates an immutable plan revision. Starting creates a new recording session with a copied noise-context snapshot; live incidents are recorded as timed take annotations.", systemImage: "lock.doc")
                    .font(.callout).foregroundStyle(.secondary)
                    .orgRecCard()
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
            Spacer()
            if step != .session { Button("Back") { step = PlannerStep(rawValue: step.rawValue - 1) ?? .session } }
            if step == .review {
                if editingPlan?.status == .active {
                    Button("Save revision and continue session") { save(startImmediately: true) }
                        .buttonStyle(.borderedProminent)
                        .disabled(canSave == false)
                } else {
                    Button("Save plan") { save(startImmediately: false) }
                        .disabled(canSave == false)
                    Button("Save and start session") { save(startImmediately: true) }
                        .buttonStyle(.borderedProminent)
                        .disabled(canSave == false)
                }
            } else {
                Button("Continue") {
                    if step == .scope { rebuildQueue() }
                    step = PlannerStep(rawValue: step.rawValue + 1) ?? .review
                }
                .buttonStyle(.borderedProminent)
                .disabled(canAdvance == false)
            }
        }
        .padding(16)
    }

    private var canAdvance: Bool {
        switch step {
        case .session:
            title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                && plannedEnd > plannedStart
        case .scope: selectedRoadmapIDs.isEmpty == false
        case .venue: venueAnchor != nil
        case .noise: assessment != nil
        case .queue: queue.isEmpty == false
        case .review: canSave
        }
    }

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && plannedEnd > plannedStart
            && queue.isEmpty == false
            && assessment != nil
    }

    private func canVisit(_ candidate: PlannerStep) -> Bool {
        if candidate.rawValue <= step.rawValue { return true }
        let sessionValid = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && plannedEnd > plannedStart
        if candidate == .scope { return sessionValid }
        let scopeValid = sessionValid && selectedRoadmapIDs.isEmpty == false
        if candidate == .venue { return scopeValid }
        let venueValid = scopeValid && venueAnchor != nil
        if candidate == .noise { return venueValid }
        let noiseValid = venueValid && assessment != nil
        if candidate == .queue { return noiseValid }
        return noiseValid && queue.isEmpty == false
    }

    private var inferredChannelCount: Int {
        let setups = Set(selectedItems.compactMap(\.setupID))
        return project?.setups.filter { setups.contains($0.id) }.flatMap(\.placements).map(\.channelNumber).max() ?? 1
    }

    private var groupedEligibleItems: [(division: String, items: [RoadmapItem])] {
        Dictionary(grouping: eligibleItems, by: { $0.component.division })
            .map { ($0.key, $0.value.sorted { ($0.component.label, $0.component.midiNote ?? 999) < ($1.component.label, $1.component.midiNote ?? 999) }) }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    private var assessmentManualNotes: Binding<String> {
        Binding(get: { assessment?.manualNotes ?? "" }, set: { assessment?.manualNotes = $0 })
    }

    private var officialLayerNotes: Binding<String> {
        Binding(get: { assessment?.officialNoiseLayerNotes ?? "" }, set: { assessment?.officialNoiseLayerNotes = $0 })
    }

    private func stepTitle(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.bold())
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.callout.bold()).frame(width: 130, alignment: .leading)
            Text(value).font(.callout).textSelection(.enabled)
            Spacer()
        }
        .padding(.vertical, 5)
    }

    private func noiseFindingEditor(index: Int) -> some View {
        let finding = assessment?.findings[index]
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(finding?.label ?? "Noise source").font(.callout.bold())
                Text(finding?.category.displayName ?? "").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let distance = finding?.distanceMeters { Text("\(Int(distance.rounded())) m").font(.caption.monospacedDigit()) }
                Picker("Review", selection: Binding(
                    get: { assessment?.findings[index].disposition ?? .unverified },
                    set: { assessment?.findings[index].disposition = $0 }
                )) {
                    ForEach(NoiseFindingDisposition.allCases, id: \.self) { Text(dispositionLabel($0)).tag($0) }
                }
                .labelsHidden().frame(width: 140)
            }
            TextField("Finding notes or expected quiet hours", text: Binding(
                get: { assessment?.findings[index].notes ?? "" },
                set: { assessment?.findings[index].notes = $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 4)
    }

    private func loadOnce() {
        guard didLoad == false, let project else { return }
        didLoad = true
        title = "\(project.organName) recording session"
        venueQuery = project.venueName
        venueAnchor = project.venueAnchor
        if let anchor = venueAnchor {
            latitudeText = String(anchor.coordinate.latitude)
            longitudeText = String(anchor.coordinate.longitude)
        }
        if let editingPlanID,
           let existing = project.sessionPlans?.first(where: { $0.id == editingPlanID }) {
            planID = existing.id
            title = existing.title
            purpose = existing.purpose
            operatorName = existing.operatorName
            institution = existing.institution
            plannedStart = existing.plannedStart
            plannedEnd = existing.plannedEnd
            accessNotes = existing.accessNotes
            preflightNotes = existing.preflightNotes
            contingencyPercent = existing.contingencyFraction * 100
            let eligibleIDs = Set(eligibleItems.map(\.id))
            let retainedQueue = existing.queue
                .filter { eligibleIDs.contains($0.roadmapItemID) }
                .sorted { $0.order < $1.order }
            if retainedQueue.count == existing.queue.count {
                queue = retainedQueue
                for index in queue.indices { queue[index].order = index }
                selectedRoadmapIDs = Set(queue.map(\.roadmapItemID))
            } else if retainedQueue.isEmpty, existing.queue.count == eligibleItems.count {
                selectedRoadmapIDs = Set(eligibleItems.map(\.id))
                rebuildQueue(adjustPlannedEnd: false)
                scopeRecoveryNotice = "This legacy full-scope plan predates stable roadmap identifiers. OrgRec safely matched it to all \(eligibleItems.count) current obligations; review the regenerated queue before saving the revision."
            } else {
                queue = retainedQueue
                for index in queue.indices { queue[index].order = index }
                selectedRoadmapIDs = Set(queue.map(\.roadmapItemID))
                scopeRecoveryNotice = "\(existing.queue.count - retainedQueue.count) legacy queue references no longer match this roadmap. Re-select the intended scope before saving the revision."
            }
            if let id = existing.noiseContextAssessmentID {
                assessment = project.noiseContextAssessments?.first(where: { $0.id == id })
                venueAnchor = assessment?.venueAnchor ?? venueAnchor
                radiusMeters = assessment?.radiusMeters ?? radiusMeters
            }
        } else {
            selectedRoadmapIDs = Set(eligibleItems.filter(\.required).map(\.id))
            assessment = project.noiseContextAssessments?.last
            rebuildQueue()
        }
    }

    private func confirmManualCoordinates() {
        guard let latitude = Double(latitudeText), (-90...90).contains(latitude),
              let longitude = Double(longitudeText), (-180...180).contains(longitude) else { return }
        venueAnchor = VenueAnchor(
            label: project?.venueName ?? project?.organName ?? "Organ venue",
            displayAddress: venueSearchQuery.isEmpty ? (project?.venueName ?? "Manually confirmed venue") : venueSearchQuery,
            coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
            precision: .manuallyPlaced,
            source: "Operator-confirmed coordinates",
            confirmedAt: .now,
            confirmedBy: operatorName
        )
        assessment = nil
    }

    private var venueSearchQuery: String {
        [venueQuery, venueLocationContext]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .reduce(into: [String]()) { parts, value in
                if parts.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) == false {
                    parts.append(value)
                }
            }
            .joined(separator: ", ")
    }

    private func searchVenue() {
        let query = venueSearchQuery
        guard query.isEmpty == false else { return }
        Task { await model.searchNoiseVenue(query) }
    }

    private func rebuildQueue(adjustPlannedEnd: Bool = true) {
        guard let project else { return }
        queue = SessionPlanningEngine.buildQueue(
            items: selectedItems,
            recipe: project.recipe,
            setupOrder: project.setups.map(\.id),
            registrationOrder: project.registrations.map(\.id)
        )
        if adjustPlannedEnd, queue.isEmpty == false {
            plannedEnd = plannedStart.addingTimeInterval(estimates.totalSeconds)
        }
    }

    private func moveQueueItem(from source: Int, offset: Int) {
        var sorted = orderedQueue
        let destination = source + offset
        guard sorted.indices.contains(source), sorted.indices.contains(destination) else { return }
        sorted.swapAt(source, destination)
        for index in sorted.indices { sorted[index].order = index }
        queue = sorted
    }

    private func addManualFinding() {
        guard assessment != nil else { return }
        assessment?.findings.append(NoiseContextFinding(
            sourceIdentifier: "operator:\(UUID().uuidString.lowercased())",
            label: manualNoiseLabel.trimmingCharacters(in: .whitespacesAndNewlines),
            category: manualNoiseCategory,
            temporalPattern: .unknown,
            planningPriority: manualNoisePriority,
            evidenceConfidence: .high,
            disposition: .confirmed,
            notes: "Added from local/operator knowledge during planning."
        ))
        manualNoiseLabel = ""
    }

    private func save(startImmediately: Bool) {
        guard let project, var assessment else { return }
        assessment.venueAnchor = venueAnchor ?? assessment.venueAnchor
        let estimate = estimates
        let plan = RecordingSessionPlan(
            id: planID,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            purpose: purpose,
            organMDVSID: project.organMDVSID,
            navigatorSnapshotSHA256: project.snapshot.payloadSHA256,
            plannedStart: plannedStart,
            plannedEnd: plannedEnd,
            timezoneIdentifier: TimeZone.current.identifier,
            operatorName: operatorName,
            institution: institution,
            accessNotes: accessNotes,
            queue: orderedQueue,
            setupIDs: project.setups.map(\.id).filter { setupID in
                selectedItems.contains { $0.setupID == setupID }
            },
            noiseContextAssessmentID: assessment.id,
            estimatedTotalSeconds: estimate.totalSeconds,
            estimatedAudioBytes: estimate.audioBytes,
            contingencyFraction: contingencyPercent / 100,
            preflightNotes: preflightNotes
        )
        Task {
            await model.saveSessionPlan(plan, noiseAssessment: assessment, startImmediately: startImmediately)
            dismiss()
        }
    }

    private func durationText(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }

    private func dispositionLabel(_ disposition: NoiseFindingDisposition) -> String {
        switch disposition {
        case .unverified: "Unverified"
        case .confirmed: "Confirmed"
        case .dismissed: "Dismissed"
        case .contactVenue: "Ask venue"
        }
    }
}

private enum PlannerStep: Int, CaseIterable, Identifiable {
    case session
    case scope
    case venue
    case noise
    case queue
    case review

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .session: "Session"
        case .scope: "Scope"
        case .venue: "Venue"
        case .noise: "Noise context"
        case .queue: "Queue"
        case .review: "Review"
        }
    }
    var detail: String {
        switch self {
        case .session: "Intent & access"
        case .scope: "Roadmap obligations"
        case .venue: "Building anchor"
        case .noise: "Mapped sources"
        case .queue: "Order & estimate"
        case .review: "Freeze revision"
        }
    }
}
