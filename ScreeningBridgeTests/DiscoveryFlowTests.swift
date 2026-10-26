import XCTest
@testable import ScreeningBridge

struct FixtureDiscoveryService: DiscoveryServing {
    func catalog() async throws -> LiveCatalog {
        LiveCatalog(films: [LiveFilm(entityId: "00000000-0000-0000-0000-000000000002", title: "Synthetic Film", year: 2023, director: "Example Director")], venues: [LiveVenue(entityId: "00000000-0000-0000-0000-000000000003", name: "Sample Cinema", address: "Fictional address", coordinates: LiveCoordinates(latitude: 40.7, longitude: -73.9), timezone: "America/New_York")], scope: "Synthetic test fixture")
    }

    func discover(_ request: LiveRequest, onEvent: @escaping @MainActor (LiveEvent) throws -> Void) async throws {
        let url = Bundle(for: DiscoveryFlowTests.self).url(forResource: "DiscoveryFixture", withExtension: "json")!
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        object["request_id"] = request.requestId
        object["brief_revision"] = request.briefRevision
        object["mode"] = "live"
        let event = try LiveDiscoveryClient.decodeEvent(JSONSerialization.data(withJSONObject: object))
        try await onEvent(event)
    }
}

final class DiscoveryFlowTests: XCTestCase {
    @MainActor func testDiscoverySavesEvidenceAndKeepsEditedIntroductionAfterRerun() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ScreeningStore(repository: LocalPlanRepository(directory: directory), discoveryService: FixtureDiscoveryService())
        store.setDiscoveryMode("live")
        await store.loadLiveCatalog()
        store.draft.film = store.liveCatalog!.films[0].film
        store.path = [.details, .research]
        await store.runSearch()
        XCTAssertEqual(store.visiblePartners.map(\.name), ["Sample Studio"])
        let partner = try XCTUnwrap(store.visiblePartners.first)
        XCTAssertEqual(partner.evidence?.sources.first?.url.host, "example.org")
        store.toggle(partner)
        store.draft.introductions[partner.id] = "My edited text"
        await store.savePlan()
        let reopened = ScreeningStore(repository: LocalPlanRepository(directory: directory), discoveryService: FixtureDiscoveryService())
        reopened.open(try XCTUnwrap(reopened.saved.first))
        XCTAssertEqual(reopened.draft.selectedPartners.first?.evidence?.facts.count, 1)
        XCTAssertEqual(reopened.draft.introduction(for: partner), "My edited text")
        let payload = try XCTUnwrap(reopened.draft.discoveryPayload)
        let wire = try JSONSerialization.jsonObject(with: payload) as! [String: Any]
        let record = (wire["recommendations"] as! [[String: Any]])[0]
        XCTAssertNotNil(record["coordinates"])
        XCTAssertNotNil(record["identity_source_ids"])
        XCTAssertNotNil(wire["unscored_partner_ids"])
        store.path = [.details, .research]
        store.applyFilters(radius: 5, categories: store.allowedCategories)
        XCTAssertTrue(store.draft.selectedIDs.contains(partner.id))
        await store.runSearch()
        XCTAssertEqual(store.draft.introduction(for: partner), "My edited text")
        store.draft.notes = "A revised brief"
        XCTAssertTrue(store.visiblePartners.isEmpty)
    }
}
