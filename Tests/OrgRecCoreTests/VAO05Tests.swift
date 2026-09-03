import Foundation
import XCTest
@testable import OrgRecCore

final class VAO05Tests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var fixtureRoot: URL {
        repositoryRoot.appendingPathComponent("Fixtures/VAO05/valid/minimal", isDirectory: true)
    }

    func testFinalFixtureDecodesAndPassesNativeValidation() throws {
        let data = try Data(contentsOf: fixtureRoot.appendingPathComponent(VAO05Contract.manifestFilename))
        XCTAssertEqual(VAOFormatDispatcher.formatVersion(in: data), VAO05Contract.formatVersion)
        let manifest = try VAOFormatDispatcher.decode05(data)
        XCTAssertEqual(manifest.schema, VAO05Contract.schemaURI)
        XCTAssertEqual(manifest.context.first, VAO05Contract.contextURI)
        XCTAssertTrue(manifest.conformsTo.contains(VAO05Contract.dynamicDeliveryProfile))
        XCTAssertEqual(VAO05Validator.validateManifest(data: data), [])
    }

    func testCarrierIdentityIsRequired() throws {
        let data = try Data(contentsOf: fixtureRoot.appendingPathComponent(VAO05Contract.carrierFilename))
        let carrier = try JSONDecoder().decode(VAO05Carrier.self, from: data)
        XCTAssertFalse(carrier.id.isEmpty)
        XCTAssertEqual(carrier.formatVersion, VAO05Contract.formatVersion)
        XCTAssertEqual(carrier.schema, VAO05Contract.carrierSchemaURI)
    }

    func testNearVersionAndDuplicateIdentifiersAreRejectedWithoutTrap() throws {
        let source = try Data(contentsOf: fixtureRoot.appendingPathComponent(VAO05Contract.manifestFilename))
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        root["formatVersion"] = "0.5"
        root["unexpected"] = true
        let nearVersion = try JSONSerialization.data(withJSONObject: root)
        let nearErrors = VAO05Validator.validateManifest(data: nearVersion)
        XCTAssertTrue(nearErrors.contains { $0.contains("formatVersion") })
        XCTAssertTrue(nearErrors.contains { $0.contains("unknown root property") })

        var manifest = try VAOFormatDispatcher.decode05(source)
        manifest.realizations.append(manifest.realizations[0])
        let duplicateErrors = VAO05Validator.validateManifest(manifest)
        XCTAssertTrue(duplicateErrors.contains { $0.contains("globally unique") })
    }

    func testMaterializationRejectsAggregateByteSizeOverflow() throws {
        let manifestData = try Data(contentsOf: fixtureRoot.appendingPathComponent(VAO05Contract.manifestFilename))
        let carrierData = try Data(contentsOf: fixtureRoot.appendingPathComponent(VAO05Contract.carrierFilename))
        var manifest = try VAOFormatDispatcher.decode05(manifestData)
        var carrier = try JSONDecoder().decode(VAO05Carrier.self, from: carrierData)

        manifest.realizations[0].byteSize = Int64.max
        manifest.assetGroups[0].totalByteSize = Int64.max

        var secondRealization = manifest.realizations[0]
        secondRealization.id = "urn:uuid:03000000-0000-4000-8000-000000000022"
        secondRealization.byteSize = 1
        manifest.realizations.append(secondRealization)
        manifest.logicalAssets[0].realizationIds.append(secondRealization.id)
        manifest.rights[0].appliesToIds.append(secondRealization.id)

        var secondGroup = manifest.assetGroups[0]
        secondGroup.id = "urn:uuid:03000000-0000-4000-8000-000000000031"
        secondGroup.selectionSetId = "overflow-fixture"
        secondGroup.realizationIds = [secondRealization.id]
        secondGroup.totalByteSize = 1
        manifest.assetGroups.append(secondGroup)

        var secondMapping = carrier.embeddedRealizations[0]
        secondMapping.realizationId = secondRealization.id
        secondMapping.path = "payload/evidence/second.txt"
        carrier.embeddedRealizations.append(secondMapping)

        XCTAssertEqual(VAO05Validator.validateManifest(manifest), [])
        XCTAssertThrowsError(
            try VAO05MaterializationPlanner.plan(
                manifest: manifest,
                carrier: carrier,
                requestedGroupIds: manifest.assetGroups.map(\.id),
                supportedCapabilities: []
            )
        ) { error in
            XCTAssertEqual(error as? VAO05MaterializationError, .aggregateByteSizeOverflow)
        }
    }

    func testNativeReaderVerifiesFinalReferenceCarrier() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao05-reference-\(UUID().uuidString).vao")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let paths = [
            "mimetype",
            VAO05Contract.manifestFilename,
            VAO05Contract.carrierFilename,
            "payload/evidence/source.txt",
        ]
        let entries = try paths.map { path in
            VAOArchiveEntrySource(path: path, data: try Data(contentsOf: fixtureRoot.appendingPathComponent(path)))
        }
        try VAOArchiveWriter.write(entries: entries, to: temporary)
        let inspection = try await VAO05PackageReader().inspect(temporary)
        XCTAssertTrue(inspection.isValid, inspection.errors.joined(separator: "; "))
        XCTAssertEqual(inspection.carrier.id, "urn:uuid:03000000-0000-4000-8000-000000000040")
        XCTAssertEqual(inspection.verifiedPayloadBytes, 69)
    }

    func testOrgRecExporterWritesSelfContainedVAO05Closure() async throws {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-vao05-export-\(UUID().uuidString)", isDirectory: true)
        let projectURL = temporary.appendingPathComponent("Example.orgrec", isDirectory: true)
        let destination = temporary.appendingPathComponent("Example.vao")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        let project = OrgRecProject(
            title: "Reference export",
            organMDVSID: "",
            organName: "Example pipe organ",
            venueName: "Example venue",
            snapshot: MODAVISSnapshot(endpoint: "manual://test", payloadSHA256: Data("snapshot".utf8).sha256Hex),
            recipe: CaptureRecipe()
        )
        try OrgRecCoding.encoder.encode(project).write(
            to: projectURL.appendingPathComponent(ProjectStore.projectFilename),
            options: .atomic
        )
        try Data("evidence\n".utf8).write(to: projectURL.appendingPathComponent("evidence.txt"), options: .atomic)
        _ = try await VAO05PackageBuilder().build(project: project, packageURL: projectURL, destinationURL: destination)
        let inspection = try await VAO05PackageReader().inspect(destination)
        XCTAssertTrue(inspection.isValid, inspection.errors.joined(separator: "; "))
        XCTAssertEqual(inspection.manifest.formatVersion, VAO05Contract.formatVersion)
        XCTAssertEqual(inspection.carrier.carrierMode, "preservation-closure")
        XCTAssertEqual(inspection.realizationCount, 2)
        XCTAssertEqual(inspection.carrier.embeddedRealizations.count, 2)
        if let python = ProcessInfo.processInfo.environment["VAO05_REFERENCE_PYTHON"] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [python, "Tools/vao05.py", "validate", destination.path]
            process.currentDirectoryURL = repositoryRoot
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            try process.run()
            process.waitUntilExit()
            let report = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            XCTAssertEqual(process.terminationStatus, 0, report)
            XCTAssertTrue(report.contains("VALID"), report)
        }
    }
}
