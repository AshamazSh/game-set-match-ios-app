import XCTest
import Combine
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

    @MainActor func testSideChangeNotificationsIgnoreCachedExpiredAndDuplicateEvents() throws {
        let manager = WatchConnectivityManager(activate: false)
        var state = MatchState.empty
        state.isCompleted = false
        state.sideChangeEvent = SideChangeEvent()
        func packet(_ version: Int) throws -> [String: Any] {
            ["request": AppRequest.newState.rawValue, "snapshotVersion": version,
             "object": try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))]
        }
        var notifications = 0
        let subscription = manager.$sideChangeEvent.compactMap { $0 }.sink { _ in notifications += 1 }
        defer { subscription.cancel() }
        manager.processMessage(try packet(1), live: false)
        XCTAssertNil(manager.sideChangeEvent)
        manager.processMessage(try packet(1))
        XCTAssertEqual(notifications, 1)
        manager.processMessage(try packet(1))
        manager.processMessage(try packet(1), live: false)
        XCTAssertEqual(notifications, 1)
        state.sideChangeEvent = SideChangeEvent(createdAt: Date(timeIntervalSinceNow: -60))
        manager.processMessage(try packet(2))
        XCTAssertEqual(notifications, 1)
        state.sideChangeEvent = SideChangeEvent()
        manager.processMessage(try packet(1)) // stale snapshot, fresh event
        XCTAssertEqual(notifications, 1)
        manager.processMessage(try packet(3))
        XCTAssertEqual(notifications, 2)
        state.sideChangeEvent = nil // undo / ordinary point
        manager.processMessage(try packet(4))
        XCTAssertNil(manager.sideChangeEvent)
    }

    @MainActor func testFirstServerSelectionSnapshotsAndLegacyFallback() throws {
        let manager = WatchConnectivityManager(activate: false)
        var state = MatchState.empty
        state.isCompleted = false
        state.requiresFirstServerSelection = true
        func packet(_ version: Int) throws -> [String: Any] {
            ["request": AppRequest.newState.rawValue, "snapshotVersion": version,
             "object": try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))]
        }
        manager.processMessage(try packet(1))
        XCTAssertTrue(manager.matchState?.isAwaitingFirstServer == true)
        let pending = try packet(1)
        state.requiresFirstServerSelection = false
        state.firstServingTeam = 1
        manager.processMessage(try packet(2))
        manager.processMessage(pending)
        XCTAssertFalse(manager.matchState?.isAwaitingFirstServer == true)
        XCTAssertEqual(manager.matchState?.firstServingTeam, 1)
        state.requiresFirstServerSelection = nil
        state.firstServingTeam = nil
        manager.processMessage(try packet(3))
        XCTAssertFalse(manager.matchState?.isAwaitingFirstServer == true)
    }

}
