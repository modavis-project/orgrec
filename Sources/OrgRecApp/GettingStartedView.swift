import SwiftUI
import OrgRecCore

struct GettingStartedView: View {
    @EnvironmentObject private var model: AppModel

    private var hasOwnProject: Bool {
        guard let project = model.project else { return false }
        return project.organMDVSID != "MDVS:ORGN:DEMO"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Get started with OrgRec")
                    .font(.system(.largeTitle, design: .serif, weight: .semibold))
                Text("Choose an organ, prepare a recording plan, and check your equipment before capturing sound. Return to this guide from the sidebar at any time.")
                    .foregroundStyle(.secondary)

                GroupBox("Analyze an existing recording") {
                    HStack {
                        Text("Drop a file into Analyze Audio to inspect sound and export results. No project, catalogue or microphone access is needed.")
                        Spacer()
                        Button("Analyze Audio") { model.page = .audioAnalysis }
                            .buttonStyle(.borderedProminent)
                    }.padding(8)
                }
                if model.project?.organMDVSID == "MDVS:ORGN:DEMO" {
                    Label("The open St. Nikolai project is a demonstration. Create or import your own project for research recordings.", systemImage: "info.circle")
                }
                if model.isWorking {
                    ProgressView("Preparing OrgRec or completing the current operation…")
                }

                GroupBox("1 · Choose your starting point") {
                    VStack(alignment: .leading, spacing: 12) {
                        Button("Find a pipe organ") { model.page = .organSearch }
                            .buttonStyle(.borderedProminent)
                        if let inspection = model.cachedPODInspection {
                            Label("Offline POD \(inspection.releaseVersion ?? "") is installed and verified.", systemImage: "internaldrive")
                        } else {
                            Text("Search MODAVIS Navigator online by organ, venue or builder. You can create a recording plan from a catalogue entry.")
                            Button("Install the optional offline catalogue…") { model.page = .podDatabase }
                        }
                        HStack {
                            Button("Create a local project…") { model.requestNewProject() }
                            Button("Open or import…") { model.page = .projects }
                            Button("Explore demonstration / current project") {
                                Task { await model.bootstrap(); model.page = .roadmap }
                            }
                        }
                    }
                    .padding(8)
                }

                GroupBox("2 · Create and review your recording plan") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("In Find Organ, search by organ, venue or builder, then choose a matching entry to create a project. Review its ranks, keys and microphone setups in Initialize and Roadmap. Historical catalogue entries must be checked against the instrument you will record.")
                        if hasOwnProject {
                            Label("Your project is open. Review its configuration before recording.", systemImage: "folder.fill")
                            Button("Review project initialization") { model.page = .initialize }
                        } else {
                            Text("Your own project has not been opened yet.").foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                }

                GroupBox("3 · Prepare the audio input and make a test recording") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Connect your audio interface. In Setup, choose the input device and check channel assignments and microphone geometry. Allow microphone access when macOS asks; if denied, enable OrgRec under System Settings → Privacy & Security → Microphone.")
                        Text("Use Field QA to check the signal path and recording readiness. Confirm that the intended channels receive sound without clipping. Select a Roadmap target, record a short test, then listen back and review the analysis before starting the session.")
                        HStack {
                            Button("Open Setup") { model.page = .setup }
                            Button("Open Field QA") { model.page = .fieldQA }
                        }
                        .disabled(!hasOwnProject)
                        Text("Existing audio can be imported through Data Exchange without microphone access. Review detected boundaries and source information before exporting the project.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .padding(8)
                }
            }
            .disabled(model.isWorking)
            .padding(28)
            .frame(maxWidth: 950, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
