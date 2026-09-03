import Foundation

enum VAOExperientialValidator {
    static func validate(manifest: VAOManifest, errors: inout [String], warnings: inout [String]) {
        let profileIDs = Set(manifest.profiles.map(\.id))
        let profileRecords = manifest.profiles.filter { $0.id == VAOContract.experientialProfile }
        let conforms = Set(manifest.conformsTo)

        if conforms.contains(VAOContract.experientialProfile), profileRecords.isEmpty {
            errors.append("The experiential conformsTo claim requires an experiential profile record.")
        }
        guard profileIDs.contains(VAOContract.experientialProfile) else { return }
        guard profileRecords.count == 1 else {
            errors.append("The experiential profile must be declared exactly once.")
            return
        }
        guard conforms.contains(VAOContract.experientialProfile) else {
            errors.append("conformsTo must include the experiential profile URI when that profile is claimed.")
            return
        }

        let declared = Set(profileRecords[0].requiredCapabilities)
        let known = declared.intersection(VAOContract.experientialCapabilities)
        if known.isEmpty {
            errors.append("The experiential profile requires at least one standard experiential capability.")
        }
        for capability in declared.subtracting(VAOContract.experientialCapabilities).sorted() {
            warnings.append("Unsupported required experiential capability: \(capability)")
        }

        let entities = Dictionary(manifest.entities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let assets = Dictionary(manifest.assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let spatialCapabilities: Set<String> = [
            VAOContract.genericModelViewingCapability,
            VAOContract.imageTargetARCapability,
            VAOContract.surfacePlacementARCapability,
            VAOContract.spatialListeningMapCapability,
        ]

        for capability in known.sorted() {
            let experiences = manifest.entities.filter {
                $0.kind == "experience"
                    && $0.properties?[VAOContract.property("experienceCapability")]?.stringValue == capability
            }
            if experiences.isEmpty {
                errors.append("Experiential capability \(capability) has no matching experience entity.")
                continue
            }
            if spatialCapabilities.contains(capability)
                && (!profileIDs.contains(VAOContract.spatialProfile) || !conforms.contains(VAOContract.spatialProfile)) {
                errors.append("Experiential capability \(capability) requires the spatial profile.")
            }
            for experience in experiences {
                validate(experience: experience, capability: capability, manifest: manifest, entities: entities, assets: assets, profileIDs: profileIDs, conforms: conforms, errors: &errors)
            }
        }
    }

    private static func validate(
        experience: VAOEntity,
        capability: String,
        manifest: VAOManifest,
        entities: [String: VAOEntity],
        assets: [String: VAOAsset],
        profileIDs: Set<String>,
        conforms: Set<String>,
        errors: inout [String]
    ) {
        switch capability {
        case VAOContract.genericModelViewingCapability:
            validatePresents(experience, allowedKinds: ["instrument", "spatialRegion"], label: "generic-model-viewing", manifest: manifest, entities: entities, errors: &errors)
            validateModels(experience, label: "generic-model-viewing", manifest: manifest, assets: assets, errors: &errors)

        case VAOContract.synchronizedMediaAnimationCapability:
            validatePresents(experience, allowedKinds: ["instrument"], label: "synchronized-media-animation", manifest: manifest, entities: entities, errors: &errors)
            let performances = activeTargets(experience.id, VAOContract.property("hasPerformance"), in: manifest)
                .compactMap { entities[$0] }
                .filter { $0.kind == "performance" }
            if performances.isEmpty {
                errors.append("Synchronized experience \(experience.id) has no hasPerformance relation to a performance entity.")
            }
            for performance in performances {
                validateSynchronizedPerformance(performance, manifest: manifest, entities: entities, assets: assets, profileIDs: profileIDs, conforms: conforms, errors: &errors)
            }

        case VAOContract.imageTargetARCapability:
            validatePresents(experience, allowedKinds: ["instrument", "spatialRegion"], label: "image-target-ar", manifest: manifest, entities: entities, errors: &errors)
            validateModels(experience, label: "image-target-ar", manifest: manifest, assets: assets, errors: &errors)
            let targets = activeTargets(experience.id, VAOContract.property("usesTarget"), in: manifest)
                .compactMap { assets[$0] }
                .filter { $0.roles.contains(VAOContract.imageTargetRole) && $0.mediaType.hasPrefix("image/") }
            if targets.isEmpty { errors.append("Image-target AR experience \(experience.id) has no image target asset.") }
            for target in targets where !validDimensions(target.properties?[VAOContract.property("physicalDimensions")], depthRequired: false) {
                errors.append("Image target \(target.id) lacks valid physical dimensions.")
            }
            for target in activeTargets(experience.id, VAOContract.property("usesTrackingData"), in: manifest)
            where assets[target]?.roles.contains(VAOContract.trackingDataRole) != true {
                errors.append("Image-target AR experience \(experience.id) has invalid tracking-data target \(target).")
            }

        case VAOContract.surfacePlacementARCapability:
            validatePresents(experience, allowedKinds: ["instrument", "spatialRegion"], label: "surface-placement-ar", manifest: manifest, entities: entities, errors: &errors)
            validateModels(experience, label: "surface-placement-ar", manifest: manifest, assets: assets, errors: &errors)
            guard let policy = experience.properties?[VAOContract.property("placementPolicy")]?.objectValue,
                  Set(policy.keys) == ["surfaceAlignment", "modelAnchor", "allowUniformScale"],
                  ["horizontal", "vertical", "any"].contains(policy["surfaceAlignment"]?.stringValue ?? ""),
                  ["origin", "base-center"].contains(policy["modelAnchor"]?.stringValue ?? ""),
                  policy["allowUniformScale"]?.booleanValue != nil else {
                errors.append("Surface-placement experience \(experience.id) has an invalid placementPolicy.")
                return
            }

        case VAOContract.spatialListeningMapCapability:
            validatePresents(experience, allowedKinds: ["place", "spatialRegion"], label: "spatial-listening-map", manifest: manifest, entities: entities, errors: &errors)
            let points = activeTargets(experience.id, VAOContract.property("hasListeningPoint"), in: manifest)
                .compactMap { entities[$0] }
                .filter { $0.kind == "spatialRegion" }
            if points.isEmpty { errors.append("Spatial-listening experience \(experience.id) has no listening point.") }
            for point in points {
                if !validListeningPoint(point) { errors.append("Listening point \(point.id) lacks valid coordinate/position metadata.") }
                let audio = activeTargets(point.id, VAOContract.property("usesMedia"), in: manifest)
                    .compactMap { assets[$0] }
                    .filter { $0.roles.contains(VAOContract.spatialListeningAudioRole) && $0.mediaType.hasPrefix("audio/") }
                if audio.isEmpty { errors.append("Listening point \(point.id) has no spatial-listening audio asset.") }
            }

        case VAOContract.offlineAssetGroupsCapability:
            validatePresents(experience, allowedKinds: ["instrument"], label: "offline-asset-groups", manifest: manifest, entities: entities, errors: &errors)
            let groups = activeTargets(experience.id, VAOContract.property("offersAssetGroup"), in: manifest)
                .compactMap { entities[$0] }
                .filter { $0.kind == "assetGroup" }
            if groups.isEmpty { errors.append("Offline experience \(experience.id) has no asset group.") }
            for group in groups {
                if !validAssetGroupPolicy(group.properties?[VAOContract.property("assetGroupPolicy")]) {
                    errors.append("Asset group \(group.id) has an invalid assetGroupPolicy.")
                }
                let members = activeTargets(group.id, VAOContract.property("includesAsset"), in: manifest)
                if members.isEmpty { errors.append("Asset group \(group.id) includes no assets.") }
                for member in members where assets[member] == nil { errors.append("Asset group \(group.id) includes non-asset target \(member).") }
            }

        case VAOContract.replaceablePerformanceMediaCapability:
            validateReplaceableMedia(experience, manifest: manifest, entities: entities, assets: assets, errors: &errors)

        default:
            break
        }
    }

    private static func validateSynchronizedPerformance(
        _ performance: VAOEntity,
        manifest: VAOManifest,
        entities: [String: VAOEntity],
        assets: [String: VAOAsset],
        profileIDs: Set<String>,
        conforms: Set<String>,
        errors: inout [String]
    ) {
        if !validTimelineClock(performance.properties?[VAOContract.property("timelineClock")]) {
            errors.append("Performance \(performance.id) has an invalid timelineClock.")
        }
        let media = activeTargets(performance.id, VAOContract.property("usesMedia"), in: manifest)
            .compactMap { assets[$0] }
            .filter { $0.roles.contains(VAOContract.performanceMediaRole) && ($0.mediaType.hasPrefix("audio/") || $0.mediaType.hasPrefix("video/")) }
        if media.isEmpty { errors.append("Performance \(performance.id) has no usesMedia relation to performance media.") }
        let animations = activeTargets(performance.id, VAOContract.property("drivesAnimation"), in: manifest)
            .compactMap { assets[$0] }
            .filter { $0.roles.contains(VAOContract.animationRole) }
        if animations.isEmpty { errors.append("Performance \(performance.id) has no drivesAnimation relation to an animation asset.") }
        let triggers = activeTargets(performance.id, VAOContract.property("triggeredBy"), in: manifest)
        if !triggers.isEmpty {
            if !profileIDs.contains(VAOContract.playableProfile) || !conforms.contains(VAOContract.playableProfile) {
                errors.append("Triggered performance \(performance.id) requires the playable profile.")
            }
            for target in triggers where entities[target]?.kind != "interaction" {
                errors.append("Performance \(performance.id) has triggeredBy target that is not an interaction.")
            }
        }
    }

    private static func validateReplaceableMedia(
        _ experience: VAOEntity,
        manifest: VAOManifest,
        entities: [String: VAOEntity],
        assets: [String: VAOAsset],
        errors: inout [String]
    ) {
        validatePresents(experience, allowedKinds: ["instrument"], label: "replaceable-performance-media", manifest: manifest, entities: entities, errors: &errors)
        if experience.properties?[VAOContract.property("selectionPolicy")]?.stringValue != "exclusive" {
            errors.append("Replaceable-media experience \(experience.id) must use exclusive selection.")
        }
        let configurations = activeTargets(experience.id, VAOContract.property("offersConfiguration"), in: manifest)
            .compactMap { entities[$0] }
            .filter { $0.kind == "configuration" }
        if configurations.count < 2 { errors.append("Replaceable-media experience \(experience.id) requires at least two configurations.") }

        var carrierIDs: [String] = []
        var performanceIDs = Set<String>()
        for configuration in configurations {
            let carriers = activeTargets(configuration.id, VAOContract.property("usesCarrier"), in: manifest)
                .filter { entities[$0]?.kind == "digitalObject" }
            if carriers.count != 1 {
                errors.append("Replaceable-media configuration \(configuration.id) must use exactly one carrier.")
                continue
            }
            let carrierID = carriers[0]
            carrierIDs.append(carrierID)
            let labels = activeTargets(carrierID, VAOContract.property("hasLabelImage"), in: manifest)
                .compactMap { assets[$0] }
                .filter { $0.roles.contains(VAOContract.carrierLabelImageRole) && $0.mediaType.hasPrefix("image/") }
            if labels.isEmpty { errors.append("Replaceable-media carrier \(carrierID) has no label image.") }
            let performances = activeTargets(carrierID, VAOContract.property("hasPerformance"), in: manifest)
                .filter { entities[$0]?.kind == "performance" }
            if performances.isEmpty { errors.append("Replaceable-media carrier \(carrierID) has no performance.") }
            performanceIDs.formUnion(performances)
        }
        if carrierIDs.count != Set(carrierIDs).count { errors.append("Replaceable-media configurations must resolve distinct carriers.") }

        for performanceID in performanceIDs.sorted() {
            guard let performance = entities[performanceID] else { continue }
            if !validTimelineClock(performance.properties?[VAOContract.property("timelineClock")]) {
                errors.append("Replaceable-media performance \(performanceID) has an invalid timelineClock.")
            }
            if !validTransportPolicy(performance.properties?[VAOContract.property("transportPolicy")]) {
                errors.append("Replaceable-media performance \(performanceID) has an invalid transportPolicy.")
            }
            let media = activeTargets(performanceID, VAOContract.property("usesMedia"), in: manifest)
                .compactMap { assets[$0] }
                .filter { $0.roles.contains(VAOContract.performanceMediaRole) && $0.mediaType.hasPrefix("audio/") }
            if media.isEmpty { errors.append("Replaceable-media performance \(performanceID) has no audio master media.") }
            let targetIDs = Set(activeTargets(performanceID, VAOContract.property("targets"), in: manifest))
            if targetIDs.isEmpty || targetIDs.contains(where: { entities[$0] == nil }) {
                errors.append("Replaceable-media performance \(performanceID) has invalid target entities.")
            }
            let animations = activeTargets(performanceID, VAOContract.property("drivesAnimation"), in: manifest)
                .compactMap { assets[$0] }
                .filter { $0.roles.contains(VAOContract.animationRole) }
            if animations.isEmpty { errors.append("Replaceable-media performance \(performanceID) has no animation asset.") }
            for animation in animations where !validAnimationBindings(animation.properties?[VAOContract.property("animationBindings")], targetIDs: targetIDs, entities: entities) {
                errors.append("Replaceable-media animation \(animation.id) has invalid animationBindings.")
            }
        }

        let interactions = activeTargets(experience.id, VAOContract.property("hasInteraction"), in: manifest)
            .compactMap { entities[$0] }
            .filter { $0.kind == "interaction" }
        if interactions.isEmpty { errors.append("Replaceable-media experience \(experience.id) has no declarative interaction.") }
        let allowed: Set<String> = ["select", "install", "eject", "play", "pause", "stop", "seek", "restart"]
        let required: Set<String> = ["select", "install", "eject", "play", "stop"]
        let targetKinds: [String: Set<String>] = [
            "select": ["configuration"], "install": ["digitalObject"], "eject": ["digitalObject"],
            "play": ["performance"], "pause": ["performance"], "stop": ["performance"],
            "seek": ["performance"], "restart": ["performance"],
        ]
        var found = Set<String>()
        for interaction in interactions {
            guard let sequence = interaction.properties?[VAOContract.property("actionSequence")]?.arrayValue, !sequence.isEmpty else {
                errors.append("Replaceable-media interaction \(interaction.id) has no actionSequence.")
                continue
            }
            for step in sequence {
                guard let record = step.objectValue,
                      Set(record.keys) == ["action", "targetId"],
                      let action = record["action"]?.stringValue,
                      allowed.contains(action),
                      let target = record["targetId"]?.stringValue,
                      let target = entities[target],
                      targetKinds[action]?.contains(target.kind) == true else {
                    errors.append("Replaceable-media interaction \(interaction.id) has a prohibited or invalid action.")
                    continue
                }
                found.insert(action)
            }
        }
        if !required.isSubset(of: found) {
            errors.append("Replaceable-media action sequences are missing required actions: \(required.subtracting(found).sorted().joined(separator: ", ")).")
        }
    }

    private static func validatePresents(_ experience: VAOEntity, allowedKinds: Set<String>, label: String, manifest: VAOManifest, entities: [String: VAOEntity], errors: inout [String]) {
        let valid = activeTargets(experience.id, VAOContract.property("presents"), in: manifest).contains { target in
            entities[target].map { allowedKinds.contains($0.kind) } == true
        }
        if !valid { errors.append("Experiential \(label) experience \(experience.id) has no valid presents relation.") }
    }

    private static func validateModels(_ experience: VAOEntity, label: String, manifest: VAOManifest, assets: [String: VAOAsset], errors: inout [String]) {
        let models = activeTargets(experience.id, VAOContract.property("usesModel"), in: manifest)
            .compactMap { assets[$0] }
            .filter { !Set($0.roles).isDisjoint(with: [VAOContract.threeDimensionalModelRole, VAOContract.spatialModelRole]) }
        if models.isEmpty { errors.append("Experiential \(label) experience \(experience.id) has no usesModel relation to a model asset.") }
        for model in models where !validCoordinateMetadata(model) {
            errors.append("Experiential model asset \(model.id) lacks valid coordinates or physical dimensions.")
        }
    }

    private static func activeTargets(_ subject: String, _ predicate: String, in manifest: VAOManifest) -> [String] {
        manifest.relations.compactMap { relation in
            guard relation.subjectId == subject,
                  relation.predicate == predicate,
                  relation.status != "rejected",
                  relation.status != "superseded" else { return nil }
            return relation.objectId
        }
    }

    private static func validCoordinateMetadata(_ asset: VAOAsset) -> Bool {
        guard let properties = asset.properties,
              properties[VAOContract.property("coordinateSystem")]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              isIRI(properties[VAOContract.property("coordinateUnit")]?.stringValue),
              ["left", "right"].contains(properties[VAOContract.property("handedness")]?.stringValue ?? ""),
              ["X", "Y", "Z"].contains(properties[VAOContract.property("upAxis")]?.stringValue ?? "") else { return false }
        return validDimensions(properties[VAOContract.property("physicalDimensions")], depthRequired: true)
    }

    private static func validDimensions(_ value: VAOJSONValue?, depthRequired: Bool) -> Bool {
        guard let object = value?.objectValue, isIRI(object["unit"]?.stringValue) else { return false }
        let names = depthRequired ? ["width", "height", "depth"] : ["width", "height"]
        return names.allSatisfy { (object[$0]?.numberValue ?? 0) > 0 }
    }

    private static func validTimelineClock(_ value: VAOJSONValue?) -> Bool {
        guard let clock = value?.objectValue,
              isIRI(clock["timeUnit"]?.stringValue),
              let duration = clock["duration"]?.numberValue,
              duration.isFinite, duration > 0 else { return false }
        if let offset = clock["offset"]?.numberValue { return offset.isFinite && offset >= 0 }
        return clock["offset"] == nil
    }

    private static func validListeningPoint(_ point: VAOEntity) -> Bool {
        guard let properties = point.properties,
              properties[VAOContract.property("coordinateSystem")]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              let unit = properties[VAOContract.property("coordinateUnit")]?.stringValue,
              isIRI(unit),
              ["left", "right"].contains(properties[VAOContract.property("handedness")]?.stringValue ?? ""),
              ["X", "Y", "Z"].contains(properties[VAOContract.property("upAxis")]?.stringValue ?? ""),
              let position = properties[VAOContract.property("position")]?.objectValue,
              position["unit"]?.stringValue == unit else { return false }
        return ["x", "y", "z"].allSatisfy { position[$0]?.numberValue?.isFinite == true }
    }

    private static func validAssetGroupPolicy(_ value: VAOJSONValue?) -> Bool {
        guard let policy = value?.objectValue,
              ["offline-optional", "offline-required"].contains(policy["availability"]?.stringValue ?? ""),
              ["independent", "exclusive"].contains(policy["selection"]?.stringValue ?? ""),
              policy["defaultSelected"]?.booleanValue != nil else { return false }
        return true
    }

    private static func validTransportPolicy(_ value: VAOJSONValue?) -> Bool {
        guard let policy = value?.objectValue,
              Set(policy.keys) == ["masterClock", "start", "pause", "stop", "seek"] else { return false }
        return policy["masterClock"]?.stringValue == "audio"
            && policy["start"]?.stringValue == "explicit"
            && policy["pause"]?.stringValue == "hold"
            && policy["stop"]?.stringValue == "reset"
            && ["allowed", "forbidden"].contains(policy["seek"]?.stringValue ?? "")
    }

    private static func validAnimationBindings(_ value: VAOJSONValue?, targetIDs: Set<String>, entities: [String: VAOEntity]) -> Bool {
        guard let bindings = value?.objectValue,
              Set(bindings.keys) == ["blendPolicy", "layers"],
              ["parallel", "ordered"].contains(bindings["blendPolicy"]?.stringValue ?? ""),
              let layers = bindings["layers"]?.arrayValue,
              !layers.isEmpty else { return false }
        return layers.allSatisfy { layer in
            guard let record = layer.objectValue,
                  Set(record.keys) == ["clip", "targetEntityIds"],
                  record["clip"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                  let targets = record["targetEntityIds"]?.arrayValue,
                  !targets.isEmpty else { return false }
            return targets.allSatisfy { value in
                guard let id = value.stringValue else { return false }
                return entities[id] != nil && targetIDs.contains(id) && isIRI(id)
            }
        }
    }

    private static func isIRI(_ value: String?) -> Bool {
        guard let value,
              value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              URLComponents(string: value)?.scheme?.isEmpty == false else { return false }
        return true
    }
}
