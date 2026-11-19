import Foundation
import XCTest
@testable import OrgRecCore

final class NavigatorClientTests: XCTestCase {
    private let publicURL = URL(string: "https://navigator.modavis.org")!
    private let customURL = URL(string: "https://catalogue.example.test")!

    func testPublicSearchAndRoadmapUseThreeReadsAndFreezeTheSelectedSpecification() async throws {
        let organID = "MDVS:ENTY:SYNTH-01"
        let detailPath = "/api/organs/\(organID)"
        let fixture = fixture([
            .init("/api/organs", json: """
                {"items":[{"mdvsId":"\(organID)","title":"Chapel organ","location":"North Chapel",
                  "pageUrl":"/organs/SYNTH-01","builder":"Builder A","related":{"mdvsId":"MDVS:ENTY:BUILDER","title":"Builder A"}}],
                 "total":1}
                """),
            .init(detailPath, json: """
                {"organ":{"mdvsId":"\(organID)","title":"Chapel organ","entityType":"organ",
                  "location":"North Chapel","componentHierarchy":[],
                  "citation":{"dataset":{"version":"1.6.0"}},
                  "status":"Published structured record"}}
                """),
            .init(detailPath + "/specification", json: """
                {"componentHierarchy":[{"id":"stops","items":[
                  {"kind":"stop","id":"spec:principal","label":"Principal 4",
                   "detail":{"division":"Manual","pitch":"4"},
                   "pipeQuantity":{"actuationRange":[36,38]},"source":{"id":"sr:primary"},
                   "sourcePath":"specifications.stops[0]"}]}],
                 "sourceSpecifications":[{"preferred":false,"componentHierarchy":[{"id":"stops","items":[
                   {"kind":"stop","id":"spec:historical","label":"Other account","detail":{"division":"Manual"}}]}]}],
                 "specification":{"summary":{"manuals":"1","stopRowCount":1}},
                 "technicalEvidence":{"pitch":{"preferredValue":"A = 445 Hz","status":"single_source",
                   "assertions":[{"sourceRecordId":"sr:primary","sourcePath":"specifications.pitch"}]},
                   "temperament":{"preferredValue":"Meantone","status":"single_source"}}}
                """)
        ])

        let empty = try await fixture.client.search(baseURL: publicURL, query: "   ")
        XCTAssertTrue(empty.isEmpty)
        let search = try await fixture.client.search(baseURL: publicURL, query: "  North Chapel  ", limit: 999)
        XCTAssertEqual(search.map(\.mdvsID), [organID])
        XCTAssertEqual(search.first?.builder, "Builder A")
        XCTAssertEqual(search.first?.pagePath, "/organs/SYNTH-01")
        let searchURL = try XCTUnwrap(fixture.requests.first?.url)
        let query = try XCTUnwrap(URLComponents(url: searchURL, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertTrue(query.contains(URLQueryItem(name: "q", value: "North Chapel")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "include_facets", value: "0")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "sort", value: "label")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "limit", value: "100")))

        let response = try await fixture.client.fetchRoadmap(baseURL: publicURL, organID: organID)
        let profile = try XCTUnwrap(response)
        XCTAssertEqual(profile.organ.mdvsID, organID)
        XCTAssertEqual(profile.organ.location, "North Chapel")
        XCTAssertEqual(profile.snapshot.release.requestedRelease, "1.6.0")
        XCTAssertNil(profile.snapshot.release.protectedFingerprintSHA256)
        XCTAssertEqual(profile.snapshot.payloadSHA256, profile.rawPayload.sha256Hex)
        XCTAssertEqual(profile.components.map(\.id), ["spec:principal"])
        let stop = try XCTUnwrap(profile.components.first)
        XCTAssertEqual(stop.locator.organMDVSID, organID)
        XCTAssertEqual(stop.locator.snapshotSHA256, profile.snapshot.payloadSHA256)
        XCTAssertEqual(stop.locator.sourceRecordID, "sr:primary")
        XCTAssertEqual(stop.footHeight, "4")
        XCTAssertEqual(stop.playableMIDILow, 36)
        XCTAssertEqual(stop.playableMIDIHigh, 38)
        XCTAssertEqual(profile.documentedPitchStandard?.frequencyHz, 445)
        XCTAssertEqual(profile.documentedPitchStandard?.modavisRelease, "1.6.0")
        XCTAssertEqual(profile.characteristics.temperament, "Meantone")
        let recipe = CaptureRecipe(techniques: [.closePair], chromaticStep: 1)
        let compilation = RoadmapEngine.compileSpecification(components: profile.components, recipe: recipe)
        XCTAssertEqual(compilation.report.generatedAtomicSoundCount, 3)
        XCTAssertEqual(fixture.requests.compactMap { $0.url?.path }, ["/api/organs", detailPath, detailPath + "/specification"])
        XCTAssertTrue(fixture.requests.allSatisfy { $0.httpMethod == "GET" })
    }

    func testConflictingPublicPitchStaysUnknownWhenFrozenEvidenceIsReopened() {
        let object: [String: Any] = ["specification": [
            "componentHierarchy": [],
            "technicalEvidence": ["pitch": ["status": "sources_differ", "preferredValue": NSNull()]],
            "sourceSpecifications": [["technicalEvidence": ["pitch": ["preferredValue": "A = 415 Hz"]]]]
        ]]
        XCTAssertNil(NavigatorClient.documentedPitchStandard(in: object, release: "1.6.0"))
    }

    func testMismatchedPublicIdentityStopsBeforeRequestingSpecification() async throws {
        let fixture = fixture([.init("/api/organs/MDVS:ENTY:SELECTED", json: """
            {"organ":{"mdvsId":"MDVS:ENTY:OTHER","title":"Another organ","entityType":"organ"}}
            """)])
        do {
            _ = try await fixture.client.fetchRoadmap(baseURL: publicURL, organID: "MDVS:ENTY:SELECTED")
            XCTFail("An organ detail for another instrument was accepted")
        } catch {
            XCTAssertEqual(fixture.requests.count, 1)
        }
    }

    func testCustomNavigatorSupportsConditionalRoadmapsAndOnlyFallsBackOnMissingRoute() async throws {
        let organID = "MDVS:ORGN:CUSTOM"
        let roadmapPath = "/api/orgrec/v1/roadmaps/\(organID)"
        let detailPath = "/api/organs/\(organID)"
        let fixture = fixture([
            .init(roadmapPath, json: """
                {"organ":{"mdvsId":"\(organID)","title":"Local organ"},"components":[
                 {"id":"custom-stop","kind":"stop","label":"Flute","detail":{"range":[60,61]}}]}
                """, headers: ["ETag": "\"r1\"", "X-MODAVIS-Release": "2.0"]),
            .init(roadmapPath, status: 304),
            .init(roadmapPath, status: 503),
            .init(roadmapPath, status: 404),
            .init(detailPath, json: """
                {"organ":{"mdvsId":"\(organID)","title":"Local organ"}}
                """),
            .init(detailPath + "/specification", json: """
                {"components":[{"id":"legacy-stop","kind":"stop","label":"Flute","detail":{"range":[60,61]}}]}
                """)
        ])
        let initial = try await fixture.client.fetchRoadmap(baseURL: customURL, organID: organID)
        let profile = try XCTUnwrap(initial)
        XCTAssertEqual(profile.components.map(\.id), ["custom-stop"])
        XCTAssertEqual(profile.snapshot.eTag, "\"r1\"")
        XCTAssertEqual(profile.snapshot.release.requestedRelease, "2.0")

        let unchanged = try await fixture.client.fetchRoadmap(baseURL: customURL, organID: organID, previousETag: profile.snapshot.eTag)
        XCTAssertNil(unchanged)
        XCTAssertEqual(fixture.requests.last?.value(forHTTPHeaderField: "If-None-Match"), "\"r1\"")

        do {
            _ = try await fixture.client.fetchRoadmap(baseURL: customURL, organID: organID)
            XCTFail("HTTP 503 was accepted")
        } catch {
            XCTAssertEqual(fixture.requests.count, 3)
        }
        let legacy = try await fixture.client.fetchRoadmap(baseURL: customURL, organID: organID)
        XCTAssertEqual(legacy?.components.map(\.id), ["legacy-stop"])
        XCTAssertEqual(fixture.requests.count, 6)
    }

    private func fixture(_ responses: [NavigatorHTTPFixture.Response]) -> NavigatorHTTPFixture {
        let fixture = NavigatorHTTPFixture(responses)
        addTeardownBlock { fixture.close() }
        return fixture
    }
}

private final class NavigatorHTTPFixture: @unchecked Sendable {
    struct Response: Sendable {
        let path: String
        let status: Int
        let json: String
        let headers: [String: String]

        init(_ path: String, status: Int = 200, json: String = "", headers: [String: String] = [:]) {
            self.path = path
            self.status = status
            self.json = json
            self.headers = headers
        }
    }

    private let lock = NSLock()
    private var responses: [Response]
    private var recorded: [URLRequest] = []
    private let id = UUID().uuidString
    private let session: URLSession
    let client: NavigatorClient

    init(_ responses: [Response]) {
        self.responses = responses
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NavigatorFixtureProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Navigator-Test": id]
        session = URLSession(configuration: configuration)
        client = NavigatorClient(session: session)
        NavigatorFixtureProtocol.register(self, for: id)
    }

    var requests: [URLRequest] { lock.withLock { recorded } }

    func respond(to request: URLRequest) -> Response? {
        lock.withLock {
            recorded.append(request)
            guard let response = responses.first, response.path == request.url?.path else {
                XCTFail("Unexpected Navigator request \(request.url?.absoluteString ?? "")")
                return nil
            }
            responses.removeFirst()
            return response
        }
    }

    func close() {
        session.invalidateAndCancel()
        NavigatorFixtureProtocol.register(nil, for: id)
    }
}

private final class NavigatorFixtureProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var fixtures: [String: NavigatorHTTPFixture] = [:]

    static func register(_ fixture: NavigatorHTTPFixture?, for id: String) {
        lock.withLock { fixtures[id] = fixture }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let id = request.value(forHTTPHeaderField: "X-Navigator-Test") ?? ""
        let fixture = Self.lock.withLock { Self.fixtures[id] }
        guard let url = request.url, let response = fixture?.respond(to: request),
              let http = HTTPURLResponse(url: url, statusCode: response.status, httpVersion: "HTTP/1.1", headerFields: response.headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}
