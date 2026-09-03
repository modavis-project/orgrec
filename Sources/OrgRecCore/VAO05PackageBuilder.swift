import Foundation

/// Writes a self-contained VAO 0.5.0 preservation closure for an OrgRec project.
/// The exporter claims only Core, Dynamic Delivery, and the small Scientific
/// registry used for discovery authorship. Detailed OrgRec records remain exact
/// identified payload bytes; no scientific or rights assertion is invented.
public actor VAO05PackageBuilder {
    private struct SourceFile {
        var url: URL
        var relativePath: String
        var payloadPath: String
        var digest: String
        var size: Int64
        var assetId: String
        var realizationId: String
    }

    public init() {}

    @discardableResult
    public func build(project: OrgRecProject, packageURL: URL, destinationURL: URL) async throws -> URL {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destinationURL.path) else {
            throw OrgRecError.exportValidation("The VAO destination already exists.")
        }
        guard manager.fileExists(atPath: packageURL.appendingPathComponent(ProjectStore.projectFilename).path) else {
            throw OrgRecError.exportValidation("The OrgRec project has no project.json.")
        }
        let sourceFiles = try packageFiles(at: packageURL)
        guard !sourceFiles.isEmpty else { throw OrgRecError.exportValidation("The OrgRec project contains no exportable files.") }

        let projectID = "urn:uuid:\(project.id.uuidString.lowercased())"
        let vaoID = "urn:orgrec:project:\(project.id.uuidString.lowercased())"
        let releaseFingerprint = sourceFiles.map { "\($0.relativePath)\u{0}\($0.size)\u{0}\($0.digest)" }.joined(separator: "\n").data(using: .utf8)!.sha256Hex
        let releaseID = "urn:orgrec:release:sha256:\(releaseFingerprint)"
        let groupID = "urn:orgrec:group:preservation:\(releaseFingerprint)"
        let rightsID = "urn:orgrec:rights:\(releaseFingerprint)"
        let softwareAgentID = "urn:orgrec:agent:software"
        let exportProtocolID = "urn:orgrec:protocol:vao050-export"
        let exportActivityID = "urn:orgrec:activity:export:\(releaseFingerprint)"
        let createdAt = Self.timestamp(project.createdAt)
        let modifiedAt = Self.timestamp(project.updatedAt)

        let profiles = [
            VAO03Profile(
                id: VAO05Contract.coreProfile,
                version: VAO05Contract.formatVersion,
                requiredCapabilities: [
                    "https://w3id.org/modavis/vao/vocab/capability/core-graph",
                    "https://w3id.org/modavis/vao/vocab/capability/fixity",
                ]
            ),
            VAO03Profile(
                id: VAO05Contract.dynamicDeliveryProfile,
                version: VAO05Contract.formatVersion,
                requiredCapabilities: [
                    "https://w3id.org/modavis/vao/vocab/capability/immutable-release",
                    "https://w3id.org/modavis/vao/vocab/capability/carrier-mapping",
                ]
            ),
            VAO03Profile(
                id: VAO05Contract.scientificProfile,
                version: VAO05Contract.formatVersion,
                requiredCapabilities: ["https://w3id.org/modavis/vao/vocab/capability/typed-scientific-provenance"]
            ),
        ]
        let entity = VAO03Entity(
            id: projectID,
            kind: "instrument",
            types: [
                "https://w3id.org/modavis/ontology/instrument#MusicalInstrument",
                "https://w3id.org/modavis/ontology/organ#PipeOrgan",
            ],
            labels: ["und": project.organName.isEmpty ? project.title : project.organName],
            classifications: nil,
            externalIdentifiers: nil,
            properties: [
                "https://w3id.org/modavis/vao/ontology#orgrecProjectTitle": .string(project.title),
                "https://w3id.org/modavis/vao/ontology#venueLabel": .string(project.venueName),
                "https://w3id.org/modavis/vao/ontology#orgrecProjectSchemaVersion": .integer(Int64(project.schemaVersion)),
            ]
        )
        let logicalAssets = sourceFiles.map { file in
            VAO03LogicalAsset(
                id: file.assetId,
                type: "LogicalAsset",
                labels: ["und": file.relativePath],
                roles: [Self.assetRole(for: file.relativePath)],
                aboutEntityIds: [projectID],
                realizationIds: [file.realizationId],
                properties: ["https://w3id.org/modavis/vao/ontology#orgrecRelativePath": .string(file.relativePath)]
            )
        }
        let realizations = sourceFiles.map { file in
            VAO05Realization(
                id: file.realizationId,
                type: "Realization",
                assetId: file.assetId,
                variantSetId: "orgrec-preservation-source",
                qualityTier: "preservation",
                mediaType: Self.mediaType(for: file.url),
                byteSize: file.size,
                sha256: file.digest,
                representationStatus: "https://w3id.org/modavis/vao/vocab/representation-status/undetermined",
                rightsIds: [rightsID],
                provenanceIds: [exportActivityID],
                technicalMetadata: .object([
                    "kind": .string(Self.technicalKind(for: file.url)),
                    "purposeLimitations": .array([
                        .string("Detailed capture and analysis metadata remain in the identified OrgRec project records.")
                    ]),
                ]),
                distributionIds: [],
                contentDigests: [VAO04ContentDigest(algorithm: "sha256", value: file.digest)],
                extensions: nil
            )
        }
        let rightsText = (project.recordingSessions ?? [])
            .map(\.rightsStatement)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
        let license = project.organCharacteristics?.sourceURLs?.first {
            $0.lowercased().contains("creativecommons.org/licenses/")
        }
        let rightsStatement = rightsText.isEmpty
            ? "Rights and consent were not asserted by the project. No reuse permission is inferred."
            : rightsText
        let coveredIDs = [vaoID, projectID] + logicalAssets.map(\.id) + realizations.map(\.id)

        let scientific: VAOJSONValue = .object([
            "agents": .array([.object([
                "id": .string(softwareAgentID),
                "agentKind": .string("software-agent"),
                "labels": .object(["en": .string("OrgRec")]),
            ])]),
            "activities": .array([.object([
                "id": .string(exportActivityID),
                "activityKind": .string("processing"),
                "startedAt": .string(modifiedAt),
                "endedAt": .string(modifiedAt),
                "agentIds": .array([.string(softwareAgentID)]),
                "protocolId": .string(exportProtocolID),
                "inputIds": .array([.string(projectID)]),
                "outputIds": .array([.string(releaseID)] + realizations.map { .string($0.id) }),
            ])]),
            "observations": .array([]), "analyses": .array([]),
            "calibrations": .array([]),
            "protocols": .array([.object([
                "id": .string(exportProtocolID),
                "labels": .object(["en": .string("OrgRec VAO 0.5.0 preservation export")]),
                "procedure": .string("Index each regular project file as an exact realization, embed the complete payload closure, and bind the manifest and carrier by SHA-256."),
                "version": .string("1"),
            ])]),
            "softwareEnvironments": .array([]),
            "claims": .array([]), "reviews": .array([]), "consents": .array([]),
        ])
        let runtime: VAOJSONValue = .object([
            "executionSemantics": .object([
                "timestampOrder": .string("ascending"),
                "simultaneousEventOrder": .string("priority-then-event-id"),
                "transitionEvaluation": .string("snapshot"),
                "actionExecution": .string("execution-group-then-array-order"),
                "runToCompletion": .boolean(true),
                "reentrancyPolicy": .string("queue"),
                "lateEventPolicy": .string("reject"),
                "timeResolution": .object([
                    "value": .integer(1),
                    "unit": .string("http://qudt.org/vocab/unit/MilliSEC"),
                ]),
                "maximumMicrosteps": .integer(10_000),
                "voiceAllocation": .string("lowest-free-then-oldest"),
                "maximumVoices": .integer(1_024),
            ]),
            "randomSources": .array([]), "renderers": .array([]), "conformanceTraces": .array([]),
        ])
        let group = VAO03AssetGroup(
            id: groupID,
            type: "AssetGroup",
            labels: ["en": "OrgRec preservation closure"],
            selectionSetId: "preservation",
            qualityTier: "bootstrap",
            availability: "offline-required",
            selectionPolicy: "independent",
            realizationIds: realizations.map(\.id),
            dependsOnGroupIds: [],
            fallbackGroupId: nil,
            totalByteSize: realizations.reduce(0) { $0 + $1.byteSize },
            requiredCapabilities: [],
            materializesProfileIds: [],
            cachePolicy: VAO03CachePolicy(evictable: false, priority: 100)
        )
        let manifest = VAO05Manifest(
            schema: VAO05Contract.schemaURI,
            context: [VAO05Contract.contextURI],
            type: "VirtualAcousticObject",
            formatVersion: VAO05Contract.formatVersion,
            id: vaoID,
            release: VAO03ReleaseIdentity(id: releaseID, revision: 1, contentVersion: modifiedAt, supersedesReleaseId: nil, migratedFromManifestSHA256: nil),
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            title: ["und": project.title],
            description: ["en": "Self-contained VAO 0.5.0 preservation closure exported from OrgRec."],
            conformsTo: profiles.map(\.id),
            profiles: profiles,
            materializableProfiles: [],
            modavisBinding: VAO03ModavisBinding(
                ontologyIRI: "https://w3id.org/modavis/ontology",
                ontologyVersion: "0.1.0",
                ontologyStatus: "released",
                ontologyVersionIRI: "https://w3id.org/modavis/ontology/0.1.0",
                mappingVersion: VAO05Contract.formatVersion,
                mappingIRI: VAO05Contract.baseURI + "/modavis-mapping",
                vocabularyReleaseIRI: nil,
                vocabularyManifestSHA256: nil,
                notes: "Final VAO 0.5.0 co-release binding."
            ),
            primaryEntityId: projectID,
            focusEntityIds: [projectID],
            entities: [entity],
            relations: [],
            scientific: scientific,
            multimodal: .object(["timebases": .array([]), "tracks": .array([]), "synchronizationMappings": .array([]), "annotations": .array([])]),
            physicalSystem: .object(["components": .array([]), "ports": .array([]), "connections": .array([]), "sensors": .array([]), "actuators": .array([]), "stateBindings": .array([])]),
            runtime: runtime,
            discovery: .object([
                "resourceType": .string("Dataset"),
                "creatorAgentIds": .array([.string(softwareAgentID)]),
                "contributorAgentIds": .array([]), "relatedIdentifiers": .array([]),
                "fundingReferences": .array([]), "subjects": .array([.object(["subject": .string("pipe organ recording")])]),
            ]),
            acoustics: nil,
            playable: nil,
            interactionModel: nil,
            captureDocumentation: nil,
            logicalAssets: logicalAssets,
            realizations: realizations,
            distributions: [],
            repositoryBindings: [],
            assetGroups: [group],
            rights: [VAO05Rights(
                id: rightsID,
                appliesToIds: coveredIDs,
                license: license,
                statement: ["und": rightsStatement],
                access: license == nil ? "unknown" : "restricted",
                attribution: nil,
                privacyClassification: "restricted"
            )],
            integrity: .object([
                "algorithm": .string("sha256"),
                "manifestDigestLocation": .string("external-release-and-carrier-descriptors"),
                "carrierDescriptor": .string(VAO05Contract.carrierFilename),
                "schemaBundleDigest": .object([
                    "algorithm": .string("sha256"),
                    "value": .string(VAO05Contract.releaseBundleSHA256),
                ]),
            ]),
            extensions: [
                "https://w3id.org/modavis/vao/ontology#orgrecSoftware": .object([
                    "name": .string(OrgRecSoftware.name),
                    "version": .string(OrgRecSoftware.version),
                    "build": .string(OrgRecSoftware.build),
                    "identifier": .string(OrgRecSoftware.identifier),
                ]),
                "https://w3id.org/modavis/vao/ontology#vaoSpecificationDOI": .string(VAO05Contract.specificationDOI),
            ]
        )
        let nativeErrors = VAO05Validator.validateManifest(manifest)
        guard nativeErrors.isEmpty else {
            throw OrgRecError.exportValidation("VAO 0.5.0 manifest failed native validation: " + nativeErrors.prefix(3).joined(separator: "; "))
        }
        let manifestData = try OrgRecCoding.encoder.encode(manifest)
        let carrier = VAO05Carrier(
            id: "urn:orgrec:carrier:sha256:\(manifestData.sha256Hex)",
            releaseId: releaseID,
            manifestSHA256: manifestData.sha256Hex,
            manifestByteSize: Int64(manifestData.count),
            carrierMode: "preservation-closure",
            embeddedRealizations: sourceFiles.map { VAO03CarrierMapping(realizationId: $0.realizationId, path: $0.payloadPath) },
            completeGroupIds: [groupID]
        )
        let carrierData = try OrgRecCoding.encoder.encode(carrier)
        var entries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAO05Contract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAO05Contract.manifestFilename, data: manifestData),
            VAOArchiveEntrySource(path: VAO05Contract.carrierFilename, data: carrierData),
        ]
        entries.append(contentsOf: sourceFiles.map { VAOArchiveEntrySource(path: $0.payloadPath, fileURL: $0.url) })
        try manager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try VAOArchiveWriter.write(entries: entries, to: destinationURL)
            let inspection = try await VAO05PackageReader().inspect(destinationURL)
            guard inspection.isValid else {
                throw OrgRecError.exportValidation("Created VAO 0.5.0 failed validation: " + inspection.errors.prefix(3).joined(separator: "; "))
            }
            return destinationURL
        } catch {
            try? manager.removeItem(at: destinationURL)
            throw error
        }
    }

    private func packageFiles(at root: URL) throws -> [SourceFile] {
        let manager = FileManager.default
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = manager.enumerator(at: resolvedRoot, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            throw OrgRecError.exportValidation("Could not enumerate the OrgRec project package.")
        }
        var files: [SourceFile] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            let resolvedPath = url.standardizedFileURL.path
            guard resolvedPath.hasPrefix(resolvedRoot.path + "/") else {
                throw OrgRecError.exportValidation("Project enumeration escaped the OrgRec package.")
            }
            let relative = String(resolvedPath.dropFirst(resolvedRoot.path.count + 1))
            if relative == "Exports" || relative.hasPrefix("Exports/") {
                enumerator.skipDescendants()
                continue
            }
            if values.isSymbolicLink == true {
                throw OrgRecError.exportValidation("OrgRec project contains a symbolic link, which VAO prohibits: \(relative)")
            }
            guard values.isRegularFile == true, isSafePackageRelativePath(relative) else { continue }
            let digest = try sha256(of: url)
            let identity = Data(relative.utf8).sha256Hex
            files.append(SourceFile(
                url: url,
                relativePath: relative,
                payloadPath: "payload/orgrec/\(relative)",
                digest: digest,
                size: Int64(values.fileSize ?? 0),
                assetId: "urn:orgrec:asset:sha256:\(identity)",
                realizationId: "urn:orgrec:realization:sha256:\(digest)"
            ))
        }
        let duplicateRealizations = Dictionary(grouping: files, by: \.realizationId).filter { $0.value.count > 1 }
        if !duplicateRealizations.isEmpty {
            // Equal bytes in different paths are distinct realizations in the VAO model.
            for index in files.indices where duplicateRealizations[files[index].realizationId] != nil {
                files[index].realizationId += ":path:\(Data(files[index].relativePath.utf8).sha256Hex)"
            }
        }
        return files.sorted { $0.payloadPath < $1.payloadPath }
    }

    private static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func assetRole(for path: String) -> String {
        if path == ProjectStore.projectFilename { return "https://w3id.org/modavis/vao/vocab/asset-role/application-state" }
        if path.hasPrefix("Analysis/") { return "https://w3id.org/modavis/vao/vocab/asset-role/analysis-result" }
        if path.hasPrefix("Audio/") { return "https://w3id.org/modavis/vao/vocab/asset-role/audio-master" }
        return "https://w3id.org/modavis/vao/vocab/asset-role/source-evidence"
    }

    private static func technicalKind(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "json", "jsonld", "csv", "tsv", "yaml", "yml", "imu": "data"
        case "txt", "md", "pdf", "html", "htm", "organ": "document"
        default: "other"
        }
    }

    private static func mediaType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav", "wave": "audio/wav"
        case "aif", "aiff": "audio/aiff"
        case "flac": "audio/flac"
        case "json": "application/json"
        case "jsonld": "application/ld+json"
        case "csv": "text/csv"
        case "tsv": "text/tab-separated-values"
        case "txt", "md", "organ": "text/plain"
        case "html", "htm": "text/html"
        case "pdf": "application/pdf"
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        case "tif", "tiff": "image/tiff"
        case "glb": "model/gltf-binary"
        case "gltf": "model/gltf+json"
        case "obj": "model/obj"
        case "mid", "midi": "audio/midi"
        case "mov": "video/quicktime"
        case "mp4": "video/mp4"
        case "imu": "application/vnd.orgrec.interaction-sensor"
        default: "application/octet-stream"
        }
    }
}
