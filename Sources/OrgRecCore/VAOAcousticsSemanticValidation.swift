import Foundation

/// Cross-record VAO 0.2 acoustic validation. JSON Schema owns record shape;
/// this layer owns references, coordinate algebra, array alignment, provenance,
/// capability contracts, and safe runtime degradation.
enum VAOAcousticsSemanticValidator {
    private static let collectionNames = [
        "coordinateFrames", "poses", "geometryBindings", "materialModels",
        "responseSets", "metricSets", "audioScenes", "renderConfigurations",
    ]

    static func identifiers(in acoustics: [String: VAOJSONValue]?) -> [String] {
        guard let acoustics else { return [] }
        return collectionNames.flatMap { collection in
            acoustics[collection]?.arrayValue?.compactMap { $0.objectValue?["id"]?.stringValue } ?? []
        }
    }

    static func validate(
        manifest: VAOManifest,
        profileIDs: Set<String>,
        errors: inout [String],
        warnings: inout [String]
    ) {
        let acousticProfiles = manifest.profiles.filter { $0.id == VAOContract.acousticsProfile }
        let declaredCapabilities = Set(acousticProfiles.flatMap(\.requiredCapabilities))
        if profileIDs.contains(VAOContract.acousticsProfile) {
            if acousticProfiles.count != 1 {
                errors.append("The acoustics profile must be declared exactly once.")
            }
            if !profileIDs.contains(VAOContract.spatialProfile) {
                errors.append("The acoustics profile requires the spatial profile.")
            }
            if !manifest.conformsTo.contains(VAOContract.acousticsProfile) {
                errors.append("conformsTo must include the acoustics profile URI.")
            }
            if declaredCapabilities.isDisjoint(with: VAOContract.acousticsCapabilities) {
                errors.append("The acoustics profile requires a standard acoustic capability.")
            }
        }
        guard let acoustics = manifest.acoustics else {
            if profileIDs.contains(VAOContract.spatialProfile) || profileIDs.contains(VAOContract.acousticsProfile) {
                errors.append("The spatial/acoustics profile requires the closed top-level acoustics object.")
            }
            return
        }

        func objects(_ key: String) -> [[String: VAOJSONValue]] {
            acoustics[key]?.arrayValue?.compactMap(\.objectValue) ?? []
        }
        let frames = objects("coordinateFrames")
        let poses = objects("poses")
        let bindings = objects("geometryBindings")
        let materials = objects("materialModels")
        let responses = objects("responseSets")
        let metricSets = objects("metricSets")
        let scenes = objects("audioScenes")
        let renderers = objects("renderConfigurations")
        // Duplicate IDs are validation errors, not process-fatal conditions.
        // Keep the first value here so the package-wide duplicate check can
        // report malformed untrusted input without Dictionary trapping.
        func firstValues<Value>(_ pairs: [(String, Value)]) -> [String: Value] {
            var result: [String: Value] = [:]
            for (identifier, value) in pairs where result[identifier] == nil {
                result[identifier] = value
            }
            return result
        }
        let frameByID = firstValues(frames.compactMap { item in item["id"]?.stringValue.map { ($0, item) } })
        let poseByID = firstValues(poses.compactMap { item in item["id"]?.stringValue.map { ($0, item) } })
        let responseByID = firstValues(responses.compactMap { item in item["id"]?.stringValue.map { ($0, item) } })
        let metricByID = firstValues(metricSets.compactMap { item in item["id"]?.stringValue.map { ($0, item) } })
        let sceneByID = firstValues(scenes.compactMap { item in item["id"]?.stringValue.map { ($0, item) } })
        let entityByID = firstValues(manifest.entities.map { ($0.id, $0) })
        let assetByID = firstValues(manifest.assets.map { ($0.id, $0) })
        let activityByID = firstValues(manifest.paradata.map { ($0.id, $0) })
        let acousticIDs = Set(identifiers(in: acoustics))
        let known = Set(entityByID.keys)
            .union(assetByID.keys)
            .union(activityByID.keys)
            .union(manifest.analyses.map(\.id))
            .union(acousticIDs)

        func stringArray(_ value: VAOJSONValue?) -> [String] {
            value?.arrayValue?.compactMap(\.stringValue) ?? []
        }
        func numbers(_ value: VAOJSONValue?) -> [Double] {
            value?.arrayValue?.compactMap(\.numberValue) ?? []
        }
        func require(_ reference: String?, owner: String, field: String, in registry: Set<String> = []) {
            guard let reference else { return }
            let target = registry.isEmpty ? known : registry
            if !target.contains(reference) { errors.append("\(owner).\(field) has unresolved reference \(reference).") }
        }
        func methodType(_ activityID: String?) -> String? {
            guard let activityID, let activity = activityByID[activityID] else { return nil }
            return activity.method?["methodType"]?.stringValue
        }

        if profileIDs.contains(VAOContract.spatialProfile) {
            if frames.isEmpty { errors.append("The spatial profile requires a coordinate frame.") }
            if poses.isEmpty && bindings.isEmpty { errors.append("The spatial profile requires a pose or geometry binding.") }
        }

        var parentByFrame: [String: String] = [:]
        for frame in frames {
            guard let id = frame["id"]?.stringValue else { continue }
            if let parent = frame["parentFrameId"]?.stringValue {
                require(parent, owner: "Coordinate frame \(id)", field: "parentFrameId", in: Set(frameByID.keys))
                let matrix = numbers(frame["transformToParent"])
                if matrix.count != 16 || !invertible(matrix) {
                    errors.append("Coordinate frame \(id) requires a finite invertible transformToParent.")
                }
                parentByFrame[id] = parent
            } else if frame["transformToParent"] != nil {
                errors.append("Coordinate frame \(id) has transformToParent without parentFrameId.")
            }
            if frame["dimension"]?.numberValue == 2, frame["handedness"]?.stringValue != "not-applicable" {
                errors.append("Two-dimensional coordinate frame \(id) must use not-applicable handedness.")
            }
        }
        for id in parentByFrame.keys {
            var cursor = id
            var visited = Set<String>()
            while let parent = parentByFrame[cursor] {
                if !visited.insert(cursor).inserted {
                    errors.append("Coordinate-frame parent graph contains a cycle at \(id).")
                    break
                }
                cursor = parent
            }
        }

        for pose in poses {
            guard let id = pose["id"]?.stringValue else { continue }
            require(pose["subjectId"]?.stringValue, owner: "Pose \(id)", field: "subjectId", in: Set(entityByID.keys))
            let frameID = pose["frameId"]?.stringValue
            require(frameID, owner: "Pose \(id)", field: "frameId", in: Set(frameByID.keys))
            if let frameID, let dimension = frameByID[frameID]?["dimension"]?.numberValue,
               numbers(pose["position"]).count != Int(dimension) {
                errors.append("Pose \(id) dimension does not match its coordinate frame.")
            }
            require(pose["configurationId"]?.stringValue, owner: "Pose \(id)", field: "configurationId", in: Set(entityByID.keys))
            require(pose["stateId"]?.stringValue, owner: "Pose \(id)", field: "stateId", in: Set(entityByID.keys))
            require(pose["trajectoryAssetId"]?.stringValue, owner: "Pose \(id)", field: "trajectoryAssetId", in: Set(assetByID.keys))
            require(pose["generatedById"]?.stringValue, owner: "Pose \(id)", field: "generatedById", in: Set(activityByID.keys))
            let quaternion = numbers(pose["orientationXYZW"])
            if !quaternion.isEmpty {
                let norm = sqrt(quaternion.reduce(0) { $0 + $1 * $1 })
                if quaternion.count != 4 || abs(norm - 1) > 1e-5 {
                    errors.append("Pose \(id) orientationXYZW must be a normalized XYZW quaternion.")
                }
            }
        }

        for binding in bindings {
            guard let id = binding["id"]?.stringValue else { continue }
            require(binding["subjectId"]?.stringValue, owner: "Geometry binding \(id)", field: "subjectId", in: Set(entityByID.keys))
            let assetID = binding["assetId"]?.stringValue
            require(assetID, owner: "Geometry binding \(id)", field: "assetId", in: Set(assetByID.keys))
            require(binding["frameId"]?.stringValue, owner: "Geometry binding \(id)", field: "frameId", in: Set(frameByID.keys))
            require(binding["generatedById"]?.stringValue, owner: "Geometry binding \(id)", field: "generatedById", in: Set(activityByID.keys))
            if let selector = binding["selector"]?.objectValue,
               selector["selectorType"]?.stringValue == "gltf-node-index" {
                if assetID.flatMap({ assetByID[$0]?.mediaType }).map({ !["model/gltf+json", "model/gltf-binary"].contains($0) }) == true {
                    errors.append("Geometry binding \(id) uses a glTF selector on a non-glTF asset.")
                }
                if selector["value"]?.numberValue == nil { errors.append("Geometry binding \(id) must use an integer glTF node index, not a name.") }
            }
        }

        for material in materials {
            guard let id = material["id"]?.stringValue else { continue }
            require(material["materialEntityId"]?.stringValue, owner: "Material model \(id)", field: "materialEntityId", in: Set(entityByID.keys))
            let bands = numbers(material["bandAxis"]?.objectValue?["centerFrequenciesHz"])
            if bands.contains(where: { $0 <= 0 }) || zip(bands, bands.dropFirst()).contains(where: { pair in pair.0 >= pair.1 }) {
                errors.append("Material model \(id) frequencies must be positive and strictly ascending.")
            }
            for key in ["absorption", "scattering", "transmissionLossDB"]
            where material[key] != nil && numbers(material[key]).count != bands.count {
                errors.append("Material model \(id) \(key) length must match its frequency axis.")
            }
            require(material["surfaceImpedanceAssetId"]?.stringValue, owner: "Material model \(id)", field: "surfaceImpedanceAssetId", in: Set(assetByID.keys))
            require(material["environmentStateId"]?.stringValue, owner: "Material model \(id)", field: "environmentStateId", in: Set(entityByID.keys))
            require(material["generatedById"]?.stringValue, owner: "Material model \(id)", field: "generatedById", in: Set(activityByID.keys))
            let method = methodType(material["generatedById"]?.stringValue)
            if !["material-characterization", "simulation", "manual-authoring", "machine-learning-inference"].contains(method ?? "") {
                errors.append("Material model \(id) requires material-method paradata.")
            }
        }

        for response in responses {
            guard let id = response["id"]?.stringValue else { continue }
            require(response["responseEntityId"]?.stringValue, owner: "Response set \(id)", field: "responseEntityId", in: Set(entityByID.keys))
            let assetID = response["assetId"]?.stringValue
            require(assetID, owner: "Response set \(id)", field: "assetId", in: Set(assetByID.keys))
            let activityID = response["generatedById"]?.stringValue
            require(activityID, owner: "Response set \(id)", field: "generatedById", in: Set(activityByID.keys))
            require(response["delayAssetId"]?.stringValue, owner: "Response set \(id)", field: "delayAssetId", in: Set(assetByID.keys))
            for calibration in stringArray(response["calibrationIds"]) { require(calibration, owner: "Response set \(id)", field: "calibrationIds") }
            if response["representationStatus"]?.stringValue == "measured",
               !["measurement", "deconvolution"].contains(methodType(activityID) ?? "") {
                errors.append("Measured response set \(id) requires measurement/deconvolution method paradata.")
            }
            let isSOFAAsset = assetID.flatMap { assetByID[$0]?.path }.map { $0.lowercased().hasSuffix(".sofa") } ?? false
            if response["encoding"]?.stringValue == "AES69-SOFA", !isSOFAAsset {
                errors.append("AES69-SOFA response set \(id) must reference a .sofa asset.")
            }
            let measurements = response["measurements"]?.arrayValue?.compactMap(\.objectValue) ?? []
            if ["WAV", "FLAC"].contains(response["encoding"]?.stringValue ?? ""), (measurements.count != 1 || response["interpolation"] != nil) {
                errors.append("WAV/FLAC response set \(id) is limited to one fixed pair without interpolation.")
            }
            for measurement in measurements {
                for key in ["sourceId", "receiverId", "spaceId", "sourceSpaceId", "receivingSpaceId", "separatingElementId"] {
                    require(measurement[key]?.stringValue, owner: "Response set \(id)", field: key, in: Set(entityByID.keys))
                }
                require(measurement["sourcePoseId"]?.stringValue, owner: "Response set \(id)", field: "sourcePoseId", in: Set(poseByID.keys))
                require(measurement["receiverPoseId"]?.stringValue, owner: "Response set \(id)", field: "receiverPoseId", in: Set(poseByID.keys))
                require(measurement["configurationId"]?.stringValue, owner: "Response set \(id)", field: "configurationId", in: Set(entityByID.keys))
                require(measurement["stateId"]?.stringValue, owner: "Response set \(id)", field: "stateId", in: Set(entityByID.keys))
                for path in stringArray(measurement["transmissionPathIds"]) { require(path, owner: "Response set \(id)", field: "transmissionPathIds", in: Set(entityByID.keys)) }
            }
            if let interpolation = response["interpolation"]?.objectValue {
                require(interpolation["domain"]?.stringValue, owner: "Response set \(id)", field: "interpolation.domain", in: Set(entityByID.keys))
                require(interpolation["fallbackResponseSetId"]?.stringValue, owner: "Response set \(id)", field: "interpolation.fallbackResponseSetId", in: Set(responseByID.keys))
                require(interpolation["modelAssetId"]?.stringValue, owner: "Response set \(id)", field: "interpolation.modelAssetId", in: Set(assetByID.keys))
                require(interpolation["qualityMetricSetId"]?.stringValue, owner: "Response set \(id)", field: "interpolation.qualityMetricSetId", in: Set(metricByID.keys))
                for key in ["trainingInputIds", "validationInputIds"] {
                    for input in stringArray(interpolation[key]) { require(input, owner: "Response set \(id)", field: "interpolation.\(key)") }
                }
                if interpolation["method"]?.stringValue == "neural-field" {
                    for key in ["modelAssetId", "trainingInputIds", "validationInputIds", "qualityMetricSetId", "fallbackResponseSetId"]
                    where interpolation[key] == nil || interpolation[key]?.arrayValue?.isEmpty == true {
                        errors.append("Neural-field response set \(id) requires \(key).")
                    }
                    let modelID = interpolation["modelAssetId"]?.stringValue
                    if modelID.flatMap({ assetByID[$0] }).map({ !Set($0.roles).contains(VAOContract.acousticModelRole) }) != false {
                        errors.append("Neural-field response set \(id) model asset requires the acoustic-model role.")
                    }
                    if methodType(activityID) != "machine-learning-inference"
                        || modelID.map({ !((activityID.flatMap { activityByID[$0] })?.inputIds.contains($0) ?? false) }) != false {
                        errors.append("Neural-field response set \(id) requires machine-learning-inference paradata that uses its fixed model asset.")
                    }
                    if modelID.map({ model in !manifest.paradata.contains(where: {
                        $0.method?["methodType"]?.stringValue == "machine-learning-training" && $0.outputIds.contains(model)
                    }) }) != false {
                        errors.append("Neural-field response set \(id) model asset requires machine-learning-training provenance.")
                    }
                    if let fallbackID = interpolation["fallbackResponseSetId"]?.stringValue,
                       ["learned", "hybrid"].contains(responseByID[fallbackID]?["representationStatus"]?.stringValue ?? "") {
                        errors.append("Neural-field response set \(id) fallback must be non-learned.")
                    }
                    let determinism = interpolation["determinism"]?.stringValue
                    if determinism == nil || (determinism == "seeded" && interpolation["seed"] == nil) {
                        errors.append("Neural-field response set \(id) requires determinism and a seed when seeded.")
                    }
                }
            }
        }

        for metricSet in metricSets {
            guard let id = metricSet["id"]?.stringValue else { continue }
            require(metricSet["generatedById"]?.stringValue, owner: "Metric set \(id)", field: "generatedById", in: Set(activityByID.keys))
            for key in ["subjectIds", "inputIds"] {
                for input in stringArray(metricSet[key]) { require(input, owner: "Metric set \(id)", field: key) }
            }
            if methodType(metricSet["generatedById"]?.stringValue) != "metric-calculation" {
                errors.append("Metric set \(id) paradata must declare metric-calculation.")
            }
            let bandCount = numbers(metricSet["bandAxis"]?.objectValue?["centerFrequenciesHz"]).count
            for metric in metricSet["metrics"]?.arrayValue?.compactMap(\.objectValue) ?? [] {
                if numbers(metric["values"]).count != bandCount { errors.append("Metric values in \(id) must align with its frequency axis.") }
                if metric["uncertainties"] != nil && numbers(metric["uncertainties"]).count != bandCount { errors.append("Metric uncertainties in \(id) must align with its frequency axis.") }
                for key in ["sourceId", "receiverId", "sourceSpaceId", "receivingSpaceId", "separatingElementId"] {
                    require(metric[key]?.stringValue, owner: "Metric set \(id)", field: key, in: Set(entityByID.keys))
                }
            }
        }

        for scene in scenes {
            guard let id = scene["id"]?.stringValue else { continue }
            require(scene["sceneEntityId"]?.stringValue, owner: "Audio scene \(id)", field: "sceneEntityId", in: Set(entityByID.keys))
            require(scene["coordinateFrameId"]?.stringValue, owner: "Audio scene \(id)", field: "coordinateFrameId", in: Set(frameByID.keys))
            for assetID in stringArray(scene["mediaAssetIds"]) { require(assetID, owner: "Audio scene \(id)", field: "mediaAssetIds", in: Set(assetByID.keys)) }
            require(scene["metadataAssetId"]?.stringValue, owner: "Audio scene \(id)", field: "metadataAssetId", in: Set(assetByID.keys))
            require(scene["generatedById"]?.stringValue, owner: "Audio scene \(id)", field: "generatedById", in: Set(activityByID.keys))
            for binding in scene["bindings"]?.arrayValue?.compactMap(\.objectValue) ?? [] {
                require(binding["entityId"]?.stringValue, owner: "Audio scene \(id)", field: "binding.entityId", in: Set(entityByID.keys))
                require(binding["mediaAssetId"]?.stringValue, owner: "Audio scene \(id)", field: "binding.mediaAssetId", in: Set(assetByID.keys))
                require(binding["poseId"]?.stringValue, owner: "Audio scene \(id)", field: "binding.poseId", in: Set(poseByID.keys))
                require(binding["directivityResponseSetId"]?.stringValue, owner: "Audio scene \(id)", field: "binding.directivityResponseSetId", in: Set(responseByID.keys))
            }
        }
        for renderer in renderers {
            guard let id = renderer["id"]?.stringValue else { continue }
            require(renderer["sceneId"]?.stringValue, owner: "Render configuration \(id)", field: "sceneId", in: Set(sceneByID.keys))
            require(renderer["coordinateFrameId"]?.stringValue, owner: "Render configuration \(id)", field: "coordinateFrameId", in: Set(frameByID.keys))
            for input in stringArray(renderer["inputIds"]) { require(input, owner: "Render configuration \(id)", field: "inputIds") }
            for fallback in stringArray(renderer["fallbackIds"]) { require(fallback, owner: "Render configuration \(id)", field: "fallbackIds") }
            require(renderer["validDomainId"]?.stringValue, owner: "Render configuration \(id)", field: "validDomainId", in: Set(entityByID.keys))
            if let listener = renderer["listener"]?.objectValue {
                require(listener["receiverId"]?.stringValue, owner: "Render configuration \(id)", field: "listener.receiverId", in: Set(entityByID.keys))
                require(listener["coordinateFrameId"]?.stringValue, owner: "Render configuration \(id)", field: "listener.coordinateFrameId", in: Set(frameByID.keys))
                require(listener["poseId"]?.stringValue, owner: "Render configuration \(id)", field: "listener.poseId", in: Set(poseByID.keys))
                for key in ["trajectoryAssetId", "personalizationAssetId", "headphoneCompensationAssetId"] {
                    require(listener[key]?.stringValue, owner: "Render configuration \(id)", field: "listener.\(key)", in: Set(assetByID.keys))
                }
            }
            for feature in renderer["features"]?.arrayValue?.compactMap(\.objectValue) ?? [] {
                for input in stringArray(feature["inputIds"]) { require(input, owner: "Render configuration \(id)", field: "feature.inputIds") }
            }
            for level in renderer["levelsOfDetail"]?.arrayValue?.compactMap(\.objectValue) ?? [] {
                for input in stringArray(level["inputIds"]) { require(input, owner: "Render configuration \(id)", field: "levelsOfDetail.inputIds") }
            }
            if renderer["outsideDomainPolicy"]?.stringValue == "fallback", stringArray(renderer["fallbackIds"]).isEmpty {
                errors.append("Render configuration \(id) selects fallback policy without a fallback.")
            }
            if renderer["strategy"]?.stringValue == "learned-field", !stringArray(renderer["inputIds"]).contains(where: {
                responseByID[$0]?["interpolation"]?.objectValue?["method"]?.stringValue == "neural-field"
            }) {
                errors.append("Learned-field render configuration \(id) requires a neural-field response input.")
            }
        }

        let kinds = Set(manifest.entities.map(\.kind))
        if declaredCapabilities.contains(VAOContract.semanticBuildingModelCapability) {
            if !Set(["building", "space", "boundary"]).isSubset(of: kinds) { errors.append("The semantic-building-model capability requires building, space, and boundary entities.") }
            if !bindings.contains(where: { $0["role"]?.stringValue == "authoritative-semantic" }) { errors.append("The semantic-building-model capability requires an authoritative semantic geometry binding.") }
        }
        if declaredCapabilities.contains(VAOContract.measuredImpulseResponseCapability), !responses.contains(where: { $0["representationStatus"]?.stringValue == "measured" }) { errors.append("The measured-impulse-response capability requires a measured response set.") }
        if declaredCapabilities.contains(VAOContract.spatialResponseFieldCapability), !responses.contains(where: { $0["interpolation"]?.objectValue != nil }) { errors.append("The spatial-response-field capability requires an interpolation contract.") }
        if declaredCapabilities.contains(VAOContract.sourceDirectivityCapability), !responses.contains(where: { $0["responseKind"]?.stringValue == "directivity" }) { errors.append("The source-directivity capability requires a directivity response set.") }
        if declaredCapabilities.contains(VAOContract.roomAcousticMetricsCapability), metricSets.isEmpty { errors.append("The room-acoustic-metrics capability requires a metric set.") }
        if declaredCapabilities.contains(VAOContract.buildingAcousticPerformanceCapability), !metricSets.contains(where: { set in
            set["metrics"]?.arrayValue?.compactMap(\.objectValue).contains(where: {
                $0["sourceSpaceId"]?.stringValue != nil
                    && $0["receivingSpaceId"]?.stringValue != nil
                    && $0["separatingElementId"]?.stringValue != nil
            }) == true
        }) { errors.append("The building-acoustic-performance capability requires source room, receiving room, and separating element on a metric.") }
        if declaredCapabilities.contains(VAOContract.spatialAudioSceneCapability), scenes.isEmpty { errors.append("The spatial-audio-scene capability requires an audio scene.") }
        if declaredCapabilities.contains(VAOContract.trackedListenerConvolutionCapability), !renderers.contains(where: {
            ["tracked-convolution", "response-interpolation"].contains($0["strategy"]?.stringValue ?? "")
                && ["tracked-3dof", "tracked-6dof"].contains($0["listener"]?.objectValue?["mode"]?.stringValue ?? "")
        }) { errors.append("The tracked-listener-convolution capability requires a tracked-listener render configuration.") }
        if declaredCapabilities.contains(VAOContract.trackedSourcesCapability), !renderers.contains(where: { renderer in
            renderer["features"]?.arrayValue?.compactMap(\.objectValue).contains(where: {
                $0["feature"]?.stringValue == "source-tracking"
                    && $0["mode"]?.stringValue != "disabled"
                    && !stringArray($0["inputIds"]).isEmpty
            }) == true
        }) { errors.append("The tracked-sources capability requires a non-disabled source-tracking feature with explicit inputs.") }
        if declaredCapabilities.contains(VAOContract.geometryAcousticRenderingCapability) {
            if materials.isEmpty { errors.append("The geometry-acoustic-rendering capability requires acoustic material models.") }
            if !renderers.contains(where: { ["geometry-acoustics", "hybrid"].contains($0["strategy"]?.stringValue ?? "") }) {
                errors.append("The geometry-acoustic-rendering capability requires a geometry or hybrid render configuration.")
            }
        }
        if declaredCapabilities.contains(VAOContract.hybridAcousticRenderingCapability), !renderers.contains(where: { $0["strategy"]?.stringValue == "hybrid" }) { errors.append("The hybrid-acoustic-rendering capability requires a hybrid render configuration.") }
        if declaredCapabilities.contains(VAOContract.learnedAcousticFieldCapability), !responses.contains(where: {
            ["learned", "hybrid"].contains($0["representationStatus"]?.stringValue ?? "")
                && $0["interpolation"]?.objectValue?["method"]?.stringValue == "neural-field"
        }) { errors.append("The learned-acoustic-field capability requires a learned/hybrid neural-field response set.") }
        _ = warnings
        _ = responseByID
        _ = metricByID
    }

    private static func invertible(_ values: [Double]) -> Bool {
        guard values.count == 16, values.allSatisfy(\.isFinite) else { return false }
        var matrix = (0..<4).map { row in Array(values[(row * 4)..<(row * 4 + 4)]) }
        for column in 0..<4 {
            guard let pivot = (column..<4).max(by: { abs(matrix[$0][column]) < abs(matrix[$1][column]) }),
                  abs(matrix[pivot][column]) >= 1e-12 else { return false }
            matrix.swapAt(column, pivot)
            for row in (column + 1)..<4 {
                let scale = matrix[row][column] / matrix[column][column]
                for item in column..<4 { matrix[row][item] -= scale * matrix[column][item] }
            }
        }
        return true
    }
}
