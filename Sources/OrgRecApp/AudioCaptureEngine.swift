import Accelerate
import AudioToolbox
import AVFoundation
import Combine
import Foundation
import OrgRecCore

struct CaptureResult: Sendable {
    var frameCount: Int64
    var sampleRate: Double
    var channelCount: Int
    var diagnostics: CaptureDiagnostics?
    var bwfMessage: String?
    /// `nil` until capture finalization has actually been attempted.
    var bwfFinalizationSucceeded: Bool?
    var audioStartHostTimeTicks: UInt64?
    var audioStartHostTimeNanoseconds: UInt64?
    var audioStartSampleTime: Int64?
}

/// The clock relationship captured at the instant the Core Audio input is
/// stopped. Auxiliary evidence must close against this boundary rather than
/// waiting for the potentially slower on-disk BWF rewrite.
struct CaptureStopBoundary: Sendable {
    var audioStartHostTimeTicks: UInt64?
    var audioStartHostTimeNanoseconds: UInt64?
    var audioStartSampleTime: Int64?
}

private final class CaptureClockAnchorStore: @unchecked Sendable {
    private let lock = NSLock()
    private var hostTime: UInt64?
    private var sampleTime: Int64?

    func reset() {
        lock.lock(); defer { lock.unlock() }
        hostTime = nil
        sampleTime = nil
    }

    func observe(_ time: AVAudioTime) {
        lock.lock(); defer { lock.unlock() }
        guard hostTime == nil else { return }
        if time.isHostTimeValid { hostTime = time.hostTime }
        if time.isSampleTimeValid { sampleTime = time.sampleTime }
    }

    func snapshot() -> (UInt64?, Int64?) {
        lock.lock(); defer { lock.unlock() }
        return (hostTime, sampleTime)
    }
}

/// Bounds UI/pitch work initiated by the Core Audio tap. File writing still
/// receives every buffer, while metering work is sampled at a human-scale rate.
private final class CaptureMonitorGate: @unchecked Sendable {
    private let lock = NSLock()
    private var callbackCount = 0
    private var callbacksPerSample = 1

    func reset(callbacksPerSample: Int) {
        lock.lock(); defer { lock.unlock() }
        callbackCount = 0
        self.callbacksPerSample = max(1, callbacksPerSample)
    }

    func shouldSample() -> Bool {
        lock.lock(); defer { lock.unlock() }
        callbackCount += 1
        return callbackCount.isMultiple(of: callbacksPerSample)
    }
}

@MainActor
final class AudioCaptureEngine: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isFinalizing = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var peakDBFS: Float = -96
    @Published private(set) var channelPeakDBFS: [Float] = []
    @Published private(set) var channelRMSDBFS: [Float] = []
    @Published private(set) var availableDiskBytes: Int64?
    @Published private(set) var liveWaveform: [Float] = []
    @Published private(set) var estimatedFileBytes: Int64 = 0
    @Published private(set) var safeRecordingSecondsRemaining: TimeInterval?
    @Published private(set) var criticalHealthMessage: String?

    private let engine = AVAudioEngine()
    private var writer: QueuedAudioWriter?
    private var startedAt: Date?
    private var timer: Timer?
    private var captureFormat: AVAudioFormat?
    private var healthTick = 0
    private var selectedDeviceID: AudioDeviceID?
    private let clockAnchor = CaptureClockAnchorStore()
    private let monitorGate = CaptureMonitorGate()
    private var criticalStopHandler: (@MainActor @Sendable (String) -> Void)?
    private var safetyStopRequested = false

    /// Leaves headroom for the BEXT chunk and the 32-bit RIFF size fields.
    private static let maximumSafeRIFFBytes = Int64(UInt32.max) - 1_048_576
    /// BWF finalization currently stages a replacement file, so the original
    /// recording plus an operational reserve must remain available.
    private static let finalizationReserveBytes: Int64 = 536_870_912

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start(
        to url: URL,
        deviceID: AudioDeviceID,
        channelRoles: [String],
        referenceChannelIndex: Int,
        bwfMetadata: BWFMetadata,
        pitchSampleHandler: (@Sendable ([Float], Double) -> Void)? = nil,
        criticalStopHandler: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> CaptureResult {
        guard !isRecording, !isFinalizing else { throw CocoaError(.fileWriteUnknown) }
        guard await requestPermission() else {
            throw NSError(
                domain: "OrgRec",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Microphone access was not granted. Enable OrgRec in System Settings → Privacy & Security → Microphone."]
            )
        }

        engine.stop()
        engine.reset()
        let input = engine.inputNode
        if let audioUnit = input.audioUnit {
            var selectedDevice = deviceID
            let status = AudioUnitSetProperty(
                audioUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &selectedDevice,
                UInt32(MemoryLayout.size(ofValue: selectedDevice))
            )
            guard status == noErr else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "OrgRec could not bind AVAudioEngine to the selected Core Audio device."])
            }
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "OrgRec", code: 2, userInfo: [NSLocalizedDescriptionKey: "No usable Core Audio input is selected."])
        }
        let writer = try QueuedAudioWriter(
            audioURL: url,
            inputFormat: format,
            channelRoles: channelRoles,
            referenceChannelIndex: referenceChannelIndex,
            bwfMetadata: bwfMetadata
        )
        self.writer = writer
        selectedDeviceID = deviceID
        captureFormat = format
        liveWaveform = []
        peakDBFS = -96
        channelPeakDBFS = Array(repeating: -96, count: Int(format.channelCount))
        channelRMSDBFS = Array(repeating: -96, count: Int(format.channelCount))
        let callbacksPerSecond = format.sampleRate / 512
        monitorGate.reset(callbacksPerSample: Int((callbacksPerSecond / 20).rounded()))
        clockAnchor.reset()
        estimatedFileBytes = 0
        safeRecordingSecondsRemaining = nil
        criticalHealthMessage = nil
        safetyStopRequested = false
        self.criticalStopHandler = criticalStopHandler

        input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self, writer] buffer, time in
            self?.clockAnchor.observe(time)
            writer.enqueue(buffer, time: time)
            guard self?.monitorGate.shouldSample() == true else { return }
            guard let channels = buffer.floatChannelData else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var peaks = [Float](repeating: 0, count: Int(buffer.format.channelCount))
            var rmsValues = peaks
            for channelIndex in peaks.indices {
                vDSP_maxmgv(channels[channelIndex], 1, &peaks[channelIndex], vDSP_Length(count))
                vDSP_rmsqv(channels[channelIndex], 1, &rmsValues[channelIndex], vDSP_Length(count))
            }
            let stride = max(1, count / 24)
            let points = Swift.stride(from: 0, to: count, by: stride).map { channels[0][$0] }
            let peakDB = peaks.map { max(-96, 20 * log10(max($0, 0.000_015_8))) }
            let rmsDB = rmsValues.map { max(-96, 20 * log10(max($0, 0.000_015_8))) }
            if let pitchSampleHandler {
                let selected = max(0, min(Int(buffer.format.channelCount) - 1, referenceChannelIndex))
                pitchSampleHandler(Array(UnsafeBufferPointer(start: channels[selected], count: count)), format.sampleRate)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.peakDBFS = peakDB.max() ?? -96
                self.channelPeakDBFS = peakDB
                self.channelRMSDBFS = rmsDB
                self.liveWaveform.append(contentsOf: points)
                if self.liveWaveform.count > 720 {
                    self.liveWaveform.removeFirst(self.liveWaveform.count - 720)
                }
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            isFinalizing = true
            self.writer = nil
            captureFormat = nil
            captureURL = nil
            selectedDeviceID = nil
            self.criticalStopHandler = nil
            safetyStopRequested = false
            _ = await Task.detached(priority: .userInitiated) { writer.finish() }.value
            isFinalizing = false
            throw error
        }
        startedAt = .now
        isRecording = true
        let healthTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let startedAt = self.startedAt else { return }
                self.elapsed = Date().timeIntervalSince(startedAt)
                let bytesPerSecond = (self.captureFormat?.sampleRate ?? 0)
                    * Double(self.captureFormat?.channelCount ?? 0) * 3
                self.estimatedFileBytes = Int64(max(0, self.elapsed * bytesPerSecond)) + 4_096
                if bytesPerSecond > 0 {
                    self.safeRecordingSecondsRemaining = max(
                        0,
                        Double(Self.maximumSafeRIFFBytes - self.estimatedFileBytes) / bytesPerSecond
                    )
                }
                self.healthTick += 1
                if let url = self.captureURL,
                   let bytes = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage {
                    self.availableDiskBytes = bytes
                    self.writer?.observeAvailableDisk(bytes: bytes)
                    let requiredForSafeFinalization = self.estimatedFileBytes + Self.finalizationReserveBytes
                    if bytes <= requiredForSafeFinalization {
                        self.requestSafetyStop(
                            "Recording stopped before the volume became too full to finalize its Broadcast Wave metadata.",
                            fault: .lowDiskSpace
                        )
                    }
                }
                if self.estimatedFileBytes >= Self.maximumSafeRIFFBytes {
                    self.requestSafetyStop(
                        "Recording stopped at the safe 32-bit RIFF/WAVE container limit. Start a new take to continue.",
                        fault: .writerFailure
                    )
                }
                if let diagnostics = self.writer?.currentDiagnostics(),
                   diagnostics.droppedBuffers > 0 || diagnostics.faults.contains(where: { $0.kind == .writerFailure }) {
                    self.requestSafetyStop(
                        "Recording stopped because the audio writer could no longer guarantee continuous lossless capture.",
                        fault: .writerFailure
                    )
                }
                if self.healthTick.isMultiple(of: 10), let deviceID = self.selectedDeviceID {
                    if self.deviceIsAlive(deviceID) == false {
                        self.requestSafetyStop(
                            "Recording stopped because the selected Core Audio input device became unavailable.",
                            fault: .deviceChanged
                        )
                    }
                    if let sampleRate = self.deviceSampleRate(deviceID),
                       abs(sampleRate - (self.captureFormat?.sampleRate ?? sampleRate)) > 0.5 {
                        self.requestSafetyStop(
                            "Recording stopped because the device nominal sample rate changed to \(sampleRate) Hz during capture.",
                            fault: .formatChanged
                        )
                    }
                }
            }
        }
        RunLoop.main.add(healthTimer, forMode: .common)
        timer = healthTimer
        captureURL = url
        return CaptureResult(
            frameCount: 0,
            sampleRate: format.sampleRate,
            channelCount: Int(format.channelCount),
            diagnostics: nil,
            bwfMessage: nil,
            bwfFinalizationSucceeded: nil,
            audioStartHostTimeTicks: nil,
            audioStartHostTimeNanoseconds: nil,
            audioStartSampleTime: nil
        )
    }

    func stop(
        boundaryHandler: ((CaptureStopBoundary) -> Void)? = nil
    ) async -> CaptureResult {
        guard isRecording else {
            return CaptureResult(
                frameCount: 0,
                sampleRate: 0,
                channelCount: 0,
                diagnostics: nil,
                bwfMessage: nil,
                bwfFinalizationSucceeded: nil,
                audioStartHostTimeTicks: nil,
                audioStartHostTimeNanoseconds: nil,
                audioStartSampleTime: nil
            )
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        isFinalizing = true

        let activeWriter = writer
        writer = nil
        let anchor = clockAnchor.snapshot()
        let format = captureFormat
        captureFormat = nil
        captureURL = nil
        selectedDeviceID = nil
        criticalStopHandler = nil
        safetyStopRequested = false
        let boundary = CaptureStopBoundary(
            audioStartHostTimeTicks: anchor.0,
            audioStartHostTimeNanoseconds: anchor.0.map(AudioConvertHostTimeToNanos),
            audioStartSampleTime: anchor.1
        )
        boundaryHandler?(boundary)

        let finalized = await Task.detached(priority: .userInitiated) {
            activeWriter?.finish()
        }.value
        let frames = finalized?.0.writtenFrames ?? 0
        isFinalizing = false
        return CaptureResult(
            frameCount: frames,
            sampleRate: format?.sampleRate ?? 0,
            channelCount: Int(format?.channelCount ?? 0),
            diagnostics: finalized?.0,
            bwfMessage: finalized?.1?.message,
            bwfFinalizationSucceeded: finalized?.1?.embedded == true,
            audioStartHostTimeTicks: boundary.audioStartHostTimeTicks,
            audioStartHostTimeNanoseconds: boundary.audioStartHostTimeNanoseconds,
            audioStartSampleTime: boundary.audioStartSampleTime
        )
    }

    private var captureURL: URL?

    private func requestSafetyStop(_ message: String, fault: CaptureFaultKind) {
        guard safetyStopRequested == false else { return }
        safetyStopRequested = true
        criticalHealthMessage = message
        writer?.recordFault(kind: fault, message: message)
        criticalStopHandler?(message)
    }

    private func deviceIsAlive(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr && value != 0
    }

    private func deviceSampleRate(_ id: AudioDeviceID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = 0.0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr ? value : nil
    }
}
