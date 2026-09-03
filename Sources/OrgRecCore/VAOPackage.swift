import Foundation

public actor VAOPackageBuilder {
    private struct RetainedPackage {
        var url: URL
        var manifest: VAOManifest
    }

    private struct RetainedMerge {
        var manifest: VAOManifest
        var preservedAssets: [VAOAsset]
    }

    public init() {}

    @discardableResult
    public func build(project sourceProject: OrgRecProject, packageURL: URL, destinationURL: URL) throws -> URL {
        var project = sourceProject
        project.collectionAnalysis = CollectionAnalysisEngine.refreshed(project: project)
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destinationURL.path) else {
            throw OrgRecError.exportValidation("The VAO destination already exists.")
        }
        guard fm.fileExists(atPath: packageURL.appendingPathComponent(ProjectStore.projectFilename).path) else {
            throw OrgRecError.exportValidation("The OrgRec project has no project.json.")
        }

        let retainedPackage = try retainedPackage(for: project, at: packageURL)
        let vaoID = retainedPackage?.manifest.id ?? "urn:uuid:\(UUID().uuidString.lowercased())"
        let instrumentID = "urn:uuid:\(project.id.uuidString.lowercased())"
        let now = Date()
        let files = try packageFiles(at: packageURL)
        var builtAssets: [(asset: VAOAsset, source: URL, originalPath: String)] = []
        for file in files {
            let archivePath = "payload/orgrec/\(file.relativePath)"
            let digest = try sha256(of: file.url)
            let size = Int64((try file.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            let identifier = stableURN(kind: "asset", value: archivePath)
            let about = assetSubjects(relativePath: file.relativePath, project: project, instrumentID: instrumentID)
            builtAssets.append((
                VAOAsset(
                    id: identifier,
                    path: archivePath,
                    mediaType: mediaType(for: file.url),
                    byteSize: size,
                    sha256: digest,
                    roles: [assetRole(for: file.relativePath)],
                    representationStatus: representationStatus(for: file.relativePath),
                    aboutEntityIds: about,
                    originalFilename: file.url.lastPathComponent,
                    createdAt: try? file.url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                    encoding: encodingDescription(for: file.url),
                    properties: [VAOContract.vaoNamespace + "orgrecRelativePath": .string(file.relativePath)]
                ),
                file.url,
                file.relativePath
            ))
        }

        let usedEmpiricalModelVersions = Set((project.timbreAnalyses ?? []).compactMap { $0.empiricalClassification?.modelVersion })
        if !usedEmpiricalModelVersions.isEmpty,
           let modelURL = OrgRecResources.bundle.url(forResource: "empirical-timbre-model-v1", withExtension: "json"),
           let model = try? OrgRecCoding.decoder.decode(EmpiricalTimbreClassifierModel.self, from: Data(contentsOf: modelURL)),
           usedEmpiricalModelVersions.contains(model.modelVersion) {
            let archivePath = "payload/models/empirical-timbre-model-v1.json"
            builtAssets.append((
                VAOAsset(
                    id: stableURN(kind: "asset", value: archivePath),
                    path: archivePath,
                    mediaType: "application/json",
                    byteSize: Int64((try modelURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0),
                    sha256: try sha256(of: modelURL),
                    roles: [VAOContract.machineLearningModelRole],
                    representationStatus: VAOContract.vaoVocabulary + "representation-status/learned",
                    aboutEntityIds: [instrumentID],
                    originalFilename: modelURL.lastPathComponent,
                    createdAt: model.trainedAt,
                    encoding: "UTF-8 JSON",
                    properties: [
                        VAOContract.vaoNamespace + "modelVersion": .string(model.modelVersion),
                        VAOContract.vaoNamespace + "trainingCorpusSHA256": .string(model.trainingCorpusSHA256),
                        VAOContract.vaoNamespace + "featureSchemaVersion": .string(model.featureSchemaVersion),
                        VAOContract.vaoNamespace + "taxonomyVersion": .string(model.taxonomyVersion),
                    ]
                ),
                modelURL,
                "Models/empirical-timbre-model-v1.json"
            ))
        }

        var retainedAssetIDMap: [String: String] = [:]
        if let retainedPackage {
            let originalByPath = Dictionary(retainedPackage.manifest.assets.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
            for index in builtAssets.indices {
                guard let original = originalByPath[builtAssets[index].asset.path] else { continue }
                let generated = builtAssets[index].asset
                retainedAssetIDMap[original.id] = generated.id
                builtAssets[index].asset.roles = Array(Set(original.roles + generated.roles)).sorted()
                builtAssets[index].asset.representationStatus = original.representationStatus
                builtAssets[index].asset.aboutEntityIds = Array(Set(original.aboutEntityIds + generated.aboutEntityIds)).sorted()
                builtAssets[index].asset.originalFilename = original.originalFilename ?? generated.originalFilename
                builtAssets[index].asset.createdAt = original.createdAt ?? generated.createdAt
                builtAssets[index].asset.encoding = original.encoding ?? generated.encoding
                builtAssets[index].asset.properties = (original.properties ?? [:]).merging(generated.properties ?? [:]) { _, new in new }
            }
        }

        let assetByOriginalPath = Dictionary(
            builtAssets.map { ($0.originalPath, $0.asset) },
            uniquingKeysWith: { first, _ in first }
        )
        let navigatorAsset = project.navigatorPayloadRelativePath.flatMap { assetByOriginalPath[$0] }
        let empiricalModelAsset = builtAssets.map(\.asset).first { $0.roles.contains(VAOContract.machineLearningModelRole) }
        var entities: [VAOEntity] = []
        var relations: [VAORelation] = []

        var externalIdentifiers: [VAOExternalIdentifier] = []
        if !project.organMDVSID.isEmpty {
            let isMDVS = project.organMDVSID.hasPrefix("MDVS:")
            let sourceURL = project.organCharacteristics?.sourceURLs?.first(where: {
                $0.hasPrefix("https://") || $0.hasPrefix("http://")
            })
            externalIdentifiers.append(VAOExternalIdentifier(
                value: project.organMDVSID,
                scheme: isMDVS
                    ? "https://modavis.org/identifier-scheme/mdvs"
                    : VAOContract.vaoVocabulary + "identifier-scheme/source-bound",
                resolvesTo: isMDVS ? "https://modavis.org/id/\(project.organMDVSID)" : sourceURL
            ))
        }
        var instrumentProperties: [String: VAOJSONValue] = [
            VAOContract.vaoNamespace + "projectTitle": .string(project.title),
            VAOContract.vaoNamespace + "venueLabel": .string(project.venueName),
            VAOContract.vaoNamespace + "navigatorPayloadSHA256": .string(project.snapshot.payloadSHA256),
        ]
        if let sourceURLs = project.organCharacteristics?.sourceURLs, !sourceURLs.isEmpty {
            instrumentProperties[VAOContract.vaoNamespace + "sourceURL"] = .array(sourceURLs.map(VAOJSONValue.string))
        }
        if let builder = project.organCharacteristics?.builder, !builder.isEmpty {
            instrumentProperties[VAOContract.modavisOrgan + "builderLabel"] = .string(builder)
        }
        if let date = project.organCharacteristics?.buildDateLabel, !date.isEmpty {
            instrumentProperties[VAOContract.modavisOrgan + "buildDateLabel"] = .string(date)
        }
        entities.append(VAOEntity(
            id: instrumentID,
            kind: "instrument",
            types: [VAOContract.musicalInstrumentType, VAOContract.pipeOrganType],
            labels: ["und": project.organName.isEmpty ? project.title : project.organName],
            classifications: [VAOConcept(
                id: "https://w3id.org/modavis/vocab/instrument-type/pipe-organ",
                label: ["en": "pipe organ"]
            )],
            externalIdentifiers: externalIdentifiers,
            properties: instrumentProperties
        ))

        var componentsByOriginalID: [String: OrganComponent] = [:]
        for component in (project.organComponents ?? []) + project.roadmap.map(\.component) {
            componentsByOriginalID[component.id] = component
        }
        let componentIDs = Dictionary(
            uniqueKeysWithValues: componentsByOriginalID.keys.map { ($0, stableURN(kind: "component", value: $0)) }
        )
        for key in componentsByOriginalID.keys.sorted() {
            guard let component = componentsByOriginalID[key], let componentID = componentIDs[key] else { continue }
            var properties: [String: VAOJSONValue] = [
                VAOContract.vaoNamespace + "orgrecComponentId": .string(component.id),
                VAOContract.vaoNamespace + "componentKind": .string(component.kind),
                VAOContract.vaoNamespace + "divisionLabel": .string(component.division),
                VAOContract.vaoNamespace + "locatorTrust": .string(component.locator.trust.rawValue),
                VAOContract.modavisEvidence + "contentHash": .string(component.locator.snapshotSHA256),
            ]
            if let footHeight = component.footHeight { properties[VAOContract.modavisOrgan + "hasNominalPitchDesignation"] = .string(footHeight) }
            if let note = component.noteName { properties[VAOContract.vaoNamespace + "noteName"] = .string(note) }
            if let midi = component.midiNote { properties[VAOContract.vaoNamespace + "midiNote"] = .integer(Int64(midi)) }
            if let frequency = component.expectedFrequencyHz { properties[VAOContract.vaoNamespace + "expectedFrequencyHz"] = .number(frequency) }
            if let canonical = component.locator.canonicalMDVSID { properties[VAOContract.modavisCore + "identifier"] = .string(canonical) }
            entities.append(VAOEntity(
                id: componentID,
                kind: componentKind(component),
                types: [componentType(component)],
                labels: ["und": component.label],
                properties: properties
            ))
            let membershipID = stableURN(kind: "membership", value: component.id)
            entities.append(VAOEntity(
                id: membershipID,
                kind: "other",
                types: [VAOContract.modavisInstrument + "ComponentMembership"],
                labels: ["en": "Membership of \(component.label)"],
                properties: [
                    VAOContract.modavisInstrument + "membershipType": .string("https://w3id.org/modavis/vocab/component-membership-type/structural-part")
                ]
            ))
            relations.append(VAORelation(subjectId: instrumentID, predicate: VAOContract.hasComponent, objectId: componentID, status: "accepted"))
            relations.append(VAORelation(subjectId: membershipID, predicate: VAOContract.modavisInstrument + "membershipInstrument", objectId: instrumentID, status: "accepted"))
            relations.append(VAORelation(subjectId: membershipID, predicate: VAOContract.modavisInstrument + "childComponent", objectId: componentID, status: "accepted"))
            if let parent = component.parentComponentID, let parentID = componentIDs[parent], parentID != componentID {
                relations.append(VAORelation(subjectId: membershipID, predicate: VAOContract.modavisInstrument + "parentComponent", objectId: parentID, status: "accepted"))
            }
        }

        let playableComponents = componentsByOriginalID.values.filter { component in
            (component.kind.lowercased() == "stop" && component.sourceDetails?["grandOrgueStopID"] != nil)
                || component.sourceDetails?["grandOrgueControlType"] != nil
        }.sorted { $0.id < $1.id }
        for component in playableComponents {
            guard let componentID = componentIDs[component.id] else { continue }
            let controlType = component.sourceDetails?["grandOrgueControlType"] ?? "stop"
            let interactionID = stableURN(kind: "interaction", value: component.id)
            entities.append(VAOEntity(
                id: interactionID,
                kind: "interaction",
                types: [VAOContract.vaoNamespace + "Interaction"],
                labels: ["und": "GrandOrgue control · \(component.label)"],
                properties: [
                    VAOContract.vaoNamespace + "interactionType": .string(VAOContract.vaoVocabulary + "interaction-type/\(controlType)-control"),
                    VAOContract.vaoNamespace + "controlProtocol": .string("GrandOrgue organ definition file"),
                    VAOContract.vaoNamespace + "controlDomain": .string("Organ registration and expression"),
                    VAOContract.vaoNamespace + "timingPolicy": .string("Event-driven state change using GrandOrgue ODF semantics"),
                    VAOContract.vaoNamespace + "odfSection": .string(component.sourceDetails?["odfSection"] ?? ""),
                ]
            ))
            relations.append(VAORelation(
                subjectId: interactionID,
                predicate: controlType == "tremulant" ? VAOContract.modulates : VAOContract.activates,
                objectId: componentID,
                status: "asserted"
            ))
        }

        var registrationIDs: [UUID: String] = [:]
        for registration in project.registrations {
            let id = "urn:uuid:\(registration.id.uuidString.lowercased())"
            registrationIDs[registration.id] = id
            entities.append(VAOEntity(
                id: id,
                kind: "configuration",
                types: [VAOContract.instrumentConfigurationType],
                labels: ["und": registration.name ?? "Registration revision \(registration.revision)"],
                properties: [
                    VAOContract.vaoNamespace + "revision": .integer(Int64(registration.revision)),
                    VAOContract.vaoNamespace + "notes": .string(registration.notes),
                ]
            ))
            relations.append(VAORelation(subjectId: instrumentID, predicate: VAOContract.modavisInstrument + "hasConfiguration", objectId: id, status: "accepted"))
        }

        var sessionIDs: [UUID: String] = [:]
        var actorIDs: [UUID: String] = [:]
        for session in project.recordingSessions ?? [] {
            let id = "urn:uuid:\(session.id.uuidString.lowercased())"
            sessionIDs[session.id] = id
            var sessionProperties: [String: VAOJSONValue] = [
                VAOContract.vaoNamespace + "sessionCode": .string(session.sessionCode),
                VAOContract.vaoNamespace + "purpose": .string(session.purpose),
                VAOContract.vaoNamespace + "timezone": .string(session.timezoneIdentifier),
                VAOContract.vaoNamespace + "clockSource": .string(session.clockSource),
                VAOContract.vaoNamespace + "venueCondition": .string(session.venueCondition),
                VAOContract.vaoNamespace + "notes": .string(session.notes),
            ]
            if let ended = session.endedAt { sessionProperties[VAOContract.vaoNamespace + "endedAt"] = .string(iso8601(ended)) }
            if let planID = session.sessionPlanID {
                sessionProperties[VAOContract.vaoNamespace + "sessionPlanId"] = .string(planID.uuidString.lowercased())
            }
            if let revision = session.sessionPlanRevision {
                sessionProperties[VAOContract.vaoNamespace + "sessionPlanRevision"] = .integer(Int64(revision))
            }
            if let assessment = session.noiseContextAssessment {
                sessionProperties[VAOContract.vaoNamespace + "surroundingNoiseContext"] = .object([
                    "id": .string(assessment.id.uuidString.lowercased()),
                    "revision": .integer(Int64(assessment.revision)),
                    "retrievedAt": .string(iso8601(assessment.retrievedAt)),
                    "radiusMeters": .number(assessment.radiusMeters),
                    "sourceName": .string(assessment.sourceName),
                    "sourceAttribution": .string(assessment.sourceAttribution),
                    "querySHA256": .string(assessment.querySHA256),
                    "venueLatitude": .number(assessment.venueAnchor.coordinate.latitude),
                    "venueLongitude": .number(assessment.venueAnchor.coordinate.longitude),
                    "summary": .string(assessment.summary),
                    "findings": .array(assessment.findings.map { finding in
                        .object([
                            "id": .string(finding.id.uuidString.lowercased()),
                            "sourceIdentifier": .string(finding.sourceIdentifier),
                            "label": .string(finding.label),
                            "category": .string(finding.category.rawValue),
                            "planningPriority": .string(finding.planningPriority.rawValue),
                            "disposition": .string(finding.disposition.rawValue),
                            "distanceMeters": finding.distanceMeters.map(VAOJSONValue.number) ?? .null,
                            "notes": .string(finding.notes),
                        ])
                    }),
                ])
            }
            if let observations = session.noiseObservations, observations.isEmpty == false {
                sessionProperties[VAOContract.vaoNamespace + "observedNoiseIncidents"] = .array(observations.map { observation in
                    .object([
                        "id": .string(observation.id.uuidString.lowercased()),
                        "observedAt": .string(iso8601(observation.observedAt)),
                        "category": .string(observation.category.rawValue),
                        "label": .string(observation.label),
                        "takeId": observation.takeID.map { .string($0.uuidString.lowercased()) } ?? .null,
                        "atSeconds": observation.atSeconds.map(VAOJSONValue.number) ?? .null,
                        "recordedBy": .string(observation.recordedBy),
                    ])
                })
            }
            if let reports = session.capturePreflightReports, reports.isEmpty == false {
                sessionProperties[VAOContract.vaoNamespace + "capturePreflightReports"] = .array(reports.map { report in
                    .object([
                        "id": .string(report.id.uuidString.lowercased()),
                        "contractVersion": .string(report.contractVersion),
                        "recordedAt": .string(iso8601(report.recordedAt)),
                        "setupId": .string(report.setupID.uuidString.lowercased()),
                        "setupRevision": .integer(Int64(report.setupRevision)),
                        "verdict": .string(report.verdict.rawValue),
                        "audioAssetId": assetByOriginalPath[report.relativeAudioPath].map { .string($0.id) } ?? .null,
                        "audioSHA256": .string(report.sha256),
                        "sampleRate": .number(report.sampleRate),
                        "frameCount": .integer(report.frameCount),
                        "durationSeconds": .number(report.durationSeconds),
                        "device": .object([
                            "uid": .string(report.deviceSnapshot.uid),
                            "name": .string(report.deviceSnapshot.name),
                            "inputChannels": .integer(Int64(report.deviceSnapshot.inputChannels)),
                            "configuredSampleRate": .number(report.deviceSnapshot.sampleRate),
                            "bufferFrames": .integer(Int64(report.deviceSnapshot.bufferFrames)),
                        ]),
                        "protocol": .object([
                            "contractVersion": .string(report.protocolSnapshot.contractVersion),
                            "quietWindowEndSeconds": .number(report.protocolSnapshot.quietWindowEndSeconds),
                            "signalWindowStartSeconds": .number(report.protocolSnapshot.signalWindowStartSeconds),
                            "minimumSignalToNoiseDB": .number(report.protocolSnapshot.minimumSignalToNoiseDB),
                            "preferredSignalToNoiseDB": .number(report.protocolSnapshot.preferredSignalToNoiseDB),
                            "minimumHeadroomDB": .number(report.protocolSnapshot.minimumHeadroomDB),
                            "preferredHeadroomDB": .number(report.protocolSnapshot.preferredHeadroomDB),
                        ]),
                        "channels": .array(report.channels.filter(\.isRequired).map { channel in
                            .object([
                                "channelNumber": .integer(Int64(channel.channelNumber)),
                                "role": .string(channel.role),
                                "quietRMSDBFS": .number(channel.quietRMSDBFS),
                                "signalRMSDBFS": .number(channel.signalRMSDBFS),
                                "peakDBFS": .number(channel.peakDBFS),
                                "headroomDB": .number(channel.headroomDB),
                                "signalToNoiseDB": .number(channel.signalToNoiseDB),
                                "dcOffset": .number(channel.dcOffset),
                                "clippedSamples": .integer(channel.clippedSamples),
                            ])
                        }),
                        "findings": .array(report.findings.map { finding in
                            .object([
                                "kind": .string(finding.kind.rawValue),
                                "severity": .string(finding.severity.rawValue),
                                "channelNumbers": .array(finding.channelNumbers.map { .integer(Int64($0)) }),
                                "title": .string(finding.title),
                                "detail": .string(finding.detail),
                                "remediation": .string(finding.remediation),
                            ])
                        }),
                    ])
                })
            }
            entities.append(VAOEntity(
                id: id,
                kind: "activity",
                types: [VAOContract.recordingEventType],
                labels: ["und": session.sessionCode],
                properties: sessionProperties
            ))
            relations.append(VAORelation(subjectId: id, predicate: VAOContract.modavisEvents + "affectedEntity", objectId: instrumentID, status: "accepted"))
            if !session.operatorName.isEmpty {
                let actorID = stableURN(kind: "agent", value: "\(session.operatorName)|\(session.institution)")
                actorIDs[session.id] = actorID
                if !entities.contains(where: { $0.id == actorID }) {
                    entities.append(VAOEntity(
                        id: actorID,
                        kind: "agent",
                        types: [VAOContract.modavisCore + "Agent"],
                        labels: ["und": session.operatorName],
                        properties: session.institution.isEmpty ? nil : [VAOContract.vaoNamespace + "institution": .string(session.institution)]
                    ))
                }
                relations.append(VAORelation(subjectId: id, predicate: VAOContract.modavisEvents + "hasParticipant", objectId: actorID, status: "accepted"))
            }
        }

        let roadmapByID = Dictionary(project.roadmap.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var takeEntityIDs: [UUID: String] = Dictionary(uniqueKeysWithValues: project.takes.map {
            ($0.id, "urn:uuid:\($0.id.uuidString.lowercased())")
        })
        var paradata: [VAOParadata] = []
        var analyses: [VAOAnalysis] = []
        var hasPlayableLoopSets = false
        var hasSampledPlaybackParameters = false
        var hasTuningMap = false
        var hasCollectionAcousticDiagnostics = false
        let tuningMapID = stableURN(kind: "tuning-map", value: project.id.uuidString.lowercased())

        for calibration in project.tuningCalibrations ?? [] {
            let calibrationID = "urn:uuid:\(calibration.id.uuidString.lowercased())"
            let sessionID = sessionIDs[calibration.sessionID]
            let calibrationAsset = calibration.relativeAudioPath.flatMap { assetByOriginalPath[$0] }
            var properties: [String: VAOJSONValue] = [
                VAOContract.modavisAudio + "contractVersion": .string(calibration.contractVersion),
                VAOContract.modavisAudio + "status": .string(calibration.status.rawValue),
                VAOContract.modavisAudio + "referenceKeyNumber": .integer(Int64(calibration.referenceMIDINote)),
                VAOContract.modavisAudio + "referenceChannelIndex": .integer(Int64(calibration.referenceChannelIndex)),
                VAOContract.modavisAudio + "method": .string(calibration.method),
                VAOContract.modavisAudio + "algorithmVersion": .string(calibration.algorithmVersion),
                VAOContract.vaoNamespace + "createdAt": .string(iso8601(calibration.createdAt)),
            ]
            if let documented = calibration.documentedA4Hz { properties[VAOContract.modavisAudio + "documentedA4Hz"] = .number(documented) }
            if let measured = calibration.measuredFrequencyHz { properties[VAOContract.modavisAudio + "measuredFrequencyHz"] = .number(measured) }
            if let normalized = calibration.normalizedA4Hz { properties[VAOContract.modavisAudio + "referenceA4Hz"] = .number(normalized) }
            if let cents = calibration.centsFromDocumented { properties[VAOContract.modavisAudio + "tuningOffsetCents"] = .number(cents) }
            if let acceptedAt = calibration.acceptedAt { properties[VAOContract.vaoNamespace + "reviewedAt"] = .string(iso8601(acceptedAt)) }
            if let acceptedBy = calibration.acceptedBy { properties[VAOContract.vaoNamespace + "reviewedBy"] = .string(acceptedBy) }
            if !calibration.notes.isEmpty { properties[VAOContract.vaoNamespace + "notes"] = .string(calibration.notes) }
            entities.append(VAOEntity(
                id: calibrationID,
                kind: "measurement",
                types: [VAOContract.tuningCalibrationType],
                labels: ["und": "Tuning calibration · \(calibration.referenceNoteName)"],
                properties: properties
            ))
            if let sessionID { relations.append(VAORelation(subjectId: calibrationID, predicate: VAOContract.recordedInSession, objectId: sessionID, status: calibration.status.rawValue)) }
            if let calibrationAsset { relations.append(VAORelation(subjectId: calibrationID, predicate: VAOContract.hasRepresentation, objectId: calibrationAsset.id, status: calibration.status.rawValue)) }
            let activityID = stableURN(kind: "activity", value: "tuning-calibration|\(calibration.id.uuidString.lowercased())")
            let inputs = calibrationAsset.map { [$0.id] } ?? sessionID.map { [$0] } ?? [instrumentID]
            paradata.append(VAOParadata(
                id: activityID,
                activityType: VAOContract.vaoVocabulary + "activity/TuningCalibration",
                startedAt: calibration.createdAt,
                endedAt: calibration.acceptedAt ?? calibration.createdAt,
                actorIds: nil,
                software: VAOSoftware(name: "OrgRec", version: calibration.algorithmVersion, uri: "https://modavis.org/orgrec", build: nil),
                inputIds: inputs,
                outputIds: [calibrationID],
                parameters: [
                    VAOContract.modavisAudio + "referenceKeyNumber": .integer(Int64(calibration.referenceMIDINote)),
                    VAOContract.modavisAudio + "referenceChannelIndex": .integer(Int64(calibration.referenceChannelIndex)),
                ],
                notes: calibration.notes.isEmpty ? nil : calibration.notes
            ))
            var calibrationObservations: [VAOObservation] = []
            if let measured = calibration.measuredFrequencyHz {
                calibrationObservations.append(VAOObservation(
                    property: VAOContract.vaoVocabulary + "analysis/pitch/measured-frequency",
                    value: .number(measured), unit: "http://qudt.org/vocab/unit/HZ",
                    confidence: calibration.confidence, status: calibration.status == .accepted ? "accepted" : "observed",
                    subjectId: calibrationID, channelIndices: [calibration.referenceChannelIndex]
                ))
            }
            if let normalized = calibration.normalizedA4Hz {
                calibrationObservations.append(VAOObservation(
                    property: VAOContract.vaoVocabulary + "analysis/pitch/normalized-a4",
                    value: .number(normalized), unit: "http://qudt.org/vocab/unit/HZ",
                    confidence: calibration.confidence, status: calibration.status == .accepted ? "accepted" : "inferred",
                    subjectId: calibrationID
                ))
            }
            if let cents = calibration.centsFromDocumented {
                calibrationObservations.append(VAOObservation(
                    property: VAOContract.vaoVocabulary + "analysis/pitch/cents-from-documented",
                    value: .number(cents), unit: VAOContract.vaoVocabulary + "unit/cent",
                    confidence: calibration.confidence, status: "inferred", subjectId: calibrationID
                ))
            }
            analyses.append(VAOAnalysis(
                id: stableURN(kind: "analysis", value: "tuning-calibration|\(calibration.id.uuidString.lowercased())"),
                analysisType: VAOContract.vaoVocabulary + "analysis/tuning-calibration",
                method: calibration.method,
                version: calibration.algorithmVersion,
                generatedAt: calibration.acceptedAt ?? calibration.createdAt,
                inputIds: inputs,
                outputIds: [calibrationID],
                paradataId: activityID,
                observations: calibrationObservations,
                qualityFlags: calibration.status == .accepted ? nil : ["calibration-\(calibration.status.rawValue)"]
            ))
            relations.append(VAORelation(subjectId: calibrationID, predicate: VAOContract.generatedBy, objectId: activityID, status: calibration.status.rawValue))
        }
        for take in project.takes {
            let takeID = "urn:uuid:\(take.id.uuidString.lowercased())"
            takeEntityIDs[take.id] = takeID
            var takeProperties: [String: VAOJSONValue] = [
                VAOContract.vaoNamespace + "takeNumber": .integer(Int64(take.takeNumber)),
                VAOContract.vaoNamespace + "status": .string(take.status.rawValue),
                VAOContract.vaoNamespace + "sampleRate": .number(take.sampleRate),
                VAOContract.vaoNamespace + "channelCount": .integer(Int64(take.channelCount)),
                VAOContract.vaoNamespace + "frameCount": .integer(take.frameCount),
                VAOContract.vaoNamespace + "startedAt": .string(iso8601(take.startedAt)),
            ]
            if let ended = take.endedAt { takeProperties[VAOContract.vaoNamespace + "endedAt"] = .string(iso8601(ended)) }
            if !take.notes.isEmpty { takeProperties[VAOContract.vaoNamespace + "notes"] = .string(take.notes) }
            entities.append(VAOEntity(
                id: takeID,
                kind: "digitalObject",
                types: [VAOContract.vaoNamespace + "RecordingTake"],
                labels: ["und": "Take \(take.takeNumber)"],
                properties: takeProperties
            ))
            relations.append(VAORelation(subjectId: takeID, predicate: VAOContract.aboutInstrument, objectId: instrumentID, status: "accepted"))
            if let item = roadmapByID[take.roadmapItemID], let componentID = componentIDs[item.component.id] {
                relations.append(VAORelation(subjectId: takeID, predicate: VAOContract.documentsComponent, objectId: componentID, status: "accepted"))
                if let registrationID = item.registrationID.flatMap({ registrationIDs[$0] }) {
                    relations.append(VAORelation(subjectId: takeID, predicate: VAOContract.usesConfiguration, objectId: registrationID, status: "accepted"))
                }
            }
            let sessionUUID = take.provenance?.sessionID
            if let sessionID = sessionUUID.flatMap({ sessionIDs[$0] }) {
                relations.append(VAORelation(subjectId: takeID, predicate: VAOContract.recordedInSession, objectId: sessionID, status: "accepted"))
            }
            guard let audioAsset = assetByOriginalPath[take.relativeAudioPath] else { continue }
            relations.append(VAORelation(subjectId: takeID, predicate: VAOContract.hasRepresentation, objectId: audioAsset.id, status: "accepted"))

            for capture in take.interactionSensorCaptures ?? [] {
                guard capture.takeID == take.id,
                      let rawAsset = assetByOriginalPath[capture.rawRelativePath],
                      let metadataAsset = assetByOriginalPath[capture.metadataRelativePath] else { continue }
                let captureActivityID = stableURN(kind: "activity", value: "interaction-sensor-capture|\(capture.id.uuidString.lowercased())")
                let derivedAsset = capture.derivedRelativePath.flatMap { assetByOriginalPath[$0] }
                paradata.append(VAOParadata(
                    id: captureActivityID,
                    activityType: VAOContract.vaoVocabulary + "activity/InteractionSensorCapture",
                    startedAt: capture.startedAt,
                    endedAt: capture.endedAt,
                    actorIds: nil,
                    software: VAOSoftware(
                        name: "OrgRec",
                        version: take.provenance?.applicationVersion ?? OrgRecSoftware.version,
                        uri: "https://modavis.org/orgrec",
                        build: nil
                    ),
                    inputIds: [instrumentID],
                    outputIds: [rawAsset.id, metadataAsset.id],
                    parameters: [
                        VAOContract.vaoNamespace + "sensorConfigurationID": .string(capture.configurationSnapshot.id.uuidString.lowercased()),
                        VAOContract.vaoNamespace + "sensorNodeIdentifier": .string(capture.configurationSnapshot.nodeIdentifier),
                        VAOContract.vaoNamespace + "sensorProtocolIdentifier": .string(capture.configurationSnapshot.protocolIdentifier),
                        VAOContract.vaoNamespace + "sensorFirmwareIdentifier": .string(capture.configurationSnapshot.firmwareIdentifier),
                        VAOContract.vaoNamespace + "sensorUseCase": .string(capture.configurationSnapshot.resolvedUseCase.rawValue),
                        VAOContract.vaoNamespace + "sensorNominalSampleRateHz": .number(capture.configurationSnapshot.nominalSampleRateHz),
                        VAOContract.vaoNamespace + "sensorReceivedPackets": .integer(Int64(capture.health.receivedPackets)),
                        VAOContract.vaoNamespace + "sensorLostPackets": .integer(Int64(capture.health.lostPackets)),
                        VAOContract.vaoNamespace + "sensorCRCErrorCount": .integer(Int64(capture.health.crcErrors)),
                        VAOContract.vaoNamespace + "sensorClockAlignmentStatus": .string(capture.clockAlignment.status.rawValue),
                        VAOContract.vaoNamespace + "sensorClockBaseUncertaintySeconds": .number(capture.clockAlignment.baseUncertaintySeconds),
                    ],
                    notes: capture.experimentalLimitations.isEmpty ? nil : capture.experimentalLimitations.joined(separator: " ")
                ))
                relations.append(VAORelation(subjectId: takeID, predicate: VAOContract.hasRepresentation, objectId: rawAsset.id, status: "accepted"))
                relations.append(VAORelation(subjectId: rawAsset.id, predicate: VAOContract.generatedBy, objectId: captureActivityID, status: "accepted"))
                relations.append(VAORelation(subjectId: metadataAsset.id, predicate: VAOContract.generatedBy, objectId: captureActivityID, status: "accepted"))

                if let derivedAsset {
                    let processingActivityID = stableURN(kind: "activity", value: "interaction-sensor-processing|\(capture.id.uuidString.lowercased())")
                    var processingParameters: [String: VAOJSONValue] = [
                        VAOContract.vaoNamespace + "processingIdentifier": .string(capture.processingIdentifier),
                        VAOContract.vaoNamespace + "motionEventCount": .integer(Int64(capture.motionEventCount)),
                        VAOContract.vaoNamespace + "calibrationID": .string(capture.calibrationSnapshot?.id.uuidString.lowercased() ?? "none"),
                    ]
                    if let coupling = capture.audioCoupling {
                        if let value = coupling.onsetAfterMotionStartSeconds {
                            processingParameters[VAOContract.vaoNamespace + "acousticOnsetAfterMotionStartSeconds"] = .number(value)
                        }
                        if let value = coupling.onsetAfterMotionEndSeconds {
                            processingParameters[VAOContract.vaoNamespace + "acousticOnsetAfterMotionEndSeconds"] = .number(value)
                        }
                        if let value = coupling.soundOffsetAfterReleaseStartSeconds {
                            processingParameters[VAOContract.vaoNamespace + "acousticOffsetAfterReleaseStartSeconds"] = .number(value)
                        }
                        if let value = coupling.heldIntervalSeconds {
                            processingParameters[VAOContract.vaoNamespace + "sensorObservedHeldIntervalSeconds"] = .number(value)
                        }
                        processingParameters[VAOContract.vaoNamespace + "sensorAudioTimingUncertaintySeconds"] = .number(coupling.timingUncertaintySeconds)
                    }
                    paradata.append(VAOParadata(
                        id: processingActivityID,
                        activityType: VAOContract.vaoVocabulary + "activity/InteractionSensorProcessing",
                        startedAt: capture.endedAt,
                        endedAt: capture.endedAt,
                        actorIds: nil,
                        software: VAOSoftware(name: "OrgRec", version: capture.processingIdentifier, uri: "https://modavis.org/orgrec", build: nil),
                        inputIds: [rawAsset.id, metadataAsset.id],
                        outputIds: [derivedAsset.id],
                        parameters: processingParameters,
                        notes: "Experimental interpretation of captured interaction-sensor packets; retain the raw packet stream as the evidential source."
                    ))
                    relations.append(VAORelation(subjectId: derivedAsset.id, predicate: VAOContract.derivedFrom, objectId: rawAsset.id, status: "accepted"))
                    relations.append(VAORelation(subjectId: derivedAsset.id, predicate: VAOContract.generatedBy, objectId: processingActivityID, status: "accepted"))
                }
            }

            if let slice = take.longTakeSource,
               let sourceRecord = (project.longTakeSources ?? []).first(where: { $0.id == slice.longTakeID }),
               let sourceAsset = assetByOriginalPath[slice.sourceRelativeAudioPath] {
                let regionID = stableURN(kind: "signal-region", value: "long-take-slice|\(take.id.uuidString.lowercased())")
                let startFrame = slice.sourceStartFrame ?? Int64((slice.sourceStartSeconds * sourceRecord.sampleRate).rounded())
                let endFrame = slice.sourceEndFrame ?? Int64((slice.sourceEndSeconds * sourceRecord.sampleRate).rounded())
                let onsetFrame = slice.detectedOnsetFrame ?? Int64((slice.detectedOnsetSeconds * sourceRecord.sampleRate).rounded())
                let offsetFrame = slice.detectedSoundOffsetFrame ?? Int64((slice.detectedSoundOffsetSeconds * sourceRecord.sampleRate).rounded())
                let matchedSegment = sourceRecord.analysis.segments
                    .filter { $0.assignedRoadmapItemID == take.roadmapItemID }
                    .min { lhs, rhs in
                        let lhsStart = lhs.exportStartFrame ?? Int64((lhs.exportStartSeconds * sourceRecord.sampleRate).rounded())
                        let rhsStart = rhs.exportStartFrame ?? Int64((rhs.exportStartSeconds * sourceRecord.sampleRate).rounded())
                        return abs(lhsStart - startFrame) < abs(rhsStart - startFrame)
                    }
                let boundaryCensoring = endFrame >= sourceRecord.frameCount ? "right" : "none"
                var regionProperties: [String: VAOJSONValue] = [
                    VAOContract.modavisAudio + "regionRole": .string("sample-extraction"),
                    VAOContract.modavisAudio + "startFrameInclusive": .integer(startFrame),
                    VAOContract.modavisAudio + "endFrameExclusive": .integer(endFrame),
                    VAOContract.modavisAudio + "sampleRate": .number(sourceRecord.sampleRate),
                    VAOContract.modavisAudio + "totalFrames": .integer(sourceRecord.frameCount),
                    VAOContract.modavisAudio + "sourceAudioSHA256": .string(slice.sourceSHA256),
                    VAOContract.modavisAudio + "referenceChannelIndex": .integer(Int64(sourceRecord.analysis.referenceChannel)),
                    VAOContract.modavisAudio + "status": .string(take.status == .accepted ? "reviewed" : "inferred"),
                    VAOContract.modavisAudio + "boundaryConfidence": .number(slice.assignmentConfidence),
                    VAOContract.modavisAudio + "censoring": .string(boundaryCensoring),
                    VAOContract.modavisAudio + "assignmentMode": .string(slice.assignmentMode.rawValue),
                    VAOContract.modavisAudio + "assignmentConfidence": .number(slice.assignmentConfidence),
                    VAOContract.modavisAudio + "takeNumber": .integer(Int64(take.takeNumber)),
                ]
                if let sequence = matchedSegment?.sequenceNumber {
                    regionProperties[VAOContract.modavisAudio + "captureSequenceIndex"] = .integer(Int64(sequence))
                }
                if let midi = matchedSegment?.assignedMIDINote {
                    regionProperties[VAOContract.modavisAudio + "assignedKeyNumber"] = .integer(Int64(midi))
                }
                entities.append(VAOEntity(
                    id: regionID,
                    kind: "signalRegion",
                    types: [VAOContract.signalRegionType, VAOContract.sampleExtractionRegionType],
                    labels: ["und": "Source extraction region for take \(take.takeNumber)"],
                    properties: regionProperties
                ))
                relations.append(VAORelation(subjectId: regionID, predicate: VAOContract.appliesToSignal, objectId: sourceAsset.id, status: "inferred"))
                relations.append(VAORelation(subjectId: takeID, predicate: VAOContract.extractedFromRegion, objectId: regionID, status: "inferred", confidence: slice.assignmentConfidence))
                relations.append(VAORelation(subjectId: audioAsset.id, predicate: VAOContract.derivedFrom, objectId: sourceAsset.id, status: "inferred"))
                let segmentationActivityID = stableURN(kind: "activity", value: "long-take-segmentation|\(take.id.uuidString.lowercased())")
                paradata.append(VAOParadata(
                    id: segmentationActivityID,
                    activityType: VAOContract.vaoVocabulary + "activity/AudioSegmentation",
                    startedAt: sourceRecord.analysis.analyzedAt,
                    endedAt: sourceRecord.analysis.analyzedAt,
                    actorIds: nil,
                    software: VAOSoftware(name: "OrgRec", version: slice.analyzerVersion, uri: "https://modavis.org/orgrec", build: nil),
                    inputIds: [sourceAsset.id],
                    outputIds: [regionID, takeID, audioAsset.id],
                    parameters: [
                        VAOContract.modavisAudio + "assignmentMode": .string(slice.assignmentMode.rawValue),
                        VAOContract.modavisAudio + "referenceChannelIndex": .integer(Int64(sourceRecord.analysis.referenceChannel)),
                        VAOContract.modavisAudio + "configuration": .object([
                            "hopSeconds": .number(sourceRecord.analysis.configuration.hopSeconds),
                            "minimumNoteDurationSeconds": .number(sourceRecord.analysis.configuration.minimumNoteDurationSeconds),
                            "minimumSilenceDurationSeconds": .number(sourceRecord.analysis.configuration.minimumSilenceDurationSeconds),
                            "maximumReleaseTailSeconds": .number(sourceRecord.analysis.configuration.maximumReleaseTailSeconds),
                        ]),
                    ],
                    notes: sourceRecord.analysis.warnings.isEmpty ? nil : sourceRecord.analysis.warnings.joined(separator: " ")
                ))
                let exactRange = VAOTimeRange(
                    startSeconds: slice.sourceStartSeconds,
                    endSeconds: slice.sourceEndSeconds,
                    startFrameInclusive: startFrame,
                    endFrameExclusive: endFrame,
                    sampleRate: sourceRecord.sampleRate,
                    clockAssetId: sourceAsset.id
                )
                analyses.append(VAOAnalysis(
                    id: stableURN(kind: "analysis", value: "long-take-segmentation|\(take.id.uuidString.lowercased())"),
                    analysisType: VAOContract.vaoVocabulary + "analysis/source-segmentation",
                    method: "Frequency-aware pipe-organ long-take segmentation and sequence assignment",
                    version: slice.analyzerVersion,
                    generatedAt: sourceRecord.analysis.analyzedAt,
                    inputIds: [sourceAsset.id],
                    outputIds: [regionID, audioAsset.id],
                    paradataId: segmentationActivityID,
                    observations: [
                        VAOObservation(
                            property: VAOContract.vaoVocabulary + "analysis/time/detected-onset",
                            value: .integer(onsetFrame), unit: "http://qudt.org/vocab/unit/FRAME",
                            confidence: matchedSegment?.onsetConfidence,
                            status: "inferred", applicability: "applicable", censoring: onsetFrame <= 0 ? "left" : "none",
                            subjectId: takeID, sourceRegionId: regionID,
                            channelIndices: [sourceRecord.analysis.referenceChannel], timeRange: exactRange
                        ),
                        VAOObservation(
                            property: VAOContract.vaoVocabulary + "analysis/time/detected-sound-offset",
                            value: .integer(offsetFrame), unit: "http://qudt.org/vocab/unit/FRAME",
                            status: "inferred", applicability: "applicable", censoring: boundaryCensoring,
                            subjectId: takeID, sourceRegionId: regionID,
                            channelIndices: [sourceRecord.analysis.referenceChannel], timeRange: exactRange
                        ),
                        VAOObservation(
                            property: VAOContract.vaoVocabulary + "analysis/classification/assignment-confidence",
                            value: .number(slice.assignmentConfidence), unit: "http://qudt.org/vocab/unit/UNITLESS",
                            confidence: slice.assignmentConfidence, status: "inferred",
                            subjectId: takeID, sourceRegionId: regionID
                        ),
                    ],
                    qualityFlags: matchedSegment?.warnings ?? sourceRecord.analysis.warnings
                ))
            }

            let loopSets = take.loopPointSets ?? []
            let loopIDs = Dictionary(uniqueKeysWithValues: loopSets.map {
                ($0.id, stableURN(kind: "loop-point-set", value: $0.id.uuidString.lowercased()))
            })
            var proposedLoopOutputIDs: [String] = []
            for set in loopSets {
                guard let loopID = loopIDs[set.id] else { continue }
                let contractErrors = LoopPointSetValidator.errors(for: set)
                if !contractErrors.isEmpty {
                    throw OrgRecError.exportValidation("Loop point set \(set.id.uuidString.lowercased()) is invalid: \(contractErrors.joined(separator: " "))")
                }
                if set.sourceAudioSHA256 != audioAsset.sha256 {
                    throw OrgRecError.exportValidation("Loop point set \(set.id.uuidString.lowercased()) does not match the source audio SHA-256.")
                }
                let relationStatus = set.status == .proposed ? "inferred" : set.status.rawValue
                var loopProperties: [String: VAOJSONValue] = [
                    VAOContract.modavisAudio + "contractVersion": .string(set.contractVersion),
                    VAOContract.modavisAudio + "sourceAudioSHA256": .string(set.sourceAudioSHA256),
                    VAOContract.modavisAudio + "sampleRate": .number(set.sampleRate),
                    VAOContract.modavisAudio + "channelCount": .integer(Int64(set.channelCount)),
                    VAOContract.modavisAudio + "totalFrames": .integer(set.totalFrames),
                    VAOContract.modavisAudio + "status": .string(set.status.rawValue),
                    VAOContract.modavisAudio + "loopability": .string(set.loopability.rawValue),
                    VAOContract.modavisAudio + "confidence": .number(set.confidence),
                    VAOContract.modavisAudio + "algorithm": .string(set.algorithm),
                    VAOContract.modavisAudio + "algorithmVersion": .string(set.algorithmVersion),
                    VAOContract.modavisAudio + "coordinateConvention": .string("start-inclusive/end-exclusive"),
                    VAOContract.modavisAudio + "envelope": .object([
                        "attackSeconds": .number(set.envelope.attackSeconds),
                        "releaseSeconds": .number(set.envelope.releaseSeconds),
                        "sustainLevel": .number(set.envelope.sustainLevel),
                        "curve": .string(set.envelope.curve.rawValue),
                    ]),
                ]
                if let rank = set.candidateRank { loopProperties[VAOContract.modavisAudio + "candidateRank"] = .integer(Int64(rank)) }
                if let reviewedAt = set.reviewedAt { loopProperties[VAOContract.modavisAudio + "reviewedAt"] = .string(iso8601(reviewedAt)) }
                if let reviewedBy = set.reviewedBy { loopProperties[VAOContract.modavisAudio + "reviewedBy"] = .string(reviewedBy) }
                if let reason = set.reviewReason { loopProperties[VAOContract.modavisAudio + "reviewReason"] = .string(reason) }
                entities.append(VAOEntity(
                    id: loopID,
                    kind: "loopPointSet",
                    types: [VAOContract.loopPointSetType],
                    labels: ["und": "\(set.status.rawValue.capitalized) loop point set"],
                    properties: loopProperties
                ))
                relations.append(VAORelation(subjectId: loopID, predicate: VAOContract.appliesToSignal, objectId: audioAsset.id, status: relationStatus))
                if let parent = set.wasRevisionOf.flatMap({ loopIDs[$0] }) {
                    relations.append(VAORelation(subjectId: loopID, predicate: VAOContract.wasRevisionOf, objectId: parent, status: "accepted"))
                }
                for region in set.regions {
                    let regionID = "urn:uuid:\(region.id.uuidString.lowercased())"
                    var properties: [String: VAOJSONValue] = [
                        VAOContract.modavisAudio + "role": .string(region.role.rawValue),
                        VAOContract.modavisAudio + "startFrameInclusive": .integer(region.startFrameInclusive),
                        VAOContract.modavisAudio + "endFrameExclusive": .integer(region.endFrameExclusive),
                        VAOContract.modavisAudio + "crossfadeFrames": .integer(region.crossfadeFrames),
                        VAOContract.modavisAudio + "mode": .string(region.mode.rawValue),
                        VAOContract.modavisAudio + "exitPolicy": .string(region.exitPolicy.rawValue),
                    ]
                    if let releaseStart = region.releaseStartFrame { properties[VAOContract.modavisAudio + "releaseStartFrame"] = .integer(releaseStart) }
                    if let repeatCount = region.repeatCount { properties[VAOContract.modavisAudio + "repeatCount"] = .integer(Int64(repeatCount)) }
                    if let score = region.score {
                        properties[VAOContract.modavisAudio + "seamScore"] = .object([
                            "waveformMismatch": .number(score.waveformMismatch),
                            "derivativeMismatch": .number(score.derivativeMismatch),
                            "spectralMismatch": .number(score.spectralMismatch),
                            "partialPhaseMismatch": .number(score.partialPhaseMismatch),
                            "levelMismatch": .number(score.levelMismatch),
                            "pitchMismatch": .number(score.pitchMismatch),
                            "stationarityPenalty": .number(score.stationarityPenalty),
                            "channelMismatch": .number(score.channelMismatch),
                            "repetitionPenalty": .number(score.repetitionPenalty),
                            "total": .number(score.total),
                        ])
                    }
                    entities.append(VAOEntity(
                        id: regionID,
                        kind: "signalRegion",
                        types: [region.role == .sustain ? VAOContract.sustainLoopRegionType : VAOContract.signalRegionType],
                        labels: ["und": "\(region.role.rawValue.capitalized) loop region"],
                        properties: properties
                    ))
                    relations.append(VAORelation(subjectId: loopID, predicate: VAOContract.hasLoopRegion, objectId: regionID, status: relationStatus))
                }
                if set.status == .proposed {
                    proposedLoopOutputIDs.append(loopID)
                }
                if set.status == .accepted, take.acceptedLoopPointSetID == set.id {
                    hasPlayableLoopSets = true
                    let interactionID = stableURN(kind: "interaction", value: "sustain-loop|\(set.id.uuidString.lowercased())")
                    entities.append(VAOEntity(
                        id: interactionID,
                        kind: "interaction",
                        types: [VAOContract.vaoNamespace + "Interaction"],
                        labels: ["und": "Sustained sampled note"],
                        properties: [
                            VAOContract.vaoNamespace + "interactionType": .string(VAOContract.vaoVocabulary + "interaction/note-on-note-off"),
                            VAOContract.vaoNamespace + "controlProtocol": .string("Abstract note gate; bindings may use MIDI, OSC, or host automation"),
                            VAOContract.vaoNamespace + "controlDomain": .string("Binary note gate with velocity-independent sustained playback"),
                            VAOContract.vaoNamespace + "timingPolicy": .string("Attack, exact-frame sustain loop, equal-power crossfade, then configured release policy"),
                        ]
                    ))
                    relations.append(VAORelation(subjectId: interactionID, predicate: VAOContract.activates, objectId: takeID, status: "accepted"))
                    relations.append(VAORelation(subjectId: interactionID, predicate: VAOContract.vaoNamespace + "usesSample", objectId: audioAsset.id, status: "accepted"))
                    relations.append(VAORelation(subjectId: interactionID, predicate: VAOContract.usesLoopPointSet, objectId: loopID, status: "accepted"))
                    if let item = roadmapByID[take.roadmapItemID], let midi = item.component.midiNote {
                        let playbackID = stableURN(kind: "sample-playback-parameters", value: set.id.uuidString.lowercased())
                        let measuredFrequency = take.analysis?.frequencyHz
                        let targetFrequency = measuredFrequency ?? item.component.expectedFrequencyHz
                        if let targetFrequency, targetFrequency > 0 {
                            var playbackProperties: [String: VAOJSONValue] = [
                                VAOContract.modavisAudio + "contractVersion": .string("modaudio.sample-playback/0.2.0"),
                                VAOContract.modavisAudio + "status": .string("reviewed"),
                                VAOContract.modavisAudio + "rootKeyNumber": .integer(Int64(midi)),
                                VAOContract.modavisAudio + "minimumKeyNumber": .integer(Int64(midi)),
                                VAOContract.modavisAudio + "maximumKeyNumber": .integer(Int64(midi)),
                                VAOContract.modavisAudio + "minimumVelocity": .integer(0),
                                VAOContract.modavisAudio + "maximumVelocity": .integer(127),
                                VAOContract.modavisAudio + "targetFrequencyHz": .number(targetFrequency),
                                VAOContract.modavisAudio + "tuningOffsetCents": .number(0),
                                VAOContract.modavisAudio + "pitchTrackingMode": .string("preserveRecordedPitch"),
                                VAOContract.modavisAudio + "gainDB": .number(0),
                                VAOContract.modavisAudio + "normalizationGainDB": .number(0),
                                VAOContract.modavisAudio + "latencyCompensationFrames": .integer(0),
                                VAOContract.modavisAudio + "noteOffPolicy": .string(set.sustainRegion?.exitPolicy.rawValue ?? LoopExitPolicy.envelopeRelease.rawValue),
                                VAOContract.modavisAudio + "channelPolicy": .object([
                                    "mode": .string("preserveSourceChannels"),
                                    "channelCount": .integer(Int64(take.channelCount)),
                                    "phaseCoherent": .boolean(true),
                                ]),
                                VAOContract.modavisAudio + "envelope": .object([
                                    "attackSeconds": .number(set.envelope.attackSeconds),
                                    "releaseSeconds": .number(set.envelope.releaseSeconds),
                                    "sustainLevel": .number(set.envelope.sustainLevel),
                                    "curve": .string(set.envelope.curve.rawValue),
                                ]),
                            ]
                            if let measuredFrequency, measuredFrequency > 0 {
                                playbackProperties[VAOContract.modavisAudio + "sourceFundamentalHz"] = .number(measuredFrequency)
                            }
                            entities.append(VAOEntity(
                                id: playbackID,
                                kind: "parameterSet",
                                types: [VAOContract.samplePlaybackParametersType],
                                labels: ["und": "Playback parameters · \(item.component.label)"],
                                properties: playbackProperties
                            ))
                            relations.append(VAORelation(subjectId: interactionID, predicate: VAOContract.usesPlaybackParameters, objectId: playbackID, status: "accepted"))
                            relations.append(VAORelation(subjectId: interactionID, predicate: VAOContract.usesTuningMap, objectId: tuningMapID, status: "inferred"))
                            hasSampledPlaybackParameters = true
                        }
                    }
                    let reviewActivityID = stableURN(kind: "activity", value: "loop-review|\(set.id.uuidString.lowercased())")
                    paradata.append(VAOParadata(
                        id: reviewActivityID,
                        activityType: VAOContract.vaoVocabulary + "activity/LoopPointReview",
                        startedAt: set.reviewedAt ?? set.generatedAt,
                        endedAt: set.reviewedAt,
                        actorIds: nil,
                        software: VAOSoftware(name: "OrgRec", version: set.algorithmVersion, uri: "https://modavis.org/orgrec", build: nil),
                        inputIds: set.wasRevisionOf.flatMap({ loopIDs[$0] }).map { [$0] } ?? [audioAsset.id],
                        outputIds: [loopID, interactionID],
                        parameters: [VAOContract.modavisAudio + "decision": .string("accepted-revision")],
                        notes: set.reviewReason
                    ))
                    relations.append(VAORelation(subjectId: loopID, predicate: VAOContract.generatedBy, objectId: reviewActivityID, status: "accepted"))
                }
            }

            let activityID = stableURN(kind: "activity", value: take.id.uuidString.lowercased())
            let derivativeAssets = builtAssets
                .filter { $0.originalPath.hasPrefix("Analysis/") && $0.originalPath.lowercased().contains(take.id.uuidString.lowercased()) }
                .map(\.asset.id)
            let actorID = sessionUUID.flatMap { actorIDs[$0] }
            paradata.append(VAOParadata(
                id: activityID,
                activityType: VAOContract.modavisProvenance + "DigitizationActivity",
                startedAt: take.startedAt,
                endedAt: take.endedAt,
                actorIds: actorID.map { [$0] },
                software: VAOSoftware(
                    name: "OrgRec",
                    version: take.provenance?.applicationVersion ?? OrgRecSoftware.version,
                    uri: "https://modavis.org/orgrec",
                    build: nil
                ),
                inputIds: [instrumentID],
                outputIds: [takeID, audioAsset.id] + derivativeAssets,
                parameters: [
                    VAOContract.vaoNamespace + "recipeVersion": .integer(Int64(take.provenance?.recipe.version ?? project.recipe.version)),
                    VAOContract.vaoNamespace + "referenceChannel": .integer(Int64(take.analysisReferenceChannel ?? 0)),
                    VAOContract.vaoNamespace + "navigatorPayloadSHA256": .string(take.provenance?.navigatorPayloadSHA256 ?? project.snapshot.payloadSHA256),
                ],
                notes: take.reviewReason
            ))
            relations.append(VAORelation(subjectId: takeID, predicate: VAOContract.generatedBy, objectId: activityID, status: "accepted"))

            if let analysis = take.analysis {
                let analysisID = stableURN(kind: "analysis", value: take.id.uuidString.lowercased())
                let run = take.analysisRuns?.first(where: { $0.id == analysis.analysisRunID }) ?? take.analysisRuns?.last
                let analysisActivityID = stableURN(kind: "activity", value: "analysis|\(run?.id.uuidString ?? analysisID)")
                paradata.append(VAOParadata(
                    id: analysisActivityID,
                    activityType: VAOContract.vaoVocabulary + "activity/AudioAnalysis",
                    startedAt: run?.startedAt ?? analysis.analyzedAt,
                    endedAt: run?.finishedAt ?? analysis.analyzedAt,
                    actorIds: nil,
                    software: VAOSoftware(name: "OrgRec", version: analysis.algorithmVersion, uri: "https://modavis.org/orgrec", build: nil),
                    inputIds: [audioAsset.id],
                    outputIds: [analysisID] + derivativeAssets + proposedLoopOutputIDs,
                    parameters: (run?.parameters ?? [:]).reduce(into: [:]) { $0[VAOContract.vaoNamespace + "analysisParameter/" + $1.key] = .string($1.value) },
                    notes: run.map { "Input SHA-256: \($0.inputSHA256)" }
                ))
                var observations: [VAOObservation] = []
                let pitchUncertainty = analysis.pitchTrackSummary.flatMap { summary -> Double? in
                    guard let lower = summary.lowerUncertaintyCents, let upper = summary.upperUncertaintyCents else { return nil }
                    return (upper - lower) / 2
                }
                appendObservation(&observations, property: "pitch/frequency", value: analysis.frequencyHz, unit: "http://qudt.org/vocab/unit/HZ", confidence: analysis.confidence, subject: takeID)
                appendObservation(&observations, property: "pitch/cents-deviation", value: analysis.centsDeviation, unit: VAOContract.vaoVocabulary + "unit/cent", uncertainty: pitchUncertainty, confidence: analysis.confidence, subject: takeID)
                appendObservation(&observations, property: "pitch/iqr", value: analysis.pitchTrackSummary?.interquartileRangeCents, unit: VAOContract.vaoVocabulary + "unit/cent", subject: takeID)
                appendObservation(&observations, property: "pitch/drift", value: analysis.pitchTrackSummary?.driftCentsPerSecond, unit: "https://w3id.org/modavis/vao/vocab/unit/cent-per-second", subject: takeID)
                appendObservation(&observations, property: "pitch/estimator-difference", value: analysis.pitchEstimatorComparison?.differenceCents, unit: VAOContract.vaoVocabulary + "unit/cent", subject: takeID)
                for estimate in analysis.pitchEstimatorComparison?.estimates ?? [] {
                    let slug = estimate.estimator.lowercased().replacingOccurrences(of: " ", with: "-")
                    appendObservation(&observations, property: "pitch/frequency-\(slug)", value: estimate.frequencyHz, unit: "http://qudt.org/vocab/unit/HZ", confidence: estimate.confidence, subject: takeID)
                }
                appendObservation(&observations, property: "signal/snr", value: analysis.signalToNoiseDB, unit: "http://qudt.org/vocab/unit/DeciB", subject: takeID)
                appendObservation(&observations, property: "signal/dc-offset", value: analysis.dcOffset, unit: "https://w3id.org/modavis/vao/vocab/unit/full-scale-ratio", subject: takeID)
                appendObservation(&observations, property: "spectrum/centroid", value: analysis.spectralSummary?.spectralCentroidHz, unit: "http://qudt.org/vocab/unit/HZ", subject: takeID)
                appendObservation(&observations, property: "spectrum/rolloff-85", value: analysis.spectralSummary?.spectralRolloff85Hz, unit: "http://qudt.org/vocab/unit/HZ", subject: takeID)
                appendObservation(&observations, property: "spectrum/odd-even-ratio", value: analysis.spectralSummary?.oddEvenEnergyRatioDB, unit: "http://qudt.org/vocab/unit/DeciB", subject: takeID)
                appendObservation(&observations, property: "spectrum/inharmonicity", value: analysis.spectralSummary?.weightedInharmonicityCents, unit: VAOContract.vaoVocabulary + "unit/cent", subject: takeID)
                appendObservation(&observations, property: "spectrum/spread", value: analysis.perceptualSpectralSummary?.spectralSpreadHz, unit: "http://qudt.org/vocab/unit/HZ", subject: takeID)
                appendObservation(&observations, property: "spectrum/flatness", value: analysis.perceptualSpectralSummary?.spectralFlatness, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                appendObservation(&observations, property: "spectrum/entropy", value: analysis.perceptualSpectralSummary?.spectralEntropy, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                appendObservation(&observations, property: "spectrum/crest", value: analysis.perceptualSpectralSummary?.spectralCrestDB, unit: "http://qudt.org/vocab/unit/DeciB", subject: takeID)
                appendObservation(&observations, property: "spectrum/flux", value: analysis.perceptualSpectralSummary?.spectralFlux, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                appendObservation(&observations, property: "spectrum/auditory-centroid-erb", value: analysis.perceptualSpectralSummary?.auditoryCentroidERB, unit: VAOContract.vaoVocabulary + "unit/erb-rate", subject: takeID)
                appendObservation(&observations, property: "spectrum/auditory-spread-erb", value: analysis.perceptualSpectralSummary?.auditorySpreadERB, unit: VAOContract.vaoVocabulary + "unit/erb-rate", subject: takeID)
                appendObservation(&observations, property: "spectrum/harmonic-energy-ratio", value: analysis.perceptualSpectralSummary?.harmonicEnergyRatio, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                appendObservation(&observations, property: "spectrum/harmonic-slope", value: analysis.perceptualSpectralSummary?.harmonicSpectralSlopeDBPerOctave, unit: VAOContract.vaoVocabulary + "unit/decibel-per-octave", subject: takeID)
                appendObservation(&observations, property: "spectrum/harmonic-deviation", value: analysis.perceptualSpectralSummary?.harmonicSpectralDeviationDB, unit: "http://qudt.org/vocab/unit/DeciB", subject: takeID)
                appendObservation(&observations, property: "spectrum/tristimulus-1", value: analysis.perceptualSpectralSummary?.tristimulus1, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                appendObservation(&observations, property: "spectrum/tristimulus-2", value: analysis.perceptualSpectralSummary?.tristimulus2, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                appendObservation(&observations, property: "spectrum/tristimulus-3", value: analysis.perceptualSpectralSummary?.tristimulus3, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                appendObservation(&observations, property: "spectrum/centroid-modulation-rate", value: analysis.perceptualSpectralSummary?.spectralCentroidModulationRateHz, unit: "http://qudt.org/vocab/unit/HZ", confidence: analysis.perceptualSpectralSummary?.spectralCentroidModulationConfidence, subject: takeID)
                appendObservation(&observations, property: "spectrum/centroid-modulation-depth", value: analysis.perceptualSpectralSummary?.spectralCentroidModulationDepthERB, unit: VAOContract.vaoVocabulary + "unit/erb-rate", confidence: analysis.perceptualSpectralSummary?.spectralCentroidModulationConfidence, subject: takeID)
                appendObservation(&observations, property: "level/peak-dbfs", value: analysis.peakDBFS, unit: "https://w3id.org/modavis/vao/vocab/unit/dbfs", subject: takeID)
                appendObservation(&observations, property: "level/rms-dbfs", value: analysis.rmsDBFS, unit: "https://w3id.org/modavis/vao/vocab/unit/dbfs", subject: takeID)
                appendObservation(&observations, property: "pipe/attack-duration", value: analysis.pipeSoundBehavior?.attackDurationSeconds, unit: "http://qudt.org/vocab/unit/SEC", subject: takeID)
                appendObservation(&observations, property: "pipe/attack-periods", value: analysis.pipeSoundBehavior?.attackDurationFundamentalPeriods, unit: "https://w3id.org/modavis/vao/vocab/unit/fundamental-period", subject: takeID)
                appendObservation(&observations, property: "pipe/sustain-stationarity", value: analysis.pipeSoundBehavior?.sustainStationarity, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                appendObservation(&observations, property: "pipe/amplitude-modulation-rate", value: analysis.pipeSoundBehavior?.amplitudeModulationRateHz, unit: "http://qudt.org/vocab/unit/HZ", subject: takeID)
                appendObservation(&observations, property: "pipe/amplitude-modulation-depth", value: analysis.pipeSoundBehavior?.amplitudeModulationDepthDB, unit: "http://qudt.org/vocab/unit/DeciB", subject: takeID)
                appendObservation(&observations, property: "pipe/frequency-modulation-rate", value: analysis.pipeSoundBehavior?.frequencyModulationRateHz, unit: "http://qudt.org/vocab/unit/HZ", subject: takeID)
                appendObservation(&observations, property: "pipe/frequency-modulation-depth", value: analysis.pipeSoundBehavior?.frequencyModulationDepthCents, unit: VAOContract.vaoVocabulary + "unit/cent", subject: takeID)
                appendObservation(&observations, property: "pipe/release-duration", value: analysis.pipeSoundBehavior?.releaseDurationSeconds, unit: "http://qudt.org/vocab/unit/SEC", subject: takeID)
                appendObservation(&observations, property: "pipe/room-tail-duration", value: analysis.pipeSoundBehavior?.roomTailDurationSeconds, unit: "http://qudt.org/vocab/unit/SEC", subject: takeID)
                appendObservation(&observations, property: "acoustics/observed-decay-edt", value: analysis.acousticResponseAnalysis?.broadband.edt?.extrapolatedDecayTimeSeconds, unit: "http://qudt.org/vocab/unit/SEC", uncertainty: analysis.acousticResponseAnalysis?.broadband.edt?.standardUncertaintySeconds, subject: takeID)
                appendObservation(&observations, property: "acoustics/observed-decay-t20", value: analysis.acousticResponseAnalysis?.broadband.t20?.extrapolatedDecayTimeSeconds, unit: "http://qudt.org/vocab/unit/SEC", uncertainty: analysis.acousticResponseAnalysis?.broadband.t20?.standardUncertaintySeconds, subject: takeID)
                appendObservation(&observations, property: "acoustics/observed-decay-t30", value: analysis.acousticResponseAnalysis?.broadband.t30?.extrapolatedDecayTimeSeconds, unit: "http://qudt.org/vocab/unit/SEC", uncertainty: analysis.acousticResponseAnalysis?.broadband.t30?.standardUncertaintySeconds, subject: takeID)
                appendObservation(&observations, property: "acoustics/observed-decay-usable-range", value: analysis.acousticResponseAnalysis?.broadband.usableDecayRangeDB, unit: "http://qudt.org/vocab/unit/DeciB", subject: takeID)
                appendObservation(&observations, property: "acoustics/observed-decay-early-slope-time", value: analysis.acousticResponseAnalysis?.broadband.multiSlope?.earlyDecayTimeSeconds, unit: "http://qudt.org/vocab/unit/SEC", subject: takeID)
                appendObservation(&observations, property: "acoustics/observed-decay-late-slope-time", value: analysis.acousticResponseAnalysis?.broadband.multiSlope?.lateDecayTimeSeconds, unit: "http://qudt.org/vocab/unit/SEC", subject: takeID)
                appendObservation(&observations, property: "acoustics/observed-decay-multislope-delta-bic", value: analysis.acousticResponseAnalysis?.broadband.multiSlope?.deltaBIC, unit: "http://qudt.org/vocab/unit/UNITLESS", subject: takeID)
                let retainedLoopScore = loopSets.first(where: { $0.id == take.acceptedLoopPointSetID })?.sustainRegion?.score?.total
                    ?? analysis.detectedLoopPointSets?.first?.sustainRegion?.score?.total
                appendObservation(&observations, property: "pipe/loop-seam-score", value: retainedLoopScore, unit: "https://w3id.org/modavis/vao/vocab/unit/normalized-penalty", subject: takeID)
                let onsetResolution = analysis.boundaries?.first(where: { $0.marker == .onset })?.timeResolutionSeconds
                let offsetResolution = analysis.boundaries?.first(where: { $0.marker == .soundOffset })?.timeResolutionSeconds
                appendObservation(&observations, property: "time/onset", value: analysis.onsetSeconds, unit: "http://qudt.org/vocab/unit/SEC", uncertainty: onsetResolution.map { $0 / 2 }, subject: takeID)
                appendObservation(&observations, property: "time/sound-offset", value: analysis.soundOffsetSeconds, unit: "http://qudt.org/vocab/unit/SEC", uncertainty: offsetResolution.map { $0 / 2 }, subject: takeID)
                observations.append(VAOObservation(
                    property: VAOContract.vaoVocabulary + "analysis/clipped-samples",
                    value: .integer(Int64(analysis.clippedSamples)), unit: nil, uncertainty: nil,
                    confidence: nil, subjectId: takeID, timeRange: nil
                ))
                analyses.append(VAOAnalysis(
                    id: analysisID,
                    analysisType: VAOContract.vaoVocabulary + "analysis/pipe-sample-characterization",
                    method: analysis.method,
                    version: analysis.algorithmVersion,
                    generatedAt: analysis.analyzedAt,
                    inputIds: [audioAsset.id],
                    outputIds: derivativeAssets,
                    paradataId: analysisActivityID,
                    observations: observations,
                    qualityFlags: analysis.qualityFlags
                ))
                relations.append(VAORelation(subjectId: analysisID, predicate: VAOContract.derivedFrom, objectId: audioAsset.id, status: "accepted"))
                for loopID in proposedLoopOutputIDs {
                    relations.append(VAORelation(subjectId: loopID, predicate: VAOContract.generatedBy, objectId: analysisActivityID, status: "inferred"))
                }
            }
        }

        var tuningEntriesByKey: [Int: VAOJSONValue] = [:]
        let playbackTakes = project.takes.sorted {
            ($0.analysis?.confidence ?? 0) > ($1.analysis?.confidence ?? 0)
        }
        for take in playbackTakes {
            guard let item = roadmapByID[take.roadmapItemID], let key = item.component.midiNote,
                  tuningEntriesByKey[key] == nil,
                  let target = take.analysis?.frequencyHz ?? item.component.expectedFrequencyHz, target > 0 else { continue }
            var entry: [String: VAOJSONValue] = [
                "keyNumber": .integer(Int64(key)),
                "targetFrequencyHz": .number(target),
                "takeId": .string(takeEntityIDs[take.id] ?? "urn:uuid:\(take.id.uuidString.lowercased())"),
                "status": .string(take.analysis?.frequencyHz == nil ? "documented-prior" : "inferred-from-capture"),
            ]
            if let componentID = componentIDs[item.component.id] { entry["componentId"] = .string(componentID) }
            if let confidence = take.analysis?.confidence { entry["confidence"] = .number(confidence) }
            if let expected = item.component.expectedFrequencyHz { entry["documentedExpectedFrequencyHz"] = .number(expected) }
            tuningEntriesByKey[key] = .object(entry)
        }
        if !tuningEntriesByKey.isEmpty {
            hasTuningMap = true
            let acceptedCalibration = (project.tuningCalibrations ?? []).last(where: { $0.status == .accepted && $0.normalizedA4Hz != nil })
            let referenceA4 = acceptedCalibration?.normalizedA4Hz
                ?? project.documentedPitchStandard?.frequencyHz
                ?? project.organCharacteristics?.referencePitchHz
                ?? 440
            var tuningProperties: [String: VAOJSONValue] = [
                VAOContract.modavisAudio + "contractVersion": .string("modaudio.tuning-map/0.2.0"),
                VAOContract.modavisAudio + "status": .string("inferred"),
                VAOContract.modavisAudio + "referenceA4Hz": .number(referenceA4),
                VAOContract.modavisAudio + "referenceKeyNumber": .integer(69),
                VAOContract.modavisAudio + "tuningEntries": .array(tuningEntriesByKey.keys.sorted().compactMap { tuningEntriesByKey[$0] }),
            ]
            if let temperament = project.organCharacteristics?.temperament ?? project.roadmapCompilation?.temperament {
                tuningProperties[VAOContract.modavisAudio + "temperamentIdentifier"] = .string(temperament)
            }
            entities.append(VAOEntity(
                id: tuningMapID,
                kind: "parameterSet",
                types: [VAOContract.tuningMapType],
                labels: ["und": "Captured per-note tuning map"],
                properties: tuningProperties
            ))
            relations.append(VAORelation(subjectId: instrumentID, predicate: VAOContract.hasTuningMap, objectId: tuningMapID, status: "inferred"))
            let tuningInputs = playbackTakes.compactMap { takeEntityIDs[$0.id] }
            let tuningActivityID = stableURN(kind: "activity", value: "tuning-map|\(project.id.uuidString.lowercased())")
            paradata.append(VAOParadata(
                id: tuningActivityID,
                activityType: VAOContract.vaoVocabulary + "activity/TuningMapCompilation",
                startedAt: project.updatedAt,
                endedAt: project.updatedAt,
                actorIds: nil,
                software: VAOSoftware(name: "OrgRec", version: VAOContract.formatVersion, uri: "https://modavis.org/orgrec", build: nil),
                inputIds: tuningInputs.isEmpty ? [instrumentID] : tuningInputs,
                outputIds: [tuningMapID],
                parameters: [VAOContract.modavisAudio + "policy": .string("Use measured stable fundamental when available; otherwise retain documented roadmap frequency.")],
                notes: "This inferred map preserves captured pipe tuning. It is distinct from documented pitch, calibration, temperament inference, and an explicitly reviewed retuning decision."
            ))
            relations.append(VAORelation(subjectId: tuningMapID, predicate: VAOContract.generatedBy, objectId: tuningActivityID, status: "inferred"))
        }

        for report in project.temperamentAnalyses ?? [] {
            let analysisID = "urn:uuid:\(report.id.uuidString.lowercased())"
            let activityID = stableURN(kind: "activity", value: "temperament|\(report.id.uuidString.lowercased())")
            let inputTakeIDs = Array(Set(report.observations.flatMap(\.takeIDs).compactMap { takeEntityIDs[$0] })).sorted()
            let subjectID = componentIDs[report.rankComponentID] ?? instrumentID
            paradata.append(VAOParadata(
                id: activityID,
                activityType: VAOContract.vaoVocabulary + "activity/TemperamentInference",
                startedAt: report.analyzedAt,
                endedAt: report.analyzedAt,
                actorIds: nil,
                software: VAOSoftware(name: "OrgRec", version: report.contractVersion, uri: "https://modavis.org/orgrec", build: nil),
                inputIds: inputTakeIDs.isEmpty ? [subjectID] : inputTakeIDs,
                outputIds: [analysisID],
                parameters: [
                    VAOContract.vaoNamespace + "catalogRelease": .string(report.catalogRelease),
                    VAOContract.vaoNamespace + "catalogPayloadSHA256": .string(report.catalogPayloadSHA256),
                    VAOContract.modavisAudio + "referenceA4Hz": .number(report.referenceA4Hz),
                ],
                notes: report.notes.joined(separator: " ")
            ))
            var temperamentObservations: [VAOObservation] = [
                VAOObservation(
                    property: VAOContract.vaoVocabulary + "analysis/tuning/reference-a4",
                    value: .number(report.referenceA4Hz), unit: "http://qudt.org/vocab/unit/HZ",
                    status: "inferred", applicability: "applicable", subjectId: subjectID
                ),
                VAOObservation(
                    property: VAOContract.vaoVocabulary + "analysis/temperament/pitch-class-map",
                    value: .array(report.observations.map { observation in .object([
                        "pitchClass": .integer(Int64(observation.pitchClass)),
                        "toneName": .string(observation.toneName),
                        "sampleCount": .integer(Int64(observation.sampleCount)),
                        "medianResidualCents": .number(observation.medianResidualCents),
                        "medianAbsoluteDeviationCents": .number(observation.medianAbsoluteDeviationCents),
                        "meanConfidence": .number(observation.meanConfidence),
                    ]) }),
                    unit: VAOContract.vaoVocabulary + "unit/cent", evidenceCount: report.analyzedTakeCount,
                    status: "inferred", applicability: report.inferenceStrength == .insufficient ? "indeterminate" : "applicable",
                    subjectId: subjectID
                ),
            ]
            if let best = report.matches.first {
                temperamentObservations.append(VAOObservation(
                    property: VAOContract.vaoVocabulary + "analysis/temperament/best-candidate",
                    value: .object([
                        "catalogEntryId": .string(best.catalogEntryID),
                        "title": .string(best.title),
                        "robustRMSECents": .number(best.robustRMSECents),
                        "medianAbsoluteErrorCents": .number(best.medianAbsoluteErrorCents),
                        "maximumAbsoluteErrorCents": .number(best.maximumAbsoluteErrorCents),
                        "matchedPitchClassCount": .integer(Int64(best.matchedPitchClassCount)),
                        "inferenceStrength": .string(report.inferenceStrength.rawValue),
                    ]),
                    unit: VAOContract.vaoVocabulary + "unit/cent", confidence: best.sensitivitySupport,
                    evidenceCount: report.analyzedTakeCount, status: "inferred",
                    applicability: report.inferenceStrength == .insufficient ? "indeterminate" : "applicable",
                    subjectId: subjectID
                ))
            }
            appendObservation(&temperamentObservations, property: "temperament/runner-up-margin", value: report.runnerUpMarginCents, unit: VAOContract.vaoVocabulary + "unit/cent", subject: subjectID)
            appendObservation(&temperamentObservations, property: "temperament/median-dispersion", value: report.medianDispersionCents, unit: VAOContract.vaoVocabulary + "unit/cent", subject: subjectID)
            appendObservation(&temperamentObservations, property: "temperament/stretch", value: report.stretchCentsPerOctave, unit: VAOContract.vaoVocabulary + "unit/cent-per-octave", subject: subjectID)
            analyses.append(VAOAnalysis(
                id: analysisID,
                analysisType: VAOContract.vaoVocabulary + "analysis/temperament-inference",
                method: "Uncertainty-weighted pitch-class residual comparison against a pinned temperament catalog",
                version: report.contractVersion,
                generatedAt: report.analyzedAt,
                inputIds: inputTakeIDs.isEmpty ? [subjectID] : inputTakeIDs,
                outputIds: [],
                paradataId: activityID,
                observations: temperamentObservations,
                qualityFlags: report.inferenceStrength == .insufficient ? report.notes + ["insufficient-evidence"] : report.notes
            ))
        }

        if let consensus = project.temperamentConsensus {
            let analysisID = "urn:uuid:\(consensus.id.uuidString.lowercased())"
            let sourceIDs = consensus.sourceReportIDs.map { "urn:uuid:\($0.uuidString.lowercased())" }
            let inputs = sourceIDs.filter { source in analyses.contains(where: { $0.id == source }) }
            let activityID = stableURN(kind: "activity", value: "temperament-consensus|\(consensus.id.uuidString.lowercased())")
            paradata.append(VAOParadata(
                id: activityID,
                activityType: VAOContract.vaoVocabulary + "activity/TemperamentConsensus",
                startedAt: consensus.analyzedAt,
                endedAt: consensus.analyzedAt,
                actorIds: nil,
                software: VAOSoftware(name: "OrgRec", version: consensus.contractVersion, uri: "https://modavis.org/orgrec", build: nil),
                inputIds: inputs.isEmpty ? [instrumentID] : inputs,
                outputIds: [analysisID],
                parameters: [:],
                notes: consensus.notes.joined(separator: " ")
            ))
            analyses.append(VAOAnalysis(
                id: analysisID,
                analysisType: VAOContract.vaoVocabulary + "analysis/temperament-inference",
                method: "Cross-rank temperament consensus",
                version: consensus.contractVersion,
                generatedAt: consensus.analyzedAt,
                inputIds: inputs.isEmpty ? [instrumentID] : inputs,
                outputIds: [],
                paradataId: activityID,
                observations: [
                    VAOObservation(
                        property: VAOContract.vaoVocabulary + "analysis/temperament/rank-agreement",
                        value: .number(consensus.rankAgreement), unit: "http://qudt.org/vocab/unit/UNITLESS",
                        coverage: consensus.rankAgreement, evidenceCount: consensus.sourceReportIDs.count,
                        status: "inferred", applicability: consensus.candidates.isEmpty ? "indeterminate" : "applicable", subjectId: instrumentID
                    ),
                    VAOObservation(
                        property: VAOContract.vaoVocabulary + "analysis/temperament/consensus-candidates",
                        value: .array(consensus.candidates.map { candidate in .object([
                            "catalogEntryId": .string(candidate.catalogEntryID),
                            "title": .string(candidate.title),
                            "supportingRankCount": .integer(Int64(candidate.supportingRankCount)),
                            "meanWeightedRMSECents": .number(candidate.meanWeightedRMSECents),
                        ]) }),
                        unit: VAOContract.vaoVocabulary + "unit/cent", evidenceCount: consensus.sourceReportIDs.count,
                        status: "inferred", applicability: consensus.candidates.isEmpty ? "indeterminate" : "applicable", subjectId: instrumentID
                    ),
                ],
                qualityFlags: consensus.notes
            ))
        }

        for report in project.timbreAnalyses ?? [] {
            let analysisID = "urn:uuid:\(report.id.uuidString.lowercased())"
            let activityID = stableURN(kind: "activity", value: "timbre-analysis|\(report.id.uuidString.lowercased())")
            let inputs = report.observations.compactMap { takeEntityIDs[$0.takeID] }
            let subjectID = componentIDs[report.rankComponentID] ?? instrumentID
            let publications = TimbreMethodology.publications.map { reference -> VAOJSONValue in
                .object([
                    "citation": .string(reference.shortCitation),
                    "doi": .string(reference.doi),
                    "contribution": .string(reference.contribution),
                ])
            }
            let parameters = report.parameters ?? TimbreMethodology.parameters
            let familyProfile = parameters.familyProfile.map { point -> VAOJSONValue in
                .object([
                    "family": .string(point.family.rawValue),
                    "centroidCenter": .number(point.centroidCenter),
                    "slopeCenterDBPerOctave": .number(point.slopeCenterDBPerOctave),
                    "centroidScale": .number(point.centroidScale),
                    "slopeScaleDBPerOctave": .number(point.slopeScaleDBPerOctave),
                ])
            }
            paradata.append(VAOParadata(
                id: activityID,
                activityType: VAOContract.vaoVocabulary + "activity/PipeTimbreCharacterization",
                startedAt: report.analyzedAt,
                endedAt: report.analyzedAt,
                actorIds: nil,
                software: VAOSoftware(name: (report.software ?? OrgRecSoftware.current).name, version: (report.software ?? OrgRecSoftware.current).version, uri: "https://modavis.org/orgrec", build: (report.software ?? OrgRecSoftware.current).build),
                method: [
                    "methodType": .string("metric-calculation"),
                    "representationStatus": .string("inferred"),
                    "standard": .string("https://doi.org/10.1121/2.0001673"),
                    "qualityFlags": .array(report.warnings.map(VAOJSONValue.string)),
                ],
                inputIds: inputs.isEmpty ? [subjectID] : inputs,
                outputIds: [analysisID],
                parameters: [
                    "targetSampleRateHz": .number(TimbreMethodology.targetSampleRate),
                    "maximumHarmonicPartial": .integer(Int64(TimbreMethodology.maximumPartialCount)),
                    "weightedSlopeExponent": .number(TimbreMethodology.slopeExponent),
                    "weightedSlopeSignConvention": .string("positive-for-ascending-adjacent-partials"),
                    "channelPolicy": .string("designated-reference-channel-no-waveform-downmix"),
                    "mode": .string(report.mode.rawValue),
                    "contract": .string(report.contractVersion),
                    "familyProfile": .string(report.familyProfileVersion),
                    "parameterSHA256": .string(report.parameterSHA256 ?? TimbreMethodology.parameterSHA256),
                    "fftSizes": .array(parameters.fftSizes.map { .integer(Int64($0)) }),
                    "targetFundamentalCycles": .number(parameters.targetFundamentalCycles),
                    "minimumWindowSeconds": .number(parameters.minimumWindowSeconds),
                    "maximumWindowSeconds": .number(parameters.maximumWindowSeconds),
                    "frameOverlapFraction": .number(parameters.frameOverlapFraction),
                    "maximumAveragedFrames": .integer(Int64(parameters.maximumAveragedFrames)),
                    "maximumStableDurationSeconds": .number(parameters.maximumStableDurationSeconds),
                    "maximumPartialFrequencyHz": .number(parameters.maximumPartialFrequencyHz),
                    "localSignalToNoiseThresholdDB": .number(parameters.localSignalToNoiseThresholdDB),
                    "minimumMeasuredPitchConfidence": .number(parameters.minimumMeasuredPitchConfidence),
                    "minimumDetectedPartials": .integer(Int64(parameters.minimumDetectedPartials)),
                    "minimumRankObservationCount": .integer(Int64(parameters.minimumRankObservationCount)),
                    "centroidDomain": .array([.number(parameters.centroidDomain.lowerBound), .number(parameters.centroidDomain.upperBound)]),
                    "slopeDomain": .array([.number(parameters.slopeDomainDBPerOctave.lowerBound), .number(parameters.slopeDomainDBPerOctave.upperBound)]),
                    "maximumProfileDistance": .number(parameters.maximumProfileDistance),
                    "adjacentTransitionMaximumSemitones": .integer(Int64(parameters.adjacentTransitionMaximumSemitones)),
                    "adjacentTransitionThreshold": .number(parameters.adjacentTransitionThreshold),
                    "limitedObservationWeight": .number(parameters.limitedObservationWeight),
                    "familyProfilePoints": .array(familyProfile),
                    "publications": .array(publications),
                ],
                notes: report.warnings.joined(separator: " ")
            ))
            let pipeValues = report.observations.map { observation -> VAOJSONValue in
                let sourceAnalysisRunID: VAOJSONValue = observation.sourceAnalysisRunID
                    .map { .string("urn:uuid:\($0.uuidString.lowercased())") } ?? .null
                let fallbackTakeID = "urn:uuid:\(observation.takeID.uuidString.lowercased())"
                let takeID = takeEntityIDs[observation.takeID] ?? fallbackTakeID
                let keyNumber: VAOJSONValue = observation.midiNote.map { .integer(Int64($0)) } ?? .null
                let noteName: VAOJSONValue = observation.noteName.map(VAOJSONValue.string) ?? .null
                let centroid: VAOJSONValue = observation.normalizedSpectralCentroid.map(VAOJSONValue.number) ?? .null
                let slope: VAOJSONValue = observation.weightedAverageSlopeDBPerOctave.map(VAOJSONValue.number) ?? .null
                let evenOdd: VAOJSONValue = observation.evenToOddEnergyRatioDB.map(VAOJSONValue.number) ?? .null
                let values: [String: VAOJSONValue] = [
                    "takeId": .string(takeID),
                    "keyNumber": keyNumber,
                    "noteName": noteName,
                    "sourceAudioSHA256": .string(observation.sourceAudioSHA256),
                    "sourceAnalysisRunId": sourceAnalysisRunID,
                    "referenceChannelIndex": .integer(Int64(observation.referenceChannel)),
                    "stableStartSeconds": .number(observation.segmentStartSeconds),
                    "stableEndSeconds": .number(observation.segmentEndSeconds),
                    "fundamentalFrequencyHz": .number(observation.fundamentalFrequencyHz),
                    "fundamentalSource": .string(observation.fundamentalSource.rawValue),
                    "fftSize": .integer(Int64(observation.fftSize)),
                    "averagedFrameCount": .integer(Int64(observation.averagedFrameCount)),
                    "detectedPartialCount": .integer(Int64(observation.partials.count)),
                    "normalizedSpectralCentroid": centroid,
                    "weightedAverageSlopeDBPerOctave": slope,
                    "evenToOddEnergyRatioDB": evenOdd,
                    "firstFivePartialPrototype": .string(observation.firstFivePrototype.rawValue),
                    "applicability": .string(observation.applicability.rawValue),
                    "outOfDistribution": .boolean(observation.outOfDistribution ?? false),
                    "qualityFlags": .array(observation.warnings.map(VAOJSONValue.string)),
                ]
                return .object(values)
            }
            let familyValues = report.familyCandidates.map { candidate -> VAOJSONValue in
                .object([
                    "family": .string(candidate.family.rawValue),
                    "relativeSupport": .number(candidate.relativeSupport),
                    "meanNormalizedDistance": .number(candidate.normalizedDistance),
                    "relativeSupportStandardDeviation": candidate.relativeSupportStandardDeviation.map(VAOJSONValue.number) ?? .null,
                    "effectiveObservationCount": candidate.effectiveObservationCount.map(VAOJSONValue.number) ?? .null,
                    "profileVersion": .string(report.familyProfileVersion),
                ])
            }
            analyses.append(VAOAnalysis(
                id: analysisID,
                analysisType: VAOContract.vaoVocabulary + "analysis/pipe-timbre-characterization",
                method: "Steady-state harmonic LTAS characterization derived from the cited Hergert methodology; optional broad-family distance profile",
                version: report.contractVersion,
                generatedAt: report.analyzedAt,
                inputIds: inputs.isEmpty ? [subjectID] : inputs,
                outputIds: [],
                paradataId: activityID,
                observations: [
                    VAOObservation(
                        property: VAOContract.vaoVocabulary + "analysis/timbre/pipe-observations",
                        value: .array(pipeValues),
                        unit: "http://qudt.org/vocab/unit/UNITLESS",
                        evidenceCount: report.observations.count,
                        status: "inferred",
                        applicability: report.applicability.rawValue,
                        aggregation: VAOContract.vaoVocabulary + "aggregation/rank-trajectory-by-key",
                        subjectId: subjectID,
                        qualityFlags: report.warnings
                    ),
                    VAOObservation(
                        property: VAOContract.vaoVocabulary + "analysis/timbre/broad-family-relative-support",
                        value: .array(familyValues),
                        unit: "http://qudt.org/vocab/unit/UNITLESS",
                        evidenceCount: report.observations.count,
                        status: "inferred",
                        applicability: report.mode == .familySuggestion ? report.applicability.rawValue : "indeterminate",
                        aggregation: VAOContract.vaoVocabulary + "aggregation/mean-per-pipe-relative-support",
                        subjectId: subjectID,
                        qualityFlags: ["Relative support is not a calibrated probability or documentary identification."]
                    ),
                ],
                qualityFlags: report.warnings
            ))

            if let classification = report.empiricalClassification {
                let empiricalID = stableURN(kind: "analysis", value: "empirical-timbre|\(report.id.uuidString.lowercased())")
                let empiricalActivityID = stableURN(kind: "activity", value: "empirical-timbre|\(report.id.uuidString.lowercased())")
                let empiricalInputs = Array(Set((inputs.isEmpty ? [subjectID] : inputs) + (empiricalModelAsset.map { [$0.id] } ?? []))).sorted()
                paradata.append(VAOParadata(
                    id: empiricalActivityID,
                    activityType: VAOContract.vaoVocabulary + "activity/EmpiricalHierarchicalTimbreInference",
                    startedAt: report.analyzedAt,
                    endedAt: report.analyzedAt,
                    actorIds: nil,
                    software: VAOSoftware(name: OrgRecSoftware.name, version: OrgRecSoftware.version, uri: "https://modavis.org/orgrec", build: OrgRecSoftware.build),
                    method: [
                        "methodType": .string("machine-learning-inference"),
                        "representationStatus": .string("learned"),
                        "qualityFlags": .array(report.warnings.map(VAOJSONValue.string)),
                    ],
                    inputIds: empiricalInputs,
                    outputIds: [empiricalID],
                    parameters: [
                        "modelVersion": .string(classification.modelVersion),
                        "trainingCorpusSHA256": classification.trainingCorpusSHA256.map(VAOJSONValue.string) ?? .null,
                        "taxonomyVersion": .string(classification.taxonomyVersion),
                        "featureSchemaVersion": .string(classification.featureSchemaVersion),
                        "minimumAcceptedProbability": .number(classification.minimumAcceptedProbability),
                        "outOfDistributionThreshold": .number(classification.outOfDistributionThreshold),
                        "groupingPolicy": .string("training-calibration-test partitions are disjoint by catalogued physical instrument"),
                    ],
                    notes: classification.reason
                ))
                let distribution: [VAOJSONValue] = classification.candidates.map { candidate in
                    .object([
                        "concept": .string(VAOContract.vaoVocabulary + "timbre-family/\(candidate.family.rawValue)"),
                        "family": .string(candidate.family.rawValue),
                        "calibratedProbability": .number(candidate.calibratedProbability),
                        "hierarchyPath": .array(candidate.hierarchyPath.map(VAOJSONValue.string)),
                    ])
                }
                let decision: [String: VAOJSONValue] = [
                    "selectedConcept": classification.selectedFamily.map { .string(VAOContract.vaoVocabulary + "timbre-family/\($0.rawValue)") } ?? .null,
                    "abstained": .boolean(classification.abstained),
                    "outOfDistribution": .boolean(classification.outOfDistribution),
                    "outOfDistributionDistance": .number(classification.outOfDistributionDistance),
                    "reason": classification.reason.map(VAOJSONValue.string) ?? .null,
                ]
                analyses.append(VAOAnalysis(
                    id: empiricalID,
                    analysisType: VAOContract.vaoVocabulary + "analysis/empirical-hierarchical-timbre-classification",
                    method: "Hierarchical multinomial logistic inference with held-out-instrument temperature calibration, empirical OOD distance, and validation-selected abstention",
                    version: classification.modelVersion,
                    generatedAt: report.analyzedAt,
                    inputIds: empiricalInputs,
                    outputIds: [],
                    paradataId: empiricalActivityID,
                    observations: [
                        VAOObservation(
                            property: VAOContract.vaoVocabulary + "analysis/timbre/calibrated-family-distribution",
                            value: .array(distribution),
                            unit: "http://qudt.org/vocab/unit/UNITLESS",
                            confidence: classification.candidates.first?.calibratedProbability,
                            evidenceCount: report.observations.count,
                            status: "inferred",
                            applicability: classification.abstained ? "limited" : report.applicability.rawValue,
                            aggregation: VAOContract.vaoVocabulary + "aggregation/rank-fingerprint",
                            subjectId: subjectID
                        ),
                        VAOObservation(
                            property: VAOContract.vaoVocabulary + "analysis/timbre/classification-decision",
                            value: .object(decision),
                            status: "inferred",
                            applicability: classification.abstained ? "limited" : "applicable",
                            subjectId: subjectID,
                            qualityFlags: classification.reason.map { [$0] }
                        ),
                    ],
                    qualityFlags: classification.reason.map { [$0] }
                ))
            }

            if let fingerprint = report.pitchDependentFingerprint, !fingerprint.points.isEmpty {
                let fingerprintID = stableURN(kind: "analysis", value: "rank-fingerprint|\(report.id.uuidString.lowercased())")
                let fingerprintActivityID = stableURN(kind: "activity", value: "rank-fingerprint|\(report.id.uuidString.lowercased())")
                let fingerprintInputs = inputs.isEmpty ? [subjectID] : inputs
                paradata.append(VAOParadata(
                    id: fingerprintActivityID,
                    activityType: VAOContract.vaoVocabulary + "activity/PitchDependentRankFingerprinting",
                    startedAt: fingerprint.generatedAt,
                    endedAt: fingerprint.generatedAt,
                    actorIds: nil,
                    software: VAOSoftware(name: OrgRecSoftware.name, version: OrgRecSoftware.version, uri: "https://modavis.org/orgrec", build: OrgRecSoftware.build),
                    method: [
                        "methodType": .string("metric-calculation"),
                        "representationStatus": .string("inferred"),
                        "randomSeed": .integer(Int64(bitPattern: fingerprint.parameters.randomSeed)),
                        "qualityFlags": .array(fingerprint.warnings.map(VAOJSONValue.string)),
                    ],
                    inputIds: fingerprintInputs,
                    outputIds: [fingerprintID],
                    parameters: [
                        "algorithmVersion": .string(fingerprint.algorithmVersion),
                        "featureSchemaVersion": .string(fingerprint.featureSchemaVersion),
                        "parameterSHA256": .string(fingerprint.parameterSHA256),
                        "minimumObservations": .integer(Int64(fingerprint.parameters.minimumObservations)),
                        "minimumSegmentObservations": .integer(Int64(fingerprint.parameters.minimumSegmentObservations)),
                        "maximumTransitions": .integer(Int64(fingerprint.parameters.maximumTransitions)),
                        "maximumAdjacentGapSemitones": .integer(Int64(fingerprint.parameters.maximumAdjacentGapSemitones)),
                        "minimumBICImprovement": .number(fingerprint.parameters.minimumBICImprovement),
                        "significanceLevel": .number(fingerprint.parameters.significanceLevel),
                        "permutationCount": .integer(Int64(fingerprint.parameters.permutationCount)),
                    ],
                    notes: fingerprint.warnings.joined(separator: " ")
                ))
                let trajectory: [VAOJSONValue] = fingerprint.points.map { point in
                    .object([
                        "keyNumber": .integer(Int64(point.midiNote)),
                        "normalizedSpectralCentroid": .number(point.normalizedSpectralCentroid),
                        "weightedAverageSlopeDBPerOctave": .number(point.weightedAverageSlopeDBPerOctave),
                        "evenToOddEnergyRatioDB": point.evenToOddEnergyRatioDB.map(VAOJSONValue.number) ?? .null,
                        "relativePartialLevelsDB": .array(point.relativePartialLevelsDB.map { $0.map(VAOJSONValue.number) ?? .null }),
                    ])
                }
                let trends: [VAOJSONValue] = fingerprint.trends.map { trend in
                    .object([
                        "feature": .string(trend.feature),
                        "interceptAtMIDIMiddle": .number(trend.interceptAtMIDIMiddle),
                        "linearChangePerOctave": .number(trend.linearChangePerOctave),
                        "quadraticChangePerOctaveSquared": .number(trend.quadraticChangePerOctaveSquared),
                        "residualRMSE": .number(trend.residualRMSE),
                    ])
                }
                let transitions: [VAOJSONValue] = fingerprint.transitions.map { transition in
                    .object([
                        "lowerKeyNumber": .integer(Int64(transition.lowerMIDINote)),
                        "upperKeyNumber": .integer(Int64(transition.upperMIDINote)),
                        "bicImprovement": .number(transition.bicImprovementForSelectedSegmentation),
                        "familyWisePermutationPValue": .number(transition.familyWisePermutationPValue),
                        "standardizedEffectSize": .number(transition.standardizedEffectSize),
                        "evidenceStrength": .string(transition.evidenceStrength),
                        "interpretation": .string(transition.interpretation),
                    ])
                }
                analyses.append(VAOAnalysis(
                    id: fingerprintID,
                    analysisType: VAOContract.vaoVocabulary + "analysis/pitch-dependent-rank-fingerprint",
                    method: "Robustly standardized pitch trajectory, quadratic feature trends, BIC-selected multivariate segmented regression, and family-wise residual-permutation testing",
                    version: fingerprint.contractVersion,
                    generatedAt: fingerprint.generatedAt,
                    inputIds: fingerprintInputs,
                    outputIds: [],
                    paradataId: fingerprintActivityID,
                    observations: [
                        VAOObservation(
                            property: VAOContract.vaoVocabulary + "analysis/timbre/pitch-trajectory",
                            value: .array(trajectory),
                            evidenceCount: fingerprint.points.count,
                            status: "inferred",
                            applicability: fingerprint.applicability.rawValue,
                            aggregation: VAOContract.vaoVocabulary + "aggregation/rank-trajectory-by-key",
                            subjectId: subjectID
                        ),
                        VAOObservation(
                            property: VAOContract.vaoVocabulary + "analysis/timbre/pitch-trends",
                            value: .array(trends),
                            evidenceCount: fingerprint.points.count,
                            status: "inferred",
                            applicability: fingerprint.applicability.rawValue,
                            subjectId: subjectID
                        ),
                        VAOObservation(
                            property: VAOContract.vaoVocabulary + "analysis/timbre/construction-transition-candidates",
                            value: .array(transitions),
                            evidenceCount: fingerprint.points.count,
                            status: "inferred",
                            applicability: fingerprint.applicability.rawValue,
                            subjectId: subjectID,
                            qualityFlags: fingerprint.warnings
                        ),
                    ],
                    qualityFlags: fingerprint.warnings
                ))
            }
        }

        if let collection = project.collectionAnalysis {
            let analysisID = "urn:uuid:\(collection.id.uuidString.lowercased())"
            let activityID = stableURN(kind: "activity", value: "collection-analysis|\(collection.id.uuidString.lowercased())")
            let assessedTakeIDs = collection.assessedTakeIDs ?? (collection.takeEvidence ?? []).map(\.takeID)
            let inputs = assessedTakeIDs.compactMap { takeEntityIDs[$0] }
            let resolvedInputs = inputs.isEmpty ? [instrumentID] : Array(Set(inputs)).sorted()

            if let parameters = collection.parameters,
               let parameterSHA256 = collection.parameterSHA256,
               let evidenceSummary = collection.evidenceSummary,
               let takeEvidence = collection.takeEvidence {
                hasCollectionAcousticDiagnostics = true
                var rankSubjectIDs: [String: String] = [:]
                for profile in collection.rankTuningProfiles {
                    if let componentID = componentIDs[profile.rankComponentID] {
                        rankSubjectIDs[profile.rankComponentID] = componentID
                        continue
                    }
                    let groupingID = stableURN(kind: "analytical-rank-group", value: profile.rankComponentID)
                    rankSubjectIDs[profile.rankComponentID] = groupingID
                    if !entities.contains(where: { $0.id == groupingID }) {
                        entities.append(VAOEntity(
                            id: groupingID,
                            kind: "componentCollection",
                            types: [VAOContract.vaoNamespace + "AnalyticalComponentGrouping"],
                            labels: ["und": profile.rankLabel],
                            properties: [
                                VAOContract.vaoNamespace + "groupingBasis": .string(profile.groupingBasis ?? "legacy-unspecified"),
                                VAOContract.vaoNamespace + "sourceGroupingIdentifier": .string(profile.rankComponentID),
                            ]
                        ))
                        relations.append(VAORelation(
                            subjectId: instrumentID,
                            predicate: VAOContract.vaoNamespace + "hasAnalyticalGrouping",
                            objectId: groupingID,
                            status: "inferred"
                        ))
                    }
                }
                for assessment in takeEvidence where rankSubjectIDs[assessment.rankComponentID] == nil {
                    if let componentID = componentIDs[assessment.rankComponentID] {
                        rankSubjectIDs[assessment.rankComponentID] = componentID
                        continue
                    }
                    let groupingID = stableURN(kind: "analytical-rank-group", value: assessment.rankComponentID)
                    rankSubjectIDs[assessment.rankComponentID] = groupingID
                    if !entities.contains(where: { $0.id == groupingID }) {
                        entities.append(VAOEntity(
                            id: groupingID,
                            kind: "componentCollection",
                            types: [VAOContract.vaoNamespace + "AnalyticalComponentGrouping"],
                            labels: ["und": "Evidence-ledger rank grouping"],
                            properties: [
                                VAOContract.vaoNamespace + "groupingBasis": .string("evidence-ledger-grouping"),
                                VAOContract.vaoNamespace + "sourceGroupingIdentifier": .string(assessment.rankComponentID),
                            ]
                        ))
                        relations.append(VAORelation(
                            subjectId: instrumentID,
                            predicate: VAOContract.vaoNamespace + "hasAnalyticalGrouping",
                            objectId: groupingID,
                            status: "inferred"
                        ))
                    }
                }
                for report in collection.sessionPitchDrift where sessionIDs[report.sessionID] == nil {
                    let sessionID = "urn:uuid:\(report.sessionID.uuidString.lowercased())"
                    sessionIDs[report.sessionID] = sessionID
                    entities.append(VAOEntity(
                        id: sessionID,
                        kind: "event",
                        types: [VAOContract.vaoNamespace + "RecordingSession"],
                        labels: ["und": report.sessionCode],
                        properties: [VAOContract.vaoNamespace + "sessionCode": .string(report.sessionCode)]
                    ))
                }
                let parameterValues: [String: VAOJSONValue] = [
                    VAOContract.vaoNamespace + "parameterSHA256": .string(parameterSHA256),
                    VAOContract.vaoNamespace + "minimumAggregateQualityScore": .number(parameters.minimumAggregateQualityScore),
                    VAOContract.vaoNamespace + "moderateQualityScore": .number(parameters.moderateQualityScore),
                    VAOContract.vaoNamespace + "highQualityScore": .number(parameters.highQualityScore),
                    VAOContract.vaoNamespace + "minimumAnomalyGroupSize": .integer(Int64(parameters.minimumAnomalyGroupSize)),
                    VAOContract.vaoNamespace + "anomalyWarningScore": .number(parameters.anomalyWarningScore),
                    VAOContract.vaoNamespace + "anomalyCriticalScore": .number(parameters.anomalyCriticalScore),
                    VAOContract.vaoNamespace + "similarityThreshold": .number(parameters.similarityThreshold),
                    VAOContract.vaoNamespace + "minimumSimilarityHarmonics": .integer(Int64(parameters.minimumSimilarityHarmonics)),
                    VAOContract.vaoNamespace + "maximumSimilarityCandidates": .integer(Int64(parameters.maximumSimilarityCandidates)),
                    VAOContract.vaoNamespace + "minimumDriftRepeatedTargets": .integer(Int64(parameters.minimumDriftRepeatedTargets)),
                    VAOContract.vaoNamespace + "minimumDriftPairComparisons": .integer(Int64(parameters.minimumDriftPairComparisons)),
                    VAOContract.vaoNamespace + "minimumDriftSpanHours": .number(parameters.minimumDriftSpanHours),
                ]
                paradata.append(VAOParadata(
                    id: activityID,
                    activityType: VAOContract.vaoVocabulary + "activity/CollectionAcousticDiagnostics",
                    startedAt: collection.analyzedAt,
                    endedAt: collection.analyzedAt,
                    actorIds: nil,
                    software: VAOSoftware(name: "OrgRec", version: collection.contractVersion, uri: "https://modavis.org/orgrec", build: nil),
                    method: [
                        "methodType": .string("metric-calculation"),
                        "representationStatus": .string("inferred"),
                    ],
                    inputIds: resolvedInputs,
                    outputIds: [analysisID],
                    parameters: parameterValues,
                    notes: collection.notes.joined(separator: " ")
                ))

                let evidenceValue: VAOJSONValue = .object([
                    "eligibleTakeCount": .integer(Int64(evidenceSummary.eligibleTakeCount)),
                    "analyzedTakeCount": .integer(Int64(evidenceSummary.analyzedTakeCount)),
                    "aggregateTakeCount": .integer(Int64(evidenceSummary.aggregateTakeCount)),
                    "highQualityCount": .integer(Int64(evidenceSummary.highQualityCount)),
                    "moderateQualityCount": .integer(Int64(evidenceSummary.moderateQualityCount)),
                    "limitedQualityCount": .integer(Int64(evidenceSummary.limitedQualityCount)),
                    "excludedCount": .integer(Int64(evidenceSummary.excludedCount)),
                    "aggregateCoverage": .number(evidenceSummary.aggregateCoverage),
                    "medianQualityScore": evidenceSummary.medianQualityScore.map(VAOJSONValue.number) ?? .null,
                    "exclusions": .array(evidenceSummary.exclusions.map { .object([
                        "reason": .string($0.reason),
                        "count": .integer(Int64($0.count)),
                    ]) }),
                ])
                let takeEvidenceValues = takeEvidence.compactMap { assessment -> VAOJSONValue? in
                    guard let takeID = takeEntityIDs[assessment.takeID] else { return nil }
                    return .object([
                        "takeId": .string(takeID),
                        "rankGroupId": .string(rankSubjectIDs[assessment.rankComponentID] ?? instrumentID),
                        "keyNumber": .integer(Int64(assessment.midiNote)),
                        "qualityScore": .number(assessment.qualityScore),
                        "tier": .string(assessment.tier.rawValue),
                        "includedInAggregates": .boolean(assessment.includedInAggregates),
                        "availableQualityDimensions": .integer(Int64(assessment.availableQualityDimensions)),
                        "exclusionReasons": .array(assessment.exclusionReasons.map(VAOJSONValue.string)),
                        "qualityFlags": .array(assessment.qualityFlags.map(VAOJSONValue.string)),
                    ])
                }
                let rankCurveValues = collection.rankTuningProfiles.map { profile -> VAOJSONValue in
                    .object([
                        "rankGroupId": .string(rankSubjectIDs[profile.rankComponentID] ?? instrumentID),
                        "rankLabel": .string(profile.rankLabel),
                        "groupingBasis": .string(profile.groupingBasis ?? "legacy-unspecified"),
                        "observedKeySpanCoverage": profile.observedKeySpanCoverage.map(VAOJSONValue.number) ?? .null,
                        "points": .array(profile.points.map { point in .object([
                            "keyNumber": .integer(Int64(point.midiNote)),
                            "medianDeviationCents": .number(point.medianDeviationCents),
                            "qualityWeightedDeviationCents": point.qualityWeightedDeviationCents.map(VAOJSONValue.number) ?? .null,
                            "medianAbsoluteDeviationCents": .number(point.medianAbsoluteDeviationCents),
                            "lowerObservedBoundCents": point.lowerObservedBoundCents.map(VAOJSONValue.number) ?? .null,
                            "upperObservedBoundCents": point.upperObservedBoundCents.map(VAOJSONValue.number) ?? .null,
                            "standardUncertaintyCents": point.standardUncertaintyCents.map(VAOJSONValue.number) ?? .null,
                            "effectiveSampleSize": point.effectiveSampleSize.map(VAOJSONValue.number) ?? .null,
                            "medianEvidenceQuality": point.medianEvidenceQuality.map(VAOJSONValue.number) ?? .null,
                            "evidenceCount": .integer(Int64(point.takeIDs.count)),
                        ]) }),
                    ])
                }
                let rankStretchValues = collection.rankTuningProfiles.compactMap { profile -> VAOJSONValue? in
                    guard let stretch = profile.stretchCentsPerOctave else { return nil }
                    return .object([
                        "rankGroupId": .string(rankSubjectIDs[profile.rankComponentID] ?? instrumentID),
                        "stretchCentsPerOctave": .number(stretch),
                        "lowerBoundCentsPerOctave": profile.stretchLowerBoundCentsPerOctave.map(VAOJSONValue.number) ?? .null,
                        "upperBoundCentsPerOctave": profile.stretchUpperBoundCentsPerOctave.map(VAOJSONValue.number) ?? .null,
                        "method": .string(profile.slopeMethod ?? "legacy-unspecified"),
                        "evidenceCount": .integer(Int64(profile.points.count)),
                    ])
                }
                let sessionOffsetValues = collection.sessionPitchDrift.compactMap { report -> VAOJSONValue? in
                    guard let value = report.medianDeviationCents else { return nil }
                    return .object([
                        "sessionId": .string(sessionIDs[report.sessionID] ?? "urn:uuid:\(report.sessionID.uuidString.lowercased())"),
                        "medianDeviationCents": .number(value),
                        "evidenceCount": .integer(Int64(report.analyzedTakeCount)),
                    ])
                }
                let sessionDriftValues = collection.sessionPitchDrift.map { report -> VAOJSONValue in
                    .object([
                        "sessionId": .string(sessionIDs[report.sessionID] ?? "urn:uuid:\(report.sessionID.uuidString.lowercased())"),
                        "driftCentsPerHour": report.driftCentsPerHour.map(VAOJSONValue.number) ?? .null,
                        "lowerBoundCentsPerHour": report.driftLowerBoundCentsPerHour.map(VAOJSONValue.number) ?? .null,
                        "upperBoundCentsPerHour": report.driftUpperBoundCentsPerHour.map(VAOJSONValue.number) ?? .null,
                        "durationHours": report.durationHours.map(VAOJSONValue.number) ?? .null,
                        "repeatedTargetCount": .integer(Int64(report.repeatedTargetCount ?? 0)),
                        "pairComparisonCount": .integer(Int64(report.pairComparisonCount ?? 0)),
                        "applicability": .string(report.applicability ?? "indeterminate"),
                    ])
                }
                let anomalyValues = (collection.acousticAnomalyCandidates ?? []).compactMap { candidate -> VAOJSONValue? in
                    guard let takeID = takeEntityIDs[candidate.takeID] else { return nil }
                    return .object([
                        "takeId": .string(takeID),
                        "rankGroupId": .string(rankSubjectIDs[candidate.rankComponentID] ?? instrumentID),
                        "keyNumber": .integer(Int64(candidate.midiNote)),
                        "robustDistance": .number(candidate.robustDistance),
                        "severity": .string(candidate.severity.rawValue),
                        "evidenceDimensionCount": .integer(Int64(candidate.evidenceDimensionCount)),
                        "qualityScore": .number(candidate.qualityScore),
                        "featureScores": .array(candidate.featureScores.map { .object([
                            "feature": .string($0.feature),
                            "value": .number($0.value),
                            "robustCenter": .number($0.robustCenter),
                            "robustZScore": .number($0.robustZScore),
                        ]) }),
                        "interpretation": .string(candidate.interpretation),
                    ])
                }
                let similarityValues = collection.acousticSimilarityCandidates.compactMap { candidate -> VAOJSONValue? in
                    guard let first = takeEntityIDs[candidate.firstTakeID], let second = takeEntityIDs[candidate.secondTakeID] else { return nil }
                    let pair = [first, second].sorted()
                    return .object([
                        "firstTakeId": .string(pair[0]),
                        "secondTakeId": .string(pair[1]),
                        "cosineSimilarity": .number(candidate.cosineSimilarity),
                        "sharedPartialCount": .integer(Int64(candidate.sharedPartialCount ?? 0)),
                        "evidenceScore": candidate.evidenceScore.map(VAOJSONValue.number) ?? .null,
                        "interpretation": .string(candidate.reason),
                    ])
                }
                let applicability = evidenceSummary.aggregateCoverage >= 0.5 ? "applicable" : "limited"
                analyses.append(VAOAnalysis(
                    id: analysisID,
                    analysisType: VAOContract.collectionAcousticDiagnosticsAnalysis,
                    method: "Evidence-qualified weighting, inverse-variance aggregation, repeated-median rank trends, within-target session drift, robust multivariate anomaly screening, and harmonic-aligned cosine similarity",
                    version: collection.contractVersion,
                    generatedAt: collection.analyzedAt,
                    inputIds: resolvedInputs,
                    outputIds: [],
                    paradataId: activityID,
                    observations: [
                        VAOObservation(property: VAOContract.collectionEvidenceSummaryProperty, value: evidenceValue, coverage: evidenceSummary.aggregateCoverage, evidenceCount: evidenceSummary.eligibleTakeCount, status: "inferred", applicability: applicability, subjectId: instrumentID),
                        VAOObservation(property: VAOContract.collectionTakeEvidenceProperty, value: .array(takeEvidenceValues), evidenceCount: takeEvidenceValues.count, status: "inferred", applicability: applicability, subjectId: instrumentID),
                        VAOObservation(property: VAOContract.collectionRankCurveProperty, value: .array(rankCurveValues), unit: VAOContract.vaoVocabulary + "unit/cent", evidenceCount: evidenceSummary.aggregateTakeCount, status: "inferred", applicability: applicability, aggregation: VAOContract.vaoVocabulary + "aggregation/quality-weighted-median", subjectId: instrumentID),
                        VAOObservation(property: VAOContract.collectionRankStretchProperty, value: .array(rankStretchValues), unit: VAOContract.vaoVocabulary + "unit/cent-per-octave", evidenceCount: rankStretchValues.count, status: "inferred", applicability: rankStretchValues.isEmpty ? "indeterminate" : applicability, aggregation: VAOContract.vaoVocabulary + "aggregation/siegel-repeated-median", subjectId: instrumentID),
                        VAOObservation(property: VAOContract.collectionSessionOffsetProperty, value: .array(sessionOffsetValues), unit: VAOContract.vaoVocabulary + "unit/cent", evidenceCount: sessionOffsetValues.count, status: "inferred", applicability: sessionOffsetValues.isEmpty ? "indeterminate" : applicability, aggregation: VAOContract.vaoVocabulary + "aggregation/median", subjectId: instrumentID),
                        VAOObservation(property: VAOContract.collectionSessionDriftProperty, value: .array(sessionDriftValues), unit: VAOContract.vaoVocabulary + "unit/cent-per-hour", evidenceCount: sessionDriftValues.count, status: "inferred", applicability: sessionDriftValues.contains(where: { value in value.objectValue?["driftCentsPerHour"] != .null }) ? applicability : "indeterminate", aggregation: VAOContract.vaoVocabulary + "aggregation/within-target-median-slope", subjectId: instrumentID),
                        VAOObservation(property: VAOContract.collectionAnomalyProperty, value: .array(anomalyValues), evidenceCount: evidenceSummary.aggregateTakeCount, status: "inferred", applicability: applicability, aggregation: VAOContract.vaoVocabulary + "aggregation/robust-multivariate-distance", subjectId: instrumentID),
                        VAOObservation(property: VAOContract.collectionSimilarityProperty, value: .array(similarityValues), evidenceCount: evidenceSummary.aggregateTakeCount, status: "inferred", applicability: applicability, aggregation: VAOContract.vaoVocabulary + "aggregation/harmonic-aligned-cosine", subjectId: instrumentID),
                    ],
                    qualityFlags: collection.notes
                ))
            } else {
                paradata.append(VAOParadata(
                    id: activityID,
                    activityType: VAOContract.vaoVocabulary + "activity/LegacyCollectionAcousticalAnalysis",
                    startedAt: collection.analyzedAt,
                    endedAt: collection.analyzedAt,
                    software: VAOSoftware(name: "OrgRec", version: collection.contractVersion, uri: "https://modavis.org/orgrec", build: nil),
                    inputIds: resolvedInputs,
                    outputIds: [analysisID],
                    parameters: [:],
                    notes: "Legacy collection-analysis projection retained without a VAO 0.2.2 collection-diagnostics capability claim. " + collection.notes.joined(separator: " ")
                ))
                analyses.append(VAOAnalysis(
                    id: analysisID,
                    analysisType: VAOContract.vaoVocabulary + "analysis/collection-tuning",
                    method: "Legacy OrgRec collection-tuning summary",
                    version: collection.contractVersion,
                    generatedAt: collection.analyzedAt,
                    inputIds: resolvedInputs,
                    outputIds: [],
                    paradataId: activityID,
                    observations: [],
                    qualityFlags: collection.notes
                ))
            }
        }

        for annotation in project.annotations {
            let id = "urn:uuid:\(annotation.id.uuidString.lowercased())"
            entities.append(VAOEntity(
                id: id,
                kind: "annotation",
                types: [VAOContract.annotationType],
                labels: ["und": annotation.text.isEmpty ? annotation.code : annotation.text],
                properties: [
                    VAOContract.vaoNamespace + "timeSeconds": .number(annotation.atSeconds),
                    VAOContract.vaoNamespace + "code": .string(annotation.code),
                    VAOContract.vaoNamespace + "severity": .string(annotation.severity),
                    VAOContract.vaoNamespace + "createdAt": .string(iso8601(annotation.createdAt)),
                ]
            ))
            if let takeID = takeEntityIDs[annotation.takeID] {
                relations.append(VAORelation(subjectId: id, predicate: VAOContract.vaoNamespace + "annotates", objectId: takeID, status: "accepted"))
            }
        }

        for built in builtAssets {
            for subjectID in built.asset.aboutEntityIds {
                relations.append(VAORelation(subjectId: subjectID, predicate: VAOContract.hasRepresentation, objectId: built.asset.id, status: "asserted"))
            }
        }

        paradata.append(VAOParadata(
            id: stableURN(kind: "activity", value: "\(vaoID)|package-export"),
            activityType: VAOContract.modavisProvenance + "PackagingActivity",
            startedAt: now,
            endedAt: now,
            actorIds: nil,
            software: VAOSoftware(name: OrgRecSoftware.name, version: OrgRecSoftware.version, uri: "https://modavis.org/orgrec", build: OrgRecSoftware.build),
            inputIds: builtAssets.map(\.asset.id),
            outputIds: [],
            parameters: [
                VAOContract.vaoNamespace + "formatVersion": .string(VAOContract.formatVersion),
                VAOContract.vaoNamespace + "compressionMethod": .string("ZIP stored / ZIP64 when required"),
                VAOContract.vaoNamespace + "hashAlgorithm": .string("sha256"),
            ],
            notes: "Created a new immutable exchange package; the source OrgRec project was not modified."
        ))

        for index in paradata.indices {
            paradata[index].software = VAOSoftware(
                name: OrgRecSoftware.name,
                version: OrgRecSoftware.version,
                uri: "https://modavis.org/orgrec",
                build: OrgRecSoftware.build
            )
            paradata[index].parameters[VAOContract.vaoNamespace + "softwareVersion"] = .string(OrgRecSoftware.version)
            paradata[index].parameters[VAOContract.vaoNamespace + "softwareBuild"] = .string(OrgRecSoftware.build)
        }

        var researchCapabilities = [
            VAOContract.vaoVocabulary + "capability/paradata",
            VAOContract.vaoVocabulary + "capability/analysis",
        ]
        if !analyses.isEmpty { researchCapabilities.append(VAOContract.acousticalAnalysisCapability) }
        if project.takes.contains(where: { $0.longTakeSource != nil }) { researchCapabilities.append(VAOContract.sourceSegmentationCapability) }
        if hasTuningMap { researchCapabilities.append(VAOContract.tuningMapCapability) }
        if (project.timbreAnalyses ?? []).contains(where: { $0.empiricalClassification != nil }) {
            researchCapabilities.append(VAOContract.empiricalTimbreClassificationCapability)
        }
        if (project.timbreAnalyses ?? []).contains(where: { $0.pitchDependentFingerprint?.points.isEmpty == false }) {
            researchCapabilities.append(VAOContract.pitchDependentRankFingerprintCapability)
        }
        if hasCollectionAcousticDiagnostics {
            researchCapabilities.append(VAOContract.collectionAcousticDiagnosticsCapability)
        }
        var profiles = [
            VAOProfile(id: VAOContract.coreProfile, requiredCapabilities: [
                VAOContract.vaoVocabulary + "capability/core-graph",
                VAOContract.vaoVocabulary + "capability/fixity",
            ]),
            VAOProfile(id: VAOContract.researchProfile, requiredCapabilities: researchCapabilities),
            VAOProfile(id: VAOContract.orgRecProfile, requiredCapabilities: [
                VAOContract.vaoVocabulary + "capability/audio",
                VAOContract.vaoVocabulary + "capability/preservation",
            ]),
        ]
        if !playableComponents.isEmpty || hasPlayableLoopSets {
            var playableCapabilities = [
                VAOContract.vaoVocabulary + "capability/playable-interaction",
                VAOContract.vaoVocabulary + "capability/performance-control",
            ]
            if hasPlayableLoopSets { playableCapabilities.append(VAOContract.vaoVocabulary + "capability/sample-looping") }
            if hasSampledPlaybackParameters { playableCapabilities.append(VAOContract.sampledInstrumentPlaybackCapability) }
            profiles.append(VAOProfile(id: VAOContract.playableProfile, requiredCapabilities: playableCapabilities))
        }
        let rightsText = (project.recordingSessions ?? [])
            .map(\.rightsStatement)
            .last(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            ?? "Rights information has not been supplied; no permission is inferred."
        let licenseURL = project.organCharacteristics?.sourceURLs?.first(where: {
            $0.lowercased().contains("creativecommons.org/licenses/")
        })
        let sourceSession = (project.recordingSessions ?? []).last(where: {
            !$0.operatorName.isEmpty && !$0.operatorName.lowercased().contains("unknown")
        })
        let rightsHolderID = sourceSession.flatMap { actorIDs[$0.id] }
        let creditLine = sourceSession.map { "Source sample set and recordings: \($0.operatorName)" }
        var manifest = VAOManifest(
            schema: VAOContract.schemaURI,
            context: [VAOContract.contextURI],
            type: "VirtualAcousticObject",
            formatVersion: VAOContract.formatVersion,
            id: vaoID,
            revision: retainedPackage.map { $0.manifest.revision + 1 } ?? 1,
            createdAt: retainedPackage?.manifest.createdAt ?? project.createdAt,
            modifiedAt: now,
            title: ["und": project.title],
            description: ["en": "OrgRec capture exchange package for \(project.organName)."],
            conformsTo: profiles.map(\.id),
            profiles: profiles,
            modavisBinding: VAOModavisBinding(
                ontologyIRI: "https://w3id.org/modavis/ontology",
                ontologyVersion: "0.1.0-dev",
                ontologyStatus: "development",
                schemaRelease: project.snapshot.release.requestedRelease,
                mappingVersion: "vao-modavis-mapping/0.2.2",
                navigatorSnapshotAssetId: navigatorAsset?.id,
                notes: "The MODAVIS ontology binding remains explicit because the development ontology is not namespace-frozen."
            ),
            primaryEntityId: instrumentID,
            focusEntityIds: [instrumentID],
            entities: uniqueEntities(entities),
            relations: relations,
            assets: builtAssets.map(\.asset),
            paradata: paradata,
            analyses: analyses,
            rights: [VAORights(
                appliesToIds: [vaoID],
                license: licenseURL,
                rightsHolderId: rightsHolderID,
                statement: ["und": rightsText],
                accessCondition: "See statement and per-source rights; no absent permission is inferred.",
                creditLine: creditLine
            )],
            integrity: VAOIntegrity(
                algorithm: "sha256",
                assetCount: builtAssets.count,
                totalPayloadBytes: builtAssets.reduce(0) { $0 + $1.asset.byteSize },
                payloadMerkleRoot: nil,
                signatureProfile: nil
            ),
            extensions: [
                VAOContract.vaoNamespace + "producer": .string("OrgRec"),
                VAOContract.vaoNamespace + "producerSoftware": .object([
                    "name": .string(OrgRecSoftware.name),
                    "version": .string(OrgRecSoftware.version),
                    "build": .string(OrgRecSoftware.build),
                    "identifier": .string(OrgRecSoftware.identifier),
                ]),
            ]
        )
        var preservedAssetSources: [(VAOAsset, URL)] = []
        var retainedExtractionDirectory: URL?
        if let retainedPackage {
            let merged = try mergeRetainedPackage(
                retainedPackage.manifest,
                into: manifest,
                generatedAssets: builtAssets.map(\.asset),
                assetIDMap: retainedAssetIDMap,
                excludedSourceRelativePath: project.importedVAO?.sourceArchiveRelativePath
            )
            manifest = merged.manifest
            if !merged.preservedAssets.isEmpty {
                let extractionDirectory = fm.temporaryDirectory
                    .appendingPathComponent("OrgRec-VAO-preserved-\(UUID().uuidString)", isDirectory: true)
                try fm.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
                retainedExtractionDirectory = extractionDirectory
                let reader = try VAOArchiveReader(url: retainedPackage.url)
                for asset in merged.preservedAssets {
                    guard let entry = reader.entry(named: asset.path) else {
                        throw OrgRecError.exportValidation("Retained VAO asset is missing: \(asset.path)")
                    }
                    let extracted = extractionDirectory.appendingPathComponent(asset.path)
                    try reader.extract(entry, to: extracted, expectedSHA256: asset.sha256)
                    preservedAssetSources.append((asset, extracted))
                }
            }
        }
        defer {
            if let retainedExtractionDirectory { try? fm.removeItem(at: retainedExtractionDirectory) }
        }
        let manifestData = try OrgRecCoding.encoder.encode(manifest)
        var archiveEntries = [
            VAOArchiveEntrySource(path: "mimetype", data: Data(VAOContract.mediaType.utf8)),
            VAOArchiveEntrySource(path: VAOContract.manifestFilename, data: manifestData),
        ]
        archiveEntries.append(contentsOf: builtAssets
            .sorted { $0.asset.path < $1.asset.path }
            .map { VAOArchiveEntrySource(path: $0.asset.path, fileURL: $0.source) })
        archiveEntries.append(contentsOf: preservedAssetSources
            .sorted { $0.0.path < $1.0.path }
            .map { VAOArchiveEntrySource(path: $0.0.path, fileURL: $0.1) })
        try fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try VAOArchiveWriter.write(entries: archiveEntries, to: destinationURL)
        let report = try VAOPackageValidator.validate(packageURL: destinationURL)
        guard report.isValid else {
            try? fm.removeItem(at: destinationURL)
            throw OrgRecError.exportValidation("Created VAO failed validation: " + report.errors.prefix(3).joined(separator: "; "))
        }
        return destinationURL
    }

    private func retainedPackage(for project: OrgRecProject, at packageURL: URL) throws -> RetainedPackage? {
        guard let reference = project.importedVAO else { return nil }
        guard isSafePackageRelativePath(reference.sourceArchiveRelativePath),
              reference.sourceArchiveRelativePath.hasPrefix("Manifests/ImportedVAO/"),
              reference.sourceArchiveRelativePath.hasSuffix("/source.vao") else {
            throw OrgRecError.exportValidation("The retained VAO source path is unsafe.")
        }
        let source = packageURL.appendingPathComponent(reference.sourceArchiveRelativePath)
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw OrgRecError.exportValidation("The retained VAO source revision is missing; refusing a lossy round trip.")
        }
        guard try sha256(of: source) == reference.packageSHA256 else {
            throw OrgRecError.exportValidation("The retained VAO source revision failed its recorded checksum.")
        }
        let report = try VAOPackageValidator.validate(packageURL: source)
        guard report.isValid else {
            throw OrgRecError.exportValidation("The retained VAO source revision is invalid: " + report.errors.prefix(3).joined(separator: "; "))
        }
        let manifest = try VAOPackageValidator.manifest(packageURL: source)
        guard manifest.id == reference.packageId,
              manifest.revision == reference.revision,
              manifest.formatVersion == reference.formatVersion else {
            throw OrgRecError.exportValidation("The retained VAO source identity does not match project.json.")
        }
        return RetainedPackage(url: source, manifest: manifest)
    }

    private func mergeRetainedPackage(
        _ original: VAOManifest,
        into generated: VAOManifest,
        generatedAssets: [VAOAsset],
        assetIDMap: [String: String],
        excludedSourceRelativePath: String?
    ) throws -> RetainedMerge {
        var result = generated
        result.id = original.id
        result.revision = original.revision + 1
        result.createdAt = original.createdAt
        result.formatVersion = VAOContract.formatVersion
        result.conformsTo = Array(Set(original.conformsTo + generated.conformsTo)).sorted()

        var profilesByID = Dictionary(original.profiles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for profile in generated.profiles {
            if let previous = profilesByID[profile.id] {
                profilesByID[profile.id] = VAOProfile(
                    id: profile.id,
                    version: profile.version,
                    requiredCapabilities: Array(Set(previous.requiredCapabilities + profile.requiredCapabilities)).sorted()
                )
            } else {
                profilesByID[profile.id] = profile
            }
        }
        result.profiles = profilesByID.values.sorted { $0.id < $1.id }

        var binding = original.modavisBinding
        if binding.mappingVersion != generated.modavisBinding.mappingVersion {
            binding.mappingVersion = generated.modavisBinding.mappingVersion
            binding.mappingIRI = generated.modavisBinding.mappingIRI
            let migrationNote = "This rewritten package uses the current OrgRec-to-VAO projection; the retained source package remains checksum-preserved as migration evidence."
            binding.notes = [binding.notes, migrationNote].compactMap { $0 }.joined(separator: " ")
            if binding.ontologyStatus == "released" && binding.mappingIRI == nil {
                throw OrgRecError.exportValidation(
                    "A retained package bound to a released ontology cannot be rewritten with an unpinned current VAO mapping."
                )
            }
        }
        if let snapshot = generated.modavisBinding.navigatorSnapshotAssetId {
            binding.navigatorSnapshotAssetId = snapshot
        } else if let oldSnapshot = binding.navigatorSnapshotAssetId {
            binding.navigatorSnapshotAssetId = assetIDMap[oldSnapshot] ?? oldSnapshot
        }
        result.modavisBinding = binding
        result.entities = mergeRetainedEntities(original.entities, generated.entities)

        let remappedRelations = original.relations.map { relation -> VAORelation in
            var relation = relation
            relation.subjectId = assetIDMap[relation.subjectId] ?? relation.subjectId
            if let object = relation.objectId { relation.objectId = assetIDMap[object] ?? object }
            relation.evidenceIds = relation.evidenceIds?.map { assetIDMap[$0] ?? $0 }
            relation.generatedByIds = relation.generatedByIds?.map { assetIDMap[$0] ?? $0 }
            return relation
        }
        result.relations = mergeRetainedRelations(remappedRelations, generated.relations)

        let generatedPaths = Set(generatedAssets.map(\.path))
        let excludedArchivePath = excludedSourceRelativePath.map { "payload/orgrec/\($0)" }
        let preservedAssets = original.assets.filter {
            !generatedPaths.contains($0.path) && $0.path != excludedArchivePath
        }
        let generatedIDs = Set(generatedAssets.map(\.id))
        if let collision = preservedAssets.first(where: { generatedIDs.contains($0.id) }) {
            throw OrgRecError.exportValidation("Retained VAO asset identifier collides with a new project asset: \(collision.id)")
        }
        result.assets = (generatedAssets + preservedAssets).sorted { $0.path < $1.path }

        let remappedParadata = original.paradata.map { record -> VAOParadata in
            var record = record
            record.inputIds = record.inputIds.map { assetIDMap[$0] ?? $0 }
            record.outputIds = record.outputIds.map { assetIDMap[$0] ?? $0 }
            return record
        }
        result.paradata = mergeByID(remappedParadata, generated.paradata, id: \.id)
        let remappedAnalyses = original.analyses.map { analysis -> VAOAnalysis in
            var analysis = analysis
            analysis.inputIds = analysis.inputIds.map { assetIDMap[$0] ?? $0 }
            analysis.outputIds = analysis.outputIds.map { assetIDMap[$0] ?? $0 }
            return analysis
        }
        result.analyses = mergeByID(remappedAnalyses, generated.analyses, id: \.id)

        let remappedRights = original.rights.map { rights -> VAORights in
            var rights = rights
            rights.appliesToIds = rights.appliesToIds.map { assetIDMap[$0] ?? $0 }
            return rights
        }
        result.rights = remappedRights
        for rights in generated.rights where !result.rights.contains(rights) { result.rights.append(rights) }
        result.extensions = (original.extensions ?? [:]).merging(generated.extensions ?? [:]) { _, new in new }
        result.integrity = VAOIntegrity(
            assetCount: result.assets.count,
            totalPayloadBytes: result.assets.reduce(Int64(0)) { $0 + $1.byteSize }
        )
        return RetainedMerge(manifest: result, preservedAssets: preservedAssets)
    }

    private func mergeByID<T>(_ original: [T], _ generated: [T], id: KeyPath<T, String>) -> [T] {
        var values = Dictionary(original.map { ($0[keyPath: id], $0) }, uniquingKeysWith: { first, _ in first })
        for value in generated { values[value[keyPath: id]] = value }
        return values.values.sorted { $0[keyPath: id] < $1[keyPath: id] }
    }

    private func mergeRetainedEntities(_ original: [VAOEntity], _ generated: [VAOEntity]) -> [VAOEntity] {
        var values = Dictionary(original.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for var entity in generated {
            if let retained = values[entity.id] {
                entity.types = Array(Set(retained.types + entity.types)).sorted()
                entity.labels = retained.labels.merging(entity.labels) { _, new in new }
                entity.classifications = mergeUnique(retained.classifications, entity.classifications)
                entity.externalIdentifiers = mergeUnique(retained.externalIdentifiers, entity.externalIdentifiers)
                entity.properties = (retained.properties ?? [:]).merging(entity.properties ?? [:]) { _, new in new }
            }
            values[entity.id] = entity
        }
        return values.values.sorted { $0.id < $1.id }
    }

    private func mergeRetainedRelations(_ original: [VAORelation], _ generated: [VAORelation]) -> [VAORelation] {
        var values = Dictionary(original.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for var relation in generated {
            if let retained = values[relation.id] {
                relation.confidence = relation.confidence ?? retained.confidence
                relation.scope = relation.scope ?? retained.scope
                relation.evidenceIds = mergeUnique(retained.evidenceIds, relation.evidenceIds)
                relation.generatedByIds = mergeUnique(retained.generatedByIds, relation.generatedByIds)
                relation.properties = (retained.properties ?? [:]).merging(relation.properties ?? [:]) { _, new in new }
            }
            values[relation.id] = relation
        }
        return values.values.sorted { $0.id < $1.id }
    }

    private func mergeUnique<T: Equatable>(_ original: [T]?, _ generated: [T]?) -> [T]? {
        var result = original ?? []
        for value in generated ?? [] where !result.contains(value) { result.append(value) }
        return result.isEmpty ? nil : result
    }

    private func packageFiles(at root: URL) throws -> [(url: URL, relativePath: String)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey, .isHiddenKey]
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        guard let enumerator = FileManager.default.enumerator(
            at: resolvedRoot,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            throw OrgRecError.exportValidation("Could not enumerate the OrgRec project package.")
        }
        var files: [(URL, String)] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            let resolvedPath = url.standardizedFileURL.path
            guard resolvedPath.hasPrefix(resolvedRoot.path + "/") else {
                throw OrgRecError.exportValidation("Project enumeration escaped the OrgRec package.")
            }
            let relative = String(resolvedPath.dropFirst(resolvedRoot.path.count + 1))
            if relative == "Exports" || relative.hasPrefix("Exports/") {
                enumerator.skipDescendants()
                continue
            }
            if relative.hasPrefix("Manifests/ImportedVAO/") && relative.hasSuffix("/source.vao") {
                continue
            }
            if values.isSymbolicLink == true {
                throw OrgRecError.exportValidation("OrgRec project contains a symbolic link, which VAO prohibits: \(relative)")
            }
            if values.isRegularFile == true, isSafePackageRelativePath(relative) {
                files.append((url, relative))
            }
        }
        return files.sorted { $0.1 < $1.1 }
    }

    private func assetSubjects(relativePath: String, project: OrgRecProject, instrumentID: String) -> [String] {
        var result = [instrumentID]
        let roadmapByID = Dictionary(project.roadmap.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for take in project.takes where take.relativeAudioPath == relativePath || relativePath.lowercased().contains(take.id.uuidString.lowercased()) {
            result.append("urn:uuid:\(take.id.uuidString.lowercased())")
            if let component = roadmapByID[take.roadmapItemID]?.component {
                result.append(stableURN(kind: "component", value: component.id))
            }
            if let sessionID = take.provenance?.sessionID,
               (project.recordingSessions ?? []).contains(where: { $0.id == sessionID }) {
                result.append("urn:uuid:\(sessionID.uuidString.lowercased())")
            }
        }
        for source in project.longTakeSources ?? [] where source.relativeAudioPath == relativePath {
            for takeID in source.generatedTakeIDs {
                result.append("urn:uuid:\(takeID.uuidString.lowercased())")
                if let take = project.takes.first(where: { $0.id == takeID }),
                   let component = roadmapByID[take.roadmapItemID]?.component {
                    result.append(stableURN(kind: "component", value: component.id))
                }
            }
        }
        for session in project.recordingSessions ?? []
        where session.capturePreflightReports?.contains(where: { $0.relativeAudioPath == relativePath }) == true {
            result.append("urn:uuid:\(session.id.uuidString.lowercased())")
        }
        return Array(Set(result)).sorted()
    }

    private func componentKind(_ component: OrganComponent) -> String {
        let kind = component.kind.lowercased()
        return kind.contains("rank") || kind.contains("division") ? "componentCollection" : "component"
    }

    private func componentType(_ component: OrganComponent) -> String {
        let kind = component.kind.lowercased()
        if kind.contains("stop") { return VAOContract.modavisOrgan + "OrganStop" }
        if kind.contains("rank") { return VAOContract.modavisOrgan + "OrganRank" }
        if kind.contains("pipe") || component.midiNote != nil { return VAOContract.modavisOrgan + "OrganPipe" }
        if kind.contains("keyboard") || kind.contains("manual") { return VAOContract.modavisOrgan + "OrganKeyboard" }
        if kind.contains("coupler") { return VAOContract.modavisOrgan + "OrganCoupler" }
        if kind.contains("division") { return VAOContract.modavisOrgan + "OrganDivision" }
        if kind.contains("accessory") || kind.contains("effect") { return VAOContract.modavisOrgan + "OrganAccessory" }
        return VAOContract.instrumentComponentType
    }

    private func mediaType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "wav": return "audio/wav"
        case "aif", "aiff": return "audio/aiff"
        case "flac": return "audio/flac"
        case "json": return "application/json"
        case "jsonld": return "application/ld+json"
        case "csv": return "text/csv"
        case "txt", "md", "organ": return "text/plain"
        case "html", "htm": return "text/html"
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "tif", "tiff": return "image/tiff"
        case "glb": return "model/gltf-binary"
        case "gltf": return "model/gltf+json"
        case "fbx": return "application/octet-stream"
        case "obj": return "model/obj"
        case "mid", "midi": return "audio/midi"
        case "imu": return "application/vnd.orgrec.interaction-sensor"
        case "mov": return "video/quicktime"
        case "mp4": return "video/mp4"
        default: return "application/octet-stream"
        }
    }

    private func encodingDescription(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "json", "jsonld", "md", "csv": "UTF-8"
        case "organ": textEncodingDescription(for: url)
        case "txt", "html", "htm": textEncodingDescription(for: url)
        case "wav": "WAVE/BWF or WAVE PCM as declared by capture metadata"
        case "imu": "OrgRec MPU-6050 packet-v1; 27-byte little-endian CRC-16-CCITT records"
        case "aif", "aiff": "AIFF PCM as declared by capture metadata"
        case "glb", "gltf": "glTF 2.x"
        default: nil
        }
    }

    private func assetRole(for relativePath: String) -> String {
        if relativePath == ProjectStore.projectFilename { return VAOContract.applicationStateRole }
        let extensionName = URL(fileURLWithPath: relativePath).pathExtension.lowercased()
        let losslessAudio = ["wav", "wave", "flac", "aif", "aiff", "caf"].contains(extensionName)
        if (relativePath.hasPrefix("Audio/Originals/") || relativePath.hasPrefix("Audio/Calibration/")), losslessAudio {
            return VAOContract.audioMasterRole
        }
        if relativePath.hasPrefix("Audio/LongTakes/"), losslessAudio { return VAOContract.sourceEvidenceRole }
        if relativePath.hasPrefix("Analysis/") { return VAOContract.analysisResultRole }
        if relativePath.hasPrefix("Sensors/Raw/") { return VAOContract.interactionSensorDataRole }
        if relativePath.hasPrefix("Sensors/Derived/") || relativePath.hasPrefix("Sensors/Decoded/") { return VAOContract.analysisResultRole }
        if relativePath.hasPrefix("Sensors/Calibration/") || relativePath.hasPrefix("Metadata/SensorCaptures/") { return VAOContract.paradataRole }
        if relativePath.hasSuffix("bwf.json") { return VAOContract.paradataRole }
        if relativePath.hasPrefix("Manifests/") { return VAOContract.sourceEvidenceRole }
        switch URL(fileURLWithPath: relativePath).pathExtension.lowercased() {
        case "glb", "gltf", "fbx", "obj", "ply", "stl", "usd", "usda", "usdc", "usdz":
            return VAOContract.threeDimensionalModelRole
        case "anim":
            return VAOContract.animationRole
        case "mid", "midi":
            return VAOContract.performanceControlRole
        case "mp3", "m4a", "aac", "ogg", "aif", "aiff":
            return VAOContract.audioDerivativeRole
        default:
            break
        }
        return VAOContract.sourceEvidenceRole
    }

    private func textEncodingDescription(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        if String(data: data, encoding: .utf8) != nil { return "UTF-8" }
        if String(data: data, encoding: .windowsCP1252) != nil { return "Windows-1252" }
        if String(data: data, encoding: .isoLatin1) != nil { return "ISO-8859-1" }
        return "Unknown text encoding"
    }

    private func representationStatus(for relativePath: String) -> String {
        let base = VAOContract.vaoVocabulary + "representation-status/"
        let role = assetRole(for: relativePath)
        if role == VAOContract.audioMasterRole { return base + "captured" }
        if role == VAOContract.interactionSensorDataRole { return base + "captured" }
        if role == VAOContract.analysisResultRole { return base + "inferred" }
        if role == VAOContract.audioDerivativeRole || role == VAOContract.threeDimensionalModelRole || role == VAOContract.spatialModelRole {
            return base + "processed"
        }
        return base + "authored"
    }

    private func stableURN(kind: String, value: String) -> String {
        "urn:vao:\(kind):\(Data(value.utf8).sha256Hex)"
    }

    private func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func appendObservation(
        _ observations: inout [VAOObservation],
        property: String,
        value: Double?,
        unit: String,
        uncertainty: Double? = nil,
        confidence: Double? = nil,
        subject: String
    ) {
        guard let value, value.isFinite else { return }
        observations.append(VAOObservation(
            property: VAOContract.vaoVocabulary + "analysis/" + property,
            value: .number(value),
            unit: unit,
            uncertainty: uncertainty,
            confidence: confidence,
            status: "inferred",
            applicability: "applicable",
            subjectId: subject,
            timeRange: nil
        ))
    }

    private func uniqueEntities(_ entities: [VAOEntity]) -> [VAOEntity] {
        var seen = Set<String>()
        return entities.filter { seen.insert($0.id).inserted }
    }
}

public enum VAOPackageValidator {
    public static func validate(packageURL: URL) throws -> VAOValidationReport {
        let reader = try VAOArchiveReader(url: packageURL)
        var errors: [String] = []
        var warnings: [String] = []
        guard reader.entries.first?.path == "mimetype" else {
            throw OrgRecError.invalidProject("VAO mimetype must be the first archive entry.")
        }
        guard let mimetypeEntry = reader.entry(named: "mimetype") else {
            throw OrgRecError.invalidProject("VAO has no mimetype entry.")
        }
        let mimetype = try reader.data(for: mimetypeEntry, maximumSize: 256)
        if mimetype != Data(VAOContract.mediaType.utf8) {
            errors.append("VAO mimetype content is invalid.")
        }
        guard let manifestEntry = reader.entry(named: VAOContract.manifestFilename) else {
            throw OrgRecError.invalidProject("VAO has no \(VAOContract.manifestFilename).")
        }
        let manifestData = try reader.data(for: manifestEntry, maximumSize: VAOArchiveReader.maximumManifestBytes)
        errors.append(contentsOf: VAOManifestSchemaValidator.validate(manifestData))
        let manifest: VAOManifest
        do {
            manifest = try OrgRecCoding.decoder.decode(VAOManifest.self, from: manifestData)
        } catch {
            throw OrgRecError.invalidProject("VAO manifest cannot be decoded: \(error.localizedDescription)")
        }
        let versionParts = manifest.formatVersion.split(separator: ".", omittingEmptySubsequences: false)
        if versionParts.count != 3 || versionParts[0] != "0" || versionParts[1] != "2" || Int(versionParts[2]) == nil {
            errors.append("Unsupported VAO format \(manifest.formatVersion); this implementation supports 0.2.x.")
        }
        if manifest.type != "VirtualAcousticObject" { errors.append("VAO manifest type is invalid.") }
        if manifest.schema != VAOContract.schemaURI { errors.append("VAO 0.2 requires schema URI \(VAOContract.schemaURI).") }
        if !manifest.context.contains(VAOContract.contextURI) { errors.append("VAO 0.2 manifest does not include the normative JSON-LD context.") }
        if !manifest.conformsTo.contains(VAOContract.coreProfile) || !manifest.profiles.contains(where: { $0.id == VAOContract.coreProfile }) {
            errors.append("VAO does not claim the core profile.")
        }
        let profileIDs = Set(manifest.profiles.map(\.id))
        let conformsTo = Set(manifest.conformsTo)
        if profileIDs.count != manifest.profiles.count {
            errors.append("VAO profile identifiers must be unique.")
        }
        for profile in manifest.profiles {
            if !conformsTo.contains(profile.id) {
                errors.append("Declared profile must also occur in conformsTo: \(profile.id)")
            }
            if VAOContract.standardProfiles.contains(profile.id), profile.version != "0.2" {
                errors.append("Standard VAO 0.2 profile must declare version 0.2: \(profile.id)")
            }
        }
        for claim in conformsTo.intersection(VAOContract.standardProfiles) where !profileIDs.contains(claim) {
            errors.append("conformsTo standard-profile claim has no matching profile record: \(claim)")
        }
        let declaredCapabilities = Set(manifest.profiles.flatMap(\.requiredCapabilities))
        for capability in VAOPackageReader.capabilityReports(for: manifest)
        where capability.processing == .unsupported {
            warnings.append("Unsupported required capability retained without interpretation: \(capability.capability)")
        }
        if declaredCapabilities.contains(VAOContract.empiricalTimbreClassificationCapability) {
            let records = manifest.analyses.filter {
                $0.analysisType == VAOContract.vaoVocabulary + "analysis/empirical-hierarchical-timbre-classification"
            }
            if records.isEmpty {
                errors.append("The empirical-timbre-classification capability requires a hierarchical classification analysis.")
            }
            let modelAssets = manifest.assets.filter { $0.roles.contains(VAOContract.machineLearningModelRole) }
            if modelAssets.isEmpty {
                errors.append("The empirical-timbre-classification capability requires an indexed machine-learning model asset.")
            }
            for record in records {
                guard let paradataID = record.paradataId,
                      let activity = manifest.paradata.first(where: { $0.id == paradataID }) else { continue }
                if activity.method?["methodType"]?.stringValue != "machine-learning-inference"
                    || activity.method?["representationStatus"]?.stringValue != "learned" {
                    errors.append("Empirical timbre analysis \(record.id) requires learned machine-learning-inference paradata.")
                }
                if Set(activity.inputIds).isDisjoint(with: modelAssets.map(\.id)) {
                    errors.append("Empirical timbre analysis \(record.id) does not identify its model asset as an input.")
                }
                guard let distribution = record.observations.first(where: {
                    $0.property == VAOContract.vaoVocabulary + "analysis/timbre/calibrated-family-distribution"
                })?.value.arrayValue else {
                    errors.append("Empirical timbre analysis \(record.id) has no calibrated family distribution.")
                    continue
                }
                let probabilities = distribution.compactMap { $0.objectValue?["calibratedProbability"]?.numberValue }
                let concepts = distribution.compactMap { $0.objectValue?["concept"]?.stringValue }
                let expectedConcepts = Set(["flute", "diapason", "string", "reed"].map {
                    VAOContract.vaoVocabulary + "timbre-family/\($0)"
                })
                if probabilities.count != 4 || Set(concepts) != expectedConcepts {
                    errors.append("Empirical timbre analysis \(record.id) must contain exactly the governed flute, diapason, string, and reed family probabilities.")
                } else if probabilities.contains(where: { !$0.isFinite || !(0...1).contains($0) })
                            || abs(probabilities.reduce(0, +) - 1) > 1e-6 {
                    errors.append("Empirical timbre analysis \(record.id) probabilities must be finite, lie in 0...1, and sum to one.")
                }
                guard let decision = record.observations.first(where: {
                    $0.property == VAOContract.vaoVocabulary + "analysis/timbre/classification-decision"
                })?.value.objectValue,
                      let abstained = decision["abstained"]?.booleanValue else {
                    errors.append("Empirical timbre analysis \(record.id) has no typed classification decision.")
                    continue
                }
                guard let outOfDistribution = decision["outOfDistribution"]?.booleanValue,
                      let distance = decision["outOfDistributionDistance"]?.numberValue,
                      distance.isFinite, distance >= 0 else {
                    errors.append("Empirical timbre analysis \(record.id) requires a typed non-negative OOD decision and distance.")
                    continue
                }
                _ = outOfDistribution
                if !abstained {
                    guard let selected = decision["selectedConcept"]?.stringValue,
                          expectedConcepts.contains(selected) else {
                        errors.append("Non-abstained empirical timbre analysis \(record.id) requires a selected governed family concept.")
                        continue
                    }
                }
            }
        }
        if declaredCapabilities.contains(VAOContract.pitchDependentRankFingerprintCapability) {
            let records = manifest.analyses.filter {
                $0.analysisType == VAOContract.vaoVocabulary + "analysis/pitch-dependent-rank-fingerprint"
            }
            if records.isEmpty {
                errors.append("The pitch-dependent-rank-fingerprint capability requires a rank-fingerprint analysis.")
            }
            for record in records {
                if let paradataID = record.paradataId,
                   let activity = manifest.paradata.first(where: { $0.id == paradataID }) {
                    if activity.method?["methodType"]?.stringValue != "metric-calculation" {
                        errors.append("Rank fingerprint \(record.id) requires metric-calculation paradata.")
                    }
                    let seed = activity.method?["randomSeed"]
                    if seed?.integerValue == nil && seed?.stringValue == nil {
                        errors.append("Rank fingerprint \(record.id) requires a typed deterministic random seed.")
                    }
                    let parameterHash = activity.parameters["parameterSHA256"]?.stringValue
                    if parameterHash?.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil {
                        errors.append("Rank fingerprint \(record.id) requires a lowercase SHA-256 parameter fingerprint.")
                    }
                } else {
                    errors.append("Rank fingerprint \(record.id) requires resolvable method paradata.")
                }
                guard let trajectory = record.observations.first(where: {
                    $0.property == VAOContract.vaoVocabulary + "analysis/timbre/pitch-trajectory"
                })?.value.arrayValue else {
                    errors.append("Rank fingerprint \(record.id) has no pitch trajectory.")
                    continue
                }
                let keys = trajectory.compactMap { $0.objectValue?["keyNumber"]?.integerValue }
                if keys.isEmpty || keys.count != trajectory.count || Set(keys).count != keys.count || keys != keys.sorted() {
                    errors.append("Rank fingerprint \(record.id) trajectory keys must be non-empty, typed, unique, and ascending.")
                }
                for point in trajectory {
                    guard let value = point.objectValue,
                          let centroid = value["normalizedSpectralCentroid"]?.numberValue, centroid.isFinite,
                          let slope = value["weightedAverageSlopeDBPerOctave"]?.numberValue, slope.isFinite,
                          value["relativePartialLevelsDB"]?.arrayValue != nil else {
                        errors.append("Rank fingerprint \(record.id) contains an incomplete or non-finite trajectory point.")
                        break
                    }
                }
                let adjacentPairs = Set(zip(keys, keys.dropFirst()).map { "\($0.0)|\($0.1)" })
                if let transitions = record.observations.first(where: {
                    $0.property == VAOContract.vaoVocabulary + "analysis/timbre/construction-transition-candidates"
                })?.value.arrayValue {
                    for transition in transitions {
                        guard let value = transition.objectValue,
                              let lower = value["lowerKeyNumber"]?.integerValue,
                              let upper = value["upperKeyNumber"]?.integerValue,
                              lower < upper,
                              let delta = value["bicImprovement"]?.numberValue, delta >= 0,
                              let p = value["familyWisePermutationPValue"]?.numberValue, (0...1).contains(p),
                              let effect = value["standardizedEffectSize"]?.numberValue, effect.isFinite, effect >= 0,
                              let strength = value["evidenceStrength"]?.stringValue, !strength.isEmpty,
                              let interpretation = value["interpretation"]?.stringValue, !interpretation.isEmpty,
                              adjacentPairs.contains("\(lower)|\(upper)") else {
                            errors.append("Rank fingerprint \(record.id) contains an invalid construction-transition candidate.")
                            continue
                        }
                    }
                } else {
                    errors.append("Rank fingerprint \(record.id) has no transition-candidate observation.")
                }
            }
        }
        if declaredCapabilities.contains(VAOContract.collectionAcousticDiagnosticsCapability) {
            let researchCapabilities = Set(
                manifest.profiles.first(where: { $0.id == VAOContract.researchProfile })?.requiredCapabilities ?? []
            )
            if !researchCapabilities.contains(VAOContract.collectionAcousticDiagnosticsCapability) {
                errors.append("The collection-acoustic-diagnostics capability must be declared by the research profile.")
            }
            if !researchCapabilities.contains(VAOContract.acousticalAnalysisCapability) {
                errors.append("The collection-acoustic-diagnostics capability requires acoustical-analysis in the research profile.")
            }
            let records = manifest.analyses.filter { $0.analysisType == VAOContract.collectionAcousticDiagnosticsAnalysis }
            if records.isEmpty {
                errors.append("The collection-acoustic-diagnostics capability requires an evidence-qualified collection analysis.")
            }
            let entityIDs = Set(manifest.entities.map(\.id))
            let requiredProperties: Set<String> = [
                VAOContract.collectionEvidenceSummaryProperty,
                VAOContract.collectionTakeEvidenceProperty,
                VAOContract.collectionRankCurveProperty,
                VAOContract.collectionRankStretchProperty,
                VAOContract.collectionSessionOffsetProperty,
                VAOContract.collectionSessionDriftProperty,
                VAOContract.collectionAnomalyProperty,
                VAOContract.collectionSimilarityProperty,
            ]
            for record in records {
                guard let paradataID = record.paradataId,
                      let activity = manifest.paradata.first(where: { $0.id == paradataID }) else {
                    errors.append("Collection diagnostics \(record.id) requires resolvable method paradata.")
                    continue
                }
                if activity.method?["methodType"]?.stringValue != "metric-calculation"
                    || activity.method?["representationStatus"]?.stringValue != "inferred" {
                    errors.append("Collection diagnostics \(record.id) requires inferred metric-calculation paradata.")
                }
                let parameterHashKey = VAOContract.vaoNamespace + "parameterSHA256"
                let parameterHash = activity.parameters[parameterHashKey]?.stringValue
                if parameterHash?.range(of: "^[0-9a-f]{64}$", options: .regularExpression) == nil {
                    errors.append("Collection diagnostics \(record.id) requires a lowercase SHA-256 parameter fingerprint.")
                }
                let requiredParameterKeys = [
                    "minimumAggregateQualityScore", "moderateQualityScore", "highQualityScore",
                    "minimumAnomalyGroupSize", "anomalyWarningScore", "anomalyCriticalScore",
                    "similarityThreshold", "minimumSimilarityHarmonics", "minimumDriftRepeatedTargets",
                    "maximumSimilarityCandidates", "minimumDriftPairComparisons", "minimumDriftSpanHours",
                ].map { VAOContract.vaoNamespace + $0 }
                if requiredParameterKeys.contains(where: { activity.parameters[$0] == nil }) {
                    errors.append("Collection diagnostics \(record.id) has an incomplete parameter set.")
                }
                let parameter = { (name: String) in
                    activity.parameters[VAOContract.vaoNamespace + name]?.numberValue
                }
                let integerParameter = { (name: String) in
                    activity.parameters[VAOContract.vaoNamespace + name]?.integerValue
                }
                guard let minimumQuality = parameter("minimumAggregateQualityScore"), minimumQuality.isFinite,
                      let moderateQuality = parameter("moderateQualityScore"), moderateQuality.isFinite,
                      let highQuality = parameter("highQualityScore"), highQuality.isFinite,
                      0...1 ~= minimumQuality, 0...1 ~= moderateQuality, 0...1 ~= highQuality,
                      minimumQuality <= moderateQuality, moderateQuality <= highQuality,
                      let anomalyGroup = integerParameter("minimumAnomalyGroupSize"), anomalyGroup >= 3,
                      let warningScore = parameter("anomalyWarningScore"), warningScore.isFinite, warningScore > 0,
                      let criticalScore = parameter("anomalyCriticalScore"), criticalScore.isFinite, criticalScore >= warningScore,
                      let similarityThreshold = parameter("similarityThreshold"), similarityThreshold.isFinite, 0...1 ~= similarityThreshold,
                      let similarityHarmonics = integerParameter("minimumSimilarityHarmonics"), similarityHarmonics >= 3,
                      let maximumCandidates = integerParameter("maximumSimilarityCandidates"), maximumCandidates > 0,
                      let repeatedTargets = integerParameter("minimumDriftRepeatedTargets"), repeatedTargets > 0,
                      let pairComparisons = integerParameter("minimumDriftPairComparisons"), pairComparisons > 0,
                      let driftSpan = parameter("minimumDriftSpanHours"), driftSpan.isFinite, driftSpan >= 0 else {
                    errors.append("Collection diagnostics \(record.id) has invalid parameter values.")
                    continue
                }
                let observationProperties = record.observations.map(\.property)
                if Set(observationProperties) != requiredProperties || Set(observationProperties).count != observationProperties.count {
                    errors.append("Collection diagnostics \(record.id) must contain each governed observation exactly once.")
                    continue
                }
                let observationByProperty = Dictionary(uniqueKeysWithValues: record.observations.map { ($0.property, $0) })
                let expectedAggregations: [String: String] = [
                    VAOContract.collectionRankCurveProperty: VAOContract.vaoVocabulary + "aggregation/quality-weighted-median",
                    VAOContract.collectionRankStretchProperty: VAOContract.vaoVocabulary + "aggregation/siegel-repeated-median",
                    VAOContract.collectionSessionOffsetProperty: VAOContract.vaoVocabulary + "aggregation/median",
                    VAOContract.collectionSessionDriftProperty: VAOContract.vaoVocabulary + "aggregation/within-target-median-slope",
                    VAOContract.collectionAnomalyProperty: VAOContract.vaoVocabulary + "aggregation/robust-multivariate-distance",
                    VAOContract.collectionSimilarityProperty: VAOContract.vaoVocabulary + "aggregation/harmonic-aligned-cosine",
                ]
                if record.observations.contains(where: { $0.status != "inferred" })
                    || expectedAggregations.contains(where: { observationByProperty[$0.key]?.aggregation != $0.value }) {
                    errors.append("Collection diagnostics \(record.id) uses invalid status or aggregation semantics.")
                }
                let observationSubjects = Set(record.observations.compactMap(\.subjectId))
                if observationSubjects.count != 1 || record.observations.contains(where: { $0.subjectId == nil })
                    || !observationSubjects.allSatisfy(entityIDs.contains) {
                    errors.append("Collection diagnostics \(record.id) observations must share one resolved subject.")
                }
                if observationByProperty[VAOContract.collectionRankCurveProperty]?.unit != VAOContract.vaoVocabulary + "unit/cent"
                    || observationByProperty[VAOContract.collectionRankStretchProperty]?.unit != VAOContract.vaoVocabulary + "unit/cent-per-octave"
                    || observationByProperty[VAOContract.collectionSessionOffsetProperty]?.unit != VAOContract.vaoVocabulary + "unit/cent"
                    || observationByProperty[VAOContract.collectionSessionDriftProperty]?.unit != VAOContract.vaoVocabulary + "unit/cent-per-hour" {
                    errors.append("Collection diagnostics \(record.id) uses an invalid governed unit.")
                }
                guard let summary = observationByProperty[VAOContract.collectionEvidenceSummaryProperty]?.value.objectValue,
                      let eligible = summary["eligibleTakeCount"]?.integerValue,
                      let analyzed = summary["analyzedTakeCount"]?.integerValue,
                      let aggregate = summary["aggregateTakeCount"]?.integerValue,
                      let high = summary["highQualityCount"]?.integerValue,
                      let moderate = summary["moderateQualityCount"]?.integerValue,
                      let limited = summary["limitedQualityCount"]?.integerValue,
                      let excluded = summary["excludedCount"]?.integerValue,
                      let coverage = summary["aggregateCoverage"]?.numberValue,
                      eligible >= 0, analyzed >= 0, aggregate >= 0, high >= 0, moderate >= 0, limited >= 0, excluded >= 0,
                      analyzed <= eligible, aggregate <= analyzed,
                      high + moderate + limited == aggregate,
                      high + moderate + limited + excluded == eligible,
                      coverage.isFinite, (0...1).contains(coverage),
                      (eligible == 0 ? coverage == 0 : abs(coverage - Double(aggregate) / Double(eligible)) <= 1e-9) else {
                    errors.append("Collection diagnostics \(record.id) has an inconsistent evidence summary.")
                    continue
                }
                guard let ledger = observationByProperty[VAOContract.collectionTakeEvidenceProperty]?.value.arrayValue,
                      ledger.count == Int(eligible) else {
                    errors.append("Collection diagnostics \(record.id) evidence ledger does not match its eligible count.")
                    continue
                }
                var ledgerTakeIDs = Set<String>()
                for entryValue in ledger {
                    guard let entry = entryValue.objectValue,
                          let takeID = entry["takeId"]?.stringValue, entityIDs.contains(takeID), ledgerTakeIDs.insert(takeID).inserted,
                          let rankID = entry["rankGroupId"]?.stringValue, entityIDs.contains(rankID),
                          let key = entry["keyNumber"]?.integerValue, (0...127).contains(key),
                          let quality = entry["qualityScore"]?.numberValue, quality.isFinite, (0...1).contains(quality),
                          let tier = entry["tier"]?.stringValue, ["high", "moderate", "limited", "excluded"].contains(tier),
                          let included = entry["includedInAggregates"]?.booleanValue, included == (tier != "excluded") else {
                        errors.append("Collection diagnostics \(record.id) has an invalid or duplicate take-evidence entry.")
                        break
                    }
                }
                if ledgerTakeIDs != Set(record.inputIds) {
                    errors.append("Collection diagnostics \(record.id) inputs must equal its assessed take ledger.")
                }
                if ledgerTakeIDs != Set(activity.inputIds) || !activity.outputIds.contains(record.id) {
                    errors.append("Collection diagnostics \(record.id) paradata lineage must use the assessed ledger and generate the analysis.")
                }
                guard let curves = observationByProperty[VAOContract.collectionRankCurveProperty]?.value.arrayValue else {
                    errors.append("Collection diagnostics \(record.id) rank curves must be an array.")
                    continue
                }
                do {
                    var rankIDs = Set<String>()
                    for curveValue in curves {
                        guard let curve = curveValue.objectValue,
                              let rankID = curve["rankGroupId"]?.stringValue, entityIDs.contains(rankID), rankIDs.insert(rankID).inserted,
                              let grouping = curve["groupingBasis"]?.stringValue, !grouping.isEmpty,
                              let points = curve["points"]?.arrayValue, !points.isEmpty else {
                            errors.append("Collection diagnostics \(record.id) has an invalid or duplicate rank curve.")
                            continue
                        }
                        var priorKey: Int64?
                        for pointValue in points {
                            guard let point = pointValue.objectValue,
                                  let key = point["keyNumber"]?.integerValue, (0...127).contains(key), priorKey.map({ key > $0 }) ?? true,
                                  let median = point["medianDeviationCents"]?.numberValue, median.isFinite,
                                  let mad = point["medianAbsoluteDeviationCents"]?.numberValue, mad.isFinite, mad >= 0,
                                  let count = point["evidenceCount"]?.integerValue, count > 0 else {
                                errors.append("Collection diagnostics \(record.id) rank keys must be ascending and carry finite non-negative evidence.")
                                break
                            }
                            priorKey = key
                        }
                    }
                }
                guard let stretches = observationByProperty[VAOContract.collectionRankStretchProperty]?.value.arrayValue else {
                    errors.append("Collection diagnostics \(record.id) rank stretches must be an array.")
                    continue
                }
                var stretchRankIDs = Set<String>()
                for stretchValue in stretches {
                    guard let stretch = stretchValue.objectValue,
                          let rankID = stretch["rankGroupId"]?.stringValue, entityIDs.contains(rankID), stretchRankIDs.insert(rankID).inserted,
                          let value = stretch["stretchCentsPerOctave"]?.numberValue, value.isFinite,
                          let method = stretch["method"]?.stringValue, !method.isEmpty,
                          let count = stretch["evidenceCount"]?.integerValue, count > 0 else {
                        errors.append("Collection diagnostics \(record.id) has an invalid or duplicate rank-stretch entry.")
                        break
                    }
                }
                guard let offsets = observationByProperty[VAOContract.collectionSessionOffsetProperty]?.value.arrayValue else {
                    errors.append("Collection diagnostics \(record.id) session offsets must be an array.")
                    continue
                }
                var offsetSessionIDs = Set<String>()
                for offsetValue in offsets {
                    guard let offset = offsetValue.objectValue,
                          let sessionID = offset["sessionId"]?.stringValue, entityIDs.contains(sessionID), offsetSessionIDs.insert(sessionID).inserted,
                          let value = offset["medianDeviationCents"]?.numberValue, value.isFinite,
                          let count = offset["evidenceCount"]?.integerValue, count > 0 else {
                        errors.append("Collection diagnostics \(record.id) has an invalid or duplicate session-offset entry.")
                        break
                    }
                }
                guard let drifts = observationByProperty[VAOContract.collectionSessionDriftProperty]?.value.arrayValue else {
                    errors.append("Collection diagnostics \(record.id) session drift must be an array.")
                    continue
                }
                do {
                    var sessionIDs = Set<String>()
                    for driftValue in drifts {
                        guard let drift = driftValue.objectValue,
                              let sessionID = drift["sessionId"]?.stringValue, entityIDs.contains(sessionID), sessionIDs.insert(sessionID).inserted,
                              let applicability = drift["applicability"]?.stringValue, ["applicable", "indeterminate"].contains(applicability),
                              let repeated = drift["repeatedTargetCount"]?.integerValue, repeated >= 0,
                              let comparisons = drift["pairComparisonCount"]?.integerValue, comparisons >= 0 else {
                            errors.append("Collection diagnostics \(record.id) has an invalid or duplicate session-drift entry.")
                            continue
                        }
                        if let value = drift["driftCentsPerHour"]?.numberValue {
                            let duration = drift["durationHours"]?.numberValue
                            if !value.isFinite || applicability != "applicable"
                                || repeated < repeatedTargets || comparisons < pairComparisons
                                || duration == nil || !duration!.isFinite || duration! < driftSpan {
                                errors.append("Collection diagnostics \(record.id) has a non-finite or inapplicable numeric session drift.")
                            }
                        } else if drift["driftCentsPerHour"] != .null || applicability != "indeterminate" {
                            errors.append("Collection diagnostics \(record.id) must encode insufficient session drift as null and indeterminate.")
                        }
                    }
                }
                guard let anomalies = observationByProperty[VAOContract.collectionAnomalyProperty]?.value.arrayValue else {
                    errors.append("Collection diagnostics \(record.id) anomalies must be an array.")
                    continue
                }
                do {
                    var takeIDs = Set<String>()
                    for candidateValue in anomalies {
                        guard let candidate = candidateValue.objectValue,
                              let takeID = candidate["takeId"]?.stringValue, ledgerTakeIDs.contains(takeID), takeIDs.insert(takeID).inserted,
                              let score = candidate["robustDistance"]?.numberValue, score.isFinite, score >= 0,
                              let quality = candidate["qualityScore"]?.numberValue, quality.isFinite, (0...1).contains(quality),
                              let severity = candidate["severity"]?.stringValue, ["warning", "critical"].contains(severity),
                              score >= warningScore,
                              severity == (score >= criticalScore ? "critical" : "warning") else {
                            errors.append("Collection diagnostics \(record.id) has an invalid or duplicate anomaly candidate.")
                            break
                        }
                    }
                }
                guard let similarities = observationByProperty[VAOContract.collectionSimilarityProperty]?.value.arrayValue else {
                    errors.append("Collection diagnostics \(record.id) similarities must be an array.")
                    continue
                }
                if similarities.count > Int(maximumCandidates) {
                    errors.append("Collection diagnostics \(record.id) exceeds its declared similarity-candidate cap.")
                }
                do {
                    var pairs = Set<String>()
                    for candidateValue in similarities {
                        guard let candidate = candidateValue.objectValue,
                              let first = candidate["firstTakeId"]?.stringValue, ledgerTakeIDs.contains(first),
                              let second = candidate["secondTakeId"]?.stringValue, ledgerTakeIDs.contains(second), first < second,
                              pairs.insert("\(first)|\(second)").inserted,
                              let similarity = candidate["cosineSimilarity"]?.numberValue, similarity.isFinite,
                              similarity >= similarityThreshold, similarity <= 1,
                              let count = candidate["sharedPartialCount"]?.integerValue, count >= similarityHarmonics,
                              let interpretation = candidate["interpretation"]?.stringValue,
                              interpretation.localizedCaseInsensitiveContains("candidate") else {
                            errors.append("Collection diagnostics \(record.id) has an invalid, duplicate, or identity-overstating similarity candidate.")
                            break
                        }
                    }
                }
            }
        }
        if profileIDs.contains(VAOContract.researchProfile), manifest.paradata.isEmpty {
            errors.append("The VAO research profile requires processing or capture paradata.")
        }
        let generatedOutputs = Set(manifest.paradata.flatMap(\.outputIds))
        if profileIDs.contains(VAOContract.researchProfile) {
            for analysis in manifest.analyses where analysis.paradataId == nil {
                errors.append("Research-profile analysis requires paradata: \(analysis.id)")
            }
            for asset in manifest.assets
            where !Set(asset.roles).isDisjoint(with: [VAOContract.analysisResultRole, VAOContract.audioDerivativeRole])
                && !generatedOutputs.contains(asset.id) {
                errors.append("Research-profile derivative asset is not a paradata output: \(asset.id)")
            }
        }
        if profileIDs.contains(VAOContract.orgRecProfile) {
            if !profileIDs.contains(VAOContract.researchProfile) {
                errors.append("The OrgRec capture profile requires the research profile.")
            }
            let projectAssets = manifest.assets.filter {
                $0.path == "payload/orgrec/\(ProjectStore.projectFilename)" && $0.roles.contains(VAOContract.applicationStateRole)
            }
            if projectAssets.count != 1 {
                errors.append("The OrgRec capture profile requires exactly one application-state project.json asset.")
            }
        }
        if profileIDs.contains(VAOContract.playableProfile) {
            let interactions = manifest.entities.filter { $0.kind == "interaction" }
            if interactions.isEmpty { errors.append("The playable profile requires an interaction entity.") }
            for interaction in interactions {
                let properties = interaction.properties ?? [:]
                for localName in ["interactionType", "controlProtocol", "controlDomain", "timingPolicy"]
                where properties[VAOContract.vaoNamespace + localName] == nil {
                    errors.append("Playable interaction \(interaction.id) is missing \(localName).")
                }
                if !manifest.relations.contains(where: {
                    $0.subjectId == interaction.id
                        && ($0.predicate == VAOContract.activates || $0.predicate == VAOContract.modulates)
                }) {
                    errors.append("Playable interaction has no activates/modulates relation: \(interaction.id)")
                }
            }
        }
        let loopPointSets = manifest.entities.filter { $0.kind == "loopPointSet" }
        let signalRegions = Dictionary(
            uniqueKeysWithValues: manifest.entities.filter { $0.kind == "signalRegion" }.map { ($0.id, $0) }
        )
        for set in loopPointSets {
            let properties = set.properties ?? [:]
            guard let rate = number(properties[VAOContract.modavisAudio + "sampleRate"]), rate > 0,
                  let totalFrames = integer(properties[VAOContract.modavisAudio + "totalFrames"]), totalFrames > 0,
                  case .string(let digest)? = properties[VAOContract.modavisAudio + "sourceAudioSHA256"],
                  digest.count == 64 else {
                errors.append("Loop point set has invalid source clock or fixity: \(set.id)")
                continue
            }
            let regionIDs = manifest.relations.filter {
                $0.subjectId == set.id && $0.predicate == VAOContract.hasLoopRegion
            }.compactMap(\.objectId)
            if regionIDs.count != 1 {
                errors.append("Loop point set must resolve exactly one sustain region: \(set.id)")
                continue
            }
            guard let region = regionIDs.first.flatMap({ signalRegions[$0] }) else {
                errors.append("Loop point set has an unresolved signal region: \(set.id)")
                continue
            }
            let regionProperties = region.properties ?? [:]
            let start = integer(regionProperties[VAOContract.modavisAudio + "startFrameInclusive"])
            let end = integer(regionProperties[VAOContract.modavisAudio + "endFrameExclusive"])
            let crossfade = integer(regionProperties[VAOContract.modavisAudio + "crossfadeFrames"])
            if start == nil || end == nil || crossfade == nil || start! < 0 || end! <= start! || end! > totalFrames || crossfade! < 0 || crossfade! * 2 >= end! - start! {
                errors.append("Signal loop region has invalid half-open frame coordinates: \(region.id)")
            }
            if case .string(let exitPolicy)? = regionProperties[VAOContract.modavisAudio + "exitPolicy"],
               exitPolicy != LoopExitPolicy.envelopeRelease.rawValue,
               integer(regionProperties[VAOContract.modavisAudio + "releaseStartFrame"]) == nil {
                errors.append("Signal loop region requires a recorded release start for its exit policy: \(region.id)")
            }
            if let relation = manifest.relations.first(where: { $0.subjectId == set.id && $0.predicate == VAOContract.appliesToSignal }),
               let assetID = relation.objectId,
               let asset = manifest.assets.first(where: { $0.id == assetID }), asset.sha256 != digest {
                errors.append("Loop point set source hash does not match its linked audio asset: \(set.id)")
            }
            if case .string("accepted")? = properties[VAOContract.modavisAudio + "status"] {
                let interactions = manifest.entities.filter { entity in
                    entity.kind == "interaction" && manifest.relations.contains {
                        $0.subjectId == entity.id && $0.predicate == VAOContract.usesLoopPointSet && $0.objectId == set.id
                    }
                }
                if interactions.isEmpty {
                    errors.append("Accepted loop point set has no playable interaction: \(set.id)")
                }
                for interaction in interactions where !manifest.relations.contains(where: {
                    $0.subjectId == interaction.id && $0.predicate == VAOContract.vaoNamespace + "usesSample"
                }) {
                    errors.append("Loop interaction has no usesSample relation: \(interaction.id)")
                }
            }
        }
        let activeTargets: (String, String) -> [String] = { subject, predicate in
            manifest.relations.filter {
                $0.subjectId == subject && $0.predicate == predicate && $0.status != "rejected" && $0.status != "superseded"
            }.compactMap(\.objectId)
        }
        let assetsByID = Dictionary(uniqueKeysWithValues: manifest.assets.map { ($0.id, $0) })
        let entitiesByID = Dictionary(uniqueKeysWithValues: manifest.entities.map { ($0.id, $0) })

        if declaredCapabilities.contains(VAOContract.sampledInstrumentPlaybackCapability) {
            if !profileIDs.contains(VAOContract.playableProfile) {
                errors.append("The sampled-instrument-playback capability requires the playable profile.")
            }
            let mappings = manifest.entities.filter {
                $0.kind == "parameterSet" && $0.types.contains(VAOContract.samplePlaybackParametersType)
            }
            if mappings.isEmpty { errors.append("The sampled-instrument-playback capability requires sample playback parameters.") }
            for mapping in mappings {
                let properties = mapping.properties ?? [:]
                guard let rootKey = integer(properties[VAOContract.modavisAudio + "rootKeyNumber"]),
                      let minimumKey = integer(properties[VAOContract.modavisAudio + "minimumKeyNumber"]),
                      let maximumKey = integer(properties[VAOContract.modavisAudio + "maximumKeyNumber"]),
                      let minimumVelocity = integer(properties[VAOContract.modavisAudio + "minimumVelocity"]),
                      let maximumVelocity = integer(properties[VAOContract.modavisAudio + "maximumVelocity"]),
                      let targetFrequency = number(properties[VAOContract.modavisAudio + "targetFrequencyHz"]),
                      number(properties[VAOContract.modavisAudio + "gainDB"]) != nil else {
                    errors.append("Sample playback parameters are missing numeric key, velocity, frequency, or gain values: \(mapping.id)")
                    continue
                }
                if !(0...127).contains(rootKey) || minimumKey < 0 || maximumKey > 127 || minimumKey > rootKey || rootKey > maximumKey {
                    errors.append("Sample playback parameters have an invalid key range: \(mapping.id)")
                }
                if minimumVelocity < 0 || maximumVelocity > 127 || minimumVelocity > maximumVelocity {
                    errors.append("Sample playback parameters have an invalid velocity range: \(mapping.id)")
                }
                if targetFrequency <= 0 { errors.append("Sample playback parameters require a positive target frequency: \(mapping.id)") }
                let pitchMode = properties[VAOContract.modavisAudio + "pitchTrackingMode"]?.stringValue
                if !["preserveRecordedPitch", "resampleToTarget", "disabled"].contains(pitchMode ?? "") {
                    errors.append("Sample playback parameters have an invalid pitch-tracking mode: \(mapping.id)")
                }
                if pitchMode == "resampleToTarget", (number(properties[VAOContract.modavisAudio + "sourceFundamentalHz"]) ?? 0) <= 0 {
                    errors.append("Sample playback parameters require a measured source fundamental for resampling: \(mapping.id)")
                }
                if let envelope = properties[VAOContract.modavisAudio + "envelope"]?.objectValue {
                    let attack = number(envelope["attackSeconds"]) ?? -1
                    let release = number(envelope["releaseSeconds"]) ?? -1
                    let sustain = number(envelope["sustainLevel"]) ?? -1
                    let curve = envelope["curve"]?.stringValue ?? ""
                    if attack < 0 || release < 0 || !(0...1).contains(sustain) || !["linear", "equalPower", "natural"].contains(curve) {
                        errors.append("Sample playback parameters have an invalid envelope: \(mapping.id)")
                    }
                } else {
                    errors.append("Sample playback parameters require an envelope: \(mapping.id)")
                }
                if !["reviewed", "accepted"].contains(properties[VAOContract.modavisAudio + "status"]?.stringValue ?? "") {
                    errors.append("Sample playback parameters must be reviewed or accepted for playable conformance: \(mapping.id)")
                }
                let interactions = manifest.entities.filter {
                    $0.kind == "interaction" && activeTargets($0.id, VAOContract.usesPlaybackParameters).contains(mapping.id)
                }
                if interactions.isEmpty { errors.append("Sample playback parameters are not used by a playable interaction: \(mapping.id)") }
                for interaction in interactions {
                    let samples = activeTargets(interaction.id, VAOContract.vaoNamespace + "usesSample")
                    if samples.count != 1 || assetsByID[samples[0]]?.mediaType.hasPrefix("audio/") != true {
                        errors.append("Sampled interaction must resolve exactly one audio sample: \(interaction.id)")
                    }
                }
            }
        }

        if declaredCapabilities.contains(VAOContract.tuningMapCapability) {
            let maps = manifest.entities.filter { $0.kind == "parameterSet" && $0.types.contains(VAOContract.tuningMapType) }
            if maps.isEmpty { errors.append("The tuning-map capability requires a tuning map entity.") }
            for map in maps {
                let properties = map.properties ?? [:]
                guard (number(properties[VAOContract.modavisAudio + "referenceA4Hz"]) ?? 0) > 0,
                      let referenceKey = integer(properties[VAOContract.modavisAudio + "referenceKeyNumber"]), (0...127).contains(referenceKey),
                      let entries = properties[VAOContract.modavisAudio + "tuningEntries"]?.arrayValue, !entries.isEmpty else {
                    errors.append("Tuning map has invalid reference data or no entries: \(map.id)")
                    continue
                }
                var keys = Set<Int64>()
                for entryValue in entries {
                    guard let entry = entryValue.objectValue,
                          let key = integer(entry["keyNumber"]), (0...127).contains(key), keys.insert(key).inserted,
                          (number(entry["targetFrequencyHz"]) ?? 0) > 0 else {
                        errors.append("Tuning map has an invalid or duplicate entry: \(map.id)")
                        break
                    }
                    if let component = entry["componentId"]?.stringValue, entitiesByID[component] == nil {
                        errors.append("Tuning map entry has an unresolved component: \(map.id)")
                    }
                }
                if !manifest.entities.contains(where: { entity in
                    activeTargets(entity.id, VAOContract.hasTuningMap).contains(map.id)
                        || activeTargets(entity.id, VAOContract.usesTuningMap).contains(map.id)
                }) {
                    errors.append("Tuning map is not linked to an instrument or interaction: \(map.id)")
                }
            }
        }

        if declaredCapabilities.contains(VAOContract.sourceSegmentationCapability) {
            let regions = manifest.entities.filter { $0.kind == "signalRegion" && $0.types.contains(VAOContract.sampleExtractionRegionType) }
            if regions.isEmpty { errors.append("The source-segmentation capability requires a sample extraction region.") }
            for region in regions {
                let properties = region.properties ?? [:]
                guard let start = integer(properties[VAOContract.modavisAudio + "startFrameInclusive"]), start >= 0,
                      let end = integer(properties[VAOContract.modavisAudio + "endFrameExclusive"]), end > start,
                      let total = integer(properties[VAOContract.modavisAudio + "totalFrames"]), end <= total,
                      (number(properties[VAOContract.modavisAudio + "sampleRate"]) ?? 0) > 0,
                      let digest = properties[VAOContract.modavisAudio + "sourceAudioSHA256"]?.stringValue,
                      digest.count == 64 else {
                    errors.append("Sample extraction region has invalid source coordinates or fixity: \(region.id)")
                    continue
                }
                let sources = activeTargets(region.id, VAOContract.appliesToSignal)
                if sources.count != 1 || assetsByID[sources[0]]?.sha256 != digest {
                    errors.append("Sample extraction region does not resolve its fixed source audio: \(region.id)")
                }
                if !manifest.relations.contains(where: {
                    $0.predicate == VAOContract.extractedFromRegion && $0.objectId == region.id && $0.status != "rejected" && $0.status != "superseded"
                }) {
                    errors.append("Sample extraction region has no derived sample or take: \(region.id)")
                }
            }
        }
        if declaredCapabilities.contains(VAOContract.acousticalAnalysisCapability), manifest.analyses.isEmpty {
            errors.append("The acoustical-analysis capability requires at least one analysis record.")
        }
        VAOAcousticsSemanticValidator.validate(manifest: manifest, profileIDs: profileIDs, errors: &errors, warnings: &warnings)
        VAOExperientialValidator.validate(manifest: manifest, errors: &errors, warnings: &warnings)
        if profileIDs.contains(VAOContract.preservationProfile) {
            for asset in manifest.assets {
                if asset.originalFilename?.isEmpty != false { errors.append("Preservation asset has no original filename: \(asset.id)") }
                if asset.createdAt == nil { errors.append("Preservation asset has no creation time: \(asset.id)") }
                if !Set(asset.roles).isDisjoint(with: [VAOContract.analysisResultRole, VAOContract.audioDerivativeRole])
                    && !generatedOutputs.contains(asset.id) {
                    errors.append("Preservation derivative asset is not a paradata output: \(asset.id)")
                }
            }
            for record in manifest.rights where record.accessCondition?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                errors.append("A preservation-profile rights record has no access condition.")
            }
        }
        if manifest.modavisBinding.ontologyIRI.isEmpty || manifest.modavisBinding.mappingVersion.isEmpty {
            errors.append("VAO has an incomplete MODAVIS binding.")
        }
        let registries: [[String]] = [
            manifest.entities.map(\.id), manifest.relations.map(\.id), manifest.assets.map(\.id),
            manifest.paradata.map(\.id), manifest.analyses.map(\.id),
            VAOAcousticsSemanticValidator.identifiers(in: manifest.acoustics),
        ]
        let identifiers = registries.flatMap { $0 }
        if Set(identifiers).count != identifiers.count { errors.append("VAO contains duplicate resource identifiers.") }
        let known = Set(identifiers)
        let entityIDs = Set(manifest.entities.map(\.id))
        guard manifest.entities.contains(where: { $0.id == manifest.primaryEntityId }) else {
            errors.append("VAO primary entity is unresolved.")
            return VAOValidationReport(contractVersion: manifest.formatVersion, checkedAt: .now, errors: errors, warnings: warnings, verifiedAssetCount: 0, verifiedPayloadBytes: 0)
        }
        if manifest.focusEntityIds.isEmpty || !manifest.focusEntityIds.contains(manifest.primaryEntityId) {
            errors.append("VAO focus entities must be non-empty and include the primary entity.")
        }
        for focus in manifest.focusEntityIds where !entityIDs.contains(focus) {
            errors.append("VAO focus entity is unresolved: \(focus)")
        }
        if manifest.assets.isEmpty { errors.append("VAO core profile requires at least one asset.") }
        if manifest.rights.isEmpty || !manifest.rights.contains(where: { $0.appliesToIds.contains(manifest.id) }) {
            errors.append("VAO has no rights statement applying to the package.")
        }
        if manifest.integrity.algorithm != "sha256" { errors.append("VAO 0.2 requires SHA-256 fixity.") }
        if manifest.integrity.assetCount != manifest.assets.count { errors.append("VAO asset count is inconsistent.") }
        let declaredBytes = manifest.assets.reduce(Int64(0)) { $0 + $1.byteSize }
        if manifest.integrity.totalPayloadBytes != declaredBytes { errors.append("VAO total payload byte count is inconsistent.") }

        let payloadEntries = reader.entries.filter { !$0.isDirectory && $0.path.hasPrefix("payload/") }
        let payloadPaths = Set(payloadEntries.map(\.path))
        let assetPaths = Set(manifest.assets.map(\.path))
        if payloadPaths != assetPaths {
            for path in assetPaths.subtracting(payloadPaths).sorted() { errors.append("Indexed VAO asset is missing: \(path)") }
            for path in payloadPaths.subtracting(assetPaths).sorted() { errors.append("VAO payload is not indexed: \(path)") }
        }
        let allowedStructural = Set(["mimetype", VAOContract.manifestFilename])
        for entry in reader.entries where !entry.isDirectory && !entry.path.hasPrefix("payload/") && !entry.path.hasPrefix("META-INF/") && !allowedStructural.contains(entry.path) {
            errors.append("Unknown VAO root entry: \(entry.path)")
        }
        var verifiedAssets = 0
        var verifiedBytes: Int64 = 0
        for asset in manifest.assets {
            guard isSafeVAOPayloadPath(asset.path) else {
                errors.append("Unsafe VAO asset path: \(asset.path)")
                continue
            }
            if asset.roles.isEmpty { errors.append("VAO asset has no role: \(asset.id)") }
            for subject in asset.aboutEntityIds where !entityIDs.contains(subject) {
                errors.append("VAO asset \(asset.id) has unresolved subject \(subject).")
            }
            guard let entry = reader.entry(named: asset.path) else { continue }
            if entry.uncompressedSize != UInt64(asset.byteSize) { errors.append("VAO ZIP and manifest sizes differ: \(asset.path)") }
            do {
                let result = try reader.sha256(for: entry)
                verifiedBytes += result.size
                if result.digest == asset.sha256, result.size == asset.byteSize {
                    verifiedAssets += 1
                } else {
                    errors.append("VAO asset fixity failed: \(asset.path)")
                }
            } catch {
                errors.append(error.localizedDescription)
            }
        }
        for relation in manifest.relations {
            if !known.contains(relation.subjectId) { errors.append("VAO relation has unresolved subject: \(relation.id)") }
            if (relation.objectId == nil) == (relation.literal == nil) { errors.append("VAO relation must have exactly one object: \(relation.id)") }
            for reference in (relation.evidenceIds ?? []) + (relation.generatedByIds ?? []) where !known.contains(reference) {
                errors.append("VAO relation \(relation.id) has unresolved local reference \(reference).")
            }
            if let confidence = relation.confidence, !(0...1).contains(confidence) { errors.append("VAO relation confidence is outside 0...1: \(relation.id)") }
            if let scope = relation.scope, let start = scope.validFrom, let end = scope.validUntil, end < start {
                errors.append("VAO relation has an inverted validity interval: \(relation.id)")
            }
        }
        for activity in manifest.paradata {
            for reference in activity.inputIds + activity.outputIds where !known.contains(reference) {
                errors.append("VAO paradata \(activity.id) has unresolved reference \(reference).")
            }
            for actor in activity.actorIds ?? [] where !entityIDs.contains(actor) {
                errors.append("VAO paradata \(activity.id) has unresolved actor \(actor).")
            }
            if let end = activity.endedAt, end < activity.startedAt { errors.append("VAO paradata has an inverted time interval: \(activity.id)") }
        }
        for analysis in manifest.analyses {
            for reference in analysis.inputIds + analysis.outputIds where !known.contains(reference) {
                errors.append("VAO analysis \(analysis.id) has unresolved reference \(reference).")
            }
            if let activity = analysis.paradataId, !known.contains(activity) { errors.append("VAO analysis has unresolved paradata: \(analysis.id)") }
            for observation in analysis.observations {
                if observation.unit == "http://qudt.org/vocab/unit/Centi" || observation.unit == "https://qudt.org/vocab/unit/Centi" {
                    errors.append("VAO observation uses QUDT Centi, which is not a cent unit: \(analysis.id)")
                }
                if let confidence = observation.confidence, !(0...1).contains(confidence) { errors.append("VAO observation confidence is outside 0...1: \(analysis.id)") }
                if let coverage = observation.coverage, !(0...1).contains(coverage) { errors.append("VAO observation coverage is outside 0...1: \(analysis.id)") }
                for reference in [observation.subjectId, observation.sourceRegionId, observation.valueAssetId].compactMap({ $0 }) where !known.contains(reference) {
                    errors.append("VAO observation has an unresolved local reference \(reference): \(analysis.id)")
                }
                if let region = observation.sourceRegionId, entitiesByID[region]?.kind != "signalRegion" {
                    errors.append("VAO observation sourceRegionId is not a signal region: \(analysis.id)")
                }
                if let asset = observation.valueAssetId, assetsByID[asset] == nil {
                    errors.append("VAO observation valueAssetId is not an indexed asset: \(analysis.id)")
                }
                if let channels = observation.channelIndices,
                   channels.isEmpty || Set(channels).count != channels.count || channels.contains(where: { $0 < 0 }) {
                    errors.append("VAO observation has invalid channel indices: \(analysis.id)")
                }
                if let range = observation.timeRange, range.endSeconds < range.startSeconds { errors.append("VAO observation has an inverted time range: \(analysis.id)") }
                if let range = observation.timeRange, range.startFrameInclusive != nil {
                    guard let start = range.startFrameInclusive, let end = range.endFrameExclusive, end > start,
                          let rate = range.sampleRate, rate > 0,
                          let clock = range.clockAssetId, assetsByID[clock] != nil else {
                        errors.append("VAO observation has an invalid exact-frame clock: \(analysis.id)")
                        continue
                    }
                }
            }
        }
        var folded: [String: String] = [:]
        for path in assetPaths {
            if let other = folded[path.lowercased()], other != path {
                let message = "VAO paths collide when case-folded: \(other), \(path)"
                if profileIDs.contains(VAOContract.preservationProfile) {
                    errors.append(message)
                } else {
                    warnings.append(message)
                }
            } else {
                folded[path.lowercased()] = path
            }
        }
        return VAOValidationReport(
            contractVersion: manifest.formatVersion,
            checkedAt: .now,
            errors: errors,
            warnings: warnings,
            verifiedAssetCount: verifiedAssets,
            verifiedPayloadBytes: verifiedBytes
        )
    }

    static func manifest(packageURL: URL) throws -> VAOManifest {
        let reader = try VAOArchiveReader(url: packageURL)
        guard let entry = reader.entry(named: VAOContract.manifestFilename) else {
            throw OrgRecError.invalidProject("VAO has no manifest.")
        }
        return try OrgRecCoding.decoder.decode(
            VAOManifest.self,
            from: reader.data(for: entry, maximumSize: VAOArchiveReader.maximumManifestBytes)
        )
    }

    private static func isSafeVAOPayloadPath(_ path: String) -> Bool {
        guard path.hasPrefix("payload/"), !path.hasPrefix("/"), !path.contains("\\"), !path.contains("\0") else { return false }
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        return components.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func integer(_ value: VAOJSONValue?) -> Int64? {
        if case .integer(let result)? = value { return result }
        return nil
    }

    private static func number(_ value: VAOJSONValue?) -> Double? {
        switch value {
        case .number(let result)?: return result
        case .integer(let result)?: return Double(result)
        default: return nil
        }
    }
}

public actor VAOPackageImporter {
    public init() {}

    public func importPackage(from source: URL, to destination: URL) async throws -> OrgRecProject {
        let report = try VAOPackageValidator.validate(packageURL: source)
        guard report.isValid else {
            throw OrgRecError.invalidProject("VAO validation failed: " + report.errors.prefix(3).joined(separator: "; "))
        }
        let manifest = try VAOPackageValidator.manifest(packageURL: source)
        guard manifest.profiles.contains(where: { $0.id == VAOContract.orgRecProfile }) else {
            throw OrgRecError.invalidProject("This VAO is valid but does not carry the OrgRec capture profile. Use VAOM for instrument-neutral editing.")
        }
        guard let projectAsset = manifest.assets.first(where: {
            $0.path == "payload/orgrec/\(ProjectStore.projectFilename)" && $0.roles.contains(VAOContract.applicationStateRole)
        }) else {
            throw OrgRecError.invalidProject("The OrgRec VAO has no lossless project.json asset.")
        }
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path) else {
            throw OrgRecError.invalidProject("The VAO import destination already exists.")
        }
        let reader = try VAOArchiveReader(url: source)
        do {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            for asset in manifest.assets where asset.path.hasPrefix("payload/orgrec/") {
                let relative = String(asset.path.dropFirst("payload/orgrec/".count))
                guard isSafePackageRelativePath(relative), !relative.isEmpty else {
                    throw OrgRecError.invalidProject("The OrgRec VAO contains an unsafe project path.")
                }
                guard let entry = reader.entry(named: asset.path) else {
                    throw OrgRecError.invalidProject("The OrgRec VAO is missing \(asset.path).")
                }
                try reader.extract(entry, to: destination.appendingPathComponent(relative), expectedSHA256: asset.sha256)
            }
            guard fm.fileExists(atPath: destination.appendingPathComponent(projectAsset.path.split(separator: "/").last.map(String.init) ?? "").path) else {
                throw OrgRecError.invalidProject("The OrgRec VAO did not restore project.json.")
            }
            var project = try await ProjectStore().load(from: destination)
            let expectedRoot = "urn:uuid:\(project.id.uuidString.lowercased())"
            guard manifest.primaryEntityId == expectedRoot else {
                throw OrgRecError.invalidProject("The VAO primary instrument and OrgRec project identity differ.")
            }
            let auditDirectory = destination
                .appendingPathComponent("Manifests/ImportedVAO", isDirectory: true)
                .appendingPathComponent(Data(manifest.id.utf8).sha256Hex, isDirectory: true)
            try fm.createDirectory(at: auditDirectory, withIntermediateDirectories: true)
            try OrgRecCoding.encoder.encode(manifest).write(
                to: auditDirectory.appendingPathComponent(VAOContract.manifestFilename),
                options: .atomic
            )
            try OrgRecCoding.encoder.encode(report).write(
                to: auditDirectory.appendingPathComponent("validation.json"),
                options: .atomic
            )
            let retainedSource = auditDirectory.appendingPathComponent("source.vao")
            if fm.fileExists(atPath: retainedSource.path) {
                try fm.removeItem(at: retainedSource)
            }
            try fm.copyItem(at: source, to: retainedSource)
            let relativeSource = String(retainedSource.standardizedFileURL.path.dropFirst(destination.standardizedFileURL.path.count + 1))
            project.importedVAO = ImportedVAOReference(
                packageId: manifest.id,
                revision: manifest.revision,
                formatVersion: manifest.formatVersion,
                packageSHA256: try sha256(of: source),
                sourceArchiveRelativePath: relativeSource
            )
            try await ProjectStore().save(project, at: destination)
            return project
        } catch {
            try? fm.removeItem(at: destination)
            throw error
        }
    }
}
