import Foundation

public enum VAOCapabilityProcessing: String, Codable, Sendable {
    /// OrgRec validates and directly processes this capability in its native workflow.
    case native
    /// OrgRec validates and exposes the complete graph/assets, but has no native XR runtime for it.
    case metadataOnly
    /// The required capability is unknown to this implementation.
    case unsupported
}

public struct VAOCapabilityReport: Codable, Sendable, Equatable {
    public var profileId: String
    public var capability: String
    public var validationSupported: Bool
    public var processing: VAOCapabilityProcessing
    public var detail: String
}

public struct VAOExperienceDescriptor: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var capability: String
    public var labels: [String: String]
    public var properties: [String: VAOJSONValue]
    public var outgoingRelations: [VAORelation]
    public var relatedEntityIds: [String]
    public var relatedAssetIds: [String]
}

public struct VAOPackageInspection: Codable, Sendable, Equatable {
    public var manifest: VAOManifest
    public var validation: VAOValidationReport
    public var capabilities: [VAOCapabilityReport]
    public var experiences: [VAOExperienceDescriptor]
    public var isEditableOrgRecCapture: Bool
}

public struct VAOPackageAssetSource: Sendable, Equatable {
    public var assetId: String
    public var fileURL: URL

    public init(assetId: String, fileURL: URL) {
        self.assetId = assetId
        self.fileURL = fileURL
    }
}

public actor VAOPackageReader {
    public init() {}

    public func inspect(_ packageURL: URL) throws -> VAOPackageInspection {
        let validation = try VAOPackageValidator.validate(packageURL: packageURL)
        let manifest = try VAOPackageValidator.manifest(packageURL: packageURL)
        return VAOPackageInspection(
            manifest: manifest,
            validation: validation,
            capabilities: Self.capabilityReports(for: manifest),
            experiences: Self.experienceDescriptors(for: manifest),
            isEditableOrgRecCapture: manifest.profiles.contains { $0.id == VAOContract.orgRecProfile }
        )
    }

    /// Imports any valid VAO into its lossless directory-form authoring workspace.
    /// No content is executed and every extracted asset is verified again.
    @discardableResult
    public func importWorkspace(from packageURL: URL, to destination: URL) throws -> VAOPackageInspection {
        let inspection = try inspect(packageURL)
        guard inspection.validation.isValid else {
            throw OrgRecError.invalidProject("VAO validation failed: " + inspection.validation.errors.prefix(3).joined(separator: "; "))
        }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else {
            throw OrgRecError.invalidProject("The VAO workspace destination already exists.")
        }
        let archive = try VAOArchiveReader(url: packageURL)
        do {
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            guard let mimetype = archive.entry(named: "mimetype"),
                  let manifestEntry = archive.entry(named: VAOContract.manifestFilename) else {
                throw OrgRecError.invalidProject("The VAO structural entries are missing.")
            }
            try archive.data(for: mimetype, maximumSize: 256).write(to: destination.appendingPathComponent("mimetype"), options: .atomic)
            try archive.data(for: manifestEntry, maximumSize: VAOArchiveReader.maximumManifestBytes).write(to: destination.appendingPathComponent(VAOContract.manifestFilename), options: .atomic)
            for asset in inspection.manifest.assets {
                guard let entry = archive.entry(named: asset.path) else {
                    throw OrgRecError.invalidProject("The VAO is missing \(asset.path).")
                }
                try archive.extract(entry, to: destination.appendingPathComponent(asset.path), expectedSHA256: asset.sha256)
            }
            return inspection
        } catch {
            try? manager.removeItem(at: destination)
            throw error
        }
    }

    public func extractAsset(id: String, from packageURL: URL, to destination: URL) throws {
        let inspection = try inspect(packageURL)
        guard inspection.validation.isValid else {
            throw OrgRecError.invalidProject("VAO validation failed: " + inspection.validation.errors.prefix(3).joined(separator: "; "))
        }
        guard let asset = inspection.manifest.assets.first(where: { $0.id == id }) else {
            throw OrgRecError.invalidProject("The VAO has no asset with identifier \(id).")
        }
        let archive = try VAOArchiveReader(url: packageURL)
        guard let entry = archive.entry(named: asset.path) else {
            throw OrgRecError.invalidProject("The VAO is missing \(asset.path).")
        }
        try archive.extract(entry, to: destination, expectedSHA256: asset.sha256)
    }

    /// Copies an immutable, fully validated VAO without rewriting its version or bytes.
    public func copyValidatedPackage(from source: URL, to destination: URL) throws {
        let inspection = try inspect(source)
        guard inspection.validation.isValid else {
            throw OrgRecError.invalidProject("VAO validation failed: " + inspection.validation.errors.prefix(3).joined(separator: "; "))
        }
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw OrgRecError.exportValidation("The VAO destination already exists.")
        }
        try FileManager.default.copyItem(at: source, to: destination)
    }

    public static func capabilityReports(for manifest: VAOManifest) -> [VAOCapabilityReport] {
        let native: Set<String> = [
            VAOContract.vaoVocabulary + "capability/core-graph",
            VAOContract.vaoVocabulary + "capability/fixity",
            VAOContract.vaoVocabulary + "capability/paradata",
            VAOContract.vaoVocabulary + "capability/analysis",
            VAOContract.vaoVocabulary + "capability/audio",
            VAOContract.vaoVocabulary + "capability/preservation",
            VAOContract.vaoVocabulary + "capability/interaction",
            VAOContract.vaoVocabulary + "capability/playable-interaction",
            VAOContract.vaoVocabulary + "capability/performance-control",
            VAOContract.vaoVocabulary + "capability/sample-looping",
            VAOContract.sampledInstrumentPlaybackCapability,
            VAOContract.sourceSegmentationCapability,
            VAOContract.acousticalAnalysisCapability,
            VAOContract.tuningMapCapability,
            VAOContract.empiricalTimbreClassificationCapability,
            VAOContract.pitchDependentRankFingerprintCapability,
            VAOContract.collectionAcousticDiagnosticsCapability,
            VAOContract.vaoVocabulary + "capability/spatial",
        ]
        return manifest.profiles.flatMap { profile in
            profile.requiredCapabilities.map { capability in
                if native.contains(capability) {
                    return VAOCapabilityReport(profileId: profile.id, capability: capability, validationSupported: true, processing: .native, detail: "Validated and processed by OrgRec's native VAO workflow.")
                }
                if VAOContract.experientialCapabilities.contains(capability) {
                    return VAOCapabilityReport(profileId: profile.id, capability: capability, validationSupported: true, processing: .metadataOnly, detail: "The complete experiential graph and verified assets are exposed; OrgRec does not execute an XR runtime.")
                }
                if VAOContract.acousticsCapabilities.contains(capability) {
                    return VAOCapabilityReport(profileId: profile.id, capability: capability, validationSupported: true, processing: .metadataOnly, detail: "The VAO 0.2 acoustic contract is validated and exposed; OrgRec does not execute an acoustic renderer.")
                }
                return VAOCapabilityReport(profileId: profile.id, capability: capability, validationSupported: false, processing: .unsupported, detail: "Unknown required capability; retained without interpretation.")
            }
        }
    }

    public static func experienceDescriptors(for manifest: VAOManifest) -> [VAOExperienceDescriptor] {
        let entityIDs = Set(manifest.entities.map(\.id))
        let assetIDs = Set(manifest.assets.map(\.id))
        return manifest.entities.filter { $0.kind == "experience" }.map { experience in
            let relations = manifest.relations.filter {
                $0.subjectId == experience.id && $0.status != "rejected" && $0.status != "superseded"
            }
            let targets = relations.compactMap(\.objectId)
            return VAOExperienceDescriptor(
                id: experience.id,
                capability: experience.properties?[VAOContract.property("experienceCapability")]?.stringValue ?? "",
                labels: experience.labels,
                properties: experience.properties ?? [:],
                outgoingRelations: relations,
                relatedEntityIds: targets.filter { entityIDs.contains($0) },
                relatedAssetIds: targets.filter { assetIDs.contains($0) }
            )
        }
    }
}

/// General VAO 0.2.2 writer. Unlike the OrgRec capture builder, this accepts a
/// complete caller-supplied graph and therefore can write any standard profile,
/// including experiential/XR packages, without inventing runtime semantics.
public actor VAOPackageWriter {
    public init() {}

    @discardableResult
    public func write(
        manifest sourceManifest: VAOManifest,
        assetSources: [VAOPackageAssetSource],
        to destination: URL
    ) throws -> VAOValidationReport {
        guard sourceManifest.formatVersion == VAOContract.formatVersion else {
            throw OrgRecError.exportValidation("A new package written by this implementation must use VAO \(VAOContract.formatVersion).")
        }
        let sources = Dictionary(assetSources.map { ($0.assetId, $0.fileURL) }, uniquingKeysWith: { first, _ in first })
        guard sources.count == assetSources.count, Set(sources.keys) == Set(sourceManifest.assets.map(\.id)) else {
            throw OrgRecError.exportValidation("The VAO writer requires exactly one source file for every indexed asset.")
        }
        var manifest = sourceManifest
        manifest.modifiedAt = Date()
        for index in manifest.assets.indices {
            let asset = manifest.assets[index]
            guard let fileURL = sources[asset.id] else { continue }
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw OrgRecError.exportValidation("VAO asset source is not a regular file: \(fileURL.lastPathComponent)")
            }
            manifest.assets[index].byteSize = Int64(values.fileSize ?? 0)
            manifest.assets[index].sha256 = try sha256(of: fileURL)
        }
        manifest.integrity = VAOIntegrity(
            assetCount: manifest.assets.count,
            totalPayloadBytes: manifest.assets.reduce(Int64(0)) { $0 + $1.byteSize },
            payloadMerkleRoot: manifest.integrity.payloadMerkleRoot,
            signatureProfile: manifest.integrity.signatureProfile
        )
        let manifestData = try OrgRecCoding.encoder.encode(manifest)
        let schemaErrors = VAOManifestSchemaValidator.validate(manifestData)
        guard schemaErrors.isEmpty else {
            throw OrgRecError.exportValidation("VAO manifest failed schema validation: " + schemaErrors.prefix(3).joined(separator: "; "))
        }
        var entries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAOContract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAOContract.manifestFilename, data: manifestData),
        ]
        entries.append(contentsOf: manifest.assets.sorted { $0.path < $1.path }.map {
            VAOArchiveEntrySource(path: $0.path, fileURL: sources[$0.id]!)
        })
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try VAOArchiveWriter.write(entries: entries, to: destination)
        let report = try VAOPackageValidator.validate(packageURL: destination)
        guard report.isValid else {
            try? FileManager.default.removeItem(at: destination)
            throw OrgRecError.exportValidation("Created VAO failed validation: " + report.errors.prefix(3).joined(separator: "; "))
        }
        return report
    }
}
