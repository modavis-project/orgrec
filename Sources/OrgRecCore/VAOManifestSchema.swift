import CoreFoundation
import Foundation

/// Native checks for the closed, normative VAO 0.2 manifest shape. Codable
/// supplies required-field and scalar-type checking; this layer enforces the
/// JSON Schema rules that Codable intentionally ignores, especially closed
/// objects, URI-keyed extension maps, enums, uniqueness, and numeric bounds.
enum VAOManifestSchemaValidator {
    static func validate(_ data: Data) -> [String] {
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data)
        } catch {
            return ["VAO manifest is not valid JSON: \(error.localizedDescription)"]
        }
        guard let root = value as? [String: Any] else {
            return ["VAO manifest root must be a JSON object."]
        }

        var errors: [String] = []
        checkObject(root, at: "manifest", required: [
            "$schema", "@context", "type", "formatVersion", "id", "revision", "createdAt", "modifiedAt",
            "title", "conformsTo", "profiles", "modavisBinding", "primaryEntityId", "focusEntityIds", "entities", "relations",
            "assets", "paradata", "analyses", "rights", "integrity",
        ], allowed: [
            "$schema", "@context", "type", "formatVersion", "id", "revision", "createdAt", "modifiedAt",
            "title", "description", "conformsTo", "profiles", "modavisBinding", "primaryEntityId", "focusEntityIds", "entities",
            "relations", "assets", "paradata", "analyses", "acoustics", "rights", "integrity", "extensions",
        ], errors: &errors)

        if root["$schema"] as? String != VAOContract.schemaURI {
            errors.append("Manifest $schema must equal \(VAOContract.schemaURI).")
        }
        if root["type"] as? String != "VirtualAcousticObject" {
            errors.append("Manifest type must be VirtualAcousticObject.")
        }
        if let version = root["formatVersion"] as? String {
            let parts = version.split(separator: ".", omittingEmptySubsequences: false)
            if parts.count != 3 || parts[0] != "0" || parts[1] != "2" || Int(parts[2]) == nil {
                errors.append("Manifest formatVersion must match 0.2.x.")
            }
        }
        checkIdentifier(root["id"], at: "manifest.id", errors: &errors)
        checkIdentifier(root["primaryEntityId"], at: "manifest.primaryEntityId", errors: &errors)
        checkIdentifierArray(root["focusEntityIds"], at: "manifest.focusEntityIds", nonEmpty: true, errors: &errors)
        checkPositiveInteger(root["revision"], at: "manifest.revision", errors: &errors)
        checkLocalized(root["title"], at: "manifest.title", errors: &errors)
        if let description = root["description"] { checkLocalized(description, at: "manifest.description", errors: &errors) }
        checkIRIArray(root["@context"], at: "manifest.@context", nonEmpty: true, errors: &errors)
        checkIRIArray(root["conformsTo"], at: "manifest.conformsTo", nonEmpty: true, errors: &errors)
        if let context = root["@context"] as? [String], !context.contains(VAOContract.contextURI) {
            errors.append("Manifest @context must contain the normative VAO context.")
        }
        if let extensions = root["extensions"] { checkIRIProperties(extensions, at: "manifest.extensions", errors: &errors) }

        checkProfiles(root["profiles"], errors: &errors)
        checkBinding(root["modavisBinding"], errors: &errors)
        checkEntities(root["entities"], errors: &errors)
        checkRelations(root["relations"], errors: &errors)
        checkAssets(root["assets"], errors: &errors)
        checkParadata(root["paradata"], errors: &errors)
        checkAnalyses(root["analyses"], errors: &errors)
        if let acoustics = root["acoustics"] { checkAcoustics(acoustics, errors: &errors) }
        checkRights(root["rights"], errors: &errors)
        checkIntegrity(root["integrity"], errors: &errors)
        return errors
    }

    private static func checkProfiles(_ value: Any?, errors: inout [String]) {
        guard let records = value as? [[String: Any]], !records.isEmpty else {
            errors.append("Manifest profiles must be a non-empty array.")
            return
        }
        for (index, record) in records.enumerated() {
            let path = "profiles[\(index)]"
            checkObject(record, at: path, required: ["id", "version", "requiredCapabilities"], allowed: ["id", "version", "requiredCapabilities"], errors: &errors)
            checkIRI(record["id"], at: "\(path).id", errors: &errors)
            if (record["version"] as? String)?.isEmpty != false { errors.append("\(path).version must be non-empty.") }
            checkIRIArray(record["requiredCapabilities"], at: "\(path).requiredCapabilities", nonEmpty: false, errors: &errors)
        }
    }

    private static func checkBinding(_ value: Any?, errors: inout [String]) {
        guard let record = value as? [String: Any] else {
            errors.append("modavisBinding must be an object.")
            return
        }
        let allowed: Set<String> = [
            "ontologyIRI", "ontologyVersion", "ontologyStatus", "ontologyVersionIRI", "vocabularyReleaseIRI",
            "vocabularyManifestSHA256", "schemaRelease", "mappingVersion", "mappingIRI", "navigatorSnapshotAssetId", "notes",
        ]
        checkObject(record, at: "modavisBinding", required: ["ontologyIRI", "ontologyVersion", "ontologyStatus", "mappingVersion"], allowed: allowed, errors: &errors)
        checkIRI(record["ontologyIRI"], at: "modavisBinding.ontologyIRI", errors: &errors)
        if (record["ontologyVersion"] as? String)?.isEmpty != false { errors.append("modavisBinding.ontologyVersion must be non-empty.") }
        if (record["mappingVersion"] as? String)?.isEmpty != false { errors.append("modavisBinding.mappingVersion must be non-empty.") }
        let status = record["ontologyStatus"] as? String
        if !["development", "released", "embedded-snapshot"].contains(status ?? "") {
            errors.append("modavisBinding.ontologyStatus is invalid.")
        }
        for key in ["ontologyVersionIRI", "vocabularyReleaseIRI", "mappingIRI"] where record[key] != nil {
            checkIRI(record[key], at: "modavisBinding.\(key)", errors: &errors)
        }
        if status == "released" {
            if record["ontologyVersionIRI"] == nil { errors.append("Released modavisBinding requires ontologyVersionIRI.") }
            if record["mappingIRI"] == nil { errors.append("Released modavisBinding requires mappingIRI.") }
        }
        let releaseIRI = record["vocabularyReleaseIRI"]
        let releaseHash = record["vocabularyManifestSHA256"]
        if (releaseIRI == nil) != (releaseHash == nil) {
            errors.append("modavisBinding vocabularyReleaseIRI and vocabularyManifestSHA256 must occur together.")
        }
        if let hash = releaseHash as? String, !isSHA256(hash, lowercaseOnly: false) {
            errors.append("modavisBinding.vocabularyManifestSHA256 must be a SHA-256 digest.")
        }
        if record["navigatorSnapshotAssetId"] != nil {
            checkIdentifier(record["navigatorSnapshotAssetId"], at: "modavisBinding.navigatorSnapshotAssetId", errors: &errors)
        }
    }

    private static func checkEntities(_ value: Any?, errors: inout [String]) {
        guard let records = value as? [[String: Any]], !records.isEmpty else {
            errors.append("Manifest entities must be a non-empty array.")
            return
        }
        let kinds: Set<String> = [
            "instrument", "component", "componentCollection", "configuration", "state", "performance", "event",
            "activity", "agent", "place", "building", "storey", "space", "zone", "boundary", "opening", "material",
            "source", "acousticEmitter", "acousticReceiver", "receiverArray", "coordinateFrame", "acousticResponse",
            "audioScene", "renderConfiguration", "sensor", "equipment", "sourceSnapshot", "sourceFragment", "assertion", "evidenceSupport",
            "annotation", "digitalObject", "measurement", "analysis", "parameterSet", "spatialRegion", "interaction",
            "experience", "assetGroup", "loopPointSet", "signalRegion", "other",
        ]
        for (index, record) in records.enumerated() {
            let path = "entities[\(index)]"
            checkObject(record, at: path, required: ["id", "kind", "types", "labels"], allowed: ["id", "kind", "types", "labels", "classifications", "externalIdentifiers", "properties"], errors: &errors)
            checkIdentifier(record["id"], at: "\(path).id", errors: &errors)
            if !kinds.contains(record["kind"] as? String ?? "") { errors.append("\(path).kind is not a VAO 0.2 entity kind.") }
            checkIRIArray(record["types"], at: "\(path).types", nonEmpty: true, errors: &errors)
            checkLocalized(record["labels"], at: "\(path).labels", errors: &errors)
            if let properties = record["properties"] { checkIRIProperties(properties, at: "\(path).properties", errors: &errors) }
            if let concepts = record["classifications"] as? [[String: Any]] {
                for (conceptIndex, concept) in concepts.enumerated() {
                    let conceptPath = "\(path).classifications[\(conceptIndex)]"
                    checkObject(concept, at: conceptPath, required: ["id"], allowed: ["id", "label", "code", "scheme"], errors: &errors)
                    checkIRI(concept["id"], at: "\(conceptPath).id", errors: &errors)
                    if let label = concept["label"] { checkLocalized(label, at: "\(conceptPath).label", errors: &errors) }
                    if concept["scheme"] != nil { checkIRI(concept["scheme"], at: "\(conceptPath).scheme", errors: &errors) }
                }
            }
            if let identifiers = record["externalIdentifiers"] as? [[String: Any]] {
                for (identifierIndex, identifier) in identifiers.enumerated() {
                    let identifierPath = "\(path).externalIdentifiers[\(identifierIndex)]"
                    checkObject(identifier, at: identifierPath, required: ["value", "scheme"], allowed: ["value", "scheme", "resolvesTo"], errors: &errors)
                    if (identifier["value"] as? String)?.isEmpty != false { errors.append("\(identifierPath).value must be non-empty.") }
                    checkIRI(identifier["scheme"], at: "\(identifierPath).scheme", errors: &errors)
                    if identifier["resolvesTo"] != nil { checkIRI(identifier["resolvesTo"], at: "\(identifierPath).resolvesTo", errors: &errors) }
                }
            }
        }
    }

    private static func checkRelations(_ value: Any?, errors: inout [String]) {
        guard let records = value as? [[String: Any]] else {
            errors.append("Manifest relations must be an array.")
            return
        }
        for (index, record) in records.enumerated() {
            let path = "relations[\(index)]"
            checkObject(record, at: path, required: ["id", "subjectId", "predicate", "status"], allowed: ["id", "subjectId", "predicate", "objectId", "literal", "status", "confidence", "scope", "evidenceIds", "generatedByIds", "properties"], errors: &errors)
            checkIdentifier(record["id"], at: "\(path).id", errors: &errors)
            checkIdentifier(record["subjectId"], at: "\(path).subjectId", errors: &errors)
            checkIRI(record["predicate"], at: "\(path).predicate", errors: &errors)
            if (record["objectId"] == nil) == (record["literal"] == nil) { errors.append("\(path) must contain exactly one of objectId or literal.") }
            if record["objectId"] != nil { checkIdentifier(record["objectId"], at: "\(path).objectId", errors: &errors) }
            if !["asserted", "accepted", "rejected", "superseded", "inferred"].contains(record["status"] as? String ?? "") { errors.append("\(path).status is invalid.") }
            if let confidence = number(record["confidence"]), !(0...1).contains(confidence) { errors.append("\(path).confidence is outside 0...1.") }
            if let properties = record["properties"] { checkIRIProperties(properties, at: "\(path).properties", errors: &errors) }
            if let literal = record["literal"] as? [String: Any] {
                checkObject(literal, at: "\(path).literal", required: ["value"], allowed: ["value", "datatype", "language", "unit"], errors: &errors)
                for key in ["datatype", "unit"] where literal[key] != nil { checkIRI(literal[key], at: "\(path).literal.\(key)", errors: &errors) }
            }
            if let scope = record["scope"] as? [String: Any] {
                checkObject(scope, at: "\(path).scope", required: [], allowed: ["configurationId", "stateId", "validFrom", "validUntil", "spatialRegionId"], errors: &errors)
                if scope.isEmpty { errors.append("\(path).scope must not be empty.") }
                for key in ["configurationId", "stateId", "spatialRegionId"] where scope[key] != nil { checkIdentifier(scope[key], at: "\(path).scope.\(key)", errors: &errors) }
            }
            checkIdentifierArrayIfPresent(record["evidenceIds"], at: "\(path).evidenceIds", errors: &errors)
            checkIdentifierArrayIfPresent(record["generatedByIds"], at: "\(path).generatedByIds", errors: &errors)
        }
    }

    private static func checkAssets(_ value: Any?, errors: inout [String]) {
        guard let records = value as? [[String: Any]] else {
            errors.append("Manifest assets must be an array.")
            return
        }
        for (index, record) in records.enumerated() {
            let path = "assets[\(index)]"
            checkObject(record, at: path, required: ["id", "path", "mediaType", "byteSize", "sha256", "roles", "representationStatus", "aboutEntityIds"], allowed: ["id", "path", "mediaType", "byteSize", "sha256", "roles", "representationStatus", "aboutEntityIds", "originalFilename", "createdAt", "encoding", "properties"], errors: &errors)
            checkIdentifier(record["id"], at: "\(path).id", errors: &errors)
            if let assetPath = record["path"] as? String {
                if !isSafePayloadPath(assetPath) { errors.append("\(path).path is not a safe payload path.") }
            } else { errors.append("\(path).path must be a string.") }
            if let mediaType = record["mediaType"] as? String {
                if mediaType.range(of: "^[^/\\s]+/[^\\s]+$", options: .regularExpression) == nil { errors.append("\(path).mediaType is invalid.") }
            } else { errors.append("\(path).mediaType must be a string.") }
            checkNonnegativeInteger(record["byteSize"], at: "\(path).byteSize", errors: &errors)
            if !isSHA256(record["sha256"] as? String ?? "", lowercaseOnly: true) { errors.append("\(path).sha256 must be a lowercase SHA-256 digest.") }
            checkIRIArray(record["roles"], at: "\(path).roles", nonEmpty: true, errors: &errors)
            checkIRI(record["representationStatus"], at: "\(path).representationStatus", errors: &errors)
            checkIdentifierArray(record["aboutEntityIds"], at: "\(path).aboutEntityIds", nonEmpty: true, errors: &errors)
            if let properties = record["properties"] { checkIRIProperties(properties, at: "\(path).properties", errors: &errors) }
        }
    }

    private static func checkParadata(_ value: Any?, errors: inout [String]) {
        guard let records = value as? [[String: Any]] else { errors.append("Manifest paradata must be an array."); return }
        for (index, record) in records.enumerated() {
            let path = "paradata[\(index)]"
            checkObject(record, at: path, required: ["id", "activityType", "startedAt", "software", "inputIds", "outputIds", "parameters"], allowed: ["id", "activityType", "startedAt", "endedAt", "actorIds", "software", "method", "inputIds", "outputIds", "parameters", "notes"], errors: &errors)
            checkIdentifier(record["id"], at: "\(path).id", errors: &errors)
            checkIRI(record["activityType"], at: "\(path).activityType", errors: &errors)
            checkIdentifierArrayIfPresent(record["actorIds"], at: "\(path).actorIds", errors: &errors)
            checkIdentifierArray(record["inputIds"], at: "\(path).inputIds", nonEmpty: false, errors: &errors)
            checkIdentifierArray(record["outputIds"], at: "\(path).outputIds", nonEmpty: false, errors: &errors)
            guard let software = record["software"] as? [String: Any] else { errors.append("\(path).software must be an object."); continue }
            checkObject(software, at: "\(path).software", required: ["name", "version"], allowed: ["name", "version", "uri", "build"], errors: &errors)
            if (software["name"] as? String)?.isEmpty != false || (software["version"] as? String)?.isEmpty != false { errors.append("\(path).software requires non-empty name and version.") }
            if software["uri"] != nil { checkIRI(software["uri"], at: "\(path).software.uri", errors: &errors) }
            if let method = record["method"] as? [String: Any] {
                checkObject(method, at: "\(path).method", required: ["methodType", "representationStatus"], allowed: [
                    "methodType", "representationStatus", "standard", "standardEdition", "protocolAssetId",
                    "equipmentIds", "calibrationIds", "environmentStateId", "randomSeed", "qualityFlags",
                ], errors: &errors)
                let methodTypes = ["measurement", "deconvolution", "spatial-registration", "material-characterization", "metric-calculation", "simulation", "auralization", "encoding", "interpolation", "machine-learning-training", "machine-learning-inference", "manual-authoring", "other"]
                if !methodTypes.contains(method["methodType"] as? String ?? "") { errors.append("\(path).method.methodType is invalid.") }
                let statuses = ["measured", "simulated", "inferred", "learned", "authored", "hybrid"]
                if !statuses.contains(method["representationStatus"] as? String ?? "") { errors.append("\(path).method.representationStatus is invalid.") }
                if method["standard"] != nil { checkIRI(method["standard"], at: "\(path).method.standard", errors: &errors) }
                for key in ["protocolAssetId", "environmentStateId"] where method[key] != nil { checkIdentifier(method[key], at: "\(path).method.\(key)", errors: &errors) }
                for key in ["equipmentIds", "calibrationIds"] where method[key] != nil { checkIdentifierArray(method[key], at: "\(path).method.\(key)", nonEmpty: false, errors: &errors) }
            } else if record["method"] != nil {
                errors.append("\(path).method must be an object.")
            }
            if !(record["parameters"] is [String: Any]) { errors.append("\(path).parameters must be an object.") }
        }
    }

    private static func checkAnalyses(_ value: Any?, errors: inout [String]) {
        guard let records = value as? [[String: Any]] else { errors.append("Manifest analyses must be an array."); return }
        for (index, record) in records.enumerated() {
            let path = "analyses[\(index)]"
            checkObject(record, at: path, required: ["id", "analysisType", "method", "version", "generatedAt", "inputIds", "outputIds", "observations"], allowed: ["id", "analysisType", "method", "version", "generatedAt", "inputIds", "outputIds", "paradataId", "observations", "qualityFlags"], errors: &errors)
            checkIdentifier(record["id"], at: "\(path).id", errors: &errors)
            checkIRI(record["analysisType"], at: "\(path).analysisType", errors: &errors)
            checkIdentifierArray(record["inputIds"], at: "\(path).inputIds", nonEmpty: true, errors: &errors)
            checkIdentifierArray(record["outputIds"], at: "\(path).outputIds", nonEmpty: false, errors: &errors)
            if record["paradataId"] != nil { checkIdentifier(record["paradataId"], at: "\(path).paradataId", errors: &errors) }
            guard let observations = record["observations"] as? [[String: Any]] else { errors.append("\(path).observations must be an array."); continue }
            for (observationIndex, observation) in observations.enumerated() {
                let observationPath = "\(path).observations[\(observationIndex)]"
                checkObject(
                    observation,
                    at: observationPath,
                    required: ["property", "value"],
                    allowed: [
                        "property", "value", "unit", "uncertainty", "confidence", "coverage", "evidenceCount",
                        "status", "applicability", "censoring", "aggregation", "subjectId", "sourceRegionId",
                        "valueAssetId", "channelIndices", "qualityFlags", "timeRange",
                    ],
                    errors: &errors
                )
                checkIRI(observation["property"], at: "\(observationPath).property", errors: &errors)
                if observation["unit"] != nil { checkIRI(observation["unit"], at: "\(observationPath).unit", errors: &errors) }
                if let uncertainty = number(observation["uncertainty"]), uncertainty < 0 { errors.append("\(observationPath).uncertainty must be non-negative.") }
                if let confidence = number(observation["confidence"]), !(0...1).contains(confidence) { errors.append("\(observationPath).confidence is outside 0...1.") }
                if let coverage = number(observation["coverage"]), !(0...1).contains(coverage) { errors.append("\(observationPath).coverage is outside 0...1.") }
                if observation["evidenceCount"] != nil { checkNonnegativeInteger(observation["evidenceCount"], at: "\(observationPath).evidenceCount", errors: &errors) }
                if let status = observation["status"] as? String, !["observed", "inferred", "reviewed", "accepted", "rejected", "superseded"].contains(status) { errors.append("\(observationPath).status is invalid.") }
                if let applicability = observation["applicability"] as? String, !["applicable", "limited", "notApplicable", "indeterminate"].contains(applicability) { errors.append("\(observationPath).applicability is invalid.") }
                if let censoring = observation["censoring"] as? String, !["none", "left", "right", "interval"].contains(censoring) { errors.append("\(observationPath).censoring is invalid.") }
                if observation["aggregation"] != nil { checkIRI(observation["aggregation"], at: "\(observationPath).aggregation", errors: &errors) }
                if observation["subjectId"] != nil { checkIdentifier(observation["subjectId"], at: "\(observationPath).subjectId", errors: &errors) }
                if observation["sourceRegionId"] != nil { checkIdentifier(observation["sourceRegionId"], at: "\(observationPath).sourceRegionId", errors: &errors) }
                if observation["valueAssetId"] != nil { checkIdentifier(observation["valueAssetId"], at: "\(observationPath).valueAssetId", errors: &errors) }
                if observation["channelIndices"] != nil {
                    guard let channels = observation["channelIndices"] as? [Any], !channels.isEmpty else {
                        errors.append("\(observationPath).channelIndices must be a non-empty array.")
                        continue
                    }
                    if Set(channels.compactMap { $0 as? Int }).count != channels.count || channels.contains(where: { ($0 as? Int ?? -1) < 0 }) {
                        errors.append("\(observationPath).channelIndices must contain unique non-negative integers.")
                    }
                }
                if let range = observation["timeRange"] as? [String: Any] {
                    checkObject(range, at: "\(observationPath).timeRange", required: ["startSeconds", "endSeconds"], allowed: ["startSeconds", "endSeconds", "startFrameInclusive", "endFrameExclusive", "sampleRate", "clockAssetId"], errors: &errors)
                    for key in ["startSeconds", "endSeconds"] where (number(range[key]) ?? -1) < 0 { errors.append("\(observationPath).timeRange.\(key) must be non-negative.") }
                    let exactKeys = ["startFrameInclusive", "endFrameExclusive", "sampleRate", "clockAssetId"]
                    let exactCount = exactKeys.filter { range[$0] != nil }.count
                    if exactCount != 0 && exactCount != exactKeys.count { errors.append("\(observationPath).timeRange exact-frame clock must be complete.") }
                    if exactCount == exactKeys.count {
                        checkNonnegativeInteger(range["startFrameInclusive"], at: "\(observationPath).timeRange.startFrameInclusive", errors: &errors)
                        guard let end = range["endFrameExclusive"] as? Int, end > 0 else { errors.append("\(observationPath).timeRange.endFrameExclusive must be positive."); continue }
                        if (number(range["sampleRate"]) ?? 0) <= 0 { errors.append("\(observationPath).timeRange.sampleRate must be positive.") }
                        checkIdentifier(range["clockAssetId"], at: "\(observationPath).timeRange.clockAssetId", errors: &errors)
                    }
                }
            }
        }
    }

    private static func checkAcoustics(_ value: Any, errors: inout [String]) {
        guard let acoustics = value as? [String: Any] else {
            errors.append("acoustics must be an object.")
            return
        }
        let collections: Set<String> = [
            "coordinateFrames", "poses", "geometryBindings", "materialModels",
            "responseSets", "metricSets", "audioScenes", "renderConfigurations",
        ]
        checkObject(acoustics, at: "acoustics", required: collections, allowed: collections, errors: &errors)

        func records(_ key: String) -> [[String: Any]] {
            guard let records = acoustics[key] as? [[String: Any]] else {
                errors.append("acoustics.\(key) must be an array of objects.")
                return []
            }
            return records
        }
        func checkNumberArray(_ value: Any?, count: Int? = nil, at path: String, errors: inout [String]) {
            guard let values = value as? [Any], values.allSatisfy({ number($0) != nil }) else {
                errors.append("\(path) must be an array of finite numbers.")
                return
            }
            if let count, values.count != count { errors.append("\(path) must contain exactly \(count) values.") }
        }
        func checkBandAxis(_ value: Any?, at path: String, errors: inout [String]) {
            guard let axis = value as? [String: Any] else { errors.append("\(path) must be an object."); return }
            checkObject(axis, at: path, required: ["scale", "centerFrequenciesHz"], allowed: ["scale", "centerFrequenciesHz", "lowerEdgesHz", "upperEdgesHz", "weighting"], errors: &errors)
            checkNumberArray(axis["centerFrequenciesHz"], at: "\(path).centerFrequenciesHz", errors: &errors)
            if axis["lowerEdgesHz"] != nil { checkNumberArray(axis["lowerEdgesHz"], at: "\(path).lowerEdgesHz", errors: &errors) }
            if axis["upperEdgesHz"] != nil { checkNumberArray(axis["upperEdgesHz"], at: "\(path).upperEdgesHz", errors: &errors) }
        }

        for (index, record) in records("coordinateFrames").enumerated() {
            let path = "acoustics.coordinateFrames[\(index)]"
            checkObject(record, at: path, required: ["id", "dimension", "coordinateType", "unit", "handedness", "upAxis", "forwardAxis"], allowed: ["id", "dimension", "coordinateType", "unit", "handedness", "upAxis", "forwardAxis", "crs", "parentFrameId", "transformToParent", "registrationUncertainty", "generatedById", "notes"], errors: &errors)
            checkIdentifier(record["id"], at: "\(path).id", errors: &errors)
            if ![2, 3].contains(Int(integer(record["dimension"]) ?? -1)) { errors.append("\(path).dimension must be 2 or 3.") }
            checkIRI(record["unit"], at: "\(path).unit", errors: &errors)
            if record["crs"] != nil { checkIRI(record["crs"], at: "\(path).crs", errors: &errors) }
            for key in ["parentFrameId", "generatedById"] where record[key] != nil { checkIdentifier(record[key], at: "\(path).\(key)", errors: &errors) }
            if record["transformToParent"] != nil { checkNumberArray(record["transformToParent"], count: 16, at: "\(path).transformToParent", errors: &errors) }
        }

        for (index, record) in records("poses").enumerated() {
            let path = "acoustics.poses[\(index)]"
            checkObject(record, at: path, required: ["id", "subjectId", "frameId", "position"], allowed: ["id", "subjectId", "frameId", "position", "orientationXYZW", "extent", "positionUncertainty", "orientationUncertainty", "configurationId", "stateId", "validFrom", "validUntil", "trajectoryAssetId", "interpolation", "generatedById"], errors: &errors)
            for key in ["id", "subjectId", "frameId", "configurationId", "stateId", "trajectoryAssetId", "generatedById"] where record[key] != nil { checkIdentifier(record[key], at: "\(path).\(key)", errors: &errors) }
            guard let position = record["position"] as? [Any], [2, 3].contains(position.count), position.allSatisfy({ number($0) != nil }) else { errors.append("\(path).position must contain two or three finite numbers."); continue }
            if record["orientationXYZW"] != nil { checkNumberArray(record["orientationXYZW"], count: 4, at: "\(path).orientationXYZW", errors: &errors) }
            if record["extent"] != nil { checkNumberArray(record["extent"], count: 3, at: "\(path).extent", errors: &errors) }
        }

        for (index, record) in records("geometryBindings").enumerated() {
            let path = "acoustics.geometryBindings[\(index)]"
            checkObject(record, at: path, required: ["id", "subjectId", "assetId", "role", "selector"], allowed: ["id", "subjectId", "assetId", "role", "selector", "frameId", "generatedById"], errors: &errors)
            for key in ["id", "subjectId", "assetId", "frameId", "generatedById"] where record[key] != nil { checkIdentifier(record[key], at: "\(path).\(key)", errors: &errors) }
            if let selector = record["selector"] as? [String: Any] {
                checkObject(selector, at: "\(path).selector", required: ["selectorType", "value"], allowed: ["selectorType", "value", "subSelector"], errors: &errors)
            } else { errors.append("\(path).selector must be an object.") }
        }

        for (index, record) in records("materialModels").enumerated() {
            let path = "acoustics.materialModels[\(index)]"
            checkObject(record, at: path, required: ["id", "materialEntityId", "bandAxis", "absorption", "representationStatus", "generatedById"], allowed: ["id", "materialEntityId", "bandAxis", "absorption", "scattering", "transmissionLossDB", "surfaceImpedanceAssetId", "incidence", "sidedness", "thicknessMeters", "environmentStateId", "representationStatus", "uncertainty", "generatedById"], errors: &errors)
            for key in ["id", "materialEntityId", "surfaceImpedanceAssetId", "environmentStateId", "generatedById"] where record[key] != nil { checkIdentifier(record[key], at: "\(path).\(key)", errors: &errors) }
            checkBandAxis(record["bandAxis"], at: "\(path).bandAxis", errors: &errors)
            for key in ["absorption", "scattering", "transmissionLossDB"] where record[key] != nil { checkNumberArray(record[key], at: "\(path).\(key)", errors: &errors) }
        }

        for (index, record) in records("responseSets").enumerated() {
            let path = "acoustics.responseSets[\(index)]"
            checkObject(record, at: path, required: ["id", "responseEntityId", "responseKind", "assetId", "encoding", "representationStatus", "measurements", "generatedById"], allowed: ["id", "responseEntityId", "responseKind", "assetId", "encoding", "convention", "representationStatus", "measurements", "sampleRateHz", "timeZeroPolicy", "delayAssetId", "normalization", "calibrationIds", "channelTopology", "interpolation", "generatedById", "qualityFlags"], errors: &errors)
            for key in ["id", "responseEntityId", "assetId", "delayAssetId", "generatedById"] where record[key] != nil { checkIdentifier(record[key], at: "\(path).\(key)", errors: &errors) }
            guard let measurements = record["measurements"] as? [[String: Any]], !measurements.isEmpty else { errors.append("\(path).measurements must be a non-empty array."); continue }
            for (measurementIndex, measurement) in measurements.enumerated() {
                let measurementPath = "\(path).measurements[\(measurementIndex)]"
                checkObject(measurement, at: measurementPath, required: ["index", "sourceId", "receiverId", "sourcePoseId", "receiverPoseId"], allowed: ["index", "sourceId", "receiverId", "sourcePoseId", "receiverPoseId", "spaceId", "sourceSpaceId", "receivingSpaceId", "separatingElementId", "transmissionPathIds", "configurationId", "stateId", "channelIndices", "validFrom", "validUntil"], errors: &errors)
                for key in ["sourceId", "receiverId", "sourcePoseId", "receiverPoseId", "spaceId", "sourceSpaceId", "receivingSpaceId", "separatingElementId", "configurationId", "stateId"] where measurement[key] != nil { checkIdentifier(measurement[key], at: "\(measurementPath).\(key)", errors: &errors) }
            }
            if let interpolation = record["interpolation"] as? [String: Any] {
                checkObject(interpolation, at: "\(path).interpolation", required: ["method", "domain", "outsideDomainPolicy"], allowed: ["method", "domain", "outsideDomainPolicy", "fallbackResponseSetId", "modelAssetId", "trainingInputIds", "validationInputIds", "qualityMetricSetId", "determinism", "seed"], errors: &errors)
                for key in ["domain", "fallbackResponseSetId", "modelAssetId", "qualityMetricSetId"] where interpolation[key] != nil { checkIdentifier(interpolation[key], at: "\(path).interpolation.\(key)", errors: &errors) }
            }
        }

        for (index, record) in records("metricSets").enumerated() {
            let path = "acoustics.metricSets[\(index)]"
            checkObject(record, at: path, required: ["id", "standard", "standardEdition", "method", "subjectIds", "inputIds", "bandAxis", "metrics", "generatedById"], allowed: ["id", "standard", "standardEdition", "method", "subjectIds", "inputIds", "bandAxis", "metrics", "generatedById", "qualityFlags"], errors: &errors)
            for key in ["id", "generatedById"] { checkIdentifier(record[key], at: "\(path).\(key)", errors: &errors) }
            checkIRI(record["standard"], at: "\(path).standard", errors: &errors)
            checkIdentifierArray(record["subjectIds"], at: "\(path).subjectIds", nonEmpty: true, errors: &errors)
            checkIdentifierArray(record["inputIds"], at: "\(path).inputIds", nonEmpty: true, errors: &errors)
            checkBandAxis(record["bandAxis"], at: "\(path).bandAxis", errors: &errors)
            guard let metrics = record["metrics"] as? [[String: Any]], !metrics.isEmpty else { errors.append("\(path).metrics must be a non-empty array."); continue }
            for (metricIndex, metric) in metrics.enumerated() {
                let metricPath = "\(path).metrics[\(metricIndex)]"
                checkObject(metric, at: metricPath, required: ["property", "values", "unit", "status"], allowed: ["property", "values", "unit", "uncertainties", "status", "sourceId", "receiverId", "sourceSpaceId", "receivingSpaceId", "separatingElementId"], errors: &errors)
                checkIRI(metric["property"], at: "\(metricPath).property", errors: &errors)
                checkIRI(metric["unit"], at: "\(metricPath).unit", errors: &errors)
                checkNumberArray(metric["values"], at: "\(metricPath).values", errors: &errors)
            }
        }

        for (index, record) in records("audioScenes").enumerated() {
            let path = "acoustics.audioScenes[\(index)]"
            checkObject(record, at: path, required: ["id", "sceneEntityId", "representationType", "coordinateFrameId", "mediaAssetIds", "bindings"], allowed: ["id", "sceneEntityId", "representationType", "standard", "coordinateFrameId", "mediaAssetIds", "metadataAssetId", "bindings", "contentTimebase", "generatedById"], errors: &errors)
            for key in ["id", "sceneEntityId", "coordinateFrameId", "metadataAssetId", "generatedById"] where record[key] != nil { checkIdentifier(record[key], at: "\(path).\(key)", errors: &errors) }
            checkIdentifierArray(record["mediaAssetIds"], at: "\(path).mediaAssetIds", nonEmpty: true, errors: &errors)
            guard let bindings = record["bindings"] as? [[String: Any]], !bindings.isEmpty else { errors.append("\(path).bindings must be a non-empty array."); continue }
            for (bindingIndex, binding) in bindings.enumerated() {
                let bindingPath = "\(path).bindings[\(bindingIndex)]"
                checkObject(binding, at: bindingPath, required: ["id", "entityId", "mediaAssetId", "bindingType"], allowed: ["id", "entityId", "mediaAssetId", "bindingType", "channelIndices", "poseId", "gainDB", "directivityResponseSetId"], errors: &errors)
                for key in ["id", "entityId", "mediaAssetId", "poseId", "directivityResponseSetId"] where binding[key] != nil { checkIdentifier(binding[key], at: "\(bindingPath).\(key)", errors: &errors) }
            }
        }

        for (index, record) in records("renderConfigurations").enumerated() {
            let path = "acoustics.renderConfigurations[\(index)]"
            checkObject(record, at: path, required: ["id", "sceneId", "strategy", "coordinateFrameId", "inputIds", "listener", "features", "outsideDomainPolicy", "fallbackIds"], allowed: ["id", "sceneId", "strategy", "coordinateFrameId", "inputIds", "listener", "features", "validDomainId", "outsideDomainPolicy", "fallbackIds", "transitionSeconds", "latencyBudgetMilliseconds", "levelsOfDetail", "rendererRequirements"], errors: &errors)
            for key in ["id", "sceneId", "coordinateFrameId", "validDomainId"] where record[key] != nil { checkIdentifier(record[key], at: "\(path).\(key)", errors: &errors) }
            checkIdentifierArray(record["inputIds"], at: "\(path).inputIds", nonEmpty: true, errors: &errors)
            checkIdentifierArray(record["fallbackIds"], at: "\(path).fallbackIds", nonEmpty: false, errors: &errors)
            if let listener = record["listener"] as? [String: Any] {
                checkObject(listener, at: "\(path).listener", required: ["mode", "receiverId", "coordinateFrameId"], allowed: ["mode", "receiverId", "coordinateFrameId", "poseId", "trajectoryAssetId", "personalizationAssetId", "headphoneCompensationAssetId"], errors: &errors)
                for key in ["receiverId", "coordinateFrameId", "poseId", "trajectoryAssetId", "personalizationAssetId", "headphoneCompensationAssetId"] where listener[key] != nil { checkIdentifier(listener[key], at: "\(path).listener.\(key)", errors: &errors) }
            } else { errors.append("\(path).listener must be an object.") }
        }
    }

    private static func checkRights(_ value: Any?, errors: inout [String]) {
        guard let records = value as? [[String: Any]], !records.isEmpty else { errors.append("Manifest rights must be a non-empty array."); return }
        for (index, record) in records.enumerated() {
            let path = "rights[\(index)]"
            checkObject(record, at: path, required: ["appliesToIds", "statement"], allowed: ["appliesToIds", "license", "rightsHolderId", "statement", "accessCondition", "creditLine"], errors: &errors)
            checkIdentifierArray(record["appliesToIds"], at: "\(path).appliesToIds", nonEmpty: true, errors: &errors)
            checkLocalized(record["statement"], at: "\(path).statement", errors: &errors)
            if record["license"] != nil { checkIRI(record["license"], at: "\(path).license", errors: &errors) }
            if record["rightsHolderId"] != nil { checkIdentifier(record["rightsHolderId"], at: "\(path).rightsHolderId", errors: &errors) }
        }
    }

    private static func checkIntegrity(_ value: Any?, errors: inout [String]) {
        guard let record = value as? [String: Any] else { errors.append("integrity must be an object."); return }
        checkObject(record, at: "integrity", required: ["algorithm", "assetCount", "totalPayloadBytes"], allowed: ["algorithm", "assetCount", "totalPayloadBytes", "payloadMerkleRoot", "signatureProfile"], errors: &errors)
        if record["algorithm"] as? String != "sha256" { errors.append("integrity.algorithm must be sha256.") }
        checkNonnegativeInteger(record["assetCount"], at: "integrity.assetCount", errors: &errors)
        checkNonnegativeInteger(record["totalPayloadBytes"], at: "integrity.totalPayloadBytes", errors: &errors)
        if let digest = record["payloadMerkleRoot"] as? String, !isSHA256(digest, lowercaseOnly: true) { errors.append("integrity.payloadMerkleRoot must be a lowercase SHA-256 digest.") }
        if record["signatureProfile"] != nil { checkIRI(record["signatureProfile"], at: "integrity.signatureProfile", errors: &errors) }
    }

    private static func checkObject(_ object: [String: Any], at path: String, required: Set<String>, allowed: Set<String>, errors: inout [String]) {
        for key in required where object[key] == nil { errors.append("\(path) is missing required property \(key).") }
        for key in Set(object.keys).subtracting(allowed).sorted() { errors.append("\(path) contains unknown property \(key).") }
    }

    private static func checkLocalized(_ value: Any?, at path: String, errors: inout [String]) {
        guard let map = value as? [String: Any], !map.isEmpty else { errors.append("\(path) must be a non-empty localized-text object."); return }
        for (language, text) in map {
            if language.range(of: "^(und|[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*)$", options: .regularExpression) == nil { errors.append("\(path) contains invalid language tag \(language).") }
            if (text as? String)?.isEmpty != false { errors.append("\(path).\(language) must be a non-empty string.") }
        }
    }

    private static func checkIRIProperties(_ value: Any, at path: String, errors: inout [String]) {
        guard let map = value as? [String: Any] else { errors.append("\(path) must be an object."); return }
        for key in map.keys where !isIRI(key) { errors.append("\(path) contains a property name that is not an absolute IRI: \(key).") }
    }

    private static func checkIRIArray(_ value: Any?, at path: String, nonEmpty: Bool, errors: inout [String]) {
        guard let values = value as? [String] else { errors.append("\(path) must be an array of IRIs."); return }
        if nonEmpty && values.isEmpty { errors.append("\(path) must not be empty.") }
        if Set(values).count != values.count { errors.append("\(path) must contain unique values.") }
        for value in values where !isIRI(value) { errors.append("\(path) contains an invalid IRI: \(value).") }
    }

    private static func checkIdentifierArray(_ value: Any?, at path: String, nonEmpty: Bool, errors: inout [String]) {
        guard let values = value as? [String] else { errors.append("\(path) must be an array of identifiers."); return }
        if nonEmpty && values.isEmpty { errors.append("\(path) must not be empty.") }
        if Set(values).count != values.count { errors.append("\(path) must contain unique values.") }
        for value in values where !isIdentifier(value) { errors.append("\(path) contains an invalid identifier: \(value).") }
    }

    private static func checkIdentifierArrayIfPresent(_ value: Any?, at path: String, errors: inout [String]) {
        guard value != nil else { return }
        checkIdentifierArray(value, at: path, nonEmpty: false, errors: &errors)
    }

    private static func checkIRI(_ value: Any?, at path: String, errors: inout [String]) {
        guard let value = value as? String, isIRI(value) else { errors.append("\(path) must be an absolute IRI."); return }
    }

    private static func checkIdentifier(_ value: Any?, at path: String, errors: inout [String]) {
        guard let value = value as? String, isIdentifier(value) else { errors.append("\(path) must be a VAO identifier."); return }
    }

    private static func checkPositiveInteger(_ value: Any?, at path: String, errors: inout [String]) {
        guard let value = integer(value), value >= 1 else { errors.append("\(path) must be a positive integer."); return }
    }

    private static func checkNonnegativeInteger(_ value: Any?, at path: String, errors: inout [String]) {
        guard let value = integer(value), value >= 0 else { errors.append("\(path) must be a non-negative integer."); return }
    }

    private static func isIRI(_ value: String) -> Bool {
        guard value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let components = URLComponents(string: value),
              let scheme = components.scheme, !scheme.isEmpty else { return false }
        return true
    }

    private static func isIdentifier(_ value: String) -> Bool {
        value.count >= 3 && (value.hasPrefix("urn:") || value.hasPrefix("http://") || value.hasPrefix("https://")) && value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }

    private static func isSHA256(_ value: String, lowercaseOnly: Bool) -> Bool {
        let pattern = lowercaseOnly ? "^[0-9a-f]{64}$" : "^[0-9a-fA-F]{64}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isSafePayloadPath(_ path: String) -> Bool {
        guard path.hasPrefix("payload/"), !path.contains("\\"), !path.contains("\0"), !path.hasPrefix("/") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func integer(_ value: Any?) -> Int64? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double.rounded() == double, double >= Double(Int64.min), double <= Double(Int64.max) else { return nil }
        return number.int64Value
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite else { return nil }
        return number.doubleValue
    }
}
