import Foundation

/// The VAO 0.3 line is intentionally separate from `VAOContract` (0.2.2).
/// Readers dispatch by `formatVersion`; existing 0.2 models remain unchanged.
public enum VAO03Contract {
    public static let formatVersion = "0.3.3"
    public static let spatialProfile = "https://w3id.org/modavis/vao/profile/spatial/0.3"
    public static let acousticsProfile = "https://w3id.org/modavis/vao/profile/acoustics/0.3"
    public static let playableProfile = "https://w3id.org/modavis/vao/profile/playable/0.3"
    public static let mediaType = "application/vnd.modavis.vao+zip"
    public static let manifestFilename = "vao-manifest.json"
    public static let carrierFilename = "META-INF/vao-carrier.json"
    public static let schemaURI = "https://w3id.org/modavis/vao/0.3/schema/manifest.json"
    public static let releaseSchemaURI = "https://w3id.org/modavis/vao/0.3/schema/release.json"
    public static let zenodoMetadataSchemaURI = "https://w3id.org/modavis/vao/0.3/schema/zenodo-metadata.json"
    public static let contextURI = "https://w3id.org/modavis/vao/0.3/context.jsonld"
    public static let coreProfile = "https://w3id.org/modavis/vao/profile/core/0.3"
    public static let dynamicDeliveryProfile = "https://w3id.org/modavis/vao/profile/dynamic-delivery/0.3"
    public static let zenodoProfile = "https://w3id.org/modavis/vao/profile/repository/zenodo/0.3"
    public static let zenodoRepositoryType = "https://w3id.org/modavis/vao/repository/zenodo"
}

public struct VAO03Manifest: Codable, Sendable, Equatable {
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
    public var relations: [VAO03Relation]
    public var paradata: [VAOJSONValue]
    public var analyses: [VAOJSONValue]
    public var acoustics: VAOJSONValue?
    public var playable: VAO03Playable?
    public var interactionModel: VAO03InteractionModel?
    public var captureDocumentation: VAO03CaptureDocumentation?
    public var logicalAssets: [VAO03LogicalAsset]
    public var realizations: [VAO03Realization]
    public var distributions: [VAO03Distribution]
    public var repositoryBindings: [VAO03RepositoryBinding]
    public var assetGroups: [VAO03AssetGroup]
    public var rights: [VAO03Rights]
    public var integrity: VAO03Integrity
    public var extensions: [String: VAOJSONValue]?

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case context = "@context"
        case type, formatVersion, id, release, createdAt, modifiedAt, title, description, conformsTo, profiles
        case materializableProfiles, modavisBinding, primaryEntityId, focusEntityIds, entities, relations, paradata
        case analyses, acoustics, playable, interactionModel, captureDocumentation, logicalAssets, realizations, distributions, repositoryBindings, assetGroups, rights
        case integrity, extensions
    }
}

public struct VAO03ReleaseIdentity: Codable, Sendable, Equatable {
    public var id: String
    public var revision: Int
    public var contentVersion: String
    public var supersedesReleaseId: String?
    public var migratedFromManifestSHA256: String?
}

public struct VAO03Profile: Codable, Sendable, Equatable {
    public var id: String
    public var version: String
    public var requiredCapabilities: [String]
}

public struct VAO03MaterializableProfile: Codable, Sendable, Equatable {
    public var id: String
    public var version: String
    public var requiredCapabilities: [String]
    public var groupIds: [String]
}

public struct VAO03ModavisBinding: Codable, Sendable, Equatable {
    public var ontologyIRI: String
    public var ontologyVersion: String
    public var ontologyStatus: String
    public var ontologyVersionIRI: String?
    public var mappingVersion: String
    public var mappingIRI: String?
    public var vocabularyReleaseIRI: String?
    public var vocabularyManifestSHA256: String?
    public var notes: String?
}

public struct VAO03Entity: Codable, Sendable, Equatable {
    public var id: String
    public var kind: String
    public var types: [String]
    public var labels: [String: String]
    public var classifications: [VAOJSONValue]?
    public var externalIdentifiers: [VAOJSONValue]?
    public var properties: [String: VAOJSONValue]?
}

public struct VAO03Relation: Codable, Sendable, Equatable {
    public var id: String
    public var subjectId: String
    public var predicate: String
    public var objectId: String?
    public var literal: VAOJSONValue?
    public var status: String
    public var confidence: Double?
    public var scope: VAOJSONValue?
    public var evidenceIds: [String]?
    public var generatedByIds: [String]?
    public var properties: [String: VAOJSONValue]?
}

public struct VAO03LogicalAsset: Codable, Sendable, Equatable {
    public var id: String
    public var type: String
    public var labels: [String: String]?
    public var roles: [String]
    public var aboutEntityIds: [String]
    public var realizationIds: [String]
    public var properties: [String: VAOJSONValue]?
}

public struct VAO03Realization: Codable, Sendable, Equatable {
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
    public var technicalMetadata: VAO03TechnicalMetadata
    public var distributionIds: [String]
}

public struct VAO03TechnicalMetadata: Codable, Sendable, Equatable {
    public var kind: String
    public var sampleRate: Double?
    public var sampleFormat: String?
    public var bitDepth: Int?
    public var channelCount: Int?
    public var frameCount: Int64?
    public var channelLabels: [String]?
    public var audioContainer: String?
    public var ambisonicsOrder: Int?
    public var ambisonicsDimensionality: String?
    public var ambisonicsChannelOrder: String?
    public var ambisonicsNormalization: String?
    public var impulseResponse: VAOJSONValue?
    public var coordinateFrameId: String?
    public var coordinateUnit: String?
    public var handedness: String?
    public var upAxis: String?
    public var lod: Int?
    public var triangleCount: Int64?
    public var vertexCount: Int64?
    public var textureMaxDimension: Int?
    public var purposeLimitations: [String]?
    public var extensions: [String: VAOJSONValue]?
}

public struct VAO03Playable: Codable, Sendable, Equatable {
    public var signalRegions: [VAO03SignalRegion]
    public var loopPointSets: [VAO03LoopPointSet]
    public var tuningMaps: [VAO03TuningMap]
    public var perspectiveGroups: [VAO03PerspectiveGroup]
    public var sampleVariants: [VAO03SampleVariant]
    public var sampleMappings: [VAO03SampleMapping]
}

public struct VAO03SignalRegion: Codable, Sendable, Equatable {
    public var id: String
    public var realizationId: String
    public var role: String
    public var startFrameInclusive: Int64
    public var endFrameExclusive: Int64
    public var status: String
    public var source: String
    public var generatedById: String?
    public var notes: String?
}

public struct VAO03LoopPointSet: Codable, Sendable, Equatable {
    public var id: String
    public var regionIds: [String]
    public var mode: String
    public var selectionPolicy: String
    public var exitPolicy: String
    public var crossfadeFrames: Int64?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03TuningEntry: Codable, Sendable, Equatable {
    public var key: Int
    public var targetFrequencyHz: Double?
    public var sourceFrequencyHz: Double?
    public var correctionCents: Double?
    public var harmonicNumber: Double?
    public var originalPitch: String?
}

public struct VAO03TuningMap: Codable, Sendable, Equatable {
    public var id: String
    public var referencePitchHz: Double
    public var referenceMIDINote: Int
    public var temperamentLabel: String?
    public var entries: [VAO03TuningEntry]
    public var status: String
    public var source: String
    public var generatedById: String?
    public var notes: String?
}

public struct VAO03PerspectiveGroup: Codable, Sendable, Equatable {
    public var id: String
    public var labels: [String: String]
    public var perspectiveType: String
    public var realizationIds: [String]
    public var channelIndices: [Int]?
    public var poseIds: [String]?
    public var geometryStatus: String
    public var selectionPolicy: String
    public var status: String
    public var source: String
    public var generatedById: String?
}

public struct VAO03SampleVariant: Codable, Sendable, Equatable {
    public var id: String
    public var realizationId: String
    public var trigger: String
    public var signalRole: String
    public var signalRegionIds: [String]?
    public var loopPointSetIds: [String]?
    public var perspectiveGroupId: String?
    public var roundRobinGroup: String?
    public var roundRobinIndex: Int?
    public var selectionWeight: Double?
    public var sourceLocator: String?
    public var status: String
    public var source: String
    public var generatedById: String?
}

public struct VAO03MIDIRange: Codable, Sendable, Equatable {
    public var minimum: Int
    public var maximum: Int
}

public struct VAO03SampleMapping: Codable, Sendable, Equatable {
    public var id: String
    public var instrumentEntityId: String
    public var componentEntityId: String?
    public var rankEntityId: String?
    public var keyRange: VAO03MIDIRange
    public var velocityRange: VAO03MIDIRange?
    public var velocitySensitivity: String? = nil
    public var controlKeyMeaning: String? = nil
    public var soundingKeyOffset: Int? = nil
    public var sampleRootKey: Int? = nil
    public var variantIds: [String]
    public var selectionPolicy: String
    public var tuningMapId: String?
    public var gainDB: Double?
    public var pitchTuningCents: Double?
    public var noteOffPolicy: String
    public var sourceLocator: String?
    public var status: String
    public var source: String
    public var generatedById: String?
}

public struct VAO03InteractionModel: Codable, Sendable, Equatable {
    public var controls: [VAO03InteractionControl]
    public var eventTypes: [VAO03InteractionEventType]
    public var protocolBindings: [VAO03ProtocolBinding]
    public var stateVariables: [VAO03StateVariable]
    public var transitions: [VAO03InteractionTransition]
    public var routingRules: [VAO03RoutingRule]
    public var processModels: [VAO03ProcessModel]
    public var timingConstraints: [VAO03TimingConstraint]
    public var transferFunctions: [VAO03TransferFunction]
    public var renderBindings: [VAO03RenderBinding]
}

public struct VAO03InteractionControl: Codable, Sendable, Equatable {
    public var id: String
    public var labels: [String: String]
    public var entityId: String?
    public var controlBehavior: String
    public var valueType: String
    public var minimumValue: Double?
    public var maximumValue: Double?
    public var stepCount: Int?
    public var allowedValues: [VAOJSONValue]?
    public var defaultValue: VAOJSONValue?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var sourceLocator: String?
    public var notes: String?
}

public struct VAO03InteractionEventType: Codable, Sendable, Equatable {
    public var id: String
    public var labels: [String: String]
    public var eventKind: String
    public var valueDomain: String
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03ProtocolBinding: Codable, Sendable, Equatable {
    public var id: String
    public var controlId: String
    public var eventTypeId: String
    public var protocolName: String
    public var direction: String
    public var messageType: String
    public var channel: Int?
    public var number: Int?
    public var channelNumberingBase: Int?
    public var dataNumberingBase: Int?
    public var address: String?
    public var activationValue: VAOJSONValue?
    public var deactivationValue: VAOJSONValue?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var sourceLocator: String?

    enum CodingKeys: String, CodingKey {
        case id, controlId, eventTypeId, direction, messageType, channel, number
        case channelNumberingBase, dataNumberingBase, address, activationValue, deactivationValue
        case status, source, generatedById, reviewedById, sourceLocator
        case protocolName = "protocol"
    }
}

public struct VAO03StateVariable: Codable, Sendable, Equatable {
    public var id: String
    public var labels: [String: String]
    public var subjectEntityId: String?
    public var valueType: String
    public var persistence: String
    public var defaultValue: VAOJSONValue
    public var minimumValue: Double?
    public var maximumValue: Double?
    public var stepCount: Int?
    public var allowedValues: [VAOJSONValue]?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03StateCondition: Codable, Sendable, Equatable {
    public var stateVariableId: String
    public var comparisonOperator: String
    public var value: VAOJSONValue

    enum CodingKeys: String, CodingKey {
        case stateVariableId, value
        case comparisonOperator = "operator"
    }
}

public struct VAO03DeclarativeAction: Codable, Sendable, Equatable {
    public var operation: String
    public var targetId: String
    public var value: VAOJSONValue?
    public var keyOffset: Int?
    public var delayConstraintId: String?
    public var executionGroup: String?
}

public struct VAO03InteractionTransition: Codable, Sendable, Equatable {
    public var id: String
    public var eventTypeId: String
    public var controlId: String?
    public var conditions: [VAO03StateCondition]?
    public var actions: [VAO03DeclarativeAction]
    public var atomic: Bool
    public var conflictPolicy: String?
    public var priority: Int?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03KeyTransformEntry: Codable, Sendable, Equatable {
    public var inputKey: Int
    public var outputKeys: [Int]
}

public struct VAO03KeyTransform: Codable, Sendable, Equatable {
    public var kind: String
    public var semitoneOffset: Int?
    public var fixedOutputKeys: [Int]?
    public var entries: [VAO03KeyTransformEntry]?
}

public struct VAO03RoutingRule: Codable, Sendable, Equatable {
    public var id: String
    public var sourceControlId: String?
    public var sourceEntityId: String
    public var targetEntityId: String
    public var routingBehavior: String
    public var inputKeyMeaning: String
    public var outputKeyMeaning: String
    public var inputRange: VAO03MIDIRange
    public var keyTransform: VAO03KeyTransform
    public var conditions: [VAO03StateCondition]?
    public var footageLabel: String?
    public var harmonicRelation: Double?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var sourceLocator: String?
    public var notes: String?
}

public struct VAO03TimingUncertainty: Codable, Sendable, Equatable {
    public var kind: String
    public var value: VAOJSONValue
    public var unit: String
    public var coverageFactor: Double?
    public var confidenceLevel: Double?
    public var method: String?
}

public struct VAO03TimingConstraint: Codable, Sendable, Equatable {
    public var id: String
    public var timingKind: String
    public var unit: String
    public var minimum: Double
    public var typical: Double?
    public var maximum: Double?
    public var uncertainty: VAO03TimingUncertainty?
    public var appliesToIds: [String]?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var sourceLocator: String?
    public var notes: String?
}

public struct VAO03ProcessModel: Codable, Sendable, Equatable {
    public var id: String
    public var processKind: String
    public var ordering: String
    public var actions: [VAO03DeclarativeAction]
    public var childProcessIds: [String]?
    public var timingConstraintIds: [String]?
    public var terminationPolicy: String
    public var maximumIterations: Int?
    public var durationConstraintId: String?
    public var cancellationControlId: String?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03TransferPoint: Codable, Sendable, Equatable {
    public var input: Double
    public var output: VAOJSONValue
}

public struct VAO03TransferFunction: Codable, Sendable, Equatable {
    public var id: String
    public var inputKind: String
    public var outputKind: String
    public var inputUnit: String?
    public var outputUnit: String?
    public var interpolation: String
    public var points: [VAO03TransferPoint]
    public var monotonic: Bool?
    public var appliesToIds: [String]?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var sourceLocator: String?
    public var notes: String?
}

public struct VAO03RenderBinding: Codable, Sendable, Equatable {
    public var id: String
    public var eventTypeId: String?
    public var processModelId: String?
    public var conditions: [VAO03StateCondition]?
    public var sampleMappingIds: [String]?
    public var sampleVariantIds: [String]?
    public var selectionPolicy: String
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03CaptureDocumentation: Codable, Sendable, Equatable {
    public var captureStates: [VAO03CaptureState]
    public var eventAlignments: [VAO03EventAlignment]
    public var takeSets: [VAO03TakeSet]
    public var derivationMaps: [VAO03DerivationMap]
}

public struct VAO03StateAssignment: Codable, Sendable, Equatable {
    public var stateVariableId: String
    public var value: VAOJSONValue
}

public struct VAO03CaptureState: Codable, Sendable, Equatable {
    public var id: String
    public var instrumentEntityId: String
    public var labels: [String: String]?
    public var stateAssignments: [VAO03StateAssignment]
    public var capturedAt: String?
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var sourceLocator: String?
    public var notes: String?
}

public struct VAO03EventFrameMapping: Codable, Sendable, Equatable {
    public var eventLocator: String
    public var eventTypeId: String?
    public var startFrame: Int64
    public var endFrameExclusive: Int64?
}

public struct VAO03EventAlignment: Codable, Sendable, Equatable {
    public var id: String
    public var audioRealizationId: String
    public var eventLogRealizationId: String
    public var clockBasis: String
    public var offset: Double
    public var driftPPM: Double?
    public var uncertainty: VAO03TimingUncertainty?
    public var eventMappings: [VAO03EventFrameMapping]
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03TakeSet: Codable, Sendable, Equatable {
    public var id: String
    public var captureStateId: String
    public var realizationIds: [String]
    public var setRole: String
    public var selectionStatus: String
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03DerivationOperation: Codable, Sendable, Equatable {
    public var kind: String
    public var activityId: String?
    public var softwareName: String?
    public var softwareVersion: String?
    public var parameters: [String: VAOJSONValue]?
}

public struct VAO03DerivationMap: Codable, Sendable, Equatable {
    public var id: String
    public var sourceRealizationId: String
    public var derivedRealizationId: String
    public var sourceFrameRange: VAO03FrameRange?
    public var channelMap: [Int]?
    public var operations: [VAO03DerivationOperation]
    public var status: String
    public var source: String
    public var generatedById: String?
    public var reviewedById: String?
    public var notes: String?
}

public struct VAO03FrameRange: Codable, Sendable, Equatable {
    public var startFrameInclusive: Int64
    public var endFrameExclusive: Int64
}

/// Closed union represented with optional variant fields so unknown repository
/// adapters do not require Swift enum rewrites. The validator enforces the
/// fields allowed and required for `repository` and `pack-member`.
public struct VAO03Distribution: Codable, Sendable, Equatable {
    public var id: String
    public var kind: String
    public var repositoryBindingId: String?
    public var persistentIdentifier: String?
    public var conceptIdentifier: String?
    public var recordIdentifier: String?
    public var fileIdentifier: String?
    public var access: String?
    public var transportChecksums: [String: String]?
    public var packRealizationId: String?
    public var memberPath: String?
    public var packManifestSHA256: String?
}

public struct VAO03RepositoryBinding: Codable, Sendable, Equatable {
    public var id: String
    public var repositoryType: String
    public var instance: String
    public var apiProfile: String
    public var resolutionPolicy: String
}

public struct VAO03AssetGroup: Codable, Sendable, Equatable {
    public var id: String
    public var type: String
    public var labels: [String: String]
    public var selectionSetId: String
    public var qualityTier: String
    public var availability: String
    public var selectionPolicy: String
    public var realizationIds: [String]
    public var dependsOnGroupIds: [String]
    public var fallbackGroupId: String?
    public var totalByteSize: Int64
    public var requiredCapabilities: [String]
    public var materializesProfileIds: [String]
    public var cachePolicy: VAO03CachePolicy
}

public struct VAO03CachePolicy: Codable, Sendable, Equatable {
    public var evictable: Bool
    public var priority: Int
}

public struct VAO03Rights: Codable, Sendable, Equatable {
    public var id: String
    public var appliesToIds: [String]
    public var license: String?
    public var statement: [String: String]
    public var access: String
    public var attribution: String?
}

public struct VAO03Integrity: Codable, Sendable, Equatable {
    public var algorithm: String
    public var manifestDigestLocation: String
    public var carrierDescriptor: String
}

public struct VAO03Carrier: Codable, Sendable, Equatable {
    public var schema: String
    public var type: String
    public var formatVersion: String
    public var releaseId: String
    public var manifestSHA256: String
    public var manifestByteSize: Int64
    public var carrierMode: String
    public var embeddedRealizations: [VAO03CarrierMapping]
    public var completeGroupIds: [String]

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case type, formatVersion, releaseId, manifestSHA256, manifestByteSize, carrierMode
        case embeddedRealizations, completeGroupIds
    }
}

public struct VAO03CarrierMapping: Codable, Sendable, Equatable {
    public var realizationId: String
    public var path: String
}

public struct VAO03ReleaseDescriptor: Codable, Sendable, Equatable {
    public var schema: String
    public var type: String
    public var formatVersion: String
    public var vaoId: String
    public var releaseId: String
    public var revision: Int
    public var contentVersion: String
    public var publication: VAO03Publication

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case type, formatVersion, vaoId, releaseId, revision, contentVersion, publication
    }
}

public struct VAO03Publication: Codable, Sendable, Equatable {
    public var topology: String
    public var rootRecord: VAO03PublicationRecord
    public var familyMembers: [VAO03FamilyMember]
}

public struct VAO03PublicationRecord: Codable, Sendable, Equatable {
    public var id: String
    public var repositoryType: String
    public var instance: String
    public var versionPersistentIdentifier: String
    public var conceptPersistentIdentifier: String?
    public var recordIdentifier: String
    public var files: [VAO03PublicationFile]
}

public struct VAO03PublicationFile: Codable, Sendable, Equatable {
    public var fileIdentifier: String
    public var role: String
    public var byteSize: Int64
    public var sha256: String
    public var realizationIds: [String]?
}

public struct VAO03FamilyMember: Codable, Sendable, Equatable {
    public var recordRole: String
    public var membership: String
    public var relationFromRoot: String
    public var inverseRelationFromMember: String?
    public var record: VAO03PublicationRecord
}

public struct VAO03ZenodoMetadataDocument: Codable, Sendable, Equatable {
    public var schema: String
    public var type: String
    public var formatVersion: String
    public var releaseId: String
    public var publicationRecordId: String
    public var recordRole: String
    public var metadata: VAO03ZenodoMetadata

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case type, formatVersion, releaseId, publicationRecordId, recordRole, metadata
    }
}

public struct VAO03ZenodoMetadata: Codable, Sendable, Equatable {
    public var uploadType: String
    public var title: String
    public var description: String
    public var creators: [VAO03ZenodoPerson]
    public var contributors: [VAO03ZenodoContributor]?
    public var publicationDate: String
    public var version: String
    public var accessRight: String
    public var license: String?
    public var embargoDate: String?
    public var accessConditions: String?
    public var keywords: [String]
    public var relatedIdentifiers: [VAO03ZenodoRelatedIdentifier]
    public var communities: [VAO03ZenodoCommunity]?
    public var grants: [VAO03ZenodoGrant]?
    public var references: [String]?
    public var subjects: [VAO03ZenodoSubject]?
    public var dates: [VAO03ZenodoDate]?
    public var language: String?
    public var notes: String?
    public var method: String?

    enum CodingKeys: String, CodingKey {
        case uploadType = "upload_type"
        case title, description, creators, contributors
        case publicationDate = "publication_date"
        case version
        case accessRight = "access_right"
        case license
        case embargoDate = "embargo_date"
        case accessConditions = "access_conditions"
        case keywords
        case relatedIdentifiers = "related_identifiers"
        case communities, grants, references, subjects, dates, language, notes, method
    }
}

public struct VAO03ZenodoPerson: Codable, Sendable, Equatable {
    public var name: String
    public var affiliation: String?
    public var orcid: String?
    public var gnd: String?
}

public struct VAO03ZenodoContributor: Codable, Sendable, Equatable {
    public var name: String
    public var affiliation: String?
    public var orcid: String?
    public var gnd: String?
    public var type: String
}

public struct VAO03ZenodoRelatedIdentifier: Codable, Sendable, Equatable {
    public var identifier: String
    public var relation: String
    public var resourceType: String?

    enum CodingKeys: String, CodingKey {
        case identifier, relation
        case resourceType = "resource_type"
    }
}

public struct VAO03ZenodoCommunity: Codable, Sendable, Equatable { public var identifier: String }
public struct VAO03ZenodoGrant: Codable, Sendable, Equatable { public var id: String }
public struct VAO03ZenodoSubject: Codable, Sendable, Equatable { public var term: String; public var identifier: String; public var scheme: String }
public struct VAO03ZenodoDate: Codable, Sendable, Equatable { public var start: String; public var end: String?; public var type: String; public var description: String? }

public enum VAOFormatDispatcher {
    public static func formatVersion(in data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return root["formatVersion"] as? String
    }

    public static func decode03(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> VAO03Manifest {
        try decoder.decode(VAO03Manifest.self, from: data)
    }
}
