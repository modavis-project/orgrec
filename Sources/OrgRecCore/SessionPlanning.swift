import Foundation

public struct GeoCoordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct VenueAnchor: Codable, Hashable, Identifiable, Sendable {
    public enum Precision: String, Codable, CaseIterable, Sendable {
        case building
        case address
        case street
        case locality
        case manuallyPlaced
        case unknown
    }

    public var id: UUID
    public var label: String
    public var displayAddress: String
    public var coordinate: GeoCoordinate
    public var precision: Precision
    public var source: String
    public var sourceIdentifier: String?
    public var resolvedAt: Date
    public var confirmedAt: Date?
    public var confirmedBy: String?

    public init(
        id: UUID = UUID(),
        label: String,
        displayAddress: String,
        coordinate: GeoCoordinate,
        precision: Precision = .unknown,
        source: String,
        sourceIdentifier: String? = nil,
        resolvedAt: Date = .now,
        confirmedAt: Date? = nil,
        confirmedBy: String? = nil
    ) {
        self.id = id
        self.label = label
        self.displayAddress = displayAddress
        self.coordinate = coordinate
        self.precision = precision
        self.source = source
        self.sourceIdentifier = sourceIdentifier
        self.resolvedAt = resolvedAt
        self.confirmedAt = confirmedAt
        self.confirmedBy = confirmedBy
    }
}

public struct NoiseGeocodeCandidate: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var coordinate: GeoCoordinate
    public var osmType: String
    public var osmIdentifier: String
    public var category: String
    public var importance: Double?

    public init(
        id: String,
        displayName: String,
        coordinate: GeoCoordinate,
        osmType: String,
        osmIdentifier: String,
        category: String,
        importance: Double? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.coordinate = coordinate
        self.osmType = osmType
        self.osmIdentifier = osmIdentifier
        self.category = category
        self.importance = importance
    }

    public func venueAnchor(label: String, confirmedBy: String? = nil) -> VenueAnchor {
        VenueAnchor(
            label: label,
            displayAddress: displayName,
            coordinate: coordinate,
            precision: Self.precision(for: category),
            source: "OpenStreetMap Nominatim",
            sourceIdentifier: "\(osmType)/\(osmIdentifier)",
            confirmedAt: confirmedBy == nil ? nil : .now,
            confirmedBy: confirmedBy
        )
    }

    private static func precision(for category: String) -> VenueAnchor.Precision {
        switch category.lowercased() {
        case "building", "amenity", "place_of_worship": .building
        case "highway": .street
        case "place", "boundary": .locality
        default: .address
        }
    }
}

public enum NoiseSourceCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case mainRoad
    case railOrTram
    case station
    case construction
    case education
    case emergencyOrHealthcare
    case industrial
    case aviation
    case sportsOrEvents
    case manual
    case other

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .mainRoad: "Main roads"
        case .railOrTram: "Rail and tram"
        case .station: "Stations and stops"
        case .construction: "Construction"
        case .education: "Schools and education"
        case .emergencyOrHealthcare: "Emergency and healthcare"
        case .industrial: "Industrial activity"
        case .aviation: "Aviation"
        case .sportsOrEvents: "Sports and events"
        case .manual: "Local observation"
        case .other: "Other"
        }
    }
}

public enum NoiseTemporalPattern: String, Codable, CaseIterable, Sendable {
    case persistent
    case recurring
    case scheduled
    case intermittent
    case timeSensitive
    case unknown
}

public enum NoisePlanningPriority: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
}

public enum NoiseEvidenceConfidence: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
}

public enum NoiseFindingDisposition: String, Codable, CaseIterable, Sendable {
    case unverified
    case confirmed
    case dismissed
    case contactVenue
}

public struct NoiseObservation: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var observedAt: Date
    public var category: NoiseSourceCategory
    public var label: String
    public var notes: String
    public var takeID: UUID?
    public var atSeconds: Double?
    public var recordedBy: String

    public init(
        id: UUID = UUID(),
        observedAt: Date = .now,
        category: NoiseSourceCategory,
        label: String,
        notes: String = "",
        takeID: UUID? = nil,
        atSeconds: Double? = nil,
        recordedBy: String = "operator"
    ) {
        self.id = id
        self.observedAt = observedAt
        self.category = category
        self.label = label
        self.notes = notes
        self.takeID = takeID
        self.atSeconds = atSeconds
        self.recordedBy = recordedBy
    }
}

public struct NoiseContextFinding: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var sourceIdentifier: String
    public var label: String
    public var category: NoiseSourceCategory
    public var coordinate: GeoCoordinate?
    public var geometry: [GeoCoordinate]
    public var distanceMeters: Double?
    public var temporalPattern: NoiseTemporalPattern
    public var planningPriority: NoisePlanningPriority
    public var evidenceConfidence: NoiseEvidenceConfidence
    public var disposition: NoiseFindingDisposition
    public var tags: [String: String]
    public var notes: String

    public init(
        id: UUID = UUID(),
        sourceIdentifier: String,
        label: String,
        category: NoiseSourceCategory,
        coordinate: GeoCoordinate? = nil,
        geometry: [GeoCoordinate] = [],
        distanceMeters: Double? = nil,
        temporalPattern: NoiseTemporalPattern = .unknown,
        planningPriority: NoisePlanningPriority = .low,
        evidenceConfidence: NoiseEvidenceConfidence = .medium,
        disposition: NoiseFindingDisposition = .unverified,
        tags: [String: String] = [:],
        notes: String = ""
    ) {
        self.id = id
        self.sourceIdentifier = sourceIdentifier
        self.label = label
        self.category = category
        self.coordinate = coordinate
        self.geometry = geometry
        self.distanceMeters = distanceMeters
        self.temporalPattern = temporalPattern
        self.planningPriority = planningPriority
        self.evidenceConfidence = evidenceConfidence
        self.disposition = disposition
        self.tags = tags
        self.notes = notes
    }
}

public struct NoiseContextAssessment: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var revision: Int
    public var supersedesAssessmentID: UUID?
    public var venueAnchor: VenueAnchor
    public var radiusMeters: Double
    public var retrievedAt: Date
    public var sourceName: String
    public var sourceURL: URL?
    public var sourceDataTimestamp: Date?
    public var sourceAttribution: String
    public var querySHA256: String
    public var findings: [NoiseContextFinding]
    public var manualNotes: String
    public var officialNoiseLayerNotes: String

    public init(
        id: UUID = UUID(),
        revision: Int = 1,
        supersedesAssessmentID: UUID? = nil,
        venueAnchor: VenueAnchor,
        radiusMeters: Double = 750,
        retrievedAt: Date = .now,
        sourceName: String = "OpenStreetMap via Overpass",
        sourceURL: URL? = URL(string: "https://www.openstreetmap.org/copyright"),
        sourceDataTimestamp: Date? = nil,
        sourceAttribution: String = "Map data © OpenStreetMap contributors, ODbL 1.0",
        querySHA256: String,
        findings: [NoiseContextFinding] = [],
        manualNotes: String = "",
        officialNoiseLayerNotes: String = ""
    ) {
        self.id = id
        self.revision = revision
        self.supersedesAssessmentID = supersedesAssessmentID
        self.venueAnchor = venueAnchor
        self.radiusMeters = radiusMeters
        self.retrievedAt = retrievedAt
        self.sourceName = sourceName
        self.sourceURL = sourceURL
        self.sourceDataTimestamp = sourceDataTimestamp
        self.sourceAttribution = sourceAttribution
        self.querySHA256 = querySHA256
        self.findings = findings
        self.manualNotes = manualNotes
        self.officialNoiseLayerNotes = officialNoiseLayerNotes
    }

    public var actionableFindings: [NoiseContextFinding] {
        findings.filter { $0.disposition != .dismissed }
    }

    public var highPriorityCount: Int {
        actionableFindings.filter { $0.planningPriority == .high }.count
    }

    public var summary: String {
        let actionable = actionableFindings
        guard actionable.isEmpty == false else { return "No surrounding noise sources retained after review." }
        let groups = Dictionary(grouping: actionable, by: \.category)
            .map { "\($0.key.displayName): \($0.value.count)" }
            .sorted()
            .joined(separator: "; ")
        return "\(actionable.count) potential surrounding noise sources within \(Int(radiusMeters)) m (\(highPriorityCount) high planning priority). \(groups)"
    }
}

public enum RecordingSessionPlanStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case frozen
    case active
    case completed
}

public struct SessionPlanQueueItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var roadmapItemID: UUID
    public var order: Int
    public var estimatedCaptureSeconds: Double
    public var estimatedOperatingSeconds: Double
    public var notes: String

    public init(
        id: UUID = UUID(),
        roadmapItemID: UUID,
        order: Int,
        estimatedCaptureSeconds: Double,
        estimatedOperatingSeconds: Double,
        notes: String = ""
    ) {
        self.id = id
        self.roadmapItemID = roadmapItemID
        self.order = order
        self.estimatedCaptureSeconds = estimatedCaptureSeconds
        self.estimatedOperatingSeconds = estimatedOperatingSeconds
        self.notes = notes
    }
}

public struct RecordingSessionPlan: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var revision: Int
    public var supersedesPlanID: UUID?
    public var status: RecordingSessionPlanStatus
    public var title: String
    public var purpose: String
    public var organMDVSID: String
    public var navigatorSnapshotSHA256: String
    public var plannedStart: Date
    public var plannedEnd: Date
    public var timezoneIdentifier: String
    public var operatorName: String
    public var institution: String
    public var accessNotes: String
    public var queue: [SessionPlanQueueItem]
    public var setupIDs: [UUID]
    public var noiseContextAssessmentID: UUID?
    public var estimatedTotalSeconds: Double
    public var estimatedAudioBytes: Int64
    public var contingencyFraction: Double
    public var preflightNotes: String
    public var createdAt: Date
    public var frozenAt: Date?

    public init(
        id: UUID = UUID(),
        revision: Int = 1,
        supersedesPlanID: UUID? = nil,
        status: RecordingSessionPlanStatus = .draft,
        title: String,
        purpose: String,
        organMDVSID: String,
        navigatorSnapshotSHA256: String,
        plannedStart: Date,
        plannedEnd: Date,
        timezoneIdentifier: String = TimeZone.current.identifier,
        operatorName: String = "",
        institution: String = "",
        accessNotes: String = "",
        queue: [SessionPlanQueueItem] = [],
        setupIDs: [UUID] = [],
        noiseContextAssessmentID: UUID? = nil,
        estimatedTotalSeconds: Double = 0,
        estimatedAudioBytes: Int64 = 0,
        contingencyFraction: Double = 0.15,
        preflightNotes: String = "",
        createdAt: Date = .now,
        frozenAt: Date? = nil
    ) {
        self.id = id
        self.revision = revision
        self.supersedesPlanID = supersedesPlanID
        self.status = status
        self.title = title
        self.purpose = purpose
        self.organMDVSID = organMDVSID
        self.navigatorSnapshotSHA256 = navigatorSnapshotSHA256
        self.plannedStart = plannedStart
        self.plannedEnd = plannedEnd
        self.timezoneIdentifier = timezoneIdentifier
        self.operatorName = operatorName
        self.institution = institution
        self.accessNotes = accessNotes
        self.queue = queue
        self.setupIDs = setupIDs
        self.noiseContextAssessmentID = noiseContextAssessmentID
        self.estimatedTotalSeconds = estimatedTotalSeconds
        self.estimatedAudioBytes = estimatedAudioBytes
        self.contingencyFraction = contingencyFraction
        self.preflightNotes = preflightNotes
        self.createdAt = createdAt
        self.frozenAt = frozenAt
    }
}

public enum SessionPlanningEngine {
    public static func eligibleRoadmapItems(_ project: OrgRecProject) -> [RoadmapItem] {
        project.roadmap.filter {
            $0.required && [.missing, .queued, .rejected].contains($0.state)
        }
    }

    /// Includes optional suggested protocols so a field session can explicitly
    /// opt into instrument-mechanics captures without making them mandatory for
    /// overall pipe-speech coverage.
    public static func plannableRoadmapItems(_ project: OrgRecProject) -> [RoadmapItem] {
        project.roadmap.filter {
            [.missing, .queued, .rejected].contains($0.state)
        }
    }

    public static func buildQueue(
        items: [RoadmapItem],
        recipe: CaptureRecipe,
        setupOrder: [UUID] = [],
        registrationOrder: [UUID] = [],
        operatingOverheadSeconds: Double = 12
    ) -> [SessionPlanQueueItem] {
        let ordinaryCaptureSeconds = recipe.preRollSeconds + recipe.sustainSeconds + recipe.releaseSeconds
        let resolvedSetupOrder = setupOrder.isEmpty ? firstAppearanceOrder(items.compactMap(\.setupID)) : setupOrder
        let resolvedRegistrationOrder = registrationOrder.isEmpty ? firstAppearanceOrder(items.compactMap(\.registrationID)) : registrationOrder
        let setupRanks = Dictionary(uniqueKeysWithValues: resolvedSetupOrder.enumerated().map { ($1, $0) })
        let registrationRanks = Dictionary(uniqueKeysWithValues: resolvedRegistrationOrder.enumerated().map { ($1, $0) })
        let sourceRanks = Dictionary(uniqueKeysWithValues: items.enumerated().map { ($1.id, $0) })
        let sorted = items.sorted {
            queuePrecedes(
                $0,
                $1,
                setupRanks: setupRanks,
                registrationRanks: registrationRanks,
                sourceRanks: sourceRanks
            )
        }
        return sorted.enumerated().map { index, item in
            let repetitions = Double(item.minimumAcceptedTakeCount)
            let complexCaptureSeconds: Double? = item.complexCaptureProtocol.map { protocolSnapshot in
                switch protocolSnapshot.kind {
                case .operationalBaseline:
                    return protocolSnapshot.operationalBaseline?.minimumDurationSeconds ?? 180
                case .declarativeProcess:
                    let processDuration = protocolSnapshot.processModel?.maximumDurationSeconds
                        ?? protocolSnapshot.processModel?.stages.compactMap(\.duration?.typicalSeconds).reduce(0, +)
                        ?? recipe.sustainSeconds
                    return recipe.preRollSeconds + processDuration + recipe.releaseSeconds
                case .physicalActuatorResponse:
                    let actionDuration = item.soundingTargetDefinition?.plannedDurationSeconds
                        ?? protocolSnapshot.physicalActuation?.gateDurationSeconds
                        ?? recipe.sustainSeconds
                    return recipe.preRollSeconds + actionDuration + recipe.releaseSeconds
                case .discreteShutterMapping:
                    return max(ordinaryCaptureSeconds, recipe.preRollSeconds + 6 + recipe.releaseSeconds)
                case .tremulantResponse:
                    return max(ordinaryCaptureSeconds, recipe.preRollSeconds + 10 + recipe.releaseSeconds)
                }
            }
            let captureSeconds = (item.spatialAcousticProtocol?.plannedDurationSeconds ?? item.instrumentNoiseProtocol?.captureDurationSeconds ?? complexCaptureSeconds ?? ordinaryCaptureSeconds) * repetitions
            return SessionPlanQueueItem(
                roadmapItemID: item.id,
                order: index,
                estimatedCaptureSeconds: captureSeconds,
                estimatedOperatingSeconds: max(0, operatingOverheadSeconds) * repetitions
            )
        }
    }

    public static func estimates(
        queue: [SessionPlanQueueItem],
        roadmap: [RoadmapItem],
        sampleRate: Double,
        channelCount: Int,
        bytesPerSample: Int = 3,
        fixedPreparationSeconds: Double = 1_200,
        setupChangeSeconds: Double = 600,
        contingencyFraction: Double = 0.15
    ) -> (totalSeconds: Double, audioBytes: Int64) {
        let byID = Dictionary(uniqueKeysWithValues: roadmap.map { ($0.id, $0) })
        var priorSetup: UUID?
        var setupChanges = 0
        for queued in queue.sorted(by: { $0.order < $1.order }) {
            let setup = byID[queued.roadmapItemID]?.setupID
            if priorSetup != nil, setup != priorSetup { setupChanges += 1 }
            priorSetup = setup
        }
        let work = queue.reduce(0) { $0 + $1.estimatedCaptureSeconds + $1.estimatedOperatingSeconds }
            + fixedPreparationSeconds
            + Double(setupChanges) * setupChangeSeconds
        let total = work * (1 + max(0, contingencyFraction))
        let capture = queue.reduce(0) { $0 + $1.estimatedCaptureSeconds }
        let bytes = capture * max(1, sampleRate) * Double(max(1, channelCount)) * Double(max(1, bytesPerSample)) * 1.1
        return (total, Int64(min(bytes, Double(Int64.max)).rounded(.up)))
    }

    public static func nextPlannedRoadmapItem(in project: OrgRecProject, session: RecordingSession?) -> RoadmapItem? {
        guard let planID = session?.sessionPlanID,
              let plan = project.sessionPlans?.first(where: { $0.id == planID }) else {
            return RoadmapEngine.nextItem(in: project.roadmap)
        }
        let roadmap = Dictionary(project.roadmap.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return plan.queue.sorted(by: { $0.order < $1.order }).compactMap { roadmap[$0.roadmapItemID] }.first {
            $0.required && [.missing, .queued, .rejected].contains($0.state)
        }
    }

    private static func firstAppearanceOrder(_ values: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return values.filter { seen.insert($0).inserted }
    }

    private static func queuePrecedes(
        _ lhs: RoadmapItem,
        _ rhs: RoadmapItem,
        setupRanks: [UUID: Int],
        registrationRanks: [UUID: Int],
        sourceRanks: [UUID: Int]
    ) -> Bool {
        let lhsSetup = lhs.setupID.flatMap { setupRanks[$0] } ?? Int.max
        let rhsSetup = rhs.setupID.flatMap { setupRanks[$0] } ?? Int.max
        if lhsSetup != rhsSetup { return lhsSetup < rhsSetup }

        let lhsRegistration = lhs.registrationID.flatMap { registrationRanks[$0] } ?? Int.max
        let rhsRegistration = rhs.registrationID.flatMap { registrationRanks[$0] } ?? Int.max
        if lhsRegistration != rhsRegistration { return lhsRegistration < rhsRegistration }

        let divisionComparison = lhs.component.division.localizedStandardCompare(rhs.component.division)
        if divisionComparison != .orderedSame { return divisionComparison == .orderedAscending }
        let labelComparison = lhs.component.label.localizedStandardCompare(rhs.component.label)
        if labelComparison != .orderedSame { return labelComparison == .orderedAscending }
        if lhs.component.midiNote != rhs.component.midiNote {
            return (lhs.component.midiNote ?? Int.max) < (rhs.component.midiNote ?? Int.max)
        }
        let techniqueComparison = lhs.technique.rawValue.localizedStandardCompare(rhs.technique.rawValue)
        if techniqueComparison != .orderedSame { return techniqueComparison == .orderedAscending }
        return (sourceRanks[lhs.id] ?? Int.max) < (sourceRanks[rhs.id] ?? Int.max)
    }
}

public actor NoiseContextService {
    private let session: URLSession
    private let geocodingBaseURL: URL
    private let overpassURL: URL
    private let userAgent: String
    private var lastGeocodeRequestAt: Date?

    public init(
        session: URLSession = .shared,
        geocodingBaseURL: URL = URL(string: "https://nominatim.openstreetmap.org/search")!,
        overpassURL: URL = URL(string: "https://overpass-api.de/api/interpreter")!,
        userAgent: String = "OrgRec/0.1 (pipe-organ recording session planning)"
    ) {
        self.session = session
        self.geocodingBaseURL = geocodingBaseURL
        self.overpassURL = overpassURL
        self.userAgent = userAgent
    }

    public func geocode(_ query: String, limit: Int = 5) async throws -> [NoiseGeocodeCandidate] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.isEmpty == false else { return [] }
        if let lastGeocodeRequestAt {
            let remaining = 1.05 - Date().timeIntervalSince(lastGeocodeRequestAt)
            if remaining > 0 {
                try await Task.sleep(for: .seconds(remaining))
            }
        }
        var components = URLComponents(url: geocodingBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: clean),
            URLQueryItem(name: "format", value: "jsonv2"),
            URLQueryItem(name: "limit", value: String(min(max(limit, 1), 10))),
            URLQueryItem(name: "addressdetails", value: "1"),
        ]
        guard let url = components.url else { throw OrgRecError.invalidNavigatorResponse("The venue search URL is invalid.") }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await session.data(for: request)
        lastGeocodeRequestAt = .now
        try validate(response: response, data: data, service: "Nominatim")
        let decoded = try JSONDecoder().decode([NominatimResult].self, from: data)
        return decoded.compactMap { result in
            guard let latitude = Double(result.lat), let longitude = Double(result.lon) else { return nil }
            return NoiseGeocodeCandidate(
                id: "\(result.osmType)/\(result.osmID)",
                displayName: result.displayName,
                coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
                osmType: result.osmType,
                osmIdentifier: String(result.osmID),
                category: result.category ?? result.type ?? "unknown",
                importance: result.importance
            )
        }
    }

    public func assess(anchor: VenueAnchor, radiusMeters: Double = 750) async throws -> NoiseContextAssessment {
        let radius = min(max(radiusMeters, 100), 2_500)
        let query = Self.overpassQuery(anchor: anchor, radiusMeters: radius)
        var components = URLComponents(url: overpassURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "data", value: query)]
        guard let url = components.url else { throw OrgRecError.invalidNavigatorResponse("The noise-context query URL is invalid.") }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 45
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, service: "Overpass")
        let payload = try JSONDecoder().decode(OverpassResponse.self, from: data)
        let findings = Self.findings(from: payload.elements, anchor: anchor)
        return NoiseContextAssessment(
            venueAnchor: anchor,
            radiusMeters: radius,
            sourceDataTimestamp: payload.osm3s.timestampOSMBase.flatMap(Self.parseISO8601),
            querySHA256: Data(query.utf8).sha256Hex,
            findings: findings
        )
    }

    public static func overpassQuery(anchor: VenueAnchor, radiusMeters: Double) -> String {
        let around = "around:\(Int(radiusMeters.rounded())),\(anchor.coordinate.latitude),\(anchor.coordinate.longitude)"
        return """
        [out:json][timeout:35];
        (
          nwr(\(around))[highway~"^(motorway|motorway_link|trunk|trunk_link|primary|primary_link|secondary|secondary_link)$"];
          nwr(\(around))[railway~"^(rail|tram|light_rail|subway|station|halt|tram_stop|yard)$"];
          nwr(\(around))[amenity~"^(school|kindergarten|college|university|hospital|clinic|police|fire_station|events_venue)$"];
          nwr(\(around))[landuse~"^(construction|industrial)$"];
          nwr(\(around))[building="construction"];
          nwr(\(around))[highway="construction"];
          nwr(\(around))[railway="construction"];
          nwr(\(around))[man_made="works"];
          nwr(\(around))[aeroway~"^(aerodrome|helipad|heliport)$"];
          nwr(\(around))[leisure~"^(stadium|sports_centre|pitch)$"];
        );
        out tags center geom qt;
        """
    }

    public static func findings(from elements: [OverpassElement], anchor: VenueAnchor) -> [NoiseContextFinding] {
        let raw = elements.compactMap { finding(from: $0, anchor: anchor) }
        let exactGroups = Dictionary(grouping: raw) { finding in
            let normalized = finding.label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let named = finding.tags["name"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            return named
                ? "\(finding.category.rawValue)|\(normalized)"
                : "\(finding.category.rawValue)|\(finding.sourceIdentifier)"
        }
        let exactMerged = exactGroups.values.compactMap(mergeFindings)
        let consolidated = consolidateAdjacentLinearFeatures(exactMerged)
        let balanced = Dictionary(grouping: consolidated, by: \.category).values.flatMap { categoryFindings in
            categoryFindings.sorted(by: findingPrecedes)
                .prefix(categoryReviewLimit(categoryFindings[0].category))
        }
        return balanced
        .sorted(by: findingPrecedes)
        .prefix(100)
        .map { $0 }
    }

    private static func categoryReviewLimit(_ category: NoiseSourceCategory) -> Int {
        switch category {
        case .mainRoad, .railOrTram, .construction: 12
        case .station, .education, .emergencyOrHealthcare, .other: 10
        case .industrial, .aviation, .sportsOrEvents: 8
        case .manual: 100
        }
    }

    private static func findingPrecedes(_ lhs: NoiseContextFinding, _ rhs: NoiseContextFinding) -> Bool {
        if lhs.planningPriority != rhs.planningPriority {
            return priorityRank(lhs.planningPriority) < priorityRank(rhs.planningPriority)
        }
        let leftDistance = lhs.distanceMeters ?? .greatestFiniteMagnitude
        let rightDistance = rhs.distanceMeters ?? .greatestFiniteMagnitude
        if leftDistance != rightDistance { return leftDistance < rightDistance }
        return lhs.sourceIdentifier < rhs.sourceIdentifier
    }

    private static func consolidateAdjacentLinearFeatures(
        _ findings: [NoiseContextFinding]
    ) -> [NoiseContextFinding] {
        var retained: [NoiseContextFinding] = []
        let candidates = findings.filter {
            ($0.category == .railOrTram || $0.category == .mainRoad)
                && ($0.tags["name"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false)
        }
        retained.append(contentsOf: findings.filter { candidate in
            candidates.contains(where: { $0.id == candidate.id }) == false
        })

        let grouped = Dictionary(grouping: candidates, by: linearFeatureKey)
        for group in grouped.values {
            var clusters: [[NoiseContextFinding]] = []
            for candidate in group.sorted(by: {
                ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude)
            }) {
                let threshold = candidate.category == .railOrTram ? 60.0 : 40.0
                if let index = clusters.firstIndex(where: { cluster in
                    cluster.contains { featureDistance($0, candidate) <= threshold }
                }) {
                    clusters[index].append(candidate)
                } else {
                    clusters.append([candidate])
                }
            }
            retained.append(contentsOf: clusters.compactMap(mergeFindings))
        }
        return retained
    }

    private static func linearFeatureKey(_ finding: NoiseContextFinding) -> String {
        [
            finding.category.rawValue,
            finding.tags["railway"] ?? "",
            finding.tags["highway"] ?? "",
            finding.tags["ref"] ?? "",
            finding.tags["operator"] ?? "",
        ].joined(separator: "|")
    }

    private static func mergeFindings(_ candidates: [NoiseContextFinding]) -> NoiseContextFinding? {
        guard var nearest = candidates.min(by: {
            ($0.distanceMeters ?? .greatestFiniteMagnitude) < ($1.distanceMeters ?? .greatestFiniteMagnitude)
        }) else { return nil }
        guard candidates.count > 1 else { return nearest }

        let identifiers = candidates.map(\.sourceIdentifier).sorted()
        let fingerprint = Data(identifiers.joined(separator: "|").utf8).sha256Hex.prefix(16)
        nearest.sourceIdentifier = "osm:aggregate/\(nearest.category.rawValue)/\(fingerprint)"
        nearest.label += " (\(candidates.count) mapped segments)"
        nearest.tags["orgrec:aggregated_source_count"] = String(candidates.count)
        nearest.tags["orgrec:aggregated_source_ids"] = identifiers.joined(separator: ",")
        let consolidationNote = "OrgRec consolidated \(candidates.count) connected or duplicate OpenStreetMap features into this planning indicator; the map shows representative geometry."
        nearest.notes = nearest.notes.isEmpty ? consolidationNote : "\(nearest.notes) \(consolidationNote)"
        return nearest
    }

    private static func featureDistance(_ lhs: NoiseContextFinding, _ rhs: NoiseContextFinding) -> Double {
        let lhsPoints = lhs.geometry.isEmpty ? [lhs.coordinate].compactMap { $0 } : lhs.geometry
        let rhsPoints = rhs.geometry.isEmpty ? [rhs.coordinate].compactMap { $0 } : rhs.geometry
        guard lhsPoints.isEmpty == false, rhsPoints.isEmpty == false else { return .greatestFiniteMagnitude }
        return lhsPoints.reduce(.greatestFiniteMagnitude) { current, left in
            min(current, rhsPoints.reduce(.greatestFiniteMagnitude) { min($0, haversine(from: left, to: $1)) })
        }
    }

    private static func finding(from element: OverpassElement, anchor: VenueAnchor) -> NoiseContextFinding? {
        let tags = element.tags ?? [:]
        guard let category = category(tags: tags) else { return nil }
        let geometry = (element.geometry ?? []).map { GeoCoordinate(latitude: $0.lat, longitude: $0.lon) }
        let center = element.lat.flatMap { latitude in element.lon.map { GeoCoordinate(latitude: latitude, longitude: $0) } }
            ?? element.center.map { GeoCoordinate(latitude: $0.lat, longitude: $0.lon) }
            ?? geometry.first
        let distance = minimumDistance(from: anchor.coordinate, to: geometry.isEmpty ? [center].compactMap { $0 } : geometry)
        let label = displayLabel(category: category, tags: tags)
        return NoiseContextFinding(
            sourceIdentifier: "osm:\(element.type)/\(element.id)",
            label: label,
            category: category,
            coordinate: center,
            geometry: geometry,
            distanceMeters: distance,
            temporalPattern: temporalPattern(category: category),
            planningPriority: planningPriority(category: category, distanceMeters: distance),
            evidenceConfidence: evidenceConfidence(category: category),
            tags: tags,
            notes: defaultNote(category: category)
        )
    }

    private static func category(tags: [String: String]) -> NoiseSourceCategory? {
        let highway = tags["highway"] ?? ""
        let railway = tags["railway"] ?? ""
        let amenity = tags["amenity"] ?? ""
        if [highway, railway, tags["landuse"] ?? "", tags["building"] ?? ""].contains("construction") { return .construction }
        if ["motorway", "motorway_link", "trunk", "trunk_link", "primary", "primary_link", "secondary", "secondary_link"].contains(highway) { return .mainRoad }
        if ["station", "halt", "tram_stop", "yard"].contains(railway) { return .station }
        if ["rail", "tram", "light_rail", "subway"].contains(railway) { return .railOrTram }
        if ["school", "kindergarten", "college", "university"].contains(amenity) { return .education }
        if ["hospital", "clinic", "police", "fire_station"].contains(amenity) { return .emergencyOrHealthcare }
        if tags["landuse"] == "industrial" || tags["man_made"] == "works" { return .industrial }
        if tags["aeroway"] != nil { return .aviation }
        if amenity == "events_venue" || tags["leisure"] != nil { return .sportsOrEvents }
        return nil
    }

    private static func displayLabel(category: NoiseSourceCategory, tags: [String: String]) -> String {
        if let name = tags["name"], name.isEmpty == false { return name }
        switch category {
        case .mainRoad: return "\((tags["highway"] ?? "Main").replacingOccurrences(of: "_", with: " ").capitalized) road"
        case .railOrTram: return "\((tags["railway"] ?? "Rail").replacingOccurrences(of: "_", with: " ").capitalized) corridor"
        case .station: return "Rail or public-transport station"
        case .construction: return "Mapped construction activity"
        case .education: return "\((tags["amenity"] ?? "Education").capitalized) site"
        case .emergencyOrHealthcare: return "\((tags["amenity"] ?? "Emergency/healthcare").replacingOccurrences(of: "_", with: " ").capitalized) facility"
        case .industrial: return "Industrial activity"
        case .aviation: return "\((tags["aeroway"] ?? "Aviation").capitalized) facility"
        case .sportsOrEvents: return "Sports or event venue"
        case .manual: return "Local observation"
        case .other: return "Potential noise source"
        }
    }

    private static func temporalPattern(category: NoiseSourceCategory) -> NoiseTemporalPattern {
        switch category {
        case .mainRoad, .industrial: .persistent
        case .railOrTram, .station: .recurring
        case .education, .sportsOrEvents: .scheduled
        case .emergencyOrHealthcare, .aviation: .intermittent
        case .construction: .timeSensitive
        case .manual, .other: .unknown
        }
    }

    private static func evidenceConfidence(category: NoiseSourceCategory) -> NoiseEvidenceConfidence {
        switch category {
        case .mainRoad, .railOrTram, .station, .construction, .industrial: .medium
        case .education, .emergencyOrHealthcare, .aviation, .sportsOrEvents, .manual, .other: .low
        }
    }

    private static func defaultNote(category: NoiseSourceCategory) -> String {
        switch category {
        case .construction: "Time-sensitive map evidence; confirm activity and working hours with the venue."
        case .mainRoad: "Road class and proximity are screening evidence, not a prediction of indoor sound level."
        case .railOrTram, .station: "Check the planned session window against local service patterns."
        case .education, .sportsOrEvents: "Likely schedule-dependent; confirm occupancy and event times."
        case .emergencyOrHealthcare: "Proximity alone does not prove siren or vehicle noise."
        case .industrial: "Confirm operating hours and whether the activity is audible inside the venue."
        case .aviation: "A mapped facility does not establish an active flight path over the venue."
        case .manual, .other: "Operator-supplied contextual observation."
        }
    }

    private static func planningPriority(category: NoiseSourceCategory, distanceMeters: Double?) -> NoisePlanningPriority {
        guard let distanceMeters else { return .low }
        switch category {
        case .construction:
            return distanceMeters <= 500 ? .high : distanceMeters <= 1_000 ? .medium : .low
        case .railOrTram, .station:
            return distanceMeters <= 250 ? .high : distanceMeters <= 750 ? .medium : .low
        case .mainRoad:
            return distanceMeters <= 150 ? .high : distanceMeters <= 500 ? .medium : .low
        case .industrial:
            return distanceMeters <= 400 ? .high : distanceMeters <= 1_000 ? .medium : .low
        case .aviation:
            return distanceMeters <= 1_000 ? .high : distanceMeters <= 2_500 ? .medium : .low
        case .education, .emergencyOrHealthcare, .sportsOrEvents:
            return distanceMeters <= 250 ? .medium : .low
        case .manual, .other:
            return .medium
        }
    }

    private static func minimumDistance(from origin: GeoCoordinate, to points: [GeoCoordinate]) -> Double? {
        points.map { haversine(from: origin, to: $0) }.min()
    }

    private static func haversine(from: GeoCoordinate, to: GeoCoordinate) -> Double {
        let radius = 6_371_000.0
        let latitudeDelta = (to.latitude - from.latitude) * .pi / 180
        let longitudeDelta = (to.longitude - from.longitude) * .pi / 180
        let first = from.latitude * .pi / 180
        let second = to.latitude * .pi / 180
        let value = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(first) * cos(second) * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return 2 * radius * atan2(sqrt(value), sqrt(max(0, 1 - value)))
    }

    private static func priorityRank(_ priority: NoisePlanningPriority) -> Int {
        switch priority { case .high: 0; case .medium: 1; case .low: 2 }
    }

    private func validate(response: URLResponse, data: Data, service: String) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let detail = String(data: data.prefix(512), encoding: .utf8) ?? ""
            throw OrgRecError.invalidNavigatorResponse("\(service) returned HTTP \(http.statusCode). \(detail)")
        }
    }

    private static func parseISO8601(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }
}

public struct OverpassElement: Codable, Hashable, Sendable {
    public struct Point: Codable, Hashable, Sendable {
        public var lat: Double
        public var lon: Double
    }

    public var type: String
    public var id: Int64
    public var lat: Double?
    public var lon: Double?
    public var center: Point?
    public var geometry: [Point]?
    public var tags: [String: String]?
}

private struct OverpassResponse: Decodable {
    struct Metadata: Decodable {
        var timestampOSMBase: String?

        enum CodingKeys: String, CodingKey {
            case timestampOSMBase = "timestamp_osm_base"
        }
    }

    var osm3s: Metadata
    var elements: [OverpassElement]
}

private struct NominatimResult: Decodable {
    var osmType: String
    var osmID: Int64
    var lat: String
    var lon: String
    var displayName: String
    var category: String?
    var type: String?
    var importance: Double?

    enum CodingKeys: String, CodingKey {
        case osmType = "osm_type"
        case osmID = "osm_id"
        case lat, lon
        case displayName = "display_name"
        case category, type, importance
    }
}
