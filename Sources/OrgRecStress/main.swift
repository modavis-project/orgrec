import AVFAudio
import AudioToolbox
import Foundation
import OrgRecCore

struct Options {
    var duration = 10.0
    var sampleRate = 96_000.0
    var channels = 8
    var bufferFrames = 1_024
    var realtime = true
    var output: URL?

    init(arguments: [String]) {
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--duration" where index + 1 < arguments.count:
                duration = Double(arguments[index + 1]) ?? duration
                index += 1
            case "--sample-rate" where index + 1 < arguments.count:
                sampleRate = Double(arguments[index + 1]) ?? sampleRate
                index += 1
            case "--channels" where index + 1 < arguments.count:
                channels = Int(arguments[index + 1]) ?? channels
                index += 1
            case "--buffer-frames" where index + 1 < arguments.count:
                bufferFrames = Int(arguments[index + 1]) ?? bufferFrames
                index += 1
            case "--output" where index + 1 < arguments.count:
                output = URL(fileURLWithPath: arguments[index + 1])
                index += 1
            case "--unthrottled":
                realtime = false
            default:
                break
            }
            index += 1
        }
    }
}

let options = Options(arguments: Array(CommandLine.arguments.dropFirst()))
guard (1...64).contains(options.channels),
      options.duration > 0,
      options.sampleRate >= 8_000,
      options.bufferFrames > 0 else {
    FileHandle.standardError.write(Data("Invalid stress-test options.\n".utf8))
    exit(2)
}

let layout = AVAudioChannelLayout(
    layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | AudioChannelLayoutTag(options.channels)
)!
let format = AVAudioFormat(
    commonFormat: .pcmFormatFloat32,
    sampleRate: options.sampleRate,
    interleaved: false,
    channelLayout: layout
)
let output = options.output ?? FileManager.default.temporaryDirectory
    .appendingPathComponent("OrgRec-Stress-\(options.channels)ch-\(Int(options.sampleRate))Hz.wav")
let metadata = BWFMetadata(
    description: "OrgRec synthetic multichannel field-pilot stress run",
    originatorReference: "ORGREC-STRESS-\(UUID().uuidString.prefix(16))",
    originationDate: Date().formatted(.iso8601.year().month().day()),
    originationTime: Date().formatted(.iso8601.time(includingFractionalSeconds: false)),
    codingHistory: "A=PCM,F=\(Int(options.sampleRate)),W=24,M=\(options.channels)"
)
let writer = try QueuedAudioWriter(
    audioURL: output,
    inputFormat: format,
    bufferCapacity: AVAudioFrameCount(options.bufferFrames),
    poolSize: 256,
    channelRoles: (1...options.channels).map { "Stress channel \($0)" },
    bwfMetadata: metadata
)

let totalBuffers = Int(ceil(options.duration * options.sampleRate / Double(options.bufferFrames)))
let started = ContinuousClock.now
var sampleTime: AVAudioFramePosition = 0
for bufferIndex in 0..<totalBuffers {
    autoreleasepool {
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(options.bufferFrames)
        )!
        buffer.frameLength = AVAudioFrameCount(options.bufferFrames)
        for channel in 0..<options.channels {
            let samples = buffer.floatChannelData![channel]
            let frequency = Double(55 * (channel + 1))
            for frame in 0..<options.bufferFrames {
                let time = Double(bufferIndex * options.bufferFrames + frame) / options.sampleRate
                samples[frame] = Float(0.12 * sin(2 * Double.pi * frequency * time))
            }
        }
        writer.enqueue(buffer, time: AVAudioTime(sampleTime: sampleTime, atRate: options.sampleRate))
    }
    sampleTime += AVAudioFramePosition(options.bufferFrames)
    if options.realtime {
        Thread.sleep(forTimeInterval: Double(options.bufferFrames) / options.sampleRate)
    }
}
let (diagnostics, bwf) = writer.finish()
let elapsed = started.duration(to: .now)
let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
let audio = try AVAudioFile(forReading: output)
let report = """
OrgRec field-pilot stress report
output: \(output.path)
simulated: \(options.duration) s · \(options.channels) channels · \(Int(options.sampleRate)) Hz · 24-bit PCM
wall time: \(String(format: "%.3f", seconds)) s
frames: \(diagnostics.writtenFrames)
buffers: \(diagnostics.writtenBuffers)/\(diagnostics.receivedBuffers)
dropped: \(diagnostics.droppedBuffers)
discontinuities: \(diagnostics.discontinuityCount)
faults: \(diagnostics.faults.count)
verified format: \(audio.fileFormat.channelCount) channels · \(Int(audio.fileFormat.sampleRate)) Hz · \(audio.fileFormat.streamDescription.pointee.mBitsPerChannel)-bit
BWF: \(bwf?.message ?? "not finalized")
"""
print(report)
if diagnostics.droppedBuffers > 0 || diagnostics.discontinuityCount > 0 || diagnostics.faults.isEmpty == false {
    exit(1)
}
