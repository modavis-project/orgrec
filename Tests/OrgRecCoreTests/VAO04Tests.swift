import Foundation
import XCTest
@testable import OrgRecCore

final class VAO04Tests: XCTestCase {
    private var fixtureURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Fixtures/VAO04/descriptors/kinoorgel-multimodal-scientific.example.json")
    }

    private var repositoryRoot: URL { fixtureURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() }

    private func fixture() throws -> VAO04Manifest { try VAOFormatDispatcher.decode04(Data(contentsOf: fixtureURL)) }

    func testKinoorgelFixtureDecodesAndPassesNativeValidation() throws {
        let data = try Data(contentsOf: fixtureURL)
        XCTAssertEqual(VAOFormatDispatcher.formatVersion(in: data), "0.4.0")
        let manifest = try VAOFormatDispatcher.decode04(data)
        XCTAssertEqual(manifest.multimodal.tracks.count, 2)
        XCTAssertEqual(manifest.scientific.observations.count, 1)
        XCTAssertEqual(manifest.physicalSystem.actuators.count, 1)
        XCTAssertEqual(manifest.interactionModel?.protocolBindings.filter { $0.protocolName == "MIDI-2.0" }.count, 1)
        XCTAssertEqual(VAO04Validator.validateManifest(data: data), [])
    }

    func testDeterministicTraceExecutesExactly() throws {
        let manifest = try fixture()
        let trace = try XCTUnwrap(manifest.runtime.conformanceTraces.first)
        XCTAssertEqual(VAO04RuntimeEngine.verify(trace: trace, manifest: manifest), [])
        let result = try VAO04RuntimeEngine.execute(manifest: manifest, events: trace.inputEvents, initialState: trace.initialState ?? [:])
        XCTAssertEqual(result.state["urn:vao:fixture:kinoorgel:state:tibia-enabled"], .boolean(true))
        XCTAssertEqual(result.renderBindingIds, [])
    }

    func testImmutableNamespaceIsRequired() throws {
        var manifest = try fixture(); manifest.schema = "https://w3id.org/modavis/vao/0.4/schema/manifest.json"
        XCTAssertTrue(VAO04Validator.validateManifest(manifest).contains { $0.contains("immutable") })
    }

    func testScientificReferencesAreClosed() throws {
        var manifest = try fixture(); manifest.scientific.activities[1].protocolId = "urn:missing"
        XCTAssertTrue(VAO04Validator.validateManifest(manifest).contains { $0.contains("unresolved protocolId") })
    }

    func testSeededAnalysisRequiresRandomSource() throws {
        var manifest = try fixture(); manifest.scientific.analyses[0].reproducibility = "seeded"; manifest.scientific.analyses[0].randomSourceId = "urn:missing"
        XCTAssertTrue(VAO04Validator.validateManifest(manifest).contains { $0.contains("Seeded analysis") })
    }

    func testMultimodalMappingRejectsOverlappingSegments() throws {
        var manifest = try fixture()
        let segment = manifest.multimodal.synchronizationMappings[0].segments[0]
        manifest.multimodal.synchronizationMappings[0].segments.append(segment)
        XCTAssertTrue(VAO04Validator.validateManifest(manifest).contains { $0.contains("overlapping segment") })
    }

    func testMIDI2RequiresCompleteUMPBinding() throws {
        var manifest = try fixture(); let index = try XCTUnwrap(manifest.interactionModel?.protocolBindings.firstIndex { $0.protocolName == "MIDI-2.0" })
        manifest.interactionModel?.protocolBindings[index].umpGroup = nil
        XCTAssertTrue(VAO04Validator.validateManifest(manifest).contains { $0.contains("lacks UMP") })
    }

    func testPhysicalTopologyRejectsUnresolvedPort() throws {
        var manifest = try fixture(); manifest.physicalSystem.connections[0].targetPortId = "urn:missing"
        XCTAssertTrue(VAO04Validator.validateManifest(manifest).contains { $0.contains("unresolved port") })
    }

    func testContentDigestCannotContradictCoreSHA256() throws {
        var manifest = try fixture(); manifest.realizations[0].contentDigests = [VAO04ContentDigest(algorithm: "sha256", value: String(repeating: "0", count: 64))]
        XCTAssertTrue(VAO04Validator.validateManifest(manifest).contains { $0.contains("conflicting SHA-256") })
    }

    func testRightsConsentMustResolve() throws {
        var manifest = try fixture(); manifest.rights[0].consentIds = ["urn:missing"]
        XCTAssertTrue(VAO04Validator.validateManifest(manifest).contains { $0.contains("unresolved consent") })
    }

    func testUnknownRootPropertyIsRejectedByNativeShapeCheck() throws {
        let data = try Data(contentsOf: fixtureURL); var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        root["script"] = "unsafe()"
        let mutated = try JSONSerialization.data(withJSONObject: root)
        XCTAssertTrue(VAO04Validator.validateManifest(data: mutated).contains { $0.contains("unknown root property script") })
    }

    func testMaterializationPlannerRetainsAssetGroupSemantics() throws {
        let manifest = try fixture()
        let carrier = VAO03Carrier(
            schema: VAO04Contract.baseURI + "/schema/carrier.json", type: "VAOCarrier", formatVersion: "0.4.0",
            releaseId: manifest.release.id, manifestSHA256: String(repeating: "0", count: 64), manifestByteSize: 0,
            carrierMode: "bootstrap", embeddedRealizations: manifest.realizations.map { VAO03CarrierMapping(realizationId: $0.id, path: "payload/\($0.id.sha256Hex).bin") },
            completeGroupIds: manifest.assetGroups.map(\.id)
        )
        let group = try XCTUnwrap(manifest.assetGroups.first)
        let plan = try VAO04MaterializationPlanner.plan(
            manifest: manifest, carrier: carrier, requestedGroupIds: [group.id],
            supportedCapabilities: Set(group.requiredCapabilities)
        )
        XCTAssertEqual(Set(plan.realizationIds), Set(group.realizationIds))
        XCTAssertEqual(plan.remoteRealizationIds, [])
        XCTAssertEqual(plan.totalByteSize, group.totalByteSize)
    }

    func testNativeReaderImportsPythonWrittenCarrier() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-vao040-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: root) }
        let workspace = root.appendingPathComponent("workspace", isDirectory: true); let archive = root.appendingPathComponent("fixture.vao")
        func run(_ arguments: [String]) throws {
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/env"); process.arguments = ["python3", "Tools/vao04.py"] + arguments; process.currentDirectoryURL = repositoryRoot
            let error = Pipe(); process.standardError = error; try process.run(); process.waitUntilExit()
            if process.terminationStatus != 0 { throw NSError(domain: "VAO04Tests", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Python command failed"] ) }
        }
        try run(["migrate-0.3", "Fixtures/VAO03/valid/embedded-private", workspace.path])
        try run(["pack", workspace.path, archive.path])
        let inspection = try await VAO04PackageReader().inspect(archive)
        XCTAssertTrue(inspection.isValid, inspection.errors.joined(separator: "; "))
        XCTAssertEqual(inspection.verifiedPayloadBytes, 69)
        let imported = root.appendingPathComponent("imported", isDirectory: true)
        _ = try await VAO04PackageReader().importWorkspace(from: archive, to: imported)
        XCTAssertEqual(try sha256(of: imported.appendingPathComponent("payload/evidence/source.txt")), "167b48baa46a4d2c665c7ee655e255e817e32f2fee84275bd7067971b1593f17")
    }
}

private extension String {
    var sha256Hex: String { Data(utf8).sha256Hex }
}
