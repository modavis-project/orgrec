import Combine
import OrgRecCore
import SwiftUI

enum LoopBoundaryHandle: String, CaseIterable, Identifiable {
    case start = "Loop start"
    case end = "Loop end"
    var id: String { rawValue }
}

@MainActor
final class AnalysisInteractionState: ObservableObject {
    @Published var viewport = AnalysisTimeViewport.full(duration: 1)
    @Published var cursorTime: Double?
    @Published var inspection: SpectrogramInspection?
    @Published var selectedPartial: Int?
    @Published var showPartialTracks = true
    @Published var showBoundaryMarkers = true
    @Published var showAnnotations = true
    @Published var showLoopRegions = true
    @Published var showLowConfidenceEvidence = false
    @Published var boundaryDrafts: [AnalysisMarkerKind: Double] = [:]
    @Published var selectedBoundary: AnalysisMarkerKind?
    @Published var loopDraftStartSeconds: Double?
    @Published var loopDraftEndSeconds: Double?
    @Published var loopCrossfadeSeconds: Double = 0
    @Published var loopSourceID: UUID?
    @Published var selectedLoopHandle: LoopBoundaryHandle?

    private(set) var totalDuration: Double = 1
    private var boundaryBaseline: [AnalysisMarkerKind: Double] = [:]
    private var loopBaseline: (start: Double, end: Double, crossfade: Double, sourceID: UUID)?

    func configure(duration: Double, boundaries: [AnalysisMarkerKind: Double] = [:], loopPointSet: LoopPointSet? = nil) {
        totalDuration = max(0.001, duration)
        viewport = .full(duration: totalDuration)
        cursorTime = nil
        inspection = nil
        selectedPartial = nil
        selectedBoundary = nil
        boundaryBaseline = clamped(boundaries)
        boundaryDrafts = boundaryBaseline
        configureLoop(loopPointSet)
    }

    func reset() {
        viewport = .full(duration: totalDuration)
    }

    func zoom(by factor: Double, anchor: Double = 0.5) {
        viewport = viewport.zoomed(by: factor, anchorNormalizedX: anchor, totalDuration: totalDuration)
    }

    func pan(fraction: Double) {
        viewport = viewport.panned(bySeconds: viewport.duration * fraction, totalDuration: totalDuration)
    }

    func focus(time: Double, span: Double? = nil) {
        let targetSpan = min(totalDuration, max(0.05, span ?? viewport.duration))
        let start = min(max(0, time - targetSpan / 2), max(0, totalDuration - targetSpan))
        viewport = AnalysisTimeViewport(startSeconds: start, endSeconds: start + targetSpan)
        cursorTime = min(totalDuration, max(0, time))
    }

    var boundaryChronologyIsValid: Bool {
        AnalysisBoundarySequence.isChronological(boundaryDrafts)
    }

    var hasBoundaryChanges: Bool {
        boundaryDrafts != boundaryBaseline
    }

    func setBoundary(_ marker: AnalysisMarkerKind, to time: Double) {
        boundaryDrafts[marker] = min(totalDuration, max(0, time))
        cursorTime = boundaryDrafts[marker]
    }

    func nudgeBoundary(_ marker: AnalysisMarkerKind, by seconds: Double) {
        setBoundary(marker, to: (boundaryDrafts[marker] ?? 0) + seconds)
    }

    func revertBoundaryDrafts() {
        boundaryDrafts = boundaryBaseline
    }

    func commitBoundaryDrafts() {
        boundaryBaseline = boundaryDrafts
    }

    func boundaryIsStaged(_ marker: AnalysisMarkerKind) -> Bool {
        boundaryDrafts[marker] != boundaryBaseline[marker]
    }

    var loopDraftIsValid: Bool {
        guard let start = loopDraftStartSeconds, let end = loopDraftEndSeconds else { return false }
        return start >= 0 && end <= totalDuration && end > start
            && loopCrossfadeSeconds >= 0 && loopCrossfadeSeconds * 2 < end - start
    }

    var hasLoopChanges: Bool {
        guard let baseline = loopBaseline else { return loopDraftStartSeconds != nil || loopDraftEndSeconds != nil }
        return loopSourceID != baseline.sourceID
            || abs((loopDraftStartSeconds ?? -.infinity) - baseline.start) > 0.000_000_1
            || abs((loopDraftEndSeconds ?? -.infinity) - baseline.end) > 0.000_000_1
            || abs(loopCrossfadeSeconds - baseline.crossfade) > 0.000_000_1
    }

    func configureLoop(_ set: LoopPointSet?) {
        guard let set, let region = set.sustainRegion else {
            loopDraftStartSeconds = nil
            loopDraftEndSeconds = nil
            loopCrossfadeSeconds = 0
            loopSourceID = nil
            selectedLoopHandle = nil
            loopBaseline = nil
            return
        }
        let start = region.startSeconds(sampleRate: set.sampleRate)
        let end = region.endSeconds(sampleRate: set.sampleRate)
        let crossfade = Double(region.crossfadeFrames) / set.sampleRate
        loopDraftStartSeconds = start
        loopDraftEndSeconds = end
        loopCrossfadeSeconds = crossfade
        loopSourceID = set.id
        loopBaseline = (start, end, crossfade, set.id)
    }

    func setLoopHandle(_ handle: LoopBoundaryHandle, to time: Double) {
        let value = min(totalDuration, max(0, time))
        switch handle {
        case .start: loopDraftStartSeconds = value
        case .end: loopDraftEndSeconds = value
        }
        cursorTime = value
    }

    func nudgeLoopHandle(_ handle: LoopBoundaryHandle, by seconds: Double) {
        let current = handle == .start ? loopDraftStartSeconds : loopDraftEndSeconds
        setLoopHandle(handle, to: (current ?? 0) + seconds)
    }

    func revertLoopDraft() {
        guard let baseline = loopBaseline else { return }
        loopDraftStartSeconds = baseline.start
        loopDraftEndSeconds = baseline.end
        loopCrossfadeSeconds = baseline.crossfade
        loopSourceID = baseline.sourceID
    }

    func commitLoopDraft(result: LoopPointSet) {
        configureLoop(result)
    }

    private func clamped(_ values: [AnalysisMarkerKind: Double]) -> [AnalysisMarkerKind: Double] {
        values.mapValues { min(totalDuration, max(0, $0)) }
    }
}

struct AnalysisNavigationBar: View {
    @ObservedObject var interaction: AnalysisInteractionState

    var body: some View {
        HStack(spacing: 10) {
            Label("Linked inspection", systemImage: "scope").font(.headline)
            Text(visibleRange)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("Visible time range \(visibleRange)")
            Spacer()
            ControlGroup {
                Button { interaction.pan(fraction: -0.8) } label: { Label("Earlier", systemImage: "chevron.left") }
                    .help("Pan earlier")
                Button { interaction.zoom(by: 1.8) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                    .help("Zoom in around the center")
                Button { interaction.zoom(by: 1 / 1.8) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                    .help("Zoom out around the center")
                Button { interaction.pan(fraction: 0.8) } label: { Label("Later", systemImage: "chevron.right") }
                    .help("Pan later")
                Button("Reset") { interaction.reset() }
            }
            Toggle("Partials", isOn: $interaction.showPartialTracks).toggleStyle(.checkbox)
                .help("Show inferred partial tracks")
            Toggle("Boundaries", isOn: $interaction.showBoundaryMarkers).toggleStyle(.checkbox)
                .help("Show automated or corrected transient boundaries")
            Toggle("Annotations", isOn: $interaction.showAnnotations).toggleStyle(.checkbox)
            Toggle("Loops", isOn: $interaction.showLoopRegions).toggleStyle(.checkbox)
                .help("Show the staged sustain loop and crossfade zones")
            Toggle("Low confidence", isOn: $interaction.showLowConfidenceEvidence).toggleStyle(.checkbox)
                .help("Include evidence that failed normal validity or confidence gates")
        }
        .controlSize(.small)
    }

    private var visibleRange: String {
        let start = interaction.viewport.startSeconds.formatted(.number.precision(.fractionLength(3)))
        let end = interaction.viewport.endSeconds.formatted(.number.precision(.fractionLength(3)))
        let total = interaction.totalDuration.formatted(.number.precision(.fractionLength(3)))
        return "\(start)–\(end) s of \(total) s"
    }
}

struct InteractiveAnalysisWaveform: View {
    let waveform: WaveformSummary?
    let analysis: AnalysisSummary
    let correctedMarkers: Set<AnalysisMarkerKind>
    let annotations: [TimedAnnotation]
    @ObservedObject var interaction: AnalysisInteractionState
    let playback: AudioPlaybackController

    var body: some View {
        VStack(spacing: 4) {
            DeferredAnalysisCanvas(renderKey: renderKey, draw: draw)
                .overlay {
                    LinkedCursorOverlay(
                        interaction: interaction,
                        playback: playback,
                        darkBackground: true
                    )
                }
                .overlay { timelineInteraction }
                .clipShape(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Audio waveform with transient boundaries")
                .accessibilityValue(accessibilityValue)
                .accessibilityHint("Move the pointer or drag to inspect time; release to seek playback")
            TimelineAxis(viewport: interaction.viewport)
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OrgRecTheme.sumi.opacity(0.94)))
        drawTimeGrid(context: &context, size: size, viewport: interaction.viewport, color: OrgRecTheme.washi.opacity(0.12))
        drawPhases(context: &context, size: size)
        if interaction.showLoopRegions { drawLoopOverlay(context: &context, size: size, interaction: interaction, darkBackground: true) }
        if let waveform, waveform.samples.count > 1 {
            let duration = max(0.001, waveform.duration)
            let lower = max(0, min(waveform.samples.count - 1, Int(floor(interaction.viewport.startSeconds / duration * Double(waveform.samples.count - 1)))))
            let upper = max(lower + 1, min(waveform.samples.count - 1, Int(ceil(interaction.viewport.endSeconds / duration * Double(waveform.samples.count - 1)))))
            var path = Path()
            for index in lower...upper {
                let time = Double(index) / Double(waveform.samples.count - 1) * duration
                let x = CGFloat(interaction.viewport.normalizedX(for: time)) * size.width
                let y = size.height / 2 - CGFloat(waveform.samples[index]) * size.height * 0.45
                if index == lower { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(OrgRecTheme.ai), lineWidth: 1.2)
        }
        if interaction.showBoundaryMarkers { drawBoundaries(context: &context, size: size) }
        if interaction.showAnnotations { drawAnnotations(context: &context, size: size, annotations: annotations, viewport: interaction.viewport) }
    }

    private var renderKey: Int {
        var hasher = Hasher()
        hasher.combine(analysis.analysisRunID)
        hasher.combine(analysis.analyzedAt)
        hasher.combine(waveform?.samples.count)
        hasher.combine(waveform?.duration)
        hasher.combine(correctedMarkers)
        combineAnnotations(annotations, into: &hasher)
        combineTimelineDrawingState(interaction, into: &hasher)
        return hasher.finalize()
    }

    private func drawBoundaries(context: inout GraphicsContext, size: CGSize) {
        let evidence = Dictionary(uniqueKeysWithValues: (analysis.boundaries ?? []).map { ($0.marker, $0) })
        for kind in AnalysisMarkerKind.allCases {
            guard let time = interaction.boundaryDrafts[kind], interaction.viewport.startSeconds...interaction.viewport.endSeconds ~= time else { continue }
            let item = evidence[kind]
            let isReviewed = correctedMarkers.contains(kind)
            let isStaged = interaction.boundaryIsStaged(kind)
            let isSelected = interaction.selectedBoundary == kind
            let x = CGFloat(interaction.viewport.normalizedX(for: time)) * size.width
            var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
            let color: Color = kind == .onset || kind == .sustainStart ? OrgRecTheme.shu : OrgRecTheme.ai
            if !isReviewed, !isStaged, let resolution = item?.timeResolutionSeconds, resolution > 0 {
                let bandWidth = max(3, CGFloat(resolution / interaction.viewport.duration) * size.width)
                context.fill(Path(CGRect(x: x - bandWidth / 2, y: 0, width: bandWidth, height: size.height)), with: .color(color.opacity(0.16)))
            }
            let isCensored = !isReviewed && (item?.state == .leftCensored || item?.state == .rightCensored)
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: isSelected ? 2.8 : 1.5, dash: isSelected ? [] : (isCensored ? [2, 4] : [5, 3])))
            if isSelected {
                context.fill(Path(ellipseIn: CGRect(x: x - 5, y: 1, width: 10, height: 10)), with: .color(OrgRecTheme.washi))
                context.stroke(Path(ellipseIn: CGRect(x: x - 5, y: 1, width: 10, height: 10)), with: .color(color), lineWidth: 2)
            }
            context.draw(
                Text(isReviewed ? "\(kind.rawValue) (reviewed)" : (isCensored ? "\(kind.rawValue) (censored)" : kind.rawValue)).font(.caption2).foregroundStyle(OrgRecTheme.washi),
                at: CGPoint(x: min(size.width - 4, x + 4), y: 8),
                anchor: .topLeading
            )
        }
        for item in analysis.boundaries ?? [] where interaction.boundaryDrafts[item.marker] == nil {
            guard item.state == .leftCensored || item.state == .rightCensored || item.state == .unresolved else { continue }
            let x: CGFloat = item.state == .rightCensored ? size.width - 2 : 2
            context.draw(
                Text("\(item.marker.rawValue): \(item.state.rawValue)").font(.caption2).foregroundStyle(OrgRecTheme.washi.opacity(0.8)),
                at: CGPoint(x: x, y: size.height - 5),
                anchor: item.state == .rightCensored ? .bottomTrailing : .bottomLeading
            )
        }
    }

    private func drawPhases(context: inout GraphicsContext, size: CGSize) {
        let values = interaction.boundaryDrafts
        phase(from: values[.onset], to: values[.sustainStart], label: "ATTACK", color: OrgRecTheme.shu.opacity(0.13), context: &context, size: size)
        phase(from: values[.sustainStart], to: values[.keyUp] ?? values[.soundOffset], label: "SUSTAIN", color: OrgRecTheme.ai.opacity(0.13), context: &context, size: size)
        phase(from: values[.keyUp], to: values[.soundOffset], label: "RELEASE", color: OrgRecTheme.shu.opacity(0.09), context: &context, size: size)
        phase(from: values[.soundOffset], to: values[.tailEnd], label: "TAIL", color: OrgRecTheme.ai.opacity(0.09), context: &context, size: size)
    }

    private func phase(
        from start: Double?,
        to end: Double?,
        label: String,
        color: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard let start, let end, end > start,
              end >= interaction.viewport.startSeconds, start <= interaction.viewport.endSeconds else { return }
        let clippedStart = max(start, interaction.viewport.startSeconds)
        let clippedEnd = min(end, interaction.viewport.endSeconds)
        let x = CGFloat(interaction.viewport.normalizedX(for: clippedStart)) * size.width
        let width = CGFloat(interaction.viewport.normalizedX(for: clippedEnd) - interaction.viewport.normalizedX(for: clippedStart)) * size.width
        context.fill(Path(CGRect(x: x, y: 0, width: width, height: size.height)), with: .color(color))
        if width > 52 {
            context.draw(Text(label).font(.caption2).foregroundStyle(OrgRecTheme.washi.opacity(0.55)), at: CGPoint(x: x + 5, y: size.height - 5), anchor: .bottomLeading)
        }
    }

    private var timelineInteraction: some View {
        GeometryReader { proxy in
            Color.clear.contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point): interaction.cursorTime = time(at: point.x, width: proxy.size.width)
                    case .ended: interaction.cursorTime = nil
                    }
                }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged {
                        let value = time(at: $0.location.x, width: proxy.size.width)
                        if let handle = interaction.selectedLoopHandle { interaction.setLoopHandle(handle, to: value) }
                        else if let marker = interaction.selectedBoundary { interaction.setBoundary(marker, to: value) }
                        else { interaction.cursorTime = value }
                    }
                    .onEnded {
                        let value = time(at: $0.location.x, width: proxy.size.width)
                        if let handle = interaction.selectedLoopHandle { interaction.setLoopHandle(handle, to: value) }
                        else if let marker = interaction.selectedBoundary { interaction.setBoundary(marker, to: value) }
                        playback.seek(to: value)
                    })
        }
    }

    private func time(at x: CGFloat, width: CGFloat) -> Double {
        interaction.viewport.time(atNormalizedX: width > 0 ? Double(x / width) : 0)
    }

    private var accessibilityValue: String {
        let markerText = interaction.boundaryDrafts.sorted(by: { $0.value < $1.value }).map {
            "\($0.key.rawValue) \($0.value.formatted(.number.precision(.fractionLength(3)))) seconds"
        }.joined(separator: ", ")
        let loopText: String
        if let start = interaction.loopDraftStartSeconds, let end = interaction.loopDraftEndSeconds {
            loopText = "Loop from \(start.formatted(.number.precision(.fractionLength(4)))) to \(end.formatted(.number.precision(.fractionLength(4)))) seconds, \(interaction.loopDraftIsValid ? "valid" : "invalid")"
        } else {
            loopText = "No loop region"
        }
        return (markerText.isEmpty ? "No resolved boundaries" : markerText) + ". " + loopText
    }
}

struct InteractivePitchTrackView: View {
    let track: [PitchTrackPoint]
    let summary: PitchTrackSummary?
    let runCount: Int
    @ObservedObject var interaction: AnalysisInteractionState
    let playback: AudioPlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Framewise pitch evidence", systemImage: "waveform.path.ecg.rectangle").font(.headline)
                Text("solid points: voiced measurements · opacity: confidence")
                    .font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(track.count) frames · \(runCount) immutable run\(runCount == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DeferredAnalysisCanvas(renderKey: renderKey, draw: draw)
                .overlay {
                    LinkedCursorOverlay(
                        interaction: interaction,
                        playback: playback,
                        darkBackground: false
                    )
                }
                .overlay { timelineInteraction }
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Framewise pitch deviations")
                .accessibilityValue(accessibilityValue)
                .accessibilityHint("Vertical range is plus or minus 60 cents around the median")
            TimelineAxis(viewport: interaction.viewport)
            HStack(spacing: 18) {
                evidence("Voiced", summary?.voicedRatio.formatted(.percent.precision(.fractionLength(0))))
                evidence("IQR", summary?.interquartileRangeCents.map { format($0, " ¢") })
                evidence("MAD", summary?.medianAbsoluteDeviationCents.map { format($0, " ¢") })
                evidence("Drift", summary?.driftCentsPerSecond.map { format($0, " ¢/s", signed: true) })
                evidence("Modulation", summary?.modulationRateHz.map { format($0, " Hz") })
                evidence("Depth", summary?.modulationDepthCents.map { format($0, " ¢") })
                Spacer()
            }
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OrgRecTheme.recessed))
        drawTimeGrid(context: &context, size: size, viewport: interaction.viewport, color: OrgRecTheme.sumi.opacity(0.08))
        guard let center = summary?.medianFrequencyHz else { return }
        if let lower = summary?.lowerUncertaintyCents, let upper = summary?.upperUncertaintyCents {
            let top = pitchY(upper, height: size.height)
            let bottom = pitchY(lower, height: size.height)
            context.fill(Path(CGRect(x: 0, y: min(top, bottom), width: size.width, height: abs(bottom - top))), with: .color(OrgRecTheme.ai.opacity(0.08)))
        }
        for cents in [-60.0, -30, 0, 30, 60] {
            let y = pitchY(cents, height: size.height)
            var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(OrgRecTheme.sumi.opacity(cents == 0 ? 0.25 : 0.08)), lineWidth: cents == 0 ? 1.2 : 1)
            context.draw(Text("\(Int(cents))¢").font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: 4, y: y - 2), anchor: .bottomLeading)
        }
        var path = Path(); var connected = false
        for point in track where interaction.viewport.startSeconds...interaction.viewport.endSeconds ~= point.timeSeconds {
            guard let frequency = point.frequencyHz,
                  let cents = PitchMatcher.cents(measured: frequency, expected: center) else { connected = false; continue }
            let visible = point.voiced || interaction.showLowConfidenceEvidence
            guard visible else { connected = false; continue }
            let x = CGFloat(interaction.viewport.normalizedX(for: point.timeSeconds)) * size.width
            let y = pitchY(cents, height: size.height)
            if point.voiced {
                if connected { path.addLine(to: CGPoint(x: x, y: y)) } else { path.move(to: CGPoint(x: x, y: y)); connected = true }
            } else {
                connected = false
            }
            let radius: CGFloat = point.voiced ? 2 : 1.5
            let color = point.voiced ? OrgRecTheme.ai.opacity(max(0.25, point.confidence)) : OrgRecTheme.shu.opacity(0.45)
            context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
        }
        context.stroke(path, with: .color(OrgRecTheme.ai.opacity(0.75)), lineWidth: 1.2)
    }

    private var renderKey: Int {
        var hasher = Hasher()
        hasher.combine(track.count)
        hasher.combine(track.first?.timeSeconds)
        hasher.combine(track.last?.timeSeconds)
        hasher.combine(summary)
        hasher.combine(runCount)
        hasher.combine(interaction.viewport)
        hasher.combine(interaction.showLowConfidenceEvidence)
        return hasher.finalize()
    }

    private func pitchY(_ cents: Double, height: CGFloat) -> CGFloat {
        height * CGFloat(0.5 - max(-60, min(60, cents)) / 120)
    }

    private var timelineInteraction: some View {
        GeometryReader { proxy in
            Color.clear.contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point): interaction.cursorTime = interaction.viewport.time(atNormalizedX: Double(point.x / max(1, proxy.size.width)))
                    case .ended: interaction.cursorTime = nil
                    }
                }
                .gesture(DragGesture(minimumDistance: 0).onEnded {
                    playback.seek(to: interaction.viewport.time(atNormalizedX: Double($0.location.x / max(1, proxy.size.width))))
                })
        }
    }

    private func evidence(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value ?? "—").font(.caption.monospacedDigit())
        }
    }

    private func format(_ value: Double, _ suffix: String, signed: Bool = false) -> String {
        value.formatted(.number.precision(.fractionLength(1)).sign(strategy: signed ? .always() : .automatic)) + suffix
    }

    private var accessibilityValue: String {
        let voiced = summary?.voicedRatio.formatted(.percent.precision(.fractionLength(0))) ?? "unknown"
        let median = summary?.medianFrequencyHz?.formatted(.number.precision(.fractionLength(2))) ?? "unknown"
        return "Median \(median) hertz, voiced frame ratio \(voiced)"
    }
}

struct PitchEstimatorComparisonView: View {
    let comparison: PitchEstimatorComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Independent pitch-estimator comparison", systemImage: severitySymbol).font(.headline)
                Spacer()
                Text(comparison.severity.rawValue.capitalized)
                    .font(.caption.bold())
                    .foregroundStyle(severityColor)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(severityColor.opacity(0.12), in: Capsule())
            }
            HStack(spacing: 12) {
                ForEach(comparison.estimates) { estimate in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(estimate.estimator).font(.caption.bold())
                        Text(estimate.frequencyHz.formatted(.number.precision(.fractionLength(2))) + " Hz")
                            .font(.title3.monospacedDigit().bold())
                        Text("confidence \(estimate.confidence.formatted(.percent.precision(.fractionLength(0))))" +
                             (estimate.voicedFrameRatio.map { " · voiced \($0.formatted(.percent.precision(.fractionLength(0))))" } ?? ""))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(OrgRecTheme.sumi.opacity(0.035), in: RoundedRectangle(cornerRadius: OrgRecTheme.compactCornerRadius))
                }
                if let difference = comparison.differenceCents {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CREPE ↔ pYIN").font(.caption.bold())
                        Text(difference.formatted(.number.precision(.fractionLength(1))) + " ¢")
                            .font(.title3.monospacedDigit().bold()).foregroundStyle(severityColor)
                        Text(comparison.severity == .critical ? "not averaged" : "comparison distance")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(width: 145, alignment: .leading)
                }
            }
            Label(comparison.rationale, systemImage: comparison.severity == .critical ? "hand.raised.fill" : "info.circle")
                .font(.caption).foregroundStyle(comparison.severity == .critical ? OrgRecTheme.shu : .secondary)
            if comparison.severity == .critical {
                Text("Treat the displayed pitch as provisional. Inspect the sustain region, voicing, octave relationship, and source audio before accepting the take.")
                    .font(.caption.bold()).foregroundStyle(OrgRecTheme.shu)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pitch estimator comparison, \(comparison.severity.rawValue)")
        .accessibilityValue(accessibilityValue)
    }

    private var severityColor: Color {
        comparison.severity == .critical ? OrgRecTheme.shu : OrgRecTheme.ai
    }

    private var severitySymbol: String {
        comparison.severity == .critical ? "exclamationmark.octagon.fill" : "point.3.connected.trianglepath.dotted"
    }

    private var accessibilityValue: String {
        let values = comparison.estimates.map {
            "\($0.estimator) \($0.frequencyHz.formatted(.number.precision(.fractionLength(2)))) hertz"
        }.joined(separator: ", ")
        return values + (comparison.differenceCents.map { ", difference \($0.formatted(.number.precision(.fractionLength(1)))) cents" } ?? "")
    }
}

struct InteractiveSpectrogramView: View {
    let data: SpectrogramData?
    let analysis: AnalysisSummary
    let annotations: [TimedAnnotation]
    @ObservedObject var interaction: AnalysisInteractionState
    let playback: AudioPlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DeferredAnalysisCanvas(renderKey: renderKey, draw: draw)
                .overlay {
                    SpectrogramCursorOverlay(
                        data: data,
                        interaction: interaction,
                        playback: playback
                    )
                }
                .overlay { spectralInteraction }
                .frame(minHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: OrgRecTheme.cornerRadius))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Spectrogram with optional inferred partial tracks")
                .accessibilityValue(accessibilityValue)
                .accessibilityHint("Move the pointer for exact stored-bin evidence; release a drag to seek")
            HStack(alignment: .center, spacing: 12) {
                SpectrogramColorLegend(dynamicRange: data?.configuration?.dynamicRangeDB ?? 90)
                    .frame(width: 240)
                Divider().frame(height: 28)
                SpectrogramInspectorReadout(inspection: interaction.inspection)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(frequencyRange).font(.caption.monospacedDigit())
                    Text(data?.configuration?.frequencyScale.rawValue ?? "Unknown scale")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            TimelineAxis(viewport: interaction.viewport)
        }
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(OrgRecTheme.recessed))
        guard let data, data.timeBins > 0, data.frequencyBins > 0,
              let timeStep = data.timeStepSeconds else { return }
        let dynamicRange = Float(data.configuration?.dynamicRangeDB ?? 90)
        let startBin = max(0, min(data.timeBins - 1, Int(floor(interaction.viewport.startSeconds / timeStep))))
        let endBin = max(startBin, min(data.timeBins - 1, Int(ceil(interaction.viewport.endSeconds / timeStep))))
        let visibleBins = max(1, endBin - startBin + 1)
        let cellW = size.width / CGFloat(visibleBins)
        let cellH = size.height / CGFloat(data.frequencyBins)
        for timeBin in startBin...endBin where data.magnitudes.indices.contains(timeBin) {
            for frequencyBin in 0..<min(data.frequencyBins, data.magnitudes[timeBin].count) {
                let intensity = max(0, min(1, CGFloat((data.magnitudes[timeBin][frequencyBin] + dynamicRange) / dynamicRange)))
                let rect = CGRect(
                    x: CGFloat(timeBin - startBin) * cellW,
                    y: size.height - CGFloat(frequencyBin + 1) * cellH,
                    width: cellW + 0.5,
                    height: cellH + 0.5
                )
                context.fill(Path(rect), with: .color(spectrogramColor(intensity)))
            }
        }
        if interaction.showBoundaryMarkers { drawSpectralPhases(context: &context, size: size) }
        if interaction.showLoopRegions { drawLoopOverlay(context: &context, size: size, interaction: interaction, darkBackground: false) }
        if interaction.showPartialTracks { drawPartials(data: data, context: &context, size: size) }
        if interaction.showBoundaryMarkers { drawSpectralBoundaries(context: &context, size: size) }
        if interaction.showAnnotations { drawAnnotations(context: &context, size: size, annotations: annotations, viewport: interaction.viewport) }
    }

    private var renderKey: Int {
        var hasher = Hasher()
        hasher.combine(analysis.analysisRunID)
        hasher.combine(analysis.analyzedAt)
        hasher.combine(data?.timeBins)
        hasher.combine(data?.frequencyBins)
        hasher.combine(data?.configuration)
        hasher.combine(interaction.viewport)
        hasher.combine(interaction.showPartialTracks)
        hasher.combine(interaction.showBoundaryMarkers)
        hasher.combine(interaction.showAnnotations)
        hasher.combine(interaction.showLoopRegions)
        hasher.combine(interaction.showLowConfidenceEvidence)
        hasher.combine(interaction.selectedPartial)
        combineAnnotations(annotations, into: &hasher)
        combineTimelineDrawingState(interaction, into: &hasher)
        return hasher.finalize()
    }

    private func drawPartials(data: SpectrogramData, context: inout GraphicsContext, size: CGSize) {
        guard let frequencies = data.frequencyAxisHz else { return }
        for track in (data.partialTracks ?? []).prefix(32) {
            let selected = interaction.selectedPartial == track.harmonicNumber
            var path = Path(); var connected = false
            for point in track.points where interaction.viewport.startSeconds...interaction.viewport.endSeconds ~= point.timeSeconds {
                let valid = point.isValid != false
                guard valid || interaction.showLowConfidenceEvidence else { connected = false; continue }
                let nearest = frequencies.indices.min(by: { abs(frequencies[$0] - point.frequencyHz) < abs(frequencies[$1] - point.frequencyHz) }) ?? 0
                let x = CGFloat(interaction.viewport.normalizedX(for: point.timeSeconds)) * size.width
                let y = size.height - size.height * CGFloat(nearest) / CGFloat(max(1, frequencies.count - 1))
                if valid {
                    if connected { path.addLine(to: CGPoint(x: x, y: y)) } else { path.move(to: CGPoint(x: x, y: y)); connected = true }
                } else {
                    connected = false
                    let cross = Path(CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
                    context.stroke(cross, with: .color(OrgRecTheme.shu.opacity(0.6)), lineWidth: 0.7)
                }
            }
            let color = selected ? OrgRecTheme.shu : OrgRecTheme.ai.opacity(max(0.32, track.confidence ?? 0.45))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: selected ? 2.4 : (track.harmonicNumber == 1 ? 1.6 : 0.9), dash: selected ? [] : [5, 2]))
        }
    }

    private func drawSpectralPhases(context: inout GraphicsContext, size: CGSize) {
        for interval in AnalysisBoundarySequence.phases(interaction.boundaryDrafts) {
            guard interval.endSeconds >= interaction.viewport.startSeconds,
                  interval.startSeconds <= interaction.viewport.endSeconds else { continue }
            let start = max(interval.startSeconds, interaction.viewport.startSeconds)
            let end = min(interval.endSeconds, interaction.viewport.endSeconds)
            let x = CGFloat(interaction.viewport.normalizedX(for: start)) * size.width
            let width = CGFloat(interaction.viewport.normalizedX(for: end) - interaction.viewport.normalizedX(for: start)) * size.width
            let color = interval.phase == .attack || interval.phase == .release ? OrgRecTheme.shu : OrgRecTheme.ai
            context.fill(Path(CGRect(x: x, y: 0, width: width, height: 15)), with: .color(color.opacity(0.72)))
            if width > 48 {
                context.draw(Text(interval.phase.rawValue.uppercased()).font(.caption2).foregroundStyle(OrgRecTheme.washi), at: CGPoint(x: x + 4, y: 7), anchor: .leading)
            }
        }
    }

    private func drawSpectralBoundaries(context: inout GraphicsContext, size: CGSize) {
        for (kind, time) in interaction.boundaryDrafts where interaction.viewport.startSeconds...interaction.viewport.endSeconds ~= time {
            let x = CGFloat(interaction.viewport.normalizedX(for: time)) * size.width
            var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
            let selected = interaction.selectedBoundary == kind
            let color: Color = kind == .onset || kind == .sustainStart ? OrgRecTheme.shu : OrgRecTheme.ai
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: selected ? 2.4 : 1, dash: selected ? [] : [4, 3]))
        }
        for item in analysis.boundaries ?? [] where interaction.boundaryDrafts[item.marker] == nil {
            guard item.state == .leftCensored || item.state == .rightCensored else { continue }
            let x: CGFloat = item.state == .rightCensored ? size.width - 3 : 3
            var edge = Path(); edge.move(to: CGPoint(x: x, y: 0)); edge.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(edge, with: .color(OrgRecTheme.shu), style: StrokeStyle(lineWidth: 2, dash: [2, 3]))
        }
    }

    private var spectralInteraction: some View {
        GeometryReader { proxy in
            Color.clear.contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point): updateInspection(point, size: proxy.size)
                    case .ended:
                        interaction.cursorTime = nil
                        interaction.inspection = nil
                    }
                }
                .gesture(DragGesture(minimumDistance: 0)
                    .onChanged {
                        updateInspection($0.location, size: proxy.size)
                        if let handle = interaction.selectedLoopHandle, let time = interaction.inspection?.timeSeconds {
                            interaction.setLoopHandle(handle, to: time)
                        } else if let marker = interaction.selectedBoundary, let time = interaction.inspection?.timeSeconds {
                            interaction.setBoundary(marker, to: time)
                        }
                    }
                    .onEnded {
                        updateInspection($0.location, size: proxy.size)
                        if let inspection = interaction.inspection {
                            if let handle = interaction.selectedLoopHandle {
                                interaction.setLoopHandle(handle, to: inspection.timeSeconds)
                            } else if let marker = interaction.selectedBoundary {
                                interaction.setBoundary(marker, to: inspection.timeSeconds)
                            } else if let harmonic = inspection.nearestPartialHarmonic {
                                interaction.selectedPartial = harmonic
                            }
                            playback.seek(to: inspection.timeSeconds)
                        }
                    })
        }
    }

    private func updateInspection(_ point: CGPoint, size: CGSize) {
        guard let data, size.width > 0, size.height > 0 else { return }
        let result = SpectrogramInspector.inspect(
            data: data,
            normalizedX: Double(point.x / size.width),
            normalizedY: Double(point.y / size.height),
            viewport: interaction.viewport
        )
        interaction.inspection = result
        interaction.cursorTime = result?.timeSeconds
    }

    private var frequencyRange: String {
        guard let data else { return "—" }
        let minimum = data.frequencyAxisHz?.first ?? 0
        let maximum = data.frequencyAxisHz?.last ?? data.maximumFrequency
        return "\(minimum.formatted(.number.precision(.fractionLength(0))))–\(maximum.formatted(.number.precision(.fractionLength(0)))) Hz"
    }

    private var accessibilityValue: String {
        guard let data else { return "No spectral derivative loaded" }
        let loop = interaction.loopDraftStartSeconds != nil ? ", with a staged or reviewed loop overlay" : ""
        return "\(data.timeBins) time bins, \(data.frequencyBins) frequency bins, magnitude relative to the derivative peak\(loop)"
    }
}

struct InteractivePartialTracksView: View {
    let tracks: [PartialTrack]
    @ObservedObject var interaction: AnalysisInteractionState
    let playback: AudioPlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Pipe-sound partial evidence", systemImage: "waveform.path.ecg").font(.headline)
                Spacer()
                Text("Select a row to highlight its inferred path").font(.caption).foregroundStyle(.secondary)
            }
            header
            ForEach(tracks.prefix(32)) { track in
                Button {
                    interaction.selectedPartial = interaction.selectedPartial == track.harmonicNumber ? nil : track.harmonicNumber
                    if let time = track.onsetSeconds ?? track.points.first?.timeSeconds {
                        interaction.focus(time: time)
                        playback.seek(to: time)
                    }
                } label: {
                    row(track)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 6)
                        .background(interaction.selectedPartial == track.harmonicNumber ? OrgRecTheme.ai.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Harmonic \(track.harmonicNumber), confidence \(track.confidence?.formatted(.percent.precision(.fractionLength(0))) ?? "unknown")")
                Divider()
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Partial").frame(width: 48, alignment: .leading)
            Text("Measured").frame(width: 92, alignment: .trailing)
            Text("Offset").frame(width: 72, alignment: .trailing)
            Text("Onset").frame(width: 82, alignment: .trailing)
            Text("Acoustic offset").frame(width: 105, alignment: .trailing)
            Text("SNR").frame(width: 64, alignment: .trailing)
            Text("Valid").frame(width: 60, alignment: .trailing)
            Text("Confidence").frame(width: 80, alignment: .trailing)
            Text("Decay").frame(width: 88, alignment: .trailing)
            Spacer()
        }
        .font(.caption.bold()).foregroundStyle(.secondary)
    }

    private func row(_ track: PartialTrack) -> some View {
        HStack {
            Text("H\(track.harmonicNumber)").frame(width: 48, alignment: .leading)
            Text(track.medianFrequencyHz.map { hz($0) } ?? "—").frame(width: 92, alignment: .trailing)
            Text(track.medianOffsetCents.map { signed($0, " ¢") } ?? "—").frame(width: 72, alignment: .trailing)
            Text(seconds(track.onsetSeconds)).frame(width: 82, alignment: .trailing)
            Text(seconds(track.offsetSeconds)).frame(width: 105, alignment: .trailing)
            Text(track.signalToNoiseDB.map { format($0, " dB") } ?? "—").frame(width: 64, alignment: .trailing)
            Text(track.validPointRatio?.formatted(.percent.precision(.fractionLength(0))) ?? "—").frame(width: 60, alignment: .trailing)
            Text(track.confidence?.formatted(.percent.precision(.fractionLength(0))) ?? "—").frame(width: 80, alignment: .trailing)
            Text(track.decayRateDBPerSecond.map { signed($0, " dB/s") } ?? "—").frame(width: 88, alignment: .trailing)
            Spacer()
        }
        .font(.system(.caption, design: .monospaced))
    }

    private func hz(_ value: Double) -> String { format(value, " Hz") }
    private func seconds(_ value: Double?) -> String { value.map { format($0, " s", digits: 3) } ?? "—" }
    private func signed(_ value: Double, _ suffix: String) -> String {
        value.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())) + suffix
    }
    private func format(_ value: Double, _ suffix: String, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(digits))) + suffix
    }
}

struct InteractiveBoundaryEditor: View {
    @EnvironmentObject private var model: AppModel
    let analysis: AnalysisSummary
    @ObservedObject var interaction: AnalysisInteractionState
    @State private var author = NSFullUserName()
    @State private var reason = ""
    @State private var expanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Select a boundary, then drag its solid handle in the waveform or spectrogram. Changes remain staged until explicitly saved.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    if interaction.hasBoundaryChanges {
                        Label("Unsaved review", systemImage: "pencil.and.outline")
                            .font(.caption.bold()).foregroundStyle(OrgRecTheme.shu)
                    }
                }
                boundaryHeader
                ForEach(AnalysisMarkerKind.allCases) { marker in boundaryRow(marker) }
                if interaction.boundaryChronologyIsValid == false {
                    Label("Invalid order: onset ≤ sustain start ≤ key-up ≤ sound offset ≤ tail end.", systemImage: "exclamationmark.octagon.fill")
                        .font(.caption.bold()).foregroundStyle(OrgRecTheme.shu)
                }
                Divider()
                HStack {
                    TextField("Reviewer", text: $author).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                    TextField("Evidence-based reason for correction", text: $reason).textFieldStyle(.roundedBorder)
                    Button("Revert staged edits") { interaction.revertBoundaryDrafts() }
                        .disabled(!interaction.hasBoundaryChanges)
                    Button("Save reviewed boundaries") {
                        Task {
                            await model.saveMarkerCorrections(interaction.boundaryDrafts, author: author, reason: reason)
                            if model.errorMessage == nil {
                                interaction.commitBoundaryDrafts()
                                reason = ""
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                }
                if interaction.hasBoundaryChanges && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("A reason is required because corrections become immutable scientific review history.")
                        .font(.caption2).foregroundStyle(OrgRecTheme.shu)
                }
                correctionHistory
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Label("Interactive onset and offset adjudication", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.headline)
                Spacer()
                Text(interaction.boundaryChronologyIsValid ? "chronology valid" : "chronology invalid")
                    .font(.caption.bold())
                    .foregroundStyle(interaction.boundaryChronologyIsValid ? OrgRecTheme.ai : OrgRecTheme.shu)
            }
        }
    }

    private var boundaryHeader: some View {
        HStack {
            Text("Boundary").frame(width: 112, alignment: .leading)
            Text("Time").frame(width: 105, alignment: .trailing)
            Text("Automatic evidence").frame(width: 190, alignment: .leading)
            Text("Fine adjustment").frame(width: 250, alignment: .center)
            Spacer()
        }
        .font(.caption.bold()).foregroundStyle(.secondary)
    }

    private func boundaryRow(_ marker: AnalysisMarkerKind) -> some View {
        let evidence = analysis.boundaries?.first { $0.marker == marker }
        let selected = interaction.selectedBoundary == marker
        return HStack(spacing: 10) {
            Button {
                interaction.selectedBoundary = selected ? nil : marker
                interaction.selectedLoopHandle = nil
                if let time = interaction.boundaryDrafts[marker] {
                    interaction.cursorTime = time
                    model.playback.seek(to: time)
                }
            } label: {
                Label(marker.rawValue, systemImage: selected ? "circle.inset.filled" : "circle")
                    .frame(width: 112, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selected ? OrgRecTheme.shu : OrgRecTheme.sumi)
            .accessibilityLabel("\(selected ? "Deselect" : "Select") \(marker.rawValue) boundary")
            .accessibilityValue(evidenceLabel(evidence))

            if interaction.boundaryDrafts[marker] != nil {
                TextField(
                    "seconds",
                    value: Binding(
                        get: { interaction.boundaryDrafts[marker] ?? 0 },
                        set: { interaction.setBoundary(marker, to: $0) }
                    ),
                    format: .number.precision(.fractionLength(4))
                )
                .textFieldStyle(.roundedBorder).frame(width: 92)
                .accessibilityLabel("\(marker.rawValue) boundary time in seconds")
            } else {
                Text("— unresolved").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: 92, alignment: .trailing)
            }
            Text("s").font(.caption).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(evidenceLabel(evidence)).font(.caption)
                if let evidence {
                    Text(evidence.contributingFeatures.joined(separator: " · "))
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(width: 190, alignment: .leading)

            ControlGroup {
                Button("−10 ms") { interaction.nudgeBoundary(marker, by: -0.010) }
                    .accessibilityLabel("Move \(marker.rawValue) boundary 10 milliseconds earlier")
                Button("−1 ms") { interaction.nudgeBoundary(marker, by: -0.001) }
                    .accessibilityLabel("Move \(marker.rawValue) boundary 1 millisecond earlier")
                Button("+1 ms") { interaction.nudgeBoundary(marker, by: 0.001) }
                    .accessibilityLabel("Move \(marker.rawValue) boundary 1 millisecond later")
                Button("+10 ms") { interaction.nudgeBoundary(marker, by: 0.010) }
                    .accessibilityLabel("Move \(marker.rawValue) boundary 10 milliseconds later")
            }
            .controlSize(.mini).frame(width: 250)
            Button("Playhead") { interaction.setBoundary(marker, to: model.playback.currentTime) }
                .controlSize(.small)
                .accessibilityLabel("Set \(marker.rawValue) boundary to playhead")
            if let automatic = automaticTime(marker) {
                Button("Automatic") { interaction.setBoundary(marker, to: automatic) }
                    .controlSize(.small)
                    .accessibilityLabel("Restore automatic \(marker.rawValue) boundary")
            }
            Spacer()
        }
        .padding(.vertical, 3)
        .background(selected ? OrgRecTheme.shu.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(marker.rawValue) boundary controls")
    }

    @ViewBuilder
    private var correctionHistory: some View {
        if let corrections = model.selectedTake?.markerCorrections, corrections.isEmpty == false {
            DisclosureGroup("Immutable correction history (\(corrections.count))") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(corrections.suffix(10).reversed()) { correction in
                        Text("\(correction.marker.rawValue): \(correction.automatedSeconds?.formatted(.number.precision(.fractionLength(4))) ?? "—") → \(correction.correctedSeconds.formatted(.number.precision(.fractionLength(4)))) s · \(correction.author) · \(correction.reason)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.top, 5)
            }.font(.caption)
        }
    }

    private var canSave: Bool {
        interaction.hasBoundaryChanges
            && interaction.boundaryChronologyIsValid
            && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func evidenceLabel(_ evidence: AnalysisBoundaryEvidence?) -> String {
        guard let evidence else { return "Legacy · confidence unavailable" }
        let resolution = evidence.timeResolutionSeconds.map {
            " · \(($0 * 1_000).formatted(.number.precision(.fractionLength(0)))) ms grid"
        } ?? ""
        return "\(evidence.state.rawValue) · \(evidence.confidence.formatted(.percent.precision(.fractionLength(0)))) confidence\(resolution)"
    }

    private func automaticTime(_ marker: AnalysisMarkerKind) -> Double? {
        switch marker {
        case .onset: analysis.onsetSeconds
        case .sustainStart: analysis.sustainStartSeconds
        case .keyUp: analysis.keyUpSeconds
        case .soundOffset: analysis.soundOffsetSeconds
        case .tailEnd: analysis.tailEndSeconds
        }
    }
}

struct ResponsibleVisualizationNote: View {
    let data: SpectrogramData?
    let analysis: AnalysisSummary
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 7) {
                statement("Measured", "Waveform samples and heatmap cells are stored analysis derivatives. Heatmap values are dB relative to this derivative’s global peak—not calibrated sound-pressure level.")
                statement("Inferred", "Pitch connections, transient boundaries, partial tracks, and proposed loop regions are algorithmic interpretations. Confidence opacity, dashed lines, censored labels, score details, and gaps expose uncertainty or failed validity gates.")
                statement("Interaction", "Hover readouts snap to stored bins. Zoom, pan, selection, and visibility alter presentation only. Loop audition changes no evidence; accepting a loop or boundary requires a reason and creates review provenance.")
                if let configuration = data?.configuration {
                    Text("Resolution: \(configuration.fftSize)-sample \(configuration.window.rawValue) window · hop \(configuration.hopSize) samples · \(data?.timeStepSeconds?.formatted(.number.precision(.fractionLength(5))) ?? "—") s displayed time step.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let run = analysis.analysisRunID {
                    Text("Evidence run: \(run.uuidString.lowercased())")
                        .font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Interpretation, uncertainty, and display provenance", systemImage: "info.circle")
                .font(.headline)
        }
    }

    private func statement(_ term: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(term).font(.caption.bold()).frame(width: 70, alignment: .leading)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct TimelineAxis: View {
    let viewport: AnalysisTimeViewport
    var body: some View {
        HStack {
            Text(viewport.startSeconds.formatted(.number.precision(.fractionLength(3))) + " s")
            Spacer()
            Text(viewport.time(atNormalizedX: 0.5).formatted(.number.precision(.fractionLength(3))) + " s")
            Spacer()
            Text(viewport.endSeconds.formatted(.number.precision(.fractionLength(3))) + " s")
        }
        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
    }
}

private struct SpectrogramColorLegend: View {
    let dynamicRange: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            LinearGradient(colors: [OrgRecTheme.recessed, OrgRecTheme.ai, OrgRecTheme.shu], startPoint: .leading, endPoint: .trailing)
                .frame(height: 8).clipShape(Capsule())
            HStack {
                Text("−\(Int(dynamicRange)) dB")
                Spacer()
                Text("relative magnitude")
                Spacer()
                Text("0 dB")
            }.font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spectrogram color scale from minus \(Int(dynamicRange)) to zero decibels relative to peak")
    }
}

private struct SpectrogramInspectorReadout: View {
    let inspection: SpectrogramInspection?
    var body: some View {
        if let inspection {
            HStack(spacing: 14) {
                readout("Time", inspection.timeSeconds.formatted(.number.precision(.fractionLength(4))) + " s")
                readout("Frequency", inspection.frequencyHz.formatted(.number.precision(.fractionLength(1))) + " Hz")
                readout("Relative level", inspection.relativeMagnitudeDB.formatted(.number.precision(.fractionLength(1))) + " dB")
                if let harmonic = inspection.nearestPartialHarmonic {
                    let snr = inspection.nearestPartialSignalToNoiseDB.map {
                        " · \($0.formatted(.number.precision(.fractionLength(1)))) dB SNR"
                    } ?? ""
                    readout("Nearest inference", "H\(harmonic)" + snr + (inspection.nearestPartialIsValid == false ? " · invalid" : ""))
                }
            }
        } else {
            Text("Hover for time, frequency, relative level, and nearby partial evidence")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func readout(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.monospacedDigit())
        }
    }
}

private func spectrogramColor(_ intensity: CGFloat) -> Color {
    if intensity < 0.55 {
        return OrgRecTheme.ai.opacity(0.05 + intensity * 1.35)
    }
    return OrgRecTheme.shu.opacity(0.22 + intensity * 0.78)
}

/// Prevents high-frequency cursor and transport updates in the parent from
/// rebuilding an unchanged plot. The draw closure is replaced only when its
/// compact data/viewport key changes.
private struct DeferredAnalysisCanvas: View, Equatable {
    let renderKey: Int
    let draw: (inout GraphicsContext, CGSize) -> Void

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.renderKey == rhs.renderKey
    }

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            draw(&context, size)
        }
    }
}

@MainActor
private func combineTimelineDrawingState(
    _ interaction: AnalysisInteractionState,
    into hasher: inout Hasher
) {
    hasher.combine(interaction.viewport)
    hasher.combine(interaction.showBoundaryMarkers)
    hasher.combine(interaction.showAnnotations)
    hasher.combine(interaction.showLoopRegions)
    hasher.combine(interaction.selectedBoundary)
    hasher.combine(interaction.loopDraftStartSeconds)
    hasher.combine(interaction.loopDraftEndSeconds)
    hasher.combine(interaction.loopCrossfadeSeconds)
    hasher.combine(interaction.selectedLoopHandle)
    for marker in AnalysisMarkerKind.allCases {
        hasher.combine(marker)
        hasher.combine(interaction.boundaryDrafts[marker])
    }
}

private func combineAnnotations(_ annotations: [TimedAnnotation], into hasher: inout Hasher) {
    hasher.combine(annotations.count)
    for annotation in annotations {
        hasher.combine(annotation.id)
        hasher.combine(annotation.atSeconds)
        hasher.combine(annotation.severity)
    }
}

/// Playback advances frequently, so its cursor is intentionally isolated from
/// the expensive waveform, pitch, and spectrogram canvases. Only this small
/// transparent overlay redraws for transport ticks.
private struct LinkedCursorOverlay: View {
    @ObservedObject var interaction: AnalysisInteractionState
    @ObservedObject var playback: AudioPlaybackController
    let darkBackground: Bool

    var body: some View {
        Canvas { context, size in
            drawLinkedCursors(
                context: &context,
                size: size,
                viewport: interaction.viewport,
                playhead: playback.currentTime,
                cursor: interaction.cursorTime,
                darkBackground: darkBackground
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SpectrogramCursorOverlay: View {
    let data: SpectrogramData?
    @ObservedObject var interaction: AnalysisInteractionState
    @ObservedObject var playback: AudioPlaybackController

    var body: some View {
        Canvas { context, size in
            drawLinkedCursors(
                context: &context,
                size: size,
                viewport: interaction.viewport,
                playhead: playback.currentTime,
                cursor: interaction.cursorTime
            )
            guard let inspection = interaction.inspection,
                  interaction.viewport.startSeconds...interaction.viewport.endSeconds ~= inspection.timeSeconds,
                  let frequencies = data?.frequencyAxisHz,
                  let index = frequencies.indices.min(by: {
                      abs(frequencies[$0] - inspection.frequencyHz) < abs(frequencies[$1] - inspection.frequencyHz)
                  }) else { return }
            let y = size.height - size.height * CGFloat(index) / CGFloat(max(1, frequencies.count - 1))
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(
                line,
                with: .color(OrgRecTheme.washi.opacity(0.75)),
                style: StrokeStyle(lineWidth: 0.8, dash: [2, 3])
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private func drawTimeGrid(context: inout GraphicsContext, size: CGSize, viewport: AnalysisTimeViewport, color: Color) {
    for index in 1..<4 {
        let x = size.width * CGFloat(index) / 4
        var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(line, with: .color(color), lineWidth: 0.7)
    }
}

@MainActor
private func drawLoopOverlay(
    context: inout GraphicsContext,
    size: CGSize,
    interaction: AnalysisInteractionState,
    darkBackground: Bool
) {
    guard let rawStart = interaction.loopDraftStartSeconds,
          let rawEnd = interaction.loopDraftEndSeconds,
          rawEnd >= interaction.viewport.startSeconds,
          rawStart <= interaction.viewport.endSeconds else { return }
    let start = max(rawStart, interaction.viewport.startSeconds)
    let end = min(rawEnd, interaction.viewport.endSeconds)
    let x0 = CGFloat(interaction.viewport.normalizedX(for: start)) * size.width
    let x1 = CGFloat(interaction.viewport.normalizedX(for: end)) * size.width
    let color = interaction.loopDraftIsValid ? Color.green : OrgRecTheme.shu
    context.fill(Path(CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: size.height)), with: .color(color.opacity(darkBackground ? 0.12 : 0.09)))
    let crossfade = min(interaction.loopCrossfadeSeconds, max(0, (rawEnd - rawStart) / 2))
    if crossfade > 0 {
        for range in [(rawStart, rawStart + crossfade), (rawEnd - crossfade, rawEnd)] {
            let bandStart = max(range.0, interaction.viewport.startSeconds)
            let bandEnd = min(range.1, interaction.viewport.endSeconds)
            guard bandEnd > bandStart else { continue }
            let bx = CGFloat(interaction.viewport.normalizedX(for: bandStart)) * size.width
            let bw = CGFloat(interaction.viewport.normalizedX(for: bandEnd) - interaction.viewport.normalizedX(for: bandStart)) * size.width
            context.fill(Path(CGRect(x: bx, y: 0, width: bw, height: size.height)), with: .color(color.opacity(0.22)))
        }
    }
    for (handle, time) in [(LoopBoundaryHandle.start, rawStart), (.end, rawEnd)] {
        guard interaction.viewport.startSeconds...interaction.viewport.endSeconds ~= time else { continue }
        let x = CGFloat(interaction.viewport.normalizedX(for: time)) * size.width
        var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
        let selected = interaction.selectedLoopHandle == handle
        context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: selected ? 3 : 1.8, dash: selected ? [] : [7, 3]))
        context.fill(Path(roundedRect: CGRect(x: x - 5, y: size.height / 2 - 9, width: 10, height: 18), cornerRadius: 3), with: .color(color))
        context.draw(Text(handle == .start ? "LOOP IN" : "LOOP OUT").font(.caption2).foregroundStyle(darkBackground ? OrgRecTheme.washi : OrgRecTheme.sumi), at: CGPoint(x: x + (handle == .start ? 5 : -5), y: size.height - 4), anchor: handle == .start ? .bottomLeading : .bottomTrailing)
    }
}

private func drawLinkedCursors(
    context: inout GraphicsContext,
    size: CGSize,
    viewport: AnalysisTimeViewport,
    playhead: Double,
    cursor: Double?,
    darkBackground: Bool = false
) {
    if viewport.startSeconds...viewport.endSeconds ~= playhead {
        let x = CGFloat(viewport.normalizedX(for: playhead)) * size.width
        var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(line, with: .color(OrgRecTheme.shu), lineWidth: 1.7)
    }
    if let cursor, viewport.startSeconds...viewport.endSeconds ~= cursor {
        let x = CGFloat(viewport.normalizedX(for: cursor)) * size.width
        var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
        let color = darkBackground ? OrgRecTheme.washi : OrgRecTheme.sumi
        context.stroke(line, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
    }
}

private func drawAnnotations(
    context: inout GraphicsContext,
    size: CGSize,
    annotations: [TimedAnnotation],
    viewport: AnalysisTimeViewport
) {
    for annotation in annotations where viewport.startSeconds...viewport.endSeconds ~= annotation.atSeconds {
        let x = CGFloat(viewport.normalizedX(for: annotation.atSeconds)) * size.width
        var marker = Path(); marker.move(to: CGPoint(x: x, y: 1)); marker.addLine(to: CGPoint(x: x - 4, y: 9)); marker.addLine(to: CGPoint(x: x + 4, y: 9)); marker.closeSubpath()
        context.fill(marker, with: .color(OrgRecTheme.shu))
    }
}
