import Foundation

public struct WAVEmbeddedSampleLoop: Codable, Hashable, Sendable {
    public var cuePointID: UInt32
    public var typeCode: UInt32
    public var mode: String
    public var startFrameInclusive: Int64
    public var sourceEndFrameInclusive: Int64
    public var endFrameExclusive: Int64
    public var fraction: UInt32
    public var playCount: UInt32
    public var isUsable: Bool
    public var rejectionReason: String?
}

public struct WAVSamplerMetadata: Codable, Hashable, Sendable {
    public var contract: String
    public var container: String
    public var chunkOffset: Int64
    public var manufacturerCode: UInt32
    public var productCode: UInt32
    public var samplePeriodNanoseconds: UInt32
    public var midiUnityNote: UInt32
    public var midiPitchFraction: UInt32
    public var smpteFormat: UInt32
    public var smpteOffset: UInt32
    public var loops: [WAVEmbeddedSampleLoop]
    public var samplerDataByteCount: UInt32
    public var warnings: [String]
}

public enum WAVSamplerMetadataReader {
    private static let maximumSamplerChunkBytes = 16 * 1024 * 1024

    /// Reads RIFF/RF64/RIFX chunk headers without loading the audio data chunk.
    /// Unknown chunks are skipped and no source byte is modified.
    public static func read(from url: URL) throws -> WAVSamplerMetadata? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        try handle.seek(toOffset: 0)
        guard let header = try handle.read(upToCount: 12), header.count == 12 else { return nil }
        return try read(
            header: header,
            fileSize: fileSize,
            readAt: { offset, count in
                try handle.seek(toOffset: offset)
                return try handle.read(upToCount: count) ?? Data()
            }
        )
    }

    public static func read(from data: Data) throws -> WAVSamplerMetadata? {
        guard data.count >= 12 else { return nil }
        return try read(
            header: data.prefix(12),
            fileSize: UInt64(data.count),
            readAt: { offset, count in
                guard offset <= UInt64(data.count), count >= 0 else { return Data() }
                let lower = Int(offset)
                let upper = min(data.count, lower + count)
                guard lower <= upper else { return Data() }
                return data.subdata(in: lower..<upper)
            }
        )
    }

    private static func read(
        header: Data,
        fileSize: UInt64,
        readAt: (UInt64, Int) throws -> Data
    ) throws -> WAVSamplerMetadata? {
        let container = ascii(header, 0..<4)
        guard ["RIFF", "RF64", "RIFX"].contains(container), ascii(header, 8..<12) == "WAVE" else { return nil }
        let bigEndian = container == "RIFX"
        var offset: UInt64 = 12
        var rf64DataSize: UInt64?
        var rf64ChunkSizes: [String: [UInt64]] = [:]
        while offset <= fileSize, fileSize - offset >= 8 {
            let chunkHeader = try readAt(offset, 8)
            guard chunkHeader.count == 8 else { return nil }
            let chunkID = ascii(chunkHeader, 0..<4)
            let size32 = uint32(chunkHeader, at: 4, bigEndian: bigEndian)
            var declaredSize = UInt64(size32)
            let dataOffset = offset + 8
            if chunkID == "ds64", container == "RF64" {
                guard declaredSize >= 28, declaredSize <= UInt64(maximumSamplerChunkBytes),
                      declaredSize <= UInt64(Int.max), dataOffset <= fileSize,
                      declaredSize <= fileSize - dataOffset else { return nil }
                let payload = try readAt(dataOffset, Int(declaredSize))
                guard payload.count == Int(declaredSize) else { return nil }
                rf64DataSize = uint64(payload, at: 8, bigEndian: false)
                let entryCount = Int(uint32(payload, at: 24, bigEndian: false))
                guard entryCount <= (payload.count - 28) / 12 else { return nil }
                for index in 0..<entryCount {
                    let base = 28 + index * 12
                    rf64ChunkSizes[ascii(payload, base..<(base + 4)), default: []]
                        .append(uint64(payload, at: base + 4, bigEndian: false))
                }
            }
            if size32 == UInt32.max {
                if container != "RF64" { return nil }
                if chunkID == "data", let dataSize = rf64DataSize {
                    declaredSize = dataSize
                } else if var values = rf64ChunkSizes[chunkID], !values.isEmpty {
                    declaredSize = values.removeFirst()
                    rf64ChunkSizes[chunkID] = values
                } else {
                    return nil
                }
            }
            if chunkID == "smpl" {
                guard declaredSize <= UInt64(maximumSamplerChunkBytes),
                      declaredSize <= UInt64(Int.max),
                      dataOffset <= fileSize,
                      declaredSize <= fileSize - dataOffset else {
                    throw OrgRecError.invalidProject("WAVE smpl chunk is truncated or exceeds the safe metadata limit.")
                }
                let payload = try readAt(dataOffset, Int(declaredSize))
                return parseSamplerChunk(payload, container: container, chunkOffset: offset, bigEndian: bigEndian)
            }
            // RF64 0xffffffff sentinels have been resolved through ds64 above;
            // chunk payloads are still skipped rather than loaded.
            let paddedSize = declaredSize + (declaredSize & 1)
            guard dataOffset <= fileSize, paddedSize <= fileSize - dataOffset else { return nil }
            offset = dataOffset + paddedSize
        }
        return nil
    }

    private static func parseSamplerChunk(
        _ data: Data,
        container: String,
        chunkOffset: UInt64,
        bigEndian: Bool
    ) -> WAVSamplerMetadata? {
        guard data.count >= 36 else { return nil }
        let declaredLoopCount = Int(uint32(data, at: 28, bigEndian: bigEndian))
        let availableLoopCount = max(0, (data.count - 36) / 24)
        let loopCount = min(declaredLoopCount, availableLoopCount)
        var warnings: [String] = []
        if declaredLoopCount > availableLoopCount {
            warnings.append("The smpl chunk declares \(declaredLoopCount) loops but contains only \(availableLoopCount) complete records.")
        }
        var loops: [WAVEmbeddedSampleLoop] = []
        loops.reserveCapacity(loopCount)
        for index in 0..<loopCount {
            let base = 36 + index * 24
            let start = Int64(uint32(data, at: base + 8, bigEndian: bigEndian))
            let inclusiveEnd = Int64(uint32(data, at: base + 12, bigEndian: bigEndian))
            let type = uint32(data, at: base + 4, bigEndian: bigEndian)
            let usable = inclusiveEnd >= start
            loops.append(WAVEmbeddedSampleLoop(
                cuePointID: uint32(data, at: base, bigEndian: bigEndian),
                typeCode: type,
                mode: type == 0 ? "forward" : (type == 1 ? "alternating" : (type == 2 ? "backward" : "unknown")),
                startFrameInclusive: start,
                sourceEndFrameInclusive: inclusiveEnd,
                endFrameExclusive: inclusiveEnd + 1,
                fraction: uint32(data, at: base + 16, bigEndian: bigEndian),
                playCount: uint32(data, at: base + 20, bigEndian: bigEndian),
                isUsable: usable && type <= 2,
                rejectionReason: !usable ? "The inclusive end precedes the start." : (type > 2 ? "The loop type is not defined by RIFF smpl." : nil)
            ))
        }
        return WAVSamplerMetadata(
            contract: "orgrec.wav-smpl-metadata/v1",
            container: container,
            chunkOffset: Int64(chunkOffset),
            manufacturerCode: uint32(data, at: 0, bigEndian: bigEndian),
            productCode: uint32(data, at: 4, bigEndian: bigEndian),
            samplePeriodNanoseconds: uint32(data, at: 8, bigEndian: bigEndian),
            midiUnityNote: uint32(data, at: 12, bigEndian: bigEndian),
            midiPitchFraction: uint32(data, at: 16, bigEndian: bigEndian),
            smpteFormat: uint32(data, at: 20, bigEndian: bigEndian),
            smpteOffset: uint32(data, at: 24, bigEndian: bigEndian),
            loops: loops,
            samplerDataByteCount: uint32(data, at: 32, bigEndian: bigEndian),
            warnings: warnings
        )
    }

    private static func ascii(_ data: Data, _ range: Range<Int>) -> String {
        guard range.lowerBound >= 0, range.upperBound <= data.count else { return "" }
        return String(decoding: data[range], as: UTF8.self)
    }

    private static func uint32(_ data: Data, at offset: Int, bigEndian: Bool) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        let bytes = data[offset..<(offset + 4)]
        if bigEndian {
            return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }
        return bytes.reversed().reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func uint64(_ data: Data, at offset: Int, bigEndian: Bool) -> UInt64 {
        guard offset >= 0, offset + 8 <= data.count else { return 0 }
        let bytes = data[offset..<(offset + 8)]
        if bigEndian {
            return bytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        }
        return bytes.reversed().reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }
}
