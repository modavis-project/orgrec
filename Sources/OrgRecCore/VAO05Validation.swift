import Foundation

public enum VAO05Validator {
    private static let rootProperties: Set<String> = [
        "$schema", "@context", "type", "formatVersion", "id", "release", "createdAt", "modifiedAt",
        "title", "description", "conformsTo", "profiles", "materializableProfiles", "modavisBinding",
        "primaryEntityId", "focusEntityIds", "entities", "relations", "scientific", "multimodal",
        "physicalSystem", "runtime", "discovery", "acoustics", "playable", "interactionModel",
        "captureDocumentation", "logicalAssets", "realizations", "distributions", "repositoryBindings",
        "assetGroups", "rights", "integrity", "extensions",
    ]

    public static func validateManifest(data: Data) -> [String] {
        let manifest: VAO05Manifest
        do {
            manifest = try VAOFormatDispatcher.decode05(data)
        } catch {
            return ["VAO 0.5.0 manifest cannot be decoded: \(error.localizedDescription)"]
        }
        var errors = validateManifest(manifest)
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            errors.append("VAO 0.5.0 manifest is not a JSON object.")
            return Array(Set(errors)).sorted()
        }
        for key in Set(root.keys).subtracting(rootProperties).sorted() {
            errors.append("Manifest contains unknown root property \(key).")
        }
        return Array(Set(errors)).sorted()
    }

    public static func validateManifest(_ manifest: VAO05Manifest) -> [String] {
        var errors: [String] = []
        if manifest.schema != VAO05Contract.schemaURI { errors.append("Manifest uses the wrong immutable VAO 0.5.0 schema IRI.") }
        if manifest.context.first != VAO05Contract.contextURI { errors.append("The immutable VAO 0.5.0 context IRI must be first.") }
        if manifest.formatVersion != VAO05Contract.formatVersion { errors.append("Manifest formatVersion must be 0.5.0.") }
        if manifest.type != "VirtualAcousticObject" { errors.append("Manifest type must be VirtualAcousticObject.") }

        let profileIDs = Set(manifest.profiles.map(\.id))
        let claims = Set(manifest.conformsTo)
        for profile in [VAO05Contract.coreProfile, VAO05Contract.dynamicDeliveryProfile]
        where !profileIDs.contains(profile) || !claims.contains(profile) {
            errors.append("Every VAO 0.5.0 release must embed and claim \(profile).")
        }
        for profile in manifest.profiles where profile.version != VAO05Contract.formatVersion {
            errors.append("Profile \(profile.id) has a non-0.5.0 version.")
        }

        let entityIDs = Set(manifest.entities.map(\.id))
        if !entityIDs.contains(manifest.primaryEntityId) { errors.append("primaryEntityId does not resolve to an Entity.") }
        for id in manifest.focusEntityIds where !entityIDs.contains(id) { errors.append("focusEntityId \(id) does not resolve to an Entity.") }

        let logicalAssetIDs = Set(manifest.logicalAssets.map(\.id))
        let realizationIDs = Set(manifest.realizations.map(\.id))
        let groupIDs = Set(manifest.assetGroups.map(\.id))
        let rightsIDs = Set(manifest.rights.map(\.id))
        let declaredIDs = [
            manifest.entities.map(\.id), manifest.logicalAssets.map(\.id), manifest.realizations.map(\.id),
            manifest.assetGroups.map(\.id), manifest.rights.map(\.id), [manifest.id, manifest.release.id],
        ].flatMap { $0 }
        if Set(declaredIDs).count != declaredIDs.count { errors.append("Declared identifiers are not globally unique.") }

        for asset in manifest.logicalAssets {
            for id in asset.aboutEntityIds where !entityIDs.contains(id) { errors.append("Logical asset \(asset.id) has unresolved subject \(id).") }
            for id in asset.realizationIds where !realizationIDs.contains(id) { errors.append("Logical asset \(asset.id) has unresolved realization \(id).") }
        }
        for realization in manifest.realizations {
            if !logicalAssetIDs.contains(realization.assetId) { errors.append("Realization \(realization.id) has unresolved assetId.") }
            if realization.byteSize < 0 { errors.append("Realization \(realization.id) has a negative byteSize.") }
            if !isSHA256(realization.sha256) { errors.append("Realization \(realization.id) has an invalid SHA-256.") }
            for id in realization.rightsIds where !rightsIDs.contains(id) { errors.append("Realization \(realization.id) has unresolved rights \(id).") }
            if let digest = realization.contentDigests?.first(where: { $0.algorithm == "sha256" }), digest.value != realization.sha256 {
                errors.append("Realization \(realization.id) has conflicting SHA-256 identities.")
            }
        }
        let realizationByID = Dictionary(manifest.realizations.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for group in manifest.assetGroups {
            for id in group.realizationIds where realizationByID[id] == nil { errors.append("Asset group \(group.id) has unresolved realization \(id).") }
            for id in group.dependsOnGroupIds where !groupIDs.contains(id) { errors.append("Asset group \(group.id) has unresolved dependency \(id).") }
            var total: Int64 = 0
            var overflow = false
            for size in group.realizationIds.compactMap({ realizationByID[$0]?.byteSize }) {
                let result = total.addingReportingOverflow(size)
                total = result.partialValue
                overflow = overflow || result.overflow
            }
            if overflow || total != group.totalByteSize { errors.append("Asset group \(group.id) totalByteSize is inconsistent.") }
        }

        let requiredRights = Set([manifest.id] + manifest.logicalAssets.map(\.id) + manifest.realizations.map(\.id))
        let coveredRights = Set(manifest.rights.flatMap(\.appliesToIds))
        for id in requiredRights.subtracting(coveredRights).sorted() { errors.append("No rights record covers \(id).") }

        if manifest.scientific.objectValue == nil { errors.append("scientific must be a closed registry object.") }
        if manifest.multimodal.objectValue == nil { errors.append("multimodal must be a closed registry object.") }
        if manifest.physicalSystem.objectValue == nil { errors.append("physicalSystem must be a closed registry object.") }
        if manifest.runtime.objectValue == nil { errors.append("runtime must be a closed registry object.") }
        if manifest.discovery.objectValue == nil { errors.append("discovery must be a closed registry object.") }
        if manifest.integrity.objectValue == nil { errors.append("integrity must be an object.") }
        return Array(Set(errors)).sorted()
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    }
}
