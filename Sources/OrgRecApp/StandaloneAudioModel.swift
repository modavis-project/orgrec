import AppKit
import Combine
import Foundation
import OrgRecCore
import UniformTypeIdentifiers

@MainActor
final class StandaloneAudioModel: ObservableObject {
    @Published private(set) var sourceURL: URL?
    @Published private(set) var source: StandaloneAudioSource?
    @Published private(set) var document: StandaloneAnalysisDocument?
    @Published private(set) var isWorking = false
    @Published private(set) var status = "Drop one audio file to begin."
    @Published var error: String?
    @Published var request = StandaloneAnalysisRequest()
    @Published var expectedFrequencyText = ""
    @Published private(set) var valueRows: [AnalysisValueRow] = []
    let playback = AudioPlaybackController()
    let interaction = AnalysisInteractionState()
    private(set) var workspace: URL?
    private var operation: Task<StandaloneAnalysisDocument, Error>?

    var canCancel: Bool { operation != nil }

    var hasChangedSettings: Bool {
        guard let document else { return false }
        return request != document.request || expectedFrequencyText != (document.request.expectedFrequencyHz.map { String($0) } ?? "")
    }

    func chooseFile() {
        guard !isWorking else { return }
        let panel = NSOpenPanel()
        panel.title = "Analyze an audio file"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { Task { await load(url) } }
    }

    func accept(_ urls: [URL]) -> Bool {
        guard !isWorking else { return false }
        guard urls.count == 1, let url = urls.first, url.isFileURL else {
            error = "Drop one local audio file at a time."
            return false
        }
        Task { await load(url) }
        return true
    }

    func load(_ url: URL) async {
        guard !isWorking else { return }
        isWorking = true
        status = "Reading audio format…"
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let info = try await Task.detached(priority: .userInitiated) { try StandaloneAudioSource.inspect(url) }.value
            clearResult()
            sourceURL = url
            source = info
            request = .init(durationSeconds: min(120, info.duration, info.maximumExcerptDuration))
            expectedFrequencyText = ""
            error = nil
            isWorking = false
            if info.duration <= request.durationSeconds + 0.000_001 {
                await analyze()
            } else {
                status = "Choose an excerpt and select Analyze. The entire file will not be analyzed automatically."
            }
        } catch {
            isWorking = false
            self.error = "Cannot open this audio file: \(error.localizedDescription)"
            status = document == nil ? "Choose a supported audio file and try again." : "The previous result is still available."
        }
    }

    func analyze() async {
        guard !isWorking, let url = sourceURL, let source else { return }
        do {
            let input = expectedFrequencyText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !input.isEmpty && (request.applicability == .monophonic || request.applicability == .indeterminate) {
                guard let value = Double(input), value.isFinite else {
                    throw OrgRecError.unsupportedAudio("Enter a reference frequency in Hz, or leave it blank.")
                }
                request.expectedFrequencyHz = value
            } else { request.expectedFrequencyHz = nil }
            _ = try request.frameRange(in: source)
        } catch { self.error = error.localizedDescription; return }
        isWorking = true
        error = nil
        playback.stop()
        status = "Preparing excerpt, computing measurements and verifying the source…"
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
            isWorking = false
            operation = nil
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-audio-\(UUID().uuidString)", isDirectory: true)
        let submitted = request
        let task = Task { try await StandaloneAudioAnalyzer().analyze(sourceURL: url, request: submitted, workspace: directory) }
        operation = task
        do {
            let result = try await task.value
            try Task.checkCancellation()
            guard !task.isCancelled else { throw CancellationError() }
            clearResult()
            workspace = directory
            document = result
            request = result.request
            expectedFrequencyText = result.request.expectedFrequencyHz.map { String($0) } ?? ""
            valueRows = try StandaloneAnalysisDataExport.rows(result.analysis)
            interaction.configure(duration: result.duration)
            interaction.showAnnotations = false
            interaction.showLoopRegions = false
            do { try playback.load(directory.appendingPathComponent("excerpt.wav")) }
            catch { self.error = "Analysis succeeded, but playback could not load: \(error.localizedDescription)" }
            status = "Analysis complete. Results describe the selected excerpt; review the evidence before using it."
        } catch {
            try? FileManager.default.removeItem(at: directory)
            if error is CancellationError { status = "Analysis cancelled. Previous results, if any, are unchanged." }
            else { self.error = error.localizedDescription; status = "Analysis failed. Review the file and settings, then retry." }
        }
    }

    func cancel() {
        operation?.cancel()
        status = "Cancelling at the next safe analysis boundary…"
    }

    func clearResult() {
        playback.stop()
        document = nil
        valueRows = []
        if let workspace { try? FileManager.default.removeItem(at: workspace) }
        workspace = nil
    }

    func export(_ kind: StandaloneExportKind) {
        guard !isWorking, let document, let workspace else { return }
        let panel = NSSavePanel()
        panel.title = kind.title
        panel.nameFieldStringValue = "\(URL(fileURLWithPath: document.source.filename).deletingPathExtension().lastPathComponent)-analysis\(kind.suffix)"
        if let type = kind.contentType { panel.allowedContentTypes = [type] }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        guard destination.standardizedFileURL.resolvingSymlinksInPath() != sourceURL?.standardizedFileURL.resolvingSymlinksInPath() else {
            error = "Export to a new location; the original audio file must remain unchanged."
            return
        }
        isWorking = true
        status = "Writing \(kind.title.lowercased())…"
        Task {
            defer { isWorking = false }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try StandaloneAudioExport.write(document, workspace: workspace, kind: kind, destination: destination)
                }.value
                status = "Export complete: \(destination.lastPathComponent)"
                NSWorkspace.shared.activateFileViewerSelecting([destination])
            } catch { self.error = error.localizedDescription; status = "Export failed. Choose another destination and retry." }
        }
    }
}
