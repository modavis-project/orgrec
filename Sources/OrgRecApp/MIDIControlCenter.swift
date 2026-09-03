import AudioToolbox
import Combine
import CoreMIDI
import Foundation
import OrgRecCore

struct MIDIEndpointChoice: Identifiable, Hashable {
    var id: String
    var endpoint: MIDIEndpointRef
    var name: String
    var manufacturer: String

    var displayName: String {
        manufacturer.isEmpty || name.localizedCaseInsensitiveContains(manufacturer) ? name : "\(manufacturer) · \(name)"
    }
}

enum MIDILearnSlot: String, Sendable {
    case activation
    case deactivation
    case continuous
}

struct MIDILearnedMessage: Identifiable, Sendable {
    var id = UUID()
    var slot: MIDILearnSlot
    var message: ControlMessageDescriptor
    var rawDataHex: String
    var sourceID: String?
    var sourceName: String?
}

struct MIDIInputObservation: Identifiable, Sendable {
    var id = UUID()
    var message: ControlMessageDescriptor
    var hostTimeNanoseconds: UInt64
    var sourceID: String?
    var sourceName: String?
}

fileprivate struct CopiedMIDIPacket: Sendable {
    var timestamp: UInt64
    var bytes: [UInt8]
}

final class MIDIControlCenter: ObservableObject, @unchecked Sendable {
    @Published private(set) var sources: [MIDIEndpointChoice] = []
    @Published private(set) var destinations: [MIDIEndpointChoice] = []
    @Published var selectedSourceID: String? {
        didSet { reconnectSelectedSource() }
    }
    @Published var selectedDestinationID: String?
    @Published private(set) var lastIncomingMessage: ControlMessageDescriptor?
    @Published private(set) var lastIncomingRawHex = ""
    @Published private(set) var lastIncomingObservation: MIDIInputObservation?
    @Published private(set) var learnedMessage: MIDILearnedMessage?
    @Published private(set) var learningSlot: MIDILearnSlot?
    @Published private(set) var status = "No MIDI input selected"

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var connectedSource: MIDIEndpointRef?
    private var activeEventLog: ControlEventLog?
    private var captureBindings: [ControlBinding] = []

    init() {
        MIDIClientCreate("OrgRec MIDI" as CFString, nil, nil, &client)
        let context = Unmanaged.passUnretained(self).toOpaque()
        MIDIInputPortCreate(client, "OrgRec MIDI Input" as CFString, orgRecMIDIReadProc, context, &inputPort)
        MIDIOutputPortCreate(client, "OrgRec MIDI Output" as CFString, &outputPort)
        refreshEndpoints()
    }

    deinit {
        if let connectedSource { MIDIPortDisconnectSource(inputPort, connectedSource) }
        MIDIPortDispose(inputPort)
        MIDIPortDispose(outputPort)
        MIDIClientDispose(client)
    }

    func refreshEndpoints() {
        sources = (0..<MIDIGetNumberOfSources()).compactMap { choice(endpoint: MIDIGetSource($0)) }
        destinations = (0..<MIDIGetNumberOfDestinations()).compactMap { choice(endpoint: MIDIGetDestination($0)) }
        if selectedSourceID == nil { selectedSourceID = sources.first?.id }
        if selectedDestinationID == nil { selectedDestinationID = destinations.first?.id }
        status = selectedSourceID == nil ? "No MIDI input selected" : "Listening for MIDI 1.0 channel messages"
    }

    func armLearn(_ slot: MIDILearnSlot) {
        learningSlot = slot
        status = "Waiting for \(slot.rawValue) message…"
    }

    func cancelLearn() {
        learningSlot = nil
        status = selectedSourceID == nil ? "No MIDI input selected" : "Listening for MIDI 1.0 channel messages"
    }

    func beginCapture(takeID: UUID, bindings: [ControlBinding]) {
        captureBindings = bindings
        activeEventLog = ControlEventLog(
            takeID: takeID,
            sourceDeviceIDs: selectedSourceID.map { [$0] } ?? []
        )
    }

    func cancelCapture() {
        activeEventLog = nil
        captureBindings = []
    }

    func endCapture() -> ControlEventLog? {
        guard var log = activeEventLog else { return nil }
        log.endedAt = .now
        activeEventLog = nil
        captureBindings = []
        return log
    }

    @discardableResult
    func sendTest(_ descriptor: ControlMessageDescriptor, to destinationID: String? = nil) -> OSStatus {
        guard let bytes = Self.midiBytes(for: descriptor),
              let destination = destinations.first(where: { $0.id == (destinationID ?? selectedDestinationID) }) else {
            return kMIDIInvalidClient
        }
        var packetList = MIDIPacketList()
        let packet = MIDIPacketListInit(&packetList)
        _ = bytes.withUnsafeBufferPointer { pointer in
            MIDIPacketListAdd(&packetList, 1024, packet, 0, bytes.count, pointer.baseAddress!)
        }
        return MIDISend(outputPort, destination.endpoint, &packetList)
    }

    private func receive(_ packets: [CopiedMIDIPacket]) {
        let source = sources.first { $0.id == selectedSourceID }
        for packet in packets {
            for (message, raw) in MIDI1MessageParser.parse(packet.bytes) {
                let rawHex = raw.map { String(format: "%02X", $0) }.joined(separator: " ")
                lastIncomingMessage = message
                lastIncomingRawHex = rawHex
                let ticks = packet.timestamp != 0 ? packet.timestamp : AudioGetCurrentHostTime()
                lastIncomingObservation = MIDIInputObservation(
                    message: message,
                    hostTimeNanoseconds: AudioConvertHostTimeToNanos(ticks),
                    sourceID: source?.id,
                    sourceName: source?.displayName
                )
                if let slot = learningSlot {
                    learnedMessage = MIDILearnedMessage(
                        slot: slot,
                        message: message,
                        rawDataHex: rawHex,
                        sourceID: source?.id,
                        sourceName: source?.displayName
                    )
                    learningSlot = nil
                    status = "Learned \(slot.rawValue): \(message.messageType.displayName)"
                }
                appendCaptureEvent(message: message, rawHex: rawHex, packetTimestamp: packet.timestamp, source: source)
            }
        }
    }

    private func appendCaptureEvent(
        message: ControlMessageDescriptor,
        rawHex: String,
        packetTimestamp: UInt64,
        source: MIDIEndpointChoice?
    ) {
        guard var log = activeEventLog else { return }
        let match = Self.match(message, in: captureBindings)
        let provided = packetTimestamp != 0
        let ticks = provided ? packetTimestamp : AudioGetCurrentHostTime()
        let nanos = AudioConvertHostTimeToNanos(ticks)
        log.events.append(ControlEvent(
            bindingID: match?.binding.id,
            componentID: match?.binding.componentID,
            role: match?.role ?? .unmatched,
            controlProtocol: .midi1,
            message: message,
            hostTimeTicks: ticks,
            hostTimeNanoseconds: nanos,
            timestampWasProvidedByTransport: provided,
            sourceDeviceID: source?.id,
            sourceDeviceName: source?.displayName,
            rawDataHex: rawHex
        ))
        activeEventLog = log
    }

    private func reconnectSelectedSource() {
        if let connectedSource {
            MIDIPortDisconnectSource(inputPort, connectedSource)
            self.connectedSource = nil
        }
        guard let source = sources.first(where: { $0.id == selectedSourceID }) else {
            status = "No MIDI input selected"
            return
        }
        let result = MIDIPortConnectSource(inputPort, source.endpoint, nil)
        if result == noErr {
            connectedSource = source.endpoint
            status = "Listening to \(source.displayName)"
        } else {
            status = "Could not connect MIDI input (OSStatus \(result))"
        }
    }

    private func choice(endpoint: MIDIEndpointRef) -> MIDIEndpointChoice? {
        guard endpoint != 0 else { return nil }
        var name: Unmanaged<CFString>?
        var manufacturer: Unmanaged<CFString>?
        var uniqueID: Int32 = 0
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name)
        MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer)
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
        return MIDIEndpointChoice(
            id: uniqueID == 0 ? "endpoint:\(endpoint)" : "coremidi:\(uniqueID)",
            endpoint: endpoint,
            name: name?.takeRetainedValue() as String? ?? "MIDI endpoint \(endpoint)",
            manufacturer: manufacturer?.takeRetainedValue() as String? ?? ""
        )
    }

    nonisolated fileprivate static func copyPackets(_ list: UnsafePointer<MIDIPacketList>) -> [CopiedMIDIPacket] {
        var result: [CopiedMIDIPacket] = []
        let packetOffset = MemoryLayout<MIDIPacketList>.offset(of: \MIDIPacketList.packet) ?? MemoryLayout<UInt32>.stride
        var packetPointer = UnsafeMutableRawPointer(mutating: list)
            .advanced(by: packetOffset)
            .assumingMemoryBound(to: MIDIPacket.self)
        for _ in 0..<list.pointee.numPackets {
            let packet = packetPointer.pointee
            let bytes = withUnsafeBytes(of: packet.data) { raw in
                Array(raw.prefix(Int(packet.length)))
            }
            result.append(CopiedMIDIPacket(timestamp: packet.timeStamp, bytes: bytes))
            packetPointer = MIDIPacketNext(packetPointer)
        }
        return result
    }

    private static func match(_ message: ControlMessageDescriptor, in bindings: [ControlBinding]) -> (binding: ControlBinding, role: ControlEventRole)? {
        for binding in bindings {
            if matches(message, template: binding.activation) { return (binding, .activation) }
            if matches(message, template: binding.deactivation) { return (binding, .deactivation) }
            if matches(message, template: binding.continuous, ignoreValue: true) { return (binding, .continuousChange) }
        }
        return nil
    }

    private static func matches(_ event: ControlMessageDescriptor, template: ControlMessageDescriptor?, ignoreValue: Bool = false) -> Bool {
        guard let template, template.messageType == event.messageType else { return false }
        if let channel = template.channel, channel != event.channel { return false }
        if let number = template.number, number != event.number { return false }
        let valueDefinesIdentity = ![ControlMessageType.noteOn, .noteOff, .pitchBend, .channelPressure, .polyphonicPressure].contains(template.messageType)
        if !ignoreValue, valueDefinesIdentity, let value = template.value, value != event.value { return false }
        return true
    }

    private static func midiBytes(for descriptor: ControlMessageDescriptor) -> [UInt8]? {
        let channel = UInt8(descriptor.channel ?? 0) & 0x0F
        func byte(_ value: Int?) -> UInt8 { UInt8(max(0, min(127, value ?? 0))) }
        switch descriptor.messageType {
        case .noteOn: return [0x90 | channel, byte(descriptor.number), byte(descriptor.value ?? 127)]
        case .noteOff: return [0x80 | channel, byte(descriptor.number), byte(descriptor.value)]
        case .controlChange: return [0xB0 | channel, byte(descriptor.number), byte(descriptor.value)]
        case .programChange: return [0xC0 | channel, byte(descriptor.number)]
        case .channelPressure: return [0xD0 | channel, byte(descriptor.value)]
        case .polyphonicPressure: return [0xA0 | channel, byte(descriptor.number), byte(descriptor.value)]
        case .pitchBend:
            let value = max(0, min(16_383, descriptor.value ?? 8_192))
            return [0xE0 | channel, UInt8(value & 0x7F), UInt8((value >> 7) & 0x7F)]
        default: return nil
        }
    }
}

private let orgRecMIDIReadProc: MIDIReadProc = { packetList, refCon, _ in
    guard let refCon else { return }
    let packets = MIDIControlCenter.copyPackets(packetList)
    guard packets.isEmpty == false else { return }
    let owner = Unmanaged<MIDIControlCenter>.fromOpaque(refCon).takeUnretainedValue()
    DispatchQueue.main.async { owner.receiveFromMIDIReadProc(packets) }
}

private extension MIDIControlCenter {
    func receiveFromMIDIReadProc(_ packets: [CopiedMIDIPacket]) {
        receive(packets)
    }
}
