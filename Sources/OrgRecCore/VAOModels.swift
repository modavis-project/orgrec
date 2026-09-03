import Foundation

public enum VAOContract {
    public static let formatVersion = "0.2.2"
    public static let mediaType = "application/vnd.modavis.vao+zip"
    public static let manifestFilename = "vao-manifest.json"
    public static let schemaURI = "https://w3id.org/modavis/vao/0.2/schema/manifest.json"
    public static let contextURI = "https://w3id.org/modavis/vao/0.2/context.jsonld"
    public static let coreProfile = "https://w3id.org/modavis/vao/profile/core/0.2"
    public static let researchProfile = "https://w3id.org/modavis/vao/profile/research/0.2"
    public static let orgRecProfile = "https://w3id.org/modavis/vao/profile/orgrec-capture/0.2"
    public static let playableProfile = "https://w3id.org/modavis/vao/profile/playable/0.2"
    public static let spatialProfile = "https://w3id.org/modavis/vao/profile/spatial/0.2"
    public static let acousticsProfile = "https://w3id.org/modavis/vao/profile/acoustics/0.2"
    public static let experientialProfile = "https://w3id.org/modavis/vao/profile/experiential/0.2"
    public static let preservationProfile = "https://w3id.org/modavis/vao/profile/preservation/0.2"
    public static let standardProfiles: Set<String> = [
        coreProfile, researchProfile, orgRecProfile, playableProfile,
        spatialProfile, acousticsProfile, experientialProfile, preservationProfile,
    ]

    public static let vaoNamespace = "https://w3id.org/modavis/vao/ontology#"
    public static let vaoVocabulary = "https://w3id.org/modavis/vao/vocab/"
    public static let modavisCore = "https://w3id.org/modavis/ontology/core#"
    public static let modavisInstrument = "https://w3id.org/modavis/ontology/instrument#"
    public static let modavisOrgan = "https://w3id.org/modavis/ontology/organ#"
    public static let modavisEvidence = "https://w3id.org/modavis/ontology/evidence#"
    public static let modavisEvents = "https://w3id.org/modavis/ontology/events#"
    public static let modavisAudio = "https://w3id.org/modavis/ontology/audio#"
    public static let modavisProvenance = "https://w3id.org/modavis/ontology/provenance#"
    public static let prov = "http://www.w3.org/ns/prov#"

    public static let musicalInstrumentType = modavisInstrument + "MusicalInstrument"
    public static let pipeOrganType = modavisOrgan + "PipeOrgan"
    public static let instrumentComponentType = modavisInstrument + "InstrumentComponent"
    public static let instrumentConfigurationType = modavisInstrument + "InstrumentConfiguration"
    public static let recordingEventType = modavisEvents + "Activity"
    public static let digitalObjectType = vaoNamespace + "DigitalAsset"
    public static let analysisType = vaoNamespace + "Analysis"
    public static let annotationType = vaoNamespace + "Annotation"
    public static let loopPointSetType = modavisAudio + "LoopPointSet"
    public static let signalRegionType = modavisAudio + "SignalRegion"
    public static let sustainLoopRegionType = modavisAudio + "SustainLoopRegion"
    public static let sampleExtractionRegionType = modavisAudio + "SampleExtractionRegion"
    public static let attackRegionType = modavisAudio + "AttackRegion"
    public static let stableSustainRegionType = modavisAudio + "StableSustainRegion"
    public static let releaseRegionType = modavisAudio + "ReleaseRegion"
    public static let samplePlaybackParametersType = modavisAudio + "SamplePlaybackParameters"
    public static let tuningMapType = modavisAudio + "TuningMap"
    public static let tuningCalibrationType = modavisAudio + "TuningCalibration"
    public static let hasRepresentation = vaoNamespace + "hasRepresentation"
    public static let activates = vaoNamespace + "activates"
    public static let modulates = vaoNamespace + "modulates"
    public static let aboutInstrument = vaoNamespace + "aboutInstrument"
    public static let documentsComponent = vaoNamespace + "documentsComponent"
    public static let recordedInSession = vaoNamespace + "recordedInSession"
    public static let usesConfiguration = vaoNamespace + "usesConfiguration"
    public static let derivedFrom = prov + "wasDerivedFrom"
    public static let generatedBy = prov + "wasGeneratedBy"
    public static let wasRevisionOf = prov + "wasRevisionOf"
    public static let appliesToSignal = modavisAudio + "appliesToSignal"
    public static let hasLoopRegion = modavisAudio + "hasLoopRegion"
    public static let usesLoopPointSet = modavisAudio + "usesLoopPointSet"
    public static let hasSignalRegion = modavisAudio + "hasSignalRegion"
    public static let extractedFromRegion = modavisAudio + "extractedFromRegion"
    public static let usesPlaybackParameters = modavisAudio + "usesPlaybackParameters"
    public static let hasTuningMap = modavisAudio + "hasTuningMap"
    public static let usesTuningMap = modavisAudio + "usesTuningMap"
    public static let usesReleaseRegion = modavisAudio + "usesReleaseRegion"
    public static let hasComponent = modavisInstrument + "hasComponent"
    public static let sourceEvidenceRole = vaoVocabulary + "asset-role/source-evidence"
    public static let audioMasterRole = vaoVocabulary + "asset-role/audio-master"
    public static let analysisResultRole = vaoVocabulary + "asset-role/analysis-result"
    public static let paradataRole = vaoVocabulary + "asset-role/paradata-record"
    public static let applicationStateRole = vaoVocabulary + "asset-role/application-state"
    public static let threeDimensionalModelRole = vaoVocabulary + "asset-role/three-dimensional-model"
    public static let spatialModelRole = vaoVocabulary + "asset-role/spatial-model"
    public static let animationRole = vaoVocabulary + "asset-role/animation"
    public static let performanceControlRole = vaoVocabulary + "asset-role/performance-control"
    public static let interactionSensorDataRole = vaoVocabulary + "asset-role/interaction-sensor-data"
    public static let audioDerivativeRole = vaoVocabulary + "asset-role/audio-derivative"
    public static let performanceMediaRole = vaoVocabulary + "asset-role/performance-media"
    public static let imageTargetRole = vaoVocabulary + "asset-role/image-target"
    public static let trackingDataRole = vaoVocabulary + "asset-role/tracking-data"
    public static let spatialListeningAudioRole = vaoVocabulary + "asset-role/spatial-listening-audio"
    public static let impulseResponseRole = vaoVocabulary + "asset-role/impulse-response"
    public static let acousticModelRole = vaoVocabulary + "asset-role/acoustic-model"
    public static let acousticSceneMetadataRole = vaoVocabulary + "asset-role/acoustic-scene-metadata"
    public static let carrierLabelImageRole = vaoVocabulary + "asset-role/carrier-label-image"
    public static let tuningTableRole = vaoVocabulary + "asset-role/tuning-table"
    public static let featureTrackRole = vaoVocabulary + "asset-role/feature-track"
    public static let machineLearningModelRole = vaoVocabulary + "asset-role/machine-learning-model"

    public static let genericModelViewingCapability = vaoVocabulary + "capability/generic-model-viewing"
    public static let synchronizedMediaAnimationCapability = vaoVocabulary + "capability/synchronized-media-animation"
    public static let imageTargetARCapability = vaoVocabulary + "capability/image-target-ar"
    public static let surfacePlacementARCapability = vaoVocabulary + "capability/surface-placement-ar"
    public static let spatialListeningMapCapability = vaoVocabulary + "capability/spatial-listening-map"
    public static let offlineAssetGroupsCapability = vaoVocabulary + "capability/offline-asset-groups"
    public static let replaceablePerformanceMediaCapability = vaoVocabulary + "capability/replaceable-performance-media"
    public static let sampledInstrumentPlaybackCapability = vaoVocabulary + "capability/sampled-instrument-playback"
    public static let sourceSegmentationCapability = vaoVocabulary + "capability/source-segmentation"
    public static let acousticalAnalysisCapability = vaoVocabulary + "capability/acoustical-analysis"
    public static let tuningMapCapability = vaoVocabulary + "capability/tuning-map"
    public static let empiricalTimbreClassificationCapability = vaoVocabulary + "capability/empirical-timbre-classification"
    public static let pitchDependentRankFingerprintCapability = vaoVocabulary + "capability/pitch-dependent-rank-fingerprint"
    public static let collectionAcousticDiagnosticsCapability = vaoVocabulary + "capability/collection-acoustic-diagnostics"
    public static let collectionAcousticDiagnosticsAnalysis = vaoVocabulary + "analysis/evidence-qualified-collection-acoustic-diagnostics"
    public static let collectionEvidenceSummaryProperty = vaoVocabulary + "analysis/collection/evidence-summary"
    public static let collectionTakeEvidenceProperty = vaoVocabulary + "analysis/collection/take-evidence"
    public static let collectionRankCurveProperty = vaoVocabulary + "analysis/collection/rank-tuning-curves"
    public static let collectionRankStretchProperty = vaoVocabulary + "analysis/collection/rank-stretch"
    public static let collectionSessionOffsetProperty = vaoVocabulary + "analysis/collection/session-offset"
    public static let collectionSessionDriftProperty = vaoVocabulary + "analysis/collection/session-drift"
    public static let collectionAnomalyProperty = vaoVocabulary + "analysis/collection/acoustic-anomaly-candidates"
    public static let collectionSimilarityProperty = vaoVocabulary + "analysis/collection/acoustic-similarity-candidates"
    public static let semanticBuildingModelCapability = vaoVocabulary + "capability/semantic-building-model"
    public static let measuredImpulseResponseCapability = vaoVocabulary + "capability/measured-impulse-response"
    public static let spatialResponseFieldCapability = vaoVocabulary + "capability/spatial-response-field"
    public static let sourceDirectivityCapability = vaoVocabulary + "capability/source-directivity"
    public static let roomAcousticMetricsCapability = vaoVocabulary + "capability/room-acoustic-metrics"
    public static let buildingAcousticPerformanceCapability = vaoVocabulary + "capability/building-acoustic-performance"
    public static let spatialAudioSceneCapability = vaoVocabulary + "capability/spatial-audio-scene"
    public static let trackedListenerConvolutionCapability = vaoVocabulary + "capability/tracked-listener-convolution"
    public static let trackedSourcesCapability = vaoVocabulary + "capability/tracked-sources"
    public static let geometryAcousticRenderingCapability = vaoVocabulary + "capability/geometry-acoustic-rendering"
    public static let hybridAcousticRenderingCapability = vaoVocabulary + "capability/hybrid-acoustic-rendering"
    public static let learnedAcousticFieldCapability = vaoVocabulary + "capability/learned-acoustic-field"

    public static let acousticsCapabilities: Set<String> = [
        semanticBuildingModelCapability, measuredImpulseResponseCapability, spatialResponseFieldCapability,
        sourceDirectivityCapability, roomAcousticMetricsCapability, buildingAcousticPerformanceCapability,
        spatialAudioSceneCapability, trackedListenerConvolutionCapability, trackedSourcesCapability,
        geometryAcousticRenderingCapability, hybridAcousticRenderingCapability, learnedAcousticFieldCapability,
    ]

    public static let experientialCapabilities: Set<String> = [
        genericModelViewingCapability,
        synchronizedMediaAnimationCapability,
        imageTargetARCapability,
        surfacePlacementARCapability,
        spatialListeningMapCapability,
        offlineAssetGroupsCapability,
        replaceablePerformanceMediaCapability,
    ]

    public static func property(_ localName: String) -> String { vaoNamespace + localName }
}

public enum VAOJSONValue: Codable, Sendable, Equatable {
    case string(String)
    case integer(Int64)
    case number(Double)
    case boolean(Bool)
    case object([String: VAOJSONValue])
    case array([VAOJSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([VAOJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: VAOJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    public var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    public var numberValue: Double? {
        switch self {
        case .number(let value): return value
        case .integer(let value): return Double(value)
        default: return nil
        }
    }

    public var integerValue: Int64? {
        guard case .integer(let value) = self else { return nil }
        return value
    }

    public var booleanValue: Bool? {
        guard case .boolean(let value) = self else { return nil }
        return value
    }

    public var objectValue: [String: VAOJSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    public var arrayValue: [VAOJSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

}

public struct VAOProfile: Codable, Sendable, Equatable {
    public var id: String
    public var version: String
    public var requiredCapabilities: [String]

    public init(id: String, version: String = "0.2", requiredCapabilities: [String]) {
        self.id = id
        self.version = version
        self.requiredCapabilities = requiredCapabilities
    }
}

public struct VAOModavisBinding: Codable, Sendable, Equatable {
    public var ontologyIRI: String
    public var ontologyVersion: String
    public var ontologyStatus: String
    public var ontologyVersionIRI: String?
    public var vocabularyReleaseIRI: String?
    public var vocabularyManifestSHA256: String?
    public var schemaRelease: String?
    public var mappingVersion: String
    public var mappingIRI: String?
    public var navigatorSnapshotAssetId: String?
    public var notes: String?

    public init(
        ontologyIRI: String,
        ontologyVersion: String,
        ontologyStatus: String,
        ontologyVersionIRI: String? = nil,
        vocabularyReleaseIRI: String? = nil,
        vocabularyManifestSHA256: String? = nil,
        schemaRelease: String? = nil,
        mappingVersion: String,
        mappingIRI: String? = nil,
        navigatorSnapshotAssetId: String? = nil,
        notes: String? = nil
    ) {
        self.ontologyIRI = ontologyIRI
        self.ontologyVersion = ontologyVersion
        self.ontologyStatus = ontologyStatus
        self.ontologyVersionIRI = ontologyVersionIRI
        self.vocabularyReleaseIRI = vocabularyReleaseIRI
        self.vocabularyManifestSHA256 = vocabularyManifestSHA256
        self.schemaRelease = schemaRelease
        self.mappingVersion = mappingVersion
        self.mappingIRI = mappingIRI
        self.navigatorSnapshotAssetId = navigatorSnapshotAssetId
        self.notes = notes
    }
}

public struct VAOConcept: Codable, Sendable, Equatable {
    public var id: String
    public var label: [String: String]?
    public var code: String?
    public var scheme: String?

    public init(id: String, label: [String: String]? = nil, code: String? = nil, scheme: String? = nil) {
        self.id = id
        self.label = label
        self.code = code
        self.scheme = scheme
    }
}

public struct VAOExternalIdentifier: Codable, Sendable, Equatable {
    public var value: String
    public var scheme: String
    public var resolvesTo: String?

    public init(value: String, scheme: String, resolvesTo: String? = nil) {
        self.value = value
        self.scheme = scheme
        self.resolvesTo = resolvesTo
    }
}

public struct VAOEntity: Codable, Sendable, Equatable {
    public var id: String
    public var kind: String
    public var types: [String]
    public var labels: [String: String]
    public var classifications: [VAOConcept]?
    public var externalIdentifiers: [VAOExternalIdentifier]?
    public var properties: [String: VAOJSONValue]?

    public init(
        id: String,
        kind: String,
        types: [String],
        labels: [String: String],
        classifications: [VAOConcept]? = nil,
        externalIdentifiers: [VAOExternalIdentifier]? = nil,
        properties: [String: VAOJSONValue]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.types = types
        self.labels = labels
        self.classifications = classifications
        self.externalIdentifiers = externalIdentifiers
        self.properties = properties
    }
}

public struct VAORelationScope: Codable, Sendable, Equatable {
    public var configurationId: String?
    public var stateId: String?
    public var validFrom: Date?
    public var validUntil: Date?
    public var spatialRegionId: String?

    public init(configurationId: String? = nil, stateId: String? = nil, validFrom: Date? = nil, validUntil: Date? = nil, spatialRegionId: String? = nil) {
        self.configurationId = configurationId
        self.stateId = stateId
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.spatialRegionId = spatialRegionId
    }
}

public struct VAOLiteral: Codable, Sendable, Equatable {
    public var value: VAOJSONValue
    public var datatype: String?
    public var language: String?
    public var unit: String?

    public init(value: VAOJSONValue, datatype: String? = nil, language: String? = nil, unit: String? = nil) {
        self.value = value
        self.datatype = datatype
        self.language = language
        self.unit = unit
    }
}

public struct VAORelation: Codable, Sendable, Equatable {
    public var id: String
    public var subjectId: String
    public var predicate: String
    public var objectId: String?
    public var literal: VAOLiteral?
    public var status: String
    public var confidence: Double?
    public var scope: VAORelationScope?
    public var evidenceIds: [String]?
    public var generatedByIds: [String]?
    public var properties: [String: VAOJSONValue]?

    public init(
        id: String = "urn:uuid:\(UUID().uuidString.lowercased())",
        subjectId: String,
        predicate: String,
        objectId: String,
        status: String = "asserted",
        confidence: Double? = nil,
        scope: VAORelationScope? = nil,
        evidenceIds: [String]? = nil,
        generatedByIds: [String]? = nil,
        properties: [String: VAOJSONValue]? = nil
    ) {
        self.id = id
        self.subjectId = subjectId
        self.predicate = predicate
        self.objectId = objectId
        self.literal = nil
        self.status = status
        self.confidence = confidence
        self.scope = scope
        self.evidenceIds = evidenceIds
        self.generatedByIds = generatedByIds
        self.properties = properties
    }

    public init(
        id: String = "urn:uuid:\(UUID().uuidString.lowercased())",
        subjectId: String,
        predicate: String,
        literal: VAOLiteral,
        status: String = "asserted",
        confidence: Double? = nil,
        scope: VAORelationScope? = nil,
        evidenceIds: [String]? = nil,
        generatedByIds: [String]? = nil,
        properties: [String: VAOJSONValue]? = nil
    ) {
        self.id = id
        self.subjectId = subjectId
        self.predicate = predicate
        self.objectId = nil
        self.literal = literal
        self.status = status
        self.confidence = confidence
        self.scope = scope
        self.evidenceIds = evidenceIds
        self.generatedByIds = generatedByIds
        self.properties = properties
    }
}

public struct VAOAsset: Codable, Sendable, Equatable {
    public var id: String
    public var path: String
    public var mediaType: String
    public var byteSize: Int64
    public var sha256: String
    public var roles: [String]
    public var representationStatus: String
    public var aboutEntityIds: [String]
    public var originalFilename: String?
    public var createdAt: Date?
    public var encoding: String?
    public var properties: [String: VAOJSONValue]?

    public init(id: String, path: String, mediaType: String, byteSize: Int64, sha256: String, roles: [String], representationStatus: String, aboutEntityIds: [String], originalFilename: String? = nil, createdAt: Date? = nil, encoding: String? = nil, properties: [String: VAOJSONValue]? = nil) {
        self.id = id
        self.path = path
        self.mediaType = mediaType
        self.byteSize = byteSize
        self.sha256 = sha256
        self.roles = roles
        self.representationStatus = representationStatus
        self.aboutEntityIds = aboutEntityIds
        self.originalFilename = originalFilename
        self.createdAt = createdAt
        self.encoding = encoding
        self.properties = properties
    }
}

public struct VAOSoftware: Codable, Sendable, Equatable {
    public var name: String
    public var version: String
    public var uri: String?
    public var build: String?

    public init(name: String, version: String, uri: String? = nil, build: String? = nil) {
        self.name = name
        self.version = version
        self.uri = uri
        self.build = build
    }
}

public struct VAOParadata: Codable, Sendable, Equatable {
    public var id: String
    public var activityType: String
    public var startedAt: Date
    public var endedAt: Date?
    public var actorIds: [String]?
    public var software: VAOSoftware
    public var method: [String: VAOJSONValue]?
    public var inputIds: [String]
    public var outputIds: [String]
    public var parameters: [String: VAOJSONValue]
    public var notes: String?

    public init(id: String, activityType: String, startedAt: Date, endedAt: Date? = nil, actorIds: [String]? = nil, software: VAOSoftware, method: [String: VAOJSONValue]? = nil, inputIds: [String], outputIds: [String], parameters: [String: VAOJSONValue], notes: String? = nil) {
        self.id = id
        self.activityType = activityType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.actorIds = actorIds
        self.software = software
        self.method = method
        self.inputIds = inputIds
        self.outputIds = outputIds
        self.parameters = parameters
        self.notes = notes
    }
}

public struct VAOTimeRange: Codable, Sendable, Equatable {
    public var startSeconds: Double
    public var endSeconds: Double
    public var startFrameInclusive: Int64?
    public var endFrameExclusive: Int64?
    public var sampleRate: Double?
    public var clockAssetId: String?

    public init(
        startSeconds: Double,
        endSeconds: Double,
        startFrameInclusive: Int64? = nil,
        endFrameExclusive: Int64? = nil,
        sampleRate: Double? = nil,
        clockAssetId: String? = nil
    ) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.startFrameInclusive = startFrameInclusive
        self.endFrameExclusive = endFrameExclusive
        self.sampleRate = sampleRate
        self.clockAssetId = clockAssetId
    }
}

public struct VAOObservation: Codable, Sendable, Equatable {
    public var property: String
    public var value: VAOJSONValue
    public var unit: String?
    public var uncertainty: Double?
    public var confidence: Double?
    public var coverage: Double?
    public var evidenceCount: Int?
    public var status: String?
    public var applicability: String?
    public var censoring: String?
    public var aggregation: String?
    public var subjectId: String?
    public var sourceRegionId: String?
    public var valueAssetId: String?
    public var channelIndices: [Int]?
    public var qualityFlags: [String]?
    public var timeRange: VAOTimeRange?

    public init(
        property: String,
        value: VAOJSONValue,
        unit: String? = nil,
        uncertainty: Double? = nil,
        confidence: Double? = nil,
        coverage: Double? = nil,
        evidenceCount: Int? = nil,
        status: String? = nil,
        applicability: String? = nil,
        censoring: String? = nil,
        aggregation: String? = nil,
        subjectId: String? = nil,
        sourceRegionId: String? = nil,
        valueAssetId: String? = nil,
        channelIndices: [Int]? = nil,
        qualityFlags: [String]? = nil,
        timeRange: VAOTimeRange? = nil
    ) {
        self.property = property
        self.value = value
        self.unit = unit
        self.uncertainty = uncertainty
        self.confidence = confidence
        self.coverage = coverage
        self.evidenceCount = evidenceCount
        self.status = status
        self.applicability = applicability
        self.censoring = censoring
        self.aggregation = aggregation
        self.subjectId = subjectId
        self.sourceRegionId = sourceRegionId
        self.valueAssetId = valueAssetId
        self.channelIndices = channelIndices
        self.qualityFlags = qualityFlags
        self.timeRange = timeRange
    }
}

public struct VAOAnalysis: Codable, Sendable, Equatable {
    public var id: String
    public var analysisType: String
    public var method: String
    public var version: String
    public var generatedAt: Date
    public var inputIds: [String]
    public var outputIds: [String]
    public var paradataId: String?
    public var observations: [VAOObservation]
    public var qualityFlags: [String]?

    public init(id: String, analysisType: String, method: String, version: String, generatedAt: Date, inputIds: [String], outputIds: [String], paradataId: String? = nil, observations: [VAOObservation], qualityFlags: [String]? = nil) {
        self.id = id
        self.analysisType = analysisType
        self.method = method
        self.version = version
        self.generatedAt = generatedAt
        self.inputIds = inputIds
        self.outputIds = outputIds
        self.paradataId = paradataId
        self.observations = observations
        self.qualityFlags = qualityFlags
    }
}

public struct VAORights: Codable, Sendable, Equatable {
    public var appliesToIds: [String]
    public var license: String?
    public var rightsHolderId: String?
    public var statement: [String: String]
    public var accessCondition: String?
    public var creditLine: String?

    public init(appliesToIds: [String], license: String? = nil, rightsHolderId: String? = nil, statement: [String: String], accessCondition: String? = nil, creditLine: String? = nil) {
        self.appliesToIds = appliesToIds
        self.license = license
        self.rightsHolderId = rightsHolderId
        self.statement = statement
        self.accessCondition = accessCondition
        self.creditLine = creditLine
    }
}

public struct VAOIntegrity: Codable, Sendable, Equatable {
    public var algorithm: String
    public var assetCount: Int
    public var totalPayloadBytes: Int64
    public var payloadMerkleRoot: String?
    public var signatureProfile: String?

    public init(algorithm: String = "sha256", assetCount: Int, totalPayloadBytes: Int64, payloadMerkleRoot: String? = nil, signatureProfile: String? = nil) {
        self.algorithm = algorithm
        self.assetCount = assetCount
        self.totalPayloadBytes = totalPayloadBytes
        self.payloadMerkleRoot = payloadMerkleRoot
        self.signatureProfile = signatureProfile
    }
}

public struct VAOManifest: Codable, Sendable, Equatable {
    public var schema: String
    public var context: [String]
    public var type: String
    public var formatVersion: String
    public var id: String
    public var revision: Int
    public var createdAt: Date
    public var modifiedAt: Date
    public var title: [String: String]
    public var description: [String: String]?
    public var conformsTo: [String]
    public var profiles: [VAOProfile]
    public var modavisBinding: VAOModavisBinding
    public var primaryEntityId: String
    public var focusEntityIds: [String]
    public var entities: [VAOEntity]
    public var relations: [VAORelation]
    public var assets: [VAOAsset]
    public var paradata: [VAOParadata]
    public var analyses: [VAOAnalysis]
    /// Closed acoustic technical layer. Its record shapes are checked by the
    /// native schema and semantic validators while JSONValue preserves future
    /// patch-line additions without inventing application-specific classes.
    public var acoustics: [String: VAOJSONValue]?
    public var rights: [VAORights]
    public var integrity: VAOIntegrity
    public var extensions: [String: VAOJSONValue]?

    public init(
        schema: String = VAOContract.schemaURI,
        context: [String] = [VAOContract.contextURI],
        type: String = "VirtualAcousticObject",
        formatVersion: String = VAOContract.formatVersion,
        id: String,
        revision: Int,
        createdAt: Date,
        modifiedAt: Date,
        title: [String: String],
        description: [String: String]? = nil,
        conformsTo: [String],
        profiles: [VAOProfile],
        modavisBinding: VAOModavisBinding,
        primaryEntityId: String,
        focusEntityIds: [String]? = nil,
        entities: [VAOEntity],
        relations: [VAORelation],
        assets: [VAOAsset],
        paradata: [VAOParadata],
        analyses: [VAOAnalysis],
        acoustics: [String: VAOJSONValue]? = nil,
        rights: [VAORights],
        integrity: VAOIntegrity,
        extensions: [String: VAOJSONValue]? = nil
    ) {
        self.schema = schema
        self.context = context
        self.type = type
        self.formatVersion = formatVersion
        self.id = id
        self.revision = revision
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.title = title
        self.description = description
        self.conformsTo = conformsTo
        self.profiles = profiles
        self.modavisBinding = modavisBinding
        self.primaryEntityId = primaryEntityId
        self.focusEntityIds = focusEntityIds ?? [primaryEntityId]
        self.entities = entities
        self.relations = relations
        self.assets = assets
        self.paradata = paradata
        self.analyses = analyses
        self.acoustics = acoustics
        self.rights = rights
        self.integrity = integrity
        self.extensions = extensions
    }

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case context = "@context"
        case type, formatVersion, id, revision, createdAt, modifiedAt, title, description
        case conformsTo, profiles, modavisBinding, primaryEntityId, focusEntityIds, entities, relations, assets
        case paradata, analyses, acoustics, rights, integrity, extensions
    }

    /// Source compatibility for OrgRec code that still uses its historical
    /// instrument-root terminology. VAO 0.2 serializes only primaryEntityId.
    public var rootEntityId: String {
        get { primaryEntityId }
        set {
            primaryEntityId = newValue
            if !focusEntityIds.contains(newValue) { focusEntityIds.insert(newValue, at: 0) }
        }
    }
}

public struct VAOValidationReport: Codable, Sendable, Equatable {
    public var contractVersion: String?
    public var checkedAt: Date
    public var errors: [String]
    public var warnings: [String]
    public var verifiedAssetCount: Int
    public var verifiedPayloadBytes: Int64

    public var isValid: Bool { errors.isEmpty }
}
