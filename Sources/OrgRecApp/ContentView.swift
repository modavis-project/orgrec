import AppKit
import SwiftUI
import OrgRecCore
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                ProjectHeader()
                Divider()
                Group {
                    switch model.page {
                    case .audioAnalysis: StandaloneAudioView(model: model.standaloneAudio)
                    case .gettingStarted: GettingStartedView()
                    case .podDatabase: PODDatabaseImportView()
                    case .projects: ProjectsView()
                    case .datasetImport: DatasetImportView()
                    case .organSearch: OrganSearchView()
                    case .initialize: ProjectInitializationView()
                    case .roadmap: RoadmapView()
                    case .record: RecordView()
                    case .analysis: AnalysisView()
                    case .fieldQA: FieldQAView()
                    case .setup: SetupView()
                    case .interactionSensors: InteractionSensorLabView()
                    case .sync: SyncView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OrgRecTheme.washi)
            }
        }
        .tint(OrgRecTheme.shu)
        .foregroundStyle(OrgRecTheme.sumi)
        .alert("The action could not be completed", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 9) {
                if case let .dirty(message) = model.persistenceState {
                    PersistenceFailureBanner(message: message)
                }
                if let notice = model.notice {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(OrgRecTheme.ai)
                        Text(notice)
                        Button("Dismiss") { model.notice = nil }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(OrgRecTheme.surface, in: Capsule())
                    .overlay(Capsule().stroke(OrgRecTheme.hairline))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .task(id: model.notice) {
            guard let displayedNotice = model.notice else { return }
            try? await Task.sleep(for: .seconds(6))
            if model.notice == displayedNotice { model.notice = nil }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard urls.count == 1, let url = urls.first, url.isFileURL,
                  let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
                  type.conforms(to: .audio), !model.standaloneAudio.isWorking else { return false }
            model.page = .audioAnalysis
            return model.standaloneAudio.accept(urls)
        }
        .onOpenURL { url in
            Task { await model.openIncomingURL(url) }
        }
    }
}

private struct PersistenceFailureBanner: View {
    @EnvironmentObject private var model: AppModel
    let message: String

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(OrgRecTheme.shu)
            VStack(alignment: .leading, spacing: 2) {
                Text("Project changes are not saved").font(.callout.bold())
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 14)
            Button("Retry Save") { Task { await model.retryPersistence() } }
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .frame(maxWidth: 680)
        .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous)
                .stroke(OrgRecTheme.shu.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, y: 5)
        .accessibilityElement(children: .contain)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius).fill(OrgRecTheme.shu)
                    Image(systemName: "waveform.and.mic").foregroundStyle(OrgRecTheme.washi)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("OrgRec").font(.system(.headline, design: .serif, weight: .semibold)).tracking(0.2)
                    Text("Field capture").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)

            List {
                Section("Library") {
                    SidebarDestination(page: .gettingStarted)
                    SidebarDestination(page: .audioAnalysis)
                    SidebarDestination(page: .projects)
                    SidebarDestination(page: .datasetImport)
                    SidebarDestination(page: .organSearch)
                }

                if let project = model.project {
                    Section("Active Project") {
                        ForEach([AppPage.initialize, .roadmap, .fieldQA, .record, .analysis, .setup, .interactionSensors, .sync]) { page in
                            SidebarDestination(page: page)
                        }
                    }
                    Section {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(project.organName).fontWeight(.semibold).lineLimit(2)
                            Text(project.title).lineLimit(2)
                            HStack {
                                Label("\(project.roadmap.count)", systemImage: "list.number")
                                Label("\(project.takes.count)", systemImage: "waveform")
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("MODAVIS").font(.caption.bold())
                    Spacer()
                    Text(model.project.map { "Release \($0.snapshot.release.requestedRelease)" } ?? "No source selected").font(.caption2)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(OrgRecTheme.ai.opacity(0.12), in: Capsule())
                        .foregroundStyle(OrgRecTheme.ai)
                }
                Text(model.project?.organMDVSID == "MDVS:ORGN:DEMO" ? "Demonstration project" : "Frozen source snapshot")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .background(OrgRecTheme.recessed)
        .navigationSplitViewColumnWidth(min: 215, ideal: 235, max: 270)
    }
}

private struct SidebarDestination: View {
    @EnvironmentObject private var model: AppModel
    let page: AppPage

    var body: some View {
        Button { model.page = page } label: {
            Label(page.rawValue, systemImage: page.symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .foregroundStyle(model.page == page ? OrgRecTheme.ai : OrgRecTheme.sumi)
                .background(
                    model.page == page ? OrgRecTheme.ai.opacity(0.13) : .clear,
                    in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius, style: .continuous)
                )
                .overlay(alignment: .leading) {
                    if model.page == page {
                        Rectangle().fill(OrgRecTheme.ai).frame(width: 2).padding(.vertical, 5)
                    }
                }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
    }
}

private struct ProjectHeader: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.system(.headline, design: .serif, weight: .semibold))
                    .tracking(0.1)
                Text(headerSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isWorking {
                ProgressView().controlSize(.small)
            }
            if model.capture.isFinalizing {
                Label("Finalizing audio…", systemImage: "waveform.badge.checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHint("The recording has stopped and OrgRec is finishing its Broadcast Wave file")
            } else if model.persistenceState.isSaving {
                Label("Saving…", systemImage: "externaldrive")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if model.persistenceState.isDirty {
                Button {
                    Task { await model.retryPersistence() }
                } label: {
                    Label("Not Saved", systemImage: "externaldrive.badge.exclamationmark")
                }
                .buttonStyle(.bordered)
                .foregroundStyle(OrgRecTheme.shu)
                .help("Retry saving the active project")
            }
            if ![AppPage.projects, .organSearch, .gettingStarted, .podDatabase, .audioAnalysis].contains(model.page) {
                CoveragePill(summary: model.coverage)
            }
            if model.capture.isRecording {
                Label(model.capture.elapsed.formatted(.number.precision(.fractionLength(1))) + " s", systemImage: "record.circle.fill")
                    .foregroundStyle(OrgRecTheme.shu)
                    .font(.callout.monospacedDigit().bold())
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 62)
        .background(OrgRecTheme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(OrgRecTheme.hairline).frame(height: 1) }
    }

    private var headerTitle: String {
        switch model.page {
        case .audioAnalysis: "Standalone audio analysis"
        case .gettingStarted: "Welcome to OrgRec"
        case .podDatabase: "Set up the organ catalogue"
        case .projects: "Pipe-organ recording projects"
        case .datasetImport: "Dataset and VAO tools"
        case .organSearch: "Find a pipe organ"
        case .initialize: "Initialize the recording project"
        default: model.project?.title ?? "No active project"
        }
    }

    private var headerSubtitle: String {
        switch model.page {
        case .audioAnalysis: return "Inspect a file · review evidence · export results"
        case .gettingStarted: return "Choose a source · prepare a project · check your recording setup"
        case .podDatabase: return "Download once · verify · search offline"
        case .projects: return "Organ-grouped library · create, plan, import, and export"
        case .datasetImport: return "Inspect · verify identities and mappings · preserve · validate"
        case .organSearch: return "Search MODAVIS Navigator and compile a recording roadmap"
        case .initialize: return "MODAVIS evidence · field A4 · session readiness"
        default:
            guard let project = model.project else { return "Choose a project from the library" }
            return "\(project.organMDVSID) • \(project.snapshot.release.releaseState)"
        }
    }
}

private enum DatasetImportKind: String, CaseIterable, Identifiable {
    case audioDataset = "Audio dataset"
    case grandOrgue = "GrandOrgue"
    case podDatabase = "POD 1.6.0 database"
    var id: String { rawValue }
}

private struct DatasetImportView: View {
    @State private var kind: DatasetImportKind?

    var body: some View {
        Group {
            if let kind {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            self.kind = nil
                        } label: {
                            Label("All data workflows", systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(workflowLabel(for: kind))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(OrgRecTheme.surface)
                    Divider()
                    if kind == .audioDataset {
                        AudioDatasetVAOWizard()
                    } else if kind == .grandOrgue {
                        GrandOrgueVAOWizard()
                    } else {
                        PODDatabaseImportView()
                    }
                }
            } else {
                converterChoice
            }
        }
    }

    private var converterChoice: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Data and VAO workflows")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    Text("Choose the source you actually have. The converters use different evidence and never reinterpret one format as the other.")
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 18) {
                    converterCard(
                        kind: .audioDataset,
                        symbol: "waveform.badge.magnifyingglass",
                        title: "Audio dataset → VAO",
                        description: "For folders of more-or-less consistently named audio files. Parse filenames, verify stop and pitch mappings, then preserve the reviewed interpretation as source-bound evidence.",
                        evidence: "Evidence: filenames + audio headers + reviewed mapping"
                    )
                    converterCard(
                        kind: .grandOrgue,
                        symbol: "music.note.house",
                        title: "GrandOrgue → VAO",
                        description: "For a GrandOrgue sample set with an .organ file. Stops, compasses, pipe references, shared samples, and controls are read from the selected ODF.",
                        evidence: "Evidence: GrandOrgue ODF + self-contained source tree"
                    )
                    converterCard(
                        kind: .podDatabase,
                        symbol: "externaldrive.badge.checkmark",
                        title: "POD 1.6.0 local database",
                        description: "Verify and cache the separately published SQLite projection of MODAVIS Pipe Organ Dataset 1.5. Use it offline for organ search and specification-derived roadmaps.",
                        evidence: "Evidence: SQLite integrity + release metadata + schema + exact fixity"
                    )
                }
                GroupBox("Why consistent filenames matter") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Prefer one pattern for the entire folder, such as Principal8_060.wav or Principal8_C4.wav.", systemImage: "1.circle")
                        Label("Keep stop tokens identical across pitches; Principal8, Prin8, and P8 become three groups unless you deliberately reconcile them.", systemImage: "2.circle")
                        Label("Use MIDI numbers or scientific note names consistently, and mark variants explicitly, for example _rr2.", systemImage: "3.circle")
                        Text("Consistent names produce the strongest automatic grouping. The audio-dataset wizard still asks you to confirm every semantic mapping before VAO creation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(28)
            .frame(maxWidth: 1050, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func workflowLabel(for kind: DatasetImportKind) -> String {
        switch kind {
        case .audioDataset: "AUDIO DATASET WORKFLOW"
        case .grandOrgue: "GRANDORGUE WORKFLOW"
        case .podDatabase: "POD 1.6.0 DATABASE WORKFLOW"
        }
    }

    private func converterCard(
        kind: DatasetImportKind,
        symbol: String,
        title: String,
        description: String,
        evidence: String
    ) -> some View {
        Button { self.kind = kind } label: {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 31))
                    .foregroundStyle(OrgRecTheme.ai)
                Text(title).font(.title2.weight(.semibold))
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Divider()
                Text(evidence).font(.caption).foregroundStyle(.secondary)
                Label("Open converter", systemImage: "arrow.right.circle.fill")
                    .font(.callout.weight(.semibold))
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 285, alignment: .leading)
            .background(OrgRecTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(OrgRecTheme.hairline))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct PODDatabaseImportView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Install the POD 1.6.0 database")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    Text("Download the organ catalogue once to search offline and create recording plans. No Zenodo account or API key is needed. If you already have the unpacked OrgRec SQLite database, select it below and choose Cache verified database.")
                        .foregroundStyle(.secondary)
                }

                Text("Download: 1.8 GB · Installed database: 5.8 GB. Allow at least 15 GB free on the startup disk for the download, extraction and cache copies. Installation and verification can take several minutes; keep OrgRec open until the catalogue is ready.")
                    .font(.callout)

                GroupBox("Retrieve from Zenodo") {
                    HStack {
                        TextField("HTTPS database download URL", text: $model.podDatabaseDownloadURL)
                            .textFieldStyle(.roundedBorder)
                            .privacySensitive()
                        Button {
                            Task { await model.downloadPODDatabase() }
                        } label: {
                            Label("Download, verify & install", systemImage: "arrow.down.circle")
                        }
                        .disabled(model.isWorking || model.podDatabaseDownloadURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.top, 6)
                }

                GroupBox("Local source") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.podDatabaseSourceURL?.path ?? "No SQLite database selected")
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                        Button {
                            selectSource()
                        } label: {
                            Label("Choose SQLite database…", systemImage: "externaldrive")
                        }
                        .disabled(model.isWorking)
                    }
                    .padding(.top, 6)
                }

                if let inspection = model.podDatabaseInspection {
                    GroupBox("Verified release boundary") {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Release", value: inspection.releaseVersion ?? "Unknown")
                            LabeledContent("Projection", value: inspection.metadata["projection_profile"] ?? "Unknown")
                            LabeledContent("Contract", value: inspection.metadata["contract"] ?? "Unknown")
                            LabeledContent("Pinned artifact", value: inspection.matchesPublishedArtifact ? "Exact match" : "Different bytes")
                            LabeledContent("Database", value: "\(inspection.organCount.formatted()) organs · \(inspection.componentCount.formatted()) components")
                            LabeledContent("Roadmap coverage", value: "\(inspection.roadmapEligibleOrganCount.formatted()) eligible organs")
                            LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: inspection.fileSize, countStyle: .file))
                            LabeledContent("SHA-256", value: inspection.sha256)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            if inspection.errors.isEmpty == false {
                                Divider()
                                ForEach(inspection.errors, id: \.self) { error in
                                    Label(error, systemImage: "xmark.octagon.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                            ForEach(inspection.warnings, id: \.self) { warning in
                                Label(warning, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.top, 6)
                    }
                }

                if model.isWorking {
                    ProgressView("Installing or checking the catalogue…")
                        .accessibilityLabel("Catalogue operation in progress")
                }
                if let status = model.podDatabaseStatus {
                    Text(status).font(.callout).foregroundStyle(.secondary)
                }
                if model.podDatabaseCacheURL != nil {
                    Label("Catalogue installed — ready for offline organ search", systemImage: "checkmark.circle.fill")
                    Button("Continue to Find Organ") { model.page = .organSearch }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                }

                HStack {
                    Button {
                        Task { await model.importPODDatabase() }
                    } label: {
                        Label("Cache verified database", systemImage: "externaldrive.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.podDatabaseSourceURL == nil || model.podDatabaseInspection?.matchesPublishedArtifact != true || model.isWorking)

                    if model.podDatabaseCacheURL != nil {
                        Button("Reveal cache") { model.revealPODDatabaseCache() }
                        Button("Remove cached copy", role: .destructive) { model.removePODDatabaseCache() }
                            .disabled(model.isWorking)
                    }
                }

                Text("The POD 1.6.0 download expands to 5.8 GB. The database contains structured public facts, identifiers, and source citations; it declares that raw source media and descriptive prose are excluded. The prefilled URL points to the published OrgRec projection. You can also create a local project or import recordings without installing POD.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func selectSource() {
        let panel = NSOpenPanel()
        panel.title = "Choose the POD 1.6.0 OrgRec SQLite database"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlite") ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.inspectPODDatabase(at: url) }
    }
}

private struct ProjectsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var quickSearch = ""
    @State private var libraryFilter = ""
    @State private var showNewProject = false

    private var groups: [OrganProjectGroup] {
        guard libraryFilter.isEmpty == false else { return model.groupedProjects }
        return model.groupedProjects.compactMap { group in
            let projects = group.projects.filter {
                $0.title.localizedCaseInsensitiveContains(libraryFilter)
                    || $0.organName.localizedCaseInsensitiveContains(libraryFilter)
                    || $0.venueName.localizedCaseInsensitiveContains(libraryFilter)
                    || $0.organMDVSID.localizedCaseInsensitiveContains(libraryFilter)
            }
            return projects.isEmpty ? nil : OrganProjectGroup(
                id: group.id,
                organName: group.organName,
                organMDVSID: group.organMDVSID,
                projects: projects
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start with the organ").font(.system(.title, design: .serif, weight: .semibold))
                            Text("Find its MODAVIS specification and let OrgRec build the recording roadmap.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("New local project…") { showNewProject = true }
                            .buttonStyle(.bordered)
                        Button("Import VAO, project, or IAD…") { importProject() }
                            .buttonStyle(.bordered)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
                        TextField("Search for an organ, venue, builder, or MDVS ID", text: $quickSearch)
                            .textFieldStyle(.plain)
                            .font(.title3)
                            .onSubmit { Task { await model.showOrganSearch(query: quickSearch) } }
                        Button("Search MODAVIS") {
                            Task { await model.showOrganSearch(query: quickSearch) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(15)
                    .background(OrgRecTheme.washi, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous).stroke(OrgRecTheme.hairline))
                }
                .padding(20)
                .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
                .overlay(alignment: .leading) { Rectangle().fill(OrgRecTheme.shu).frame(width: 3) }

                if let inspection = model.importedVAO05Inspection {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("VAO \(VAO05Contract.formatVersion) validated workspace", systemImage: "cube.transparent")
                                .font(.headline)
                            Spacer()
                            Button("Show Workspace") { model.revealImportedVAO05Workspace() }
                                .buttonStyle(.bordered)
                        }
                        Text(inspection.displayTitle).font(.system(.title3, design: .serif, weight: .semibold))
                        HStack(spacing: 18) {
                            Label("\(inspection.realizationCount) realizations", systemImage: "shippingbox")
                            Label("\(inspection.trackCount) tracks", systemImage: "timeline.selection")
                            Label("\(inspection.scientificRecordCount) scientific records", systemImage: "atom")
                            Label("\(inspection.physicalComponentCount) physical components", systemImage: "point.3.connected.trianglepath.dotted")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(OrgRecTheme.washi, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
                }

                if let inspection = model.importedVAO04Inspection {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("VAO \(VAO04Contract.formatVersion) validated scientific workspace", systemImage: "cube.transparent")
                                .font(.headline)
                            Spacer()
                            Button("Show Workspace") { model.revealImportedVAO04Workspace() }
                                .buttonStyle(.bordered)
                        }
                        Text(inspection.displayTitle).font(.system(.title3, design: .serif, weight: .semibold))
                        HStack(spacing: 18) {
                            Label("\(inspection.manifest.realizations.count) realizations", systemImage: "shippingbox")
                            Label("\(inspection.trackCount) tracks", systemImage: "timeline.selection")
                            Label("\(inspection.scientificRecordCount) scientific records", systemImage: "atom")
                            Label("\(inspection.manifest.physicalSystem.components.count) physical components", systemImage: "point.3.connected.trianglepath.dotted")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(OrgRecTheme.washi, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
                }

                if let inspection = model.importedVAO03Inspection {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("VAO \(VAO03Contract.formatVersion) validated workspace", systemImage: "cube.transparent")
                                .font(.headline)
                            Spacer()
                            Button("Show Workspace") { model.revealImportedVAO03Workspace() }
                                .buttonStyle(.bordered)
                        }
                        Text(inspection.displayTitle)
                            .font(.system(.title3, design: .serif, weight: .semibold))
                        VStack(alignment: .leading, spacing: 6) {
                            if let scene = inspection.acousticScene {
                                HStack(spacing: 18) {
                                    Label("\(scene.geometryResources.count) geometry", systemImage: "cube")
                                    Label("\(scene.impulseResponseResources.count) RIR", systemImage: "waveform")
                                    Label("\(scene.measurements.count) source–receiver pairs", systemImage: "point.3.connected.trianglepath.dotted")
                                    Label("\(scene.coordinateFrames.count) frames", systemImage: "move.3d")
                                }
                            }
                            if let playable = inspection.playableInstrument {
                                HStack(spacing: 18) {
                                    Label("\(playable.sampleMappings.count) mappings", systemImage: "pianokeys")
                                    Label("\(playable.sampleVariants.count) variants", systemImage: "waveform.badge.plus")
                                    Label("\(playable.loopPointSets.count) loop sets", systemImage: "repeat")
                                    Label("\(playable.perspectiveGroups.count) perspectives", systemImage: "mic")
                                }
                            }
                            if let complex = inspection.complexInstrument {
                                HStack(spacing: 18) {
                                    Label("\(complex.controlCount) controls", systemImage: "switch.2")
                                    Label("\(complex.routingRuleCount) routes", systemImage: "arrow.triangle.branch")
                                    Label("\(complex.processCount) processes", systemImage: "gearshape.2")
                                    Label("\(complex.eventAlignmentCount) alignments", systemImage: "timeline.selection")
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Text("OrgRec verified the exact carrier and exposed its typed acoustic, playable, interaction, and capture-lineage resources. Sampler execution, synthesis, process execution, acoustic rendering, and unsupported codecs remain the responsibility of compatible engines.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius).stroke(OrgRecTheme.ai.opacity(0.35)))
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Project library").font(.system(.title2, design: .serif, weight: .semibold))
                        Text("\(model.projectLibrary.count) projects grouped across \(model.groupedProjects.count) organs")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    TextField("Filter projects", text: $libraryFilter)
                        .textFieldStyle(.roundedBorder).frame(width: 260)
                    Button { Task { await model.refreshProjectLibrary() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                if groups.isEmpty {
                    ContentUnavailableView(
                        libraryFilter.isEmpty ? "No recording projects" : "No matching projects",
                        systemImage: "music.note.house",
                        description: Text(libraryFilter.isEmpty ? "Search MODAVIS or create a local project to begin." : "Try a different project or organ name.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 250)
                } else {
                    ForEach(groups) { group in
                        OrganProjectSection(group: group)
                    }
                }
            }
            .padding(24)
        }
        .task {
            if model.newProjectRequestID != nil {
                showNewProject = true
                model.newProjectRequestID = nil
            }
            await model.refreshProjectLibrary()
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet().environmentObject(model)
        }
        .onChange(of: model.newProjectRequestID) { _, requestID in
            guard requestID != nil else { return }
            showNewProject = true
            model.newProjectRequestID = nil
        }
    }

    private func importProject() {
        let panel = NSOpenPanel()
        panel.title = "Import Virtual Acoustic Object, OrgRec Project, or Instrumental Audio Dataset"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.importProject(from: url) }
        }
    }
}

private struct OrganProjectSection: View {
    @EnvironmentObject private var model: AppModel
    let group: OrganProjectGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "music.note.house.fill").foregroundStyle(OrgRecTheme.shu)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.organName).font(.headline)
                    Text(group.organMDVSID).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(group.projects.count) project\(group.projects.count == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(group.projects) { project in
                ProjectLibraryRow(summary: project)
            }
        }
        .padding(16)
        .background(OrgRecTheme.recessed.opacity(0.55), in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
    }
}

private struct ProjectLibraryRow: View {
    @EnvironmentObject private var model: AppModel
    let summary: RecordingProjectSummary

    var body: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(summary.title).fontWeight(.semibold)
                    if summary.isActive {
                        Text("ACTIVE").font(.caption2.bold()).foregroundStyle(OrgRecTheme.ai)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(OrgRecTheme.ai.opacity(0.12), in: Capsule())
                    }
                }
                Text([summary.venueName, "Updated \(summary.updatedAt.formatted(date: .abbreviated, time: .shortened))"]
                    .filter { $0.isEmpty == false }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: summary.coverage.fraction).frame(width: 130)
                Text("\(Int(summary.coverage.fraction * 100))% · \(summary.coverage.accepted)/\(summary.coverage.applicableRequired) accepted")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Label("\(summary.roadmapItems)", systemImage: "list.number").font(.caption).frame(width: 62)
            Label("\(summary.takes)", systemImage: "waveform").font(.caption).frame(width: 55)
            Label(
                "QA \(summary.consistencyScore)",
                systemImage: summary.consistencyBlockers == 0 ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
            )
            .font(.caption.bold())
            .foregroundStyle(summary.consistencyBlockers == 0 ? OrgRecTheme.ai : OrgRecTheme.shu)
            .frame(width: 72)
            Button("Open") { Task { await model.openProject(summary) } }
                .buttonStyle(.borderedProminent).controlSize(.small)
            Button("Plan") { Task { await model.openProject(summary, destinationPage: .roadmap) } }
                .buttonStyle(.bordered).controlSize(.small)
            Menu {
                Button("Export VAO…") { exportVAO() }
                Button("Export IAD / Navigator package…") { exportCapture() }
                Divider()
                Button("Export editable project…") { exportEditable() }
                Button("Show in Finder") { model.revealProject(summary) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton).frame(width: 28)
        }
        .padding(13)
        .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous).stroke(summary.isActive ? OrgRecTheme.ai.opacity(0.45) : OrgRecTheme.hairline))
    }

    private func exportEditable() {
        let panel = NSSavePanel()
        panel.title = "Export Editable OrgRec Project"
        panel.nameFieldStringValue = safeFilename(summary.title) + ".orgrec"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.exportEditableProject(summary, to: url) }
        }
    }

    private func exportVAO() {
        let panel = NSSavePanel()
        panel.title = "Export Virtual Acoustic Object"
        panel.nameFieldStringValue = safeFilename(summary.title) + ".vao"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.exportVAO(summary, to: url) }
        }
    }

    private func exportCapture() {
        let panel = NSSavePanel()
        panel.title = "Export Instrumental Audio Dataset Package"
        panel.nameFieldStringValue = safeFilename(summary.title) + ".orgrec-capture"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.exportCapturePackage(summary, to: url) }
        }
    }
}

private struct NewProjectSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var organName = ""
    @State private var organMDVSID = ""
    @State private var venueName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("New local recording project").font(.system(.title2, design: .serif, weight: .semibold))
                    Text("Create a project shell now, then attach a MODAVIS specification from Find Organ.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create project") {
                    Task {
                        await model.createManualProject(
                            title: title,
                            organName: organName,
                            organMDVSID: organMDVSID,
                            venueName: venueName
                        )
                        if model.errorMessage == nil { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(organName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            Divider()
            Form {
                Section("Project") {
                    TextField("Project title (optional)", text: $title)
                    TextField("Pipe organ name", text: $organName)
                    TextField("Venue", text: $venueName)
                    TextField("MODAVIS organ ID (optional)", text: $organMDVSID)
                }
                Section {
                    Text("A local project has no generated roadmap until a specification is retrieved. Recordings should begin only after the organ's stops, compasses, couplers, and accessories have been reviewed.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 680, height: 410)
    }
}

private struct OrganSearchView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MODAVIS · ORGAN CATALOGUE").eyebrow()
                    Label("Find a pipe organ", systemImage: "magnifyingglass")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        .foregroundStyle(OrgRecTheme.sumi)
                    Text(model.canAttachNavigatorOrganToActiveProject
                         ? "Choose an organ to attach its specification to the active local project and build its roadmap."
                         : "Choose an organ to create a separate recording project with a specification-derived roadmap.")
                        .font(.title3).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 11) {
                        Image(systemName: "magnifyingglass").font(.title)
                        TextField("Organ, venue, builder, city, or MDVS ID", text: $model.navigatorQuery)
                            .textFieldStyle(.plain).font(.title2)
                            .onSubmit { Task { await model.searchNavigator() } }
                        Button("Search") { Task { await model.searchNavigator() } }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(
                                (model.podDatabaseCacheURL == nil && model.navigatorURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    || model.navigatorQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                    }
                    .padding(18)
                    .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous).stroke(OrgRecTheme.shu.opacity(0.48)))
                    HStack {
                        if let inspection = model.podDatabaseInspection, model.podDatabaseCacheURL != nil {
                            Label("Local POD \(inspection.releaseVersion ?? "1.6.0") SQLite catalogue", systemImage: "internaldrive.fill")
                            Text("\(inspection.organCount.formatted()) organs · read-only")
                        } else {
                            Text("Navigator")
                            TextField("Base URL", text: $model.navigatorURL)
                                .textFieldStyle(.roundedBorder).frame(width: 310)
                            Button("Install POD 1.6.0…") { model.page = .podDatabase }
                        }
                        Spacer()
                        Button("Back to projects") { model.page = .projects }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }

                if model.navigatorResults.isEmpty {
                    ContentUnavailableView(
                        model.navigatorQuery.isEmpty ? "Search the organ database" : "No results loaded",
                        systemImage: "building.columns",
                        description: Text("OrgRec reads the local POD database or Navigator, freezes the selected structured projection, and compiles a field roadmap.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    Text("\(model.navigatorResults.count) organs").font(.headline)
                    LazyVStack(spacing: 10) {
                        ForEach(model.navigatorResults) { organ in
                            HStack(spacing: 15) {
                                Image(systemName: "music.note.house.fill")
                                    .font(.title2).foregroundStyle(OrgRecTheme.shu).frame(width: 34)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(organ.title).font(.headline)
                                    Text([organ.location, organ.builder, organ.dateLabel].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(organ.mdvsID).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(model.canAttachNavigatorOrganToActiveProject ? "Attach & build roadmap" : "Create recording project") {
                                    Task { await model.importNavigatorOrgan(organ) }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(16)
                            .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous).stroke(OrgRecTheme.hairline))
                        }
                    }
                }
            }
            .padding(28)
        }
    }
}

private struct CoveragePill: View {
    let summary: CoverageSummary

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("PROJECT COMPLETION")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(summary.fraction * 100))%")
                    .font(.caption.monospacedDigit().bold())
            }
            ProgressView(value: min(max(summary.fraction, 0), 1))
                .progressViewStyle(.linear)
                .tint(OrgRecTheme.ai)
            HStack {
                Text("\(summary.accepted) / \(summary.applicableRequired) accepted")
                Spacer()
                Text("\(summary.review) review")
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .frame(width: 190)
        .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius, style: .continuous).stroke(OrgRecTheme.hairline))
    }
}

private struct RoadmapView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var stateFilter: RoadmapState?
    @State private var showRegistrationPlanner = false
    @State private var showInstrumentNoisePlanner = false
    @State private var showComplexCapturePlanner = false
    @State private var showSpatialAcousticPlanner = false
    @State private var showControlMap = false
    @State private var showSoundingTargetPlanner = false
    @State private var sessionPlannerRequest: SessionPlannerRequest?
    @State private var mapAssessment: NoiseContextAssessment?
    @State private var showSourceDetails = false
    @State private var showPhysicalOverlapReview = false
    @State private var selectedSoundID: String?
    @State private var expandedDivisions = Set<String>()

    private var roadmap: [RoadmapItem] { model.project?.roadmap ?? [] }

    private var filteredItems: [RoadmapItem] {
        roadmap.filter { item in
            let textMatch = search.isEmpty ||
                item.component.label.localizedCaseInsensitiveContains(search) ||
                item.component.division.localizedCaseInsensitiveContains(search) ||
                (item.component.noteName ?? "").localizedCaseInsensitiveContains(search) ||
                item.technique.rawValue.localizedCaseInsensitiveContains(search) ||
                (item.instrumentNoiseProtocol?.kind.displayName.localizedCaseInsensitiveContains(search) ?? false) ||
                (item.instrumentNoiseProtocol?.variantLabel.localizedCaseInsensitiveContains(search) ?? false) ||
                (item.complexCaptureProtocol?.kind.displayName.localizedCaseInsensitiveContains(search) ?? false) ||
                (item.complexCaptureProtocol?.name.localizedCaseInsensitiveContains(search) ?? false) ||
                (item.spatialAcousticProtocol?.name.localizedCaseInsensitiveContains(search) ?? false) ||
                (item.activationRoutes ?? []).contains {
                    $0.component.label.localizedCaseInsensitiveContains(search) ||
                    ($0.component.noteName ?? "").localizedCaseInsensitiveContains(search)
                }
            return textMatch && (stateFilter == nil || item.state == stateFilter)
        }
    }

    private var soundGroups: [RoadmapSoundGroup] {
        Dictionary(grouping: filteredItems) { item in
            RoadmapSoundGroup.identifier(division: item.component.division, label: item.component.label)
        }
        .compactMap { id, items in
            guard let first = items.first else { return nil }
            return RoadmapSoundGroup(id: id, division: first.component.division, label: first.component.label, items: items)
        }
        .sorted {
            let divisionOrder = $0.division.localizedStandardCompare($1.division)
            return divisionOrder == .orderedSame
                ? $0.label.localizedStandardCompare($1.label) == .orderedAscending
                : divisionOrder == .orderedAscending
        }
    }

    private var activeGroup: RoadmapSoundGroup? {
        soundGroups.first { $0.id == selectedSoundID } ?? soundGroups.first
    }

    private func completeItems(for group: RoadmapSoundGroup) -> [RoadmapItem] {
        roadmap.filter {
            $0.component.division == group.division && $0.component.label == group.label
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    roadmapHeading
                    Spacer()
                    sourceControls
                    statePicker
                    capturePlanningMenu
                    planSessionButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        roadmapHeading
                        Spacer()
                        planSessionButton
                    }
                    HStack(spacing: 12) {
                        sourceControls
                        statePicker
                        Spacer()
                        capturePlanningMenu
                    }
                }
            }
            .padding(.horizontal, 22).padding(.vertical, 16)

            if showSourceDetails, let report = model.project?.roadmapCompilation {
                RoadmapCompilationBanner(report: report, characteristics: model.project?.organCharacteristics)
                    .padding(.horizontal, 22).padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let plan = model.roadmapSessionPlan {
                SessionPlanRoadmapBanner(
                    plan: plan,
                    edit: {
                        sessionPlannerRequest = SessionPlannerRequest(editingPlanID: plan.id)
                    },
                    showMap: {
                        mapAssessment = model.noiseContext(for: plan)
                    }
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
            }

            if roadmap.isEmpty {
                ContentUnavailableView(
                    "No roadmap available",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Attach a MODAVIS organ specification to compile its recording roadmap.")
                )
            } else if let activeGroup {
                HStack(spacing: 0) {
                    RoadmapSoundNavigator(
                        groups: soundGroups,
                        allItems: roadmap,
                        selectedID: Binding(
                            get: { activeGroup.id },
                            set: { selectedSoundID = $0 }
                        ),
                        expandedDivisions: $expandedDivisions,
                        visibleItemCount: filteredItems.count
                    )
                    .frame(width: 280)

                    Divider()

                    RoadmapSoundDetail(
                        group: activeGroup,
                        allItems: completeItems(for: activeGroup),
                        groupIndex: soundGroups.firstIndex(where: { $0.id == activeGroup.id }) ?? 0,
                        groupCount: soundGroups.count,
                        selectPrevious: { moveSelection(by: -1) },
                        selectNext: { moveSelection(by: 1) }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ContentUnavailableView.search(text: search)
            }
        }
        .onAppear { establishSelection() }
        .onChange(of: soundGroups.map(\.id)) { _, _ in establishSelection() }
        .searchable(
            text: $search,
            placement: .toolbar,
            prompt: "Find division, stop, note, or technique"
        )
        .sheet(isPresented: $showRegistrationPlanner) {
            RegistrationPlannerSheet().environmentObject(model)
        }
        .sheet(isPresented: $showInstrumentNoisePlanner) {
            InstrumentNoisePlannerSheet().environmentObject(model)
        }
        .sheet(isPresented: $showControlMap) {
            ControlMapSheet().environmentObject(model)
        }
        .sheet(isPresented: $showSoundingTargetPlanner) {
            SoundingTargetPlannerSheet().environmentObject(model)
        }
        .sheet(isPresented: $showComplexCapturePlanner) {
            ComplexCapturePlannerSheet().environmentObject(model)
        }
        .sheet(isPresented: $showSpatialAcousticPlanner) {
            SpatialAcousticPlannerSheet().environmentObject(model)
        }
        .sheet(item: $sessionPlannerRequest) { request in
            RecordingSessionPlannerSheet(editingPlanID: request.editingPlanID).environmentObject(model)
        }
        .sheet(item: $mapAssessment) { assessment in
            NoiseContextMapSheet(assessment: assessment)
        }
        .sheet(isPresented: $showPhysicalOverlapReview) {
            PhysicalOverlapReviewSheet().environmentObject(model)
        }
    }

    private var roadmapHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Recording roadmap")
                .font(.system(.title2, design: .serif, weight: .semibold))
            Text("Navigate by division and sound; open individual techniques inside each note.")
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var sourceControls: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showSourceDetails.toggle() }
            } label: {
                Label(showSourceDetails ? "Hide source" : "MODAVIS source", systemImage: "link")
            }
            .buttonStyle(.bordered)
            .fixedSize()

            if (model.project?.physicalOverlapCandidates?.isEmpty == false)
                || (model.project?.pipeSharingAssertions?.isEmpty == false) {
                Button {
                    showPhysicalOverlapReview = true
                } label: {
                    Label(
                        "Shared pipes",
                        systemImage: (model.project?.physicalOverlapCandidates?.isEmpty == false)
                            ? "exclamationmark.triangle"
                            : "link"
                    )
                }
                .buttonStyle(.bordered)
                .fixedSize()
            }
        }
    }

    private var statePicker: some View {
        Picker("State", selection: $stateFilter) {
            Text("All states").tag(RoadmapState?.none)
            Text("Missing").tag(RoadmapState?.some(.missing))
            Text("Review").tag(RoadmapState?.some(.needsReview))
            Text("Accepted").tag(RoadmapState?.some(.accepted))
        }
        .frame(width: 150)
    }

    private var capturePlanningMenu: some View {
        Menu {
            Button("Registration…") { showRegistrationPlanner = true }
            Button("Instrument noise…") { showInstrumentNoisePlanner = true }
            Button("Sound or effect…") { showSoundingTargetPlanner = true }
            Divider()
            Button("Complex capture…") { showComplexCapturePlanner = true }
            Button("Spatial response…") { showSpatialAcousticPlanner = true }
            Divider()
            Button {
                showControlMap = true
            } label: {
                Label("Control map…", systemImage: "cable.connector")
            }
        } label: {
            Label("Add Capture Plan", systemImage: "plus.rectangle.on.rectangle")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Add a registration, sound, noise, complex-instrument, or spatial-response capture plan")
    }

    private var planSessionButton: some View {
        Button {
            sessionPlannerRequest = SessionPlannerRequest(editingPlanID: nil)
        } label: {
            Label("Plan session…", systemImage: "calendar.badge.clock")
        }
        .buttonStyle(.borderedProminent)
        .fixedSize()
    }

    private struct SessionPlannerRequest: Identifiable {
        let id = UUID()
        let editingPlanID: UUID?
    }

    private func establishSelection() {
        if let selectedSoundID, soundGroups.contains(where: { $0.id == selectedSoundID }) {
            if let group = soundGroups.first(where: { $0.id == selectedSoundID }) {
                expandedDivisions.insert(group.division)
            }
            return
        }
        if let item = model.selectedRoadmapItem {
            let id = RoadmapSoundGroup.identifier(division: item.component.division, label: item.component.label)
            if soundGroups.contains(where: { $0.id == id }) {
                selectedSoundID = id
                expandedDivisions.insert(item.component.division)
                return
            }
        }
        selectedSoundID = soundGroups.first?.id
        if let division = soundGroups.first?.division { expandedDivisions.insert(division) }
    }

    private func moveSelection(by offset: Int) {
        guard let activeGroup,
              let index = soundGroups.firstIndex(where: { $0.id == activeGroup.id }) else { return }
        let destination = min(max(index + offset, 0), soundGroups.count - 1)
        let group = soundGroups[destination]
        selectedSoundID = group.id
        expandedDivisions.insert(group.division)
    }
}

private struct RoadmapSoundGroup: Identifiable {
    let id: String
    let division: String
    let label: String
    let items: [RoadmapItem]

    static func identifier(division: String, label: String) -> String {
        division + "\u{1F}" + label
    }
}

private struct RoadmapSoundNavigator: View {
    let groups: [RoadmapSoundGroup]
    let allItems: [RoadmapItem]
    @Binding var selectedID: String
    @Binding var expandedDivisions: Set<String>
    let visibleItemCount: Int

    private var divisions: [(String, [RoadmapSoundGroup])] {
        Dictionary(grouping: groups, by: \.division)
            .map { ($0.key, $0.value.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }) }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SOUND NAVIGATOR").eyebrow()
                Text("\(groups.count) sounds · \(visibleItemCount) captures")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(divisions, id: \.0) { division, groups in
                        divisionSection(division, groups: groups)
                    }
                }
                .padding(10)
            }
        }
        .background(OrgRecTheme.recessed.opacity(0.58))
    }

    @ViewBuilder
    private func divisionSection(_ division: String, groups: [RoadmapSoundGroup]) -> some View {
        let divisionItems = allItems.filter { $0.component.division == division }
        let coverage = RoadmapEngine.coverage(divisionItems)
        VStack(spacing: 4) {
            Button {
                if expandedDivisions.contains(division) { expandedDivisions.remove(division) }
                else { expandedDivisions.insert(division) }
            } label: {
                VStack(spacing: 7) {
                    HStack {
                        Image(systemName: expandedDivisions.contains(division) ? "chevron.down" : "chevron.right")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text(division).font(.callout.bold()).lineLimit(1)
                        Spacer()
                        Text("\(Int(coverage.fraction * 100))%")
                            .font(.caption.monospacedDigit().bold())
                    }
                    ProgressView(value: coverage.fraction).tint(OrgRecTheme.ai)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 9).padding(.vertical, 8)

            if expandedDivisions.contains(division) {
                ForEach(groups) { group in
                    soundButton(group)
                }
            }
        }
        .padding(3)
        .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous).stroke(OrgRecTheme.hairline))
    }

    private func soundButton(_ group: RoadmapSoundGroup) -> some View {
        let completeItems = allItems.filter {
            $0.component.division == group.division && $0.component.label == group.label
        }
        let coverage = RoadmapEngine.coverage(completeItems)
        return Button {
            selectedID = group.id
        } label: {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(selectedID == group.id ? OrgRecTheme.ai : .clear)
                    .frame(width: 2, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.label).font(.callout).fontWeight(selectedID == group.id ? .semibold : .regular).lineLimit(1)
                    Text("\(coverage.accepted)/\(coverage.applicableRequired) · \(coverage.review) review")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                if coverage.fraction == 1 {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(OrgRecTheme.ai)
                } else {
                    Text("\(Int(coverage.fraction * 100))%")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 7).padding(.vertical, 5)
            .background(selectedID == group.id ? OrgRecTheme.ai.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PhysicalOverlapReviewSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var componentsByID: [String: OrganComponent] {
        Dictionary((model.project?.organComponents ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Physical pipe sharing").font(.title2.bold())
                    Text("Only source-confirmed or explicitly reviewed relationships suppress capture obligations.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            List {
                let candidates = model.project?.physicalOverlapCandidates ?? []
                if candidates.isEmpty == false {
                    Section("Requires review") {
                        ForEach(candidates) { candidate in
                            let first = componentsByID[candidate.firstStopComponentID]
                            let second = componentsByID[candidate.secondStopComponentID]
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(first?.label ?? candidate.firstStopComponentID) ↔ \(second?.label ?? candidate.secondStopComponentID)")
                                            .font(.headline)
                                        Text("\(candidate.overlappingAddressCount) potentially shared positions · sounding MIDI \(candidate.soundingMIDILow)–\(candidate.soundingMIDIHigh)")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Confirm shared rank") {
                                        Task { await model.confirmPhysicalOverlap(candidate) }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(model.project?.takes.isEmpty == false)
                                }
                                Text(candidate.reason).font(.caption).foregroundStyle(.secondary)
                                Text("Example: \(first?.label ?? "first stop") MIDI \(candidate.soundingMIDILow - candidate.firstSoundingSemitoneOffset) and \(second?.label ?? "second stop") MIDI \(candidate.soundingMIDILow - candidate.secondSoundingSemitoneOffset) would become alternate routes to one physical target.")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                let assertions = model.project?.pipeSharingAssertions ?? []
                if assertions.isEmpty == false {
                    Section("Reviewed local assertions") {
                        ForEach(assertions) { assertion in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(assertion.stops.compactMap { componentsByID[$0.stopComponentID]?.label }.joined(separator: " ↔ "))
                                        .font(.headline)
                                    Text("Sounding MIDI \(assertion.soundingMIDILow)–\(assertion.soundingMIDIHigh) · \(assertion.author) · \(assertion.reviewedAt.formatted())")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(assertion.note).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    Task { await model.removePipeSharingAssertion(assertion.id) }
                                }
                                .disabled(model.project?.takes.isEmpty == false)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                if candidates.isEmpty && assertions.isEmpty {
                    ContentUnavailableView("No shared-pipe review needed", systemImage: "checkmark.seal")
                }
                if model.project?.takes.isEmpty == false {
                    Section {
                        Label("This roadmap already has takes. Physical groupings are frozen so take identifiers and coverage cannot be silently rewritten.", systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}

private struct RoadmapCompilationBanner: View {
    let report: RoadmapCompilationReport
    let characteristics: OrganSpecificationCharacteristics?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 18) {
                Label("\(report.sourceStopCount) stops", systemImage: "slider.vertical.3")
                Label("\(report.physicalSoundTargetCount ?? report.generatedAtomicSoundCount) physical targets", systemImage: "pianokeys")
                if let logical = report.logicalSoundAddressCount,
                   let physical = report.physicalSoundTargetCount {
                    Label("\(logical) addresses → \(physical) physical targets", systemImage: "arrow.triangle.merge")
                }
                if let aliases = report.sharedAliasCount, aliases > 0 {
                    Label("\(aliases) shared aliases", systemImage: "link")
                }
                Label("\(report.sourceCouplerCount) couplers", systemImage: "arrow.triangle.branch")
                Label("\(report.sourceAccessoryCount) accessories", systemImage: "sparkles")
                if let instrumentNoise = report.generatedInstrumentNoiseCount, instrumentNoise > 0 {
                    Label("\(instrumentNoise) noise protocols", systemImage: "waveform.badge.plus")
                }
                if let intended = report.generatedIntendedSoundTargetCount, intended > 0 {
                    Label("\(intended) intended effect captures", systemImage: "sparkles.rectangle.stack")
                }
                if let ranks = report.sourceRankCount, ranks > 0 {
                    Label("\(ranks) ranks", systemImage: "line.3.horizontal.decrease")
                }
                if let pitch = report.referencePitchHz {
                    Text("A4 \(pitch.formatted(.number.precision(.fractionLength(0...2)))) Hz" + ((report.tuningPitchAssumed ?? false) ? " assumed" : ""))
                }
                if let temperament = report.temperament {
                    Text(temperament).lineLimit(1)
                }
                Spacer()
                Text("\(report.theoreticalRegistrationStateCount) theoretical switch states")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .font(.callout.bold())
            ForEach(report.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(OrgRecTheme.shu)
            }
            if let characteristics {
                HStack(spacing: 14) {
                    if let builder = characteristics.builder { Label(builder, systemImage: "hammer") }
                    if let date = characteristics.buildDateLabel { Label(date, systemImage: "calendar") }
                    if let action = characteristics.actionType { Label(action, systemImage: "pianokeys") }
                    if let pressure = characteristics.windPressure { Label(pressure, systemImage: "wind") }
                    if let sources = characteristics.sourceCount { Label("\(sources) sources", systemImage: "doc.on.doc") }
                    if let documented = characteristics.documentedStopCount {
                        let agrees = documented == report.sourceStopCount
                        Label(
                            agrees ? "Stop count reconciled" : "\(documented) documented / \(report.sourceStopCount) parsed",
                            systemImage: agrees ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(agrees ? OrgRecTheme.ai : OrgRecTheme.shu)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(13)
        .background(OrgRecTheme.ai.opacity(0.07), in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
        .overlay(alignment: .top) { Rectangle().fill(OrgRecTheme.ai).frame(height: 2) }
    }
}

private struct RoadmapNoteGroup: Identifiable {
    let id: String
    let note: String
    let midi: Int?
    let items: [RoadmapItem]
}

private struct RoadmapSoundDetail: View {
    @EnvironmentObject private var model: AppModel
    let group: RoadmapSoundGroup
    let allItems: [RoadmapItem]
    let groupIndex: Int
    let groupCount: Int
    let selectPrevious: () -> Void
    let selectNext: () -> Void

    private var coverage: CoverageSummary { RoadmapEngine.coverage(allItems) }

    private var noteGroups: [RoadmapNoteGroup] {
        Dictionary(grouping: group.items) { item in
            item.component.midiNote.map(String.init) ?? item.component.noteName ?? "control"
        }
        .compactMap { id, items in
            guard let first = items.first else { return nil }
            return RoadmapNoteGroup(
                id: id,
                note: first.component.noteName ?? "Control",
                midi: first.component.midiNote,
                items: items.sorted { techniqueIndex($0.technique) < techniqueIndex($1.technique) }
            )
        }
        .sorted {
            if let left = $0.midi, let right = $1.midi { return left < right }
            if $0.midi != nil { return true }
            if $1.midi != nil { return false }
            return $0.note.localizedStandardCompare($1.note) == .orderedAscending
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.division).eyebrow()
                    Text(group.label)
                        .font(.system(.title2, design: .serif, weight: .semibold))
                    Text("\(noteGroups.count) notes · \(group.items.count) visible captures")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                RoadmapGroupCoverage(summary: coverage)

                HStack(spacing: 4) {
                    Button(action: selectPrevious) { Image(systemName: "chevron.left") }
                        .disabled(groupIndex == 0)
                        .help("Previous sound")
                    Text("\(groupIndex + 1) / \(groupCount)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(minWidth: 44)
                    Button(action: selectNext) { Image(systemName: "chevron.right") }
                        .disabled(groupIndex + 1 >= groupCount)
                        .help("Next sound")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    if let item = RoadmapEngine.nextItem(in: allItems) ?? allItems.first {
                        model.select(item, record: true)
                    }
                } label: {
                    Label("Record next", systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(allItems.isEmpty)
            }
            .padding(.horizontal, 18).padding(.vertical, 13)
            .background(OrgRecTheme.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(OrgRecTheme.hairline).frame(height: 1) }

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 285, maximum: 390), spacing: 10, alignment: .top)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(noteGroups) { noteGroup in
                        RoadmapNoteCard(group: noteGroup)
                    }
                }
                .padding(14)
            }
            .background(OrgRecTheme.recessed.opacity(0.35))
        }
    }

    private func techniqueIndex(_ technique: CaptureTechnique) -> Int {
        CaptureTechnique.allCases.firstIndex(of: technique) ?? 0
    }
}

private struct RoadmapGroupCoverage: View {
    let summary: CoverageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("SOUND COVERAGE").font(.caption2.weight(.semibold)).tracking(0.7)
                Spacer()
                Text("\(Int(summary.fraction * 100))%").font(.caption.monospacedDigit().bold())
            }
            ProgressView(value: summary.fraction).tint(OrgRecTheme.ai)
            HStack(spacing: 10) {
                Label("\(summary.accepted)", systemImage: "checkmark.circle.fill").foregroundStyle(OrgRecTheme.ai)
                Label("\(summary.review)", systemImage: "eye.circle.fill").foregroundStyle(OrgRecTheme.shu)
                Label("\(summary.missing)", systemImage: "circle.dashed").foregroundStyle(.secondary)
            }
            .font(.caption2.monospacedDigit())
        }
        .frame(width: 155)
    }
}

private struct RoadmapNoteCard: View {
    let group: RoadmapNoteGroup

    private var expectedFrequency: Double? {
        group.items.compactMap(\.component.expectedFrequencyHz).first
    }

    private var aliases: [PhysicalActivationRoute] {
        guard let item = group.items.first else { return [] }
        return (item.activationRoutes ?? []).filter { $0.id != item.primaryActivationRouteID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.note).font(.system(.headline, design: .serif, weight: .semibold))
                if let midi = group.midi {
                    Text("MIDI \(midi)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                if let expectedFrequency {
                    Text(expectedFrequency.formatted(.number.precision(.fractionLength(1))) + " Hz")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 11).padding(.vertical, 9)
            .background(OrgRecTheme.ai.opacity(0.07))

            if aliases.isEmpty == false {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "link")
                    Text("One physical target; also addressed by " + aliases.map {
                        "\($0.component.label) \($0.component.noteName ?? "")"
                    }.joined(separator: ", ") + ". These aliases are not separate recording tasks.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 11).padding(.vertical, 7)
            }

            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider().padding(.leading, 11) }
                RoadmapCompactCaptureRow(item: item)
            }
        }
        .background(OrgRecTheme.surface, in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous).stroke(OrgRecTheme.hairline))
    }
}

private struct RoadmapCompactCaptureRow: View {
    @EnvironmentObject private var model: AppModel
    let item: RoadmapItem

    var body: some View {
        Button {
            model.select(item, record: true)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: techniqueSymbol)
                    .foregroundStyle(OrgRecTheme.ai)
                    .frame(width: 16)
                Text(item.technique.rawValue).font(.caption).lineLimit(1)
                if item.minimumAcceptedTakeCount > 1,
                   let project = model.project {
                    let accepted = acceptedTakeCount(in: project)
                    Text("\(accepted)/\(item.minimumAcceptedTakeCount)")
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(accepted >= item.minimumAcceptedTakeCount ? OrgRecTheme.ai : .secondary)
                        .help("Accepted repetitions")
                }
                Spacer(minLength: 4)
                StatusBadge(state: item.state)
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(OrgRecTheme.shu)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(model.selectedRoadmapID == item.id ? OrgRecTheme.ai.opacity(0.11) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens this capture task in the recording workspace")
        .help("Open \(item.component.noteName ?? "capture") for recording")
    }

    private var accessibilityLabel: String {
        let note = item.component.noteName.map { "\(item.component.label) \($0)" } ?? item.component.label
        return "\(note), \(item.technique.rawValue)"
    }

    private var accessibilityValue: String {
        var parts = [item.state.rawValue.replacingOccurrences(of: "needsReview", with: "Needs review")]
        if item.minimumAcceptedTakeCount > 1, let project = model.project {
            parts.append("\(acceptedTakeCount(in: project)) of \(item.minimumAcceptedTakeCount) accepted takes")
        }
        return parts.joined(separator: ", ")
    }

    private func acceptedTakeCount(in project: OrgRecProject) -> Int {
        project.takes.filter {
            item.takeIDs.contains($0.id) && $0.status == .accepted
        }.count
    }

    private var techniqueSymbol: String {
        switch item.technique {
        case .closePair: "mic.fill"
        case .naveORTF: "arrow.left.and.right"
        case .rearOmni: "dot.radiowaves.left.and.right"
        case .releaseTail: "waveform.path"
        }
    }
}

private struct InstrumentNoisePlannerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedComponentID = ""
    @State private var customComponentLabel = ""
    @State private var kind: InstrumentNoiseKind = .keyAction
    @State private var actions: Set<InstrumentNoiseAction> = [.activation, .release]
    @State private var velocities: Set<InstrumentNoiseVelocityPreset> = [.slow, .normal, .fast]
    @State private var configurationLabels = "Standard configuration"
    @State private var fromPosition = ""
    @State private var toPosition = ""
    @State private var includePedalActuation = false
    @State private var minimumTakes = 3
    @State private var captureDuration = 8.0
    @State private var technique: CaptureTechnique = .closePair
    @State private var required = true
    @State private var sourceScope: AcousticSourceScope = .instrument
    @State private var mechanisms: Set<AcousticMechanism> = [.mechanical, .structuralContact]
    @State private var role: AcousticEventRole = .intendedTarget
    @State private var actuationQuantity: ActuationQuantity = .position
    @State private var customQuantityLabel = ""
    @State private var actuationUnit = "normalized 0–1"
    @State private var curveKind: ActuationCurveKind = .smoothSCurve
    @State private var curveInterpolation: ActuationInterpolation = .linear
    @State private var curveStartValue = "0"
    @State private var curveEndValue = "1"
    @State private var curveDuration = 1.0
    @State private var customCurvePoints = "0:0, 0.25:0.1, 0.75:0.9, 1:1"
    @State private var curveEvidence: ActuationEvidenceSource = .operatorPlanned
    @State private var commandDeviceLabel = ""
    @State private var calibrationReference = ""
    @State private var uncertainty = ""
    @State private var actuationNotes = ""

    private var components: [OrganComponent] {
        (model.project?.organComponents ?? []).filter {
            let kind = $0.kind.lowercased()
            return kind != "pipe" && kind != "pipe_position" && kind != "pipeposition"
        }.sorted {
            if $0.division != $1.division { return $0.division.localizedStandardCompare($1.division) == .orderedAscending }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    private var availableTechniques: [CaptureTechnique] {
        model.project?.recipe.techniques ?? CaptureTechnique.allCases
    }

    private var configurations: [InstrumentNoiseConfiguration] {
        let labels = configurationLabels
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        return (labels.isEmpty ? ["Standard configuration"] : labels).map {
            InstrumentNoiseConfiguration(
                label: $0,
                fromPosition: nonEmpty(fromPosition),
                toPosition: nonEmpty(toPosition),
                pedalActuationIncluded: includePedalActuation
            )
        }
    }

    private var estimatedVariantCount: Int {
        actions.reduce(0) { result, action in
            result + (usesVelocity(action) ? max(1, velocities.count) : 1) * configurations.count
        }
    }

    private var actuationProfile: ActuationProfile? {
        guard let startValue = Double(curveStartValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let endValue = Double(curveEndValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              curveDuration > 0 else { return nil }
        var curve: ActuationCurve
        if curveKind == .custom {
            let points = customCurvePoints
                .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isNewline })
                .compactMap { token -> ActuationCurvePoint? in
                    let pair = token.split(separator: ":", maxSplits: 1).map {
                        $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    guard pair.count == 2, let time = Double(pair[0]), let value = Double(pair[1]) else { return nil }
                    return ActuationCurvePoint(time: time, value: value)
                }
            curve = ActuationCurve(
                kind: .custom,
                timeBasis: .normalized,
                interpolation: curveInterpolation,
                points: points,
                durationSeconds: curveDuration,
                evidenceSource: curveEvidence
            )
        } else {
            curve = ActuationCurve.preset(
                kind: curveKind,
                startValue: startValue,
                endValue: endValue,
                durationSeconds: curveDuration,
                evidenceSource: curveEvidence
            )
            curve.interpolation = curveInterpolation
        }
        curve.deviceLabel = nonEmpty(commandDeviceLabel)
        curve.calibrationReference = nonEmpty(calibrationReference)
        curve.uncertainty = Double(uncertainty.trimmingCharacters(in: .whitespacesAndNewlines))
        let values = curve.points.map(\.value)
        return ActuationProfile(
            quantity: actuationQuantity,
            customQuantityLabel: nonEmpty(customQuantityLabel),
            unit: actuationUnit.trimmingCharacters(in: .whitespacesAndNewlines),
            minimumValue: values.min(),
            maximumValue: values.max(),
            commandedCurve: curve,
            notes: actuationNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private var actuationValidationIssues: [String] {
        var issues = actuationProfile?.validationIssues ?? ["Enter valid start, end, and duration values."]
        let uncertaintyText = uncertainty.trimmingCharacters(in: .whitespacesAndNewlines)
        if uncertaintyText.isEmpty == false && Double(uncertaintyText) == nil {
            issues.append("Uncertainty must be numeric.")
        }
        return issues
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plan instrument mechanics and auxiliaries")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                    Text("Create separately recordable action, direction, velocity, configuration, and repetition targets.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(estimatedVariantCount) Roadmap variant\(estimatedVariantCount == 1 ? "" : "s")")
                    .font(.callout.monospacedDigit().bold())
                    .foregroundStyle(OrgRecTheme.ai)
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox("Source mechanism") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Specification component", selection: $selectedComponentID) {
                                Text("Organ-wide or operator-defined mechanism").tag("")
                                ForEach(components) { component in
                                    Text("\(component.division) · \(component.label)").tag(component.id)
                                }
                            }
                            if selectedComponentID.isEmpty {
                                TextField("Mechanism name, e.g. Main blower or Jalousie bank II", text: $customComponentLabel)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Picker("Noise family", selection: $kind) {
                                ForEach(InstrumentNoiseKind.allCases) { Text($0.displayName).tag($0) }
                            }
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("Actions and directions") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 175))], alignment: .leading, spacing: 8) {
                            ForEach(InstrumentNoiseAction.allCases) { action in
                                Toggle(action.displayName, isOn: membershipBinding(action, in: $actions))
                                    .toggleStyle(.checkbox)
                            }
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("Acoustic classification") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Picker("Source scope", selection: $sourceScope) {
                                    ForEach(AcousticSourceScope.allCases) { Text($0.displayName).tag($0) }
                                }
                                Picker("Role", selection: $role) {
                                    ForEach(AcousticEventRole.allCases) { Text($0.displayName).tag($0) }
                                }
                            }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 165))], alignment: .leading, spacing: 8) {
                                ForEach(AcousticMechanism.allCases) { mechanism in
                                    Toggle(mechanism.displayName, isOn: membershipBinding(mechanism, in: $mechanisms))
                                        .toggleStyle(.checkbox)
                                }
                            }
                            Text("Temporal behavior and operating phase are derived separately for each selected action; source, mechanism, and role remain independent classifications.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("Velocity and dynamic character") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 22) {
                                ForEach(InstrumentNoiseVelocityPreset.allCases) { velocity in
                                    Toggle("\(velocity.displayName) · MIDI \(velocity.midiVelocity)", isOn: membershipBinding(velocity, in: $velocities))
                                        .toggleStyle(.checkbox)
                                }
                            }
                            Text("Velocity is applied to keys, pedals, stops, and moving controls. Startup, shutdown, baselines, and steady operation remain unmetered.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("Commanded action curve") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Picker("Quantity", selection: $actuationQuantity) {
                                    ForEach(ActuationQuantity.allCases) { Text($0.displayName).tag($0) }
                                }
                                TextField("Unit", text: $actuationUnit)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 190)
                            }
                            if actuationQuantity == .custom {
                                TextField("Custom quantity name", text: $customQuantityLabel)
                                    .textFieldStyle(.roundedBorder)
                            }
                            HStack {
                                Picker("Curve", selection: $curveKind) {
                                    ForEach(ActuationCurveKind.allCases) { Text($0.displayName).tag($0) }
                                }
                                Picker("Interpolation", selection: $curveInterpolation) {
                                    ForEach(ActuationInterpolation.allCases) { Text($0.displayName).tag($0) }
                                }
                            }
                            HStack {
                                TextField("Forward start", text: $curveStartValue)
                                TextField("Forward end", text: $curveEndValue)
                                Stepper(
                                    "Fallback duration: \(curveDuration.formatted(.number.precision(.fractionLength(1...2)))) s",
                                    value: $curveDuration,
                                    in: 0.05...60,
                                    step: 0.05
                                )
                            }
                            .textFieldStyle(.roundedBorder)
                            if curveKind == .custom {
                                TextField("Normalized time:value points, e.g. 0:0, 0.4:0.15, 1:1", text: $customCurvePoints)
                                    .textFieldStyle(.roundedBorder)
                            }
                            if let profile = actuationProfile, profile.validationIssues.isEmpty {
                                ActuationCurvePlot(
                                    planned: profile.commandedCurve,
                                    observed: nil,
                                    minimumValue: profile.minimumValue,
                                    maximumValue: profile.maximumValue
                                )
                                .frame(height: 125)
                            }
                            HStack {
                                Picker("Command evidence", selection: $curveEvidence) {
                                    Text(ActuationEvidenceSource.operatorPlanned.displayName).tag(ActuationEvidenceSource.operatorPlanned)
                                    Text(ActuationEvidenceSource.controllerCommanded.displayName).tag(ActuationEvidenceSource.controllerCommanded)
                                }
                                TextField("Controller / device (optional)", text: $commandDeviceLabel)
                            }
                            .textFieldStyle(.roundedBorder)
                            HStack {
                                TextField("Calibration reference (optional)", text: $calibrationReference)
                                TextField("± uncertainty in selected unit", text: $uncertainty)
                                    .frame(maxWidth: 230)
                            }
                            .textFieldStyle(.roundedBorder)
                            TextField("Curve notes (optional)", text: $actuationNotes)
                                .textFieldStyle(.roundedBorder)
                            if actuationValidationIssues.isEmpty == false {
                                Label(actuationValidationIssues.joined(separator: " "), systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(OrgRecTheme.shu)
                            } else {
                                Text("Author the activation/opening/press trajectory. Position-like profiles are reversed automatically for release, deactivation, closing, and pedal release. Velocity variants preserve the shape and apply their documented target duration.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("Configurations") {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("One or more configurations, separated by commas or semicolons", text: $configurationLabels)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                TextField("From position (optional)", text: $fromPosition)
                                TextField("To position (optional)", text: $toPosition)
                            }
                            .textFieldStyle(.roundedBorder)
                            Toggle("Include pedal and linkage actuation", isOn: $includePedalActuation)
                            Text("Use separate configurations for multiple swell boxes, jalousie banks, mechanical linkages, console modes, or wind-system states.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }

                    GroupBox("Capture and coverage") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Microphone technique", selection: $technique) {
                                ForEach(availableTechniques) { Text($0.rawValue).tag($0) }
                            }
                            Stepper("Retain at least \(minimumTakes) accepted take\(minimumTakes == 1 ? "" : "s") per variant", value: $minimumTakes, in: 1...20)
                            Stepper("Capture window: \(captureDuration.formatted(.number.precision(.fractionLength(0...1)))) s", value: $captureDuration, in: 3...60, step: 1)
                            Toggle("Required Roadmap obligation", isOn: $required)
                            Text("Every take freezes the complete protocol and receives a repetition number. Action markers record structured begin/end paradata.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Add \(estimatedVariantCount) variant\(estimatedVariantCount == 1 ? "" : "s")") {
                    Task {
                        await model.addInstrumentNoisePlan(
                            componentID: nonEmpty(selectedComponentID),
                            customComponentLabel: customComponentLabel,
                            kind: kind,
                            actions: actions,
                            velocityPresets: velocities,
                            configurations: configurations,
                            minimumAcceptedTakeCount: minimumTakes,
                            captureDurationSeconds: captureDuration,
                            technique: technique,
                            required: required,
                            sourceScope: sourceScope,
                            mechanisms: mechanisms,
                            role: role,
                            actuationProfile: actuationProfile!
                        )
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(actions.isEmpty || mechanisms.isEmpty || estimatedVariantCount == 0 || actuationValidationIssues.isEmpty == false || (selectedComponentID.isEmpty && customComponentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
            .padding(16)
        }
        .frame(minWidth: 820, minHeight: 720)
        .onAppear {
            if availableTechniques.contains(technique) == false, let first = availableTechniques.first { technique = first }
        }
        .onChange(of: kind) { _, newKind in applyDefaults(for: newKind) }
        .onChange(of: actuationQuantity) { _, newQuantity in
            actuationUnit = newQuantity.suggestedUnit
            if newQuantity == .midiVelocity {
                curveStartValue = "1"
                curveEndValue = "127"
            } else if newQuantity == .actionProgress || newQuantity == .position || newQuantity == .switchState {
                curveStartValue = "0"
                curveEndValue = "1"
            }
        }
    }

    private func membershipBinding<Element: Hashable>(_ value: Element, in set: Binding<Set<Element>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(value) },
            set: { enabled in
                if enabled { set.wrappedValue.insert(value) }
                else { set.wrappedValue.remove(value) }
            }
        )
    }

    private func usesVelocity(_ action: InstrumentNoiseAction) -> Bool {
        switch action {
        case .activation, .release, .deactivation, .opening, .closing, .pedalPress, .pedalRelease, .movement: true
        case .startup, .steadyOperation, .shutdown, .idleBaseline: false
        }
    }

    private func nonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func applyDefaults(for kind: InstrumentNoiseKind) {
        switch kind {
        case .keyAction:
            actions = [.activation, .release]
            sourceScope = .instrument
            mechanisms = [.mechanical, .structuralContact]
            actuationQuantity = .position
            curveKind = .smoothSCurve
        case .stopAction, .couplerAction, .accessoryAction:
            actions = [.activation, .deactivation]
            sourceScope = .instrument
            mechanisms = [.mechanical, .structuralContact]
            actuationQuantity = .switchState
            curveKind = .stepped
        case .tremulant:
            actions = [.activation, .deactivation]
            sourceScope = .instrument
            mechanisms = [.mechanical, .pneumatic, .aerodynamicFlow]
            actuationQuantity = .switchState
            curveKind = .stepped
        case .blower:
            actions = [.startup, .steadyOperation, .shutdown]
            sourceScope = .instrumentAuxiliary
            mechanisms = [.electrical, .mechanical, .aerodynamicFlow]
            actuationQuantity = .actionProgress
            curveKind = .easeIn
        case .windSystem:
            actions = [.startup, .steadyOperation, .shutdown]
            sourceScope = .instrumentAuxiliary
            mechanisms = [.pneumatic, .aerodynamicFlow, .mechanical]
            actuationQuantity = .actionProgress
            curveKind = .easeIn
        case .swellerJalousie:
            actions = [.opening, .closing, .pedalPress, .pedalRelease]
            includePedalActuation = true
            captureDuration = 10
            sourceScope = .instrument
            mechanisms = [.mechanical, .aerodynamicFlow, .structuralContact]
            actuationQuantity = .position
            curveKind = .smoothSCurve
        case .pedalAction:
            actions = [.pedalPress, .pedalRelease]
            sourceScope = .instrument
            mechanisms = [.mechanical, .structuralContact]
            actuationQuantity = .position
            curveKind = .smoothSCurve
        case .other:
            actions = [.activation, .deactivation]
            sourceScope = .instrument
            mechanisms = [.mechanical]
            actuationQuantity = .actionProgress
            curveKind = .linear
        }
        curveInterpolation = curveKind == .stepped ? .step : .linear
    }
}

private struct RegistrationPlannerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = "Custom registration"
    @State private var selected = Set<String>()
    @State private var midiLow = 36
    @State private var midiHigh = 96
    @State private var step = 1
    @State private var exhaustive = false

    private var components: [OrganComponent] { model.project?.organComponents ?? [] }
    private var stops: [OrganComponent] { components.filter { $0.kind == "stop" } }
    private var couplers: [OrganComponent] { components.filter { $0.kind == "coupler" } }
    private var accessories: [OrganComponent] { components.filter { $0.kind == "accessory" } }
    private var selectedStopCount: Int { stops.filter { selected.contains($0.id) }.count }
    private var selectedControlCount: Int {
        (couplers + accessories).filter { selected.contains($0.id) }.count
    }
    private var perRegistrationCaptureCount: Int {
        guard midiLow <= midiHigh else { return 0 }
        return ((midiHigh - midiLow) / max(1, step) + 1) * (model.project?.recipe.techniques.count ?? 0)
    }
    private var registrationCount: Int? {
        exhaustive ? RoadmapEngine.exhaustiveSubsetCount(stopCount: selectedStopCount, controlCount: selectedControlCount) : 1
    }
    private var captureCount: Int? { registrationCount.map { $0 * perRegistrationCaptureCount } }
    private var addButtonTitle: String {
        if selectedStopCount == 0 { return "Select a speaking stop" }
        return captureCount.map { "Add \($0) captures" } ?? "Selection too large"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Plan any organ registration").font(.system(.title2, design: .serif, weight: .semibold))
                    Text("Every selected control is linked to the frozen MODAVIS specification.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button(addButtonTitle) {
                    Task {
                        if exhaustive {
                            await model.addExhaustiveRegistrationSubsets(
                                name: name,
                                componentIDs: selected,
                                midiLow: midiLow,
                                midiHigh: midiHigh,
                                step: step
                            )
                        } else {
                            await model.addCustomRegistration(
                                name: name,
                                componentIDs: selected,
                                midiLow: midiLow,
                                midiHigh: midiHigh,
                                step: step
                            )
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedStopCount == 0 || captureCount == nil || (captureCount ?? 0) == 0 || (captureCount ?? 0) > 50_000)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Registration name", text: $name).textFieldStyle(.roundedBorder)
                    Toggle("Generate every sound-producing subset of the selected switches", isOn: $exhaustive)
                    if exhaustive {
                        Text(selectedStopCount == 0 ? "Select at least one speaking stop." : registrationCount.map {
                            "This creates all \($0) subsets containing at least one speaking stop. Maximum: 10 selected switches and 50,000 resulting captures."
                        } ?? "Select no more than 10 switches for exhaustive generation. Larger individual combinations remain available in normal mode.")
                        .font(.caption).foregroundStyle(registrationCount == nil ? OrgRecTheme.shu : Color.secondary)
                    }
                    HStack {
                        Stepper("Lowest MIDI \(midiLow)", value: $midiLow, in: 0...127)
                        Stepper("Highest MIDI \(midiHigh)", value: $midiHigh, in: 0...127)
                        Stepper("Step \(step)", value: $step, in: 1...24)
                    }
                    Text("Step 1 records every chromatic key. Larger steps sample this custom combination while isolated-stop coverage remains exhaustive.")
                        .font(.caption).foregroundStyle(.secondary)
                    componentSection("Speaking stops", components: stops)
                    componentSection("Couplers", components: couplers)
                    componentSection("Accessories and playing aids", components: accessories)
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, minHeight: 680)
    }

    @ViewBuilder
    private func componentSection(_ title: String, components: [OrganComponent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if components.isEmpty {
                Text("None documented in the selected Navigator specification.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), alignment: .leading)], alignment: .leading, spacing: 7) {
                    ForEach(components) { component in
                        Toggle(isOn: Binding(
                            get: { selected.contains(component.id) },
                            set: { enabled in
                                if enabled { selected.insert(component.id) }
                                else { selected.remove(component.id) }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(component.label).lineLimit(1)
                                Text(component.division).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }
}

private struct ProjectInitializationView: View {
    @EnvironmentObject private var model: AppModel
    @State private var candidateID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("RECORDING PROJECT INITIALIZATION").eyebrow()
                    Text("Verify identity, establish A4, then record")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                    Text("The MODAVIS value is imported as documentary evidence. A short field measurement establishes the reference pitch for this session and enables live intended-note checking.")
                        .font(.title3).foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 14)], spacing: 14) {
                    InitializationStep(number: 1, title: "Organ identity", detail: identityDetail, complete: model.project?.snapshot.endpoint != "manual://orgrec-project", action: "Find organ") {
                        model.page = .organSearch
                    }
                    InitializationStep(number: 2, title: "Roadmap", detail: "\(model.project?.roadmap.count ?? 0) planned captures from the frozen specification", complete: model.project?.roadmap.isEmpty == false, action: "Inspect roadmap") {
                        model.page = .roadmap
                    }
                    InitializationStep(number: 3, title: "Session & environment", detail: sessionDetail, complete: sessionComplete, action: "Edit paradata") {
                        model.page = .fieldQA
                    }
                    InitializationStep(number: 4, title: "Audio setup", detail: setupDetail, complete: model.audioSystem.selectedDevice != nil && model.project?.setups.isEmpty == false, action: "Open setup") {
                        model.page = .setup
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        Image(systemName: "tuningfork").font(.title).foregroundStyle(OrgRecTheme.shu)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("5 · Reference pitch").font(.title2.bold())
                            Text("Documentary prior and field measurement are intentionally separate.")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.acceptedCalibration != nil {
                            Label("Session initialized", systemImage: "checkmark.seal.fill").foregroundStyle(OrgRecTheme.ai)
                        }
                    }

                    HStack(alignment: .top, spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("MODAVIS documented A4").font(.headline)
                            if let pitch = model.project?.documentedPitchStandard {
                                Text("\(pitch.frequencyHz.formatted(.number.precision(.fractionLength(2)))) Hz")
                                    .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
                                Text("Inserted automatically from MODAVIS \(pitch.modavisRelease) · \(pitch.evidenceStatus ?? "source assertion")")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let sourcePath = pitch.sourcePath {
                                    Text(sourcePath).font(.caption2.monospaced()).textSelection(.enabled).foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Not supplied").font(.title3.bold()).foregroundStyle(OrgRecTheme.shu)
                                Text("OrgRec will use 440 Hz only as an analysis prior until the field value is accepted.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current session field A4").font(.headline)
                            if let calibration = model.latestCalibration {
                                Text(calibration.normalizedA4Hz.map { "\($0.formatted(.number.precision(.fractionLength(2)))) Hz" } ?? "No stable estimate")
                                    .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
                                HStack {
                                    Text(calibration.status.rawValue.capitalized)
                                    if let cents = calibration.centsFromDocumented {
                                        Text("\(cents.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))) cents from documented")
                                    }
                                    if let confidence = calibration.confidence { Text("confidence \(confidence.formatted(.percent.precision(.fractionLength(0))))") }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                                if calibration.status == .pending {
                                    HStack {
                                        Button("Reject") { Task { await model.rejectPitchCalibration(calibration.id) } }
                                        Button("Accept and recalculate") { Task { await model.acceptPitchCalibration(calibration.id) } }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(calibration.normalizedA4Hz == nil)
                                    }
                                }
                            } else {
                                Text("Not measured").font(.title3.bold()).foregroundStyle(OrgRecTheme.shu)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()
                    Text("Choose an isolated unison 8′ stop, disable tremulant/celeste/couplers, play A4 steadily, and record at least three seconds. OrgRec stores the calibration WAV, environment, estimator, confidence, checksum, and acceptance decision.")
                        .font(.callout).foregroundStyle(.secondary)
                    if model.calibrationCandidates.isEmpty {
                        Label("No A4 unison candidate exists in the compiled roadmap. Attach or repair the specification first.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(OrgRecTheme.shu)
                    } else {
                        HStack {
                            Picker("A4 reference", selection: Binding(
                                get: { candidateID ?? model.calibrationCandidates.first?.id },
                                set: { candidateID = $0 }
                            )) {
                                ForEach(model.calibrationCandidates) { item in
                                    Text("\(item.component.label) · \(item.component.division) · \(item.component.footHeight ?? "8′")").tag(Optional(item.id))
                                }
                            }
                            .frame(maxWidth: 430)
                            Spacer()
                            Button {
                                Task {
                                    if model.isCalibrating { await model.stopPitchCalibration() }
                                    else if let id = candidateID ?? model.calibrationCandidates.first?.id,
                                            let item = model.calibrationCandidates.first(where: { $0.id == id }) {
                                        await model.startPitchCalibration(using: item)
                                    }
                                }
                            } label: {
                                Label(model.isCalibrating ? "Stop and estimate A4" : "Record field A4", systemImage: model.isCalibrating ? "stop.fill" : "record.circle")
                            }
                            .buttonStyle(.borderedProminent).tint(OrgRecTheme.shu)
                            .disabled(
                                model.isWorking
                                    || model.capture.isFinalizing
                                    || (model.capture.isRecording && model.isCalibrating == false)
                            )
                        }
                    }
                }
                .card()

                HStack {
                    Label(model.acceptedCalibration == nil ? "Normal recording remains blocked until field A4 is accepted." : "Live frequency and intended-note checks are enabled for this session.", systemImage: model.acceptedCalibration == nil ? "lock.fill" : "waveform.badge.magnifyingglass")
                        .foregroundStyle(model.acceptedCalibration == nil ? OrgRecTheme.shu : OrgRecTheme.ai)
                    Spacer()
                    Button("Continue to Record") { model.page = .record }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.acceptedCalibration == nil)
                }
                .card()
            }
            .padding(24)
        }
        .onAppear { candidateID = candidateID ?? model.calibrationCandidates.first?.id }
    }

    private var identityDetail: String {
        guard let project = model.project else { return "No project" }
        return "\(project.organMDVSID) · MODAVIS \(project.snapshot.release.requestedRelease) · frozen SHA-256 \(project.snapshot.payloadSHA256.prefix(10))…"
    }

    private var sessionComplete: Bool {
        guard let session = model.activeSession else { return false }
        return session.operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && session.environment.temperatureCelsius != nil
            && session.environment.relativeHumidityPercent != nil
    }

    private var sessionDetail: String {
        guard let session = model.activeSession else { return "No active session" }
        let operatorName = session.operatorName.isEmpty ? "operator missing" : session.operatorName
        let environment = session.environment.temperatureCelsius.map { "\($0.formatted()) °C" } ?? "temperature missing"
        return "\(session.sessionCode) · \(operatorName) · \(environment)"
    }

    private var setupDetail: String {
        if let device = model.audioSystem.selectedDevice { return "\(device.name) · \(device.inputChannels) input channels" }
        return "No Core Audio interface selected"
    }
}

private struct InitializationStep: View {
    let number: Int
    let title: String
    let detail: String
    let complete: Bool
    let action: String
    let perform: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(number)").font(.caption.bold()).frame(width: 26, height: 26)
                    .background((complete ? OrgRecTheme.ai : OrgRecTheme.shu).opacity(0.14), in: Circle())
                Text(title).font(.headline)
                Spacer()
                Image(systemName: complete ? "checkmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(complete ? OrgRecTheme.ai : OrgRecTheme.shu)
            }
            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            Button(action, action: perform).buttonStyle(.link)
        }
        .card()
    }
}

private struct StatusBadge: View {
    let state: RoadmapState
    var color: Color {
        switch state {
        case .accepted: OrgRecTheme.ai
        case .needsReview, .recorded: OrgRecTheme.shu
        case .rejected, .unresolved: OrgRecTheme.shu
        case .queued: OrgRecTheme.ai
        case .exempt: .secondary
        case .missing: .secondary
        }
    }
    var body: some View {
        Text(state.rawValue.replacingOccurrences(of: "needsReview", with: "Review"))
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct SoundingTargetPlannerSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedComponentID = "__local__"
    @State private var localLabel = ""
    @State private var family: SoundingTargetFamily = .oneShotEffect
    @State private var behavior: SoundingTargetTemporalBehavior = .discrete
    @State private var trigger: SoundingTargetTriggerMode = .stopTab
    @State private var useKeyboardRange = false
    @State private var midiLow = 36
    @State private var midiHigh = 96
    @State private var minimumTakes = 3
    @State private var hasDuration = false
    @State private var duration = 6.0
    @State private var memberIDs = ""
    @State private var notes = ""
    @State private var required = true
    @State private var techniques = Set<CaptureTechnique>([.closePair])

    private var components: [OrganComponent] {
        (model.project?.organComponents ?? [])
            .filter { !["division", "rank", "pipe", "pipe_position"].contains($0.kind) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    private var definition: SoundingTargetDefinition {
        SoundingTargetDefinition(
            family: family,
            temporalBehavior: behavior,
            triggerMode: trigger,
            memberComponentIDs: memberIDs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            minimumAcceptedTakeCount: minimumTakes,
            plannedDurationSeconds: hasDuration ? duration : nil,
            captureRelease: true,
            notes: notes
        )
    }

    private var selectedSource: OrganComponent? {
        components.first { $0.id == selectedComponentID }
    }

    private var priorTakesExist: Bool {
        guard let source = selectedSource else { return false }
        let ids = model.project?.roadmap.filter {
            $0.soundingTargetDefinition != nil && ($0.component.id == source.id || $0.component.parentComponentID == source.id)
        }.flatMap(\.takeIDs) ?? []
        return ids.isEmpty == false
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan intended sound / effect").font(.title2.bold())
                    Text("Use this to add or correct cinema-organ sounding content. Its actuator noise remains a separate Roadmap family.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save target") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(canSave == false)
            }
            .padding(20)
            Divider()
            Form {
                Section("Source component") {
                    Picker("Component", selection: $selectedComponentID) {
                        Text("New local sounding component").tag("__local__")
                        ForEach(components) { component in
                            Text("\(component.label) · \(component.division)").tag(component.id)
                        }
                    }
                    if selectedComponentID == "__local__" {
                        TextField("Documented sound/effect label", text: $localLabel)
                    } else if priorTakesExist {
                        Label("This target already has takes. Its frozen contract cannot be replaced; create a new local component revision.", systemImage: "lock.fill")
                            .foregroundStyle(OrgRecTheme.shu)
                    }
                }

                Section("Sounding-target contract") {
                    Picker("Family", selection: $family) {
                        ForEach(SoundingTargetFamily.allCases.filter { $0 != .pipeSpeech }) { value in Text(value.displayName).tag(value) }
                    }
                    Picker("Temporal behavior", selection: $behavior) {
                        ForEach(SoundingTargetTemporalBehavior.allCases, id: \.self) { value in Text(value.rawValue.capitalized).tag(value) }
                    }
                    Picker("Trigger", selection: $trigger) {
                        ForEach(SoundingTargetTriggerMode.allCases, id: \.self) { value in Text(value.rawValue).tag(value) }
                    }
                    Toggle("Expand a keyboard MIDI range", isOn: $useKeyboardRange)
                    if useKeyboardRange {
                        Stepper("Lowest raw MIDI note \(midiLow)", value: $midiLow, in: 0...127)
                        Stepper("Highest raw MIDI note \(midiHigh)", value: $midiHigh, in: midiLow...127)
                    }
                    Stepper("Minimum accepted takes \(minimumTakes)", value: $minimumTakes, in: 1...20)
                    Toggle("Planned active duration", isOn: $hasDuration)
                    if hasDuration {
                        HStack {
                            Slider(value: $duration, in: 0.1...60, step: 0.1)
                            Text("\(duration.formatted(.number.precision(.fractionLength(1)))) s").font(.caption.monospacedDigit()).frame(width: 58)
                        }
                    }
                    TextField("Constituent component IDs, comma-separated", text: $memberIDs)
                    if family == .compositeEffect && definition.memberComponentIDs.isEmpty {
                        Label("Composite targets require at least one constituent component ID.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(OrgRecTheme.shu)
                    }
                    TextField("Capture notes", text: $notes, axis: .vertical).lineLimit(2...5)
                }

                Section("Roadmap expansion") {
                    ForEach(CaptureTechnique.allCases, id: \.self) { technique in
                        Toggle(technique.rawValue, isOn: Binding(
                            get: { techniques.contains(technique) },
                            set: { enabled in
                                if enabled { techniques.insert(technique) }
                                else { techniques.remove(technique) }
                            }
                        ))
                    }
                    Toggle("Required for coverage", isOn: $required)
                    Text("Each key (when ranged) × selected microphone technique becomes a separate obligation; repeat takes remain linked to that exact target.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 780, minHeight: 720)
        .onChange(of: family) { _, value in
            switch value {
            case .sustainedEffect: behavior = .sustained
            case .repeatingEffect: behavior = .repeating
            case .sequencedEffect: behavior = .sequenced
            case .compositeEffect: behavior = .composite
            default: behavior = .discrete
            }
        }
        .onChange(of: useKeyboardRange) { _, enabled in
            if enabled { trigger = .keyboardKey }
        }
        .onChange(of: selectedComponentID) { _, _ in loadSelectedComponent() }
        .onAppear {
            if let selected = model.selectedRoadmapItem?.component {
                let sourceID = selected.parentComponentID ?? selected.id
                if components.contains(where: { $0.id == sourceID }) { selectedComponentID = sourceID }
            }
            loadSelectedComponent()
        }
    }

    private var canSave: Bool {
        let labelExists = selectedComponentID != "__local__" || localLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return labelExists && midiLow <= midiHigh && techniques.isEmpty == false && definition.validationIssues.isEmpty && priorTakesExist == false
    }

    private func loadSelectedComponent() {
        guard let component = selectedSource else { return }
        localLabel = component.label
        useKeyboardRange = component.playableMIDILow != nil && component.playableMIDIHigh != nil
        midiLow = component.playableMIDILow ?? midiLow
        midiHigh = component.playableMIDIHigh ?? midiHigh
        if let existing = component.soundingTargetDefinition ?? RoadmapEngine.soundingTargetDefinition(for: component) {
            family = existing.family
            behavior = existing.temporalBehavior
            trigger = existing.triggerMode
            minimumTakes = existing.minimumAcceptedTakeCount
            hasDuration = existing.plannedDurationSeconds != nil
            duration = existing.plannedDurationSeconds ?? duration
            memberIDs = existing.memberComponentIDs.joined(separator: ", ")
            notes = existing.notes
        }
    }

    private func save() {
        guard let project = model.project else { return }
        var component: OrganComponent
        if var existing = selectedSource {
            existing.playableMIDILow = useKeyboardRange ? midiLow : nil
            existing.playableMIDIHigh = useKeyboardRange ? midiHigh : nil
            component = existing
        } else {
            let id = "local:sounding-target:\(UUID().uuidString.lowercased())"
            let label = localLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            component = OrganComponent(
                id: id,
                kind: family.rawValue,
                label: label,
                division: "Locally documented sounds / effects",
                locator: ComponentLocator(
                    id: id,
                    organMDVSID: project.organMDVSID,
                    sourcePath: "operator-planned sounding target",
                    snapshotSHA256: project.snapshot.payloadSHA256,
                    kind: family.rawValue,
                    label: label,
                    trust: .sourceBound
                ),
                playableMIDILow: useKeyboardRange ? midiLow : nil,
                playableMIDIHigh: useKeyboardRange ? midiHigh : nil,
                sourceDetails: ["orgrec:localSoundingTarget": "true"]
            )
        }
        Task {
            await model.saveSoundingTargetPlan(
                component: component,
                definition: definition,
                techniques: CaptureTechnique.allCases.filter { techniques.contains($0) },
                required: required
            )
            dismiss()
        }
    }
}

private struct ControlMapSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingBinding: ControlBinding?

    private var components: [OrganComponent] {
        (model.project?.organComponents ?? [])
            .filter { !["division", "rank", "pipe", "pipe_position"].contains($0.kind) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Control map & MIDI Learn").font(.title2.bold())
                    Text("Map sounding and state controls explicitly; raw protocol values and their display numbering bases are both preserved.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.midiControl.refreshEndpoints()
                } label: { Label("Refresh MIDI", systemImage: "arrow.clockwise") }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding(20)
            Divider()
            HStack(spacing: 0) {
                List {
                    Section("Bindings") {
                        ForEach(model.project?.controlBindings ?? []) { binding in
                            Button { editingBinding = binding } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(binding.componentLabel).font(.headline)
                                        Spacer()
                                        Image(systemName: binding.validationIssues.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundStyle(binding.validationIssues.isEmpty ? OrgRecTheme.ai : OrgRecTheme.shu)
                                    }
                                    Text("\(binding.controlProtocol.displayName) · \(binding.direction.displayName) · \(binding.verification.rawValue)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", role: .destructive) { Task { await model.removeControlBinding(binding.id) } }
                            }
                        }
                    }
                }
                .frame(width: 330)
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    Label("Scientifically explicit control addresses", systemImage: "cable.connector.horizontal")
                        .font(.title3.bold())
                    Text("Activation and deactivation are independent messages. This matters for cinema-organ systems where two Program Change numbers, rather than one number plus an on/off value, may operate the same effect.")
                        .foregroundStyle(.secondary)
                    Text("MIDI Learn listens to the selected CoreMIDI source. During every audio take, all incoming messages are logged against the frozen bindings and mapped onto exact audio-file frames using the shared macOS host clock.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        guard let component = model.selectedRoadmapItem?.component ?? components.first else { return }
                        editingBinding = ControlBinding(componentID: component.parentComponentID ?? component.id, componentLabel: component.label)
                    } label: {
                        Label("Add binding", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(components.isEmpty)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 980, minHeight: 650)
        .sheet(item: $editingBinding) { binding in
            ControlBindingEditorSheet(binding: binding, components: components, monitor: model.midiControl)
                .environmentObject(model)
        }
    }
}

private struct ControlBindingEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var monitor: MIDIControlCenter
    let components: [OrganComponent]
    @State private var binding: ControlBinding
    @State private var outputStatus = ""

    init(binding: ControlBinding, components: [OrganComponent], monitor: MIDIControlCenter) {
        self.components = components
        self.monitor = monitor
        _binding = State(initialValue: binding)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Control binding").font(.title2.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    Task {
                        await model.saveControlBinding(binding)
                        if binding.validationIssues.isEmpty { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(binding.validationIssues.isEmpty == false)
            }
            .padding(18)
            Divider()
            Form {
                Section("Identity") {
                    Picker("Instrument component", selection: componentSelection) {
                        ForEach(components) { component in
                            Text("\(component.label) · \(component.division)").tag(component.id)
                        }
                    }
                    TextField("Binding label", text: $binding.label)
                    Picker("Protocol", selection: $binding.controlProtocol) {
                        ForEach(ControlProtocol.allCases) { value in Text(value.displayName).tag(value) }
                    }
                    Picker("Direction", selection: $binding.direction) {
                        ForEach(ControlDirection.allCases) { value in Text(value.displayName).tag(value) }
                    }
                }

                Section("Numbering contract") {
                    Picker("Displayed channel base", selection: $binding.channelNumberingBase) {
                        Text("0-based (0…15)").tag(0)
                        Text("1-based (1…16)").tag(1)
                    }
                    Picker("Displayed data-number base", selection: $binding.dataNumberingBase) {
                        Text("0-based (0…127)").tag(0)
                        Text("1-based (1…128)").tag(1)
                    }
                    Text("OrgRec always stores raw MIDI bytes. These fields make any human-facing renumbering explicit and reversible.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if binding.controlProtocol == .midi1 {
                    Section("MIDI endpoint & Learn") {
                        Picker("Input source", selection: $monitor.selectedSourceID) {
                            Text("No input").tag(String?.none)
                            ForEach(monitor.sources) { source in Text(source.displayName).tag(String?.some(source.id)) }
                        }
                        if binding.direction.permitsOutput {
                            Picker("Output destination", selection: $monitor.selectedDestinationID) {
                                Text("No output").tag(String?.none)
                                ForEach(monitor.destinations) { destination in Text(destination.displayName).tag(String?.some(destination.id)) }
                            }
                        }
                        LabeledContent("Monitor", value: monitor.status)
                        if let last = monitor.lastIncomingMessage {
                            LabeledContent("Last input", value: "\(last.messageType.displayName) · \(monitor.lastIncomingRawHex)")
                        }
                    }

                    descriptorSection("Activation", slot: .activation, descriptor: $binding.activation)
                    descriptorSection("Deactivation", slot: .deactivation, descriptor: $binding.deactivation)
                    descriptorSection("Continuous value", slot: .continuous, descriptor: $binding.continuous)

                    if binding.direction.permitsOutput {
                        Section("Explicit outbound validation") {
                            Text("Sending a test can move stops, shutters, percussion, or other mechanisms. Verify that the instrument and its surroundings are safe before pressing either button; OrgRec never sends automatically.")
                                .font(.caption).foregroundStyle(OrgRecTheme.shu)
                            HStack {
                                Button("Send activation") { send(binding.activation) }.disabled(binding.activation == nil || monitor.selectedDestinationID == nil)
                                Button("Send deactivation") { send(binding.deactivation) }.disabled(binding.deactivation == nil || monitor.selectedDestinationID == nil)
                                Button("Mark round-trip verified") {
                                    binding.verification = .roundTripVerified
                                    binding.lastVerifiedAt = .now
                                }
                                .disabled(outputStatus.isEmpty)
                            }
                            if outputStatus.isEmpty == false { Text(outputStatus).font(.caption.monospacedDigit()) }
                        }
                    }
                } else {
                    Section("Protocol-specific address") {
                        Text("The typed map preserves this protocol choice. MIDI Learn and outbound validation are currently available for MIDI 1.0; enter non-MIDI address evidence in Notes.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Verification & evidence") {
                    Picker("Verification", selection: $binding.verification) {
                        ForEach(ControlBindingVerification.allCases) { value in Text(value.rawValue).tag(value) }
                    }
                    TextField("Source / evidence", text: $binding.source)
                    TextField("Notes", text: $binding.notes, axis: .vertical).lineLimit(2...5)
                    ForEach(binding.validationIssues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle.fill").foregroundStyle(OrgRecTheme.shu)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 800, minHeight: 720)
        .onChange(of: monitor.learnedMessage?.id) { _, _ in
            guard let learned = monitor.learnedMessage else { return }
            switch learned.slot {
            case .activation: binding.activation = learned.message
            case .deactivation: binding.deactivation = learned.message
            case .continuous: binding.continuous = learned.message
            }
            binding.sourceDeviceID = learned.sourceID
            binding.sourceDeviceName = learned.sourceName
            binding.verification = .learned
            binding.lastVerifiedAt = .now
        }
    }

    @ViewBuilder
    private func descriptorSection(_ title: String, slot: MIDILearnSlot, descriptor: Binding<ControlMessageDescriptor?>) -> some View {
        Section(title) {
            ControlMessageDescriptorEditor(descriptor: descriptor)
            HStack {
                Button(monitor.learningSlot == slot ? "Waiting…" : "Learn next message") {
                    monitor.armLearn(slot)
                }
                .disabled(monitor.selectedSourceID == nil || monitor.learningSlot != nil)
                if monitor.learningSlot == slot { Button("Cancel Learn") { monitor.cancelLearn() } }
                if descriptor.wrappedValue != nil {
                    Button("Mark input verified") {
                        binding.verification = .inputVerified
                        binding.lastVerifiedAt = .now
                    }
                }
            }
        }
    }

    private var componentSelection: Binding<String> {
        Binding(
            get: { binding.componentID },
            set: { value in
                binding.componentID = value
                if let component = components.first(where: { $0.id == value }) {
                    binding.componentLabel = component.label
                    if binding.label.isEmpty { binding.label = component.label }
                }
            }
        )
    }

    private func send(_ descriptor: ControlMessageDescriptor?) {
        guard let descriptor else { return }
        let status = monitor.sendTest(descriptor)
        outputStatus = status == 0 ? "Message sent; confirm the observed physical response before marking round-trip verified." : "Send failed with OSStatus \(status)."
        if status != 0 { binding.verification = .failed }
        binding.destinationDeviceID = monitor.selectedDestinationID
        binding.destinationDeviceName = monitor.destinations.first { $0.id == monitor.selectedDestinationID }?.displayName
    }
}

private struct ControlMessageDescriptorEditor: View {
    @Binding var descriptor: ControlMessageDescriptor?

    var body: some View {
        if descriptor == nil {
            Button("Add message manually") {
                descriptor = ControlMessageDescriptor(messageType: .controlChange, channel: 0, number: 0, value: 127)
            }
        } else {
            Picker("Message type", selection: field(\.messageType, default: .controlChange)) {
                ForEach(ControlMessageType.allCases.filter { ![.ump, .oscMessage, .hidReport, .contact, .custom].contains($0) }) { type in
                    Text(type.displayName).tag(type)
                }
            }
            Stepper("Raw channel \(field(\.channel, default: 0).wrappedValue) (display \(field(\.channel, default: 0).wrappedValue + 1) in common 1-based notation)", value: field(\.channel, default: 0), in: 0...15)
            Stepper("Raw number \(field(\.number, default: 0).wrappedValue)", value: field(\.number, default: 0), in: 0...127)
            if descriptor?.messageType != .programChange {
                Stepper("Value \(field(\.value, default: 0).wrappedValue)", value: field(\.value, default: 0), in: 0...16_383)
            }
            Button("Clear message", role: .destructive) { descriptor = nil }
        }
    }

    private func field<Value>(_ keyPath: WritableKeyPath<ControlMessageDescriptor, Value?>, default fallback: Value) -> Binding<Value> {
        Binding(
            get: { descriptor?[keyPath: keyPath] ?? fallback },
            set: { value in
                guard var copy = descriptor else { return }
                copy[keyPath: keyPath] = value
                descriptor = copy
            }
        )
    }

    private func field<Value>(_ keyPath: WritableKeyPath<ControlMessageDescriptor, Value>, default fallback: Value) -> Binding<Value> {
        Binding(
            get: { descriptor?[keyPath: keyPath] ?? fallback },
            set: { value in
                guard var copy = descriptor else { return }
                copy[keyPath: keyPath] = value
                descriptor = copy
            }
        )
    }
}

private struct RecordView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let item = model.selectedRoadmapItem {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Ready to record").font(.caption.bold()).foregroundStyle(OrgRecTheme.shu)
                            Text(item.component.label + " · " + (item.component.noteName ?? ""))
                                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                            Text("\(item.component.division) · \(item.technique.rawValue)")
                                .font(.title3).foregroundStyle(.secondary)
                            Divider().padding(.vertical, 4)
                            if let expectedFrequency = item.component.expectedFrequencyHz {
                                Label("Expected \(expectedFrequency.formatted(.number.precision(.fractionLength(2)))) Hz", systemImage: "tuningfork")
                            }
                            Label(item.component.locator.id, systemImage: "link")
                                .textSelection(.enabled)
                                .lineLimit(1)
                            if let instructions = item.instructions {
                                Label(instructions, systemImage: "checklist")
                                    .font(.callout).foregroundStyle(.secondary)
                            }
                            if let registrationID = item.registrationID,
                               let registration = model.project?.registrations.first(where: { $0.id == registrationID }) {
                                RegistrationActivationSummary(registration: registration)
                            }
                            if let protocolSnapshot = item.instrumentNoiseProtocol {
                                InstrumentNoiseProtocolSummary(
                                    protocolSnapshot: protocolSnapshot,
                                    acceptedCount: acceptedRepetitions(for: item)
                                )
                            }
                            if let protocolSnapshot = item.complexCaptureProtocol {
                                ComplexCaptureProtocolSummary(
                                    protocolSnapshot: protocolSnapshot,
                                    acceptedCount: acceptedRepetitions(for: item)
                                )
                            }
                            if let protocolSnapshot = item.spatialAcousticProtocol {
                                SpatialAcousticProtocolSummary(
                                    protocolSnapshot: protocolSnapshot,
                                    acceptedCount: acceptedRepetitions(for: item)
                                )
                            }
                            if let soundingTarget = item.soundingTargetDefinition {
                                SoundingTargetSummary(
                                    definition: soundingTarget,
                                    acceptedCount: acceptedRepetitions(for: item)
                                )
                            }
                        }
                        Spacer()
                        StatusBadge(state: item.state)
                    }
                    .card()

                    if let state = model.requiredCaptureState(for: item) {
                        CaptureStateConfirmationCard(state: state)
                    }

                    CaptureReadinessPanel(issues: model.captureReadiness)

                    if model.capture.isRecording {
                        CaptureHealthStrip(capture: model.capture)
                    }

                    if let sensorConfiguration = model.activeInteractionSensorConfiguration,
                       sensorConfiguration.capturePolicy != .disabled {
                        InteractionSensorRecordingStrip(
                            sensor: model.interactionSensors,
                            configuration: sensorConfiguration,
                            calibration: model.activeInteractionSensorCalibration
                        )
                    }

                    NoiseContextCaptureCard()

                    if item.instrumentNoiseProtocol == nil && item.soundingTargetDefinition == nil && item.complexCaptureProtocol == nil && item.spatialAcousticProtocol == nil {
                        LongTakeCapturePanel()
                    }

                    if model.capture.isRecording, model.isLongTakeRecording == false, let pitch = model.livePitch.evidence {
                        LivePitchStatusCard(evidence: pitch)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Signal").font(.headline)
                            LiveWaveform(samples: model.capture.liveWaveform)
                                .frame(height: 170)
                            ChannelMeterGrid(
                                capture: model.capture,
                                roles: selectedChannelRoles
                            )
                            HStack {
                                Text(model.capture.peakDBFS.formatted(.number.precision(.fractionLength(1))) + " dBFS")
                                    .font(.title3.monospacedDigit().bold())
                                LevelMeter(db: model.capture.peakDBFS, label: "Peak input level")
                                Text(model.capture.elapsed.formatted(.number.precision(.fractionLength(1))) + " s")
                                    .font(.title3.monospacedDigit())
                            }
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 13) {
                            Text("Capture protocol").font(.headline)
                            if let protocolSnapshot = item.spatialAcousticProtocol {
                                SpatialAcousticCaptureControl(protocolSnapshot: protocolSnapshot)
                                    .id(protocolSnapshot.id)
                            } else if let protocolSnapshot = item.complexCaptureProtocol {
                                ComplexCaptureControl(protocolSnapshot: protocolSnapshot)
                                    .id(protocolSnapshot.id)
                            } else if let protocolSnapshot = item.instrumentNoiseProtocol {
                                InstrumentNoiseCaptureSteps(protocolSnapshot: protocolSnapshot)
                                if model.capture.isRecording, model.isLongTakeRecording == false {
                                    InstrumentActuationCaptureControl(protocolSnapshot: protocolSnapshot)
                                        .id(protocolSnapshot.id)
                                }
                            } else if let soundingTarget = item.soundingTargetDefinition {
                                SoundingTargetCaptureSteps(definition: soundingTarget, item: item)
                                if model.capture.isRecording, model.isLongTakeRecording == false {
                                    HStack {
                                        Button("Mark trigger") { Task { await model.markLiveEvent(code: "operator_effect_trigger", text: "Intended effect trigger") } }
                                        Button("Mark release") { Task { await model.markLiveEvent(code: "operator_effect_release", text: "Intended effect release") } }
                                    }
                                }
                            } else {
                                CaptureProtocolTimeline(
                                    elapsed: model.capture.elapsed,
                                    isRecording: model.capture.isRecording,
                                    recipe: model.project?.recipe ?? CaptureRecipe()
                                )
                                ProtocolStep(number: "1", text: String(format: "%.1f s room tone", model.project?.recipe.preRollSeconds ?? 1))
                                ProtocolStep(number: "2", text: "Press and hold the indicated key")
                                ProtocolStep(number: "3", text: String(format: "%.1f s steady state", model.project?.recipe.sustainSeconds ?? 4))
                                ProtocolStep(number: "4", text: String(format: "Release; keep %.1f s tail", model.project?.recipe.releaseSeconds ?? 4))
                                if model.capture.isRecording, model.isLongTakeRecording == false {
                                    HStack {
                                        Button("Mark key-down") {
                                            Task { await model.markLiveEvent(code: "operator_key_down", text: "Operator key-down") }
                                        }
                                        Button("Mark key-up") {
                                            Task { await model.markLiveEvent(code: "operator_key_up", text: "Operator key-up") }
                                        }
                                    }
                                }
                            }
                            Spacer()
                            Text(item.complexCaptureProtocol != nil
                                 ? "P1 events are stored as structured take paradata; exact protocol, physical inputs, stages, subsystem state, and derived evidence remain frozen with the take."
                                 : item.instrumentNoiseProtocol != nil
                                 ? "Action markers are stored as structured take paradata; the complete planned protocol is frozen in provenance."
                                 : item.soundingTargetDefinition != nil
                                    ? "The sounding-target family, required state, repetitions, MIDI/control events, and audio-frame alignment are frozen with every take."
                                    : "Onset and acoustic offset are detected after capture; key-up can be annotated during review.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(width: 330)
                        .card()
                    }

                    Button {
                        Task {
                            if model.isCalibrating {
                                await model.stopPitchCalibration()
                            } else if model.isLongTakeRecording {
                                await model.stopLongTakeRecording()
                            } else if model.capture.isRecording {
                                await model.stopRecording()
                            } else {
                                await model.startRecording()
                            }
                        }
                    } label: {
                        Label(
                            model.isCalibrating
                                ? "Stop A4 calibration"
                                : model.isLongTakeRecording
                                    ? "Stop and split long take"
                                    : model.capture.isRecording
                                        ? "Stop and analyze"
                                        : (model.captureIsReady ? "Start recording" : "Resolve readiness blockers"),
                            systemImage: model.capture.isRecording ? "stop.fill" : "record.circle"
                        )
                        .font(.title3.bold())
                        .frame(minWidth: 210)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(OrgRecTheme.shu)
                    .disabled(
                        model.isWorking
                            || model.capture.isFinalizing
                            || (model.capture.isRecording == false && model.captureIsReady == false)
                    )
                } else {
                    ContentUnavailableView("No roadmap item selected", systemImage: "list.bullet.rectangle", description: Text("Choose an item in the roadmap first."))
                }
            }
            .padding(24)
        }
    }

    private var selectedChannelRoles: [String] {
        guard let setupID = model.selectedRoadmapItem?.setupID,
              let setup = model.project?.setups.first(where: { $0.id == setupID }) else { return [] }
        return setup.placements.sorted { $0.channelNumber < $1.channelNumber }.map(\.role)
    }

    private func acceptedRepetitions(for item: RoadmapItem) -> Int {
        guard let project = model.project else { return 0 }
        let takeIDs = Set(item.takeIDs)
        return project.takes.filter { takeIDs.contains($0.id) && $0.status == .accepted }.count
    }
}

private struct InteractionSensorRecordingStrip: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var sensor: InteractionSensorCenter
    let configuration: InteractionSensorConfiguration
    let calibration: InteractionSensorCalibration?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 16) {
                Image(systemName: "gyroscope")
                    .font(.title2)
                    .foregroundStyle(sensor.isStreaming ? OrgRecTheme.ai : OrgRecTheme.shu)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(configuration.name).font(.subheadline.bold())
                        Text("EXPERIMENTAL").eyebrow()
                    }
                    Text(statusText)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.2f° · %.1f °/s", sensor.latestAngleDegrees, sensor.latestProjectedAngularVelocityDPS))
                        .font(.subheadline.monospacedDigit().bold())
                    Text(calibration == nil ? "Raw dynamics only" : "Calibrated motion")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                if let progress = sensor.latestProgress {
                    ProgressView(value: progress).frame(width: 110).tint(OrgRecTheme.shu)
                }
                if model.capture.isRecording {
                    Label(sensor.isCapturingTake ? "Capturing" : "Audio only",
                          systemImage: sensor.isCapturingTake ? "record.circle.fill" : "waveform")
                        .font(.caption.bold())
                        .foregroundStyle(sensor.isCapturingTake ? OrgRecTheme.ai : .secondary)
                } else {
                    Toggle("Include interaction data in this take", isOn: $model.includeInteractionSensorForNextTake)
                        .toggleStyle(.switch)
                        .fixedSize()
                }
            }
            HStack(spacing: 8) {
                Text(configuration.resolvedUseCase.displayName).font(.caption.bold())
                Text("·").foregroundStyle(.tertiary)
                Text(targetText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("Audio-only recording is always available.")
                    .font(.caption.bold()).foregroundStyle(OrgRecTheme.ai)
            }
        }
        .orgRecCard(inset: 14)
    }

    private var statusText: String {
        if sensor.isCapturingTake { return "Capturing motion from before audio start through the release tail." }
        if model.includeInteractionSensorForNextTake == false { return "Not selected for this take; no interaction-data file will be created." }
        if sensor.isStreaming && sensor.activeConfigurationID == configuration.id {
            return "Selected for this take; motion will be aligned to the audio timeline."
        }
        return "Selected, but the exact sensor is offline; OrgRec will record audio without it."
    }

    private var targetText: String {
        switch model.activeInteractionSensorMatchesSelectedTarget {
        case .some(true): "matches selected Roadmap target"
        case .some(false): "configured for \(configuration.targetComponentLabel), not this target"
        case .none: "manual representative-mechanism selection"
        }
    }
}

private struct SoundingTargetSummary: View {
    let definition: SoundingTargetDefinition
    let acceptedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(definition.family.displayName, systemImage: "sparkles.rectangle.stack")
                .font(.callout.bold())
            Text("Intended sounding content · \(definition.temporalBehavior.rawValue) · \(definition.triggerMode.rawValue)")
                .font(.caption).foregroundStyle(.secondary)
            ProgressView(value: Double(min(acceptedCount, definition.minimumAcceptedTakeCount)), total: Double(definition.minimumAcceptedTakeCount))
            Text("\(acceptedCount) of \(definition.minimumAcceptedTakeCount) accepted takes")
                .font(.caption.monospacedDigit())
            if definition.memberComponentIDs.isEmpty == false {
                Text("Constituents: " + definition.memberComponentIDs.joined(separator: ", "))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text("Actuator and mechanism noise remains separately recordable under Instrument noise.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(OrgRecTheme.ai.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct SoundingTargetCaptureSteps: View {
    let definition: SoundingTargetDefinition
    let item: RoadmapItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ProtocolStep(number: "1", text: "Confirm the exact typed instrument state and capture room tone")
            ProtocolStep(number: "2", text: "Trigger the intended \(definition.family.displayName.lowercased()) target")
            switch definition.temporalBehavior {
            case .discrete:
                ProtocolStep(number: "3", text: "Allow the full natural decay without retriggering")
            case .sustained:
                ProtocolStep(number: "3", text: "Hold for \((definition.plannedDurationSeconds ?? 6).formatted(.number.precision(.fractionLength(0...1)))) s, then release")
            case .repeating:
                ProtocolStep(number: "3", text: "Retain startup, stable repeating operation, shutdown, and tail")
            case .sequenced:
                ProtocolStep(number: "3", text: "Perform the documented ordering and timing unchanged")
            case .composite:
                ProtocolStep(number: "3", text: "Preserve constituent order, overlap, and release behavior")
            }
            ProtocolStep(number: "4", text: "Retain complete release and room tail; repeat in a separate take")
            Text("\(item.minimumAcceptedTakeCount) accepted takes required · incoming control events are logged automatically")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

private struct CaptureStateConfirmationCard: View {
    @EnvironmentObject private var model: AppModel
    let state: CaptureStateSnapshot

    private var activeState: CaptureStateSnapshot? {
        guard let id = model.project?.activeCaptureStateID else { return nil }
        return model.project?.captureStates?.first { $0.id == id }
    }

    private var isConfirmed: Bool { activeState?.isStateEquivalent(to: state) == true }
    private var enabledAssignments: [CaptureStateAssignment] {
        state.assignments.filter { $0.booleanValue == true || $0.valueKind != .boolean }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Exact capture state", systemImage: isConfirmed ? "checkmark.shield.fill" : "switch.2")
                    .font(.headline).foregroundStyle(isConfirmed ? OrgRecTheme.ai : OrgRecTheme.shu)
                Spacer()
                Text(String(state.fingerprintSHA256.prefix(12))).font(.caption2.monospaced()).textSelection(.enabled)
            }
            Text(state.name).font(.callout.bold())
            if enabledAssignments.isEmpty {
                Text("All mapped stops, couplers, and accessories are off; no additional typed state is asserted.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(enabledAssignments.prefix(8)) { assignment in
                    HStack {
                        Text(assignment.dimension.displayName).font(.caption.bold()).frame(width: 110, alignment: .leading)
                        Text(assignment.subjectLabel)
                        Spacer()
                        Text(assignment.booleanValue.map { $0 ? "on" : "off" } ?? assignment.textValue ?? assignment.numericValue?.formatted() ?? "—")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            let offCount = state.assignments.filter { $0.booleanValue == false }.count
            Text("\(state.assignments.count) typed assignments, including \(offCount) explicit off-state\(offCount == 1 ? "" : "s"). Confirmation freezes this exact fingerprint into the take.")
                .font(.caption).foregroundStyle(.secondary)
            Button(isConfirmed ? "State confirmed" : "I have set and verified this state") {
                Task { await model.confirmRequiredCaptureState() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isConfirmed || model.capture.isRecording)
        }
        .card()
    }
}

private struct InstrumentNoiseProtocolSummary: View {
    let protocolSnapshot: InstrumentNoiseCaptureProtocol
    let acceptedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(protocolSnapshot.kind.displayName, systemImage: "waveform.badge.magnifyingglass")
                .font(.callout.bold())
            Text(protocolSnapshot.variantLabel).font(.callout)
            HStack(spacing: 10) {
                Text(protocolSnapshot.sourceScope.displayName)
                Text(protocolSnapshot.mechanisms.map(\.displayName).joined(separator: " + "))
                Text(protocolSnapshot.temporalBehavior.displayName)
            }
            .font(.caption).foregroundStyle(.secondary)
            ProgressView(
                value: Double(min(acceptedCount, protocolSnapshot.minimumAcceptedTakeCount)),
                total: Double(protocolSnapshot.minimumAcceptedTakeCount)
            )
            Text("\(acceptedCount) of \(protocolSnapshot.minimumAcceptedTakeCount) accepted repetitions")
                .font(.caption.monospacedDigit())
            if let profile = protocolSnapshot.actuationProfile {
                Divider()
                HStack {
                    Text("\(profile.quantityLabel) · \(profile.commandedCurve.kind.displayName)")
                    Spacer()
                    Text(profile.commandedCurve.evidenceSource.displayName)
                }
                .font(.caption.bold())
                ActuationCurvePlot(
                    planned: profile.commandedCurve,
                    observed: nil,
                    minimumValue: profile.minimumValue,
                    maximumValue: profile.maximumValue
                )
                .frame(height: 82)
                Text("\(profile.unit) · \(profile.commandedCurve.durationSeconds?.formatted(.number.precision(.fractionLength(0...2))) ?? "duration not set")\(profile.commandedCurve.durationSeconds == nil ? "" : " s")")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(OrgRecTheme.ai.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct InstrumentNoiseCaptureSteps: View {
    let protocolSnapshot: InstrumentNoiseCaptureProtocol

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ProtocolStep(number: "1", text: "Capture room tone before touching the mechanism")
            ProtocolStep(number: "2", text: "Mark begin; perform \(protocolSnapshot.action.displayName.lowercased())")
            if let velocity = protocolSnapshot.velocity {
                let durationText = velocity.targetDurationSeconds.map {
                    ", about \($0.formatted(.number.precision(.fractionLength(0...2)))) s"
                } ?? ""
                ProtocolStep(number: "3", text: "Use \(velocity.label.lowercased()) velocity" + durationText)
            } else {
                ProtocolStep(number: "3", text: "Hold or observe the planned operating state")
            }
            ProtocolStep(number: "4", text: "Mark end; retain decay and room tail")
            if let profile = protocolSnapshot.actuationProfile {
                Text("Follow \(profile.commandedCurve.kind.displayName.lowercased()) \(profile.quantityLabel.lowercased()) · \(profile.unit) · \(profile.commandedCurve.points.count) points")
                    .font(.caption.bold()).foregroundStyle(OrgRecTheme.ai)
            }
            Text("Window \(protocolSnapshot.captureDurationSeconds.formatted(.number.precision(.fractionLength(0...1)))) s · \(protocolSnapshot.configuration.label)")
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}

private struct InstrumentActuationCaptureControl: View {
    @EnvironmentObject private var model: AppModel
    let protocolSnapshot: InstrumentNoiseCaptureProtocol
    @State private var observedValue = 0.0

    private var profile: ActuationProfile? { protocolSnapshot.actuationProfile }
    private var valueBounds: ClosedRange<Double> {
        let values = profile?.commandedCurve.points.map(\.value) ?? [0, 1]
        let lower = profile?.minimumValue ?? values.min() ?? 0
        let upper = profile?.maximumValue ?? values.max() ?? 1
        return lower < upper ? lower...upper : lower...(lower + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let profile {
                Divider()
                Text("Observed \(profile.quantityLabel.lowercased())")
                    .font(.caption.bold())
                Slider(value: $observedValue, in: valueBounds)
                HStack {
                    Text(observedValue.formatted(.number.precision(.fractionLength(0...4))))
                        .font(.callout.monospacedDigit().bold())
                    Text(profile.unit).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Sample") {
                        Task { await model.markInstrumentNoiseEvent(.actuationSample, observedValue: observedValue) }
                    }
                    .help("Store an operator-observed point on the take-specific trajectory")
                }
            }
            HStack {
                Button("Mark action begin") {
                    Task { await model.markInstrumentNoiseEvent(.actionBegin, observedValue: profile == nil ? nil : observedValue) }
                }
                Button("Mark action end") {
                    Task { await model.markInstrumentNoiseEvent(.actionEnd, observedValue: profile == nil ? nil : observedValue) }
                }
            }
            Button("Mark notable variation") {
                Task { await model.markInstrumentNoiseEvent(.notableVariation) }
            }
        }
        .onAppear {
            observedValue = min(max(profile?.commandedCurve.points.first?.value ?? valueBounds.lowerBound, valueBounds.lowerBound), valueBounds.upperBound)
        }
    }
}

private struct ActuationCurvePlot: View {
    let planned: ActuationCurve
    let observed: ActuationCurve?
    let minimumValue: Double?
    let maximumValue: Double?

    private var valueRange: ClosedRange<Double> {
        let values = planned.points.map(\.value) + (observed?.points.map(\.value) ?? [])
        let lower = minimumValue ?? values.min() ?? 0
        let upper = maximumValue ?? values.max() ?? 1
        return lower < upper ? lower...upper : (lower - 0.5)...(upper + 0.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                let plot = CGRect(x: 8, y: 6, width: max(1, size.width - 16), height: max(1, size.height - 12))
                var border = Path()
                border.addRoundedRect(in: plot, cornerSize: CGSize(width: 4, height: 4))
                context.stroke(border, with: .color(OrgRecTheme.hairline), lineWidth: 1)
                draw(planned, in: plot, color: OrgRecTheme.ai, context: &context)
                if let observed { draw(observed, in: plot, color: OrgRecTheme.shu, context: &context) }
            }
            HStack(spacing: 12) {
                Label("commanded", systemImage: "minus").foregroundStyle(OrgRecTheme.ai)
                if observed != nil { Label("observed", systemImage: "minus").foregroundStyle(OrgRecTheme.shu) }
                Spacer()
                Text("\(valueRange.lowerBound.formatted(.number.precision(.fractionLength(0...3))))…\(valueRange.upperBound.formatted(.number.precision(.fractionLength(0...3))))")
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
        }
    }

    private func draw(_ curve: ActuationCurve, in rect: CGRect, color: Color, context: inout GraphicsContext) {
        guard curve.points.isEmpty == false else { return }
        let denominator = max(0.000_001, valueRange.upperBound - valueRange.lowerBound)
        let timeDenominator = curve.timeBasis == .normalized
            ? 1
            : max(0.000_001, curve.durationSeconds ?? curve.points.last?.time ?? 1)
        func location(_ point: ActuationCurvePoint) -> CGPoint {
            CGPoint(
                x: rect.minX + rect.width * min(max(point.time / timeDenominator, 0), 1),
                y: rect.maxY - rect.height * min(max((point.value - valueRange.lowerBound) / denominator, 0), 1)
            )
        }
        var path = Path()
        path.move(to: location(curve.points[0]))
        for index in curve.points.indices.dropFirst() {
            let point = curve.points[index]
            if curve.interpolation == .step {
                let previous = curve.points[index - 1]
                path.addLine(to: CGPoint(x: location(point).x, y: location(previous).y))
            }
            path.addLine(to: location(point))
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        for point in curve.points {
            let center = location(point)
            let dot = CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: dot), with: .color(color))
        }
    }
}

private struct LongTakeCapturePanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Continuous stop recording", systemImage: "waveform.badge.plus")
                        .font(.headline)
                    Text("Record or import many isolated notes in one WAV. OrgRec uses frequency-aware attack analysis, exact source-frame cuts, acoustic releases, and room tails to create one reviewable take per note.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.longTakeScopeLabel)
                    .font(.caption.bold())
                    .foregroundStyle(OrgRecTheme.ai)
            }

            HStack(spacing: 12) {
                Picker("Classification", selection: $model.longTakeAssignmentMode) {
                    ForEach(LongTakeAssignmentMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .frame(maxWidth: 330)

                Button {
                    chooseLongTake()
                } label: {
                    Label("Import long WAV", systemImage: "square.and.arrow.down")
                }
                .disabled(model.capture.isRecording || model.isWorking || model.hasRecoverableLongTakeMaster)
                .help(model.hasRecoverableLongTakeMaster ? "Create note takes from the retained recording master first" : "Import a continuous WAV or AIFF")

                Button {
                    Task {
                        if model.isLongTakeRecording { await model.stopLongTakeRecording() }
                        else { await model.startLongTakeRecording() }
                    }
                } label: {
                    Label(
                        model.isLongTakeRecording ? "Stop and split" : "Record long take",
                        systemImage: model.isLongTakeRecording ? "stop.fill" : "record.circle"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isLongTakeRecording ? OrgRecTheme.shu : OrgRecTheme.ai)
                .disabled(
                    model.capture.isFinalizing
                        || (model.capture.isRecording && model.isLongTakeRecording == false)
                        || (model.capture.isRecording == false && model.captureIsReady == false)
                        || model.isWorking
                )
            }

            Text("For the default ascending mode, start with the selected roadmap note, move upward, and leave at least 0.4 s of quiet between keys. Partial ranks and interrupted/retried takes are supported; every result remains in review state.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let source = model.longTakeSourceURL {
                Label(source.path, systemImage: "waveform")
                    .font(.caption.monospaced())
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            if let status = model.longTakeStatus {
                HStack(spacing: 8) {
                    if model.isWorking { ProgressView().controlSize(.small) }
                    Text(status).font(.callout)
                }
            }

            if model.longTakeSourceURL != nil,
               model.longTakeAnalysis == nil,
               model.isLongTakeRecording == false {
                Button {
                    Task { await model.reanalyzeLongTake() }
                } label: {
                    Label("Analyze retained master", systemImage: "waveform.badge.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
            }

            if let analysis = model.longTakeAnalysis {
                Divider()
                HStack(spacing: 24) {
                    metric("Regions", "\(analysis.segments.count)")
                    metric("Assigned", "\(analysis.assignedSegmentCount)")
                    metric("Needs attention", "\(analysis.reviewSegmentCount)")
                    metric("Noise floor", analysis.noiseFloorDBFS.formatted(.number.precision(.fractionLength(1))) + " dBFS")
                    metric("Gate", analysis.activityThresholdDBFS.formatted(.number.precision(.fractionLength(1))) + " dBFS")
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(analysis.segments) { segment in
                            HStack(spacing: 12) {
                                Text("\(segment.sequenceNumber)")
                                    .font(.caption.monospacedDigit().bold())
                                    .frame(width: 28, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(assignedLabel(for: segment))
                                        .font(.callout.weight(.medium))
                                    Text("\(time(segment.exportStartSeconds))–\(time(segment.exportEndSeconds)) · \(segment.durationSeconds.formatted(.number.precision(.fractionLength(2)))) s · tail \(max(0, segment.exportEndSeconds - segment.soundOffsetSeconds).formatted(.number.precision(.fractionLength(2)))) s")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let frequency = segment.estimatedFrequencyHz {
                                    Text(frequency.formatted(.number.precision(.fractionLength(1))) + " Hz")
                                        .font(.caption.monospacedDigit())
                                }
                                if let cents = segment.pitchDeviationCents {
                                    Text(cents.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always())) + " ¢")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(abs(cents) > 80 ? OrgRecTheme.shu : .secondary)
                                }
                                Image(systemName: segment.warnings.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(segment.warnings.isEmpty ? OrgRecTheme.ai : .orange)
                                    .help(segment.warnings.joined(separator: " "))
                            }
                            .padding(.vertical, 7)
                            if segment.id != analysis.segments.last?.id { Divider() }
                        }
                    }
                }
                .frame(maxHeight: 230)

                ForEach(analysis.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                HStack {
                    if model.hasRecoverableLongTakeMaster {
                        Label("Source master retained", systemImage: "lock.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Clear") { model.clearLongTakePreview() }
                    }
                    Button("Reanalyze classification") { Task { await model.reanalyzeLongTake() } }
                        .disabled(model.isWorking)
                    Spacer()
                    Button {
                        Task { await model.importLongTakeSegments() }
                    } label: {
                        Label("Create \(analysis.assignedSegmentCount) note takes", systemImage: "scissors")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isWorking || analysis.assignedSegmentCount == 0)
                }
            }
        }
        .card()
    }

    private func chooseLongTake() {
        let panel = NSOpenPanel()
        panel.title = "Choose a continuous organ recording"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.wav, .aiff]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.inspectLongTake(at: url) }
    }

    private func assignedLabel(for segment: LongTakeSegment) -> String {
        guard let itemID = segment.assignedRoadmapItemID,
              let item = model.project?.roadmap.first(where: { $0.id == itemID }) else {
            return "Unassigned region"
        }
        return item.component.noteName ?? "MIDI \(item.component.midiNote ?? 0)"
    }

    private func time(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainder = seconds - Double(minutes * 60)
        return String(format: "%d:%05.2f", minutes, remainder)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct LivePitchStatusCard: View {
    let evidence: LivePitchEvidence

    private var color: Color {
        switch evidence.decision {
        case .matched: OrgRecTheme.ai
        case .probableWrongNote: OrgRecTheme.shu
        case .tuningWarning: .orange
        case .noSignal, .acquiring, .ambiguous: .secondary
        }
    }

    private var title: String {
        switch evidence.decision {
        case .matched: "Intended note matches"
        case .tuningWarning: "Pitch differs from the calibrated target"
        case .probableWrongNote: "STOP — probable wrong note"
        case .ambiguous: "Pitch is ambiguous"
        case .noSignal: "Waiting for a played note"
        case .acquiring: "Acquiring a stable pitch…"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: evidence.decision == .probableWrongNote ? "exclamationmark.octagon.fill" : "waveform.badge.magnifyingglass")
                .font(.largeTitle).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title2.bold()).foregroundStyle(color)
                Text("Expected \(evidence.expectedFrequencyHz.formatted(.number.precision(.fractionLength(2)))) Hz")
                    .font(.callout.monospacedDigit())
            }
            Spacer()
            if let measured = evidence.measuredFrequencyHz {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(measured.formatted(.number.precision(.fractionLength(2)))) Hz")
                        .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
                    HStack {
                        if let midi = evidence.detectedMIDINote { Text("detected MIDI \(midi)") }
                        if let cents = evidence.centsDeviation {
                            Text("\(cents.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always()))) cents")
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .background(color.opacity(evidence.decision == .probableWrongNote ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius).stroke(color.opacity(0.55), lineWidth: evidence.decision == .probableWrongNote ? 2 : 1))
        .accessibilityElement(children: .combine)
    }
}

private struct CaptureReadinessPanel: View {
    @EnvironmentObject private var model: AppModel
    let issues: [ConsistencyIssue]

    private var blockers: [ConsistencyIssue] { issues.filter { $0.severity == .blocker } }
    private var warnings: [ConsistencyIssue] { issues.filter { $0.severity == .warning } }
    private var actionableIssues: [ConsistencyIssue] { blockers + warnings }
    private var accent: Color { actionableIssues.isEmpty ? OrgRecTheme.ai : OrgRecTheme.shu }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: readinessSymbol)
                .font(.title2)
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 5) {
                Text(readinessTitle)
                    .font(.headline)
                if actionableIssues.isEmpty {
                    Text("Session, MODAVIS binding, registration, setup geometry, and channel routing are documented.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        if blockers.isEmpty == false {
                            Label(
                                "\(blockers.count) blocker\(blockers.count == 1 ? "" : "s")",
                                systemImage: "xmark.circle.fill"
                            )
                        }
                        if warnings.isEmpty == false {
                            Label(
                                "\(warnings.count) warning\(warnings.count == 1 ? "" : "s")",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(OrgRecTheme.shu)

                    ForEach(actionableIssues.prefix(4)) { issue in
                        Label(issue.title, systemImage: issue.severity == .blocker ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(OrgRecTheme.shu)
                    }
                    if actionableIssues.count > 4 {
                        Text("\(actionableIssues.count - 4) more issue\(actionableIssues.count - 4 == 1 ? "" : "s") in Field QA")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if actionableIssues.isEmpty == false {
                Button("Open Field QA") { model.page = .fieldQA }.buttonStyle(.borderedProminent)
            }
        }
        .padding(13)
        .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous).stroke(accent.opacity(0.24)))
    }

    private var readinessTitle: String {
        if blockers.isEmpty == false { return "Capture is not ready" }
        if warnings.isEmpty == false { return "Capture ready with warnings" }
        return "Capture ready"
    }

    private var readinessSymbol: String {
        if blockers.isEmpty == false { return "exclamationmark.shield.fill" }
        if warnings.isEmpty == false { return "exclamationmark.triangle.fill" }
        return "checkmark.shield.fill"
    }
}

private struct CaptureHealthStrip: View {
    @ObservedObject var capture: AudioCaptureEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 16) {
                Label("Recording health", systemImage: "waveform.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(capture.criticalHealthMessage == nil ? OrgRecTheme.ai : OrgRecTheme.shu)
                Spacer()
                Label(ByteCountFormatter.string(fromByteCount: capture.estimatedFileBytes, countStyle: .file), systemImage: "doc.waveform")
                if let available = capture.availableDiskBytes {
                    Label(ByteCountFormatter.string(fromByteCount: available, countStyle: .file) + " free", systemImage: "internaldrive")
                }
                if let remaining = capture.safeRecordingSecondsRemaining {
                    Label("RIFF headroom " + duration(remaining), systemImage: "hourglass")
                }
            }
            .font(.callout.monospacedDigit())

            if let message = capture.criticalHealthMessage {
                Label(message, systemImage: "exclamationmark.octagon.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(OrgRecTheme.shu)
            } else {
                Text("The writer queue, input device, sample rate, container size, and finalization disk reserve are monitored continuously.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(13)
        .background(
            (capture.criticalHealthMessage == nil ? OrgRecTheme.ai : OrgRecTheme.shu).opacity(0.07),
            in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous)
                .stroke((capture.criticalHealthMessage == nil ? OrgRecTheme.ai : OrgRecTheme.shu).opacity(0.25))
        )
        .accessibilityElement(children: .combine)
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let bounded = max(0, Int(seconds.rounded(.down)))
        let hours = bounded / 3_600
        let minutes = (bounded % 3_600) / 60
        let remainingSeconds = bounded % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds) }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

private struct CaptureProtocolTimeline: View {
    let elapsed: Double
    let isRecording: Bool
    let recipe: CaptureRecipe

    private var total: Double { max(0.1, recipe.preRollSeconds + recipe.sustainSeconds + recipe.releaseSeconds) }
    private var stage: String {
        guard isRecording else { return "Ready" }
        if elapsed < recipe.preRollSeconds { return "Room tone" }
        if elapsed < recipe.preRollSeconds + recipe.sustainSeconds { return "Sustain" }
        if elapsed < total { return "Release tail" }
        return "Protocol complete"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(stage).font(.caption.bold()).foregroundStyle(isRecording ? OrgRecTheme.shu : OrgRecTheme.secondaryText)
                Spacer()
                Text("\(elapsed.formatted(.number.precision(.fractionLength(1)))) / \(total.formatted(.number.precision(.fractionLength(1)))) s")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(OrgRecTheme.sumi.opacity(0.12))
                    HStack(spacing: 2) {
                        Rectangle().fill(OrgRecTheme.ai.opacity(0.65)).frame(width: proxy.size.width * recipe.preRollSeconds / total)
                        Rectangle().fill(OrgRecTheme.shu.opacity(0.75)).frame(width: proxy.size.width * recipe.sustainSeconds / total)
                        Rectangle().fill(OrgRecTheme.ai.opacity(0.65)).frame(maxWidth: .infinity)
                    }
                    .clipShape(Capsule())
                    Capsule().stroke(OrgRecTheme.washi.opacity(0.9), lineWidth: 2)
                        .frame(width: 3, height: 14)
                        .offset(x: proxy.size.width * min(1, elapsed / total) - 1.5)
                }
            }
            .frame(height: 12)
        }
        .padding(.bottom, 3)
    }
}

private struct RegistrationActivationSummary: View {
    let registration: RegistrationState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(registration.name ?? "Registration").font(.headline)
            if registration.activatedStops.isEmpty == false {
                Text("Stops: " + registration.activatedStops.map(\.label).joined(separator: ", "))
            }
            if registration.activatedCouplers.isEmpty == false {
                Text("Couplers: " + registration.activatedCouplers.map(\.label).joined(separator: ", "))
            }
            if registration.activatedAccessories.isEmpty == false {
                Text("Accessories: " + registration.activatedAccessories.map(\.label).joined(separator: ", "))
            }
        }
        .font(.caption)
        .padding(9)
        .background(OrgRecTheme.sumi.opacity(0.06), in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
    }
}

private struct ProtocolStep: View {
    let number: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Text(number).font(.caption.bold()).frame(width: 24, height: 24)
                .background(OrgRecTheme.shu.opacity(0.14), in: Circle()).foregroundStyle(OrgRecTheme.shu)
            Text(text)
        }
    }
}

private struct LevelMeter: View {
    let db: Float
    var label = "Input level"

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(OrgRecTheme.sumi.opacity(0.12))
                Capsule().fill(db > -3 ? OrgRecTheme.shu : (db > -12 ? OrgRecTheme.shu.opacity(0.72) : OrgRecTheme.ai))
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, (db + 60) / 60))))
            }
        }
        .frame(height: 9)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard db.isFinite else { return "No signal" }
        return db.formatted(.number.precision(.fractionLength(1))) + " decibels full scale"
    }
}

private struct ChannelMeterGrid: View {
    @ObservedObject var capture: AudioCaptureEngine
    let roles: [String]

    var body: some View {
        if !capture.channelPeakDBFS.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 8)], spacing: 7) {
                ForEach(capture.channelPeakDBFS.indices, id: \.self) { index in
                    HStack(spacing: 7) {
                        Text("\(index + 1)").font(.caption.monospacedDigit().bold()).frame(width: 18)
                        Text(roles.indices.contains(index) ? roles[index] : "Input \(index + 1)")
                            .font(.caption).lineLimit(1).frame(width: 70, alignment: .leading)
                        LevelMeter(
                            db: capture.channelPeakDBFS[index],
                            label: (roles.indices.contains(index) ? roles[index] : "Input \(index + 1)") + " level"
                        )
                        Text(capture.channelPeakDBFS[index].formatted(.number.precision(.fractionLength(1))))
                            .font(.caption2.monospacedDigit()).frame(width: 38, alignment: .trailing)
                    }
                }
            }
        }
    }
}

private struct LiveWaveform: View {
    let samples: [Float]

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OrgRecTheme.sumi.opacity(0.88)))
            guard samples.count > 1 else {
                var baseline = Path()
                baseline.move(to: CGPoint(x: 0, y: size.height / 2))
                baseline.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(baseline, with: .color(OrgRecTheme.ai.opacity(0.5)), lineWidth: 1)
                return
            }
            var path = Path()
            for (index, value) in samples.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(samples.count - 1)
                let y = size.height / 2 - CGFloat(value) * size.height * 0.46
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(OrgRecTheme.ai), lineWidth: 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live input waveform")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        guard let peak = samples.lazy.map({ abs($0) }).max(), peak > 0 else {
            return "No live signal yet"
        }
        let peakDBFS = 20 * log10(max(Double(peak), 0.000_001))
        return "Recent peak "
            + peakDBFS.formatted(.number.precision(.fractionLength(1)))
            + " decibels full scale"
    }
}

private struct AnalysisView: View {
    @EnvironmentObject private var model: AppModel
    @State private var reviewReason = ""
    @StateObject private var interaction = AnalysisInteractionState()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Take analysis").font(.system(.title2, design: .serif, weight: .semibold))
                        Text(model.selectedTake.map { "Take \($0.takeNumber) · \($0.status.rawValue)" } ?? "Record a take to begin")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let take = model.selectedTake, take.status != .analyzing {
                        Button("Reanalyze") { Task { await model.analyze(takeID: take.id) } }
                    }
                }

                TemperamentInferencePanel()
                TimbreAnalysisPanel()
                CollectionAnalysisPanel()
                ActuatorResponseFunctionsPanel()

                if let analysis = model.selectedTake?.analysis {
                    PlaybackBar(playback: model.playback)
                        .card()

                    AnalysisNavigationBar(interaction: interaction)
                        .card()

                    HStack(spacing: 12) {
                        MetricCard(title: "Onset", value: seconds(analysis.onsetSeconds), symbol: "bolt.fill")
                        MetricCard(title: "Sound offset", value: seconds(analysis.soundOffsetSeconds), symbol: "waveform.path")
                        MetricCard(title: "Pitch", value: analysis.frequencyHz.map { $0.formatted(.number.precision(.fractionLength(2))) + " Hz" } ?? "—", symbol: "tuningfork")
                        MetricCard(title: "Deviation", value: analysis.centsDeviation.map { $0.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())) + " ¢" } ?? "—", symbol: "arrow.up.and.down")
                        MetricCard(title: "Peak", value: analysis.peakDBFS.map { $0.formatted(.number.precision(.fractionLength(1))) + " dBFS" } ?? "—", symbol: "speaker.wave.2")
                    }

                    if let comparison = analysis.pitchEstimatorComparison {
                        PitchEstimatorComparisonView(comparison: comparison)
                            .card()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Waveform & transient markers").font(.headline)
                            Spacer()
                            Text(analysis.method).font(.caption).foregroundStyle(.secondary)
                        }
                        InteractiveAnalysisWaveform(
                            waveform: model.waveform,
                            analysis: analysis,
                            correctedMarkers: Set(model.selectedTake?.markerCorrections?.map(\.marker) ?? []),
                            annotations: selectedAnnotations,
                            interaction: interaction,
                            playback: model.playback
                        )
                            .frame(height: 174)
                    }
                    .card()

                    if let track = model.selectedTake?.pitchTrack, track.isEmpty == false {
                        InteractivePitchTrackView(
                            track: track,
                            summary: analysis.pitchTrackSummary,
                            runCount: model.selectedTake?.analysisRuns?.count ?? 0,
                            interaction: interaction,
                            playback: model.playback
                        )
                        .card()
                    }

                    InteractiveBoundaryEditor(analysis: analysis, interaction: interaction)
                        .card()

                    InteractiveLoopPointEditor(analysis: analysis, interaction: interaction)
                        .card()

                    if let behavior = analysis.pipeSoundBehavior {
                        PipeSoundBehaviorPanel(behavior: behavior)
                            .card()
                    }

                    if let spectral = analysis.perceptualSpectralSummary {
                        PerceptualSpectralPanel(summary: spectral)
                            .card()
                    }

                    if let decay = analysis.acousticResponseAnalysis {
                        AcousticDecayEvidencePanel(analysis: decay)
                            .card()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Spectrogram & partial-offset tracking").font(.headline)
                            Spacer()
                            if let configuration = model.spectrogram?.configuration {
                                Text("\(configuration.fftSize)-point FFT · \(configuration.window.rawValue) · hop \(configuration.hopSize)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        InteractiveSpectrogramView(
                            data: model.spectrogram,
                            analysis: analysis,
                            annotations: selectedAnnotations,
                            interaction: interaction,
                            playback: model.playback
                        )
                    }
                    .card()

                    ResponsibleVisualizationNote(data: model.spectrogram, analysis: analysis)
                        .card()

                    SpectrogramControls()
                        .card()

                    if let tracks = model.spectrogram?.partialTracks, !tracks.isEmpty {
                        InteractivePartialTracksView(
                            tracks: tracks,
                            interaction: interaction,
                            playback: model.playback
                        )
                            .card()
                    }

                    if let diagnostics = model.selectedTake?.captureDiagnostics {
                        CaptureDiagnosticsView(diagnostics: diagnostics)
                            .card()
                    }

                    if let eventLog = model.selectedTake?.controlEventLog {
                        ControlEventAlignmentView(eventLog: eventLog, alignment: model.selectedTake?.audioControlAlignment)
                            .card()
                    }

                    if let paradata = model.selectedTake?.instrumentNoiseParadata,
                       paradata.protocolSnapshot.actuationProfile != nil {
                        InstrumentActuationTakeReview(paradata: paradata)
                            .card()
                    }

                    if let paradata = model.selectedTake?.complexCaptureParadata {
                        ComplexCaptureTakeReview(paradata: paradata)
                            .card()
                    }

                    if let paradata = model.selectedTake?.spatialAcousticParadata {
                        SpatialAcousticTakeReview(paradata: paradata)
                            .card()
                    }

                    if let effect = model.selectedTake?.effectAnalysis {
                        EffectAnalysisReview(result: effect)
                            .card()
                    }

                    if let comparisons = model.project?.spatialAcousticResponseComparisons,
                       comparisons.isEmpty == false {
                        SpatialResponseComparisonsPanel(comparisons: comparisons)
                            .card()
                    }

                    if let provenance = model.selectedTake?.provenance {
                        TakeProvenanceView(provenance: provenance)
                            .card()
                    }

                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quality control").font(.headline)
                            if analysis.qualityFlags.isEmpty {
                                Label("Automated checks passed", systemImage: "checkmark.seal.fill").foregroundStyle(OrgRecTheme.ai)
                            } else {
                                ForEach(analysis.qualityFlags, id: \.self) { flag in
                                    Label(flag, systemImage: "exclamationmark.triangle.fill").foregroundStyle(OrgRecTheme.shu)
                                }
                            }
                            Text("Estimator confidence (\(analysis.method)): " + (analysis.confidence?.formatted(.percent.precision(.fractionLength(0))) ?? "—"))
                                .font(.caption).foregroundStyle(.secondary)
                            if let snr = analysis.signalToNoiseDB {
                                Text("SNR: \(snr.formatted(.number.precision(.fractionLength(1)))) dB")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Curatorial decision").font(.headline)
                            Text("Automation proposes; a researcher accepts. Rejected takes remain in the audit trail.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let integrityIssue = model.selectedTakeCaptureIntegrityIssue {
                                Label("Capture integrity unresolved", systemImage: "exclamationmark.triangle.fill")
                                    .font(.callout.bold())
                                    .foregroundStyle(OrgRecTheme.shu)
                                Text(integrityIssue + " This take may be reanalyzed for diagnosis, but it cannot be accepted; reject it and record a replacement.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            TextField("Decision reason", text: $reviewReason)
                                .textFieldStyle(.roundedBorder)
                            if analysis.pitchEstimatorComparison?.severity == .critical,
                               reviewReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("A reason is required to accept a take with a critical CREPE–pYIN mismatch.")
                                    .font(.caption).foregroundStyle(OrgRecTheme.shu)
                            }
                            HStack {
                                Button("Reject / retake") { Task { await model.setReview(accepted: false, reason: reviewReason) } }
                                Button("Accept take") { Task { await model.setReview(accepted: true, reason: reviewReason) } }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(
                                        model.selectedTakeCaptureIntegrityIssue != nil
                                            || (analysis.pitchEstimatorComparison?.severity == .critical
                                                && reviewReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }
                } else {
                    ContentUnavailableView("No analyzed take", systemImage: "waveform.badge.magnifyingglass", description: Text("Stop a recording to run onset, offset, CREPE–pYIN pitch comparison, spectrogram, and QC analysis."))
                        .frame(height: 420)
                }
            }
            .padding(24)
        }
        .onAppear { configureInteraction() }
        .onChange(of: model.selectedTakeID) { _, _ in
            reviewReason = model.selectedTake?.reviewReason ?? ""
            configureInteraction()
        }
        .onChange(of: model.waveform?.duration) { _, _ in configureInteraction() }
    }

    private func seconds(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(3))) + " s" } ?? "—"
    }

    private var selectedAnnotations: [TimedAnnotation] {
        guard let takeID = model.selectedTakeID else { return [] }
        return (model.project?.annotations ?? [])
            .filter { $0.takeID == takeID }
            .sorted { $0.atSeconds < $1.atSeconds }
    }

    private func configureInteraction() {
        let spectralDuration = (model.spectrogram?.timeStepSeconds).map {
            $0 * Double(max(0, (model.spectrogram?.timeBins ?? 1) - 1))
        } ?? 0
        let duration = max(model.waveform?.duration ?? 0, model.playback.duration, spectralDuration)
        let boundaries = Dictionary(uniqueKeysWithValues: AnalysisMarkerKind.allCases.compactMap { marker in
            model.correctedMarker(marker).map { (marker, $0) }
        })
        let loopSet = model.acceptedLoopPointSet ?? model.selectedLoopPointSets.first(where: { $0.status == .proposed })
        interaction.configure(duration: max(0.001, duration), boundaries: boundaries, loopPointSet: loopSet)
    }
}

private struct InstrumentActuationTakeReview: View {
    let paradata: InstrumentNoiseTakeParadata

    private var profile: ActuationProfile { paradata.protocolSnapshot.actuationProfile! }
    private var plannedDuration: Double? { profile.commandedCurve.durationSeconds }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Actuation trajectory").font(.headline)
                    Text("\(profile.quantityLabel) · \(profile.unit)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("take \(paradata.repetitionNumber)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(OrgRecTheme.ai)
            }
            ActuationCurvePlot(
                planned: profile.commandedCurve,
                observed: paradata.observedActuationCurve,
                minimumValue: profile.minimumValue,
                maximumValue: profile.maximumValue
            )
            .frame(height: 160)
            HStack(spacing: 22) {
                trajectoryMetric("Planned duration", plannedDuration.map(seconds) ?? "—")
                trajectoryMetric("Actual duration", paradata.actualDurationSeconds.map(seconds) ?? "—")
                trajectoryMetric("Observed points", "\(paradata.observedActuationCurve?.points.count ?? 0)")
                if let error = durationErrorPercent {
                    trajectoryMetric("Duration error", error.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())))
                }
            }
            Text("Command evidence: \(profile.commandedCurve.evidenceSource.displayName). Observation evidence: \(paradata.observedActuationCurve?.evidenceSource.displayName ?? "not captured").")
                .font(.caption)
            if paradata.observedActuationCurve?.evidenceSource == .operatorObserved {
                Label("Operator-timed values document the performed action but are not sensor measurements.", systemImage: "hand.tap")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var durationErrorPercent: Double? {
        guard let plannedDuration, plannedDuration > 0, let actual = paradata.actualDurationSeconds else { return nil }
        return (actual - plannedDuration) / plannedDuration
    }

    private func seconds(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...3))) + " s"
    }

    private func trajectoryMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.callout.monospacedDigit().bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct CollectionAnalysisPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let project = model.project, let report = project.collectionAnalysis {
            let isCurrent = CollectionAnalysisEngine.isCurrent(report, for: project)
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(report.contractVersion).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(report.analyzedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Label(isCurrent ? "Current evidence" : "Refresh required", systemImage: isCurrent ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                            .font(.caption.bold())
                            .foregroundStyle(isCurrent ? OrgRecTheme.ai : OrgRecTheme.shu)
                    }
                    if let summary = report.evidenceSummary {
                        HStack(spacing: 12) {
                            MetricCard(
                                title: "Qualified evidence",
                                value: "\(summary.aggregateTakeCount)/\(summary.eligibleTakeCount)",
                                symbol: "checkmark.seal"
                            )
                            MetricCard(
                                title: "Coverage",
                                value: summary.aggregateCoverage.formatted(.percent.precision(.fractionLength(0))),
                                symbol: "chart.bar.fill"
                            )
                            MetricCard(
                                title: "High quality",
                                value: "\(summary.highQualityCount)",
                                symbol: "waveform.badge.checkmark"
                            )
                            MetricCard(
                                title: "Review candidates",
                                value: "\((report.acousticAnomalyCandidates ?? []).count)",
                                symbol: "exclamationmark.magnifyingglass"
                            )
                        }
                    } else {
                        HStack(spacing: 12) {
                            MetricCard(title: "Rank profiles", value: "\(report.rankTuningProfiles.count)", symbol: "chart.xyaxis.line")
                            MetricCard(title: "Session trends", value: "\(report.sessionPitchDrift.count)", symbol: "clock.arrow.2.circlepath")
                            MetricCard(title: "Similarity candidates", value: "\(report.acousticSimilarityCandidates.count)", symbol: "waveform.path.badge.plus")
                        }
                    }
                    ForEach(report.rankTuningProfiles.prefix(8)) { profile in
                        HStack {
                            Text(profile.rankLabel).font(.caption.bold())
                            Text("\(profile.points.count) notes").font(.caption).foregroundStyle(.secondary)
                            if let quality = profile.medianEvidenceQuality {
                                Text("quality \(quality.formatted(.percent.precision(.fractionLength(0))))")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(profile.stretchCentsPerOctave.map { "stretch \($0.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))) ¢/oct" } ?? "stretch —")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            if profile.outlierTakeIDs.isEmpty == false {
                                Text("\(profile.outlierTakeIDs.count) outliers").font(.caption).foregroundStyle(OrgRecTheme.shu)
                            }
                        }
                    }
                    if report.sessionPitchDrift.isEmpty == false {
                        Divider()
                        Text("Repeated-target session evidence").font(.caption.bold())
                        ForEach(report.sessionPitchDrift.prefix(6)) { session in
                            HStack {
                                Text(session.sessionCode).font(.caption)
                                Spacer()
                                if let drift = session.driftCentsPerHour {
                                    Text("\(drift.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))) ¢/h · \(session.repeatedTargetCount ?? 0) repeated targets")
                                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                } else {
                                    Text("Insufficient repeated-target evidence")
                                        .font(.caption).foregroundStyle(OrgRecTheme.ai)
                                }
                            }
                        }
                    }
                    if let anomalies = report.acousticAnomalyCandidates, anomalies.isEmpty == false {
                        Divider()
                        Text("Acoustic review candidates").font(.caption.bold())
                        ForEach(anomalies.prefix(6)) { candidate in
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: candidate.severity == .critical ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                                    .foregroundStyle(candidate.severity == .critical ? OrgRecTheme.shu : OrgRecTheme.ai)
                                Text("\(candidate.rankLabel) · MIDI \(candidate.midiNote)").font(.caption.bold())
                                Text("robust distance \(candidate.robustDistance.formatted(.number.precision(.fractionLength(2)))) across \(candidate.evidenceDimensionCount) feature(s)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text("Candidates are statistical review prompts, not fault, identity, or construction assertions.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if report.acousticSimilarityCandidates.isEmpty == false {
                        Divider()
                        Text("Harmonic-overlap review candidates").font(.caption.bold())
                        ForEach(report.acousticSimilarityCandidates.prefix(6)) { candidate in
                            HStack(alignment: .firstTextBaseline) {
                                Image(systemName: "waveform.path.badge.magnifyingglass").foregroundStyle(OrgRecTheme.ai)
                                Text("\(takeLabel(candidate.firstTakeID, in: project)) ↔ \(takeLabel(candidate.secondTakeID, in: project))")
                                    .font(.caption.bold())
                                Spacer()
                                Text("\(candidate.cosineSimilarity.formatted(.percent.precision(.fractionLength(1)))) · \(candidate.sharedPartialCount ?? 0) aligned harmonics")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        Text("Similarity is a candidate-only screening result; it never establishes shared physical-pipe identity.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(report.notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                }
                .padding(.top, 10)
            } label: {
                Label("Collection-level analysis", systemImage: "square.stack.3d.up").font(.headline)
            }
            .card()
        }
    }

    private func takeLabel(_ takeID: UUID, in project: OrgRecProject) -> String {
        guard let take = project.takes.first(where: { $0.id == takeID }),
              let item = project.roadmap.first(where: { $0.id == take.roadmapItemID }) else {
            return takeID.uuidString.prefix(8).lowercased()
        }
        return "\(item.component.label) \(item.component.noteName ?? "MIDI \(item.component.midiNote ?? -1)")"
    }
}

private struct TemperamentInferencePanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var rankID: String?
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Compare the measured pitch-class shape with the MODAVIS/BDO temperament catalogue. The result is a ranked acoustic hypothesis and never replaces documentary metadata.")
                            .font(.callout).foregroundStyle(.secondary)
                        if let documented = model.project?.organCharacteristics?.temperament,
                           documented.isEmpty == false,
                           documented.localizedCaseInsensitiveContains("unknown") == false {
                            Label("Documented: \(documented)", systemImage: "doc.text.magnifyingglass")
                                .font(.caption).foregroundStyle(OrgRecTheme.ai)
                        }
                    }
                    Spacer()
                    if let catalog = model.project?.temperamentCatalog {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(catalog.entries.count) cached candidates").font(.caption.bold())
                            Text("MODAVIS \(catalog.modavisRelease) · \(catalog.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }

                if model.temperamentRankOptions.isEmpty {
                    Label("No recorded unison 8′ rank with note-level positions is available.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(OrgRecTheme.shu)
                } else {
                    HStack {
                        Picker("Reference rank", selection: Binding(
                            get: { rankID ?? model.temperamentRankOptions.first?.id },
                            set: { rankID = $0 }
                        )) {
                            ForEach(model.temperamentRankOptions) { option in
                                Text("\(option.label) · \(option.division) · \(option.pitchClassCount)/12 classes · \(option.takeCount) takes")
                                    .tag(Optional(option.id))
                            }
                        }
                        .frame(maxWidth: 540)
                        Spacer()
                        Button("Refresh catalogue & analyze") { run(refresh: true) }
                            .disabled(model.isWorking)
                        Button("Analyze nearest temperament") { run(refresh: false) }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isWorking)
                    }
                }

                if let progress = model.temperamentProgress {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text(progress).font(.caption).foregroundStyle(.secondary)
                    }
                }

                if let report = model.selectedTemperamentReport {
                    Divider()
                    reportHeader(report)
                    if let best = report.matches.first {
                        TemperamentVectorChart(report: report, match: best)
                            .frame(height: 220)
                        VStack(spacing: 7) {
                            ForEach(Array(report.matches.prefix(6).enumerated()), id: \.element.id) { index, match in
                                TemperamentCandidateRow(index: index + 1, match: match, catalogBaseURL: model.project?.temperamentCatalog?.navigatorBaseURL)
                            }
                        }
                    } else {
                        ContentUnavailableView("Insufficient comparable evidence", systemImage: "chart.xyaxis.line", description: Text("Analyze at least eight distinct pitch classes with reliable frequency estimates."))
                            .frame(minHeight: 150)
                    }
                    DisclosureGroup("Interpretation and limitations") {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(report.notes, id: \.self) { note in
                                Label(note, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                            }
                            Text("Catalog snapshot SHA-256: \(report.catalogPayloadSHA256)")
                                .font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        .padding(.top, 6)
                    }
                    if let reports = model.project?.temperamentAnalyses, reports.count > 1 {
                        HStack {
                            Text("Previous analyses").font(.caption).foregroundStyle(.secondary)
                            Picker("Previous analyses", selection: Binding(
                                get: { Optional(report.id) },
                                set: { model.selectedTemperamentReportID = $0 }
                            )) {
                                ForEach(reports.reversed()) { item in
                                    Text("\(item.rankLabel) · \(item.analyzedAt.formatted(date: .abbreviated, time: .shortened))").tag(Optional(item.id))
                                }
                            }
                            .labelsHidden().frame(maxWidth: 420)
                        }
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            HStack {
                Label("Temperament suggestion", systemImage: "tuningfork").font(.headline)
                Spacer()
                if let report = model.selectedTemperamentReport {
                    Text(report.inferenceStrength.rawValue.capitalized)
                        .font(.caption.bold()).foregroundStyle(strengthColor(report.inferenceStrength))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(strengthColor(report.inferenceStrength).opacity(0.12), in: Capsule())
                }
            }
        }
        .card()
        .onAppear { rankID = rankID ?? model.temperamentRankOptions.first?.id }
    }

    @ViewBuilder
    private func reportHeader(_ report: TemperamentAnalysisReport) -> some View {
        HStack(spacing: 12) {
            MetricCard(title: "Evidence", value: report.inferenceStrength.rawValue.capitalized, symbol: "checkmark.seal")
            MetricCard(title: "Pitch classes", value: "\(report.observations.count) / 12", symbol: "circle.grid.3x3")
            MetricCard(title: "Reference A4", value: "\(report.referenceA4Hz.formatted(.number.precision(.fractionLength(2)))) Hz", symbol: "tuningfork")
            MetricCard(title: "Best weighted fit", value: report.matches.first.map { "\(($0.weightedRMSECents ?? $0.robustRMSECents).formatted(.number.precision(.fractionLength(2)))) ¢" } ?? "—", symbol: "point.3.connected.trianglepath.dotted")
            MetricCard(title: "Runner-up margin", value: report.runnerUpMarginCents.map { "\($0.formatted(.number.precision(.fractionLength(2)))) ¢" } ?? "—", symbol: "arrow.left.and.right")
        }
        Text("\(report.rankLabel) · \(report.analyzedTakeCount) analyzed takes · A4 source: \(a4Source(report.referenceA4Source))")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func run(refresh: Bool) {
        guard let id = rankID ?? model.temperamentRankOptions.first?.id else { return }
        Task { await model.analyzeTemperament(rankComponentID: id, refreshCatalog: refresh) }
    }

    private func strengthColor(_ strength: TemperamentInferenceStrength) -> Color {
        switch strength {
        case .strong: OrgRecTheme.ai
        case .suggestive: OrgRecTheme.ai
        case .tentative: .orange
        case .insufficient: OrgRecTheme.shu
        }
    }

    private func a4Source(_ source: TemperamentA4Source) -> String {
        switch source {
        case .acceptedSessionCalibration: "accepted session calibration"
        case .measuredFromSelectedRank: "measured A4 recording in this rank"
        case .documentedPrior: "documented prior (provisional)"
        case .assumed440: "assumed 440 Hz (provisional)"
        }
    }
}

private struct TemperamentCandidateRow: View {
    let index: Int
    let match: TemperamentCandidateMatch
    let catalogBaseURL: URL?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)").font(.headline.monospacedDigit()).frame(width: 26, height: 26)
                .background(index == 1 ? OrgRecTheme.ai.opacity(0.15) : OrgRecTheme.sumi.opacity(0.07), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(match.title).fontWeight(index == 1 ? .semibold : .regular)
                    if match.isPreciseVariant { Text("Precise").font(.caption2).padding(.horizontal, 5).background(OrgRecTheme.ai.opacity(0.1), in: Capsule()) }
                }
                Text([match.label, match.groupLabel].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            LabeledContent("Weighted RMSE", value: "\((match.weightedRMSECents ?? match.robustRMSECents).formatted(.number.precision(.fractionLength(2)))) ¢")
            LabeledContent("Median error", value: "\(match.medianAbsoluteErrorCents.formatted(.number.precision(.fractionLength(2)))) ¢")
            if let support = match.sensitivitySupport {
                LabeledContent("Sensitivity", value: support.formatted(.percent.precision(.fractionLength(0))))
            }
            Text("\(match.matchedPitchClassCount)/12").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            if let url = navigatorURL {
                Link("MODAVIS detail", destination: url).font(.caption)
            }
        }
        .font(.caption)
        .padding(10)
        .background(index == 1 ? OrgRecTheme.ai.opacity(0.07) : OrgRecTheme.sumi.opacity(0.035), in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
    }

    private var navigatorURL: URL? {
        guard let path = match.navigatorPath, let base = catalogBaseURL else { return match.sourceURL }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }
}

private struct TemperamentVectorChart: View {
    let report: TemperamentAnalysisReport
    let match: TemperamentCandidateMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Observed pitch-class shape vs. nearest candidate").font(.headline)
                    Text(match.title).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 12) {
                    Label("Observed", systemImage: "circle.fill").foregroundStyle(OrgRecTheme.shu)
                    Label("Candidate", systemImage: "circle.fill").foregroundStyle(OrgRecTheme.ai)
                }.font(.caption)
            }
            Canvas { context, size in
                let values = match.vector.flatMap { [$0.observedCents, $0.candidateCents] }
                let span = max(10, min(60, ceil((values.map(abs).max() ?? 10) / 10) * 10))
                func point(_ index: Int, _ value: Double) -> CGPoint {
                    CGPoint(
                        x: size.width * CGFloat(index) / CGFloat(max(1, match.vector.count - 1)),
                        y: size.height * CGFloat(0.5 - value / (2 * span))
                    )
                }
                for fraction in [-1.0, -0.5, 0, 0.5, 1.0] {
                    let y = size.height * CGFloat(0.5 - fraction / 2)
                    var grid = Path(); grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(grid, with: .color(OrgRecTheme.sumi.opacity(fraction == 0 ? 0.28 : 0.08)), lineWidth: fraction == 0 ? 1.2 : 1)
                }
                var observed = Path(); var candidate = Path()
                for (index, value) in match.vector.enumerated() {
                    let op = point(index, value.observedCents)
                    let cp = point(index, value.candidateCents)
                    if let observation = report.observations.first(where: { $0.pitchClass == value.pitchClass }) {
                        let uncertainty = max(observation.medianAbsoluteDeviationCents, observation.uncertaintyCents ?? 0)
                        if uncertainty > 0 {
                            var whisker = Path()
                            whisker.move(to: point(index, value.observedCents - uncertainty))
                            whisker.addLine(to: point(index, value.observedCents + uncertainty))
                            context.stroke(whisker, with: .color(OrgRecTheme.shu.opacity(0.55)), lineWidth: 1)
                        }
                    }
                    if index == 0 { observed.move(to: op); candidate.move(to: cp) }
                    else { observed.addLine(to: op); candidate.addLine(to: cp) }
                    context.fill(Path(ellipseIn: CGRect(x: op.x - 3, y: op.y - 3, width: 6, height: 6)), with: .color(OrgRecTheme.shu))
                    context.fill(Path(ellipseIn: CGRect(x: cp.x - 3, y: cp.y - 3, width: 6, height: 6)), with: .color(OrgRecTheme.ai))
                }
                context.stroke(observed, with: .color(OrgRecTheme.shu), lineWidth: 2)
                context.stroke(candidate, with: .color(OrgRecTheme.ai), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Observed temperament shape compared with \(match.title)")
            .accessibilityValue("Weighted root mean square error \((match.weightedRMSECents ?? match.robustRMSECents).formatted(.number.precision(.fractionLength(2)))) cents across \(match.matchedPitchClassCount) pitch classes")
            Text("Observed whiskers show the larger of pitch-class MAD or propagated uncertainty; the dashed candidate remains a catalogue hypothesis.")
                .font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 0) {
                ForEach(match.vector) { point in
                    Text(point.toneName).font(.caption2.monospaced()).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(13)
        .background(OrgRecTheme.sumi.opacity(0.035), in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius))
    }
}

private struct ControlEventAlignmentView: View {
    let eventLog: ControlEventLog
    let alignment: AudioControlAlignment?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Synchronized control events", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.headline)
                Spacer()
                Text(alignment?.status.rawValue ?? "unaligned").font(.caption.monospacedDigit())
            }
            HStack(spacing: 18) {
                LabeledContent("Events", value: "\(eventLog.events.count)")
                LabeledContent("Mapped frames", value: "\(alignment?.mappings.count ?? 0)")
                LabeledContent("Clock drift", value: alignment?.driftPPM.map { "\($0.formatted(.number.precision(.fractionLength(0...3)))) ppm" } ?? "—")
                LabeledContent("Base uncertainty", value: alignment.map { "\(($0.baseUncertaintySeconds * 1_000).formatted(.number.precision(.fractionLength(1)))) ms" } ?? "—")
            }
            .font(.caption)
            if eventLog.events.isEmpty {
                Text("The CoreMIDI event lane was active, but no input messages arrived during this take.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(eventLog.events.prefix(10)) { event in
                    let mapping = alignment?.mappings.first { $0.eventID == event.id }
                    HStack {
                        Text(event.role.rawValue).frame(width: 112, alignment: .leading)
                        Text(event.message.messageType.displayName)
                        Text(event.rawDataHex).font(.caption.monospacedDigit())
                        Spacer()
                        Text(mapping.map { "frame \($0.audioFrame) · \($0.audioTimeSeconds.formatted(.number.precision(.fractionLength(4)))) s ± \(($0.uncertaintySeconds * 1_000).formatted(.number.precision(.fractionLength(1)))) ms" } ?? "not mapped")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                if eventLog.events.count > 10 {
                    Text("+ \(eventLog.events.count - 10) further events in the immutable control-event log")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(alignment?.clockBasis ?? eventLog.clockBasis)
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct TakeProvenanceView: View {
    let provenance: TakeProvenanceSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Immutable take provenance", systemImage: "lock.doc.fill").font(.headline)
                Spacer()
                Text(provenance.contractVersion).font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
                GridRow {
                    LabeledContent("Session", value: provenance.sessionCode)
                    LabeledContent("Operator", value: provenance.operatorName)
                    LabeledContent("Timezone", value: provenance.timezoneIdentifier)
                }
                GridRow {
                    LabeledContent("Setup", value: provenance.microphoneSetup.map { "\($0.name) r\($0.revision)" } ?? "—")
                    LabeledContent("Registration", value: provenance.registration?.name ?? "—")
                    LabeledContent("Recipe", value: "\(provenance.recipe.name) r\(provenance.recipe.version)")
                }
                GridRow {
                    LabeledContent("Environment", value: environmentLabel)
                    LabeledContent("Clock", value: provenance.clockSource)
                    LabeledContent("MODAVIS", value: provenance.component.locator.trust.rawValue)
                }
                if let protocolSnapshot = provenance.instrumentNoiseProtocol {
                    GridRow {
                        LabeledContent("Noise target", value: protocolSnapshot.kind.displayName)
                        LabeledContent("Action", value: protocolSnapshot.variantLabel)
                        LabeledContent("Repetitions", value: "\(protocolSnapshot.minimumAcceptedTakeCount) accepted")
                    }
                }
                if let definition = provenance.soundingTargetDefinition {
                    GridRow {
                        LabeledContent("Sounding target", value: definition.family.displayName)
                        LabeledContent("Behavior", value: definition.temporalBehavior.rawValue)
                        LabeledContent("Takes required", value: "\(definition.minimumAcceptedTakeCount)")
                    }
                }
                if let state = provenance.captureStateSnapshot {
                    GridRow {
                        LabeledContent("Capture state", value: state.name)
                        LabeledContent("State fingerprint", value: String(state.fingerprintSHA256.prefix(12)))
                        LabeledContent("Mapped controls", value: "\(provenance.controlBindings?.count ?? 0)")
                    }
                }
            }
            .font(.caption)
            Text(provenance.navigatorPayloadSHA256)
                .font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
        }
    }

    private var environmentLabel: String {
        let temperature = provenance.environment.temperatureCelsius.map { "\($0.formatted(.number.precision(.fractionLength(1)))) °C" }
        let humidity = provenance.environment.relativeHumidityPercent.map { "\($0.formatted(.number.precision(.fractionLength(0))))% RH" }
        let value = [temperature, humidity].compactMap { $0 }.joined(separator: " · ")
        return value.isEmpty ? "—" : value
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit().bold()).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct AnalysisWaveform: View {
    let waveform: WaveformSummary?
    let analysis: AnalysisSummary
    let markers: [AnalysisMarkerKind: Double]
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OrgRecTheme.sumi.opacity(0.94)))
            if let waveform, waveform.samples.count > 1 {
                var path = Path()
                for (i, sample) in waveform.samples.enumerated() {
                    let x = size.width * CGFloat(i) / CGFloat(waveform.samples.count - 1)
                    let y = size.height / 2 - CGFloat(sample) * size.height * 0.45
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(OrgRecTheme.ai), lineWidth: 1)
                let colors: [AnalysisMarkerKind: Color] = [
                    .onset: OrgRecTheme.shu,
                    .sustainStart: OrgRecTheme.shu.opacity(0.62),
                    .keyUp: OrgRecTheme.sumi.opacity(0.65),
                    .soundOffset: OrgRecTheme.ai,
                    .tailEnd: OrgRecTheme.ai.opacity(0.58),
                ]
                for kind in AnalysisMarkerKind.allCases {
                    guard let time = markers[kind] else { continue }
                    let x = size.width * CGFloat(time / max(0.001, waveform.duration))
                    var marker = Path()
                    marker.move(to: CGPoint(x: x, y: 0)); marker.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(marker, with: .color(colors[kind] ?? OrgRecTheme.washi), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct InteractiveLoopPointEditor: View {
    @EnvironmentObject private var model: AppModel
    let analysis: AnalysisSummary
    @ObservedObject var interaction: AnalysisInteractionState
    @State private var author = NSFullUserName()
    @State private var reason = ""
    @State private var attackSeconds = 0.008
    @State private var releaseSeconds = 0.35
    @State private var sustainLevel = 1.0
    @State private var curve = PlaybackEnvelopeCurve.equalPower
    @State private var exitPolicy = LoopExitPolicy.crossfadeToRecordedRelease
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Text("Candidates are detector evidence. Drag LOOP IN/OUT in either linked visualization, audition the gated instrument response, then create a reviewed revision. The source candidate is never overwritten.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if let behavior = analysis.pipeSoundBehavior {
                        Text("\(label(behavior.loopability)) · stationarity \(behavior.sustainStationarity?.formatted(.percent.precision(.fractionLength(0))) ?? "—")")
                            .font(.caption.bold())
                            .foregroundStyle(behavior.loopability == .unsuitable ? OrgRecTheme.shu : OrgRecTheme.ai)
                    }
                }
                if candidates.isEmpty {
                    Label("No defensible loop candidate was found in the observed sustain.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout).foregroundStyle(OrgRecTheme.shu)
                } else {
                    candidateStrip
                    Divider()
                    HStack(alignment: .top, spacing: 18) {
                        loopCoordinates.frame(maxWidth: .infinity, alignment: .topLeading)
                        envelopeControls.frame(maxWidth: .infinity, alignment: .topLeading)
                        SustainEnvelopeMonitor(playback: model.playback, attackSeconds: attackSeconds, releaseSeconds: releaseSeconds, sustainLevel: sustainLevel, curve: curve)
                            .frame(width: 250, height: 126)
                    }
                    Divider()
                    HStack {
                        TextField("Reviewer", text: $author).textFieldStyle(.roundedBorder).frame(maxWidth: 210)
                        TextField("Evidence-based reason for accepting or rejecting this loop", text: $reason).textFieldStyle(.roundedBorder)
                        Button("Reject candidate") {
                            guard let sourceID = interaction.loopSourceID else { return }
                            Task { await model.rejectLoopPointSet(sourceID: sourceID, author: author, reason: reason) }
                        }
                        .disabled(selectedSet?.status != .proposed || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button(model.playback.isSustainActive ? "Release note" : "Hold note") {
                            if model.playback.isSustainActive { model.playback.releaseSustain() }
                            else { configureAudition(); model.playback.triggerSustain() }
                        }
                        .keyboardShortcut(.space, modifiers: [.option])
                        .disabled(!interaction.loopDraftIsValid)
                        Button("Accept reviewed loop") { accept() }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canAccept)
                    }
                    if reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Acceptance and rejection require a reason because the decision becomes provenance, not a display preference.")
                            .font(.caption2).foregroundStyle(OrgRecTheme.shu)
                    }
                    reviewHistory
                }
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Label("Loop-point adjudication & sustained sampled-instrument playback", systemImage: "repeat.circle")
                    .font(.headline)
                Spacer()
                if let set = model.acceptedLoopPointSet {
                    Label("Reviewed loop \(short(set.id))", systemImage: "checkmark.seal.fill")
                        .font(.caption.bold()).foregroundStyle(OrgRecTheme.ai)
                } else {
                    Text("candidate evidence").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { loadEnvelope(from: selectedSet) }
        .onChange(of: interaction.loopSourceID) { _, _ in loadEnvelope(from: selectedSet) }
    }

    private var candidates: [LoopPointSet] { model.selectedLoopPointSets }
    private var selectedSet: LoopPointSet? { candidates.first { $0.id == interaction.loopSourceID } }

    private var candidateStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(candidates) { set in
                    let region = set.sustainRegion
                    Button {
                        interaction.configureLoop(set)
                        loadEnvelope(from: set)
                        model.playback.configureLoopPointSet(set)
                        if let region { interaction.focus(time: (region.startSeconds(sampleRate: set.sampleRate) + region.endSeconds(sampleRate: set.sampleRate)) / 2, span: min(5, max(0.5, region.endSeconds(sampleRate: set.sampleRate) - region.startSeconds(sampleRate: set.sampleRate) + 1))) }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(set.status == .accepted ? "REVIEWED" : "CANDIDATE \(set.candidateRank ?? 0)").font(.caption2.bold())
                                if interaction.loopSourceID == set.id { Image(systemName: "checkmark.circle.fill") }
                            }
                            Text(region.map { "\($0.startSeconds(sampleRate: set.sampleRate).formatted(.number.precision(.fractionLength(4))))–\($0.endSeconds(sampleRate: set.sampleRate).formatted(.number.precision(.fractionLength(4)))) s" } ?? "invalid region")
                                .font(.caption.monospacedDigit())
                            Text("confidence \(set.confidence.formatted(.percent.precision(.fractionLength(0)))) · seam \(region?.score?.total.formatted(.number.precision(.fractionLength(3))) ?? "—")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(interaction.loopSourceID == set.id ? OrgRecTheme.ai.opacity(0.13) : OrgRecTheme.sumi.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var loopCoordinates: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exact loop coordinates").font(.caption.bold())
            ForEach(LoopBoundaryHandle.allCases) { handle in
                HStack {
                    Button {
                        interaction.selectedLoopHandle = interaction.selectedLoopHandle == handle ? nil : handle
                        interaction.selectedBoundary = nil
                    } label: {
                        Label(handle.rawValue, systemImage: interaction.selectedLoopHandle == handle ? "circle.inset.filled" : "circle")
                            .frame(width: 110, alignment: .leading)
                    }.buttonStyle(.plain)
                    TextField("seconds", value: Binding(
                        get: { handle == .start ? interaction.loopDraftStartSeconds ?? 0 : interaction.loopDraftEndSeconds ?? 0 },
                        set: { interaction.setLoopHandle(handle, to: $0) }
                    ), format: .number.precision(.fractionLength(6)))
                    .textFieldStyle(.roundedBorder).frame(width: 112)
                    Text("s").foregroundStyle(.secondary)
                    ControlGroup {
                        Button("−1 frame") { nudgeFrames(handle, -1) }
                        Button("+1 frame") { nudgeFrames(handle, 1) }
                    }.controlSize(.mini)
                    Button("Playhead") { interaction.setLoopHandle(handle, to: model.playback.currentTime) }.controlSize(.small)
                }
            }
            HStack {
                Text("Crossfade").frame(width: 110, alignment: .leading)
                TextField("seconds", value: $interaction.loopCrossfadeSeconds, format: .number.precision(.fractionLength(6)))
                    .textFieldStyle(.roundedBorder).frame(width: 112)
                Text("s").foregroundStyle(.secondary)
                Button("Revert") { interaction.revertLoopDraft(); configureAudition() }.disabled(!interaction.hasLoopChanges)
            }
            if let set = selectedSet, let start = interaction.loopDraftStartSeconds, let end = interaction.loopDraftEndSeconds {
                Text("Authoritative frames: \(Int64((start * set.sampleRate).rounded()))..<\(Int64((end * set.sampleRate).rounded())) at \(set.sampleRate.formatted(.number.precision(.fractionLength(0)))) Hz · shared by all \(set.channelCount) channels")
                    .font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if !interaction.loopDraftIsValid {
                Label("Loop out must follow loop in; crossfade must be shorter than half the region.", systemImage: "exclamationmark.octagon.fill")
                    .font(.caption).foregroundStyle(OrgRecTheme.shu)
            }
            if !releasePolicyIsValid {
                Label("This capture has no addressed recorded release; choose Envelope release.", systemImage: "exclamationmark.octagon.fill")
                    .font(.caption).foregroundStyle(OrgRecTheme.shu)
            }
        }
    }

    private var envelopeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Perceptual playback envelope").font(.caption.bold())
            LabeledContent("Attack") { TextField("s", value: $attackSeconds, format: .number.precision(.fractionLength(3))).textFieldStyle(.roundedBorder).frame(width: 82) }
            LabeledContent("Release") { TextField("s", value: $releaseSeconds, format: .number.precision(.fractionLength(3))).textFieldStyle(.roundedBorder).frame(width: 82) }
            LabeledContent("Sustain level") { Slider(value: $sustainLevel, in: 0.05...1).frame(width: 130); Text(sustainLevel.formatted(.percent.precision(.fractionLength(0)))).font(.caption.monospacedDigit()) }
            Picker("Curve", selection: $curve) { ForEach(PlaybackEnvelopeCurve.allCases) { Text(label($0)).tag($0) } }.pickerStyle(.segmented)
            Picker("Note-off", selection: $exitPolicy) { ForEach(LoopExitPolicy.allCases) { Text(label($0)).tag($0) } }
                .pickerStyle(.menu)
            Text("Equal-power overlap is applied at every loop seam. At note-off, OrgRec follows the selected policy and uses the recorded release when available.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var reviewHistory: some View {
        if let reviews = model.selectedTake?.loopPointReviews, !reviews.isEmpty {
            DisclosureGroup("Immutable loop review history (\(reviews.count))") {
                ForEach(reviews.reversed()) { review in
                    Text("\(review.decision) · \(short(review.loopPointSetID)) · \(review.author) · \(review.reason)")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 4)
            }.font(.caption)
        }
    }

    private var canAccept: Bool {
        interaction.loopDraftIsValid && releasePolicyIsValid && interaction.loopSourceID != nil
            && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && attackSeconds >= 0 && releaseSeconds > 0 && (0...1).contains(sustainLevel)
    }

    private var releasePolicyIsValid: Bool {
        exitPolicy == .envelopeRelease || selectedSet?.sustainRegion?.releaseStartFrame != nil
    }

    private func nudgeFrames(_ handle: LoopBoundaryHandle, _ frames: Int) {
        let rate = selectedSet?.sampleRate ?? 48_000
        interaction.nudgeLoopHandle(handle, by: Double(frames) / rate)
    }

    private func currentEnvelope() -> SustainPlaybackEnvelope {
        SustainPlaybackEnvelope(attackSeconds: attackSeconds, releaseSeconds: releaseSeconds, sustainLevel: sustainLevel, curve: curve)
    }

    private func configureAudition() {
        guard var set = selectedSet, var region = set.sustainRegion,
              let start = interaction.loopDraftStartSeconds, let end = interaction.loopDraftEndSeconds else { return }
        region.startFrameInclusive = Int64((start * set.sampleRate).rounded())
        region.endFrameExclusive = Int64((end * set.sampleRate).rounded())
        region.crossfadeFrames = Int64((interaction.loopCrossfadeSeconds * set.sampleRate).rounded())
        region.exitPolicy = exitPolicy
        set.regions = [region]
        set.envelope = currentEnvelope()
        model.playback.configureLoopPointSet(set)
    }

    private func accept() {
        guard let sourceID = interaction.loopSourceID,
              let start = interaction.loopDraftStartSeconds,
              let end = interaction.loopDraftEndSeconds else { return }
        Task {
            await model.acceptLoopPointSet(
                sourceID: sourceID,
                startSeconds: start,
                endSeconds: end,
                crossfadeSeconds: interaction.loopCrossfadeSeconds,
                envelope: currentEnvelope(),
                mode: .forward,
                exitPolicy: exitPolicy,
                author: author,
                reason: reason
            )
            if let accepted = model.acceptedLoopPointSet {
                interaction.commitLoopDraft(result: accepted)
                reason = ""
            }
        }
    }

    private func loadEnvelope(from set: LoopPointSet?) {
        guard let set else { return }
        attackSeconds = set.envelope.attackSeconds
        releaseSeconds = set.envelope.releaseSeconds
        sustainLevel = set.envelope.sustainLevel
        curve = set.envelope.curve
        exitPolicy = set.sustainRegion?.exitPolicy ?? .crossfadeToRecordedRelease
    }

    private func short(_ id: UUID) -> String { String(id.uuidString.lowercased().prefix(8)) }
    private func label(_ value: LoopabilityClass?) -> String { value?.rawValue.replacingOccurrences(of: "Periodic", with: " periodic").capitalized ?? "Unknown loopability" }
    private func label(_ value: PlaybackEnvelopeCurve) -> String { value == .equalPower ? "Equal power" : "Linear" }
    private func label(_ value: LoopExitPolicy) -> String {
        switch value {
        case .crossfadeToRecordedRelease: "Recorded release"
        case .envelopeRelease: "Envelope release"
        case .finishCycleThenRelease: "Finish cycle, then release"
        }
    }
}

private struct SustainEnvelopeMonitor: View {
    @ObservedObject var playback: AudioPlaybackController
    let attackSeconds: Double
    let releaseSeconds: Double
    let sustainLevel: Double
    let curve: PlaybackEnvelopeCurve

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Runtime envelope").font(.caption.bold())
                Spacer()
                Text(playback.sustainPhase.rawValue).font(.caption2).foregroundStyle(.secondary)
            }
            Canvas { context, size in
                let attackWidth = size.width * 0.2
                let releaseWidth = size.width * 0.25
                let levelY = size.height * CGFloat(1 - sustainLevel)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addCurve(to: CGPoint(x: attackWidth, y: levelY), control1: CGPoint(x: attackWidth * 0.55, y: curve == .equalPower ? size.height * 0.3 : size.height), control2: CGPoint(x: attackWidth * 0.8, y: levelY))
                path.addLine(to: CGPoint(x: size.width - releaseWidth, y: levelY))
                path.addCurve(to: CGPoint(x: size.width, y: size.height), control1: CGPoint(x: size.width - releaseWidth * 0.45, y: levelY), control2: CGPoint(x: size.width - releaseWidth * 0.2, y: size.height))
                context.stroke(path, with: .color(OrgRecTheme.ai), lineWidth: 2)
                let x = size.width * CGFloat(min(1, max(0, playback.currentTime / max(0.001, playback.duration))))
                let y = size.height * CGFloat(1 - playback.envelopeLevel)
                context.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 4, width: 8, height: 8)), with: .color(OrgRecTheme.shu))
            }
            Text("A \(attackSeconds.formatted(.number.precision(.fractionLength(3)))) s · S \(sustainLevel.formatted(.percent.precision(.fractionLength(0)))) · R \(releaseSeconds.formatted(.number.precision(.fractionLength(3)))) s · cycle \(playback.loopIteration)")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(8).background(OrgRecTheme.sumi.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct PipeSoundBehaviorPanel: View {
    let behavior: PipeSoundBehaviorSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("Phase-resolved pipe-sound behaviour", systemImage: "waveform.path.ecg.rectangle").font(.headline)
            HStack(spacing: 12) {
                MetricCard(title: "Attack", value: behavior.attackDurationSeconds.map { "\($0.formatted(.number.precision(.fractionLength(3)))) s" } ?? "—", symbol: "bolt")
                MetricCard(title: "Attack periods", value: behavior.attackDurationFundamentalPeriods?.formatted(.number.precision(.fractionLength(1))) ?? "—", symbol: "waveform")
                MetricCard(title: "AM", value: behavior.amplitudeModulationRateHz.map { "\($0.formatted(.number.precision(.fractionLength(2)))) Hz" } ?? "—", symbol: "waveform.path")
                MetricCard(title: "Release", value: behavior.releaseDurationSeconds.map { "\($0.formatted(.number.precision(.fractionLength(3)))) s" } ?? "—", symbol: "speaker.wave.1")
                MetricCard(title: "Room tail", value: behavior.roomTailDurationSeconds.map { "\($0.formatted(.number.precision(.fractionLength(3)))) s" } ?? "—", symbol: "building.columns")
            }
            Text("Partial onset order: \(behavior.partialOnsetOrder.isEmpty ? "unavailable" : behavior.partialOnsetOrder.map { "H\($0)" }.joined(separator: " → "))")
                .font(.caption).foregroundStyle(.secondary)
            Text("These descriptors separate pipe attack, stationary or modulated sustain, key-release behaviour, and room decay; absent values indicate unobserved or insufficient evidence.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct PerceptualSpectralPanel: View {
    let summary: PerceptualSpectralSummary
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Perceptual spectrum & beat evidence", systemImage: "ear.badge.waveform")
                        .font(.headline)
                    Text("Broadband, auditory ERB, harmonic-shape, and slow-modulation descriptors from the stable sustain.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("v1 · \(summary.analyzedFrameCount) frames")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                descriptor("Auditory centroid", value(summary.auditoryCentroidERB, " ERB"), "ear")
                descriptor("Auditory spread", value(summary.auditorySpreadERB, " ERB"), "arrow.left.and.right")
                descriptor("Spectral flatness", ratio(summary.spectralFlatness), "waveform.path")
                descriptor("Spectral entropy", ratio(summary.spectralEntropy), "chart.bar.xaxis")
                descriptor("Spectral crest", value(summary.spectralCrestDB, " dB"), "waveform.badge.plus")
                descriptor("Frame-to-frame flux", ratio(summary.spectralFlux), "arrow.triangle.2.circlepath")
                descriptor("Harmonic energy", percent(summary.harmonicEnergyRatio), "music.note.list")
                descriptor("Harmonic slope", value(summary.harmonicSpectralSlopeDBPerOctave, " dB/oct"), "chart.line.downtrend.xyaxis")
                descriptor("Harmonic deviation", value(summary.harmonicSpectralDeviationDB, " dB"), "point.3.connected.trianglepath.dotted")
                descriptor("Tristimulus T₁/T₂/T₃", tristimulus, "square.stack.3d.up")
                descriptor("Amplitude beat", modulation(summary.amplitudeModulationRateHz, summary.amplitudeModulationDepthDB, " dB"), "waveform.path.ecg")
                descriptor("Brightness cycle", modulation(summary.spectralCentroidModulationRateHz, summary.spectralCentroidModulationDepthERB, " ERB"), "sun.max")
            }
            if let am = summary.amplitudeModulationRateHz,
               let spectral = summary.spectralCentroidModulationRateHz,
               abs(am - spectral) <= max(0.15, am * 0.08) {
                Label("Amplitude and spectral-centroid modulation agree near \(am.formatted(.number.precision(.fractionLength(2)))) Hz. This is useful beat/tremulant evidence, not a mechanism identification.", systemImage: "waveform.badge.checkmark")
                    .font(.caption).foregroundStyle(OrgRecTheme.ai)
            }
            DisclosureGroup("Method and interpretation limits") {
                Text(summary.method).font(.caption).textSelection(.enabled)
                ForEach(summary.limitations, id: \.self) { limitation in
                    Text("• \(limitation)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .font(.caption.bold())
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Perceptual spectrum and beat evidence")
    }

    private var tristimulus: String {
        guard let first = summary.tristimulus1, let second = summary.tristimulus2, let third = summary.tristimulus3 else { return "—" }
        return [first, second, third].map { $0.formatted(.percent.precision(.fractionLength(0))) }.joined(separator: " / ")
    }
    private func descriptor(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit().bold()).lineLimit(1).minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)
        .padding(8).background(OrgRecTheme.sumi.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }
    private func value(_ number: Double?, _ suffix: String) -> String { number.map { $0.formatted(.number.precision(.fractionLength(2))) + suffix } ?? "—" }
    private func ratio(_ number: Double?) -> String { number?.formatted(.number.precision(.fractionLength(3))) ?? "—" }
    private func percent(_ number: Double?) -> String { number?.formatted(.percent.precision(.fractionLength(0))) ?? "—" }
    private func modulation(_ rate: Double?, _ depth: Double?, _ suffix: String) -> String {
        guard let rate else { return "—" }
        return rate.formatted(.number.precision(.fractionLength(2))) + " Hz · " + (depth.map { $0.formatted(.number.precision(.fractionLength(2))) + suffix } ?? "depth —")
    }
}

struct AcousticDecayEvidencePanel: View {
    let analysis: AcousticResponseAnalysis
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label(analysis.qualification == .observedInstrumentRelease ? "Observed release-decay evidence" : "Qualified room-response evidence", systemImage: "building.columns.circle")
                        .font(.headline)
                    Text(analysis.qualification.displayName)
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(analysis.broadband.usableDecayRangeDB.formatted(.number.precision(.fractionLength(1)))) dB usable")
                    .font(.caption.monospacedDigit().bold())
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                fit("EDT", analysis.broadband.edt)
                fit("T20", analysis.broadband.t20)
                fit("T30", analysis.broadband.t30)
                compactMetric("Noise floor", "\(analysis.broadband.estimatedNoiseFloorDB.formatted(.number.precision(.fractionLength(1)))) dBFS", "waveform.slash")
                if let value = analysis.broadband.clarity80DB { compactMetric("C₈₀", "\(value.formatted(.number.precision(.fractionLength(1)))) dB", "music.quarternote.3") }
                if let value = analysis.broadband.definition50 { compactMetric("D₅₀", value.formatted(.percent.precision(.fractionLength(0))), "quote.bubble") }
            }
            if let slopes = analysis.broadband.multiSlope {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Multiple decay slopes supported", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                        .font(.callout.bold()).foregroundStyle(OrgRecTheme.shu)
                    Text("Early \(slopes.earlyDecayTimeSeconds.formatted(.number.precision(.fractionLength(2)))) s → late \(slopes.lateDecayTimeSeconds.formatted(.number.precision(.fractionLength(2)))) s at \(slopes.transitionTimeSeconds.formatted(.number.precision(.fractionLength(3)))) s / \(slopes.transitionLevelDB.formatted(.number.precision(.fractionLength(1)))) dB · ΔBIC \(slopes.deltaBIC.formatted(.number.precision(.fractionLength(1))))")
                        .font(.caption.monospacedDigit())
                    Text("Coupled church volumes and non-diffuse fields can produce real multi-rate decay; inspect both slopes instead of reporting one RT value.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(9).background(OrgRecTheme.shu.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
            }
            if !analysis.octaveBands.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(analysis.octaveBands) { band in
                            VStack(spacing: 3) {
                                Text(band.centerFrequencyHz.map(bandLabel) ?? "BB").font(.caption2.bold())
                                Text(band.t20.map { "\($0.extrapolatedDecayTimeSeconds.formatted(.number.precision(.fractionLength(2)))) s" } ?? "—")
                                    .font(.caption.monospacedDigit())
                                Text("R² \(band.t20?.coefficientOfDetermination.formatted(.number.precision(.fractionLength(2))) ?? "—")")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(width: 70).padding(6)
                            .background(OrgRecTheme.ai.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .accessibilityLabel("Octave-band T20 decay estimates")
            }
            ForEach(analysis.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary)
            }
            Text(analysis.conformanceStatement).font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
    }

    private func fit(_ title: String, _ value: AcousticDecayFit?) -> some View {
        compactMetric(title, value.map {
            let uncertainty = $0.standardUncertaintySeconds.map { " ± \($0.formatted(.number.precision(.fractionLength(2))))" } ?? ""
            return $0.extrapolatedDecayTimeSeconds.formatted(.number.precision(.fractionLength(2))) + uncertainty + " s · R² " + $0.coefficientOfDetermination.formatted(.number.precision(.fractionLength(2)))
        } ?? "—", "chart.line.downtrend.xyaxis")
    }
    private func compactMetric(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit().bold()).lineLimit(1).minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)
        .padding(8).background(OrgRecTheme.sumi.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }
    private func bandLabel(_ frequency: Double) -> String {
        frequency >= 1_000 ? "\((frequency / 1_000).formatted(.number.precision(.fractionLength(0...1))))k" : frequency.formatted(.number.precision(.fractionLength(0)))
    }
}

struct PlaybackBar: View {
    @ObservedObject var playback: AudioPlaybackController

    var body: some View {
        HStack(spacing: 12) {
            Button {
                playback.skip(by: -2)
            } label: {
                Label("Back 2 seconds", systemImage: "gobackward.2").labelStyle(.iconOnly)
            }
            .help("Back 2 seconds")
            Button {
                playback.togglePlayback()
            } label: {
                Label(playback.isPlaying ? "Pause" : "Play", systemImage: playback.isPlaying ? "pause.fill" : "play.fill")
                    .labelStyle(.iconOnly)
                    .frame(width: 18)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!playback.isLoaded)
            Button {
                playback.skip(by: 2)
            } label: {
                Label("Forward 2 seconds", systemImage: "goforward.2").labelStyle(.iconOnly)
            }
            .help("Forward 2 seconds")
            Text(playback.currentTime.formatted(.number.precision(.fractionLength(3))))
                .font(.system(.body, design: .monospaced)).frame(width: 75, alignment: .trailing)
            Slider(
                value: Binding(get: { playback.currentTime }, set: { playback.seek(to: $0) }),
                in: 0...max(0.001, playback.duration)
            )
            .accessibilityLabel("Playback position")
            .accessibilityValue(playback.currentTime.formatted(.number.precision(.fractionLength(3))) + " seconds")
            Text(playback.duration.formatted(.number.precision(.fractionLength(3))) + " s")
                .font(.system(.body, design: .monospaced)).frame(width: 88, alignment: .leading)
            Toggle("Whole-file loop", isOn: $playback.loops).toggleStyle(.checkbox)
            if playback.isSustainActive {
                Label("\(playback.sustainPhase.rawValue) · cycle \(playback.loopIteration)", systemImage: "repeat.circle.fill")
                    .font(.caption.bold()).foregroundStyle(OrgRecTheme.ai)
            }
        }
    }
}

private struct MarkerCorrectionEditor: View {
    @EnvironmentObject private var model: AppModel
    @State private var values: [AnalysisMarkerKind: Double] = [:]
    @State private var author = NSFullUserName()
    @State private var reason = ""
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(spacing: 8) {
                ForEach(AnalysisMarkerKind.allCases) { marker in
                    HStack {
                        Text(marker.rawValue).frame(width: 105, alignment: .leading)
                        TextField(
                            "seconds",
                            value: Binding(
                                get: { values[marker] ?? model.correctedMarker(marker) ?? 0 },
                                set: { values[marker] = $0 }
                            ),
                            format: .number.precision(.fractionLength(4))
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        Text("s").foregroundStyle(.secondary)
                        Button("Set to playhead") {
                            values[marker] = model.playback.currentTime
                        }
                        .controlSize(.small)
                        Spacer()
                        if let automated = automated(marker) {
                            Text("automatic \(automated.formatted(.number.precision(.fractionLength(3)))) s")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
                HStack {
                    TextField("Reviewer", text: $author).textFieldStyle(.roundedBorder)
                    TextField("Reason for correction", text: $reason).textFieldStyle(.roundedBorder)
                    Button("Save corrections") {
                        Task { await model.saveMarkerCorrections(values, author: author, reason: reason) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                if let corrections = model.selectedTake?.markerCorrections, !corrections.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Immutable correction history").font(.caption.bold())
                        ForEach(corrections.suffix(8).reversed()) { correction in
                            Text("\(correction.marker.rawValue): \(correction.automatedSeconds?.formatted(.number.precision(.fractionLength(3))) ?? "—") → \(correction.correctedSeconds.formatted(.number.precision(.fractionLength(3)))) s · \(correction.author) · \(correction.reason)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 10)
        } label: {
            Label("Manual transient adjudication", systemImage: "slider.horizontal.below.rectangle")
                .font(.headline)
        }
        .onAppear {
            values = Dictionary(uniqueKeysWithValues: AnalysisMarkerKind.allCases.compactMap { marker in
                model.correctedMarker(marker).map { (marker, $0) }
            })
        }
    }

    private func automated(_ marker: AnalysisMarkerKind) -> Double? {
        guard let analysis = model.selectedTake?.analysis else { return nil }
        return switch marker {
        case .onset: analysis.onsetSeconds
        case .sustainStart: analysis.sustainStartSeconds
        case .keyUp: analysis.keyUpSeconds
        case .soundOffset: analysis.soundOffsetSeconds
        case .tailEnd: analysis.tailEndSeconds
        }
    }
}

private struct PitchTrackEvidenceView: View {
    let track: [PitchTrackPoint]
    let summary: PitchTrackSummary?
    let runCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Framewise pitch evidence", systemImage: "waveform.path.ecg.rectangle").font(.headline)
                Spacer()
                Text("\(track.count) frames · \(runCount) immutable run\(runCount == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OrgRecTheme.recessed))
                guard let center = summary?.medianFrequencyHz,
                      let firstTime = track.first?.timeSeconds,
                      let lastTime = track.last?.timeSeconds,
                      lastTime > firstTime else { return }
                var zero = Path()
                zero.move(to: CGPoint(x: 0, y: size.height / 2))
                zero.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(zero, with: .color(OrgRecTheme.sumi.opacity(0.2)), lineWidth: 1)
                var path = Path()
                var connected = false
                for point in track {
                    guard point.voiced, let frequency = point.frequencyHz,
                          let cents = PitchMatcher.cents(measured: frequency, expected: center) else {
                        connected = false
                        continue
                    }
                    let x = size.width * CGFloat((point.timeSeconds - firstTime) / (lastTime - firstTime))
                    let y = size.height * CGFloat(0.5 - max(-60, min(60, cents)) / 120)
                    if connected { path.addLine(to: CGPoint(x: x, y: y)) }
                    else { path.move(to: CGPoint(x: x, y: y)); connected = true }
                }
                context.stroke(path, with: .color(OrgRecTheme.ai), lineWidth: 1.4)
            }
            .frame(height: 110)
            HStack(spacing: 18) {
                evidence("Voiced", (summary?.voicedRatio).map { $0.formatted(.percent.precision(.fractionLength(0))) })
                evidence("IQR", (summary?.interquartileRangeCents).map { $0.formatted(.number.precision(.fractionLength(1))) + " ¢" })
                evidence("MAD", (summary?.medianAbsoluteDeviationCents).map { $0.formatted(.number.precision(.fractionLength(1))) + " ¢" })
                evidence("Drift", (summary?.driftCentsPerSecond).map { $0.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always())) + " ¢/s" })
                evidence("Modulation", (summary?.modulationRateHz).map { $0.formatted(.number.precision(.fractionLength(2))) + " Hz" })
                evidence("Depth", (summary?.modulationDepthCents).map { $0.formatted(.number.precision(.fractionLength(1))) + " ¢" })
                Spacer()
            }
        }
    }

    private func evidence(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value ?? "—").font(.caption.monospacedDigit())
        }
    }
}

private struct SpectrogramView: View {
    let data: SpectrogramData?
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OrgRecTheme.recessed))
            guard let data, data.timeBins > 0, data.frequencyBins > 0 else { return }
            let cellW = size.width / CGFloat(data.timeBins)
            let cellH = size.height / CGFloat(data.frequencyBins)
            let dynamicRange = Float(data.configuration?.dynamicRangeDB ?? 90)
            for x in 0..<data.timeBins {
                for y in 0..<data.frequencyBins {
                    let db = data.magnitudes[x][y]
                    let intensity = max(0, min(1, CGFloat((db + dynamicRange) / dynamicRange)))
                    let color = intensity > 0.72
                        ? OrgRecTheme.shu.opacity(0.45 + intensity * 0.55)
                        : OrgRecTheme.ai.opacity(0.08 + intensity * 0.88)
                    let rect = CGRect(x: CGFloat(x) * cellW, y: size.height - CGFloat(y + 1) * cellH, width: cellW + 0.5, height: cellH + 0.5)
                    context.fill(Path(rect), with: .color(color))
                }
            }
            if let frequencies = data.frequencyAxisHz,
               let timeStep = data.timeStepSeconds,
               let tracks = data.partialTracks {
                let duration = max(timeStep, timeStep * Double(data.timeBins - 1))
                for track in tracks.prefix(16) {
                    var path = Path()
                    var hasPoint = false
                    for point in track.points where point.timeSeconds <= duration {
                        guard point.isValid != false else { hasPoint = false; continue }
                        let nearest = frequencies.indices.min(by: {
                            abs(frequencies[$0] - point.frequencyHz) < abs(frequencies[$1] - point.frequencyHz)
                        }) ?? 0
                        let x = size.width * CGFloat(point.timeSeconds / duration)
                        let y = size.height - size.height * CGFloat(nearest) / CGFloat(max(1, frequencies.count - 1))
                        if hasPoint { path.addLine(to: CGPoint(x: x, y: y)) }
                        else { path.move(to: CGPoint(x: x, y: y)); hasPoint = true }
                    }
                    let color = track.harmonicNumber.isMultiple(of: 3)
                        ? OrgRecTheme.shu
                        : OrgRecTheme.ai.opacity(max(0.38, 1 - Double(track.harmonicNumber) * 0.035))
                    context.stroke(path, with: .color(color.opacity(0.85)), lineWidth: track.harmonicNumber == 1 ? 1.8 : 0.8)
                    for marker in [track.onsetSeconds, track.offsetSeconds].compactMap({ $0 }) {
                        let x = size.width * CGFloat(marker / duration)
                        let rect = CGRect(x: x - 1.5, y: 2, width: 3, height: 7)
                        context.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

private struct SpectrogramControls: View {
    @EnvironmentObject private var model: AppModel
    @State private var draft = SpectrogramConfiguration()
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    Text("FFT size")
                    Picker("FFT size", selection: $draft.fftSize) {
                        ForEach([1_024, 2_048, 4_096, 8_192, 16_384, 32_768], id: \.self) { Text("\($0)") }
                    }.labelsHidden()
                    Text("Hop size")
                    Picker("Hop size", selection: $draft.hopSize) {
                        ForEach([64, 128, 256, 512, 1_024, 2_048, 4_096], id: \.self) { Text("\($0)") }
                    }.labelsHidden()
                }
                GridRow {
                    Text("Window")
                    Picker("Window", selection: $draft.window) {
                        ForEach(SpectralWindow.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden()
                    Text("Frequency scale")
                    Picker("Frequency scale", selection: $draft.frequencyScale) {
                        ForEach(SpectralFrequencyScale.allCases) { Text($0.rawValue).tag($0) }
                    }.labelsHidden()
                }
                GridRow {
                    Text("Frequency range")
                    HStack {
                        TextField("Minimum", value: $draft.minimumFrequencyHz, format: .number).frame(width: 76)
                        Text("to")
                        TextField("Maximum", value: $draft.maximumFrequencyHz, format: .number).frame(width: 88)
                        Text("Hz")
                    }
                    Text("Dynamic range")
                    HStack {
                        Slider(value: $draft.dynamicRangeDB, in: 40...140, step: 5).frame(width: 130)
                        Text("\(Int(draft.dynamicRangeDB)) dB").monospacedDigit().frame(width: 55)
                    }
                }
                GridRow {
                    Text("Tracked partials")
                    Stepper("\(draft.partialCount)", value: $draft.partialCount, in: 1...96)
                    Text("Search tolerance")
                    HStack {
                        Slider(value: $draft.partialSearchCents, in: 10...150, step: 5).frame(width: 130)
                        Text("±\(Int(draft.partialSearchCents)) ¢").monospacedDigit().frame(width: 55)
                    }
                }
                GridRow {
                    Text("Partial onset")
                    HStack {
                        TextField("Onset", value: $draft.partialOnsetBelowPeakDB, format: .number).frame(width: 55)
                        Text("dB below peak")
                    }
                    Text("Partial offset")
                    HStack {
                        TextField("Offset", value: $draft.partialOffsetBelowPeakDB, format: .number).frame(width: 55)
                        Text("dB below peak")
                    }
                }
                GridRow {
                    Text("Persistence")
                    Stepper("\(draft.partialPersistenceFrames) frames", value: $draft.partialPersistenceFrames, in: 1...20)
                    Text("Display resolution")
                    Stepper("\(draft.displayFrequencyBins) bins", value: $draft.displayFrequencyBins, in: 64...1_024, step: 32)
                }
                GridRow {
                    Text("Analysis duration")
                    Stepper(
                        "\(Int(draft.maximumAnalysisDurationSeconds)) s maximum",
                        value: $draft.maximumAnalysisDurationSeconds,
                        in: 10...600,
                        step: 10
                    )
                    Text("Maximum frames")
                    Stepper("\(draft.maximumTimeBins)", value: $draft.maximumTimeBins, in: 100...10_000, step: 100)
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.top, 12)

            HStack {
                Text("Smaller hops improve partial onset/offset timing; larger FFTs improve low-frequency separation. Blackman–Harris suppresses leakage for long organ tails.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.selectedTakeID == nil ? "Save capture profile" : "Apply and reanalyze") {
                    Task { await model.reanalyzeSelected(with: draft) }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 12)
        } label: {
            Label("Spectral analysis parameters", systemImage: "slider.horizontal.3")
                .font(.headline)
        }
        .onAppear {
            draft = model.selectedTake?.spectrogramConfiguration
                ?? model.project?.spectrogramConfiguration
                ?? SpectrogramConfiguration()
        }
    }
}

private struct PartialTracksView: View {
    let tracks: [PartialTrack]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Pipe-sound partials", systemImage: "waveform.path.ecg").font(.headline)
                Spacer()
                Text("\(tracks.count) tracked").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text("Partial").frame(width: 55, alignment: .leading)
                Text("Expected").frame(width: 100, alignment: .trailing)
                Text("Measured").frame(width: 100, alignment: .trailing)
                Text("Offset").frame(width: 80, alignment: .trailing)
                Text("Onset").frame(width: 90, alignment: .trailing)
                Text("Acoustic offset").frame(width: 110, alignment: .trailing)
                Text("Decay span").frame(width: 100, alignment: .trailing)
                Spacer()
            }
            .font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(tracks.prefix(32)) { track in
                HStack {
                    Text("H\(track.harmonicNumber)").frame(width: 55, alignment: .leading)
                    Text(hz(track.expectedFrequencyHz)).frame(width: 100, alignment: .trailing)
                    Text(track.medianFrequencyHz.map(hz) ?? "—").frame(width: 100, alignment: .trailing)
                    Text(track.medianOffsetCents.map { $0.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())) + " ¢" } ?? "—")
                        .frame(width: 80, alignment: .trailing)
                    Text(seconds(track.onsetSeconds)).frame(width: 90, alignment: .trailing)
                    Text(seconds(track.offsetSeconds)).frame(width: 110, alignment: .trailing)
                    Text(span(track)).frame(width: 100, alignment: .trailing)
                    Spacer()
                }
                .font(.system(.caption, design: .monospaced))
                Divider()
            }
        }
    }

    private func hz(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) + " Hz" }
    private func seconds(_ value: Double?) -> String { value.map { $0.formatted(.number.precision(.fractionLength(3))) + " s" } ?? "—" }
    private func span(_ track: PartialTrack) -> String {
        guard let onset = track.onsetSeconds, let offset = track.offsetSeconds else { return "—" }
        return (offset - onset).formatted(.number.precision(.fractionLength(3))) + " s"
    }
}

private struct CaptureDiagnosticsView: View {
    let diagnostics: CaptureDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Capture integrity", systemImage: diagnostics.faults.isEmpty ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.headline)
                    .foregroundStyle(diagnostics.faults.isEmpty ? OrgRecTheme.ai : OrgRecTheme.shu)
                Spacer()
                Text("\(diagnostics.bitDepth)-bit · \(diagnostics.container) · \(diagnostics.writerContract)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 22) {
                LabeledContent("Received", value: "\(diagnostics.receivedBuffers) buffers")
                LabeledContent("Written", value: "\(diagnostics.writtenFrames) frames")
                LabeledContent("Dropped", value: "\(diagnostics.droppedBuffers)")
                LabeledContent("Discontinuities", value: "\(diagnostics.discontinuityCount)")
                if let bytes = diagnostics.minimumAvailableDiskBytes {
                    LabeledContent("Minimum free", value: ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                }
            }
            .font(.caption)
            ForEach(diagnostics.channels) { channel in
                HStack {
                    Text("Ch. \(channel.channelIndex + 1)").frame(width: 45, alignment: .leading)
                    Text(channel.role).frame(maxWidth: .infinity, alignment: .leading)
                    if channel.isReferenceChannel { Text("REFERENCE").font(.caption2.bold()).foregroundStyle(OrgRecTheme.ai) }
                    Text("peak \(channel.peakDBFS.formatted(.number.precision(.fractionLength(1)))) dBFS")
                    Text("RMS \(channel.rmsDBFS.formatted(.number.precision(.fractionLength(1)))) dBFS")
                    Text("\(channel.clippedSamples) clipped")
                }
                .font(.caption.monospacedDigit())
            }
            ForEach(diagnostics.faults) { fault in
                Label(fault.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(OrgRecTheme.shu)
            }
        }
    }
}

private struct AudioInterfaceConfigurationView: View {
    @ObservedObject var audio: CoreAudioDeviceManager

    private var availableRates: [Double] {
        guard let device = audio.selectedDevice else { return [] }
        let standard = [44_100.0, 48_000, 88_200, 96_000, 176_400, 192_000]
        let supported = standard.filter { rate in device.availableSampleRates.isEmpty || device.availableSampleRates.contains(where: { $0.contains(rate) }) }
        return Array(Set(supported + [device.nominalSampleRate])).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Core Audio interface", systemImage: "waveform.and.mic").font(.headline)
                Spacer()
                Text(audio.status).font(.caption).foregroundStyle(.secondary)
                Button {
                    audio.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Input endpoint").font(.caption).foregroundStyle(.secondary)
                    Picker("Input endpoint", selection: Binding(
                        get: { audio.selectedUID },
                        set: { audio.select(uid: $0) }
                    )) {
                        ForEach(audio.devices) { device in
                            VStack(alignment: .leading) {
                                Text(device.name)
                                Text(device.detailLine)
                            }
                            .tag(device.uid)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    if let device = audio.selectedDevice {
                        Text([device.manufacturer, device.detailLine].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                        Text("UID: \(device.uid)").font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 7) {
                    Text("Nominal sample rate").font(.caption).foregroundStyle(.secondary)
                    Picker("Sample rate", selection: $audio.selectedSampleRate) {
                        ForEach(availableRates, id: \.self) { rate in
                            Text("\(Int(rate)) Hz").tag(rate)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 145)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Latency policy").font(.caption).foregroundStyle(.secondary)
                    Picker("Latency policy", selection: Binding(
                        get: { audio.latencyMode },
                        set: { audio.setLatencyMode($0) }
                    )) {
                        ForEach(LowLatencyMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("I/O buffer").font(.caption).foregroundStyle(.secondary)
                    if let device = audio.selectedDevice {
                        Stepper(
                            "\(audio.selectedBufferFrames) frames",
                            value: $audio.selectedBufferFrames,
                            in: device.bufferFrameRange,
                            step: 32
                        )
                        .onChange(of: audio.selectedBufferFrames) { _, _ in
                            if audio.latencyMode != .custom { audio.latencyMode = .custom }
                        }
                    }
                    Text("≈ \(audio.estimatedLatency.formatted(.number.precision(.fractionLength(2)))) ms input path")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .frame(width: 185)
            }

            if let device = audio.selectedDevice {
                HStack {
                    Label(
                        device.isAggregate ? "macOS Aggregate Device" : "AUHAL endpoint",
                        systemImage: device.isAggregate ? "square.stack.3d.up.fill" : "bolt.horizontal.circle.fill"
                    )
                    Text("·")
                    Text("\(device.inputChannels) input channels")
                    Text("·")
                    Text("device latency \(device.inputLatencyFrames) + safety \(device.inputSafetyOffsetFrames) frames")
                    if device.isRunning {
                        Text("IN USE").font(.caption.bold()).foregroundStyle(OrgRecTheme.shu)
                    }
                    Spacer()
                    Button("Audio MIDI Setup…") {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Audio MIDI Setup.app"))
                    }
                    Button("Apply to HAL") {
                        do { try audio.applyToHAL() }
                        catch { audio.status = error.localizedDescription }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .font(.caption)

                if device.transport == "Bluetooth" || device.transport == "Virtual" {
                    Label(
                        "This transport may resample, drift, or add variable latency. Use a class-compliant USB/Thunderbolt interface, AVB device, or clocked Aggregate Device for phase-coherent multichannel organ capture.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption).foregroundStyle(OrgRecTheme.shu)
                }
            } else {
                ContentUnavailableView("No input interfaces", systemImage: "mic.slash", description: Text("Connect or enable a Core Audio input device, then refresh."))
            }
        }
        .card()
    }
}

private struct FieldQAView: View {
    @EnvironmentObject private var model: AppModel
    @State private var draftSession: RecordingSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Field QA & paradata").font(.system(.title2, design: .serif, weight: .semibold))
                        Text("Resolve capture risks before recording and keep every scientific decision auditable.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Run full audit") { Task { await model.runConsistencyAudit() } }
                        .buttonStyle(.borderedProminent)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) {
                        ConsistencyScoreCard(report: model.auditReport)
                            .frame(width: 400)
                        FieldWorkflowGuide()
                            .frame(minWidth: 500)
                    }

                    VStack(spacing: 14) {
                        ConsistencyScoreCard(report: model.auditReport)
                        FieldWorkflowGuide()
                    }
                }

                CapturePreflightCard(model: model, capture: model.capture)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        captureReadinessCard
                            .frame(minWidth: 400, maxWidth: .infinity, alignment: .top)
                        sessionEditor
                            .frame(minWidth: 460, maxWidth: .infinity, alignment: .top)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        captureReadinessCard
                        sessionEditor
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Project consistency report", systemImage: "checklist.checked").font(.headline)
                        Spacer()
                        if let report = model.auditReport {
                            Text("\(report.checksPerformed) checks · \(report.generatedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let report = model.auditReport {
                        if report.issues.isEmpty {
                            ContentUnavailableView("No consistency issues", systemImage: "checkmark.seal.fill", description: Text("This project is ready for checked VAO exchange."))
                                .frame(maxWidth: .infinity, minHeight: 180)
                        } else {
                            ForEach(ConsistencySeverity.allCases, id: \.rawValue) { severity in
                                let issues = report.issues.filter { $0.severity == severity }
                                if issues.isEmpty == false {
                                    Text(severityTitle(severity, count: issues.count))
                                        .font(.caption.bold()).foregroundStyle(severityColor(severity))
                                    ForEach(issues) { issue in
                                        Button { model.openIssue(issue) } label: {
                                            ConsistencyIssueRow(issue: issue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    } else {
                        ProgressView("Auditing project package…").frame(maxWidth: .infinity, minHeight: 160)
                    }
                }
                .card()
            }
            .padding(24)
        }
        .task {
            draftSession = model.activeSession
            await model.runConsistencyAudit()
        }
        .onChange(of: model.activeSession?.id) { _, _ in draftSession = model.activeSession }
    }

    private var captureReadinessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current-capture readiness", systemImage: "record.circle").font(.headline)
            if model.captureReadiness.isEmpty {
                Label("All preflight checks passed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(OrgRecTheme.ai)
            } else {
                ForEach(model.captureReadiness) { issue in
                    ConsistencyIssueRow(issue: issue)
                }
            }
        }
        .card()
    }

    @ViewBuilder
    private var sessionEditor: some View {
        if let session = draftSession {
            SessionParadataEditor(session: Binding(
                get: { draftSession ?? session },
                set: { draftSession = $0 }
            )) {
                if let draftSession { Task { await model.saveSession(draftSession) } }
            } startNew: {
                Task {
                    await model.startNewSession()
                    draftSession = model.activeSession
                }
            }
        }
    }

    private func severityTitle(_ severity: ConsistencySeverity, count: Int) -> String {
        switch severity {
        case .blocker: "BLOCKERS · \(count)"
        case .warning: "WARNINGS · \(count)"
        case .information: "INFORMATION · \(count)"
        }
    }
}

private struct CapturePreflightCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var model: AppModel
    @ObservedObject var capture: AudioCaptureEngine

    private var report: CapturePreflightReport? { model.currentCapturePreflightReport }
    private var protocolSnapshot: CapturePreflightProtocolSnapshot {
        report?.protocolSnapshot ?? CapturePreflightProtocolSnapshot()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(OrgRecTheme.ai)
                    .frame(width: 34, height: 34)
                    .background(OrgRecTheme.ai.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Signal-path rehearsal").font(.headline)
                    Text("A retained line check for every assigned microphone—not a momentary level meter.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.capturePreflightContextLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(OrgRecTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 12)
                statusBadge
            }

            if model.isRunningCapturePreflight {
                runningProtocol
            } else {
                protocolGuide
                if let report {
                    reportSummary(report)
                } else if model.mostRecentCapturePreflightReport != nil {
                    Label("The most recent rehearsal belongs to another setup, revision, interface, or sample rate.", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(OrgRecTheme.shu)
                }
            }

            HStack {
                if model.isRunningCapturePreflight {
                    Button("Stop now & assess", role: .destructive) {
                        Task { await model.stopCapturePreflight() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(capture.isFinalizing || model.isWorking)
                    Text("OrgRec stops automatically at \(Int(protocolSnapshot.targetDurationSeconds)) seconds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button(report == nil ? "Run 12-second rehearsal" : "Repeat rehearsal") {
                        Task { await model.startCapturePreflight() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.canStartCapturePreflight == false)
                    Text("Retains the BWF, SHA-256, device state, thresholds, and analysis with this session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Signal-path rehearsal")
    }

    private var statusBadge: some View {
        let label: String
        let symbol: String
        let color: Color
        if model.isRunningCapturePreflight {
            label = "Listening"
            symbol = "record.circle.fill"
            color = OrgRecTheme.shu
        } else {
            switch report?.verdict {
            case .passed:
                label = "Verified"
                symbol = "checkmark.seal.fill"
                color = OrgRecTheme.ai
            case .attention:
                label = "Attention"
                symbol = "exclamationmark.triangle.fill"
                color = OrgRecTheme.shu
            case .failed:
                label = "Failed"
                symbol = "xmark.octagon.fill"
                color = OrgRecTheme.shu
            case nil:
                label = "Required"
                symbol = "circle.dashed"
                color = OrgRecTheme.secondaryText
            }
        }
        return Label(label, systemImage: symbol)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.11), in: Capsule())
    }

    private var protocolGuide: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                protocolStep("0–3 s", "Room quiet", "Organ silent; capture blower, HVAC, venue, and preamp floor.", symbol: "ear")
                protocolArrow
                protocolStep("3–5 s", "Prepare", "Move to the console without sounding; the gap protects both windows.", symbol: "figure.walk")
                protocolArrow
                protocolStep("5–12 s", "Planned maximum", "Hold the loudest registration or coupled chord expected in this session.", symbol: "music.note")
            }
            VStack(spacing: 8) {
                protocolStep("0–3 s", "Room quiet", "Organ silent; capture blower, HVAC, venue, and preamp floor.", symbol: "ear")
                protocolStep("3–5 s", "Prepare", "Move to the console without sounding; the gap protects both windows.", symbol: "figure.walk")
                protocolStep("5–12 s", "Planned maximum", "Hold the loudest registration or coupled chord expected in this session.", symbol: "music.note")
            }
        }
    }

    private func protocolStep(_ time: String, _ title: String, _ detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(OrgRecTheme.ai)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(time).font(.caption.monospaced().bold())
                    Text(title).font(.caption.bold())
                }
                Text(detail).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OrgRecTheme.recessed.opacity(0.72), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var protocolArrow: some View {
        Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(OrgRecTheme.tertiaryText)
    }

    private var runningProtocol: some View {
        let elapsed = capture.elapsed
        let progress = min(protocolSnapshot.targetDurationSeconds, max(0, elapsed))
        let stage: (title: String, detail: String, symbol: String, color: Color)
        if capture.isFinalizing || (model.isWorking && capture.isRecording == false) {
            stage = ("Finalizing and analyzing", "Draining the writer, embedding BWF metadata, fixing the checksum, and assessing every assigned channel.", "hourglass", OrgRecTheme.ai)
        } else if elapsed < 3 {
            stage = ("Keep the organ and room quiet", "Measuring the acoustic and electronic floor on every assigned channel.", "ear.fill", OrgRecTheme.ai)
        } else if elapsed < 5 {
            stage = ("Prepare the loudest planned registration", "The protected transition gap prevents movement from contaminating either window.", "figure.walk", OrgRecTheme.ai)
        } else {
            stage = ("Sound and hold now", "Use the loudest registration or coupled chord planned for this session.", "music.note", OrgRecTheme.shu)
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: stage.symbol)
                    .font(.title2)
                    .foregroundStyle(stage.color)
                    .symbolEffect(.pulse, options: .repeating, isActive: reduceMotion == false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.title).font(.title3.bold())
                    Text(stage.detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(elapsed, format: .number.precision(.fractionLength(1))) s")
                    .font(.title3.monospacedDigit().bold())
            }
            ProgressView(value: progress, total: protocolSnapshot.targetDurationSeconds)
                .tint(stage.color)
                .accessibilityValue("\(Int(progress)) of \(Int(protocolSnapshot.targetDurationSeconds)) seconds")
            if capture.channelPeakDBFS.isEmpty == false {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 12)], alignment: .leading, spacing: 6) {
                    ForEach(Array(capture.channelPeakDBFS.enumerated()), id: \.offset) { index, peak in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CH \(index + 1)").font(.caption2.bold()).foregroundStyle(.secondary)
                            Text("\(Double(peak), format: .number.precision(.fractionLength(1))) dBFS")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(peak > -3 ? OrgRecTheme.shu : OrgRecTheme.sumi)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(stage.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    @ViewBuilder
    private func reportSummary(_ report: CapturePreflightReport) -> some View {
        Divider()
        HStack {
            Text("Assigned-channel evidence").font(.subheadline.bold())
            Spacer()
            Text("\(report.recordedAt.formatted(date: .abbreviated, time: .shortened)) · \(report.sha256.prefix(12))…")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .help(report.sha256)
        }
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 7) {
            GridRow {
                tableHeader("Channel")
                tableHeader("Role")
                tableHeader("Quiet RMS")
                tableHeader("Signal RMS")
                tableHeader("SNR")
                tableHeader("Peak")
                tableHeader("Headroom")
                tableHeader("Result")
            }
            Divider().gridCellColumns(8)
            ForEach(report.channels.filter(\.isRequired)) { channel in
                GridRow {
                    Text("\(channel.channelNumber)").font(.caption.monospacedDigit().bold())
                    Text(channel.role).font(.caption).lineLimit(1)
                    metric(channel.quietRMSDBFS, suffix: " dBFS")
                    metric(channel.signalRMSDBFS, suffix: " dBFS")
                    metric(channel.signalToNoiseDB, suffix: " dB")
                    metric(channel.peakDBFS, suffix: " dBFS")
                    metric(channel.headroomDB, suffix: " dB")
                    channelStatus(channel.channelNumber, report: report)
                }
            }
        }
        .accessibilityElement(children: .contain)

        if report.findings.isEmpty {
            Label("Every assigned channel passed continuity, level, noise, DC, and independent-routing checks.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(OrgRecTheme.ai)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(report.findings.prefix(6)) { finding in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: finding.severity == .blocker ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(OrgRecTheme.shu)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(finding.title).font(.caption.bold())
                            Text(finding.detail).font(.caption2).foregroundStyle(.secondary)
                            Text(finding.remediation).font(.caption2).foregroundStyle(OrgRecTheme.ai)
                        }
                    }
                }
                if report.findings.count > 6 {
                    Text("+ \(report.findings.count - 6) additional finding(s) retained in the report")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func tableHeader(_ text: String) -> some View {
        Text(text).font(.caption2.bold()).foregroundStyle(.secondary)
    }

    private func metric(_ value: Double, suffix: String) -> some View {
        Text(value.formatted(.number.precision(.fractionLength(1))) + suffix)
            .font(.caption.monospacedDigit())
    }

    private func channelStatus(_ number: Int, report: CapturePreflightReport) -> some View {
        let findings = report.findings.filter { $0.channelNumbers.contains(number) }
        let hasBlocker = findings.contains { $0.severity == .blocker }
        let hasWarning = findings.contains { $0.severity == .warning }
        let symbol = hasBlocker ? "xmark.circle.fill" : (hasWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        let label = hasBlocker ? "Fail" : (hasWarning ? "Check" : "Pass")
        let color = (hasBlocker || hasWarning) ? OrgRecTheme.shu : OrgRecTheme.ai
        return Label(label, systemImage: symbol).font(.caption.bold()).foregroundStyle(color)
    }
}

private struct ConsistencyScoreCard: View {
    let report: ProjectConsistencyReport?

    var body: some View {
        HStack(spacing: 16) {
            Gauge(value: Double(report?.score ?? 0), in: 0...100) {
                Text("QA")
            } currentValueLabel: {
                Text("\(report?.score ?? 0)").font(.title3.bold())
            }
            .gaugeStyle(.accessoryCircular)
            .tint((report?.blockerCount ?? 1) == 0 ? OrgRecTheme.ai : OrgRecTheme.shu)
            .scaleEffect(1.25)
            .frame(width: 75, height: 75)
            VStack(alignment: .leading, spacing: 6) {
                Text((report?.isExportReady ?? false) ? "VAO exchange ready" : "Consistency work required")
                    .font(.headline)
                HStack(spacing: 12) {
                    Label("\(report?.blockerCount ?? 0) blockers", systemImage: "xmark.octagon.fill").foregroundStyle(OrgRecTheme.shu)
                    Label("\(report?.warningCount ?? 0) warnings", systemImage: "exclamationmark.triangle.fill").foregroundStyle(OrgRecTheme.shu)
                }
                .font(.caption)
                Text("The report checks frozen MODAVIS bindings, roadmap links, BWF integrity, provenance, analysis markers, and review history.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .card()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FieldWorkflowGuide: View {
    private let steps = [
        ("1", "Organ", "Frozen MODAVIS specification"),
        ("2", "Session", "Operator & environment"),
        ("3", "Setup", "Geometry & routing"),
        ("4", "Capture", "Protocol & live signal"),
        ("5", "Review", "Transients, pitch & decision"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(steps, id: \.0) { number, title, detail in
                VStack(spacing: 5) {
                    Text(number).font(.caption.bold()).frame(width: 25, height: 25)
                        .background(OrgRecTheme.shu.opacity(0.14), in: Circle()).foregroundStyle(OrgRecTheme.shu)
                    Text(title).font(.caption.bold())
                    Text(detail).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                if number != "5" { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
            }
        }
        .card()
        .frame(maxWidth: .infinity)
    }
}

private struct SessionParadataEditor: View {
    @Binding var session: RecordingSession
    let save: () -> Void
    let startNew: () -> Void
    @State private var showNoiseMap = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("Active recording session", systemImage: "person.text.rectangle").font(.headline)
                Spacer()
                Text(session.sessionCode).font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow { Text("Operator"); TextField("Required", text: $session.operatorName) }
                GridRow { Text("Institution"); TextField("Optional", text: $session.institution) }
                GridRow { Text("Purpose"); TextField("Scientific purpose", text: $session.purpose) }
                GridRow { Text("Rights"); TextField("Rights or consent statement", text: $session.rightsStatement) }
                GridRow { Text("Timezone"); TextField("IANA timezone", text: $session.timezoneIdentifier) }
                GridRow { Text("Clock"); TextField("Clock source", text: $session.clockSource) }
                GridRow { Text("Condition"); TextField("Audience, HVAC, traffic…", text: $session.venueCondition) }
                GridRow {
                    Text("Environment")
                    HStack {
                        TextField("°C", value: $session.environment.temperatureCelsius, format: .number).frame(width: 70)
                        Text("°C")
                        TextField("RH", value: $session.environment.relativeHumidityPercent, format: .number).frame(width: 70)
                        Text("% RH")
                        TextField("hPa", value: $session.environment.pressureHPa, format: .number).frame(width: 75)
                        Text("hPa")
                    }
                }
            }
            .font(.caption)
            .textFieldStyle(.roundedBorder)
            TextField("Session notes", text: $session.notes, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(2...4)
            if let assessment = session.noiseContextAssessment {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Label("Frozen surrounding-noise assessment", systemImage: "map.fill")
                            .font(.callout.bold())
                        Spacer()
                        Text("rev. \(assessment.revision)").font(.caption.monospaced()).foregroundStyle(.secondary)
                        Button("View map") { showNoiseMap = true }
                    }
                    Text(assessment.summary).font(.caption).foregroundStyle(.secondary)
                    Text("Retrieved \(assessment.retrievedAt.formatted(date: .abbreviated, time: .shortened)) · \(assessment.sourceAttribution)")
                        .font(.caption2).foregroundStyle(.secondary)
                    if let observations = session.noiseObservations, observations.isEmpty == false {
                        Divider()
                        Text("Observed during this session").font(.caption.bold())
                        ForEach(observations.suffix(6)) { observation in
                            HStack {
                                Text(observation.observedAt, style: .time).font(.caption.monospacedDigit())
                                Text(observation.label).font(.caption)
                                Spacer()
                                if let seconds = observation.atSeconds {
                                    Text("take +\(seconds.formatted(.number.precision(.fractionLength(1)))) s")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(OrgRecTheme.ai.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                .sheet(isPresented: $showNoiseMap) {
                    NoiseContextMapSheet(assessment: assessment)
                }
            }
            HStack {
                Button("Start new session", action: startNew)
                Spacer()
                Button("Save paradata", action: save).buttonStyle(.borderedProminent)
            }
        }
        .card()
    }
}

private struct ConsistencyIssueRow: View {
    let issue: ConsistencyIssue

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: issue.severity == .blocker ? "xmark.octagon.fill" : issue.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(severityColor(issue.severity)).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(issue.title).font(.callout.bold())
                    Text(issue.scope.rawValue.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
                }
                Text(issue.detail).font(.caption).foregroundStyle(.secondary)
                Text(issue.remediation).font(.caption).foregroundStyle(severityColor(issue.severity))
            }
            Spacer()
            if issue.roadmapItemID != nil || issue.takeID != nil { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
        }
        .padding(9)
        .background(severityColor(issue.severity).opacity(0.055), in: RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
    }
}

private func severityColor(_ severity: ConsistencySeverity) -> Color {
    OrgRecTheme.status(severity)
}

private struct SetupView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingSetup: MicrophoneSetup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Capture setup & paradata").font(.system(.title2, design: .serif, weight: .semibold))
                    Text("Versioned equipment, geometry, environment, and documentation travel with every take.")
                        .foregroundStyle(.secondary)
                }

                AudioInterfaceConfigurationView(audio: model.audioSystem)

                SpectrogramControls()
                    .card()

                if let project = model.project {
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Peripheral devices", systemImage: "cable.connector").font(.headline)
                            ForEach(project.devices) { device in
                                HStack {
                                    Image(systemName: device.kind == .microphone ? "mic.fill" : "hifispeaker.2.fill")
                                        .frame(width: 24).foregroundStyle(OrgRecTheme.shu)
                                    VStack(alignment: .leading) {
                                        Text(device.displayName).fontWeight(.medium)
                                        Text(device.serialNumber.isEmpty ? device.kind.rawValue : device.serialNumber)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if device.modavisManifestationID != nil {
                                        Image(systemName: "link.circle.fill").foregroundStyle(OrgRecTheme.ai)
                                    }
                                }
                                Divider()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .card()

                        VStack(alignment: .leading, spacing: 12) {
                            Label("Environment", systemImage: "thermometer.medium").font(.headline)
                            let environment = project.setups.first?.environment
                            LabeledContent("Temperature", value: environment?.temperatureCelsius.map { "\($0.formatted()) °C" } ?? "—")
                            LabeledContent("Humidity", value: environment?.relativeHumidityPercent.map { "\($0.formatted()) %" } ?? "—")
                            LabeledContent("Pressure", value: environment?.pressureHPa.map { "\($0.formatted()) hPa" } ?? "—")
                            Text("Readings are frozen into the setup revision referenced by each roadmap item.")
                                .font(.caption).foregroundStyle(.secondary)
                            if let setup = project.setups.first {
                                Button("Create revised setup…") { editingSetup = setup }
                            }
                        }
                        .frame(width: 320)
                        .card()
                    }

                    ForEach(project.setups) { setup in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(setup.name).font(.headline)
                                    Text("Revision \(setup.revision) · \(setup.arrayGeometry)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(setup.coordinateOrigin).font(.caption).foregroundStyle(.secondary)
                                Button("Revise…") { editingSetup = setup }
                                    .controlSize(.small)
                            }
                            Divider()
                            HStack {
                                Text("Ch.").frame(width: 36, alignment: .leading)
                                Text("Role").frame(maxWidth: .infinity, alignment: .leading)
                                Text("X / Y / Z (m)").frame(width: 180, alignment: .leading)
                                Text("Yaw / pitch").frame(width: 130, alignment: .leading)
                                Text("Gain").frame(width: 75, alignment: .leading)
                                Text("48 V").frame(width: 50, alignment: .leading)
                            }
                            .font(.caption.bold()).foregroundStyle(.secondary)
                            ForEach(setup.placements) { placement in
                                HStack {
                                    Text("\(placement.channelNumber)").frame(width: 36, alignment: .leading)
                                    Text(placement.role).frame(maxWidth: .infinity, alignment: .leading)
                                    Text("\(placement.xMeters, specifier: "%.2f") / \(placement.yMeters, specifier: "%.2f") / \(placement.zMeters, specifier: "%.2f")")
                                        .font(.system(.body, design: .monospaced)).frame(width: 180, alignment: .leading)
                                    Text("\(placement.yawDegrees, specifier: "%.0f")° / \(placement.pitchDegrees, specifier: "%.0f")°")
                                        .frame(width: 130, alignment: .leading)
                                    Text("\(placement.gainDB, specifier: "%.1f") dB").frame(width: 75, alignment: .leading)
                                    Image(systemName: placement.phantomPower ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(placement.phantomPower ? OrgRecTheme.ai : OrgRecTheme.secondaryText)
                                        .frame(width: 50, alignment: .leading)
                                }
                            }
                        }
                        .card()
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $editingSetup) { setup in
            SetupEditorSheet(
                setup: setup,
                microphones: model.project?.devices.filter { $0.kind == .microphone } ?? []
            ) { revised in
                Task {
                    await model.updateProject { project in
                        var newRevision = revised
                        newRevision.id = UUID()
                        newRevision.revision = setup.revision + 1
                        project.setups.append(newRevision)
                        for index in project.roadmap.indices
                        where project.roadmap[index].setupID == setup.id
                            && project.roadmap[index].takeIDs.isEmpty {
                            project.roadmap[index].setupID = newRevision.id
                        }
                    }
                    model.notice = "Setup revision \(setup.revision + 1) created; existing takes remain bound to their original revision."
                }
            }
        }
    }
}

private struct SetupEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MicrophoneSetup
    let microphones: [DeviceInstance]
    let onSave: (MicrophoneSetup) -> Void

    init(
        setup: MicrophoneSetup,
        microphones: [DeviceInstance],
        onSave: @escaping (MicrophoneSetup) -> Void
    ) {
        _draft = State(initialValue: setup)
        self.microphones = microphones
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Revise microphone setup").font(.system(.title2, design: .serif, weight: .semibold))
                    Text("Saving creates revision \(draft.revision + 1); recorded takes retain the old revision.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save revision") {
                    onSave(draft)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            Divider()

            Form {
                Section("Identity and routing") {
                    TextField("Setup name", text: $draft.name)
                    TextField("Array geometry", text: $draft.arrayGeometry)
                    TextField("Coordinate origin", text: $draft.coordinateOrigin)
                    Picker("Analysis reference channel", selection: Binding(
                        get: { draft.referenceChannelNumber ?? 1 },
                        set: { draft.referenceChannelNumber = $0 }
                    )) {
                        ForEach(1...max(1, draft.placements.map(\.channelNumber).max() ?? 1), id: \.self) {
                            Text("Channel \($0)").tag($0)
                        }
                    }
                }

                Section("Environment") {
                    HStack {
                        TextField("Temperature °C", value: optional(\.temperatureCelsius), format: .number)
                        TextField("Humidity %", value: optional(\.relativeHumidityPercent), format: .number)
                        TextField("Pressure hPa", value: optional(\.pressureHPa), format: .number)
                    }
                    TextField("Environmental notes", text: $draft.environment.notes, axis: .vertical)
                }

                Section("Microphone placements") {
                    ForEach($draft.placements) { $placement in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Picker("Microphone", selection: $placement.microphoneID) {
                                    ForEach(microphones) { microphone in
                                        Text(microphone.displayName).tag(microphone.id)
                                    }
                                }
                                TextField("Role", text: $placement.role)
                                Stepper("Channel \(placement.channelNumber)", value: $placement.channelNumber, in: 1...64)
                                Button(role: .destructive) {
                                    draft.placements.removeAll { $0.id == placement.id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                            Grid {
                                GridRow {
                                    TextField("X m", value: $placement.xMeters, format: .number)
                                    TextField("Y m", value: $placement.yMeters, format: .number)
                                    TextField("Z m", value: $placement.zMeters, format: .number)
                                    TextField("Yaw °", value: $placement.yawDegrees, format: .number)
                                }
                                GridRow {
                                    TextField("Pitch °", value: $placement.pitchDegrees, format: .number)
                                    TextField("Roll °", value: $placement.rollDegrees, format: .number)
                                    TextField("Gain dB", value: $placement.gainDB, format: .number)
                                    Toggle("48 V", isOn: $placement.phantomPower)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                        }
                        .padding(.vertical, 5)
                    }
                    Button("Add microphone placement") {
                        guard let microphone = microphones.first else { return }
                        draft.placements.append(MicrophonePlacement(
                            microphoneID: microphone.id,
                            channelNumber: (draft.placements.map(\.channelNumber).max() ?? 0) + 1,
                            role: "New channel",
                            xMeters: 0,
                            yMeters: 0,
                            zMeters: 0
                        ))
                    }
                    .disabled(microphones.isEmpty)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 850, minHeight: 720)
    }

    private func optional(_ keyPath: WritableKeyPath<EnvironmentReading, Double?>) -> Binding<Double> {
        Binding(
            get: { draft.environment[keyPath: keyPath] ?? 0 },
            set: { draft.environment[keyPath: keyPath] = $0 }
        )
    }
}

private struct SyncView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Navigator & release binding").font(.system(.title2, design: .serif, weight: .semibold))
                    Text("Navigator is the synchronization boundary; OrgRec never writes directly to MODAVIS.")
                        .foregroundStyle(.secondary)
                }

                if let release = model.project?.snapshot.release {
                    HStack(spacing: 22) {
                        ReleaseField(title: "Requested", value: release.requestedRelease)
                        ReleaseField(title: "Terminal state", value: release.releaseState)
                        ReleaseField(title: "Canonical source", value: release.canonicalSourceRelease)
                        ReleaseField(title: "Contract", value: release.navigatorContractVersion)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Protected database fingerprint", systemImage: "lock.shield.fill").font(.headline)
                        Text(release.protectedFingerprintSHA256)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        Text("Every component locator and export also carries the retrieved Navigator payload checksum.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .card()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Organ source", systemImage: "network").font(.headline)
                    Text("Organ search and roadmap creation now live in the project library. This screen documents the active project's immutable Navigator binding and handles capture export.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("Navigator base URL")
                        TextField("Base URL", text: $model.navigatorURL)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 380)
                        Spacer()
                        Button("Find another pipe organ…") { model.page = .organSearch }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Label("Export Virtual Acoustic Object", systemImage: "shippingbox.fill").font(.headline)
                    Text("Build a self-contained VAO 0.5.0 preservation closure with exact project media, MODAVIS binding, explicit rights status, and SHA-256 fixity.")
                        .foregroundStyle(.secondary)
                    Button("Export VAO…") {
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = safeFilename(model.project?.title ?? "OrgRec-Capture") + ".vao"
                        panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let url = panel.url {
                            Task { await model.exportVAO(to: url) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Label("Secondary Navigator projection", systemImage: "arrow.triangle.branch").font(.headline)
                    Text("Export the existing IAD / Navigator package when a MODAVIS database projection is needed. This is a candidate-admission handoff, not the primary exchange object.")
                        .foregroundStyle(.secondary)
                    Button("Export IAD / Navigator package…") {
                        let panel = NSSavePanel()
                        panel.nameFieldStringValue = safeFilename(model.project?.title ?? "OrgRec-Capture") + ".orgrec-capture"
                        panel.canCreateDirectories = true
                        if panel.runModal() == .OK, let url = panel.url {
                            Task { await model.exportCapturePackage(to: url) }
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .card()
            }
            .padding(24)
        }
    }
}

private struct ReleaseField: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.bold()).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Form {
            Section("Navigator") {
                TextField("Base URL", text: $model.navigatorURL)
                Text("The MVP keeps credentials out of project packages. Authentication will use the macOS Keychain when Navigator exposes its submission API.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Analysis") {
                LabeledContent("Pitch engine", value: "CREPE + probabilistic YIN · autocorrelation adjudicator")
                LabeledContent("Transient engine", value: "Adaptive multifeature detector v2 + reviewed boundaries")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private extension View {
    func card() -> some View {
        orgRecCard()
    }
}
