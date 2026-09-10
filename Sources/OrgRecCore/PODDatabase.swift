import CryptoKit
import Foundation
import SQLite3

/// Compatibility boundary for the reduced MODAVIS Pipe Organ Dataset 1.6.0
/// SQLite projection published for OrgRec. The database is always opened
/// read-only; OrgRec copies a verified database into its local cache instead of
/// changing the published bytes.
public enum PODDatabaseContract {
    public static let releaseVersion = "1.6.0"
    public static let projectionProfile = "orgrec"
    public static let artifactProfile = "public_structured_dataset"
    public static let databaseContract = "modavis.release-1.6.0-public-preparation/v1"
    public static let preferredFilename = "modavis-pod-1.6.0-orgrec.sqlite"
    public static let publishedByteSize: Int64 = 5_814_468_608
    public static let publishedSHA256 = "e8c97e7cc2b9d36a11d66ea317335367175e1cc9542ce0c4275fd27089c8b1e0"

    public static let downloadURL = URL(string: "https://zenodo.org/records/22308263/files/modavis-pod-1.6.0-orgrec.sqlite.gz?download=1")!
    public static let compressedByteSize: Int64 = 1_791_863_814
    public static let compressedSHA256 = "df6090ab11629cb8894fc088b352d4261ddd4ea83fc438d321b6332ddcbb44a3"

    static func identity(for version: String?) -> (contract: String, bytes: Int64, sha256: String)? {
        switch version {
        case releaseVersion: return (databaseContract, publishedByteSize, publishedSHA256)
        case "1.5.0": return ("modavis.release-1.5-public-preparation/v1", 418_177_024,
            "dd57394627c91d9fa3f4f3bfd1770c773184345448af80bef63d834de0cbc464")
        default: return nil
        }
    }

    // These are the three disclosed label classes admitted by POD 1.6.0 FTS.
    static let disclosedComponentPredicate = "label_disclosure_state IN ('fact_label_included', 'public_structured_label', 'structured_source_fact')"

    static let requiredColumns: [String: Set<String>] = [
        "metadata": ["key", "value"],
        "organ": ["organ_pk", "mdvs_id", "canonical_uri", "label", "source_count", "media_available", "period_buckets_json", "sources_json"],
        "organ_alias": ["alias_mdvs_id", "canonical_mdvs_id", "alias_uri", "canonical_uri", "outcome", "evidence_sha256"],
        "builder": ["actor_pk", "mdvs_id", "canonical_uri", "label", "actor_type", "structured_name_count"],
        "organ_builder": ["organ_mdvs_id", "actor_mdvs_id", "actor_uri", "assertion_count", "relation_count"],
        "component": ["component_id", "organ_mdvs_id", "component_type", "label", "division_label", "pitch_label", "terminal_outcome", "occurrence_count", "label_disclosure_state"],
        "component_provenance": ["component_id", "source_record_id", "source_key", "evidence_sha256", "decision_sha256"],
        "technical_parameter": ["fact_id", "organ_mdvs_id", "family", "label", "display_value", "normalized_number", "support_state", "conflict_state", "captured_component_count", "source_record_id", "source_url", "evidence_sha256", "row_sha256"],
        "source": ["source_key", "source_record_count", "canonical_organ_count", "sample_host", "included_data", "excluded_data"],
        "roadmap_eligibility": ["organ_mdvs_id", "stop_count", "pitched_stop_count", "division_count", "eligibility_state", "caveat"],
        "organ_search": ["mdvs_id", "label"],
        "component_search": ["component_id", "organ_mdvs_id", "label", "division_label"],
    ]
}

public struct PODDatabaseInspection: Codable, Hashable, Sendable {
    public var databaseFilename: String
    public var fileSize: Int64
    public var sha256: String
    public var metadata: [String: String]
    public var rowCounts: [String: Int64]
    public var errors: [String]
    public var warnings: [String]

    public var isCompatible: Bool { errors.isEmpty }
    public var releaseVersion: String? { metadata["release_version"] }
    public var organCount: Int64 { rowCounts["organ"] ?? 0 }
    public var componentCount: Int64 { rowCounts["component"] ?? 0 }
    public var roadmapEligibleOrganCount: Int64 { rowCounts["roadmap_eligibility"] ?? 0 }
    public var matchesPublishedArtifact: Bool {
        guard isCompatible, let identity = PODDatabaseContract.identity(for: releaseVersion) else { return false }
        return fileSize == identity.bytes && sha256 == identity.sha256
    }
}

public struct PODOrganSummary: Codable, Hashable, Identifiable, Sendable {
    public var id: String { mdvsID }
    public var mdvsID: String
    public var canonicalURI: String?
    public var title: String
    public var builders: String?
    public var sourceCount: Int
    public var mediaAvailable: Bool
    public var stopCount: Int?
    public var pitchedStopCount: Int?
    public var divisionCount: Int?
    public var eligibilityState: String?
    public var caveat: String?

    public var navigatorSummary: NavigatorOrganSummary {
        NavigatorOrganSummary(mdvsID: mdvsID, title: title, builder: builders)
    }
}

public enum PODDatabaseReader {
    private static let countedTables = [
        "metadata", "organ", "organ_alias", "builder", "organ_builder", "component",
        "component_provenance", "technical_parameter", "source", "roadmap_eligibility",
    ]

    public static func inspect(databaseURL: URL) throws -> PODDatabaseInspection {
        let initialValues = try validatedDatabaseFile(databaseURL)
        let digest = try sha256(of: databaseURL)
        let connection = try PODSQLiteConnection(databaseURL: databaseURL)
        var errors: [String] = []
        var warnings: [String] = []

        let quickCheck = try connection.scalarText("PRAGMA quick_check(1)")
        if quickCheck != "ok" {
            errors.append("SQLite integrity check failed: \(quickCheck ?? "no result").")
        }

        let metadata = try readMetadata(connection)
        validateMetadata(metadata, errors: &errors)
        try validateSchema(connection, errors: &errors)

        var rowCounts: [String: Int64] = [:]
        for table in countedTables {
            do {
                rowCounts[table] = try connection.scalarInt64("SELECT count(*) FROM \(table)") ?? 0
            } catch {
                rowCounts[table] = 0
            }
        }
        for table in ["organ", "organ_alias", "builder", "organ_builder", "component", "component_provenance", "technical_parameter", "source", "roadmap_eligibility"]
        where rowCounts[table, default: 0] == 0 {
            errors.append("Required POD table \(table) is empty.")
        }
        if rowCounts["component"] != rowCounts["component_provenance"] {
            errors.append("Every component must have exactly one component_provenance row.")
        }

        if let orphanComponents = try? connection.scalarInt64("""
            SELECT count(*) FROM component AS c
            LEFT JOIN organ AS o ON o.mdvs_id = c.organ_mdvs_id
            WHERE o.mdvs_id IS NULL
            """), orphanComponents != 0 {
            errors.append("The database contains \(orphanComponents) orphan component rows.")
        }
        if let orphanRoadmaps = try? connection.scalarInt64("""
            SELECT count(*) FROM roadmap_eligibility AS r
            LEFT JOIN organ AS o ON o.mdvs_id = r.organ_mdvs_id
            WHERE o.mdvs_id IS NULL
            """), orphanRoadmaps != 0 {
            errors.append("The database contains \(orphanRoadmaps) orphan roadmap rows.")
        }

        let identityChecks: [(String, String)] = [
            ("SELECT count(*) - count(DISTINCT mdvs_id) FROM organ", "Duplicate canonical organ identifiers are present."),
            ("SELECT count(*) - count(DISTINCT component_id) FROM component", "Duplicate component identifiers are present."),
            ("SELECT count(*) FROM (SELECT component_id FROM component_provenance GROUP BY component_id HAVING count(*) != 1)", "Component provenance is not one-to-one."),
            ("SELECT count(*) FROM component_provenance AS p LEFT JOIN component AS c ON c.component_id = p.component_id WHERE c.component_id IS NULL", "Orphan component provenance rows are present."),
            ("SELECT count(*) FROM (SELECT organ_mdvs_id FROM roadmap_eligibility GROUP BY organ_mdvs_id HAVING count(*) != 1)", "Roadmap eligibility is not one-to-one per organ."),
            ("SELECT count(*) FROM organ WHERE rowid != organ_pk", "Organ search row identifiers do not match organ_pk."),
        ]
        for (sql, message) in identityChecks {
            if let count = try? connection.scalarInt64(sql), count != 0 { errors.append(message) }
        }

        do {
            _ = try connection.scalarInt64("SELECT rowid FROM organ_search WHERE organ_search MATCH 'MDVS' LIMIT 1")
            _ = try connection.scalarInt64("SELECT rowid FROM component_search WHERE component_search MATCH 'Principal' LIMIT 1")
            let organSearchCount = try connection.scalarInt64("SELECT count(*) FROM organ_search") ?? -1
            let componentSearchCount = try connection.scalarInt64("SELECT count(*) FROM component_search") ?? -1
            if organSearchCount != rowCounts["organ"] { errors.append("The organ FTS5 index is incomplete.") }
            let expectedComponentCount = metadata["release_version"] == "1.6.0"
                ? try connection.scalarInt64("SELECT count(*) FROM component WHERE \(PODDatabaseContract.disclosedComponentPredicate)")
                : rowCounts["component"]
            if componentSearchCount != expectedComponentCount { errors.append("The component FTS5 index does not match the disclosed component set.") }
            // Component FTS rowids are assigned after disclosure filtering and
            // are not component-table rowids. The published artifact digest
            // establishes exact index identity; do not join these row clocks.
        } catch {
            errors.append("The POD FTS5 search indexes cannot be queried: \(error.localizedDescription)")
        }

        if metadata["raw_source_media_included"] != "false" {
            warnings.append("This projection unexpectedly declares that raw source media are included.")
        }
        if metadata["raw_source_prose_included"] != "false" {
            warnings.append("This projection unexpectedly declares that raw source prose is included.")
        }

        let finalValues = try databaseURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        if initialValues.fileSize != finalValues.fileSize || initialValues.contentModificationDate != finalValues.contentModificationDate {
            errors.append("The POD database changed while it was being verified.")
        }

        return PODDatabaseInspection(
            databaseFilename: databaseURL.lastPathComponent,
            fileSize: Int64(initialValues.fileSize ?? 0),
            sha256: digest,
            metadata: metadata,
            rowCounts: rowCounts,
            errors: Array(Set(errors)).sorted(),
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public static func search(databaseURL: URL, query: String, limit: Int = 30) throws -> [PODOrganSummary] {
        _ = try validatedDatabaseFile(databaseURL)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        let connection = try compatibleConnection(databaseURL)
        let ftsQuery = quotedPrefixFTSQuery(normalizedQuery)
        guard !ftsQuery.isEmpty else { return [] }
        let boundedLimit = min(max(limit, 1), 100)
        let likeQuery = "%\(normalizedQuery)%"
        return try connection.query(
            """
            SELECT o.mdvs_id, o.canonical_uri, o.label, o.source_count, o.media_available,
                   r.stop_count, r.pitched_stop_count, r.division_count, r.eligibility_state, r.caveat,
                   (SELECT group_concat(label, '; ') FROM (
                        SELECT DISTINCT b.label AS label
                        FROM organ_builder AS ob
                        JOIN builder AS b ON b.mdvs_id = ob.actor_mdvs_id
                        WHERE ob.organ_mdvs_id = o.mdvs_id AND b.label IS NOT NULL
                        ORDER BY b.label COLLATE NOCASE LIMIT 4
                   )) AS builders
            FROM organ AS o
            LEFT JOIN roadmap_eligibility AS r ON r.organ_mdvs_id = o.mdvs_id
            WHERE o.rowid IN (
                SELECT rowid FROM organ_search WHERE organ_search MATCH ?1
            ) OR o.mdvs_id IN (
                SELECT DISTINCT ob.organ_mdvs_id
                FROM organ_builder AS ob
                JOIN builder AS b ON b.mdvs_id = ob.actor_mdvs_id
                WHERE b.label LIKE ?2 COLLATE NOCASE
            )
            ORDER BY CASE WHEN o.mdvs_id = ?3 THEN 0 ELSE 1 END,
                     CASE WHEN r.eligibility_state = 'component_comparison_ready' THEN 0 ELSE 1 END,
                     o.label COLLATE NOCASE
            LIMIT ?4
            """,
            bindings: [.text(ftsQuery), .text(likeQuery), .text(normalizedQuery), .int64(Int64(boundedLimit))]
        ) { statement in
            PODOrganSummary(
                mdvsID: PODSQLiteConnection.text(statement, 0) ?? "",
                canonicalURI: PODSQLiteConnection.text(statement, 1),
                title: PODSQLiteConnection.text(statement, 2) ?? "Unnamed pipe organ",
                builders: PODSQLiteConnection.text(statement, 10),
                sourceCount: PODSQLiteConnection.int(statement, 3) ?? 0,
                mediaAvailable: (PODSQLiteConnection.int(statement, 4) ?? 0) != 0,
                stopCount: PODSQLiteConnection.int(statement, 5),
                pitchedStopCount: PODSQLiteConnection.int(statement, 6),
                divisionCount: PODSQLiteConnection.int(statement, 7),
                eligibilityState: PODSQLiteConnection.text(statement, 8),
                caveat: PODSQLiteConnection.text(statement, 9)
            )
        }
    }

    public static func roadmapProfile(
        databaseURL: URL,
        organID requestedOrganID: String,
        databaseSHA256 knownDatabaseSHA256: String? = nil
    ) throws -> NavigatorRoadmapProfile {
        _ = try validatedDatabaseFile(databaseURL)
        let connection = try compatibleConnection(databaseURL)
        let metadata = try readMetadata(connection)
        let databaseSHA256 = try knownDatabaseSHA256 ?? sha256(of: databaseURL)
        let organID = try canonicalOrganID(requestedOrganID, connection: connection)

        guard let organ = try connection.query(
            """
            SELECT o.mdvs_id, o.canonical_uri, o.label, o.source_count, o.media_available,
                   r.stop_count, r.pitched_stop_count, r.division_count, r.eligibility_state, r.caveat
            FROM organ AS o
            LEFT JOIN roadmap_eligibility AS r ON r.organ_mdvs_id = o.mdvs_id
            WHERE o.mdvs_id = ?1 LIMIT 1
            """,
            bindings: [.text(organID)]
        , map: { statement in
            PODFrozenOrgan(
                mdvsID: PODSQLiteConnection.text(statement, 0) ?? "",
                canonicalURI: PODSQLiteConnection.text(statement, 1),
                label: PODSQLiteConnection.text(statement, 2) ?? "Unnamed pipe organ",
                sourceCount: PODSQLiteConnection.int(statement, 3) ?? 0,
                mediaAvailable: (PODSQLiteConnection.int(statement, 4) ?? 0) != 0,
                stopCount: PODSQLiteConnection.int(statement, 5),
                pitchedStopCount: PODSQLiteConnection.int(statement, 6),
                divisionCount: PODSQLiteConnection.int(statement, 7),
                eligibilityState: PODSQLiteConnection.text(statement, 8),
                caveat: PODSQLiteConnection.text(statement, 9)
            )
        }).first else {
            throw OrgRecError.invalidProject("The POD database does not contain organ \(requestedOrganID).")
        }

        guard organ.eligibilityState == "component_comparison_ready" else {
            throw OrgRecError.invalidProject("The POD database marks \(organ.mdvsID) as technical-facts-only; no component roadmap can be compiled.")
        }

        let builders = try connection.query(
            """
            SELECT b.mdvs_id, b.canonical_uri, b.label, b.actor_type
            FROM organ_builder AS ob
            JOIN builder AS b ON b.mdvs_id = ob.actor_mdvs_id
            WHERE ob.organ_mdvs_id = ?1
            ORDER BY b.label COLLATE NOCASE
            """,
            bindings: [.text(organID)]
        ) { statement in
            PODFrozenBuilder(
                mdvsID: PODSQLiteConnection.text(statement, 0),
                canonicalURI: PODSQLiteConnection.text(statement, 1),
                label: PODSQLiteConnection.text(statement, 2),
                actorType: PODSQLiteConnection.text(statement, 3)
            )
        }

        let componentRows = try connection.query(
            """
            SELECT c.component_id, c.component_type, c.label, c.division_label, c.pitch_label,
                   c.terminal_outcome, c.occurrence_count, c.label_disclosure_state,
                   p.source_record_id, p.source_key, p.evidence_sha256, p.decision_sha256
            FROM component AS c
            LEFT JOIN component_provenance AS p ON p.component_id = c.component_id
            WHERE c.organ_mdvs_id = ?1
              AND (\(metadata["release_version"] == "1.6.0" ? PODDatabaseContract.disclosedComponentPredicate : "1"))
            ORDER BY c.component_type, c.division_label COLLATE NOCASE, c.label COLLATE NOCASE, c.component_id
            """,
            bindings: [.text(organID)]
        ) { statement in
            PODFrozenComponent(
                componentID: PODSQLiteConnection.text(statement, 0) ?? "",
                componentType: PODSQLiteConnection.text(statement, 1) ?? "",
                label: PODSQLiteConnection.text(statement, 2) ?? "Unnamed component",
                divisionLabel: PODSQLiteConnection.text(statement, 3),
                pitchLabel: PODSQLiteConnection.text(statement, 4),
                terminalOutcome: PODSQLiteConnection.text(statement, 5),
                occurrenceCount: PODSQLiteConnection.int(statement, 6),
                labelDisclosureState: PODSQLiteConnection.text(statement, 7),
                sourceRecordID: PODSQLiteConnection.text(statement, 8),
                sourceKey: PODSQLiteConnection.text(statement, 9),
                evidenceSHA256: PODSQLiteConnection.text(statement, 10),
                decisionSHA256: PODSQLiteConnection.text(statement, 11)
            )
        }

        let technicalRows = try connection.query(
            """
            SELECT fact_id, family, label, display_value, normalized_number, support_state,
                   conflict_state, source_record_id, source_url, evidence_sha256, row_sha256
            FROM technical_parameter
            WHERE organ_mdvs_id = ?1
            ORDER BY family, fact_id
            """,
            bindings: [.text(organID)]
        ) { statement in
            PODFrozenTechnicalParameter(
                factID: PODSQLiteConnection.text(statement, 0),
                family: PODSQLiteConnection.text(statement, 1) ?? "",
                label: PODSQLiteConnection.text(statement, 2),
                displayValue: PODSQLiteConnection.text(statement, 3),
                normalizedNumber: PODSQLiteConnection.double(statement, 4),
                supportState: PODSQLiteConnection.text(statement, 5),
                conflictState: PODSQLiteConnection.text(statement, 6),
                sourceRecordID: PODSQLiteConnection.text(statement, 7),
                sourceURL: PODSQLiteConnection.text(statement, 8),
                evidenceSHA256: PODSQLiteConnection.text(statement, 9),
                rowSHA256: PODSQLiteConnection.text(statement, 10)
            )
        }

        let frozenProjection = PODFrozenProjection(
            contract: "orgrec.pod-sqlite-projection/v1",
            databaseSHA256: databaseSHA256,
            metadata: metadata,
            organ: organ,
            builders: builders,
            components: componentRows,
            technicalParameters: technicalRows
        )
        let payload = try OrgRecCoding.encoder.encode(frozenProjection)
        let payloadSHA256 = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()

        let components = componentRows.map { row in
            var details: [String: String] = [:]
            if let value = row.terminalOutcome { details["terminalOutcome"] = value }
            if let value = row.occurrenceCount { details["occurrenceCount"] = String(value) }
            if let value = row.labelDisclosureState { details["labelDisclosureState"] = value }
            if let value = row.sourceKey { details["sourceKey"] = value }
            if let value = row.evidenceSHA256 { details["evidenceSHA256"] = value }
            if let value = row.decisionSHA256 { details["decisionSHA256"] = value }
            return OrganComponent(
                id: row.componentID,
                kind: row.componentType,
                label: row.label,
                division: row.divisionLabel?.nonEmpty ?? (row.componentType == "division" ? row.label : "Unassigned"),
                footHeight: row.pitchLabel?.nonEmpty,
                locator: ComponentLocator(
                    id: row.componentID,
                    organMDVSID: organ.mdvsID,
                    canonicalMDVSID: organ.mdvsID,
                    sourceRecordID: row.sourceRecordID,
                    sourcePath: "pod-sqlite/component/\(row.componentID)",
                    snapshotSHA256: payloadSHA256,
                    kind: row.componentType,
                    label: row.label,
                    trust: .canonicalMDVS
                ),
                sourceDetails: details.isEmpty ? nil : details
            )
        }

        let builderLabel = builders.compactMap(\.label).filter { !$0.isEmpty }.joined(separator: "; ").nonEmpty
        let sourceURLs = Array(Set(technicalRows.compactMap(\.sourceURL).filter { !$0.isEmpty })).sorted()
        let firstTechnicalValue: (String) -> String? = { family in
            technicalRows.first { $0.family == family }?.displayValue?.nonEmpty
        }
        let pitchRow = technicalRows.first {
            $0.family == "pitch_standard" && ($0.normalizedNumber.map { (300...600).contains($0) } ?? false)
        }
        let pitch = pitchRow?.normalizedNumber
        let summary = NavigatorOrganSummary(mdvsID: organ.mdvsID, title: organ.label, builder: builderLabel)
        let characteristics = OrganSpecificationCharacteristics(
            referencePitchHz: pitch,
            temperament: firstTechnicalValue("temperament"),
            manualCount: technicalRows.first { $0.family == "manual_total" }?.normalizedNumber.map(Int.init),
            documentedStopCount: organ.stopCount,
            divisionCount: organ.divisionCount,
            couplerCount: componentRows.filter { $0.componentType == "coupler" }.count,
            accessoryCount: componentRows.filter { $0.componentType == "accessory" }.count,
            builder: builderLabel,
            actionType: firstTechnicalValue("action_system"),
            windPressure: firstTechnicalValue("wind_pressure"),
            sourceCount: organ.sourceCount,
            sourceURLs: sourceURLs.isEmpty ? nil : sourceURLs
        )
        let release = ReleaseBinding(
            requestedRelease: metadata["release_version"] ?? PODDatabaseContract.releaseVersion,
            releaseState: metadata["artifact_profile"] ?? PODDatabaseContract.artifactProfile,
            canonicalSourceRelease: metadata["release_version"] ?? PODDatabaseContract.releaseVersion,
            protectedFingerprintSHA256: databaseSHA256,
            navigatorContractVersion: metadata["contract"] ?? PODDatabaseContract.databaseContract
        )
        let snapshot = MODAVISSnapshot(
            endpoint: "pod-sqlite/organ/\(organ.mdvsID)",
            payloadSHA256: payloadSHA256,
            release: release
        )
        let documentedPitch = pitchRow.flatMap { row -> DocumentedPitchStandard? in
            guard let frequency = row.normalizedNumber else { return nil }
            return DocumentedPitchStandard(
                frequencyHz: frequency,
                rawValue: row.displayValue ?? String(frequency),
                evidenceStatus: row.supportState,
                sourcePath: "pod-sqlite/technical_parameter/\(row.factID ?? "pitch_standard")",
                sourceRecordID: row.sourceRecordID,
                modavisRelease: metadata["release_version"] ?? PODDatabaseContract.releaseVersion
            )
        }
        return NavigatorRoadmapProfile(
            organ: summary,
            snapshot: snapshot,
            components: components,
            rawPayload: payload,
            characteristics: characteristics,
            documentedPitchStandard: documentedPitch
        )
    }

    private static func compatibleConnection(_ databaseURL: URL) throws -> PODSQLiteConnection {
        let connection = try PODSQLiteConnection(databaseURL: databaseURL)
        let metadata = try readMetadata(connection)
        var errors: [String] = []
        validateMetadata(metadata, errors: &errors)
        try validateSchema(connection, errors: &errors)
        guard errors.isEmpty else {
            throw OrgRecError.invalidProject("Incompatible POD database: " + errors.prefix(3).joined(separator: "; "))
        }
        return connection
    }

    private static func canonicalOrganID(_ requested: String, connection: PODSQLiteConnection) throws -> String {
        if let direct = try connection.scalarText(
            "SELECT mdvs_id FROM organ WHERE mdvs_id = ?1 LIMIT 1",
            bindings: [.text(requested)]
        ) { return direct }
        if let alias = try connection.scalarText(
            "SELECT canonical_mdvs_id FROM organ_alias WHERE alias_mdvs_id = ?1 LIMIT 1",
            bindings: [.text(requested)]
        ) { return alias }
        return requested
    }

    private static func readMetadata(_ connection: PODSQLiteConnection) throws -> [String: String] {
        Dictionary(uniqueKeysWithValues: try connection.query("SELECT key, value FROM metadata ORDER BY key") { statement in
            (PODSQLiteConnection.text(statement, 0) ?? "", PODSQLiteConnection.text(statement, 1) ?? "")
        })
    }

    private static func validateMetadata(_ metadata: [String: String], errors: inout [String]) {
        guard let identity = PODDatabaseContract.identity(for: metadata["release_version"]) else {
            errors.append("Unsupported POD release_version; expected 1.6.0 or 1.5.0.")
            return
        }
        let expected = [
            "projection_profile": PODDatabaseContract.projectionProfile,
            "artifact_profile": PODDatabaseContract.artifactProfile,
            "contract": identity.contract,
        ]
        for (key, value) in expected where metadata[key] != value {
            errors.append("POD metadata \(key) must equal \(value).")
        }
        for key in ["created_at", "canonical_uri_base", "uri_ledger_sha256", "source_uri_ledger_sha256"]
        where metadata[key]?.nonEmpty == nil {
            errors.append("POD metadata is missing \(key).")
        }
        for key in ["uri_ledger_sha256", "source_uri_ledger_sha256"] {
            if let value = metadata[key], value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil {
                errors.append("POD metadata \(key) is not a SHA-256 digest.")
            }
        }
    }

    private static func validateSchema(_ connection: PODSQLiteConnection, errors: inout [String]) throws {
        let tables = Set(try connection.query(
            "SELECT name FROM sqlite_schema WHERE type IN ('table', 'view')"
        ) { PODSQLiteConnection.text($0, 0) ?? "" })
        for (table, requiredColumns) in PODDatabaseContract.requiredColumns.sorted(by: { $0.key < $1.key }) {
            guard tables.contains(table) else {
                errors.append("Missing required POD table \(table).")
                continue
            }
            let columns = Set(try connection.query(
                "SELECT name FROM pragma_table_info(?1)",
                bindings: [.text(table)]
            ) { PODSQLiteConnection.text($0, 0) ?? "" })
            let missing = requiredColumns.subtracting(columns).sorted()
            if !missing.isEmpty {
                errors.append("POD table \(table) is missing columns: \(missing.joined(separator: ", ")).")
            }
        }
    }

    private static func validatedDatabaseFile(_ databaseURL: URL) throws -> URLResourceValues {
        let values = try databaseURL.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw OrgRecError.invalidProject("The POD database must be a regular, non-symbolic file.")
        }
        guard (values.fileSize ?? 0) > 0 else {
            throw OrgRecError.invalidProject("The POD database file is empty.")
        }
        return values
    }

    private static func quotedPrefixFTSQuery(_ query: String) -> String {
        let tokens = query.unicodeScalars.split { !CharacterSet.alphanumerics.contains($0) }
            .map { String(String.UnicodeScalarView($0)) }
            .filter { !$0.isEmpty }
        return tokens.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }.joined(separator: " AND ")
    }
}

public actor PODDatabaseImporter {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    @discardableResult
    public func importVerifiedDatabase(
        from source: URL,
        to destination: URL,
        enforcePublishedArtifactFixity: Bool = true
    ) throws -> PODDatabaseInspection {
        let sourceInspection = try PODDatabaseReader.inspect(databaseURL: source)
        guard sourceInspection.isCompatible else {
            throw OrgRecError.invalidProject("POD database validation failed: " + sourceInspection.errors.prefix(3).joined(separator: "; "))
        }
        if enforcePublishedArtifactFixity && !sourceInspection.matchesPublishedArtifact {
            throw OrgRecError.invalidProject("The POD database matches the schema but not the pinned supported OrgRec artifact size and SHA-256 digest.")
        }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else {
            throw OrgRecError.invalidProject("The POD database destination already exists.")
        }
        let parent = destination.deletingLastPathComponent()
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".orgrec-pod-\(UUID().uuidString).sqlite")
        do {
            try manager.copyItem(at: source, to: staging)
            let stagedInspection = try PODDatabaseReader.inspect(databaseURL: staging)
            guard stagedInspection.isCompatible, stagedInspection.sha256 == sourceInspection.sha256 else {
                throw OrgRecError.invalidProject("The staged POD database failed exact revalidation.")
            }
            try manager.moveItem(at: staging, to: destination)
            return PODDatabaseInspection(
                databaseFilename: destination.lastPathComponent,
                fileSize: stagedInspection.fileSize,
                sha256: stagedInspection.sha256,
                metadata: stagedInspection.metadata,
                rowCounts: stagedInspection.rowCounts,
                errors: stagedInspection.errors,
                warnings: stagedInspection.warnings
            )
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }
    }

    @discardableResult
    public func downloadVerifiedDatabase(
        from remoteURL: URL,
        to destination: URL,
        expectedSHA256: String? = nil,
        expectedByteSize: Int64? = nil
    ) async throws -> PODDatabaseInspection {
        guard remoteURL.scheme?.lowercased() == "https", remoteURL.host?.isEmpty == false else {
            throw OrgRecError.invalidProject("The POD database download URL must use HTTPS.")
        }
        let (temporaryURL, response) = try await session.download(from: remoteURL)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OrgRecError.invalidProject("The POD database download did not return a successful HTTP response.")
        }
        guard response.url?.scheme?.lowercased() == "https" else {
            throw OrgRecError.invalidProject("The POD database download redirected away from HTTPS.")
        }
        let header = try FileHandle(forReadingFrom: temporaryURL)
        let magic = try header.read(upToCount: 2)
        try header.close()
        let expanded = magic == Data([0x1f, 0x8b]) ? try Self.expandPublishedArchive(at: temporaryURL) : nil
        defer { if let expanded { try? FileManager.default.removeItem(at: expanded) } }
        let databaseURL = expanded ?? temporaryURL
        let inspection = try PODDatabaseReader.inspect(databaseURL: databaseURL)
        let requiredSHA256 = expectedSHA256 ?? PODDatabaseContract.publishedSHA256
        let requiredByteSize = expectedByteSize ?? PODDatabaseContract.publishedByteSize
        if inspection.sha256 != requiredSHA256.lowercased() {
            throw OrgRecError.invalidProject("The downloaded POD database does not match the expected SHA-256 digest.")
        }
        if inspection.fileSize != requiredByteSize {
            throw OrgRecError.invalidProject("The downloaded POD database does not match the expected byte size.")
        }
        return try importVerifiedDatabase(from: databaseURL, to: destination)
    }

    /// Verify compressed bytes before invoking the decoder; both representations
    /// are independently pinned by the published POD manifest.
    static func expandPublishedArchive(
        at source: URL,
        compressedBytes: Int64 = PODDatabaseContract.compressedByteSize,
        compressedSHA256: String = PODDatabaseContract.compressedSHA256,
        decodedBytes: Int64 = PODDatabaseContract.publishedByteSize,
        decodedSHA256: String = PODDatabaseContract.publishedSHA256
    ) throws -> URL {
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard Int64(size ?? -1) == compressedBytes, try sha256(of: source) == compressedSHA256 else {
            throw OrgRecError.invalidProject("The compressed POD archive does not match the published size and SHA-256 digest.")
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("orgrec-pod-expanded-\(UUID().uuidString).sqlite")
        guard FileManager.default.createFile(atPath: output.path, contents: nil) else {
            throw OrgRecError.invalidProject("Cannot create temporary storage for the POD database.")
        }
        do {
            let handle = try FileHandle(forWritingTo: output)
            defer { try? handle.close() }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
            process.arguments = ["-dc", source.path]
            process.standardOutput = handle
            process.standardError = FileHandle.nullDevice
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  Int64(try output.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? -1) == decodedBytes,
                  try sha256(of: output) == decodedSHA256 else {
                throw OrgRecError.invalidProject("The expanded POD database failed size or SHA-256 verification.")
            }
            return output
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

}

private struct PODFrozenProjection: Codable {
    var contract: String
    var databaseSHA256: String
    var metadata: [String: String]
    var organ: PODFrozenOrgan
    var builders: [PODFrozenBuilder]
    var components: [PODFrozenComponent]
    var technicalParameters: [PODFrozenTechnicalParameter]
}

private struct PODFrozenOrgan: Codable {
    var mdvsID: String
    var canonicalURI: String?
    var label: String
    var sourceCount: Int
    var mediaAvailable: Bool
    var stopCount: Int?
    var pitchedStopCount: Int?
    var divisionCount: Int?
    var eligibilityState: String?
    var caveat: String?
}

private struct PODFrozenBuilder: Codable {
    var mdvsID: String?
    var canonicalURI: String?
    var label: String?
    var actorType: String?
}

private struct PODFrozenComponent: Codable {
    var componentID: String
    var componentType: String
    var label: String
    var divisionLabel: String?
    var pitchLabel: String?
    var terminalOutcome: String?
    var occurrenceCount: Int?
    var labelDisclosureState: String?
    var sourceRecordID: String?
    var sourceKey: String?
    var evidenceSHA256: String?
    var decisionSHA256: String?
}

private struct PODFrozenTechnicalParameter: Codable {
    var factID: String?
    var family: String
    var label: String?
    var displayValue: String?
    var normalizedNumber: Double?
    var supportState: String?
    var conflictState: String?
    var sourceRecordID: String?
    var sourceURL: String?
    var evidenceSHA256: String?
    var rowSHA256: String?
}

private enum PODSQLiteBinding {
    case text(String)
    case int64(Int64)
}

private final class PODSQLiteConnection {
    private var database: OpaquePointer?

    init(databaseURL: URL) throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(databaseURL.path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle else {
            let message = handle.flatMap { sqlite3_errmsg($0) }.map(String.init(cString:)) ?? "unknown SQLite error"
            if let handle { sqlite3_close(handle) }
            throw OrgRecError.invalidProject("Could not open the POD SQLite database read-only: \(message)")
        }
        database = handle
        sqlite3_busy_timeout(handle, 5_000)
        try execute("PRAGMA query_only = ON")
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    func execute(_ sql: String) throws {
        guard let database else { throw OrgRecError.invalidProject("The POD database is closed.") }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
            if let errorMessage { sqlite3_free(errorMessage) }
            throw OrgRecError.invalidProject("POD SQLite error: \(message)")
        }
    }

    func scalarText(_ sql: String, bindings: [PODSQLiteBinding] = []) throws -> String? {
        try query(sql, bindings: bindings) { Self.text($0, 0) }.first ?? nil
    }

    func scalarInt64(_ sql: String, bindings: [PODSQLiteBinding] = []) throws -> Int64? {
        try query(sql, bindings: bindings) { statement in
            sqlite3_column_type(statement, 0) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 0)
        }.first ?? nil
    }

    func query<T>(
        _ sql: String,
        bindings: [PODSQLiteBinding] = [],
        map: (OpaquePointer) throws -> T
    ) throws -> [T] {
        guard let database else { throw OrgRecError.invalidProject("The POD database is closed.") }
        var statement: OpaquePointer?
        let prepare = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard prepare == SQLITE_OK, let statement else {
            throw OrgRecError.invalidProject("POD SQLite prepare error: \(String(cString: sqlite3_errmsg(database)))")
        }
        defer { sqlite3_finalize(statement) }
        for (offset, binding) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch binding {
            case .text(let value):
                result = sqlite3_bind_text(statement, index, value, -1, PODSQLiteConnection.transient)
            case .int64(let value):
                result = sqlite3_bind_int64(statement, index, value)
            }
            guard result == SQLITE_OK else {
                throw OrgRecError.invalidProject("POD SQLite bind error: \(String(cString: sqlite3_errmsg(database)))")
            }
        }
        var rows: [T] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                rows.append(try map(statement))
            case SQLITE_DONE:
                return rows
            default:
                throw OrgRecError.invalidProject("POD SQLite query error: \(String(cString: sqlite3_errmsg(database)))")
            }
        }
    }

    static func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL,
              let value = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: value)
    }

    static func int(_ statement: OpaquePointer, _ column: Int32) -> Int? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, column))
    }

    static func double(_ statement: OpaquePointer, _ column: Int32) -> Double? {
        guard sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(statement, column)
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
