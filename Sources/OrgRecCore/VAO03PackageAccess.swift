import Foundation

public struct VAO03CoordinateFrameDescriptor: Sendable, Equatable, Identifiable {
    public var id: String
    public var dimension: Int
    public var unit: String
    public var handedness: String
    public var upAxis: String
    public var forwardAxis: String
    public var parentFrameId: String?
    public var transformToParent: [Double]?
}

public struct VAO03PoseDescriptor: Sendable, Equatable, Identifiable {
    public var id: String
    public var subjectId: String
    public var frameId: String
    public var position: [Double]
    public var orientationXYZW: [Double]?
}

public struct VAO03ResponseMeasurementDescriptor: Sendable, Equatable, Identifiable {
    public var id: String
    public var sourceId: String
    public var receiverId: String
    public var sourcePoseId: String
    public var receiverPoseId: String
    public var spaceId: String?
}

public struct VAO03GeometryResourceDescriptor: Sendable, Equatable, Identifiable {
    public var id: String { realizationId }
    public var logicalAssetId: String
    public var realizationId: String
    public var mediaType: String
    public var byteSize: Int64
    public var sha256: String
    public var coordinateFrameId: String
    public var bindingRoles: [String]
    public var embeddedPath: String?
}

public struct VAO03ImpulseResponseResourceDescriptor: Sendable, Equatable, Identifiable {
    public var id: String { realizationId }
    public var logicalAssetId: String
    public var realizationId: String
    public var responseSetId: String
    public var mediaType: String
    public var encoding: String
    public var sampleRate: Double
    public var sampleCount: Int64
    public var channelCount: Int
    public var measurementIds: [String]
    public var byteSize: Int64
    public var sha256: String
    public var embeddedPath: String?
}

public struct VAO03AcousticSceneDescriptor: Sendable, Equatable {
    public var coordinateFrames: [VAO03CoordinateFrameDescriptor]
    public var poses: [VAO03PoseDescriptor]
    public var measurements: [VAO03ResponseMeasurementDescriptor]
    public var geometryResources: [VAO03GeometryResourceDescriptor]
    public var impulseResponseResources: [VAO03ImpulseResponseResourceDescriptor]
    public var audioSceneCount: Int
    public var renderConfigurationCount: Int
}

public struct VAO03PlayableAudioResourceDescriptor: Sendable, Equatable, Identifiable {
    public var id: String { realizationId }
    public var realizationId: String
    public var logicalAssetId: String
    public var mediaType: String
    public var sampleRate: Double
    public var channelCount: Int
    public var frameCount: Int64?
    public var variantIds: [String]
    public var signalRoles: [String]
    public var embeddedPath: String?
}

public struct VAO03PlayableInstrumentDescriptor: Sendable, Equatable {
    public var signalRegions: [VAO03SignalRegion]
    public var loopPointSets: [VAO03LoopPointSet]
    public var tuningMaps: [VAO03TuningMap]
    public var perspectiveGroups: [VAO03PerspectiveGroup]
    public var sampleVariants: [VAO03SampleVariant]
    public var sampleMappings: [VAO03SampleMapping]
    public var audioResources: [VAO03PlayableAudioResourceDescriptor]
}

public struct VAO03ComplexInstrumentDescriptor: Sendable, Equatable {
    public var interactionModel: VAO03InteractionModel?
    public var captureDocumentation: VAO03CaptureDocumentation?

    public var controlCount: Int { interactionModel?.controls.count ?? 0 }
    public var stateVariableCount: Int { interactionModel?.stateVariables.count ?? 0 }
    public var routingRuleCount: Int { interactionModel?.routingRules.count ?? 0 }
    public var processCount: Int { interactionModel?.processModels.count ?? 0 }
    public var eventAlignmentCount: Int { captureDocumentation?.eventAlignments.count ?? 0 }
    public var derivationCount: Int { captureDocumentation?.derivationMaps.count ?? 0 }
}

public struct VAO03PackageInspection: Sendable, Equatable {
    public var manifest: VAO03Manifest
    public var carrier: VAO03Carrier
    public var errors: [String]
    public var verifiedPayloadBytes: Int64
    public var acousticScene: VAO03AcousticSceneDescriptor?
    public var playableInstrument: VAO03PlayableInstrumentDescriptor?
    public var complexInstrument: VAO03ComplexInstrumentDescriptor?

    public var isValid: Bool { errors.isEmpty }
    public var displayTitle: String {
        manifest.title["en"] ?? manifest.title["und"] ?? manifest.title.values.sorted().first ?? manifest.id
    }
}

/// Read-only, instrument-neutral access to exact VAO 0.3.3 carriers. OrgRec
/// validates and exposes visual-acoustic metadata and assets but does not claim
/// to be an acoustic simulator or renderer.
public actor VAO03PackageReader {
    private static let maximumCarrierDescriptorBytes: UInt64 = 64 * 1_024 * 1_024

    public init() {}

    public nonisolated static func formatVersion(of packageURL: URL) throws -> String? {
        let archive = try VAOArchiveReader(url: packageURL)
        guard let entry = archive.entry(named: VAO03Contract.manifestFilename) else { return nil }
        let data = try archive.data(for: entry, maximumSize: VAOArchiveReader.maximumManifestBytes)
        return VAOFormatDispatcher.formatVersion(in: data)
    }

    public func inspect(_ packageURL: URL) throws -> VAO03PackageInspection {
        let archive = try VAOArchiveReader(url: packageURL)
        guard archive.entries.first?.path == "mimetype",
              let mimetypeEntry = archive.entry(named: "mimetype"),
              let manifestEntry = archive.entry(named: VAO03Contract.manifestFilename),
              let carrierEntry = archive.entry(named: VAO03Contract.carrierFilename) else {
            throw OrgRecError.invalidProject("The VAO 0.3 carrier is missing or misorders a structural entry.")
        }
        let mimetype = try archive.data(for: mimetypeEntry, maximumSize: 256)
        guard mimetype == Data(VAO03Contract.mediaType.utf8) else {
            throw OrgRecError.invalidProject("The VAO 0.3 carrier has the wrong mimetype bytes.")
        }
        let manifestData = try archive.data(for: manifestEntry, maximumSize: VAOArchiveReader.maximumManifestBytes)
        guard VAOFormatDispatcher.formatVersion(in: manifestData) == VAO03Contract.formatVersion else {
            throw OrgRecError.invalidProject("OrgRec expected VAO \(VAO03Contract.formatVersion) for the 0.3 reader.")
        }
        let carrierData = try archive.data(for: carrierEntry, maximumSize: Self.maximumCarrierDescriptorBytes)
        let manifest = try VAOFormatDispatcher.decode03(manifestData)
        let carrier = try JSONDecoder().decode(VAO03Carrier.self, from: carrierData)

        let allowed = Set(["mimetype", VAO03Contract.manifestFilename, VAO03Contract.carrierFilename])
        var errors = archive.entries.compactMap { entry -> String? in
            entry.path.hasPrefix("payload/") || allowed.contains(entry.path)
                ? nil
                : "Unknown VAO 0.3 carrier entry \(entry.path)."
        }
        var verification: [String: VAO03EmbeddedFileVerification] = [:]
        var verifiedBytes: Int64 = 0
        for entry in archive.entries where entry.path.hasPrefix("payload/") {
            let result = try archive.sha256(for: entry)
            verification[entry.path] = VAO03EmbeddedFileVerification(sha256: result.digest, byteSize: result.size)
            verifiedBytes += result.size
        }
        errors.append(contentsOf: VAO03Validator.validateCarrier(
            manifestData: manifestData,
            carrierData: carrierData,
            embeddedVerification: verification
        ))
        errors = Array(Set(errors)).sorted()
        return VAO03PackageInspection(
            manifest: manifest,
            carrier: carrier,
            errors: errors,
            verifiedPayloadBytes: verifiedBytes,
            acousticScene: Self.acousticScene(manifest: manifest, carrier: carrier),
            playableInstrument: Self.playableInstrument(manifest: manifest, carrier: carrier),
            complexInstrument: manifest.interactionModel == nil && manifest.captureDocumentation == nil
                ? nil
                : VAO03ComplexInstrumentDescriptor(
                    interactionModel: manifest.interactionModel,
                    captureDocumentation: manifest.captureDocumentation
                )
        )
    }

    /// Imports the exact structural records and every embedded realization to
    /// a directory-form inspection workspace. Remote distributions are not
    /// fetched and no semantic record is rewritten.
    @discardableResult
    public func importWorkspace(from packageURL: URL, to destination: URL) throws -> VAO03PackageInspection {
        let inspection = try inspect(packageURL)
        guard inspection.isValid else {
            throw OrgRecError.invalidProject("VAO 0.3 validation failed: " + inspection.errors.prefix(3).joined(separator: "; "))
        }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else {
            throw OrgRecError.invalidProject("The VAO 0.3 workspace destination already exists.")
        }
        let archive = try VAOArchiveReader(url: packageURL)
        let realizations = Dictionary(uniqueKeysWithValues: inspection.manifest.realizations.map { ($0.id, $0) })
        do {
            try manager.createDirectory(at: destination, withIntermediateDirectories: true)
            for path in ["mimetype", VAO03Contract.manifestFilename, VAO03Contract.carrierFilename] {
                guard let entry = archive.entry(named: path) else {
                    throw OrgRecError.invalidProject("The VAO 0.3 carrier is missing \(path).")
                }
                let target = destination.appendingPathComponent(path)
                try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try archive.data(for: entry, maximumSize: path == "mimetype" ? 256 : Self.maximumCarrierDescriptorBytes)
                    .write(to: target, options: .atomic)
            }
            for mapping in inspection.carrier.embeddedRealizations {
                guard let entry = archive.entry(named: mapping.path),
                      let realization = realizations[mapping.realizationId] else {
                    throw OrgRecError.invalidProject("The VAO 0.3 carrier has an unresolved embedded mapping.")
                }
                try archive.extract(
                    entry,
                    to: destination.appendingPathComponent(mapping.path),
                    expectedSHA256: realization.sha256
                )
            }
            return inspection
        } catch {
            try? manager.removeItem(at: destination)
            throw error
        }
    }

    public func extractRealization(id: String, from packageURL: URL, to destination: URL) throws {
        let inspection = try inspect(packageURL)
        guard inspection.isValid else {
            throw OrgRecError.invalidProject("VAO 0.3 validation failed: " + inspection.errors.prefix(3).joined(separator: "; "))
        }
        guard let realization = inspection.manifest.realizations.first(where: { $0.id == id }) else {
            throw OrgRecError.invalidProject("The VAO 0.3 carrier has no realization \(id).")
        }
        guard let mapping = inspection.carrier.embeddedRealizations.first(where: { $0.realizationId == id }) else {
            throw OrgRecError.invalidProject("Realization \(id) is not embedded in this carrier.")
        }
        let archive = try VAOArchiveReader(url: packageURL)
        guard let entry = archive.entry(named: mapping.path) else {
            throw OrgRecError.invalidProject("The VAO 0.3 carrier is missing \(mapping.path).")
        }
        try archive.extract(entry, to: destination, expectedSHA256: realization.sha256)
    }

    private static func acousticScene(manifest: VAO03Manifest, carrier: VAO03Carrier) -> VAO03AcousticSceneDescriptor? {
        guard let acoustics = manifest.acoustics?.objectValue else { return nil }
        func objects(_ name: String) -> [[String: VAOJSONValue]] {
            acoustics[name]?.arrayValue?.compactMap(\.objectValue) ?? []
        }
        func numbers(_ value: VAOJSONValue?) -> [Double] {
            value?.arrayValue?.compactMap(\.numberValue) ?? []
        }
        let embeddedPaths = Dictionary(uniqueKeysWithValues: carrier.embeddedRealizations.map { ($0.realizationId, $0.path) })
        let frames = objects("coordinateFrames").compactMap { value -> VAO03CoordinateFrameDescriptor? in
            guard let id = value["id"]?.stringValue,
                  let dimension = value["dimension"]?.integerValue,
                  let unit = value["unit"]?.stringValue,
                  let handedness = value["handedness"]?.stringValue,
                  let upAxis = value["upAxis"]?.stringValue,
                  let forwardAxis = value["forwardAxis"]?.stringValue else { return nil }
            return VAO03CoordinateFrameDescriptor(
                id: id, dimension: Int(dimension), unit: unit, handedness: handedness,
                upAxis: upAxis, forwardAxis: forwardAxis,
                parentFrameId: value["parentFrameId"]?.stringValue,
                transformToParent: value["transformToParent"].map(numbers)
            )
        }
        let poses = objects("poses").compactMap { value -> VAO03PoseDescriptor? in
            guard let id = value["id"]?.stringValue,
                  let subjectId = value["subjectId"]?.stringValue,
                  let frameId = value["frameId"]?.stringValue else { return nil }
            return VAO03PoseDescriptor(
                id: id, subjectId: subjectId, frameId: frameId, position: numbers(value["position"]),
                orientationXYZW: value["orientationXYZW"].map(numbers)
            )
        }
        let measurements = objects("measurements").compactMap { value -> VAO03ResponseMeasurementDescriptor? in
            guard let id = value["id"]?.stringValue,
                  let sourceId = value["sourceId"]?.stringValue,
                  let receiverId = value["receiverId"]?.stringValue,
                  let sourcePoseId = value["sourcePoseId"]?.stringValue,
                  let receiverPoseId = value["receiverPoseId"]?.stringValue else { return nil }
            return VAO03ResponseMeasurementDescriptor(
                id: id, sourceId: sourceId, receiverId: receiverId,
                sourcePoseId: sourcePoseId, receiverPoseId: receiverPoseId,
                spaceId: value["spaceId"]?.stringValue
            )
        }

        let bindingRoles = Dictionary(grouping: objects("geometryBindings"), by: { $0["logicalAssetId"]?.stringValue ?? "" })
            .mapValues { records in Array(Set(records.compactMap { $0["role"]?.stringValue })).sorted() }
        let assets = Dictionary(uniqueKeysWithValues: manifest.logicalAssets.map { ($0.id, $0) })
        let geometry = manifest.realizations.compactMap { realization -> VAO03GeometryResourceDescriptor? in
            guard realization.technicalMetadata.kind == "geometry",
                  let frameId = realization.technicalMetadata.coordinateFrameId,
                  let roles = bindingRoles[realization.assetId], !roles.isEmpty else { return nil }
            return VAO03GeometryResourceDescriptor(
                logicalAssetId: realization.assetId, realizationId: realization.id,
                mediaType: realization.mediaType, byteSize: realization.byteSize, sha256: realization.sha256,
                coordinateFrameId: frameId, bindingRoles: roles, embeddedPath: embeddedPaths[realization.id]
            )
        }
        let responses = manifest.realizations.compactMap { realization -> VAO03ImpulseResponseResourceDescriptor? in
            guard realization.technicalMetadata.kind == "audio",
                  let impulse = realization.technicalMetadata.impulseResponse?.objectValue,
                  let responseSetId = impulse["responseSetId"]?.stringValue,
                  let encoding = impulse["encoding"]?.stringValue,
                  let sampleCount = impulse["sampleCount"]?.integerValue,
                  let sampleRate = realization.technicalMetadata.sampleRate,
                  let channelCount = realization.technicalMetadata.channelCount,
                  assets[realization.assetId] != nil else { return nil }
            let measurementIds = impulse["measurementMappings"]?.arrayValue?.compactMap {
                $0.objectValue?["measurementId"]?.stringValue
            } ?? []
            return VAO03ImpulseResponseResourceDescriptor(
                logicalAssetId: realization.assetId, realizationId: realization.id,
                responseSetId: responseSetId, mediaType: realization.mediaType, encoding: encoding,
                sampleRate: sampleRate, sampleCount: sampleCount, channelCount: channelCount,
                measurementIds: measurementIds, byteSize: realization.byteSize, sha256: realization.sha256,
                embeddedPath: embeddedPaths[realization.id]
            )
        }
        return VAO03AcousticSceneDescriptor(
            coordinateFrames: frames.sorted { $0.id < $1.id },
            poses: poses.sorted { $0.id < $1.id },
            measurements: measurements.sorted { $0.id < $1.id },
            geometryResources: geometry.sorted { $0.realizationId < $1.realizationId },
            impulseResponseResources: responses.sorted { $0.realizationId < $1.realizationId },
            audioSceneCount: objects("audioScenes").count,
            renderConfigurationCount: objects("renderConfigurations").count
        )
    }

    private static func playableInstrument(manifest: VAO03Manifest, carrier: VAO03Carrier) -> VAO03PlayableInstrumentDescriptor? {
        guard let playable = manifest.playable else { return nil }
        let embeddedPaths = Dictionary(uniqueKeysWithValues: carrier.embeddedRealizations.map { ($0.realizationId, $0.path) })
        let variantsByRealization = Dictionary(grouping: playable.sampleVariants, by: \.realizationId)
        let resources = manifest.realizations.compactMap { realization -> VAO03PlayableAudioResourceDescriptor? in
            guard realization.technicalMetadata.kind == "audio",
                  let sampleRate = realization.technicalMetadata.sampleRate,
                  let channelCount = realization.technicalMetadata.channelCount,
                  let variants = variantsByRealization[realization.id], !variants.isEmpty else { return nil }
            return VAO03PlayableAudioResourceDescriptor(
                realizationId: realization.id,
                logicalAssetId: realization.assetId,
                mediaType: realization.mediaType,
                sampleRate: sampleRate,
                channelCount: channelCount,
                frameCount: realization.technicalMetadata.frameCount,
                variantIds: variants.map(\.id).sorted(),
                signalRoles: Array(Set(variants.map(\.signalRole))).sorted(),
                embeddedPath: embeddedPaths[realization.id]
            )
        }
        return VAO03PlayableInstrumentDescriptor(
            signalRegions: playable.signalRegions.sorted { $0.id < $1.id },
            loopPointSets: playable.loopPointSets.sorted { $0.id < $1.id },
            tuningMaps: playable.tuningMaps.sorted { $0.id < $1.id },
            perspectiveGroups: playable.perspectiveGroups.sorted { $0.id < $1.id },
            sampleVariants: playable.sampleVariants.sorted { $0.id < $1.id },
            sampleMappings: playable.sampleMappings.sorted { $0.id < $1.id },
            audioResources: resources.sorted { $0.realizationId < $1.realizationId }
        )
    }
}
