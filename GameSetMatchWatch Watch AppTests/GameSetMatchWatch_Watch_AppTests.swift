import XCTest
@testable import GameSetMatch

final class GameSetMatchWatch_Watch_AppTests: XCTestCase {
    private func message(version: Int64, points: String = "15") throws -> [String: Any] {
        var state = MatchState.empty
        state.matchID = "match"
        state.revision = version
        state.team1.points = points
        return ["request": AppRequest.newState.rawValue, "snapshotVersion": version,
                "object": try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))]
    }

    @MainActor func testOldSnapshotCannotOverwriteNewScore() throws {
        let manager = WatchConnectivityManager(activate: false)
        manager.processMessage(try message(version: 2, points: "30"))
        manager.processMessage(try message(version: 1))
        XCTAssertEqual(manager.matchState?.team1.points, "30")
    }

    @MainActor func testOldResetCannotCloseNewMatch() throws {
        let manager = WatchConnectivityManager(activate: false)
        manager.processMessage(try message(version: 3))
        manager.processMessage(["request": AppRequest.resetMatch.rawValue, "snapshotVersion": Int64(2)])
        XCTAssertNotNil(manager.matchState)
        manager.processMessage(["request": AppRequest.resetMatch.rawValue, "snapshotVersion": Int64(4)])
        XCTAssertNil(manager.matchState)
        manager.processMessage(try message(version: 3))
        XCTAssertNil(manager.matchState)
    }

    @MainActor func testInvalidPayloadDoesNotEraseLastGoodState() throws {
        let manager = WatchConnectivityManager(activate: false)
        manager.processMessage(["request": AppRequest.newState.rawValue, "object": [:]])
        XCTAssertFalse(manager.didRecieveMatchState)
        manager.processMessage(try message(version: 1))
        manager.processMessage(["request": AppRequest.newState.rawValue, "snapshotVersion": Int64(2), "object": [:]])
        XCTAssertEqual(manager.matchState?.team1.points, "15")
    }
    @MainActor func testNewRuleIndicatorsDecodeWithoutBreakingLegacySnapshots() throws {
        let manager = WatchConnectivityManager(activate: false)
        var state = MatchState.empty
        state.isSuperTieBreak = true
        state.decidingPointRule = .star
        manager.processMessage(["request": AppRequest.newState.rawValue, "snapshotVersion": Int64(1),
            "object": try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))])
        XCTAssertTrue(manager.matchState?.isSuperTieBreak == true)
        XCTAssertEqual(manager.matchState?.decidingPointRule, .star)
        var oldObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(MatchState.empty)) as! [String: Any]
        oldObject.removeValue(forKey: "isSuperTieBreak")
        oldObject.removeValue(forKey: "decidingPointRule")
        manager.processMessage(["request": AppRequest.newState.rawValue, "snapshotVersion": Int64(2), "object": oldObject])
        XCTAssertNil(manager.matchState?.isSuperTieBreak)
        XCTAssertNil(manager.matchState?.decidingPointRule)
    }

}
