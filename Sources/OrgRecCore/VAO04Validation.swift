import CryptoKit
import Foundation

public enum VAO04Validator {
    public static func validateManifest(data: Data) -> [String] {
        let manifest: VAO04Manifest
        do { manifest = try JSONDecoder().decode(VAO04Manifest.self, from: data) }
        catch { return ["VAO 0.4.0 manifest cannot be decoded: \(error.localizedDescription)"] }
        var errors = validateManifest(manifest)
        guard var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            errors.append("VAO 0.4.0 manifest is not a JSON object."); return Array(Set(errors)).sorted()
        }
        let allowed: Set<String> = [
            "$schema", "@context", "type", "formatVersion", "id", "release", "createdAt", "modifiedAt", "title", "description",
            "conformsTo", "profiles", "materializableProfiles", "modavisBinding", "primaryEntityId", "focusEntityIds", "entities", "relations",
            "scientific", "multimodal", "physicalSystem", "runtime", "discovery", "acoustics", "playable", "interactionModel", "captureDocumentation",
            "logicalAssets", "realizations", "distributions", "repositoryBindings", "assetGroups", "rights", "integrity", "extensions",
        ]
        for key in Set(root.keys).subtracting(allowed).sorted() { errors.append("Manifest contains unknown root property \(key).") }
        if let projected = project03(root: &root), let data = try? JSONSerialization.data(withJSONObject: projected) {
            errors.append(contentsOf: VAO03Validator.validateManifest(data: data).map {
                $0.replacingOccurrences(of: "VAO 0.3", with: "VAO 0.4.0")
            })
        } else { errors.append("VAO 0.4.0 could not be projected into retained core semantic checks.") }
        return Array(Set(errors)).sorted()
    }

    private static func project03(root: inout [String: Any]) -> [String: Any]? {
        root["$schema"] = VAO03Contract.schemaURI
        root["formatVersion"] = VAO03Contract.formatVersion
        root["@context"] = (root["@context"] as? [String] ?? []).map { $0 == VAO04Contract.contextURI ? VAO03Contract.contextURI : $0 }
        func profile03(_ value: String) -> String {
            value.hasPrefix("https://w3id.org/modavis/vao/profile/") && value.hasSuffix("/0.4.0")
                ? String(value.dropLast(5)) + "0.3" : value
        }
        root["conformsTo"] = (root["conformsTo"] as? [String] ?? []).map(profile03)
        for name in ["profiles", "materializableProfiles"] {
            root[name] = (root[name] as? [[String: Any]] ?? []).map { record in
                var result = record; if let id = result["id"] as? String { result["id"] = profile03(id) }; result["version"] = "0.3"; return result
            }
        }
        let scientific = root.removeValue(forKey: "scientific") as? [String: Any] ?? [:]
        func records(_ names: [String]) -> [[String: Any]] { names.flatMap { scientific[$0] as? [[String: Any]] ?? [] } }
        root["paradata"] = records(["agents", "activities", "observations", "calibrations", "protocols", "softwareEnvironments", "consents"])
        root["analyses"] = records(["analyses", "claims", "reviews"])
        for key in ["multimodal", "physicalSystem", "runtime", "discovery"] { root.removeValue(forKey: key) }
        let allowedTechnical: Set<String> = ["kind", "sampleRate", "sampleFormat", "bitDepth", "channelCount", "frameCount", "channelLabels", "audioContainer", "ambisonicsOrder", "ambisonicsDimensionality", "ambisonicsChannelOrder", "ambisonicsNormalization", "impulseResponse", "coordinateFrameId", "coordinateUnit", "handedness", "upAxis", "lod", "triangleCount", "vertexCount", "textureMaxDimension", "purposeLimitations", "extensions"]
        root["realizations"] = (root["realizations"] as? [[String: Any]] ?? []).map { item in
            var result = item
            for key in ["contentDigests", "chunking", "streamingIndexRealizationId", "authenticityEnvelopeRealizationId"] { result.removeValue(forKey: key) }
            if var technical = result["technicalMetadata"] as? [String: Any] {
                let retainedKinds = Set(["audio", "geometry", "image", "document", "data", "software", "other"])
                if let kind = technical["kind"] as? String, !retainedKinds.contains(kind) { technical["kind"] = "data" }
                technical = technical.filter { allowedTechnical.contains($0.key) }; result["technicalMetadata"] = technical
            }
            return result
        }
        let allowedRights: Set<String> = ["id", "appliesToIds", "license", "statement", "access", "attribution"]
        root["rights"] = (root["rights"] as? [[String: Any]] ?? []).map { $0.filter { allowedRights.contains($0.key) } }
        if var integrity = root["integrity"] as? [String: Any] { integrity.removeValue(forKey: "schemaBundleDigest"); integrity.removeValue(forKey: "signatureEnvelopeRealizationId"); root["integrity"] = integrity }
        if var model = root["interactionModel"] as? [String: Any] {
            model.removeValue(forKey: "executionSemantics"); model.removeValue(forKey: "randomSources")
            let allowedBinding: Set<String> = ["id", "controlId", "eventTypeId", "protocol", "direction", "messageType", "channel", "number", "channelNumberingBase", "dataNumberingBase", "address", "activationValue", "deactivationValue", "status", "source", "generatedById", "reviewedById", "sourceLocator"]
            model["protocolBindings"] = (model["protocolBindings"] as? [[String: Any]] ?? []).map { $0.filter { allowedBinding.contains($0.key) } }
            model["routingRules"] = (model["routingRules"] as? [[String: Any]] ?? []).map { item in
                var result = item; let delayed = result.removeValue(forKey: "delayConstraintId") != nil
                if delayed, ["copies", "transposes"].contains(result["routingBehavior"] as? String ?? "") { result["routingBehavior"] = "activates" }
                return result
            }
            model["processModels"] = (model["processModels"] as? [[String: Any]] ?? []).map { item in var result = item; result.removeValue(forKey: "randomSourceId"); result.removeValue(forKey: "probabilityDistribution"); return result }
            model["transferFunctions"] = (model["transferFunctions"] as? [[String: Any]] ?? []).map { item in
                var result = item; for key in ["inputKinds", "validDomain", "extrapolationPolicy", "hysteresis", "dynamicModel", "fitResidual"] { result.removeValue(forKey: key) }
                result["points"] = (result["points"] as? [[String: Any]] ?? []).map { point in var value = point; value.removeValue(forKey: "inputs"); value.removeValue(forKey: "uncertainty"); return value }; return result
            }
            root["interactionModel"] = model
        }
        return root
    }

    public static func validateManifest(_ manifest: VAO04Manifest) -> [String] {
        var errors: [String] = []
        if manifest.schema != VAO04Contract.schemaURI { errors.append("Manifest uses the wrong immutable VAO 0.4.0 schema IRI.") }
        if !manifest.context.contains(VAO04Contract.contextURI) { errors.append("Manifest lacks the immutable VAO 0.4.0 context IRI.") }
        if manifest.formatVersion != VAO04Contract.formatVersion { errors.append("Manifest formatVersion must be 0.4.0.") }
        if manifest.type != "VirtualAcousticObject" { errors.append("Manifest type must be VirtualAcousticObject.") }
        let profiles = Set(manifest.profiles.map(\.id)), conforms = Set(manifest.conformsTo)
        for profile in [VAO04Contract.coreProfile, VAO04Contract.dynamicDeliveryProfile] where !profiles.contains(profile) || !conforms.contains(profile) {
            errors.append("Every VAO 0.4.0 release must embed and claim \(profile).")
        }

        let entityIDs = Set(manifest.entities.map(\.id)); let realizationIDs = Set(manifest.realizations.map(\.id))
        let agentIDs = Set(manifest.scientific.agents.map(\.id)); let activityIDs = Set(manifest.scientific.activities.map(\.id))
        let protocolIDs = Set(manifest.scientific.protocols.map(\.id)); let environmentIDs = Set(manifest.scientific.softwareEnvironments.map(\.id))
        let calibrationIDs = Set(manifest.scientific.calibrations.map(\.id)); let consentIDs = Set(manifest.scientific.consents.map(\.id))
        var known = entityIDs.union(realizationIDs).union(manifest.logicalAssets.map(\.id)).union(manifest.relations.map(\.id))
            .union(manifest.distributions.map(\.id)).union(manifest.repositoryBindings.map(\.id)).union(manifest.assetGroups.map(\.id))
            .union(manifest.rights.map(\.id)).union(agentIDs).union(activityIDs).union(protocolIDs).union(environmentIDs).union(calibrationIDs)
            .union(manifest.scientific.observations.map(\.id)).union(manifest.scientific.analyses.map(\.id)).union(manifest.scientific.claims.map(\.id))
            .union(manifest.scientific.reviews.map(\.id)).union(consentIDs)
        known.insert(manifest.id); known.insert(manifest.release.id)

        for activity in manifest.scientific.activities {
            if activity.endedAt < activity.startedAt { errors.append("Activity \(activity.id) ends before it starts.") }
            for id in activity.agentIds where !agentIDs.contains(id) { errors.append("Activity \(activity.id) has unresolved agent \(id).") }
            if !protocolIDs.contains(activity.protocolId) { errors.append("Activity \(activity.id) has unresolved protocolId.") }
            if let id = activity.softwareEnvironmentId, !environmentIDs.contains(id) { errors.append("Activity \(activity.id) has unresolved softwareEnvironmentId.") }
            for id in activity.inputIds + activity.outputIds where !known.contains(id) { errors.append("Activity \(activity.id) has unresolved input/output \(id).") }
        }
        for observation in manifest.scientific.observations {
            if !known.contains(observation.featureOfInterestId) || !activityIDs.contains(observation.activityId) || !protocolIDs.contains(observation.protocolId) { errors.append("Observation \(observation.id) has unresolved scientific references.") }
            if let id = observation.calibrationId, !calibrationIDs.contains(id) { errors.append("Observation \(observation.id) has unresolved calibrationId.") }
        }
        let randomIDs = Set(manifest.runtime.randomSources.map(\.id) + (manifest.interactionModel?.randomSources?.map(\.id) ?? []))
        for analysis in manifest.scientific.analyses {
            if !activityIDs.contains(analysis.activityId) || !environmentIDs.contains(analysis.softwareEnvironmentId) { errors.append("Analysis \(analysis.id) has unresolved activity or software environment.") }
            if analysis.reproducibility == "seeded", analysis.randomSourceId.map(randomIDs.contains) != true { errors.append("Seeded analysis \(analysis.id) requires a declared random source.") }
        }
        for consent in manifest.scientific.consents {
            if !agentIDs.contains(consent.grantedByAgentId) { errors.append("Consent \(consent.id) has unresolved granting Agent.") }
            for id in consent.appliesToIds where !known.contains(id) { errors.append("Consent \(consent.id) has unresolved subject \(id).") }
        }
        for claim in manifest.scientific.claims where (claim.objectId == nil) == (claim.literal == nil) { errors.append("Claim \(claim.id) requires exactly one of objectId or literal.") }

        let timebaseIDs = Set(manifest.multimodal.timebases.map(\.id)); let trackIDs = Set(manifest.multimodal.tracks.map(\.id))
        for track in manifest.multimodal.tracks where !timebaseIDs.contains(track.timebaseId) || !realizationIDs.contains(track.realizationId) { errors.append("Track \(track.id) has an unresolved timebase or realization.") }
        for mapping in manifest.multimodal.synchronizationMappings {
            if !timebaseIDs.contains(mapping.sourceTimebaseId) || !timebaseIDs.contains(mapping.targetTimebaseId) || mapping.sourceTimebaseId == mapping.targetTimebaseId { errors.append("Synchronization mapping \(mapping.id) has invalid timebase references.") }
            var prior: Double?
            for segment in mapping.segments {
                if segment.sourceEndExclusive <= segment.sourceStart || prior.map({ segment.sourceStart < $0 }) == true { errors.append("Synchronization mapping \(mapping.id) has an empty or overlapping segment.") }
                prior = segment.sourceEndExclusive
            }
        }
        for annotation in manifest.multimodal.annotations where !trackIDs.contains(annotation.target.trackId) { errors.append("Annotation \(annotation.id) has unresolved trackId.") }

        let componentIDs = Set(manifest.physicalSystem.components.map(\.id)); let portIDs = Set(manifest.physicalSystem.ports.map(\.id))
        for component in manifest.physicalSystem.components where !entityIDs.contains(component.entityId) { errors.append("Physical component \(component.id) has unresolved entityId.") }
        for port in manifest.physicalSystem.ports where !componentIDs.contains(port.componentId) { errors.append("Physical port \(port.id) has unresolved componentId.") }
        for connection in manifest.physicalSystem.connections where !portIDs.contains(connection.sourcePortId) || !portIDs.contains(connection.targetPortId) { errors.append("Physical connection \(connection.id) has an unresolved port.") }
        for sensor in manifest.physicalSystem.sensors where !componentIDs.contains(sensor.componentId) || !portIDs.contains(sensor.outputPortId) || !protocolIDs.contains(sensor.protocolId) { errors.append("Sensor \(sensor.id) has unresolved topology or protocol.") }
        for actuator in manifest.physicalSystem.actuators where !componentIDs.contains(actuator.componentId) || !portIDs.contains(actuator.inputPortId) || !protocolIDs.contains(actuator.protocolId) { errors.append("Actuator \(actuator.id) has unresolved topology or protocol.") }

        if let model = manifest.interactionModel {
            let timingIDs = Set(model.timingConstraints.map(\.id))
            for binding in model.protocolBindings where binding.protocolName == "MIDI-2.0" {
                if binding.umpGroup == nil || binding.functionBlock == nil || binding.umpMessageType == nil || binding.dataResolutionBits == nil || binding.jrTimestamp != true { errors.append("MIDI 2.0 binding \(binding.id) lacks UMP/function-block/resolution/JR semantics.") }
            }
            for process in model.processModels where process.processKind == "stochastic" {
                if process.randomSourceId.map(randomIDs.contains) != true || process.probabilityDistribution == nil { errors.append("Stochastic process \(process.id) is not reproducible.") }
            }
            var zeroDelay: [String: [String]] = [:]
            for route in model.routingRules {
                if let delay = route.delayConstraintId, !timingIDs.contains(delay) { errors.append("Routing rule \(route.id) has unresolved delayConstraintId.") }
                if ["copies", "transposes"].contains(route.routingBehavior), route.delayConstraintId == nil { zeroDelay[route.sourceEntityId, default: []].append(route.targetEntityId); zeroDelay[route.targetEntityId, default: []] += [] }
            }
            findCycles(zeroDelay, errors: &errors)
        }
        for trace in manifest.runtime.conformanceTraces { errors.append(contentsOf: VAO04RuntimeEngine.verify(trace: trace, manifest: manifest)) }

        for realization in manifest.realizations {
            if let digest = realization.contentDigests?.first(where: { $0.algorithm == "sha256" }), digest.value != realization.sha256 { errors.append("Realization \(realization.id) has conflicting SHA-256 identities.") }
            if let chunking = realization.chunking, !chunking.chunks.isEmpty {
                let chunks = chunking.chunks.sorted { $0.index < $1.index }; var offset: Int64 = 0
                if chunks.map(\.index) != Array(0..<chunks.count) { errors.append("Realization \(realization.id) has non-contiguous chunk indices.") }
                for chunk in chunks { if chunk.offset != offset { errors.append("Realization \(realization.id) has non-contiguous chunks.") }; offset = chunk.offset + chunk.length }
                if offset != realization.byteSize { errors.append("Realization \(realization.id) chunk coverage does not equal byteSize.") }
                if let root = chunking.merkleRoot {
                    if Set(chunks.map { $0.digest.algorithm }) != Set([root.algorithm]) { errors.append("Realization \(realization.id) Merkle root and chunk algorithms differ.") }
                    else if merkleRoot(chunks: chunks, algorithm: root.algorithm) != root.value { errors.append("Realization \(realization.id) has an invalid Merkle root.") }
                }
            }
        }
        for rights in manifest.rights {
            for id in rights.performerAgentIds ?? [] where !agentIDs.contains(id) { errors.append("Rights record \(rights.id) has unresolved performer Agent.") }
            for id in rights.consentIds ?? [] where !consentIDs.contains(id) { errors.append("Rights record \(rights.id) has unresolved consent.") }
            if rights.privacyClassification == "community-governed", rights.communityAuthorityIds?.isEmpty != false { errors.append("Community-governed rights record \(rights.id) requires an authority.") }
        }
        for id in manifest.discovery.creatorAgentIds where !agentIDs.contains(id) { errors.append("Discovery creatorAgentId \(id) does not resolve to an Agent.") }
        return Array(Set(errors)).sorted()
    }

    private static func findCycles(_ edges: [String: [String]], errors: inout [String]) {
        var visiting: Set<String> = [], visited: Set<String> = []
        func visit(_ node: String) {
            if visiting.contains(node) { errors.append("Zero-delay routing graph contains an instantaneous cycle at \(node)."); return }
            if visited.contains(node) { return }; visiting.insert(node)
            for target in edges[node] ?? [] where edges[target] != nil { visit(target) }
            visiting.remove(node); visited.insert(node)
        }
        for node in edges.keys { visit(node) }
    }

    private static func digest(_ data: Data, algorithm: String) -> Data? {
        if algorithm == "sha256" { return Data(SHA256.hash(data: data)) }
        if algorithm == "sha512" { return Data(SHA512.hash(data: data)) }
        return nil
    }

    private static func merkleRoot(chunks: [VAO04Chunk], algorithm: String) -> String? {
        var level = chunks.compactMap { chunk -> Data? in
            guard let bytes = Data(lowercaseHex: chunk.digest.value) else { return nil }
            return digest(Data([0]) + bytes, algorithm: algorithm)
        }
        guard level.count == chunks.count, !level.isEmpty else { return nil }
        while level.count > 1 {
            if level.count % 2 == 1 { level.append(level.last!) }
            var next: [Data] = []
            for index in stride(from: 0, to: level.count, by: 2) {
                guard let value = digest(Data([1]) + level[index] + level[index + 1], algorithm: algorithm) else { return nil }
                next.append(value)
            }
            level = next
        }
        return level[0].map { String(format: "%02x", $0) }.joined()
    }
}

private extension Data {
    init?(lowercaseHex value: String) {
        guard value.count.isMultiple(of: 2), value.allSatisfy({ $0.isNumber || ("a"..."f").contains(String($0)) }) else { return nil }
        var bytes: [UInt8] = []; bytes.reserveCapacity(value.count / 2); var index = value.startIndex
        while index < value.endIndex { let end = value.index(index, offsetBy: 2); guard let byte = UInt8(value[index..<end], radix: 16) else { return nil }; bytes.append(byte); index = end }
        self.init(bytes)
    }
}
