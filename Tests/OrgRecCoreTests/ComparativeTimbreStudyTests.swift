import XCTest
@testable import OrgRecCore

final class ComparativeTimbreStudyTests: XCTestCase {
    func testDocumentaryLabelRulesRecognizeAttachedFootage() throws {
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Ped Trompette4")?.family, .reed)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Ped Octave8")?.family, .diapason)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Violoncell8")?.family, .string)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.assignment(for: "Subbass16")?.family, .flute)
        XCTAssertEqual(TimbreDocumentaryLabelNormalizer.version, "orgrec-organ-stop-label-rules/3")
    }

    func testCanonicalNameRetainsLexicalIdentityButRemovesDivisionAndFootage() {
        XCTAssertEqual(ComparativeStopNameNormalizer.canonicalName("Ped. Trompette4′"), "trompette")
        XCTAssertEqual(ComparativeStopNameNormalizer.canonicalName("Hauptwerk Prästant 8'"), "prastant")
        XCTAssertEqual(ComparativeStopNameNormalizer.canonicalName("Geigenregal 8"), "geigenregal")
        XCTAssertEqual(ComparativeStopNameNormalizer.canonicalName("Voix céleste"), "voix celeste")
    }

    func testComparativeExportReusesFeaturesAndKeepsInstrumentGroupsDisjoint() throws {
        let instruments = (1...5).map { index in
            RetrievedCorpusInstrumentSummary(
                entityID: "organ-\(index)",
                instrumentName: "Organ \(index)",
                producer: "Producer \(index)",
                recordingBasis: "Single real pipe organ",
                licenseClass: "test-only",
                sourceURL: "https://example.invalid/\(index)",
                sourceDefinitionPath: "/test/organ-\(index).organ",
                sourceDefinitionSHA256: String(repeating: String(index), count: 64),
                includedRankCount: 1,
                includedPipeCount: 4
            )
        }
        let ranks = instruments.enumerated().map { offset, instrument in
            EmpiricalTimbreRankRecord(
                instrumentID: instrument.entityID,
                instrumentName: instrument.instrumentName,
                rankID: "rank-\(offset)",
                rankLabel: offset.isMultiple(of: 2) ? "Principal8" : "Flute8",
                division: "Great",
                footage: "8",
                labelAssignment: TimbreLabelAssignment(
                    family: offset.isMultiple(of: 2) ? .diapason : .flute,
                    normalizedSourceLabel: offset.isMultiple(of: 2) ? "principal 8" : "flute 8",
                    matchedRule: offset.isMultiple(of: 2) ? "diapason:principal" : "flute:flute"
                ),
                observations: (48...51).map { Self.observation(midi: $0, offset: Double(offset)) },
                sourceDefinitionSHA256: instrument.sourceDefinitionSHA256
            )
        }
        let corpus = RetrievedTimbreCorpus(
            generatedAt: Date(timeIntervalSince1970: 100),
            inventoryPath: "/test/inventory.csv",
            inventorySHA256: String(repeating: "a", count: 64),
            catalogPath: "/test/catalog.csv",
            catalogSHA256: String(repeating: "b", count: 64),
            options: RetrievedCorpusBuildOptions(),
            instruments: instruments,
            ranks: ranks
        )
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-comparative-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try OrgRecCoding.encoder.encode(corpus).write(to: temporary)

        let first = try ComparativeTimbreStudyBuilder.build(corpus: corpus, sourceCorpusURL: temporary)
        let second = try ComparativeTimbreStudyBuilder.build(corpus: corpus, sourceCorpusURL: temporary)
        XCTAssertEqual(first.contractVersion, "orgrec-comparative-stop-timbre-study/1")
        XCTAssertEqual(first.assignments, second.assignments)
        XCTAssertEqual(Set(first.assignments.map { $0.instrumentID }).count, instruments.count)
        XCTAssertEqual(Set(first.assignments.map { $0.role }), Set(ComparativeStudyRole.allCases))
        XCTAssertEqual(first.ranks.count, ranks.count)
        XCTAssertEqual(first.pipes.count, ranks.count * 4)
        XCTAssertEqual(first.featureNames, TimbreRankFeatureVectorizer.featureNames)
        XCTAssertEqual(first.parameters.normalizedCentroidDomain, [0.95, 12])
        XCTAssertEqual(first.parameters.slopeDomainDBPerOctave, [-70, 45])
        XCTAssertEqual(first.ranks.first?.featureValues, TimbreRankFeatureVectorizer.vector(observations: ranks.first!.observations))
        XCTAssertTrue(first.ranks.allSatisfy { $0.featureValues.count == first.featureNames.count })
        XCTAssertTrue(first.ranks.allSatisfy { !$0.canonicalStopName.contains("8") })
        XCTAssertEqual(first.sourceCorpusFileSHA256, try sha256(of: temporary))
        XCTAssertEqual(first.sourceCorpusFingerprint, corpus.fingerprint)
    }

    private static func observation(midi: Int, offset: Double) -> PipeTimbreObservation {
        PipeTimbreObservation(
            takeID: UUID(),
            roadmapItemID: UUID(),
            midiNote: midi,
            noteName: "MIDI \(midi)",
            sourceAudioSHA256: String(repeating: "c", count: 64),
            sourceAnalysisRunID: UUID(),
            referenceChannel: 0,
            segmentStartSeconds: 1,
            segmentEndSeconds: 3,
            resampledRateHz: 48_000,
            fftSize: 16_384,
            averagedFrameCount: 12,
            fundamentalFrequencyHz: midiFrequency(midi),
            fundamentalSource: .measuredConsensus,
            partials: (1...8).map { harmonic in
                TimbrePartialMeasurement(
                    harmonicNumber: harmonic,
                    frequencyHz: midiFrequency(midi) * Double(harmonic),
                    relativeLevelDB: -5 * Double(harmonic - 1) + offset,
                    energyFraction: 1 / Double(harmonic),
                    localSignalToNoiseDB: 30
                )
            },
            normalizedSpectralCentroid: 1.2 + offset * 0.1 + Double(midi - 48) * 0.01,
            weightedAverageSlopeDBPerOctave: -18 + offset + Double(midi - 48) * 0.1,
            evenToOddEnergyRatioDB: -12 + offset,
            firstFivePrototype: .dominantFundamental,
            familyCandidates: [],
            applicability: .applicable,
            warnings: []
        )
    }
}
