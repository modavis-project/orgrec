import AudioToolbox
import Combine
import CoreAudio
import Foundation
import OrgRecCore

struct CoreAudioDevice: Identifiable, Hashable, Sendable {
    var id: AudioDeviceID
    var uid: String
    var name: String
    var manufacturer: String
    var transport: String
    var inputChannels: Int
    var outputChannels: Int
    var nominalSampleRate: Double
    var availableSampleRates: [ClosedRange<Double>]
    var bufferFrames: Int
    var bufferFrameRange: ClosedRange<Int>
    var inputLatencyFrames: Int
    var inputSafetyOffsetFrames: Int
    var isAlive: Bool
    var isRunning: Bool
    var isAggregate: Bool

    var latencyMilliseconds: Double {
        guard nominalSampleRate > 0 else { return 0 }
        return Double(bufferFrames + inputLatencyFrames + inputSafetyOffsetFrames) / nominalSampleRate * 1_000
    }

    var detailLine: String {
        "\(inputChannels) in / \(outputChannels) out · \(transport) · \(Int(nominalSampleRate)) Hz · \(bufferFrames) frames"
    }

    func snapshot(mode: LowLatencyMode, sampleRate: Double, bufferFrames: Int) -> AudioDeviceSnapshot {
        let milliseconds = Double(bufferFrames + inputLatencyFrames + inputSafetyOffsetFrames) / max(1, sampleRate) * 1_000
        return AudioDeviceSnapshot(
            uid: uid,
            name: name,
            manufacturer: manufacturer,
            transport: transport,
            inputChannels: inputChannels,
            sampleRate: sampleRate,
            bufferFrames: bufferFrames,
            deviceLatencyFrames: inputLatencyFrames,
            safetyOffsetFrames: inputSafetyOffsetFrames,
            estimatedInputLatencyMilliseconds: milliseconds,
            lowLatencyMode: mode.rawValue
        )
    }
}

enum LowLatencyMode: String, CaseIterable, Identifiable, Sendable {
    case safe = "Safe"
    case balanced = "Balanced"
    case ultraLow = "Ultra-low"
    case custom = "Custom"

    var id: String { rawValue }

    var preferredFrames: Int? {
        switch self {
        case .safe: 512
        case .balanced: 256
        case .ultraLow: 64
        case .custom: nil
        }
    }
}

@MainActor
final class CoreAudioDeviceManager: ObservableObject {
    @Published private(set) var devices: [CoreAudioDevice] = []
    @Published var selectedUID: String = ""
    @Published var selectedSampleRate: Double = 48_000
    @Published var selectedBufferFrames: Int = 256
    @Published var latencyMode: LowLatencyMode = .balanced
    @Published var status = "Core Audio HAL"

    var selectedDevice: CoreAudioDevice? {
        devices.first { $0.uid == selectedUID }
    }

    init() {
        selectedUID = UserDefaults.standard.string(forKey: "OrgRec.selectedAudioDeviceUID") ?? ""
        let savedRate = UserDefaults.standard.double(forKey: "OrgRec.selectedSampleRate")
        if savedRate > 0 { selectedSampleRate = savedRate }
        let savedFrames = UserDefaults.standard.integer(forKey: "OrgRec.selectedBufferFrames")
        if savedFrames > 0 { selectedBufferFrames = savedFrames }
        if let raw = UserDefaults.standard.string(forKey: "OrgRec.lowLatencyMode"),
           let mode = LowLatencyMode(rawValue: raw) {
            latencyMode = mode
        }
        refresh()
        if let device = selectedDevice {
            if savedRate > 0,
               device.availableSampleRates.isEmpty || device.availableSampleRates.contains(where: { $0.contains(savedRate) }) {
                selectedSampleRate = savedRate
            }
            if savedFrames > 0 {
                selectedBufferFrames = max(device.bufferFrameRange.lowerBound, min(device.bufferFrameRange.upperBound, savedFrames))
            }
        }
    }

    func refresh() {
        devices = Self.allDevices().filter { $0.inputChannels > 0 && $0.isAlive }
            .sorted { lhs, rhs in
                if lhs.isAggregate != rhs.isAggregate { return lhs.isAggregate }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        let defaultID = Self.defaultInputDeviceID()
        if selectedUID.isEmpty || !devices.contains(where: { $0.uid == selectedUID }) {
            selectedUID = devices.first(where: { $0.id == defaultID })?.uid ?? devices.first?.uid ?? ""
        }
        adoptDeviceDefaults()
    }

    func select(uid: String) {
        selectedUID = uid
        UserDefaults.standard.set(uid, forKey: "OrgRec.selectedAudioDeviceUID")
        adoptDeviceDefaults()
    }

    func setLatencyMode(_ mode: LowLatencyMode) {
        latencyMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "OrgRec.lowLatencyMode")
        if let preferred = mode.preferredFrames, let device = selectedDevice {
            selectedBufferFrames = max(device.bufferFrameRange.lowerBound, min(device.bufferFrameRange.upperBound, preferred))
        }
    }

    func applyToHAL() throws {
        guard let device = selectedDevice else {
            throw NSError(domain: "OrgRec.CoreAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Core Audio input device is selected."])
        }
        try Self.setNominalSampleRate(selectedSampleRate, deviceID: device.id)
        try Self.setBufferFrames(UInt32(selectedBufferFrames), deviceID: device.id)
        if let refreshed = Self.device(device.id),
           let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = refreshed
            selectedSampleRate = refreshed.nominalSampleRate
            selectedBufferFrames = refreshed.bufferFrames
        }
        UserDefaults.standard.set(selectedSampleRate, forKey: "OrgRec.selectedSampleRate")
        UserDefaults.standard.set(selectedBufferFrames, forKey: "OrgRec.selectedBufferFrames")
        status = "AUHAL · \(Int(selectedSampleRate)) Hz · \(selectedBufferFrames) frames · \(estimatedLatency.formatted(.number.precision(.fractionLength(1)))) ms"
    }

    var estimatedLatency: Double {
        guard let device = selectedDevice else { return 0 }
        return Double(selectedBufferFrames + device.inputLatencyFrames + device.inputSafetyOffsetFrames)
            / max(1, selectedSampleRate) * 1_000
    }

    private func adoptDeviceDefaults() {
        guard let device = selectedDevice else { return }
        selectedSampleRate = device.nominalSampleRate
        setLatencyMode(latencyMode)
        status = "Core Audio HAL · \(device.transport)"
    }

    private static func allDevices() -> [CoreAudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap(device)
    }

    private static func device(_ id: AudioDeviceID) -> CoreAudioDevice? {
        let inputChannels = channelCount(id, scope: kAudioDevicePropertyScopeInput)
        let outputChannels = channelCount(id, scope: kAudioDevicePropertyScopeOutput)
        guard inputChannels + outputChannels > 0 else { return nil }
        let transportCode = uint32(id, selector: kAudioDevicePropertyTransportType) ?? 0
        let rateRanges = valueRanges(id, selector: kAudioDevicePropertyAvailableNominalSampleRates)
            .map { $0.mMinimum...$0.mMaximum }
        let frameRange = valueRange(id, selector: kAudioDevicePropertyBufferFrameSizeRange)
            .map { Int($0.mMinimum)...Int($0.mMaximum) } ?? 32...4_096
        return CoreAudioDevice(
            id: id,
            uid: string(id, selector: kAudioDevicePropertyDeviceUID) ?? "device-\(id)",
            name: string(id, selector: kAudioObjectPropertyName) ?? "Core Audio Device \(id)",
            manufacturer: string(id, selector: kAudioObjectPropertyManufacturer) ?? "",
            transport: transportName(transportCode),
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            nominalSampleRate: double(id, selector: kAudioDevicePropertyNominalSampleRate) ?? 48_000,
            availableSampleRates: rateRanges,
            bufferFrames: Int(uint32(id, selector: kAudioDevicePropertyBufferFrameSize) ?? 256),
            bufferFrameRange: frameRange,
            inputLatencyFrames: Int(uint32(id, selector: kAudioDevicePropertyLatency, scope: kAudioDevicePropertyScopeInput) ?? 0),
            inputSafetyOffsetFrames: Int(uint32(id, selector: kAudioDevicePropertySafetyOffset, scope: kAudioDevicePropertyScopeInput) ?? 0),
            isAlive: (uint32(id, selector: kAudioDevicePropertyDeviceIsAlive) ?? 1) != 0,
            isRunning: (uint32(id, selector: kAudioDevicePropertyDeviceIsRunningSomewhere) ?? 0) != 0,
            isAggregate: transportCode == kAudioDeviceTransportTypeAggregate
        )
    }

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = AudioDeviceID(0)
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func setNominalSampleRate(_ value: Double, deviceID: AudioDeviceID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutable = value
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: mutable)), &mutable)
        guard status == noErr else { throw osStatusError(status, operation: "set sample rate") }
    }

    private static func setBufferFrames(_ value: UInt32, deviceID: AudioDeviceID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutable = value
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: mutable)), &mutable)
        guard status == noErr else { throw osStatusError(status, operation: "set I/O buffer size") }
    }

    private static func string(_ id: AudioObjectID, selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value?.takeUnretainedValue() as String?
    }

    private static func uint32(
        _ id: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> UInt32? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func double(_ id: AudioObjectID, selector: AudioObjectPropertySelector) -> Double? {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var value = 0.0
        var size = UInt32(MemoryLayout.size(ofValue: value))
        return AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func valueRange(_ id: AudioObjectID, selector: AudioObjectPropertySelector) -> AudioValueRange? {
        valueRanges(id, selector: selector).first
    }

    private static func valueRanges(_ id: AudioObjectID, selector: AudioObjectPropertySelector) -> [AudioValueRange] {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr else { return [] }
        var values = [AudioValueRange](repeating: AudioValueRange(), count: Int(size) / MemoryLayout<AudioValueRange>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &values) == noErr else { return [] }
        return values
    }

    private static func channelCount(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr else { return 0 }
        let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { memory.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, memory) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to: AudioBufferList.self))
        return list.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func transportName(_ code: UInt32) -> String {
        switch code {
        case kAudioDeviceTransportTypeBuiltIn: return "Built-in"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeFireWire: return "FireWire"
        case kAudioDeviceTransportTypeThunderbolt: return "Thunderbolt"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "Bluetooth"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        case kAudioDeviceTransportTypeAggregate: return "Aggregate Device"
        case kAudioDeviceTransportTypeVirtual: return "Virtual"
        case kAudioDeviceTransportTypeAVB: return "AVB"
        case kAudioDeviceTransportTypePCI: return "PCI"
        default:
            let bytes = [
                UInt8((code >> 24) & 0xff), UInt8((code >> 16) & 0xff),
                UInt8((code >> 8) & 0xff), UInt8(code & 0xff),
            ]
            return String(bytes: bytes, encoding: .macOSRoman)?.trimmingCharacters(in: .whitespaces) ?? "Core Audio"
        }
    }

    private static func osStatusError(_ status: OSStatus, operation: String) -> NSError {
        NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: "Core Audio could not \(operation) (OSStatus \(status)). The interface may be clocked externally or in use by another application."]
        )
    }
}
