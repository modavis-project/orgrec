import Foundation
import XCTest
@testable import OrgRecApp
import OrgRecCore

final class InteractionSensorCenterTests: XCTestCase {
    func testFailedFinalizationLeavesCaptureStateAndPreservesRawEvidence() async throws {
        let package = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-sensor-finalization-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: package) }

        try await MainActor.run {
            let manager = FileManager.default
            let sensorDirectory = package.appendingPathComponent("Sensors", isDirectory: true)
            try manager.createDirectory(at: sensorDirectory, withIntermediateDirectories: true)
            let blockedDerivedDirectory = sensorDirectory.appendingPathComponent("Derived")
            try Data("not a directory".utf8).write(to: blockedDerivedDirectory)

            let configuration = InteractionSensorConfiguration(transport: .simulation)
            let center = InteractionSensorCenter()
            try center.connect(configuration: configuration, calibration: nil)
            defer { center.disconnect() }

            try center.beginCapture(
                packageURL: package,
                takeID: UUID(),
                configuration: configuration,
                calibration: nil
            )
            let rawDirectory = sensorDirectory.appendingPathComponent("Raw", isDirectory: true)
            let rawURL = try XCTUnwrap(
                manager.contentsOfDirectory(at: rawDirectory, includingPropertiesForKeys: nil).first
            )

            XCTAssertThrowsError(try center.endCapture(packageURL: package, audioStartHostNanoseconds: nil))
            XCTAssertFalse(center.isCapturingTake)
            XCTAssertNil(center.lastFinalizedDerivedData)
            XCTAssertTrue(manager.fileExists(atPath: rawURL.path), "Raw sensor evidence must survive finalization failures.")

            try manager.removeItem(at: blockedDerivedDirectory)
            try center.beginCapture(
                packageURL: package,
                takeID: UUID(),
                configuration: configuration,
                calibration: nil
            )
            XCTAssertTrue(center.isCapturingTake, "A failed finalization must not wedge subsequent captures.")
            center.cancelCapture()
            XCTAssertFalse(center.isCapturingTake)
            XCTAssertTrue(manager.fileExists(atPath: rawURL.path), "Canceling a later capture must not remove earlier raw evidence.")
        }
    }
}
