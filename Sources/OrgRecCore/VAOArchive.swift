import CryptoKit
import Foundation

struct VAOArchiveEntrySource {
    var path: String
    var data: Data?
    var fileURL: URL?

    init(path: String, data: Data) {
        self.path = path
        self.data = data
        self.fileURL = nil
    }

    init(path: String, fileURL: URL) {
        self.path = path
        self.data = nil
        self.fileURL = fileURL
    }
}

struct VAOArchiveEntry: Sendable {
    var path: String
    var compressionMethod: UInt16
    var flags: UInt16
    var crc32: UInt32
    var compressedSize: UInt64
    var uncompressedSize: UInt64
    var localHeaderOffset: UInt64
    var externalAttributes: UInt32

    var isDirectory: Bool { path.hasSuffix("/") }
}

private struct VAOCRC32 {
    private static let table: [UInt32] = (0..<256).map { raw in
        var value = UInt32(raw)
        for _ in 0..<8 {
            value = (value & 1) == 1 ? (value >> 1) ^ 0xedb88320 : value >> 1
        }
        return value
    }

    private var value: UInt32 = 0xffffffff

    mutating func update(_ data: Data) {
        for byte in data {
            value = Self.table[Int((value ^ UInt32(byte)) & 0xff)] ^ (value >> 8)
        }
    }

    var final: UInt32 { value ^ 0xffffffff }
}

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var copy = value.littleEndian
        Swift.withUnsafeBytes(of: &copy) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var copy = value.littleEndian
        Swift.withUnsafeBytes(of: &copy) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt64) {
        var copy = value.littleEndian
        Swift.withUnsafeBytes(of: &copy) { append(contentsOf: $0) }
    }

    func uint16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func uint64LE(at offset: Int) -> UInt64 {
        UInt64(uint32LE(at: offset)) | (UInt64(uint32LE(at: offset + 4)) << 32)
    }
}

private func archivePathIsSafe(_ path: String) -> Bool {
    guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else { return false }
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    return components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
}

enum VAOArchiveWriter {
    private struct Metadata {
        var path: String
        var name: Data
        var crc32: UInt32
        var size: UInt64
        var offset: UInt64
    }

    static func write(entries: [VAOArchiveEntrySource], to destination: URL) throws {
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw OrgRecError.exportValidation("VAO destination already exists: \(destination.lastPathComponent)")
        }
        guard !entries.isEmpty, entries.first?.path == "mimetype" else {
            throw OrgRecError.exportValidation("The first VAO archive entry must be mimetype.")
        }
        let paths = entries.map(\.path)
        let normalizedPaths = paths.map(\.precomposedStringWithCanonicalMapping)
        guard Set(normalizedPaths).count == paths.count, paths.allSatisfy(archivePathIsSafe) else {
            throw OrgRecError.exportValidation("VAO archive entry paths are unsafe or duplicated.")
        }
        for source in entries {
            guard source.path.utf8.count <= Int(UInt16.max) else {
                throw OrgRecError.exportValidation("VAO archive path is too long: \(source.path)")
            }
            guard (source.data == nil) != (source.fileURL == nil) else {
                throw OrgRecError.exportValidation("VAO entry \(source.path) has an invalid source.")
            }
        }

        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).partial")
        FileManager.default.createFile(atPath: temporary.path, contents: nil)
        do {
            let handle = try FileHandle(forWritingTo: temporary)
            defer { try? handle.close() }
            var metadata: [Metadata] = []

            for source in entries {
                let statistics = try entryStatistics(source)
                let offset = try handle.offset()
                let name = Data(source.path.utf8)
                let needsZip64 = statistics.size >= UInt64(UInt32.max)
                var extra = Data()
                if needsZip64 {
                    extra.appendLE(UInt16(0x0001))
                    extra.appendLE(UInt16(16))
                    extra.appendLE(statistics.size)
                    extra.appendLE(statistics.size)
                }
                var header = Data()
                header.appendLE(UInt32(0x04034b50))
                header.appendLE(UInt16(needsZip64 ? 45 : 20))
                header.appendLE(UInt16(0x0800))
                header.appendLE(UInt16(0))
                header.appendLE(UInt16(0))
                header.appendLE(UInt16(0))
                header.appendLE(statistics.crc32)
                header.appendLE(needsZip64 ? UInt32.max : UInt32(statistics.size))
                header.appendLE(needsZip64 ? UInt32.max : UInt32(statistics.size))
                header.appendLE(UInt16(name.count))
                header.appendLE(UInt16(extra.count))
                header.append(name)
                header.append(extra)
                try handle.write(contentsOf: header)
                try writeContents(source, to: handle)
                metadata.append(Metadata(path: source.path, name: name, crc32: statistics.crc32, size: statistics.size, offset: offset))
            }

            let centralOffset = try handle.offset()
            for entry in metadata {
                let largeSize = entry.size >= UInt64(UInt32.max)
                let largeOffset = entry.offset >= UInt64(UInt32.max)
                var extraPayload = Data()
                if largeSize {
                    extraPayload.appendLE(entry.size)
                    extraPayload.appendLE(entry.size)
                }
                if largeOffset { extraPayload.appendLE(entry.offset) }
                var extra = Data()
                if !extraPayload.isEmpty {
                    extra.appendLE(UInt16(0x0001))
                    extra.appendLE(UInt16(extraPayload.count))
                    extra.append(extraPayload)
                }

                var central = Data()
                central.appendLE(UInt32(0x02014b50))
                central.appendLE(UInt16((3 << 8) | 45))
                central.appendLE(UInt16(largeSize || largeOffset ? 45 : 20))
                central.appendLE(UInt16(0x0800))
                central.appendLE(UInt16(0))
                central.appendLE(UInt16(0))
                central.appendLE(UInt16(0))
                central.appendLE(entry.crc32)
                central.appendLE(largeSize ? UInt32.max : UInt32(entry.size))
                central.appendLE(largeSize ? UInt32.max : UInt32(entry.size))
                central.appendLE(UInt16(entry.name.count))
                central.appendLE(UInt16(extra.count))
                central.appendLE(UInt16(0))
                central.appendLE(UInt16(0))
                central.appendLE(UInt16(0))
                central.appendLE(UInt32(0o100644 << 16))
                central.appendLE(largeOffset ? UInt32.max : UInt32(entry.offset))
                central.append(entry.name)
                central.append(extra)
                try handle.write(contentsOf: central)
            }
            let centralEnd = try handle.offset()
            let centralSize = centralEnd - centralOffset
            let usesZip64 = metadata.count >= Int(UInt16.max)
                || centralOffset >= UInt64(UInt32.max)
                || centralSize >= UInt64(UInt32.max)
                || metadata.contains { $0.size >= UInt64(UInt32.max) || $0.offset >= UInt64(UInt32.max) }

            if usesZip64 {
                let zip64Offset = try handle.offset()
                var record = Data()
                record.appendLE(UInt32(0x06064b50))
                record.appendLE(UInt64(44))
                record.appendLE(UInt16((3 << 8) | 45))
                record.appendLE(UInt16(45))
                record.appendLE(UInt32(0))
                record.appendLE(UInt32(0))
                record.appendLE(UInt64(metadata.count))
                record.appendLE(UInt64(metadata.count))
                record.appendLE(centralSize)
                record.appendLE(centralOffset)
                try handle.write(contentsOf: record)

                var locator = Data()
                locator.appendLE(UInt32(0x07064b50))
                locator.appendLE(UInt32(0))
                locator.appendLE(zip64Offset)
                locator.appendLE(UInt32(1))
                try handle.write(contentsOf: locator)
            }

            var end = Data()
            end.appendLE(UInt32(0x06054b50))
            end.appendLE(UInt16(0))
            end.appendLE(UInt16(0))
            end.appendLE(usesZip64 ? UInt16.max : UInt16(metadata.count))
            end.appendLE(usesZip64 ? UInt16.max : UInt16(metadata.count))
            end.appendLE(usesZip64 ? UInt32.max : UInt32(centralSize))
            end.appendLE(usesZip64 ? UInt32.max : UInt32(centralOffset))
            end.appendLE(UInt16(0))
            try handle.write(contentsOf: end)
            try handle.synchronize()
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private static func entryStatistics(_ source: VAOArchiveEntrySource) throws -> (crc32: UInt32, size: UInt64) {
        var crc = VAOCRC32()
        if let data = source.data {
            crc.update(data)
            return (crc.final, UInt64(data.count))
        }
        guard let url = source.fileURL else {
            throw OrgRecError.exportValidation("VAO entry has no content source.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var size: UInt64 = 0
        while true {
            let data = try handle.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            size += UInt64(data.count)
            crc.update(data)
        }
        return (crc.final, size)
    }

    private static func writeContents(_ source: VAOArchiveEntrySource, to output: FileHandle) throws {
        if let data = source.data {
            try output.write(contentsOf: data)
            return
        }
        guard let url = source.fileURL else { return }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }
        while true {
            let data = try input.read(upToCount: 1_048_576) ?? Data()
            if data.isEmpty { break }
            try output.write(contentsOf: data)
        }
    }
}

final class VAOArchiveReader {
    static let maximumEntries = 100_000
    static let maximumManifestBytes: UInt64 = 64 * 1_024 * 1_024
    static let maximumEntryBytes: UInt64 = 1_024 * 1_024 * 1_024 * 1_024
    static let maximumTotalBytes: UInt64 = 4 * 1_024 * 1_024 * 1_024 * 1_024

    let url: URL
    let entries: [VAOArchiveEntry]
    private let handle: FileHandle

    init(url: URL) throws {
        self.url = url
        self.handle = try FileHandle(forReadingFrom: url)
        do {
            self.entries = try Self.readCentralDirectory(handle: handle)
        } catch {
            try? handle.close()
            throw error
        }
    }

    deinit { try? handle.close() }

    func entry(named name: String) -> VAOArchiveEntry? {
        entries.first { $0.path == name }
    }

    func data(for entry: VAOArchiveEntry, maximumSize: UInt64) throws -> Data {
        guard entry.uncompressedSize <= maximumSize else {
            throw OrgRecError.invalidProject("VAO entry exceeds the supported in-memory size: \(entry.path)")
        }
        guard entry.compressionMethod == 0, entry.compressedSize == entry.uncompressedSize else {
            throw OrgRecError.invalidProject("OrgRec supports stored VAO entries; \(entry.path) uses compression method \(entry.compressionMethod).")
        }
        let offset = try dataOffset(for: entry)
        try handle.seek(toOffset: offset)
        let data = try handle.read(upToCount: Int(entry.compressedSize)) ?? Data()
        guard UInt64(data.count) == entry.compressedSize else {
            throw OrgRecError.invalidProject("VAO entry is truncated: \(entry.path)")
        }
        var crc = VAOCRC32()
        crc.update(data)
        guard crc.final == entry.crc32 else {
            throw OrgRecError.invalidProject("VAO ZIP checksum failed: \(entry.path)")
        }
        return data
    }

    func sha256(for entry: VAOArchiveEntry) throws -> (digest: String, size: Int64) {
        guard entry.compressionMethod == 0, entry.compressedSize == entry.uncompressedSize else {
            throw OrgRecError.invalidProject("OrgRec supports stored VAO entries; \(entry.path) is compressed.")
        }
        let offset = try dataOffset(for: entry)
        try handle.seek(toOffset: offset)
        var remaining = entry.compressedSize
        var hasher = SHA256()
        var crc = VAOCRC32()
        while remaining > 0 {
            let count = Int(min(UInt64(1_048_576), remaining))
            let data = try handle.read(upToCount: count) ?? Data()
            guard !data.isEmpty else { throw OrgRecError.invalidProject("VAO entry is truncated: \(entry.path)") }
            remaining -= UInt64(data.count)
            hasher.update(data: data)
            crc.update(data)
        }
        guard crc.final == entry.crc32 else {
            throw OrgRecError.invalidProject("VAO ZIP checksum failed: \(entry.path)")
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return (digest, Int64(entry.uncompressedSize))
    }

    func extract(_ entry: VAOArchiveEntry, to destination: URL, expectedSHA256: String) throws {
        guard entry.compressionMethod == 0, entry.compressedSize == entry.uncompressedSize else {
            throw OrgRecError.invalidProject("OrgRec supports stored VAO entries; \(entry.path) is compressed.")
        }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw OrgRecError.invalidProject("VAO extraction would overwrite \(destination.lastPathComponent).")
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).partial")
        FileManager.default.createFile(atPath: temporary.path, contents: nil)
        do {
            let output = try FileHandle(forWritingTo: temporary)
            defer { try? output.close() }
            let offset = try dataOffset(for: entry)
            try handle.seek(toOffset: offset)
            var remaining = entry.compressedSize
            var hasher = SHA256()
            var crc = VAOCRC32()
            while remaining > 0 {
                let count = Int(min(UInt64(1_048_576), remaining))
                let data = try handle.read(upToCount: count) ?? Data()
                guard !data.isEmpty else { throw OrgRecError.invalidProject("VAO entry is truncated: \(entry.path)") }
                remaining -= UInt64(data.count)
                hasher.update(data: data)
                crc.update(data)
                try output.write(contentsOf: data)
            }
            try output.synchronize()
            guard crc.final == entry.crc32 else {
                throw OrgRecError.invalidProject("VAO ZIP checksum failed: \(entry.path)")
            }
            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == expectedSHA256 else {
                throw OrgRecError.invalidProject("VAO SHA-256 failed: \(entry.path)")
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw error
        }
    }

    private func dataOffset(for entry: VAOArchiveEntry) throws -> UInt64 {
        try handle.seek(toOffset: entry.localHeaderOffset)
        let header = try handle.read(upToCount: 30) ?? Data()
        guard header.count == 30, header.uint32LE(at: 0) == 0x04034b50 else {
            throw OrgRecError.invalidProject("VAO local ZIP header is invalid: \(entry.path)")
        }
        let nameLength = UInt64(header.uint16LE(at: 26))
        let extraLength = UInt64(header.uint16LE(at: 28))
        return entry.localHeaderOffset + 30 + nameLength + extraLength
    }

    private static func readCentralDirectory(handle: FileHandle) throws -> [VAOArchiveEntry] {
        let size = try handle.seekToEnd()
        guard size >= 22 else { throw OrgRecError.invalidProject("The VAO is not a ZIP archive.") }
        let tailSize = min(size, UInt64(65_557))
        try handle.seek(toOffset: size - tailSize)
        let tail = try handle.read(upToCount: Int(tailSize)) ?? Data()
        guard tail.count >= 22 else { throw OrgRecError.invalidProject("The VAO ZIP end record is missing.") }
        var endIndex: Int?
        for index in stride(from: tail.count - 22, through: 0, by: -1) {
            if tail.uint32LE(at: index) == 0x06054b50 {
                let commentLength = Int(tail.uint16LE(at: index + 20))
                if index + 22 + commentLength == tail.count {
                    endIndex = index
                    break
                }
            }
        }
        guard let endIndex else { throw OrgRecError.invalidProject("The VAO ZIP end record is missing.") }
        let endOffset = size - tailSize + UInt64(endIndex)
        var count = UInt64(tail.uint16LE(at: endIndex + 10))
        var centralSize = UInt64(tail.uint32LE(at: endIndex + 12))
        var centralOffset = UInt64(tail.uint32LE(at: endIndex + 16))
        if count == UInt64(UInt16.max) || centralSize == UInt64(UInt32.max) || centralOffset == UInt64(UInt32.max) {
            guard endOffset >= 20 else { throw OrgRecError.invalidProject("The VAO ZIP64 locator is missing.") }
            try handle.seek(toOffset: endOffset - 20)
            let locator = try handle.read(upToCount: 20) ?? Data()
            guard locator.count == 20, locator.uint32LE(at: 0) == 0x07064b50 else {
                throw OrgRecError.invalidProject("The VAO ZIP64 locator is invalid.")
            }
            let recordOffset = locator.uint64LE(at: 8)
            try handle.seek(toOffset: recordOffset)
            let record = try handle.read(upToCount: 56) ?? Data()
            guard record.count >= 56, record.uint32LE(at: 0) == 0x06064b50 else {
                throw OrgRecError.invalidProject("The VAO ZIP64 end record is invalid.")
            }
            count = record.uint64LE(at: 32)
            centralSize = record.uint64LE(at: 40)
            centralOffset = record.uint64LE(at: 48)
        }
        guard count <= UInt64(maximumEntries), centralOffset + centralSize <= size else {
            throw OrgRecError.invalidProject("The VAO ZIP central directory exceeds safe limits.")
        }
        guard centralSize <= 256 * 1_024 * 1_024 else {
            throw OrgRecError.invalidProject("The VAO ZIP central directory is too large for OrgRec.")
        }
        try handle.seek(toOffset: centralOffset)
        let central = try handle.read(upToCount: Int(centralSize)) ?? Data()
        guard UInt64(central.count) == centralSize else {
            throw OrgRecError.invalidProject("The VAO ZIP central directory is truncated.")
        }
        var result: [VAOArchiveEntry] = []
        var cursor = 0
        var total: UInt64 = 0
        while cursor < central.count {
            guard cursor + 46 <= central.count, central.uint32LE(at: cursor) == 0x02014b50 else {
                throw OrgRecError.invalidProject("The VAO ZIP central directory contains an invalid record.")
            }
            let flags = central.uint16LE(at: cursor + 8)
            let compression = central.uint16LE(at: cursor + 10)
            let crc = central.uint32LE(at: cursor + 16)
            let compressed32 = central.uint32LE(at: cursor + 20)
            let uncompressed32 = central.uint32LE(at: cursor + 24)
            let nameLength = Int(central.uint16LE(at: cursor + 28))
            let extraLength = Int(central.uint16LE(at: cursor + 30))
            let commentLength = Int(central.uint16LE(at: cursor + 32))
            let external = central.uint32LE(at: cursor + 38)
            let offset32 = central.uint32LE(at: cursor + 42)
            let recordEnd = cursor + 46 + nameLength + extraLength + commentLength
            guard recordEnd <= central.count else {
                throw OrgRecError.invalidProject("The VAO ZIP central record is truncated.")
            }
            let nameData = central.subdata(in: cursor + 46..<cursor + 46 + nameLength)
            guard let path = String(data: nameData, encoding: .utf8), archivePathIsSafe(path) else {
                throw OrgRecError.invalidProject("The VAO contains an invalid or unsafe UTF-8 path.")
            }
            let extra = central.subdata(in: cursor + 46 + nameLength..<cursor + 46 + nameLength + extraLength)
            var compressed = UInt64(compressed32)
            var uncompressed = UInt64(uncompressed32)
            var localOffset = UInt64(offset32)
            if compressed32 == UInt32.max || uncompressed32 == UInt32.max || offset32 == UInt32.max {
                var extraCursor = 0
                var zip64: Data?
                while extraCursor + 4 <= extra.count {
                    let identifier = extra.uint16LE(at: extraCursor)
                    let length = Int(extra.uint16LE(at: extraCursor + 2))
                    guard extraCursor + 4 + length <= extra.count else { break }
                    if identifier == 0x0001 { zip64 = extra.subdata(in: extraCursor + 4..<extraCursor + 4 + length); break }
                    extraCursor += 4 + length
                }
                guard let zip64 else { throw OrgRecError.invalidProject("A VAO ZIP64 entry is missing its size metadata.") }
                var zipCursor = 0
                if uncompressed32 == UInt32.max {
                    guard zipCursor + 8 <= zip64.count else { throw OrgRecError.invalidProject("Invalid VAO ZIP64 size metadata.") }
                    uncompressed = zip64.uint64LE(at: zipCursor); zipCursor += 8
                }
                if compressed32 == UInt32.max {
                    guard zipCursor + 8 <= zip64.count else { throw OrgRecError.invalidProject("Invalid VAO ZIP64 size metadata.") }
                    compressed = zip64.uint64LE(at: zipCursor); zipCursor += 8
                }
                if offset32 == UInt32.max {
                    guard zipCursor + 8 <= zip64.count else { throw OrgRecError.invalidProject("Invalid VAO ZIP64 offset metadata.") }
                    localOffset = zip64.uint64LE(at: zipCursor)
                }
            }
            guard (flags & 0x0001) == 0 else { throw OrgRecError.invalidProject("Encrypted VAO entries are prohibited.") }
            guard compression == 0 else {
                throw OrgRecError.invalidProject("OrgRec supports stored VAO entries; \(path) uses compression method \(compression).")
            }
            guard uncompressed <= maximumEntryBytes else { throw OrgRecError.invalidProject("VAO entry exceeds OrgRec's safety limit: \(path)") }
            total += uncompressed
            guard total <= maximumTotalBytes else { throw OrgRecError.invalidProject("VAO payload exceeds OrgRec's safety limit.") }
            let mode = external >> 16
            let fileType = mode & 0o170000
            guard fileType == 0 || fileType == 0o100000 || (path.hasSuffix("/") && fileType == 0o040000) else {
                throw OrgRecError.invalidProject("VAO links and special files are prohibited: \(path)")
            }
            result.append(VAOArchiveEntry(
                path: path, compressionMethod: compression, flags: flags, crc32: crc,
                compressedSize: compressed, uncompressedSize: uncompressed,
                localHeaderOffset: localOffset, externalAttributes: external
            ))
            cursor = recordEnd
        }
        let normalizedPaths = result.map { $0.path.precomposedStringWithCanonicalMapping }
        guard result.count == Int(count), Set(normalizedPaths).count == result.count else {
            throw OrgRecError.invalidProject("The VAO ZIP entry count is inconsistent or contains duplicates.")
        }
        return result
    }
}
