import AVFoundation
import Combine
import Foundation
import OrgRecCore

enum SustainedPlaybackPhase: String {
    case idle = "Ready"
    case attack = "Attack"
    case sustain = "Sustain loop"
    case release = "Release"
}

/// Normal transport plus a sample-instrument gate. Sustained playback keeps
/// source-frame loop coordinates authoritative, renders an equal-power seam on
/// every repetition, and crossfades to the recorded release when available.
@MainActor
final class AudioPlaybackController: NSObject, ObservableObject {
    @Published private(set) var isLoaded = false
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isSustainActive = false
    @Published private(set) var sustainPhase: SustainedPlaybackPhase = .idle
    @Published private(set) var envelopeLevel: Double = 0
    @Published private(set) var loopIteration = 0
    @Published private(set) var configuredLoopPointSet: LoopPointSet?
    @Published var loops = false {
        didSet { player?.numberOfLoops = loops ? -1 : 0 }
    }

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var loadedURL: URL?
    private var loadedSHA256: String?
    private var sourceBuffer: AVAudioPCMBuffer?
    private let engine = AVAudioEngine()
    private let sustainNode = AVAudioPlayerNode()
    private let releaseNode = AVAudioPlayerNode()
    private var sustainedStartedAt: TimeInterval?
    private var releaseStartedAt: TimeInterval?
    private var prefixDuration = 0.0
    private var cycleDuration = 0.0
    private var releaseDuration = 0.0
    private var pendingFinishCycleRelease = false

    override init() {
        super.init()
        engine.attach(sustainNode)
        engine.attach(releaseNode)
    }

    func load(_ url: URL) throws {
        guard loadedURL != url else { return }
        stop()
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        player.numberOfLoops = loops ? -1 : 0
        let file = try AVAudioFile(forReading: url)
        guard file.length <= Int64(UInt32.max),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              ) else {
            throw NSError(domain: "OrgRecPlayback", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "The audio file is too long to load into the sustained-playback buffer."
            ])
        }
        try file.read(into: buffer)
        self.player = player
        sourceBuffer = buffer
        loadedURL = url
        loadedSHA256 = try sha256(of: url)
        duration = player.duration
        currentTime = 0
        isLoaded = true
    }

    func configureLoopPointSet(_ set: LoopPointSet?) {
        if isSustainActive { stopSustainedPlayback() }
        guard let set, LoopPointSetValidator.errors(for: set).isEmpty,
              let sourceBuffer,
              set.sourceAudioSHA256 == loadedSHA256,
              set.totalFrames == Int64(sourceBuffer.frameLength),
              set.channelCount == Int(sourceBuffer.format.channelCount),
              abs(set.sampleRate - sourceBuffer.format.sampleRate) < 0.001 else {
            configuredLoopPointSet = nil
            return
        }
        configuredLoopPointSet = set
    }

    func togglePlayback() {
        guard let player else { return }
        if isSustainActive { stopSustainedPlayback() }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            invalidateTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func triggerSustain() {
        guard let set = configuredLoopPointSet,
              let region = set.sustainRegion,
              let sourceBuffer,
              let prefix = copyBuffer(sourceBuffer, from: 0, to: region.endFrameExclusive - region.crossfadeFrames),
              let cycle = makeCycleBuffer(sourceBuffer, region: region) else { return }
        player?.stop()
        invalidateTimer()
        sustainNode.stop()
        releaseNode.stop()
        engine.stop()
        engine.reset()
        let format = sourceBuffer.format
        engine.connect(sustainNode, to: engine.mainMixerNode, format: format)
        engine.connect(releaseNode, to: engine.mainMixerNode, format: format)
        sustainNode.volume = 1
        releaseNode.volume = 0
        sustainNode.scheduleBuffer(prefix)
        sustainNode.scheduleBuffer(cycle, at: nil, options: .loops)
        do {
            try engine.start()
            sustainNode.play()
        } catch {
            return
        }
        let rate = set.sampleRate
        prefixDuration = Double(prefix.frameLength) / rate
        cycleDuration = Double(cycle.frameLength) / rate
        sustainedStartedAt = systemUptime
        releaseStartedAt = nil
        pendingFinishCycleRelease = false
        isSustainActive = true
        isPlaying = true
        sustainPhase = .attack
        envelopeLevel = 0
        loopIteration = 0
        startTimer()
    }

    func releaseSustain() {
        guard isSustainActive, let region = configuredLoopPointSet?.sustainRegion else { return }
        if region.exitPolicy == .finishCycleThenRelease,
           let started = sustainedStartedAt,
           systemUptime - started > prefixDuration,
           cycleDuration > 0 {
            pendingFinishCycleRelease = true
            return
        }
        beginRelease()
    }

    func stopSustainedPlayback() {
        sustainNode.stop()
        releaseNode.stop()
        engine.stop()
        sustainedStartedAt = nil
        releaseStartedAt = nil
        pendingFinishCycleRelease = false
        isSustainActive = false
        isPlaying = false
        sustainPhase = .idle
        envelopeLevel = 0
        loopIteration = 0
        invalidateTimer()
    }

    func seek(to seconds: TimeInterval) {
        if isSustainActive { stopSustainedPlayback() }
        guard let player else { return }
        player.currentTime = max(0, min(player.duration, seconds))
        currentTime = player.currentTime
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    func stop() {
        player?.stop()
        stopSustainedPlayback()
        player = nil
        sourceBuffer = nil
        loadedURL = nil
        loadedSHA256 = nil
        configuredLoopPointSet = nil
        isLoaded = false
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    private func beginRelease() {
        guard releaseStartedAt == nil, let set = configuredLoopPointSet,
              let region = set.sustainRegion else { return }
        pendingFinishCycleRelease = false
        releaseStartedAt = systemUptime
        sustainPhase = .release
        releaseDuration = max(0.02, set.envelope.releaseSeconds)
        if region.exitPolicy != .envelopeRelease,
           let sourceBuffer,
           let releaseStart = region.releaseStartFrame,
           let release = copyBuffer(sourceBuffer, from: releaseStart, to: Int64(sourceBuffer.frameLength)) {
            releaseDuration = max(releaseDuration, Double(release.frameLength) / set.sampleRate)
            releaseNode.scheduleBuffer(release) { [weak self] in
                Task { @MainActor in
                    guard let self, self.isSustainActive, self.releaseStartedAt != nil else { return }
                    self.stopSustainedPlayback()
                }
            }
            releaseNode.volume = 0
            releaseNode.play()
        }
    }

    private func startTimer() {
        invalidateTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateTransport() }
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateTransport() {
        guard isSustainActive else {
            guard let player else { return }
            currentTime = player.currentTime
            if !player.isPlaying && !loops {
                isPlaying = false
                invalidateTimer()
            }
            return
        }
        guard let set = configuredLoopPointSet, let region = set.sustainRegion,
              let started = sustainedStartedAt else { return }
        let elapsed = max(0, systemUptime - started)
        if let releaseStartedAt {
            let releaseElapsed = max(0, systemUptime - releaseStartedAt)
            let fade = max(0.01, Double(region.crossfadeFrames) / set.sampleRate)
            let crossfadeProgress = min(1, releaseElapsed / fade)
            sustainNode.volume = Float(cos(crossfadeProgress * .pi / 2))
            if releaseNode.isPlaying { releaseNode.volume = Float(sin(crossfadeProgress * .pi / 2)) }
            let envelopeProgress = min(1, releaseElapsed / max(0.02, set.envelope.releaseSeconds))
            envelopeLevel = curveValue(1 - envelopeProgress, curve: set.envelope.curve)
            currentTime = min(duration, Double(region.releaseStartFrame ?? region.endFrameExclusive) / set.sampleRate + releaseElapsed)
            if region.exitPolicy == .envelopeRelease && envelopeProgress >= 1 {
                stopSustainedPlayback()
            } else if releaseElapsed >= releaseDuration && !releaseNode.isPlaying {
                stopSustainedPlayback()
            }
            return
        }
        if elapsed < prefixDuration {
            currentTime = elapsed
            let attack = max(0.005, set.envelope.attackSeconds)
            let progress = min(1, elapsed / attack)
            envelopeLevel = set.envelope.sustainLevel * curveValue(progress, curve: set.envelope.curve)
            sustainNode.volume = Float(envelopeLevel)
            sustainPhase = progress < 1 ? .attack : .sustain
        } else {
            let loopElapsed = elapsed - prefixDuration
            let phase = cycleDuration > 0 ? loopElapsed.truncatingRemainder(dividingBy: cycleDuration) : 0
            loopIteration = cycleDuration > 0 ? Int(loopElapsed / cycleDuration) + 1 : 1
            currentTime = Double(region.startFrameInclusive) / set.sampleRate + phase
            envelopeLevel = set.envelope.sustainLevel
            sustainNode.volume = Float(envelopeLevel)
            sustainPhase = .sustain
            if pendingFinishCycleRelease, cycleDuration - phase <= 0.025 { beginRelease() }
        }
    }

    private func copyBuffer(_ source: AVAudioPCMBuffer, from rawStart: Int64, to rawEnd: Int64) -> AVAudioPCMBuffer? {
        let start = max(0, min(Int64(source.frameLength), rawStart))
        let end = max(start, min(Int64(source.frameLength), rawEnd))
        let count = end - start
        guard count > 0, count <= Int64(UInt32.max),
              let result = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: AVAudioFrameCount(count)) else { return nil }
        result.frameLength = AVAudioFrameCount(count)
        guard let input = source.floatChannelData, let output = result.floatChannelData else { return nil }
        for channel in 0..<Int(source.format.channelCount) {
            output[channel].update(from: input[channel].advanced(by: Int(start)), count: Int(count))
        }
        return result
    }

    private func makeCycleBuffer(_ source: AVAudioPCMBuffer, region: AudioLoopRegion) -> AVAudioPCMBuffer? {
        let start = max(0, region.startFrameInclusive)
        let end = min(Int64(source.frameLength), region.endFrameExclusive)
        let crossfade = min(max(0, region.crossfadeFrames), max(0, (end - start) / 2 - 1))
        guard let input = source.floatChannelData else { return nil }
        let slices: [[Float]] = (0..<Int(source.format.channelCount)).map { channel in
            Array(UnsafeBufferPointer(start: input[channel].advanced(by: Int(start)), count: Int(end - start)))
        }
        guard let rendered = try? SustainLoopRenderer.renderForwardCycle(channels: slices, crossfadeFrames: Int(crossfade)),
              let count = rendered.first?.count, count > 1,
              let result = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: AVAudioFrameCount(count)) else { return nil }
        result.frameLength = AVAudioFrameCount(count)
        guard let output = result.floatChannelData else { return nil }
        for channel in rendered.indices {
            rendered[channel].withUnsafeBufferPointer { pointer in
                if let base = pointer.baseAddress { output[channel].update(from: base, count: count) }
            }
        }
        return result
    }

    private func curveValue(_ progress: Double, curve: PlaybackEnvelopeCurve) -> Double {
        let clamped = min(1, max(0, progress))
        switch curve {
        case .linear: return clamped
        case .equalPower: return sin(clamped * .pi / 2)
        }
    }

    private var systemUptime: TimeInterval { ProcessInfo.processInfo.systemUptime }
}
