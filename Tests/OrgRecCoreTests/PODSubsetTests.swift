import Foundation
import XCTest
@testable import OrgRecCore

final class PODSubsetTests: XCTestCase {
    private var fixtureRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/POD/valid/synthetic-minimal", isDirectory: true)
    }

    func testSyntheticFixtureHasExactClosedInventory() throws {
        let inspection = try PODSubsetValidator.inspect(directory: fixtureRoot)
        XCTAssertTrue(inspection.isValid, inspection.errors.joined(separator: "; "))
        XCTAssertEqual(inspection.manifest?.contractVersion, PODSubsetContract.version)
        XCTAssertEqual(inspection.manifest?.source.releaseVersion, "1.5")
        XCTAssertEqual(inspection.verifiedFileCount, 1)
        XCTAssertEqual(inspection.verifiedBytes, 172)
    }

    func testImporterStagesAndRevalidatesBeforeCommit() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-pod-import-test-\(UUID().uuidString)", isDirectory: true)
        let destination = temporary.appendingPathComponent("cache/pod", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let inspection = try await PODSubsetImporter().importVerifiedSubset(from: fixtureRoot, to: destination)
        XCTAssertTrue(inspection.isValid)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("payload/records.jsonl").path
        ))
    }

    func testAlteredBytesAreRejected() throws {
        let copy = try copiedFixture()
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
        try Data("altered\n".utf8).write(to: copy.appendingPathComponent("payload/records.jsonl"), options: .atomic)
        let inspection = try PODSubsetValidator.inspect(directory: copy)
        XCTAssertFalse(inspection.isValid)
        XCTAssertTrue(inspection.errors.contains { $0.contains("mismatch") })
    }

    func testWrongReleaseAndTraversalAreRejected() throws {
        let copy = try copiedFixture()
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
        let manifestURL = copy.appendingPathComponent(PODSubsetContract.manifestFilename)
        var manifest = try OrgRecCoding.decoder.decode(PODSubsetManifest.self, from: Data(contentsOf: manifestURL))
        manifest.source.releaseVersion = "1.4"
        manifest.files[0].path = "../records.jsonl"
        try OrgRecCoding.encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        let inspection = try PODSubsetValidator.inspect(directory: copy)
        XCTAssertFalse(inspection.isValid)
        XCTAssertTrue(inspection.errors.contains { $0.contains("Release 1.5") })
        XCTAssertTrue(inspection.errors.contains { $0.contains("Unsafe") })
    }

    func testDuplicateIdentifiersAndUndeclaredFilesAreRejected() throws {
        let copy = try copiedFixture()
        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }
        let manifestURL = copy.appendingPathComponent(PODSubsetContract.manifestFilename)
        var manifest = try OrgRecCoding.decoder.decode(PODSubsetManifest.self, from: Data(contentsOf: manifestURL))
        var duplicate = manifest.files[0]
        duplicate.path = "payload/duplicate.jsonl"
        try FileManager.default.copyItem(
            at: copy.appendingPathComponent("payload/records.jsonl"),
            to: copy.appendingPathComponent(duplicate.path)
        )
        manifest.files.append(duplicate)
        manifest.selection.fileCount = 2
        manifest.selection.byteSize = 344
        try OrgRecCoding.encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        try Data("extra\n".utf8).write(to: copy.appendingPathComponent("undeclared.txt"), options: .atomic)
        let inspection = try PODSubsetValidator.inspect(directory: copy)
        XCTAssertFalse(inspection.isValid)
        XCTAssertTrue(inspection.errors.contains { $0.contains("Duplicate file identifiers") })
        XCTAssertTrue(inspection.errors.contains { $0.contains("Undeclared files") })
    }

    private func copiedFixture() throws -> URL {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-pod-fixture-\(UUID().uuidString)", isDirectory: true)
        let copy = temporary.appendingPathComponent("subset", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: fixtureRoot, to: copy)
        return copy
    }
}
