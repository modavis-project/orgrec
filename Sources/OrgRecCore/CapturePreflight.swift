import Foundation
@preconcurrency import AVFAudio

public enum CapturePreflightVerdict: String, Codable, CaseIterable, Sendable {
    case passed
    case attention
    case failed

    public var displayName: String {
        switch self {
        case .passed: "Verified"
        case .attention: "Attention"
        case .failed: "Failed"
        }
    }
}

public struct CapturePreflightProtocolSnapshot: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var targetDurationSeconds: Double
    public var minimumDurationSeconds: Double
    public var quietWindowEndSeconds: Double
    public var signalWindowStartSeconds: Double
    public var minimumSignalToNoiseDB: Double
    public var preferredSignalToNoiseDB: Double
    public var minimumHeadroomDB: Double
    public var preferredHeadroomDB: Double
    public var elevatedRoomToneDBFS: Double
    public var duplicateCorrelationThreshold: Double
    public var duplicateResidualThresholdDB: Double

    public init(
        contractVersion: String = "orgrec.signal-path-rehearsal/v1",
        targetDurationSeconds: Double = 12,
        minimumDurationSeconds: Double = 8,
        quietWindowEndSeconds: Double = 3,
        signalWindowStartSeconds: Double = 5,
        minimumSignalToNoiseDB: Double = 15,
        preferredSignalToNoiseDB: Double = 24,
        minimumHeadroomDB: Double = 3,
        preferredHeadroomDB: Double = 10,
        elevatedRoomToneDBFS: Double = -42,
        duplicateCorrelationThreshold: Double = 0.999_999,
        duplicateResidualThresholdDB: Double = -60
    ) {
        self.contractVersion = contractVersion
        self.targetDurationSeconds = targetDurationSeconds
        self.minimumDurationSeconds = minimumDurationSeconds
        self.quietWindowEndSeconds = quietWindowEndSeconds
        self.signalWindowStartSeconds = signalWindowStartSeconds
        self.minimumSignalToNoiseDB = minimumSignalToNoiseDB
        self.preferredSignalToNoiseDB = preferredSignalToNoiseDB
        self.minimumHeadroomDB = minimumHeadroomDB
        self.preferredHeadroomDB = preferredHeadroomDB
        self.elevatedRoomToneDBFS = elevatedRoomToneDBFS
        self.duplicateCorrelationThreshold = duplicateCorrelationThreshold
        self.duplicateResidualThresholdDB = duplicateResidualThresholdDB
    }
}

public struct CapturePreflightChannelAssignment: Codable, Hashable, Sendable {
    public var channelNumber: Int
    public var role: String
    public var isRequired: Bool

    public init(channelNumber: Int, role: String, isRequired: Bool) {
        self.channelNumber = channelNumber
        self.role = role
        self.isRequired = isRequired
    }
}

public struct CapturePreflightChannelResult: Codable, Hashable, Identifiable, Sendable {
    public var id: Int { channelNumber }
    public var channelNumber: Int
    public var role: String
    public var isRequired: Bool
    public var quietRMSDBFS: Double
    public var signalRMSDBFS: Double
    public var peakDBFS: Double
    public var headroomDB: Double
    public var signalToNoiseDB: Double
    public var dcOffset: Double
    public var clippedSamples: Int64

    public init(
        channelNumber: Int,
        role: String,
        isRequired: Bool,
        quietRMSDBFS: Double,
        signalRMSDBFS: Double,
        peakDBFS: Double,
        headroomDB: Double,
        signalToNoiseDB: Double,
        dcOffset: Double,
        clippedSamples: Int64
    ) {
        self.channelNumber = channelNumber
        self.role = role
        self.isRequired = isRequired
        self.quietRMSDBFS = quietRMSDBFS
        self.signalRMSDBFS = signalRMSDBFS
        self.peakDBFS = peakDBFS
        self.headroomDB = headroomDB
        self.signalToNoiseDB = signalToNoiseDB
        self.dcOffset = dcOffset
        self.clippedSamples = clippedSamples
    }
}

public enum CapturePreflightFindingKind: String, Codable, Sendable {
    case duration
    case channelUnavailable
    case silence
    case clipping
    case headroom
    case lowGain
    case signalToNoise
    case roomTone
    case dcOffset
    case duplicatedRouting
    case invertedRouting
    case captureIntegrity
    case metadataFinalization
    case formatMismatch
    case evidenceIntegrity
}

public struct CapturePreflightFinding: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var kind: CapturePreflightFindingKind
    public var severity: ConsistencySeverity
    public var channelNumbers: [Int]
    public var title: String
    public var detail: String
    public var remediation: String

    public init(
        id: String,
        kind: CapturePreflightFindingKind,
        severity: ConsistencySeverity,
        channelNumbers: [Int] = [],
        title: String,
        detail: String,
        remediation: String
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.channelNumbers = channelNumbers
        self.title = title
        self.detail = detail
        self.remediation = remediation
    }
}

public struct CapturePreflightAnalysisContext: Hashable, Sendable {
    public var reportID: UUID
    public var recordedAt: Date
    public var sessionID: UUID
    public var setupID: UUID
    public var setupRevision: Int
    public var deviceSnapshot: AudioDeviceSnapshot
    public var relativeAudioPath: String
    public var fileSize: Int64
    public var sha256: String
    public var sampleRate: Double
    public var frameCount: Int64
    public var assignments: [CapturePreflightChannelAssignment]
    public var captureDiagnostics: CaptureDiagnostics?
    public var bwfMetadata: BWFMetadata?
    public var bwfFinalizationSucceeded: Bool
    public var protocolSnapshot: CapturePreflightProtocolSnapshot

    public init(
        reportID: UUID = UUID(),
        recordedAt: Date = .now,
        sessionID: UUID,
        setupID: UUID,
        setupRevision: Int,
        deviceSnapshot: AudioDeviceSnapshot,
        relativeAudioPath: String,
        fileSize: Int64,
        sha256: String,
        sampleRate: Double,
        frameCount: Int64,
        assignments: [CapturePreflightChannelAssignment],
        captureDiagnostics: CaptureDiagnostics? = nil,
        bwfMetadata: BWFMetadata? = nil,
        bwfFinalizationSucceeded: Bool = true,
        protocolSnapshot: CapturePreflightProtocolSnapshot = CapturePreflightProtocolSnapshot()
    ) {
        self.reportID = reportID
        self.recordedAt = recordedAt
        self.sessionID = sessionID
        self.setupID = setupID
        self.setupRevision = setupRevision
        self.deviceSnapshot = deviceSnapshot
        self.relativeAudioPath = relativeAudioPath
        self.fileSize = fileSize
        self.sha256 = sha256
        self.sampleRate = sampleRate
        self.frameCount = frameCount
        self.assignments = assignments
        self.captureDiagnostics = captureDiagnostics
        self.bwfMetadata = bwfMetadata
        self.bwfFinalizationSucceeded = bwfFinalizationSucceeded
        self.protocolSnapshot = protocolSnapshot
    }
}

public struct CapturePreflightReport: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var contractVersion: String
    public var recordedAt: Date
    public var sessionID: UUID
    public var setupID: UUID
    public var setupRevision: Int
    public var deviceSnapshot: AudioDeviceSnapshot
    public var relativeAudioPath: String
    public var fileSize: Int64
    public var sha256: String
    public var sampleRate: Double
    public var frameCount: Int64
    public var durationSeconds: Double
    public var protocolSnapshot: CapturePreflightProtocolSnapshot
    public var channels: [CapturePreflightChannelResult]
    public var findings: [CapturePreflightFinding]
    public var verdict: CapturePreflightVerdict
    public var captureDiagnostics: CaptureDiagnostics?
    public var bwfMetadata: BWFMetadata?
    public var bwfFinalizationSucceeded: Bool

    public init(
        id: UUID,
        contractVersion: String = "orgrec.capture-preflight-report/v1",
        recordedAt: Date,
        sessionID: UUID,
        setupID: UUID,
        setupRevision: Int,
        deviceSnapshot: AudioDeviceSnapshot,
        relativeAudioPath: String,
        fileSize: Int64,
        sha256: String,
        sampleRate: Double,
        frameCount: Int64,
        durationSeconds: Double,
        protocolSnapshot: CapturePreflightProtocolSnapshot,
        channels: [CapturePreflightChannelResult],
        findings: [CapturePreflightFinding],
        verdict: CapturePreflightVerdict,
        captureDiagnostics: CaptureDiagnostics?,
        bwfMetadata: BWFMetadata?,
        bwfFinalizationSucceeded: Bool
    ) {
        self.id = id
        self.contractVersion = contractVersion
        self.recordedAt = recordedAt
        self.sessionID = sessionID
        self.setupID = setupID
        self.setupRevision = setupRevision
        self.deviceSnapshot = deviceSnapshot
        self.relativeAudioPath = relativeAudioPath
        self.fileSize = fileSize
        self.sha256 = sha256
        self.sampleRate = sampleRate
        self.frameCount = frameCount
        self.durationSeconds = durationSeconds
        self.protocolSnapshot = protocolSnapshot
        self.channels = channels
        self.findings = findings
        self.verdict = verdict
        self.captureDiagnostics = captureDiagnostics
        self.bwfMetadata = bwfMetadata
        self.bwfFinalizationSucceeded = bwfFinalizationSucceeded
    }

    public func matches(
        sessionID: UUID,
        setupID: UUID,
        setupRevision: Int,
        deviceUID: String,
        sampleRate: Double,
        inputChannels: Int
    ) -> Bool {
        self.sessionID == sessionID
            && self.setupID == setupID
            && self.setupRevision == setupRevision
            && deviceSnapshot.uid == deviceUID
            && deviceSnapshot.inputChannels == inputChannels
            && abs(deviceSnapshot.sampleRate - sampleRate) <= 0.5
    }
}

public enum CapturePreflightAnalyzer {
    public static func analyze(
        fileURL: URL,
        context: CapturePreflightAnalysisContext
    ) throws -> CapturePreflightReport {
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw OrgRecError.unsupportedAudio("The signal-path rehearsal has no readable PCM channels.")
        }

        let maximumFrames = min(
            file.length,
            AVAudioFramePosition((context.protocolSnapshot.targetDurationSeconds * format.sampleRate).rounded(.up))
        )
        let channelCount = Int(format.channelCount)
        var samples = Array(repeating: [Float](), count: channelCount)
        for index in samples.indices { samples[index].reserveCapacity(Int(maximumFrames)) }
        let capacity = AVAudioFrameCount(min(8_192, max(1, maximumFrames)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw OrgRecError.unsupportedAudio("OrgRec could not allocate the rehearsal analysis buffer.")
        }

        var remaining = maximumFrames
        while remaining > 0 {
            let requested = AVAudioFrameCount(min(AVAudioFramePosition(capacity), remaining))
            try file.read(into: buffer, frameCount: requested)
            guard buffer.frameLength > 0, let channelData = buffer.floatChannelData else { break }
            let count = Int(buffer.frameLength)
            for channel in 0..<channelCount {
                samples[channel].append(contentsOf: UnsafeBufferPointer(start: channelData[channel], count: count))
            }
            remaining -= AVAudioFramePosition(count)
        }

        var adjusted = context
        adjusted.sampleRate = format.sampleRate
        adjusted.frameCount = file.length
        return evaluate(samples: samples, context: adjusted)
    }

    public static func evaluate(
        samples: [[Float]],
        context: CapturePreflightAnalysisContext,
        additionalFindings: [CapturePreflightFinding] = []
    ) -> CapturePreflightReport {
        let protocolSnapshot = context.protocolSnapshot
        let sampleRate = max(1, context.sampleRate)
        let analyzedFrames = samples.map(\.count).min() ?? 0
        let duration = Double(context.frameCount > 0 ? context.frameCount : Int64(analyzedFrames)) / sampleRate
        let quietEnd = min(analyzedFrames, max(0, Int((protocolSnapshot.quietWindowEndSeconds * sampleRate).rounded())))
        let signalStart = min(analyzedFrames, max(quietEnd, Int((protocolSnapshot.signalWindowStartSeconds * sampleRate).rounded())))
        var findings = additionalFindings

        if duration < protocolSnapshot.minimumDurationSeconds {
            findings.append(finding(
                "duration", .duration, .blocker,
                title: "Rehearsal ended too early",
                detail: "Only \(duration.formatted(.number.precision(.fractionLength(1)))) s were retained; the protocol requires at least \(protocolSnapshot.minimumDurationSeconds.formatted(.number.precision(.fractionLength(0)))) s.",
                remediation: "Repeat the full quiet-then-loud rehearsal without stopping early."
            ))
        }
        if context.sha256.count != 64 || context.fileSize <= 0 {
            findings.append(finding(
                "evidence", .evidenceIntegrity, .blocker,
                title: "Rehearsal evidence is not fixed",
                detail: "The retained audio file has no valid size and SHA-256 identity.",
                remediation: "Repeat the rehearsal and retain the finalized audio evidence."
            ))
        }
        if abs(context.sampleRate - context.deviceSnapshot.sampleRate) > 0.5 {
            findings.append(finding(
                "sample-rate", .formatMismatch, .blocker,
                title: "Input format changed",
                detail: "The interface was configured for \(Int(context.deviceSnapshot.sampleRate)) Hz but delivered \(Int(context.sampleRate)) Hz.",
                remediation: "Apply the intended Core Audio format, then repeat the rehearsal."
            ))
        }
        if context.bwfFinalizationSucceeded == false {
            findings.append(finding(
                "bwf", .metadataFinalization, .blocker,
                title: "Broadcast Wave finalization failed",
                detail: "The rehearsal audio could not retain its complete BWF identity.",
                remediation: "Check writable disk space and repeat the rehearsal."
            ))
        }
        if let diagnostics = context.captureDiagnostics,
           diagnostics.droppedBuffers > 0 || diagnostics.discontinuityCount > 0 || diagnostics.faults.isEmpty == false {
            let messages = diagnostics.faults.map(\.message)
            findings.append(finding(
                "capture", .captureIntegrity, .blocker,
                title: "Capture path was not continuous",
                detail: ([
                    "\(diagnostics.droppedBuffers) dropped buffer(s)",
                    "\(diagnostics.discontinuityCount) sample discontinuity event(s)",
                ] + messages).joined(separator: "; "),
                remediation: "Resolve disk, interface, or clock instability before recording irreplaceable material."
            ))
        }

        var assignments: [Int: CapturePreflightChannelAssignment] = [:]
        for assignment in context.assignments {
            if assignment.channelNumber < 1 || assignments[assignment.channelNumber] != nil {
                findings.append(finding(
                    "assignment-\(assignment.channelNumber)", .channelUnavailable, .blocker,
                    channels: assignment.channelNumber > 0 ? [assignment.channelNumber] : [],
                    title: "Documented channel assignments are invalid",
                    detail: "Channel numbers must be unique positive integers; found \(assignment.channelNumber).",
                    remediation: "Correct the microphone setup and repeat the rehearsal."
                ))
            } else {
                assignments[assignment.channelNumber] = assignment
            }
        }
        if context.assignments.contains(where: \.isRequired) == false {
            findings.append(finding(
                "assignment-none", .channelUnavailable, .blocker,
                title: "No microphone channels are assigned",
                detail: "The rehearsal has no documented microphone route to assess.",
                remediation: "Add microphone placements with explicit channel numbers before recording."
            ))
        }
        var channelResults: [CapturePreflightChannelResult] = []
        let resultCount = max(samples.count, context.deviceSnapshot.inputChannels)
        for channelIndex in 0..<resultCount {
            let number = channelIndex + 1
            let assignment = assignments[number] ?? CapturePreflightChannelAssignment(
                channelNumber: number,
                role: "Input \(number)",
                isRequired: false
            )
            guard samples.indices.contains(channelIndex) else {
                channelResults.append(CapturePreflightChannelResult(
                    channelNumber: number, role: assignment.role, isRequired: assignment.isRequired,
                    quietRMSDBFS: -120, signalRMSDBFS: -120, peakDBFS: -120,
                    headroomDB: 120, signalToNoiseDB: 0, dcOffset: 0, clippedSamples: 0
                ))
                if assignment.isRequired {
                    findings.append(finding(
                        "channel-\(number)-unavailable", .channelUnavailable, .blocker, channels: [number],
                        title: "Channel \(number) is unavailable",
                        detail: "The documented \(assignment.role) route was not present in the captured stream.",
                        remediation: "Correct the interface routing or microphone setup before recording."
                    ))
                }
                continue
            }

            let channel = samples[channelIndex]
            let quiet = statistics(channel, range: 0..<min(quietEnd, channel.count))
            let signal = statistics(channel, range: min(signalStart, channel.count)..<channel.count)
            let overall = statistics(channel, range: 0..<channel.count)
            let quietDB = decibels(quiet.rms)
            let signalDB = decibels(signal.rms)
            let peakDB = decibels(overall.peak)
            let headroom = max(0, -peakDB)
            let signalToNoise = max(-120, min(120, signalDB - quietDB))
            channelResults.append(CapturePreflightChannelResult(
                channelNumber: number,
                role: assignment.role,
                isRequired: assignment.isRequired,
                quietRMSDBFS: quietDB,
                signalRMSDBFS: signalDB,
                peakDBFS: peakDB,
                headroomDB: headroom,
                signalToNoiseDB: signalToNoise,
                dcOffset: overall.mean,
                clippedSamples: overall.clipped
            ))
            guard assignment.isRequired else { continue }

            if overall.clipped > 0 {
                findings.append(finding(
                    "channel-\(number)-clipping", .clipping, .blocker, channels: [number],
                    title: "Channel \(number) clipped",
                    detail: "\(assignment.role) contains \(overall.clipped) full-scale sample(s).",
                    remediation: "Reduce analogue input gain and repeat the loudest planned registration."
                ))
            }
            if signalDB < -60 {
                findings.append(finding(
                    "channel-\(number)-silence", .silence, .blocker, channels: [number],
                    title: "Channel \(number) did not receive the test signal",
                    detail: "\(assignment.role) measured \(formatDB(signalDB)) during the sounding window.",
                    remediation: "Check phantom power, cable, preamplifier, routing, and the documented channel assignment."
                ))
            } else {
                if overall.clipped == 0, headroom < protocolSnapshot.minimumHeadroomDB {
                    findings.append(finding(
                        "channel-\(number)-headroom-fail", .headroom, .blocker, channels: [number],
                        title: "Channel \(number) has unsafe headroom",
                        detail: "\(assignment.role) retains only \(formatDB(headroom, suffix: " dB")) of headroom.",
                        remediation: "Reduce analogue gain so the loudest planned registration retains at least \(Int(protocolSnapshot.preferredHeadroomDB)) dB."
                    ))
                } else if headroom < protocolSnapshot.preferredHeadroomDB {
                    findings.append(finding(
                        "channel-\(number)-headroom-warning", .headroom, .warning, channels: [number],
                        title: "Channel \(number) has limited headroom",
                        detail: "\(assignment.role) retains \(formatDB(headroom, suffix: " dB")); pipe attacks and coupled plenums may exceed the rehearsal peak.",
                        remediation: "Consider lowering analogue gain to retain at least \(Int(protocolSnapshot.preferredHeadroomDB)) dB."
                    ))
                } else if peakDB < -30 {
                    findings.append(finding(
                        "channel-\(number)-low-gain", .lowGain, .warning, channels: [number],
                        title: "Channel \(number) is recorded very quietly",
                        detail: "\(assignment.role) peaked at \(formatDB(peakDB)).",
                        remediation: "Confirm that the loudest planned registration was sounded, then raise analogue gain if appropriate."
                    ))
                }

                if signalToNoise < protocolSnapshot.minimumSignalToNoiseDB {
                    findings.append(finding(
                        "channel-\(number)-snr-fail", .signalToNoise, .blocker, channels: [number],
                        title: "Channel \(number) lacks usable separation",
                        detail: "\(assignment.role) measured only \(formatDB(signalToNoise, suffix: " dB")) signal-to-room-noise ratio.",
                        remediation: "Check gain and microphone position, quiet the venue, then repeat the rehearsal."
                    ))
                } else if signalToNoise < protocolSnapshot.preferredSignalToNoiseDB {
                    findings.append(finding(
                        "channel-\(number)-snr-warning", .signalToNoise, .warning, channels: [number],
                        title: "Channel \(number) has modest signal-to-noise ratio",
                        detail: "\(assignment.role) measured \(formatDB(signalToNoise, suffix: " dB")); decay and low-level speech detail may be masked.",
                        remediation: "Reduce ambient noise or refine microphone position before critical capture."
                    ))
                }
            }
            if quietDB > protocolSnapshot.elevatedRoomToneDBFS {
                findings.append(finding(
                    "channel-\(number)-room-tone", .roomTone, .warning, channels: [number],
                    title: "Channel \(number) has elevated room tone",
                    detail: "\(assignment.role) measured \(formatDB(quietDB)) while the organ was silent.",
                    remediation: "Listen for blower, HVAC, traffic, electrical noise, or activity that may mask pipe decay."
                ))
            }
            let absoluteDC = abs(overall.mean)
            if absoluteDC > 0.03 {
                findings.append(finding(
                    "channel-\(number)-dc-fail", .dcOffset, .blocker, channels: [number],
                    title: "Channel \(number) has severe DC offset",
                    detail: "\(assignment.role) has a normalized mean offset of \(absoluteDC.formatted(.number.precision(.fractionLength(4)))).",
                    remediation: "Inspect the interface, preamplifier, and cable before recording."
                ))
            } else if absoluteDC > 0.01 {
                findings.append(finding(
                    "channel-\(number)-dc-warning", .dcOffset, .warning, channels: [number],
                    title: "Channel \(number) has measurable DC offset",
                    detail: "\(assignment.role) has a normalized mean offset of \(absoluteDC.formatted(.number.precision(.fractionLength(4)))).",
                    remediation: "Inspect the analogue signal path and repeat the rehearsal if the offset persists."
                ))
            }
        }

        let requiredChannels = Set(context.assignments.filter(\.isRequired).map(\.channelNumber)).filter { $0 > 0 }.sorted()
        if signalStart < analyzedFrames {
            for firstOffset in requiredChannels.indices {
                for secondOffset in requiredChannels.indices where secondOffset > firstOffset {
                    let firstNumber = requiredChannels[firstOffset]
                    let secondNumber = requiredChannels[secondOffset]
                    guard samples.indices.contains(firstNumber - 1), samples.indices.contains(secondNumber - 1) else { continue }
                    let first = samples[firstNumber - 1]
                    let second = samples[secondNumber - 1]
                    let end = min(first.count, second.count)
                    guard signalStart < end,
                          let comparison = compare(first, second, range: signalStart..<end),
                          abs(comparison.correlation) >= protocolSnapshot.duplicateCorrelationThreshold,
                          comparison.residualDB <= protocolSnapshot.duplicateResidualThresholdDB else { continue }
                    let inverted = comparison.correlation < 0
                    findings.append(finding(
                        "channels-\(firstNumber)-\(secondNumber)-\(inverted ? "inverted" : "duplicated")",
                        inverted ? .invertedRouting : .duplicatedRouting,
                        .blocker,
                        channels: [firstNumber, secondNumber],
                        title: inverted ? "Channels \(firstNumber) and \(secondNumber) are digitally inverted" : "Channels \(firstNumber) and \(secondNumber) are digitally duplicated",
                        detail: "The two assigned routes have correlation \(comparison.correlation.formatted(.number.precision(.fractionLength(6)))) and residual \(formatDB(comparison.residualDB, suffix: " dB")), consistent with the same digital feed rather than independent microphones.",
                        remediation: "Correct the interface or DAW routing, then repeat the rehearsal before spatial capture."
                    ))
                }
            }
        }

        let verdict: CapturePreflightVerdict
        if findings.contains(where: { $0.severity == .blocker }) {
            verdict = .failed
        } else if findings.contains(where: { $0.severity == .warning }) {
            verdict = .attention
        } else {
            verdict = .passed
        }
        return CapturePreflightReport(
            id: context.reportID,
            recordedAt: context.recordedAt,
            sessionID: context.sessionID,
            setupID: context.setupID,
            setupRevision: context.setupRevision,
            deviceSnapshot: context.deviceSnapshot,
            relativeAudioPath: context.relativeAudioPath,
            fileSize: context.fileSize,
            sha256: context.sha256,
            sampleRate: context.sampleRate,
            frameCount: context.frameCount,
            durationSeconds: duration,
            protocolSnapshot: protocolSnapshot,
            channels: channelResults,
            findings: findings,
            verdict: verdict,
            captureDiagnostics: context.captureDiagnostics,
            bwfMetadata: context.bwfMetadata,
            bwfFinalizationSucceeded: context.bwfFinalizationSucceeded
        )
    }

    private static func statistics(_ samples: [Float], range: Range<Int>) -> (rms: Double, peak: Double, mean: Double, clipped: Int64) {
        guard range.isEmpty == false else { return (0, 0, 0, 0) }
        var sum = 0.0
        var sumSquares = 0.0
        var peak = 0.0
        var clipped: Int64 = 0
        for index in range {
            let value = Double(samples[index])
            let magnitude = abs(value)
            sum += value
            sumSquares += value * value
            peak = max(peak, magnitude)
            if magnitude >= 0.999_969 { clipped += 1 }
        }
        let count = Double(range.count)
        return (sqrt(sumSquares / count), peak, sum / count, clipped)
    }

    private static func compare(_ first: [Float], _ second: [Float], range: Range<Int>) -> (correlation: Double, residualDB: Double)? {
        guard range.count >= 2 else { return nil }
        var firstSum = 0.0
        var secondSum = 0.0
        for index in range {
            firstSum += Double(first[index])
            secondSum += Double(second[index])
        }
        let count = Double(range.count)
        let firstMean = firstSum / count
        let secondMean = secondSum / count
        var xx = 0.0
        var yy = 0.0
        var xy = 0.0
        for index in range {
            let x = Double(first[index]) - firstMean
            let y = Double(second[index]) - secondMean
            xx += x * x
            yy += y * y
            xy += x * y
        }
        guard xx > 1e-18, yy > 1e-18 else { return nil }
        let correlation = xy / sqrt(xx * yy)
        let gain = xy / xx
        var residual = 0.0
        for index in range {
            let x = Double(first[index]) - firstMean
            let y = Double(second[index]) - secondMean
            let error = y - gain * x
            residual += error * error
        }
        let residualRatio = sqrt(max(1e-24, residual / yy))
        return (max(-1, min(1, correlation)), 20 * log10(residualRatio))
    }

    private static func decibels(_ linear: Double) -> Double {
        max(-120, 20 * log10(max(linear, 1e-6)))
    }

    private static func formatDB(_ value: Double, suffix: String = " dBFS") -> String {
        value.formatted(.number.precision(.fractionLength(1))) + suffix
    }

    private static func finding(
        _ id: String,
        _ kind: CapturePreflightFindingKind,
        _ severity: ConsistencySeverity,
        channels: [Int] = [],
        title: String,
        detail: String,
        remediation: String
    ) -> CapturePreflightFinding {
        CapturePreflightFinding(
            id: id,
            kind: kind,
            severity: severity,
            channelNumbers: channels,
            title: title,
            detail: detail,
            remediation: remediation
        )
    }
}
