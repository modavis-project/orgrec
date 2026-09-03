import Foundation

public struct NavigatorOrganSummary: Codable, Hashable, Identifiable, Sendable {
    public var id: String { mdvsID }
    public var mdvsID: String
    public var title: String
    public var location: String?
    public var builder: String?
    public var dateLabel: String?

    public init(mdvsID: String, title: String, location: String? = nil, builder: String? = nil, dateLabel: String? = nil) {
        self.mdvsID = mdvsID
        self.title = title
        self.location = location
        self.builder = builder
        self.dateLabel = dateLabel
    }
}

public struct NavigatorRoadmapProfile: Sendable {
    public var organ: NavigatorOrganSummary
    public var snapshot: MODAVISSnapshot
    public var components: [OrganComponent]
    public var rawPayload: Data
    public var characteristics: OrganSpecificationCharacteristics
    public var documentedPitchStandard: DocumentedPitchStandard?
    public var componentRelationships: [OrganComponentRelationship]
    public var physicalPipeMappings: [PhysicalPipeMapping]

    public init(organ: NavigatorOrganSummary, snapshot: MODAVISSnapshot, components: [OrganComponent], rawPayload: Data, characteristics: OrganSpecificationCharacteristics = OrganSpecificationCharacteristics(), documentedPitchStandard: DocumentedPitchStandard? = nil, componentRelationships: [OrganComponentRelationship] = [], physicalPipeMappings: [PhysicalPipeMapping] = []) {
        self.organ = organ
        self.snapshot = snapshot
        self.components = components
        self.rawPayload = rawPayload
        self.characteristics = characteristics
        self.documentedPitchStandard = documentedPitchStandard
        self.componentRelationships = componentRelationships
        self.physicalPipeMappings = physicalPipeMappings
    }
}

public actor NavigatorClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func search(baseURL: URL, query: String, limit: Int = 30) async throws -> [NavigatorOrganSummary] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/organs"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(min(max(limit, 1), 100))),
            URLQueryItem(name: "include_facets", value: "0"),
        ]
        let (data, response) = try await session.data(from: components.url!)
        try validate(response: response, data: data)
        let object = try JSONSerialization.jsonObject(with: data)
        return Self.findOrganSummaries(in: object)
    }

    public func fetchRoadmap(baseURL: URL, organID: String, previousETag: String? = nil) async throws -> NavigatorRoadmapProfile? {
        let encodedID = organID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? organID
        let profileURL = baseURL.appendingPathComponent("api/orgrec/v1/roadmaps/\(encodedID)")
        var profileRequest = URLRequest(url: profileURL)
        if let previousETag { profileRequest.setValue(previousETag, forHTTPHeaderField: "If-None-Match") }
        do {
            let (data, response) = try await session.data(for: profileRequest)
            if let http = response as? HTTPURLResponse, http.statusCode == 304 { return nil }
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                return try await fetchCompatibilityRoadmap(baseURL: baseURL, organID: organID, previousETag: previousETag)
            }
            try validate(response: response, data: data)
            return try Self.decodeProfile(data: data, response: response, baseURL: baseURL, endpoint: profileURL.path)
        } catch let error as URLError where error.code == .fileDoesNotExist {
            return try await fetchCompatibilityRoadmap(baseURL: baseURL, organID: organID, previousETag: previousETag)
        }
    }

    public func fetchCompatibilityRoadmap(baseURL: URL, organID: String, previousETag: String? = nil) async throws -> NavigatorRoadmapProfile? {
        let encodedID = organID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? organID
        let organURL = baseURL.appendingPathComponent("api/organs/\(encodedID)")
        let specURL = baseURL.appendingPathComponent("api/organs/\(encodedID)/specification")
        async let organResult = session.data(from: organURL)
        async let specResult = session.data(from: specURL)
        let ((organData, organResponse), (specData, specResponse)) = try await (organResult, specResult)
        try validate(response: organResponse, data: organData)
        try validate(response: specResponse, data: specData)

        let organJSON = try JSONSerialization.jsonObject(with: organData)
        let specJSON = try JSONSerialization.jsonObject(with: specData)
        let envelope: [String: Any] = [
            "contractVersion": "modavis.navigator.compatibility-profile/v1",
            "organ": organJSON,
            "specification": specJSON,
        ]
        let canonical = try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
        let etag = (specResponse as? HTTPURLResponse)?.value(forHTTPHeaderField: "ETag")
        if previousETag != nil, previousETag == etag { return nil }
        return try Self.decodeProfile(data: canonical, response: specResponse, baseURL: baseURL, endpoint: specURL.path)
    }

    public func fetchTemperamentCatalog(baseURL: URL) async throws -> TemperamentCatalogSnapshot {
        var offset = 0
        let limit = 100
        var total = Int.max
        var entries: [TemperamentCatalogEntry] = []
        var payload = Data()
        var release = "unknown"
        while offset < total {
            var components = URLComponents(url: baseURL.appendingPathComponent("api/temperaments"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "mode", value: "surface"),
                URLQueryItem(name: "limit", value: String(limit)),
                URLQueryItem(name: "offset", value: String(offset)),
            ]
            let (data, response) = try await session.data(from: components.url!)
            try validate(response: response, data: data)
            if let http = response as? HTTPURLResponse,
               let header = http.value(forHTTPHeaderField: "X-MODAVIS-Release"), header.isEmpty == false {
                release = header
            }
            payload.append(data)
            let object = try JSONSerialization.jsonObject(with: data)
            let page = Self.temperamentEntries(in: object)
            entries.append(contentsOf: page)
            let returnedCount = (object as? [String: Any])?["items"] as? [Any]
            if let dictionary = object as? [String: Any] {
                total = Self.intValue(dictionary["total"]) ?? entries.count
            } else {
                total = entries.count
            }
            let consumed = returnedCount?.count ?? page.count
            if consumed == 0 { break }
            offset += consumed
        }
        let unique = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            .values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        guard unique.isEmpty == false else {
            throw OrgRecError.invalidNavigatorResponse("Navigator returned no temperament vectors.")
        }
        return TemperamentCatalogSnapshot(
            navigatorBaseURL: baseURL,
            modavisRelease: release,
            payloadSHA256: payload.sha256Hex,
            totalAvailable: total,
            entries: unique
        )
    }

    public func submit(packageURL: URL, baseURL: URL, packageSHA256: String) async throws -> SyncReceipt {
        let endpoint = baseURL.appendingPathComponent("api/orgrec/v1/submissions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/zip", forHTTPHeaderField: "Content-Type")
        request.setValue(packageSHA256, forHTTPHeaderField: "Idempotency-Key")
        let (data, response) = try await session.upload(for: request, fromFile: packageURL)
        try validate(response: response, data: data)
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return SyncReceipt(
            targetURL: endpoint,
            packageSHA256: packageSHA256,
            idempotencyKey: packageSHA256,
            status: object?["status"] as? String ?? "submitted",
            submissionID: object?["submissionId"] as? String ?? object?["submission_id"] as? String
        )
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let detail = String(data: data.prefix(1024), encoding: .utf8) ?? ""
            throw OrgRecError.invalidNavigatorResponse("Navigator returned HTTP \(http.statusCode). \(detail)")
        }
    }

    private static func decodeProfile(data: Data, response: URLResponse, baseURL: URL, endpoint: String) throws -> NavigatorRoadmapProfile {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let organ = primaryOrganSummary(in: object) else {
            throw OrgRecError.invalidNavigatorResponse("The Navigator profile did not contain an organ identity.")
        }
        let hash = data.sha256Hex
        let http = response as? HTTPURLResponse
        let release = releaseBinding(from: object, response: http)
        let snapshot = MODAVISSnapshot(
            navigatorBaseURL: baseURL,
            endpoint: endpoint,
            eTag: http?.value(forHTTPHeaderField: "ETag"),
            payloadSHA256: hash,
            release: release
        )
        let documentedPitch = documentedPitchStandard(in: object, release: release.requestedRelease)
        var characteristics = specificationCharacteristics(in: object)
        characteristics.referencePitchHz = documentedPitch?.frequencyHz ?? characteristics.referencePitchHz
        let components = extractComponents(
            from: object,
            organ: organ,
            snapshotSHA256: hash,
            referencePitchHz: characteristics.referencePitchHz,
            temperament: characteristics.temperament
        )
        characteristics = enrichedCharacteristics(
            characteristics,
            components: components,
            object: object,
            organ: organ
        )
        let physicalStructure = extractPhysicalStructure(from: object, components: components)
        return NavigatorRoadmapProfile(
            organ: organ,
            snapshot: snapshot,
            components: components,
            rawPayload: data,
            characteristics: characteristics,
            documentedPitchStandard: documentedPitch,
            componentRelationships: physicalStructure.relationships,
            physicalPipeMappings: physicalStructure.mappings
        )
    }

    private static func releaseBinding(from object: Any, response: HTTPURLResponse?) -> ReleaseBinding {
        let dictionaries = allDictionaries(in: object)
        func string(_ keys: [String]) -> String? {
            for dictionary in dictionaries {
                for key in keys {
                    if let value = dictionary[key] as? String, !value.isEmpty { return value }
                }
            }
            return nil
        }
        return ReleaseBinding(
            requestedRelease: response?.value(forHTTPHeaderField: "X-MODAVIS-Release") ?? string(["requestedRelease", "release", "releaseVersion"]) ?? "1.1",
            releaseState: string(["releaseState", "status"]) ?? "release_1_1_enrichment_not_justified",
            canonicalSourceRelease: string(["canonicalSourceRelease", "sourceRelease"]) ?? "1.0",
            protectedFingerprintSHA256: response?.value(forHTTPHeaderField: "X-MODAVIS-Snapshot-SHA256") ?? string(["protectedFingerprintSha256", "protectedFingerprintSHA256"]) ?? ReleaseBinding().protectedFingerprintSHA256,
            navigatorContractVersion: string(["contractVersion"]) ?? "modavis.navigator.compatibility-profile/v1"
        )
    }

    private static func findOrganSummaries(in object: Any) -> [NavigatorOrganSummary] {
        var result: [NavigatorOrganSummary] = []
        for dictionary in allDictionaries(in: object) {
            let id = firstString(in: dictionary, keys: ["mdvsId", "mdvs_id", "organMdvsId", "id"])
            let title = firstString(in: dictionary, keys: ["title", "canonicalLabel", "canonical_label", "name", "label"])
            guard let id, id.hasPrefix("MDVS:"), let title else { continue }
            let summary = NavigatorOrganSummary(
                mdvsID: id,
                title: title,
                location: firstString(in: dictionary, keys: ["location", "venue", "place"]),
                builder: firstString(in: dictionary, keys: ["builder"]),
                dateLabel: firstString(in: dictionary, keys: ["dateLabel", "date"])
            )
            if !result.contains(where: { $0.mdvsID == id }) { result.append(summary) }
        }
        return result
    }

    private static func primaryOrganSummary(in object: Any) -> NavigatorOrganSummary? {
        let dictionaries = allDictionaries(in: object)
        func summary(_ dictionary: [String: Any]) -> NavigatorOrganSummary? {
            let id = firstString(in: dictionary, keys: ["organMdvsId", "organ_mdvs_id", "mdvsId", "mdvs_id", "id"])
            let title = firstString(in: dictionary, keys: ["title", "canonicalLabel", "canonical_label", "name", "label"])
            guard let id, id.hasPrefix("MDVS:"), let title else { return nil }
            return NavigatorOrganSummary(
                mdvsID: id,
                title: title,
                location: firstString(in: dictionary, keys: ["location", "venue", "place"]),
                builder: firstString(in: dictionary, keys: ["builder"]),
                dateLabel: firstString(in: dictionary, keys: ["dateLabel", "date"])
            )
        }
        if let root = object as? [String: Any] {
            for key in ["organ", "entity", "record", "item"] {
                if let dictionary = root[key] as? [String: Any], let result = summary(dictionary) { return result }
            }
            if let result = summary(root),
               result.mdvsID.contains(":ORGN:") || result.mdvsID.contains(":ORGA:") { return result }
        }
        for dictionary in dictionaries {
            let type = firstString(in: dictionary, keys: ["entityType", "entity_type", "instrumentType", "instrument_type", "type", "kind"])?.lowercased() ?? ""
            if type.contains("organ"), let result = summary(dictionary) { return result }
        }
        if let result = dictionaries.compactMap(summary).first(where: {
            $0.mdvsID.contains(":ORGN:") || $0.mdvsID.contains(":ORGA:")
        }) { return result }
        return findOrganSummaries(in: object).first
    }

    static func extractComponents(
        from object: Any,
        organ: NavigatorOrganSummary,
        snapshotSHA256: String,
        referencePitchHz: Double? = nil,
        temperament: String? = nil
    ) -> [OrganComponent] {
        var result: [OrganComponent] = []
        var seen = Set<String>()
        var identityAliases: [String: String] = [:]
        let dictionaries = allDictionaries(in: object)
        for (index, dictionary) in dictionaries.enumerated() {
            guard let rawKind = firstString(in: dictionary, keys: ["kind", "componentType", "component_type", "type"]) else { continue }
            let kind = normalizeKind(rawKind)
            guard [
                "stop", "rank", "pipe_position", "pipe", "coupler", "accessory", "keyboard", "division",
                "tonal_percussion", "atonal_percussion", "percussion", "sustained_effect", "one_shot_effect",
                "repeating_effect", "sequenced_effect", "composite_effect", "sound_effect", "effect", "sounding_element"
            ].contains(kind) else { continue }
            let detail = dictionary["detail"] as? [String: Any] ?? [:]
            let merged = detail.merging(dictionary) { _, outer in outer }
            guard let label = firstString(in: merged, keys: ["label", "name", "title", "stop_name", "raw_str"]), !label.isEmpty else { continue }
            let rawID = firstString(in: merged, keys: ["componentId", "component_id", "id"])
            let candidateMDVS = firstString(in: merged, keys: ["mdvsId", "mdvs_id"])
            let mdvsID = candidateMDVS?.hasPrefix("MDVS:") == true ? candidateMDVS : nil
            let pipeReference = firstString(in: merged, keys: ["derivedReference", "derived_reference", "referenceId", "reference_id"])
            let sourceDictionary = dictionary["source"] as? [String: Any]
            let sourceRecord = firstString(in: merged, keys: ["sourceRecordId", "source_record_id"])
                ?? sourceDictionary.flatMap { firstString(in: $0, keys: ["id", "sourceRecordId"]) }
            let sourcePath = firstString(in: dictionary, keys: ["sourcePath", "source_path"])
            let identity = mdvsID ?? pipeReference ?? rawID ?? "source:\(sourceRecord ?? "unknown"):\(sourcePath ?? String(index))"
            guard seen.insert(identity).inserted else { continue }
            identityAliases[identity] = identity
            if let rawID { identityAliases[rawID] = identity }
            if let candidateMDVS { identityAliases[candidateMDVS] = identity }
            if let pipeReference { identityAliases[pipeReference] = identity }
            let division = firstString(in: merged, keys: ["division", "division_name", "manual", "manual_name", "werk", "work", "department", "groupLabel"]) ?? (kind == "division" || kind == "keyboard" ? label : "Unassigned")
            let midi = intValue(merged["midiNote"] ?? merged["midi_note"] ?? merged["midi"] ?? merged["keyNumber"])
            let frequency = doubleValue(merged["expectedFrequencyHz"] ?? merged["frequency"])
            let footHeight = componentFootHeight(in: merged)
            let playable = playableRange(in: merged, division: division)
            let parentID = firstString(in: merged, keys: ["parentComponentId", "parent_component_id", "stopId", "stop_id", "rankId", "rank_id"])
            let locator = ComponentLocator(
                id: identity,
                organMDVSID: organ.mdvsID,
                canonicalMDVSID: mdvsID,
                pipePositionReference: pipeReference,
                sourceRecordID: sourceRecord,
                sourcePath: sourcePath,
                snapshotSHA256: snapshotSHA256,
                kind: kind,
                label: label,
                trust: mdvsID != nil ? .canonicalMDVS : (pipeReference != nil || kind == "pipe_position" ? .functionalPosition : .sourceBound)
            )
            result.append(OrganComponent(
                id: identity,
                kind: kind,
                label: label,
                division: division,
                footHeight: footHeight,
                noteName: firstString(in: merged, keys: ["noteName", "note_name", "soundingNote", "key"]),
                midiNote: midi,
                expectedFrequencyHz: frequency ?? midi.flatMap {
                    OrganFootage.nominalFrequency(
                        keyMidi: $0,
                        footHeight: footHeight,
                        referencePitchHz: referencePitchHz
                    )
                },
                locator: locator,
                parentComponentID: parentID,
                playableMIDILow: playable?.lowerBound,
                playableMIDIHigh: playable?.upperBound,
                sourceDetails: stringDetails(merged),
                referencePitchHz: referencePitchHz,
                temperament: temperament
            ))
        }
        var rangeByLabel: [String: ClosedRange<Int>] = [:]
        for index in result.indices {
            if let parent = result[index].parentComponentID {
                result[index].parentComponentID = identityAliases[parent] ?? parent
            }
        }
        for component in result where ["division", "keyboard"].contains(component.kind) {
            guard let low = component.playableMIDILow, let high = component.playableMIDIHigh else { continue }
            rangeByLabel[component.label.lowercased(), default: low...high] = low...high
        }
        for index in result.indices where result[index].kind == "stop" && result[index].playableMIDILow == nil {
            let details = result[index].sourceDetails ?? [:]
            let labels = [result[index].division, details["manual"], details["keyboard"]].compactMap { $0?.lowercased() }
            if let range = labels.compactMap({ rangeByLabel[$0] }).first {
                result[index].playableMIDILow = range.lowerBound
                result[index].playableMIDIHigh = range.upperBound
            }
        }
        for index in result.indices {
            result[index].soundingTargetDefinition = RoadmapEngine.soundingTargetDefinition(for: result[index])
        }
        return result
    }

    static func extractPhysicalStructure(
        from object: Any,
        components: [OrganComponent]
    ) -> (relationships: [OrganComponentRelationship], mappings: [PhysicalPipeMapping]) {
        var aliases: [String: String] = [:]
        for component in components {
            aliases[component.id] = component.id
            if let canonical = component.locator.canonicalMDVSID { aliases[canonical] = component.id }
            if let reference = component.locator.pipePositionReference { aliases[reference] = component.id }
            for key in ["id", "componentId", "component_id", "mdvsId", "mdvs_id"] {
                if let raw = component.sourceDetails?[key], raw.isEmpty == false { aliases[raw] = component.id }
            }
        }
        func resolved(_ raw: String?) -> String? {
            guard let raw, raw.isEmpty == false else { return nil }
            return aliases[raw] ?? raw
        }
        func values(_ value: Any?) -> [String] {
            if let string = value as? String { return string.isEmpty ? [] : [string] }
            if let array = value as? [Any] {
                return array.compactMap {
                    if let string = $0 as? String { return string }
                    if let dictionary = $0 as? [String: Any] {
                        return firstString(in: dictionary, keys: ["physicalPipeId", "physical_pipe_id", "pipeComponentId", "pipe_component_id", "pipeId", "pipe_id", "id", "mdvsId"])
                    }
                    return nil
                }
            }
            return []
        }
        var relationships: [OrganComponentRelationship] = []
        var mappings: [PhysicalPipeMapping] = []

        func appendRelationship(source: String, target: String, kind: String, sourcePath: String?, evidence: String?) {
            let normalizedSource = resolved(source) ?? source
            let normalizedTarget = resolved(target) ?? target
            let signature = "\(normalizedSource)|\(kind)|\(normalizedTarget)|\(sourcePath ?? "")"
            relationships.append(OrganComponentRelationship(
                id: "component-relation:\(Data(signature.utf8).sha256Hex)",
                sourceComponentID: normalizedSource,
                targetComponentID: normalizedTarget,
                kind: kind,
                sourcePath: sourcePath,
                evidence: evidence
            ))
        }

        func appendMapping(_ dictionary: [String: Any], inheritedStopID: String? = nil, inheritedPath: String? = nil) {
            let stopID = resolved(firstString(in: dictionary, keys: ["stopComponentId", "stop_component_id", "stopId", "stop_id"]) ?? inheritedStopID)
            let midi = intValue(dictionary["keyMidi"] ?? dictionary["key_midi"] ?? dictionary["midiNote"] ?? dictionary["midi_note"] ?? dictionary["midi"] ?? dictionary["keyNumber"])
            guard let stopID, let midi, (0...127).contains(midi) else { return }
            let rankID = resolved(firstString(in: dictionary, keys: ["rankComponentId", "rank_component_id", "rankId", "rank_id"]))
            let rankPosition = intValue(dictionary["rankPosition"] ?? dictionary["rank_position"] ?? dictionary["pipeNumber"] ?? dictionary["pipe_number"])
            var pipeIDs: [String] = []
            for key in ["physicalPipeComponentIds", "physical_pipe_component_ids", "physicalPipeIds", "physical_pipe_ids", "pipeComponentIds", "pipe_component_ids", "pipeIds", "pipe_ids", "physicalPipeId", "physical_pipe_id", "pipeComponentId", "pipe_component_id", "pipeId", "pipe_id"] {
                pipeIDs.append(contentsOf: values(dictionary[key]).compactMap(resolved))
            }
            pipeIDs = Array(Set(pipeIDs)).sorted()
            let evidence: PhysicalIdentityEvidence
            if pipeIDs.isEmpty, let rankID, let rankPosition {
                pipeIDs = ["rank-position|\(rankID)|\(rankPosition)"]
                evidence = .sharedRankPosition
            } else if firstString(in: dictionary, keys: ["sharedWith", "shared_with", "borrowedFrom", "borrowed_from"]) != nil {
                evidence = .explicitSharedPipe
            } else {
                evidence = pipeIDs.allSatisfy { $0.hasPrefix("MDVS:") } ? .canonicalPipe : .explicitSharedPipe
            }
            guard pipeIDs.isEmpty == false else { return }
            let sourcePath = firstString(in: dictionary, keys: ["sourcePath", "source_path"]) ?? inheritedPath
            let signature = "\(stopID)|\(midi)|\(pipeIDs.joined(separator: "|"))"
            mappings.append(PhysicalPipeMapping(
                id: "pipe-mapping:\(Data(signature.utf8).sha256Hex)",
                stopComponentID: stopID,
                keyMIDI: midi,
                physicalPipeComponentIDs: pipeIDs,
                rankComponentID: rankID,
                rankPosition: rankPosition,
                evidence: evidence,
                sourcePath: sourcePath
            ))
        }

        for dictionary in allDictionaries(in: object) {
            let detail = dictionary["detail"] as? [String: Any] ?? [:]
            let merged = detail.merging(dictionary) { _, outer in outer }
            let componentID = resolved(firstString(in: merged, keys: ["componentId", "component_id", "mdvsId", "mdvs_id", "id"]))
            let sourcePath = firstString(in: dictionary, keys: ["sourcePath", "source_path"])
            if let componentID {
                for (key, kind) in [
                    ("rankComponentId", "uses_rank"), ("rank_component_id", "uses_rank"),
                    ("rankId", "uses_rank"), ("rank_id", "uses_rank"),
                    ("sharedWithComponentId", "shares_pipe_with"), ("shared_with_component_id", "shares_pipe_with"),
                    ("borrowedFromComponentId", "borrowed_from"), ("borrowed_from_component_id", "borrowed_from"),
                    ("extensionOfComponentId", "extension_of"), ("extension_of_component_id", "extension_of")
                ] {
                    if let target = firstString(in: merged, keys: [key]) {
                        appendRelationship(source: componentID, target: target, kind: kind, sourcePath: sourcePath, evidence: key)
                    }
                }
                for key in ["pipeMappings", "pipe_mappings", "physicalPipeMappings", "physical_pipe_mappings", "keyMappings", "key_mappings", "positions"] {
                    if let entries = merged[key] as? [[String: Any]] {
                        for entry in entries { appendMapping(entry, inheritedStopID: componentID, inheritedPath: sourcePath) }
                    }
                }
                let kind = normalizeKind(firstString(in: merged, keys: ["kind", "componentType", "component_type", "type"]) ?? "")
                if kind == "pipe" || kind == "pipe_position" {
                    var mapping = merged
                    if mapping["physicalPipeId"] == nil, kind == "pipe", let canonical = firstString(in: merged, keys: ["mdvsId", "mdvs_id", "componentId", "component_id", "id"]) {
                        mapping["physicalPipeId"] = canonical
                    }
                    appendMapping(mapping, inheritedStopID: firstString(in: merged, keys: ["stopId", "stop_id", "parentComponentId", "parent_component_id"]), inheritedPath: sourcePath)
                }
            }

            let relationKind = firstString(in: dictionary, keys: ["relationshipKind", "relationship_kind", "predicate", "relationType", "relation_type"])
            let relationSource = firstString(in: dictionary, keys: ["sourceComponentId", "source_component_id", "subjectComponentId", "subject_component_id", "fromComponentId", "from_component_id"])
            let relationTarget = firstString(in: dictionary, keys: ["targetComponentId", "target_component_id", "objectComponentId", "object_component_id", "toComponentId", "to_component_id"])
            if let relationKind, let relationSource, let relationTarget {
                appendRelationship(source: relationSource, target: relationTarget, kind: relationKind, sourcePath: sourcePath, evidence: "explicit component relation")
            }
            appendMapping(dictionary)
        }

        relationships = Dictionary(relationships.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.sorted { $0.id < $1.id }
        mappings = Dictionary(mappings.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.sorted { $0.id < $1.id }
        return (relationships, mappings)
    }

    static func specificationCharacteristics(in object: Any) -> OrganSpecificationCharacteristics {
        let dictionaries = allDictionaries(in: object)
        var pitch: Double?
        var temperament: String?
        var manuals: Int?
        var stops: Int?
        var actionType: String?
        var windPressure: String?
        var sourceURLs = Set<String>()
        var sourceRecords = Set<String>()
        for dictionary in dictionaries {
            if pitch == nil {
                for key in ["referencePitchHz", "reference_pitch_hz", "pitch", "pitch_standard", "tuning_pitch"] {
                    if let value = doubleValue(dictionary[key]), (350...550).contains(value) { pitch = value; break }
                    if let text = dictionary[key] as? String {
                        let tokens = text.replacingOccurrences(of: ",", with: ".")
                            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
                        if let value = tokens.compactMap(Double.init).first(where: { (350...550).contains($0) }) {
                            pitch = value
                            break
                        }
                    }
                }
            }
            temperament = temperament ?? firstString(in: dictionary, keys: ["temperament", "tuning_system"])
            manuals = manuals ?? intValue(dictionary["manuals"] ?? dictionary["manual_count"])
            stops = stops ?? intValue(dictionary["stops"] ?? dictionary["stop_count"])
            actionType = actionType ?? firstString(in: dictionary, keys: ["actionType", "action_type", "keyAction", "key_action", "tracture"])
            windPressure = windPressure ?? firstString(in: dictionary, keys: ["windPressure", "wind_pressure", "pressure", "windSystem", "wind_system"])
            for key in ["url", "sourceUrl", "source_url"] {
                if let value = dictionary[key] as? String, value.hasPrefix("http") { sourceURLs.insert(value) }
            }
            if let value = firstString(in: dictionary, keys: ["sourceRecordId", "source_record_id"]) {
                sourceRecords.insert(value)
            }
        }
        return OrganSpecificationCharacteristics(
            referencePitchHz: pitch,
            temperament: temperament,
            manualCount: manuals,
            documentedStopCount: stops,
            actionType: actionType,
            windPressure: windPressure,
            sourceCount: sourceRecords.isEmpty ? (sourceURLs.isEmpty ? nil : sourceURLs.count) : sourceRecords.count,
            sourceURLs: sourceURLs.isEmpty ? nil : sourceURLs.sorted()
        )
    }

    static func temperamentEntries(in object: Any) -> [TemperamentCatalogEntry] {
        let dictionaries: [[String: Any]]
        if let root = object as? [String: Any], let items = root["items"] as? [[String: Any]] {
            dictionaries = items
        } else {
            dictionaries = allDictionaries(in: object).filter { $0["toneOrder"] is [Any] && $0["centValues"] is [Any] }
        }
        return dictionaries.compactMap { dictionary in
            guard let id = firstString(in: dictionary, keys: ["id", "tuningId", "sourceRecordId"]),
                  let title = firstString(in: dictionary, keys: ["title", "label"]) else { return nil }
            let tones = (dictionary["toneOrder"] as? [Any] ?? []).compactMap { $0 as? String }
            let cents = (dictionary["centValues"] as? [Any] ?? []).compactMap(doubleValue)
            guard tones.count >= 8, cents.count >= 8 else { return nil }
            let precision = dictionary["precision"] as? [String: Any]
            let urls = dictionary["urls"] as? [String: Any]
            return TemperamentCatalogEntry(
                id: id,
                title: title,
                label: firstString(in: dictionary, keys: ["label"]),
                groupKey: firstString(in: dictionary, keys: ["groupKey"]),
                groupLabel: firstString(in: dictionary, keys: ["groupLabel", "groupTitle"]),
                isPreciseVariant: precision?["isPreciseVariant"] as? Bool ?? false,
                toneOrder: Array(tones.prefix(cents.count)),
                centValues: Array(cents.prefix(tones.count)),
                sourceRecordID: firstString(in: dictionary, keys: ["sourceRecordId"]),
                sourceURL: firstString(in: dictionary, keys: ["sourceUrl"]).flatMap(URL.init(string:)),
                commentaryURL: firstString(in: dictionary, keys: ["commentaryUrl"]).flatMap(URL.init(string:)),
                navigatorPath: urls.flatMap { firstString(in: $0, keys: ["temperament"]) }
            )
        }
    }

    /// Reads both the Navigator 1.2 technical-evidence envelope and legacy
    /// specification fields. The returned source detail is preserved in OrgRec.
    static func documentedPitchStandard(in object: Any, release: String) -> DocumentedPitchStandard? {
        func parseFrequency(_ value: Any?) -> Double? {
            if let number = doubleValue(value), (350...550).contains(number) { return number }
            guard let text = value as? String else { return nil }
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            let tokens = normalized.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            return tokens.compactMap(Double.init).first(where: { (350...550).contains($0) })
        }

        func technicalEvidence(_ value: Any, path: String) -> DocumentedPitchStandard? {
            if let dictionary = value as? [String: Any] {
                for key in ["technicalEvidence", "technical_evidence"] {
                    if let envelope = dictionary[key] as? [String: Any],
                       let pitch = envelope["pitch"] as? [String: Any] {
                        let preferred = pitch["preferredValue"] ?? pitch["preferred_value"] ?? pitch["value"]
                        if let frequency = parseFrequency(preferred) {
                            let assertion = (pitch["assertions"] as? [[String: Any]])?.first
                            return DocumentedPitchStandard(
                                frequencyHz: frequency,
                                rawValue: (preferred as? String) ?? String(frequency),
                                evidenceStatus: firstString(in: pitch, keys: ["status", "evidenceStatus"]),
                                sourcePath: assertion.flatMap { firstString(in: $0, keys: ["sourcePath", "source_path"]) }
                                    ?? "\(path).\(key).pitch.preferredValue",
                                sourceRecordID: assertion.flatMap { firstString(in: $0, keys: ["sourceRecordId", "source_record_id"]) },
                                modavisRelease: release
                            )
                        }
                    }
                }
                for (key, nested) in dictionary {
                    if let result = technicalEvidence(nested, path: path.isEmpty ? key : "\(path).\(key)") { return result }
                }
            } else if let array = value as? [Any] {
                for (index, nested) in array.enumerated() {
                    if let result = technicalEvidence(nested, path: "\(path)[\(index)]") { return result }
                }
            }
            return nil
        }

        if let result = technicalEvidence(object, path: "root") { return result }
        let pitchKeys = ["referencePitchHz", "reference_pitch_hz", "pitch", "pitch_standard", "tuning_pitch"]
        for dictionary in allDictionaries(in: object) {
            for key in pitchKeys {
                guard let raw = dictionary[key], let frequency = parseFrequency(raw) else { continue }
                return DocumentedPitchStandard(
                    frequencyHz: frequency,
                    rawValue: (raw as? String) ?? String(frequency),
                    sourcePath: key,
                    sourceRecordID: firstString(in: dictionary, keys: ["sourceRecordId", "source_record_id"]),
                    modavisRelease: release
                )
            }
        }
        return nil
    }

    static func enrichedCharacteristics(
        _ base: OrganSpecificationCharacteristics,
        components: [OrganComponent],
        object: Any,
        organ: NavigatorOrganSummary
    ) -> OrganSpecificationCharacteristics {
        let kinds = Dictionary(grouping: components, by: \.kind)
        let namedDivisions = Set(components.filter { $0.kind == "stop" }.map(\.division).filter { $0 != "Unassigned" })
        var result = base
        result.documentedStopCount = result.documentedStopCount ?? kinds["stop"]?.count
        result.divisionCount = kinds["division"]?.count ?? (namedDivisions.isEmpty ? nil : namedDivisions.count)
        result.keyboardCount = kinds["keyboard"]?.count
        result.manualCount = result.manualCount ?? kinds["keyboard"]?.filter {
            $0.label.localizedCaseInsensitiveContains("pedal") == false
        }.count
        result.rankCount = kinds["rank"]?.count
        result.pipePositionCount = (kinds["pipe_position"]?.count ?? 0) + (kinds["pipe"]?.count ?? 0)
        result.couplerCount = kinds["coupler"]?.count
        result.accessoryCount = kinds["accessory"]?.count
        result.builder = organ.builder
        result.buildDateLabel = organ.dateLabel
        if result.builder == nil || result.buildDateLabel == nil {
            for dictionary in allDictionaries(in: object) {
                result.builder = result.builder ?? firstString(in: dictionary, keys: ["builder", "organBuilder", "organ_builder", "maker"])
                result.buildDateLabel = result.buildDateLabel ?? firstString(in: dictionary, keys: ["dateLabel", "buildDate", "build_date", "year", "date"])
            }
        }
        return result
    }

    private static func normalizeKind(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
            .lowercased()
        if normalized == "pipeposition" { return "pipe_position" }
        if normalized == "playing_aid" || normalized == "playingaids" || normalized == "playingaid" { return "accessory" }
        if normalized == "manual" || normalized == "pedal" { return "keyboard" }
        if normalized == "tonalpercussion" || normalized == "tunedpercussion" { return "tonal_percussion" }
        if normalized == "atonalpercussion" || normalized == "untunedpercussion" { return "atonal_percussion" }
        if normalized == "soundeffect" { return "sound_effect" }
        if normalized == "oneshoteffect" { return "one_shot_effect" }
        if normalized == "compositeeffect" { return "composite_effect" }
        return normalized
    }

    private static func playableRange(in dictionary: [String: Any], division: String) -> ClosedRange<Int>? {
        if let quantity = dictionary["pipeQuantity"] as? [String: Any] {
            if let values = quantity["actuationRange"] as? [Any], values.count >= 2,
               let low = intValue(values[0]), let high = intValue(values[1]), low <= high {
                return max(0, low)...min(127, high)
            }
            if let compass = quantity["documentedCompass"] as? String, let parsed = parseCompass(compass) {
                return parsed
            }
            if let count = intValue(quantity["noteCount"]), count > 0 { return 36...min(127, 35 + count) }
        }
        let low = intValue(dictionary["lowestMidi"] ?? dictionary["lowest_midi"] ?? dictionary["midiLow"] ?? dictionary["midi_low"])
        let high = intValue(dictionary["highestMidi"] ?? dictionary["highest_midi"] ?? dictionary["midiHigh"] ?? dictionary["midi_high"])
        if let low, let high, (0...127).contains(low), low <= high { return low...min(127, high) }
        for key in ["midiRange", "midi_range", "range"] {
            if let values = dictionary[key] as? [Any], values.count >= 2,
               let low = intValue(values[0]), let high = intValue(values[1]), low <= high {
                return max(0, low)...min(127, high)
            }
        }
        for key in ["compass", "observed_compass", "keyboard_compass", "range"] {
            if let text = dictionary[key] as? String, let parsed = parseCompass(text) { return parsed }
        }
        if let count = intValue(dictionary["observed_note_count"] ?? dictionary["note_count"] ?? dictionary["notes"]), count > 0 {
            let start = 36
            return start...min(127, start + count - 1)
        }
        return nil
    }

    private static func componentFootHeight(in dictionary: [String: Any]) -> String? {
        if let direct = firstString(in: dictionary, keys: ["footHeight", "foot_height", "pitch", "length", "observed_pitch"]) {
            return direct
        }
        guard let quantity = dictionary["pipeQuantity"] as? [String: Any],
              let nominal = quantity["nominalSoundingPitch"] as? [String: Any],
              let feet = nominal["pitchFeet"] as? [String: Any] else { return nil }
        return firstString(in: feet, keys: ["display", "decimal"])
    }

    private static func parseCompass(_ raw: String) -> ClosedRange<Int>? {
        let normalized = raw.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
        let tokens = normalized.split(separator: "-").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard tokens.count >= 2, let low = organNoteMIDI(tokens[0]), let high = organNoteMIDI(tokens[1]), low <= high else { return nil }
        return low...high
    }

    private static func organNoteMIDI(_ raw: String) -> Int? {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let letter = token.first, "ABCDEFGabcdefg".contains(letter) else { return nil }
        let upper = Character(String(letter).uppercased())
        let semitones: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard var semitone = semitones[upper] else { return nil }
        var remainder = String(token.dropFirst())
        if remainder.first == "#" || remainder.first == "♯" { semitone += 1; remainder.removeFirst() }
        if remainder.first == "b" || remainder.first == "♭" { semitone -= 1; remainder.removeFirst() }
        let digits = remainder.filter(\.isNumber)
        let scientificOctave: Int
        if let written = Int(digits) {
            scientificOctave = letter.isLowercase ? written + 3 : written
        } else {
            scientificOctave = letter.isLowercase ? 3 : 2
        }
        let midi = (scientificOctave + 1) * 12 + semitone
        return (0...127).contains(midi) ? midi : nil
    }

    private static func stringDetails(_ dictionary: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in dictionary where key != "detail" && key != "source" && key != "componentRelations" {
            if let string = value as? String { result[key] = string }
            else if let number = value as? NSNumber { result[key] = number.stringValue }
            else if JSONSerialization.isValidJSONObject(value),
                    let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
                    let string = String(data: data, encoding: .utf8), string.count <= 2_048 {
                result[key] = string
            }
        }
        return result
    }

    private static func allDictionaries(in object: Any) -> [[String: Any]] {
        var result: [[String: Any]] = []
        func visit(_ value: Any) {
            if let dictionary = value as? [String: Any] {
                result.append(dictionary)
                dictionary.values.forEach(visit)
            } else if let array = value as? [Any] {
                array.forEach(visit)
            }
        }
        visit(object)
        return result
    }

    private static func firstString(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let string = dictionary[key] as? String, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return string }
            if let number = dictionary[key] as? NSNumber { return number.stringValue }
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }
}
