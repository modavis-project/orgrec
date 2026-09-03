import AVFAudio
import Foundation

public struct GrandOrgueDivisionSummary: Codable, Hashable, Identifiable, Sendable {
    public var id: String { section }
    public var section: String
    public var name: String
    public var isPedal: Bool
    public var firstMIDINote: Int
    public var keyCount: Int
    public var stopCount: Int
}

public struct GrandOrgueStopSummary: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var division: String
    public var footHeight: String?
    public var sectionNames: [String]
    public var firstMIDINote: Int
    public var lastMIDINote: Int
    public var pipeCount: Int
    public var logicalPipeCount: Int?
    public var rankSectionNames: [String]?
}

public struct GrandOrgueControlSummary: Codable, Hashable, Identifiable, Sendable {
    public var id: String { section }
    public var section: String
    public var name: String
    public var type: String
    public var division: String?
    public var destinationDivision: String?
}

public struct GrandOrgueSampleRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var stopID: String
    public var stopName: String
    public var division: String
    public var footHeight: String?
    public var odfSection: String
    public var odfPipeKey: String
    public var odfValue: String
    public var midiNote: Int
    public var rankSection: String?
    public var rankName: String?
    public var sampleRole: String?
    public var variantIndex: Int?
    public var pitchTuningCents: Double?
    public var harmonicNumber: Double?
    public var amplitudeLevel: Double?
    public var gainDB: Double?
    public var loadsEmbeddedRelease: Bool?
    public var perspectiveLabel: String?
    public var sourceRelativePath: String?
    public var referenceTarget: String?
    public var sampleRate: Double?
    public var channelCount: Int?
    public var frameCount: Int64?
    public var fileSize: Int64?
    public var sha256: String?
    public var embeddedSamplerMetadata: WAVSamplerMetadata?
}

public struct GrandOrguePayloadFile: Codable, Hashable, Identifiable, Sendable {
    public var id: String { relativePath }
    public var relativePath: String
    public var fileSize: Int64
    public var sha256: String?
}

public struct GrandOrgueSampleSetInspection: Codable, Hashable, Sendable {
    public var contract: String
    public var sourceDirectory: String
    public var odfRelativePath: String
    public var odfEncoding: String
    public var odfSHA256: String
    public var organName: String
    public var venueName: String
    public var location: String
    public var builder: String?
    public var buildDateLabel: String?
    public var recordingDetails: String?
    public var sourcePageURL: String?
    public var licenseURL: String?
    public var licenseLabel: String?
    public var rightsHolder: String?
    public var divisions: [GrandOrgueDivisionSummary]
    public var stops: [GrandOrgueStopSummary]
    public var samples: [GrandOrgueSampleRecord]
    public var payloadFiles: [GrandOrguePayloadFile]
    public var controls: [GrandOrgueControlSummary]
    public var couplerCount: Int
    public var tremulantCount: Int
    public var warnings: [String]

    public init(
        contract: String = "orgrec.grandorgue-inspection/v1",
        sourceDirectory: String,
        odfRelativePath: String,
        odfEncoding: String,
        odfSHA256: String,
        organName: String,
        venueName: String,
        location: String,
        builder: String? = nil,
        buildDateLabel: String? = nil,
        recordingDetails: String? = nil,
        sourcePageURL: String? = nil,
        licenseURL: String? = nil,
        licenseLabel: String? = nil,
        rightsHolder: String? = nil,
        divisions: [GrandOrgueDivisionSummary],
        stops: [GrandOrgueStopSummary],
        samples: [GrandOrgueSampleRecord],
        payloadFiles: [GrandOrguePayloadFile],
        controls: [GrandOrgueControlSummary],
        couplerCount: Int,
        tremulantCount: Int,
        warnings: [String]
    ) {
        self.contract = contract
        self.sourceDirectory = sourceDirectory
        self.odfRelativePath = odfRelativePath
        self.odfEncoding = odfEncoding
        self.odfSHA256 = odfSHA256
        self.organName = organName
        self.venueName = venueName
        self.location = location
        self.builder = builder
        self.buildDateLabel = buildDateLabel
        self.recordingDetails = recordingDetails
        self.sourcePageURL = sourcePageURL
        self.licenseURL = licenseURL
        self.licenseLabel = licenseLabel
        self.rightsHolder = rightsHolder
        self.divisions = divisions
        self.stops = stops
        self.samples = samples
        self.payloadFiles = payloadFiles
        self.controls = controls
        self.couplerCount = couplerCount
        self.tremulantCount = tremulantCount
        self.warnings = warnings
    }

    public var referencedSampleCount: Int { samples.count }
    public var uniqueReferencedAudioCount: Int { Set(samples.compactMap(\.sourceRelativePath)).count }
    public var missingSampleCount: Int {
        samples.filter { $0.sourceRelativePath == nil && $0.sampleRole != "silence-control" }.count
    }
    public var totalPayloadBytes: Int64 { payloadFiles.reduce(0) { $0 + $1.fileSize } }
}

public struct GrandOrgueImportManifest: Codable, Hashable, Sendable {
    public var contract: String
    public var importedAt: Date
    public var sourceDirectoryName: String
    public var sourceDirectoryPathAtImport: String
    public var sourceMutationPolicy: String
    public var inspection: GrandOrgueSampleSetInspection

    public init(
        contract: String = "orgrec.grandorgue-import-manifest/v1",
        importedAt: Date = .now,
        sourceDirectoryName: String,
        sourceDirectoryPathAtImport: String,
        sourceMutationPolicy: String = "The GrandOrgue source was read-only. OrgRec copied the complete sample-set tree, preserved its relative layout, and verified every copied file with SHA-256.",
        inspection: GrandOrgueSampleSetInspection
    ) {
        self.contract = contract
        self.importedAt = importedAt
        self.sourceDirectoryName = sourceDirectoryName
        self.sourceDirectoryPathAtImport = sourceDirectoryPathAtImport
        self.sourceMutationPolicy = sourceMutationPolicy
        self.inspection = inspection
    }
}

public actor GrandOrgueSampleSetImporter {
    public static let manifestRelativePath = "Manifests/grandorgue-source.json"
    public static let sourcePayloadPrefix = "Audio/Originals/GrandOrgue"

    public init() {}

    public func inspect(odfURL: URL, sourcePageURL: String? = nil) throws -> GrandOrgueSampleSetInspection {
        let odf = odfURL.standardizedFileURL
        guard odf.pathExtension.lowercased() == "organ" else {
            throw OrgRecError.invalidProject("Choose a GrandOrgue .organ definition file.")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: odf.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw OrgRecError.invalidProject("GrandOrgue ODF does not exist: \(odf.path)")
        }
        let odfDirectory = odf.deletingLastPathComponent()
        let root = Self.packageRoot(containing: odf)
        let document = try ODFDocument(url: odf)
        guard let organ = document.sections["Organ"] else {
            throw OrgRecError.invalidProject("The ODF has no [Organ] section.")
        }

        var warnings: [String] = []
        let manuals = document.sectionOrder.filter { $0.hasPrefix("Manual") }.compactMap { section -> ManualDefinition? in
            guard let values = document.sections[section],
                  let first = Int(values["FirstAccessibleKeyMIDINoteNumber"] ?? ""),
                  let count = Int(values["NumberOfAccessibleKeys"] ?? "") else {
                warnings.append("\(section) has no usable MIDI compass and was skipped.")
                return nil
            }
            let name = clean(values["Name"]) ?? section
            let stopSlots = values
                .filter { $0.key.range(of: #"^Stop[0-9]{3}$"#, options: .regularExpression) != nil }
                .sorted { $0.key < $1.key }
            return ManualDefinition(
                section: section,
                name: name,
                firstMIDINote: first,
                keyCount: count,
                stopSlots: Dictionary(uniqueKeysWithValues: stopSlots)
            )
        }
        guard !manuals.isEmpty else {
            throw OrgRecError.invalidProject("The ODF contains no importable manual or pedal compass.")
        }

        let manualBySection = Dictionary(uniqueKeysWithValues: manuals.map { ($0.section, $0) })
        var stopToManual: [String: ManualDefinition] = [:]
        for manual in manuals {
            for target in manual.stopSlots.values {
                stopToManual["Stop\(target)"] = manual
            }
        }

        var rawStops: [RawStop] = []
        for section in document.sectionOrder where section.hasPrefix("Stop") {
            guard let values = document.sections[section], let manual = stopToManual[section] else { continue }
            let name = clean(values["Name"]) ?? section
            let firstKey = Int(values["FirstAccessiblePipeLogicalKeyNumber"] ?? "1") ?? 1
            let stopCount = Int(values["NumberOfAccessiblePipes"] ?? values["NumberOfLogicalPipes"] ?? "0") ?? 0
            let rankBindings = values
                .filter { $0.key.range(of: #"^Rank[0-9]{3}$"#, options: .regularExpression) != nil }
                .sorted { $0.key < $1.key }
            if !rankBindings.isEmpty {
                for (_, rankNumber) in rankBindings {
                    let rankSection = "Rank\(rankNumber)"
                    guard let rankValues = document.sections[rankSection] else {
                        warnings.append("\(section) (‘\(name)’) references missing [\(rankSection)].")
                        continue
                    }
                    let firstPipe = Int(rankValues["FirstAccessiblePipeLogicalPipeNumber"] ?? "1") ?? 1
                    let rankCount = Int(rankValues["NumberOfAccessiblePipes"] ?? rankValues["NumberOfLogicalPipes"] ?? "0") ?? 0
                    let count = stopCount > 0 && rankCount > 0 ? min(stopCount, rankCount) : max(stopCount, rankCount)
                    guard count > 0 else {
                        warnings.append("\(rankSection), bound by \(section), declares no accessible pipes.")
                        continue
                    }
                    let firstMIDINote = Int(rankValues["FirstMidiNoteNumber"] ?? "")
                        ?? (manual.firstMIDINote + firstKey - 1)
                    rawStops.append(RawStop(
                        section: rankSection,
                        sourceStopSection: section,
                        rankSection: rankSection,
                        rankName: clean(rankValues["Name"]) ?? rankSection,
                        name: name,
                        manual: manual,
                        firstKey: firstMIDINote - manual.firstMIDINote + 1,
                        firstMIDINote: firstMIDINote,
                        firstPipe: firstPipe,
                        count: count,
                        values: rankValues
                    ))
                }
                continue
            }
            let firstPipe = Int(values["FirstAccessiblePipeLogicalPipeNumber"] ?? "1") ?? 1
            guard stopCount > 0 else {
                warnings.append("\(section) (‘\(name)’) declares no accessible pipes.")
                continue
            }
            rawStops.append(RawStop(
                section: section,
                sourceStopSection: section,
                rankSection: nil,
                rankName: nil,
                name: name,
                manual: manual,
                firstKey: firstKey,
                firstMIDINote: manual.firstMIDINote + firstKey - 1,
                firstPipe: firstPipe,
                count: stopCount,
                values: values
            ))
        }

        let groupedStops = Self.groupStops(rawStops)
        var summaries: [GrandOrgueStopSummary] = []
        var samples: [GrandOrgueSampleRecord] = []
        var rawStopBySection: [String: RawStop] = [:]
        for raw in rawStops where rawStopBySection[raw.section] == nil {
            rawStopBySection[raw.section] = raw
        }
        for (groupIndex, group) in groupedStops.enumerated() {
            let stopID = "grandorgue:stop:\(slug(group.manual.section)):\(slug(group.name)):\(groupIndex + 1)"
            let foot = Self.footHeight(in: group.name)
            var groupSamples: [GrandOrgueSampleRecord] = []
            for raw in group.parts.sorted(by: { $0.firstKey < $1.firstKey }) {
                for offset in 0..<raw.count {
                    let pipeNumber = raw.firstPipe + offset
                    let baseKey = String(format: "Pipe%03d", pipeNumber)
                    let midi = raw.firstMIDINote + offset
                    for variant in Self.sampleVariants(pipeKey: baseKey, values: raw.values) {
                        let value = variant.value
                        let isIntentionalSilence = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DUMMY"
                        let resolved = isIntentionalSilence ? nil : Self.resolvePipe(
                            value: value,
                            currentSection: raw.section,
                            document: document,
                            manualBySection: manualBySection,
                            rawStopBySection: rawStopBySection,
                            visited: []
                        )
                        var relativePath: String?
                        var rate: Double?
                        var channels: Int?
                        var frames: Int64?
                        var size: Int64?
                        var samplerMetadata: WAVSamplerMetadata?
                        if isIntentionalSilence {
                            // GrandOrgue's DUMMY token is an intentional silent
                            // logical pipe, not a missing filesystem reference.
                        } else if let resolved,
                           let resolvedPath = Self.resolveSourcePath(resolved.path, relativeTo: odfDirectory, within: root) {
                            let audioURL = resolvedPath.url
                            let safe = resolvedPath.relativePath
                            var targetIsDirectory: ObjCBool = false
                            if FileManager.default.fileExists(atPath: audioURL.path, isDirectory: &targetIsDirectory), !targetIsDirectory.boolValue {
                                relativePath = safe
                                size = Int64((try audioURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
                                do {
                                    let audio = try AVAudioFile(forReading: audioURL)
                                    rate = audio.fileFormat.sampleRate
                                    channels = Int(audio.fileFormat.channelCount)
                                    frames = audio.length
                                } catch {
                                    warnings.append("\(raw.section).\(variant.key) points to audio ‘\(safe)’ that is not natively decodable by AVFoundation; its explicit ODF mapping is preserved for an external codec adapter: \(error.localizedDescription)")
                                }
                                do {
                                    samplerMetadata = try WAVSamplerMetadataReader.read(from: audioURL)
                                    for warning in samplerMetadata?.warnings ?? [] {
                                        warnings.append("\(raw.section).\(variant.key): \(warning)")
                                    }
                                } catch {
                                    warnings.append("\(raw.section).\(variant.key) has unreadable embedded WAVE sampler metadata: \(error.localizedDescription)")
                                }
                            } else {
                                warnings.append("\(raw.section).\(variant.key) points to missing audio ‘\(safe)’.")
                            }
                        } else if value.isEmpty {
                            warnings.append("\(raw.section).\(variant.key) is missing.")
                        } else {
                            warnings.append("\(raw.section).\(variant.key) escapes the selected package root or is unresolved: ‘\(value)’.")
                        }
                        groupSamples.append(GrandOrgueSampleRecord(
                            id: "\(stopID):midi:\(midi):\(raw.section):\(variant.key)",
                            stopID: stopID,
                            stopName: group.name,
                            division: group.manual.name,
                            footHeight: foot,
                            odfSection: raw.section,
                            odfPipeKey: variant.key,
                            odfValue: value,
                            midiNote: midi,
                            rankSection: raw.rankSection,
                            rankName: raw.rankName,
                            sampleRole: isIntentionalSilence ? "silence-control" : variant.role,
                            variantIndex: variant.index,
                            pitchTuningCents: Self.numericValue("\(baseKey)PitchTuning", values: raw.values, fallback: "PitchTuning"),
                            harmonicNumber: Self.numericValue("\(baseKey)HarmonicNumber", values: raw.values, fallback: "HarmonicNumber"),
                            amplitudeLevel: Self.numericValue("\(baseKey)AmplitudeLevel", values: raw.values, fallback: "AmplitudeLevel"),
                            gainDB: Self.numericValue("\(baseKey)Gain", values: raw.values, fallback: "Gain"),
                            loadsEmbeddedRelease: Self.booleanValue(raw.values["\(variant.key)LoadRelease"] ?? raw.values["\(baseKey)LoadRelease"]),
                            perspectiveLabel: Self.perspectiveLabel(in: resolved?.path),
                            sourceRelativePath: relativePath,
                            referenceTarget: resolved?.referenceTarget,
                            sampleRate: rate,
                            channelCount: channels,
                            frameCount: frames,
                            fileSize: size,
                            sha256: nil,
                            embeddedSamplerMetadata: samplerMetadata
                        ))
                    }
                }
            }
            let notes = groupSamples.map(\.midiNote)
            summaries.append(GrandOrgueStopSummary(
                id: stopID,
                name: group.name,
                division: group.manual.name,
                footHeight: foot,
                sectionNames: Array(Set(group.parts.map(\.sourceStopSection))).sorted(),
                firstMIDINote: notes.min() ?? group.manual.firstMIDINote,
                lastMIDINote: notes.max() ?? group.manual.firstMIDINote,
                pipeCount: groupSamples.count,
                logicalPipeCount: Set(groupSamples.map { "\($0.rankSection ?? $0.odfSection):\($0.midiNote)" }).count,
                rankSectionNames: Array(Set(group.parts.compactMap(\.rankSection))).sorted()
            ))
            samples.append(contentsOf: groupSamples)
        }

        let payload = try Self.payloadInventory(root: root, warnings: &warnings)
        let license = Self.detectLicense(organ: organ, root: root)
        if license.url == nil {
            warnings.append("No machine-readable sample-set license was found. Resolve rights before dissemination.")
        }
        let divisions = manuals.map { manual in
            GrandOrgueDivisionSummary(
                section: manual.section,
                name: manual.name,
                isPedal: manual.section == "Manual000" || manual.name.lowercased().contains("pedal"),
                firstMIDINote: manual.firstMIDINote,
                keyCount: manual.keyCount,
                stopCount: summaries.filter { $0.division == manual.name }.count
            )
        }
        let manualNameByNumber = Dictionary(uniqueKeysWithValues: manuals.map {
            (String($0.section.dropFirst("Manual".count)), $0.name)
        })
        var controlDivisionBySection: [String: String] = [:]
        for manual in manuals {
            guard let values = document.sections[manual.section] else { continue }
            for (key, target) in values where key.range(of: #"^(Coupler|Tremulant)[0-9]{3}$"#, options: .regularExpression) != nil {
                let prefix = key.hasPrefix("Coupler") ? "Coupler" : "Tremulant"
                controlDivisionBySection[prefix + target] = manual.name
            }
        }
        let controls = document.sectionOrder.compactMap { section -> GrandOrgueControlSummary? in
            let type: String
            if section.hasPrefix("Coupler") { type = "coupler" }
            else if section.hasPrefix("Tremulant") { type = "tremulant" }
            else { return nil }
            let values = document.sections[section] ?? [:]
            return GrandOrgueControlSummary(
                section: section,
                name: clean(values["Name"]) ?? section,
                type: type,
                division: controlDivisionBySection[section],
                destinationDivision: values["DestinationManual"].flatMap { manualNameByNumber[$0] }
            )
        }
        let location = clean(organ["ChurchAddress"]) ?? ""
        let displayedName = clean(organ["ChurchName"]) ?? odf.deletingPathExtension().lastPathComponent
        let venue = displayedName.replacingOccurrences(of: " (Original)", with: "", options: [.caseInsensitive])
        return GrandOrgueSampleSetInspection(
            sourceDirectory: root.path,
            odfRelativePath: Self.relativePath(of: odf, under: root) ?? odf.lastPathComponent,
            odfEncoding: document.encodingLabel,
            odfSHA256: try sha256(of: odf),
            organName: venue,
            venueName: venue,
            location: location,
            builder: clean(organ["OrganBuilder"]),
            buildDateLabel: clean(organ["OrganBuildDate"]),
            recordingDetails: clean(organ["RecordingDetails"]),
            sourcePageURL: clean(sourcePageURL),
            licenseURL: license.url,
            licenseLabel: license.label,
            rightsHolder: license.rightsHolder,
            divisions: divisions,
            stops: summaries,
            samples: samples,
            payloadFiles: payload,
            controls: controls,
            couplerCount: controls.filter { $0.type == "coupler" }.count,
            tremulantCount: controls.filter { $0.type == "tremulant" }.count,
            warnings: Array(Set(warnings)).sorted()
        )
    }

    public func importSampleSet(
        odfURL: URL,
        to destination: URL,
        sourcePageURL: String? = nil
    ) async throws -> OrgRecProject {
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw OrgRecError.invalidProject("Import destination already exists: \(destination.path)")
        }
        var inspection = try inspect(odfURL: odfURL, sourcePageURL: sourcePageURL)
        guard inspection.missingSampleCount == 0 else {
            throw OrgRecError.invalidProject("The selected ODF has \(inspection.missingSampleCount) missing or unreadable referenced samples.")
        }
        let root = URL(fileURLWithPath: inspection.sourceDirectory).standardizedFileURL
        var hashByPath: [String: String] = [:]
        for index in inspection.payloadFiles.indices {
            let file = root.appendingPathComponent(inspection.payloadFiles[index].relativePath)
            let digest = try sha256(of: file)
            inspection.payloadFiles[index].sha256 = digest
            hashByPath[inspection.payloadFiles[index].relativePath] = digest
        }
        for index in inspection.samples.indices {
            inspection.samples[index].sha256 = inspection.samples[index].sourceRelativePath.flatMap { hashByPath[$0] }
        }
        let manifest = GrandOrgueImportManifest(
            sourceDirectoryName: root.lastPathComponent,
            sourceDirectoryPathAtImport: root.path,
            inspection: inspection
        )
        let manifestData = try OrgRecCoding.encoder.encode(manifest)
        let project = Self.makeProject(inspection: inspection, snapshotHash: manifestData.sha256Hex)
        let payloadDestination = destination
            .appendingPathComponent(Self.sourcePayloadPrefix, isDirectory: true)
            .appendingPathComponent(root.lastPathComponent, isDirectory: true)
        do {
            try await ProjectStore().createPackage(at: destination, project: project)
            try manifestData.write(to: destination.appendingPathComponent(Self.manifestRelativePath), options: .atomic)
            try FileManager.default.createDirectory(at: payloadDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: root, to: payloadDestination)
            for file in inspection.payloadFiles {
                let copied = payloadDestination.appendingPathComponent(file.relativePath)
                guard try sha256(of: copied) == file.sha256 else {
                    throw OrgRecError.invalidProject("Checksum mismatch after copying \(file.relativePath).")
                }
            }
            _ = try await ProjectStore().load(from: destination)
            return project
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private static func makeProject(inspection: GrandOrgueSampleSetInspection, snapshotHash: String) -> OrgRecProject {
        let organID = "SOURCE:grandorgue:\(inspection.odfSHA256)"
        let sourceRecordID = "sr:grandorgue:odf-sha256:\(inspection.odfSHA256)"
        let snapshot = MODAVISSnapshot(
            endpoint: inspection.sourcePageURL ?? "grandorgue://odf/\(inspection.odfSHA256)",
            payloadSHA256: snapshotHash
        )
        let recipe = CaptureRecipe(
            name: "Imported GrandOrgue pipe samples",
            version: 1,
            techniques: [.closePair],
            preRollSeconds: 0,
            sustainSeconds: 0,
            releaseSeconds: 0
        )
        let importDate = Date()
        let rights = [inspection.licenseLabel, inspection.licenseURL].compactMap { $0 }.joined(separator: " · ")
        let session = RecordingSession(
            sessionCode: "GRANDORGUE-IMPORT-\(inspection.odfSHA256.prefix(12))",
            startedAt: importDate,
            endedAt: importDate,
            operatorName: inspection.rightsHolder ?? "Unknown source creator",
            institution: "",
            purpose: "GrandOrgue sample-set ingest",
            rightsStatement: rights.isEmpty ? "Unknown; resolve before dissemination" : rights,
            clockSource: "Not encoded by the GrandOrgue ODF",
            venueCondition: "Not encoded by the GrandOrgue ODF",
            notes: "This is the import activity. Source recording detail: \(inspection.recordingDetails ?? "not encoded")."
        )
        let rootName = URL(fileURLWithPath: inspection.sourceDirectory).lastPathComponent
        let prefix = "\(Self.sourcePayloadPrefix)/\(rootName)"
        var components: [OrganComponent] = []
        for division in inspection.divisions {
            let id = "\(organID):division:\(slug(division.section))"
            let locator = ComponentLocator(
                id: id,
                organMDVSID: organID,
                sourceRecordID: sourceRecordID,
                sourcePath: "\(inspection.odfRelativePath)#\(division.section)",
                snapshotSHA256: snapshotHash,
                kind: division.isPedal ? "pedalDivision" : "manualDivision",
                label: division.name,
                trust: .sourceBound
            )
            components.append(OrganComponent(
                id: id,
                kind: division.isPedal ? "pedalDivision" : "manualDivision",
                label: division.name,
                division: division.name,
                locator: locator,
                playableMIDILow: division.firstMIDINote,
                playableMIDIHigh: division.firstMIDINote + division.keyCount - 1,
                sourceDetails: ["odfSection": division.section, "semanticStatus": "asserted-by-grandorgue-odf"]
            ))
        }

        var stopComponents: [String: OrganComponent] = [:]
        var rankComponents: [String: OrganComponent] = [:]
        var registrations: [RegistrationState] = []
        var registrationByStop: [String: RegistrationState] = [:]
        for stop in inspection.stops {
            let id = "\(organID):\(stop.id)"
            let locator = ComponentLocator(
                id: id,
                organMDVSID: organID,
                sourceRecordID: sourceRecordID,
                sourcePath: "\(inspection.odfRelativePath)#\(stop.sectionNames.joined(separator: ","))",
                snapshotSHA256: snapshotHash,
                kind: "stop",
                label: stop.name,
                trust: .sourceBound
            )
            let stopComponent = OrganComponent(
                id: id,
                kind: "stop",
                label: stop.name,
                division: stop.division,
                footHeight: stop.footHeight,
                locator: locator,
                playableMIDILow: stop.firstMIDINote,
                playableMIDIHigh: stop.lastMIDINote,
                sourceDetails: [
                    "grandOrgueStopID": stop.id,
                    "odfSections": stop.sectionNames.joined(separator: ","),
                    "semanticStatus": "asserted-by-grandorgue-odf",
                ],
                referencePitchHz: 440,
                temperament: "Unknown; A4=440 Hz and 12-TET are analysis priors only"
            )
            components.append(stopComponent)
            stopComponents[stop.id] = stopComponent
            for rankSection in stop.rankSectionNames ?? [] {
                let rankID = "\(id):rank:\(slug(rankSection))"
                let rankLabel = inspection.samples.first {
                    $0.stopID == stop.id && $0.rankSection == rankSection
                }?.rankName ?? rankSection
                let rankLocator = ComponentLocator(
                    id: rankID,
                    organMDVSID: organID,
                    sourceRecordID: sourceRecordID,
                    sourcePath: "\(inspection.odfRelativePath)#\(rankSection)",
                    snapshotSHA256: snapshotHash,
                    kind: "rank",
                    label: rankLabel,
                    trust: .sourceBound
                )
                let rank = OrganComponent(
                    id: rankID,
                    kind: "rank",
                    label: rankLabel,
                    division: stop.division,
                    locator: rankLocator,
                    parentComponentID: stopComponent.id,
                    playableMIDILow: stop.firstMIDINote,
                    playableMIDIHigh: stop.lastMIDINote,
                    sourceDetails: [
                        "grandOrgueStopID": stop.id,
                        "odfRankSection": rankSection,
                        "semanticStatus": "asserted-by-grandorgue-odf",
                    ]
                )
                components.append(rank)
                rankComponents["\(stop.id)#\(rankSection)"] = rank
            }
            let registration = RegistrationState(
                activatedStops: [locator],
                notes: "Isolated ODF stop state; split bass/discant ODF sections are merged when contiguous.",
                name: "\(stop.division) · \(stop.name)",
                purpose: "GrandOrgue sample mapping"
            )
            registrations.append(registration)
            registrationByStop[stop.id] = registration
        }
        for control in inspection.controls {
            let id = "\(organID):grandorgue-control:\(slug(control.section))"
            let division = control.division ?? control.destinationDivision ?? "Organ"
            let locator = ComponentLocator(
                id: id,
                organMDVSID: organID,
                sourceRecordID: sourceRecordID,
                sourcePath: "\(inspection.odfRelativePath)#\(control.section)",
                snapshotSHA256: snapshotHash,
                kind: control.type,
                label: control.name,
                trust: .sourceBound
            )
            components.append(OrganComponent(
                id: id,
                kind: control.type,
                label: control.name,
                division: division,
                locator: locator,
                sourceDetails: [
                    "grandOrgueControlType": control.type,
                    "odfSection": control.section,
                    "destinationDivision": control.destinationDivision ?? "",
                    "semanticStatus": "asserted-by-grandorgue-odf",
                ]
            ))
        }

        var roadmap: [RoadmapItem] = []
        var takes: [TakeRecord] = []
        for sample in inspection.samples {
            guard let stop = stopComponents[sample.stopID],
                  let registration = registrationByStop[sample.stopID],
                  let relative = sample.sourceRelativePath else { continue }
            let pipeID = "\(stop.id):midi:\(sample.midiNote):\(slug(sample.odfSection)): \(sample.odfPipeKey)"
                .replacingOccurrences(of: " ", with: "")
            let harmonicRatio = sample.harmonicNumber.flatMap { $0 > 0 ? $0 / 8 : nil }
                ?? OrganFootage.nominalRatio(footHeight: sample.footHeight)
            let tuningRatio = pow(2, (sample.pitchTuningCents ?? 0) / 1_200)
            let expected = harmonicRatio.map {
                440 * pow(2, Double(sample.midiNote - 69) / 12) * $0 * tuningRatio
            }
            let parentComponent = sample.rankSection.flatMap { rankComponents["\(sample.stopID)#\($0)"] } ?? stop
            let locator = ComponentLocator(
                id: pipeID,
                organMDVSID: organID,
                pipePositionReference: "orgrec.grandorgue-pipe/v1?section=\(sample.odfSection)&pipe=\(sample.odfPipeKey)",
                sourceRecordID: sourceRecordID,
                sourcePath: "\(inspection.odfRelativePath)#\(sample.odfSection).\(sample.odfPipeKey)",
                snapshotSHA256: snapshotHash,
                kind: "pipePosition",
                label: "\(sample.stopName) · \(Self.noteName(sample.midiNote))",
                trust: .sourceBound
            )
            let frequencyStatus = expected == nil
                ? "unavailable-invalid-or-compound-footage"
                : (sample.harmonicNumber != nil || sample.pitchTuningCents != nil
                    ? "source-mapping-applied-over-assumed-A4"
                    : "analysis-prior-from-assumed-A4-and-stop-footage")
            let sampleDetails: [String: String] = [
                "grandOrgueStopID": sample.stopID,
                "odfSection": sample.odfSection,
                "odfPipeKey": sample.odfPipeKey,
                "odfValue": sample.odfValue,
                "resolvedSamplePath": relative,
                "referenceTarget": sample.referenceTarget ?? "direct",
                "sampleRole": sample.sampleRole ?? "attack-sustain",
                "variantIndex": String(sample.variantIndex ?? 0),
                "rankSection": sample.rankSection ?? "direct-stop",
                "rankName": sample.rankName ?? "",
                "pitchTuningCents": sample.pitchTuningCents.map { String($0) } ?? "",
                "harmonicNumber": sample.harmonicNumber.map { String($0) } ?? "",
                "amplitudeLevel": sample.amplitudeLevel.map { String($0) } ?? "",
                "gainDB": sample.gainDB.map { String($0) } ?? "",
                "loadsEmbeddedRelease": sample.loadsEmbeddedRelease.map { String($0) } ?? "unknown",
                "perspectiveLabel": sample.perspectiveLabel ?? "",
                "perspectiveStatus": sample.perspectiveLabel == nil ? "not-encoded" : "inferred-from-source-path-label",
                "embeddedWAVLoopCount": String(sample.embeddedSamplerMetadata?.loops.count ?? 0),
                "semanticStatus": "source-bound-grandorgue-mapping",
                "expectedFrequencyStatus": frequencyStatus,
            ]
            let component = OrganComponent(
                id: pipeID,
                kind: "pipePosition",
                label: locator.label,
                division: sample.division,
                footHeight: sample.footHeight,
                noteName: Self.noteName(sample.midiNote),
                midiNote: sample.midiNote,
                expectedFrequencyHz: expected,
                locator: locator,
                parentComponentID: parentComponent.id,
                sourceDetails: sampleDetails,
                referencePitchHz: 440,
                temperament: "Unknown; 12-TET is an analysis prior only"
            )
            components.append(component)
            let item = RoadmapItem(
                component: component,
                technique: .closePair,
                recipeID: recipe.id,
                registrationID: registration.id,
                state: .needsReview,
                coverageKind: .explicitPipe,
                instructions: "Imported from \(sample.odfSection).\(sample.odfPipeKey); verify pitch, loop/release semantics, and recording provenance."
            )
            let importedLoops = Self.importedLoopPointSets(for: sample)
            let take = TakeRecord(
                roadmapItemID: item.id,
                takeNumber: 1,
                status: .needsReview,
                startedAt: importDate,
                endedAt: importDate,
                relativeAudioPath: "\(prefix)/\(relative)",
                sampleRate: sample.sampleRate ?? 0,
                channelCount: sample.channelCount ?? 0,
                frameCount: sample.frameCount ?? 0,
                fileSize: sample.fileSize ?? 0,
                sha256: sample.sha256,
                captureDiagnostics: CaptureDiagnostics(
                    writerContract: "orgrec.grandorgue-import/v1",
                    container: "RIFF/WAVE",
                    encoding: "Source encoding preserved without transcoding",
                    bitDepth: 0,
                    queuedBufferCapacity: 0,
                    writtenFrames: sample.frameCount ?? 0,
                    channels: (1...(max(sample.channelCount ?? 1, 1))).map {
                        ChannelCaptureStatistics(channelIndex: $0, role: "GrandOrgue source channel \($0)")
                    }
                ),
                analysisReferenceChannel: 0,
                notes: "Bit-preserved GrandOrgue \(sample.sampleRole ?? "attack-sustain") source. ODF value: \(sample.odfValue). Embedded RIFF smpl loops remain source assertions pending playback review.",
                reviewReason: "The ODF mapping and embedded sampler metadata are explicit source assertions; acquisition setup, tuning reference, loop suitability, and temperament still require review.",
                provenance: TakeProvenanceSnapshot(
                    session: session,
                    recipe: recipe,
                    microphoneSetup: nil,
                    registration: registration,
                    component: component,
                    releaseBinding: snapshot.release,
                    navigatorPayloadSHA256: snapshotHash,
                    organMDVSID: organID,
                    applicationVersion: "\(OrgRecSoftware.current.displayName); grandorgue-importer/2"
                ),
                loopPointSets: importedLoops.isEmpty ? nil : importedLoops
            )
            var linked = item
            linked.takeIDs = [take.id]
            roadmap.append(linked)
            takes.append(take)
        }

        let sourceURLs = [inspection.sourcePageURL, inspection.licenseURL].compactMap { $0 }
        let compilation = RoadmapCompilationReport(
            compilerContract: "orgrec.grandorgue-roadmap-compiler/v1",
            sourceStopCount: inspection.stops.count,
            sourceCouplerCount: inspection.couplerCount,
            sourceAccessoryCount: inspection.tremulantCount,
            sourceDivisionCount: inspection.divisions.count,
            sourceKeyboardCount: inspection.divisions.count,
            sourceRankCount: Self.rankCount(in: inspection),
            explicitPipePositionCount: roadmap.count,
            generatedAtomicSoundCount: roadmap.count,
            generatedControlTestCount: 0,
            theoreticalRegistrationStateCount: String(inspection.stops.count),
            assumedCompassCount: 0,
            warnings: inspection.warnings + [
                "The complete self-contained GrandOrgue tree is preserved; the selected ODF controls the modeled disposition.",
                "A4=440 Hz and 12-TET are analysis priors, not source assertions.",
            ],
            referencePitchHz: 440,
            tuningPitchAssumed: true,
            temperament: "Unknown; 12-TET is an analysis prior only"
        )
        return OrgRecProject(
            title: "\(inspection.organName) · GrandOrgue",
            organMDVSID: organID,
            organName: inspection.organName,
            venueName: [inspection.venueName, inspection.location].filter { !$0.isEmpty }.joined(separator: ", "),
            snapshot: snapshot,
            recipe: recipe,
            registrations: registrations,
            roadmap: roadmap,
            takes: takes,
            spectrogramConfiguration: SpectrogramConfiguration(),
            organComponents: components,
            roadmapCompilation: compilation,
            navigatorPayloadRelativePath: Self.manifestRelativePath,
            organCharacteristics: OrganSpecificationCharacteristics(
                referencePitchHz: 440,
                temperament: "Unknown; 12-TET is an analysis prior only",
                manualCount: inspection.divisions.filter { !$0.isPedal }.count,
                documentedStopCount: inspection.stops.count,
                divisionCount: inspection.divisions.count,
                keyboardCount: inspection.divisions.count,
                rankCount: Self.rankCount(in: inspection),
                pipePositionCount: roadmap.count,
                couplerCount: inspection.couplerCount,
                accessoryCount: inspection.tremulantCount,
                builder: inspection.builder,
                buildDateLabel: inspection.buildDateLabel,
                sourceCount: sourceURLs.count,
                sourceURLs: sourceURLs
            ),
            recordingSessions: [session]
        )
    }

    private struct ManualDefinition {
        var section: String
        var name: String
        var firstMIDINote: Int
        var keyCount: Int
        var stopSlots: [String: String]
    }

    private struct RawStop {
        var section: String
        var sourceStopSection: String
        var rankSection: String?
        var rankName: String?
        var name: String
        var manual: ManualDefinition
        var firstKey: Int
        var firstMIDINote: Int
        var firstPipe: Int
        var count: Int
        var values: [String: String]
    }

    private struct StopGroup {
        var name: String
        var manual: ManualDefinition
        var parts: [RawStop]
    }

    private struct ResolvedPipe {
        var path: String
        var referenceTarget: String?
    }

    private struct SampleVariantDefinition {
        var key: String
        var value: String
        var role: String
        var index: Int
    }

    private struct ODFDocument {
        var sections: [String: [String: String]]
        var sectionOrder: [String]
        var encodingLabel: String

        init(url: URL) throws {
            let data = try Data(contentsOf: url)
            let decoded: (String, String)? = [
                (String.Encoding.utf8, "UTF-8"),
                (.windowsCP1252, "Windows-1252"),
                (.isoLatin1, "ISO-8859-1"),
                (.macOSRoman, "Mac OS Roman"),
            ].compactMap { encoding, label in
                String(data: data, encoding: encoding).map { ($0, label) }
            }.first
            guard let (text, label) = decoded else {
                throw OrgRecError.invalidProject("The ODF text encoding is unsupported.")
            }
            var result: [String: [String: String]] = [:]
            var order: [String] = []
            var current: String?
            for rawLine in text.components(separatedBy: .newlines) {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty, !line.hasPrefix(";") else { continue }
                if line.hasPrefix("["), line.hasSuffix("]") {
                    let section = String(line.dropFirst().dropLast())
                    current = section
                    if result[section] == nil { result[section] = [:]; order.append(section) }
                    continue
                }
                guard let current, let equals = line.firstIndex(of: "=") else { continue }
                let key = String(line[..<equals]).trimmingCharacters(in: .whitespaces)
                let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
                result[current, default: [:]][key] = value
            }
            sections = result
            sectionOrder = order
            encodingLabel = label
        }
    }

    private static func groupStops(_ stops: [RawStop]) -> [StopGroup] {
        var result: [StopGroup] = []
        for stop in stops.sorted(by: {
            if $0.manual.section != $1.manual.section { return $0.manual.section < $1.manual.section }
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.firstKey < $1.firstKey
        }) {
            let lastKey = stop.firstKey + stop.count - 1
            if let index = result.lastIndex(where: { group in
                guard group.manual.section == stop.manual.section,
                      group.name.caseInsensitiveCompare(stop.name) == .orderedSame else { return false }
                let ranges = group.parts.map { $0.firstKey...($0.firstKey + $0.count - 1) }
                return ranges.contains { $0.overlaps(stop.firstKey...lastKey) || $0.upperBound + 1 == stop.firstKey || lastKey + 1 == $0.lowerBound }
            }) {
                result[index].parts.append(stop)
            } else {
                result.append(StopGroup(name: stop.name, manual: stop.manual, parts: [stop]))
            }
        }
        return result
    }

    private static func resolvePipe(
        value: String,
        currentSection: String,
        document: ODFDocument,
        manualBySection: [String: ManualDefinition],
        rawStopBySection: [String: RawStop],
        visited: Set<String>
    ) -> ResolvedPipe? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.uppercased().hasPrefix("REF:") else { return ResolvedPipe(path: trimmed, referenceTarget: nil) }
        let parts = trimmed.split(separator: ":").map(String.init)
        guard parts.count == 4 else { return nil }
        let manualSection = "Manual\(parts[1])"
        let slot = "Stop\(parts[2])"
        let pipeKey = "Pipe\(parts[3])"
        guard let manual = manualBySection[manualSection],
              let stopNumber = manual.stopSlots[slot] else { return nil }
        let targetSection = "Stop\(stopNumber)"
        let marker = "\(targetSection).\(pipeKey)"
        guard !visited.contains(marker), let target = rawStopBySection[targetSection]?.values[pipeKey] else { return nil }
        var nextVisited = visited
        nextVisited.insert("\(currentSection):\(trimmed)")
        guard var resolved = resolvePipe(
            value: target,
            currentSection: targetSection,
            document: document,
            manualBySection: manualBySection,
            rawStopBySection: rawStopBySection,
            visited: nextVisited
        ) else { return nil }
        resolved.referenceTarget = marker
        return resolved
    }

    private static func packageRoot(containing odf: URL) -> URL {
        let directory = odf.deletingLastPathComponent().standardizedFileURL
        if directory.lastPathComponent.caseInsensitiveCompare("OrganDefinitions") == .orderedSame {
            let parent = directory.deletingLastPathComponent()
            if FileManager.default.fileExists(atPath: parent.appendingPathComponent("OrganInstallationPackages", isDirectory: true).path) {
                return parent
            }
        }
        var candidate = directory
        for _ in 0..<5 {
            let definitions = candidate.appendingPathComponent("OrganDefinitions", isDirectory: true)
            let packages = candidate.appendingPathComponent("OrganInstallationPackages", isDirectory: true)
            if FileManager.default.fileExists(atPath: definitions.path),
               FileManager.default.fileExists(atPath: packages.path),
               relativePath(of: odf, under: candidate) != nil {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path { break }
            candidate = parent
        }
        return directory
    }

    private static func resolveSourcePath(
        _ raw: String,
        relativeTo base: URL,
        within packageRoot: URL
    ) -> (url: URL, relativePath: String)? {
        let path = raw.replacingOccurrences(of: "\\", with: "/")
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0") else { return nil }
        let root = packageRoot.standardizedFileURL.resolvingSymlinksInPath()
        let candidate = base.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard let relative = relativePath(of: candidate, under: root), !relative.isEmpty else { return nil }
        return (candidate, relative)
    }

    private static func relativePath(of url: URL, under root: URL) -> String? {
        let rootPath = root.standardizedFileURL.path
        let childPath = url.standardizedFileURL.path
        guard childPath == rootPath || childPath.hasPrefix(rootPath + "/") else { return nil }
        if childPath == rootPath { return "" }
        return String(childPath.dropFirst(rootPath.count + 1))
    }

    private static func sampleVariants(pipeKey: String, values: [String: String]) -> [SampleVariantDefinition] {
        var result: [SampleVariantDefinition] = []
        if let value = values[pipeKey] {
            let role = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DUMMY"
                ? "silence-control"
                : "attack-sustain"
            result.append(SampleVariantDefinition(key: pipeKey, value: value, role: role, index: 0))
        }
        let escaped = NSRegularExpression.escapedPattern(for: pipeKey)
        let pattern = "^\(escaped)(Attack|Release)([0-9]{3})$"
        let variantKeys = values.keys.filter {
            $0.range(of: pattern, options: .regularExpression) != nil
        }.sorted()
        for key in variantKeys {
            let role = key.contains("Release") ? "release" : "attack"
            let suffix = String(key.suffix(3))
            result.append(SampleVariantDefinition(key: key, value: values[key] ?? "", role: role, index: Int(suffix) ?? 0))
        }
        if result.isEmpty {
            result.append(SampleVariantDefinition(key: pipeKey, value: "", role: "attack-sustain", index: 0))
        }
        return result
    }

    private static func numericValue(_ key: String, values: [String: String], fallback: String) -> Double? {
        Double(values[key] ?? values[fallback] ?? "")
    }

    private static func booleanValue(_ raw: String?) -> Bool? {
        guard let raw else { return nil }
        if ["Y", "YES", "TRUE", "1"].contains(raw.uppercased()) { return true }
        if ["N", "NO", "FALSE", "0"].contains(raw.uppercased()) { return false }
        return nil
    }

    /// Perspective labels are documentary path evidence only. They are not a
    /// physical microphone pose and remain explicitly marked as inferred.
    private static func perspectiveLabel(in rawPath: String?) -> String? {
        guard let path = rawPath?.lowercased() else { return nil }
        let tokens: [(String, [String])] = [
            ("front", ["front", "near", "close"]),
            ("rear", ["rear", "far", "distant"]),
            ("surround", ["surround"]),
            ("wet", ["wet"]),
            ("dry", ["dry"]),
        ]
        return tokens.first { _, candidates in candidates.contains { path.contains($0) } }?.0
    }

    private static func importedLoopPointSets(for sample: GrandOrgueSampleRecord) -> [LoopPointSet] {
        guard let metadata = sample.embeddedSamplerMetadata else { return [] }
        let validLoops = metadata.loops.filter { loop in
            loop.isUsable
                && loop.endFrameExclusive > loop.startFrameInclusive
                && (sample.frameCount == nil || loop.endFrameExclusive <= sample.frameCount!)
        }
        guard !validLoops.isEmpty else { return [] }
        let regions = validLoops.map { loop in
            AudioLoopRegion(
                role: .sustain,
                startFrameInclusive: loop.startFrameInclusive,
                endFrameExclusive: loop.endFrameExclusive,
                mode: AudioLoopMode(rawValue: loop.mode) ?? .forward,
                repeatCount: loop.playCount == 0 ? nil : Int(loop.playCount),
                crossfadeFrames: 0,
                exitPolicy: .envelopeRelease
            )
        }
        let rejectedCount = metadata.loops.count - validLoops.count
        return [LoopPointSet(
            sourceAudioSHA256: sample.sha256 ?? String(repeating: "0", count: 64),
            sampleRate: sample.sampleRate ?? 0,
            channelCount: sample.channelCount ?? 0,
            totalFrames: sample.frameCount ?? 0,
            status: .asserted,
            loopability: .notAssessed,
            regions: regions,
            confidence: 1,
            algorithm: "RIFF/WAVE smpl metadata parser",
            algorithmVersion: "orgrec.wav-smpl-metadata/v1",
            parameters: [
                "metadataSource": "embedded-metadata",
                "evidenceStatus": "asserted",
                "sourceEndConvention": "inclusive",
                "orgRecEndConvention": "exclusive",
                "midiUnityNote": String(metadata.midiUnityNote),
                "midiPitchFraction": String(metadata.midiPitchFraction),
                "declaredLoopCount": String(metadata.loops.count),
                "exitPolicyStatus": "not-encoded; envelope fallback is not a source assertion",
            ],
            qualityFlags: rejectedCount == 0 ? ["loop-suitability-not-assessed"] : [
                "loop-suitability-not-assessed",
                "\(rejectedCount) embedded loop record(s) rejected from playback; preserved in the source inspection",
            ]
        )]
    }

    private static func rankCount(in inspection: GrandOrgueSampleSetInspection) -> Int {
        inspection.stops.reduce(0) { total, stop in
            total + max(stop.rankSectionNames?.count ?? 0, 1)
        }
    }

    private static func payloadInventory(root: URL, warnings: inout [String]) throws -> [GrandOrguePayloadFile] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .isHiddenKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { throw OrgRecError.invalidProject("Could not enumerate the sample-set directory.") }
        var result: [GrandOrguePayloadFile] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: keys)
            let relative = String(url.standardizedFileURL.path.dropFirst(root.standardizedFileURL.path.count + 1))
            if values.isSymbolicLink == true {
                warnings.append("Symbolic link ‘\(relative)’ is excluded; VAO packages cannot contain symbolic links.")
            } else if values.isRegularFile == true, isSafePackageRelativePath(relative) {
                result.append(GrandOrguePayloadFile(relativePath: relative, fileSize: Int64(values.fileSize ?? 0), sha256: nil))
            }
        }
        return result.sorted { $0.relativePath < $1.relativePath }
    }

    private static func detectLicense(organ: [String: String], root: URL) -> (url: String?, label: String?, rightsHolder: String?) {
        let comments = organ["OrganComments"] ?? ""
        let url: String?
        let label: String?
        if comments.lowercased().contains("creativecommons.org/licenses/by-sa/2.5") {
            url = comments.contains("http") ? comments : "https://creativecommons.org/licenses/by-sa/2.5/"
            label = "Creative Commons Attribution-ShareAlike 2.5"
        } else if comments.lowercased().contains("creativecommons.org/licenses/by-sa/4.0") {
            url = comments.contains("http") ? comments : "https://creativecommons.org/licenses/by-sa/4.0/"
            label = "Creative Commons Attribution-ShareAlike 4.0 International"
        } else {
            url = nil
            label = nil
        }
        let detail = organ["RecordingDetails"] ?? ""
        let rightsHolder: String?
        if let range = detail.range(of: " by ", options: [.caseInsensitive]) {
            rightsHolder = clean(String(detail[range.upperBound...]))
        } else {
            rightsHolder = nil
        }
        return (url, label, rightsHolder)
    }

    private static func footHeight(in name: String) -> String? {
        let pattern = #"(?i)([0-9]+(?:\s+[0-9]+/[0-9]+|/[0-9]+)?)\s*['′]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
              let range = Range(match.range(at: 1), in: name) else { return nil }
        return String(name[range]) + "′"
    }

    private static func noteName(_ midi: Int) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        return "\(names[((midi % 12) + 12) % 12])\(midi / 12 - 1)"
    }
}

private func clean(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func slug(_ value: String) -> String {
    let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    let pieces = folded.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    return pieces.joined(separator: "-").lowercased()
}
