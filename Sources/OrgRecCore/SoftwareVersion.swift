import Foundation

public struct OrgRecSoftwareMetadata: Codable, Hashable, Sendable {
    public var name: String
    public var version: String
    public var build: String
    public var identifier: String

    public init(name: String, version: String, build: String, identifier: String) {
        self.name = name
        self.version = version
        self.build = build
        self.identifier = identifier
    }

    public var displayName: String { "\(name) \(version) (\(build))" }
}

public enum OrgRecSoftware {
    public static let name = "OrgRec"
    public static let version = "0.3.2"
    public static let build = "13"
    public static let identifier = "org.modavis.OrgRec"
    public static let current = OrgRecSoftwareMetadata(
        name: name,
        version: version,
        build: build,
        identifier: identifier
    )
}
