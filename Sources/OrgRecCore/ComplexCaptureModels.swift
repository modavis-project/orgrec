import Foundation

// MARK: - Intended sounding targets

/// An intended acoustic result of operating the instrument. This is deliberately
/// separate from `InstrumentNoiseCaptureProtocol`: a cymbal, siren, or xylophone
/// is musical/effect content even when a solenoid or valve is audible with it.
public enum SoundingTargetFamily: String, Codable, CaseIterable, Identifiable, Sendable {
    case pipeSpeech
    case tonalPercussion
    case atonalPercussion
    case sustainedEffect
    case oneShotEffect
    case repeatingEffect
    case sequencedEffect
    case compositeEffect
    case otherSoundingElement

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .pipeSpeech: "Pipe speech"
        case .tonalPercussion: "Tonal percussion"
        case .atonalPercussion: "Atonal percussion"
        case .sustainedEffect: "Sustained effect"
        case .oneShotEffect: "One-shot effect"
        case .repeatingEffect: "Repeating effect"
        case .sequencedEffect: "Sequenced effect"
        case .compositeEffect: "Composite / chained effect"
        case .otherSoundingElement: "Other sounding element"
        }
    }
}

public enum SoundingTargetTemporalBehavior: String, Codable, CaseIterable, Sendable {
    case discrete
    case sustained
    case repeating
    case sequenced
    case composite
}

public enum SoundingTargetTriggerMode: String, Codable, CaseIterable, Sendable {
    case keyboardKey
    case stopTab
    case piston
    case pedal
    case continuousController
    case externalControl
    case manual
    case composite
}

public struct SoundingTargetDefinition: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var family: SoundingTargetFamily
    public var temporalBehavior: SoundingTargetTemporalBehavior
    public var triggerMode: SoundingTargetTriggerMode
    public var memberComponentIDs: [String]
    public var minimumAcceptedTakeCount: Int
    public var plannedDurationSeconds: Double?
    public var captureRelease: Bool
    public var notes: String

    public init(
        contractVersion: String = "orgrec.sounding-target/v1",
        family: SoundingTargetFamily,
        temporalBehavior: SoundingTargetTemporalBehavior,
        triggerMode: SoundingTargetTriggerMode,
        memberComponentIDs: [String] = [],
        minimumAcceptedTakeCount: Int = 1,
        plannedDurationSeconds: Double? = nil,
        captureRelease: Bool = true,
        notes: String = ""
    ) {
        self.contractVersion = contractVersion
        self.family = family
        self.temporalBehavior = temporalBehavior
        self.triggerMode = triggerMode
        self.memberComponentIDs = memberComponentIDs
        self.minimumAcceptedTakeCount = max(1, minimumAcceptedTakeCount)
        self.plannedDurationSeconds = plannedDurationSeconds
        self.captureRelease = captureRelease
        self.notes = notes
    }

    public var validationIssues: [String] {
        var result: [String] = []
        if minimumAcceptedTakeCount < 1 { result.append("At least one accepted take is required.") }
        if let plannedDurationSeconds, plannedDurationSeconds <= 0 { result.append("Planned duration must be positive.") }
        if family == .compositeEffect && memberComponentIDs.isEmpty {
            result.append("A composite target must identify at least one constituent component.")
        }
        return result
    }
}

// MARK: - Exact capture state

public enum CaptureStateDimension: String, Codable, CaseIterable, Identifiable, Sendable {
    case stop
    case coupler
    case accessory
    case soundingTarget
    case tremulant
    case windSystem
    case blower
    case shutter
    case combination
    case routing
    case enclosure
    case controller
    case custom

    public var id: String { rawValue }
    public var displayName: String { rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
}

public enum CaptureStateValueKind: String, Codable, CaseIterable, Sendable {
    case boolean
    case discrete
    case continuous
    case text
}

public struct CaptureStateAssignment: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let subjectComponentID: String
    public let subjectLabel: String
    public let dimension: CaptureStateDimension
    public let valueKind: CaptureStateValueKind
    public let booleanValue: Bool?
    public let numericValue: Double?
    public let textValue: String?
    public let unit: String?
    public let evidence: String

    public init(
        subjectComponentID: String,
        subjectLabel: String,
        dimension: CaptureStateDimension,
        valueKind: CaptureStateValueKind,
        booleanValue: Bool? = nil,
        numericValue: Double? = nil,
        textValue: String? = nil,
        unit: String? = nil,
        evidence: String = "operator-planned"
    ) {
        self.subjectComponentID = subjectComponentID
        self.subjectLabel = subjectLabel
        self.dimension = dimension
        self.valueKind = valueKind
        self.booleanValue = booleanValue
        self.numericValue = numericValue
        self.textValue = textValue
        self.unit = unit
        self.evidence = evidence
        self.id = "\(dimension.rawValue)|\(subjectComponentID)"
    }

    public static func enabled(component: OrganComponent, dimension: CaptureStateDimension, enabled: Bool, evidence: String = "roadmap-registration") -> Self {
        Self(
            subjectComponentID: component.id,
            subjectLabel: component.label,
            dimension: dimension,
            valueKind: .boolean,
            booleanValue: enabled,
            evidence: evidence
        )
    }

    fileprivate var canonicalValue: String {
        let bool = booleanValue.map { $0 ? "true" : "false" } ?? ""
        let number = numericValue.map { String(format: "%.12g", $0) } ?? ""
        return [dimension.rawValue, subjectComponentID, valueKind.rawValue, bool, number, textValue ?? "", unit ?? ""]
            .joined(separator: "\u{1f}")
    }
}

public enum CaptureStateSource: String, Codable, CaseIterable, Sendable {
    case roadmapCompiler
    case operatorPlanned
    case operatorConfirmed
    case controllerObserved
    case imported
}

/// Value-semantic, immutable state frozen into both a Roadmap obligation and a
/// take. Its fingerprint ignores human-facing name/date but covers every typed
/// assignment and therefore supports exact state comparison.
public struct CaptureStateSnapshot: Codable, Hashable, Identifiable, Sendable {
    public let contractVersion: String
    public let id: UUID
    public let revision: Int
    public let name: String
    public let source: CaptureStateSource
    public let capturedAt: Date
    public let assignments: [CaptureStateAssignment]
    public let notes: String
    public let fingerprintSHA256: String

    public init(
        contractVersion: String = "orgrec.capture-state/v1",
        id: UUID = UUID(),
        revision: Int = 1,
        name: String,
        source: CaptureStateSource,
        capturedAt: Date = .now,
        assignments: [CaptureStateAssignment],
        notes: String = ""
    ) {
        let ordered = assignments.sorted {
            if $0.dimension.rawValue != $1.dimension.rawValue { return $0.dimension.rawValue < $1.dimension.rawValue }
            return $0.subjectComponentID < $1.subjectComponentID
        }
        self.contractVersion = contractVersion
        self.id = id
        self.revision = revision
        self.name = name
        self.source = source
        self.capturedAt = capturedAt
        self.assignments = ordered
        self.notes = notes
        self.fingerprintSHA256 = Data(ordered.map(\.canonicalValue).joined(separator: "\u{1e}").utf8).sha256Hex
    }

    public func isStateEquivalent(to other: CaptureStateSnapshot) -> Bool {
        fingerprintSHA256 == other.fingerprintSHA256
    }
}

public extension OrgRecProject {
    func requiredCaptureState(for item: RoadmapItem) -> CaptureStateSnapshot? {
        if let inline = item.requiredCaptureState { return inline }
        if let id = item.requiredCaptureStateID,
           let state = captureStates?.first(where: { $0.id == id }) { return state }
        if let fingerprint = item.requiredCaptureStateFingerprint {
            return captureStates?.first { $0.fingerprintSHA256 == fingerprint }
        }
        return nil
    }
}

// MARK: - Control map

public enum ControlProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
    case midi1
    case midi2UMP
    case osc
    case hid
    case contactClosure
    case other
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .midi1: "MIDI 1.0"
        case .midi2UMP: "MIDI 2.0 / UMP"
        case .osc: "OSC"
        case .hid: "HID"
        case .contactClosure: "Contact closure"
        case .other: "Other"
        }
    }
}

public enum ControlDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    case instrumentToOrgRec
    case orgRecToInstrument
    case bidirectional
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .instrumentToOrgRec: "Instrument → OrgRec"
        case .orgRecToInstrument: "OrgRec → instrument"
        case .bidirectional: "Bidirectional"
        }
    }
    public var permitsOutput: Bool { self != .instrumentToOrgRec }
}

public enum ControlMessageType: String, Codable, CaseIterable, Identifiable, Sendable {
    case noteOn
    case noteOff
    case controlChange
    case programChange
    case pitchBend
    case channelPressure
    case polyphonicPressure
    case systemExclusive
    case ump
    case oscMessage
    case hidReport
    case contact
    case custom
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .noteOn: "Note On"
        case .noteOff: "Note Off"
        case .controlChange: "Control Change"
        case .programChange: "Program Change"
        case .pitchBend: "Pitch Bend"
        case .channelPressure: "Channel Pressure"
        case .polyphonicPressure: "Polyphonic Pressure"
        case .systemExclusive: "System Exclusive"
        case .ump: "UMP"
        case .oscMessage: "OSC message"
        case .hidReport: "HID report"
        case .contact: "Contact"
        case .custom: "Custom"
        }
    }
}

public struct ControlMessageDescriptor: Codable, Hashable, Sendable {
    public var messageType: ControlMessageType
    /// Raw protocol channel (0...15 for MIDI 1); display conversion is governed
    /// by the binding's explicit channel-numbering base.
    public var channel: Int?
    /// Raw protocol note/controller/program number.
    public var number: Int?
    public var value: Int?
    public var rawDataHex: String?
    public var address: String?

    public init(messageType: ControlMessageType, channel: Int? = nil, number: Int? = nil, value: Int? = nil, rawDataHex: String? = nil, address: String? = nil) {
        self.messageType = messageType
        self.channel = channel
        self.number = number
        self.value = value
        self.rawDataHex = rawDataHex
        self.address = address
    }

    public var validationIssues: [String] {
        var result: [String] = []
        if let channel, !(0...15).contains(channel) { result.append("MIDI channel must be stored as raw 0…15.") }
        if let number, !(0...127).contains(number), messageType != .pitchBend { result.append("MIDI data number must be 0…127.") }
        if let value, !(0...16_383).contains(value) { result.append("Control value is outside the MIDI 1 range.") }
        if [.noteOn, .noteOff, .controlChange, .programChange, .polyphonicPressure].contains(messageType), number == nil {
            result.append("The message number has not been learned or entered.")
        }
        return result
    }
}

public enum ControlBindingVerification: String, Codable, CaseIterable, Identifiable, Sendable {
    case unverified
    case learned
    case inputVerified
    case roundTripVerified
    case failed
    public var id: String { rawValue }
}

public struct ControlBinding: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var componentID: String
    public var componentLabel: String
    public var label: String
    public var controlProtocol: ControlProtocol
    public var direction: ControlDirection
    public var channelNumberingBase: Int
    public var dataNumberingBase: Int
    public var activation: ControlMessageDescriptor?
    public var deactivation: ControlMessageDescriptor?
    public var continuous: ControlMessageDescriptor?
    public var sourceDeviceID: String?
    public var sourceDeviceName: String?
    public var destinationDeviceID: String?
    public var destinationDeviceName: String?
    public var source: String
    public var verification: ControlBindingVerification
    public var lastVerifiedAt: Date?
    public var notes: String

    public init(
        contractVersion: String = "orgrec.control-binding/v1",
        id: UUID = UUID(),
        componentID: String,
        componentLabel: String,
        label: String = "",
        controlProtocol: ControlProtocol = .midi1,
        direction: ControlDirection = .instrumentToOrgRec,
        channelNumberingBase: Int = 1,
        dataNumberingBase: Int = 0,
        activation: ControlMessageDescriptor? = nil,
        deactivation: ControlMessageDescriptor? = nil,
        continuous: ControlMessageDescriptor? = nil,
        sourceDeviceID: String? = nil,
        sourceDeviceName: String? = nil,
        destinationDeviceID: String? = nil,
        destinationDeviceName: String? = nil,
        source: String = "operator",
        verification: ControlBindingVerification = .unverified,
        lastVerifiedAt: Date? = nil,
        notes: String = ""
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.componentID = componentID
        self.componentLabel = componentLabel
        self.label = label.isEmpty ? componentLabel : label
        self.controlProtocol = controlProtocol
        self.direction = direction
        self.channelNumberingBase = channelNumberingBase
        self.dataNumberingBase = dataNumberingBase
        self.activation = activation
        self.deactivation = deactivation
        self.continuous = continuous
        self.sourceDeviceID = sourceDeviceID
        self.sourceDeviceName = sourceDeviceName
        self.destinationDeviceID = destinationDeviceID
        self.destinationDeviceName = destinationDeviceName
        self.source = source
        self.verification = verification
        self.lastVerifiedAt = lastVerifiedAt
        self.notes = notes
    }

    public var validationIssues: [String] {
        var result = (activation?.validationIssues ?? []) + (deactivation?.validationIssues ?? []) + (continuous?.validationIssues ?? [])
        if controlProtocol == .midi1 && ![0, 1].contains(channelNumberingBase) { result.append("Channel numbering base must be explicitly 0 or 1.") }
        if controlProtocol == .midi1 && ![0, 1].contains(dataNumberingBase) { result.append("Data numbering base must be explicitly 0 or 1.") }
        if activation == nil && deactivation == nil && continuous == nil { result.append("No control message has been mapped.") }
        if let activation, let deactivation, activation == deactivation { result.append("Activation and deactivation messages must be distinguishable.") }
        return Array(Set(result)).sorted()
    }
}

// MARK: - Synchronized control-event paradata

public enum ControlEventRole: String, Codable, CaseIterable, Sendable {
    case activation
    case deactivation
    case continuousChange
    case trigger
    case unmatched
}

public struct ControlEvent: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var bindingID: UUID?
    public var componentID: String?
    public var role: ControlEventRole
    public var controlProtocol: ControlProtocol
    public var message: ControlMessageDescriptor
    public var capturedAt: Date
    public var hostTimeTicks: UInt64
    public var hostTimeNanoseconds: UInt64
    public var timestampWasProvidedByTransport: Bool
    public var sourceDeviceID: String?
    public var sourceDeviceName: String?
    public var rawDataHex: String

    public init(
        id: UUID = UUID(),
        bindingID: UUID? = nil,
        componentID: String? = nil,
        role: ControlEventRole = .unmatched,
        controlProtocol: ControlProtocol,
        message: ControlMessageDescriptor,
        capturedAt: Date = .now,
        hostTimeTicks: UInt64,
        hostTimeNanoseconds: UInt64,
        timestampWasProvidedByTransport: Bool,
        sourceDeviceID: String? = nil,
        sourceDeviceName: String? = nil,
        rawDataHex: String
    ) {
        self.id = id
        self.bindingID = bindingID
        self.componentID = componentID
        self.role = role
        self.controlProtocol = controlProtocol
        self.message = message
        self.capturedAt = capturedAt
        self.hostTimeTicks = hostTimeTicks
        self.hostTimeNanoseconds = hostTimeNanoseconds
        self.timestampWasProvidedByTransport = timestampWasProvidedByTransport
        self.sourceDeviceID = sourceDeviceID
        self.sourceDeviceName = sourceDeviceName
        self.rawDataHex = rawDataHex
    }
}

public struct ControlEventLog: Codable, Hashable, Identifiable, Sendable {
    public var contractVersion: String
    public var id: UUID
    public var takeID: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var clockBasis: String
    public var sourceDeviceIDs: [String]
    public var events: [ControlEvent]

    public init(
        contractVersion: String = "orgrec.control-event-log/v1",
        id: UUID = UUID(),
        takeID: UUID,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        clockBasis: String = "CoreMIDI/CoreAudio shared host time",
        sourceDeviceIDs: [String] = [],
        events: [ControlEvent] = []
    ) {
        self.contractVersion = contractVersion
        self.id = id
        self.takeID = takeID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.clockBasis = clockBasis
        self.sourceDeviceIDs = sourceDeviceIDs
        self.events = events
    }
}

public enum AudioControlAlignmentStatus: String, Codable, CaseIterable, Sendable {
    case synchronizedSharedClock
    case estimated
    case unavailable
}

public struct AudioControlEventFrameMapping: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID { eventID }
    public var eventID: UUID
    public var audioFrame: Int64
    public var audioTimeSeconds: Double
    public var uncertaintySeconds: Double
    public var withinRecordedAudio: Bool
}

public struct AudioControlAlignment: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var eventLogID: UUID
    public var status: AudioControlAlignmentStatus
    public var clockBasis: String
    public var audioStartHostTimeTicks: UInt64?
    public var audioStartHostTimeNanoseconds: UInt64?
    public var audioStartSampleTime: Int64?
    public var offsetSeconds: Double
    public var driftPPM: Double?
    public var baseUncertaintySeconds: Double
    public var mappings: [AudioControlEventFrameMapping]
    public var notes: String

    public init(
        contractVersion: String = "orgrec.audio-control-alignment/v1",
        eventLogID: UUID,
        status: AudioControlAlignmentStatus,
        clockBasis: String,
        audioStartHostTimeTicks: UInt64?,
        audioStartHostTimeNanoseconds: UInt64?,
        audioStartSampleTime: Int64?,
        offsetSeconds: Double,
        driftPPM: Double?,
        baseUncertaintySeconds: Double,
        mappings: [AudioControlEventFrameMapping],
        notes: String = ""
    ) {
        self.contractVersion = contractVersion
        self.eventLogID = eventLogID
        self.status = status
        self.clockBasis = clockBasis
        self.audioStartHostTimeTicks = audioStartHostTimeTicks
        self.audioStartHostTimeNanoseconds = audioStartHostTimeNanoseconds
        self.audioStartSampleTime = audioStartSampleTime
        self.offsetSeconds = offsetSeconds
        self.driftPPM = driftPPM
        self.baseUncertaintySeconds = baseUncertaintySeconds
        self.mappings = mappings
        self.notes = notes
    }

    public static func sharedHostClock(
        eventLog: ControlEventLog,
        audioStartHostTimeTicks: UInt64?,
        audioStartHostTimeNanoseconds: UInt64?,
        audioStartSampleTime: Int64?,
        sampleRate: Double,
        frameCount: Int64
    ) -> Self {
        guard let startNanos = audioStartHostTimeNanoseconds, sampleRate > 0 else {
            return Self(
                eventLogID: eventLog.id,
                status: .unavailable,
                clockBasis: eventLog.clockBasis,
                audioStartHostTimeTicks: audioStartHostTimeTicks,
                audioStartHostTimeNanoseconds: audioStartHostTimeNanoseconds,
                audioStartSampleTime: audioStartSampleTime,
                offsetSeconds: 0,
                driftPPM: nil,
                baseUncertaintySeconds: 0.01,
                mappings: [],
                notes: "The first audio-buffer host timestamp was unavailable."
            )
        }
        let sampleUncertainty = max(0.000_1, 1 / sampleRate)
        let mappings = eventLog.events.map { event -> AudioControlEventFrameMapping in
            let seconds = (Double(event.hostTimeNanoseconds) - Double(startNanos)) / 1_000_000_000
            let frame = Int64((seconds * sampleRate).rounded())
            let uncertainty = event.timestampWasProvidedByTransport ? sampleUncertainty : max(0.003, sampleUncertainty)
            return AudioControlEventFrameMapping(
                eventID: event.id,
                audioFrame: frame,
                audioTimeSeconds: seconds,
                uncertaintySeconds: uncertainty,
                withinRecordedAudio: frame >= 0 && frame < frameCount
            )
        }
        return Self(
            eventLogID: eventLog.id,
            status: .synchronizedSharedClock,
            clockBasis: "CoreMIDI packet and first CoreAudio buffer host timestamps (shared macOS host clock)",
            audioStartHostTimeTicks: audioStartHostTimeTicks,
            audioStartHostTimeNanoseconds: startNanos,
            audioStartSampleTime: audioStartSampleTime,
            offsetSeconds: 0,
            driftPPM: 0,
            baseUncertaintySeconds: sampleUncertainty,
            mappings: mappings,
            notes: "Frame zero is the first buffer written to the audio file. Drift is zero by construction because both timestamps use the same host clock; transport-fallback timestamps carry larger per-event uncertainty."
        )
    }
}

/// Pure MIDI 1 parser used by the CoreMIDI monitor and unit tests. It accepts
/// multiple channel messages and running status in one packet.
public enum MIDI1MessageParser {
    public static func parse(_ bytes: [UInt8]) -> [(ControlMessageDescriptor, [UInt8])] {
        var result: [(ControlMessageDescriptor, [UInt8])] = []
        var index = 0
        var runningStatus: UInt8?
        while index < bytes.count {
            var status: UInt8
            if bytes[index] & 0x80 != 0 {
                status = bytes[index]
                index += 1
                if status < 0xF0 { runningStatus = status }
            } else if let saved = runningStatus {
                status = saved
            } else {
                index += 1
                continue
            }
            if status >= 0xF0 {
                if status == 0xF0, let end = bytes[index...].firstIndex(of: 0xF7) {
                    let raw = [status] + Array(bytes[index...end])
                    result.append((ControlMessageDescriptor(messageType: .systemExclusive, rawDataHex: hex(raw)), raw))
                    index = end + 1
                }
                runningStatus = nil
                continue
            }
            let command = status & 0xF0
            let length = (command == 0xC0 || command == 0xD0) ? 1 : 2
            guard index + length <= bytes.count else { break }
            let data = Array(bytes[index..<(index + length)])
            index += length
            let channel = Int(status & 0x0F)
            let descriptor: ControlMessageDescriptor
            switch command {
            case 0x80: descriptor = .init(messageType: .noteOff, channel: channel, number: Int(data[0]), value: Int(data[1]))
            case 0x90:
                descriptor = .init(messageType: data[1] == 0 ? .noteOff : .noteOn, channel: channel, number: Int(data[0]), value: Int(data[1]))
            case 0xA0: descriptor = .init(messageType: .polyphonicPressure, channel: channel, number: Int(data[0]), value: Int(data[1]))
            case 0xB0: descriptor = .init(messageType: .controlChange, channel: channel, number: Int(data[0]), value: Int(data[1]))
            case 0xC0: descriptor = .init(messageType: .programChange, channel: channel, number: Int(data[0]))
            case 0xD0: descriptor = .init(messageType: .channelPressure, channel: channel, value: Int(data[0]))
            case 0xE0: descriptor = .init(messageType: .pitchBend, channel: channel, value: Int(data[0]) | (Int(data[1]) << 7))
            default: continue
            }
            result.append((descriptor, [status] + data))
        }
        return result
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
