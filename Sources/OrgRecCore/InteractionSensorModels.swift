import Foundation

// MARK: - Experimental interaction-sensor contracts

public struct SensorVector3: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = SensorVector3(x: 0, y: 0, z: 0)
    public static let unitX = SensorVector3(x: 1, y: 0, z: 0)

    public var magnitude: Double { sqrt(x * x + y * y + z * z) }

    public func normalized(or fallback: SensorVector3 = .unitX) -> SensorVector3 {
        let length = magnitude
        guard length.isFinite, length > 0.000_000_1 else { return fallback }
        return self / length
    }

    public func dot(_ other: SensorVector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    public func cross(_ other: SensorVector3) -> SensorVector3 {
        SensorVector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    public static func +(lhs: SensorVector3, rhs: SensorVector3) -> SensorVector3 {
        SensorVector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func -(lhs: SensorVector3, rhs: SensorVector3) -> SensorVector3 {
        SensorVector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static func *(lhs: SensorVector3, rhs: Double) -> SensorVector3 {
        SensorVector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    public static func /(lhs: SensorVector3, rhs: Double) -> SensorVector3 {
        SensorVector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }
}

public enum InteractionSensorTransport: String, Codable, CaseIterable, Identifiable, Sendable {
    case serial
    case simulation
    case imported

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .serial: "USB serial"
        case .simulation: "Simulation"
        case .imported: "Imported capture"
        }
    }
}

public enum InteractionMovementModel: String, Codable, CaseIterable, Identifiable, Sendable {
    case hinge
    case endpointConstrainedTranslation
    case angularRateOnly

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .hinge: "Hinge (key or pedal)"
        case .endpointConstrainedTranslation: "Endpoint-constrained stop"
        case .angularRateOnly: "Angular dynamics only"
        }
    }
}

public enum InteractionSensorUseCase: String, Codable, CaseIterable, Identifiable, Sendable {
    case representativeKeyAction
    case pedalOrContinuousControl
    case stopOrAccessory
    case mechanicalActionNoise
    case exploratory

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .representativeKeyAction: "Representative key action"
        case .pedalOrContinuousControl: "Pedal / continuous control"
        case .stopOrAccessory: "Stop / accessory motion"
        case .mechanicalActionNoise: "Mechanical action noise"
        case .exploratory: "Exploratory motion"
        }
    }

    public var guidance: String {
        switch self {
        case .representativeKeyAction:
            "Keep the IMU on one representative key or pedal and record key-down, held sound, key-up, and the full acoustic tail. Remounting requires recalibration."
        case .pedalOrContinuousControl:
            "Use for swell shoes and other constrained continuous controls; prioritize calibrated position and timing rather than per-pipe note capture."
        case .stopOrAccessory:
            "Use for drawknobs, tablets, combination pistons, tremulants, and other controls whose mechanical transition is itself under study."
        case .mechanicalActionNoise:
            "Use when the actuator noise and motion profile are the intended evidence; retain room tone before touching the mechanism."
        case .exploratory:
            "Retain raw motion as exploratory evidence without treating it as a validated physical or acoustic-response measurement."
        }
    }
}

public enum InteractionSensorCapturePolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case disabled
    case optional
    case required

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .disabled: "Off"
        case .optional: "Available per take"
        case .required: "Legacy required (treated as optional)"
        }
    }
}

public enum InteractionSensorValidationState: String, Codable, CaseIterable, Identifiable, Sendable {
    case unvalidated
    case provisional
    case acceptedForExperiment
    case failed

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .unvalidated: "Unvalidated"
        case .provisional: "Provisional"
        case .acceptedForExperiment: "Accepted for experiment"
        case .failed: "Failed validation"
        }
    }
}

public struct InteractionSensorConfiguration: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var name: String
    public var experimental: Bool
    public var capturePolicy: InteractionSensorCapturePolicy
    public var transport: InteractionSensorTransport
    public var portPath: String?
    public var baudRate: Int
    public var nodeIdentifier: String
    public var sensorDeviceID: UUID?
    public var targetComponentID: String?
    public var targetComponentLabel: String
    public var useCase: InteractionSensorUseCase?
    public var movementModel: InteractionMovementModel
    public var nominalSampleRateHz: Double
    public var gyroFullScaleDPS: Double
    public var accelerometerFullScaleG: Double
    public var hingeRadiusMillimeters: Double?
    public var knownStrokeMillimeters: Double?
    public var endpointInputsExpected: Bool
    public var currentCalibrationID: UUID?
    public var validationState: InteractionSensorValidationState
    public var firmwareIdentifier: String
    public var protocolIdentifier: String
    public var notes: String

    public init(
        contractVersion: String = "orgrec.interaction-sensor-configuration/v1-experimental",
        id: UUID = UUID(),
        name: String = "Experimental IMU",
        experimental: Bool = true,
        capturePolicy: InteractionSensorCapturePolicy = .optional,
        transport: InteractionSensorTransport = .simulation,
        portPath: String? = nil,
        baudRate: Int = 230_400,
        nodeIdentifier: String = "imu-node-1",
        sensorDeviceID: UUID? = nil,
        targetComponentID: String? = nil,
        targetComponentLabel: String = "Unassigned organ control",
        useCase: InteractionSensorUseCase? = .representativeKeyAction,
        movementModel: InteractionMovementModel = .hinge,
        nominalSampleRateHz: Double = 200,
        gyroFullScaleDPS: Double = 500,
        accelerometerFullScaleG: Double = 4,
        hingeRadiusMillimeters: Double? = nil,
        knownStrokeMillimeters: Double? = nil,
        endpointInputsExpected: Bool = false,
        currentCalibrationID: UUID? = nil,
        validationState: InteractionSensorValidationState = .unvalidated,
        firmwareIdentifier: String = "organ_imu_node packet-v1",
        protocolIdentifier: String = "mpu6050-serial-v1",
        notes: String = ""
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.name = name
        self.experimental = experimental
        self.capturePolicy = capturePolicy
        self.transport = transport
        self.portPath = portPath
        self.baudRate = baudRate
        self.nodeIdentifier = nodeIdentifier
        self.sensorDeviceID = sensorDeviceID
        self.targetComponentID = targetComponentID
        self.targetComponentLabel = targetComponentLabel
        self.useCase = useCase
        self.movementModel = movementModel
        self.nominalSampleRateHz = nominalSampleRateHz
        self.gyroFullScaleDPS = gyroFullScaleDPS
        self.accelerometerFullScaleG = accelerometerFullScaleG
        self.hingeRadiusMillimeters = hingeRadiusMillimeters
        self.knownStrokeMillimeters = knownStrokeMillimeters
        self.endpointInputsExpected = endpointInputsExpected
        self.currentCalibrationID = currentCalibrationID
        self.validationState = validationState
        self.firmwareIdentifier = firmwareIdentifier
        self.protocolIdentifier = protocolIdentifier
        self.notes = notes
    }

    public var validationIssues: [String] {
        var issues: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Name is required.") }
        if nominalSampleRateHz <= 0 || nominalSampleRateHz > 2_000 { issues.append("Sample rate must be between 0 and 2,000 Hz.") }
        if gyroFullScaleDPS <= 0 { issues.append("Gyroscope range must be positive.") }
        if accelerometerFullScaleG <= 0 { issues.append("Accelerometer range must be positive.") }
        if transport == .serial && (portPath?.hasPrefix("/dev/cu.") != true && portPath?.hasPrefix("/dev/tty.") != true) {
            issues.append("Select a serial device under /dev/cu.* or /dev/tty.*.")
        }
        if movementModel == .endpointConstrainedTranslation && endpointInputsExpected == false {
            issues.append("A stop-state experiment should use independent endpoint inputs.")
        }
        return issues
    }

    public var resolvedUseCase: InteractionSensorUseCase { useCase ?? .exploratory }
}

public struct InteractionSensorCalibration: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var configurationID: UUID
    public var createdAt: Date
    public var method: String
    public var stationarySampleCount: Int
    public var movementSampleCount: Int
    public var gyroBiasDPS: SensorVector3
    public var gyroNoiseRMSDPS: Double
    public var neutralGravityUnit: SensorVector3
    public var hingeAxisUnit: SensorVector3
    public var estimatedTravelDegrees: Double?
    public var axisExplainedVariance: Double?
    public var gravityIsObservable: Bool
    public var referenceTravelDegrees: Double?
    public var referenceMethod: String?
    public var temperatureCelsius: Double?
    public var qualityScore: Double
    public var warnings: [String]

    public init(
        contractVersion: String = "orgrec.interaction-sensor-calibration/v1-experimental",
        id: UUID = UUID(),
        configurationID: UUID,
        createdAt: Date = .now,
        method: String = "stationary bias + gyroscope PCA hinge axis + gravity reference",
        stationarySampleCount: Int,
        movementSampleCount: Int,
        gyroBiasDPS: SensorVector3,
        gyroNoiseRMSDPS: Double,
        neutralGravityUnit: SensorVector3,
        hingeAxisUnit: SensorVector3,
        estimatedTravelDegrees: Double? = nil,
        axisExplainedVariance: Double? = nil,
        gravityIsObservable: Bool,
        referenceTravelDegrees: Double? = nil,
        referenceMethod: String? = nil,
        temperatureCelsius: Double? = nil,
        qualityScore: Double,
        warnings: [String] = []
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.configurationID = configurationID
        self.createdAt = createdAt
        self.method = method
        self.stationarySampleCount = stationarySampleCount
        self.movementSampleCount = movementSampleCount
        self.gyroBiasDPS = gyroBiasDPS
        self.gyroNoiseRMSDPS = gyroNoiseRMSDPS
        self.neutralGravityUnit = neutralGravityUnit.normalized()
        self.hingeAxisUnit = hingeAxisUnit.normalized()
        self.estimatedTravelDegrees = estimatedTravelDegrees
        self.axisExplainedVariance = axisExplainedVariance
        self.gravityIsObservable = gravityIsObservable
        self.referenceTravelDegrees = referenceTravelDegrees
        self.referenceMethod = referenceMethod
        self.temperatureCelsius = temperatureCelsius
        self.qualityScore = min(max(qualityScore, 0), 1)
        self.warnings = warnings
    }
}

// MARK: - Packet and scaled sample representation

public struct MPU6050RawSample: Codable, Hashable, Sendable {
    public var version: UInt8
    public var packetType: UInt8
    public var sequence: UInt16
    public var timestampMicroseconds: UInt32
    public var accelerometerX: Int16
    public var accelerometerY: Int16
    public var accelerometerZ: Int16
    public var temperatureRaw: Int16
    public var gyroscopeX: Int16
    public var gyroscopeY: Int16
    public var gyroscopeZ: Int16
    public var status: UInt8

    public init(
        version: UInt8 = 1,
        packetType: UInt8 = 1,
        sequence: UInt16,
        timestampMicroseconds: UInt32,
        accelerometerX: Int16,
        accelerometerY: Int16,
        accelerometerZ: Int16,
        temperatureRaw: Int16,
        gyroscopeX: Int16,
        gyroscopeY: Int16,
        gyroscopeZ: Int16,
        status: UInt8
    ) {
        self.version = version
        self.packetType = packetType
        self.sequence = sequence
        self.timestampMicroseconds = timestampMicroseconds
        self.accelerometerX = accelerometerX
        self.accelerometerY = accelerometerY
        self.accelerometerZ = accelerometerZ
        self.temperatureRaw = temperatureRaw
        self.gyroscopeX = gyroscopeX
        self.gyroscopeY = gyroscopeY
        self.gyroscopeZ = gyroscopeZ
        self.status = status
    }

    public var sensorOK: Bool { status & 0x01 != 0 }
    public var stationary: Bool { status & 0x02 != 0 }
    public var timingOverrun: Bool { status & 0x04 != 0 }
    public var i2cError: Bool { status & 0x08 != 0 }
    public var biasReady: Bool { status & 0x10 != 0 }
    public var endpointOff: Bool { status & 0x20 != 0 }
    public var endpointOn: Bool { status & 0x40 != 0 }
}

public struct InteractionSensorSample: Codable, Hashable, Sendable {
    public var raw: MPU6050RawSample
    public var unwrappedDeviceMicroseconds: UInt64
    public var hostReceiptNanoseconds: UInt64
    public var accelerationG: SensorVector3
    public var angularVelocityDPS: SensorVector3
    public var temperatureCelsius: Double

    public init(raw: MPU6050RawSample, unwrappedDeviceMicroseconds: UInt64, hostReceiptNanoseconds: UInt64) {
        self.raw = raw
        self.unwrappedDeviceMicroseconds = unwrappedDeviceMicroseconds
        self.hostReceiptNanoseconds = hostReceiptNanoseconds
        self.accelerationG = SensorVector3(
            x: Double(raw.accelerometerX) / 8_192,
            y: Double(raw.accelerometerY) / 8_192,
            z: Double(raw.accelerometerZ) / 8_192
        )
        self.angularVelocityDPS = SensorVector3(
            x: Double(raw.gyroscopeX) / 65.5,
            y: Double(raw.gyroscopeY) / 65.5,
            z: Double(raw.gyroscopeZ) / 65.5
        )
        self.temperatureCelsius = Double(raw.temperatureRaw) / 340 + 36.53
    }
}

public struct MPU6050PacketDecoder: Sendable {
    public static let packetSize = 27
    private var buffer: [UInt8] = []
    public private(set) var crcErrorCount = 0
    public private(set) var discardedByteCount = 0
    public private(set) var invalidPacketCount = 0

    public init() {}

    public mutating func feed(_ data: Data) -> [MPU6050RawSample] {
        buffer.append(contentsOf: data)
        var result: [MPU6050RawSample] = []
        while buffer.count >= Self.packetSize {
            guard buffer[0] == 0xA5, buffer[1] == 0x5A else {
                buffer.removeFirst()
                discardedByteCount += 1
                continue
            }
            let packet = Array(buffer.prefix(Self.packetSize))
            let expected = UInt16(packet[25]) | UInt16(packet[26]) << 8
            guard Self.crc16(packet.prefix(25)) == expected else {
                crcErrorCount += 1
                discardedByteCount += 1
                buffer.removeFirst()
                continue
            }
            guard packet[2] == 1, packet[3] == 1 else {
                invalidPacketCount += 1
                buffer.removeFirst(Self.packetSize)
                continue
            }
            func u16(_ offset: Int) -> UInt16 { UInt16(packet[offset]) | UInt16(packet[offset + 1]) << 8 }
            func i16(_ offset: Int) -> Int16 { Int16(bitPattern: u16(offset)) }
            func u32(_ offset: Int) -> UInt32 {
                UInt32(packet[offset]) | UInt32(packet[offset + 1]) << 8 |
                    UInt32(packet[offset + 2]) << 16 | UInt32(packet[offset + 3]) << 24
            }
            result.append(MPU6050RawSample(
                version: packet[2], packetType: packet[3], sequence: u16(4), timestampMicroseconds: u32(6),
                accelerometerX: i16(10), accelerometerY: i16(12), accelerometerZ: i16(14),
                temperatureRaw: i16(16), gyroscopeX: i16(18), gyroscopeY: i16(20),
                gyroscopeZ: i16(22), status: packet[24]
            ))
            buffer.removeFirst(Self.packetSize)
        }
        return result
    }

    public static func encode(_ sample: MPU6050RawSample) -> Data {
        var bytes: [UInt8] = [0xA5, 0x5A, sample.version, sample.packetType]
        func append(_ value: UInt16) { bytes.append(UInt8(value & 0xFF)); bytes.append(UInt8(value >> 8)) }
        func append(_ value: UInt32) {
            bytes.append(UInt8(value & 0xFF)); bytes.append(UInt8((value >> 8) & 0xFF))
            bytes.append(UInt8((value >> 16) & 0xFF)); bytes.append(UInt8((value >> 24) & 0xFF))
        }
        append(sample.sequence); append(sample.timestampMicroseconds)
        for value in [sample.accelerometerX, sample.accelerometerY, sample.accelerometerZ, sample.temperatureRaw,
                      sample.gyroscopeX, sample.gyroscopeY, sample.gyroscopeZ] {
            append(UInt16(bitPattern: value))
        }
        bytes.append(sample.status)
        append(crc16(bytes))
        return Data(bytes)
    }

    public static func crc16<S: Sequence>(_ bytes: S) -> UInt16 where S.Element == UInt8 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1
            }
        }
        return crc
    }
}

// MARK: - Capture health, motion, clock mapping, and provenance

public struct InteractionSensorHealthSnapshot: Codable, Hashable, Sendable {
    public var receivedPackets: Int
    public var lostPackets: Int
    public var crcErrors: Int
    public var discardedBytes: Int
    public var invalidPackets: Int
    public var i2cErrors: Int
    public var timingOverruns: Int
    public var saturations: Int
    public var resetDiscontinuities: Int
    public var endpointConflicts: Int
    public var observedSampleRateHz: Double?
    public var maximumPacketGapSeconds: Double
    public var startedAt: Date
    public var endedAt: Date?

    public init(
        receivedPackets: Int = 0,
        lostPackets: Int = 0,
        crcErrors: Int = 0,
        discardedBytes: Int = 0,
        invalidPackets: Int = 0,
        i2cErrors: Int = 0,
        timingOverruns: Int = 0,
        saturations: Int = 0,
        resetDiscontinuities: Int = 0,
        endpointConflicts: Int = 0,
        observedSampleRateHz: Double? = nil,
        maximumPacketGapSeconds: Double = 0,
        startedAt: Date = .now,
        endedAt: Date? = nil
    ) {
        self.receivedPackets = receivedPackets
        self.lostPackets = lostPackets
        self.crcErrors = crcErrors
        self.discardedBytes = discardedBytes
        self.invalidPackets = invalidPackets
        self.i2cErrors = i2cErrors
        self.timingOverruns = timingOverruns
        self.saturations = saturations
        self.resetDiscontinuities = resetDiscontinuities
        self.endpointConflicts = endpointConflicts
        self.observedSampleRateHz = observedSampleRateHz
        self.maximumPacketGapSeconds = maximumPacketGapSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public var retentionFraction: Double {
        let expected = receivedPackets + lostPackets
        return expected > 0 ? Double(receivedPackets) / Double(expected) : 0
    }
}

public struct InteractionMotionEvent: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var deviceStartMicroseconds: UInt64
    public var deviceEndMicroseconds: UInt64
    public var hostStartNanoseconds: UInt64
    public var hostEndNanoseconds: UInt64
    public var travelDegrees: Double
    public var peakAngularVelocityDPS: Double
    public var durationSeconds: Double
    public var direction: Int
    public var completedEndpointState: String?
    public var audioStartSeconds: Double?
    public var audioEndSeconds: Double?

    public init(
        id: UUID = UUID(),
        deviceStartMicroseconds: UInt64,
        deviceEndMicroseconds: UInt64,
        hostStartNanoseconds: UInt64,
        hostEndNanoseconds: UInt64,
        travelDegrees: Double,
        peakAngularVelocityDPS: Double,
        durationSeconds: Double,
        direction: Int,
        completedEndpointState: String? = nil,
        audioStartSeconds: Double? = nil,
        audioEndSeconds: Double? = nil
    ) {
        self.id = id
        self.deviceStartMicroseconds = deviceStartMicroseconds
        self.deviceEndMicroseconds = deviceEndMicroseconds
        self.hostStartNanoseconds = hostStartNanoseconds
        self.hostEndNanoseconds = hostEndNanoseconds
        self.travelDegrees = travelDegrees
        self.peakAngularVelocityDPS = peakAngularVelocityDPS
        self.durationSeconds = durationSeconds
        self.direction = direction
        self.completedEndpointState = completedEndpointState
        self.audioStartSeconds = audioStartSeconds
        self.audioEndSeconds = audioEndSeconds
    }
}

public struct SensorClockObservation: Codable, Hashable, Sendable {
    public var deviceMicroseconds: UInt64
    public var hostNanoseconds: UInt64
    public init(deviceMicroseconds: UInt64, hostNanoseconds: UInt64) {
        self.deviceMicroseconds = deviceMicroseconds
        self.hostNanoseconds = hostNanoseconds
    }
}

public struct SensorClockAnchor: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var deviceMicroseconds: UInt64
    public var hostNanoseconds: UInt64
    public var audioSeconds: Double
    public var source: String

    public init(id: UUID = UUID(), deviceMicroseconds: UInt64, hostNanoseconds: UInt64, audioSeconds: Double, source: String) {
        self.id = id
        self.deviceMicroseconds = deviceMicroseconds
        self.hostNanoseconds = hostNanoseconds
        self.audioSeconds = audioSeconds
        self.source = source
    }
}

public struct SensorClockSegment: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var firstDeviceMicroseconds: UInt64
    public var lastDeviceMicroseconds: UInt64
    /// audioSeconds = slope * deviceSeconds + offsetSeconds
    public var slope: Double
    public var offsetSeconds: Double
    public var driftPPM: Double
    public var residualRMSSeconds: Double

    public init(id: UUID = UUID(), firstDeviceMicroseconds: UInt64, lastDeviceMicroseconds: UInt64, slope: Double, offsetSeconds: Double, driftPPM: Double, residualRMSSeconds: Double) {
        self.id = id
        self.firstDeviceMicroseconds = firstDeviceMicroseconds
        self.lastDeviceMicroseconds = lastDeviceMicroseconds
        self.slope = slope
        self.offsetSeconds = offsetSeconds
        self.driftPPM = driftPPM
        self.residualRMSSeconds = residualRMSSeconds
    }

    public func audioSeconds(for deviceMicroseconds: UInt64) -> Double {
        slope * Double(deviceMicroseconds) / 1_000_000 + offsetSeconds
    }
}

public enum SensorClockAlignmentStatus: String, Codable, CaseIterable, Sendable {
    case fittedHostReceipts
    case hardwareSynchronized
    case eventMatched
    case unavailable
}

public struct InteractionSensorClockAlignment: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var status: SensorClockAlignmentStatus
    public var clockBasis: String
    public var audioStartHostNanoseconds: UInt64?
    public var segments: [SensorClockSegment]
    public var anchors: [SensorClockAnchor]
    public var baseUncertaintySeconds: Double
    public var notes: String

    public init(
        contractVersion: String = "orgrec.interaction-sensor-clock-alignment/v1-experimental",
        status: SensorClockAlignmentStatus,
        clockBasis: String,
        audioStartHostNanoseconds: UInt64?,
        segments: [SensorClockSegment],
        anchors: [SensorClockAnchor],
        baseUncertaintySeconds: Double,
        notes: String
    ) {
        self.contractVersion = contractVersion
        self.status = status
        self.clockBasis = clockBasis
        self.audioStartHostNanoseconds = audioStartHostNanoseconds
        self.segments = segments
        self.anchors = anchors
        self.baseUncertaintySeconds = baseUncertaintySeconds
        self.notes = notes
    }
}

public struct InteractionSensorPreviewPoint: Codable, Hashable, Sendable {
    public var deviceMicroseconds: UInt64
    /// Time relative to the first audio sample. Negative values are valid and
    /// represent sensor evidence acquired while the audio engine was starting.
    public var audioSeconds: Double?
    public var angleDegrees: Double
    public var angularVelocityDPS: Double
    public var accelerationMagnitudeG: Double
    public var progress: Double?

    public init(deviceMicroseconds: UInt64, audioSeconds: Double? = nil, angleDegrees: Double, angularVelocityDPS: Double, accelerationMagnitudeG: Double, progress: Double?) {
        self.deviceMicroseconds = deviceMicroseconds
        self.audioSeconds = audioSeconds
        self.angleDegrees = angleDegrees
        self.angularVelocityDPS = angularVelocityDPS
        self.accelerationMagnitudeG = accelerationMagnitudeG
        self.progress = progress
    }
}

public struct InteractionSensorAudioCouplingSummary: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var activationMotionEventID: UUID?
    public var releaseMotionEventID: UUID?
    public var activationMotionStartAudioSeconds: Double?
    public var activationMotionEndAudioSeconds: Double?
    public var acousticOnsetSeconds: Double?
    public var onsetAfterMotionStartSeconds: Double?
    public var onsetAfterMotionEndSeconds: Double?
    public var releaseMotionStartAudioSeconds: Double?
    public var releaseMotionEndAudioSeconds: Double?
    public var acousticSoundOffsetSeconds: Double?
    public var soundOffsetAfterReleaseStartSeconds: Double?
    public var soundOffsetAfterReleaseEndSeconds: Double?
    public var heldIntervalSeconds: Double?
    public var timingUncertaintySeconds: Double
    public var interpretation: String
    public var warnings: [String]

    public init(
        contractVersion: String = "orgrec.interaction-sensor-audio-coupling/v1-experimental",
        activationMotionEventID: UUID?,
        releaseMotionEventID: UUID?,
        activationMotionStartAudioSeconds: Double?,
        activationMotionEndAudioSeconds: Double?,
        acousticOnsetSeconds: Double?,
        onsetAfterMotionStartSeconds: Double?,
        onsetAfterMotionEndSeconds: Double?,
        releaseMotionStartAudioSeconds: Double?,
        releaseMotionEndAudioSeconds: Double?,
        acousticSoundOffsetSeconds: Double?,
        soundOffsetAfterReleaseStartSeconds: Double?,
        soundOffsetAfterReleaseEndSeconds: Double?,
        heldIntervalSeconds: Double?,
        timingUncertaintySeconds: Double,
        interpretation: String,
        warnings: [String]
    ) {
        self.contractVersion = contractVersion
        self.activationMotionEventID = activationMotionEventID
        self.releaseMotionEventID = releaseMotionEventID
        self.activationMotionStartAudioSeconds = activationMotionStartAudioSeconds
        self.activationMotionEndAudioSeconds = activationMotionEndAudioSeconds
        self.acousticOnsetSeconds = acousticOnsetSeconds
        self.onsetAfterMotionStartSeconds = onsetAfterMotionStartSeconds
        self.onsetAfterMotionEndSeconds = onsetAfterMotionEndSeconds
        self.releaseMotionStartAudioSeconds = releaseMotionStartAudioSeconds
        self.releaseMotionEndAudioSeconds = releaseMotionEndAudioSeconds
        self.acousticSoundOffsetSeconds = acousticSoundOffsetSeconds
        self.soundOffsetAfterReleaseStartSeconds = soundOffsetAfterReleaseStartSeconds
        self.soundOffsetAfterReleaseEndSeconds = soundOffsetAfterReleaseEndSeconds
        self.heldIntervalSeconds = heldIntervalSeconds
        self.timingUncertaintySeconds = timingUncertaintySeconds
        self.interpretation = interpretation
        self.warnings = warnings
    }
}

public struct InteractionSensorDerivedData: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var captureID: UUID
    public var generatedAt: Date
    public var processingIdentifier: String
    public var preview: [InteractionSensorPreviewPoint]
    public var motionEvents: [InteractionMotionEvent]
    public var audioCoupling: InteractionSensorAudioCouplingSummary?

    public init(contractVersion: String = "orgrec.interaction-sensor-derived/v1-experimental", captureID: UUID, generatedAt: Date = .now, processingIdentifier: String, preview: [InteractionSensorPreviewPoint], motionEvents: [InteractionMotionEvent], audioCoupling: InteractionSensorAudioCouplingSummary? = nil) {
        self.contractVersion = contractVersion
        self.captureID = captureID
        self.generatedAt = generatedAt
        self.processingIdentifier = processingIdentifier
        self.preview = preview
        self.motionEvents = motionEvents
        self.audioCoupling = audioCoupling
    }
}

public struct InteractionSensorCaptureRecord: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var takeID: UUID
    public var configurationSnapshot: InteractionSensorConfiguration
    public var calibrationSnapshot: InteractionSensorCalibration?
    public var startedAt: Date
    public var endedAt: Date
    public var rawRelativePath: String
    public var rawSHA256: String
    public var rawByteCount: Int64
    public var metadataRelativePath: String
    public var derivedRelativePath: String?
    public var health: InteractionSensorHealthSnapshot
    public var clockAlignment: InteractionSensorClockAlignment
    public var motionEventCount: Int
    public var audioCoupling: InteractionSensorAudioCouplingSummary?
    public var processingIdentifier: String
    public var experimentalLimitations: [String]

    public init(
        contractVersion: String = "orgrec.interaction-sensor-capture/v1-experimental",
        id: UUID = UUID(),
        takeID: UUID,
        configurationSnapshot: InteractionSensorConfiguration,
        calibrationSnapshot: InteractionSensorCalibration?,
        startedAt: Date,
        endedAt: Date,
        rawRelativePath: String,
        rawSHA256: String,
        rawByteCount: Int64,
        metadataRelativePath: String,
        derivedRelativePath: String?,
        health: InteractionSensorHealthSnapshot,
        clockAlignment: InteractionSensorClockAlignment,
        motionEventCount: Int,
        audioCoupling: InteractionSensorAudioCouplingSummary? = nil,
        processingIdentifier: String = "orgrec-native-imu/v1-experimental",
        experimentalLimitations: [String] = []
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.takeID = takeID
        self.configurationSnapshot = configurationSnapshot
        self.calibrationSnapshot = calibrationSnapshot
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rawRelativePath = rawRelativePath
        self.rawSHA256 = rawSHA256
        self.rawByteCount = rawByteCount
        self.metadataRelativePath = metadataRelativePath
        self.derivedRelativePath = derivedRelativePath
        self.health = health
        self.clockAlignment = clockAlignment
        self.motionEventCount = motionEventCount
        self.audioCoupling = audioCoupling
        self.processingIdentifier = processingIdentifier
        self.experimentalLimitations = experimentalLimitations
    }
}

// MARK: - MIDI comparison and independent validation

public struct MIDIVelocityMotionTrial: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var capturedAt: Date
    public var midiNote: Int
    public var midiVelocity: Int
    public var motionEventID: UUID
    public var motionStartToMIDISeconds: Double
    public var peakAngularVelocityDPS: Double
    public var travelDegrees: Double
    public var durationSeconds: Double

    public init(id: UUID = UUID(), capturedAt: Date = .now, midiNote: Int, midiVelocity: Int, motionEventID: UUID, motionStartToMIDISeconds: Double, peakAngularVelocityDPS: Double, travelDegrees: Double, durationSeconds: Double) {
        self.id = id
        self.capturedAt = capturedAt
        self.midiNote = midiNote
        self.midiVelocity = midiVelocity
        self.motionEventID = motionEventID
        self.motionStartToMIDISeconds = motionStartToMIDISeconds
        self.peakAngularVelocityDPS = peakAngularVelocityDPS
        self.travelDegrees = travelDegrees
        self.durationSeconds = durationSeconds
    }
}

public struct MIDIVelocityEvaluation: Codable, Hashable, Sendable {
    public var trialCount: Int
    public var distinctVelocityCount: Int
    public var slopeDPSPerVelocityUnit: Double?
    public var interceptDPS: Double?
    public var rSquared: Double?
    public var rmseDPS: Double?
    public var suitableAsComparativePredictor: Bool
    public var conclusion: String

    public init(trialCount: Int, distinctVelocityCount: Int, slopeDPSPerVelocityUnit: Double?, interceptDPS: Double?, rSquared: Double?, rmseDPS: Double?, suitableAsComparativePredictor: Bool, conclusion: String) {
        self.trialCount = trialCount
        self.distinctVelocityCount = distinctVelocityCount
        self.slopeDPSPerVelocityUnit = slopeDPSPerVelocityUnit
        self.interceptDPS = interceptDPS
        self.rSquared = rSquared
        self.rmseDPS = rmseDPS
        self.suitableAsComparativePredictor = suitableAsComparativePredictor
        self.conclusion = conclusion
    }
}

public enum InteractionValidationReference: String, Codable, CaseIterable, Identifiable, Sendable {
    case encoder
    case laserDisplacement
    case highSpeedVideo
    case measuredGeometry
    case midiTimingOnly
    case operatorObservation

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .encoder: "Encoder"
        case .laserDisplacement: "Laser displacement"
        case .highSpeedVideo: "High-speed video"
        case .measuredGeometry: "Measured geometry"
        case .midiTimingOnly: "MIDI timing only"
        case .operatorObservation: "Operator observation"
        }
    }

    public var isIndependentPhysicalReference: Bool {
        [.encoder, .laserDisplacement, .highSpeedVideo, .measuredGeometry].contains(self)
    }
}

public struct InteractionValidationTrial: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var capturedAt: Date
    public var motionEventID: UUID
    public var reference: InteractionValidationReference
    public var measuredTravelDegrees: Double
    public var referenceTravelDegrees: Double?
    public var measuredDurationSeconds: Double
    public var referenceDurationSeconds: Double?
    public var notes: String

    public init(id: UUID = UUID(), capturedAt: Date = .now, motionEventID: UUID, reference: InteractionValidationReference, measuredTravelDegrees: Double, referenceTravelDegrees: Double?, measuredDurationSeconds: Double, referenceDurationSeconds: Double?, notes: String = "") {
        self.id = id
        self.capturedAt = capturedAt
        self.motionEventID = motionEventID
        self.reference = reference
        self.measuredTravelDegrees = measuredTravelDegrees
        self.referenceTravelDegrees = referenceTravelDegrees
        self.measuredDurationSeconds = measuredDurationSeconds
        self.referenceDurationSeconds = referenceDurationSeconds
        self.notes = notes
    }
}

public struct InteractionValidationSummary: Codable, Hashable, Sendable {
    public var trialCount: Int
    public var independentReferenceTrialCount: Int
    public var travelRMSEDegrees: Double?
    public var durationRMSESeconds: Double?
    public var maximumTravelErrorDegrees: Double?
    public var passedExperimentalGate: Bool
    public var findings: [String]

    public init(trialCount: Int, independentReferenceTrialCount: Int, travelRMSEDegrees: Double?, durationRMSESeconds: Double?, maximumTravelErrorDegrees: Double?, passedExperimentalGate: Bool, findings: [String]) {
        self.trialCount = trialCount
        self.independentReferenceTrialCount = independentReferenceTrialCount
        self.travelRMSEDegrees = travelRMSEDegrees
        self.durationRMSESeconds = durationRMSESeconds
        self.maximumTravelErrorDegrees = maximumTravelErrorDegrees
        self.passedExperimentalGate = passedExperimentalGate
        self.findings = findings
    }
}

public struct InteractionSensorValidationSession: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var configurationID: UUID
    public var calibrationID: UUID?
    public var createdAt: Date
    public var environment: String
    public var trials: [InteractionValidationTrial]
    public var midiTrials: [MIDIVelocityMotionTrial]
    public var midiEvaluation: MIDIVelocityEvaluation
    public var summary: InteractionValidationSummary
    public var notes: String

    public init(contractVersion: String = "orgrec.interaction-sensor-validation/v1-experimental", id: UUID = UUID(), configurationID: UUID, calibrationID: UUID?, createdAt: Date = .now, environment: String, trials: [InteractionValidationTrial], midiTrials: [MIDIVelocityMotionTrial], midiEvaluation: MIDIVelocityEvaluation, summary: InteractionValidationSummary, notes: String = "") {
        self.contractVersion = contractVersion
        self.id = id
        self.configurationID = configurationID
        self.calibrationID = calibrationID
        self.createdAt = createdAt
        self.environment = environment
        self.trials = trials
        self.midiTrials = midiTrials
        self.midiEvaluation = midiEvaluation
        self.summary = summary
        self.notes = notes
    }
}

// MARK: - Pure processing utilities

public enum InteractionSensorProcessing {
    public static func signedGravityAngleDegrees(current: SensorVector3, neutral: SensorVector3, axis: SensorVector3) -> Double? {
        let unitAxis = axis.normalized()
        let neutralPlane = neutral - unitAxis * neutral.dot(unitAxis)
        let currentPlane = current - unitAxis * current.dot(unitAxis)
        guard neutralPlane.magnitude > 0.15, currentPlane.magnitude > 0.15 else { return nil }
        let a = neutralPlane.normalized()
        let b = currentPlane.normalized()
        // Gravity is observed in the rotating sensor/body frame, so its apparent
        // rotation is opposite to the body's right-handed gyroscope rotation.
        return atan2(-unitAxis.dot(a.cross(b)), max(-1, min(1, a.dot(b)))) * 180 / .pi
    }

    public static func calibration(
        configurationID: UUID,
        stationarySamples: [InteractionSensorSample],
        movementSamples: [InteractionSensorSample],
        referenceTravelDegrees: Double? = nil,
        referenceMethod: String? = nil
    ) -> InteractionSensorCalibration? {
        guard stationarySamples.count >= 40, movementSamples.count >= 40 else { return nil }
        let bias = mean(stationarySamples.map(\.angularVelocityDPS))
        let gravity = mean(stationarySamples.map(\.accelerationG)).normalized(or: SensorVector3(x: 0, y: 0, z: 1))
        let gyroResiduals = stationarySamples.map { $0.angularVelocityDPS - bias }
        let noise = sqrt(gyroResiduals.map { pow($0.magnitude, 2) }.reduce(0, +) / Double(gyroResiduals.count))
        let centered = movementSamples.map { $0.angularVelocityDPS - bias }
        let (axisCandidate, explained) = principalAxis(centered)
        var axis = axisCandidate
        // Define positive travel from the first deliberate movement in the guided
        // sequence. PCA eigenvectors otherwise have an arbitrary sign.
        if let firstMovement = centered.first(where: { $0.magnitude > max(5, noise * 5) }),
           firstMovement.dot(axis) < 0 {
            axis = axis * -1
        }
        var integrated = 0.0
        var low = 0.0
        var high = 0.0
        for pair in zip(movementSamples, movementSamples.dropFirst()) {
            let dt = Double(pair.1.unwrappedDeviceMicroseconds - pair.0.unwrappedDeviceMicroseconds) / 1_000_000
            if dt > 0, dt < 0.1 {
                integrated += (pair.0.angularVelocityDPS - bias).dot(axis) * dt
                low = min(low, integrated); high = max(high, integrated)
            }
        }
        let travel = high - low
        let gravityObservable = abs(gravity.dot(axis)) < 0.94
        var warnings: [String] = []
        if noise > 1 { warnings.append("Stationary gyroscope noise exceeds 1 °/s RMS.") }
        if explained < 0.8 { warnings.append("Movement is not strongly one-dimensional; inspect the mount and mechanism.") }
        if gravityObservable == false { warnings.append("The hinge axis is nearly parallel to gravity, so a 6-axis IMU cannot correct absolute-angle drift.") }
        if travel < 2 { warnings.append("Learned travel is below 2°; perform several complete strokes.") }
        let noiseScore = max(0, min(1, 1 - noise / 5))
        let quality = 0.45 * min(max(explained, 0), 1) + 0.35 * noiseScore + 0.20 * (gravityObservable ? 1 : 0.25)
        return InteractionSensorCalibration(
            configurationID: configurationID,
            stationarySampleCount: stationarySamples.count,
            movementSampleCount: movementSamples.count,
            gyroBiasDPS: bias,
            gyroNoiseRMSDPS: noise,
            neutralGravityUnit: gravity,
            hingeAxisUnit: axis,
            estimatedTravelDegrees: travel,
            axisExplainedVariance: explained,
            gravityIsObservable: gravityObservable,
            referenceTravelDegrees: referenceTravelDegrees,
            referenceMethod: referenceMethod,
            temperatureCelsius: stationarySamples.map(\.temperatureCelsius).reduce(0, +) / Double(stationarySamples.count),
            qualityScore: quality,
            warnings: warnings
        )
    }

    public static func fitClock(
        observations: [SensorClockObservation],
        audioStartHostNanoseconds: UInt64?,
        nominalSampleRateHz: Double,
        serialBaudRate: Int
    ) -> InteractionSensorClockAlignment {
        guard observations.count >= 2, let audioStartHostNanoseconds else {
            return InteractionSensorClockAlignment(
                status: .unavailable, clockBasis: "independent sensor clock", audioStartHostNanoseconds: audioStartHostNanoseconds,
                segments: [], anchors: [], baseUncertaintySeconds: max(0.01, 1 / max(1, nominalSampleRateHz)),
                notes: "At least two host receipt anchors and an audio start timestamp are required."
            )
        }
        let first = observations[0]
        let x = observations.map { Double($0.deviceMicroseconds - first.deviceMicroseconds) / 1_000_000 }
        let y = observations.map { (Double($0.hostNanoseconds) - Double(first.hostNanoseconds)) / 1_000_000_000 }
        let xMean = x.reduce(0, +) / Double(x.count)
        let yMean = y.reduce(0, +) / Double(y.count)
        let denominator = x.map { pow($0 - xMean, 2) }.reduce(0, +)
        let slope = denominator > 0 ? zip(x, y).map { ($0 - xMean) * ($1 - yMean) }.reduce(0, +) / denominator : 1
        let hostFirstRelativeAudio = (Double(first.hostNanoseconds) - Double(audioStartHostNanoseconds)) / 1_000_000_000
        let absoluteDeviceFirstSeconds = Double(first.deviceMicroseconds) / 1_000_000
        let offset = hostFirstRelativeAudio - slope * absoluteDeviceFirstSeconds
        let residuals = zip(x, y).map { observedX, observedY in observedY - (slope * observedX + yMean - slope * xMean) }
        let residual = sqrt(residuals.map { $0 * $0 }.reduce(0, +) / Double(residuals.count))
        let wireSeconds = serialBaudRate > 0 ? Double(MPU6050PacketDecoder.packetSize * 10) / Double(serialBaudRate) : 0.002
        let uncertainty = max(0.5 / max(1, nominalSampleRateHz), residual + wireSeconds)
        let segment = SensorClockSegment(
            firstDeviceMicroseconds: first.deviceMicroseconds,
            lastDeviceMicroseconds: observations.last!.deviceMicroseconds,
            slope: slope,
            offsetSeconds: offset,
            driftPPM: (slope - 1) * 1_000_000,
            residualRMSSeconds: residual
        )
        let selected = observations.count == 2 ? observations : [observations.first!, observations.last!]
        let anchors = selected.map { observation in
            SensorClockAnchor(
                deviceMicroseconds: observation.deviceMicroseconds,
                hostNanoseconds: observation.hostNanoseconds,
                audioSeconds: (Double(observation.hostNanoseconds) - Double(audioStartHostNanoseconds)) / 1_000_000_000,
                source: "serial host receipt corrected for packet wire order"
            )
        }
        return InteractionSensorClockAlignment(
            status: .fittedHostReceipts,
            clockBasis: "device microseconds fitted to CoreAudio host time through serial receipt anchors",
            audioStartHostNanoseconds: audioStartHostNanoseconds,
            segments: [segment], anchors: anchors, baseUncertaintySeconds: uncertainty,
            notes: "Experimental alignment. USB buffering is represented by fit residuals but is not eliminated; use a shared hardware pulse for high-confidence timing."
        )
    }

    /// Relates the physical control movement to the acoustic pipe response. The
    /// values stay signed: a negative onset-after-motion-end value is meaningful
    /// when the pipe begins speaking before the key has completed its travel.
    public static func coupleMotionToAudio(
        events: [InteractionMotionEvent],
        acousticOnsetSeconds: Double?,
        acousticSoundOffsetSeconds: Double?,
        operatorKeyUpSeconds: Double?,
        timingUncertaintySeconds: Double
    ) -> InteractionSensorAudioCouplingSummary? {
        let mapped = events.filter { $0.audioStartSeconds != nil && $0.audioEndSeconds != nil }
        guard mapped.isEmpty == false else { return nil }

        let activation: InteractionMotionEvent? = {
            guard let onset = acousticOnsetSeconds else {
                return mapped.first(where: { $0.direction > 0 }) ?? mapped.first
            }
            let preferred = mapped.filter {
                $0.direction > 0 && ($0.audioStartSeconds ?? .infinity) <= onset + 0.5
            }
            let candidates = preferred.isEmpty
                ? mapped.filter { ($0.audioStartSeconds ?? .infinity) <= onset + 0.5 }
                : preferred
            return candidates.min {
                abs(onset - ($0.audioEndSeconds ?? onset)) < abs(onset - ($1.audioEndSeconds ?? onset))
            }
        }()

        let releaseReference = operatorKeyUpSeconds ?? acousticSoundOffsetSeconds
        let release: InteractionMotionEvent? = {
            let afterActivation = mapped.filter { candidate in
                guard candidate.id != activation?.id else { return false }
                if let activationEnd = activation?.audioEndSeconds {
                    return (candidate.audioStartSeconds ?? -.infinity) >= activationEnd
                }
                return true
            }
            let preferred = afterActivation.filter { $0.direction < 0 }
            let candidates = preferred.isEmpty ? afterActivation : preferred
            guard let reference = releaseReference else { return candidates.last }
            return candidates.min {
                abs(reference - ($0.audioStartSeconds ?? reference)) < abs(reference - ($1.audioStartSeconds ?? reference))
            }
        }()

        let activationStart = activation?.audioStartSeconds
        let activationEnd = activation?.audioEndSeconds
        let releaseStart = release?.audioStartSeconds
        let releaseEnd = release?.audioEndSeconds
        var warnings: [String] = []
        if activation == nil { warnings.append("No activation-like motion could be associated with acoustic onset.") }
        if release == nil { warnings.append("No release-like motion could be associated with key-up or acoustic offset.") }
        if operatorKeyUpSeconds == nil, release != nil {
            warnings.append("Release association was inferred from motion direction because no operator key-up marker was available.")
        }
        if activation?.direction != 1, activation != nil {
            warnings.append("Activation used a fallback event because no positive-travel event preceded onset.")
        }
        if release?.direction != -1, release != nil {
            warnings.append("Release used a fallback event because no negative-travel event followed activation.")
        }
        let interpretation = "Timing describes this mounted mechanism and audio setup only. It is not an estimate of pallet motion, wind-chest pressure, or a transferable keyboard action."
        return InteractionSensorAudioCouplingSummary(
            activationMotionEventID: activation?.id,
            releaseMotionEventID: release?.id,
            activationMotionStartAudioSeconds: activationStart,
            activationMotionEndAudioSeconds: activationEnd,
            acousticOnsetSeconds: acousticOnsetSeconds,
            onsetAfterMotionStartSeconds: activationStart.flatMap { start in acousticOnsetSeconds.map { $0 - start } },
            onsetAfterMotionEndSeconds: activationEnd.flatMap { end in acousticOnsetSeconds.map { $0 - end } },
            releaseMotionStartAudioSeconds: releaseStart,
            releaseMotionEndAudioSeconds: releaseEnd,
            acousticSoundOffsetSeconds: acousticSoundOffsetSeconds,
            soundOffsetAfterReleaseStartSeconds: releaseStart.flatMap { start in acousticSoundOffsetSeconds.map { $0 - start } },
            soundOffsetAfterReleaseEndSeconds: releaseEnd.flatMap { end in acousticSoundOffsetSeconds.map { $0 - end } },
            heldIntervalSeconds: activationEnd.flatMap { end in releaseStart.map { max(0, $0 - end) } },
            timingUncertaintySeconds: max(0, timingUncertaintySeconds),
            interpretation: interpretation,
            warnings: warnings
        )
    }

    public static func evaluateMIDIVelocity(_ trials: [MIDIVelocityMotionTrial]) -> MIDIVelocityEvaluation {
        let distinct = Set(trials.map(\.midiVelocity)).count
        guard trials.count >= 5, distinct >= 3 else {
            return MIDIVelocityEvaluation(
                trialCount: trials.count, distinctVelocityCount: distinct, slopeDPSPerVelocityUnit: nil, interceptDPS: nil,
                rSquared: nil, rmseDPS: nil, suitableAsComparativePredictor: false,
                conclusion: "Collect at least five presses spanning at least three distinct MIDI velocities. MIDI velocity is not a physical calibration reference."
            )
        }
        let x = trials.map { Double($0.midiVelocity) }
        let y = trials.map(\.peakAngularVelocityDPS)
        let xMean = x.reduce(0, +) / Double(x.count)
        let yMean = y.reduce(0, +) / Double(y.count)
        let denominator = x.map { pow($0 - xMean, 2) }.reduce(0, +)
        guard denominator > 0 else {
            return MIDIVelocityEvaluation(trialCount: trials.count, distinctVelocityCount: distinct, slopeDPSPerVelocityUnit: nil, interceptDPS: nil, rSquared: nil, rmseDPS: nil, suitableAsComparativePredictor: false, conclusion: "The MIDI source emitted no usable velocity variation.")
        }
        let slope = zip(x, y).map { ($0 - xMean) * ($1 - yMean) }.reduce(0, +) / denominator
        let intercept = yMean - slope * xMean
        let errors = zip(x, y).map { xv, yv in yv - (slope * xv + intercept) }
        let sse = errors.map { $0 * $0 }.reduce(0, +)
        let total = y.map { pow($0 - yMean, 2) }.reduce(0, +)
        let r2 = total > 0 ? 1 - sse / total : 0
        let rmse = sqrt(sse / Double(y.count))
        let suitable = r2 >= 0.8 && slope > 0
        let conclusion = suitable
            ? "MIDI velocity is a useful comparative predictor for this exact keyboard, mounting, and MIDI implementation. It does not establish absolute physical velocity and must not be transferred to another action."
            : "MIDI velocity does not reliably predict measured peak key speed in this setup; retain it only as synchronized event metadata."
        return MIDIVelocityEvaluation(trialCount: trials.count, distinctVelocityCount: distinct, slopeDPSPerVelocityUnit: slope, interceptDPS: intercept, rSquared: r2, rmseDPS: rmse, suitableAsComparativePredictor: suitable, conclusion: conclusion)
    }

    public static func summarizeValidation(_ trials: [InteractionValidationTrial]) -> InteractionValidationSummary {
        let independent = trials.filter { $0.reference.isIndependentPhysicalReference }
        let travelErrors = independent.compactMap { trial -> Double? in
            trial.referenceTravelDegrees.map { trial.measuredTravelDegrees - $0 }
        }
        let durationErrors = independent.compactMap { trial -> Double? in
            trial.referenceDurationSeconds.map { trial.measuredDurationSeconds - $0 }
        }
        func rmse(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : sqrt(values.map { $0 * $0 }.reduce(0, +) / Double(values.count))
        }
        let travelRMSE = rmse(travelErrors)
        let durationRMSE = rmse(durationErrors)
        let maximum = travelErrors.map(abs).max()
        let passed = independent.count >= 10 && (travelRMSE ?? .infinity) <= 0.5 && (durationRMSE ?? 0) <= 0.01
        var findings: [String] = []
        if independent.count < 10 { findings.append("Fewer than 10 trials use an independent physical reference.") }
        if let travelRMSE, travelRMSE > 0.5 { findings.append("Travel RMSE exceeds the provisional 0.5° gate.") }
        if let durationRMSE, durationRMSE > 0.01 { findings.append("Duration RMSE exceeds the provisional 10 ms gate.") }
        if independent.isEmpty { findings.append("MIDI and operator observations cannot validate physical displacement.") }
        if passed { findings.append("This calibration passed the provisional experimental gate; it is not a general sensor certification.") }
        return InteractionValidationSummary(trialCount: trials.count, independentReferenceTrialCount: independent.count, travelRMSEDegrees: travelRMSE, durationRMSESeconds: durationRMSE, maximumTravelErrorDegrees: maximum, passedExperimentalGate: passed, findings: findings)
    }

    private static func mean(_ vectors: [SensorVector3]) -> SensorVector3 {
        guard vectors.isEmpty == false else { return .zero }
        return vectors.reduce(.zero, +) / Double(vectors.count)
    }

    private static func principalAxis(_ vectors: [SensorVector3]) -> (SensorVector3, Double) {
        guard vectors.isEmpty == false else { return (.unitX, 0) }
        let meanVector = mean(vectors)
        let values = vectors.map { $0 - meanVector }
        var covariance = Array(repeating: Array(repeating: 0.0, count: 3), count: 3)
        for value in values {
            let row = [value.x, value.y, value.z]
            for i in 0..<3 { for j in 0..<3 { covariance[i][j] += row[i] * row[j] } }
        }
        var axis = SensorVector3(x: 0.81, y: 0.47, z: 0.35).normalized()
        for _ in 0..<24 {
            axis = SensorVector3(
                x: covariance[0][0] * axis.x + covariance[0][1] * axis.y + covariance[0][2] * axis.z,
                y: covariance[1][0] * axis.x + covariance[1][1] * axis.y + covariance[1][2] * axis.z,
                z: covariance[2][0] * axis.x + covariance[2][1] * axis.y + covariance[2][2] * axis.z
            ).normalized()
        }
        let projected = values.map { pow($0.dot(axis), 2) }.reduce(0, +)
        let total = values.map { pow($0.magnitude, 2) }.reduce(0, +)
        return (axis, total > 0 ? projected / total : 0)
    }
}
