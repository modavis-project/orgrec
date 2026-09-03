import AppKit
import OrgRecCore
import SwiftUI

@MainActor
final class OrgRecApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?
    private var terminationReplyPending = false
    private var sleepObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let model = self.model, model.hasActiveCapture else { return }
                _ = await model.finalizeActiveCaptureForLifecycle(reason: "system sleep")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model,
              model.hasActiveCapture || model.persistenceState.requiresResolution || model.isWorking else {
            return .terminateNow
        }
        guard terminationReplyPending == false else { return .terminateLater }

        let alert = NSAlert()
        if model.hasActiveCapture {
            alert.messageText = "A recording is still active"
            alert.informativeText = model.isRunningCapturePreflight
                ? "OrgRec must stop the audio engine, drain its writer queue, finalize the Broadcast Wave file, analyze every assigned channel, and save the signal-path report before the app can close."
                : "OrgRec must stop the audio engine, drain its writer queue, finalize Broadcast Wave metadata, and save the take before the app can close."
            alert.addButton(withTitle: "Stop, Finalize & Quit")
            alert.addButton(withTitle: "Return to Recording")
        } else if model.persistenceState.isSaving {
            alert.messageText = "A project save is still finishing"
            alert.informativeText = "OrgRec will wait for the atomic save to finish before quitting. If it does not settle safely, the app will remain open."
            alert.addButton(withTitle: "Wait for Save & Quit")
            alert.addButton(withTitle: "Cancel")
        } else if model.persistenceState.isDirty {
            alert.messageText = "Project changes are not saved"
            alert.informativeText = "OrgRec will retry the atomic project save before quitting. If it still fails, the app will remain open so the changes are not silently discarded."
            alert.addButton(withTitle: "Retry Save & Quit")
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.messageText = "A project operation is still finishing"
            alert.informativeText = "OrgRec will wait for the current import, export, or analysis transaction to reach a safe boundary before quitting."
            alert.addButton(withTitle: "Wait & Quit")
            alert.addButton(withTitle: "Cancel")
        }
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }

        terminationReplyPending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let safeToQuit = await model.finalizeActiveCaptureForLifecycle(reason: "quitting")
            self.terminationReplyPending = false
            sender.reply(toApplicationShouldTerminate: safeToQuit)
        }
        return .terminateLater
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

@main
struct OrgRecApplication: App {
    @NSApplicationDelegateAdaptor(OrgRecApplicationDelegate.self) private var applicationDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("OrgRec", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1_080, minHeight: 700)
                .task { await model.bootstrap() }
                .onAppear { applicationDelegate.model = model }
        }
        .defaultSize(width: 1_380, height: 860)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Local Project…") { model.requestNewProject() }
                    .keyboardShortcut("n", modifiers: [.command])
                Button("Open or Import…") { presentImportPanel() }
                    .keyboardShortcut("o", modifiers: [.command])
                Divider()
                Button("Show Active Project in Finder") {
                    if let url = model.projectURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                }
                .disabled(model.projectURL == nil)
            }

            CommandMenu("Project") {
                Button("Project Library") { model.page = .projects }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Find Pipe Organ…") { model.page = .organSearch }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                Divider()
                Button("Roadmap") { model.page = .roadmap }
                    .keyboardShortcut("2", modifiers: [.command])
                    .disabled(model.project == nil)
                Button("Record") { model.page = .record }
                    .keyboardShortcut("3", modifiers: [.command])
                    .disabled(model.project == nil)
                Button("Analysis") { model.page = .analysis }
                    .keyboardShortcut("4", modifiers: [.command])
                    .disabled(model.project == nil)
                Button("Field QA") { model.page = .fieldQA }
                    .keyboardShortcut("5", modifiers: [.command])
                    .disabled(model.project == nil)
                Button("Setup") { model.page = .setup }
                    .keyboardShortcut("6", modifiers: [.command])
                    .disabled(model.project == nil)
                Divider()
                Button("Save Project Now") { Task { await model.retryPersistence() } }
                    .keyboardShortcut("s", modifiers: [.command])
                    .disabled(model.persistenceState.isDirty == false)
                Divider()
                Button("Export VAO…") { presentVAOExportPanel() }
                    .disabled(model.project == nil || model.isWorking || model.hasActiveCapture)
                Button("Export IAD / Navigator Package…") { presentIADExportPanel() }
                    .disabled(model.project == nil || model.isWorking || model.hasActiveCapture)
            }

            CommandMenu("Capture") {
                Button(captureCommandTitle) {
                    Task { await performCaptureCommand() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(captureCommandDisabled)
                Divider()
                Button("Mark Key-down") {
                    Task { await model.markLiveEvent(code: "operator_key_down", text: "Operator key-down") }
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .disabled(model.capture.isRecording == false || model.isLongTakeRecording || model.isCalibrating || model.isRunningCapturePreflight)
                Button("Mark Key-up") {
                    Task { await model.markLiveEvent(code: "operator_key_up", text: "Operator key-up") }
                }
                .keyboardShortcut("k", modifiers: [.command, .option])
                .disabled(model.capture.isRecording == false || model.isLongTakeRecording || model.isCalibrating || model.isRunningCapturePreflight)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(minWidth: 560, minHeight: 360)
        }
        .defaultSize(width: 620, height: 440)
    }

    private var captureCommandTitle: String {
        if model.isRunningCapturePreflight { return "Stop Signal-Path Rehearsal" }
        if model.isCalibrating { return "Stop A4 Calibration" }
        if model.isLongTakeRecording { return "Stop Long Take" }
        return model.capture.isRecording ? "Stop Recording" : "Start Recording"
    }

    private var captureCommandDisabled: Bool {
        if model.capture.isRecording { return false }
        return model.selectedRoadmapItem == nil || model.captureIsReady == false || model.isWorking
    }

    private func performCaptureCommand() async {
        if model.isRunningCapturePreflight {
            await model.stopCapturePreflight()
        } else if model.isCalibrating {
            await model.stopPitchCalibration()
        } else if model.isLongTakeRecording {
            await model.stopLongTakeRecording()
        } else if model.capture.isRecording {
            await model.stopRecording()
        } else {
            await model.startRecording()
        }
    }

    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open or Import"
        panel.message = "Choose an OrgRec project, Virtual Acoustic Object, or Instrumental Audio Dataset package."
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.importProject(from: url) }
    }

    private func presentVAOExportPanel() {
        guard let title = model.project?.title else { return }
        let panel = NSSavePanel()
        panel.title = "Export Virtual Acoustic Object"
        panel.nameFieldStringValue = safeFilename(title) + ".vao"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.exportVAO(to: url) }
    }

    private func presentIADExportPanel() {
        guard let title = model.project?.title else { return }
        let panel = NSSavePanel()
        panel.title = "Export Instrumental Audio Dataset Package"
        panel.nameFieldStringValue = safeFilename(title) + ".orgrec-capture"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.exportCapturePackage(to: url) }
    }
}
