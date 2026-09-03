import Foundation
@testable import OrgRecCore
import XCTest

final class CollectionAnalysisV2Tests: XCTestCase {
    private let fixtureDate = Date(timeIntervalSince1970: 1_800_000_000)
    private let fixtureOrganID = "MDVS:ORGN:COLLECTION-V2-TEST"
    private let fixtureSnapshotSHA256 = String(repeating: "a", count: 64)

    func testRobustRepeatedMedianSlopeAndOutlierResistExtremeEndpoint() throws {
        let rankID = "rank:robust-slope"
        let items = (60...67).enumerated().map { offset, midi in
            makeItem(seed: 100 + offset, midi: midi, parentID: rankID)
        }
        let outlierID = uuid(208)
        let takes = items.enumerated().map { offset, item in
            let trend = 0.5 * Double(offset)
            return makeTake(
                id: offset == items.count - 1 ? outlierID : uuid(201 + offset),
                item: item,
                analysis: goodAnalysis(cents: trend + (offset == items.count - 1 ? 80 : 0))
            )
        }

        let report = try XCTUnwrap(CollectionAnalysisEngine.analyze(project: makeProject(items: items, takes: takes)))
        let profile = try XCTUnwrap(report.rankTuningProfiles.first { $0.rankComponentID == rankID })

        XCTAssertEqual(profile.points.count, 8)
        XCTAssertEqual(try XCTUnwrap(profile.stretchCentsPerOctave), 6, accuracy: 1e-9)
        XCTAssertEqual(profile.outlierTakeIDs, [outlierID])
        XCTAssertEqual(profile.groupingBasis, "declared-parent-component")
        XCTAssertTrue(profile.slopeMethod?.contains("Siegel repeated-median") == true)
    }

    func testParentlessComponentsUseOneExplicitlyInferredRankGrouping() throws {
        let items = (60...62).enumerated().map { offset, midi in
            makeItem(
                seed: 300 + offset,
                midi: midi,
                parentID: nil,
                label: "Principal 8′",
                division: "Great",
                footHeight: "8′"
            )
        }
        let takes = items.enumerated().map { offset, item in
            makeTake(id: uuid(311 + offset), item: item, analysis: goodAnalysis(cents: Double(offset)))
        }

        let report = try XCTUnwrap(CollectionAnalysisEngine.analyze(project: makeProject(items: items, takes: takes)))
        let profile = try XCTUnwrap(report.rankTuningProfiles.first)

        XCTAssertEqual(report.rankTuningProfiles.count, 1)
        XCTAssertEqual(profile.points.map(\.midiNote), [60, 61, 62])
        XCTAssertEqual(profile.groupingBasis, "inferred-division-label-footage-signature")
        XCTAssertTrue(profile.rankComponentID.hasPrefix("urn:orgrec:inferred-rank:"))
    }

    func testEvidenceQualityExclusionsRemainVisibleInSummary() throws {
        let rankID = "rank:evidence"
        let items = (60...63).enumerated().map { offset, midi in
            makeItem(seed: 400 + offset, midi: midi, parentID: rankID)
        }
        let validID = uuid(411)
        let missingID = uuid(412)
        let criticalID = uuid(413)
        let lowQualityID = uuid(414)
        let takes = [
            makeTake(id: validID, item: items[0], analysis: goodAnalysis(cents: 0)),
            makeTake(id: missingID, item: items[1], analysis: nil),
            makeTake(
                id: criticalID,
                item: items[2],
                analysis: goodAnalysis(cents: 2, estimatorSeverity: .critical)
            ),
            makeTake(
                id: lowQualityID,
                item: items[3],
                analysis: AnalysisSummary(
                    method: "fixture",
                    algorithmVersion: "fixture/2",
                    frequencyHz: 440,
                    confidence: 0,
                    centsDeviation: 3,
                    clippedSamples: 1,
                    pitchApplicability: .monophonic,
                    pitchEstimatorComparison: PitchEstimatorComparison(
                        estimates: [],
                        differenceCents: nil,
                        severity: .unavailable,
                        rationale: "Deliberately weak fixture evidence."
                    )
                )
            ),
        ]

        let report = try XCTUnwrap(CollectionAnalysisEngine.analyze(project: makeProject(items: items, takes: takes)))
        let summary = try XCTUnwrap(report.evidenceSummary)
        let evidence = try XCTUnwrap(report.takeEvidence)

        XCTAssertEqual(summary.eligibleTakeCount, 4)
        XCTAssertEqual(summary.analyzedTakeCount, 3)
        XCTAssertEqual(summary.aggregateTakeCount, 1)
        XCTAssertEqual(summary.highQualityCount, 1)
        XCTAssertEqual(summary.excludedCount, 3)
        XCTAssertEqual(summary.aggregateCoverage, 0.25, accuracy: 1e-12)
        XCTAssertEqual(report.assessedTakeIDs, [validID, missingID, criticalID, lowQualityID].sorted(by: uuidOrder))
        XCTAssertEqual(report.contributingTakeIDs, [validID])
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: summary.exclusions.map { ($0.reason, $0.count) }),
            [
                "critical-estimator-mismatch": 1,
                "missing-analysis": 1,
                "quality-score-below-aggregate-threshold": 1,
            ]
        )
        XCTAssertEqual(evidence.first { $0.takeID == missingID }?.tier, .excluded)
        XCTAssertEqual(evidence.first { $0.takeID == criticalID }?.exclusionReasons, ["critical-estimator-mismatch"])
        XCTAssertEqual(evidence.first { $0.takeID == lowQualityID }?.exclusionReasons, ["quality-score-below-aggregate-threshold"])
    }

    func testSessionDriftIsIndeterminateWithoutRepeatedTargets() throws {
        let session = makeSession(seed: 500)
        let setupID = uuid(501)
        let items = (60...62).enumerated().map { offset, midi in
            makeItem(
                seed: 510 + offset,
                midi: midi,
                parentID: "rank:no-repeat",
                physicalTargetID: "target:\(offset)",
                setupID: setupID
            )
        }
        let takes = items.enumerated().map { offset, item in
            makeTake(
                id: uuid(520 + offset),
                item: item,
                startedAt: fixtureDate.addingTimeInterval(Double(offset) * 3_600),
                analysis: goodAnalysis(cents: Double(offset * 20 - 20)),
                session: session
            )
        }

        let project = makeProject(items: items, takes: takes, sessions: [session])
        let drift = try XCTUnwrap(CollectionAnalysisEngine.analyze(project: project)?.sessionPitchDrift.first)

        XCTAssertNil(drift.driftCentsPerHour)
        XCTAssertNil(drift.driftLowerBoundCentsPerHour)
        XCTAssertNil(drift.driftUpperBoundCentsPerHour)
        XCTAssertEqual(drift.repeatedTargetCount, 0)
        XCTAssertEqual(drift.pairComparisonCount, 0)
        XCTAssertEqual(try XCTUnwrap(drift.durationHours), 2, accuracy: 1e-12)
        XCTAssertEqual(drift.applicability, "indeterminate")
        XCTAssertNil(drift.slopeMethod)
    }

    func testSessionDriftRecoversWithinTargetSlopeDespiteDifferentBaselines() throws {
        let session = makeSession(seed: 600)
        let setupID = uuid(601)
        let baselines = [-20.0, 0.0, 30.0]
        let items = baselines.indices.map { index in
            makeItem(
                seed: 610 + index,
                midi: 60 + index,
                parentID: "rank:repeated-drift",
                physicalTargetID: "repeated-target:\(index)",
                setupID: setupID
            )
        }
        var takes: [TakeRecord] = []
        for index in items.indices {
            takes.append(makeTake(
                id: uuid(620 + index * 2),
                item: items[index],
                startedAt: fixtureDate,
                analysis: goodAnalysis(cents: baselines[index]),
                session: session
            ))
            takes.append(makeTake(
                id: uuid(621 + index * 2),
                item: items[index],
                startedAt: fixtureDate.addingTimeInterval(2 * 3_600),
                analysis: goodAnalysis(cents: baselines[index] + 4),
                session: session
            ))
        }

        let project = makeProject(items: items, takes: takes, sessions: [session])
        let drift = try XCTUnwrap(CollectionAnalysisEngine.analyze(project: project)?.sessionPitchDrift.first)

        XCTAssertEqual(try XCTUnwrap(drift.driftCentsPerHour), 2, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(drift.driftLowerBoundCentsPerHour), 2, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(drift.driftUpperBoundCentsPerHour), 2, accuracy: 1e-12)
        XCTAssertEqual(drift.repeatedTargetCount, 3)
        XCTAssertEqual(drift.pairComparisonCount, 3)
        XCTAssertEqual(try XCTUnwrap(drift.durationHours), 2, accuracy: 1e-12)
        XCTAssertEqual(drift.applicability, "applicable")
        XCTAssertTrue(drift.slopeMethod?.contains("within-target") == true)
    }

    func testSimilarityAlignsPartialTracksByHarmonicNumber() throws {
        let setupID = uuid(700)
        let firstItem = makeItem(
            seed: 701,
            midi: 60,
            parentID: "rank:similarity-a",
            physicalTargetID: "target:similarity-a",
            setupID: setupID
        )
        let secondItem = makeItem(
            seed: 702,
            midi: 60,
            parentID: "rank:similarity-b",
            physicalTargetID: "target:similarity-b",
            setupID: setupID
        )
        let levels: [Int: Double] = [1: 0, 2: -3, 3: -6, 4: -9, 5: -12, 6: -15]
        let firstPartials = try [1, 2, 3, 4, 5, 6].map { try partialTrack(harmonic: $0, peakDB: levels[$0]!) }
        let secondPartials = try [4, 1, 6, 2, 5, 3].map { try partialTrack(harmonic: $0, peakDB: levels[$0]!) }
        let firstID = uuid(711)
        let secondID = uuid(712)
        let takes = [
            makeTake(id: firstID, item: firstItem, analysis: goodAnalysis(cents: 0), partialTracks: firstPartials),
            makeTake(id: secondID, item: secondItem, analysis: goodAnalysis(cents: 0), partialTracks: secondPartials),
        ]

        let report = try XCTUnwrap(CollectionAnalysisEngine.analyze(
            project: makeProject(items: [firstItem, secondItem], takes: takes)
        ))
        let candidate = try XCTUnwrap(report.acousticSimilarityCandidates.first)

        XCTAssertEqual(report.acousticSimilarityCandidates.count, 1)
        XCTAssertEqual(Set([candidate.firstTakeID, candidate.secondTakeID]), Set([firstID, secondID]))
        XCTAssertEqual(candidate.sharedPartialCount, 6)
        XCTAssertEqual(candidate.cosineSimilarity, 1, accuracy: 1e-12)
        XCTAssertTrue(candidate.reason.contains("physical-pipe evidence"))
    }

    func testInjectedIdentityAndDateProducePermutationStableReport() throws {
        let items = (60...63).enumerated().map { offset, midi in
            makeItem(seed: 800 + offset, midi: midi, parentID: "rank:deterministic")
        }
        let takes = items.enumerated().map { offset, item in
            makeTake(id: uuid(810 + offset), item: item, analysis: goodAnalysis(cents: Double(offset)))
        }
        let reportID = uuid(899)
        let analyzedAt = fixtureDate.addingTimeInterval(12_345)
        let first = try XCTUnwrap(CollectionAnalysisEngine.analyze(
            project: makeProject(items: items, takes: takes),
            id: reportID,
            analyzedAt: analyzedAt
        ))
        let second = try XCTUnwrap(CollectionAnalysisEngine.analyze(
            project: makeProject(items: items.reversed(), takes: takes.reversed()),
            id: reportID,
            analyzedAt: analyzedAt
        ))

        XCTAssertEqual(first.id, reportID)
        XCTAssertEqual(first.analyzedAt, analyzedAt)
        XCTAssertEqual(first, second)
        XCTAssertEqual(try OrgRecCoding.encoder.encode(first), try OrgRecCoding.encoder.encode(second))
    }

    func testLegacyV1CollectionReportRemainsDecodable() throws {
        let legacy = Data(#"""
        {
          "contractVersion": "orgrec-collection-analysis/1",
          "id": "00000000-0000-0000-0000-000000000901",
          "analyzedAt": "2026-01-01T00:00:00Z",
          "sourceAnalysisRunIDs": [],
          "rankTuningProfiles": [
            {
              "rankComponentID": "rank:legacy",
              "rankLabel": "Legacy rank",
              "points": [
                {
                  "midiNote": 60,
                  "medianDeviationCents": 1.5,
                  "medianAbsoluteDeviationCents": 0.5,
                  "takeIDs": []
                }
              ],
              "stretchCentsPerOctave": null,
              "outlierTakeIDs": []
            }
          ],
          "sessionPitchDrift": [],
          "acousticSimilarityCandidates": [],
          "notes": ["Legacy fixture"]
        }
        """#.utf8)

        let report = try OrgRecCoding.decoder.decode(CollectionAnalysisReport.self, from: legacy)

        XCTAssertEqual(report.contractVersion, "orgrec-collection-analysis/1")
        XCTAssertEqual(report.rankTuningProfiles.first?.points.first?.medianDeviationCents, 1.5)
        XCTAssertNil(report.parameters)
        XCTAssertNil(report.sourceFingerprintSHA256)
        XCTAssertNil(report.evidenceSummary)
        XCTAssertNil(report.takeEvidence)
        XCTAssertNil(report.acousticAnomalyCandidates)
        XCTAssertNil(report.assessedTakeIDs)
        XCTAssertNil(report.contributingTakeIDs)
        XCTAssertNil(report.rankTuningProfiles.first?.groupingBasis)
        XCTAssertNil(report.rankTuningProfiles.first?.points.first?.standardUncertaintyCents)
    }

    func testSourceFingerprintRetainsCurrentReportAndRefreshesAfterReviewChange() throws {
        let item = makeItem(seed: 950, midi: 60, parentID: "rank:fingerprint")
        let take = makeTake(id: uuid(951), item: item, analysis: goodAnalysis(cents: 1))
        var project = makeProject(items: [item], takes: [take])
        let original = try XCTUnwrap(CollectionAnalysisEngine.analyze(
            project: project,
            id: uuid(952),
            analyzedAt: fixtureDate
        ))
        project.collectionAnalysis = original

        XCTAssertEqual(CollectionAnalysisEngine.refreshed(project: project)?.id, original.id)
        XCTAssertTrue(CollectionAnalysisEngine.isCurrent(original, for: project))

        project.takes[0].status = .rejected
        let refreshed = try XCTUnwrap(CollectionAnalysisEngine.refreshed(project: project))
        XCTAssertNotEqual(refreshed.id, original.id)
        XCTAssertNotEqual(refreshed.sourceFingerprintSHA256, original.sourceFingerprintSHA256)
        XCTAssertEqual(refreshed.evidenceSummary?.aggregateTakeCount, 0)
        XCTAssertFalse(CollectionAnalysisEngine.isCurrent(original, for: project))
    }

    func testVAOExportsAndValidatesTheCompleteCollectionDiagnosticsContract() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-collection-vao-\(UUID().uuidString)", isDirectory: true)
        let package = root.appendingPathComponent("Source.orgrec", isDirectory: true)
        let archive = root.appendingPathComponent("Collection-0.2.2.vao")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let items = (60...63).enumerated().map { offset, midi in
            makeItem(seed: 1_000 + offset, midi: midi, parentID: nil)
        }
        let takes = items.enumerated().map { offset, item in
            makeTake(id: uuid(1_100 + offset), item: item, analysis: goodAnalysis(cents: Double(offset)))
        }
        var project = makeProject(items: items, takes: takes)
        project.collectionAnalysis = try XCTUnwrap(CollectionAnalysisEngine.analyze(
            project: project,
            id: uuid(1_200),
            analyzedAt: fixtureDate
        ))
        try await ProjectStore().createPackage(at: package, project: project)
        try await VAOPackageBuilder().build(project: project, packageURL: package, destinationURL: archive)

        let validation = try VAOPackageValidator.validate(packageURL: archive)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))
        let manifest = try VAOPackageValidator.manifest(packageURL: archive)
        let research = try XCTUnwrap(manifest.profiles.first { $0.id == VAOContract.researchProfile })
        XCTAssertTrue(research.requiredCapabilities.contains(VAOContract.collectionAcousticDiagnosticsCapability))
        XCTAssertTrue(research.requiredCapabilities.contains(VAOContract.acousticalAnalysisCapability))

        let analysis = try XCTUnwrap(manifest.analyses.first {
            $0.analysisType == VAOContract.collectionAcousticDiagnosticsAnalysis
        })
        XCTAssertEqual(Set(analysis.observations.map(\.property)), [
            VAOContract.collectionEvidenceSummaryProperty,
            VAOContract.collectionTakeEvidenceProperty,
            VAOContract.collectionRankCurveProperty,
            VAOContract.collectionRankStretchProperty,
            VAOContract.collectionSessionOffsetProperty,
            VAOContract.collectionSessionDriftProperty,
            VAOContract.collectionAnomalyProperty,
            VAOContract.collectionSimilarityProperty,
        ])
        let activity = try XCTUnwrap(manifest.paradata.first { $0.id == analysis.paradataId })
        XCTAssertEqual(Set(activity.inputIds), Set(analysis.inputIds))
        XCTAssertTrue(activity.outputIds.contains(analysis.id))
        XCTAssertNotNil(activity.parameters[VAOContract.vaoNamespace + "parameterSHA256"])
        XCTAssertNotNil(activity.parameters[VAOContract.vaoNamespace + "maximumSimilarityCandidates"])

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "python3",
            FileManager.default.currentDirectoryPath + "/Tools/vaom.py",
            "validate",
            archive.path,
            "--json",
        ]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let validatorOutput = String(
            data: output.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, validatorOutput)
    }

    func testRoadmapCoverageUsesOnlyRequiredAcceptedItemsAndAccountsForRejections() {
        var requiredRejected = makeItem(seed: 1_300, midi: 60, parentID: "rank:coverage")
        requiredRejected.required = true
        requiredRejected.state = .rejected
        var optionalAccepted = makeItem(seed: 1_301, midi: 61, parentID: "rank:coverage")
        optionalAccepted.required = false
        optionalAccepted.state = .accepted

        let coverage = RoadmapEngine.coverage([requiredRejected, optionalAccepted])

        XCTAssertEqual(coverage.accepted, 1)
        XCTAssertEqual(coverage.acceptedRequired, 0)
        XCTAssertEqual(coverage.applicableRequired, 1)
        XCTAssertEqual(coverage.review, 1)
        XCTAssertEqual(coverage.fraction, 0)

        requiredRejected.state = .accepted
        XCTAssertEqual(RoadmapEngine.coverage([requiredRejected, optionalAccepted]).fraction, 1)
    }

    private var recipe: CaptureRecipe {
        CaptureRecipe(id: uuid(1), techniques: [.closePair])
    }

    private var snapshot: MODAVISSnapshot {
        MODAVISSnapshot(
            id: uuid(2),
            retrievedAt: fixtureDate,
            endpoint: "fixture://collection-analysis-v2",
            payloadSHA256: fixtureSnapshotSHA256
        )
    }

    private func makeProject<S1: Sequence, S2: Sequence>(
        items: S1,
        takes: S2,
        sessions: [RecordingSession] = []
    ) -> OrgRecProject where S1.Element == RoadmapItem, S2.Element == TakeRecord {
        OrgRecProject(
            id: uuid(3),
            title: "Collection analysis v2 fixture",
            organMDVSID: fixtureOrganID,
            organName: "Fixture organ",
            venueName: "Fixture venue",
            createdAt: fixtureDate,
            updatedAt: fixtureDate,
            snapshot: snapshot,
            recipe: recipe,
            roadmap: Array(items),
            takes: Array(takes),
            recordingSessions: sessions
        )
    }

    private func makeItem(
        seed: Int,
        midi: Int,
        parentID: String?,
        label: String = "Principal 8′",
        division: String = "Great",
        footHeight: String? = "8′",
        physicalTargetID: String? = nil,
        setupID: UUID? = nil
    ) -> RoadmapItem {
        let componentID = "component:\(seed):\(midi)"
        let locator = ComponentLocator(
            id: "locator:\(seed):\(midi)",
            organMDVSID: fixtureOrganID,
            pipePositionReference: "pipe:\(seed):\(midi)",
            sourceRecordID: "fixture-source",
            sourcePath: "fixture.ranks[\(seed)].notes[\(midi)]",
            snapshotSHA256: fixtureSnapshotSHA256,
            kind: "pipe_position",
            label: "\(label) MIDI \(midi)",
            trust: .functionalPosition
        )
        let component = OrganComponent(
            id: componentID,
            kind: "pipe_position",
            label: label,
            division: division,
            footHeight: footHeight,
            noteName: "MIDI \(midi)",
            midiNote: midi,
            expectedFrequencyHz: midiFrequency(midi),
            locator: locator,
            parentComponentID: parentID
        )
        return RoadmapItem(
            id: uuid(seed),
            component: component,
            technique: .closePair,
            recipeID: recipe.id,
            setupID: setupID,
            state: .accepted,
            coverageKind: .isolatedStop,
            physicalSoundTargetID: physicalTargetID
        )
    }

    private func goodAnalysis(
        cents: Double,
        estimatorSeverity: PitchEstimatorMismatchSeverity = .agreement
    ) -> AnalysisSummary {
        AnalysisSummary(
            method: "fixture",
            algorithmVersion: "fixture/2",
            frequencyHz: 440,
            confidence: 0.99,
            centsDeviation: cents,
            clippedSamples: 0,
            pitchApplicability: .monophonic,
            signalToNoiseDB: 40,
            pitchEstimatorComparison: PitchEstimatorComparison(
                estimates: [],
                differenceCents: estimatorSeverity == .agreement ? 0 : 40,
                severity: estimatorSeverity,
                rationale: "Collection-analysis fixture comparison."
            )
        )
    }

    private func makeTake(
        id: UUID,
        item: RoadmapItem,
        startedAt: Date? = nil,
        analysis: AnalysisSummary?,
        session: RecordingSession? = nil,
        partialTracks: [PartialTrack]? = nil
    ) -> TakeRecord {
        TakeRecord(
            id: id,
            roadmapItemID: item.id,
            takeNumber: 1,
            status: .accepted,
            startedAt: startedAt ?? fixtureDate,
            relativeAudioPath: "Audio/Originals/\(id.uuidString.lowercased()).wav",
            sampleRate: 48_000,
            channelCount: 1,
            analysis: analysis,
            partialTracks: partialTracks,
            analysisReferenceChannel: 0,
            provenance: session.map { makeProvenance(session: $0, item: item) }
        )
    }

    private func makeSession(seed: Int) -> RecordingSession {
        RecordingSession(
            id: uuid(seed),
            sessionCode: "SESSION-\(seed)",
            startedAt: fixtureDate,
            operatorName: "Fixture operator",
            environment: EnvironmentReading(temperatureCelsius: 20, relativeHumidityPercent: 50)
        )
    }

    private func makeProvenance(session: RecordingSession, item: RoadmapItem) -> TakeProvenanceSnapshot {
        TakeProvenanceSnapshot(
            session: session,
            recipe: recipe,
            microphoneSetup: nil,
            registration: nil,
            component: item.component,
            releaseBinding: snapshot.release,
            navigatorPayloadSHA256: fixtureSnapshotSHA256,
            organMDVSID: fixtureOrganID,
            expectedFrequencyHz: item.component.expectedFrequencyHz,
            physicalSoundTargetID: item.physicalSoundTargetID
        )
    }

    private func partialTrack(harmonic: Int, peakDB: Double) throws -> PartialTrack {
        let object: [String: Any] = [
            "harmonicNumber": harmonic,
            "expectedFrequencyHz": 220 * Double(harmonic),
            "peakDB": peakDB,
            "points": [],
            "confidence": 0.99,
        ]
        return try OrgRecCoding.decoder.decode(
            PartialTrack.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func uuidOrder(_ left: UUID, _ right: UUID) -> Bool {
        left.uuidString < right.uuidString
    }
}
