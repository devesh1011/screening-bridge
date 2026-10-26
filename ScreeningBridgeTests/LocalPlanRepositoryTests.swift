import XCTest
@testable import ScreeningBridge

final class LocalPlanRepositoryTests: XCTestCase {
    private var directory: URL!
    private var repository: LocalPlanRepository!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        repository = LocalPlanRepository(directory: directory)
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    func testPlanAndEditedIntroductionSurviveReload() throws {
        var draft = ScreeningDraft()
        draft.film = .perfectDays
        draft.selectedIDs = ["books", "records"]
        draft.introductions["books"] = "Our edited introduction"
        let plan = SavedScreening(draft: draft, savedAt: Date(timeIntervalSince1970: 100))
        try repository.savePlans([plan])
        let restored = try LocalPlanRepository(directory: directory).loadPlans()
        XCTAssertEqual(restored, [plan])
        XCTAssertEqual(restored[0].draft.introduction(for: SampleContent.partners[0]), "Our edited introduction")
    }

    func testIncompleteDraftSurvivesAndCanBeClearedWithoutDeletingPlans() throws {
        let draft = ScreeningDraft()
        let plan = SavedScreening(draft: draft, savedAt: Date())
        try repository.savePlans([plan])
        try repository.saveDraft(draft)
        XCTAssertEqual(try repository.loadDraft(), draft)
        try repository.clearDraft()
        XCTAssertNil(try repository.loadDraft())
        XCTAssertEqual(try repository.loadPlans().count, 1)
    }

    func testLivePartnerAndEvidenceSurviveReloadWithoutSampleLookup() throws {
        var draft = ScreeningDraft()
        draft.discoveryMode = "live"
        draft.film = .perfectDays
        let partner = Partner(id: "real-partner", name: "A Real Bookshop", category: "Bookshop", image: "", walkingMinutes: 0, distanceMiles: 0.6, rationale: "Discuss a reading.", connection: "A proposed connection.", idea: "A short reading.", activity: "Reading + screening")
        draft.partnerSnapshots = [partner]
        draft.selectedIDs = [partner.id]
        draft.introductions[partner.id] = "My edited introduction."
        draft.researchWarnings = ["Availability is unconfirmed."]
        try repository.savePlans([SavedScreening(draft: draft, savedAt: Date())])
        let restored = try LocalPlanRepository(directory: directory).loadPlans()[0].draft
        XCTAssertEqual(restored.selectedPartners.map(\.name), ["A Real Bookshop"])
        XCTAssertEqual(restored.introduction(for: restored.selectedPartners[0]), "My edited introduction.")
        XCTAssertEqual(restored.researchWarnings, ["Availability is unconfirmed."])
    }

    func testCorruptArchiveIsReportedAndPreserved() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "plans.json")
        let data = Data("invalid archive".utf8)
        try data.write(to: file)
        XCTAssertThrowsError(try repository.loadPlans())
        XCTAssertEqual(try Data(contentsOf: file), data)
    }

    @MainActor func testFailedSaveKeepsDraftAndRetryWritesOnePlan() async throws {
        let store = ScreeningStore(repository: repository)
        store.draft.film = .perfectDays
        store.draft.selectedIDs = ["books"]
        store.failNextSave = true
        await store.savePlan()
        XCTAssertNotNil(store.saveError)
        XCTAssertNil(store.confirmation)
        XCTAssertEqual(store.draft.selectedIDs, ["books"])
        await store.savePlan()
        XCTAssertNil(store.saveError)
        XCTAssertNotNil(store.confirmation)
        await store.savePlan()
        XCTAssertEqual(try repository.loadPlans().count, 1)
    }
}
