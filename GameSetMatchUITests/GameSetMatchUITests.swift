import XCTest

final class GameSetMatchUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testConfigurationDefaultsFormatAndDecidingSet() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let format = app.buttons["matchFormat"]
        XCTAssertTrue(format.waitForExistence(timeout: 5))
        XCTAssertTrue(format.label.contains("1×1"), format.debugDescription)
        XCTAssertTrue(app.buttons["matchSets"].label.contains("3"), app.buttons["matchSets"].debugDescription)
        XCTAssertTrue(app.buttons["deuceRule"].label.contains("Star point"), app.buttons["deuceRule"].debugDescription)
        XCTAssertTrue(app.buttons["decidingSet"].label.contains("Normal set"), app.buttons["decidingSet"].debugDescription)
        XCTAssertTrue(app.staticTexts["Two rounds of advantage. At the third deuce, the next point wins the game."].exists)
        XCTAssertFalse(app.switches["notifySideChanges"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Default match configuration"
        attachment.lifetime = .keepAlways
        add(attachment)
        format.tap()
        app.buttons["2×2"].tap()
        XCTAssertTrue(app.staticTexts["Player 1B"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Player 2B"].exists)
        app.swipeDown()
        app.buttons["decidingSet"].tap()
        app.buttons["Super tiebreak"].tap()
        XCTAssertTrue(app.staticTexts["At equal sets, play the deciding set as a tiebreak to 10, with a two-point lead."].exists)
        app.buttons["matchSets"].tap()
        app.buttons["1"].tap()
        XCTAssertFalse(app.buttons["decidingSet"].isEnabled)
        XCTAssertTrue(app.buttons["decidingSet"].label.contains("Normal set"), app.buttons["decidingSet"].debugDescription)
        app.buttons["deuceRule"].tap()
        app.buttons["Golden point"].tap()
        XCTAssertTrue(app.staticTexts["At 40:40, the next point wins the game."].exists)
        app.buttons["Create"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.buttons["0"].firstMatch.waitForExistence(timeout: 5))
    }
    private func statisticsApp(finished: Bool = false, doubles: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-statistics-fixture", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if finished { app.launchArguments.append("--ui-statistics-finished") }
        if doubles { app.launchArguments.append("--ui-statistics-doubles") }
        app.launch()
        XCTAssertTrue(app.buttons["matchDetails"].waitForExistence(timeout: 5))
        app.buttons["matchDetails"].tap()
        return app
    }

    private func choose(_ mode: String, in app: XCUIApplication) {
        app.buttons["matchDetailsMenu"].tap()
        app.buttons[mode].tap()
    }

    private func assertPeriod(_ title: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let period = app.staticTexts["statisticsPeriod"]
        let matches = NSPredicate(format: "label == %@", title)
        expectation(for: matches, evaluatedWith: period)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(period.label, title, file: file, line: line)
    }

    func testStatisticsOpensViewedSetAndArrowsVisitWholeMatchThenSets() {
        let app = statisticsApp()
        app.buttons["Next set"].tap() // Score now shows set 2.
        choose("Stats", in: app)
        assertPeriod("Set 2", in: app)
        XCTAssertFalse(app.buttons["Next set"].isEnabled)
        app.buttons["Previous set"].tap()
        assertPeriod("Set 1", in: app)
        app.buttons["Previous set"].tap()
        assertPeriod("Whole match", in: app)
        XCTAssertFalse(app.buttons["Previous set"].isEnabled)
        app.buttons["Next set"].tap()
        assertPeriod("Set 1", in: app)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Statistics for set 1"
        attachment.lifetime = .keepAlways
        add(attachment)
        choose("Score", in: app)
        XCTAssertFalse(app.buttons["Next set"].isEnabled) // Score retained set 2.
        choose("Stats", in: app)
        assertPeriod("Set 2", in: app)
    }

    func testFinishedMatchAlwaysOpensWholeMatchStatistics() {
        let app = statisticsApp(finished: true)
        app.buttons["Next set"].tap()
        choose("Stats", in: app)
        assertPeriod("Whole match", in: app)
        XCTAssertFalse(app.buttons["Previous set"].isEnabled)
        app.buttons["Next set"].tap()
        assertPeriod("Set 1", in: app)
        app.buttons["Next set"].tap()
        assertPeriod("Set 2", in: app)
        XCTAssertFalse(app.buttons["Next set"].isEnabled)
        choose("Score", in: app)
        choose("Stats", in: app)
        assertPeriod("Whole match", in: app)
    }

    func testDoublesPlayersShowOnlyPersonalServiceMetrics() {
        let app = statisticsApp(doubles: true)
        choose("Stats", in: app)
        XCTAssertTrue(app.staticTexts["Break points"].firstMatch.waitForExistence(timeout: 5))
        app.segmentedControls["statisticsParticipants"].buttons["Players"].tap()
        XCTAssertTrue(app.staticTexts["Own serve"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Serve from right"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Serve from left"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Break points"].exists)
        XCTAssertFalse(app.staticTexts["Mini-breaks"].exists)
        XCTAssertFalse(app.staticTexts["Games from 40:40"].exists)
        app.segmentedControls["statisticsParticipants"].buttons["Teams"].tap()
        XCTAssertTrue(app.staticTexts["Break points"].firstMatch.exists)
    }

}
