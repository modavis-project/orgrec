import Foundation
import XCTest
@testable import OrgRecCore

final class VAO03Tests: XCTestCase {
    private var fixture: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/VAO03/valid/embedded-private")
    }

    private var descriptors: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/VAO03/descriptors")
    }

    private var acousticFixture: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/VAO03/valid/acousticrooms-scene")
    }

    private var kinoorgelFixture: URL {
        descriptors.appendingPathComponent("kinoorgel-interaction.example.json")
    }

    private func playableManifest() throws -> VAO03Manifest {
        let data = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.manifestFilename))
        var manifest = try VAOFormatDispatcher.decode03(data)
        let realizationID = manifest.realizations[0].id
        manifest.realizations[0].mediaType = "audio/wav"
        manifest.realizations[0].technicalMetadata = VAO03TechnicalMetadata(
            kind: "audio",
            sampleRate: 48_000,
            sampleFormat: "signed-integer",
            bitDepth: 24,
            channelCount: 2,
            frameCount: 100,
            channelLabels: ["left", "right"],
            audioContainer: "WAVE",
            ambisonicsOrder: nil,
            ambisonicsDimensionality: nil,
            ambisonicsChannelOrder: nil,
            ambisonicsNormalization: nil,
            impulseResponse: nil,
            coordinateFrameId: nil,
            coordinateUnit: nil,
            handedness: nil,
            upAxis: nil,
            lod: nil,
            triangleCount: nil,
            vertexCount: nil,
            textureMaxDimension: nil,
            purposeLimitations: nil,
            extensions: nil
        )
        let interactionID = "urn:uuid:03000000-0000-4000-8000-000000000100"
        let ontology = "https://w3id.org/modavis/vao/ontology#"
        manifest.entities.append(VAO03Entity(
            id: interactionID,
            kind: "interaction",
            types: [ontology + "Interaction"],
            labels: ["en": "Play note"],
            classifications: nil,
            externalIdentifiers: nil,
            properties: [
                ontology + "interactionType": .string("https://w3id.org/modavis/vao/vocab/interaction/note-on"),
                ontology + "controlProtocol": .string("host-note-gate"),
                ontology + "controlDomain": .string("MIDI key and velocity"),
                ontology + "timingPolicy": .string("note-on/note-off"),
            ]
        ))
        manifest.relations.append(VAO03Relation(
            id: "urn:uuid:03000000-0000-4000-8000-000000000099",
            subjectId: interactionID,
            predicate: ontology + "activates",
            objectId: manifest.primaryEntityId,
            literal: nil,
            status: "asserted",
            confidence: nil,
            scope: nil,
            evidenceIds: nil,
            generatedByIds: nil,
            properties: nil
        ))
        manifest.conformsTo.append(VAO03Contract.playableProfile)
        manifest.profiles.append(VAO03Profile(
            id: VAO03Contract.playableProfile,
            version: "0.3",
            requiredCapabilities: [
                VAO03PlayableValidator.interactionCapability,
                VAO03PlayableValidator.sampledInstrumentPlaybackCapability,
                VAO03PlayableValidator.sampleLoopingCapability,
                VAO03PlayableValidator.recordedReleaseCapability,
                VAO03PlayableValidator.sourceSamplerSemanticsCapability,
            ]
        ))
        let loopRegionID = "urn:uuid:03000000-0000-4000-8000-000000000101"
        let releaseRegionID = "urn:uuid:03000000-0000-4000-8000-000000000102"
        let loopID = "urn:uuid:03000000-0000-4000-8000-000000000103"
        let noteOnID = "urn:uuid:03000000-0000-4000-8000-000000000104"
        let noteOffID = "urn:uuid:03000000-0000-4000-8000-000000000105"
        manifest.playable = VAO03Playable(
            signalRegions: [
                VAO03SignalRegion(id: loopRegionID, realizationId: realizationID, role: "sustain-loop", startFrameInclusive: 10, endFrameExclusive: 21, status: "asserted", source: "embedded-metadata", generatedById: nil, notes: "RIFF smpl end 20 becomes exclusive end 21."),
                VAO03SignalRegion(id: releaseRegionID, realizationId: realizationID, role: "release", startFrameInclusive: 60, endFrameExclusive: 100, status: "asserted", source: "native-definition", generatedById: nil, notes: nil),
            ],
            loopPointSets: [
                VAO03LoopPointSet(id: loopID, regionIds: [loopRegionID], mode: "forward", selectionPolicy: "ordered", exitPolicy: "recorded-release", crossfadeFrames: 4, status: "asserted", source: "embedded-metadata", generatedById: nil, reviewedById: nil, notes: nil),
            ],
            tuningMaps: [],
            perspectiveGroups: [],
            sampleVariants: [
                VAO03SampleVariant(id: noteOnID, realizationId: realizationID, trigger: "note-on", signalRole: "attack-sustain", signalRegionIds: nil, loopPointSetIds: [loopID], perspectiveGroupId: nil, roundRobinGroup: nil, roundRobinIndex: nil, selectionWeight: nil, sourceLocator: "[Rank001].Pipe001", status: "asserted", source: "native-definition", generatedById: nil),
                VAO03SampleVariant(id: noteOffID, realizationId: realizationID, trigger: "note-off", signalRole: "release", signalRegionIds: [releaseRegionID], loopPointSetIds: nil, perspectiveGroupId: nil, roundRobinGroup: nil, roundRobinIndex: nil, selectionWeight: nil, sourceLocator: "[Rank001].Pipe001Release001", status: "asserted", source: "native-definition", generatedById: nil),
            ],
            sampleMappings: [
                VAO03SampleMapping(id: "urn:uuid:03000000-0000-4000-8000-000000000106", instrumentEntityId: manifest.primaryEntityId, componentEntityId: nil, rankEntityId: nil, keyRange: VAO03MIDIRange(minimum: 36, maximum: 36), velocityRange: VAO03MIDIRange(minimum: 1, maximum: 127), variantIds: [noteOnID, noteOffID], selectionPolicy: "single", tuningMapId: nil, gainDB: nil, pitchTuningCents: nil, noteOffPolicy: "recorded-release", sourceLocator: "[Rank001].Pipe001", status: "asserted", source: "native-definition", generatedById: nil),
            ]
        )
        return manifest
    }

    private func writeAcousticArchive(to destination: URL, corruptRIR: Bool = false) throws {
        let manager = FileManager.default
        let payload = acousticFixture.appendingPathComponent("payload", isDirectory: true)
        let payloadFiles = try XCTUnwrap(manager.enumerator(
            at: payload,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )).compactMap { $0 as? URL }.filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted { $0.path < $1.path }
        var entries = [
            VAOArchiveEntrySource(path: "mimetype", fileURL: acousticFixture.appendingPathComponent("mimetype")),
            VAOArchiveEntrySource(path: VAO03Contract.manifestFilename, fileURL: acousticFixture.appendingPathComponent(VAO03Contract.manifestFilename)),
            VAOArchiveEntrySource(path: VAO03Contract.carrierFilename, fileURL: acousticFixture.appendingPathComponent(VAO03Contract.carrierFilename)),
        ]
        for file in payloadFiles {
            let relative = "payload/" + String(file.standardizedFileURL.path.dropFirst(payload.standardizedFileURL.path.count + 1))
            if corruptRIR, relative.hasSuffix("S000_R0011_hybrid_IR.wav") {
                entries.append(VAOArchiveEntrySource(path: relative, data: Data("corrupt RIR".utf8)))
            } else {
                entries.append(VAOArchiveEntrySource(path: relative, fileURL: file))
            }
        }
        try VAOArchiveWriter.write(entries: entries, to: destination)
    }

    func testRepositoryFreeVAO03FixtureIsValid() throws {
        let data = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.manifestFilename))
        XCTAssertEqual(VAOFormatDispatcher.formatVersion(in: data), "0.3.3")
        XCTAssertEqual(VAO03Validator.validateManifest(data: data), [])
        let manifest = try VAOFormatDispatcher.decode03(data)
        XCTAssertTrue(manifest.distributions.isEmpty)
        XCTAssertTrue(manifest.repositoryBindings.isEmpty)
        XCTAssertFalse(manifest.profiles.contains { $0.id == VAO03Contract.zenodoProfile })
    }

    func testPlayableProfileValidatesLosslessSourceLoopAndRecordedRelease() throws {
        let manifest = try playableManifest()
        let data = try JSONEncoder().encode(manifest)
        XCTAssertEqual(VAO03Validator.validateManifest(data: data), [])
        let decoded = try VAOFormatDispatcher.decode03(data)
        XCTAssertEqual(decoded.playable?.signalRegions[0].endFrameExclusive, 21)
        XCTAssertEqual(decoded.playable?.sampleMappings[0].noteOffPolicy, "recorded-release")
    }

    func testPlayableInteractionDoesNotRequireASampleImplementation() throws {
        var manifest = try playableManifest()
        manifest.playable = nil
        let index = try XCTUnwrap(manifest.profiles.firstIndex { $0.id == VAO03Contract.playableProfile })
        manifest.profiles[index].requiredCapabilities = [VAO03PlayableValidator.interactionCapability]
        XCTAssertEqual(VAO03Validator.validateManifest(manifest), [])

        manifest.profiles[index].requiredCapabilities.append(VAO03PlayableValidator.sampledInstrumentPlaybackCapability)
        let errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("requires the closed top-level playable object") })
    }

    func testPlayableProfileRejectsOutOfBoundsLoopAndEvidenceLaundering() throws {
        var manifest = try playableManifest()
        manifest.playable?.signalRegions[0].endFrameExclusive = 101
        manifest.playable?.loopPointSets[0].source = "algorithmic"
        manifest.playable?.loopPointSets[0].status = "asserted"
        let errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("exceeds the realization frameCount") })
        XCTAssertTrue(errors.contains { $0.contains("algorithmic output as asserted") })
        XCTAssertTrue(errors.contains { $0.contains("lacks generatedById") })
    }

    func testPlayableProfileRejectsFalseRecordedReleaseCapability() throws {
        var manifest = try playableManifest()
        manifest.playable?.sampleVariants.removeLast()
        manifest.playable?.sampleMappings[0].variantIds.removeLast()
        let errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("claims recorded-release without") })
    }

    func testPlayableProfileRejectsDetachedCapabilitiesAndUnusableEvidence() throws {
        var manifest = try playableManifest()
        let profileIndex = try XCTUnwrap(manifest.profiles.firstIndex { $0.id == VAO03Contract.playableProfile })
        manifest.profiles[profileIndex].requiredCapabilities.append(VAO03PlayableValidator.tuningMapCapability)
        manifest.profiles[profileIndex].requiredCapabilities.append(VAO03PlayableValidator.multiPerspectiveCapability)
        manifest.playable?.signalRegions[1].status = "rejected"
        let instrumentIndex = try XCTUnwrap(manifest.entities.firstIndex { $0.id == manifest.primaryEntityId })
        manifest.entities[instrumentIndex].kind = "component"

        let errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("unreviewed inferred region") })
        XCTAssertTrue(errors.contains { $0.contains("does not identify an instrument") })
        XCTAssertTrue(errors.contains { $0.contains("usable sample mapping bound to a tuning map") })
        XCTAssertTrue(errors.contains { $0.contains("at least two perspective groups") })
    }

    func testKinoorgelComplexInteractionFixtureIsValidAndTyped() throws {
        let data = try Data(contentsOf: kinoorgelFixture)
        XCTAssertEqual(VAO03Validator.validateManifest(data: data), [])
        let manifest = try VAOFormatDispatcher.decode03(data)
        XCTAssertEqual(manifest.interactionModel?.controls.count, 5)
        XCTAssertEqual(manifest.interactionModel?.routingRules.count, 3)
        XCTAssertEqual(manifest.interactionModel?.processModels.first?.terminationPolicy, "on-control-release")
        XCTAssertEqual(manifest.captureDocumentation?.eventAlignments.first?.clockBasis, "audio-frames")
        XCTAssertEqual(manifest.playable?.sampleMappings.first?.velocitySensitivity, "none")
        XCTAssertNil(manifest.playable?.sampleMappings.first?.velocityRange)
    }

    func testComplexInteractionClaimsAndMIDINumberingAreEnforced() throws {
        let data = try Data(contentsOf: kinoorgelFixture)
        var manifest = try VAOFormatDispatcher.decode03(data)
        manifest.interactionModel = nil
        var errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("require the closed top-level interactionModel") })

        manifest = try VAOFormatDispatcher.decode03(data)
        manifest.interactionModel?.protocolBindings[0].channelNumberingBase = nil
        errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("requires explicit channelNumberingBase") })
    }

    func testComplexInteractionRejectsEmbeddedExecutableProperties() throws {
        let data = try Data(contentsOf: kinoorgelFixture)
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var interactionModel = try XCTUnwrap(root["interactionModel"] as? [String: Any])
        var transitions = try XCTUnwrap(interactionModel["transitions"] as? [[String: Any]])
        transitions[0]["script"] = "runArbitraryCode()"
        interactionModel["transitions"] = transitions
        root["interactionModel"] = interactionModel

        let mutated = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        let errors = VAO03Validator.validateManifest(data: mutated)
        XCTAssertTrue(errors.contains { $0.contains("transitions[0] contains unknown property script") })
    }

    func testComplexInteractionRejectsCyclesUnboundedProcessesAndBadAlignment() throws {
        let data = try Data(contentsOf: kinoorgelFixture)
        var manifest = try VAOFormatDispatcher.decode03(data)
        manifest.interactionModel?.processModels[0].terminationPolicy = "completed"
        manifest.interactionModel?.routingRules[1].sourceEntityId = "urn:vao:fixture:kinoorgel:rank:tibia"
        manifest.interactionModel?.routingRules[1].targetEntityId = "urn:vao:fixture:kinoorgel:manual:great"
        manifest.interactionModel?.routingRules[1].routingBehavior = "copies"
        manifest.captureDocumentation?.eventAlignments[0].eventMappings[0].endFrameExclusive = 200_000
        let errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("potentially unbounded") })
        XCTAssertTrue(errors.contains { $0.contains("routing graph contains a cycle") })
        XCTAssertTrue(errors.contains { $0.contains("exceeds audio frameCount") })
    }

    func testCarrierComparisonRejectsUnicodeNormalizationCollisions() throws {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("vao-unicode-collision-\(UUID().uuidString).vao")
        defer { try? FileManager.default.removeItem(at: destination) }
        let entries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAO03Contract.mediaType.utf8)),
            VAOArchiveEntrySource(path: "payload/Caf\u{e9}.wav", data: Data([0])),
            VAOArchiveEntrySource(path: "payload/Cafe\u{301}.wav", data: Data([1])),
        ]
        XCTAssertThrowsError(try VAOArchiveWriter.write(entries: entries, to: destination)) { error in
            XCTAssertTrue(String(describing: error).contains("unsafe or duplicated"))
        }
    }

    func testOrgRecReaderExposesTypedPlayableResources() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao033-playable-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manifestData = try JSONEncoder().encode(playableManifest())
        var carrier = try JSONDecoder().decode(
            VAO03Carrier.self,
            from: Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.carrierFilename))
        )
        carrier.manifestSHA256 = manifestData.sha256Hex
        carrier.manifestByteSize = Int64(manifestData.count)
        let carrierData = try JSONEncoder().encode(carrier)
        let archive = root.appendingPathComponent("playable.vao")
        try VAOArchiveWriter.write(entries: [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAO03Contract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAO03Contract.manifestFilename, data: manifestData),
            VAOArchiveEntrySource(path: VAO03Contract.carrierFilename, data: carrierData),
            VAOArchiveEntrySource(path: "payload/evidence/source.txt", fileURL: fixture.appendingPathComponent("payload/evidence/source.txt")),
        ], to: archive)

        let inspection = try await VAO03PackageReader().inspect(archive)
        XCTAssertTrue(inspection.isValid, inspection.errors.joined(separator: "; "))
        let playable = try XCTUnwrap(inspection.playableInstrument)
        XCTAssertEqual(playable.sampleMappings.count, 1)
        XCTAssertEqual(playable.loopPointSets.count, 1)
        XCTAssertEqual(playable.audioResources.count, 1)
        XCTAssertEqual(playable.audioResources[0].frameCount, 100)
        XCTAssertEqual(playable.audioResources[0].signalRoles, ["attack-sustain", "release"])
        XCTAssertEqual(playable.audioResources[0].embeddedPath, "payload/evidence/source.txt")
    }

    func testCarrierPinsManifestAndEmbeddedRealization() throws {
        let manifest = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.manifestFilename))
        let carrier = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.carrierFilename))
        let evidence = try Data(contentsOf: fixture.appendingPathComponent("payload/evidence/source.txt"))
        XCTAssertEqual(VAO03Validator.validateCarrier(
            manifestData: manifest,
            carrierData: carrier,
            embeddedData: ["payload/evidence/source.txt": evidence]
        ), [])
    }

    func testZenodoProfileCannotBeClaimedWithoutBinding() throws {
        let data = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.manifestFilename))
        var manifest = try VAOFormatDispatcher.decode03(data)
        manifest.profiles.append(VAO03Profile(id: VAO03Contract.zenodoProfile, version: "0.3", requiredCapabilities: []))
        let errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("if and only if") })
    }

    func testGroupDependencyCycleIsRejected() throws {
        let data = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.manifestFilename))
        var manifest = try VAOFormatDispatcher.decode03(data)
        manifest.assetGroups[0].dependsOnGroupIds = [manifest.assetGroups[0].id]
        let errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("dependency graph contains a cycle") })
    }

    func testDuplicateRegistryIdentifierIsReportedWithoutTrapping() throws {
        let data = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.manifestFilename))
        var manifest = try VAOFormatDispatcher.decode03(data)
        manifest.assetGroups.append(manifest.assetGroups[0])
        let errors = VAO03Validator.validateManifest(manifest)
        XCTAssertTrue(errors.contains { $0.contains("not unique") })
    }

    func testMaterializationPlannerKeepsRepositoryUseOptional() throws {
        let data = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.manifestFilename))
        let carrierData = try Data(contentsOf: fixture.appendingPathComponent(VAO03Contract.carrierFilename))
        let manifest = try VAOFormatDispatcher.decode03(data)
        let carrier = try JSONDecoder().decode(VAO03Carrier.self, from: carrierData)
        let plan = try VAO03MaterializationPlanner.plan(
            manifest: manifest,
            carrier: carrier,
            requestedGroupIds: [manifest.assetGroups[0].id],
            supportedCapabilities: []
        )
        XCTAssertEqual(plan.embeddedRealizationIds.count, 1)
        XCTAssertTrue(plan.remoteRealizationIds.isEmpty)
        XCTAssertEqual(plan.totalByteSize, 69)
    }

    func testSingleRecordPublicationAndZenodoMetadataAreCoherent() throws {
        let releaseData = try Data(contentsOf: descriptors.appendingPathComponent("release-single-record.example.json"))
        let metadataData = try Data(contentsOf: descriptors.appendingPathComponent("zenodo-metadata-single-record.example.json"))
        let release = try JSONDecoder().decode(VAO03ReleaseDescriptor.self, from: releaseData)
        let metadata = try JSONDecoder().decode(VAO03ZenodoMetadataDocument.self, from: metadataData)
        XCTAssertEqual(VAO03Validator.validateReleaseDescriptor(data: releaseData), [])
        XCTAssertEqual(VAO03Validator.validatePublication(release, zenodoMetadata: [metadata]), [])
        XCTAssertEqual(release.publication.topology, "single-record")
        XCTAssertTrue(release.publication.familyMembers.isEmpty)
    }

    func testRecordFamilyRequiresExactProjectedRelations() throws {
        let release = try JSONDecoder().decode(
            VAO03ReleaseDescriptor.self,
            from: Data(contentsOf: descriptors.appendingPathComponent("release-record-family.example.json"))
        )
        let names = [
            "zenodo-metadata-family-root.example.json",
            "zenodo-metadata-family-model.example.json",
            "zenodo-metadata-family-audio.example.json",
        ]
        var metadata = try names.map {
            try JSONDecoder().decode(VAO03ZenodoMetadataDocument.self, from: Data(contentsOf: descriptors.appendingPathComponent($0)))
        }
        XCTAssertEqual(VAO03Validator.validatePublication(release, zenodoMetadata: metadata), [])
        metadata[0].metadata.relatedIdentifiers.removeFirst()
        XCTAssertTrue(VAO03Validator.validatePublication(release, zenodoMetadata: metadata).contains { $0.contains("lacks hasPart relation") })
    }

    func testPublicAcousticRoomsSceneIsPositionRegisteredAndValid() throws {
        let data = try Data(contentsOf: acousticFixture.appendingPathComponent(VAO03Contract.manifestFilename))
        XCTAssertEqual(VAO03Validator.validateManifest(data: data), [])
        let manifest = try VAOFormatDispatcher.decode03(data)
        let acoustics = try XCTUnwrap(manifest.acoustics?.objectValue)
        let poses = try XCTUnwrap(acoustics["poses"]?.arrayValue)
        XCTAssertEqual(poses[0].objectValue?["position"]?.arrayValue?.compactMap(\.numberValue), [2.3496, 0.7269, 1.353])
        XCTAssertEqual(poses[1].objectValue?["position"]?.arrayValue?.compactMap(\.numberValue), [2.8176, 0.9871, 1.4665])
        XCTAssertEqual(manifest.realizations.first { $0.mediaType == "audio/wav" }?.technicalMetadata.impulseResponse?.objectValue?["sampleCount"]?.integerValue, 11_864)
    }

    func testPublicAcousticRoomsPreservationCarrierClosesAllBytes() throws {
        let manifestData = try Data(contentsOf: acousticFixture.appendingPathComponent(VAO03Contract.manifestFilename))
        let carrierData = try Data(contentsOf: acousticFixture.appendingPathComponent(VAO03Contract.carrierFilename))
        let carrier = try JSONDecoder().decode(VAO03Carrier.self, from: carrierData)
        let embedded = try Dictionary(uniqueKeysWithValues: carrier.embeddedRealizations.map { mapping in
            (mapping.path, try Data(contentsOf: acousticFixture.appendingPathComponent(mapping.path)))
        })
        XCTAssertEqual(embedded.count, 8)
        XCTAssertEqual(VAO03Validator.validateCarrier(manifestData: manifestData, carrierData: carrierData, embeddedData: embedded), [])
    }

    func testImpulseResponseChannelOutsideRealizationIsRejected() throws {
        let source = try Data(contentsOf: acousticFixture.appendingPathComponent(VAO03Contract.manifestFilename))
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        var realizations = try XCTUnwrap(root["realizations"] as? [[String: Any]])
        let audioIndex = try XCTUnwrap(realizations.firstIndex { ($0["mediaType"] as? String) == "audio/wav" })
        var realization = realizations[audioIndex]
        var technical = try XCTUnwrap(realization["technicalMetadata"] as? [String: Any])
        var impulse = try XCTUnwrap(technical["impulseResponse"] as? [String: Any])
        var mappings = try XCTUnwrap(impulse["measurementMappings"] as? [[String: Any]])
        mappings[0]["channelIndices"] = [1]
        impulse["measurementMappings"] = mappings
        technical["impulseResponse"] = impulse
        realization["technicalMetadata"] = technical
        realizations[audioIndex] = realization
        root["realizations"] = realizations
        let data = try JSONSerialization.data(withJSONObject: root)
        XCTAssertTrue(VAO03Validator.validateManifest(data: data).contains { $0.contains("outside channelCount") })
    }

    func testVisualAcousticSceneRequiresTransformableGeometry() throws {
        let source = try Data(contentsOf: acousticFixture.appendingPathComponent(VAO03Contract.manifestFilename))
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        var acoustics = try XCTUnwrap(root["acoustics"] as? [String: Any])
        var frames = try XCTUnwrap(acoustics["coordinateFrames"] as? [[String: Any]])
        frames[1]["transformToParent"] = Array(repeating: 0, count: 16)
        acoustics["coordinateFrames"] = frames
        root["acoustics"] = acoustics
        let data = try JSONSerialization.data(withJSONObject: root)
        XCTAssertTrue(VAO03Validator.validateManifest(data: data).contains { $0.contains("invertible transformToParent") })
    }

    func testOrgRecInspectsImportsAndExtractsVAO033AcousticCarrier() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao033-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("acousticrooms.vao")
        try writeAcousticArchive(to: archive)

        let reader = VAO03PackageReader()
        let inspection = try await reader.inspect(archive)
        XCTAssertTrue(inspection.isValid, inspection.errors.joined(separator: "; "))
        XCTAssertEqual(inspection.verifiedPayloadBytes, 1_722_650)
        let scene = try XCTUnwrap(inspection.acousticScene)
        XCTAssertEqual(scene.coordinateFrames.count, 2)
        XCTAssertEqual(scene.poses.count, 2)
        XCTAssertEqual(scene.measurements.count, 1)
        XCTAssertEqual(scene.geometryResources.count, 2)
        XCTAssertEqual(scene.impulseResponseResources.count, 1)
        XCTAssertEqual(scene.impulseResponseResources[0].sampleCount, 11_864)
        XCTAssertEqual(scene.impulseResponseResources[0].embeddedPath, "payload/acoustics/S000_R0011_hybrid_IR.wav")

        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        _ = try await reader.importWorkspace(from: archive, to: workspace)
        XCTAssertEqual(
            try sha256(of: workspace.appendingPathComponent("payload/geometry/Bathrooms_idx_0.glb")),
            "03e1bb41f2db881da22212184baa765a71ae9e3248ef610237f67322b039798a"
        )
        let extracted = root.appendingPathComponent("rir.wav")
        try await reader.extractRealization(
            id: "urn:vao:fixture:acousticrooms:realization:rir:wav",
            from: archive,
            to: extracted
        )
        XCTAssertEqual(try sha256(of: extracted), "acfa34ce1f465e78337da0ac7032b92e2913dfa4203c077acd1e5cbe6dd446b6")
    }

    func testOrgRecStreamingReaderRejectsCorruptVAO033Payload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao033-corrupt-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("corrupt.vao")
        try writeAcousticArchive(to: archive, corruptRIR: true)
        let inspection = try await VAO03PackageReader().inspect(archive)
        XCTAssertFalse(inspection.isValid)
        XCTAssertTrue(inspection.errors.contains { $0.contains("fails fixity") })
    }
}
