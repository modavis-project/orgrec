import Accelerate
import AVFoundation
import Foundation

private struct PendingAudioBuffer {
    var buffer: AVAudioPCMBuffer
    var sampleTime: AVAudioFramePosition?
}

public final class QueuedAudioWriter: @unchecked Sendable {
    private let lock = NSLock()
    private let available = DispatchSemaphore(value: 0)
    private let finished = DispatchGroup()
    private let queue = DispatchQueue(label: "org.modavis.OrgRec.audio-writer", qos: .userInitiated)
    private var file: AVAudioFile?
    private var buffers: [PendingAudioBuffer?] = []
    private var queueHead = 0
    private var queueTail = 0
    private var queuedCount = 0
    private var pool: [AVAudioPCMBuffer] = []
    private var stopping = false
    private var expectedSampleTime: AVAudioFramePosition?
    private var diagnostics: CaptureDiagnostics
    private var channelEnergySums: [Double] = []
    private var channelSampleCounts: [Int64] = []
    private let audioURL: URL
    private let bwfMetadata: BWFMetadata

    public init(
        audioURL: URL,
        inputFormat: AVAudioFormat,
        bufferCapacity: AVAudioFrameCount = 4_096,
        poolSize: Int = 128,
        channelRoles: [String],
        referenceChannelIndex: Int = 0,
        bwfMetadata: BWFMetadata
    ) throws {
        self.audioURL = audioURL
        self.bwfMetadata = bwfMetadata
        let channels = Int(inputFormat.channelCount)
        diagnostics = CaptureDiagnostics(
            queuedBufferCapacity: poolSize,
            channels: (0..<channels).map { index in
                ChannelCaptureStatistics(
                    channelIndex: index,
                    role: channelRoles.indices.contains(index) ? channelRoles[index] : "Input \(index + 1)",
                    isReferenceChannel: index == referenceChannelIndex
                )
            }
        )
        channelEnergySums = Array(repeating: 0, count: channels)
        channelSampleCounts = Array(repeating: 0, count: channels)
        guard poolSize > 0, channels > 0 else {
            throw NSError(domain: "OrgRec.Writer", code: 2, userInfo: [NSLocalizedDescriptionKey: "The writer requires at least one channel and one queued buffer."])
        }
        buffers = Array(repeating: nil, count: poolSize)
        pool.reserveCapacity(poolSize)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: channels,
            AVLinearPCMBitDepthKey: 24,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        file = try AVAudioFile(
            forWriting: audioURL,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        for _ in 0..<poolSize {
            if let buffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: bufferCapacity) {
                pool.append(buffer)
            }
        }
        guard pool.count == poolSize else {
            throw NSError(domain: "OrgRec.Writer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not preallocate the complete real-time capture buffer pool."])
        }
        finished.enter()
        queue.async { [weak self] in self?.writerLoop() }
    }

    public func enqueue(_ source: AVAudioPCMBuffer, time: AVAudioTime) {
        lock.lock()
        diagnostics.receivedBuffers += 1
        let start = time.isSampleTimeValid ? time.sampleTime : nil
        if let start, let expectedSampleTime, start != expectedSampleTime {
            diagnostics.discontinuityCount += 1
            diagnostics.faults.append(CaptureFault(
                kind: .sampleDiscontinuity,
                framePosition: start,
                message: "Expected sample time \(expectedSampleTime), received \(start)."
            ))
        }
        if let start { expectedSampleTime = start + AVAudioFramePosition(source.frameLength) }
        guard queuedCount < buffers.count,
              let target = pool.popLast(),
              source.frameLength <= target.frameCapacity else {
            diagnostics.droppedBuffers += 1
            diagnostics.faults.append(CaptureFault(
                kind: .queueOverrun,
                framePosition: start,
                message: "The bounded writer queue exhausted its \(diagnostics.queuedBufferCapacity) preallocated buffers."
            ))
            lock.unlock()
            return
        }
        target.frameLength = source.frameLength
        copy(source, to: target)
        buffers[queueTail] = PendingAudioBuffer(buffer: target, sampleTime: start)
        queueTail = (queueTail + 1) % buffers.count
        queuedCount += 1
        lock.unlock()
        available.signal()
    }

    public func observeAvailableDisk(bytes: Int64) {
        lock.lock()
        diagnostics.minimumAvailableDiskBytes = min(diagnostics.minimumAvailableDiskBytes ?? bytes, bytes)
        if bytes < 1_073_741_824,
           diagnostics.faults.contains(where: { $0.kind == .lowDiskSpace }) == false {
            diagnostics.faults.append(CaptureFault(
                kind: .lowDiskSpace,
                message: "Less than 1 GiB remained on the recording volume."
            ))
        }
        lock.unlock()
    }

    public func recordFault(kind: CaptureFaultKind, message: String) {
        lock.lock()
        if diagnostics.faults.contains(where: { $0.kind == kind && $0.message == message }) == false {
            diagnostics.faults.append(CaptureFault(
                kind: kind,
                framePosition: diagnostics.writtenFrames,
                message: message
            ))
        }
        lock.unlock()
    }

    /// Returns a value snapshot suitable for live health monitoring while the
    /// writer continues to receive and drain buffers.
    public func currentDiagnostics() -> CaptureDiagnostics {
        lock.lock()
        defer { lock.unlock() }
        return diagnostics
    }

    public func finish() -> (CaptureDiagnostics, BWFMetadataWriter.Result?) {
        lock.lock()
        stopping = true
        lock.unlock()
        available.signal()
        finished.wait()
        file = nil
        let result: BWFMetadataWriter.Result?
        do {
            result = try BWFMetadataWriter.finalize(audioURL: audioURL, metadata: bwfMetadata)
            if let result, result.embedded == false {
                lock.lock()
                diagnostics.faults.append(CaptureFault(
                    kind: .writerFailure,
                    framePosition: diagnostics.writtenFrames,
                    message: "Broadcast Wave finalization did not embed metadata: \(result.message)"
                ))
                lock.unlock()
            }
        } catch {
            result = nil
            lock.lock()
            diagnostics.faults.append(CaptureFault(
                kind: .writerFailure,
                framePosition: diagnostics.writtenFrames,
                message: "Broadcast Wave finalization failed: \(error.localizedDescription)"
            ))
            lock.unlock()
        }
        lock.lock()
        let snapshot = diagnostics
        lock.unlock()
        return (snapshot, result)
    }

    private func writerLoop() {
        defer { finished.leave() }
        while true {
            available.wait()
            while let pending = dequeue() {
                do {
                    try file?.write(from: pending.buffer)
                    accumulateStatistics(pending.buffer)
                    lock.lock()
                    diagnostics.writtenBuffers += 1
                    diagnostics.writtenFrames += Int64(pending.buffer.frameLength)
                    pool.append(pending.buffer)
                    lock.unlock()
                } catch {
                    lock.lock()
                    diagnostics.faults.append(CaptureFault(
                        kind: .writerFailure,
                        framePosition: pending.sampleTime,
                        message: error.localizedDescription
                    ))
                    pool.append(pending.buffer)
                    lock.unlock()
                }
            }
            lock.lock()
            let shouldStop = stopping && queuedCount == 0
            lock.unlock()
            if shouldStop { break }
        }
    }

    private func dequeue() -> PendingAudioBuffer? {
        lock.lock()
        defer { lock.unlock() }
        guard queuedCount > 0, let value = buffers[queueHead] else { return nil }
        buffers[queueHead] = nil
        queueHead = (queueHead + 1) % buffers.count
        queuedCount -= 1
        return value
    }

    private func accumulateStatistics(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        let silenceAmplitude = pow(10.0, -80.0 / 20.0)
        var observations: [(peakDB: Double, energy: Double, clipped: Int64, silent: Int64)] = []
        observations.reserveCapacity(Int(buffer.format.channelCount))
        for channelIndex in 0..<Int(buffer.format.channelCount) {
            let samples = channels[channelIndex]
            var peak: Float = 0
            vDSP_maxmgv(samples, 1, &peak, vDSP_Length(frames))
            let peakDB = 20 * log10(max(Double(peak), 0.000_001))
            var energy = 0.0
            var clipped: Int64 = 0, silent: Int64 = 0
            for frame in 0..<frames {
                let sample = Double(samples[frame])
                energy += sample * sample
                if abs(sample) >= 0.999 { clipped += 1 }
                if abs(sample) < silenceAmplitude { silent += 1 }
            }
            observations.append((peakDB, energy, clipped, silent))
        }
        lock.lock()
        for channelIndex in observations.indices where diagnostics.channels.indices.contains(channelIndex) {
            let observation = observations[channelIndex]
            channelEnergySums[channelIndex] += observation.energy
            channelSampleCounts[channelIndex] += Int64(frames)
            let meanSquare = channelEnergySums[channelIndex] / Double(max(1, channelSampleCounts[channelIndex]))
            diagnostics.channels[channelIndex].peakDBFS = max(diagnostics.channels[channelIndex].peakDBFS, observation.peakDB)
            diagnostics.channels[channelIndex].rmsDBFS = 10 * log10(max(meanSquare, 0.000_000_000_001))
            diagnostics.channels[channelIndex].clippedSamples += observation.clipped
            diagnostics.channels[channelIndex].silentFrames += observation.silent
        }
        lock.unlock()
    }

    private func copy(_ source: AVAudioPCMBuffer, to target: AVAudioPCMBuffer) {
        let sourceList = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let targetList = UnsafeMutableAudioBufferListPointer(target.mutableAudioBufferList)
        for index in 0..<min(sourceList.count, targetList.count) {
            guard let sourceData = sourceList[index].mData, let targetData = targetList[index].mData else { continue }
            let byteCount = Int(sourceList[index].mDataByteSize)
            memcpy(targetData, sourceData, byteCount)
            targetList[index].mDataByteSize = sourceList[index].mDataByteSize
        }
    }
}
