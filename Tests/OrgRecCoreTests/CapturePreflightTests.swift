import Foundation
import XCTest
@testable import OrgRecCore

final class CapturePreflightTests: XCTestCase {
    func testIndependentAssignedChannelsPassTheOrganSignalPathProtocol() {
        let rate = 1_000.0
        let first = rehearsalChannel(sampleRate: rate, signalFrequency: 23, phase: 0.2)
        let second = rehearsalChannel(sampleRate: rate, signalFrequency: 31, phase: 0.7)

        let report = CapturePreflightAnalyzer.evaluate(
            samples: [first, second],
            context: context(
                sampleRate: rate,
                assignments: [
                    CapturePreflightChannelAssignment(channelNumber: 1, role: "Main left", isRequired: true),
                    CapturePreflightChannelAssignment(channelNumber: 2, role: "Main right", isRequired: true),
                ]
            )
        )

        XCTAssertEqual(report.verdict, .passed)
        XCTAssertTrue(report.findings.isEmpty)
        XCTAssertEqual(report.channels.count, 2)
        XCTAssertTrue(report.channels.allSatisfy { $0.signalToNoiseDB >= 24 })
        XCTAssertTrue(report.channels.allSatisfy { $0.headroomDB >= 10 })
    }

    func testDigitallyDuplicatedMicrophoneRoutesAreBlocking() {
        let rate = 1_000.0
        let channel = rehearsalChannel(sampleRate: rate, signalFrequency: 29, phase: 0.4)
        let report = CapturePreflightAnalyzer.evaluate(
            samples: [channel, channel],
            context: context(
                sampleRate: rate,
                assignments: [
                    CapturePreflightChannelAssignment(channelNumber: 1, role: "Main left", isRequired: true),
                    CapturePreflightChannelAssignment(channelNumber: 2, role: "Main right", isRequired: true),
                ]
            )
        )

        XCTAssertEqual(report.verdict, .failed)
        XCTAssertTrue(report.findings.contains {
            $0.kind == .duplicatedRouting && $0.severity == .blocker && $0.channelNumbers == [1, 2]
        })
    }

    func testDigitallyInvertedMicrophoneRoutesAreBlocking() {
        let rate = 1_000.0
        let channel = rehearsalChannel(sampleRate: rate, signalFrequency: 19, phase: 0.1)
        let report = CapturePreflightAnalyzer.evaluate(
            samples: [channel, channel.map(-)],
            context: context(
                sampleRate: rate,
                assignments: [
                    CapturePreflightChannelAssignment(channelNumber: 1, role: "Left", isRequired: true),
                    CapturePreflightChannelAssignment(channelNumber: 2, role: "Right", isRequired: true),
                ]
            )
        )

        XCTAssertEqual(report.verdict, .failed)
        XCTAssertTrue(report.findings.contains { $0.kind == .invertedRouting && $0.severity == .blocker })
    }

    func testUnusedInterfaceInputDoesNotFailTheDocumentedSetup() {
        let rate = 1_000.0
        let assigned = rehearsalChannel(sampleRate: rate, signalFrequency: 27, phase: 0.3)
        let unused = [Float](repeating: 0, count: assigned.count)
        let report = CapturePreflightAnalyzer.evaluate(
            samples: [assigned, unused],
            context: context(
                sampleRate: rate,
                assignments: [
                    CapturePreflightChannelAssignment(channelNumber: 1, role: "Main", isRequired: true),
                    CapturePreflightChannelAssignment(channelNumber: 2, role: "Input 2", isRequired: false),
                ]
            )
        )

        XCTAssertEqual(report.verdict, .passed)
        XCTAssertFalse(report.findings.contains { $0.channelNumbers.contains(2) })
        XCTAssertFalse(report.channels[1].isRequired)
    }

    func testDuplicateDocumentedAssignmentsFailWithoutTrapping() {
        let rate = 1_000.0
        let channel = rehearsalChannel(sampleRate: rate, signalFrequency: 27, phase: 0.3)
        let report = CapturePreflightAnalyzer.evaluate(
            samples: [channel],
            context: context(
                sampleRate: rate,
                assignments: [
                    CapturePreflightChannelAssignment(channelNumber: 1, role: "First", isRequired: true),
                    CapturePreflightChannelAssignment(channelNumber: 1, role: "Duplicate", isRequired: true),
                ]
            )
        )

        XCTAssertEqual(report.verdict, .failed)
        XCTAssertTrue(report.findings.contains {
            $0.kind == .channelUnavailable && $0.title == "Documented channel assignments are invalid"
        })
    }

    func testSilentAssignedChannelAndShortProtocolAreBlocking() {
        let rate = 1_000.0
        let silence = [Float](repeating: 0, count: 6_000)
        let report = CapturePreflightAnalyzer.evaluate(
            samples: [silence],
            context: context(
                sampleRate: rate,
                frameCount: 6_000,
                assignments: [CapturePreflightChannelAssignment(channelNumber: 1, role: "Room", isRequired: true)]
            )
        )

        XCTAssertEqual(report.verdict, .failed)
        XCTAssertTrue(report.findings.contains { $0.kind == .duration })
        XCTAssertTrue(report.findings.contains { $0.kind == .silence && $0.channelNumbers == [1] })
    }

    func testCaptureFaultCannotBeHiddenByHealthyAcousticalMetrics() {
        let rate = 1_000.0
        let channel = rehearsalChannel(sampleRate: rate, signalFrequency: 23, phase: 0.2)
        let diagnostics = CaptureDiagnostics(
            writtenFrames: 12_000,
            droppedBuffers: 1,
            discontinuityCount: 1,
            faults: [CaptureFault(kind: .queueOverrun, message: "Test queue overrun")]
        )
        let report = CapturePreflightAnalyzer.evaluate(
            samples: [channel],
            context: context(
                sampleRate: rate,
                assignments: [CapturePreflightChannelAssignment(channelNumber: 1, role: "Main", isRequired: true)],
                diagnostics: diagnostics
            )
        )

        XCTAssertEqual(report.verdict, .failed)
        XCTAssertTrue(report.findings.contains { $0.kind == .captureIntegrity })
    }

    func testReportContextMatchingInvalidatesChangedSetupOrDeviceConfiguration() {
        let rate = 1_000.0
        let report = CapturePreflightAnalyzer.evaluate(
            samples: [rehearsalChannel(sampleRate: rate, signalFrequency: 23, phase: 0.2)],
            context: context(
                sampleRate: rate,
                assignments: [CapturePreflightChannelAssignment(channelNumber: 1, role: "Main", isRequired: true)]
            )
        )

        XCTAssertTrue(report.matches(
            sessionID: report.sessionID,
            setupID: report.setupID,
            setupRevision: report.setupRevision,
            deviceUID: report.deviceSnapshot.uid,
            sampleRate: rate,
            inputChannels: 2
        ))
        XCTAssertFalse(report.matches(
            sessionID: report.sessionID,
            setupID: report.setupID,
            setupRevision: report.setupRevision + 1,
            deviceUID: report.deviceSnapshot.uid,
            sampleRate: rate,
            inputChannels: 2
        ))
        XCTAssertFalse(report.matches(
            sessionID: report.sessionID,
            setupID: report.setupID,
            setupRevision: report.setupRevision,
            deviceUID: "another-interface",
            sampleRate: rate,
            inputChannels: 2
        ))
    }

    func testConsistencyAuditDetectsChangedRehearsalEvidence() async throws {
        let package = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-preflight-integrity-\(UUID().uuidString).orgrec", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: package) }
        var project = DemoProjectFactory.make()
        let setup = try XCTUnwrap(project.setups.first)
        let session = RecordingSession(sessionCode: "PREFLIGHT", operatorName: "Operator")
        let bytes = Data("immutable preflight evidence".utf8)
        let relativePath = "Audio/Calibration/signal-path-integrity.wav"
        var report = CapturePreflightAnalyzer.evaluate(
            samples: [rehearsalChannel(sampleRate: 1_000, signalFrequency: 23, phase: 0.2)],
            context: context(
                sampleRate: 1_000,
                assignments: [CapturePreflightChannelAssignment(channelNumber: 1, role: "Main", isRequired: true)]
            )
        )
        report.sessionID = session.id
        report.setupID = setup.id
        report.setupRevision = setup.revision
        report.relativeAudioPath = relativePath
        report.fileSize = Int64(bytes.count)
        report.sha256 = bytes.sha256Hex
        var storedSession = session
        storedSession.capturePreflightReports = [report]
        project.recordingSessions = [storedSession]

        try await ProjectStore().createPackage(at: package, project: project)
        let audio = package.appendingPathComponent(relativePath)
        try bytes.write(to: audio)
        let initial = ProjectConsistencyAuditor.audit(project: project, packageURL: package)
        XCTAssertFalse(initial.issues.contains { $0.id.hasPrefix("preflight.\(report.id)") })

        try Data("changed rehearsal evidence".utf8).write(to: audio)
        let tampered = ProjectConsistencyAuditor.audit(project: project, packageURL: package)
        XCTAssertTrue(tampered.issues.contains {
            ($0.id == "preflight.\(report.id).size" || $0.id == "preflight.\(report.id).hash")
                && $0.severity == .blocker
        })
    }

    private func context(
        sampleRate: Double,
        frameCount: Int64 = 12_000,
        assignments: [CapturePreflightChannelAssignment],
        diagnostics: CaptureDiagnostics? = CaptureDiagnostics(writtenFrames: 12_000)
    ) -> CapturePreflightAnalysisContext {
        CapturePreflightAnalysisContext(
            sessionID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            setupID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            setupRevision: 3,
            deviceSnapshot: AudioDeviceSnapshot(
                uid: "test-interface",
                name: "Test Interface",
                manufacturer: "OrgRec Tests",
                transport: "Virtual",
                inputChannels: 2,
                sampleRate: sampleRate,
                bufferFrames: 128,
                deviceLatencyFrames: 4,
                safetyOffsetFrames: 2,
                estimatedInputLatencyMilliseconds: 2,
                lowLatencyMode: "Balanced"
            ),
            relativeAudioPath: "Audio/Calibration/signal-path-test.wav",
            fileSize: 144_000,
            sha256: String(repeating: "a", count: 64),
            sampleRate: sampleRate,
            frameCount: frameCount,
            assignments: assignments,
            captureDiagnostics: diagnostics,
            bwfMetadata: nil,
            bwfFinalizationSucceeded: true
        )
    }

    private func rehearsalChannel(sampleRate: Double, signalFrequency: Double, phase: Double) -> [Float] {
        let count = Int(sampleRate * 12)
        let angularFactor = 2 * Double.pi
        var samples: [Float] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            let time = Double(index) / sampleRate
            let quietNoise = 0.000_35 * sin(angularFactor * 7 * time + phase)
            if time < 5 {
                samples.append(Float(quietNoise))
                continue
            }
            let fundamental = 0.18 * sin(angularFactor * signalFrequency * time + phase)
            let second = 0.045 * sin(angularFactor * signalFrequency * 2 * time + phase * 0.7)
            let third = 0.018 * sin(angularFactor * signalFrequency * 3 * time + phase * 1.3)
            samples.append(Float(quietNoise + fundamental + second + third))
        }
        return samples
    }
}
