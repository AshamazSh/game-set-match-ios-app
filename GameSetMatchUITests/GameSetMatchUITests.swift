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
}
