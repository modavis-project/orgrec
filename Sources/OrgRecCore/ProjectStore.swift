import Foundation

public actor ProjectStore {
    public static let projectFilename = "project.json"

    public init() {}

    public func createPackage(at packageURL: URL, project: OrgRecProject) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: packageURL, withIntermediateDirectories: true)
        for path in [
            "Manifests",
            "Audio/Originals",
            "Audio/LongTakes",
            "Audio/Derivatives",
            "Audio/Calibration",
            "Analysis/Pitch",
            "Analysis/Derivatives",
            "Analysis/SpectrogramTiles",
            "Sensors/Raw",
            "Sensors/Calibration",
            "Sensors/Derived",
            "Sensors/Decoded",
            "Metadata/SensorCaptures",
            "Documentation/Photos",
            "Documentation/Plans",
            "Exports",
        ] {
            try manager.createDirectory(at: packageURL.appendingPathComponent(path, isDirectory: true), withIntermediateDirectories: true)
        }
        try save(project, at: packageURL)
    }

    public func load(from packageURL: URL) throws -> OrgRecProject {
        let projectFileURL = try validatedPackageRelativeURL(Self.projectFilename, in: packageURL)
        let data = try Data(contentsOf: projectFileURL)
        var project = try OrgRecCoding.decoder.decode(OrgRecProject.self, from: data)
        guard project.schemaVersion == 1 else {
            throw OrgRecError.invalidProject("Unsupported OrgRec project schema version \(project.schemaVersion).")
        }
        try validateUniqueIdentifiers(in: project)
        let navigatorPayloadURL = try validateRetainedPackagePaths(in: project, packageURL: packageURL)
        if project.navigatorPayloadRelativePath != nil {
            if project.documentedPitchStandard == nil,
               let navigatorPayloadURL,
               let payload = try? Data(contentsOf: navigatorPayloadURL),
               let object = try? JSONSerialization.jsonObject(with: payload),
               let pitch = NavigatorClient.documentedPitchStandard(
                   in: object,
                   release: project.snapshot.release.requestedRelease
               ) {
                project.documentedPitchStandard = pitch
                project.organCharacteristics?.referencePitchHz = pitch.frequencyHz
                if project.recordingSessions?.contains(where: { $0.tuningCalibrationID != nil }) != true {
                    RoadmapEngine.applyFieldReferencePitch(pitch.frequencyHz, to: &project)
                }
            }
        }
        return project
    }

    public func save(_ project: OrgRecProject, at packageURL: URL) throws {
        var updated = project
        updated.updatedAt = Date()
        updated.software = OrgRecSoftware.current
        let data = try OrgRecCoding.encoder.encode(updated)
        let destination = packageURL.appendingPathComponent(Self.projectFilename)
        let temporary = packageURL.appendingPathComponent(".project-\(UUID().uuidString).json")
        try data.write(to: temporary, options: .atomic)
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try FileManager.default.moveItem(at: temporary, to: destination)
        }
    }

    public func storeNavigatorPayload(
        _ data: Data,
        expectedSHA256: String,
        relativePath: String,
        at packageURL: URL
    ) throws {
        guard data.sha256Hex == expectedSHA256 else {
            throw OrgRecError.invalidNavigatorResponse("Navigator payload checksum changed before it could be frozen in the project.")
        }
        let destination = try validatedPackageRelativeURL(relativePath, in: packageURL)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
    }

    public func recoverInterruptedTakes(in project: OrgRecProject, packageURL: URL) -> OrgRecProject {
        var copy = project
        for index in copy.takes.indices where copy.takes[index].status == .recording || copy.takes[index].status == .analyzing {
            let interruptedStatus = copy.takes[index].status
            let file = packageURL.appendingPathComponent(copy.takes[index].relativeAudioPath)
            let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values?.isRegularFile == true,
                  values?.isSymbolicLink != true,
                  (values?.fileSize ?? 0) > 0 else {
                copy.takes[index].status = .failed
                copy.takes[index].endedAt = copy.takes[index].endedAt ?? .now
                var integrityFaults = copy.takes[index].captureIntegrityFaults ?? []
                integrityFaults.append(CaptureFault(
                    kind: .interruptedCapture,
                    message: "Interrupted take has no recoverable regular audio file."
                ))
                copy.takes[index].captureIntegrityFaults = integrityFaults
                copy.takes[index].reviewReason = [
                    copy.takes[index].reviewReason,
                    "Interrupted take has no recoverable regular audio file.",
                ].compactMap { $0 }.joined(separator: " ")
                if let roadmapIndex = copy.roadmap.firstIndex(where: { $0.id == copy.takes[index].roadmapItemID }) {
                    copy.roadmap[roadmapIndex].state = .needsReview
                }
                continue
            }
            copy.takes[index].fileSize = Int64(values?.fileSize ?? 0)
            copy.takes[index].sha256 = try? sha256(of: file)
            if interruptedStatus == .recording {
                copy.takes[index].status = .failed
                copy.takes[index].endedAt = copy.takes[index].endedAt ?? .now
                var integrityFaults = copy.takes[index].captureIntegrityFaults ?? []
                integrityFaults.append(CaptureFault(
                    kind: .interruptedCapture,
                    message: "Recording finalization was interrupted; Broadcast Wave integrity is not established."
                ))
                copy.takes[index].captureIntegrityFaults = integrityFaults
                copy.takes[index].reviewReason = [
                    copy.takes[index].reviewReason,
                    "Recording finalization was interrupted; Broadcast Wave integrity is not established and the take must be replaced.",
                ].compactMap { $0 }.joined(separator: " ")
            } else {
                copy.takes[index].status = .recovered
                copy.takes[index].reviewReason = [
                    copy.takes[index].reviewReason,
                    "Recovered after an interrupted analysis operation; reanalysis and human review are required.",
                ].compactMap { $0 }.joined(separator: " ")
            }
            if let roadmapIndex = copy.roadmap.firstIndex(where: { $0.id == copy.takes[index].roadmapItemID }) {
                copy.roadmap[roadmapIndex].state = .needsReview
            }
        }
        return copy
    }

    private func validateUniqueIdentifiers(in project: OrgRecProject) throws {
        try requireUnique(project.devices.map(\.id), collection: "device")
        try requireUnique(project.setups.map(\.id), collection: "microphone setup")
        try requireUnique(project.registrations.map(\.id), collection: "registration")
        try requireUnique(project.roadmap.map(\.id), collection: "roadmap item")
        try requireUnique(project.takes.map(\.id), collection: "take")
        try requireUnique((project.recordingSessions ?? []).map(\.id), collection: "recording session")
        try requireUnique(
            (project.recordingSessions ?? []).flatMap { ($0.capturePreflightReports ?? []).map(\.id) },
            collection: "capture preflight report"
        )
        try requireUnique((project.tuningCalibrations ?? []).map(\.id), collection: "tuning calibration")
        try requireUnique((project.longTakeSources ?? []).map(\.id), collection: "long-take source")
        try requireUnique((project.noiseContextAssessments ?? []).map(\.id), collection: "noise-context assessment")
        try requireUnique((project.sessionPlans ?? []).map(\.id), collection: "recording-session plan")
        try requireUnique((project.controlBindings ?? []).map(\.id), collection: "control binding")
        try requireUnique((project.captureStates ?? []).map(\.id), collection: "capture state")
        try requireUnique((project.spatialGeometrySnapshots ?? []).map(\.id), collection: "spatial-geometry snapshot")
        try requireUnique((project.interactionSensorConfigurations ?? []).map(\.id), collection: "interaction-sensor configuration")
        try requireUnique((project.interactionSensorCalibrations ?? []).map(\.id), collection: "interaction-sensor calibration")
        try requireUnique((project.interactionSensorValidations ?? []).map(\.id), collection: "interaction-sensor validation")

        for take in project.takes {
            try requireUnique((take.analysisRuns ?? []).map(\.id), collection: "analysis run in take \(take.id.uuidString)")
            try requireUnique((take.loopPointSets ?? []).map(\.id), collection: "loop-point set in take \(take.id.uuidString)")
            try requireUnique((take.loopPointReviews ?? []).map(\.id), collection: "loop-point review in take \(take.id.uuidString)")
            try requireUnique((take.interactionSensorCaptures ?? []).map(\.id), collection: "interaction-sensor capture in take \(take.id.uuidString)")
            if let boundaries = take.analysis?.boundaries {
                try requireUnique(boundaries.map(\.id), collection: "analysis boundary in take \(take.id.uuidString)")
            }
            if let spectral = take.analysis?.perceptualSpectralSummary,
               let error = spectral.validationErrors.first {
                throw OrgRecError.invalidProject("Take \(take.id.uuidString): \(error)")
            }
            if let response = take.analysis?.acousticResponseAnalysis,
               let error = response.validationErrors.first {
                throw OrgRecError.invalidProject("Take \(take.id.uuidString): \(error)")
            }
            if let paradata = take.spatialAcousticParadata,
               let response = paradata.observation?.acousticResponseAnalysis {
                if let error = response.validationErrors.first {
                    throw OrgRecError.invalidProject("Spatial response in take \(take.id.uuidString): \(error)")
                }
                if paradata.protocolSnapshot.effectiveExcitation.responseQualification == nil {
                    throw OrgRecError.invalidProject("Spatial response in take \(take.id.uuidString) contains room metrics without a declared impulse-response excitation.")
                }
            }
        }
    }

    private func requireUnique<ID: Hashable>(_ identifiers: [ID], collection: String) throws {
        var seen: Set<ID> = []
        for identifier in identifiers where seen.insert(identifier).inserted == false {
            throw OrgRecError.invalidProject("The project contains a duplicate \(collection) identifier.")
        }
    }

    private func validateRetainedPackagePaths(in project: OrgRecProject, packageURL: URL) throws -> URL? {
        for setup in project.setups {
            try validateDocumentationPaths(setup.documentationPaths, owner: "Microphone setup \(setup.id.uuidString)", packageURL: packageURL)
        }

        for take in project.takes {
            _ = try validatePath(
                take.relativeAudioPath,
                prefix: "Audio/Originals/",
                description: "Take \(take.id.uuidString) original audio",
                packageURL: packageURL
            )
            if let source = take.longTakeSource {
                _ = try validatePath(
                    source.sourceRelativeAudioPath,
                    prefix: "Audio/LongTakes/",
                    description: "Take \(take.id.uuidString) long-take source",
                    packageURL: packageURL
                )
            }
            for run in take.analysisRuns ?? [] {
                for artifactPath in run.artifactRelativePaths ?? [] {
                    _ = try validatePath(
                        artifactPath,
                        prefix: "Analysis/",
                        description: "Analysis run \(run.id.uuidString) artifact",
                        packageURL: packageURL
                    )
                }
            }
            for sensorCapture in take.interactionSensorCaptures ?? [] {
                _ = try validatePath(
                    sensorCapture.rawRelativePath,
                    prefix: "Sensors/Raw/",
                    description: "Take \(take.id.uuidString) interaction-sensor raw data",
                    packageURL: packageURL
                )
                _ = try validatePath(
                    sensorCapture.metadataRelativePath,
                    prefix: "Metadata/SensorCaptures/",
                    description: "Take \(take.id.uuidString) interaction-sensor metadata",
                    packageURL: packageURL
                )
                if let derivedPath = sensorCapture.derivedRelativePath {
                    _ = try validatePath(
                        derivedPath,
                        prefix: "Sensors/Derived/",
                        description: "Take \(take.id.uuidString) interaction-sensor derived data",
                        packageURL: packageURL
                    )
                }
            }
            if let provenanceSetup = take.provenance?.microphoneSetup {
                try validateDocumentationPaths(
                    provenanceSetup.documentationPaths,
                    owner: "Take \(take.id.uuidString) microphone-setup snapshot",
                    packageURL: packageURL
                )
            }
            if let calibrationPath = take.provenance?.tuningCalibration?.relativeAudioPath {
                _ = try validatePath(
                    calibrationPath,
                    prefix: "Audio/Calibration/",
                    description: "Take \(take.id.uuidString) tuning-calibration snapshot audio",
                    packageURL: packageURL
                )
            }
        }

        for session in project.recordingSessions ?? [] {
            for report in session.capturePreflightReports ?? [] {
                _ = try validatePath(
                    report.relativeAudioPath,
                    prefix: "Audio/Calibration/",
                    description: "Capture preflight \(report.id.uuidString) audio",
                    packageURL: packageURL
                )
            }
        }

        for source in project.longTakeSources ?? [] {
            _ = try validatePath(
                source.relativeAudioPath,
                prefix: "Audio/LongTakes/",
                description: "Long take \(source.id.uuidString) source audio",
                packageURL: packageURL
            )
        }
        for calibration in project.tuningCalibrations ?? [] {
            if let audioPath = calibration.relativeAudioPath {
                _ = try validatePath(
                    audioPath,
                    prefix: "Audio/Calibration/",
                    description: "Tuning calibration \(calibration.id.uuidString) audio",
                    packageURL: packageURL
                )
            }
        }

        let navigatorPayloadURL: URL?
        if let payloadPath = project.navigatorPayloadRelativePath {
            navigatorPayloadURL = try validatePath(
                payloadPath,
                prefix: "Manifests/",
                description: "Navigator payload",
                packageURL: packageURL
            )
        } else {
            navigatorPayloadURL = nil
        }
        if let importedVAO = project.importedVAO {
            let path = importedVAO.sourceArchiveRelativePath
            guard path.hasSuffix("/source.vao") else {
                throw OrgRecError.invalidProject("The retained VAO source path is unsafe: \(path)")
            }
            _ = try validatePath(
                path,
                prefix: "Manifests/ImportedVAO/",
                description: "Retained VAO source",
                packageURL: packageURL
            )
        }
        return navigatorPayloadURL
    }

    private func validateDocumentationPaths(_ paths: [String], owner: String, packageURL: URL) throws {
        for path in paths {
            _ = try validatePath(
                path,
                prefix: "Documentation/",
                description: "\(owner) documentation",
                packageURL: packageURL
            )
        }
    }

    private func validatePath(
        _ path: String,
        prefix: String,
        description: String,
        packageURL: URL
    ) throws -> URL {
        guard isSafePackageRelativePath(path), path.hasPrefix(prefix) else {
            throw OrgRecError.invalidProject("\(description) has an unsafe package-relative path: \(path)")
        }
        return try validatedPackageRelativeURL(path, in: packageURL)
    }
}
