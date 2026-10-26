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

    func testLiveResearchEvidenceEditingAndReopen() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SCREENING_LIVE_UI"] == "1", "Opt-in live API smoke test")
        let app = launch()
        addUIInterruptionMonitor(withDescription: "Local network permission") { alert in
            guard alert.staticTexts.allElementsBoundByIndex.contains(where: { $0.label.lowercased().contains("local network") }) else { return false }
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            if alert.buttons["OK"].exists { alert.buttons["OK"].tap(); return true }
            return false
        }
        app.buttons["newScreening"].tap()
        app.segmentedControls["researchMode"].buttons["Live"].tap()
        app.tap()
        if app.buttons["Retry Connection"].waitForExistence(timeout: 2) { app.buttons["Retry Connection"].tap() }
        XCTAssertTrue(app.buttons["filmPerfectDays"].waitForExistence(timeout: 15))
        app.buttons["filmPerfectDays"].tap()
        app.buttons["continueFilm"].tap()
        app.buttons["findPartners"].tap()
        let select = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'select-' ")).firstMatch
        XCTAssertTrue(select.waitForExistence(timeout: 100))
        let shortlist = XCTAttachment(screenshot: app.screenshot()); shortlist.name = "live-shortlist"; shortlist.lifetime = .keepAlways; add(shortlist)
        app.buttons["whyPlaces"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Qloo' ")).firstMatch.waitForExistence(timeout: 3))
        let evidence = XCTAttachment(screenshot: app.screenshot()); evidence.name = "live-evidence"; evidence.lifetime = .keepAlways; add(evidence)
        app.buttons["closeEvidence"].tap()
        select.tap()
        app.buttons["buildPlan"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'introduction-' ")).firstMatch.tap()
        let editor = app.textViews["messageEditor"]
        editor.tap(); editor.typeText(" We can discuss a small group.")
        app.buttons["saveIntroduction"].tap()
        app.buttons["savePlan"].tap()
        XCTAssertTrue(app.staticTexts["planSavedHeading"].waitForExistence(timeout: 5))
        app.buttons["closeSaved"].tap()
        app.terminate()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["savedScreening"].tap()
        if !app.buttons["View Evidence"].waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(app.buttons["View Evidence"].waitForExistence(timeout: 3))
        let reopened = XCTAttachment(screenshot: app.screenshot()); reopened.name = "live-reopened-plan"; reopened.lifetime = .keepAlways; add(reopened)
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'introduction-' ")).firstMatch.tap()
        XCTAssertTrue((app.textViews["messageEditor"].value as? String ?? "").contains("We can discuss a small group."))
    }
}
