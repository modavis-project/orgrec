import CryptoKit
import Foundation

public enum OrgRecError: LocalizedError, Sendable {
    case invalidProject(String)
    case invalidNavigatorResponse(String)
    case missingResource(String)
    case unsupportedAudio(String)
    case exportValidation(String)

    public var errorDescription: String? {
        switch self {
        case .invalidProject(let message), .invalidNavigatorResponse(let message), .unsupportedAudio(let message), .exportValidation(let message):
            message
        case .missingResource(let name):
            "Missing bundled resource: \(name)"
        }
    }
}

public extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }

    func appendToFile(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: self)
    }
}

public func sha256(of url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while true {
        let data = try handle.read(upToCount: 1_048_576) ?? Data()
        if data.isEmpty { break }
        hasher.update(data: data)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
}

public enum OrgRecCoding {
    public static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    public static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Deterministic single-line JSON used by package JSONL manifests.
    public static let lineEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

public func isSafePackageRelativePath(_ path: String) -> Bool {
    guard path.isEmpty == false, path.hasPrefix("/") == false else { return false }
    let components = NSString(string: path).pathComponents
    return components.contains("..") == false && components.contains("~") == false
}

/// Resolves a retained package-relative path without allowing an existing
/// symbolic link in any component to redirect access outside the package.
/// The lexical check remains necessary for paths whose final payload has not
/// been created yet; the resolved check protects existing package contents.
func validatedPackageRelativeURL(_ path: String, in packageURL: URL) throws -> URL {
    guard isSafePackageRelativePath(path) else {
        throw OrgRecError.invalidProject("Unsafe package-relative path: \(path)")
    }

    let lexicalRoot = packageURL.standardizedFileURL
    let candidate = lexicalRoot.appendingPathComponent(path).standardizedFileURL
    guard candidate.isStrictDescendant(of: lexicalRoot) else {
        throw OrgRecError.invalidProject("Package-relative path escapes the project package: \(path)")
    }

    // `resolvingSymlinksInPath()` may leave an unresolved tail untouched when
    // its final payload does not exist yet. Inspect every existing component as
    // well, so a symlinked parent cannot hide an escaping future artifact.
    var componentURL = lexicalRoot
    for component in NSString(string: path).pathComponents where component != "." {
        componentURL.appendPathComponent(component)
        if (try? componentURL.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            throw OrgRecError.invalidProject("Package-relative path uses a symbolic link: \(path)")
        }
    }

    let resolvedRoot = lexicalRoot.resolvingSymlinksInPath()
    let resolvedCandidate = candidate.resolvingSymlinksInPath()
    guard resolvedCandidate.isStrictDescendant(of: resolvedRoot) else {
        throw OrgRecError.invalidProject("Package-relative path resolves outside the project package through a symbolic link: \(path)")
    }
    return candidate
}

private extension URL {
    func isStrictDescendant(of directory: URL) -> Bool {
        let rootComponents = directory.standardizedFileURL.pathComponents
        let candidateComponents = standardizedFileURL.pathComponents
        guard candidateComponents.count > rootComponents.count else { return false }
        return zip(rootComponents, candidateComponents).allSatisfy { $0.0 == $0.1 }
    }
}

public func midiFrequency(_ note: Int, a4: Double = 440) -> Double {
    a4 * pow(2, Double(note - 69) / 12)
}

public func centsDifference(measured: Double, expected: Double) -> Double? {
    guard measured > 0, expected > 0 else { return nil }
    return 1200 * log2(measured / expected)
}

public func safeFilename(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
        .replacingOccurrences(of: "--", with: "-")
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
}
