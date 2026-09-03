import AVFAudio
import XCTest
@testable import OrgRecCore

final class OrgRecCoreTests: XCTestCase {
    func testReleaseBindingPinsMODAVIS11TerminalState() {
        let binding = ReleaseBinding()
        XCTAssertEqual(binding.requestedRelease, "1.1")
        XCTAssertEqual(binding.releaseState, "release_1_1_enrichment_not_justified")
        XCTAssertEqual(binding.canonicalSourceRelease, "1.0")
        XCTAssertEqual(
            binding.protectedFingerprintSHA256,
            "70a3ff6dd2f629e6da9fb713acfe9e9358cd7db85612a9789931ded5663031c7"
        )
    }

    func testMODAVIS12TechnicalEvidencePitchIsImportedWithProvenance() throws {
        let object: [String: Any] = [
            "organ": ["mdvsId": "MDVS:ORGN:TEST", "title": "Test organ"],
            "technicalEvidence": [
                "pitch": [
                    "preferredValue": "a' = 435 Hz",
                    "status": "agreement",
                    "assertions": [[
                        "value": "a' = 435 Hz",
                        "rawValue": "Chorton a' 435 Hz",
                        "sourcePath": "specifications.pitch",
                        "sourceRecordId": "source:organ:17",
                    ]],
                ],
            ],
        ]
        let pitch = try XCTUnwrap(NavigatorClient.documentedPitchStandard(in: object, release: "1.2"))
        XCTAssertEqual(pitch.frequencyHz, 435)
        XCTAssertEqual(pitch.rawValue, "a' = 435 Hz")
        XCTAssertEqual(pitch.evidenceStatus, "agreement")
        XCTAssertEqual(pitch.sourcePath, "specifications.pitch")
        XCTAssertEqual(pitch.sourceRecordID, "source:organ:17")
        XCTAssertEqual(pitch.modavisRelease, "1.2")
        XCTAssertTrue(pitch.automaticallyImported)
    }

    func testAcceptedFieldA4RecalculatesRoadmapAndReadiness() throws {
        var project = DemoProjectFactory.make()
        let item = try XCTUnwrap(project.roadmap.first)
        let session = RecordingSession(
            sessionCode: "CAL-1",
            operatorName: "Operator",
            environment: EnvironmentReading(temperatureCelsius: 20, relativeHumidityPercent: 50)
        )
        project.recordingSessions = [session]
        project.documentedPitchStandard = DocumentedPitchStandard(
            frequencyHz: 440,
            rawValue: "A4 = 440 Hz",
            modavisRelease: "1.2"
        )
        XCTAssertTrue(ProjectConsistencyAuditor.captureReadiness(project: project, item: item).contains {
            $0.id == "readiness.pitch-calibration" && $0.severity == .blocker
        })

        let calibration = TuningCalibration(
            sessionID: session.id,
            status: .accepted,
            documentedA4Hz: 440,
            measuredFrequencyHz: 462.95,
            normalizedA4Hz: 462.95,
            confidence: 0.92,
            centsFromDocumented: PitchMatcher.cents(measured: 462.95, expected: 440),
            method: "Autocorrelation fallback",
            acceptedAt: .now,
            acceptedBy: "Operator"
        )
        project.tuningCalibrations = [calibration]
        project.recordingSessions?[0].tuningCalibrationID = calibration.id
        let temperamentCatalog = TemperamentCatalogSnapshot(
            navigatorBaseURL: URL(string: "https://navigator.test")!,
            modavisRelease: "1.2",
            payloadSHA256: String(repeating: "c", count: 64),
            totalAvailable: 1,
            entries: [TemperamentCatalogEntry(
                id: "equal", title: "Equal temperament",
                toneOrder: ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"],
                centValues: Array(repeating: 0, count: 12)
            )]
        )
        let temperamentReport = TemperamentAnalysisEngine.analyze(
            samples: (60...71).map { midi in
                TemperamentFrequencySample(
                    takeID: UUID(), midiNote: midi, footHeight: "8′",
                    frequencyHz: 442 * pow(2, Double(midi - 69) / 12), confidence: 0.95
                )
            },
            referenceA4Hz: 442,
            referenceA4Source: .acceptedSessionCalibration,
            rankComponentID: "rank:export-test",
            rankLabel: "Export rank",
            documentedTemperament: nil,
            catalog: temperamentCatalog
        )
        project.temperamentCatalog = temperamentCatalog
        project.temperamentAnalyses = [temperamentReport]
        let midi = try XCTUnwrap(item.component.midiNote)
        let expected = try XCTUnwrap(RoadmapEngine.soundingFrequency(
            keyMidi: midi,
            footHeight: item.component.footHeight,
            referencePitchHz: 462.95
        ))
        RoadmapEngine.applyFieldReferencePitch(462.95, to: &project)
        XCTAssertEqual(project.roadmap[0].component.expectedFrequencyHz ?? 0, expected, accuracy: 0.0001)
        XCTAssertEqual(project.roadmapCompilation?.referencePitchHz, 462.95)
        XCTAssertEqual(project.roadmapCompilation?.tuningPitchAssumed, false)
        XCTAssertFalse(ProjectConsistencyAuditor.captureReadiness(project: project, item: project.roadmap[0]).contains {
            $0.id == "readiness.pitch-calibration"
        })
    }

    func testLivePitchMatcherDistinguishesTuningFromWrongKey() {
        XCTAssertEqual(PitchMatcher.decision(measuredFrequency: 440, confidence: 0.9, expectedFrequency: 440), .matched)
        XCTAssertEqual(PitchMatcher.decision(measuredFrequency: 451, confidence: 0.9, expectedFrequency: 440), .tuningWarning)
        XCTAssertEqual(
            PitchMatcher.decision(
                measuredFrequency: 493.883,
                confidence: 0.9,
                expectedFrequency: 440,
                nearestAlternativeFrequency: 493.883
            ),
            .probableWrongNote
        )
        XCTAssertEqual(PitchMatcher.decision(measuredFrequency: 440, confidence: 0.2, expectedFrequency: 440), .ambiguous)
    }

    func testNavigatorTemperamentCatalogDecodesMODAVISVectors() throws {
        let object: [String: Any] = [
            "total": 1,
            "items": [[
                "id": "2hKi2",
                "tuningId": "2hKi2",
                "title": "Kirnberger 2",
                "label": "2hKi2",
                "groupKey": "gruppe_2",
                "groupLabel": "Gruppe 2 · wohltemperierte Stimmungen",
                "precision": ["isPreciseVariant": false],
                "toneOrder": ["C", "G", "D", "A", "E", "H", "Fis", "Cis", "Gis", "Dis", "Ais", "Eis"],
                "centValues": [0, 2, 4, -5, -14, -2, 1, 3, -7, -11, -6, 5],
                "sourceRecordId": "sr:bdo:2hKi2",
                "sourceUrl": "https://example.test/2hKi2",
                "urls": ["temperament": "/temperaments/2hKi2"],
            ]],
        ]
        let entries = NavigatorClient.temperamentEntries(in: object)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.id, "2hKi2")
        XCTAssertEqual(entry.title, "Kirnberger 2")
        XCTAssertEqual(entry.toneOrder.count, 12)
        XCTAssertEqual(entry.centValues[4], -14)
        XCTAssertEqual(entry.navigatorPath, "/temperaments/2hKi2")
    }

    func testTemperamentInferenceRanksMatchingVectorFirst() throws {
        let tones = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        let target = [6.0, -4, 2, 8, -2, 4, -6, 1, 7, 0, -8, 3]
        let catalog = TemperamentCatalogSnapshot(
            navigatorBaseURL: URL(string: "https://navigator.test")!,
            modavisRelease: "1.2",
            payloadSHA256: String(repeating: "a", count: 64),
            totalAvailable: 2,
            entries: [
                TemperamentCatalogEntry(id: "target", title: "Target temperament", toneOrder: tones, centValues: target),
                TemperamentCatalogEntry(id: "equal", title: "Equal temperament", toneOrder: tones, centValues: Array(repeating: 0, count: 12)),
            ]
        )
        let samples = (48...71).map { midi -> TemperamentFrequencySample in
            let pitchClass = midi % 12
            let equal = 442 * pow(2, Double(midi - 69) / 12)
            let frequency = equal * pow(2, target[pitchClass] / 1_200)
            return TemperamentFrequencySample(takeID: UUID(), midiNote: midi, footHeight: "8′", frequencyHz: frequency, confidence: 0.95)
        }
        let report = TemperamentAnalysisEngine.analyze(
            samples: samples,
            referenceA4Hz: 442,
            referenceA4Source: .acceptedSessionCalibration,
            rankComponentID: "rank:test",
            rankLabel: "Principal 8′",
            documentedTemperament: nil,
            catalog: catalog
        )
        XCTAssertEqual(report.observations.count, 12)
        XCTAssertEqual(report.matches.first?.catalogEntryID, "target")
        XCTAssertEqual(report.matches.first?.robustRMSECents ?? 99, 0, accuracy: 0.001)
        XCTAssertGreaterThan(report.runnerUpMarginCents ?? 0, 1)
        XCTAssertEqual(report.inferenceStrength, .strong)
        XCTAssertEqual(report.matches.first?.weightedRMSECents ?? 99, 0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(report.sensitivitySupport ?? 0, 0.8)
    }

    func testTemperamentInferenceRefusesSparseEvidence() {
        let tones = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        let catalog = TemperamentCatalogSnapshot(
            navigatorBaseURL: URL(string: "https://navigator.test")!,
            modavisRelease: "1.2",
            payloadSHA256: String(repeating: "b", count: 64),
            totalAvailable: 1,
            entries: [TemperamentCatalogEntry(id: "equal", title: "Equal", toneOrder: tones, centValues: Array(repeating: 0, count: 12))]
        )
        let samples = (60...65).map { midi in
            TemperamentFrequencySample(
                takeID: UUID(), midiNote: midi, footHeight: "8′",
                frequencyHz: 440 * pow(2, Double(midi - 69) / 12), confidence: 0.9
            )
        }
        let report = TemperamentAnalysisEngine.analyze(
            samples: samples, referenceA4Hz: 440, referenceA4Source: .documentedPrior,
            rankComponentID: "rank:sparse", rankLabel: "Sparse", documentedTemperament: nil, catalog: catalog
        )
        XCTAssertEqual(report.inferenceStrength, .insufficient)
        XCTAssertTrue(report.matches.isEmpty)
    }

    func testTemperamentInferenceDoesNotOverstateHighDispersion() {
        let tones = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
        let catalog = TemperamentCatalogSnapshot(
            navigatorBaseURL: URL(string: "https://navigator.test")!,
            modavisRelease: "1.2",
            payloadSHA256: String(repeating: "d", count: 64),
            totalAvailable: 2,
            entries: [
                TemperamentCatalogEntry(id: "equal", title: "Equal temperament", toneOrder: tones, centValues: Array(repeating: 0, count: 12)),
                TemperamentCatalogEntry(id: "offset", title: "Offset", toneOrder: tones, centValues: (0..<12).map { $0.isMultiple(of: 2) ? 12 : -12 }),
            ]
        )
        let samples = (48...71).map { midi -> TemperamentFrequencySample in
            let equal = 440 * pow(2, Double(midi - 69) / 12)
            let deviation = midi < 60 ? -20.0 : 20.0
            return TemperamentFrequencySample(
                takeID: UUID(), midiNote: midi, footHeight: "8′",
                frequencyHz: equal * pow(2, deviation / 1_200), confidence: 0.9,
                uncertaintyCents: 3
            )
        }
        let report = TemperamentAnalysisEngine.analyze(
            samples: samples, referenceA4Hz: 440, referenceA4Source: .acceptedSessionCalibration,
            rankComponentID: "rank:variable", rankLabel: "Variable rank", documentedTemperament: nil,
            catalog: catalog
        )
        XCTAssertEqual(report.inferenceStrength, .tentative)
        XCTAssertGreaterThan(report.medianDispersionCents ?? 0, 10)

        var second = report
        second.id = UUID()
        second.rankComponentID = "rank:second"
        let consensus = TemperamentConsensusEngine.analyze(reports: [report, second])
        XCTAssertEqual(consensus?.sourceReportIDs.count, 2)
        XCTAssertEqual(consensus?.rankAgreement, 1)
    }

    func testRoadmapGenerationAndCoverage() {
        let project = DemoProjectFactory.make()
        XCTAssertEqual(project.roadmap.count, 168)
        let coverage = RoadmapEngine.coverage(project.roadmap)
        XCTAssertEqual(coverage.accepted, 0)
        XCTAssertEqual(coverage.review, 0)
        XCTAssertEqual(coverage.missing, 168)
        XCTAssertEqual(RoadmapEngine.nextItem(in: project.roadmap)?.state, .queued)
        XCTAssertEqual(Set(project.roadmap.map { $0.component.locator.snapshotSHA256 }).count, 1)
    }

    func testCollectionAnalysisBuildsRankTuningCurveAndOutliers() throws {
        var project = DemoProjectFactory.make()
        let items = Dictionary(grouping: project.roadmap) { $0.component.midiNote ?? Int.min }
            .compactMap { $0.key == Int.min ? nil : $0.value.first }
            .sorted { ($0.component.midiNote ?? 0) < ($1.component.midiNote ?? 0) }
            .prefix(4)
        let fixtureRankID = "rank:collection-fixture"
        for (index, item) in items.enumerated() {
            let roadmapIndex = try XCTUnwrap(project.roadmap.firstIndex { $0.id == item.id })
            project.roadmap[roadmapIndex].component.parentComponentID = fixtureRankID
            let take = TakeRecord(
                roadmapItemID: item.id,
                takeNumber: 1,
                status: .recorded,
                relativeAudioPath: "Audio/Originals/collection-\(index).wav",
                sampleRate: 48_000,
                channelCount: 1,
                analysis: AnalysisSummary(
                    method: "fixture", algorithmVersion: "fixture/1",
                    frequencyHz: item.component.expectedFrequencyHz,
                    confidence: 0.9,
                    centsDeviation: index == 3 ? 80 : Double(index)
                )
            )
            project.takes.append(take)
        }
        let report = try XCTUnwrap(CollectionAnalysisEngine.analyze(project: project))
        let profile = try XCTUnwrap(report.rankTuningProfiles.first { $0.rankComponentID == fixtureRankID })
        XCTAssertEqual(profile.points.count, 4)
        XCTAssertNotNil(profile.stretchCentsPerOctave)
        XCTAssertEqual(profile.outlierTakeIDs.count, 1)
    }

    func testNavigatorSpecificationCompilesStopsCompassesControlsAndCustomRegistrations() throws {
        let object: [String: Any] = [
            "organ": ["mdvsId": "MDVS:ORGN:TEST", "title": "Specification test organ"],
            "source": ["sourceRecordId": "sr:test:1", "sourceUrl": "https://example.test/organ"],
            "specification": ["summary": [
                "pitch": "A = 442 Hz",
                "temperament": "Werckmeister III",
                "actionType": "Mechanical",
                "windPressure": "75 mm WC",
            ]],
            "componentHierarchy": [
                [
                    "id": "divisions",
                    "items": [[
                        "id": "division-great",
                        "kind": "division",
                        "label": "Great",
                        "detail": ["range": [36, 40]],
                        "sourcePath": "specifications.divisions[0]",
                    ]],
                ],
                [
                    "id": "stops",
                    "items": [
                        [
                            "id": "stop-principal",
                            "kind": "stop",
                        "label": "Principal 8′",
                            "detail": [
                                "division": "Great",
                                "pitch": "8′",
                                "pipeQuantity": ["actuationRange": [36, 40]],
                            ],
                            "sourcePath": "specifications.stops[0]",
                        ],
                        [
                            "id": "stop-octave",
                            "kind": "stop",
                            "label": "Octave 4′",
                            "detail": ["division": "Great", "pitch": "4′"],
                            "sourcePath": "specifications.stops[1]",
                        ],
                    ],
                ],
                [
                    "id": "couplers",
                    "items": [[
                        "id": "coupler-great-pedal",
                        "kind": "coupler",
                        "label": "Great to Pedal",
                        "detail": ["source": "Great", "destination": "Pedal"],
                    ]],
                ],
                [
                    "id": "accessories",
                    "items": [[
                        "id": "accessory-tremulant",
                        "kind": "accessory",
                        "label": "Great Tremulant",
                        "detail": ["division": "Great"],
                    ]],
                ],
            ],
        ]
        let organ = NavigatorOrganSummary(
            mdvsID: "MDVS:ORGN:TEST",
            title: "Specification test organ",
            builder: "Test Builder",
            dateLabel: "1898"
        )
        let characteristics = NavigatorClient.specificationCharacteristics(in: object)
        XCTAssertEqual(characteristics.referencePitchHz, 442)
        XCTAssertEqual(characteristics.temperament, "Werckmeister III")
        let components = NavigatorClient.extractComponents(
            from: object,
            organ: organ,
            snapshotSHA256: String(repeating: "a", count: 64),
            referencePitchHz: characteristics.referencePitchHz,
            temperament: characteristics.temperament
        )
        XCTAssertEqual(components.filter { $0.kind == "stop" }.count, 2)
        XCTAssertEqual(components.filter { $0.kind == "coupler" }.count, 1)
        XCTAssertEqual(components.filter { $0.kind == "accessory" }.count, 1)
        XCTAssertEqual(components.first { $0.id == "stop-principal" }?.playableMIDILow, 36)
        XCTAssertEqual(components.first { $0.id == "stop-principal" }?.playableMIDIHigh, 40)
        let enriched = NavigatorClient.enrichedCharacteristics(characteristics, components: components, object: object, organ: organ)
        XCTAssertEqual(enriched.documentedStopCount, 2)
        XCTAssertEqual(enriched.divisionCount, 1)
        XCTAssertEqual(enriched.couplerCount, 1)
        XCTAssertEqual(enriched.accessoryCount, 1)
        XCTAssertEqual(enriched.builder, "Test Builder")
        XCTAssertEqual(enriched.actionType, "Mechanical")
        XCTAssertEqual(enriched.windPressure, "75 mm WC")
        XCTAssertEqual(enriched.sourceCount, 1)

        let recipe = CaptureRecipe(techniques: [.closePair], chromaticStep: 1)
        let compilation = RoadmapEngine.compileSpecification(components: components, recipe: recipe)
        XCTAssertEqual(compilation.report.sourceStopCount, 2)
        XCTAssertEqual(compilation.report.sourceCouplerCount, 1)
        XCTAssertEqual(compilation.report.sourceAccessoryCount, 1)
        XCTAssertEqual(compilation.report.generatedAtomicSoundCount, 10)
        XCTAssertEqual(compilation.report.generatedControlTestCount, 6)
        XCTAssertEqual(compilation.report.theoreticalRegistrationStateCount, "15")
        XCTAssertEqual(compilation.report.assumedCompassCount, 0)
        XCTAssertEqual(compilation.report.referencePitchHz, 442)
        XCTAssertEqual(compilation.report.tuningPitchAssumed, false)
        XCTAssertEqual(compilation.report.temperament, "Werckmeister III")
        XCTAssertEqual(compilation.roadmap.count, 25)
        XCTAssertEqual(compilation.roadmap.filter { $0.coverageKind == .isolatedStop }.count, 10)
        XCTAssertEqual(compilation.roadmap.filter { $0.coverageKind == .couplerEffect }.count, 3)
        XCTAssertEqual(compilation.roadmap.filter { $0.coverageKind == .accessoryEffect }.count, 3)
        XCTAssertEqual(compilation.roadmap.filter { $0.coverageKind == .instrumentNoise }.count, 9)
        XCTAssertEqual(compilation.report.generatedInstrumentNoiseCount, 9)
        XCTAssertTrue(compilation.roadmap.filter { $0.coverageKind == .instrumentNoise }.allSatisfy { $0.required == false })
        let octaveC = try XCTUnwrap(compilation.roadmap.first {
            $0.component.label == "Octave 4′" && $0.component.midiNote == 36
        })
        XCTAssertEqual(octaveC.component.expectedFrequencyHz ?? 0, 131.407, accuracy: 0.02)

        let custom = RoadmapEngine.customRegistration(
            name: "Principal chorus with tremulant",
            stops: components.filter { $0.kind == "stop" },
            couplers: components.filter { $0.kind == "coupler" },
            accessories: components.filter { $0.kind == "accessory" },
            midiRange: 36...37,
            step: 1,
            recipe: recipe,
            setupIDs: []
        )
        XCTAssertEqual(custom.0.activatedStops.count, 2)
        XCTAssertEqual(custom.0.activatedCouplers.count, 1)
        XCTAssertEqual(custom.0.activatedAccessories.count, 1)
        XCTAssertEqual(custom.1.count, 2)
        XCTAssertTrue(custom.1.allSatisfy { $0.coverageKind == .customRegistration })

        let exhaustive = try XCTUnwrap(RoadmapEngine.exhaustiveRegistrationSubsets(
            namePrefix: "All",
            stops: components.filter { $0.kind == "stop" },
            couplers: components.filter { $0.kind == "coupler" },
            accessories: [],
            midiRange: 36...36,
            step: 1,
            recipe: recipe,
            setupIDs: []
        ))
        XCTAssertEqual(RoadmapEngine.exhaustiveSubsetCount(stopCount: 2, controlCount: 1), 6)
        XCTAssertEqual(exhaustive.count, 6)
        XCTAssertEqual(exhaustive.flatMap(\.1).count, 6)
        XCTAssertTrue(exhaustive.allSatisfy { $0.0.activatedStops.isEmpty == false })
    }

    func testSharedRankDeduplicatesOnlyProvenOctaveOverlap() throws {
        let snapshot = String(repeating: "b", count: 64)
        func component(id: String, kind: String, label: String, foot: String? = nil) -> OrganComponent {
            OrganComponent(
                id: id,
                kind: kind,
                label: label,
                division: "Great",
                footHeight: foot,
                locator: ComponentLocator(
                    id: id,
                    organMDVSID: "MDVS:ORGN:SHARED",
                    sourceRecordID: "source:shared-rank",
                    sourcePath: "components.\(id)",
                    snapshotSHA256: snapshot,
                    kind: kind,
                    label: label,
                    trust: .sourceBound
                ),
                playableMIDILow: kind == "stop" ? 36 : nil,
                playableMIDIHigh: kind == "stop" ? 96 : nil
            )
        }
        let principal8 = component(id: "stop-principal-8", kind: "stop", label: "Prinzipal 8′", foot: "8′")
        let principal4 = component(id: "stop-principal-4", kind: "stop", label: "Prinzipal 4′", foot: "4′")
        let rank = component(id: "rank-principal", kind: "rank", label: "Principal unit rank")
        let recipe = CaptureRecipe(techniques: [.closePair])

        let unproven = RoadmapEngine.compileSpecification(components: [principal8, principal4, rank], recipe: recipe)
        XCTAssertEqual(unproven.report.logicalSoundAddressCount, 122)
        XCTAssertEqual(unproven.report.physicalSoundTargetCount, 122)
        XCTAssertEqual(unproven.report.sharedAliasCount, 0)
        XCTAssertEqual(unproven.overlapCandidates.count, 1)

        let relationships = [
            OrganComponentRelationship(id: "r1", sourceComponentID: principal8.id, targetComponentID: rank.id, kind: "uses_rank"),
            OrganComponentRelationship(id: "r2", sourceComponentID: principal4.id, targetComponentID: rank.id, kind: "uses_rank"),
        ]
        let proven = RoadmapEngine.compileSpecification(
            components: [principal8, principal4, rank],
            recipe: recipe,
            relationships: relationships
        )
        XCTAssertEqual(proven.report.logicalSoundAddressCount, 122)
        XCTAssertEqual(proven.report.physicalSoundTargetCount, 73)
        XCTAssertEqual(proven.report.sharedAliasCount, 49)
        XCTAssertEqual(proven.roadmap.filter { $0.coverageKind != .instrumentNoise }.count, 73)
        XCTAssertEqual(proven.roadmap.filter { $0.coverageKind == .instrumentNoise }.count, 4)
        XCTAssertTrue(proven.overlapCandidates.isEmpty)
        let shared = try XCTUnwrap(proven.physicalSoundTargets.first { target in
            let addresses = Set(target.routes.map { "\($0.component.parentComponentID ?? "")|\($0.component.midiNote ?? -1)" })
            return addresses.contains("stop-principal-8|48") && addresses.contains("stop-principal-4|36")
        })
        XCTAssertEqual(shared.routes.count, 2)
        XCTAssertEqual(shared.routes.first { $0.id == shared.primaryRouteID }?.component.parentComponentID, principal8.id)
    }

    func testReviewedAssertionIsPartialReversibleEvidence() {
        let snapshot = String(repeating: "c", count: 64)
        func stop(_ id: String, _ label: String, _ foot: String) -> OrganComponent {
            OrganComponent(
                id: id, kind: "stop", label: label, division: "Great", footHeight: foot,
                locator: ComponentLocator(id: id, organMDVSID: "MDVS:ORGN:ASSERT", sourcePath: id, snapshotSHA256: snapshot, kind: "stop", label: label, trust: .sourceBound),
                playableMIDILow: 36, playableMIDIHigh: 96
            )
        }
        let principal8 = stop("p8", "Principal 8′", "8′")
        let principal4 = stop("p4", "Principal 4′", "4′")
        let assertion = PipeSharingAssertion(
            stops: [StopPipeOffset(stopComponentID: "p8", soundingSemitoneOffset: 0), StopPipeOffset(stopComponentID: "p4", soundingSemitoneOffset: 12)],
            soundingMIDILow: 60,
            soundingMIDIHigh: 72,
            snapshotSHA256: snapshot,
            author: "Reviewer",
            note: "Console and chest documentation confirm the shared section."
        )
        let compilation = RoadmapEngine.compileSpecification(
            components: [principal8, principal4],
            recipe: CaptureRecipe(techniques: [.closePair]),
            sharingAssertions: [assertion]
        )
        XCTAssertEqual(compilation.report.logicalSoundAddressCount, 122)
        XCTAssertEqual(compilation.report.physicalSoundTargetCount, 109)
        XCTAssertEqual(compilation.report.sharedAliasCount, 13)
        XCTAssertEqual(compilation.overlapCandidates.count, 2)
        XCTAssertEqual(compilation.overlapCandidates.reduce(0) { $0 + $1.overlappingAddressCount }, 36)
        XCTAssertEqual(compilation.physicalSoundTargets.filter { $0.routes.count == 2 }.count, 13)
    }

    func testPhysicalPipeSetMustMatchCompletelyBeforeDeduplication() {
        let snapshot = String(repeating: "d", count: 64)
        func stop(_ id: String) -> OrganComponent {
            OrganComponent(
                id: id, kind: "stop", label: id, division: "Great", footHeight: "8′",
                locator: ComponentLocator(id: id, organMDVSID: "MDVS:ORGN:SETS", sourcePath: id, snapshotSHA256: snapshot, kind: "stop", label: id, trust: .sourceBound),
                playableMIDILow: 60, playableMIDIHigh: 60
            )
        }
        let mappings = [
            PhysicalPipeMapping(id: "m1", stopComponentID: "a", keyMIDI: 60, physicalPipeComponentIDs: ["pipe:1", "pipe:2"]),
            PhysicalPipeMapping(id: "m2", stopComponentID: "b", keyMIDI: 60, physicalPipeComponentIDs: ["pipe:2", "pipe:1"]),
            PhysicalPipeMapping(id: "m3", stopComponentID: "c", keyMIDI: 60, physicalPipeComponentIDs: ["pipe:1", "pipe:3"]),
        ]
        let compilation = RoadmapEngine.compileSpecification(
            components: [stop("a"), stop("b"), stop("c")],
            recipe: CaptureRecipe(techniques: [.closePair]),
            physicalPipeMappings: mappings
        )
        XCTAssertEqual(compilation.report.logicalSoundAddressCount, 3)
        XCTAssertEqual(compilation.report.physicalSoundTargetCount, 2)
        XCTAssertEqual(compilation.report.sharedAliasCount, 1)
        XCTAssertEqual(compilation.physicalSoundTargets.map(\.routes.count).sorted(), [1, 2])
    }

    func testNavigatorPreservesRankRelationshipsAndPhysicalMappings() {
        let object: [String: Any] = [
            "componentHierarchy": [[
                "items": [[
                    "id": "stop-8", "kind": "stop", "label": "Principal 8′",
                    "detail": [
                        "division": "Great", "pitch": "8′", "rankId": "rank-principal",
                        "pipeQuantity": ["actuationRange": [60, 60]],
                        "pipeMappings": [["keyMidi": 60, "physicalPipeIds": ["pipe-c4"]]],
                    ],
                ], [
                    "id": "rank-principal", "kind": "rank", "label": "Principal rank",
                ]],
            ]],
        ]
        let organ = NavigatorOrganSummary(mdvsID: "MDVS:ORGN:STRUCTURE", title: "Structure")
        let components = NavigatorClient.extractComponents(from: object, organ: organ, snapshotSHA256: String(repeating: "e", count: 64))
        let structure = NavigatorClient.extractPhysicalStructure(from: object, components: components)
        XCTAssertTrue(structure.relationships.contains {
            $0.sourceComponentID == "stop-8" && $0.targetComponentID == "rank-principal" && $0.kind == "uses_rank"
        })
        let mapping = structure.mappings.first { $0.stopComponentID == "stop-8" && $0.keyMIDI == 60 }
        XCTAssertEqual(mapping?.physicalPipeComponentIDs, ["pipe-c4"])
        XCTAssertEqual(mapping?.evidence, .explicitSharedPipe)
    }

    func testProjectPackageRoundTrip() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let store = ProjectStore()
        var original = DemoProjectFactory.make()
        let navigatorPayload = Data("{\"contractVersion\":\"test\",\"specification\":{}}".utf8)
        original.snapshot.payloadSHA256 = navigatorPayload.sha256Hex
        original.navigatorPayloadRelativePath = "Manifests/modavis-navigator-payload.json"
        try await store.createPackage(at: temporary, project: original)
        try await store.storeNavigatorPayload(
            navigatorPayload,
            expectedSHA256: original.snapshot.payloadSHA256,
            relativePath: try XCTUnwrap(original.navigatorPayloadRelativePath),
            at: temporary
        )
        let loaded = try await store.load(from: temporary)
        XCTAssertEqual(loaded.id, original.id)
        XCTAssertEqual(loaded.snapshot.release.requestedRelease, "1.1")
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.appendingPathComponent("Audio/Originals").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.appendingPathComponent("Audio/Calibration").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temporary.appendingPathComponent("Analysis/SpectrogramTiles").path))
        XCTAssertEqual(
            try Data(contentsOf: temporary.appendingPathComponent("Manifests/modavis-navigator-payload.json")),
            navigatorPayload
        )
    }

    func testSchemaOneProjectWithoutPhysicalFieldsRemainsDecodable() throws {
        let project = DemoProjectFactory.make()
        let encoded = try OrgRecCoding.encoder.encode(project)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for key in ["componentRelationships", "physicalPipeMappings", "pipeSharingAssertions", "physicalSoundTargets", "physicalOverlapCandidates", "timbreAnalyses"] {
            object.removeValue(forKey: key)
        }
        if var roadmap = object["roadmap"] as? [[String: Any]] {
            for index in roadmap.indices {
                roadmap[index].removeValue(forKey: "physicalSoundTargetID")
                roadmap[index].removeValue(forKey: "primaryActivationRouteID")
                roadmap[index].removeValue(forKey: "activationRoutes")
            }
            object["roadmap"] = roadmap
        }
        if var report = object["roadmapCompilation"] as? [String: Any] {
            report["compilerContract"] = "orgrec.modavis-roadmap-compiler/v2"
            for key in ["logicalSoundAddressCount", "physicalSoundTargetCount", "sharedAliasCount", "unresolvedSharedCandidateCount"] {
                report.removeValue(forKey: key)
            }
            object["roadmapCompilation"] = report
        }
        let legacyData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let decoded = try OrgRecCoding.decoder.decode(OrgRecProject.self, from: legacyData)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.roadmap.count, project.roadmap.count)
        XCTAssertNil(decoded.physicalSoundTargets)
        XCTAssertNil(decoded.timbreAnalyses)
        XCTAssertNil(decoded.roadmap.first?.activationRoutes)
        XCTAssertEqual(decoded.roadmapCompilation?.compilerContract, "orgrec.modavis-roadmap-compiler/v2")
    }

    func testAudioAnalysisFindsToneAndTransients() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-tone-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let sampleRate = 16_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let silence = Int(sampleRate * 0.55)
        let tone = Int(sampleRate * 1.8)
        let tail = Int(sampleRate * 0.55)
        let total = silence + tone + tail
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total))!
        buffer.frameLength = AVAudioFrameCount(total)
        let channel = buffer.floatChannelData![0]
        for index in 0..<total {
            if index < silence || index >= silence + tone {
                channel[index] = 0.000_05
            } else {
                let time = Double(index - silence) / sampleRate
                channel[index] = Float(0.28 * sin(2 * Double.pi * 261.625_6 * time))
            }
        }
        do {
            let file = try AVAudioFile(forWriting: temporary, settings: format.settings)
            try file.write(from: buffer)
        }

        let result = try await AudioAnalyzer().analyze(fileURL: temporary, expectedFrequency: 261.625_6)
        XCTAssertEqual(result.0.frequencyHz ?? 0, 261.625_6, accuracy: 4)
        XCTAssertTrue(result.0.method.contains("CREPE"))
        XCTAssertEqual(result.0.onsetSeconds ?? 0, 0.55, accuracy: 0.12)
        XCTAssertEqual(result.0.boundaries?.first(where: { $0.marker == .onset })?.timeResolutionSeconds ?? 0, 0.01, accuracy: 0.000_001)
        XCTAssertGreaterThan(result.0.soundOffsetSeconds ?? 0, 2.2)
        XCTAssertFalse(result.1.samples.isEmpty)
        XCTAssertGreaterThan(result.2.timeBins, 0)
        XCTAssertGreaterThan(result.2.frequencyBins, 0)
        XCTAssertEqual(result.2.configuration?.fftSize, 8_192)
        XCTAssertEqual(result.2.configuration?.frequencyScale, .logarithmic)
        XCTAssertFalse(result.2.pitchTrack?.isEmpty ?? true)
        XCTAssertNotNil(result.2.analysisRun)
        XCTAssertEqual(result.2.analysisRun?.outputSummary?.analysisRunID, result.0.analysisRunID)
        XCTAssertNotNil(result.2.analysisRun?.pitchTrackSHA256)
        XCTAssertNotNil(result.2.analysisRun?.parameterSHA256)
        XCTAssertEqual(result.2.analysisRun?.artifactRelativePaths?.count, 2)
        XCTAssertGreaterThan(result.0.pitchTrackSummary?.voicedRatio ?? 0, 0.8)
        XCTAssertEqual(result.0.contractVersion, "orgrec-analysis-summary/2")
        XCTAssertEqual(result.0.pitchEstimatorComparison?.estimates.filter { $0.estimator == "CREPE" || $0.estimator == "pYIN" }.count, 2)
        XCTAssertEqual(result.0.pitchEstimatorComparison?.severity, .agreement)
        let loopSet = try XCTUnwrap(result.0.detectedLoopPointSets?.first)
        XCTAssertEqual(loopSet.status, .proposed)
        XCTAssertTrue(LoopPointSetValidator.errors(for: loopSet).isEmpty)
        XCTAssertEqual(loopSet.sourceAudioSHA256, try sha256(of: temporary))
        XCTAssertGreaterThan(loopSet.sustainRegion?.frameCount ?? 0, 0)
        XCTAssertNotNil(result.0.pipeSoundBehavior)
        XCTAssertNotEqual(result.0.pipeSoundBehavior?.loopability, .unsuitable)
        let fundamental = try XCTUnwrap(result.2.partialTracks?.first)
        XCTAssertEqual(fundamental.harmonicNumber, 1)
        XCTAssertEqual(fundamental.medianFrequencyHz ?? 0, 261.625_6, accuracy: 2)
        XCTAssertNotNil(fundamental.onsetSeconds)
        XCTAssertNotNil(fundamental.offsetSeconds)
    }

    func testHighOrganPitchUsesWidebandPYIN() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-high-tone-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let sampleRate = 48_000.0
        let expected = 4_186.009
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = Int(sampleRate * 1.5)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let channel = buffer.floatChannelData![0]
        for index in 0..<frames {
            channel[index] = Float(0.25 * sin(2 * Double.pi * expected * Double(index) / sampleRate))
        }
        do {
            let file = try AVAudioFile(forWriting: temporary, settings: format.settings)
            try file.write(from: buffer)
        }

        let result = try await AudioAnalyzer().analyze(fileURL: temporary, expectedFrequency: expected)
        XCTAssertEqual(result.0.method, "Probabilistic YIN")
        let pitch = try XCTUnwrap(result.0.frequencyHz)
        XCTAssertLessThan(abs(PitchMatcher.cents(measured: pitch, expected: expected) ?? 99), 5)
        XCTAssertGreaterThan(result.0.confidence ?? 0, 0.5)
        XCTAssertGreaterThan(result.0.pitchTrackSummary?.voicedFrameCount ?? 0, 1)
        XCTAssertEqual(result.0.pitchEstimatorComparison?.estimates.first?.estimator, "pYIN")
        XCTAssertEqual(result.0.pitchEstimatorComparison?.severity, .unavailable)
    }

    func testAnalysisRepresentsBoundaryCensoringWithoutInventingTailEnd() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-censored-tone-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let sampleRate = 16_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = Int(sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        for index in 0..<frames {
            buffer.floatChannelData![0][index] = Float(0.2 * sin(2 * Double.pi * 440 * Double(index) / sampleRate))
        }
        do {
            let file = try AVAudioFile(forWriting: temporary, settings: format.settings)
            try file.write(from: buffer)
        }

        let result = try await AudioAnalyzer().analyze(fileURL: temporary, expectedFrequency: 440)
        let onset = try XCTUnwrap(result.0.boundaries?.first { $0.marker == .onset })
        let offset = try XCTUnwrap(result.0.boundaries?.first { $0.marker == .soundOffset })
        let tail = try XCTUnwrap(result.0.boundaries?.first { $0.marker == .tailEnd })
        XCTAssertEqual(onset.state, .leftCensored)
        XCTAssertEqual(offset.state, .rightCensored)
        XCTAssertEqual(tail.state, .rightCensored)
        XCTAssertNil(result.0.tailEndSeconds)
        XCTAssertTrue(result.0.qualityFlags.contains("Sound offset not fully observed"))
    }

    func testNonPitchedAnalysisDoesNotFailForMissingPitch() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-noise-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let sampleRate = 16_000.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = Int(sampleRate * 0.7)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        for index in 0..<frames { buffer.floatChannelData![0][index] = index.isMultiple(of: 2) ? 0.01 : -0.01 }
        do {
            let file = try AVAudioFile(forWriting: temporary, settings: format.settings)
            try file.write(from: buffer)
        }

        let result = try await AudioAnalyzer().analyze(
            fileURL: temporary,
            expectedFrequency: nil,
            pitchApplicability: .nonPitched
        )
        XCTAssertNil(result.0.frequencyHz)
        XCTAssertEqual(result.0.pitchApplicability, .nonPitched)
        XCTAssertFalse(result.0.qualityFlags.contains("Required monophonic pitch estimate unavailable"))
    }

    func testLegacyDatasetImportPreservesSourceBoundIdentityAndObservedKeys() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-legacy-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("Source", isDirectory: true)
        let destination = root.appendingPathComponent("Imported.orgrec", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try Data("ignored".utf8).write(to: source.appendingPathComponent("notes.txt"))
        let format = AVAudioFormat(standardFormatWithSampleRate: 16_000, channels: 2)!
        for midi in [36, 38, 40] {
            let frames = 8_000
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
            buffer.frameLength = AVAudioFrameCount(frames)
            for channelIndex in 0..<2 {
                let samples = buffer.floatChannelData![channelIndex]
                let frequency = 440 * pow(2, Double(midi - 69) / 12)
                for frame in 0..<frames {
                    samples[frame] = Float(0.1 * sin(2 * Double.pi * frequency * Double(frame) / 16_000))
                }
            }
            let file = try AVAudioFile(
                forWriting: source.appendingPathComponent("123_test_\(midi).wav"),
                settings: format.settings
            )
            try file.write(from: buffer)
        }
        let profile = LegacyDatasetProfile(
            sourceNamespace: "fixture",
            sourceRecordIdentifier: "123",
            organName: "Legacy fixture",
            venueName: "Test venue",
            stopMappings: [LegacyStopMapping(code: "test", label: "Test", footHeight: "8′")]
        )
        let importer = LegacyAudioDatasetImporter()
        let inspection = try await importer.inspect(directory: source, profile: profile)
        XCTAssertEqual(inspection.files.count, 3)
        XCTAssertEqual(inspection.ignoredEntries, ["notes.txt"])
        let project = try await importer.importDataset(from: source, to: destination, profile: profile)
        XCTAssertEqual(project.organMDVSID, "SOURCE:fixture:123")
        XCTAssertEqual(project.takes.count, 3)
        XCTAssertEqual(project.organComponents?.filter { $0.kind == "stop" }.first?.sourceDetails?["observedMIDIKeys"], "36,38,40")
        XCTAssertTrue(project.roadmap.allSatisfy { $0.component.locator.trust == .sourceBound })
        XCTAssertTrue(project.roadmap.allSatisfy { $0.component.locator.canonicalMDVSID == nil })
        XCTAssertTrue(project.takes.allSatisfy { $0.status == .needsReview && $0.sha256 != nil })
        let manifestData = try Data(contentsOf: destination.appendingPathComponent(LegacyAudioDatasetImporter.manifestRelativePath))
        XCTAssertEqual(manifestData.sha256Hex, project.snapshot.payloadSHA256)
        for take in project.takes {
            XCTAssertEqual(try sha256(of: destination.appendingPathComponent(take.relativeAudioPath)), take.sha256)
        }
        XCTAssertEqual(try Data(contentsOf: source.appendingPathComponent("notes.txt")), Data("ignored".utf8))

        let export = root.appendingPathComponent("Legacy.orgrec-capture", isDirectory: true)
        try await CapturePackageBuilder().build(project: project, packageURL: destination, destinationURL: export)
        let validation = try IADPackageValidator.validate(packageURL: export)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))
        let iadFiles: [IADFileRecord] = try String(
            contentsOf: export.appendingPathComponent("manifests/files.jsonl"),
            encoding: .utf8
        ).split(separator: "\n").map { try OrgRecCoding.decoder.decode(IADFileRecord.self, from: Data($0.utf8)) }
        XCTAssertTrue(iadFiles.allSatisfy { $0.encoding == "IEEE 754 32-bit floating point" && $0.bitDepth == 32 })
        let iadTakes: [IADTakeRecord] = try String(
            contentsOf: export.appendingPathComponent("manifests/takes.jsonl"),
            encoding: .utf8
        ).split(separator: "\n").map { try OrgRecCoding.decoder.decode(IADTakeRecord.self, from: Data($0.utf8)) }
        XCTAssertTrue(iadTakes.allSatisfy { abs(($0.durationSeconds ?? 0) - 0.5) < 0.001 })
        let roundTrip = root.appendingPathComponent("RoundTrip.orgrec", isDirectory: true)
        let reconstructed = try await IADPackageImporter().importPackage(from: export, to: roundTrip)
        XCTAssertEqual(reconstructed.takes.count, 3)
    }

    func testAudioDatasetFilenameConventionsPreserveRawPitchAndApplyReviewedOffset() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-audio-wizard-\(UUID().uuidString)", isDirectory: true)
        let numericSource = root.appendingPathComponent("Numeric", isDirectory: true)
        let noteSource = root.appendingPathComponent("Notes", isDirectory: true)
        let recordSource = root.appendingPathComponent("Record", isDirectory: true)
        let midiFirstSource = root.appendingPathComponent("MIDIFirst", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: numericSource, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: noteSource, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: recordSource, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: midiFirstSource, withIntermediateDirectories: true)

        let fixture = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/VAO03/valid/acousticrooms-scene/payload/acoustics/S000_R0011_hybrid_IR.wav")
        let fixtureData = try Data(contentsOf: fixture)
        func writeAudio(named name: String, in directory: URL) throws {
            try fixtureData.write(to: directory.appendingPathComponent(name))
        }
        try writeAudio(named: "Principal8_001.wav", in: numericSource)
        try writeAudio(named: "Principal8_002_rr2.wav", in: numericSource)
        try writeAudio(named: "Flute4_003.wav", in: numericSource)
        try writeAudio(named: "Reed8_C4.wav", in: noteSource)
        try writeAudio(named: "Reed8_Cs4_take2.wav", in: noteSource)
        try writeAudio(named: "set42_Principal8_060.wav", in: recordSource)
        try writeAudio(named: "061_Principal8_rr2.wav", in: midiFirstSource)

        let numericProfile = LegacyDatasetProfile.audioDataset(
            sourceNamespace: "fixture",
            sourceRecordIdentifier: "numeric",
            organName: "Numeric fixture",
            venueName: "",
            divisionName: "Manual",
            convention: .stopThenMIDI,
            midiNoteOffset: 35,
            stopMappings: []
        )
        let importer = LegacyAudioDatasetImporter()
        let numeric = try await importer.inspect(directory: numericSource, profile: numericProfile)
        XCTAssertEqual(numeric.files.count, 3)
        XCTAssertEqual(numeric.stopCodes, ["Flute4", "Principal8"])
        XCTAssertEqual(numeric.files.first { $0.filename == "Principal8_001.wav" }?.sourcePitchToken, "001")
        XCTAssertEqual(numeric.files.first { $0.filename == "Principal8_001.wav" }?.midiNote, 36)
        XCTAssertEqual(numeric.files.first { $0.filename == "Principal8_002_rr2.wav" }?.variant, "rr2")
        let technicalRecord = try XCTUnwrap(numeric.files.first { $0.filename == "Principal8_001.wav" })
        XCTAssertEqual(technicalRecord.sampleRate, 22_050)
        XCTAssertEqual(technicalRecord.channelCount, 1)
        XCTAssertEqual(technicalRecord.frameCount, 11_864)
        XCTAssertEqual(technicalRecord.containerDescription, "RIFF/WAVE")
        XCTAssertEqual(technicalRecord.encodingDescription, "Signed integer PCM")
        XCTAssertEqual(technicalRecord.bitDepth, 16)

        let reviewedProfile = LegacyDatasetProfile.audioDataset(
            sourceNamespace: "fixture",
            sourceRecordIdentifier: "numeric",
            organName: "Numeric fixture",
            venueName: "Test collection",
            divisionName: "Manual",
            convention: .stopThenMIDI,
            midiNoteOffset: 35,
            stopMappings: [
                LegacyStopMapping(code: "Flute4", label: "Flute", footHeight: "4′", soundingSemitoneOffset: 12),
                LegacyStopMapping(code: "Principal8", label: "Principal", footHeight: "8′"),
            ],
            rightsStatement: "Test-only fixture"
        )
        let projectURL = root.appendingPathComponent("Numeric.orgrec", isDirectory: true)
        let project = try await importer.importDataset(from: numericSource, to: projectURL, profile: reviewedProfile)
        XCTAssertEqual(project.takes.count, 3)
        XCTAssertEqual(
            project.roadmap.first { $0.component.sourceDetails?["legacyFilename"] == "Principal8_001.wav" }?.component.sourceDetails?["sourcePitchToken"],
            "001"
        )
        let vaoURL = root.appendingPathComponent("Numeric.vao")
        _ = try await VAOPackageBuilder().build(project: project, packageURL: projectURL, destinationURL: vaoURL)
        XCTAssertTrue(try VAOPackageValidator.validate(packageURL: vaoURL).isValid)

        let noteProfile = LegacyDatasetProfile.audioDataset(
            sourceNamespace: "fixture",
            sourceRecordIdentifier: "notes",
            organName: "Note fixture",
            venueName: "",
            divisionName: "Manual",
            convention: .stopThenNoteName,
            stopMappings: []
        )
        let notes = try await importer.inspect(directory: noteSource, profile: noteProfile)
        XCTAssertEqual(notes.files.map(\.midiNote).sorted(), [60, 61])
        XCTAssertEqual(notes.files.first { $0.filename == "Reed8_Cs4_take2.wav" }?.variant, "take2")

        let recordProfile = LegacyDatasetProfile.audioDataset(
            sourceNamespace: "fixture", sourceRecordIdentifier: "record", organName: "Record fixture",
            venueName: "", divisionName: "Manual", convention: .recordStopMIDI, stopMappings: []
        )
        let record = try await importer.inspect(directory: recordSource, profile: recordProfile)
        XCTAssertEqual(record.files.first?.sourceRecordIdentifier, "set42")
        XCTAssertEqual(record.files.first?.stopCode, "Principal8")
        XCTAssertEqual(record.files.first?.midiNote, 60)

        let midiFirstProfile = LegacyDatasetProfile.audioDataset(
            sourceNamespace: "fixture", sourceRecordIdentifier: "midi-first", organName: "MIDI-first fixture",
            venueName: "", divisionName: "Manual", convention: .midiThenStop, stopMappings: []
        )
        let midiFirst = try await importer.inspect(directory: midiFirstSource, profile: midiFirstProfile)
        XCTAssertEqual(midiFirst.files.first?.stopCode, "Principal8")
        XCTAssertEqual(midiFirst.files.first?.midiNote, 61)
        XCTAssertEqual(midiFirst.files.first?.variant, "rr2")
    }

    func testCapturePackageIncludesSnapshotAndIntegrityManifest() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-export-test-\(UUID().uuidString)", isDirectory: true)
        let package = root.appendingPathComponent("Source.orgrec", isDirectory: true)
        let export = root.appendingPathComponent("Export.orgrec-capture", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        var project = DemoProjectFactory.make()
        let frozenPayload = Data("{\"organ\":\"MDVS:ORGN:DEMO\",\"specification\":{\"stops\":[]}}".utf8)
        project.snapshot.payloadSHA256 = frozenPayload.sha256Hex
        project.navigatorPayloadRelativePath = "Manifests/modavis-navigator-payload.json"
        for index in project.roadmap.indices {
            project.roadmap[index].component.locator.snapshotSHA256 = frozenPayload.sha256Hex
            if project.roadmap[index].activationRoutes != nil {
                for routeIndex in project.roadmap[index].activationRoutes!.indices {
                    project.roadmap[index].activationRoutes![routeIndex].component.locator.snapshotSHA256 = frozenPayload.sha256Hex
                }
            }
            project.roadmap[index].state = .missing
        }
        project.recordingSessions = [RecordingSession(
            sessionCode: "TEST-SESSION",
            operatorName: "Test operator",
            environment: EnvironmentReading(temperatureCelsius: 20, relativeHumidityPercent: 50)
        )]
        let calibration = TuningCalibration(
            sessionID: try XCTUnwrap(project.recordingSessions?.first?.id),
            status: .accepted,
            documentedA4Hz: 440,
            measuredFrequencyHz: 442,
            normalizedA4Hz: 442,
            confidence: 0.95,
            centsFromDocumented: PitchMatcher.cents(measured: 442, expected: 440),
            method: "Test estimator",
            relativeAudioPath: "Audio/Calibration/export-calibration.wav",
            acceptedAt: .now,
            acceptedBy: "Test operator"
        )
        project.tuningCalibrations = [calibration]
        project.recordingSessions?[0].tuningCalibrationID = calibration.id
        project.temperamentAnalyses = [TemperamentAnalysisReport(
            rankComponentID: "rank:export-test",
            rankLabel: "Export rank",
            referenceA4Hz: 442,
            referenceA4Source: .acceptedSessionCalibration,
            documentedTemperament: nil,
            observations: [],
            matches: [],
            inferenceStrength: .insufficient,
            runnerUpMarginCents: nil,
            analyzedTakeCount: 0,
            rejectedSampleCount: 0,
            catalogRelease: "1.2",
            catalogPayloadSHA256: String(repeating: "c", count: 64),
            catalogFetchedAt: .now,
            notes: ["Export vector"]
        )]
        let takeID = UUID()
        let syntheticAudio = Data("synthetic audio payload".utf8)
        let preflightID = UUID()
        let preflightAudio = Data("retained multichannel signal-path rehearsal".utf8)
        let preflightSetup = try XCTUnwrap(project.setups.first)
        let preflightSessionID = try XCTUnwrap(project.recordingSessions?.first?.id)
        let preflightPath = "Audio/Calibration/signal-path-\(preflightID.uuidString.lowercased()).wav"
        let preflight = CapturePreflightReport(
            id: preflightID,
            recordedAt: .now,
            sessionID: preflightSessionID,
            setupID: preflightSetup.id,
            setupRevision: preflightSetup.revision,
            deviceSnapshot: AudioDeviceSnapshot(
                uid: "export-test-interface", name: "Export Test Interface", manufacturer: "OrgRec",
                transport: "Virtual", inputChannels: 2, sampleRate: 96_000, bufferFrames: 128,
                deviceLatencyFrames: 4, safetyOffsetFrames: 2,
                estimatedInputLatencyMilliseconds: 1.4, lowLatencyMode: "Balanced"
            ),
            relativeAudioPath: preflightPath,
            fileSize: Int64(preflightAudio.count),
            sha256: preflightAudio.sha256Hex,
            sampleRate: 96_000,
            frameCount: 1_152_000,
            durationSeconds: 12,
            protocolSnapshot: CapturePreflightProtocolSnapshot(),
            channels: [
                CapturePreflightChannelResult(
                    channelNumber: 1, role: "Main left", isRequired: true,
                    quietRMSDBFS: -60, signalRMSDBFS: -18, peakDBFS: -12,
                    headroomDB: 12, signalToNoiseDB: 42, dcOffset: 0.0001, clippedSamples: 0
                ),
                CapturePreflightChannelResult(
                    channelNumber: 2, role: "Main right", isRequired: true,
                    quietRMSDBFS: -59, signalRMSDBFS: -17, peakDBFS: -11,
                    headroomDB: 11, signalToNoiseDB: 42, dcOffset: -0.0001, clippedSamples: 0
                ),
            ],
            findings: [],
            verdict: .passed,
            captureDiagnostics: CaptureDiagnostics(writtenFrames: 1_152_000),
            bwfMetadata: nil,
            bwfFinalizationSucceeded: true
        )
        project.recordingSessions?[0].capturePreflightReports = [preflight]
        let acceptedLoopID = UUID()
        let acceptedLoop = LoopPointSet(
            id: acceptedLoopID,
            sourceAudioSHA256: syntheticAudio.sha256Hex,
            sampleRate: 96_000,
            channelCount: 2,
            totalFrames: 4_096,
            status: .accepted,
            loopability: .stablePeriodic,
            regions: [AudioLoopRegion(
                startFrameInclusive: 1_000,
                endFrameExclusive: 3_000,
                crossfadeFrames: 100,
                exitPolicy: .crossfadeToRecordedRelease,
                releaseStartFrame: 3_100
            )],
            confidence: 0.94,
            wasRevisionOf: nil,
            reviewedAt: .now,
            reviewedBy: "Reviewer",
            reviewReason: "Repeated audition found no tonal or spatial seam."
        )
        let bwf = BWFMetadata(
            description: "Export contract vector",
            originatorReference: "ORGREC-EXPORT-TEST",
            originationDate: "2026-08-12",
            originationTime: "21:30:00",
            codingHistory: "A=PCM,F=96000,W=24,M=2"
        )
        let perceptualSpectrum = PerceptualSpectralSummary(
            fftSize: 4_096,
            hopSize: 512,
            analyzedFrameCount: 24,
            analyzedDurationSeconds: 2,
            spectralSpreadHz: 432,
            spectralFlatness: 0.12,
            auditoryCentroidERB: 15.4,
            harmonicEnergyRatio: 0.91,
            harmonicSpectralSlopeDBPerOctave: -5.2,
            harmonicSpectralDeviationDB: 1.8,
            tristimulus1: 0.4,
            tristimulus2: 0.35,
            tristimulus3: 0.25,
            spectralCentroidModulationRateHz: 1.7,
            spectralCentroidModulationDepthERB: 0.3,
            spectralCentroidModulationConfidence: 0.88,
            method: "Export contract fixture"
        )
        let observedT20 = AcousticDecayFit(
            label: "T20", upperLevelDB: -5, lowerLevelDB: -25,
            slopeDBPerSecond: -30, extrapolatedDecayTimeSeconds: 2,
            coefficientOfDetermination: 0.98, standardUncertaintySeconds: 0.04,
            pointCount: 30
        )
        let observedDecay = AcousticResponseAnalysis(
            contractVersion: "orgrec-acoustic-response-analysis/1",
            qualification: .observedInstrumentRelease,
            referenceChannel: 1,
            analyzedAt: .now,
            analyzedDurationSeconds: 2,
            directArrivalSeconds: nil,
            broadband: AcousticBandMetrics(
                centerFrequencyHz: nil, lowerFrequencyHz: nil, upperFrequencyHz: nil,
                edt: nil, t20: observedT20, t30: nil,
                clarity50DB: nil, clarity80DB: nil, definition50: nil,
                centerTimeSeconds: nil, directToReverberantRatioDB: nil,
                estimatedNoiseFloorDB: -62, usableDecayRangeDB: 29,
                multiSlope: nil, temporalResolutionSeconds: 1 / 96_000
            ),
            octaveBands: [],
            standardReference: nil,
            conformanceStatement: "Descriptive pipe-plus-room release evidence; no ISO 3382 conformance is claimed.",
            method: "Export contract fixture",
            warnings: []
        )
        project.takes.append(TakeRecord(
            id: takeID,
            roadmapItemID: try XCTUnwrap(project.roadmap.first?.id),
            takeNumber: 1,
            status: .accepted,
            endedAt: Date(),
            relativeAudioPath: "Audio/Originals/export-vector.wav",
            sampleRate: 96_000,
            channelCount: 2,
            frameCount: 4_096,
            analysis: AnalysisSummary(
                method: "CREPE Core ML",
                algorithmVersion: "test",
                onsetSeconds: 0.2,
                soundOffsetSeconds: 2.1,
                perceptualSpectralSummary: perceptualSpectrum,
                acousticResponseAnalysis: observedDecay
            ),
            captureDiagnostics: CaptureDiagnostics(
                receivedBuffers: 8,
                writtenBuffers: 8,
                writtenFrames: 4_096,
                channels: [ChannelCaptureStatistics(
                    channelIndex: 1,
                    role: "Reference",
                    peakDBFS: -6,
                    rmsDBFS: -18,
                    isReferenceChannel: true
                )]
            ),
            bwfMetadata: bwf,
            markerCorrections: [MarkerCorrection(
                marker: .soundOffset,
                automatedSeconds: 2.1,
                correctedSeconds: 2.25,
                author: "Reviewer",
                reason: "Last partial remained audible"
            )],
            analysisReferenceChannel: 1,
            loopPointSets: [acceptedLoop],
            acceptedLoopPointSetID: acceptedLoopID,
            loopPointReviews: [LoopPointReview(
                loopPointSetID: acceptedLoopID,
                resultingLoopPointSetID: acceptedLoopID,
                decision: "accepted-revision",
                author: "Reviewer",
                reason: "Repeated audition found no tonal or spatial seam."
            )]
        ))
        let sensorRaw = (0..<20).reduce(into: Data()) { data, index in
            data.append(MPU6050PacketDecoder.encode(MPU6050RawSample(
                sequence: UInt16(index), timestampMicroseconds: UInt32(index * 5_000),
                accelerometerX: 0, accelerometerY: 0, accelerometerZ: 8_192,
                temperatureRaw: 0, gyroscopeX: 0, gyroscopeY: 0, gyroscopeZ: 0, status: 0x13
            )))
        }
        var sensorConfiguration = InteractionSensorConfiguration(
            name: "Export-test hinge sensor", capturePolicy: .required, transport: .serial,
            portPath: "/dev/cu.test", targetComponentID: project.roadmap[0].component.id,
            targetComponentLabel: project.roadmap[0].component.label, movementModel: .hinge,
            validationState: .acceptedForExperiment
        )
        let sensorCalibration = InteractionSensorCalibration(
            configurationID: sensorConfiguration.id, stationarySampleCount: 400, movementSampleCount: 800,
            gyroBiasDPS: .zero, gyroNoiseRMSDPS: 0.1,
            neutralGravityUnit: SensorVector3(x: 0, y: 0, z: 1), hingeAxisUnit: .unitX,
            estimatedTravelDegrees: 10, axisExplainedVariance: 0.99, gravityIsObservable: true, qualityScore: 0.95
        )
        sensorConfiguration.currentCalibrationID = sensorCalibration.id
        let sensorCaptureID = UUID()
        let sensorStem = "\(takeID.uuidString.lowercased())-\(sensorCaptureID.uuidString.lowercased())"
        let sensorRecord = InteractionSensorCaptureRecord(
            id: sensorCaptureID, takeID: takeID, configurationSnapshot: sensorConfiguration,
            calibrationSnapshot: sensorCalibration, startedAt: .now, endedAt: .now,
            rawRelativePath: "Sensors/Raw/\(sensorStem).imu", rawSHA256: sensorRaw.sha256Hex,
            rawByteCount: Int64(sensorRaw.count), metadataRelativePath: "Metadata/SensorCaptures/\(sensorStem).json",
            derivedRelativePath: "Sensors/Derived/\(sensorStem).json",
            health: InteractionSensorHealthSnapshot(receivedPackets: 20, observedSampleRateHz: 200),
            clockAlignment: InteractionSensorClockAlignment(
                status: .fittedHostReceipts, clockBasis: "test fit", audioStartHostNanoseconds: 1_000,
                segments: [SensorClockSegment(firstDeviceMicroseconds: 0, lastDeviceMicroseconds: 95_000, slope: 1, offsetSeconds: 0, driftPPM: 0, residualRMSSeconds: 0.001)],
                anchors: [], baseUncertaintySeconds: 0.003, notes: "test"
            ),
            motionEventCount: 1
        )
        project.interactionSensorConfigurations = [sensorConfiguration]
        project.interactionSensorCalibrations = [sensorCalibration]
        project.activeInteractionSensorConfigurationID = sensorConfiguration.id
        project.takes[0].interactionSensorCaptures = [sensorRecord]
        let longTakeID = UUID()
        let longTakeBytes = Data("preserved continuous source master".utf8)
        let longSegment = LongTakeSegment(
            sequenceNumber: 1,
            onsetSeconds: 0.2,
            soundOffsetSeconds: 2.1,
            exportStartSeconds: 0,
            exportEndSeconds: 2.5,
            onsetConfidence: 0.9,
            offsetConfidence: 0.85,
            peakDBFS: -6,
            assignedRoadmapItemID: project.roadmap[0].id,
            assignedMIDINote: project.roadmap[0].component.midiNote,
            expectedFrequencyHz: project.roadmap[0].component.expectedFrequencyHz,
            assignmentConfidence: 0.92
        )
        let longAnalysis = LongTakeAnalysis(
            sourceFilename: "export-long.wav",
            sourceDurationSeconds: 3,
            sampleRate: 96_000,
            channelCount: 2,
            bitDepth: 32,
            encoding: "linear PCM floating point",
            referenceChannel: 1,
            assignmentMode: .ascendingFromAnchor,
            anchorRoadmapItemID: project.roadmap[0].id,
            noiseFloorDBFS: -60,
            activityThresholdDBFS: -45,
            tailThresholdDBFS: -55,
            configuration: LongTakeSegmentationConfiguration(),
            segments: [longSegment]
        )
        project.longTakeSources = [LongTakeSourceRecord(
            id: longTakeID,
            sourceFilename: "export-long.wav",
            relativeAudioPath: "Audio/LongTakes/export-long.wav",
            sha256: longTakeBytes.sha256Hex,
            fileSize: Int64(longTakeBytes.count),
            sampleRate: 96_000,
            channelCount: 2,
            frameCount: 288_000,
            analysis: longAnalysis,
            generatedTakeIDs: [takeID],
            sourceWasRecordedInOrgRec: false
        )]
        project.takes[0].longTakeSource = LongTakeSliceProvenance(
            longTakeID: longTakeID,
            sourceRelativeAudioPath: "Audio/LongTakes/export-long.wav",
            sourceSHA256: longTakeBytes.sha256Hex,
            sourceStartSeconds: 0,
            sourceEndSeconds: 2.5,
            detectedOnsetSeconds: 0.2,
            detectedSoundOffsetSeconds: 2.1,
            assignmentMode: .ascendingFromAnchor,
            assignmentConfidence: 0.92,
            analyzerVersion: LongTakeSegmenter.algorithmVersion
        )
        project.roadmap[0].takeIDs.append(takeID)
        project.roadmap[0].state = .accepted
        try await ProjectStore().createPackage(at: package, project: project)
        try await ProjectStore().storeNavigatorPayload(
            frozenPayload,
            expectedSHA256: project.snapshot.payloadSHA256,
            relativePath: try XCTUnwrap(project.navigatorPayloadRelativePath),
            at: package
        )
        let audio = package.appendingPathComponent("Audio/Originals/export-vector.wav")
        try syntheticAudio.write(to: audio)
        try longTakeBytes.write(to: package.appendingPathComponent("Audio/LongTakes/export-long.wav"))
        try Data("synthetic calibration payload".utf8).write(to: package.appendingPathComponent("Audio/Calibration/export-calibration.wav"))
        try preflightAudio.write(to: package.appendingPathComponent(preflightPath))
        try sensorRaw.write(to: package.appendingPathComponent(sensorRecord.rawRelativePath))
        try OrgRecCoding.encoder.encode(sensorRecord).write(to: package.appendingPathComponent(sensorRecord.metadataRelativePath))
        try OrgRecCoding.encoder.encode(InteractionSensorDerivedData(
            captureID: sensorCaptureID,
            processingIdentifier: "test",
            preview: [InteractionSensorPreviewPoint(deviceMicroseconds: 0, angleDegrees: 0, angularVelocityDPS: 0, accelerationMagnitudeG: 1, progress: 0)],
            motionEvents: []
        )).write(to: package.appendingPathComponent(try XCTUnwrap(sensorRecord.derivedRelativePath)))
        let sidecar = audio.deletingPathExtension().appendingPathExtension("bwf.json")
        try OrgRecCoding.encoder.encode(bwf).write(to: sidecar)
        try await CapturePackageBuilder().build(project: project, packageURL: package, destinationURL: export)

        let manifestURL = export.appendingPathComponent("capture-package.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: export.appendingPathComponent("modavis-snapshot.json").path))
        let manifest = try OrgRecCoding.decoder.decode(
            CapturePackageManifest.self,
            from: Data(contentsOf: manifestURL)
        )
        XCTAssertEqual(manifest.releaseBinding.requestedRelease, "1.1")
        XCTAssertEqual(manifest.schemaVersion, "orgrec-capture-package/2.0")
        XCTAssertEqual(manifest.software, OrgRecSoftware.current)
        XCTAssertEqual(manifest.iadManifestRelativePath, IADContract.manifestFilename)
        XCTAssertNotNil(manifest.integrity["project.json"])
        XCTAssertNotNil(manifest.integrity["modavis-snapshot.json"])
        XCTAssertNotNil(manifest.integrity["consistency-report.json"])
        XCTAssertNotNil(manifest.consistencyScore)
        XCTAssertEqual(manifest.integrity["modavis-navigator-payload.json"], frozenPayload.sha256Hex)
        XCTAssertEqual(
            try Data(contentsOf: export.appendingPathComponent("modavis-navigator-payload.json")),
            frozenPayload
        )
        let entry = try XCTUnwrap(manifest.takes.first { $0.takeID == takeID })
        let analysisPath = try XCTUnwrap(entry.analysisRelativePath)
        let envelope = try OrgRecCoding.decoder.decode(
            TakeAnalysisPackage.self,
            from: Data(contentsOf: export.appendingPathComponent(analysisPath))
        )
        XCTAssertEqual(envelope.analysisReferenceChannel, 1)
        XCTAssertEqual(envelope.captureDiagnostics?.writtenFrames, 4_096)
        XCTAssertEqual(envelope.markerCorrections.first?.correctedSeconds, 2.25)
        XCTAssertEqual(envelope.bwfMetadata?.originatorReference, "ORGREC-EXPORT-TEST")
        XCTAssertEqual(envelope.acceptedLoopPointSetID, acceptedLoopID)
        XCTAssertEqual(envelope.loopPointSets?.first?.sustainRegion?.startFrameInclusive, 1_000)
        XCTAssertEqual(envelope.loopPointReviews?.count, 1)
        XCTAssertEqual(envelope.longTakeSource?.longTakeID, longTakeID)
        XCTAssertEqual(envelope.analysis.perceptualSpectralSummary?.auditoryCentroidERB, 15.4)
        XCTAssertEqual(envelope.analysis.acousticResponseAnalysis?.broadband.t20?.standardUncertaintySeconds, 0.04)
        XCTAssertTrue(entry.derivedRelativePaths.contains { $0.hasSuffix(".bwf.json") })
        XCTAssertEqual(entry.interactionSensorRelativePaths?.count, 3)
        XCTAssertTrue(entry.interactionSensorRelativePaths?.contains { $0.hasPrefix("sensors/raw/") } == true)
        XCTAssertTrue(entry.interactionSensorRelativePaths?.allSatisfy { manifest.integrity[$0] != nil } == true)
        XCTAssertEqual(envelope.interactionSensorCaptures?.first?.rawSHA256, sensorRaw.sha256Hex)

        let iad = try OrgRecCoding.decoder.decode(
            IADDatasetManifest.self,
            from: Data(contentsOf: export.appendingPathComponent(IADContract.manifestFilename))
        )
        XCTAssertEqual(iad.contractVersion, IADContract.version)
        XCTAssertEqual(iad.software, OrgRecSoftware.current)
        XCTAssertEqual(iad.projectionMode, IADContract.projectionMode)
        XCTAssertEqual(iad.projectID, project.id)
        XCTAssertEqual(iad.organ.mdvsID, project.organMDVSID)
        XCTAssertEqual(iad.counts.sessions, 1)
        XCTAssertEqual(iad.counts.takes, 1)
        XCTAssertEqual(iad.counts.files, 3)
        XCTAssertEqual(iad.counts.channels, 2)
        XCTAssertEqual(iad.counts.calibrations, 1)
        XCTAssertEqual(iad.counts.temperamentAnalyses, 1)
        XCTAssertTrue(iad.files.contains { $0.relativePath == "manifests/takes.jsonl" })
        XCTAssertTrue(iad.files.contains { $0.relativePath == "manifests/calibrations.jsonl" })
        XCTAssertTrue(iad.files.contains { $0.relativePath == "manifests/temperament-analyses.jsonl" })
        XCTAssertTrue(iad.files.contains { $0.relativePath == "audio/calibration-\(calibration.id.uuidString.lowercased()).wav" })
        XCTAssertTrue(iad.files.contains { $0.relativePath == "audio/preflight-\(preflightID.uuidString.lowercased()).wav" })
        XCTAssertTrue(iad.files.contains { $0.relativePath == "audio/\(takeID.uuidString.lowercased()).wav" })
        XCTAssertTrue(iad.files.contains { $0.relativePath == "audio/long-take-\(longTakeID.uuidString.lowercased()).wav" })
        let iadParadata: [IADParadataRecord] = try String(
            contentsOf: export.appendingPathComponent(iad.manifests.paradata),
            encoding: .utf8
        ).split(separator: "\n").map { try OrgRecCoding.decoder.decode(IADParadataRecord.self, from: Data($0.utf8)) }
        XCTAssertTrue(iadParadata.allSatisfy { $0.software == OrgRecSoftware.current })
        let iadSessions: [IADSessionRecord] = try String(
            contentsOf: export.appendingPathComponent(iad.manifests.sessions),
            encoding: .utf8
        ).split(separator: "\n").map { try OrgRecCoding.decoder.decode(IADSessionRecord.self, from: Data($0.utf8)) }
        XCTAssertEqual(iadSessions.first?.capturePreflightReports?.first?.report.id, preflightID)
        XCTAssertEqual(iadSessions.first?.capturePreflightReports?.first?.audioRelativePath, "audio/preflight-\(preflightID.uuidString.lowercased()).wav")
        let iadTakes: [IADTakeRecord] = try String(
            contentsOf: export.appendingPathComponent(iad.manifests.takes),
            encoding: .utf8
        ).split(separator: "\n").map { try OrgRecCoding.decoder.decode(IADTakeRecord.self, from: Data($0.utf8)) }
        let iadTake = try XCTUnwrap(iadTakes.first { $0.localTakeID == takeID })
        XCTAssertEqual(iadTake.physicalSoundTargetID, project.roadmap[0].physicalSoundTargetID)
        XCTAssertEqual(iadTake.equivalentComponentLocators?.count, 1)
        XCTAssertEqual(iadTake.activationRoutes?.count, 1)
        XCTAssertEqual(iadTake.longTakeSource?.longTakeID, longTakeID)
        let iadSegments: [IADSegmentRecord] = try String(
            contentsOf: export.appendingPathComponent(iad.manifests.segments),
            encoding: .utf8
        ).split(separator: "\n").map { try OrgRecCoding.decoder.decode(IADSegmentRecord.self, from: Data($0.utf8)) }
        XCTAssertTrue(iadSegments.contains { $0.segmentType == "sustain-loop" && $0.source == "reviewed-loop-point-set" })
        XCTAssertTrue(iadSegments.contains { $0.segmentType == "automatically-detected-note-candidate" && $0.localFileID == longTakeID })
        let iadObservations: [IADObservationRecord] = try String(
            contentsOf: export.appendingPathComponent(iad.manifests.observations),
            encoding: .utf8
        ).split(separator: "\n").map { try OrgRecCoding.decoder.decode(IADObservationRecord.self, from: Data($0.utf8)) }
        XCTAssertTrue(iadObservations.contains { $0.property == "auditory-centroid-erb" && $0.numericValue == 15.4 })
        XCTAssertTrue(iadObservations.contains { $0.property == "observed-decay-t20" && $0.numericValue == 2 && $0.uncertainty == 0.04 })

        let report = try IADPackageValidator.validate(packageURL: export)
        XCTAssertTrue(report.isValid, report.errors.joined(separator: "; "))
        XCTAssertGreaterThan(report.verifiedFileCount, 10)

        let importedURL = root.appendingPathComponent("Imported.orgrec", isDirectory: true)
        let imported = try await IADPackageImporter().importPackage(from: export, to: importedURL)
        XCTAssertEqual(imported.id, project.id)
        let importedAudio = importedURL.appendingPathComponent(try XCTUnwrap(imported.takes.first?.relativeAudioPath))
        XCTAssertEqual(try sha256(of: importedAudio), entry.audioSHA256)
        XCTAssertTrue(FileManager.default.fileExists(atPath: importedAudio.deletingPathExtension().appendingPathExtension("bwf.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: importedURL.appendingPathComponent("Audio/Calibration/export-calibration.wav").path))
        XCTAssertEqual(try sha256(of: importedURL.appendingPathComponent(preflightPath)), preflightAudio.sha256Hex)
        XCTAssertEqual(
            try sha256(of: importedURL.appendingPathComponent("Audio/LongTakes/export-long.wav")),
            longTakeBytes.sha256Hex
        )

        let vaoURL = root.appendingPathComponent("Looped.vao")
        _ = try await VAOPackageBuilder().build(project: project, packageURL: package, destinationURL: vaoURL)
        let vaoReport = try VAOPackageValidator.validate(packageURL: vaoURL)
        XCTAssertTrue(vaoReport.isValid, vaoReport.errors.joined(separator: "; "))
        let vao = try VAOPackageValidator.manifest(packageURL: vaoURL)
        let vaoSessionID = "urn:uuid:\(preflightSessionID.uuidString.lowercased())"
        XCTAssertNotNil(vao.entities.first(where: { $0.id == vaoSessionID })?.properties?[VAOContract.vaoNamespace + "capturePreflightReports"])
        XCTAssertTrue(vao.profiles.contains { $0.id == VAOContract.playableProfile })
        XCTAssertEqual(vao.entities.filter { $0.kind == "loopPointSet" }.count, 1)
        XCTAssertEqual(vao.entities.filter { $0.kind == "signalRegion" }.count, 2)
        XCTAssertTrue(vao.entities.contains { $0.types.contains(VAOContract.sampleExtractionRegionType) })
        XCTAssertTrue(vao.entities.contains { $0.types.contains(VAOContract.samplePlaybackParametersType) })
        XCTAssertTrue(vao.entities.contains { $0.types.contains(VAOContract.tuningMapType) })
        XCTAssertTrue(vao.entities.contains { $0.types.contains(VAOContract.tuningCalibrationType) })
        XCTAssertTrue(vao.profiles.contains {
            $0.id == VAOContract.researchProfile
                && $0.requiredCapabilities.contains(VAOContract.sourceSegmentationCapability)
                && $0.requiredCapabilities.contains(VAOContract.acousticalAnalysisCapability)
                && $0.requiredCapabilities.contains(VAOContract.tuningMapCapability)
        })
        XCTAssertTrue(vao.profiles.contains {
            $0.id == VAOContract.playableProfile
                && $0.requiredCapabilities.contains(VAOContract.sampledInstrumentPlaybackCapability)
        })
        XCTAssertTrue(vao.analyses.flatMap(\.observations).contains {
            $0.sourceRegionId != nil && $0.timeRange?.startFrameInclusive != nil && $0.timeRange?.clockAssetId != nil
        })
        XCTAssertFalse(vao.analyses.flatMap(\.observations).contains {
            $0.unit == "http://qudt.org/vocab/unit/Centi" || $0.unit == "https://qudt.org/vocab/unit/Centi"
        })
        XCTAssertTrue(vao.analyses.flatMap(\.observations).contains {
            $0.property == VAOContract.vaoVocabulary + "analysis/spectrum/auditory-centroid-erb"
        })
        XCTAssertTrue(vao.analyses.flatMap(\.observations).contains {
            $0.property == VAOContract.vaoVocabulary + "analysis/acoustics/observed-decay-t20"
                && $0.uncertainty == 0.04
        })
        XCTAssertTrue(vao.relations.contains { $0.predicate == VAOContract.usesLoopPointSet })
        let crossPlatform = Process()
        let crossPlatformOutput = Pipe()
        crossPlatform.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        crossPlatform.arguments = ["python3", FileManager.default.currentDirectoryPath + "/Tools/vaom.py", "validate", vaoURL.path, "--json"]
        crossPlatform.standardOutput = crossPlatformOutput
        crossPlatform.standardError = crossPlatformOutput
        try crossPlatform.run()
        crossPlatform.waitUntilExit()
        XCTAssertEqual(crossPlatform.terminationStatus, 0, String(data: crossPlatformOutput.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")

        let takesIndex = export.appendingPathComponent(iad.manifests.takes)
        try Data("tamper".utf8).appendToFile(takesIndex)
        let tampered = try IADPackageValidator.validate(packageURL: export)
        XCTAssertFalse(tampered.isValid)
        XCTAssertTrue(tampered.errors.contains { $0.contains("SHA-256 mismatch") })
    }

    func testConsistencyAuditFindsBrokenBindingsAndAcceptsFrozenParadata() throws {
        var project = DemoProjectFactory.make()
        for index in project.roadmap.indices { project.roadmap[index].state = .missing }
        project.recordingSessions = []
        project.roadmap[0].component.locator.snapshotSHA256 = "stale"
        var report = ProjectConsistencyAuditor.audit(project: project)
        XCTAssertGreaterThan(report.blockerCount, 0)
        XCTAssertTrue(report.issues.contains { $0.id == "session.none" })
        XCTAssertTrue(report.issues.contains { $0.scope == .modavis && $0.roadmapItemID == project.roadmap[0].id })

        project.recordingSessions = [RecordingSession(
            sessionCode: "QA-001",
            operatorName: "Researcher",
            rightsStatement: "Research capture with venue permission",
            environment: EnvironmentReading(temperatureCelsius: 19.2, relativeHumidityPercent: 54)
        )]
        project.roadmap[0].component.locator.snapshotSHA256 = project.snapshot.payloadSHA256
        let takeID = UUID()
        project.takes = [TakeRecord(
            id: takeID,
            roadmapItemID: project.roadmap[0].id,
            takeNumber: 1,
            status: .recorded,
            endedAt: .now,
            relativeAudioPath: "Audio/Originals/qa.wav",
            sampleRate: 96_000,
            channelCount: 2,
            frameCount: 96_000
        )]
        project.roadmap[0].takeIDs = [takeID]
        project.roadmap[0].state = .recorded
        report = ProjectConsistencyAuditor.audit(project: project)
        XCTAssertEqual(report.blockerCount, 0)
        XCTAssertTrue(report.isExportReady)
    }

    func testVAOIsPrimarySingleFileRoundTripWithGraphFixityAndOrgRecProfile() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Source.orgrec", isDirectory: true)
        let archive = root.appendingPathComponent("Exchange.vao")
        let imported = root.appendingPathComponent("Imported.orgrec", isDirectory: true)
        var project = DemoProjectFactory.make()
        project.title = "VAO round-trip project"
        project.recordingSessions = [RecordingSession(
            sessionCode: "VAO-001",
            operatorName: "VAO tester",
            rightsStatement: "Test fixture only"
        )]
        try await ProjectStore().createPackage(at: source, project: project)
        let evidence = Data("frozen navigator evidence".utf8)
        let evidencePath = "Manifests/navigator-source.json"
        try evidence.write(to: source.appendingPathComponent(evidencePath))
        project.navigatorPayloadRelativePath = evidencePath
        project.snapshot.payloadSHA256 = evidence.sha256Hex
        try await ProjectStore().save(project, at: source)

        try await VAOPackageBuilder().build(project: project, packageURL: source, destinationURL: archive)
        XCTAssertTrue(FileManager.default.fileExists(atPath: archive.path))
        XCTAssertGreaterThan((try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0, 0)

        let validation = try VAOPackageValidator.validate(packageURL: archive)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))
        let manifest = try VAOPackageValidator.manifest(packageURL: archive)
        XCTAssertEqual(validation.verifiedAssetCount, manifest.assets.count)
        XCTAssertEqual(manifest.formatVersion, VAOContract.formatVersion)
        XCTAssertEqual(VAOContract.formatVersion, "0.2.2")
        XCTAssertTrue(manifest.profiles.contains { $0.id == VAOContract.orgRecProfile })
        XCTAssertTrue(manifest.assets.contains { $0.path == "payload/orgrec/project.json" })
        XCTAssertTrue(manifest.assets.contains { $0.path == "payload/orgrec/\(evidencePath)" })
        XCTAssertTrue(manifest.entities.contains { $0.id == manifest.rootEntityId && $0.types.contains(VAOContract.pipeOrganType) })
        XCTAssertFalse(manifest.relations.isEmpty)

        let crossPlatformValidator = Process()
        let validatorOutput = Pipe()
        crossPlatformValidator.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        crossPlatformValidator.arguments = [
            "python3",
            FileManager.default.currentDirectoryPath + "/Tools/vaom.py",
            "validate",
            archive.path,
            "--json",
        ]
        crossPlatformValidator.standardOutput = validatorOutput
        crossPlatformValidator.standardError = validatorOutput
        try crossPlatformValidator.run()
        crossPlatformValidator.waitUntilExit()
        let validatorText = String(
            data: validatorOutput.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        ) ?? ""
        XCTAssertEqual(crossPlatformValidator.terminationStatus, 0, validatorText)

        let restored = try await VAOPackageImporter().importPackage(from: archive, to: imported)
        XCTAssertEqual(restored.id, project.id)
        XCTAssertEqual(restored.title, project.title)
        XCTAssertEqual(
            try Data(contentsOf: imported.appendingPathComponent(evidencePath)),
            evidence
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.appendingPathComponent("Manifests/ImportedVAO").path))
    }

    func testGrandOrgueODFImportPreservesReferencesRightsAndVAORoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-grandorgue-\(UUID().uuidString)", isDirectory: true)
        let source = root.appendingPathComponent("Tiny Set", isDirectory: true)
        let projectURL = root.appendingPathComponent("Tiny.orgrec", isDirectory: true)
        let archive = root.appendingPathComponent("Tiny.vao")
        let restoredURL = root.appendingPathComponent("Restored.orgrec", isDirectory: true)
        try FileManager.default.createDirectory(at: source.appendingPathComponent("Samples", isDirectory: true), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2))
        for name in ["060-C.wav", "061-C#.wav"] {
            let file = try AVAudioFile(forWriting: source.appendingPathComponent("Samples/\(name)"), settings: format.settings)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 512))
            buffer.frameLength = 512
            try file.write(from: buffer)
        }
        let odfText = """
        ; Windows-1252 fixture: Bureå
        [Organ]
        ChurchName=Tiny Bureå Organ
        ChurchAddress=Test Chapel, Sweden
        OrganBuilder=Fixture Builder
        OrganBuildDate=1990
        OrganComments=https://creativecommons.org/licenses/by-sa/2.5/se/
        RecordingDetails=Recorded 2009 by Test Author
        NumberOfManuals=1
        NumberOfTremulants=0

        [Manual001]
        Name=Manual
        NumberOfAccessibleKeys=2
        FirstAccessibleKeyMIDINoteNumber=60
        NumberOfStops=2
        Stop001=101
        Stop002=102

        [Stop101]
        Name=Gedackt 8'
        NumberOfAccessiblePipes=2
        FirstAccessiblePipeLogicalPipeNumber=1
        FirstAccessiblePipeLogicalKeyNumber=1
        Pipe001=.\\Samples\\060-C.wav
        Pipe002=.\\Samples\\061-C#.wav

        [Stop102]
        Name=Salicional 8'
        NumberOfAccessiblePipes=1
        FirstAccessiblePipeLogicalPipeNumber=1
        FirstAccessiblePipeLogicalKeyNumber=1
        Pipe001=REF:001:001:001
        """
        let odfURL = source.appendingPathComponent("tiny.organ")
        try XCTUnwrap(odfText.data(using: .windowsCP1252)).write(to: odfURL)
        try Data("Fixture source license\n".utf8).write(to: source.appendingPathComponent("LICENSE.txt"))

        let importer = GrandOrgueSampleSetImporter()
        let inspection = try await importer.inspect(odfURL: odfURL, sourcePageURL: "https://example.org/tiny-organ")
        XCTAssertEqual(inspection.odfEncoding, "Windows-1252")
        XCTAssertEqual(inspection.organName, "Tiny Bureå Organ")
        XCTAssertEqual(inspection.stops.count, 2)
        XCTAssertTrue(inspection.controls.isEmpty)
        XCTAssertEqual(inspection.referencedSampleCount, 3)
        XCTAssertEqual(inspection.uniqueReferencedAudioCount, 2)
        XCTAssertEqual(inspection.missingSampleCount, 0)
        XCTAssertEqual(inspection.samples.filter { $0.referenceTarget != nil }.count, 1)
        XCTAssertEqual(inspection.licenseLabel, "Creative Commons Attribution-ShareAlike 2.5")

        let project = try await importer.importSampleSet(
            odfURL: odfURL,
            to: projectURL,
            sourcePageURL: "https://example.org/tiny-organ"
        )
        XCTAssertEqual(project.takes.count, 3)
        XCTAssertEqual(Set(project.takes.map(\.relativeAudioPath)).count, 2)
        XCTAssertTrue(project.organMDVSID.hasPrefix("SOURCE:grandorgue:"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("Audio/Originals/GrandOrgue/Tiny Set/tiny.organ").path))

        _ = try await VAOPackageBuilder().build(project: project, packageURL: projectURL, destinationURL: archive)
        let validation = try VAOPackageValidator.validate(packageURL: archive)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))
        let manifest = try VAOPackageValidator.manifest(packageURL: archive)
        let rootEntity = try XCTUnwrap(manifest.entities.first { $0.id == manifest.rootEntityId })
        XCTAssertTrue(manifest.profiles.contains { $0.id == VAOContract.playableProfile })
        XCTAssertEqual(manifest.entities.filter { $0.kind == "interaction" }.count, 2)
        XCTAssertEqual(rootEntity.externalIdentifiers?.first?.scheme, VAOContract.vaoVocabulary + "identifier-scheme/source-bound")
        XCTAssertEqual(rootEntity.externalIdentifiers?.first?.resolvesTo, "https://example.org/tiny-organ")
        XCTAssertEqual(manifest.rights.first?.license, "https://creativecommons.org/licenses/by-sa/2.5/se/")
        let odfAsset = try XCTUnwrap(manifest.assets.first { $0.originalFilename == "tiny.organ" })
        XCTAssertEqual(odfAsset.roles, [VAOContract.sourceEvidenceRole])
        XCTAssertEqual(odfAsset.encoding, "Windows-1252")

        let restored = try await VAOPackageImporter().importPackage(from: archive, to: restoredURL)
        XCTAssertEqual(restored.id, project.id)
        XCTAssertEqual(restored.organMDVSID, project.organMDVSID)
        XCTAssertEqual(
            try sha256(of: restoredURL.appendingPathComponent("Audio/Originals/GrandOrgue/Tiny Set/Samples/060-C.wav")),
            try sha256(of: source.appendingPathComponent("Samples/060-C.wav"))
        )
    }

    func testWAVSamplerMetadataPreservesMultipleLoopsAndInclusiveEndConversion() throws {
        func littleEndian(_ value: UInt32) -> Data {
            Data([
                UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
                UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff),
            ])
        }
        var smpl = Data()
        for value: UInt32 in [0, 0, 20_833, 60, 0, 0, 0, 2, 0] { smpl.append(littleEndian(value)) }
        for values: [UInt32] in [
            [1, 0, 100, 199, 0, 0],
            [2, 1, 300, 499, 0, 3],
        ] {
            for value in values { smpl.append(littleEndian(value)) }
        }
        var wave = Data("RIFF".utf8)
        wave.append(littleEndian(UInt32(4 + 8 + smpl.count)))
        wave.append(Data("WAVEsmpl".utf8))
        wave.append(littleEndian(UInt32(smpl.count)))
        wave.append(smpl)

        let metadata = try XCTUnwrap(WAVSamplerMetadataReader.read(from: wave))
        XCTAssertEqual(metadata.midiUnityNote, 60)
        XCTAssertEqual(metadata.loops.count, 2)
        XCTAssertEqual(metadata.loops[0].startFrameInclusive, 100)
        XCTAssertEqual(metadata.loops[0].sourceEndFrameInclusive, 199)
        XCTAssertEqual(metadata.loops[0].endFrameExclusive, 200)
        XCTAssertEqual(metadata.loops[1].mode, "alternating")
        XCTAssertEqual(metadata.loops[1].playCount, 3)
    }

    func testRF64SamplerMetadataAfterSentinelDataChunkUsesDS64Size() throws {
        func littleEndian32(_ value: UInt32) -> Data {
            Data([
                UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
                UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff),
            ])
        }
        func littleEndian64(_ value: UInt64) -> Data {
            Data((0..<8).map { UInt8((value >> UInt64($0 * 8)) & 0xff) })
        }
        var smpl = Data()
        for value: UInt32 in [0, 0, 20_833, 60, 0, 0, 0, 1, 0] { smpl.append(littleEndian32(value)) }
        for value: UInt32 in [1, 0, 10, 19, 0, 0] { smpl.append(littleEndian32(value)) }

        var ds64 = Data()
        ds64.append(littleEndian64(0)) // RIFF size is not needed for chunk traversal.
        ds64.append(littleEndian64(4)) // True size of the sentinel data chunk.
        ds64.append(littleEndian64(1))
        ds64.append(littleEndian32(0))

        var wave = Data("RF64".utf8)
        wave.append(littleEndian32(UInt32.max))
        wave.append(Data("WAVEds64".utf8))
        wave.append(littleEndian32(UInt32(ds64.count)))
        wave.append(ds64)
        wave.append(Data("data".utf8))
        wave.append(littleEndian32(UInt32.max))
        wave.append(Data(repeating: 0, count: 4))
        wave.append(Data("smpl".utf8))
        wave.append(littleEndian32(UInt32(smpl.count)))
        wave.append(smpl)

        let metadata = try XCTUnwrap(WAVSamplerMetadataReader.read(from: wave))
        XCTAssertEqual(metadata.container, "RF64")
        XCTAssertEqual(metadata.loops.count, 1)
        XCTAssertEqual(metadata.loops[0].endFrameExclusive, 20)
    }

    func testGrandOrgueCompoundRanksVariantsAndPackageRelativeTraversalArePreserved() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-grandorgue-ranks-\(UUID().uuidString)", isDirectory: true)
        let package = temporary.appendingPathComponent("Compound.CompPkg.Hauptwerk", isDirectory: true)
        let definitions = package.appendingPathComponent("OrganDefinitions", isDirectory: true)
        let samples = package.appendingPathComponent("OrganInstallationPackages/001", isDirectory: true)
        try FileManager.default.createDirectory(at: definitions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: samples, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        for name in ["rank1.wav", "rank1-release.wav", "rank2.wav"] {
            let file = try AVAudioFile(forWriting: samples.appendingPathComponent(name), settings: format.settings)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 64))
            buffer.frameLength = 64
            try file.write(from: buffer)
        }
        let odf = definitions.appendingPathComponent("compound.organ")
        let text = """
        [Organ]
        ChurchName=Compound fixture
        NumberOfManuals=1

        [Manual001]
        Name=Great
        NumberOfAccessibleKeys=1
        FirstAccessibleKeyMIDINoteNumber=60
        NumberOfStops=1
        Stop001=107

        [Stop107]
        Name=Cornet 2 ranks
        NumberOfRanks=2
        Rank001=001
        Rank002=002
        NumberOfAccessiblePipes=1
        FirstAccessiblePipeLogicalKeyNumber=1

        [Rank001]
        Name=Foundation layer
        FirstMidiNoteNumber=60
        NumberOfLogicalPipes=1
        HarmonicNumber=8
        AmplitudeLevel=90
        Pipe001=..\\OrganInstallationPackages\\001\\rank1.wav
        Pipe001PitchTuning=-12.5
        Pipe001ReleaseCount=1
        Pipe001Release001=..\\OrganInstallationPackages\\001\\rank1-release.wav

        [Rank002]
        Name=Octave layer
        FirstMidiNoteNumber=60
        NumberOfLogicalPipes=1
        HarmonicNumber=16
        Pipe001=..\\OrganInstallationPackages\\001\\rank2.wav
        """
        try Data(text.utf8).write(to: odf)

        let inspection = try await GrandOrgueSampleSetImporter().inspect(odfURL: odf)
        XCTAssertEqual(inspection.sourceDirectory, package.path)
        XCTAssertEqual(inspection.odfRelativePath, "OrganDefinitions/compound.organ")
        XCTAssertEqual(inspection.stops.count, 1)
        XCTAssertEqual(inspection.stops[0].rankSectionNames, ["Rank001", "Rank002"])
        XCTAssertEqual(inspection.stops[0].logicalPipeCount, 2)
        XCTAssertEqual(inspection.samples.count, 3)
        XCTAssertEqual(inspection.missingSampleCount, 0)
        XCTAssertEqual(Set(inspection.samples.compactMap(\.sampleRole)), ["attack-sustain", "release"])
        XCTAssertEqual(inspection.samples.first { $0.rankSection == "Rank001" && $0.sampleRole == "attack-sustain" }?.pitchTuningCents, -12.5)
        XCTAssertEqual(inspection.samples.first { $0.rankSection == "Rank002" }?.harmonicNumber, 16)
        XCTAssertTrue(inspection.samples.allSatisfy { $0.sourceRelativePath?.hasPrefix("OrganInstallationPackages/001/") == true })
    }

    func testGrandOrgueParentTraversalOutsidePackageRootIsRejected() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-grandorgue-escape-\(UUID().uuidString)", isDirectory: true)
        let package = temporary.appendingPathComponent("Unsafe.CompPkg.Hauptwerk", isDirectory: true)
        let definitions = package.appendingPathComponent("OrganDefinitions", isDirectory: true)
        try FileManager.default.createDirectory(at: definitions, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: package.appendingPathComponent("OrganInstallationPackages"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let odf = definitions.appendingPathComponent("unsafe.organ")
        let text = """
        [Organ]
        ChurchName=Unsafe fixture
        NumberOfManuals=1
        [Manual001]
        Name=Great
        NumberOfAccessibleKeys=1
        FirstAccessibleKeyMIDINoteNumber=60
        Stop001=101
        [Stop101]
        Name=Principal 8'
        NumberOfAccessiblePipes=1
        FirstAccessiblePipeLogicalPipeNumber=1
        FirstAccessiblePipeLogicalKeyNumber=1
        Pipe001=..\\..\\outside.wav
        """
        try Data(text.utf8).write(to: odf)
        try Data("outside".utf8).write(to: temporary.appendingPathComponent("outside.wav"))

        let inspection = try await GrandOrgueSampleSetImporter().inspect(odfURL: odf)
        XCTAssertEqual(inspection.missingSampleCount, 1)
        XCTAssertNil(inspection.samples[0].sourceRelativePath)
        XCTAssertTrue(inspection.warnings.contains { $0.contains("escapes the selected package root") })
    }

    func testSoundFontInspectorPreservesHeaderPitchLinksAndDeclaredLoopRangeWithoutClaimingActivation() throws {
        func le16(_ value: UInt16) -> Data { Data([UInt8(value & 0xff), UInt8(value >> 8)]) }
        func le32(_ value: UInt32) -> Data {
            Data([UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8((value >> 24) & 0xff)])
        }
        func header(name: String, start: UInt32, end: UInt32, loopStart: UInt32, loopEnd: UInt32, rate: UInt32, pitch: UInt8, correction: Int8, link: UInt16, type: UInt16) -> Data {
            var data = Data(name.utf8.prefix(20))
            data.append(Data(repeating: 0, count: 20 - data.count))
            for value in [start, end, loopStart, loopEnd, rate] { data.append(le32(value)) }
            data.append(pitch)
            data.append(UInt8(bitPattern: correction))
            data.append(le16(link))
            data.append(le16(type))
            return data
        }
        var shdr = header(name: "Principal C", start: 0, end: 1_000, loopStart: 100, loopEnd: 900, rate: 44_100, pitch: 60, correction: -3, link: 2, type: 4)
        shdr.append(header(name: "EOS", start: 1_000, end: 1_000, loopStart: 1_000, loopEnd: 1_000, rate: 44_100, pitch: 0, correction: 0, link: 0, type: 1))
        var pdta = Data("pdta".utf8)
        pdta.append(Data("shdr".utf8))
        pdta.append(le32(UInt32(shdr.count)))
        pdta.append(shdr)
        var body = Data("sfbkLIST".utf8)
        body.append(le32(UInt32(pdta.count)))
        body.append(pdta)
        var file = Data("RIFF".utf8)
        file.append(le32(UInt32(body.count)))
        file.append(body)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-sf2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("fixture.sf2")
        try file.write(to: url)
        let inspection = try SoundFont2Inspector.inspect(url: url)
        XCTAssertEqual(inspection.sampleHeaders.count, 1)
        XCTAssertEqual(inspection.sampleHeaders[0].loopEndSamplePointExclusive, 900)
        XCTAssertTrue(inspection.sampleHeaders[0].hasDeclaredLoopRange)
        XCTAssertEqual(inspection.sampleHeaders[0].pitchCorrectionCents, -3)
        XCTAssertEqual(inspection.sampleHeaders[0].sampleLink, 2)
        XCTAssertTrue(inspection.mappingStatus.contains("not asserted active"))
    }

    func testNativeCorpusInspectorKeepsFormatCapabilitiesAndIdentityLimitsExplicit() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-native-corpus-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("""
        [Organ]
        [Stop101]
        Name=Cornet
        Rank001=001
        [Rank001]
        HarmonicNumber=8
        Pipe001=.\\Samples\\one.wav
        Pipe001Release001=.\\Samples\\one-release.wav
        Pipe001PitchTuning=-4.5
        """.utf8).write(to: root.appendingPathComponent("fixture.organ"))
        try Data("""
        <Hauptwerk><ObjectList ObjectType="Sample"><o/><o/></ObjectList><ObjectList ObjectType="Rank"><o/></ObjectList></Hauptwerk>
        """.utf8).write(to: root.appendingPathComponent("fixture.Organ_Hauptwerk_xml"))
        try Data("""
        <organ><elements><rank id="1"/><rank id="2"/><console id="3"/></elements></organ>
        """.utf8).write(to: root.appendingPathComponent("fixture.disposition"))
        try Data("license evidence".utf8).write(to: root.appendingPathComponent("LICENSE.txt"))

        let inspection = try await NativeSampleCorpusInspector().inspect(roots: [root])
        XCTAssertEqual(inspection.definitions.count, 3)
        let grandOrgue = try XCTUnwrap(inspection.definitions.first { $0.format == .grandOrgue })
        XCTAssertEqual(grandOrgue.objectCounts["rankBindings"], 1)
        XCTAssertEqual(grandOrgue.objectCounts["releaseVariants"], 1)
        let hauptwerk = try XCTUnwrap(inspection.definitions.first { $0.format == .hauptwerk })
        XCTAssertEqual(hauptwerk.objectCounts["objects:Sample"], 2)
        XCTAssertTrue(hauptwerk.semanticDecoding.contains("opaque"))
        let jorgan = try XCTUnwrap(inspection.definitions.first { $0.format == .jOrgan })
        XCTAssertEqual(jorgan.objectCounts["elements:rank"], 2)
        XCTAssertEqual(inspection.rightsEvidencePaths.count, 1)
        XCTAssertTrue(inspection.identityPolicy.contains("distinct identities"))
    }

    func testQueuedEightChannelWriterProduces24BitBWFWithoutDrops() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-writer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("eight-channel.wav")
        let layout = try XCTUnwrap(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | 8))
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 96_000,
            interleaved: false,
            channelLayout: layout
        )
        let metadata = BWFMetadata(
            description: "OrgRec eight-channel stress vector",
            originatorReference: "ORGREC-TEST-8CH",
            originationDate: "2026-08-12",
            originationTime: "21:00:00",
            codingHistory: "A=PCM,F=96000,W=24,M=8"
        )
        let writer = try QueuedAudioWriter(
            audioURL: url,
            inputFormat: format,
            bufferCapacity: 1_024,
            poolSize: 32,
            channelRoles: (1...8).map { "Input \($0)" },
            bwfMetadata: metadata
        )
        var sampleTime: AVAudioFramePosition = 0
        for bufferIndex in 0..<120 {
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_024)!
            buffer.frameLength = 1_024
            for channel in 0..<8 {
                let samples = buffer.floatChannelData![channel]
                for frame in 0..<1_024 {
                    let phase = 2 * Double.pi * Double(110 + channel * 55) * Double(bufferIndex * 1_024 + frame) / 96_000
                    samples[frame] = Float(0.15 * sin(phase))
                }
            }
            writer.enqueue(
                buffer,
                time: AVAudioTime(sampleTime: sampleTime, atRate: 96_000)
            )
            sampleTime += 1_024
        }
        let (diagnostics, bwf) = writer.finish()
        XCTAssertEqual(diagnostics.droppedBuffers, 0)
        XCTAssertEqual(diagnostics.discontinuityCount, 0)
        XCTAssertEqual(diagnostics.writtenFrames, 120 * 1_024)
        XCTAssertEqual(diagnostics.channels.count, 8)
        XCTAssertTrue(diagnostics.faults.isEmpty)
        XCTAssertEqual(bwf?.embedded, true)

        let audio = try AVAudioFile(forReading: url)
        XCTAssertEqual(audio.fileFormat.channelCount, 8)
        XCTAssertEqual(audio.fileFormat.sampleRate, 96_000)
        XCTAssertEqual(audio.fileFormat.streamDescription.pointee.mBitsPerChannel, 24)
        let prefix = try Data(contentsOf: url, options: .mappedIfSafe).prefix(2_048)
        XCTAssertNotNil(prefix.range(of: Data("bext".utf8)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("eight-channel.bwf.json").path))
    }

    func testAnalysisViewportKeepsLinkedVisualsWithinRecordingBounds() {
        let full = AnalysisTimeViewport.full(duration: 12)
        XCTAssertEqual(full.time(atNormalizedX: 0.25), 3, accuracy: 0.000_001)
        XCTAssertEqual(full.normalizedX(for: 9), 0.75, accuracy: 0.000_001)

        let zoomed = full.zoomed(by: 3, anchorNormalizedX: 0.75, totalDuration: 12)
        XCTAssertEqual(zoomed.duration, 4, accuracy: 0.000_001)
        XCTAssertEqual(zoomed.time(atNormalizedX: 0.75), 9, accuracy: 0.000_001)

        let pannedPastEnd = zoomed.panned(bySeconds: 100, totalDuration: 12)
        XCTAssertEqual(pannedPastEnd.startSeconds, 8, accuracy: 0.000_001)
        XCTAssertEqual(pannedPastEnd.endSeconds, 12, accuracy: 0.000_001)
        let pannedPastStart = pannedPastEnd.panned(bySeconds: -100, totalDuration: 12)
        XCTAssertEqual(pannedPastStart.startSeconds, 0, accuracy: 0.000_001)
    }

    func testSustainLoopRendererUsesSharedEqualPowerCycleAcrossChannels() throws {
        let frames = 1_000
        let crossfade = 80
        let left = (0..<frames).map { Float(0.3 * sin(2 * Double.pi * 10 * Double($0) / Double(frames))) }
        let right = left.map { $0 * 0.5 }
        let rendered = try SustainLoopRenderer.renderForwardCycle(channels: [left, right], crossfadeFrames: crossfade)
        XCTAssertEqual(rendered.count, 2)
        XCTAssertEqual(rendered[0].count, frames - crossfade)
        XCTAssertEqual(rendered[1].count, frames - crossfade)
        for index in stride(from: 0, to: rendered[0].count, by: 37) {
            XCTAssertEqual(rendered[1][index], rendered[0][index] * 0.5, accuracy: 0.000_001)
        }
        XCTAssertThrowsError(try SustainLoopRenderer.renderForwardCycle(channels: [left], crossfadeFrames: frames / 2))
    }

    func testSpectrogramInspectorReportsStoredBinAndQualifiedPartialEvidence() throws {
        let partial = PartialTrack(
            harmonicNumber: 2,
            expectedFrequencyHz: 400,
            medianFrequencyHz: 401,
            medianOffsetCents: nil,
            peakDB: -8,
            onsetSeconds: 0.5,
            offsetSeconds: 1.5,
            points: [PartialTrackPoint(
                timeSeconds: 1,
                frequencyHz: 401,
                amplitudeDB: -12,
                localSignalToNoiseDB: 18,
                isValid: true
            )],
            noiseFloorDB: -60,
            signalToNoiseDB: 18,
            validPointRatio: 1,
            frequencyMADHz: 0.5,
            decayRateDBPerSecond: -7,
            confidence: 0.9
        )
        let data = SpectrogramData(
            magnitudes: [
                [-90, -80, -70],
                [-60, -20, -50],
                [-75, -65, -55],
            ],
            timeBins: 3,
            frequencyBins: 3,
            maximumFrequency: 600,
            timeStepSeconds: 1,
            frequencyAxisHz: [200, 400, 600],
            configuration: SpectrogramConfiguration(partialSearchCents: 50),
            partialTracks: [partial]
        )
        let inspected = try XCTUnwrap(SpectrogramInspector.inspect(
            data: data,
            normalizedX: 0.5,
            normalizedY: 0.5,
            viewport: .full(duration: 2)
        ))
        XCTAssertEqual(inspected.timeSeconds, 1, accuracy: 0.000_001)
        XCTAssertEqual(inspected.frequencyHz, 400, accuracy: 0.000_001)
        XCTAssertEqual(inspected.relativeMagnitudeDB, -20, accuracy: 0.000_001)
        XCTAssertEqual(inspected.timeBin, 1)
        XCTAssertEqual(inspected.frequencyBin, 1)
        XCTAssertEqual(inspected.nearestPartialHarmonic, 2)
        XCTAssertEqual(inspected.nearestPartialSignalToNoiseDB, 18)
        XCTAssertEqual(inspected.nearestPartialIsValid, true)
    }

    func testPitchEstimatorComparisonNeverAveragesCriticalMismatch() throws {
        let crepe = PitchEstimate(
            frequencyHz: 440,
            confidence: 0.92,
            method: "CREPE Core ML",
            modelVersion: "crepe-test"
        )
        let pyin = PitchEstimate(
            frequencyHz: 466.163_8,
            confidence: 0.88,
            method: "Probabilistic YIN",
            modelVersion: "pyin-test"
        )
        let fallback = PitchEstimate(
            frequencyHz: 440.2,
            confidence: 0.8,
            method: "Normalized autocorrelation fallback",
            modelVersion: "acf-test"
        )
        let resolution = PitchEstimatorComparisonEngine.resolve(
            crepe: crepe,
            pyin: pyin,
            fallback: fallback,
            expectedFrequency: 440
        )
        XCTAssertEqual(resolution.comparison.severity, .critical)
        XCTAssertEqual(resolution.comparison.differenceCents ?? 0, 100, accuracy: 0.01)
        XCTAssertEqual(resolution.comparison.selectedEstimator, "CREPE")
        XCTAssertEqual(resolution.estimate?.frequencyHz ?? 0, 440, accuracy: 0.001)
        XCTAssertTrue(resolution.estimate?.method.contains("critical") == true)
        XCTAssertTrue(resolution.comparison.rationale.contains("not averaged") || resolution.comparison.rationale.contains("were not averaged"))
    }

    func testPYINTracksHarmonicRichOrganToneIndependently() async throws {
        let sampleRate = 48_000.0
        let expected = 220.0
        let samples: [Float] = (0..<Int(sampleRate * 1.6)).map { index in
            let time = Double(index) / sampleRate
            let attack = min(1, time / 0.08)
            return Float(attack * (
                0.07 * sin(2 * .pi * expected * time)
                + 0.22 * sin(2 * .pi * expected * 2 * time)
                + 0.13 * sin(2 * .pi * expected * 3 * time)
                + 0.06 * sin(2 * .pi * expected * 5 * time)
            ))
        }
        let rawEstimate = try await PYINPitchEstimator().estimate(
            samples: samples,
            sampleRate: sampleRate,
            expectedFrequency: expected
        )
        let estimate = try XCTUnwrap(rawEstimate)
        XCTAssertLessThan(abs(PitchMatcher.cents(measured: estimate.frequencyHz, expected: expected) ?? 99), 8)
        XCTAssertGreaterThan(estimate.confidence, 0.5)
        XCTAssertGreaterThan(estimate.track.filter(\.voiced).count, 10)
        XCTAssertEqual(estimate.modelVersion, "orgrec-pyin/1")
    }

    func testNativeVAOValidatorCoversEveryExperientialCapabilityAndRejectsInvalidPolicy() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao-xr-validation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let validArchive = root.appendingPathComponent("valid.vao")
        var manifest = try experientialFixtureManifest()
        try writeFixtureArchive(manifest: manifest, to: validArchive)
        let valid = try VAOPackageValidator.validate(packageURL: validArchive)
        XCTAssertTrue(valid.isValid, valid.errors.joined(separator: "; "))

        let inspection = try await VAOPackageReader().inspect(validArchive)
        XCTAssertEqual(inspection.experiences.count, 7)
        XCTAssertEqual(
            Set(inspection.experiences.map(\.capability)),
            VAOContract.experientialCapabilities
        )
        XCTAssertTrue(inspection.capabilities.filter {
            VAOContract.experientialCapabilities.contains($0.capability)
        }.allSatisfy { $0.validationSupported && $0.processing == .metadataOnly })

        let placementKey = VAOContract.property("placementPolicy")
        for index in manifest.entities.indices
        where manifest.entities[index].properties?[VAOContract.property("experienceCapability")]?.stringValue == VAOContract.surfacePlacementARCapability {
            var policy = try XCTUnwrap(manifest.entities[index].properties?[placementKey]?.objectValue)
            policy["surfaceAlignment"] = .string("ceiling")
            manifest.entities[index].properties?[placementKey] = .object(policy)
        }
        let invalidArchive = root.appendingPathComponent("invalid-placement.vao")
        try writeFixtureArchive(manifest: manifest, to: invalidArchive)
        let invalid = try VAOPackageValidator.validate(packageURL: invalidArchive)
        XCTAssertFalse(invalid.isValid)
        XCTAssertTrue(invalid.errors.contains { $0.contains("invalid placementPolicy") })
    }

    func testNativeVAOSchemaRejectsUnknownClosedObjectMembers() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao-schema-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let manifest = try experientialFixtureManifest()
        let data = try OrgRecCoding.encoder.encode(manifest)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["unregisteredField"] = true
        let invalidManifestData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let archive = root.appendingPathComponent("unknown-field.vao")
        try writeFixtureArchive(manifestData: invalidManifestData, manifest: manifest, to: archive)
        let report = try VAOPackageValidator.validate(packageURL: archive)
        XCTAssertFalse(report.isValid)
        XCTAssertTrue(report.errors.contains { $0.contains("unknown property unregisteredField") })
    }

    func testGeneralVAOWorkspaceImportAndAssetExtraction() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao-general-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("experiential.vao")
        let manifest = try experientialFixtureManifest()
        try writeFixtureArchive(manifest: manifest, to: archive)
        let workspace = root.appendingPathComponent("workspace", isDirectory: true)
        let reader = VAOPackageReader()
        let inspection = try await reader.importWorkspace(from: archive, to: workspace)
        XCTAssertTrue(inspection.validation.isValid)
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.appendingPathComponent("payload/media/model.glb").path))
        let target = try XCTUnwrap(manifest.assets.first { $0.roles.contains(VAOContract.imageTargetRole) })
        let extracted = root.appendingPathComponent("target.png")
        try await reader.extractAsset(id: target.id, from: archive, to: extracted)
        XCTAssertEqual(try sha256(of: extracted), target.sha256)
    }

    func testOrgRecRoundTripPreservesImportedExperientialGraphAndExternalPayload() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao-xr-roundtrip-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceProject = root.appendingPathComponent("Source.orgrec", isDirectory: true)
        let baseArchive = root.appendingPathComponent("Base.vao")
        let augmentedArchive = root.appendingPathComponent("Augmented.vao")
        let importedProject = root.appendingPathComponent("Imported.orgrec", isDirectory: true)
        let reexported = root.appendingPathComponent("Reexported.vao")

        let project = DemoProjectFactory.make()
        try await ProjectStore().createPackage(at: sourceProject, project: project)
        try await VAOPackageBuilder().build(project: project, packageURL: sourceProject, destinationURL: baseArchive)
        var manifest = try VAOPackageValidator.manifest(packageURL: baseArchive)
        let external = root.appendingPathComponent("xr-note.txt")
        try Data("preserved XR payload\n".utf8).write(to: external)
        let externalAssetID = "urn:vao:test:asset:external-xr"
        let groupID = "urn:vao:test:asset-group"
        let experienceID = "urn:vao:test:experience:offline"
        manifest.assets.append(VAOAsset(
            id: externalAssetID,
            path: "payload/xr/note.txt",
            mediaType: "text/plain",
            byteSize: 0,
            sha256: String(repeating: "0", count: 64),
            roles: [VAOContract.sourceEvidenceRole],
            representationStatus: VAOContract.vaoVocabulary + "representation-status/authored",
            aboutEntityIds: [manifest.rootEntityId],
            originalFilename: "xr-note.txt"
        ))
        manifest.entities.append(VAOEntity(
            id: groupID,
            kind: "assetGroup",
            types: [VAOContract.vaoNamespace + "AssetGroup"],
            labels: ["en": "Offline XR material"],
            properties: [VAOContract.property("assetGroupPolicy"): .object([
                "availability": .string("offline-required"),
                "selection": .string("independent"),
                "defaultSelected": .boolean(true),
            ])]
        ))
        manifest.entities.append(VAOEntity(
            id: experienceID,
            kind: "experience",
            types: [VAOContract.vaoNamespace + "Experience"],
            labels: ["en": "Offline XR experience"],
            properties: [VAOContract.property("experienceCapability"): .string(VAOContract.offlineAssetGroupsCapability)]
        ))
        manifest.relations.append(VAORelation(subjectId: experienceID, predicate: VAOContract.property("presents"), objectId: manifest.rootEntityId))
        manifest.relations.append(VAORelation(subjectId: experienceID, predicate: VAOContract.property("offersAssetGroup"), objectId: groupID))
        manifest.relations.append(VAORelation(subjectId: groupID, predicate: VAOContract.property("includesAsset"), objectId: externalAssetID))
        let retainedEntityProperty = "https://example.org/xr/root-display-hint"
        let retainedRelationProperty = "https://example.org/xr/relation-display-hint"
        let rootIndex = try XCTUnwrap(manifest.entities.firstIndex { $0.id == manifest.rootEntityId })
        manifest.entities[rootIndex].properties = (manifest.entities[rootIndex].properties ?? [:]).merging([
            retainedEntityProperty: .string("holographic")
        ]) { _, new in new }
        let relationIndex = try XCTUnwrap(manifest.relations.firstIndex { $0.subjectId == manifest.rootEntityId })
        manifest.relations[relationIndex].properties = (manifest.relations[relationIndex].properties ?? [:]).merging([
            retainedRelationProperty: .string("retain-on-edit")
        ]) { _, new in new }
        manifest.profiles.append(VAOProfile(id: VAOContract.experientialProfile, requiredCapabilities: [VAOContract.offlineAssetGroupsCapability]))
        manifest.conformsTo.append(VAOContract.experientialProfile)

        var sources = manifest.assets.compactMap { asset -> VAOPackageAssetSource? in
            guard asset.id != externalAssetID, asset.path.hasPrefix("payload/orgrec/") else { return nil }
            return VAOPackageAssetSource(
                assetId: asset.id,
                fileURL: sourceProject.appendingPathComponent(String(asset.path.dropFirst("payload/orgrec/".count)))
            )
        }
        sources.append(VAOPackageAssetSource(assetId: externalAssetID, fileURL: external))
        let augmentedReport = try await VAOPackageWriter().write(manifest: manifest, assetSources: sources, to: augmentedArchive)
        XCTAssertTrue(augmentedReport.isValid, augmentedReport.errors.joined(separator: "; "))

        var imported = try await VAOPackageImporter().importPackage(from: augmentedArchive, to: importedProject)
        XCTAssertNotNil(imported.importedVAO)
        imported.title = "Edited after XR import"
        try await ProjectStore().save(imported, at: importedProject)
        try await VAOPackageBuilder().build(project: imported, packageURL: importedProject, destinationURL: reexported)

        let finalReport = try VAOPackageValidator.validate(packageURL: reexported)
        XCTAssertTrue(finalReport.isValid, finalReport.errors.joined(separator: "; "))
        let finalManifest = try VAOPackageValidator.manifest(packageURL: reexported)
        XCTAssertEqual(finalManifest.id, manifest.id)
        XCTAssertEqual(finalManifest.revision, manifest.revision + 1)
        XCTAssertTrue(finalManifest.profiles.contains { $0.id == VAOContract.experientialProfile })
        XCTAssertTrue(finalManifest.entities.contains { $0.id == experienceID })
        XCTAssertTrue(finalManifest.assets.contains { $0.path == "payload/xr/note.txt" && $0.id == externalAssetID })
        XCTAssertEqual(
            finalManifest.entities.first { $0.id == manifest.rootEntityId }?.properties?[retainedEntityProperty],
            .string("holographic")
        )
        XCTAssertEqual(
            finalManifest.relations.first { $0.id == manifest.relations[relationIndex].id }?.properties?[retainedRelationProperty],
            .string("retain-on-edit")
        )
        let extracted = root.appendingPathComponent("roundtripped-note.txt")
        try await VAOPackageReader().extractAsset(id: externalAssetID, from: reexported, to: extracted)
        XCTAssertEqual(try Data(contentsOf: extracted), try Data(contentsOf: external))
    }

    func testLongTakeSegmenterFindsAndClassifiesSeparatedOrganNotes() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-long-take-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("continuous.wav")
        let sampleRate = 24_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        var samples: [Float] = []
        var expectedOnsetFrames: [Int64] = []

        func appendRoomTone(seconds: Double) {
            let count = Int(seconds * sampleRate)
            for index in 0..<count {
                samples.append(Float(0.000_45 * sin(2 * Double.pi * 37 * Double(samples.count + index) / sampleRate)))
            }
        }

        func appendPipe(frequency: Double, seconds: Double) {
            expectedOnsetFrames.append(Int64(samples.count))
            let count = Int(seconds * sampleRate)
            for index in 0..<count {
                let time = Double(index) / sampleRate
                let attack = min(1, time / 0.06)
                let release = min(1, (seconds - time) / 0.18)
                let envelope = max(0, min(attack, release))
                let fundamental = sin(2 * Double.pi * frequency * time)
                let second = 0.28 * sin(2 * Double.pi * frequency * 2 * time)
                let chiff = 0.045 * exp(-time / 0.012) * sin(2 * Double.pi * 3_700 * time)
                samples.append(Float(0.16 * envelope * (fundamental + second) + chiff))
            }
        }

        appendRoomTone(seconds: 0.8137)
        appendPipe(frequency: 220, seconds: 2.1)
        appendRoomTone(seconds: 0.7313)
        appendPipe(frequency: 246.9417, seconds: 1.8)
        appendRoomTone(seconds: 0.6679)
        appendPipe(frequency: 277.1826, seconds: 2.2)
        appendRoomTone(seconds: 0.9)

        let buffer = try XCTUnwrap(AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ))
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { pointer in
            buffer.floatChannelData![0].update(from: pointer.baseAddress!, count: samples.count)
        }
        var outputFile: AVAudioFile? = try AVAudioFile(forWriting: source, settings: format.settings)
        try outputFile?.write(from: buffer)
        outputFile = nil

        let candidates = [
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 57, expectedFrequencyHz: 220, label: "A3"),
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 59, expectedFrequencyHz: 246.9417, label: "B3"),
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 61, expectedFrequencyHz: 277.1826, label: "C♯4"),
        ]
        let analysis = try await LongTakeSegmenter().analyze(
            fileURL: source,
            candidates: candidates,
            anchorRoadmapItemID: candidates[0].roadmapItemID,
            assignmentMode: .ascendingFromAnchor
        )
        XCTAssertEqual(analysis.segments.count, 3)
        XCTAssertEqual(analysis.segments.compactMap(\.assignedMIDINote), [57, 59, 61])
        for (segment, expectedOnsetFrame) in zip(analysis.segments, expectedOnsetFrames) {
            XCTAssertGreaterThan(segment.durationSeconds, 1.5)
            XCTAssertGreaterThan(segment.assignmentConfidence, 0.7)
            XCTAssertLessThan(abs(segment.pitchDeviationCents ?? 9_999), 35)
            XCTAssertEqual(segment.onsetDetectionMethod, "adaptive-multiband-harmonic-onset")
            XCTAssertLessThanOrEqual(segment.onsetTimeResolutionSeconds ?? 1, 0.001)
            let detectedOnsetFrame = try XCTUnwrap(segment.onsetFrame)
            XCTAssertGreaterThanOrEqual(detectedOnsetFrame, expectedOnsetFrame - Int64(sampleRate * 0.02))
            XCTAssertLessThanOrEqual(detectedOnsetFrame, expectedOnsetFrame + Int64(sampleRate * 0.003))
            XCTAssertEqual(segment.exportStartFrame, max(0, detectedOnsetFrame - Int64(sampleRate * 0.01)))
            XCTAssertEqual(segment.exportStartSeconds, max(0, segment.onsetSeconds - 0.01), accuracy: 1 / sampleRate)
            XCTAssertEqual(segment.tailDetectionMethod, "frequency-local-harmonic-decay")
            XCTAssertGreaterThan(segment.tailEndSeconds ?? 0, segment.soundOffsetSeconds)
        }

        let destinations = Dictionary(uniqueKeysWithValues: analysis.segments.map { segment in
            (segment.id, root.appendingPathComponent("split-\(segment.sequenceNumber).wav"))
        })
        let exports = try await LongTakeAudioExporter().export(
            sourceURL: source,
            segments: analysis.segments,
            destinations: destinations
        )
        XCTAssertEqual(exports.count, 3)
        for exported in exports {
            XCTAssertTrue(FileManager.default.fileExists(atPath: exported.destinationURL.path))
            XCTAssertEqual(exported.sampleRate, sampleRate)
            XCTAssertEqual(exported.channelCount, 1)
            XCTAssertGreaterThan(exported.frameCount, Int64(sampleRate * 1.5))
            let segment = try XCTUnwrap(analysis.segments.first { $0.id == exported.segmentID })
            XCTAssertEqual(exported.frameCount, (segment.exportEndFrame ?? 0) - (segment.exportStartFrame ?? 0))

            let sourceFile = try AVAudioFile(forReading: source)
            let splitFile = try AVAudioFile(forReading: exported.destinationURL)
            sourceFile.framePosition = try XCTUnwrap(segment.exportStartFrame)
            let compareFrames: AVAudioFrameCount = 512
            let sourceBuffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: sourceFile.processingFormat, frameCapacity: compareFrames))
            let splitBuffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: splitFile.processingFormat, frameCapacity: compareFrames))
            try sourceFile.read(into: sourceBuffer, frameCount: compareFrames)
            try splitFile.read(into: splitBuffer, frameCount: compareFrames)
            XCTAssertEqual(sourceBuffer.frameLength, splitBuffer.frameLength)
            for frame in 0..<Int(sourceBuffer.frameLength) {
                XCTAssertEqual(sourceBuffer.floatChannelData![0][frame], splitBuffer.floatChannelData![0][frame], accuracy: 1e-7)
            }
        }
    }

    func testLongTakeOnsetRefinementAdaptsFromLowPipeBloomToHighPipeSpeech() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-frequency-onsets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("low-and-high.wav")
        let sampleRate = 24_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        var samples: [Float] = []
        var expectedOnsets: [Int64] = []

        func appendRoom(seconds: Double) {
            let initialCount = samples.count
            for index in 0..<Int(seconds * sampleRate) {
                let time = Double(initialCount + index) / sampleRate
                samples.append(Float(0.000_28 * sin(2 * Double.pi * 41 * time) + 0.000_12 * sin(2 * Double.pi * 913 * time)))
            }
        }

        func appendPipe(frequency: Double, seconds: Double, attackSeconds: Double, transientFrequency: Double) {
            expectedOnsets.append(Int64(samples.count))
            for index in 0..<Int(seconds * sampleRate) {
                let time = Double(index) / sampleRate
                let attack = 1 - exp(-time / attackSeconds)
                let release = min(1, max(0, (seconds - time) / 0.16))
                let tone = sin(2 * Double.pi * frequency * time)
                    + 0.32 * sin(2 * Double.pi * frequency * 2 * time)
                    + 0.12 * sin(2 * Double.pi * frequency * 3 * time)
                let speechTransient = 0.035 * exp(-time / 0.018) * sin(2 * Double.pi * transientFrequency * time)
                samples.append(Float(0.15 * attack * release * tone + speechTransient))
            }
        }

        appendRoom(seconds: 0.7273)
        appendPipe(frequency: 32.7032, seconds: 2.8, attackSeconds: 0.16, transientFrequency: 640)
        appendRoom(seconds: 0.6841)
        appendPipe(frequency: 4_186.009, seconds: 1.7, attackSeconds: 0.008, transientFrequency: 7_200)
        appendRoom(seconds: 0.8)

        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)))
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer {
            buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count)
        }
        var output: AVAudioFile? = try AVAudioFile(forWriting: source, settings: format.settings)
        try output?.write(from: buffer)
        output = nil

        let candidates = [
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 24, expectedFrequencyHz: 32.7032, label: "C1"),
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 108, expectedFrequencyHz: 4_186.009, label: "C8"),
        ]
        let analysis = try await LongTakeSegmenter().analyze(
            fileURL: source,
            candidates: candidates,
            anchorRoadmapItemID: candidates[0].roadmapItemID,
            assignmentMode: .ascendingFromAnchor
        )
        XCTAssertEqual(analysis.segments.count, 2)
        XCTAssertEqual(analysis.analyzerVersion, LongTakeSegmenter.algorithmVersion)
        for (segment, expectedFrame) in zip(analysis.segments, expectedOnsets) {
            let onsetFrame = try XCTUnwrap(segment.onsetFrame)
            XCTAssertGreaterThanOrEqual(onsetFrame, expectedFrame - Int64(sampleRate * 0.03))
            XCTAssertLessThanOrEqual(onsetFrame, expectedFrame + Int64(sampleRate * 0.012))
            XCTAssertEqual(segment.exportStartFrame, max(0, onsetFrame - Int64(sampleRate * 0.01)))
            XCTAssertEqual(segment.onsetDetectionMethod, "adaptive-multiband-harmonic-onset")
        }
        XCTAssertGreaterThan(analysis.segments[0].onsetFrequencyWindowSeconds ?? 0, 0.04)
        XCTAssertLessThan(analysis.segments[1].onsetFrequencyWindowSeconds ?? 1, 0.004)
        XCTAssertLessThanOrEqual(analysis.segments[0].onsetTimeResolutionSeconds ?? 1, 0.001)
        XCTAssertLessThanOrEqual(analysis.segments[1].onsetTimeResolutionSeconds ?? 1, 0.001)
    }

    func testLongTakeOnsetRejectsDetachedMechanicalClick() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-click-resistant-onset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("click-before-high-pipe.wav")
        let sampleRate = 24_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let expectedOnset = 1.0
        var samples = [Float](repeating: 0, count: Int(3.5 * sampleRate))
        for index in samples.indices {
            samples[index] = Float(0.000_18 * sin(2 * Double.pi * 47 * Double(index) / sampleRate))
        }
        let clickStart = Int(0.67 * sampleRate)
        for index in 0..<Int(0.012 * sampleRate) {
            let envelope = exp(-Double(index) / (0.0025 * sampleRate))
            samples[clickStart + index] += Float(0.12 * envelope * sin(2 * Double.pi * 4_800 * Double(index) / sampleRate))
        }
        let pipeStart = Int(expectedOnset * sampleRate)
        let pipeDuration = 1.8
        for index in 0..<Int(pipeDuration * sampleRate) {
            let time = Double(index) / sampleRate
            let attack = 1 - exp(-time / 0.008)
            let release = min(1, max(0, (pipeDuration - time) / 0.2))
            let tone = sin(2 * Double.pi * 1_200 * time) + 0.22 * sin(2 * Double.pi * 2_400 * time)
            samples[pipeStart + index] += Float(0.14 * attack * release * tone)
        }
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)))
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        var output: AVAudioFile? = try AVAudioFile(forWriting: source, settings: format.settings)
        try output?.write(from: buffer)
        output = nil

        let candidate = LongTakePitchCandidate(
            roadmapItemID: UUID(), midiNote: 86, expectedFrequencyHz: 1_200, label: "high pipe"
        )
        let analysis = try await LongTakeSegmenter().analyze(
            fileURL: source,
            candidates: [candidate],
            anchorRoadmapItemID: candidate.roadmapItemID,
            assignmentMode: .ascendingFromAnchor
        )
        let segment = try XCTUnwrap(analysis.segments.first)
        XCTAssertEqual(analysis.segments.count, 1)
        XCTAssertGreaterThan(segment.onsetSeconds, expectedOnset - 0.025)
        XCTAssertLessThan(segment.onsetSeconds, expectedOnset + 0.015)
        XCTAssertLessThanOrEqual(segment.exportStartSeconds, expectedOnset)
        XCTAssertGreaterThan(segment.exportStartSeconds, expectedOnset - 0.04)
        XCTAssertGreaterThan(segment.onsetSeconds, 0.9, "The detached console click must not become the acoustic onset.")
    }

    func testLongTakeTailFollowsQuietHarmonicDecay() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-harmonic-tail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("long-release.wav")
        let sampleRate = 24_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        var samples: [Float] = []
        func appendRoom(_ seconds: Double) {
            let initial = samples.count
            for index in 0..<Int(seconds * sampleRate) {
                samples.append(Float(0.000_35 * sin(2 * Double.pi * 43 * Double(initial + index) / sampleRate)))
            }
        }
        appendRoom(0.8)
        let pipeStart = samples.count
        let sustainSeconds = 1.4
        let decaySeconds = 1.25
        for index in 0..<Int((sustainSeconds + decaySeconds) * sampleRate) {
            let time = Double(index) / sampleRate
            let attack = min(1, time / 0.04)
            let decay = time <= sustainSeconds ? 1 : exp(-(time - sustainSeconds) / 0.24)
            let tone = sin(2 * Double.pi * 220 * time) + 0.3 * sin(2 * Double.pi * 440 * time)
            samples.append(Float(0.16 * attack * decay * tone))
        }
        appendRoom(1.1)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)))
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        var output: AVAudioFile? = try AVAudioFile(forWriting: source, settings: format.settings)
        try output?.write(from: buffer)
        output = nil

        let candidate = LongTakePitchCandidate(
            roadmapItemID: UUID(), midiNote: 57, expectedFrequencyHz: 220, label: "A3"
        )
        let analysis = try await LongTakeSegmenter().analyze(
            fileURL: source,
            candidates: [candidate],
            anchorRoadmapItemID: candidate.roadmapItemID,
            assignmentMode: .ascendingFromAnchor
        )
        let segment = try XCTUnwrap(analysis.segments.first)
        let physicalOnset = Double(pipeStart) / sampleRate
        XCTAssertEqual(segment.tailDetectionMethod, "frequency-local-harmonic-decay")
        XCTAssertGreaterThan(segment.tailConfidence ?? 0, 0.45)
        XCTAssertGreaterThan(segment.exportEndSeconds, segment.soundOffsetSeconds + 0.45)
        XCTAssertGreaterThan(segment.exportEndSeconds, physicalOnset + sustainSeconds + 0.75)
        XCTAssertLessThan(segment.exportEndSeconds, physicalOnset + sustainSeconds + decaySeconds + 0.8)
    }

    func testLongTakeSequenceAssignmentHandlesRetakeMissingPipeAndSpuriousTone() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-sequence-assignment-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("retake-and-missing.wav")
        let sampleRate = 24_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        var samples: [Float] = []
        func appendRoom(_ seconds: Double) {
            let initial = samples.count
            for index in 0..<Int(seconds * sampleRate) {
                samples.append(Float(0.000_22 * sin(2 * Double.pi * 41 * Double(initial + index) / sampleRate)))
            }
        }
        func appendPipe(_ frequency: Double) {
            let seconds = 1.25
            for index in 0..<Int(seconds * sampleRate) {
                let time = Double(index) / sampleRate
                let envelope = min(1, time / 0.04) * min(1, max(0, (seconds - time) / 0.16))
                let tone = sin(2 * Double.pi * frequency * time) + 0.24 * sin(2 * Double.pi * frequency * 2 * time)
                samples.append(Float(0.14 * envelope * tone))
            }
        }
        appendRoom(0.7)
        for frequency in [220.0, 220.0, 246.9417, 349.2282, 261.6256] {
            appendPipe(frequency)
            appendRoom(0.55)
        }
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)))
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        var output: AVAudioFile? = try AVAudioFile(forWriting: source, settings: format.settings)
        try output?.write(from: buffer)
        output = nil

        let candidates = [
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 57, expectedFrequencyHz: 220, label: "A3"),
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 58, expectedFrequencyHz: 233.0819, label: "A♯3"),
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 59, expectedFrequencyHz: 246.9417, label: "B3"),
            LongTakePitchCandidate(roadmapItemID: UUID(), midiNote: 60, expectedFrequencyHz: 261.6256, label: "C4"),
        ]
        let analysis = try await LongTakeSegmenter().analyze(
            fileURL: source,
            candidates: candidates,
            anchorRoadmapItemID: candidates[0].roadmapItemID,
            assignmentMode: .ascendingFromAnchor
        )
        XCTAssertEqual(analysis.segments.count, 5)
        XCTAssertEqual(
            analysis.segments.map(\.assignedRoadmapItemID),
            [candidates[0].roadmapItemID, candidates[0].roadmapItemID, candidates[2].roadmapItemID, nil, candidates[3].roadmapItemID]
        )
        XCTAssertTrue(analysis.segments[1].warnings.contains { $0.contains("alternate take") })
        XCTAssertTrue(analysis.segments[2].warnings.contains { $0.contains("skipped 1 expected") })
        XCTAssertTrue(analysis.segments[3].warnings.contains { $0.contains("No roadmap note") })
    }

    func testHergertWeightedSlopeUsesPlotConsistentSignAndIsPitchNormalized() throws {
        let minusTwelveDBPerOctave: [Double?] = (1...20).map { harmonic in
            -12 * log2(Double(harmonic))
        }
        let features = TimbreFeatureCalculator.calculate(relativePartialLevelsDB: minusTwelveDBPerOctave)
        XCTAssertEqual(try XCTUnwrap(features.weightedAverageSlopeDBPerOctave), -12, accuracy: 0.000_001)
        let centroid = try XCTUnwrap(features.normalizedSpectralCentroid)
        XCTAssertGreaterThan(centroid, 1)

        // Multiplying every harmonic frequency by a different f₁ leaves c/f₁
        // unchanged because the implementation uses harmonic number n.
        let secondCalculation = TimbreFeatureCalculator.calculate(relativePartialLevelsDB: minusTwelveDBPerOctave)
        XCTAssertEqual(secondCalculation.normalizedSpectralCentroid, centroid)
    }

    func testHergertFirstFivePrototypeRecognizesWeakEvenPartials() {
        let prototype = TimbreFeatureCalculator.prototype(levels: [0, -18, -4, -20, -8])
        XCTAssertEqual(prototype, .weakEvenChalumeau)
    }

    func testTimbreAnalysisReadsReferenceChannelWithoutAntiPhaseDownmix() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-timbre-antiphase-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let rate = 48_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2))
        let count = Int(rate * 3)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)))
        buffer.frameLength = AVAudioFrameCount(count)
        for index in 0..<count {
            let time = Double(index) / rate
            let sample = Float(0.22 * sin(2 * Double.pi * 220 * time) + 0.07 * sin(2 * Double.pi * 660 * time))
            buffer.floatChannelData![0][index] = sample
            buffer.floatChannelData![1][index] = -sample
        }
        var file: AVAudioFile? = try AVAudioFile(forWriting: url, settings: format.settings)
        try file?.write(from: buffer)
        file = nil
        func input(channel: Int) -> TimbreAnalysisInput {
            TimbreAnalysisInput(
                fileURL: url,
                takeID: UUID(),
                roadmapItemID: UUID(),
                midiNote: 57,
                noteName: "A3",
                expectedFrequencyHz: 220,
                measuredFrequencyHz: 220,
                measuredConfidence: 0.99,
                sourceAudioSHA256: nil,
                sourceAnalysisRunID: nil,
                referenceChannel: channel,
                sustainStartSeconds: 0.2,
                soundOffsetSeconds: 2.8,
                keyUpSeconds: nil
            )
        }
        let engine = TimbreAnalysisEngine()
        let left = try await engine.analyze(input: input(channel: 0), mode: .characterization)
        let right = try await engine.analyze(input: input(channel: 1), mode: .characterization)
        XCTAssertEqual(left.referenceChannel, 0)
        XCTAssertEqual(right.referenceChannel, 1)
        XCTAssertGreaterThan(try XCTUnwrap(left.normalizedSpectralCentroid), 1)
        XCTAssertEqual(
            try XCTUnwrap(left.normalizedSpectralCentroid),
            try XCTUnwrap(right.normalizedSpectralCentroid),
            accuracy: 0.01
        )
    }

    func testTimbreReportPreservesPublicationsAndFlagsConstructionJump() {
        let first = makeTimbreObservation(midi: 36, centroid: 1.2, slope: -20)
        let second = makeTimbreObservation(midi: 37, centroid: 5.8, slope: 12)
        let report = TimbreAnalysisEngine.report(
            mode: .familySuggestion,
            rankComponentID: "rank:test",
            rankLabel: "Test rank",
            observations: [second, first]
        )
        XCTAssertEqual(report.observations.map(\.midiNote), [36, 37])
        XCTAssertEqual(Set(report.publicationDOIs), Set(TimbreMethodology.publications.map(\.doi)))
        XCTAssertTrue(report.warnings.contains { $0.contains("Abrupt timbre transition") })
        XCTAssertEqual(report.applicability, .limited)
        XCTAssertEqual(report.parameters, TimbreMethodology.parameters)
        XCTAssertEqual(report.parameterSHA256, TimbreMethodology.parameterSHA256)
        XCTAssertEqual(report.software, OrgRecSoftware.current)
        XCTAssertEqual(report.parameterSHA256?.count, 64)
    }

    func testTimbreCandidateDecodesLegacyProbabilityButEncodesRelativeSupport() throws {
        let legacy = Data(#"{"family":"flute","probability":0.75,"normalizedDistance":0.5,"explanation":"legacy"}"#.utf8)
        let candidate = try OrgRecCoding.decoder.decode(TimbreFamilyCandidate.self, from: legacy)
        XCTAssertEqual(candidate.relativeSupport, 0.75)
        let encoded = try OrgRecCoding.encoder.encode(candidate)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertEqual(object["relativeSupport"] as? Double, 0.75)
        XCTAssertNil(object["probability"])
    }

    func testTimbreFamilyProfileExplicitlyRejectsOutOfDistributionCoordinates() {
        let classification = TimbreAnalysisEngine.classify(features: TimbreFeatureResult(
            normalizedSpectralCentroid: 20,
            weightedAverageSlopeDBPerOctave: -10,
            evenToOddEnergyRatioDB: nil,
            firstFivePrototype: .indeterminate
        ))
        XCTAssertTrue(classification.candidates.isEmpty)
        XCTAssertTrue(classification.outOfDistributionReason?.contains("outside") == true)
    }

    func testTimbreRankAggregationRetainsDistanceUncertaintyAndEvidenceWeight() throws {
        let applicable = TimbreFamilyCandidate(
            family: .flute, relativeSupport: 0.8, normalizedDistance: 1,
            explanation: "fixture"
        )
        let limited = TimbreFamilyCandidate(
            family: .flute, relativeSupport: 0.2, normalizedDistance: 3,
            explanation: "fixture"
        )
        let report = TimbreAnalysisEngine.report(
            mode: .familySuggestion,
            rankComponentID: "rank:weighted",
            rankLabel: "Weighted rank",
            observations: [
                makeTimbreObservation(midi: 60, centroid: 1.2, slope: -20, candidates: [applicable]),
                makeTimbreObservation(midi: 61, centroid: 1.3, slope: -19, candidates: [limited], applicability: .limited),
            ]
        )
        let aggregate = try XCTUnwrap(report.familyCandidates.first)
        let weight = TimbreMethodology.parameters.limitedObservationWeight
        XCTAssertEqual(aggregate.normalizedDistance, (1 + 3 * weight) / (1 + weight), accuracy: 1e-12)
        XCTAssertNotNil(aggregate.relativeSupportStandardDeviation)
        XCTAssertEqual(try XCTUnwrap(aggregate.effectiveObservationCount), pow(1 + weight, 2) / (1 + weight * weight), accuracy: 1e-12)
    }

    func testTimbreTransitionDoesNotBridgeWidePitchGap() {
        let report = TimbreAnalysisEngine.report(
            mode: .characterization,
            rankComponentID: "rank:gapped",
            rankLabel: "Gapped rank",
            observations: [
                makeTimbreObservation(midi: 36, centroid: 1.1, slope: -25),
                makeTimbreObservation(midi: 48, centroid: 8, slope: 20),
            ]
        )
        XCTAssertFalse(report.warnings.contains { $0.contains("Abrupt timbre transition") })
        XCTAssertTrue(report.warnings.contains { $0.contains("no adjacent-pipe transition claim") })
    }

    func testTimbreScopeGatesCompoundAndDetunedRanks() {
        XCTAssertEqual(TimbreAnalysisEngine.scopeAssessment(rankLabel: "Mixture IV", componentKind: "rank").0, .notApplicable)
        XCTAssertEqual(TimbreAnalysisEngine.scopeAssessment(rankLabel: "Voix céleste 8′", componentKind: "rank").0, .notApplicable)
        XCTAssertEqual(TimbreAnalysisEngine.scopeAssessment(rankLabel: "Principal 8′", componentKind: "rank").0, .applicable)
        let scopedReport = TimbreAnalysisEngine.report(
            mode: .familySuggestion,
            rankComponentID: "rank:mixture",
            rankLabel: "Mixture IV",
            observations: (36..<48).map { makeTimbreObservation(midi: $0, centroid: 2, slope: -10) },
            scopeApplicability: .notApplicable,
            scopeWarnings: ["Compound rank scope gate"]
        )
        XCTAssertNil(scopedReport.empiricalClassification)
        XCTAssertNil(scopedReport.pitchDependentFingerprint)
    }

    func testDocumentaryTimbreLabelsAreAuditableAndScopeGated() throws {
        let reed = try XCTUnwrap(TimbreDocumentaryLabelNormalizer.assignment(for: "Trompette 8′"))
        XCTAssertEqual(reed.family, .reed)
        XCTAssertEqual(reed.status, "documentary-label-derived")
        XCTAssertTrue(reed.matchedRule.hasPrefix("reed:"))
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Principal 8′")?.family, .diapason)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Rohrflöte 4′")?.family, .flute)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Rörflöjt 4′")?.family, .flute)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Gedakt 8′")?.family, .flute)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Subbas 16′")?.family, .flute)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Oktava 4′")?.family, .diapason)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Basson 16′")?.family, .reed)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Basun 16′")?.family, .reed)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Viola da Gamba 8′")?.family, .string)
        XCTAssertNil(TimbreDocumentaryLabelNormalizer.assignment(for: "Mixture IV"))
        XCTAssertNil(TimbreDocumentaryLabelNormalizer.assignment(for: "Voix céleste 8′"))
        XCTAssertNil(TimbreDocumentaryLabelNormalizer.assignment(for: "StopNoise"))
    }

    func testPublicBuildDoesNotBundleUnreleasedEmpiricalClassifier() throws {
        XCTAssertNil(try EmpiricalTimbreClassifierModel.bundled())
    }

    func testPitchDependentFingerprintDetectsStrongQualifiedTransition() throws {
        let observations = (36..<60).map { midi -> PipeTimbreObservation in
            let isUpper = midi >= 48
            var observation = makeTimbreObservation(
                midi: midi,
                centroid: (isUpper ? 3.9 : 1.25) + Double(midi - 36) * 0.006,
                slope: (isUpper ? -4 : -21) + Double(midi - 36) * 0.04
            )
            observation.evenToOddEnergyRatioDB = (isUpper ? 7 : -17) + Double(midi % 3) * 0.05
            observation.partials = (1...8).map { harmonic in
                TimbrePartialMeasurement(
                    harmonicNumber: harmonic,
                    frequencyHz: midiFrequency(midi) * Double(harmonic),
                    relativeLevelDB: Double(1 - harmonic) * (isUpper ? 2.2 : 7.5) + Double(midi % 2) * 0.03,
                    energyFraction: harmonic == 1 ? 1 : 0.1,
                    localSignalToNoiseDB: 35
                )
            }
            return observation
        }
        let parameters = RankFingerprintParameters(
            minimumObservations: 8,
            minimumSegmentObservations: 4,
            maximumTransitions: 1,
            maximumAdjacentGapSemitones: 4,
            minimumBICImprovement: 10,
            significanceLevel: 0.05,
            permutationCount: 99,
            randomSeed: 42
        )
        let result = RankFingerprintAnalyzer.analyze(
            rankComponentID: "rank:test",
            rankLabel: "Test rank",
            observations: observations,
            parameters: parameters
        )
        let transition = try XCTUnwrap(result.transitions.first)
        XCTAssertEqual(transition.lowerMIDINote, 47)
        XCTAssertEqual(transition.upperMIDINote, 48)
        XCTAssertLessThanOrEqual(transition.familyWisePermutationPValue, 0.05)
        XCTAssertGreaterThan(transition.bicImprovementForSelectedSegmentation, 10)
        XCTAssertEqual(result.selectedSegmentCount, 2)
        XCTAssertEqual(result.points.map(\.midiNote), Array(36..<60))
        XCTAssertFalse(result.trends.isEmpty)
        XCTAssertNotNil(result.bassFingerprint)
        XCTAssertNotNil(result.middleFingerprint)
    }

    func testPitchDependentFingerprintRetainsDescriptionWhenUndersampled() {
        let observations = (60..<65).map {
            makeTimbreObservation(midi: $0, centroid: 1.4, slope: -14)
        }
        let result = RankFingerprintAnalyzer.analyze(
            rankComponentID: "rank:short",
            rankLabel: "Short rank",
            observations: observations
        )
        XCTAssertEqual(result.applicability, .limited)
        XCTAssertTrue(result.transitions.isEmpty)
        XCTAssertEqual(result.points.count, 5)
        XCTAssertFalse(result.trends.isEmpty)
    }

    func testRankFingerprintAvoidsSmoothFalsePositiveAndHandlesInvalidOrDuplicateInput() {
        var observations = (36..<60).map { midi in
            makeTimbreObservation(
                midi: midi,
                centroid: 1.1 + Double(midi - 36) * 0.018,
                slope: -22 + Double(midi - 36) * 0.11
            )
        }
        var duplicate = makeTimbreObservation(midi: 48, centroid: 9, slope: 30)
        duplicate.partials = []
        observations.append(duplicate)
        let smooth = RankFingerprintAnalyzer.analyze(
            rankComponentID: "rank:smooth",
            rankLabel: "Smooth rank",
            observations: observations,
            parameters: RankFingerprintParameters(permutationCount: 19, randomSeed: 3)
        )
        XCTAssertTrue(smooth.transitions.isEmpty)
        XCTAssertEqual(smooth.points.count, 24)
        XCTAssertEqual(Set(smooth.points.map(\.midiNote)).count, smooth.points.count)
        XCTAssertTrue(smooth.warnings.contains { $0.contains("duplicate key") })

        let invalid = RankFingerprintAnalyzer.analyze(
            rankComponentID: "rank:invalid-parameters",
            rankLabel: "Invalid parameters",
            observations: Array(observations.prefix(12)),
            parameters: RankFingerprintParameters(
                minimumObservations: 2,
                minimumSegmentObservations: 0,
                maximumTransitions: -1,
                maximumAdjacentGapSemitones: 0,
                minimumBICImprovement: -.infinity,
                significanceLevel: 1,
                permutationCount: 0,
                randomSeed: .max
            )
        )
        XCTAssertEqual(invalid.applicability, .limited)
        XCTAssertTrue(invalid.transitions.isEmpty)
        XCTAssertTrue(invalid.warnings.contains { $0.contains("parameters are invalid") })
    }

    func testVAO022ExportsRankFingerprintWithoutUnreleasedEmpiricalModel() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-timbre-vao-022-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appendingPathComponent("Source.orgrec", isDirectory: true)
        let archive = root.appendingPathComponent("Timbre-0.2.2.vao")
        let observations = (36..<60).map { midi in
            makeTimbreObservation(
                midi: midi,
                centroid: midi < 48 ? 1.25 : 3.9,
                slope: midi < 48 ? -20 : -4
            )
        }
        var project = DemoProjectFactory.make()
        project.timbreAnalyses = [TimbreAnalysisEngine.report(
            mode: .familySuggestion,
            rankComponentID: project.roadmap[0].component.id,
            rankLabel: "Principal 8′",
            observations: observations,
            fingerprintParameters: RankFingerprintParameters(permutationCount: 19, randomSeed: 7)
        )]
        try await ProjectStore().createPackage(at: package, project: project)
        try await VAOPackageBuilder().build(project: project, packageURL: package, destinationURL: archive)
        let manifest = try VAOPackageValidator.manifest(packageURL: archive)
        XCTAssertEqual(manifest.formatVersion, "0.2.2")
        let capabilities = Set(manifest.profiles.flatMap(\.requiredCapabilities))
        XCTAssertFalse(capabilities.contains(VAOContract.empiricalTimbreClassificationCapability))
        XCTAssertTrue(capabilities.contains(VAOContract.pitchDependentRankFingerprintCapability))
        XCTAssertFalse(manifest.assets.contains { $0.roles.contains(VAOContract.machineLearningModelRole) })
        XCTAssertFalse(manifest.analyses.contains {
            $0.analysisType == VAOContract.vaoVocabulary + "analysis/empirical-hierarchical-timbre-classification"
        })
        XCTAssertTrue(manifest.analyses.contains {
            $0.analysisType == VAOContract.vaoVocabulary + "analysis/pitch-dependent-rank-fingerprint"
        })
        let validation = try VAOPackageValidator.validate(packageURL: archive)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", FileManager.default.currentDirectoryPath + "/Tools/vaom.py", "validate", archive.path, "--json"]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        XCTAssertEqual(process.terminationStatus, 0, text)
    }

    func testVAOExportsDesignatedTimbreAnalysisAsInferred() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-timbre-vao-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let package = root.appendingPathComponent("Source.orgrec", isDirectory: true)
        let archive = root.appendingPathComponent("Timbre.vao")
        var project = DemoProjectFactory.make()
        project.timbreAnalyses = [TimbreAnalysisEngine.report(
            mode: .familySuggestion,
            rankComponentID: "rank:mixture",
            rankLabel: "Mixture IV",
            observations: [],
            scopeApplicability: .notApplicable,
            scopeWarnings: ["Compound stop scope gate"]
        )]
        try await ProjectStore().createPackage(at: package, project: project)
        try await VAOPackageBuilder().build(project: project, packageURL: package, destinationURL: archive)
        let manifest = try VAOPackageValidator.manifest(packageURL: archive)
        let analysis = try XCTUnwrap(manifest.analyses.first {
            $0.analysisType == VAOContract.vaoVocabulary + "analysis/pipe-timbre-characterization"
        })
        XCTAssertEqual(analysis.version, TimbreMethodology.contractVersion)
        XCTAssertEqual(analysis.observations.first?.status, "inferred")
        XCTAssertEqual(analysis.observations.first?.applicability, "notApplicable")
        XCTAssertTrue(manifest.paradata.allSatisfy {
            $0.software.version == OrgRecSoftware.version
                && $0.software.build == OrgRecSoftware.build
                && $0.parameters[VAOContract.vaoNamespace + "softwareVersion"] == .string(OrgRecSoftware.version)
        })
        if case .object(let software)? = manifest.extensions?[VAOContract.vaoNamespace + "producerSoftware"] {
            XCTAssertEqual(software["version"], .string(OrgRecSoftware.version))
            XCTAssertEqual(software["build"], .string(OrgRecSoftware.build))
        } else {
            XCTFail("VAO producer software metadata is missing")
        }
        let validation = try VAOPackageValidator.validate(packageURL: archive)
        XCTAssertTrue(validation.isValid, validation.errors.joined(separator: "; "))
    }

    func testNativeVAOValidatorAcceptsAcousticRoomAndReportsMetadataOnlyRendering() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao-acoustics-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Fixtures/VAO/valid/minimal-acoustic-room", isDirectory: true)
        let manifest = try OrgRecCoding.decoder.decode(
            VAOManifest.self,
            from: Data(contentsOf: fixture.appendingPathComponent(VAOContract.manifestFilename))
        )
        XCTAssertEqual(manifest.primaryEntityId, "urn:vao:fixture:acoustic-room:building")
        XCTAssertTrue(manifest.focusEntityIds.contains(manifest.primaryEntityId))
        XCTAssertNotNil(manifest.acoustics)
        XCTAssertTrue(manifest.profiles.contains { $0.id == VAOContract.acousticsProfile })

        let archive = root.appendingPathComponent("AcousticRoom.vao")
        var entries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAOContract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAOContract.manifestFilename, fileURL: fixture.appendingPathComponent(VAOContract.manifestFilename)),
        ]
        entries.append(contentsOf: manifest.assets.sorted { $0.path < $1.path }.map {
            VAOArchiveEntrySource(path: $0.path, fileURL: fixture.appendingPathComponent($0.path))
        })
        try VAOArchiveWriter.write(entries: entries, to: archive)
        let report = try VAOPackageValidator.validate(packageURL: archive)
        XCTAssertTrue(report.isValid, report.errors.joined(separator: "; "))
        let acousticReports = VAOPackageReader.capabilityReports(for: manifest).filter {
            VAOContract.acousticsCapabilities.contains($0.capability)
        }
        XCTAssertFalse(acousticReports.isEmpty)
        XCTAssertTrue(acousticReports.allSatisfy { $0.validationSupported && $0.processing == .metadataOnly })

        var duplicateManifest = manifest
        var duplicateAcoustics = try XCTUnwrap(duplicateManifest.acoustics)
        var duplicateFrames = try XCTUnwrap(duplicateAcoustics["coordinateFrames"]?.arrayValue)
        duplicateFrames.append(try XCTUnwrap(duplicateFrames.first))
        duplicateAcoustics["coordinateFrames"] = .array(duplicateFrames)
        duplicateManifest.acoustics = duplicateAcoustics
        let duplicateArchive = root.appendingPathComponent("DuplicateAcousticID.vao")
        var duplicateEntries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAOContract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAOContract.manifestFilename, data: try OrgRecCoding.encoder.encode(duplicateManifest)),
        ]
        duplicateEntries.append(contentsOf: duplicateManifest.assets.sorted { $0.path < $1.path }.map {
            VAOArchiveEntrySource(path: $0.path, fileURL: fixture.appendingPathComponent($0.path))
        })
        try VAOArchiveWriter.write(entries: duplicateEntries, to: duplicateArchive)
        let duplicateReport = try VAOPackageValidator.validate(packageURL: duplicateArchive)
        XCTAssertFalse(duplicateReport.isValid)
        XCTAssertTrue(duplicateReport.errors.contains { $0.contains("duplicate resource identifiers") })

        var misplacedManifest = manifest
        let acousticProfileIndex = try XCTUnwrap(misplacedManifest.profiles.firstIndex { $0.id == VAOContract.acousticsProfile })
        let coreProfileIndex = try XCTUnwrap(misplacedManifest.profiles.firstIndex { $0.id == VAOContract.coreProfile })
        let misplacedCapabilities = misplacedManifest.profiles[acousticProfileIndex].requiredCapabilities
        misplacedManifest.profiles[acousticProfileIndex].requiredCapabilities = []
        misplacedManifest.profiles[coreProfileIndex].requiredCapabilities.append(contentsOf: misplacedCapabilities)
        let misplacedArchive = root.appendingPathComponent("MisplacedAcousticCapabilities.vao")
        var misplacedEntries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAOContract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAOContract.manifestFilename, data: try OrgRecCoding.encoder.encode(misplacedManifest)),
        ]
        misplacedEntries.append(contentsOf: misplacedManifest.assets.sorted { $0.path < $1.path }.map {
            VAOArchiveEntrySource(path: $0.path, fileURL: fixture.appendingPathComponent($0.path))
        })
        try VAOArchiveWriter.write(entries: misplacedEntries, to: misplacedArchive)
        let misplacedReport = try VAOPackageValidator.validate(packageURL: misplacedArchive)
        XCTAssertFalse(misplacedReport.isValid)
        XCTAssertTrue(misplacedReport.errors.contains { $0.contains("standard acoustic capability") })

        var incompleteTrackedSources = manifest
        let trackedProfileIndex = try XCTUnwrap(incompleteTrackedSources.profiles.firstIndex { $0.id == VAOContract.acousticsProfile })
        incompleteTrackedSources.profiles[trackedProfileIndex].requiredCapabilities.append(VAOContract.trackedSourcesCapability)
        let trackedArchive = root.appendingPathComponent("IncompleteTrackedSources.vao")
        var trackedEntries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAOContract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAOContract.manifestFilename, data: try OrgRecCoding.encoder.encode(incompleteTrackedSources)),
        ]
        trackedEntries.append(contentsOf: incompleteTrackedSources.assets.sorted { $0.path < $1.path }.map {
            VAOArchiveEntrySource(path: $0.path, fileURL: fixture.appendingPathComponent($0.path))
        })
        try VAOArchiveWriter.write(entries: trackedEntries, to: trackedArchive)
        let trackedReport = try VAOPackageValidator.validate(packageURL: trackedArchive)
        XCTAssertFalse(trackedReport.isValid)
        XCTAssertTrue(trackedReport.errors.contains { $0.contains("source-tracking feature") })
    }

    private func experientialFixtureManifest() throws -> VAOManifest {
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Fixtures/VAO/valid/minimal-experiential-instrument/vao-manifest.json")
        return try OrgRecCoding.decoder.decode(VAOManifest.self, from: Data(contentsOf: fixture))
    }

    private func makeTimbreObservation(
        midi: Int,
        centroid: Double,
        slope: Double,
        candidates: [TimbreFamilyCandidate] = [],
        applicability: TimbreAnalysisApplicability = .applicable
    ) -> PipeTimbreObservation {
        PipeTimbreObservation(
            takeID: UUID(),
            roadmapItemID: UUID(),
            midiNote: midi,
            noteName: "MIDI \(midi)",
            sourceAudioSHA256: String(repeating: "a", count: 64),
            sourceAnalysisRunID: UUID(),
            referenceChannel: 0,
            segmentStartSeconds: 1,
            segmentEndSeconds: 4,
            resampledRateHz: 48_000,
            fftSize: 16_384,
            averagedFrameCount: 12,
            fundamentalFrequencyHz: midiFrequency(midi),
            fundamentalSource: .measuredConsensus,
            partials: [TimbrePartialMeasurement(harmonicNumber: 1, frequencyHz: midiFrequency(midi), relativeLevelDB: 0, energyFraction: 1, localSignalToNoiseDB: 40)],
            normalizedSpectralCentroid: centroid,
            weightedAverageSlopeDBPerOctave: slope,
            evenToOddEnergyRatioDB: -12,
            firstFivePrototype: .dominantFundamental,
            familyCandidates: candidates,
            applicability: applicability,
            warnings: []
        )
    }

    private func writeFixtureArchive(manifest: VAOManifest, to archive: URL) throws {
        try writeFixtureArchive(manifestData: OrgRecCoding.encoder.encode(manifest), manifest: manifest, to: archive)
    }

    private func writeFixtureArchive(manifestData: Data, manifest: VAOManifest, to archive: URL) throws {
        let fixture = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Fixtures/VAO/valid/minimal-experiential-instrument", isDirectory: true)
        var entries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAOContract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAOContract.manifestFilename, data: manifestData),
        ]
        entries.append(contentsOf: manifest.assets.sorted { $0.path < $1.path }.map {
            VAOArchiveEntrySource(path: $0.path, fileURL: fixture.appendingPathComponent($0.path))
        })
        try VAOArchiveWriter.write(entries: entries, to: archive)
    }

    func testBoundaryPhasesAndChronologyRemainExplicit() {
        let valid: [AnalysisMarkerKind: Double] = [
            .onset: 0.4,
            .sustainStart: 0.7,
            .keyUp: 2.0,
            .soundOffset: 2.25,
            .tailEnd: 2.9,
        ]
        XCTAssertTrue(AnalysisBoundarySequence.isChronological(valid))
        let phases = AnalysisBoundarySequence.phases(valid)
        XCTAssertEqual(phases.map(\.phase), [.attack, .sustain, .release, .tail])
        XCTAssertEqual(phases.first?.startSeconds, 0.4)
        XCTAssertEqual(phases.last?.endSeconds, 2.9)

        var invalid = valid
        invalid[.soundOffset] = 1.8
        XCTAssertFalse(AnalysisBoundarySequence.isChronological(invalid))
    }
}
