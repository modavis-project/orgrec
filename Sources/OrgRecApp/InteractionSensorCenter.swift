import AudioToolbox
import Combine
import Darwin
import Foundation
import OrgRecCore

enum InteractionSensorConnectionState: Equatable {
    case disconnected
    case connecting
    case streaming
    case failed(String)

    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case .streaming: "Streaming"
        case .failed(let message): "Failed: \(message)"
        }
    }
}

enum InteractionSensorCheckState: String {
    case pass
    case warning
    case fail
    case pending
}

struct InteractionSensorCheck: Identifiable {
    var id: String
    var title: String
    var detail: String
    var state: InteractionSensorCheckState
}

struct InteractionSensorLivePoint: Identifiable, Sendable {
    var id: UInt64 { deviceMicroseconds }
    var deviceMicroseconds: UInt64
    var angleDegrees: Double
    var angularVelocityDPS: Double
    var accelerationMagnitudeG: Double
    var progress: Double?
}

private struct ActiveMotionEvent {
    var id = UUID()
    var startDeviceMicroseconds: UInt64
    var startHostNanoseconds: UInt64
    var startAngleDegrees: Double
    var minimumAngleDegrees: Double
    var maximumAngleDegrees: Double
    var peakAngularVelocityDPS: Double
    var signedPeakVelocityDPS: Double
    var lastMovingHostNanoseconds: UInt64
    var endpointOff = false
    var endpointOn = false
}

private struct PendingMIDINote {
    var note: Int
    var velocity: Int
    var hostNanoseconds: UInt64
}

private struct ActiveSensorCapture {
    var id: UUID
    var takeID: UUID
    var configuration: InteractionSensorConfiguration
    var calibration: InteractionSensorCalibration?
    var startedAt: Date
    var rawRelativePath: String
    var metadataRelativePath: String
    var derivedRelativePath: String
    var rawURL: URL
    var rawHandle: FileHandle
    var initialHealth: InteractionSensorHealthSnapshot
    var clockObservations: [SensorClockObservation]
    var preview: [InteractionSensorPreviewPoint]
    var firstMotionEventIndex: Int
    var packetCounter: Int
}

@MainActor
final class InteractionSensorCenter: ObservableObject, @unchecked Sendable {
    @Published private(set) var availableSerialPorts: [String] = []
    @Published private(set) var connectionState: InteractionSensorConnectionState = .disconnected
    @Published private(set) var activeConfigurationID: UUID?
    @Published private(set) var latestSample: InteractionSensorSample?
    @Published private(set) var latestAngleDegrees = 0.0
    @Published private(set) var latestProjectedAngularVelocityDPS = 0.0
    @Published private(set) var latestProgress: Double?
    @Published private(set) var livePoints: [InteractionSensorLivePoint] = []
    @Published private(set) var health = InteractionSensorHealthSnapshot()
    @Published private(set) var motionEvents: [InteractionMotionEvent] = []
    @Published private(set) var midiTrials: [MIDIVelocityMotionTrial] = []
    @Published private(set) var validationTrials: [InteractionValidationTrial] = []
    @Published private(set) var draftCalibration: InteractionSensorCalibration?
    @Published private(set) var isCapturingStationary = false
    @Published private(set) var stationaryWindowReady = false
    @Published private(set) var stationaryCaptureStatus = "Hold the control at neutral, then begin a fresh two-second window."
    @Published private(set) var isLearningMovement = false
    @Published private(set) var isCapturingTake = false
    private(set) var lastFinalizedDerivedData: InteractionSensorDerivedData?

    private var decoder = MPU6050PacketDecoder()
    private var serialHandle: FileHandle?
    private var simulationTimer: Timer?
    private var simulationSequence: UInt16 = 0
    private var simulationTimestamp: UInt32 = 0
    private var simulationElapsed = 0.0
    private var configuration: InteractionSensorConfiguration?
    private var calibration: InteractionSensorCalibration?
    private var lastSequence: UInt16?
    private var lastRawTimestamp: UInt32?
    private var lastUnwrappedTimestamp: UInt64?
    private var timestampEpoch: UInt64 = 0
    private var recentSamples: [InteractionSensorSample] = []
    private var stationaryCalibrationSamples: [InteractionSensorSample] = []
    private var activeStationarySamples: [InteractionSensorSample] = []
    private var movementLearningSamples: [InteractionSensorSample] = []
    private var firstRateDeviceMicroseconds: UInt64?
    private var firstRatePacketCount = 0
    private var fusedAngleDegrees = 0.0
    private var lastFusionDeviceMicroseconds: UInt64?
    private var activeMotion: ActiveMotionEvent?
    private var pendingMIDINotes: [PendingMIDINote] = []
    private var activeCapture: ActiveSensorCapture?
    private var lastDecoderCRCCount = 0
    private var lastDecoderDiscardedCount = 0
    private var lastDecoderInvalidCount = 0

    var isStreaming: Bool { connectionState == .streaming }

    var midiEvaluation: MIDIVelocityEvaluation {
        InteractionSensorProcessing.evaluateMIDIVelocity(midiTrials)
    }

    var validationSummary: InteractionValidationSummary {
        InteractionSensorProcessing.summarizeValidation(validationTrials)
    }

    var diagnosticChecks: [InteractionSensorCheck] {
        guard let configuration else {
            return [InteractionSensorCheck(id: "configuration", title: "Configuration", detail: "Create or select an experimental sensor configuration.", state: .pending)]
        }
        let nowHostNanoseconds = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime())
        let recent = latestSample.map {
            nowHostNanoseconds >= $0.hostReceiptNanoseconds
                ? Double(nowHostNanoseconds - $0.hostReceiptNanoseconds) / 1_000_000_000
                : 0
        } ?? .infinity
        let rate = health.observedSampleRateHz
        let rateError = rate.map { abs($0 - configuration.nominalSampleRateHz) / max(1, configuration.nominalSampleRateHz) }
        let acceleration = latestSample?.accelerationG.magnitude
        return [
            InteractionSensorCheck(
                id: "stream", title: "Live packet stream",
                detail: isStreaming ? (recent < 1 ? "Samples are arriving." : "No recent sample has arrived.") : "Connect the sensor to begin checks.",
                state: isStreaming ? (recent < 1 ? .pass : .fail) : .pending
            ),
            InteractionSensorCheck(
                id: "rate", title: "Sample rate",
                detail: rate.map { String(format: "%.1f Hz from device timestamps; %.0f Hz configured.", $0, configuration.nominalSampleRateHz) } ?? "Collecting device-time cadence…",
                state: rateError.map { $0 <= 0.05 ? .pass : ($0 <= 0.15 ? .warning : .fail) } ?? .pending
            ),
            InteractionSensorCheck(
                id: "gravity", title: "Gravity magnitude",
                detail: acceleration.map { String(format: "%.3f g; near 1 g is expected while still.", $0) } ?? "Waiting for acceleration data…",
                state: acceleration.map { (0.82...1.18).contains($0) ? .pass : .warning } ?? .pending
            ),
            InteractionSensorCheck(
                id: "integrity", title: "Packet integrity",
                detail: "\(health.crcErrors) CRC errors, \(health.lostPackets) lost, \(health.i2cErrors) I²C faults, \(health.timingOverruns) overruns.",
                state: health.crcErrors + health.i2cErrors > 0 ? .fail : (health.lostPackets + health.timingOverruns > 0 ? .warning : (health.receivedPackets > 0 ? .pass : .pending))
            ),
            InteractionSensorCheck(
                id: "range", title: "Sensor range",
                detail: health.saturations == 0 ? "No near-full-scale samples observed." : "\(health.saturations) samples approached the configured full scale.",
                state: health.saturations == 0 ? (health.receivedPackets > 0 ? .pass : .pending) : .fail
            ),
            InteractionSensorCheck(
                id: "motion-sensitivity", title: "Motion sensitivity",
                detail: String(
                    format: "%@ starts at %.1f °/s with %.1f °/s hysteresis.",
                    configuration.resolvedUseCase.displayName,
                    motionDetectionThresholds.startDPS,
                    motionDetectionThresholds.stopDPS
                ),
                state: health.receivedPackets > 0 ? .pass : .pending
            ),
            InteractionSensorCheck(
                id: "calibration", title: "Calibration",
                detail: calibration.map { String(format: "Quality %.0f%%; axis variance %.0f%%.", $0.qualityScore * 100, ($0.axisExplainedVariance ?? 0) * 100) } ?? "Stationary and movement calibration have not been accepted.",
                state: calibration.map { $0.qualityScore >= 0.8 && $0.warnings.isEmpty ? .pass : .warning } ?? .pending
            ),
            InteractionSensorCheck(
                id: "endpoints", title: "Endpoint state",
                detail: configuration.endpointInputsExpected ? (health.endpointConflicts == 0 ? "No conflicting endpoint inputs observed." : "Both endpoints were asserted together.") : "Independent endpoints are not configured.",
                state: configuration.endpointInputsExpected ? (health.endpointConflicts == 0 ? .pass : .fail) : (configuration.movementModel == .endpointConstrainedTranslation ? .warning : .pass)
            ),
        ]
    }

    init() {
        refreshSerialPorts()
    }

    func refreshSerialPorts() {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        availableSerialPorts = names
            .filter { $0.hasPrefix("cu.") || $0.hasPrefix("tty.") }
            .filter { $0.localizedCaseInsensitiveContains("Bluetooth-Incoming-Port") == false }
            .map { "/dev/\($0)" }
            .sorted()
    }

    func connect(configuration: InteractionSensorConfiguration, calibration: InteractionSensorCalibration?) throws {
        disconnect()
        self.configuration = configuration
        self.calibration = calibration
        activeConfigurationID = configuration.id
        resetStreamState()
        connectionState = .connecting
        switch configuration.transport {
        case .simulation:
            startSimulation()
            connectionState = .streaming
        case .serial:
            guard let path = configuration.portPath else {
                connectionState = .failed("No serial port selected")
                throw NSError(domain: "OrgRec.InteractionSensor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Select a serial port before connecting."])
            }
            let descriptor = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
            guard descriptor >= 0 else {
                let message = String(cString: strerror(errno))
                connectionState = .failed(message)
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not open \(path): \(message)"])
            }
            do {
                try configureSerial(descriptor: descriptor, baudRate: configuration.baudRate)
            } catch {
                Darwin.close(descriptor)
                connectionState = .failed(error.localizedDescription)
                throw error
            }
            let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
            handle.readabilityHandler = { [weak self] readable in
                let data = readable.availableData
                guard data.isEmpty == false else { return }
                let nanos = AudioConvertHostTimeToNanos(AudioGetCurrentHostTime())
                Task { @MainActor [weak self] in self?.ingest(data: data, receiptHostNanoseconds: nanos) }
            }
            serialHandle = handle
            connectionState = .streaming
        case .imported:
            connectionState = .failed("Import uses the offline capture importer")
            throw NSError(domain: "OrgRec.InteractionSensor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Imported captures do not open a live connection."])
        }
    }

    func disconnect() {
        if isCapturingTake { cancelCapture() }
        simulationTimer?.invalidate(); simulationTimer = nil
        serialHandle?.readabilityHandler = nil
        try? serialHandle?.close()
        serialHandle = nil
        connectionState = .disconnected
        activeConfigurationID = nil
        configuration = nil
        calibration = nil
    }

    func applyCalibration(_ calibration: InteractionSensorCalibration?) {
        self.calibration = calibration
        fusedAngleDegrees = 0
        lastFusionDeviceMicroseconds = nil
    }

    func beginStationaryCalibrationWindow() {
        guard isStreaming, isCapturingStationary == false else { return }
        activeStationarySamples = []
        stationaryWindowReady = false
        isCapturingStationary = true
        stationaryCaptureStatus = "Acquiring neutral… keep the control completely still."
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.finishStationaryCalibrationWindow()
        }
    }

    func beginMovementLearning() {
        movementLearningSamples = []
        isLearningMovement = true
    }

    @discardableResult
    func finishMovementLearning(referenceTravelDegrees: Double? = nil, referenceMethod: String? = nil) -> InteractionSensorCalibration? {
        isLearningMovement = false
        guard let configuration else { return nil }
        draftCalibration = InteractionSensorProcessing.calibration(
            configurationID: configuration.id,
            stationarySamples: stationaryCalibrationSamples,
            movementSamples: movementLearningSamples,
            referenceTravelDegrees: referenceTravelDegrees,
            referenceMethod: referenceMethod
        )
        return draftCalibration
    }

    func clearEvaluation() {
        midiTrials = []
        validationTrials = []
    }

    func observeMIDINote(note: Int, velocity: Int, hostNanoseconds: UInt64) {
        guard velocity > 0 else { return }
        pendingMIDINotes.append(PendingMIDINote(note: note, velocity: velocity, hostNanoseconds: hostNanoseconds))
        pendingMIDINotes.removeAll { pending in
            hostNanoseconds > pending.hostNanoseconds && hostNanoseconds - pending.hostNanoseconds > 1_000_000_000
        }
    }

    @discardableResult
    func addValidationTrial(reference: InteractionValidationReference, referenceTravelDegrees: Double?, referenceDurationSeconds: Double?, notes: String) -> Bool {
        guard let event = motionEvents.last else { return false }
        validationTrials.append(InteractionValidationTrial(
            motionEventID: event.id,
            reference: reference,
            measuredTravelDegrees: event.travelDegrees,
            referenceTravelDegrees: referenceTravelDegrees,
            measuredDurationSeconds: event.durationSeconds,
            referenceDurationSeconds: referenceDurationSeconds,
            notes: notes
        ))
        return true
    }

    func validationSession(environment: String, notes: String) -> InteractionSensorValidationSession? {
        guard let configuration else { return nil }
        return InteractionSensorValidationSession(
            configurationID: configuration.id,
            calibrationID: calibration?.id,
            environment: environment,
            trials: validationTrials,
            midiTrials: midiTrials,
            midiEvaluation: midiEvaluation,
            summary: validationSummary,
            notes: notes
        )
    }

    func beginCapture(packageURL: URL, takeID: UUID, configuration: InteractionSensorConfiguration, calibration: InteractionSensorCalibration?) throws {
        guard isStreaming, activeConfigurationID == configuration.id, activeCapture == nil else {
            throw NSError(domain: "OrgRec.InteractionSensor", code: 3, userInfo: [NSLocalizedDescriptionKey: "The exact interaction-sensor configuration is not streaming or is already capturing."])
        }
        let captureID = UUID()
        let stem = "\(takeID.uuidString.lowercased())-\(captureID.uuidString.lowercased())"
        let rawRelative = "Sensors/Raw/\(stem).imu"
        let metadataRelative = "Metadata/SensorCaptures/\(stem).json"
        let derivedRelative = "Sensors/Derived/\(stem).json"
        let rawURL = packageURL.appendingPathComponent(rawRelative)
        try FileManager.default.createDirectory(at: rawURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: rawURL.path, contents: nil) else {
            throw NSError(domain: "OrgRec.InteractionSensor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not create the raw interaction-sensor capture."])
        }
        activeCapture = ActiveSensorCapture(
            id: captureID,
            takeID: takeID,
            configuration: configuration,
            calibration: calibration,
            startedAt: .now,
            rawRelativePath: rawRelative,
            metadataRelativePath: metadataRelative,
            derivedRelativePath: derivedRelative,
            rawURL: rawURL,
            rawHandle: try FileHandle(forWritingTo: rawURL),
            initialHealth: health,
            clockObservations: [],
            preview: [],
            firstMotionEventIndex: motionEvents.count,
            packetCounter: 0
        )
        isCapturingTake = true
    }

    func endCapture(packageURL: URL, audioStartHostNanoseconds: UInt64?) throws -> InteractionSensorCaptureRecord? {
        guard var capture = activeCapture else { return nil }
        var finalizedDerivedData: InteractionSensorDerivedData?
        defer {
            // Finalization can fail while flushing the raw stream, deriving data, hashing,
            // or writing metadata. Never leave the center pointing at a closed capture in
            // any of those cases. Deliberately do not delete the raw file: it is the primary
            // evidence and can be recovered or inspected after a failed finalization.
            try? capture.rawHandle.close()
            activeCapture = nil
            isCapturingTake = false
            lastFinalizedDerivedData = finalizedDerivedData
        }
        if let latestSample,
           capture.clockObservations.last?.deviceMicroseconds != latestSample.unwrappedDeviceMicroseconds {
            capture.clockObservations.append(SensorClockObservation(
                deviceMicroseconds: latestSample.unwrappedDeviceMicroseconds,
                hostNanoseconds: latestSample.hostReceiptNanoseconds
            ))
        }
        try capture.rawHandle.synchronize()
        try capture.rawHandle.close()
        var captureHealth = healthDelta(from: capture.initialHealth, to: health)
        captureHealth.startedAt = capture.startedAt
        captureHealth.endedAt = .now
        let alignment = InteractionSensorProcessing.fitClock(
            observations: capture.clockObservations,
            audioStartHostNanoseconds: audioStartHostNanoseconds,
            nominalSampleRateHz: capture.configuration.nominalSampleRateHz,
            serialBaudRate: capture.configuration.baudRate
        )
        var events = Array(motionEvents.dropFirst(capture.firstMotionEventIndex))
        if let segment = alignment.segments.first {
            for index in events.indices {
                events[index].audioStartSeconds = segment.audioSeconds(for: events[index].deviceStartMicroseconds)
                events[index].audioEndSeconds = segment.audioSeconds(for: events[index].deviceEndMicroseconds)
            }
            for index in capture.preview.indices {
                capture.preview[index].audioSeconds = segment.audioSeconds(for: capture.preview[index].deviceMicroseconds)
            }
        }
        let derived = InteractionSensorDerivedData(
            captureID: capture.id,
            processingIdentifier: "orgrec-native-imu/v2-experimental",
            preview: capture.preview,
            motionEvents: events
        )
        let derivedURL = packageURL.appendingPathComponent(capture.derivedRelativePath)
        try FileManager.default.createDirectory(at: derivedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try OrgRecCoding.encoder.encode(derived).write(to: derivedURL, options: .atomic)
        let values = try capture.rawURL.resourceValues(forKeys: [.fileSizeKey])
        let record = InteractionSensorCaptureRecord(
            id: capture.id,
            takeID: capture.takeID,
            configurationSnapshot: capture.configuration,
            calibrationSnapshot: capture.calibration,
            startedAt: capture.startedAt,
            endedAt: .now,
            rawRelativePath: capture.rawRelativePath,
            rawSHA256: try sha256(of: capture.rawURL),
            rawByteCount: Int64(values.fileSize ?? 0),
            metadataRelativePath: capture.metadataRelativePath,
            derivedRelativePath: capture.derivedRelativePath,
            health: captureHealth,
            clockAlignment: alignment,
            motionEventCount: events.count,
            processingIdentifier: "orgrec-native-imu/v2-experimental",
            experimentalLimitations: [
                "The sensor clock is independent of the audio clock unless a hardware synchronization pulse is documented.",
                "Host-receipt alignment includes USB and serial buffering uncertainty.",
                "Motion estimates are valid only for the configured constrained mechanism and accepted calibration.",
            ]
        )
        let metadataURL = packageURL.appendingPathComponent(capture.metadataRelativePath)
        try FileManager.default.createDirectory(at: metadataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try OrgRecCoding.encoder.encode(record).write(to: metadataURL, options: .atomic)
        finalizedDerivedData = derived
        return record
    }

    func cancelCapture() {
        guard let capture = activeCapture else { return }
        try? capture.rawHandle.close()
        try? FileManager.default.removeItem(at: capture.rawURL)
        activeCapture = nil
        isCapturingTake = false
        lastFinalizedDerivedData = nil
    }

    private func resetStreamState() {
        decoder = MPU6050PacketDecoder()
        lastDecoderCRCCount = 0; lastDecoderDiscardedCount = 0; lastDecoderInvalidCount = 0
        latestSample = nil; livePoints = []; health = InteractionSensorHealthSnapshot()
        lastSequence = nil; lastRawTimestamp = nil; lastUnwrappedTimestamp = nil; timestampEpoch = 0
        recentSamples = []; stationaryCalibrationSamples = []; movementLearningSamples = []
        activeStationarySamples = []; isCapturingStationary = false; stationaryWindowReady = false
        stationaryCaptureStatus = "Hold the control at neutral, then begin a fresh two-second window."
        firstRateDeviceMicroseconds = nil; firstRatePacketCount = 0
        fusedAngleDegrees = 0; lastFusionDeviceMicroseconds = nil; activeMotion = nil
        motionEvents = []; midiTrials = []; validationTrials = []; pendingMIDINotes = []; draftCalibration = nil
        lastFinalizedDerivedData = nil
    }

    private func configureSerial(descriptor: Int32, baudRate: Int) throws {
        var attributes = termios()
        guard tcgetattr(descriptor, &attributes) == 0 else { throw POSIXError(.EIO) }
        cfmakeraw(&attributes)
        attributes.c_cflag |= tcflag_t(CLOCAL | CREAD)
        attributes.c_cflag &= ~tcflag_t(CSTOPB | PARENB | CRTSCTS)
        attributes.c_cflag = (attributes.c_cflag & ~tcflag_t(CSIZE)) | tcflag_t(CS8)
        let speed = speed_t(baudRate)
        guard cfsetispeed(&attributes, speed) == 0, cfsetospeed(&attributes, speed) == 0,
              tcsetattr(descriptor, TCSANOW, &attributes) == 0 else { throw POSIXError(.EINVAL) }
        tcflush(descriptor, TCIOFLUSH)
    }

    private func startSimulation() {
        simulationSequence = 0; simulationTimestamp = 0; simulationElapsed = 0
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.emitSimulationBatch() }
        }
    }

    private func emitSimulationBatch() {
        guard let configuration else { return }
        let samplePeriod = 1 / max(1, configuration.nominalSampleRateHz)
        let samplesPerBatch = max(1, Int((0.02 / samplePeriod).rounded()))
        var data = Data()
        for _ in 0..<samplesPerBatch {
            simulationElapsed += samplePeriod
            simulationTimestamp &+= UInt32((samplePeriod * 1_000_000).rounded())
            simulationSequence &+= 1
            let phase = simulationElapsed.truncatingRemainder(dividingBy: 5.0)
            let angle: Double
            let angularVelocity: Double
            if phase < 2.2 { angle = 0; angularVelocity = 0 }
            else if phase < 2.5 {
                let u = (phase - 2.2) / 0.30
                angle = 12 * (u * u * (3 - 2 * u))
                angularVelocity = 12 * (6 * u - 6 * u * u) / 0.30
            } else if phase < 3.2 { angle = 12; angularVelocity = 0 }
            else if phase < 3.55 {
                let u = (phase - 3.2) / 0.35
                angle = 12 * (1 - u * u * (3 - 2 * u))
                angularVelocity = -12 * (6 * u - 6 * u * u) / 0.35
            } else { angle = 0; angularVelocity = 0 }
            let radians = angle * .pi / 180
            let noise = sin(simulationElapsed * 97) * 0.08
            let raw = MPU6050RawSample(
                sequence: simulationSequence,
                timestampMicroseconds: simulationTimestamp,
                accelerometerX: 0,
                accelerometerY: Int16(max(-32_000, min(32_000, (sin(radians) * 8_192).rounded()))),
                accelerometerZ: Int16(max(-32_000, min(32_000, (cos(radians) * 8_192).rounded()))),
                temperatureRaw: 0,
                gyroscopeX: Int16(max(-32_000, min(32_000, ((angularVelocity + noise) * 65.5).rounded()))),
                gyroscopeY: Int16((noise * 0.2 * 65.5).rounded()),
                gyroscopeZ: Int16((noise * 0.1 * 65.5).rounded()),
                status: 0x01 | 0x10 | (abs(angularVelocity) < 1 ? 0x02 : 0)
            )
            data.append(MPU6050PacketDecoder.encode(raw))
        }
        ingest(data: data, receiptHostNanoseconds: AudioConvertHostTimeToNanos(AudioGetCurrentHostTime()))
    }

    private func ingest(data: Data, receiptHostNanoseconds: UInt64) {
        if let capture = activeCapture {
            do { try capture.rawHandle.write(contentsOf: data) } catch {
                connectionState = .failed("Raw capture write failed: \(error.localizedDescription)")
            }
        }
        let packets = decoder.feed(data)
        health.crcErrors += decoder.crcErrorCount - lastDecoderCRCCount
        health.discardedBytes += decoder.discardedByteCount - lastDecoderDiscardedCount
        health.invalidPackets += decoder.invalidPacketCount - lastDecoderInvalidCount
        lastDecoderCRCCount = decoder.crcErrorCount
        lastDecoderDiscardedCount = decoder.discardedByteCount
        lastDecoderInvalidCount = decoder.invalidPacketCount
        let wireNanoseconds = configuration.map { UInt64(max(0, Double(MPU6050PacketDecoder.packetSize * 10) / Double(max(1, $0.baudRate)) * 1_000_000_000)) } ?? 0
        for (index, packet) in packets.enumerated() {
            let packetsAfter = packets.count - index - 1
            let estimatedHost = receiptHostNanoseconds > UInt64(packetsAfter) * wireNanoseconds
                ? receiptHostNanoseconds - UInt64(packetsAfter) * wireNanoseconds
                : receiptHostNanoseconds
            process(packet: packet, hostNanoseconds: estimatedHost)
        }
    }

    private func process(packet: MPU6050RawSample, hostNanoseconds: UInt64) {
        let unwrapped = unwrap(packet.timestampMicroseconds)
        let sample = InteractionSensorSample(raw: packet, unwrappedDeviceMicroseconds: unwrapped, hostReceiptNanoseconds: hostNanoseconds)
        if let lastSequence {
            let delta = Int(UInt16(truncatingIfNeeded: packet.sequence &- lastSequence))
            if delta > 1 && delta < 32_768 { health.lostPackets += delta - 1 }
        }
        self.lastSequence = packet.sequence
        health.receivedPackets += 1
        if packet.i2cError { health.i2cErrors += 1 }
        if packet.timingOverrun { health.timingOverruns += 1 }
        if packet.endpointOff && packet.endpointOn { health.endpointConflicts += 1 }
        let nearLimit = [packet.accelerometerX, packet.accelerometerY, packet.accelerometerZ,
                         packet.gyroscopeX, packet.gyroscopeY, packet.gyroscopeZ].contains { abs(Int($0)) >= 32_000 }
        if nearLimit { health.saturations += 1 }
        if let last = lastUnwrappedTimestamp {
            let gap = Double(unwrapped - last) / 1_000_000
            health.maximumPacketGapSeconds = max(health.maximumPacketGapSeconds, gap)
        }
        lastUnwrappedTimestamp = unwrapped
        updateObservedRate(deviceMicroseconds: unwrapped)
        recentSamples.append(sample)
        let maximumSamples = max(800, Int((configuration?.nominalSampleRateHz ?? 200) * 10))
        if recentSamples.count > maximumSamples { recentSamples.removeFirst(recentSamples.count - maximumSamples) }
        if isCapturingStationary { activeStationarySamples.append(sample) }
        if isLearningMovement { movementLearningSamples.append(sample) }
        updateFusionAndEvents(sample)
        latestSample = sample
    }

    private func unwrap(_ timestamp: UInt32) -> UInt64 {
        defer { lastRawTimestamp = timestamp }
        guard let last = lastRawTimestamp else { return UInt64(timestamp) }
        if timestamp < last {
            if last > 0xF000_0000 && timestamp < 0x0FFF_FFFF {
                timestampEpoch += UInt64(UInt32.max) + 1
            } else {
                health.resetDiscontinuities += 1
                timestampEpoch = (lastUnwrappedTimestamp ?? 0) + UInt64(1_000_000 / max(1, configuration?.nominalSampleRateHz ?? 200)) - UInt64(timestamp)
            }
        }
        return timestampEpoch + UInt64(timestamp)
    }

    private func updateObservedRate(deviceMicroseconds: UInt64) {
        if firstRateDeviceMicroseconds == nil {
            firstRateDeviceMicroseconds = deviceMicroseconds
            firstRatePacketCount = health.receivedPackets
            return
        }
        guard let first = firstRateDeviceMicroseconds, deviceMicroseconds >= first else { return }
        let elapsed = Double(deviceMicroseconds - first) / 1_000_000
        if elapsed >= 1 {
            health.observedSampleRateHz = Double(health.receivedPackets - firstRatePacketCount) / elapsed
            firstRateDeviceMicroseconds = deviceMicroseconds
            firstRatePacketCount = health.receivedPackets
        }
    }

    private func updateFusionAndEvents(_ sample: InteractionSensorSample) {
        let axis = calibration?.hingeAxisUnit ?? .unitX
        let bias = calibration?.gyroBiasDPS ?? .zero
        let projected = (sample.angularVelocityDPS - bias).dot(axis)
        if let last = lastFusionDeviceMicroseconds {
            let dt = Double(sample.unwrappedDeviceMicroseconds - last) / 1_000_000
            if dt > 0, dt < 0.1 {
                fusedAngleDegrees += projected * dt
                if let calibration,
                   calibration.gravityIsObservable,
                   (0.88...1.12).contains(sample.accelerationG.magnitude),
                   let gravityAngle = InteractionSensorProcessing.signedGravityAngleDegrees(
                       current: sample.accelerationG, neutral: calibration.neutralGravityUnit, axis: axis
                   ) {
                    let trust = min(0.04, max(0.004, 0.02 * (1 - min(abs(projected) / 400, 0.8))))
                    fusedAngleDegrees = (1 - trust) * fusedAngleDegrees + trust * gravityAngle
                }
            }
        }
        lastFusionDeviceMicroseconds = sample.unwrappedDeviceMicroseconds
        let travel = calibration?.referenceTravelDegrees ?? calibration?.estimatedTravelDegrees
        let progress = travel.flatMap { abs($0) > 0.1 ? min(max(fusedAngleDegrees / $0, 0), 1) : nil }
        latestAngleDegrees = fusedAngleDegrees
        latestProjectedAngularVelocityDPS = projected
        latestProgress = progress
        let point = InteractionSensorLivePoint(
            deviceMicroseconds: sample.unwrappedDeviceMicroseconds,
            angleDegrees: fusedAngleDegrees,
            angularVelocityDPS: projected,
            accelerationMagnitudeG: sample.accelerationG.magnitude,
            progress: progress
        )
        livePoints.append(point)
        if livePoints.count > 400 { livePoints.removeFirst(livePoints.count - 400) }
        updateMotionEvent(sample: sample, point: point)
        if var capture = activeCapture {
            capture.packetCounter += 1
            if capture.clockObservations.isEmpty || capture.packetCounter.isMultiple(of: 100) {
                capture.clockObservations.append(SensorClockObservation(deviceMicroseconds: sample.unwrappedDeviceMicroseconds, hostNanoseconds: sample.hostReceiptNanoseconds))
            }
            if capture.packetCounter.isMultiple(of: 10) {
                capture.preview.append(InteractionSensorPreviewPoint(
                    deviceMicroseconds: point.deviceMicroseconds,
                    angleDegrees: point.angleDegrees,
                    angularVelocityDPS: point.angularVelocityDPS,
                    accelerationMagnitudeG: point.accelerationMagnitudeG,
                    progress: point.progress
                ))
            }
            activeCapture = capture
        }
    }

    private func finishStationaryCalibrationWindow() {
        guard isCapturingStationary else { return }
        isCapturingStationary = false
        let expected = max(40, Int((configuration?.nominalSampleRateHz ?? 200) * 1.7))
        let stable = activeStationarySamples.filter {
            $0.angularVelocityDPS.magnitude < 3 && (0.90...1.10).contains($0.accelerationG.magnitude)
        }
        let hadMotion = stable.count < activeStationarySamples.count * 9 / 10
        guard activeStationarySamples.count >= expected, stable.count >= expected, hadMotion == false else {
            stationaryWindowReady = false
            stationaryCaptureStatus = "Neutral capture rejected: movement, implausible gravity, or missing packets were detected. Try again."
            activeStationarySamples = []
            return
        }
        stationaryCalibrationSamples = stable
        stationaryWindowReady = true
        stationaryCaptureStatus = "Neutral window captured from \(stable.count) stable samples."
        activeStationarySamples = []
    }

    private func updateMotionEvent(sample: InteractionSensorSample, point: InteractionSensorLivePoint) {
        let thresholds = motionDetectionThresholds
        let startsMoving = abs(point.angularVelocityDPS) >= thresholds.startDPS
        let remainsMoving = abs(point.angularVelocityDPS) >= thresholds.stopDPS
        if activeMotion == nil, startsMoving {
            activeMotion = ActiveMotionEvent(
                startDeviceMicroseconds: sample.unwrappedDeviceMicroseconds,
                startHostNanoseconds: sample.hostReceiptNanoseconds,
                startAngleDegrees: point.angleDegrees,
                minimumAngleDegrees: point.angleDegrees,
                maximumAngleDegrees: point.angleDegrees,
                peakAngularVelocityDPS: abs(point.angularVelocityDPS),
                signedPeakVelocityDPS: point.angularVelocityDPS,
                lastMovingHostNanoseconds: sample.hostReceiptNanoseconds,
                endpointOff: sample.raw.endpointOff,
                endpointOn: sample.raw.endpointOn
            )
            return
        }
        guard var active = activeMotion else { return }
        active.minimumAngleDegrees = min(active.minimumAngleDegrees, point.angleDegrees)
        active.maximumAngleDegrees = max(active.maximumAngleDegrees, point.angleDegrees)
        if abs(point.angularVelocityDPS) > active.peakAngularVelocityDPS {
            active.peakAngularVelocityDPS = abs(point.angularVelocityDPS)
            active.signedPeakVelocityDPS = point.angularVelocityDPS
        }
        active.endpointOff = active.endpointOff || sample.raw.endpointOff
        active.endpointOn = active.endpointOn || sample.raw.endpointOn
        if remainsMoving { active.lastMovingHostNanoseconds = sample.hostReceiptNanoseconds }
        let quietNanos = sample.hostReceiptNanoseconds >= active.lastMovingHostNanoseconds
            ? sample.hostReceiptNanoseconds - active.lastMovingHostNanoseconds : 0
        guard quietNanos >= thresholds.quietNanoseconds else { activeMotion = active; return }
        let duration = Double(sample.unwrappedDeviceMicroseconds - active.startDeviceMicroseconds) / 1_000_000
        let event = InteractionMotionEvent(
            id: active.id,
            deviceStartMicroseconds: active.startDeviceMicroseconds,
            deviceEndMicroseconds: sample.unwrappedDeviceMicroseconds,
            hostStartNanoseconds: active.startHostNanoseconds,
            hostEndNanoseconds: sample.hostReceiptNanoseconds,
            travelDegrees: active.maximumAngleDegrees - active.minimumAngleDegrees,
            peakAngularVelocityDPS: active.peakAngularVelocityDPS,
            durationSeconds: duration,
            direction: active.signedPeakVelocityDPS >= 0 ? 1 : -1,
            completedEndpointState: active.endpointOn && !active.endpointOff ? "on" : (active.endpointOff && !active.endpointOn ? "off" : nil)
        )
        motionEvents.append(event)
        pairPendingMIDI(with: event)
        activeMotion = nil
    }

    private var motionDetectionThresholds: (startDPS: Double, stopDPS: Double, quietNanoseconds: UInt64) {
        let useCase = configuration?.resolvedUseCase ?? .exploratory
        let base: (Double, UInt64)
        switch useCase {
        case .representativeKeyAction:
            base = (8, 150_000_000)
        case .pedalOrContinuousControl:
            base = (1.5, 350_000_000)
        case .stopOrAccessory:
            base = (3, 250_000_000)
        case .mechanicalActionNoise:
            base = (5, 180_000_000)
        case .exploratory:
            base = (4, 250_000_000)
        }
        let noise = calibration?.gyroNoiseRMSDPS ?? 0
        let start = max(base.0, noise * 6)
        let stop = max(0.6, start * 0.5)
        return (start, stop, base.1)
    }

    private func pairPendingMIDI(with event: InteractionMotionEvent) {
        guard let matchIndex = pendingMIDINotes.indices.min(by: {
            absoluteNanosecondDifference(pendingMIDINotes[$0].hostNanoseconds, event.hostStartNanoseconds)
                < absoluteNanosecondDifference(pendingMIDINotes[$1].hostNanoseconds, event.hostStartNanoseconds)
        }) else { return }
        let pending = pendingMIDINotes[matchIndex]
        guard absoluteNanosecondDifference(pending.hostNanoseconds, event.hostStartNanoseconds) <= 500_000_000 else { return }
        let latency = (Double(pending.hostNanoseconds) - Double(event.hostStartNanoseconds)) / 1_000_000_000
        midiTrials.append(MIDIVelocityMotionTrial(
            midiNote: pending.note,
            midiVelocity: pending.velocity,
            motionEventID: event.id,
            motionStartToMIDISeconds: latency,
            peakAngularVelocityDPS: event.peakAngularVelocityDPS,
            travelDegrees: event.travelDegrees,
            durationSeconds: event.durationSeconds
        ))
        pendingMIDINotes.remove(at: matchIndex)
    }

    private func absoluteNanosecondDifference(_ a: UInt64, _ b: UInt64) -> UInt64 { a >= b ? a - b : b - a }

    private func healthDelta(from initial: InteractionSensorHealthSnapshot, to final: InteractionSensorHealthSnapshot) -> InteractionSensorHealthSnapshot {
        InteractionSensorHealthSnapshot(
            receivedPackets: max(0, final.receivedPackets - initial.receivedPackets),
            lostPackets: max(0, final.lostPackets - initial.lostPackets),
            crcErrors: max(0, final.crcErrors - initial.crcErrors),
            discardedBytes: max(0, final.discardedBytes - initial.discardedBytes),
            invalidPackets: max(0, final.invalidPackets - initial.invalidPackets),
            i2cErrors: max(0, final.i2cErrors - initial.i2cErrors),
            timingOverruns: max(0, final.timingOverruns - initial.timingOverruns),
            saturations: max(0, final.saturations - initial.saturations),
            resetDiscontinuities: max(0, final.resetDiscontinuities - initial.resetDiscontinuities),
            endpointConflicts: max(0, final.endpointConflicts - initial.endpointConflicts),
            observedSampleRateHz: final.observedSampleRateHz,
            maximumPacketGapSeconds: final.maximumPacketGapSeconds,
            startedAt: initial.startedAt,
            endedAt: final.endedAt
        )
    }
}
