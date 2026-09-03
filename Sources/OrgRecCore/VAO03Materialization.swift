import Foundation

public struct VAO03MaterializationPlan: Sendable, Equatable {
    public var requestedGroupIds: [String]
    public var expandedGroupIds: [String]
    public var realizationIds: [String]
    public var embeddedRealizationIds: [String]
    public var remoteRealizationIds: [String]
    public var totalByteSize: Int64
}

public enum VAO03MaterializationError: Error, LocalizedError, Equatable {
    case invalidManifest([String])
    case unknownGroup(String)
    case unsupportedCapabilities(groupId: String, capabilities: [String])
    case selectionConflict(selectionSetId: String, groupIds: [String])
    case unavailableRealization(String)
    case aggregateByteSizeOverflow
    case byteLimitExceeded(expected: Int64, limit: Int64)

    public var errorDescription: String? {
        switch self {
        case .invalidManifest(let errors): "Invalid VAO 0.3 manifest: \(errors.prefix(3).joined(separator: "; "))"
        case .unknownGroup(let id): "Unknown VAO asset group: \(id)"
        case .unsupportedCapabilities(let id, let capabilities): "Asset group \(id) requires unsupported capabilities: \(capabilities.joined(separator: ", "))"
        case .selectionConflict(let set, let ids): "Selection set \(set) has conflicting groups: \(ids.joined(separator: ", "))"
        case .unavailableRealization(let id): "Realization \(id) is neither embedded nor remotely distributed."
        case .aggregateByteSizeOverflow: "Materialization size exceeds the supported 64-bit byte count."
        case .byteLimitExceeded(let expected, let limit): "Materialization requires \(expected) bytes, above limit \(limit)."
        }
    }
}

public enum VAO03MaterializationPlanner {
    /// Produces a side-effect-free acquisition plan. Repository selection,
    /// trust, credentials, downloads, and cache mutation remain adapter/runtime
    /// responsibilities and never come from the manifest.
    public static func plan(
        manifest: VAO03Manifest,
        carrier: VAO03Carrier,
        requestedGroupIds: [String],
        supportedCapabilities: Set<String>,
        maximumBytes: Int64? = nil
    ) throws -> VAO03MaterializationPlan {
        let validation = VAO03Validator.validateManifest(manifest)
        guard validation.isEmpty else { throw VAO03MaterializationError.invalidManifest(validation) }
        let groups = manifest.assetGroups.reduce(into: [String: VAO03AssetGroup]()) { result, group in
            if result[group.id] == nil { result[group.id] = group }
        }
        let realizations = manifest.realizations.reduce(into: [String: VAO03Realization]()) { result, realization in
            if result[realization.id] == nil { result[realization.id] = realization }
        }
        var expanded = Set<String>()
        func include(_ groupID: String) throws {
            guard let group = groups[groupID] else { throw VAO03MaterializationError.unknownGroup(groupID) }
            if expanded.insert(groupID).inserted {
                let missing = Set(group.requiredCapabilities).subtracting(supportedCapabilities)
                if !missing.isEmpty { throw VAO03MaterializationError.unsupportedCapabilities(groupId: groupID, capabilities: missing.sorted()) }
                for dependency in group.dependsOnGroupIds { try include(dependency) }
            }
        }
        for id in requestedGroupIds { try include(id) }

        let expandedGroups = expanded.compactMap { groups[$0] }
        for (selectionSet, members) in Dictionary(grouping: expandedGroups, by: \.selectionSetId) {
            let constrained = members.filter { $0.selectionPolicy != "independent" }
            if constrained.count > 1 {
                throw VAO03MaterializationError.selectionConflict(selectionSetId: selectionSet, groupIds: constrained.map(\.id).sorted())
            }
        }
        let realizationIDs = Set(expandedGroups.flatMap(\.realizationIds))
        let embedded = Set(carrier.embeddedRealizations.map(\.realizationId)).intersection(realizationIDs)
        var remote = Set<String>()
        var total: Int64 = 0
        for id in realizationIDs.sorted() {
            guard let realization = realizations[id] else { throw VAO03MaterializationError.unavailableRealization(id) }
            let addition = total.addingReportingOverflow(realization.byteSize)
            guard !addition.overflow else { throw VAO03MaterializationError.aggregateByteSizeOverflow }
            total = addition.partialValue
            if !embedded.contains(id) {
                guard !realization.distributionIds.isEmpty else { throw VAO03MaterializationError.unavailableRealization(id) }
                remote.insert(id)
            }
        }
        if let maximumBytes, total > maximumBytes { throw VAO03MaterializationError.byteLimitExceeded(expected: total, limit: maximumBytes) }
        return VAO03MaterializationPlan(
            requestedGroupIds: requestedGroupIds,
            expandedGroupIds: expanded.sorted(),
            realizationIds: realizationIDs.sorted(),
            embeddedRealizationIds: embedded.sorted(),
            remoteRealizationIds: remote.sorted(),
            totalByteSize: total
        )
    }
}
