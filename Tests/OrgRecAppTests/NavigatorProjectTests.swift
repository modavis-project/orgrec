import XCTest
import OrgRecCore
@testable import OrgRecApp

@MainActor
final class NavigatorProjectTests: XCTestCase {
    func testCatalogueImportUsesSelectedVenueAndStartsWithUnmeasuredSetups() throws {
        var profile = makeProfile()
        let manualLocator = ComponentLocator(id: "manual", organMDVSID: profile.organ.mdvsID, sourceRecordID: "record", sourcePath: "divisions[0]", snapshotSHA256: profile.snapshot.payloadSHA256, kind: "division", label: "Manual", trust: .sourceBound)
        profile.components.append(OrganComponent(id: "manual", kind: "division", label: "Manual", division: "Manual", locator: manualLocator, sourceDetails: ["short_octave": #"{"mapping":{"40":"36"}}"#]))
        let project = try AppModel.catalogueProject(profile: profile, selection: profile.organ, attachingTo: nil)
        XCTAssertEqual(project.venueName, profile.organ.location)
        XCTAssertEqual(project.organMDVSID, profile.organ.mdvsID)
        XCTAssertTrue(project.devices.isEmpty)
        XCTAssertFalse(project.setups.isEmpty)
        XCTAssertTrue(project.setups.allSatisfy { $0.placements.isEmpty && $0.environment.temperatureCelsius == nil })
        XCTAssertFalse(project.roadmap.isEmpty)
        XCTAssertTrue(project.roadmapCompilation?.warnings.contains(where: { $0.contains("short octave for Manual") }) == true)

        var manual = OrgRecProject(title: "April field session", organMDVSID: "LOCAL:TEST", organName: "Test", venueName: "North gallery", snapshot: MODAVISSnapshot(endpoint: "manual://orgrec-project", payloadSHA256: ""), recipe: CaptureRecipe())
        manual.setups = [MicrophoneSetup(name: "Console pair", coordinateOrigin: "console")]
        let attached = try AppModel.catalogueProject(profile: profile, selection: profile.organ, attachingTo: manual)
        XCTAssertEqual(attached.id, manual.id)
        XCTAssertEqual(attached.title, manual.title)
        XCTAssertEqual(attached.venueName, manual.venueName)
        XCTAssertEqual(attached.setups, manual.setups)

        let other = NavigatorOrganSummary(mdvsID: "MDVS:ENTY:OTHER", title: "Other")
        XCTAssertThrowsError(try AppModel.catalogueProject(profile: profile, selection: other, attachingTo: manual))
    }

    func testCataloguePackagePublishesOnlyAfterEvidenceIsVerified() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("Imported.orgrec")
        let profile = makeProfile()
        let project = try AppModel.catalogueProject(profile: profile, selection: profile.organ, attachingTo: nil)
        let store = ProjectStore()
        do {
            try await store.createPackage(at: destination, project: project, navigatorPayload: Data("changed".utf8))
            XCTFail("Changed evidence should fail validation")
        } catch OrgRecError.invalidNavigatorResponse { }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [])

        try await store.createPackage(at: destination, project: project, navigatorPayload: profile.rawPayload)
        let loaded = try await store.load(from: destination)
        XCTAssertNil(loaded.snapshot.release.protectedFingerprintSHA256)
        XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent(XCTUnwrap(loaded.navigatorPayloadRelativePath))), profile.rawPayload)
        let iad = root.appendingPathComponent("Field.iad")
        do {
            try await CapturePackageBuilder().build(project: loaded, packageURL: destination, destinationURL: iad)
            XCTFail("IAD requires a protected database fingerprint")
        } catch OrgRecError.exportValidation(let reason) {
            XCTAssertTrue(reason.contains("fingerprint"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: iad.path))
    }

    private func makeProfile() -> NavigatorRoadmapProfile {
        let organ = NavigatorOrganSummary(mdvsID: "MDVS:ENTY:TEST", title: "Test organ", location: "Catalogue church")
        let payload = Data("{}".utf8)
        let snapshot = MODAVISSnapshot(navigatorBaseURL: NavigatorClient.publicBaseURL, endpoint: "/specification", payloadSHA256: payload.sha256Hex, release: ReleaseBinding(protectedFingerprintSHA256: nil))
        let locator = ComponentLocator(id: "stop", organMDVSID: organ.id, sourceRecordID: "record", sourcePath: "stops[0]", snapshotSHA256: snapshot.payloadSHA256, kind: "stop", label: "Flute", trust: .sourceBound)
        let stop = OrganComponent(id: "stop", kind: "stop", label: "Flute", division: "Manual", locator: locator, playableMIDILow: 60, playableMIDIHigh: 60)
        return NavigatorRoadmapProfile(organ: organ, snapshot: snapshot, components: [stop], rawPayload: payload)
    }
}
