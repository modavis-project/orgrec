import Foundation

/// Cross-registry validation for the closed VAO 0.3.3 visual-acoustic scene model.
/// JSON Schema owns record shape; this layer owns reference closure, coordinate
/// algebra, pose/measurement agreement, realization indexing, and capability truth.
enum VAO03AcousticsValidator {
    private static let collectionNames = [
        "coordinateFrames", "poses", "geometryBindings", "materialModels", "measurements",
        "responseSets", "metricSets", "audioScenes", "renderConfigurations",
    ]
    private static let capabilityBase = "https://w3id.org/modavis/vao/vocab/capability/"
    private static let semanticBuilding = capabilityBase + "semantic-building-model"
    private static let measuredIR = capabilityBase + "measured-impulse-response"
    private static let simulatedIR = capabilityBase + "simulated-impulse-response"
    private static let registeredScene = capabilityBase + "position-registered-acoustic-scene"
    private static let visualScene = capabilityBase + "visual-acoustic-scene"
    private static let responseField = capabilityBase + "spatial-response-field"
    private static let spatialAudioScene = capabilityBase + "spatial-audio-scene"
    private static let standardCapabilities: Set<String> = [
        semanticBuilding, measuredIR, simulatedIR, registeredScene, visualScene, responseField,
        spatialAudioScene, capabilityBase + "source-directivity", capabilityBase + "room-acoustic-metrics",
        capabilityBase + "building-acoustic-performance", capabilityBase + "tracked-listener-convolution",
        capabilityBase + "tracked-sources", capabilityBase + "geometry-acoustic-rendering",
        capabilityBase + "hybrid-acoustic-rendering", capabilityBase + "learned-acoustic-field",
    ]

    static func identifiers(in acoustics: VAOJSONValue?) -> [String] {
        guard let acoustics = acoustics?.objectValue else { return [] }
        return collectionNames.flatMap { name in
            acoustics[name]?.arrayValue?.compactMap { $0.objectValue?["id"]?.stringValue } ?? []
        }
    }

    static func validate(
        manifest: VAO03Manifest,
        entities: [String: VAO03Entity],
        assets: [String: VAO03LogicalAsset],
        realizations: [String: VAO03Realization],
        errors: inout [String]
    ) {
        let profileRecords: [(String, [String])] = manifest.profiles.map { ($0.id, $0.requiredCapabilities) }
            + manifest.materializableProfiles.map { ($0.id, $0.requiredCapabilities) }
        let profileIDs = Set(profileRecords.map(\.0))
        let declaredCapabilities = Set(profileRecords.filter { $0.0 == VAO03Contract.acousticsProfile }.flatMap(\.1))
        guard let acoustics = manifest.acoustics?.objectValue else {
            if profileIDs.contains(VAO03Contract.spatialProfile) || profileIDs.contains(VAO03Contract.acousticsProfile) {
                errors.append("The Spatial/Acoustics 0.3 profile requires the closed top-level acoustics object.")
            }
            return
        }
        if profileIDs.contains(VAO03Contract.acousticsProfile) {
            if !profileIDs.contains(VAO03Contract.spatialProfile) {
                errors.append("The Acoustics 0.3 profile requires the Spatial 0.3 profile.")
            }
            if declaredCapabilities.isDisjoint(with: standardCapabilities) {
                errors.append("The Acoustics 0.3 profile requires a standard acoustic capability.")
            }
        }

        func objects(_ name: String) -> [[String: VAOJSONValue]] {
            acoustics[name]?.arrayValue?.compactMap(\.objectValue) ?? []
        }
        func firstValues(_ records: [[String: VAOJSONValue]]) -> [String: [String: VAOJSONValue]] {
            var result: [String: [String: VAOJSONValue]] = [:]
            for record in records {
                if let id = record["id"]?.stringValue, result[id] == nil { result[id] = record }
            }
            return result
        }
        func strings(_ value: VAOJSONValue?) -> [String] {
            value?.arrayValue?.compactMap(\.stringValue) ?? []
        }
        func numbers(_ value: VAOJSONValue?) -> [Double] {
            value?.arrayValue?.compactMap(\.numberValue) ?? []
        }
        let frames = firstValues(objects("coordinateFrames"))
        let poses = firstValues(objects("poses"))
        let bindings = firstValues(objects("geometryBindings"))
        let materials = firstValues(objects("materialModels"))
        let measurements = firstValues(objects("measurements"))
        let responses = firstValues(objects("responseSets"))
        let scenes = firstValues(objects("audioScenes"))
        let renderers = firstValues(objects("renderConfigurations"))
        let activityIDs = Set((manifest.paradata + manifest.analyses).compactMap { $0.objectValue?["id"]?.stringValue })

        var parentEdges: [String: [String]] = [:]
        for (id, frame) in frames {
            if let parent = frame["parentFrameId"]?.stringValue {
                parentEdges[id] = [parent]
                if frames[parent] == nil { errors.append("Coordinate frame \(id) has unresolved parentFrameId.") }
                if !invertible(numbers(frame["transformToParent"])) { errors.append("Coordinate frame \(id) requires an invertible transformToParent.") }
            } else {
                parentEdges[id] = []
            }
            let up = frame["upAxis"]?.stringValue ?? "not-applicable"
            let forward = frame["forwardAxis"]?.stringValue ?? "not-applicable"
            if up != "not-applicable", forward != "not-applicable", up.last == forward.last {
                errors.append("Coordinate frame \(id) cannot use the same axis for up and forward.")
            }
            if let generated = frame["generatedById"]?.stringValue, !activityIDs.contains(generated) {
                errors.append("Coordinate frame \(id) has unresolved generatedById.")
            }
        }
        findCycles(records: frames, edges: parentEdges, label: "Coordinate-frame", errors: &errors)

        func frameRoot(_ frameID: String?) -> String? {
            guard var current = frameID, frames[current] != nil else { return nil }
            var seen = Set<String>()
            while frames[current] != nil, seen.insert(current).inserted {
                guard let parent = frames[current]?["parentFrameId"]?.stringValue else { return current }
                current = parent
            }
            return nil
        }

        for (id, pose) in poses {
            if entities[pose["subjectId"]?.stringValue ?? ""] == nil { errors.append("Pose \(id) has unresolved subjectId.") }
            let frameID = pose["frameId"]?.stringValue ?? ""
            guard let frame = frames[frameID] else { errors.append("Pose \(id) has unresolved frameId."); continue }
            let dimension = Int(frame["dimension"]?.numberValue ?? -1)
            if numbers(pose["position"]).count != dimension { errors.append("Pose \(id) position dimension does not match its frame.") }
            if let quaternion = pose["orientationXYZW"] {
                let values = numbers(quaternion)
                let norm = values.reduce(0) { $0 + $1 * $1 }
                if values.count != 4 || abs(norm - 1) > 1e-6 { errors.append("Pose \(id) orientationXYZW must be a normalized XYZW quaternion.") }
            }
            if let trajectory = pose["trajectoryAssetId"]?.stringValue, assets[trajectory] == nil { errors.append("Pose \(id) has unresolved trajectoryAssetId.") }
        }

        var geometryRoots = Set<String>()
        for (id, binding) in bindings {
            if entities[binding["subjectId"]?.stringValue ?? ""] == nil { errors.append("Geometry binding \(id) has unresolved subjectId.") }
            guard let asset = assets[binding["logicalAssetId"]?.stringValue ?? ""] else { errors.append("Geometry binding \(id) has unresolved logicalAssetId."); continue }
            if !asset.roles.contains(where: { $0.hasSuffix("/spatial-model") || $0.hasSuffix("/three-dimensional-model") }) {
                errors.append("Geometry binding \(id) requires a spatial-model logical asset role.")
            }
            let geometry = asset.realizationIds.compactMap { realizations[$0] }.filter { $0.technicalMetadata.kind == "geometry" }
            if geometry.isEmpty { errors.append("Geometry binding \(id) has no geometry realization.") }
            for realization in geometry {
                if let root = frameRoot(realization.technicalMetadata.coordinateFrameId) { geometryRoots.insert(root) }
            }
            if let selector = binding["selector"]?.objectValue, selector["selectorType"]?.stringValue == "gltf-node-index" {
                if selector["value"]?.integerValue == nil { errors.append("Geometry binding \(id) requires an integer glTF node index.") }
                if !geometry.contains(where: { ["model/gltf+json", "model/gltf-binary"].contains($0.mediaType) }) {
                    errors.append("Geometry binding \(id) uses a glTF selector without a glTF realization.")
                }
            }
        }

        var measurementRoots = Set<String>()
        for (id, measurement) in measurements {
            let sourceID = measurement["sourceId"]?.stringValue ?? ""
            let receiverID = measurement["receiverId"]?.stringValue ?? ""
            for key in ["sourceId", "receiverId", "spaceId", "sourceSpaceId", "receivingSpaceId", "separatingElementId", "configurationId", "stateId"] {
                if let reference = measurement[key]?.stringValue, entities[reference] == nil { errors.append("Measurement \(id) has unresolved \(key).") }
            }
            let sourcePose = poses[measurement["sourcePoseId"]?.stringValue ?? ""]
            let receiverPose = poses[measurement["receiverPoseId"]?.stringValue ?? ""]
            if sourcePose == nil { errors.append("Measurement \(id) has unresolved sourcePoseId.") }
            else if sourcePose?["subjectId"]?.stringValue != sourceID { errors.append("Measurement \(id) sourcePoseId does not describe sourceId.") }
            if receiverPose == nil { errors.append("Measurement \(id) has unresolved receiverPoseId.") }
            else if receiverPose?["subjectId"]?.stringValue != receiverID { errors.append("Measurement \(id) receiverPoseId does not describe receiverId.") }
            let roots = Set([frameRoot(sourcePose?["frameId"]?.stringValue), frameRoot(receiverPose?["frameId"]?.stringValue)].compactMap { $0 })
            if roots.count > 1 { errors.append("Measurement \(id) poses are not transformable to a common frame.") }
            measurementRoots.formUnion(roots)
        }

        for (id, response) in responses {
            if entities[response["responseEntityId"]?.stringValue ?? ""] == nil { errors.append("Response set \(id) has unresolved responseEntityId.") }
            guard let asset = assets[response["logicalAssetId"]?.stringValue ?? ""] else { errors.append("Response set \(id) has unresolved logicalAssetId."); continue }
            if !asset.roles.contains(where: { $0.hasSuffix("/impulse-response") }) { errors.append("Response set \(id) requires an impulse-response logical asset role.") }
            let expected = Set(strings(response["measurementIds"]))
            for measurement in expected where measurements[measurement] == nil { errors.append("Response set \(id) has unresolved measurement \(measurement).") }
            if !activityIDs.contains(response["generatedById"]?.stringValue ?? "") { errors.append("Response set \(id) has unresolved generatedById.") }
            for realization in asset.realizationIds.compactMap({ realizations[$0] }) {
                guard realization.technicalMetadata.kind == "audio", let impulse = realization.technicalMetadata.impulseResponse?.objectValue else {
                    errors.append("Response-set realization \(realization.id) requires typed impulseResponse audio metadata.")
                    continue
                }
                if impulse["responseSetId"]?.stringValue != id { errors.append("Response-set realization \(realization.id) has the wrong responseSetId.") }
                let mappings = impulse["measurementMappings"]?.arrayValue?.compactMap(\.objectValue) ?? []
                let mapped = mappings.compactMap { $0["measurementId"]?.stringValue }
                if mapped.count != Set(mapped).count || Set(mapped) != expected { errors.append("Response-set realization \(realization.id) must map every response measurement exactly once.") }
                let indices = mappings.compactMap { $0["dataIRIndex"]?.integerValue }
                if indices.count != Set(indices).count { errors.append("Response-set realization \(realization.id) repeats a dataIRIndex.") }
                if let channels = realization.technicalMetadata.channelCount, mappings.contains(where: { mapping in
                    (mapping["channelIndices"]?.arrayValue?.compactMap(\.integerValue) ?? []).contains(where: { $0 >= Int64(channels) })
                }) { errors.append("Response-set realization \(realization.id) maps a channel outside channelCount.") }
                if ["WAV", "FLAC"].contains(impulse["encoding"]?.stringValue ?? ""), mappings.count != 1 { errors.append("WAV/FLAC realization \(realization.id) is limited to one fixed measurement.") }
                if let status = response["representationStatus"]?.stringValue, !realization.representationStatus.hasSuffix("/\(status)") { errors.append("Response-set realization \(realization.id) representation status disagrees with its response set.") }
            }
        }

        for (id, material) in materials {
            if entities[material["materialEntityId"]?.stringValue ?? ""] == nil { errors.append("Material model \(id) has unresolved materialEntityId.") }
            let bandCount = numbers(material["bandAxis"]?.objectValue?["centerFrequenciesHz"]).count
            for key in ["absorption", "scattering", "transmissionLossDB"] where material[key] != nil && numbers(material[key]).count != bandCount {
                errors.append("Material model \(id) \(key) length must match its frequency axis.")
            }
        }

        for (id, scene) in scenes {
            if entities[scene["sceneEntityId"]?.stringValue ?? ""] == nil { errors.append("Audio scene \(id) has unresolved sceneEntityId.") }
            if frames[scene["coordinateFrameId"]?.stringValue ?? ""] == nil { errors.append("Audio scene \(id) has unresolved coordinateFrameId.") }
            for assetID in strings(scene["mediaAssetIds"]) where assets[assetID] == nil { errors.append("Audio scene \(id) has unresolved mediaAssetId.") }
        }
        for (id, renderer) in renderers {
            if scenes[renderer["sceneId"]?.stringValue ?? ""] == nil { errors.append("Render configuration \(id) has unresolved sceneId.") }
            if frames[renderer["coordinateFrameId"]?.stringValue ?? ""] == nil { errors.append("Render configuration \(id) has unresolved coordinateFrameId.") }
            if renderer["outsideDomainPolicy"]?.stringValue == "fallback", strings(renderer["fallbackIds"]).isEmpty { errors.append("Render configuration \(id) selects fallback without a fallback.") }
        }

        if !declaredCapabilities.isDisjoint(with: Set([registeredScene, visualScene])), measurements.isEmpty { errors.append("A position-registered acoustic scene requires measurements.") }
        if declaredCapabilities.contains(registeredScene), measurementRoots.isEmpty { errors.append("The position-registered-acoustic-scene capability requires resolvable pose frames.") }
        if declaredCapabilities.contains(visualScene) {
            if bindings.isEmpty || responses.isEmpty { errors.append("The visual-acoustic-scene capability requires geometry and response sets.") }
            else if geometryRoots.isDisjoint(with: measurementRoots) { errors.append("The visual-acoustic-scene capability requires a common coordinate frame.") }
        }
        if declaredCapabilities.contains(measuredIR), !responses.values.contains(where: { $0["representationStatus"]?.stringValue == "measured" }) { errors.append("The measured-impulse-response capability requires measured data.") }
        if declaredCapabilities.contains(simulatedIR), !responses.values.contains(where: { ["simulated", "hybrid"].contains($0["representationStatus"]?.stringValue ?? "") }) { errors.append("The simulated-impulse-response capability requires simulated or hybrid data.") }
        if declaredCapabilities.contains(responseField), !responses.values.contains(where: { $0["interpolation"] != nil }) { errors.append("The spatial-response-field capability requires interpolation.") }
        if declaredCapabilities.contains(spatialAudioScene), scenes.isEmpty { errors.append("The spatial-audio-scene capability requires an audio scene.") }
        if declaredCapabilities.contains(semanticBuilding) {
            let kinds = Set(entities.values.map(\.kind))
            if !Set(["building", "space", "boundary"]).isSubset(of: kinds) || !bindings.values.contains(where: { $0["role"]?.stringValue == "authoritative-semantic" }) {
                errors.append("The semantic-building-model capability is incomplete.")
            }
        }
    }

    private static func invertible(_ values: [Double]) -> Bool {
        guard values.count == 16, values.allSatisfy(\.isFinite) else { return false }
        var matrix = (0..<4).map { row in Array(values[(row * 4)..<(row * 4 + 4)]) }
        for column in 0..<4 {
            guard let pivot = (column..<4).max(by: { abs(matrix[$0][column]) < abs(matrix[$1][column]) }), abs(matrix[pivot][column]) >= 1e-12 else { return false }
            matrix.swapAt(column, pivot)
            for row in (column + 1)..<4 {
                let scale = matrix[row][column] / matrix[column][column]
                for item in column..<4 { matrix[row][item] -= scale * matrix[column][item] }
            }
        }
        return true
    }

    private static func findCycles(
        records: [String: [String: VAOJSONValue]], edges: [String: [String]], label: String, errors: inout [String]
    ) {
        var visiting = Set<String>()
        var visited = Set<String>()
        func visit(_ id: String) {
            if visiting.contains(id) { errors.append("\(label) graph contains a cycle at \(id)."); return }
            if visited.contains(id) { return }
            visiting.insert(id)
            for target in edges[id] ?? [] where records[target] != nil { visit(target) }
            visiting.remove(id)
            visited.insert(id)
        }
        for id in records.keys { visit(id) }
    }
}
