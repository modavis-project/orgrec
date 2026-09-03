import Foundation

/// Immutable identifiers and required profiles from the final VAO 0.5.0 release.
public enum VAO05Contract {
    public static let formatVersion = "0.5.0"
    public static let mediaType = "application/vnd.modavis.vao+zip"
    public static let manifestFilename = "vao-manifest.json"
    public static let carrierFilename = "META-INF/vao-carrier.json"
    public static let baseURI = "https://w3id.org/modavis/vao/0.5.0"
    public static let schemaURI = baseURI + "/schema/manifest.json"
    public static let carrierSchemaURI = baseURI + "/schema/carrier.json"
    public static let contextURI = baseURI + "/context.jsonld"
    public static let coreProfile = "https://w3id.org/modavis/vao/profile/core/0.5.0"
    public static let dynamicDeliveryProfile = "https://w3id.org/modavis/vao/profile/dynamic-delivery/0.5.0"
    public static let scientificProfile = "https://w3id.org/modavis/vao/profile/scientific/0.5.0"
    public static let specificationDOI = "10.5281/zenodo.22214248"
    public static let releaseCommit = "ad2d4f0"
    public static let releaseBundleSHA256 = "d98cd8453a776217d9e7bd457ea50e5be087e04f1db36869b9935806e84c15b8"
}

/// A lossless typed envelope for the VAO 0.5.0 core. Registries that OrgRec
/// does not execute remain as JSON values, so unknown profile records survive
/// decoding without being mistaken for capabilities implemented by OrgRec.
public struct VAO05Manifest: Codable, Sendable, Equatable {
    public var schema: String
    public var context: [String]
    public var type: String
    public var formatVersion: String
    public var id: String
    public var release: VAO03ReleaseIdentity
    public var createdAt: String
    public var modifiedAt: String
    public var title: [String: String]
    public var description: [String: String]?
    public var conformsTo: [String]
    public var profiles: [VAO03Profile]
    public var materializableProfiles: [VAO03MaterializableProfile]
    public var modavisBinding: VAO03ModavisBinding
    public var primaryEntityId: String
    public var focusEntityIds: [String]
    public var entities: [VAO03Entity]
    public var relations: [VAOJSONValue]
    public var scientific: VAOJSONValue
    public var multimodal: VAOJSONValue
    public var physicalSystem: VAOJSONValue
    public var runtime: VAOJSONValue
    public var discovery: VAOJSONValue
    public var acoustics: VAOJSONValue?
    public var playable: VAOJSONValue?
    public var interactionModel: VAOJSONValue?
    public var captureDocumentation: VAOJSONValue?
    public var logicalAssets: [VAO03LogicalAsset]
    public var realizations: [VAO05Realization]
    public var distributions: [VAOJSONValue]
    public var repositoryBindings: [VAOJSONValue]
    public var assetGroups: [VAO03AssetGroup]
    public var rights: [VAO05Rights]
    public var integrity: VAOJSONValue
    public var extensions: [String: VAOJSONValue]?

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case context = "@context"
        case type, formatVersion, id, release, createdAt, modifiedAt, title, description
        case conformsTo, profiles, materializableProfiles, modavisBinding, primaryEntityId, focusEntityIds
        case entities, relations, scientific, multimodal, physicalSystem, runtime, discovery
        case acoustics, playable, interactionModel, captureDocumentation
        case logicalAssets, realizations, distributions, repositoryBindings, assetGroups, rights, integrity, extensions
    }
}

public struct VAO05Realization: Codable, Sendable, Equatable {
    public var id: String
    public var type: String
    public var assetId: String
    public var variantSetId: String
    public var qualityTier: String
    public var mediaType: String
    public var byteSize: Int64
    public var sha256: String
    public var representationStatus: String
    public var rightsIds: [String]
    public var provenanceIds: [String]
    public var technicalMetadata: VAOJSONValue
    public var distributionIds: [String]
    public var contentDigests: [VAO04ContentDigest]?
    public var extensions: [String: VAOJSONValue]?
}

public struct VAO05Rights: Codable, Sendable, Equatable {
    public var id: String
    public var appliesToIds: [String]
    public var license: String?
    public var statement: [String: String]
    public var access: String
    public var attribution: String?
    public var privacyClassification: String?
}

public struct VAO05Carrier: Codable, Sendable, Equatable {
    public var schema: String
    public var type: String
    public var formatVersion: String
    public var id: String
    public var releaseId: String
    public var manifestSHA256: String
    public var manifestByteSize: Int64
    public var carrierMode: String
    public var embeddedRealizations: [VAO03CarrierMapping]
    public var completeGroupIds: [String]

    public init(
        schema: String = VAO05Contract.carrierSchemaURI,
        type: String = "VAOCarrier",
        formatVersion: String = VAO05Contract.formatVersion,
        id: String,
        releaseId: String,
        manifestSHA256: String,
        manifestByteSize: Int64,
        carrierMode: String,
        embeddedRealizations: [VAO03CarrierMapping],
        completeGroupIds: [String]
    ) {
        self.schema = schema
        self.type = type
        self.formatVersion = formatVersion
        self.id = id
        self.releaseId = releaseId
        self.manifestSHA256 = manifestSHA256
        self.manifestByteSize = manifestByteSize
        self.carrierMode = carrierMode
        self.embeddedRealizations = embeddedRealizations
        self.completeGroupIds = completeGroupIds
    }

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case type, formatVersion, id, releaseId, manifestSHA256, manifestByteSize
        case carrierMode, embeddedRealizations, completeGroupIds
    }
}

public extension VAOFormatDispatcher {
    static func decode05(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> VAO05Manifest {
        try decoder.decode(VAO05Manifest.self, from: data)
    }
}
