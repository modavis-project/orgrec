import Foundation

public struct VAO05PackageInspection: Codable, Sendable, Equatable {
    public var manifest: VAO05Manifest
    public var carrier: VAO05Carrier
    public var errors: [String]
    public var verifiedPayloadBytes: Int64

    public var isValid: Bool { errors.isEmpty }
    public var displayTitle: String {
        manifest.title["en"] ?? manifest.title["und"] ?? manifest.title.values.sorted().first ?? manifest.id
    }
    public var realizationCount: Int { manifest.realizations.count }
    public var trackCount: Int { registryCount(manifest.multimodal, key: "tracks") }
    public var scientificRecordCount: Int {
        guard let records = manifest.scientific.objectValue else { return 0 }
        return records.values.reduce(0) { $0 + ($1.arrayValue?.count ?? 0) }
    }
    public var physicalComponentCount: Int { registryCount(manifest.physicalSystem, key: "components") }

    private func registryCount(_ value: VAOJSONValue, key: String) -> Int {
        value.objectValue?[key]?.arrayValue?.count ?? 0
    }
}

public actor VAO05PackageReader {
    private static let maximumCarrierDescriptorBytes: UInt64 = 64 * 1_024 * 1_024

    public init() {}

    public nonisolated static func formatVersion(of packageURL: URL) throws -> String? {
        let archive = try VAOArchiveReader(url: packageURL)
        guard let entry = archive.entry(named: VAO05Contract.manifestFilename) else { return nil }
        return VAOFormatDispatcher.formatVersion(
            in: try archive.data(for: entry, maximumSize: VAOArchiveReader.maximumManifestBytes)
        )
    }

    public func inspect(_ packageURL: URL) throws -> VAO05PackageInspection {
        let archive = try VAOArchiveReader(url: packageURL)
        guard archive.entries.first?.path == "mimetype",
              let mimetypeEntry = archive.entry(named: "mimetype"),
              let manifestEntry = archive.entry(named: VAO05Contract.manifestFilename),
              let carrierEntry = archive.entry(named: VAO05Contract.carrierFilename)
        else {
            throw OrgRecError.invalidProject("The VAO 0.5.0 carrier is missing or misorders a structural entry.")
        }
        guard try archive.data(for: mimetypeEntry, maximumSize: 256) == Data(VAO05Contract.mediaType.utf8) else {
            throw OrgRecError.invalidProject("The VAO 0.5.0 carrier has incorrect mimetype bytes.")
        }
        let manifestData = try archive.data(for: manifestEntry, maximumSize: VAOArchiveReader.maximumManifestBytes)
        guard VAOFormatDispatcher.formatVersion(in: manifestData) == VAO05Contract.formatVersion else {
            throw OrgRecError.invalidProject("Expected exact VAO 0.5.0 content.")
        }
        let carrierData = try archive.data(for: carrierEntry, maximumSize: Self.maximumCarrierDescriptorBytes)
        let manifest = try VAOFormatDispatcher.decode05(manifestData)
        let carrier = try JSONDecoder().decode(VAO05Carrier.self, from: carrierData)
        var errors = VAO05Validator.validateManifest(data: manifestData)
        if carrier.formatVersion != VAO05Contract.formatVersion { errors.append("Carrier formatVersion must be 0.5.0.") }
        if carrier.schema != VAO05Contract.carrierSchemaURI { errors.append("Carrier uses the wrong immutable schema IRI.") }
        if carrier.type != "VAOCarrier" { errors.append("Carrier type must be VAOCarrier.") }
        if carrier.id.isEmpty { errors.append("Carrier id is required by VAO 0.5.0.") }
        if carrier.manifestSHA256 != manifestData.sha256Hex || carrier.manifestByteSize != Int64(manifestData.count) {
            errors.append("Carrier does not pin the exact manifest bytes.")
        }
        if carrier.releaseId != manifest.release.id { errors.append("Carrier releaseId does not match manifest release.id.") }

        let realizations = Dictionary(manifest.realizations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let groups = Dictionary(manifest.assetGroups.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let mappings = Dictionary(grouping: carrier.embeddedRealizations, by: \.realizationId)
        let mappedPaths = Set(carrier.embeddedRealizations.map(\.path))
        var payloadPaths: Set<String> = []
        var verifiedBytes: Int64 = 0
        let structural = Set(["mimetype", VAO05Contract.manifestFilename, VAO05Contract.carrierFilename])
        for entry in archive.entries {
            if entry.path.hasPrefix("payload/") { payloadPaths.insert(entry.path) }
            else if !structural.contains(entry.path) { errors.append("Unknown VAO 0.5.0 carrier entry \(entry.path).") }
        }
        if mappedPaths != payloadPaths { errors.append("Carrier payload closure does not equal its embedded mappings.") }
        if mappedPaths.count != carrier.embeddedRealizations.count { errors.append("Carrier maps an embedded path more than once.") }
        for (id, records) in mappings {
            if records.count != 1 { errors.append("Carrier maps realization \(id) more than once.") }
            guard let realization = realizations[id], let mapping = records.first,
                  let entry = archive.entry(named: mapping.path)
            else {
                errors.append("Carrier has unresolved embedded mapping \(id).")
                continue
            }
            let result = try archive.sha256(for: entry)
            verifiedBytes += result.size
            if result.digest != realization.sha256 || result.size != realization.byteSize {
                errors.append("Embedded realization \(id) fails exact byte verification.")
            }
        }
        let embedded = Set(mappings.keys)
        for id in carrier.completeGroupIds {
            guard let group = groups[id] else {
                errors.append("Carrier declares unknown complete group \(id).")
                continue
            }
            if !Set(group.realizationIds).isSubset(of: embedded) { errors.append("Carrier complete group \(id) is incomplete.") }
        }
        if carrier.carrierMode == "preservation-closure", embedded != Set(realizations.keys) {
            errors.append("Preservation closure omits realizations.")
        }
        return VAO05PackageInspection(
            manifest: manifest,
            carrier: carrier,
            errors: Array(Set(errors)).sorted(),
            verifiedPayloadBytes: verifiedBytes
        )
    }

    @discardableResult
    public func importWorkspace(from packageURL: URL, to destination: URL) throws -> VAO05PackageInspection {
        let inspection = try inspect(packageURL)
        guard inspection.isValid else {
            throw OrgRecError.invalidProject("VAO 0.5.0 validation failed: " + inspection.errors.prefix(3).joined(separator: "; "))
        }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else { throw OrgRecError.invalidProject("Destination exists.") }
        let archive = try VAOArchiveReader(url: packageURL)
        let realizations = Dictionary(inspection.manifest.realizations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        do {
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            for path in ["mimetype", VAO05Contract.manifestFilename, VAO05Contract.carrierFilename] {
                guard let entry = archive.entry(named: path) else { throw OrgRecError.invalidProject("Missing \(path).") }
                let target = destination.appendingPathComponent(path)
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                let maximum: UInt64 = path == "mimetype" ? 256 : Self.maximumCarrierDescriptorBytes
                try archive.data(for: entry, maximumSize: maximum).write(to: target, options: .atomic)
            }
            for mapping in inspection.carrier.embeddedRealizations {
                guard let entry = archive.entry(named: mapping.path), let realization = realizations[mapping.realizationId] else {
                    throw OrgRecError.invalidProject("Unresolved embedded mapping.")
                }
                let target = destination.appendingPathComponent(mapping.path)
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try archive.extract(entry, to: target, expectedSHA256: realization.sha256)
            }
            return inspection
        } catch {
            try? manager.removeItem(at: destination)
            throw error
        }
    }

    public func extractRealization(id: String, from packageURL: URL, to destination: URL) throws {
        let inspection = try inspect(packageURL)
        guard inspection.isValid else { throw OrgRecError.invalidProject("VAO 0.5.0 validation failed.") }
        guard let realization = inspection.manifest.realizations.first(where: { $0.id == id }),
              let mapping = inspection.carrier.embeddedRealizations.first(where: { $0.realizationId == id })
        else { throw OrgRecError.invalidProject("Realization \(id) is not embedded in this carrier.") }
        let archive = try VAOArchiveReader(url: packageURL)
        guard let entry = archive.entry(named: mapping.path) else { throw OrgRecError.invalidProject("Missing embedded path.") }
        try archive.extract(entry, to: destination, expectedSHA256: realization.sha256)
    }
}

public typealias VAO05MaterializationPlan = VAO03MaterializationPlan
public typealias VAO05MaterializationError = VAO03MaterializationError

public enum VAO05MaterializationPlanner {
    public static func plan(
        manifest: VAO05Manifest,
        carrier: VAO05Carrier,
        requestedGroupIds: [String],
        supportedCapabilities: Set<String>,
        maximumBytes: Int64? = nil
    ) throws -> VAO05MaterializationPlan {
        let validation = VAO05Validator.validateManifest(manifest)
        guard validation.isEmpty else { throw VAO05MaterializationError.invalidManifest(validation) }
        let groups = Dictionary(uniqueKeysWithValues: manifest.assetGroups.map { ($0.id, $0) })
        let realizations = Dictionary(uniqueKeysWithValues: manifest.realizations.map { ($0.id, $0) })
        var expanded: Set<String> = []
        func include(_ id: String) throws {
            guard let group = groups[id] else { throw VAO05MaterializationError.unknownGroup(id) }
            if expanded.insert(id).inserted {
                let missing = Set(group.requiredCapabilities).subtracting(supportedCapabilities)
                if !missing.isEmpty {
                    throw VAO05MaterializationError.unsupportedCapabilities(groupId: id, capabilities: missing.sorted())
                }
                for dependency in group.dependsOnGroupIds { try include(dependency) }
            }
        }
        for id in requestedGroupIds { try include(id) }
        let selected = expanded.compactMap { groups[$0] }
        for (set, members) in Dictionary(grouping: selected, by: \.selectionSetId) {
            let constrained = members.filter { $0.selectionPolicy != "independent" }
            if constrained.count > 1 {
                throw VAO05MaterializationError.selectionConflict(selectionSetId: set, groupIds: constrained.map(\.id).sorted())
            }
        }
        let ids = Set(selected.flatMap(\.realizationIds))
        let embedded = Set(carrier.embeddedRealizations.map(\.realizationId)).intersection(ids)
        var remote: Set<String> = []
        var total: Int64 = 0
        for id in ids {
            guard let realization = realizations[id] else { throw VAO05MaterializationError.unavailableRealization(id) }
            let addition = total.addingReportingOverflow(realization.byteSize)
            guard !addition.overflow else { throw VAO05MaterializationError.aggregateByteSizeOverflow }
            total = addition.partialValue
            if !embedded.contains(id) {
                guard !realization.distributionIds.isEmpty else { throw VAO05MaterializationError.unavailableRealization(id) }
                remote.insert(id)
            }
        }
        if let maximumBytes, total > maximumBytes {
            throw VAO05MaterializationError.byteLimitExceeded(expected: total, limit: maximumBytes)
        }
        return VAO05MaterializationPlan(
            requestedGroupIds: requestedGroupIds,
            expandedGroupIds: expanded.sorted(),
            realizationIds: ids.sorted(),
            embeddedRealizationIds: embedded.sorted(),
            remoteRealizationIds: remote.sorted(),
            totalByteSize: total
        )
    }
}
