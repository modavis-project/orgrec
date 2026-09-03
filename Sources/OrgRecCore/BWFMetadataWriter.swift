import Foundation

public enum BWFMetadataWriter {
    public struct Result: Sendable {
        public var embedded: Bool
        public var sidecarURL: URL
        public var message: String
    }

    /// Writes a lossless JSON sidecar and embeds an EBU Tech 3285 metadata
    /// chunk into standard-size RIFF/WAVE files without changing audio samples.
    public static func finalize(audioURL: URL, metadata: BWFMetadata) throws -> Result {
        let sidecar = audioURL.deletingPathExtension().appendingPathExtension("bwf.json")
        try OrgRecCoding.encoder.encode(metadata).write(to: sidecar, options: .atomic)

        let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let bext = bextChunk(metadata)
        let (updatedFileSize, sizeOverflow) = fileSize.addingReportingOverflow(UInt64(bext.count))
        guard fileSize >= 12,
              sizeOverflow == false,
              updatedFileSize >= 8,
              updatedFileSize - 8 <= UInt64(UInt32.max) else {
            return Result(
                embedded: false,
                sidecarURL: sidecar,
                message: "BWF metadata retained in the sidecar; this RF64-size asset was not rewritten."
            )
        }

        let source = try FileHandle(forReadingFrom: audioURL)
        defer { try? source.close() }
        guard let header = try source.read(upToCount: 12), header.count == 12,
              String(data: header[0..<4], encoding: .ascii) == "RIFF",
              String(data: header[8..<12], encoding: .ascii) == "WAVE" else {
            return Result(embedded: false, sidecarURL: sidecar, message: "BWF sidecar written; the audio container is not standard RIFF/WAVE.")
        }

        let temporary = audioURL.deletingLastPathComponent()
            .appendingPathComponent(".bwf-\(UUID().uuidString).wav")
        FileManager.default.createFile(atPath: temporary.path, contents: nil)
        let destination = try FileHandle(forWritingTo: temporary)
        do {
            var updatedHeader = header
            updatedHeader.replaceSubrange(4..<8, with: littleEndian(UInt32(updatedFileSize - 8)))
            try destination.write(contentsOf: updatedHeader)
            try destination.write(contentsOf: bext)
            while let block = try source.read(upToCount: 1_048_576), !block.isEmpty {
                try destination.write(contentsOf: block)
            }
            try destination.synchronize()
            try destination.close()
            _ = try FileManager.default.replaceItemAt(audioURL, withItemAt: temporary)
            return Result(embedded: true, sidecarURL: sidecar, message: "EBU Tech 3285 metadata embedded.")
        } catch {
            try? destination.close()
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private static func bextChunk(_ metadata: BWFMetadata) -> Data {
        var payload = Data()
        payload.append(fixed(metadata.description, count: 256))
        payload.append(fixed(metadata.originator, count: 32))
        payload.append(fixed(metadata.originatorReference, count: 32))
        payload.append(fixed(metadata.originationDate, count: 10))
        payload.append(fixed(metadata.originationTime, count: 8))
        payload.append(littleEndian(UInt32(metadata.timeReferenceSamples & 0xffff_ffff)))
        payload.append(littleEndian(UInt32(metadata.timeReferenceSamples >> 32)))
        payload.append(littleEndian(UInt16(2)))
        payload.append(Data(repeating: 0, count: 64))
        payload.append(Data(repeating: 0, count: 10))
        payload.append(Data(repeating: 0, count: 180))
        if metadata.codingHistory.isEmpty == false {
            var history = Array(metadata.codingHistory.data(using: .ascii, allowLossyConversion: true) ?? Data())
            while history.last == 0x0a || history.last == 0x0d { history.removeLast() }
            history.append(contentsOf: [0x0d, 0x0a])
            payload.append(contentsOf: history)
        }

        var chunk = Data("bext".utf8)
        chunk.append(littleEndian(UInt32(payload.count)))
        chunk.append(payload)
        if payload.count.isMultiple(of: 2) == false { chunk.append(0) }
        return chunk
    }

    private static func fixed(_ string: String, count: Int) -> Data {
        let bytes = Array(string.data(using: .ascii, allowLossyConversion: true) ?? Data())
        return Data(bytes.prefix(count)) + Data(repeating: 0, count: max(0, count - bytes.count))
    }

    private static func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
        var mutable = value.littleEndian
        return withUnsafeBytes(of: &mutable) { Data($0) }
    }
}
