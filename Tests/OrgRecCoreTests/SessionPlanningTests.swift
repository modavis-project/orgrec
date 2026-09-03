import Foundation
@testable import OrgRecCore
import XCTest

final class SessionPlanningTests: XCTestCase {
    func testLegacySessionDecodesWithoutPlanningAndNoiseFields() throws {
        let legacy = RecordingSession(sessionCode: "LEGACY", operatorName: "Operator")
        let encoded = try JSONEncoder().encode(legacy)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "sessionPlanID")
        object.removeValue(forKey: "sessionPlanRevision")
        object.removeValue(forKey: "noiseContextAssessment")
        object.removeValue(forKey: "noiseObservations")
        object.removeValue(forKey: "capturePreflightReports")

        let decoded = try JSONDecoder().decode(
            RecordingSession.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(decoded.sessionPlanID)
        XCTAssertNil(decoded.noiseContextAssessment)
        XCTAssertNil(decoded.noiseObservations)
        XCTAssertNil(decoded.capturePreflightReports)
        XCTAssertEqual(decoded.sessionCode, "LEGACY")
    }

    func testOverpassFeaturesClassifyAndPrioritizeWithoutPretendingToMeasureNoise() throws {
        let anchor = VenueAnchor(
            label: "Organ",
            displayAddress: "Test venue",
            coordinate: GeoCoordinate(latitude: 51.0, longitude: 12.0),
            precision: .building,
            source: "test"
        )
        let elements = [
            OverpassElement(
                type: "way", id: 1, lat: nil, lon: nil, center: nil,
                geometry: [
                    .init(lat: 51.0002, lon: 12.0),
                    .init(lat: 51.0004, lon: 12.0),
                ],
                tags: ["highway": "primary", "name": "Main Street"]
            ),
            OverpassElement(
                type: "node", id: 2, lat: 51.001, lon: 12.0, center: nil, geometry: nil,
                tags: ["amenity": "hospital", "name": "Hospital"]
            ),
            OverpassElement(
                type: "way", id: 3, lat: nil, lon: nil,
                center: .init(lat: 51.003, lon: 12.0), geometry: nil,
                tags: ["landuse": "construction", "name": "Building works"]
            ),
        ]

        let findings = NoiseContextService.findings(from: elements, anchor: anchor)
        XCTAssertEqual(Set(findings.map(\.category)), [.mainRoad, .emergencyOrHealthcare, .construction])
        let road = try XCTUnwrap(findings.first { $0.category == .mainRoad })
        XCTAssertEqual(road.planningPriority, .high)
        XCTAssertTrue(road.notes.contains("screening evidence"))
        XCTAssertEqual(road.evidenceConfidence, .medium)
    }

    func testSessionQueueIsSeparateFromRoadmapStateAndEstimatesStorage() throws {
        let project = DemoProjectFactory.make()
        let eligible = Array(SessionPlanningEngine.eligibleRoadmapItems(project).prefix(4))
        let originalStates = Dictionary(uniqueKeysWithValues: project.roadmap.map { ($0.id, $0.state) })
        let queue = SessionPlanningEngine.buildQueue(items: eligible, recipe: project.recipe, operatingOverheadSeconds: 10)
        let estimates = SessionPlanningEngine.estimates(
            queue: queue,
            roadmap: project.roadmap,
            sampleRate: 96_000,
            channelCount: 4,
            fixedPreparationSeconds: 0,
            setupChangeSeconds: 0,
            contingencyFraction: 0
        )

        XCTAssertEqual(queue.count, eligible.count)
        XCTAssertGreaterThan(estimates.totalSeconds, 0)
        XCTAssertGreaterThan(estimates.audioBytes, 0)
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: project.roadmap.map { ($0.id, $0.state) }), originalStates)
    }

    func testSessionQueueUsesProjectSetupOrderInsteadOfUUIDOrder() throws {
        let project = DemoProjectFactory.make()
        let setupOrder = project.setups.map(\.id)
        let onePerSetup = setupOrder.reversed().compactMap { setupID in
            SessionPlanningEngine.eligibleRoadmapItems(project).first { $0.setupID == setupID }
        }

        let queue = SessionPlanningEngine.buildQueue(
            items: onePerSetup,
            recipe: project.recipe,
            setupOrder: setupOrder
        )
        let roadmap = Dictionary(uniqueKeysWithValues: project.roadmap.map { ($0.id, $0) })
        let queuedSetups = queue.compactMap { roadmap[$0.roadmapItemID]?.setupID }

        XCTAssertEqual(queuedSetups, setupOrder.filter { queuedSetups.contains($0) })
    }

    func testInstrumentNoisePlannerExpandsDirectionsVelocitiesConfigurationsAndRepetitions() throws {
        let project = DemoProjectFactory.make()
        let source = try XCTUnwrap(project.roadmap.first?.component)
        let items = RoadmapEngine.instrumentNoiseItems(
            component: source,
            kind: .swellerJalousie,
            actions: [.opening, .closing],
            velocityPresets: [.slow, .normal, .fast],
            configurations: [
                InstrumentNoiseConfiguration(label: "Jalousie bank I", pedalActuationIncluded: true),
                InstrumentNoiseConfiguration(label: "Jalousie bank II", pedalActuationIncluded: true),
            ],
            minimumAcceptedTakeCount: 4,
            captureDurationSeconds: 12,
            recipeID: project.recipe.id,
            techniques: [.closePair],
            setupIDs: project.setups.map(\.id)
        )

        XCTAssertEqual(items.count, 12)
        XCTAssertTrue(items.allSatisfy { $0.coverageKind == .instrumentNoise })
        XCTAssertTrue(items.allSatisfy { $0.minimumAcceptedTakeCount == 4 })
        XCTAssertEqual(Set(items.compactMap { $0.instrumentNoiseProtocol?.velocity?.midiVelocity }), [32, 80, 127])
        XCTAssertEqual(Set(items.compactMap { $0.instrumentNoiseProtocol?.configuration.label }), ["Jalousie bank I", "Jalousie bank II"])
        XCTAssertTrue(items.allSatisfy { $0.instrumentNoiseProtocol?.temporalBehavior == .ramp })

        let queue = SessionPlanningEngine.buildQueue(
            items: [try XCTUnwrap(items.first)],
            recipe: project.recipe,
            operatingOverheadSeconds: 5
        )
        XCTAssertEqual(queue.first?.estimatedCaptureSeconds, 48)
        XCTAssertEqual(queue.first?.estimatedOperatingSeconds, 20)
    }

    func testInstrumentNoiseProtocolAndEventClassificationRoundTripAsTakeParadata() throws {
        let project = DemoProjectFactory.make()
        let source = try XCTUnwrap(project.roadmap.first?.component)
        let item = try XCTUnwrap(RoadmapEngine.instrumentNoiseItems(
            component: source,
            kind: .keyAction,
            actions: [.release],
            velocityPresets: [.fast],
            minimumAcceptedTakeCount: 3,
            recipeID: project.recipe.id,
            techniques: [.closePair]
        ).first)
        let protocolSnapshot = try XCTUnwrap(item.instrumentNoiseProtocol)
        let observedCurve = ActuationCurve(
            kind: .custom,
            timeBasis: .seconds,
            interpolation: .linear,
            points: [
                ActuationCurvePoint(time: 0, value: 1),
                ActuationCurvePoint(time: 0.11, value: 0.62),
                ActuationCurvePoint(time: 0.23, value: 0),
            ],
            durationSeconds: 0.23,
            evidenceSource: .operatorObserved,
            deviceLabel: "OrgRec operator-timed observation"
        )
        let take = TakeRecord(
            roadmapItemID: item.id,
            takeNumber: 2,
            relativeAudioPath: "Audio/Originals/test.wav",
            sampleRate: 96_000,
            channelCount: 2,
            instrumentNoiseParadata: InstrumentNoiseTakeParadata(
                protocolSnapshot: protocolSnapshot,
                repetitionNumber: 2,
                actionBeginSeconds: 1.2,
                actionEndSeconds: 1.4,
                actualVelocityLabel: "Fast",
                actualNormalizedVelocity: 0.94,
                actualDurationSeconds: 0.23,
                observedActuationCurve: observedCurve
            )
        )
        let annotation = TimedAnnotation(
            takeID: take.id,
            atSeconds: 1.2,
            code: "instrument_noise_actionBegin",
            severity: "info",
            text: "Key release",
            instrumentNoiseEvent: InstrumentNoiseEventAnnotation(protocolSnapshot: protocolSnapshot, marker: .actionBegin)
        )
        let decodedTake = try JSONDecoder().decode(TakeRecord.self, from: JSONEncoder().encode(take))
        let decodedAnnotation = try JSONDecoder().decode(TimedAnnotation.self, from: JSONEncoder().encode(annotation))

        XCTAssertEqual(decodedTake.instrumentNoiseParadata?.repetitionNumber, 2)
        XCTAssertEqual(decodedTake.instrumentNoiseParadata?.protocolSnapshot.velocity?.midiVelocity, 127)
        XCTAssertEqual(decodedTake.instrumentNoiseParadata?.protocolSnapshot.actuationProfile?.quantity, .position)
        XCTAssertEqual(decodedTake.instrumentNoiseParadata?.actualDurationSeconds, 0.23)
        XCTAssertEqual(decodedTake.instrumentNoiseParadata?.observedActuationCurve?.points.count, 3)
        XCTAssertEqual(decodedTake.instrumentNoiseParadata?.observedActuationCurve?.evidenceSource, .operatorObserved)
        XCTAssertEqual(decodedAnnotation.instrumentNoiseEvent?.sourceScope, .instrument)
        XCTAssertEqual(decodedAnnotation.instrumentNoiseEvent?.mechanisms, [.mechanical, .structuralContact])
        XCTAssertEqual(decodedAnnotation.instrumentNoiseEvent?.temporalBehavior, .releaseTransient)
    }

    func testActuationProfilePreservesShapeAndMirrorsDirectionalPositionActions() throws {
        let project = DemoProjectFactory.make()
        let source = try XCTUnwrap(project.roadmap.first?.component)
        let template = ActuationProfile(
            quantity: .position,
            unit: "mm",
            minimumValue: 0,
            maximumValue: 40,
            commandedCurve: ActuationCurve(
                kind: .custom,
                timeBasis: .normalized,
                interpolation: .monotoneCubic,
                points: [
                    ActuationCurvePoint(time: 0, value: 0),
                    ActuationCurvePoint(time: 0.3, value: 5),
                    ActuationCurvePoint(time: 1, value: 40),
                ],
                durationSeconds: 2.4,
                evidenceSource: .controllerCommanded,
                deviceLabel: "Expression controller",
                calibrationReference: "CAL-42",
                uncertainty: 0.2
            )
        )
        let items = RoadmapEngine.instrumentNoiseItems(
            component: source,
            kind: .swellerJalousie,
            actions: [.opening, .closing],
            configurations: [InstrumentNoiseConfiguration(label: "Jalousie bank II")],
            recipeID: project.recipe.id,
            techniques: [.closePair],
            actuationProfile: template
        )
        let opening = try XCTUnwrap(items.first { $0.instrumentNoiseProtocol?.action == .opening }?.instrumentNoiseProtocol?.actuationProfile)
        let closing = try XCTUnwrap(items.first { $0.instrumentNoiseProtocol?.action == .closing }?.instrumentNoiseProtocol?.actuationProfile)

        XCTAssertEqual(opening.commandedCurve.points.map(\.value), [0, 5, 40])
        XCTAssertEqual(closing.commandedCurve.points.map(\.value), [40, 35, 0])
        XCTAssertEqual(closing.commandedCurve.interpolation, .monotoneCubic)
        XCTAssertEqual(closing.commandedCurve.evidenceSource, .controllerCommanded)
        XCTAssertEqual(closing.commandedCurve.calibrationReference, "CAL-42")
        XCTAssertTrue(closing.validationIssues.isEmpty)
    }

    func testInvalidActuationCurveBlocksCaptureReadiness() throws {
        var project = DemoProjectFactory.make()
        let source = try XCTUnwrap(project.roadmap.first?.component)
        let invalidProfile = ActuationProfile(
            quantity: .position,
            unit: "normalized 0–1",
            minimumValue: 0,
            maximumValue: 1,
            commandedCurve: ActuationCurve(
                kind: .custom,
                points: [ActuationCurvePoint(time: 0, value: 0)],
                durationSeconds: 1,
                evidenceSource: .operatorPlanned
            )
        )
        let item = try XCTUnwrap(RoadmapEngine.instrumentNoiseItems(
            component: source,
            kind: .keyAction,
            actions: [.activation],
            recipeID: project.recipe.id,
            techniques: [.closePair],
            setupIDs: project.setups.map(\.id),
            actuationProfile: invalidProfile
        ).first)
        project.recordingSessions = [RecordingSession(sessionCode: "CURVE", operatorName: "Operator")]

        let issues = ProjectConsistencyAuditor.captureReadiness(project: project, item: item)
        XCTAssertTrue(issues.contains { $0.id == "readiness.actuation-curve" && $0.severity == .blocker })
    }

    func testNonPitchedInstrumentNoiseCaptureDoesNotRequireA4Calibration() throws {
        var project = DemoProjectFactory.make()
        let source = try XCTUnwrap(project.roadmap.first?.component)
        let item = try XCTUnwrap(RoadmapEngine.instrumentNoiseItems(
            component: source,
            kind: .blower,
            actions: [.steadyOperation],
            minimumAcceptedTakeCount: 2,
            recipeID: project.recipe.id,
            techniques: [.closePair],
            setupIDs: project.setups.map(\.id)
        ).first)
        project.recordingSessions = [RecordingSession(sessionCode: "MECH", operatorName: "Operator")]

        let issues = ProjectConsistencyAuditor.captureReadiness(project: project, item: item)
        XCTAssertFalse(issues.contains { $0.id == "readiness.pitch-calibration" })
        XCTAssertFalse(issues.contains { $0.id == "readiness.pitch-assumed" })
    }

    func testAdjacentUnnamedRailSegmentsAreConsolidatedWithoutLosingProvenance() throws {
        let anchor = VenueAnchor(
            label: "Organ",
            displayAddress: "Test venue",
            coordinate: GeoCoordinate(latitude: 51, longitude: 12),
            precision: .building,
            source: "test"
        )
        var elements: [OverpassElement] = (0..<5).map { index in
            let start = 51.0001 + Double(index) * 0.00015
            return OverpassElement(
                type: "way",
                id: Int64(100 + index),
                lat: nil,
                lon: nil,
                center: nil,
                geometry: [
                    .init(lat: start, lon: 12),
                    .init(lat: start + 0.00015, lon: 12),
                ],
                tags: ["railway": "tram"]
            )
        }
        elements.append(OverpassElement(
            type: "way",
            id: 200,
            lat: nil,
            lon: nil,
            center: nil,
            geometry: [
                .init(lat: 51.005, lon: 12),
                .init(lat: 51.0052, lon: 12),
            ],
            tags: ["railway": "tram"]
        ))

        let rail = NoiseContextService.findings(from: elements, anchor: anchor)
            .filter { $0.category == .railOrTram }

        XCTAssertEqual(rail.count, 2)
        let aggregate = try XCTUnwrap(rail.first { $0.tags["orgrec:aggregated_source_count"] == "5" })
        XCTAssertTrue(aggregate.sourceIdentifier.hasPrefix("osm:aggregate/railOrTram/"))
        XCTAssertTrue(aggregate.notes.contains("consolidated 5"))
        XCTAssertEqual(aggregate.tags["orgrec:aggregated_source_ids"]?.split(separator: ",").count, 5)
    }

    func testDenseCategoriesUsePriorityAndDistanceReviewBudgets() throws {
        let anchor = VenueAnchor(
            label: "Organ",
            displayAddress: "Test venue",
            coordinate: GeoCoordinate(latitude: 51, longitude: 12),
            precision: .building,
            source: "test"
        )
        let schools = (0..<25).map { index in
            OverpassElement(
                type: "node",
                id: Int64(300 + index),
                lat: 51 + Double(index + 1) * 0.0001,
                lon: 12,
                center: nil,
                geometry: nil,
                tags: ["amenity": "school", "name": "School \(index)"]
            )
        }

        let retained = NoiseContextService.findings(from: schools, anchor: anchor)
            .filter { $0.category == .education }

        XCTAssertEqual(retained.count, 10)
        XCTAssertEqual(retained.first?.label, "School 0")
        XCTAssertEqual(retained.last?.label, "School 9")
    }

    func testPlannedQueueControlsNextItem() throws {
        var project = DemoProjectFactory.make()
        let eligible = SessionPlanningEngine.eligibleRoadmapItems(project)
        let chosen = try XCTUnwrap(eligible.last)
        let plan = RecordingSessionPlan(
            title: "Focused session",
            purpose: "Test",
            organMDVSID: project.organMDVSID,
            navigatorSnapshotSHA256: project.snapshot.payloadSHA256,
            plannedStart: .now,
            plannedEnd: .now.addingTimeInterval(3_600),
            queue: [SessionPlanQueueItem(roadmapItemID: chosen.id, order: 0, estimatedCaptureSeconds: 9, estimatedOperatingSeconds: 10)]
        )
        project.sessionPlans = [plan]
        let session = RecordingSession(sessionCode: "PLAN", sessionPlanID: plan.id, sessionPlanRevision: 1)

        XCTAssertEqual(SessionPlanningEngine.nextPlannedRoadmapItem(in: project, session: session)?.id, chosen.id)
    }

    func testSessionAndTakeProvenanceFreezeNoiseAssessment() throws {
        let project = DemoProjectFactory.make()
        let item = try XCTUnwrap(project.roadmap.first)
        let assessment = makeAssessment()
        var session = RecordingSession(
            sessionCode: "NOISE-1",
            operatorName: "Operator",
            noiseContextAssessment: assessment
        )
        let snapshot = TakeProvenanceSnapshot(
            session: session,
            recipe: project.recipe,
            microphoneSetup: nil,
            registration: nil,
            component: item.component,
            releaseBinding: project.snapshot.release,
            navigatorPayloadSHA256: project.snapshot.payloadSHA256,
            organMDVSID: project.organMDVSID
        )
        session.noiseContextAssessment?.findings[0].label = "Changed later"

        XCTAssertEqual(snapshot.noiseContextAssessment?.findings[0].label, "Primary road")
        XCTAssertEqual(snapshot.noiseContextAssessment?.querySHA256, String(repeating: "a", count: 64))
    }

    func testIADSessionRoundTripIncludesStructuredNoiseParadata() throws {
        let assessment = makeAssessment()
        let planID = UUID()
        let observation = NoiseObservation(category: .mainRoad, label: "Audible traffic", takeID: UUID(), atSeconds: 2.5)
        let record = IADSessionRecord(
            localSessionID: UUID(),
            targetTables: ["prov.activity", "audio.recording_session"],
            projectionStatus: IADContract.projectionMode,
            sessionCode: "IAD-NOISE",
            organStateMDVSID: "MDVS:ORGN:TEST",
            venueLabel: "Venue",
            startedAt: .now,
            endedAt: nil,
            operatorName: "Operator",
            institution: "Institute",
            purpose: "Research",
            rightsStatement: "Permitted",
            timezoneIdentifier: "Europe/Berlin",
            clockSource: "System clock",
            venueCondition: assessment.summary,
            environmentalConditions: EnvironmentReading(),
            notes: "",
            sessionPlanID: planID,
            sessionPlanRevision: 2,
            surroundingNoiseAssessment: assessment,
            observedNoiseIncidents: [observation]
        )
        let decoded = try JSONDecoder().decode(IADSessionRecord.self, from: JSONEncoder().encode(record))

        XCTAssertEqual(decoded.sessionPlanID, planID)
        XCTAssertEqual(decoded.surroundingNoiseAssessment?.findings.first?.category, .mainRoad)
        XCTAssertEqual(decoded.observedNoiseIncidents?.first?.atSeconds, 2.5)
    }

    func testConsistencyAuditorReportsMissingPlanAndNoiseContext() {
        var project = DemoProjectFactory.make()
        project.recordingSessions = [RecordingSession(
            sessionCode: "BROKEN",
            operatorName: "Operator",
            sessionPlanID: UUID()
        )]
        let report = ProjectConsistencyAuditor.audit(project: project)
        XCTAssertTrue(report.issues.contains { $0.id.contains("noise-context") })
        XCTAssertTrue(report.issues.contains { $0.id.contains(".plan") && $0.severity == .blocker })
    }

    private func makeAssessment() -> NoiseContextAssessment {
        let anchor = VenueAnchor(
            label: "Organ",
            displayAddress: "Venue",
            coordinate: GeoCoordinate(latitude: 51, longitude: 12),
            precision: .building,
            source: "OpenStreetMap"
        )
        return NoiseContextAssessment(
            venueAnchor: anchor,
            querySHA256: String(repeating: "a", count: 64),
            findings: [NoiseContextFinding(
                sourceIdentifier: "osm:way/1",
                label: "Primary road",
                category: .mainRoad,
                coordinate: GeoCoordinate(latitude: 51.0002, longitude: 12),
                distanceMeters: 22,
                temporalPattern: .persistent,
                planningPriority: .high,
                evidenceConfidence: .medium,
                disposition: .confirmed
            )]
        )
    }
}
