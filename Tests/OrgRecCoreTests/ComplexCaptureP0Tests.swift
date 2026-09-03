import XCTest
@testable import OrgRecCore

final class ComplexCaptureP0Tests: XCTestCase {
    private let snapshot = Data("complex-capture-p0".utf8).sha256Hex

    private func component(
        id: String,
        kind: String,
        label: String,
        low: Int? = nil,
        high: Int? = nil,
        details: [String: String]? = nil
    ) -> OrganComponent {
        OrganComponent(
            id: id,
            kind: kind,
            label: label,
            division: "Solo",
            locator: ComponentLocator(
                id: id,
                organMDVSID: "MDVS:ORGN:P0",
                snapshotSHA256: snapshot,
                kind: kind,
                label: label,
                trust: .sourceBound
            ),
            playableMIDILow: low,
            playableMIDIHigh: high,
            sourceDetails: details
        )
    }

    func testCinemaOrganSoundsCompileAsIntendedTargetsAndKeepActuatorNoiseSeparate() {
        let xylophone = component(id: "xylophone", kind: "tonal_percussion", label: "Xylophone", low: 60, high: 61)
        let cymbal = component(id: "cymbal", kind: "accessory", label: "Crash Cymbal")
        let shutter = component(id: "swell", kind: "accessory", label: "Solo expression shutters")
        let recipe = CaptureRecipe(techniques: [.closePair], chromaticStep: 1)

        let compilation = RoadmapEngine.compileSpecification(
            components: [xylophone, cymbal, shutter],
            recipe: recipe,
            setupIDs: [UUID()]
        )

        let tonal = compilation.roadmap.filter { $0.coverageKind == .tonalPercussion }
        let atonal = compilation.roadmap.filter { $0.coverageKind == .atonalPercussion }
        XCTAssertEqual(tonal.map(\.component.midiNote).compactMap { $0 }, [60, 61])
        XCTAssertEqual(atonal.count, 1)
        XCTAssertTrue((tonal + atonal).allSatisfy { $0.soundingTargetDefinition != nil && $0.instrumentNoiseProtocol == nil })
        XCTAssertTrue((tonal + atonal).allSatisfy { $0.requiredCaptureStateID != nil && $0.requiredCaptureStateFingerprint != nil && $0.requiredCaptureState == nil })
        XCTAssertFalse(compilation.captureStates.isEmpty)

        let actuatorNoise = compilation.roadmap.filter { $0.coverageKind == .instrumentNoise }
        XCTAssertTrue(actuatorNoise.contains { $0.component.parentComponentID == cymbal.id })
        XCTAssertTrue(actuatorNoise.contains { $0.component.parentComponentID == shutter.id })
        XCTAssertFalse(compilation.roadmap.contains { $0.soundingTargetDefinition != nil && $0.component.parentComponentID == shutter.id })
    }

    func testProgramChangeActivationAndDeactivationRemainIndependentWithExplicitBases() throws {
        let activation = ControlMessageDescriptor(messageType: .programChange, channel: 0, number: 20)
        let deactivation = ControlMessageDescriptor(messageType: .programChange, channel: 0, number: 21)
        let binding = ControlBinding(
            componentID: "siren",
            componentLabel: "Siren",
            direction: .bidirectional,
            channelNumberingBase: 1,
            dataNumberingBase: 1,
            activation: activation,
            deactivation: deactivation,
            verification: .roundTripVerified
        )
        XCTAssertTrue(binding.validationIssues.isEmpty)

        let data = try OrgRecCoding.encoder.encode(binding)
        let decoded = try OrgRecCoding.decoder.decode(ControlBinding.self, from: data)
        XCTAssertEqual(decoded.activation?.number, 20)
        XCTAssertEqual(decoded.deactivation?.number, 21)
        XCTAssertEqual(decoded.channelNumberingBase, 1)
        XCTAssertEqual(decoded.dataNumberingBase, 1)
    }

    func testMIDIParserHandlesRunningStatusAndNoteOnZeroAsRelease() {
        let messages = MIDI1MessageParser.parse([0x90, 60, 100, 61, 0, 0xB2, 7, 99])
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].0.messageType, .noteOn)
        XCTAssertEqual(messages[0].0.channel, 0)
        XCTAssertEqual(messages[1].0.messageType, .noteOff)
        XCTAssertEqual(messages[1].0.number, 61)
        XCTAssertEqual(messages[2].0.messageType, .controlChange)
        XCTAssertEqual(messages[2].0.channel, 2)
    }

    func testSharedHostClockAlignmentMapsPreRollAndInTakeEventsToExactFrames() {
        let takeID = UUID()
        let start = UInt64(10_000_000_000)
        let before = ControlEvent(
            controlProtocol: .midi1,
            message: .init(messageType: .noteOn, channel: 0, number: 60, value: 100),
            hostTimeTicks: 1,
            hostTimeNanoseconds: start - 100_000_000,
            timestampWasProvidedByTransport: true,
            rawDataHex: "90 3C 64"
        )
        let inTake = ControlEvent(
            controlProtocol: .midi1,
            message: .init(messageType: .noteOff, channel: 0, number: 60, value: 0),
            hostTimeTicks: 2,
            hostTimeNanoseconds: start + 1_500_000_000,
            timestampWasProvidedByTransport: false,
            rawDataHex: "80 3C 00"
        )
        let log = ControlEventLog(takeID: takeID, events: [before, inTake])
        let alignment = AudioControlAlignment.sharedHostClock(
            eventLog: log,
            audioStartHostTimeTicks: 10,
            audioStartHostTimeNanoseconds: start,
            audioStartSampleTime: 512,
            sampleRate: 48_000,
            frameCount: 96_000
        )

        XCTAssertEqual(alignment.status, .synchronizedSharedClock)
        XCTAssertEqual(alignment.driftPPM, 0)
        XCTAssertEqual(alignment.mappings[0].audioFrame, -4_800)
        XCTAssertFalse(alignment.mappings[0].withinRecordedAudio)
        XCTAssertEqual(alignment.mappings[1].audioFrame, 72_000)
        XCTAssertTrue(alignment.mappings[1].withinRecordedAudio)
        XCTAssertGreaterThan(alignment.mappings[1].uncertaintySeconds, alignment.mappings[0].uncertaintySeconds)
    }

    func testCaptureStateFingerprintIsSemanticAndImmutableAcrossEvidenceAndIdentity() {
        let stop = component(id: "stop-1", kind: "stop", label: "Tibia 8′")
        let first = CaptureStateSnapshot(
            name: "Tibia",
            source: .roadmapCompiler,
            assignments: [.enabled(component: stop, dimension: .stop, enabled: true, evidence: "compiler")]
        )
        let second = CaptureStateSnapshot(
            id: UUID(),
            name: "Operator confirmation",
            source: .operatorConfirmed,
            assignments: [.enabled(component: stop, dimension: .stop, enabled: true, evidence: "operator")]
        )
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.fingerprintSHA256, second.fingerprintSHA256)
        XCTAssertTrue(first.isStateEquivalent(to: second))
    }

    func testControlEventPackageRoundTripKeepsStateLogAndAlignmentTogether() throws {
        let takeID = UUID()
        let state = CaptureStateSnapshot(name: "Siren", source: .operatorConfirmed, assignments: [])
        let log = ControlEventLog(takeID: takeID)
        let alignment = AudioControlAlignment.sharedHostClock(
            eventLog: log,
            audioStartHostTimeTicks: 1,
            audioStartHostTimeNanoseconds: 1_000,
            audioStartSampleTime: 0,
            sampleRate: 48_000,
            frameCount: 48_000
        )
        let package = TakeControlEventPackage(eventLog: log, audioAlignment: alignment, captureStateSnapshot: state)
        let data = try OrgRecCoding.encoder.encode(package)
        let decoded = try OrgRecCoding.decoder.decode(TakeControlEventPackage.self, from: data)
        XCTAssertEqual(decoded.eventLog.takeID, takeID)
        XCTAssertEqual(decoded.audioAlignment?.eventLogID, log.id)
        XCTAssertEqual(decoded.captureStateSnapshot?.fingerprintSHA256, state.fingerprintSHA256)
    }

    func testExplicitPipeLocatorRemainsAnEnabledExactStateAssignment() {
        var pipe = component(id: "pipe-c4", kind: "pipe_position", label: "Documented C4")
        pipe.midiNote = 60
        let compilation = RoadmapEngine.compileSpecification(
            components: [pipe],
            recipe: CaptureRecipe(techniques: [.closePair]),
            setupIDs: [UUID()]
        )
        let item = try! XCTUnwrap(compilation.roadmap.first { $0.coverageKind == .explicitPipe })
        let state = try! XCTUnwrap(compilation.captureStates.first { $0.id == item.requiredCaptureStateID })
        XCTAssertTrue(state.assignments.contains {
            $0.subjectComponentID == pipe.locator.id && $0.dimension == .stop && $0.booleanValue == true
        })
    }
}
