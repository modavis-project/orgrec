import AVFAudio
import XCTest
@testable import OrgRecCore

final class ComplexCaptureP1Tests: XCTestCase {
    private let snapshot = Data("complex-capture-p1".utf8).sha256Hex

    private func component(
        id: String,
        kind: String,
        label: String,
        low: Int? = nil,
        high: Int? = nil
    ) -> OrganComponent {
        OrganComponent(
            id: id,
            kind: kind,
            label: label,
            division: "Solo",
            locator: ComponentLocator(
                id: id,
                organMDVSID: "MDVS:ORGN:P1",
                snapshotSHA256: snapshot,
                kind: kind,
                label: label,
                trust: .sourceBound
            ),
            playableMIDILow: low,
            playableMIDIHigh: high,
            referencePitchHz: 440
        )
    }

    func testPhysicalInputsKeepMIDIVelocitySeparateFromPhysicalIntensity() throws {
        let path = ActuationCurve(
            kind: .custom,
            points: [.init(time: 0, value: 0), .init(time: 0.5, value: 0.2), .init(time: 1, value: 1)],
            durationSeconds: 1.4,
            evidenceSource: .sensorObserved,
            deviceLabel: "Pedal encoder"
        )
        let variant = PhysicalActuationVariant(
            label: "Early-release forte",
            midiVelocity: 42,
            gateDurationSeconds: 0.18,
            deactivationOffsetSeconds: 0.12,
            deactivationOffsetReference: .activationCommand,
            actuatorRoute: "pneumatic relay A",
            forceNewtons: 18,
            pressurePascals: 6_400,
            controllerValue: 73,
            controllerUnit: "raw CC",
            pedalPath: path,
            evidence: .sensorObserved
        )

        XCTAssertTrue(variant.validationIssues.isEmpty)
        XCTAssertEqual(variant.midiVelocity, 42)
        XCTAssertEqual(variant.input(.force)?.numericValue, 18)
        XCTAssertEqual(variant.input(.pressure)?.numericValue, 6_400)
        XCTAssertEqual(variant.input(.gateDuration)?.numericValue, 0.18)
        XCTAssertEqual(variant.input(.deactivationOffset)?.reference, DeactivationOffsetReference.activationCommand.rawValue)
        XCTAssertEqual(variant.input(.actuatorRoute)?.textValue, "pneumatic relay A")
        XCTAssertNotEqual(variant.input(.midiVelocity)?.id, variant.input(.force)?.id)

        let roundTrip = try OrgRecCoding.decoder.decode(
            PhysicalActuationVariant.self,
            from: OrgRecCoding.encoder.encode(variant)
        )
        XCTAssertEqual(roundTrip, variant)
    }

    func testRepeatingProcessRequiresBoundsAndCancellationAndRejectsCycles() {
        let timing = ProcessTimingEnvelope(minimumSeconds: 0.2, typicalSeconds: 0.4, maximumSeconds: 0.8, distribution: .logNormal)
        let first = CaptureProcessStage(id: "start", label: "Start", action: .activate, childStageIDs: ["repeat"], duration: timing)
        let second = CaptureProcessStage(id: "repeat", label: "Repeat", action: .repeatChildren, duration: timing, repetitionInterval: timing, minimumRepeats: 1, maximumRepeats: 8)
        let invalid = CaptureProcessModel(
            name: "Roll", kind: .irregular, ordering: .sequential,
            rootStageIDs: ["start"], stages: [first, second],
            terminationConditions: [.init(kind: .completed)]
        )
        XCTAssertTrue(invalid.validationIssues.contains { $0.contains("hard iteration or duration bound") })
        XCTAssertTrue(invalid.validationIssues.contains { $0.contains("cancellation path") })

        let valid = CaptureProcessModel(
            name: "Roll", kind: .irregular, ordering: .sequential,
            rootStageIDs: ["start"], stages: [first, second],
            terminationConditions: [.init(kind: .manual, description: "Operator cancel")],
            maximumIterations: 8,
            maximumDurationSeconds: 20
        )
        XCTAssertTrue(valid.validationIssues.isEmpty)

        var cyclicFirst = first
        var cyclicSecond = second
        cyclicFirst.childStageIDs = ["repeat"]
        cyclicSecond.childStageIDs = ["start"]
        let cyclic = CaptureProcessModel(
            name: "Cycle", kind: .composite, ordering: .sequential,
            rootStageIDs: ["start"], stages: [cyclicFirst, cyclicSecond],
            terminationConditions: [.init(kind: .manual)]
        )
        XCTAssertTrue(cyclic.validationIssues.contains { $0.contains("acyclic") })
    }

    func testDiscreteShutterTopologyResolvesDirectionAndProducesExactStateObligations() throws {
        let enclosure = component(id: "solo-box", kind: "enclosure", label: "Solo box")
        let shutters = (1...3).map { ShutterElement(id: "s\($0)", label: "Shutter \($0)", sequenceIndex: $0 - 1) }
        let states = (0...3).map { count in
            DiscreteShutterState(
                id: "open-\(count)",
                label: "\(count) open",
                shutterOpenness: Dictionary(uniqueKeysWithValues: shutters.map { ($0.id, $0.sequenceIndex < count ? 1.0 : 0.0) })
            )
        }
        let topology = DiscreteShutterTopology(
            name: "Solo jalousie",
            enclosureComponentID: enclosure.id,
            pedalComponentID: "solo-expression-pedal",
            shutters: shutters,
            states: states,
            pedalMapping: [
                .init(pedalPosition: 0, shutterStateID: "open-0", direction: .opening),
                .init(pedalPosition: 0.4, shutterStateID: "open-1", direction: .opening),
                .init(pedalPosition: 0.7, shutterStateID: "open-2", direction: .opening),
                .init(pedalPosition: 1, shutterStateID: "open-3", direction: .opening),
                .init(pedalPosition: 0, shutterStateID: "open-0", direction: .closing),
                .init(pedalPosition: 0.3, shutterStateID: "open-1", direction: .closing),
                .init(pedalPosition: 0.6, shutterStateID: "open-2", direction: .closing),
                .init(pedalPosition: 1, shutterStateID: "open-3", direction: .closing),
            ]
        )
        XCTAssertTrue(topology.validationIssues.isEmpty)
        XCTAssertEqual(topology.state(at: 0.65, direction: .opening)?.id, "open-1")
        XCTAssertEqual(topology.state(at: 0.65, direction: .closing)?.id, "open-3")

        let items = RoadmapEngine.shutterMappingItems(
            component: enclosure,
            topology: topology,
            minimumAcceptedTakeCount: 2,
            recipe: CaptureRecipe(techniques: [.closePair]),
            techniques: [.closePair],
            setupIDs: [UUID()]
        )
        XCTAssertEqual(items.count, 8)
        let target = try XCTUnwrap(items.first { $0.complexCaptureProtocol?.targetShutterStateID == "open-2" && $0.complexCaptureProtocol?.pedalTravelDirection == .opening })
        let state = RoadmapEngine.requiredCaptureState(for: target, registration: nil, components: [enclosure])
        XCTAssertTrue(state.assignments.contains { $0.dimension == .shutter && $0.textValue == "2 open" })
    }

    func testTremulantPlanCreatesPairedSteadyAndTransitionCoverage() {
        let tremulant = component(id: "trem-solo", kind: "accessory", label: "Solo tremulant")
        let stop = component(id: "tibia", kind: "stop", label: "Tibia 8′", low: 48, high: 72)
        let plan = RoadmapEngine.tremulantResponsePlan(
            tremulant: tremulant,
            affectedStops: [stop],
            scope: .representative,
            minimumAcceptedTakeCount: 2,
            recipe: CaptureRecipe(techniques: [.closePair]),
            techniques: [.closePair],
            setupIDs: [UUID()]
        )

        XCTAssertEqual(plan.registrations.count, 4)
        XCTAssertEqual(plan.items.count, 12)
        XCTAssertEqual(Set(plan.items.compactMap { $0.complexCaptureProtocol?.tremulant?.condition }), Set(TremulantCaptureCondition.allCases))
        for item in plan.items {
            let registration = plan.registrations.first { $0.id == item.registrationID }
            let state = RoadmapEngine.requiredCaptureState(for: item, registration: registration, components: [tremulant, stop])
            let tremState = state.assignments.first { $0.dimension == .tremulant && $0.subjectComponentID == tremulant.id }
            let condition = item.complexCaptureProtocol?.tremulant?.condition
            XCTAssertEqual(tremState?.booleanValue, condition == .steadyWithTremulant || condition == .deactivationTransition)
        }
    }

    func testOperationalBaselineIsLongUnprocessedAndDoesNotRequirePitchCalibration() throws {
        let blower = component(id: "blower", kind: "blower", label: "Main blower")
        let assignment = CaptureStateAssignment(
            subjectComponentID: blower.id,
            subjectLabel: blower.label,
            dimension: .blower,
            valueKind: .boolean,
            booleanValue: true,
            evidence: "test"
        )
        let baseline = OperationalBaselineProtocol(
            kind: .blowerSteady,
            subsystemComponentIDs: [blower.id],
            requiredStateAssignments: [assignment],
            minimumDurationSeconds: 30,
            preservationRole: .virtualizationLayer,
            automaticDenoisingPermitted: false
        )
        XCTAssertEqual(baseline.minimumDurationSeconds, 120)
        XCTAssertFalse(baseline.automaticDenoisingPermitted)
        XCTAssertTrue(baseline.requiredStatistics.contains("L90"))

        let item = try XCTUnwrap(RoadmapEngine.operationalBaselineItems(
            component: blower,
            baseline: baseline,
            recipe: CaptureRecipe(techniques: [.closePair]),
            techniques: [.closePair],
            setupIDs: [UUID()]
        ).first)
        XCTAssertEqual(item.coverageKind, .operationalBaseline)
        XCTAssertNil(item.component.midiNote)
        let queue = SessionPlanningEngine.buildQueue(items: [item], recipe: CaptureRecipe(techniques: [.closePair]))
        XCTAssertEqual(queue.first?.estimatedCaptureSeconds, 120)

        var project = DemoProjectFactory.make()
        project.roadmap = [item]
        project.recordingSessions = [RecordingSession(
            sessionCode: "P1-BASELINE",
            operatorName: "Operator",
            purpose: "Capture blower layer",
            environment: EnvironmentReading(temperatureCelsius: 20, relativeHumidityPercent: 50)
        )]
        let readiness = ProjectConsistencyAuditor.captureReadiness(project: project, item: item)
        XCTAssertFalse(readiness.contains { $0.id == "readiness.pitch-calibration" })
    }

    func testMeasuredResponseFunctionAggregatesReviewedTakeEvidence() {
        var project = DemoProjectFactory.make()
        let itemID = project.roadmap[0].id
        let variant = PhysicalActuationVariant(label: "Measured", gateDurationSeconds: 0.2, forceNewtons: 12)
        let protocolSnapshot = ComplexCaptureProtocol(
            kind: .physicalActuatorResponse,
            name: "Cymbal actuator",
            sourceComponentID: "cymbal-actuator",
            physicalActuation: variant
        )
        let takeID = UUID()
        let observation = ActuatorResponseObservation(
            takeID: takeID,
            variantID: variant.id,
            inputs: variant.inputs,
            peakLevelDBFS: -8,
            rmsLevelDBFS: -20,
            acousticOnsetLatencySeconds: 0.03,
            acousticDurationSeconds: 1.4,
            takeStatus: .accepted
        )
        let variant2 = PhysicalActuationVariant(label: "Measured forte", gateDurationSeconds: 0.4, forceNewtons: 24)
        let protocol2 = ComplexCaptureProtocol(
            kind: .physicalActuatorResponse,
            name: "Cymbal actuator",
            sourceComponentID: "cymbal-actuator",
            physicalActuation: variant2
        )
        let takeID2 = UUID()
        let observation2 = ActuatorResponseObservation(
            takeID: takeID2,
            variantID: variant2.id,
            inputs: variant2.inputs,
            peakLevelDBFS: -4,
            rmsLevelDBFS: -16,
            acousticOnsetLatencySeconds: 0.02,
            acousticDurationSeconds: 1.8,
            takeStatus: .accepted
        )
        project.takes = [TakeRecord(
            id: takeID,
            roadmapItemID: itemID,
            takeNumber: 1,
            status: .accepted,
            relativeAudioPath: "Audio/Originals/response.wav",
            sampleRate: 48_000,
            channelCount: 2,
            complexCaptureParadata: ComplexCaptureTakeParadata(
                protocolSnapshot: protocolSnapshot,
                repetitionNumber: 1,
                actuatorResponseObservation: observation
            )
        ), TakeRecord(
            id: takeID2,
            roadmapItemID: itemID,
            takeNumber: 2,
            status: .accepted,
            relativeAudioPath: "Audio/Originals/response-2.wav",
            sampleRate: 48_000,
            channelCount: 2,
            complexCaptureParadata: ComplexCaptureTakeParadata(
                protocolSnapshot: protocol2,
                repetitionNumber: 2,
                actuatorResponseObservation: observation2
            )
        )]

        let functions = ComplexCaptureAnalysisEngine.responseFunctions(project: project)
        XCTAssertEqual(functions.count, 1)
        XCTAssertEqual(functions[0].status, .reviewed)
        XCTAssertEqual(functions[0].inputDimensions, [.force, .gateDuration])
        XCTAssertEqual(functions[0].observations.first?.acousticOnsetLatencySeconds, 0.03)
        let forceToPeak = functions[0].transferEstimates?.first {
            $0.inputDimension == .force && $0.outputDimension == "peak-level-dBFS"
        }
        XCTAssertEqual(forceToPeak?.sampleCount, 2)
        XCTAssertEqual(forceToPeak?.slope ?? 0, 1.0 / 3.0, accuracy: 0.000_1)
        XCTAssertEqual(Set(forceToPeak?.contributingTakeIDs ?? []), [takeID, takeID2])
    }

    func testOperationalBaselineAnalyzerStreamsLevelDistributionAndSpectrum() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-p1-baseline-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let sampleRate = 8_000.0
        let frames = Int(sampleRate * 3)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
            buffer.frameLength = AVAudioFrameCount(frames)
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            let angularFrequency = 2.0 * Double.pi * 250.0 / sampleRate
            for frame in 0..<frames {
                samples[frame] = Float(0.1 * sin(angularFrequency * Double(frame)))
            }
            try file.write(from: buffer)
        }

        let result = try OperationalBaselineAnalyzer.analyze(fileURL: url, referenceChannel: 0)
        XCTAssertEqual(result.analyzedDurationSeconds, 3, accuracy: 0.01)
        XCTAssertEqual(result.peakDBFS, -20, accuracy: 0.2)
        XCTAssertEqual(result.rmsDBFS, -23.01, accuracy: 0.3)
        XCTAssertEqual(result.octaveBandLevels.count, 10)
        XCTAssertTrue(result.warnings.contains { $0.contains("shorter than the two-minute") })
        let strongest = result.octaveBandLevels.max { $0.levelDBFS < $1.levelDBFS }
        XCTAssertEqual(strongest?.centerFrequencyHz, 250)
    }
}
