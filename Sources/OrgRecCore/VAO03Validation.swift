import Foundation

public struct VAO03EmbeddedFileVerification: Sendable, Equatable {
    public var sha256: String
    public var byteSize: Int64

    public init(sha256: String, byteSize: Int64) {
        self.sha256 = sha256
        self.byteSize = byteSize
    }
}

public enum VAO03Validator {
    public static func validateManifest(data: Data) -> [String] {
        let manifest: VAO03Manifest
        do {
            manifest = try JSONDecoder().decode(VAO03Manifest.self, from: data)
        } catch {
            return ["VAO 0.3 manifest cannot be decoded: \(error.localizedDescription)"]
        }
        var errors = validateManifest(manifest)
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let allowed: Set<String> = [
                "$schema", "@context", "type", "formatVersion", "id", "release", "createdAt", "modifiedAt",
                "title", "description", "conformsTo", "profiles", "materializableProfiles", "modavisBinding",
                "primaryEntityId", "focusEntityIds", "entities", "relations", "paradata", "analyses", "acoustics", "playable",
                "interactionModel", "captureDocumentation",
                "logicalAssets", "realizations", "distributions", "repositoryBindings", "assetGroups", "rights",
                "integrity", "extensions",
            ]
            for key in Set(root.keys).subtracting(allowed).sorted() {
                errors.append("Manifest contains unknown root property \(key).")
            }
            errors.append(contentsOf: validateComplexInteractionShape(root))
        }
        return Array(Set(errors)).sorted()
    }

    public static func validateManifest(_ manifest: VAO03Manifest) -> [String] {
        var errors: [String] = []
        if manifest.schema != VAO03Contract.schemaURI { errors.append("Manifest uses the wrong VAO 0.3 schema IRI.") }
        if !manifest.context.contains(VAO03Contract.contextURI) { errors.append("Manifest lacks the VAO 0.3 context IRI.") }
        if manifest.type != "VirtualAcousticObject" { errors.append("Manifest type must be VirtualAcousticObject.") }
        if manifest.formatVersion != VAO03Contract.formatVersion { errors.append("Manifest formatVersion must be 0.3.3.") }
        if manifest.release.revision < 1 || manifest.release.contentVersion.isEmpty { errors.append("Release identity is incomplete.") }

        let entities = index(manifest.entities, by: \.id)
        if entities.count != manifest.entities.count { errors.append("Entity identifiers are not unique.") }
        if entities[manifest.primaryEntityId] == nil { errors.append("primaryEntityId does not resolve.") }
        if !manifest.focusEntityIds.contains(manifest.primaryEntityId) { errors.append("focusEntityIds must contain primaryEntityId.") }
        for id in manifest.focusEntityIds where entities[id] == nil { errors.append("Focus entity \(id) does not resolve.") }

        let assets = index(manifest.logicalAssets, by: \.id)
        let realizations = index(manifest.realizations, by: \.id)
        let distributions = index(manifest.distributions, by: \.id)
        let bindings = index(manifest.repositoryBindings, by: \.id)
        let groups = index(manifest.assetGroups, by: \.id)
        let rights = index(manifest.rights, by: \.id)
        let acousticIDs = VAO03AcousticsValidator.identifiers(in: manifest.acoustics)
        let playableIDs = VAO03PlayableValidator.identifiers(in: manifest.playable)
        let complexInteractionIDs = VAO03ComplexInteractionValidator.identifiers(
            interaction: manifest.interactionModel,
            capture: manifest.captureDocumentation
        )
        let acousticFrameIDs = Set(
            manifest.acoustics?.objectValue?["coordinateFrames"]?.arrayValue?.compactMap {
                $0.objectValue?["id"]?.stringValue
            } ?? []
        )
        let registryCounts = [
            manifest.entities.map(\.id), manifest.relations.map(\.id), manifest.logicalAssets.map(\.id),
            manifest.realizations.map(\.id), manifest.distributions.map(\.id), manifest.repositoryBindings.map(\.id),
            manifest.assetGroups.map(\.id), manifest.rights.map(\.id), acousticIDs, playableIDs, complexInteractionIDs,
        ].flatMap { $0 }
        if Set(registryCounts).count != registryCounts.count { errors.append("Identifiers are not unique across VAO 0.3 registries.") }

        for asset in manifest.logicalAssets {
            for entityID in asset.aboutEntityIds where entities[entityID] == nil { errors.append("Logical asset \(asset.id) has unresolved subject \(entityID).") }
            for realizationID in asset.realizationIds {
                guard let realization = realizations[realizationID] else { errors.append("Logical asset \(asset.id) has unresolved realization \(realizationID)."); continue }
                if realization.assetId != asset.id { errors.append("Logical asset/realization inverse mismatch for \(realizationID).") }
            }
        }
        for realization in manifest.realizations {
            if assets[realization.assetId]?.realizationIds.contains(realization.id) != true { errors.append("Realization/logical asset inverse mismatch for \(realization.id).") }
            if realization.byteSize < 0 || realization.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil { errors.append("Realization \(realization.id) has invalid byte fixity.") }
            for id in realization.distributionIds where distributions[id] == nil { errors.append("Realization \(realization.id) has unresolved distribution \(id).") }
            for id in realization.rightsIds where rights[id] == nil { errors.append("Realization \(realization.id) has unresolved rights \(id).") }
            let technical = realization.technicalMetadata
            if technical.kind == "audio" && (technical.sampleRate ?? 0) <= 0 { errors.append("Audio realization \(realization.id) needs a positive sample rate.") }
            if let order = technical.ambisonicsOrder {
                let expected = technical.ambisonicsDimensionality == "3D" ? (order + 1) * (order + 1) : 2 * order + 1
                if technical.channelCount != expected { errors.append("Ambisonics realization \(realization.id) has inconsistent channel count.") }
                if technical.ambisonicsChannelOrder != "ACN" || !["SN3D", "N3D"].contains(technical.ambisonicsNormalization ?? "") { errors.append("Ambisonics realization \(realization.id) has incomplete convention metadata.") }
            }
            if technical.kind == "geometry" && !acousticFrameIDs.contains(technical.coordinateFrameId ?? "") { errors.append("Geometry realization \(realization.id) has unresolved coordinate frame.") }
        }

        let embeddedProfiles = Set(manifest.profiles.map(\.id))
        let materializableProfiles = Set(manifest.materializableProfiles.map(\.id))
        if !embeddedProfiles.contains(VAO03Contract.coreProfile) || !manifest.conformsTo.contains(VAO03Contract.coreProfile) { errors.append("VAO 0.3 requires embedded Core profile conformance.") }
        if !embeddedProfiles.contains(VAO03Contract.dynamicDeliveryProfile) || !manifest.conformsTo.contains(VAO03Contract.dynamicDeliveryProfile) { errors.append("VAO 0.3 requires embedded Dynamic Delivery profile conformance.") }
        if !embeddedProfiles.isDisjoint(with: materializableProfiles) { errors.append("A profile cannot be both embedded and materializable.") }
        for id in embeddedProfiles.union(materializableProfiles).union(Set(manifest.conformsTo)) where id.hasSuffix("/0.2") { errors.append("VAO 0.3 must not reuse 0.2 profile IRI \(id).") }

        let usesZenodo = manifest.repositoryBindings.contains { $0.repositoryType == VAO03Contract.zenodoRepositoryType }
        if usesZenodo != embeddedProfiles.contains(VAO03Contract.zenodoProfile) { errors.append("The optional Zenodo profile must be claimed if and only if a Zenodo binding is used.") }
        VAO03AcousticsValidator.validate(
            manifest: manifest,
            entities: entities,
            assets: assets,
            realizations: realizations,
            errors: &errors
        )
        VAO03PlayableValidator.validate(
            manifest: manifest,
            entities: entities,
            realizations: realizations,
            errors: &errors
        )
        VAO03ComplexInteractionValidator.validate(
            manifest: manifest,
            entities: entities,
            realizations: realizations,
            errors: &errors
        )
        for distribution in manifest.distributions {
            if distribution.kind == "repository" {
                guard let binding = bindings[distribution.repositoryBindingId ?? ""] else { errors.append("Repository distribution \(distribution.id) has unresolved binding."); continue }
                if binding.repositoryType == VAO03Contract.zenodoRepositoryType {
                    if distribution.persistentIdentifier == distribution.conceptIdentifier { errors.append("Zenodo distribution \(distribution.id) uses its concept DOI for exact acquisition.") }
                    let pid = distribution.persistentIdentifier ?? ""
                    if !pid.hasPrefix("https://doi.org/10.5072/zenodo.") && !pid.hasPrefix("https://doi.org/10.5281/zenodo.") { errors.append("Zenodo distribution \(distribution.id) lacks an exact Zenodo DOI URL.") }
                }
            } else if distribution.kind == "pack-member" {
                if realizations[distribution.packRealizationId ?? ""] == nil { errors.append("Pack-member distribution \(distribution.id) has unresolved outer pack.") }
                if !safeMemberPath(distribution.memberPath ?? "") { errors.append("Pack-member distribution \(distribution.id) has unsafe path.") }
            } else { errors.append("Distribution \(distribution.id) has unknown kind.") }
        }

        for group in manifest.assetGroups {
            var total: Int64 = 0
            for id in Set(group.realizationIds) {
                guard let realization = realizations[id] else { errors.append("Asset group \(group.id) has unresolved realization \(id)."); continue }
                total += realization.byteSize
            }
            if total != group.totalByteSize { errors.append("Asset group \(group.id) has incorrect totalByteSize.") }
            for id in group.dependsOnGroupIds where groups[id] == nil { errors.append("Asset group \(group.id) has unresolved dependency \(id).") }
            if let id = group.fallbackGroupId, groups[id] == nil { errors.append("Asset group \(group.id) has unresolved fallback \(id).") }
        }
        findCycles(groups: groups, edges: { $0.dependsOnGroupIds }, label: "dependency", errors: &errors)
        findCycles(groups: groups, edges: { $0.fallbackGroupId.map { [$0] } ?? [] }, label: "fallback", errors: &errors)
        if !manifest.assetGroups.contains(where: { $0.qualityTier == "bootstrap" && !$0.realizationIds.isEmpty }) { errors.append("VAO 0.3 requires a non-empty bootstrap group.") }

        let requiredRights = Set([manifest.id] + manifest.logicalAssets.map(\.id) + manifest.realizations.map(\.id))
        let coveredRights = Set(manifest.rights.flatMap(\.appliesToIds))
        for id in requiredRights.subtracting(coveredRights).sorted() { errors.append("No rights record covers \(id).") }
        return Array(Set(errors)).sorted()
    }

    public static func validateCarrier(manifestData: Data, carrierData: Data, embeddedData: [String: Data]) -> [String] {
        let verification = embeddedData.mapValues {
            VAO03EmbeddedFileVerification(sha256: $0.sha256Hex, byteSize: Int64($0.count))
        }
        return validateCarrier(
            manifestData: manifestData,
            carrierData: carrierData,
            embeddedVerification: verification
        )
    }

    /// Streaming callers can hash large embedded realizations without loading
    /// every payload into memory, then supply the verified digest/size pairs.
    public static func validateCarrier(
        manifestData: Data,
        carrierData: Data,
        embeddedVerification: [String: VAO03EmbeddedFileVerification]
    ) -> [String] {
        var errors = validateManifest(data: manifestData)
        guard let manifest = try? JSONDecoder().decode(VAO03Manifest.self, from: manifestData),
              let carrier = try? JSONDecoder().decode(VAO03Carrier.self, from: carrierData) else {
            return errors + ["Manifest or carrier descriptor cannot be decoded."]
        }
        if carrier.manifestSHA256 != manifestData.sha256Hex || carrier.manifestByteSize != manifestData.count { errors.append("Carrier does not pin exact manifest bytes.") }
        if carrier.releaseId != manifest.release.id { errors.append("Carrier releaseId differs from manifest release.id.") }
        let realizations = index(manifest.realizations, by: \.id)
        let groups = index(manifest.assetGroups, by: \.id)
        var mappedPaths = Set<String>()
        var embeddedIDs = Set<String>()
        var verificationByNormalizedPath: [String: VAO03EmbeddedFileVerification] = [:]
        for (path, verification) in embeddedVerification {
            let normalized = path.precomposedStringWithCanonicalMapping
            if verificationByNormalizedPath[normalized] != nil {
                errors.append("Carrier payload paths collide after NFC normalization.")
            } else {
                verificationByNormalizedPath[normalized] = verification
            }
        }
        for mapping in carrier.embeddedRealizations {
            let normalizedPath = mapping.path.precomposedStringWithCanonicalMapping
            guard safePayloadPath(mapping.path), let verification = verificationByNormalizedPath[normalizedPath], let realization = realizations[mapping.realizationId] else { errors.append("Carrier mapping \(mapping.path) is missing, unsafe, or unresolved."); continue }
            if !mappedPaths.insert(normalizedPath).inserted || !embeddedIDs.insert(mapping.realizationId).inserted { errors.append("Carrier mapping is duplicated after NFC normalization.") }
            if verification.byteSize != realization.byteSize || verification.sha256 != realization.sha256 { errors.append("Embedded realization \(mapping.realizationId) fails fixity.") }
        }
        for path in Set(verificationByNormalizedPath.keys).subtracting(mappedPaths) { errors.append("Unindexed payload file \(path).") }
        for groupID in carrier.completeGroupIds {
            guard let group = groups[groupID] else { errors.append("Carrier claims unknown complete group \(groupID)."); continue }
            if !Set(group.realizationIds).isSubset(of: embeddedIDs) { errors.append("Carrier claims incomplete group \(groupID).") }
        }
        if carrier.carrierMode == "bootstrap" && embeddedIDs.isEmpty { errors.append("Bootstrap carrier embeds no realization.") }
        if carrier.carrierMode == "preservation-closure" && embeddedIDs != Set(realizations.keys) { errors.append("Preservation closure does not embed every realization.") }
        return Array(Set(errors)).sorted()
    }

    public static func validateReleaseDescriptor(data: Data) -> [String] {
        guard let release = try? JSONDecoder().decode(VAO03ReleaseDescriptor.self, from: data) else {
            return ["VAO 0.3 release descriptor cannot be decoded."]
        }
        return validateReleaseDescriptor(release)
    }

    public static func validateReleaseDescriptor(_ release: VAO03ReleaseDescriptor) -> [String] {
        var errors: [String] = []
        if release.schema != VAO03Contract.releaseSchemaURI { errors.append("Release descriptor uses the wrong VAO 0.3 schema IRI.") }
        if release.type != "VAORelease" { errors.append("Release descriptor type must be VAORelease.") }
        if release.formatVersion != VAO03Contract.formatVersion { errors.append("Release descriptor formatVersion must be 0.3.3.") }
        if release.revision < 1 || release.contentVersion.isEmpty { errors.append("Release descriptor identity is incomplete.") }
        let publication = release.publication
        if publication.topology == "single-record" && !publication.familyMembers.isEmpty { errors.append("A single-record publication cannot contain family members.") }
        if publication.topology == "record-family" && publication.familyMembers.isEmpty { errors.append("A record-family publication needs at least one family member.") }
        if !["single-record", "record-family"].contains(publication.topology) { errors.append("Publication topology is unknown.") }

        let records = [publication.rootRecord] + publication.familyMembers.map(\.record)
        if Set(records.map(\.id)).count != records.count { errors.append("Publication record identifiers are not unique.") }
        if Set(records.map(\.versionPersistentIdentifier)).count != records.count { errors.append("Publication version PIDs are not unique.") }
        for record in records {
            if record.versionPersistentIdentifier == record.conceptPersistentIdentifier { errors.append("Publication record \(record.id) uses its concept PID as its exact version PID.") }
            if Set(record.files.map(\.fileIdentifier)).count != record.files.count { errors.append("Publication record \(record.id) contains duplicate file identifiers.") }
            if record.files.contains(where: { $0.fileIdentifier == "vao-release.json" }) { errors.append("Publication record \(record.id) must not self-hash vao-release.json.") }
            for file in record.files {
                if file.byteSize < 0 || file.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil { errors.append("Publication file \(file.fileIdentifier) has invalid fixity.") }
                if ["realization", "pack"].contains(file.role) && (file.realizationIds?.isEmpty != false) { errors.append("Publication realization or pack file \(file.fileIdentifier) must name realizationIds.") }
            }
        }
        let rootRoles = publication.rootRecord.files.map(\.role)
        if rootRoles.filter({ $0 == "manifest" }).count != 1 { errors.append("The publication root must inventory exactly one manifest file.") }
        if !rootRoles.contains("carrier") { errors.append("The publication root must inventory at least one bootstrap carrier.") }
        for member in publication.familyMembers {
            if member.membership == "exclusive" && (member.relationFromRoot != "hasPart" || member.inverseRelationFromMember != "isPartOf") {
                errors.append("An exclusive family member must use hasPart/isPartOf.")
            }
            if member.membership == "shared" && member.relationFromRoot == "hasPart" { errors.append("A shared family member cannot use hasPart.") }
        }
        return Array(Set(errors)).sorted()
    }

    public static func validatePublication(_ release: VAO03ReleaseDescriptor, zenodoMetadata documents: [VAO03ZenodoMetadataDocument]) -> [String] {
        var errors = validateReleaseDescriptor(release)
        let publication = release.publication
        let records = [publication.rootRecord] + publication.familyMembers.map(\.record)
        var recordsByID: [String: VAO03PublicationRecord] = [:]
        for record in records where recordsByID[record.id] == nil { recordsByID[record.id] = record }
        var documentsByID: [String: VAO03ZenodoMetadataDocument] = [:]
        for document in documents {
            if documentsByID[document.publicationRecordId] != nil { errors.append("Zenodo metadata for publication record \(document.publicationRecordId) is duplicated.") }
            else { documentsByID[document.publicationRecordId] = document }
            if document.schema != VAO03Contract.zenodoMetadataSchemaURI || document.type != "VAOZenodoMetadata" || document.formatVersion != VAO03Contract.formatVersion { errors.append("Zenodo metadata \(document.publicationRecordId) uses the wrong VAO 0.3.3 contract.") }
            if document.releaseId != release.releaseId { errors.append("Zenodo metadata \(document.publicationRecordId) has the wrong releaseId.") }
            if recordsByID[document.publicationRecordId] == nil { errors.append("Zenodo metadata names unknown publication record \(document.publicationRecordId).") }
            if document.metadata.uploadType != "dataset" { errors.append("Zenodo VAO records must use dataset upload_type.") }
            if document.metadata.creators.isEmpty || !document.metadata.keywords.contains("Virtual Acoustic Object") || !document.metadata.keywords.contains("VAO 0.3") { errors.append("Zenodo metadata \(document.publicationRecordId) lacks required creator/VAO discovery metadata.") }
            if ["open", "embargoed"].contains(document.metadata.accessRight) && document.metadata.license == nil { errors.append("Open or embargoed Zenodo metadata needs a license.") }
        }
        let zenodoIDs = Set(records.filter { $0.repositoryType == VAO03Contract.zenodoRepositoryType }.map(\.id))
        for id in zenodoIDs.subtracting(Set(documentsByID.keys)) { errors.append("Zenodo publication record \(id) lacks a metadata projection.") }
        for id in Set(documentsByID.keys).subtracting(zenodoIDs) { errors.append("Metadata projection \(id) does not describe a Zenodo record.") }

        let root = publication.rootRecord
        if let rootDocument = documentsByID[root.id] {
            let expectedRole = publication.topology == "single-record" ? "monolithic-root" : "family-root"
            if rootDocument.recordRole != expectedRole { errors.append("Root Zenodo metadata recordRole must be \(expectedRole).") }
            if rootDocument.metadata.version != release.contentVersion { errors.append("Root Zenodo metadata version must equal release contentVersion.") }
            let rootRelations = Set(rootDocument.metadata.relatedIdentifiers.map { "\($0.relation)\u{1f}\($0.identifier)" })
            for member in publication.familyMembers {
                let key = "\(member.relationFromRoot)\u{1f}\(member.record.versionPersistentIdentifier)"
                if !rootRelations.contains(key) { errors.append("Root Zenodo metadata lacks \(member.relationFromRoot) relation to exact member PID \(member.record.versionPersistentIdentifier).") }
                if let concept = member.record.conceptPersistentIdentifier, rootRelations.contains("\(member.relationFromRoot)\u{1f}\(concept)") { errors.append("Root Zenodo metadata uses a concept PID for a family relation.") }
                if let memberDocument = documentsByID[member.record.id] {
                    if memberDocument.recordRole != "family-member" { errors.append("Family-member Zenodo metadata must use recordRole family-member.") }
                    if let inverse = member.inverseRelationFromMember {
                        let inverseRelations = Set(memberDocument.metadata.relatedIdentifiers.map { "\($0.relation)\u{1f}\($0.identifier)" })
                        if !inverseRelations.contains("\(inverse)\u{1f}\(root.versionPersistentIdentifier)") { errors.append("Family-member metadata lacks inverse relation to the exact root PID.") }
                    }
                }
            }
        }
        return Array(Set(errors)).sorted()
    }

    private static func safeMemberPath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    private static func validateComplexInteractionShape(_ root: [String: Any]) -> [String] {
        var errors: [String] = []
        func rejectUnknown(_ value: Any?, allowed: Set<String>, path: String) {
            guard let object = value as? [String: Any] else { return }
            for key in Set(object.keys).subtracting(allowed).sorted() {
                errors.append("\(path) contains unknown property \(key).")
            }
        }
        func records(_ container: [String: Any], _ key: String) -> [[String: Any]] {
            (container[key] as? [[String: Any]]) ?? []
        }
        func checkConditions(_ value: Any?, path: String) {
            for (index, condition) in ((value as? [[String: Any]]) ?? []).enumerated() {
                rejectUnknown(condition, allowed: ["stateVariableId", "operator", "value"], path: "\(path)[\(index)]")
            }
        }
        func checkActions(_ value: Any?, path: String) {
            for (index, action) in ((value as? [[String: Any]]) ?? []).enumerated() {
                rejectUnknown(
                    action,
                    allowed: ["operation", "targetId", "value", "keyOffset", "delayConstraintId", "executionGroup"],
                    path: "\(path)[\(index)]"
                )
            }
        }

        if let model = root["interactionModel"] as? [String: Any] {
            let registryNames: Set<String> = [
                "controls", "eventTypes", "protocolBindings", "stateVariables", "transitions",
                "routingRules", "processModels", "timingConstraints", "transferFunctions", "renderBindings",
            ]
            rejectUnknown(model, allowed: registryNames, path: "interactionModel")
            let allowed: [String: Set<String>] = [
                "controls": ["id", "labels", "entityId", "controlBehavior", "valueType", "minimumValue", "maximumValue", "stepCount", "allowedValues", "defaultValue", "status", "source", "generatedById", "reviewedById", "sourceLocator", "notes"],
                "eventTypes": ["id", "labels", "eventKind", "valueDomain", "status", "source", "generatedById", "reviewedById", "notes"],
                "protocolBindings": ["id", "controlId", "eventTypeId", "protocol", "direction", "messageType", "channel", "number", "channelNumberingBase", "dataNumberingBase", "address", "activationValue", "deactivationValue", "status", "source", "generatedById", "reviewedById", "sourceLocator"],
                "stateVariables": ["id", "labels", "subjectEntityId", "valueType", "persistence", "defaultValue", "minimumValue", "maximumValue", "stepCount", "allowedValues", "status", "source", "generatedById", "reviewedById", "notes"],
                "transitions": ["id", "eventTypeId", "controlId", "conditions", "actions", "atomic", "conflictPolicy", "priority", "status", "source", "generatedById", "reviewedById", "notes"],
                "routingRules": ["id", "sourceControlId", "sourceEntityId", "targetEntityId", "routingBehavior", "inputKeyMeaning", "outputKeyMeaning", "inputRange", "keyTransform", "conditions", "footageLabel", "harmonicRelation", "status", "source", "generatedById", "reviewedById", "sourceLocator", "notes"],
                "processModels": ["id", "processKind", "ordering", "actions", "childProcessIds", "timingConstraintIds", "terminationPolicy", "maximumIterations", "durationConstraintId", "cancellationControlId", "status", "source", "generatedById", "reviewedById", "notes"],
                "timingConstraints": ["id", "timingKind", "unit", "minimum", "typical", "maximum", "uncertainty", "appliesToIds", "status", "source", "generatedById", "reviewedById", "sourceLocator", "notes"],
                "transferFunctions": ["id", "inputKind", "outputKind", "inputUnit", "outputUnit", "interpolation", "points", "monotonic", "appliesToIds", "status", "source", "generatedById", "reviewedById", "sourceLocator", "notes"],
                "renderBindings": ["id", "eventTypeId", "processModelId", "conditions", "sampleMappingIds", "sampleVariantIds", "selectionPolicy", "status", "source", "generatedById", "reviewedById", "notes"],
            ]
            for name in registryNames {
                for (index, record) in records(model, name).enumerated() {
                    rejectUnknown(record, allowed: allowed[name] ?? [], path: "interactionModel.\(name)[\(index)]")
                    if ["transitions", "routingRules", "renderBindings"].contains(name) {
                        checkConditions(record["conditions"], path: "interactionModel.\(name)[\(index)].conditions")
                    }
                    if ["transitions", "processModels"].contains(name) {
                        checkActions(record["actions"], path: "interactionModel.\(name)[\(index)].actions")
                    }
                    if name == "routingRules", let transform = record["keyTransform"] as? [String: Any] {
                        rejectUnknown(transform, allowed: ["kind", "semitoneOffset", "fixedOutputKeys", "entries"], path: "interactionModel.routingRules[\(index)].keyTransform")
                        for (entryIndex, entry) in ((transform["entries"] as? [[String: Any]]) ?? []).enumerated() {
                            rejectUnknown(entry, allowed: ["inputKey", "outputKeys"], path: "interactionModel.routingRules[\(index)].keyTransform.entries[\(entryIndex)]")
                        }
                    }
                    if name == "transferFunctions" {
                        for (pointIndex, point) in ((record["points"] as? [[String: Any]]) ?? []).enumerated() {
                            rejectUnknown(point, allowed: ["input", "output"], path: "interactionModel.transferFunctions[\(index)].points[\(pointIndex)]")
                        }
                    }
                }
            }
        }

        if let capture = root["captureDocumentation"] as? [String: Any] {
            let registryNames: Set<String> = ["captureStates", "eventAlignments", "takeSets", "derivationMaps"]
            rejectUnknown(capture, allowed: registryNames, path: "captureDocumentation")
            let allowed: [String: Set<String>] = [
                "captureStates": ["id", "instrumentEntityId", "labels", "stateAssignments", "capturedAt", "status", "source", "generatedById", "reviewedById", "sourceLocator", "notes"],
                "eventAlignments": ["id", "audioRealizationId", "eventLogRealizationId", "clockBasis", "offset", "driftPPM", "uncertainty", "eventMappings", "status", "source", "generatedById", "reviewedById", "notes"],
                "takeSets": ["id", "captureStateId", "realizationIds", "setRole", "selectionStatus", "status", "source", "generatedById", "reviewedById", "notes"],
                "derivationMaps": ["id", "sourceRealizationId", "derivedRealizationId", "sourceFrameRange", "channelMap", "operations", "status", "source", "generatedById", "reviewedById", "notes"],
            ]
            for name in registryNames {
                for (index, record) in records(capture, name).enumerated() {
                    rejectUnknown(record, allowed: allowed[name] ?? [], path: "captureDocumentation.\(name)[\(index)]")
                    if name == "captureStates" {
                        for (assignmentIndex, assignment) in ((record["stateAssignments"] as? [[String: Any]]) ?? []).enumerated() {
                            rejectUnknown(assignment, allowed: ["stateVariableId", "value"], path: "captureDocumentation.captureStates[\(index)].stateAssignments[\(assignmentIndex)]")
                        }
                    }
                    if name == "eventAlignments" {
                        for (mappingIndex, mapping) in ((record["eventMappings"] as? [[String: Any]]) ?? []).enumerated() {
                            rejectUnknown(mapping, allowed: ["eventLocator", "eventTypeId", "startFrame", "endFrameExclusive"], path: "captureDocumentation.eventAlignments[\(index)].eventMappings[\(mappingIndex)]")
                        }
                    }
                    if name == "derivationMaps" {
                        rejectUnknown(record["sourceFrameRange"], allowed: ["startFrameInclusive", "endFrameExclusive"], path: "captureDocumentation.derivationMaps[\(index)].sourceFrameRange")
                        for (operationIndex, operation) in ((record["operations"] as? [[String: Any]]) ?? []).enumerated() {
                            rejectUnknown(operation, allowed: ["kind", "activityId", "softwareName", "softwareVersion", "parameters"], path: "captureDocumentation.derivationMaps[\(index)].operations[\(operationIndex)]")
                        }
                    }
                }
            }
        }
        return errors
    }

    private static func index<Value>(_ values: [Value], by keyPath: KeyPath<Value, String>) -> [String: Value] {
        var result: [String: Value] = [:]
        for value in values where result[value[keyPath: keyPath]] == nil {
            result[value[keyPath: keyPath]] = value
        }
        return result
    }

    private static func safePayloadPath(_ path: String) -> Bool {
        path.hasPrefix("payload/") && safeMemberPath(path)
    }

    private static func findCycles(groups: [String: VAO03AssetGroup], edges: (VAO03AssetGroup) -> [String], label: String, errors: inout [String]) {
        var visiting = Set<String>()
        var visited = Set<String>()
        func visit(_ id: String) {
            if visiting.contains(id) { errors.append("Asset-group \(label) graph contains a cycle at \(id)."); return }
            if visited.contains(id) { return }
            visiting.insert(id)
            if let group = groups[id] { for target in edges(group) where groups[target] != nil { visit(target) } }
            visiting.remove(id)
            visited.insert(id)
        }
        for id in groups.keys { visit(id) }
    }
}
