import Foundation

/// The import boundary for the separately published, highly reduced MODAVIS
/// Pipe Organ Dataset subset. OrgRec does not assign dataset identifiers: the
/// final record must provide the identifiers and checksums minted by its
/// dataset release.
public enum PODSubsetContract {
    public static let version = "orgrec-pod-subset/1"
    public static let manifestFilename = "pod-subset-manifest.json"
    public static let expectedSourceReleaseVersion = "1.5"
}

public struct PODSubsetManifest: Codable, Hashable, Sendable {
    public var contractVersion: String
    public var publicationStatus: String
    public var dataset: PODSubsetDatasetIdentity
    public var source: PODSubsetSourceIdentity
    public var selection: PODSubsetSelection
    public var createdAt: String
    public var creators: [PODSubsetAgent]
    public var files: [PODSubsetFile]
}

public struct PODSubsetDatasetIdentity: Codable, Hashable, Sendable {
    public var identifier: String
    public var title: String
    public var version: String
    public var persistentIdentifier: String?
    public var license: String
    public var attribution: String
}

public struct PODSubsetSourceIdentity: Codable, Hashable, Sendable {
    public var title: String
    public var releaseVersion: String
    public var versionIdentifier: String?
    public var manifestSHA256: String?
}

public struct PODSubsetSelection: Codable, Hashable, Sendable {
    public var protocolIdentifier: String
    public var purpose: String
    public var method: String
    public var criteria: [String]
    public var sourceCodeCommit: String?
    public var seed: String?
    public var fileCount: Int
    public var sourceItemCount: Int
    public var instrumentCount: Int
    public var byteSize: Int64
}

public struct PODSubsetAgent: Codable, Hashable, Sendable {
    public var name: String
    public var identifier: String?
    public var role: String
}

public struct PODSubsetFile: Codable, Hashable, Sendable {
    public var id: String
    public var sourceItemIdentifier: String
    public var sourceRelativePath: String
    public var path: String
    public var role: String
    public var mediaType: String
    public var byteSize: Int64
    public var sha256: String
    public var instrumentIdentifier: String?
    public var divisionIdentifier: String?
    public var rankIdentifier: String?
    public var stopName: String?
    public var midiNote: Int?
    public var channel: Int?
    public var takeIdentifier: String?
    public var transformation: PODSubsetTransformation
}

public struct PODSubsetTransformation: Codable, Hashable, Sendable {
    public var activity: String
    public var parameters: [String: String]
}

public struct PODSubsetInspection: Codable, Hashable, Sendable {
    public var manifest: PODSubsetManifest?
    public var errors: [String]
    public var verifiedFileCount: Int
    public var verifiedBytes: Int64

    public var isValid: Bool { errors.isEmpty && manifest != nil }
}

public enum PODSubsetValidator {
    private static let productionStatus = "published-subset"
    private static let fixtureStatus = "synthetic-fixture"

    public static func inspect(directory: URL) throws -> PODSubsetInspection {
        let root = directory.standardizedFileURL.resolvingSymlinksInPath()
        var rootIsDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &rootIsDirectory), rootIsDirectory.boolValue else {
            throw OrgRecError.invalidProject("The POD subset source is not a directory.")
        }
        let manifestURL = root.appendingPathComponent(PODSubsetContract.manifestFilename)
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return PODSubsetInspection(
                manifest: nil,
                errors: ["Missing \(PODSubsetContract.manifestFilename)."],
                verifiedFileCount: 0,
                verifiedBytes: 0
            )
        }
        let manifestData = try Data(contentsOf: manifestURL, options: [.mappedIfSafe])
        let manifest: PODSubsetManifest
        do {
            manifest = try OrgRecCoding.decoder.decode(PODSubsetManifest.self, from: manifestData)
        } catch {
            return PODSubsetInspection(
                manifest: nil,
                errors: ["The POD subset manifest cannot be decoded: \(error.localizedDescription)"],
                verifiedFileCount: 0,
                verifiedBytes: 0
            )
        }

        var errors = validateMetadata(manifest, data: manifestData)
        var verifiedFileCount = 0
        var verifiedBytes: Int64 = 0
        let duplicateIDs = duplicateValues(manifest.files.map(\.id))
        let duplicatePaths = duplicateValues(manifest.files.map(\.path))
        if !duplicateIDs.isEmpty { errors.append("Duplicate file identifiers: \(duplicateIDs.joined(separator: ", ")).") }
        if !duplicatePaths.isEmpty { errors.append("Duplicate subset paths: \(duplicatePaths.joined(separator: ", ")).") }

        var declaredPaths = Set<String>()
        for file in manifest.files {
            guard isSafePackageRelativePath(file.path), file.path != PODSubsetContract.manifestFilename else {
                errors.append("Unsafe or reserved subset path: \(file.path).")
                continue
            }
            guard isSafePackageRelativePath(file.sourceRelativePath) else {
                errors.append("Unsafe source-relative path for \(file.id).")
                continue
            }
            declaredPaths.insert(file.path)
            if file.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                file.sourceItemIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("Every subset file requires stable subset and source identifiers.")
            }
            if !isAbsoluteIdentifier(file.id) || !isAbsoluteIdentifier(file.sourceItemIdentifier) {
                errors.append("File \(file.path) requires absolute subset and source identifiers.")
            }
            if file.role.isEmpty || file.mediaType.range(of: "^[^/\\s]+/[^/\\s]+$", options: .regularExpression) == nil {
                errors.append("File \(file.id) requires a role and valid media type.")
            }
            if file.byteSize < 0 { errors.append("File \(file.id) has a negative byte size.") }
            if !isSHA256(file.sha256) { errors.append("File \(file.id) has an invalid SHA-256 digest.") }
            if file.transformation.activity.isEmpty { errors.append("File \(file.id) is missing its transformation activity.") }
            do {
                let fileURL = try validatedPackageRelativeURL(file.path, in: root)
                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else {
                    errors.append("Declared path is not a regular non-symbolic file: \(file.path).")
                    continue
                }
                let actualSize = Int64(values.fileSize ?? -1)
                guard actualSize == file.byteSize else {
                    errors.append("Byte-size mismatch for \(file.path).")
                    continue
                }
                guard try sha256(of: fileURL) == file.sha256 else {
                    errors.append("SHA-256 mismatch for \(file.path).")
                    continue
                }
                verifiedFileCount += 1
                let (newTotal, overflow) = verifiedBytes.addingReportingOverflow(actualSize)
                if overflow {
                    errors.append("Verified POD byte total exceeds Int64.")
                    continue
                }
                verifiedBytes = newTotal
            } catch {
                errors.append("Cannot verify \(file.path): \(error.localizedDescription)")
            }
        }

        let actualPaths = try regularFilePaths(in: root).subtracting([PODSubsetContract.manifestFilename])
        let extraPaths = actualPaths.subtracting(declaredPaths).sorted()
        let missingPaths = declaredPaths.subtracting(actualPaths).sorted()
        if !extraPaths.isEmpty { errors.append("Undeclared files are present: \(extraPaths.joined(separator: ", ")).") }
        if !missingPaths.isEmpty { errors.append("Declared files are missing: \(missingPaths.joined(separator: ", ")).") }
        if manifest.selection.fileCount != manifest.files.count {
            errors.append("selection.fileCount does not equal the frozen file inventory.")
        }
        if manifest.selection.sourceItemCount != Set(manifest.files.map(\.sourceItemIdentifier)).count {
            errors.append("selection.sourceItemCount does not equal the frozen source-item inventory.")
        }
        var declaredBytes: Int64 = 0
        var byteOverflow = false
        for file in manifest.files {
            let result = declaredBytes.addingReportingOverflow(file.byteSize)
            declaredBytes = result.partialValue
            byteOverflow = byteOverflow || result.overflow
        }
        if byteOverflow || manifest.selection.byteSize != declaredBytes {
            errors.append("selection.byteSize does not equal the declared byte total.")
        }

        return PODSubsetInspection(
            manifest: manifest,
            errors: Array(Set(errors)).sorted(),
            verifiedFileCount: verifiedFileCount,
            verifiedBytes: verifiedBytes
        )
    }

    private static func validateMetadata(_ manifest: PODSubsetManifest, data: Data) -> [String] {
        var errors: [String] = []
        if manifest.contractVersion != PODSubsetContract.version {
            errors.append("Unsupported POD subset contract \(manifest.contractVersion).")
        }
        if manifest.publicationStatus != productionStatus && manifest.publicationStatus != fixtureStatus {
            errors.append("publicationStatus must be published-subset or synthetic-fixture.")
        }
        if manifest.source.releaseVersion != PODSubsetContract.expectedSourceReleaseVersion {
            errors.append("The subset must pin MODAVIS POD Release 1.5 exactly.")
        }
        if manifest.source.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("The source dataset title is required.")
        }
        if !isAbsoluteIdentifier(manifest.dataset.identifier) || manifest.dataset.title.isEmpty || manifest.dataset.version.isEmpty {
            errors.append("The derivative dataset requires its own identifier, title, and version.")
        }
        if !isAbsoluteIdentifier(manifest.dataset.license) {
            errors.append("The derivative dataset license must be an absolute identifier.")
        }
        if manifest.dataset.attribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("The derivative dataset requires an attribution statement.")
        }
        if !isAbsoluteIdentifier(manifest.selection.protocolIdentifier) || manifest.selection.purpose.isEmpty || manifest.selection.method.isEmpty {
            errors.append("The selection protocol, purpose, and method are required.")
        }
        if manifest.selection.criteria.isEmpty || manifest.selection.criteria.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) || manifest.creators.isEmpty || manifest.files.isEmpty {
            errors.append("Selection criteria, creators, and a frozen file inventory are required.")
        }
        if manifest.selection.fileCount <= 0 || manifest.selection.sourceItemCount <= 0 || manifest.selection.instrumentCount <= 0 || manifest.selection.byteSize < 0 {
            errors.append("Selection aggregate counts must be positive and its byte size non-negative.")
        }
        if !isISO8601(manifest.createdAt) {
            errors.append("createdAt must be an ISO 8601 timestamp.")
        }
        if manifest.creators.contains(where: { $0.name.isEmpty || $0.role.isEmpty || ($0.identifier != nil && !isAbsoluteIdentifier($0.identifier)) }) {
            errors.append("Every creator requires a name and role; supplied identifiers must be absolute.")
        }
        if manifest.publicationStatus == productionStatus {
            if !isAbsoluteIdentifier(manifest.dataset.persistentIdentifier) {
                errors.append("A published subset must pin its version-specific persistent identifier.")
            }
            if !isAbsoluteIdentifier(manifest.source.versionIdentifier) {
                errors.append("A published subset must pin the source Release 1.5 version identifier.")
            }
            if !isSHA256(manifest.source.manifestSHA256) {
                errors.append("A published subset must pin the source Release 1.5 manifest digest.")
            }
            if manifest.selection.sourceCodeCommit?.isEmpty != false {
                errors.append("A published subset must pin the selection implementation commit.")
            }
        } else if manifest.dataset.persistentIdentifier != nil || manifest.source.versionIdentifier != nil {
            errors.append("The synthetic fixture must not impersonate a published dataset identifier.")
        }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let allowed = Set(["contractVersion", "publicationStatus", "dataset", "source", "selection", "createdAt", "creators", "files"])
            let unknown = Set(object.keys).subtracting(allowed).sorted()
            if !unknown.isEmpty { errors.append("Unknown top-level manifest fields: \(unknown.joined(separator: ", ")).") }
            checkKeys(object["dataset"], allowed: ["identifier", "title", "version", "persistentIdentifier", "license", "attribution"], at: "dataset", errors: &errors)
            checkKeys(object["source"], allowed: ["title", "releaseVersion", "versionIdentifier", "manifestSHA256"], at: "source", errors: &errors)
            checkKeys(object["selection"], allowed: ["protocolIdentifier", "purpose", "method", "criteria", "sourceCodeCommit", "seed", "fileCount", "sourceItemCount", "instrumentCount", "byteSize"], at: "selection", errors: &errors)
            if let creators = object["creators"] as? [[String: Any]] {
                for (index, creator) in creators.enumerated() {
                    checkKeys(creator, allowed: ["name", "identifier", "role"], at: "creators[\(index)]", errors: &errors)
                }
            }
            if let files = object["files"] as? [[String: Any]] {
                let fileKeys = Set(["id", "sourceItemIdentifier", "sourceRelativePath", "path", "role", "mediaType", "byteSize", "sha256", "instrumentIdentifier", "divisionIdentifier", "rankIdentifier", "stopName", "midiNote", "channel", "takeIdentifier", "transformation"])
                for (index, file) in files.enumerated() {
                    checkKeys(file, allowed: fileKeys, at: "files[\(index)]", errors: &errors)
                    checkKeys(file["transformation"], allowed: ["activity", "parameters"], at: "files[\(index)].transformation", errors: &errors)
                }
            }
        }
        return errors
    }

    private static func isSHA256(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    }

    private static func isAbsoluteIdentifier(_ value: String?) -> Bool {
        guard let value, let components = URLComponents(string: value), let scheme = components.scheme else { return false }
        return !scheme.isEmpty
    }

    private static func isISO8601(_ value: String) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if formatter.date(from: value) != nil { return true }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value) != nil
    }

    private static func checkKeys(
        _ value: Any?,
        allowed: Set<String>,
        at path: String,
        errors: inout [String]
    ) {
        guard let object = value as? [String: Any] else { return }
        let unknown = Set(object.keys).subtracting(allowed).sorted()
        if !unknown.isEmpty { errors.append("Unknown fields at \(path): \(unknown.joined(separator: ", ")).") }
    }

    private static func duplicateValues(_ values: [String]) -> [String] {
        Dictionary(grouping: values, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
    }

    private static func regularFilePaths(in root: URL) throws -> Set<String> {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: []
        ) else { throw OrgRecError.invalidProject("The POD subset directory cannot be enumerated.") }
        var paths = Set<String>()
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                throw OrgRecError.invalidProject("The POD subset contains a symbolic link: \(url.lastPathComponent).")
            }
            guard values.isRegularFile == true else { continue }
            let resolvedRootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
            let rootPath = resolvedRootPath.hasSuffix("/") ? resolvedRootPath : resolvedRootPath + "/"
            let filePath = url.standardizedFileURL.resolvingSymlinksInPath().path
            guard filePath.hasPrefix(rootPath) else { throw OrgRecError.invalidProject("A POD path escapes its root.") }
            paths.insert(String(filePath.dropFirst(rootPath.count)))
        }
        return paths
    }
}

public actor PODSubsetImporter {
    public init() {}

    @discardableResult
    public func importVerifiedSubset(from source: URL, to destination: URL) throws -> PODSubsetInspection {
        let inspection = try PODSubsetValidator.inspect(directory: source)
        guard inspection.isValid, let manifest = inspection.manifest else {
            throw OrgRecError.invalidProject("POD subset validation failed: " + inspection.errors.prefix(3).joined(separator: "; "))
        }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else {
            throw OrgRecError.invalidProject("The POD subset destination already exists.")
        }
        let parent = destination.deletingLastPathComponent()
        try manager.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appendingPathComponent(".orgrec-pod-import-\(UUID().uuidString)", isDirectory: true)
        do {
            try manager.createDirectory(at: staging, withIntermediateDirectories: false)
            let manifestSource = source.appendingPathComponent(PODSubsetContract.manifestFilename)
            try manager.copyItem(at: manifestSource, to: staging.appendingPathComponent(PODSubsetContract.manifestFilename))
            for file in manifest.files {
                let sourceFile = try validatedPackageRelativeURL(file.path, in: source)
                let targetFile = try validatedPackageRelativeURL(file.path, in: staging)
                try manager.createDirectory(at: targetFile.deletingLastPathComponent(), withIntermediateDirectories: true)
                try manager.copyItem(at: sourceFile, to: targetFile)
            }
            let stagedInspection = try PODSubsetValidator.inspect(directory: staging)
            guard stagedInspection.isValid else {
                throw OrgRecError.invalidProject("The staged POD subset failed verification.")
            }
            try manager.moveItem(at: staging, to: destination)
            return stagedInspection
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }
    }
}
