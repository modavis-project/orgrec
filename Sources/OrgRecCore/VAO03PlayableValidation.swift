import Foundation

/// Semantic validation for the VAO 0.3 Playable profile. JSON Schema closes
/// every record; this validator checks registry references, frame bounds, and
/// the evidence-state rules that cannot be expressed reliably in JSON Schema.
enum VAO03PlayableValidator {
    static let capabilityBase = "https://w3id.org/modavis/vao/vocab/capability/"
    static let interactionCapability = capabilityBase + "interaction"
    static let playableInteractionCapability = capabilityBase + "playable-interaction"
    static let sampledInstrumentPlaybackCapability = capabilityBase + "sampled-instrument-playback"
    static let sampleLoopingCapability = capabilityBase + "sample-looping"
    static let tuningMapCapability = capabilityBase + "tuning-map"
    static let multiPerspectiveCapability = capabilityBase + "multi-perspective-sampling"
    static let recordedReleaseCapability = capabilityBase + "recorded-release"
    static let sourceSamplerSemanticsCapability = capabilityBase + "source-sampler-semantics"

    static let standardCapabilities: Set<String> = [
        interactionCapability,
        playableInteractionCapability,
        sampledInstrumentPlaybackCapability,
        sampleLoopingCapability,
        tuningMapCapability,
        multiPerspectiveCapability,
        recordedReleaseCapability,
        sourceSamplerSemanticsCapability,
        VAO03ComplexInteractionValidator.statefulInteractionCapability,
        VAO03ComplexInteractionValidator.conditionalRoutingCapability,
        VAO03ComplexInteractionValidator.compositeActuationCapability,
        VAO03ComplexInteractionValidator.timedProcessCapability,
        VAO03ComplexInteractionValidator.actuatorTransferCapability,
        VAO03ComplexInteractionValidator.captureEventAlignmentCapability,
    ]

    static func identifiers(in playable: VAO03Playable?) -> [String] {
        guard let playable else { return [] }
        return playable.signalRegions.map(\.id)
            + playable.loopPointSets.map(\.id)
            + playable.tuningMaps.map(\.id)
            + playable.perspectiveGroups.map(\.id)
            + playable.sampleVariants.map(\.id)
            + playable.sampleMappings.map(\.id)
    }

    static func validate(
        manifest: VAO03Manifest,
        entities: [String: VAO03Entity],
        realizations: [String: VAO03Realization],
        errors: inout [String]
    ) {
        let profileRecords = manifest.profiles + manifest.materializableProfiles.map {
            VAO03Profile(id: $0.id, version: $0.version, requiredCapabilities: $0.requiredCapabilities)
        }
        let playableProfiles = profileRecords.filter { $0.id == VAO03Contract.playableProfile }
        let profileIDs = Set(profileRecords.map(\.id))
        let declaresProfile = !playableProfiles.isEmpty
        let capabilities = Set(playableProfiles.flatMap(\.requiredCapabilities))

        if declaresProfile {
            if !manifest.conformsTo.contains(VAO03Contract.playableProfile) {
                errors.append("The Playable 0.3 profile record must also appear in conformsTo.")
            }
            if capabilities.isDisjoint(with: [interactionCapability, playableInteractionCapability]) {
                errors.append("The Playable 0.3 profile requires an interaction capability.")
            }
            let interactions = manifest.entities.filter { $0.kind == "interaction" }
            if interactions.isEmpty {
                errors.append("The Playable 0.3 profile requires at least one interaction entity.")
            }
            let ontology = "https://w3id.org/modavis/vao/ontology#"
            let outgoing = Set([ontology + "activates", ontology + "modulates"])
            for interaction in interactions {
                let properties = interaction.properties ?? [:]
                for localName in ["interactionType", "controlProtocol", "controlDomain", "timingPolicy"]
                where properties[ontology + localName] == nil {
                    errors.append("Playable interaction \(interaction.id) is missing \(localName).")
                }
                if !manifest.relations.contains(where: {
                    $0.subjectId == interaction.id
                        && outgoing.contains($0.predicate)
                        && $0.status != "rejected" && $0.status != "superseded"
                }) {
                    errors.append("Playable interaction \(interaction.id) has no active activates/modulates relation.")
                }
            }
        } else if manifest.playable != nil {
            errors.append("A playable object requires a Playable 0.3 profile claim.")
        }
        let sampleCapabilities: Set<String> = [
            sampledInstrumentPlaybackCapability, sampleLoopingCapability, tuningMapCapability,
            multiPerspectiveCapability, recordedReleaseCapability, sourceSamplerSemanticsCapability,
        ]
        if !capabilities.intersection(sampleCapabilities).isEmpty
            && !capabilities.contains(sampledInstrumentPlaybackCapability) {
            errors.append("Playable sample sub-capabilities require sampled-instrument-playback.")
        }
        if capabilities.contains(sampledInstrumentPlaybackCapability) && manifest.playable == nil {
            errors.append("The sampled-instrument-playback capability requires the closed top-level playable object.")
        }
        guard let playable = manifest.playable else { return }

        let regions = indexed(playable.signalRegions, key: \.id)
        let loops = indexed(playable.loopPointSets, key: \.id)
        let tunings = indexed(playable.tuningMaps, key: \.id)
        let perspectives = indexed(playable.perspectiveGroups, key: \.id)
        let variants = indexed(playable.sampleVariants, key: \.id)

        let activityIDs = Set((manifest.paradata + manifest.analyses).compactMap {
            $0.objectValue?["id"]?.stringValue
        })
        let acousticPoseIDs = Set(
            manifest.acoustics?.objectValue?["poses"]?.arrayValue?.compactMap {
                $0.objectValue?["id"]?.stringValue
            } ?? []
        )
        let knownGeneratedByIDs = activityIDs.union(Set(manifest.relations.map(\.id)))

        func validateEvidence(id: String, status: String, source: String, generatedByID: String?) {
            if (status == "inferred" || source == "algorithmic") && generatedByID == nil {
                errors.append("Playable record \(id) is inferred or algorithmic but lacks generatedById.")
            }
            if let generatedByID, !knownGeneratedByIDs.contains(generatedByID) {
                errors.append("Playable record \(id) has unresolved generatedById \(generatedByID).")
            }
            if source == "algorithmic" && status == "asserted" {
                errors.append("Playable record \(id) cannot describe algorithmic output as asserted source metadata.")
            }
        }

        for region in playable.signalRegions {
            validateEvidence(id: region.id, status: region.status, source: region.source, generatedByID: region.generatedById)
            guard let realization = realizations[region.realizationId] else {
                errors.append("Signal region \(region.id) has unresolved realizationId.")
                continue
            }
            if realization.technicalMetadata.kind != "audio" {
                errors.append("Signal region \(region.id) must reference an audio realization.")
            }
            if region.endFrameExclusive <= region.startFrameInclusive {
                errors.append("Signal region \(region.id) has an empty or reversed half-open frame range.")
            }
            if let frameCount = realization.technicalMetadata.frameCount,
               region.endFrameExclusive > frameCount {
                errors.append("Signal region \(region.id) exceeds the realization frameCount.")
            }
        }

        for loop in playable.loopPointSets {
            validateEvidence(id: loop.id, status: loop.status, source: loop.source, generatedByID: loop.generatedById)
            let resolved = loop.regionIds.compactMap { regions[$0] }
            for id in loop.regionIds where regions[id] == nil {
                errors.append("Loop-point set \(loop.id) has unresolved region \(id).")
            }
            if resolved.contains(where: { $0.role != "sustain-loop" }) {
                errors.append("Every region in loop-point set \(loop.id) must have role sustain-loop.")
            }
            if Set(resolved.map(\.realizationId)).count > 1 {
                errors.append("Loop-point set \(loop.id) spans more than one realization.")
            }
            if let crossfade = loop.crossfadeFrames,
               let shortest = resolved.map({ $0.endFrameExclusive - $0.startFrameInclusive }).min(),
               crossfade > shortest {
                errors.append("Loop-point set \(loop.id) has a crossfade longer than a loop region.")
            }
            if let reviewedByID = loop.reviewedById, !knownGeneratedByIDs.contains(reviewedByID) {
                errors.append("Loop-point set \(loop.id) has unresolved reviewedById \(reviewedByID).")
            }
        }

        for tuning in playable.tuningMaps {
            validateEvidence(id: tuning.id, status: tuning.status, source: tuning.source, generatedByID: tuning.generatedById)
            if Set(tuning.entries.map(\.key)).count != tuning.entries.count {
                errors.append("Tuning map \(tuning.id) contains duplicate MIDI keys.")
            }
        }

        for perspective in playable.perspectiveGroups {
            validateEvidence(id: perspective.id, status: perspective.status, source: perspective.source, generatedByID: perspective.generatedById)
            for realizationID in perspective.realizationIds {
                guard let realization = realizations[realizationID] else {
                    errors.append("Perspective group \(perspective.id) has unresolved realization \(realizationID).")
                    continue
                }
                if realization.technicalMetadata.kind != "audio" {
                    errors.append("Perspective group \(perspective.id) must reference audio realizations.")
                }
                if let indices = perspective.channelIndices,
                   let channelCount = realization.technicalMetadata.channelCount,
                   indices.contains(where: { $0 >= channelCount }) {
                    errors.append("Perspective group \(perspective.id) contains a channel outside realization \(realizationID).")
                }
            }
            for poseID in perspective.poseIds ?? [] where !acousticPoseIDs.contains(poseID) {
                errors.append("Perspective group \(perspective.id) has unresolved acoustic pose \(poseID).")
            }
            if perspective.geometryStatus == "position-registered" && (perspective.poseIds?.isEmpty != false) {
                errors.append("Position-registered perspective group \(perspective.id) requires poseIds.")
            }
            if perspective.geometryStatus == "position-registered" && !profileIDs.contains(VAO03Contract.spatialProfile) {
                errors.append("Position-registered perspective group \(perspective.id) requires the Spatial 0.3 profile.")
            }
        }

        for variant in playable.sampleVariants {
            validateEvidence(id: variant.id, status: variant.status, source: variant.source, generatedByID: variant.generatedById)
            guard let realization = realizations[variant.realizationId] else {
                errors.append("Sample variant \(variant.id) has unresolved realizationId.")
                continue
            }
            if realization.technicalMetadata.kind != "audio" {
                errors.append("Sample variant \(variant.id) must reference an audio realization.")
            }
            for regionID in variant.signalRegionIds ?? [] {
                guard let region = regions[regionID] else {
                    errors.append("Sample variant \(variant.id) has unresolved signal region \(regionID).")
                    continue
                }
                if region.realizationId != variant.realizationId {
                    errors.append("Sample variant \(variant.id) references a region from another realization.")
                } else if !isUsable(region.status) {
                    errors.append("Sample variant \(variant.id) uses a rejected, superseded, or unreviewed inferred region \(regionID).")
                }
            }
            for loopID in variant.loopPointSetIds ?? [] {
                guard let loop = loops[loopID] else {
                    errors.append("Sample variant \(variant.id) has unresolved loop-point set \(loopID).")
                    continue
                }
                let realizationIDs = Set(loop.regionIds.compactMap { regions[$0]?.realizationId })
                if realizationIDs != [variant.realizationId] {
                    errors.append("Sample variant \(variant.id) references a loop from another realization.")
                }
                if !isUsable(loop.status) {
                    errors.append("Sample variant \(variant.id) uses a rejected, superseded, or unreviewed inferred loop \(loopID).")
                }
            }
            if let perspectiveID = variant.perspectiveGroupId {
                guard let perspective = perspectives[perspectiveID] else {
                    errors.append("Sample variant \(variant.id) has unresolved perspectiveGroupId.")
                    continue
                }
                if !perspective.realizationIds.contains(variant.realizationId) {
                    errors.append("Sample variant \(variant.id) is not a member of its perspective group.")
                } else if !isUsable(perspective.status) {
                    errors.append("Sample variant \(variant.id) uses a rejected, superseded, or unreviewed inferred perspective group.")
                }
            }
        }

        var usableMappingCount = 0
        var mappedVariantIDs: Set<String> = []
        for mapping in playable.sampleMappings {
            validateEvidence(id: mapping.id, status: mapping.status, source: mapping.source, generatedByID: mapping.generatedById)
            if mapping.keyRange.minimum > mapping.keyRange.maximum {
                errors.append("Sample mapping \(mapping.id) has a reversed MIDI key range.")
            }
            if let velocityRange = mapping.velocityRange, velocityRange.minimum > velocityRange.maximum {
                errors.append("Sample mapping \(mapping.id) has a reversed velocity range.")
            }
            if mapping.velocityRange == nil && mapping.velocitySensitivity == nil {
                errors.append("Sample mapping \(mapping.id) requires velocityRange or velocitySensitivity.")
            }
            if mapping.velocitySensitivity == "none" && mapping.velocityRange != nil {
                errors.append("Velocity-insensitive sample mapping \(mapping.id) must not declare velocityRange.")
            }
            if mapping.velocitySensitivity == "range" && mapping.velocityRange == nil {
                errors.append("Velocity-range sample mapping \(mapping.id) requires velocityRange.")
            }
            for entityID in [mapping.instrumentEntityId, mapping.componentEntityId, mapping.rankEntityId].compactMap({ $0 }) where entities[entityID] == nil {
                errors.append("Sample mapping \(mapping.id) has unresolved entity \(entityID).")
            }
            if let instrument = entities[mapping.instrumentEntityId], instrument.kind != "instrument" {
                errors.append("Sample mapping \(mapping.id) instrumentEntityId does not identify an instrument entity.")
            }
            if let tuningID = mapping.tuningMapId, tunings[tuningID] == nil {
                errors.append("Sample mapping \(mapping.id) has unresolved tuningMapId.")
            } else if let tuningID = mapping.tuningMapId, let tuning = tunings[tuningID], !isUsable(tuning.status) {
                errors.append("Sample mapping \(mapping.id) uses a rejected, superseded, or unreviewed inferred tuning map.")
            }
            let resolvedVariants = mapping.variantIds.compactMap { variants[$0] }
            for variantID in mapping.variantIds where variants[variantID] == nil {
                errors.append("Sample mapping \(mapping.id) has unresolved variant \(variantID).")
            }
            if !resolvedVariants.contains(where: { $0.trigger == "note-on" }) {
                errors.append("Sample mapping \(mapping.id) requires at least one note-on variant.")
            }
            if resolvedVariants.contains(where: { !isUsable($0.status) }) {
                errors.append("Sample mapping \(mapping.id) references rejected, superseded, or unreviewed inferred variants.")
            }
            if mapping.noteOffPolicy == "recorded-release" && !resolvedVariants.contains(where: { $0.trigger == "note-off" && $0.signalRole == "release" }) {
                errors.append("Sample mapping \(mapping.id) claims recorded-release without a note-off release variant.")
            }
            if isUsable(mapping.status) {
                usableMappingCount += 1
                if resolvedVariants.allSatisfy({ isUsable($0.status) }) {
                    mappedVariantIDs.formUnion(mapping.variantIds)
                }
            }
        }

        if capabilities.contains(sampledInstrumentPlaybackCapability) && usableMappingCount == 0 {
            errors.append("The sampled-instrument-playback capability requires at least one usable sample mapping.")
        }
        let mappedVariants = mappedVariantIDs.compactMap { variants[$0] }
        if capabilities.contains(sampleLoopingCapability) && !mappedVariants.contains(where: { !($0.loopPointSetIds ?? []).isEmpty }) {
            errors.append("The sample-looping capability requires a sample variant bound to a loop-point set.")
        }
        if capabilities.contains(tuningMapCapability) && !playable.sampleMappings.contains(where: {
            isUsable($0.status) && $0.tuningMapId.flatMap { tunings[$0] } != nil
        }) {
            errors.append("The tuning-map capability requires a usable sample mapping bound to a tuning map.")
        }
        let mappedPerspectiveIDs = Set(mappedVariants.compactMap(\.perspectiveGroupId).filter { perspectives[$0] != nil })
        if capabilities.contains(multiPerspectiveCapability) && mappedPerspectiveIDs.count < 2 {
            errors.append("The multi-perspective-sampling capability requires mapped variants from at least two perspective groups.")
        }
        if capabilities.contains(recordedReleaseCapability) && !playable.sampleMappings.contains(where: { $0.noteOffPolicy == "recorded-release" }) {
            errors.append("The recorded-release capability requires a mapping with recorded-release policy.")
        }
        if capabilities.contains(sourceSamplerSemanticsCapability) {
            let sourceBacked = playable.sampleMappings.contains { $0.source == "native-definition" }
                && playable.sampleVariants.contains { $0.source == "native-definition" || $0.source == "embedded-metadata" }
            if !sourceBacked {
                errors.append("The source-sampler-semantics capability requires native-definition mappings and source-backed variants.")
            }
        }
    }

    private static func isUsable(_ status: String) -> Bool {
        ["asserted", "reviewed", "accepted"].contains(status)
    }

    private static func indexed<Value>(_ values: [Value], key: KeyPath<Value, String>) -> [String: Value] {
        var result: [String: Value] = [:]
        for value in values where result[value[keyPath: key]] == nil {
            result[value[keyPath: key]] = value
        }
        return result
    }
}
