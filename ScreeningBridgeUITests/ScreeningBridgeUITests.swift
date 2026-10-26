import XCTest

final class ScreeningBridgeUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ preview: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-demo-data"] + (preview.map { ["--preview=\($0)"] } ?? []) + extra
        app.launch()
        return app
    }

    func testCompleteScreeningFlowAndPersistence() {
        let app = launch()
        app.buttons["newScreening"].tap()
        app.buttons["filmPerfectDays"].tap()
        app.buttons["continueFilm"].tap()
        app.buttons["findPartners"].tap()
        XCTAssertTrue(app.buttons["select-books"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["buildPlan"].isEnabled)
        app.buttons["select-books"].tap()
        app.buttons["select-records"].tap()
        XCTAssertEqual(app.staticTexts["selectionCount"].label, "2 selected")
        app.buttons["buildPlan"].tap()
        app.buttons["savePlan"].tap()
        XCTAssertTrue(app.staticTexts["planSavedHeading"].waitForExistence(timeout: 5))
        app.buttons["closeSaved"].tap()
        XCTAssertTrue(app.buttons["savedScreening"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        XCTAssertTrue(app.buttons["savedScreening"].waitForExistence(timeout: 3))
    }

    func testSelectionCanReturnToZero() {
        let app = launch("partners")
        app.buttons["select-books"].tap()
        XCTAssertTrue(app.buttons["buildPlan"].isEnabled)
        app.buttons["select-books"].tap()
        XCTAssertFalse(app.buttons["buildPlan"].isEnabled)
        XCTAssertEqual(app.staticTexts["selectionCount"].label, "0 selected")
    }

    func testFailedSavePreservesPlanAndRetrySucceeds() {
        let app = launch("plan", extra: ["--fail-next-save"])
        app.buttons["savePlan"].tap()
        XCTAssertTrue(app.staticTexts["Couldn’t Save Plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Chapter House Books"].exists)
        app.buttons["savePlan"].tap()
        XCTAssertTrue(app.staticTexts["planSavedHeading"].waitForExistence(timeout: 5))
    }

    func testIntroductionCopyAndDiscard() {
        let app = launch("plan")
        app.buttons["introduction-books"].tap()
        XCTAssertTrue(app.textViews["messageEditor"].waitForExistence(timeout: 3))
        app.buttons["copyMessage"].tap()
        XCTAssertTrue(app.buttons["copyMessage"].label.contains("Copied"))
        let editor = app.textViews["messageEditor"]
        editor.tap()
        editor.typeText(" Added note.")
        app.buttons["cancelIntroduction"].tap()
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 3))
        app.buttons["Discard Changes"].tap()
        XCTAssertTrue(app.buttons["introduction-books"].waitForExistence(timeout: 3))
        app.buttons["introduction-books"].tap()
        XCTAssertFalse((app.textViews["messageEditor"].value as? String ?? "").contains("Added note"))
    }

    func testSearchRetryReturnsToResults() {
        let app = launch("search-error")
        app.buttons["recoverSearch"].tap()
        XCTAssertTrue(app.buttons["select-books"].waitForExistence(timeout: 8))
    }
}
