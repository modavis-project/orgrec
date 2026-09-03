import AVFAudio
import XCTest
@testable import OrgRecCore

final class ScienceIntegrityTests: XCTestCase {
    private func component(
        id: String = UUID().uuidString,
        label: String,
        kind: String = "pipe_position",
        footHeight: String? = "8′",
        midiNote: Int? = 60,
        sourceDetails: [String: String]? = nil
    ) -> OrganComponent {
        OrganComponent(
            id: id,
            kind: kind,
            label: label,
            division: "Great",
            footHeight: footHeight,
            noteName: midiNote == nil ? nil : "C4",
            midiNote: midiNote,
            locator: ComponentLocator(
                id: id,
                organMDVSID: "MDVS:ORGN:SCIENCE",
                snapshotSHA256: String(repeating: "a", count: 64),
                kind: kind,
                label: label,
                trust: .functionalPosition
            ),
            sourceDetails: sourceDetails,
            referencePitchHz: 440
        )
    }

    private func item(
        component: OrganComponent,
        coverageKind: RoadmapCoverageKind? = .isolatedStop,
        activationRoutes: [PhysicalActivationRoute]? = nil,
        soundingTargetDefinition: SoundingTargetDefinition? = nil,
        effectAnalysisProtocol: NonPitchedEffectAnalysisProtocol? = nil
    ) -> RoadmapItem {
        RoadmapItem(
            component: component,
            technique: .closePair,
            recipeID: UUID(),
            coverageKind: coverageKind,
            activationRoutes: activationRoutes,
            soundingTargetDefinition: soundingTargetDefinition,
            effectAnalysisProtocol: effectAnalysisProtocol
        )
    }

    func testOrganFootageParsesSingleDocumentedValues() throws {
        let cases: [(String, Double)] = [
            ("16′", 16), ("8 ft", 8), ("5⅓′", 16.0 / 3), ("4'", 4),
            ("2 2/3′", 8.0 / 3), ("2′", 2), ("1⅗′", 1.6), ("1⅓′", 4.0 / 3),
        ]
        for (raw, expected) in cases {
            XCTAssertEqual(try OrganFootage(parsing: raw).feet, expected, accuracy: 0.000_001, raw)
        }
    }

    func testOrganFootageRejectsCompoundAndInvalidDescriptions() {
        for raw in ["8′ + 4′", "8/4", "8–4"] {
            XCTAssertThrowsError(try OrganFootage(parsing: raw), raw) { error in
                XCTAssertEqual(error as? OrganFootage.ParseError, .compound)
            }
        }
        for raw in ["Mixture IV", "not a footage", "0′"] {
            XCTAssertThrowsError(try OrganFootage(parsing: raw), raw)
        }
        XCTAssertNil(OrganFootage.nominalFrequency(keyMidi: 60, footHeight: "8′ + 4′", referencePitchHz: 440))
        XCTAssertNil(OrganFootage.nominalFrequency(keyMidi: 60, footHeight: "Mixture IV", referencePitchHz: 440))
    }

    func testNominalFootageFrequencyAndDemoExpectationsAreOctaveCorrect() throws {
        let c4AtUnison = try XCTUnwrap(OrganFootage.nominalFrequency(keyMidi: 60, footHeight: "8′", referencePitchHz: 440))
        XCTAssertEqual(try XCTUnwrap(OrganFootage.nominalFrequency(keyMidi: 60, footHeight: "4′", referencePitchHz: 440)), c4AtUnison * 2, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(OrganFootage.nominalFrequency(keyMidi: 60, footHeight: "16′", referencePitchHz: 440)), c4AtUnison / 2, accuracy: 0.000_001)

        let demo = RoadmapEngine.demoComponents(
            organMDVSID: "MDVS:ORGN:SCIENCE",
            snapshotSHA256: String(repeating: "b", count: 64),
            noteRange: 60...60
        )
        let octave = try XCTUnwrap(demo.first { $0.label == "Octave 4′" })
        let subbass = try XCTUnwrap(demo.first { $0.label == "Subbass 16′" })
        let mixture = try XCTUnwrap(demo.first { $0.label == "Mixture IV" })
        XCTAssertEqual(try XCTUnwrap(octave.expectedFrequencyHz), c4AtUnison * 2, accuracy: 0.000_001)
        XCTAssertEqual(try XCTUnwrap(subbass.expectedFrequencyHz), c4AtUnison / 2, accuracy: 0.000_001)
        XCTAssertNil(mixture.expectedFrequencyHz)
    }

    func testNavigatorDerivedExpectedFrequencyUsesFootageAndRejectsCompoundFootage() throws {
        let object: [String: Any] = [
            "components": [
                ["id": "octave", "kind": "pipe_position", "label": "Octave 4′", "division": "Great", "midiNote": 60, "footHeight": "4′"],
                ["id": "mixture", "kind": "pipe_position", "label": "Mixture", "division": "Great", "midiNote": 60, "footHeight": "8′ + 4′"],
            ],
        ]
        let organ = NavigatorOrganSummary(mdvsID: "MDVS:ORGN:SCIENCE", title: "Science")
        let components = NavigatorClient.extractComponents(
            from: object,
            organ: organ,
            snapshotSHA256: String(repeating: "c", count: 64),
            referencePitchHz: 440
        )
        let unison = try XCTUnwrap(OrganFootage.nominalFrequency(keyMidi: 60, footHeight: "8′", referencePitchHz: 440))
        XCTAssertEqual(try XCTUnwrap(components.first { $0.id == "octave" }?.expectedFrequencyHz), unison * 2, accuracy: 0.000_001)
        XCTAssertNil(components.first { $0.id == "mixture" }?.expectedFrequencyHz)
    }

    func testRoadmapPitchApplicabilityIsConservative() {
        XCTAssertEqual(item(component: component(label: "Principal 8′")).inferredPitchApplicability, .monophonic)
        XCTAssertEqual(item(component: component(label: "Mixture IV")).inferredPitchApplicability, .polyphonic)

        let principal = component(label: "Principal 8′")
        let route = PhysicalActivationRoute(
            id: "multi-pipe",
            component: principal,
            registrationID: UUID(),
            physicalPipeComponentIDs: ["pipe-a", "pipe-b"],
            evidence: .explicitSharedPipe,
            evidenceDescription: "Two simultaneous emitters"
        )
        XCTAssertEqual(item(component: principal, activationRoutes: [route]).inferredPitchApplicability, .polyphonic)

        let definition = SoundingTargetDefinition(
            family: .repeatingEffect,
            temporalBehavior: .repeating,
            triggerMode: .stopTab
        )
        let effectProtocol = NonPitchedEffectAnalysisProtocol(
            sourceComponentID: "effect",
            temporalBehavior: .repeating
        )
        XCTAssertEqual(
            item(component: component(label: "Nightingale", midiNote: 60), soundingTargetDefinition: definition, effectAnalysisProtocol: effectProtocol).inferredPitchApplicability,
            .nonPitched
        )
    }

    func testBWFEmbedsCodingHistoryAndUsesActualChunkSize() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-bwf-science-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("history.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32))
            buffer.frameLength = 32
            let samples = try XCTUnwrap(buffer.floatChannelData?[0])
            for index in 0..<32 { samples[index] = 0 }
            try file.write(from: buffer)
        }
        let originalAudioPayload = try XCTUnwrap(
            riffChunks(in: Data(contentsOf: url)).first { $0.id == "data" }?.payload
        )

        let history = "A=PCM,F=48000,W=24,M=mono,T=OrgRec science!"
        let metadata = BWFMetadata(
            description: "Science vector",
            originatorReference: "ORGREC-SCIENCE",
            originationDate: "2026-08-30",
            originationTime: "12:34:56",
            timeReferenceSamples: 0x0123_4567_89ab_cdef,
            codingHistory: history
        )
        let result = try BWFMetadataWriter.finalize(audioURL: url, metadata: metadata)
        XCTAssertTrue(result.embedded)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data[0..<4], encoding: .ascii), "RIFF")
        XCTAssertEqual(Int(littleEndianUInt32(data, at: 4)) + 8, data.count)
        let chunks = riffChunks(in: data)
        let bext = try XCTUnwrap(chunks.first { $0.id == "bext" })
        XCTAssertGreaterThan(bext.payload.count, 602)
        XCTAssertEqual(littleEndianUInt16(bext.payload, at: 346), 2)
        XCTAssertEqual(littleEndianUInt64(bext.payload, at: 338), metadata.timeReferenceSamples)
        XCTAssertEqual(String(data: Data(bext.payload.dropFirst(602).dropLast(2)), encoding: .ascii), history)
        XCTAssertEqual(Array(bext.payload.suffix(2)), [0x0d, 0x0a])
        XCTAssertEqual(bext.declaredSize, 602 + history.utf8.count + 2)
        XCTAssertFalse(bext.declaredSize.isMultiple(of: 2))
        XCTAssertNotNil(chunks.first { $0.id == "fmt " })
        XCTAssertEqual(try XCTUnwrap(chunks.first { $0.id == "data" }?.payload), originalAudioPayload)
    }

    func testIntegratedRMSAndSilenceCountsAreCallbackPartitionInvariant() throws {
        let samples = Array(repeating: Float(0.5), count: 64) + Array(repeating: Float(0), count: 64)
        let oneBuffer = try writerDiagnostics(chunks: [samples])
        let manyBuffers = try writerDiagnostics(chunks: [
            Array(samples[0..<17]), Array(samples[17..<64]), Array(samples[64..<91]), Array(samples[91..<128]),
        ])
        let expectedRMS = 20 * log10(sqrt(0.125))
        XCTAssertEqual(oneBuffer.channels[0].rmsDBFS, expectedRMS, accuracy: 0.000_001)
        XCTAssertEqual(manyBuffers.channels[0].rmsDBFS, expectedRMS, accuracy: 0.000_001)
        XCTAssertEqual(oneBuffer.channels[0].rmsDBFS, manyBuffers.channels[0].rmsDBFS, accuracy: 0.000_001)
        XCTAssertEqual(oneBuffer.channels[0].silentFrames, 64)
        XCTAssertEqual(manyBuffers.channels[0].silentFrames, 64)
        XCTAssertEqual(oneBuffer.writerContract, "orgrec.bounded-realtime-writer/v2")
    }

    private func writerDiagnostics(chunks: [[Float]]) throws -> CaptureDiagnostics {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-rms-science-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("capture.wav")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let writer = try QueuedAudioWriter(
            audioURL: url,
            inputFormat: format,
            bufferCapacity: AVAudioFrameCount(chunks.map(\.count).max() ?? 1),
            poolSize: max(2, chunks.count + 1),
            channelRoles: ["Reference"],
            bwfMetadata: BWFMetadata(
                description: "RMS vector",
                originatorReference: "ORGREC-RMS",
                originationDate: "2026-08-30",
                originationTime: "12:00:00",
                codingHistory: "A=PCM,F=48000,W=24,M=mono"
            )
        )
        var sampleTime: AVAudioFramePosition = 0
        for chunk in chunks {
            let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(chunk.count)))
            buffer.frameLength = AVAudioFrameCount(chunk.count)
            let destination = try XCTUnwrap(buffer.floatChannelData?[0])
            for index in chunk.indices { destination[index] = chunk[index] }
            writer.enqueue(buffer, time: AVAudioTime(sampleTime: sampleTime, atRate: format.sampleRate))
            sampleTime += AVAudioFramePosition(chunk.count)
        }
        XCTAssertEqual(writer.currentDiagnostics().receivedBuffers, Int64(chunks.count))
        return writer.finish().0
    }

    private func riffChunks(in data: Data) -> [(id: String, declaredSize: Int, payload: Data)] {
        guard data.count >= 12 else { return [] }
        var offset = 12
        var result: [(String, Int, Data)] = []
        while offset + 8 <= data.count {
            let id = String(data: data[offset..<(offset + 4)], encoding: .ascii) ?? ""
            let size = Int(littleEndianUInt32(data, at: offset + 4))
            let payloadStart = offset + 8, payloadEnd = payloadStart + size
            guard payloadEnd <= data.count else { break }
            result.append((id, size, Data(data[payloadStart..<payloadEnd])))
            offset = payloadEnd + (size.isMultiple(of: 2) ? 0 : 1)
        }
        return result
    }

    private func littleEndianUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private func littleEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 | UInt32(data[offset + $1]) << UInt32(8 * $1) }
    }

    private func littleEndianUInt64(_ data: Data, at offset: Int) -> UInt64 {
        (0..<8).reduce(0) { $0 | UInt64(data[offset + $1]) << UInt64(8 * $1) }
    }
}
