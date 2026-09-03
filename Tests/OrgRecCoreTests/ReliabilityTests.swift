import Foundation
import XCTest
@testable import OrgRecCore

final class ReliabilityTests: XCTestCase {
    func testInterruptedRecordingCannotBeConfusedWithInterruptedAnalysis() async throws {
        let package = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-interrupted-capture-\(UUID().uuidString).orgrec", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: package) }
        let originals = package.appendingPathComponent("Audio/Originals", isDirectory: true)
        try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        try Data("unfinished recording bytes".utf8).write(to: originals.appendingPathComponent("recording.wav"))
        try Data("finalized audio awaiting analysis".utf8).write(to: originals.appendingPathComponent("analysis.wav"))

        var project = DemoProjectFactory.make()
        let roadmapItem = try XCTUnwrap(project.roadmap.first)
        project.takes = [
            TakeRecord(
                roadmapItemID: roadmapItem.id,
                takeNumber: 1,
                status: .recording,
                relativeAudioPath: "Audio/Originals/recording.wav",
                sampleRate: 48_000,
                channelCount: 2
            ),
            TakeRecord(
                roadmapItemID: roadmapItem.id,
                takeNumber: 2,
                status: .analyzing,
                relativeAudioPath: "Audio/Originals/analysis.wav",
                sampleRate: 48_000,
                channelCount: 2
            ),
        ]

        let recovered = await ProjectStore().recoverInterruptedTakes(in: project, packageURL: package)

        XCTAssertEqual(recovered.takes[0].status, .failed)
        XCTAssertNotNil(recovered.takes[0].endedAt)
        XCTAssertEqual(recovered.takes[0].captureIntegrityFaults?.first?.kind, .interruptedCapture)
        XCTAssertTrue(recovered.takes[0].reviewReason?.contains("Broadcast Wave integrity is not established") == true)
        XCTAssertEqual(recovered.takes[1].status, .recovered)
        XCTAssertNil(recovered.takes[1].captureIntegrityFaults)
        XCTAssertTrue(recovered.takes[1].reviewReason?.contains("interrupted analysis") == true)
        XCTAssertEqual(recovered.roadmap.first?.state, .needsReview)
        XCTAssertTrue(ProjectConsistencyAuditor.audit(project: recovered, packageURL: package).issues.contains {
            $0.id == "take.\(recovered.takes[0].id).capture-integrity" && $0.severity == .blocker
        })
    }

    func testReferenceChannelMustMatchDocumentedPlacementForReadinessAndAudit() throws {
        var project = DemoProjectFactory.make()
        let setupIndex = try XCTUnwrap(project.setups.firstIndex { setup in
            setup.placements.contains { $0.channelNumber == 1 }
        })
        let setupID = project.setups[setupIndex].id
        let item = try XCTUnwrap(project.roadmap.first { $0.setupID == setupID })
        project.recordingSessions = [RecordingSession(sessionCode: "REFERENCE", operatorName: "Operator")]
        project.setups[setupIndex].referenceChannelNumber = 99

        let readiness = ProjectConsistencyAuditor.captureReadiness(project: project, item: item)
        XCTAssertTrue(readiness.contains {
            $0.id == "readiness.reference-channel" && $0.severity == .blocker
        })

        let audit = ProjectConsistencyAuditor.audit(project: project)
        XCTAssertTrue(audit.issues.contains {
            $0.id == "setup.\(setupID).reference-channel" && $0.severity == .blocker
        })
    }

    func testMissingLegacyReferenceChannelUsesChannelOneWhenItIsDocumented() throws {
        var project = DemoProjectFactory.make()
        let setupIndex = try XCTUnwrap(project.setups.firstIndex { setup in
            setup.placements.contains { $0.channelNumber == 1 }
        })
        let setupID = project.setups[setupIndex].id
        let item = try XCTUnwrap(project.roadmap.first { $0.setupID == setupID })
        project.recordingSessions = [RecordingSession(sessionCode: "REFERENCE", operatorName: "Operator")]
        project.setups[setupIndex].referenceChannelNumber = nil

        XCTAssertFalse(ProjectConsistencyAuditor.captureReadiness(project: project, item: item).contains {
            $0.id == "readiness.reference-channel"
        })
        XCTAssertFalse(ProjectConsistencyAuditor.audit(project: project).issues.contains {
            $0.id == "setup.\(setupID).reference-channel"
        })
    }

    func testProjectLoadRejectsDuplicateRegistrationIdentifierWithTypedError() async throws {
        var project = DemoProjectFactory.make()
        let registration = try XCTUnwrap(project.registrations.first)
        project.registrations.append(registration)

        try await assertLoadRejects(project, messageContains: "duplicate registration identifier")
    }

    func testProjectLoadRejectsDuplicateRecordingSessionIdentifierWithTypedError() async throws {
        let session = RecordingSession(sessionCode: "DUPLICATE")
        var project = DemoProjectFactory.make()
        project.recordingSessions = [session, session]

        try await assertLoadRejects(project, messageContains: "duplicate recording session identifier")
    }

    func testProjectLoadRejectsDuplicateCaptureStateIdentifierWithTypedError() async throws {
        let state = CaptureStateSnapshot(name: "DUPLICATE", source: .operatorPlanned, assignments: [])
        var project = DemoProjectFactory.make()
        project.captureStates = [state, state]

        try await assertLoadRejects(project, messageContains: "duplicate capture state identifier")
    }

    func testProjectLoadRejectsDuplicateAnalysisRunIdentifierWithTypedError() async throws {
        let roadmapItem = try XCTUnwrap(DemoProjectFactory.make().roadmap.first)
        let run = AnalysisRunRecord(
            inputSHA256: String(repeating: "a", count: 64),
            startedAt: .now,
            referenceChannel: 0,
            parameters: [:],
            pitchApplicability: .monophonic
        )
        var project = DemoProjectFactory.make()
        project.takes = [TakeRecord(
            roadmapItemID: roadmapItem.id,
            takeNumber: 1,
            relativeAudioPath: "Audio/Originals/duplicate-run.wav",
            sampleRate: 48_000,
            channelCount: 1,
            analysisRuns: [run, run]
        )]

        try await assertLoadRejects(project, messageContains: "duplicate analysis run")
    }

    func testProjectLoadRejectsRetainedAudioSymlinkEscapeWithTypedError() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-symlink-test-\(UUID().uuidString)", isDirectory: true)
        let package = root.appendingPathComponent("Project.orgrec", isDirectory: true)
        let outside = root.appendingPathComponent("outside.wav")
        defer { try? FileManager.default.removeItem(at: root) }

        let roadmapItem = try XCTUnwrap(DemoProjectFactory.make().roadmap.first)
        var project = DemoProjectFactory.make()
        project.takes = [TakeRecord(
            roadmapItemID: roadmapItem.id,
            takeNumber: 1,
            relativeAudioPath: "Audio/Originals/escape.wav",
            sampleRate: 48_000,
            channelCount: 1
        )]
        let store = ProjectStore()
        try await store.createPackage(at: package, project: project)
        try Data("outside evidence".utf8).write(to: outside)
        try FileManager.default.createSymbolicLink(
            at: package.appendingPathComponent("Audio/Originals/escape.wav"),
            withDestinationURL: outside
        )

        await assertInvalidProjectError(messageContains: "symbolic link") {
            _ = try await store.load(from: package)
        }
    }

    func testProjectLoadRejectsAnalysisArtifactEscapingThroughSymlinkedDirectory() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-analysis-symlink-test-\(UUID().uuidString)", isDirectory: true)
        let package = root.appendingPathComponent("Project.orgrec", isDirectory: true)
        let outsideDirectory = root.appendingPathComponent("outside-analysis", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let roadmapItem = try XCTUnwrap(DemoProjectFactory.make().roadmap.first)
        let run = AnalysisRunRecord(
            inputSHA256: String(repeating: "b", count: 64),
            startedAt: .now,
            referenceChannel: 0,
            parameters: [:],
            pitchApplicability: .monophonic,
            artifactRelativePaths: ["Analysis/Runs/escaped/waveform.json"]
        )
        var project = DemoProjectFactory.make()
        project.takes = [TakeRecord(
            roadmapItemID: roadmapItem.id,
            takeNumber: 1,
            relativeAudioPath: "Audio/Originals/take.wav",
            sampleRate: 48_000,
            channelCount: 1,
            analysisRuns: [run]
        )]
        let store = ProjectStore()
        try await store.createPackage(at: package, project: project)
        try FileManager.default.createDirectory(at: outsideDirectory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: package.appendingPathComponent("Analysis/Runs"),
            withDestinationURL: outsideDirectory
        )

        await assertInvalidProjectError(messageContains: "symbolic link") {
            _ = try await store.load(from: package)
        }
    }

    private func assertLoadRejects(
        _ project: OrgRecProject,
        messageContains expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let package = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-invalid-project-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: package) }
        let store = ProjectStore()
        try await store.createPackage(at: package, project: project)
        await assertInvalidProjectError(messageContains: expectedMessage, file: file, line: line) {
            _ = try await store.load(from: package)
        }
    }

    private func assertInvalidProjectError(
        messageContains expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected OrgRecError.invalidProject.", file: file, line: line)
        } catch OrgRecError.invalidProject(let message) {
            XCTAssertTrue(
                message.localizedCaseInsensitiveContains(expectedMessage),
                "Unexpected invalid-project message: \(message)",
                file: file,
                line: line
            )
        } catch {
            XCTFail("Expected OrgRecError.invalidProject, received \(error).", file: file, line: line)
        }
    }
}
