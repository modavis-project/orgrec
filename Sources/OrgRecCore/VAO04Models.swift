import Foundation

public enum VAO04Contract {
    public static let formatVersion = "0.4.0"
    public static let mediaType = VAO03Contract.mediaType
    public static let manifestFilename = VAO03Contract.manifestFilename
    public static let carrierFilename = VAO03Contract.carrierFilename
    public static let baseURI = "https://w3id.org/modavis/vao/0.4.0"
    public static let schemaURI = baseURI + "/schema/manifest.json"
    public static let contextURI = baseURI + "/context.jsonld"
    public static let coreProfile = "https://w3id.org/modavis/vao/profile/core/0.4.0"
    public static let dynamicDeliveryProfile = "https://w3id.org/modavis/vao/profile/dynamic-delivery/0.4.0"
    public static let scientificProfile = "https://w3id.org/modavis/vao/profile/scientific/0.4.0"
    public static let multimodalProfile = "https://w3id.org/modavis/vao/profile/multimodal/0.4.0"
    public static let physicalInstrumentProfile = "https://w3id.org/modavis/vao/profile/physical-instrument/0.4.0"
    public static let deterministicRuntimeProfile = "https://w3id.org/modavis/vao/profile/deterministic-runtime/0.4.0"
    public static let playableProfile = "https://w3id.org/modavis/vao/profile/playable/0.4.0"
}

public struct VAO04Manifest: Codable, Sendable, Equatable {
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
    public var scientific: VAO04Scientific
    public var multimodal: VAO04Multimodal
    public var physicalSystem: VAO04PhysicalSystem
    public var runtime: VAO04Runtime
    public var discovery: VAO04Discovery
    public var acoustics: VAOJSONValue?
    public var playable: VAO03Playable?
    public var interactionModel: VAO04InteractionModel?
    public var captureDocumentation: VAO03CaptureDocumentation?
    public var logicalAssets: [VAO03LogicalAsset]
    public var realizations: [VAO04Realization]
    public var distributions: [VAO03Distribution]
    public var repositoryBindings: [VAO03RepositoryBinding]
    public var assetGroups: [VAO03AssetGroup]
    public var rights: [VAO04Rights]
    public var integrity: VAO04Integrity
    public var extensions: [String: VAOJSONValue]?

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"; case context = "@context"
        case type, formatVersion, id, release, createdAt, modifiedAt, title, description, conformsTo, profiles
        case materializableProfiles, modavisBinding, primaryEntityId, focusEntityIds, entities, relations
        case scientific, multimodal, physicalSystem, runtime, discovery, acoustics, playable, interactionModel, captureDocumentation
        case logicalAssets, realizations, distributions, repositoryBindings, assetGroups, rights, integrity, extensions
    }
}

public struct VAO04ContentDigest: Codable, Sendable, Equatable { public var algorithm: String; public var value: String }
public struct VAO04Chunk: Codable, Sendable, Equatable { public var index: Int; public var offset: Int64; public var length: Int64; public var digest: VAO04ContentDigest }
public struct VAO04Chunking: Codable, Sendable, Equatable {
    public var strategy: String; public var chunkSize: Int64?; public var merkleRoot: VAO04ContentDigest?
    public var chunks: [VAO04Chunk]; public var indexRealizationId: String?
}
public struct VAO04TechnicalMetadata: Codable, Sendable, Equatable {
    public var kind: String
    public var sampleRate: Double?; public var sampleFormat: String?; public var bitDepth: Int?; public var channelCount: Int?
    public var frameCount: Int64?; public var channelLabels: [String]?; public var audioContainer: String?
    public var ambisonicsOrder: Int?; public var ambisonicsDimensionality: String?; public var ambisonicsChannelOrder: String?; public var ambisonicsNormalization: String?
    public var impulseResponse: VAOJSONValue?; public var coordinateFrameId: String?; public var coordinateUnit: String?
    public var handedness: String?; public var upAxis: String?; public var lod: Int?; public var triangleCount: Int64?; public var vertexCount: Int64?
    public var textureMaxDimension: Int?; public var purposeLimitations: [String]?; public var durationSeconds: Double?
    public var timebaseId: String?; public var width: Int?; public var height: Int?; public var frameRate: Double?; public var codec: String?
    public var colorSpace: String?; public var eventEncoding: String?; public var sensorEncoding: String?; public var scoreFormat: String?
    public var trajectoryTrackId: String?; public var extensions: [String: VAOJSONValue]?
}
public struct VAO04Realization: Codable, Sendable, Equatable {
    public var id: String; public var type: String; public var assetId: String; public var variantSetId: String; public var qualityTier: String
    public var mediaType: String; public var byteSize: Int64; public var sha256: String; public var representationStatus: String
    public var rightsIds: [String]; public var provenanceIds: [String]; public var technicalMetadata: VAO04TechnicalMetadata
    public var distributionIds: [String]; public var contentDigests: [VAO04ContentDigest]?
    public var chunking: VAO04Chunking?; public var streamingIndexRealizationId: String?; public var authenticityEnvelopeRealizationId: String?
}

public struct VAO04Agent: Codable, Sendable, Equatable {
    public var id: String; public var agentKind: String; public var labels: [String: String]; public var orcid: String?; public var ror: String?
    public var roles: [String]?; public var contact: String?; public var extensions: [String: VAOJSONValue]?
}
public struct VAO04SoftwareEnvironment: Codable, Sendable, Equatable {
    public var id: String; public var name: String; public var version: String; public var identity: VAO04ContentDigest
    public var sourceCodeIRI: String?; public var softwareHeritageId: String?; public var containerDigest: VAO04ContentDigest?
    public var modelWeightDigest: VAO04ContentDigest?; public var dependencies: [String]?; public var runtime: String?; public var extensions: [String: VAOJSONValue]?
}
public struct VAO04Protocol: Codable, Sendable, Equatable {
    public var id: String; public var labels: [String: String]; public var procedure: String; public var version: String
    public var documentRealizationId: String?; public var standardIRI: String?; public var parameters: [String: VAOJSONValue]?
}
public struct VAO04Activity: Codable, Sendable, Equatable {
    public var id: String; public var activityKind: String; public var startedAt: String; public var endedAt: String
    public var agentIds: [String]; public var protocolId: String; public var softwareEnvironmentId: String?
    public var inputIds: [String]; public var outputIds: [String]; public var parameterValues: [String: VAOJSONValue]?
    public var randomSourceId: String?; public var environmentObservationIds: [String]?; public var notes: String?
}
public struct VAO04QuantityValue: Codable, Sendable, Equatable {
    public var value: VAOJSONValue; public var unit: String; public var quantityKind: String?; public var uncertainty: VAO03TimingUncertainty?
    public var sampleCount: Int?; public var censoring: String?; public var outlierPolicy: String?
}
public struct VAO04Calibration: Codable, Sendable, Equatable {
    public var id: String; public var instrumentEntityId: String; public var protocolId: String; public var performedByAgentIds: [String]
    public var performedAt: String; public var certificateRealizationId: String?; public var resultStatus: String
    public var uncertainty: VAO03TimingUncertainty?; public var validUntil: String?
}
public struct VAO04Observation: Codable, Sendable, Equatable {
    public var id: String; public var observedProperty: String; public var featureOfInterestId: String; public var result: VAO04QuantityValue
    public var resultTime: String; public var activityId: String; public var protocolId: String; public var sensorId: String?; public var calibrationId: String?
    public var rawResultRealizationId: String?; public var processedResultRealizationId: String?; public var status: String; public var qualityFlags: [String]?
}
public struct VAO04Analysis: Codable, Sendable, Equatable {
    public var id: String; public var analysisKind: String; public var activityId: String; public var inputIds: [String]; public var outputIds: [String]
    public var softwareEnvironmentId: String; public var parameters: [String: VAOJSONValue]; public var randomSourceId: String?
    public var reproducibility: String; public var fitResidual: VAO04QuantityValue?; public var validationIds: [String]?
}
public struct VAO04Claim: Codable, Sendable, Equatable {
    public var id: String; public var subjectId: String; public var predicate: String; public var objectId: String?; public var literal: VAOJSONValue?
    public var status: String; public var confidence: Double?; public var evidenceIds: [String]; public var generatedById: String?; public var reviewIds: [String]?
}
public struct VAO04Review: Codable, Sendable, Equatable { public var id: String; public var reviewedId: String; public var reviewerAgentId: String; public var reviewedAt: String; public var decision: String; public var rationale: String? }
public struct VAO04Consent: Codable, Sendable, Equatable { public var id: String; public var grantedByAgentId: String; public var appliesToIds: [String]; public var decision: String; public var recordedAt: String; public var conditions: [String: String]?; public var evidenceRealizationId: String? }
public struct VAO04Scientific: Codable, Sendable, Equatable {
    public var agents: [VAO04Agent]; public var activities: [VAO04Activity]; public var observations: [VAO04Observation]
    public var analyses: [VAO04Analysis]; public var calibrations: [VAO04Calibration]; public var protocols: [VAO04Protocol]
    public var softwareEnvironments: [VAO04SoftwareEnvironment]; public var claims: [VAO04Claim]; public var reviews: [VAO04Review]; public var consents: [VAO04Consent]
}

public struct VAO04Timebase: Codable, Sendable, Equatable { public var id: String; public var kind: String; public var unit: String; public var rate: Double; public var origin: Double; public var epoch: String?; public var wrapPeriod: Double? }
public struct VAO04Track: Codable, Sendable, Equatable { public var id: String; public var modality: String; public var timebaseId: String; public var realizationId: String; public var coordinateFrameId: String?; public var channelSelector: String?; public var continuity: String }
public struct VAO04ClockSegment: Codable, Sendable, Equatable { public var sourceStart: Double; public var sourceEndExclusive: Double; public var scale: Double; public var offset: Double; public var residualUncertainty: VAO03TimingUncertainty; public var discontinuityAfter: String? }
public struct VAO04SynchronizationMapping: Codable, Sendable, Equatable { public var id: String; public var sourceTimebaseId: String; public var targetTimebaseId: String; public var method: String; public var segments: [VAO04ClockSegment]; public var activityId: String; public var jitter: VAO03TimingUncertainty? }
public struct VAO04AnnotationSelector: Codable, Sendable, Equatable { public var trackId: String; public var start: Double?; public var endExclusive: Double?; public var spatialFragment: String?; public var svgSelector: String?; public var eventLocator: String?; public var scoreElementId: String? }
public struct VAO04Annotation: Codable, Sendable, Equatable { public var id: String; public var motivation: String; public var target: VAO04AnnotationSelector; public var body: VAOJSONValue; public var createdByAgentId: String; public var createdAt: String?; public var activityId: String? }
public struct VAO04Multimodal: Codable, Sendable, Equatable { public var timebases: [VAO04Timebase]; public var tracks: [VAO04Track]; public var synchronizationMappings: [VAO04SynchronizationMapping]; public var annotations: [VAO04Annotation] }

public struct VAO04PhysicalComponent: Codable, Sendable, Equatable { public var id: String; public var entityId: String; public var componentKind: String; public var parentComponentId: String?; public var portIds: [String]? }
public struct VAO04PhysicalPort: Codable, Sendable, Equatable { public var id: String; public var componentId: String; public var direction: String; public var signalKind: String; public var quantityKind: String? }
public struct VAO04PhysicalConnection: Codable, Sendable, Equatable { public var id: String; public var sourcePortId: String; public var targetPortId: String; public var connectionKind: String; public var delayConstraintId: String?; public var bidirectional: Bool? }
public struct VAO04Sensor: Codable, Sendable, Equatable { public var id: String; public var componentId: String; public var observedProperty: String; public var outputPortId: String; public var protocolId: String; public var calibrationId: String? }
public struct VAO04Actuator: Codable, Sendable, Equatable { public var id: String; public var componentId: String; public var actedOnProperty: String; public var inputPortId: String; public var protocolId: String; public var transferFunctionId: String? }
public struct VAO04StateBinding: Codable, Sendable, Equatable { public var id: String; public var stateVariableId: String; public var componentId: String; public var stateRole: String; public var observationId: String? }
public struct VAO04PhysicalSystem: Codable, Sendable, Equatable { public var components: [VAO04PhysicalComponent]; public var ports: [VAO04PhysicalPort]; public var connections: [VAO04PhysicalConnection]; public var sensors: [VAO04Sensor]; public var actuators: [VAO04Actuator]; public var stateBindings: [VAO04StateBinding] }

public struct VAO04ExecutionSemantics: Codable, Sendable, Equatable {
    public var timestampOrder: String; public var simultaneousEventOrder: String; public var transitionEvaluation: String; public var actionExecution: String
    public var runToCompletion: Bool; public var reentrancyPolicy: String; public var lateEventPolicy: String; public var timeResolution: VAO04QuantityValue
    public var maximumMicrosteps: Int?; public var voiceAllocation: String?; public var maximumVoices: Int?
}
public struct VAO04RandomSource: Codable, Sendable, Equatable { public var id: String; public var algorithm: String; public var seed: String; public var stream: Int }
public struct VAO04Renderer: Codable, Sendable, Equatable { public var id: String; public var name: String; public var version: String; public var capabilities: [String]; public var softwareEnvironmentId: String; public var sandboxPolicy: String; public var deterministic: Bool? }
public struct VAO04TraceEvent: Codable, Sendable, Equatable { public var timestamp: Double; public var eventTypeId: String; public var controlId: String?; public var value: VAOJSONValue?; public var priority: Int?; public var sequence: Int }
public struct VAO04TraceExpectation: Codable, Sendable, Equatable { public var state: [String: VAOJSONValue]; public var emittedEvents: [VAOJSONValue]; public var renderBindingIds: [String] }
public struct VAO04ConformanceTrace: Codable, Sendable, Equatable { public var id: String; public var initialState: [String: VAOJSONValue]?; public var inputEvents: [VAO04TraceEvent]; public var expected: VAO04TraceExpectation; public var digest: VAO04ContentDigest }
public struct VAO04Runtime: Codable, Sendable, Equatable { public var executionSemantics: VAO04ExecutionSemantics; public var randomSources: [VAO04RandomSource]; public var renderers: [VAO04Renderer]; public var conformanceTraces: [VAO04ConformanceTrace] }

public struct VAO04ProtocolBinding: Codable, Sendable, Equatable {
    public var id: String; public var controlId: String; public var eventTypeId: String; public var protocolName: String; public var direction: String; public var messageType: String
    public var channel: Int?; public var number: Int?; public var channelNumberingBase: Int?; public var dataNumberingBase: Int?; public var address: String?
    public var activationValue: VAOJSONValue?; public var deactivationValue: VAOJSONValue?; public var status: String; public var source: String
    public var generatedById: String?; public var reviewedById: String?; public var sourceLocator: String?
    public var umpGroup: Int?; public var functionBlock: Int?; public var umpMessageType: Int?; public var dataResolutionBits: Int?
    public var perNoteControllerIndex: Int?; public var jrTimestamp: Bool?; public var midiCIProfileIRI: String?; public var propertyExchangeResourceIRI: String?
    enum CodingKeys: String, CodingKey { case id, controlId, eventTypeId, direction, messageType, channel, number, channelNumberingBase, dataNumberingBase, address, activationValue, deactivationValue, status, source, generatedById, reviewedById, sourceLocator, umpGroup, functionBlock, umpMessageType, dataResolutionBits, perNoteControllerIndex, jrTimestamp, midiCIProfileIRI, propertyExchangeResourceIRI; case protocolName = "protocol" }
}
public struct VAO04ProbabilityDistribution: Codable, Sendable, Equatable { public var kind: String; public var parameters: [String: Double] }
public struct VAO04RoutingRule: Codable, Sendable, Equatable {
    public var id: String; public var sourceControlId: String?; public var sourceEntityId: String; public var targetEntityId: String
    public var routingBehavior: String; public var inputKeyMeaning: String; public var outputKeyMeaning: String; public var inputRange: VAO03MIDIRange
    public var keyTransform: VAO03KeyTransform; public var conditions: [VAO03StateCondition]?; public var delayConstraintId: String?
    public var footageLabel: String?; public var harmonicRelation: Double?; public var status: String; public var source: String
    public var generatedById: String?; public var reviewedById: String?; public var sourceLocator: String?; public var notes: String?
}
public struct VAO04ProcessModel: Codable, Sendable, Equatable {
    public var id: String; public var processKind: String; public var ordering: String; public var actions: [VAO03DeclarativeAction]; public var childProcessIds: [String]?
    public var timingConstraintIds: [String]?; public var terminationPolicy: String; public var maximumIterations: Int?; public var durationConstraintId: String?
    public var cancellationControlId: String?; public var randomSourceId: String?; public var probabilityDistribution: VAO04ProbabilityDistribution?
    public var status: String; public var source: String; public var generatedById: String?; public var reviewedById: String?; public var notes: String?
}
public struct VAO04TransferPoint: Codable, Sendable, Equatable { public var input: Double; public var output: VAOJSONValue; public var inputs: [Double]?; public var uncertainty: VAO03TimingUncertainty? }
public struct VAO04TransferFunction: Codable, Sendable, Equatable {
    public var id: String; public var inputKind: String; public var outputKind: String; public var inputUnit: String?; public var outputUnit: String?
    public var interpolation: String; public var points: [VAO04TransferPoint]; public var monotonic: Bool?; public var appliesToIds: [String]?
    public var inputKinds: [String]?; public var validDomain: [[Double]]?; public var extrapolationPolicy: String?; public var hysteresis: Bool?
    public var dynamicModel: String?; public var fitResidual: VAO04QuantityValue?; public var status: String; public var source: String
    public var generatedById: String?; public var reviewedById: String?; public var sourceLocator: String?; public var notes: String?
}
public struct VAO04InteractionModel: Codable, Sendable, Equatable {
    public var executionSemantics: VAO04ExecutionSemantics; public var randomSources: [VAO04RandomSource]?
    public var controls: [VAO03InteractionControl]; public var eventTypes: [VAO03InteractionEventType]; public var protocolBindings: [VAO04ProtocolBinding]
    public var stateVariables: [VAO03StateVariable]; public var transitions: [VAO03InteractionTransition]; public var routingRules: [VAO04RoutingRule]
    public var processModels: [VAO04ProcessModel]; public var timingConstraints: [VAO03TimingConstraint]; public var transferFunctions: [VAO04TransferFunction]
    public var renderBindings: [VAO03RenderBinding]
}

public struct VAO04FundingReference: Codable, Sendable, Equatable { public var funderName: String; public var funderIdentifier: String?; public var awardNumber: String?; public var awardIRI: String?; public var awardTitle: String? }
public struct VAO04RelatedIdentifier: Codable, Sendable, Equatable { public var identifier: String; public var relationType: String; public var resourceType: String? }
public struct VAO04Subject: Codable, Sendable, Equatable { public var subject: String; public var subjectScheme: String?; public var valueIRI: String? }
public struct VAO04Discovery: Codable, Sendable, Equatable { public var resourceType: String; public var creatorAgentIds: [String]; public var contributorAgentIds: [String]; public var relatedIdentifiers: [VAO04RelatedIdentifier]; public var fundingReferences: [VAO04FundingReference]; public var subjects: [VAO04Subject]; public var instrumentIdentifiers: [String]?; public var facilityIdentifiers: [String]? }
public struct VAO04Rights: Codable, Sendable, Equatable {
    public var id: String; public var appliesToIds: [String]; public var license: String?; public var statement: [String: String]; public var access: String; public var attribution: String?
    public var performerAgentIds: [String]?; public var consentIds: [String]?; public var communityAuthorityIds: [String]?; public var traditionalKnowledgeLabelIRIs: [String]?
    public var privacyClassification: String?; public var embargoUntil: String?; public var embargoRationale: [String: String]?; public var redactionOfRealizationIds: [String]?; public var carePrinciples: [String]?
}
public struct VAO04Integrity: Codable, Sendable, Equatable { public var algorithm: String; public var manifestDigestLocation: String; public var carrierDescriptor: String; public var schemaBundleDigest: VAO04ContentDigest?; public var signatureEnvelopeRealizationId: String? }

public extension VAOFormatDispatcher {
    static func decode04(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> VAO04Manifest { try decoder.decode(VAO04Manifest.self, from: data) }
}
