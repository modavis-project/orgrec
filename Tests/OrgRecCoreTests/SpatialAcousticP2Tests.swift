import AVFAudio
import XCTest
@testable import OrgRecCore

final class SpatialAcousticP2Tests: XCTestCase {
    private let snapshotHash = Data("p2-tests".utf8).sha256Hex

    private func component(id: String = "effect", label: String = "Cymbal") -> OrganComponent {
        OrganComponent(
            id: id, kind: "accessory", label: label, division: "Percussion",
            locator: ComponentLocator(id: id, organMDVSID: "MDVS:ORGN:P2", snapshotSHA256: snapshotHash, kind: "accessory", label: label, trust: .sourceBound)
        )
    }

    private func assignment(_ value: String) -> CaptureStateAssignment {
        CaptureStateAssignment(subjectComponentID: "shutters", subjectLabel: "Expression shutters", dimension: .shutter, valueKind: .discrete, textValue: value)
    }

    private func geometry(setupID: UUID) -> SpatialGeometrySnapshot {
        SpatialGeometrySnapshot(
            name: "Solo chamber",
            referenceFrame: SpatialGeometryReferenceFrame(compatibleMicrophoneSetupIDs: [setupID], evidence: .measured, uncertaintyMeters: 0.02),
            elements: [
                SpatialGeometryElement(id: "rank", componentID: "solo-rank", label: "Solo rank", kind: .rank,
                                       parentElementID: "box", position: .init(xMeters: 0, yMeters: -1, zMeters: 3),
                                       extent: .init(widthMeters: 3, heightMeters: 2, depthMeters: 1), distribution: .volume, evidence: .measured),
                SpatialGeometryElement(id: "box", label: "Solo box", kind: .enclosure,
                                       position: .init(xMeters: 0, yMeters: 0, zMeters: 3), extent: .init(widthMeters: 5, heightMeters: 4, depthMeters: 3), distribution: .volume, material: "wood", evidence: .architecturalDrawing),
                SpatialGeometryElement(id: "shutters", label: "Solo shutters", kind: .shutter,
                                       parentElementID: "box", position: .init(xMeters: 0, yMeters: 1, zMeters: 3), extent: .init(widthMeters: 4, heightMeters: 2, depthMeters: 0.08), distribution: .area, material: "wood", openAreaRatio: 0.5, thicknessMeters: 0.08, evidence: .measured)
            ]
        )
    }

    func testGeometryFingerprintCoversSourcePathAndFrame() throws {
        let setupID = UUID()
        let first = geometry(setupID: setupID)
        XCTAssertTrue(first.validationIssues.isEmpty)
        var changed = first
        changed.elements[2].openAreaRatio = 0.75
        XCTAssertNotEqual(first.fingerprint, changed.fingerprint)
        changed = first
        changed.referenceFrame.originDescription = "Console center"
        XCTAssertNotEqual(first.fingerprint, changed.fingerprint)
        let decoded = try OrgRecCoding.decoder.decode(SpatialGeometrySnapshot.self, from: OrgRecCoding.encoder.encode(first))
        XCTAssertEqual(decoded.id, first.id)
        XCTAssertEqual(decoded.elements, first.elements)
        XCTAssertEqual(decoded.fingerprint, first.fingerprint)
    }

    func testResponseCompilerCreatesExactStateTechniqueMatrix() throws {
        let setupA = UUID(), setupB = UUID()
        let geometry = geometry(setupID: setupA)
        var frame = geometry.referenceFrame
        frame.compatibleMicrophoneSetupIDs = [setupA, setupB]
        let revised = SpatialGeometrySnapshot(id: geometry.id, name: geometry.name, referenceFrame: frame, elements: geometry.elements)
        let states = [
            SpatialResponseState(id: "open", label: "Open", assignments: [assignment("open")]),
            SpatialResponseState(id: "closed", label: "Closed", assignments: [assignment("closed")])
        ]
        let request = SpatialAcousticPlanRequest(
            geometry: revised, sourceComponentID: "solo-rank", sourceElementID: "rank", pathElementIDs: ["box", "shutters"],
            states: states, referenceStateID: "open", minimumAcceptedTakeCount: 3, plannedDurationSeconds: 12,
            techniques: [.closePair, .naveORTF], excitation: .impulsiveSource
        )
        let compiled = RoadmapEngine.spatialAcousticResponseItems(request: request, component: component(id: "solo-rank", label: "Solo rank"), recipe: CaptureRecipe(techniques: [.closePair, .naveORTF]))
        XCTAssertEqual(compiled.states.count, 2)
        XCTAssertEqual(compiled.items.count, 4)
        XCTAssertEqual(Set(compiled.items.compactMap { $0.spatialAcousticProtocol?.responseSeriesID }).count, 1)
        XCTAssertEqual(Set(compiled.items.compactMap { $0.spatialAcousticProtocol?.targetState.id }), ["open", "closed"])
        XCTAssertTrue(compiled.items.allSatisfy { $0.requiredCaptureStateFingerprint == $0.requiredCaptureState?.fingerprintSHA256 })
        XCTAssertTrue(compiled.items.allSatisfy { $0.minimumAcceptedTakeCount == 3 })
        XCTAssertTrue(compiled.items.allSatisfy { $0.spatialAcousticProtocol?.effectiveExcitation == .impulsiveSource })
        XCTAssertEqual(SessionPlanningEngine.buildQueue(items: [compiled.items[0]], recipe: CaptureRecipe()).first?.estimatedCaptureSeconds, 36)
    }

    func testNonPitchedTargetGetsExplicitEffectAnalysisProtocol() throws {
        let source = component()
        let definition = SoundingTargetDefinition(family: .repeatingEffect, temporalBehavior: .repeating, triggerMode: .stopTab, minimumAcceptedTakeCount: 2)
        let item = try XCTUnwrap(RoadmapEngine.soundingTargetItems(component: source, definition: definition, recipe: CaptureRecipe(techniques: [.closePair]), setupIDs: [UUID()], registrationID: UUID()).first)
        XCTAssertEqual(item.effectAnalysisProtocol?.temporalBehavior, .repeating)
        XCTAssertNotNil(item.inferredNonPitchedEffectAnalysisProtocol)

        let tonal = SoundingTargetDefinition(family: .tonalPercussion, temporalBehavior: .discrete, triggerMode: .keyboardKey)
        let tonalItem = try XCTUnwrap(RoadmapEngine.soundingTargetItems(component: source, definition: tonal, recipe: CaptureRecipe(techniques: [.closePair]), setupIDs: [UUID()], registrationID: UUID()).first)
        XCTAssertNil(tonalItem.effectAnalysisProtocol)
        XCTAssertNil(tonalItem.inferredNonPitchedEffectAnalysisProtocol)
    }

    func testEffectAnalyzerMeasuresLatencyRepetitionPeriodicityAndVariability() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-p2-effect-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let rate = 16_000.0, duration = 3.0, frameCount = Int(rate * duration)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)))
            buffer.frameLength = AVAudioFrameCount(frameCount)
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            for frame in 0..<frameCount { samples[frame] = 0.000_1 * Float(sin(2 * Double.pi * 113 * Double(frame) / rate)) }
            for event in stride(from: 0.5, through: 2.5, by: 0.25) {
                let start = Int(event * rate)
                for offset in 0..<min(Int(rate * 0.02), frameCount - start) {
                    samples[start + offset] += Float(0.6 * exp(-Double(offset) / 80) * sin(2 * Double.pi * 1_200 * Double(offset) / rate))
                }
            }
            try file.write(from: buffer)
        }

        let definition = SoundingTargetDefinition(family: .repeatingEffect, temporalBehavior: .repeating, triggerMode: .stopTab)
        let item = RoadmapItem(component: component(), technique: .closePair, recipeID: UUID(), soundingTargetDefinition: definition,
                               effectAnalysisProtocol: NonPitchedEffectAnalysisProtocol(sourceComponentID: "effect", temporalBehavior: .repeating))
        let take = TakeRecord(roadmapItemID: item.id, takeNumber: 1, status: .recorded, relativeAudioPath: url.lastPathComponent, sampleRate: rate, channelCount: 1)
        let marker = TimedAnnotation(takeID: take.id, atSeconds: 0.45, code: "operator_effect_trigger", severity: "info", text: "trigger")
        let result = try XCTUnwrap(P2AnalysisEngine.analyzeEffect(fileURL: url, take: take, item: item, referenceChannel: 0, annotations: [marker]))
        XCTAssertEqual(result.commandTimingEvidence, .operatorMarker)
        XCTAssertEqual(result.latencySeconds ?? 0, 0.05, accuracy: 0.06)
        XCTAssertGreaterThanOrEqual(result.repetitionEventCount, 7)
        XCTAssertEqual(result.repetitionRateHz ?? 0, 4, accuracy: 0.35)
        XCTAssertEqual(result.periodicityRateHz ?? 0, 4, accuracy: 0.35)
        XCTAssertGreaterThan(result.periodicityConfidence ?? 0, 0.4)
        XCTAssertLessThan(result.stochasticityIndex ?? 1, 0.45)
        XCTAssertNotNil(result.effectiveImpulseWidthSeconds)
    }

    func testSpatialAnalyzerAndComparisonsRemainSetupChannelAndGeometryBound() throws {
        let setupID = UUID(), geometry = geometry(setupID: setupID), seriesID = UUID()
        let referenceState = SpatialResponseState(id: "open", label: "Open", assignments: [assignment("open")])
        let closedState = SpatialResponseState(id: "closed", label: "Closed", assignments: [assignment("closed")])
        func protocolFor(_ state: SpatialResponseState) -> SpatialAcousticCaptureProtocol {
            SpatialAcousticCaptureProtocol(responseSeriesID: seriesID, name: state.label, geometrySnapshotID: geometry.id, geometryFingerprint: geometry.fingerprint, sourceElementID: "rank", pathElementIDs: ["box", "shutters"], referenceStateID: "open", targetState: state)
        }
        func observation(takeID: UUID, state: String, channel: Int, rms: Double, band: Double) -> SpatialAcousticObservation {
            SpatialAcousticObservation(contractVersion: "orgrec.spatial-acoustic-observation/v1", takeID: takeID, responseSeriesID: seriesID, stateID: state,
                geometrySnapshotID: geometry.id, geometryFingerprint: geometry.fingerprint, sourceElementID: "rank", pathElementIDs: ["box", "shutters"],
                microphoneSetupID: setupID, captureTechnique: .closePair, referenceChannel: channel, sourceToReferenceMicrophoneDistanceMeters: 5,
                peakDBFS: rms + 6, rmsDBFS: rms, onsetLatencySeconds: 0.04, effectiveImpulseWidthSeconds: 0.2,
                thirdOctaveBandLevels: [SpectralBandLevel(centerFrequencyHz: 1_000, lowerFrequencyHz: 891, upperFrequencyHz: 1_122, levelDBFS: band)],
                analyzedDurationSeconds: 3, takeStatus: .accepted, analyzedAt: .now, method: "test", warnings: [])
        }
        let referenceID = UUID(), targetID = UUID(), otherChannelID = UUID()
        let referenceProtocol = protocolFor(referenceState), closedProtocol = protocolFor(closedState)
        var project = DemoProjectFactory.make()
        project.takes = [
            TakeRecord(id: referenceID, roadmapItemID: UUID(), takeNumber: 1, status: .accepted, relativeAudioPath: "ref.wav", sampleRate: 48_000, channelCount: 2,
                       spatialAcousticParadata: .init(protocolSnapshot: referenceProtocol, repetitionNumber: 1, observation: observation(takeID: referenceID, state: "open", channel: 0, rms: -20, band: -25))),
            TakeRecord(id: targetID, roadmapItemID: UUID(), takeNumber: 1, status: .accepted, relativeAudioPath: "closed.wav", sampleRate: 48_000, channelCount: 2,
                       spatialAcousticParadata: .init(protocolSnapshot: closedProtocol, repetitionNumber: 1, observation: observation(takeID: targetID, state: "closed", channel: 0, rms: -28, band: -37))),
            TakeRecord(id: otherChannelID, roadmapItemID: UUID(), takeNumber: 1, status: .accepted, relativeAudioPath: "closed-ch2.wav", sampleRate: 48_000, channelCount: 2,
                       spatialAcousticParadata: .init(protocolSnapshot: closedProtocol, repetitionNumber: 1, observation: observation(takeID: otherChannelID, state: "closed", channel: 1, rms: -5, band: -5)))
        ]
        let comparisons = P2AnalysisEngine.responseComparisons(project: project)
        XCTAssertEqual(comparisons.count, 1, "The unmatched reference channel must not be merged.")
        XCTAssertEqual(comparisons[0].referenceChannel, 0)
        XCTAssertEqual(comparisons[0].rmsLevelDeltaDB ?? 0, -8, accuracy: 0.001)
        XCTAssertEqual(comparisons[0].thirdOctaveBandDeltas.first?.levelDeltaDB ?? 0, -12, accuracy: 0.001)
        XCTAssertEqual(comparisons[0].targetTakeIDs, [targetID])
    }
}
