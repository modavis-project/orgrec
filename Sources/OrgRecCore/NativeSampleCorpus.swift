import Foundation

public enum NativeSamplerFormat: String, Codable, CaseIterable, Sendable {
    case grandOrgue
    case hauptwerk
    case soundFont2
    case jOrgan
    case kontakt
    case organDefinitionOther
}

public struct SoundFont2SampleHeader: Codable, Hashable, Sendable {
    public var name: String
    public var startSamplePoint: UInt32
    public var endSamplePointExclusive: UInt32
    public var loopStartSamplePoint: UInt32
    public var loopEndSamplePointExclusive: UInt32
    public var sampleRate: UInt32
    public var originalMIDIPitch: UInt8
    public var pitchCorrectionCents: Int8
    public var sampleLink: UInt16
    public var sampleType: UInt16
    public var hasDeclaredLoopRange: Bool
}

public struct SoundFont2Inspection: Codable, Hashable, Sendable {
    public var contract: String
    public var sampleHeaders: [SoundFont2SampleHeader]
    public var warnings: [String]
    public var mappingStatus: String
}

public struct NativeSamplerDefinitionInspection: Codable, Hashable, Identifiable, Sendable {
    public var id: String { relativePath }
    public var relativePath: String
    public var format: NativeSamplerFormat
    public var fileSize: Int64
    public var semanticDecoding: String
    public var objectCounts: [String: Int]
    public var soundFont: SoundFont2Inspection?
    public var warnings: [String]
}

public struct NativeWAVMetadataSummary: Codable, Hashable, Sendable {
    public var inspectedFileCount: Int
    public var samplerChunkFileCount: Int
    public var declaredLoopCount: Int
    public var multipleLoopFileCount: Int
    public var rejectedLoopCount: Int
}

public struct NativeSampleCorpusInspection: Codable, Hashable, Sendable {
    public var contract: String
    public var roots: [String]
    public var generatedAt: Date
    public var regularFileCount: Int
    public var totalBytes: Int64
    public var extensionCounts: [String: Int]
    public var definitions: [NativeSamplerDefinitionInspection]
    public var wavMetadata: NativeWAVMetadataSummary
    public var rightsEvidencePaths: [String]
    public var identityPolicy: String
    public var rightsPolicy: String
    public var interpretationCaveats: [String]
}

public actor NativeSampleCorpusInspector {
    public init() {}

    /// Builds a format-aware, non-mutating corpus index. WAVE sampler chunks
    /// are inspected only up to the explicit limit because full corpora can
    /// contain hundreds of thousands of audio files.
    public func inspect(roots: [URL], maximumWAVMetadataFiles: Int = 0) throws -> NativeSampleCorpusInspection {
        var regularFileCount = 0
        var totalBytes: Int64 = 0
        var extensionCounts: [String: Int] = [:]
        var definitions: [NativeSamplerDefinitionInspection] = []
        var rightsPaths: [String] = []
        var wavInspected = 0
        var wavSamplerFiles = 0
        var wavLoops = 0
        var wavMultiple = 0
        var wavRejected = 0

        for suppliedRoot in roots {
            let root = suppliedRoot.standardizedFileURL
            let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: Array(keys),
                options: [.skipsHiddenFiles]
            ) else {
                throw OrgRecError.invalidProject("Cannot enumerate native sample corpus root \(root.path).")
            }
            for case let url as URL in enumerator {
                let values = try url.resourceValues(forKeys: keys)
                guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                regularFileCount += 1
                totalBytes += Int64(values.fileSize ?? 0)
                let ext = url.pathExtension.lowercased()
                extensionCounts[ext.isEmpty ? "(none)" : ext, default: 0] += 1
                let corpusRelative = Self.corpusRelativePath(url: url, root: root)
                if Self.looksLikeRightsEvidence(url.lastPathComponent), rightsPaths.count < 10_000 {
                    rightsPaths.append(corpusRelative)
                }
                if let format = Self.definitionFormat(for: url) {
                    definitions.append(try Self.inspectDefinition(url: url, relativePath: corpusRelative, format: format))
                }
                if ext == "wav", wavInspected < max(0, maximumWAVMetadataFiles) {
                    wavInspected += 1
                    if let metadata = try? WAVSamplerMetadataReader.read(from: url) {
                        wavSamplerFiles += 1
                        wavLoops += metadata.loops.count
                        if metadata.loops.count > 1 { wavMultiple += 1 }
                        wavRejected += metadata.loops.filter { !$0.isUsable }.count
                    }
                }
            }
        }
        return NativeSampleCorpusInspection(
            contract: "orgrec.native-sample-corpus-inspection/v1",
            roots: roots.map { $0.standardizedFileURL.path },
            generatedAt: .now,
            regularFileCount: regularFileCount,
            totalBytes: totalBytes,
            extensionCounts: extensionCounts,
            definitions: definitions.sorted { $0.relativePath < $1.relativePath },
            wavMetadata: NativeWAVMetadataSummary(
                inspectedFileCount: wavInspected,
                samplerChunkFileCount: wavSamplerFiles,
                declaredLoopCount: wavLoops,
                multipleLoopFileCount: wavMultiple,
                rejectedLoopCount: wavRejected
            ),
            rightsEvidencePaths: rightsPaths.sorted(),
            identityPolicy: "A corpus root, folder, archive, installed package, product, sampled/modelled instrument, and physical organ are distinct identities. This filesystem index does not merge them.",
            rightsPolicy: "License/readme paths are discovery evidence only. Inclusion in analysis or distribution requires an explicit reviewed rights record for the exact bytes and intended use.",
            interpretationCaveats: [
                "GrandOrgue counts describe parseable source fields; use GrandOrgueSampleSetImporter for exact playable mappings.",
                "Hauptwerk compact ObjectList tags are inventoried structurally and are not decoded without an authorized versioned mapping table.",
                "SoundFont sample headers preserve sample ranges, pitch, links, and declared loop ranges; active preset/instrument generator-zone semantics are not claimed.",
                "jOrgan element types are inventoried structurally; SoundFont program/bank behavior remains separate.",
                "Kontakt NKI structures are opaque in this implementation and never produce a playable-semantics capability claim.",
                "Filename-derived perspective or round-robin labels are inference candidates, not asserted microphone geometry or sampler behavior.",
            ]
        )
    }

    private static func definitionFormat(for url: URL) -> NativeSamplerFormat? {
        let name = url.lastPathComponent.lowercased()
        if url.pathExtension.lowercased() == "organ" { return .grandOrgue }
        if name.hasSuffix(".organ_hauptwerk_xml") { return .hauptwerk }
        if url.pathExtension.lowercased() == "sf2" { return .soundFont2 }
        if url.pathExtension.lowercased() == "disposition" { return .jOrgan }
        if url.pathExtension.lowercased() == "nki" { return .kontakt }
        if ["orgue", "organxml"].contains(url.pathExtension.lowercased()) { return .organDefinitionOther }
        return nil
    }

    private static func inspectDefinition(
        url: URL,
        relativePath: String,
        format: NativeSamplerFormat
    ) throws -> NativeSamplerDefinitionInspection {
        let fileSize = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        switch format {
        case .grandOrgue:
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            let text = decodeDefinitionText(data) ?? ""
            var counts: [String: Int] = [:]
            for rawLine in text.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.range(of: #"^\[Stop[0-9]+\]$"#, options: .regularExpression) != nil { counts["stopSections", default: 0] += 1 }
                if line.range(of: #"^\[Rank[0-9]+\]$"#, options: .regularExpression) != nil { counts["rankSections", default: 0] += 1 }
                if line.range(of: #"^Rank[0-9]{3}="#, options: .regularExpression) != nil { counts["rankBindings", default: 0] += 1 }
                if line.range(of: #"^Pipe[0-9]{3}=.+"#, options: .regularExpression) != nil { counts["baseSampleMappings", default: 0] += 1 }
                if line.range(of: #"^Pipe[0-9]{3}Attack[0-9]{3}=.+"#, options: .regularExpression) != nil { counts["attackVariants", default: 0] += 1 }
                if line.range(of: #"^Pipe[0-9]{3}Release[0-9]{3}=.+"#, options: .regularExpression) != nil { counts["releaseVariants", default: 0] += 1 }
                if line.range(of: #"^Pipe[0-9]{3}PitchTuning="#, options: .regularExpression) != nil { counts["pitchTuningValues", default: 0] += 1 }
                if line.range(of: #"^(Pipe[0-9]{3})?HarmonicNumber="#, options: .regularExpression) != nil { counts["harmonicNumberValues", default: 0] += 1 }
                if line.contains("=REF:") { counts["referenceMappings", default: 0] += 1 }
                if line.uppercased().hasSuffix("=DUMMY") { counts["intentionalSilenceMappings", default: 0] += 1 }
                if line.contains("=..\\") || line.contains("=../") { counts["parentRelativeMappings", default: 0] += 1 }
            }
            return NativeSamplerDefinitionInspection(
                relativePath: relativePath, format: format, fileSize: fileSize,
                semanticDecoding: "source-fields-structurally-decoded; exact mapping available through GrandOrgueSampleSetImporter",
                objectCounts: counts, soundFont: nil, warnings: []
            )
        case .hauptwerk:
            let delegate = XMLStructureCounter(mode: .hauptwerk)
            let parser = XMLParser(contentsOf: url)
            parser?.delegate = delegate
            let parsed = parser?.parse() == true
            return NativeSamplerDefinitionInspection(
                relativePath: relativePath, format: format, fileSize: fileSize,
                semanticDecoding: "ObjectList inventory only; compact field tags remain opaque without a versioned authorized mapping",
                objectCounts: delegate.counts, soundFont: nil,
                warnings: parsed ? [] : [parser?.parserError?.localizedDescription ?? "XML parse failed."]
            )
        case .jOrgan:
            let delegate = XMLStructureCounter(mode: .jOrgan)
            let parser = XMLParser(contentsOf: url)
            parser?.delegate = delegate
            let parsed = parser?.parse() == true
            return NativeSamplerDefinitionInspection(
                relativePath: relativePath, format: format, fileSize: fileSize,
                semanticDecoding: "jOrgan element-type inventory; external SoundFont program semantics are not flattened",
                objectCounts: delegate.counts, soundFont: nil,
                warnings: parsed ? [] : [parser?.parserError?.localizedDescription ?? "XML parse failed."]
            )
        case .soundFont2:
            let inspection = try SoundFont2Inspector.inspect(url: url)
            return NativeSamplerDefinitionInspection(
                relativePath: relativePath, format: format, fileSize: fileSize,
                semanticDecoding: inspection.mappingStatus,
                objectCounts: ["sampleHeaders": inspection.sampleHeaders.count, "declaredLoopRanges": inspection.sampleHeaders.filter(\.hasDeclaredLoopRange).count],
                soundFont: inspection, warnings: inspection.warnings
            )
        case .kontakt:
            return NativeSamplerDefinitionInspection(
                relativePath: relativePath, format: format, fileSize: fileSize,
                semanticDecoding: "opaque-binary inventory only", objectCounts: [:], soundFont: nil,
                warnings: ["No Kontakt mapping claim is made; use an authorized format adapter or producer export."]
            )
        case .organDefinitionOther:
            return NativeSamplerDefinitionInspection(
                relativePath: relativePath, format: format, fileSize: fileSize,
                semanticDecoding: "unclassified organ-definition inventory only", objectCounts: [:], soundFont: nil,
                warnings: ["Definition requires a format-specific adapter before playable semantics can be asserted."]
            )
        }
    }

    private static func corpusRelativePath(url: URL, root: URL) -> String {
        let relative = String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
        return root.lastPathComponent + "/" + relative
    }

    private static func looksLikeRightsEvidence(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        return lower.contains("license") || lower.contains("licence") || lower.contains("copyright") || lower.hasPrefix("readme")
    }

    private static func decodeDefinitionText(_ data: Data) -> String? {
        [.utf8, .windowsCP1252, .isoLatin1, .macOSRoman].compactMap { String(data: data, encoding: $0) }.first
    }
}

private final class XMLStructureCounter: NSObject, XMLParserDelegate {
    enum Mode { case hauptwerk, jOrgan }
    let mode: Mode
    var counts: [String: Int] = [:]
    private var currentHauptwerkObjectType: String?
    private var withinElements = false
    private var elementsDepth = 0

    init(mode: Mode) { self.mode = mode }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch mode {
        case .hauptwerk:
            if elementName == "ObjectList" {
                let type = attributeDict["ObjectType"] ?? "unknown"
                currentHauptwerkObjectType = type
                counts["objectList:\(type)", default: 0] += 1
            } else if elementName == "o", let type = currentHauptwerkObjectType {
                counts["objects:\(type)", default: 0] += 1
            }
        case .jOrgan:
            if elementName == "elements" { withinElements = true; elementsDepth = 0; return }
            guard withinElements else { return }
            elementsDepth += 1
            if elementsDepth == 1 { counts["elements:\(elementName)", default: 0] += 1 }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch mode {
        case .hauptwerk:
            if elementName == "ObjectList" { currentHauptwerkObjectType = nil }
        case .jOrgan:
            if elementName == "elements" { withinElements = false; elementsDepth = 0 }
            else if withinElements { elementsDepth -= 1 }
        }
    }
}

public enum SoundFont2Inspector {
    public static func inspect(url: URL) throws -> SoundFont2Inspection {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count >= 12,
              ascii(data, 0..<4) == "RIFF",
              ascii(data, 8..<12) == "sfbk" else {
            throw OrgRecError.invalidProject("SoundFont file is not RIFF sfbk.")
        }
        var shdr: Data?
        var offset = 12
        while offset + 8 <= data.count {
            let id = ascii(data, offset..<(offset + 4))
            let size = Int(uint32(data, at: offset + 4))
            let payload = offset + 8
            guard size >= 0, payload <= data.count, size <= data.count - payload else { break }
            if id == "LIST", size >= 4, ascii(data, payload..<(payload + 4)) == "pdta" {
                var subOffset = payload + 4
                let end = payload + size
                while subOffset + 8 <= end {
                    let subID = ascii(data, subOffset..<(subOffset + 4))
                    let subSize = Int(uint32(data, at: subOffset + 4))
                    let subPayload = subOffset + 8
                    guard subSize >= 0, subPayload <= end, subSize <= end - subPayload else { break }
                    if subID == "shdr" { shdr = data.subdata(in: subPayload..<(subPayload + subSize)); break }
                    subOffset = subPayload + subSize + (subSize & 1)
                }
            }
            if shdr != nil { break }
            offset = payload + size + (size & 1)
        }
        guard let shdr else {
            throw OrgRecError.invalidProject("SoundFont pdta section has no shdr sample-header chunk.")
        }
        var warnings: [String] = []
        if shdr.count % 46 != 0 { warnings.append("The shdr chunk has trailing or truncated bytes.") }
        let recordCount = shdr.count / 46
        var headers: [SoundFont2SampleHeader] = []
        for index in 0..<max(0, recordCount - 1) {
            let base = index * 46
            let nameBytes = shdr[base..<(base + 20)]
            let name = String(decoding: nameBytes.prefix { $0 != 0 }, as: UTF8.self)
            let start = uint32(shdr, at: base + 20)
            let end = uint32(shdr, at: base + 24)
            let loopStart = uint32(shdr, at: base + 28)
            let loopEnd = uint32(shdr, at: base + 32)
            let declaredLoop = start <= loopStart && loopStart < loopEnd && loopEnd <= end
            headers.append(SoundFont2SampleHeader(
                name: name,
                startSamplePoint: start,
                endSamplePointExclusive: end,
                loopStartSamplePoint: loopStart,
                loopEndSamplePointExclusive: loopEnd,
                sampleRate: uint32(shdr, at: base + 36),
                originalMIDIPitch: shdr[base + 40],
                pitchCorrectionCents: Int8(bitPattern: shdr[base + 41]),
                sampleLink: uint16(shdr, at: base + 42),
                sampleType: uint16(shdr, at: base + 44),
                hasDeclaredLoopRange: declaredLoop
            ))
        }
        return SoundFont2Inspection(
            contract: "orgrec.soundfont2-inspection/v1",
            sampleHeaders: headers,
            warnings: warnings,
            mappingStatus: "sample headers decoded; generator zones and active sampleModes not decoded, so declared loop ranges are not asserted active playback loops"
        )
    }

    private static func ascii(_ data: Data, _ range: Range<Int>) -> String {
        guard range.lowerBound >= 0, range.upperBound <= data.count else { return "" }
        return String(decoding: data[range], as: UTF8.self)
    }

    private static func uint16(_ data: Data, at offset: Int) -> UInt16 {
        guard offset >= 0, offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func uint32(_ data: Data, at offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
