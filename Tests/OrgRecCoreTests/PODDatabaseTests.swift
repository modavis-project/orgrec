import Foundation
import SQLite3
import XCTest
@testable import OrgRecCore

final class PODDatabaseTests: XCTestCase {
    func testExternalReleaseWhenConfigured() throws {
        guard let path = ProcessInfo.processInfo.environment["ORGREC_POD_DATABASE"], !path.isEmpty else {
            throw XCTSkip("Set ORGREC_POD_DATABASE to run the release-level compatibility check.")
        }
        let databaseURL = URL(fileURLWithPath: path)
        let inspection = try PODDatabaseReader.inspect(databaseURL: databaseURL)
        XCTAssertTrue(inspection.isCompatible, inspection.errors.joined(separator: "; "))
        XCTAssertEqual(inspection.releaseVersion, PODDatabaseContract.releaseVersion)
        XCTAssertGreaterThan(inspection.organCount, 200_000)
        XCTAssertGreaterThan(inspection.componentCount, 400_000)
        XCTAssertGreaterThan(inspection.roadmapEligibleOrganCount, 20_000)

        let results = try PODDatabaseReader.search(databaseURL: databaseURL, query: "Principal", limit: 10)
        XCTAssertFalse(results.isEmpty)
        guard let eligible = results.first(where: { $0.eligibilityState == "component_comparison_ready" }) else {
            return XCTFail("Expected a component-comparison-ready search result")
        }
        let profile = try PODDatabaseReader.roadmapProfile(
            databaseURL: databaseURL,
            organID: eligible.mdvsID,
            databaseSHA256: inspection.sha256
        )
        XCTAssertFalse(profile.components.isEmpty)
        XCTAssertEqual(profile.snapshot.release.protectedFingerprintSHA256, inspection.sha256)
        XCTAssertFalse(RoadmapEngine.compileSpecification(
            components: profile.components,
            recipe: CaptureRecipe(),
            setupIDs: [UUID()]
        ).roadmap.isEmpty)
    }

    func testInspectionSearchAndRoadmapProjection() throws {
        let fixture = try makeDatabase()
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }

        let inspection = try PODDatabaseReader.inspect(databaseURL: fixture)
        XCTAssertTrue(inspection.isCompatible, inspection.errors.joined(separator: "; "))
        XCTAssertEqual(inspection.releaseVersion, "1.5.0")
        XCTAssertEqual(inspection.organCount, 1)
        XCTAssertEqual(inspection.componentCount, 1)
        XCTAssertEqual(inspection.sha256.count, 64)

        let titleResults = try PODDatabaseReader.search(databaseURL: fixture, query: "Synthetic Chapel")
        XCTAssertEqual(titleResults.map(\.mdvsID), ["MDVS:ENTY:TEST-0001-1"])
        XCTAssertEqual(titleResults.first?.builders, "Test Builder")
        XCTAssertEqual(titleResults.first?.stopCount, 1)

        let builderResults = try PODDatabaseReader.search(databaseURL: fixture, query: "Test Builder")
        XCTAssertEqual(builderResults.map(\.mdvsID), ["MDVS:ENTY:TEST-0001-1"])

        let profile = try PODDatabaseReader.roadmapProfile(
            databaseURL: fixture,
            organID: "MDVS:ENTY:ALIAS-0001-1",
            databaseSHA256: inspection.sha256
        )
        XCTAssertEqual(profile.organ.mdvsID, "MDVS:ENTY:TEST-0001-1")
        XCTAssertEqual(profile.components.count, 1)
        XCTAssertEqual(profile.components.first?.label, "Principal 8'")
        XCTAssertEqual(profile.components.first?.footHeight, "8")
        XCTAssertEqual(profile.documentedPitchStandard?.frequencyHz, 440)
        XCTAssertEqual(profile.snapshot.release.requestedRelease, "1.5.0")
        XCTAssertEqual(profile.snapshot.release.protectedFingerprintSHA256, inspection.sha256)
        XCTAssertFalse(RoadmapEngine.compileSpecification(
            components: profile.components,
            recipe: CaptureRecipe(),
            setupIDs: [UUID()]
        ).roadmap.isEmpty)
    }

    func testAtomicImporterCopiesAndRevalidatesExactDatabase() async throws {
        let fixture = try makeDatabase()
        let root = fixture.deletingLastPathComponent()
        defer { try? FileManager.default.removeItem(at: root) }
        let destination = root.appendingPathComponent("cache/modavis-pod.sqlite")

        let imported = try await PODDatabaseImporter().importVerifiedDatabase(
            from: fixture,
            to: destination,
            enforcePublishedArtifactFixity: false
        )
        XCTAssertTrue(imported.isCompatible)
        XCTAssertEqual(imported.sha256, try sha256(of: fixture))
        XCTAssertEqual(try sha256(of: destination), imported.sha256)
        do {
            _ = try await PODDatabaseImporter().importVerifiedDatabase(
                from: fixture,
                to: destination,
                enforcePublishedArtifactFixity: false
            )
            XCTFail("Importing over an existing cache should fail")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("already exists"))
        }
    }

    func testWrongReleaseAndIncompleteSchemaAreRejected() throws {
        let fixture = try makeDatabase(releaseVersion: "1.4.0", includeRoadmapTable: false)
        defer { try? FileManager.default.removeItem(at: fixture.deletingLastPathComponent()) }

        let inspection = try PODDatabaseReader.inspect(databaseURL: fixture)
        XCTAssertFalse(inspection.isCompatible)
        XCTAssertTrue(inspection.errors.contains { $0.contains("release_version") })
        XCTAssertTrue(inspection.errors.contains { $0.contains("roadmap_eligibility") })
    }

    private func makeDatabase(
        releaseVersion: String = "1.5.0",
        includeRoadmapTable: Bool = true
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("orgrec-pod-database-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let databaseURL = root.appendingPathComponent("modavis-pod-1.5-orgrec.sqlite")
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "PODDatabaseTests", code: 1)
        }
        defer { sqlite3_close(database) }

        try execute(database, """
            CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
            CREATE TABLE organ(organ_pk INT, mdvs_id TEXT, canonical_uri TEXT, label TEXT, source_count INT, media_available INT, period_buckets_json TEXT, sources_json TEXT);
            CREATE TABLE organ_alias(alias_mdvs_id TEXT, canonical_mdvs_id TEXT, alias_uri TEXT, canonical_uri TEXT, outcome TEXT, evidence_sha256 TEXT);
            CREATE TABLE builder(actor_pk INT, mdvs_id TEXT, canonical_uri TEXT, label TEXT, actor_type TEXT, structured_name_count INT);
            CREATE TABLE organ_builder(organ_mdvs_id TEXT, actor_mdvs_id TEXT, actor_uri TEXT, assertion_count INT, relation_count INT);
            CREATE TABLE component(component_id TEXT, organ_mdvs_id TEXT, component_type TEXT, label TEXT, division_label TEXT, pitch_label TEXT, terminal_outcome TEXT, occurrence_count INT, label_disclosure_state TEXT);
            CREATE TABLE component_provenance(component_id TEXT, source_record_id TEXT, source_key TEXT, evidence_sha256 TEXT, decision_sha256 TEXT);
            CREATE TABLE technical_parameter(fact_id TEXT, organ_mdvs_id TEXT, family TEXT, label TEXT, display_value TEXT, normalized_number INT, support_state TEXT, conflict_state TEXT, captured_component_count INT, source_record_id TEXT, source_url TEXT, evidence_sha256 TEXT, row_sha256 TEXT);
            CREATE TABLE source(source_key TEXT, source_record_count INT, canonical_organ_count INT, sample_host TEXT, included_data TEXT, excluded_data TEXT);
            CREATE VIRTUAL TABLE organ_search USING fts5(mdvs_id, label, content='');
            CREATE VIRTUAL TABLE component_search USING fts5(component_id, organ_mdvs_id, label, division_label, content='');
            """)
        if includeRoadmapTable {
            try execute(database, "CREATE TABLE roadmap_eligibility(organ_mdvs_id TEXT, stop_count, pitched_stop_count, division_count, eligibility_state, caveat);"
            )
        }

        let digest = String(repeating: "a", count: 64)
        let metadata: [String: String] = [
            "artifact_profile": "public_structured_dataset",
            "canonical_uri_base": "https://w3id.org/modavis/",
            "contract": "modavis.release-1.5-public-preparation/v1",
            "created_at": "2026-09-01T00:00:00Z",
            "projection_profile": "orgrec",
            "raw_source_media_included": "false",
            "raw_source_prose_included": "false",
            "release_version": releaseVersion,
            "source_uri_ledger_sha256": digest,
            "uri_ledger_sha256": digest,
        ]
        for (key, value) in metadata {
            try execute(database, "INSERT INTO metadata(key,value) VALUES(\(quoted(key)),\(quoted(value)));")
        }
        try execute(database, """
            INSERT INTO organ VALUES(1,'MDVS:ENTY:TEST-0001-1','https://w3id.org/modavis/entity/TEST-0001-1','Synthetic Chapel Organ',1,0,'[]','["test"]');
            INSERT INTO organ_alias VALUES('MDVS:ENTY:ALIAS-0001-1','MDVS:ENTY:TEST-0001-1',NULL,NULL,'canonicalized','\(digest)');
            INSERT INTO builder VALUES(1,'MDVS:ACTR:TEST-0001-1','https://w3id.org/modavis/actor/TEST-0001-1','Test Builder','organization',1);
            INSERT INTO organ_builder VALUES('MDVS:ENTY:TEST-0001-1','MDVS:ACTR:TEST-0001-1','https://w3id.org/modavis/actor/TEST-0001-1',1,1);
            INSERT INTO component VALUES('component:test:principal8','MDVS:ENTY:TEST-0001-1','stop','Principal 8''','Great','8','already_correct',1,'fact_label_included');
            INSERT INTO component_provenance VALUES('component:test:principal8','source:test:1','test','\(digest)','\(digest)');
            INSERT INTO technical_parameter VALUES('fact:test:pitch','MDVS:ENTY:TEST-0001-1','pitch_standard','Tuning Pitch','440',440,'source_backed','none',1,'source:test:1','https://example.invalid/source','\(digest)','\(digest)');
            INSERT INTO source VALUES('test',1,1,'example.invalid','structured facts','raw payloads');
            INSERT INTO organ_search(rowid,mdvs_id,label) VALUES(1,'MDVS:ENTY:TEST-0001-1','Synthetic Chapel Organ');
            INSERT INTO component_search(rowid,component_id,organ_mdvs_id,label,division_label) VALUES(1,'component:test:principal8','MDVS:ENTY:TEST-0001-1','Principal 8''','Great');
            """)
        if includeRoadmapTable {
            try execute(database, "INSERT INTO roadmap_eligibility VALUES('MDVS:ENTY:TEST-0001-1',1,1,1,'component_comparison_ready','Synthetic fixture.');")
        }
        return databaseURL
    }

    private func execute(_ database: OpaquePointer, _ sql: String) throws {
        var message: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &message)
        guard result == SQLITE_OK else {
            let detail = message.map { String(cString: $0) } ?? "SQLite error"
            if let message { sqlite3_free(message) }
            throw NSError(domain: "PODDatabaseTests", code: Int(result), userInfo: [NSLocalizedDescriptionKey: detail])
        }
    }

    private func quoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }
}
