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
        let event = try LiveDiscoveryClient.decoder().decode(LiveEvent.self, from: JSONSerialization.data(withJSONObject: object))
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
        store.path = [.details, .research]
        await store.runSearch()
        XCTAssertEqual(store.draft.introduction(for: partner), "My edited text")
        store.draft.notes = "A revised brief"
        XCTAssertTrue(store.visiblePartners.isEmpty)
    }
}
