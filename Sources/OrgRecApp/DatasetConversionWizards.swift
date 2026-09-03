import AppKit
import OrgRecCore
import SwiftUI
import UniformTypeIdentifiers

private enum GrandOrgueWizardStep: Int, CaseIterable, Identifiable {
    case source, inventory, identity, mapping, preservation, export
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .source: "Select ODF"
        case .inventory: "Inventory"
        case .identity: "Identity & rights"
        case .mapping: "ODF mappings"
        case .preservation: "Preservation"
        case .export: "Create VAO"
        }
    }
}

struct GrandOrgueVAOWizard: View {
    @EnvironmentObject private var model: AppModel
    @State private var step: GrandOrgueWizardStep = .source

    var body: some View {
        VStack(spacing: 0) {
            WizardProgress(steps: GrandOrgueWizardStep.allCases.map(\.title), selectedIndex: step.rawValue)
                .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title)
                            .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        Text("GrandOrgue is converted from ODF relationships, not from the audio-dataset filename parser.")
                            .foregroundStyle(.secondary)
                    }
                    currentStep
                }
                .padding(24)
                .frame(maxWidth: 1050, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            Divider()
            navigation
        }
    }

    @ViewBuilder private var currentStep: some View {
        switch step {
        case .source: sourceStep
        case .inventory: inventoryStep
        case .identity: identityStep
        case .mapping: mappingStep
        case .preservation: preservationStep
        case .export: exportStep
        }
    }

    private var sourceStep: some View {
        GroupBox("GrandOrgue definition") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.grandOrgueODFURL?.path ?? "No .organ definition selected")
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Text("Choose the exact original, extended, dry, or surround disposition you intend to represent.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Choose and inspect ODF…") { chooseODF() }
                        .buttonStyle(.borderedProminent)
                }
                TextField("Publisher or organ source page (recommended)", text: $model.grandOrgueSourcePageURL)
                    .textFieldStyle(.roundedBorder)
                Text("The source URL is retained as source identity evidence; it is never presented as a MODAVIS identifier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                statusLabel
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder private var inventoryStep: some View {
        if let inspection = model.grandOrgueInspection {
            GroupBox("Resolved source inventory") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 28) {
                        metric("Stops", "\(inspection.stops.count)")
                        metric("Logical pipes", "\(inspection.referencedSampleCount)")
                        metric("Unique WAVs", "\(inspection.uniqueReferencedAudioCount)")
                        metric("Payload", ByteCountFormatter.string(fromByteCount: inspection.totalPayloadBytes, countStyle: .file))
                        metric("Files", "\(inspection.payloadFiles.count)")
                    }
                    Divider()
                    Label("\(inspection.odfRelativePath) · \(inspection.odfEncoding) · SHA-256 \(inspection.odfSHA256.prefix(16))…", systemImage: "doc.text")
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                }
                .padding(.top, 6)
            }
        } else {
            missingInspection
        }
    }

    @ViewBuilder private var identityStep: some View {
        if let inspection = model.grandOrgueInspection {
            GroupBox("Identity and rights found in the source") {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 9) {
                    identityRow("Organ / venue", inspection.organName)
                    identityRow("Location", inspection.location.isEmpty ? "Not encoded" : inspection.location)
                    identityRow("Builder", inspection.builder ?? "Not encoded")
                    identityRow("Build date", inspection.buildDateLabel ?? "Not encoded")
                    identityRow("Recording", inspection.recordingDetails ?? "Not encoded")
                    identityRow("Rights holder", inspection.rightsHolder ?? "Not detected")
                    identityRow("License", inspection.licenseLabel ?? "Not detected")
                    identityRow("License URI", inspection.licenseURL ?? "Not detected")
                }
                .padding(.top, 6)
            }
        } else {
            missingInspection
        }
    }

    @ViewBuilder private var mappingStep: some View {
        if let inspection = model.grandOrgueInspection {
            GroupBox("ODF-derived disposition") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(inspection.divisions) { division in
                        Label(
                            "\(division.name): MIDI \(division.firstMIDINote)…\(division.firstMIDINote + division.keyCount - 1) · \(division.stopCount) stops",
                            systemImage: division.isPedal ? "pianokeys.inverse" : "pianokeys"
                        )
                        .font(.callout)
                    }
                    Divider()
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                        GridRow {
                            Text("Division").fontWeight(.semibold)
                            Text("Stop").fontWeight(.semibold)
                            Text("ODF sections").fontWeight(.semibold)
                            Text("Compass").fontWeight(.semibold)
                            Text("Pipes").fontWeight(.semibold)
                        }
                        ForEach(inspection.stops) { stop in
                            GridRow {
                                Text(stop.division)
                                Text(stop.name)
                                Text(stop.sectionNames.joined(separator: ", ")).monospaced()
                                Text("\(stop.firstMIDINote)…\(stop.lastMIDINote)")
                                Text("\(stop.pipeCount)")
                            }
                            .font(.callout)
                        }
                    }
                    Text("Couplers: \(inspection.couplerCount) · Tremulants: \(inspection.tremulantCount). These mappings come from ODF sections and references, never from filename guesses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        } else {
            missingInspection
        }
    }

    @ViewBuilder private var preservationStep: some View {
        if let inspection = model.grandOrgueInspection {
            GroupBox("Validation and preservation") {
                VStack(alignment: .leading, spacing: 8) {
                    bullet("The complete ODF directory is copied so UI files, photos, README, and license evidence remain with the playable source set.")
                    bullet("Every source file receives SHA-256 fixity and every copy is rehashed.")
                    bullet("Shared `REF:` audio is stored once and linked to each applicable logical pipe.")
                    bullet("Legacy ODF encoding is recorded; source text is not silently transcoded.")
                    if !inspection.warnings.isEmpty {
                        Divider()
                        ForEach(inspection.warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(OrgRecTheme.shu)
                        }
                    }
                }
                .padding(.top, 6)
            }
        } else {
            missingInspection
        }
    }

    @ViewBuilder private var exportStep: some View {
        if let inspection = model.grandOrgueInspection {
            GroupBox("Create the validated VAO") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("OrgRec will preserve the source tree, construct the component and asset graph from the selected ODF, create an editable project in the library, then write and validate a single-file VAO.")
                    Label(
                        inspection.missingSampleCount == 0
                            ? "All \(inspection.referencedSampleCount) ODF pipe mappings resolve"
                            : "\(inspection.missingSampleCount) sample references are unresolved",
                        systemImage: inspection.missingSampleCount == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(inspection.missingSampleCount == 0 ? OrgRecTheme.ai : OrgRecTheme.shu)
                    statusLabel
                    HStack {
                        Spacer()
                        Button("Choose destination and create VAO…") { chooseDestination() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(model.isWorking || inspection.missingSampleCount > 0)
                    }
                }
                .padding(.top, 6)
            }
        } else {
            missingInspection
        }
    }

    @ViewBuilder private var statusLabel: some View {
        if let status = model.grandOrgueImportStatus {
            Label(status, systemImage: model.isWorking ? "hourglass" : "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var missingInspection: some View {
        ContentUnavailableView(
            "Inspect an ODF first",
            systemImage: "music.note.house",
            description: Text("Return to the first step and choose the exact GrandOrgue definition.")
        )
        .frame(minHeight: 260)
    }

    private var navigation: some View {
        HStack {
            Button("Back") { move(by: -1) }
                .disabled(step == .source || model.isWorking)
            Spacer()
            Text("Step \(step.rawValue + 1) of \(GrandOrgueWizardStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if step != .export {
                Button("Continue") { move(by: 1) }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.grandOrgueInspection == nil || model.isWorking)
            } else {
                Button("Review mappings") { step = .mapping }
                    .disabled(model.isWorking)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 58)
        .background(OrgRecTheme.surface)
    }

    private func move(by offset: Int) {
        guard let next = GrandOrgueWizardStep(rawValue: step.rawValue + offset) else { return }
        step = next
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold()).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func identityRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private func chooseODF() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "organ") ?? .data]
        panel.prompt = "Inspect ODF"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.inspectGrandOrgueSampleSet(at: url) }
    }

    private func chooseDestination() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "vao") ?? .data]
        panel.nameFieldStringValue = "\(model.grandOrgueInspection?.organName ?? "GrandOrgue").vao"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.convertGrandOrgueToVAO(destination: url) }
    }
}

private enum AudioDatasetWizardStep: Int, CaseIterable, Identifiable {
    case source, filenames, mappings, metadata, export
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .source: "Choose audio"
        case .filenames: "Parse filenames"
        case .mappings: "Verify mappings"
        case .metadata: "Describe source"
        case .export: "Create VAO"
        }
    }
}

struct AudioDatasetVAOWizard: View {
    @EnvironmentObject private var model: AppModel
    @State private var step: AudioDatasetWizardStep = .source
    @State private var convention: LegacyFilenameConvention = .stopThenMIDI
    @State private var midiNoteOffset = 0
    @State private var stopMappings: [LegacyStopMapping] = []
    @State private var datasetIdentifier = ""
    @State private var sourceNamespace = "local"
    @State private var organName = ""
    @State private var venueName = ""
    @State private var divisionName = "Manual"
    @State private var builder = ""
    @State private var sourceURL = ""
    @State private var rightsStatement = ""
    @State private var analyzeRepresentativeSample = true

    var body: some View {
        VStack(spacing: 0) {
            WizardProgress(steps: AudioDatasetWizardStep.allCases.map(\.title), selectedIndex: step.rawValue)
                .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title)
                            .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        Text("This workflow is for collections of audio files. It does not parse or emulate GrandOrgue ODFs.")
                            .foregroundStyle(.secondary)
                    }
                    currentStep
                }
                .padding(24)
                .frame(maxWidth: 1050, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            Divider()
            navigation
        }
    }

    @ViewBuilder private var currentStep: some View {
        switch step {
        case .source: sourceStep
        case .filenames: filenameStep
        case .mappings: mappingStep
        case .metadata: metadataStep
        case .export: exportStep
        }
    }

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Source boundary") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.legacyImportSourceURL?.path ?? "No audio directory selected")
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                                .lineLimit(2)
                            Text("The selected directory is read-only input. Conversion writes a new project and VAO elsewhere.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Choose audio directory…") { chooseDirectory() }
                            .buttonStyle(.borderedProminent)
                    }
                    if let status = model.legacyImportStatus { statusView(status) }
                }
                .padding(.top, 6)
            }
            GroupBox("Prepare the folder for the strongest result") {
                VStack(alignment: .leading, spacing: 8) {
                    advice("Put one logical recording per file and keep the audio files at the top level of the selected folder.")
                    advice("Use the same field order and separators throughout: stop + pitch, optionally followed by a variant such as rr2 or take3.")
                    advice("Use stable stop tokens and either MIDI 0…127 or scientific note names such as C4. Avoid unexplained sequence numbers.")
                    advice("Keep documentation and license evidence available; identify their source and rights before export.")
                }
                .padding(.top, 6)
            }
        }
    }

    private var filenameStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Filename convention") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Fields in each filename", selection: $convention) {
                        ForEach(LegacyFilenameConvention.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    Text("Expected example: \(convention.example). Underscores, spaces, and hyphens are accepted as separators.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if convention != .stopThenNoteName {
                        Stepper(
                            "Pitch-number offset: \(midiNoteOffset >= 0 ? "+" : "")\(midiNoteOffset)",
                            value: $midiNoteOffset,
                            in: -127...127
                        )
                        Text("Leave this at 0 when names already contain MIDI notes. If key 1 means MIDI 36, use +35. The raw token and interpreted MIDI note are both retained.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Spacer()
                        Button(model.legacyInspection == nil ? "Parse and inspect files" : "Parse again") { parseFilenames() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isWorking || model.legacyImportSourceURL == nil)
                    }
                    if let status = model.legacyImportStatus { statusView(status) }
                }
                .padding(.top, 6)
            }
            GroupBox("Filename sample") {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(model.legacyCandidateFilenames.prefix(10)), id: \.self) { filename in
                        Text(filename).font(.callout.monospaced())
                    }
                    if model.legacyCandidateFilenames.count > 10 {
                        Text("…and \(model.legacyCandidateFilenames.count - 10) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder private var mappingStep: some View {
        if let inspection = model.legacyInspection {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Review every stop token") {
                    VStack(alignment: .leading, spacing: 12) {
                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                            GridRow {
                                Text("Filename token").fontWeight(.semibold)
                                Text("VAO label").fontWeight(.semibold)
                                Text("Footage").fontWeight(.semibold)
                                Text("Files / interpreted MIDI").fontWeight(.semibold)
                            }
                            Divider().gridCellColumns(4)
                            ForEach($stopMappings) { $mapping in
                                let records = inspection.files.filter { $0.stopCode == mapping.code }
                                GridRow {
                                    Text(mapping.code).monospaced()
                                    TextField("Stop label", text: $mapping.label)
                                        .textFieldStyle(.roundedBorder)
                                    TextField(
                                        "e.g. 8′",
                                        text: Binding(
                                            get: { mapping.footHeight ?? "" },
                                            set: { mapping.footHeight = $0.isEmpty ? nil : $0 }
                                        )
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    Text("\(records.count) · \(keySummary(records.map(\.midiNote)))")
                                        .font(.callout.monospacedDigit())
                                }
                            }
                        }
                        Text("Footage changes the expected sounding-pitch prior. Confirm it carefully: 4′ sounds one octave above the key number, 2′ two octaves above, and 16′ one octave below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
                GroupBox("Parse coverage") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "\(inspection.files.count) of \(model.legacyCandidateFilenames.count) candidate audio files parsed",
                            systemImage: inspection.files.count == model.legacyCandidateFilenames.count ? "checkmark.seal.fill" : "exclamationmark.triangle"
                        )
                        Label("\(stopMappings.count) distinct stop tokens require \(stopMappings.count) reviewed mappings", systemImage: "point.3.connected.trianglepath.dotted")
                        if !inspection.ignoredEntries.isEmpty {
                            Text("Not parsed: \(inspection.ignoredEntries.prefix(12).joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(OrgRecTheme.shu)
                        }
                        let structuralWarnings = inspection.warnings.filter {
                            !$0.contains("has no semantic mapping")
                        }
                        ForEach(structuralWarnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(OrgRecTheme.shu)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        } else {
            ContentUnavailableView(
                "Parse filenames first",
                systemImage: "text.magnifyingglass",
                description: Text("Return to the filename step and choose the convention that matches the collection.")
            )
            .frame(minHeight: 280)
        }
    }

    private var metadataStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Source identity") {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    formRow("Instrument or dataset name", placeholder: "Required", text: $organName)
                    formRow("Local collection ID", placeholder: "Required", text: $datasetIdentifier)
                    formRow("Identifier namespace", placeholder: "local", text: $sourceNamespace)
                    formRow("Venue or collection", placeholder: "Unknown", text: $venueName)
                    formRow("Division", placeholder: "Manual", text: $divisionName)
                    formRow("Builder", placeholder: "Unknown", text: $builder)
                    formRow("Publisher / catalog URL", placeholder: "https://…", text: $sourceURL)
                    formRow("Rights statement", placeholder: "Unknown; resolve before dissemination", text: $rightsStatement)
                }
                .padding(.top, 6)
            }
            GroupBox("Evidence policy") {
                VStack(alignment: .leading, spacing: 8) {
                    advice("A local collection ID becomes a source-bound identifier, never an invented MDVS identifier.")
                    advice("Unknown recording date, operator, microphones, placement, tuning, and rights remain explicitly unknown.")
                    advice("Filename labels and pitch offsets are recorded as reviewed interpretations with their raw tokens preserved.")
                }
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder private var exportStep: some View {
        if let inspection = model.legacyInspection {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Conversion summary") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 28) {
                            metric("Parsed audio", "\(inspection.files.count)")
                            metric("Mapped stops", "\(stopMappings.count)")
                            metric("Size", ByteCountFormatter.string(fromByteCount: inspection.totalBytes, countStyle: .file))
                            metric("Identity", "\(sourceNamespace):\(datasetIdentifier)")
                        }
                        Divider()
                        Label(
                            "Every parsed file has one stop mapping and an interpreted MIDI position",
                            systemImage: mappingsAreComplete ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(mappingsAreComplete ? OrgRecTheme.ai : OrgRecTheme.shu)
                        Label("Source audio will be copied byte-for-byte and checksum-verified", systemImage: "lock.shield")
                        Label("A validated VAO and an editable OrgRec project will be created", systemImage: "shippingbox")
                    }
                    .padding(.top, 6)
                }
                GroupBox("Optional representative analysis") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Analyze low, middle, and high note for each stop before packaging", isOn: $analyzeRepresentativeSample)
                        Text("Pitch, boundary, level, partial, and spectrogram results remain marked Needs review because filenames do not establish recording context or historical tuning.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
                GroupBox("Create VAO") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let status = model.legacyImportStatus { statusView(status) }
                        HStack {
                            Spacer()
                            Button("Choose destination and create VAO…") { chooseDestination() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .disabled(model.isWorking || !mappingsAreComplete || !metadataIsComplete)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        } else {
            ContentUnavailableView(
                "No parsed dataset",
                systemImage: "waveform.badge.exclamationmark",
                description: Text("Return to the filename step and parse the source collection.")
            )
            .frame(minHeight: 280)
        }
    }

    private var navigation: some View {
        HStack {
            Button("Back") { move(by: -1) }
                .disabled(step == .source || model.isWorking)
            Spacer()
            Text("Step \(step.rawValue + 1) of \(AudioDatasetWizardStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if step != .export {
                Button("Continue") { move(by: 1) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue || model.isWorking)
            } else {
                Button("Review mappings") { step = .mappings }
                    .disabled(model.isWorking)
            }
        }
        .padding(.horizontal, 24)
        .frame(height: 58)
        .background(OrgRecTheme.surface)
    }

    private var canContinue: Bool {
        switch step {
        case .source:
            model.legacyImportSourceURL != nil && !model.legacyCandidateFilenames.isEmpty
        case .filenames:
            model.legacyInspection != nil
        case .mappings:
            mappingsAreComplete
        case .metadata:
            metadataIsComplete
        case .export:
            true
        }
    }

    private var mappingsAreComplete: Bool {
        guard let inspection = model.legacyInspection else { return false }
        let mapped = Set(stopMappings.filter {
            !$0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.map(\.code))
        return !inspection.files.isEmpty && Set(inspection.files.map(\.stopCode)).isSubset(of: mapped)
    }

    private var metadataIsComplete: Bool {
        !organName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !datasetIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sourceNamespace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !divisionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func move(by offset: Int) {
        guard let next = AudioDatasetWizardStep(rawValue: step.rawValue + offset) else { return }
        step = next
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose an audio dataset"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.selectLegacyDatasetSource(url)
        let stem = url.lastPathComponent
        if datasetIdentifier.isEmpty { datasetIdentifier = safeIdentifier(stem) }
        if organName.isEmpty { organName = stem }
        stopMappings = []
    }

    private func parseFilenames() {
        guard let source = model.legacyImportSourceURL else { return }
        Task {
            await model.inspectLegacyDataset(at: source, profile: makeProfile(mappings: []))
            if let inspection = model.legacyInspection {
                stopMappings = inspection.stopCodes.map(suggestedMapping)
            }
        }
    }

    private func makeProfile(mappings: [LegacyStopMapping]? = nil) -> LegacyDatasetProfile {
        let trimmedURL = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let urls = URL(string: trimmedURL).map { [$0.absoluteString] } ?? []
        return .audioDataset(
            sourceNamespace: sourceNamespace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "local" : sourceNamespace,
            sourceRecordIdentifier: datasetIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unidentified-dataset" : datasetIdentifier,
            organName: organName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unidentified audio dataset" : organName,
            venueName: venueName,
            divisionName: divisionName.isEmpty ? "Manual" : divisionName,
            convention: convention,
            midiNoteOffset: convention == .stopThenNoteName ? 0 : midiNoteOffset,
            stopMappings: mappings ?? stopMappings.map(normalizedMapping),
            sourceURLs: urls,
            rightsStatement: rightsStatement,
            builder: builder
        )
    }

    private func suggestedMapping(_ code: String) -> LegacyStopMapping {
        let spaced = code
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let lower = spaced.lowercased()
        let footage: String?
        let offset: Int
        if lower.contains("16") { footage = "16′"; offset = -12 }
        else if lower.contains("223") || lower.contains("2 2/3") { footage = "2 2/3′"; offset = 19 }
        else if lower.contains("8") { footage = "8′"; offset = 0 }
        else if lower.contains("4") { footage = "4′"; offset = 12 }
        else if lower.contains("2") { footage = "2′"; offset = 24 }
        else { footage = nil; offset = 0 }
        var labelSource = spaced
        if footage != nil,
           let suffix = ["223", "16", "8", "4", "2", "1"].first(where: { lower.hasSuffix($0) }) {
            labelSource.removeLast(suffix.count)
            labelSource = labelSource.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-_")))
        }
        labelSource = labelSource.replacingOccurrences(
            of: #"([a-z])([A-Z])"#,
            with: "$1 $2",
            options: .regularExpression
        )
        return LegacyStopMapping(
            code: code,
            label: labelSource.split(separator: " ").map {
                $0.prefix(1).uppercased() + $0.dropFirst()
            }.joined(separator: " "),
            footHeight: footage,
            soundingSemitoneOffset: offset,
            interpretationNote: "Reviewed filename token ‘\(code)’; confirm label and footage against source documentation."
        )
    }

    private func normalizedMapping(_ mapping: LegacyStopMapping) -> LegacyStopMapping {
        var result = mapping
        let footage = mapping.footHeight?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if footage.hasPrefix("16") { result.soundingSemitoneOffset = -12 }
        else if footage.contains("2/3") { result.soundingSemitoneOffset = 19 }
        else if footage.hasPrefix("4") { result.soundingSemitoneOffset = 12 }
        else if footage.hasPrefix("2") { result.soundingSemitoneOffset = 24 }
        else { result.soundingSemitoneOffset = 0 }
        result.footHeight = footage.isEmpty ? nil : footage
        return result
    }

    private func chooseDestination() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "vao") ?? .data]
        panel.nameFieldStringValue = "\(safeIdentifier(organName)).vao"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            await model.convertLegacyDatasetToVAO(
                profile: makeProfile(),
                analyzeRepresentativeSample: analyzeRepresentativeSample,
                destination: url
            )
        }
    }

    private func formRow(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        GridRow {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func advice(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private func statusView(_ status: String) -> some View {
        Label(status, systemImage: model.isWorking ? "hourglass" : "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold()).lineLimit(1)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func keySummary(_ notes: [Int]) -> String {
        let unique = Array(Set(notes)).sorted()
        guard let low = unique.first, let high = unique.last else { return "—" }
        return "\(low)…\(high)"
    }

    private func safeIdentifier(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let transformed = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let result = String(transformed).replacingOccurrences(of: "--", with: "-")
        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return trimmed.isEmpty ? "audio-dataset" : trimmed.lowercased()
    }
}

private struct WizardProgress: View {
    let steps: [String]
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                HStack(spacing: 6) {
                    Image(systemName: symbol(for: index))
                        .foregroundStyle(index <= selectedIndex ? OrgRecTheme.ai : .secondary)
                    Text(title)
                        .font(.caption.weight(index == selectedIndex ? .semibold : .regular))
                        .lineLimit(1)
                }
                if index < steps.count - 1 {
                    Rectangle().fill(OrgRecTheme.hairline).frame(height: 1)
                }
            }
        }
    }

    private func symbol(for index: Int) -> String {
        if index < selectedIndex { return "checkmark.circle.fill" }
        if index == selectedIndex { return "\(index + 1).circle.fill" }
        return "\(index + 1).circle"
    }
}
