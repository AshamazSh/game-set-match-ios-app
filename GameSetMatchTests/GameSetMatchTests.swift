import XCTest
import CoreData
@testable import GameSetMatch

private final class TestContext: NSManagedObjectContext, @unchecked Sendable {
    var failSave = false
    var saveCount = 0
    override func save() throws {
        saveCount += 1
        if failSave { throw NSError(domain: "InjectedSaveFailure", code: 1) }
        try super.save()
    }
}

@MainActor
private final class Harness {
    let context: TestContext
    let repository: CoreDataManager
    let transport: ConnectivityManager
    let service: MatchService
    let defaults: UserDefaults
    let suite = "GameSetMatchTests.\(UUID().uuidString)"

    init() throws {
        let url = try XCTUnwrap(Bundle(for: Match.self).url(forResource: "GameSetMatch", withExtension: "momd"))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: url))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil)
        context = TestContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        repository = CoreDataManager(context: context)
        defaults = UserDefaults(suiteName: suite)!
        transport = ConnectivityManager(defaults: defaults, activate: false)
        service = MatchService(context: context, coreDataManager: repository, connectivityManager: transport, defaults: defaults)
    }

    func create(bestOf: Int32 = 1, golden: Bool = false, doubles: Bool = false) throws -> Match {
        let match = try repository.createMatch(.custom,
            customRule: CustomRule(duration: bestOf, goldenRule: golden, matchType: .custom),
            players1: doubles ? [.playerOne, .playerOneB] : [.playerOne],
            players2: doubles ? [.playerTwo, .playerTwoB] : [.playerTwo])
        service.match = match
        return match
    }

    func winGame(_ match: Match, team: Int) throws {
        for _ in 0..<4 { try repository.awardPoint(in: match, to: team) }
    }
    func winSet(_ match: Match, team: Int) throws {
        for _ in 0..<6 { try winGame(match, team: team) }
    }
    func command(_ action: AppRequest, id: String = UUID().uuidString) -> [String: Any] {
        var message: [String: Any] = ["request": action.rawValue, "requestID": id]
        message["matchID"] = service.match?.id
        message["revision"] = service.match?.revision
        return message
    }
    @discardableResult
    func receive(_ message: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        transport.receive(message) { result = $0 }
        return result
    }
}

final class GameSetMatchTests: XCTestCase {
    func testDeuceAdvantageAndGoldenPoint() {
        let deuce = MatchEngine.Score(first: 3, second: 3)
        let normal = MatchEngine.pointOutcome(team: 0, points: deuce, games: .init(), sets: .init(), isTieBreak: false, rules: .init())
        XCTAssertFalse(normal.gameWon)
        XCTAssertEqual(MatchEngine.displayPoints(.init(first: 4, second: 3), isTieBreak: false).0, "AD")
        XCTAssertEqual(MatchEngine.displayPoints(.init(first: 4, second: 4), isTieBreak: false).0, "40")
        XCTAssertTrue(MatchEngine.pointOutcome(team: 0, points: .init(first: 4, second: 3), games: .init(), sets: .init(), isTieBreak: false, rules: .init()).gameWon)
        XCTAssertTrue(MatchEngine.pointOutcome(team: 1, points: deuce, games: .init(), sets: .init(), isTieBreak: false, rules: .init(goldenPoint: true)).gameWon)
    }

    func testTieBreakNeedsTwoPointLead() {
        XCTAssertFalse(MatchEngine.pointOutcome(team: 0, points: .init(first: 6, second: 6), games: .init(first: 6, second: 6), sets: .init(), isTieBreak: true, rules: .init()).gameWon)
        XCTAssertTrue(MatchEngine.pointOutcome(team: 0, points: .init(first: 7, second: 6), games: .init(first: 6, second: 6), sets: .init(), isTieBreak: true, rules: .init()).matchWon)
    }

    func testServiceRotationIncludingTieBreak() {
        XCTAssertEqual((0..<7).map { MatchEngine.servingPlayer(completedGames: 12, tieBreakPoints: $0) }, [.t1p1, .t2p1, .t2p1, .t1p2, .t1p2, .t2p2, .t2p2])
        XCTAssertEqual(MatchEngine.servingPlayer(completedGames: 13), .t2p1)
    }

    @MainActor func testBestOfFiveEndsAtThreeOneAndUndoReopens() throws {
        let h = try Harness(), match = try h.create(bestOf: 5)
        try h.winSet(match, team: 0)
        try h.winSet(match, team: 1)
        try h.winSet(match, team: 0)
        XCTAssertNil(match.winner)
        try h.winSet(match, team: 0)
        XCTAssertEqual(match.winner, match.teams.firstObject as? Team)
        XCTAssertEqual(match.sets.count, 4)
        XCTAssertEqual((match.teams.firstObject as? Team)?.finalScore, 3)
        try h.repository.deleteLastPoint(in: match)
        XCTAssertNil(match.winner)
        XCTAssertEqual((match.teams.firstObject as? Team)?.finalScore, 2)
        try h.repository.awardPoint(in: match, to: 0)
        XCTAssertNotNil(match.winner)
    }

    @MainActor func testServiceAfterSixLoveAndSevenFive() throws {
        let h = try Harness(), match = try h.create(bestOf: 3)
        let first = try h.repository.servingPlayer(in: match)
        try h.winSet(match, team: 0)
        XCTAssertEqual(try h.repository.servingPlayer(in: match), first)
        try h.repository.deleteLastPoint(in: match)
        XCTAssertEqual(match.sets.count, 1)
        XCTAssertNotEqual(try h.repository.servingPlayer(in: match), first)
        let other = try h.create(bestOf: 3)
        for _ in 0..<5 { try h.winGame(other, team: 0); try h.winGame(other, team: 1) }
        try h.winGame(other, team: 0); try h.winGame(other, team: 0)
        XCTAssertEqual(other.sets.count, 2)
        XCTAssertEqual(try h.repository.servingPlayer(in: other).id, MatchPlayer.playerOne.id)
    }

    @MainActor func testTieBreakPersistenceAndUndoSetBoundary() throws {
        let h = try Harness(), match = try h.create(bestOf: 3, doubles: true)
        for _ in 0..<6 { try h.winGame(match, team: 0); try h.winGame(match, team: 1) }
        let set = try XCTUnwrap(match.sets.firstObject as? MatchSet)
        let game = try XCTUnwrap(set.games.lastObject as? Game)
        XCTAssertTrue(game.isTieBreak)
        var servers = [UUID]()
        for _ in 0..<7 {
            servers.append(try h.repository.servingPlayer(in: match).id)
            try h.repository.awardPoint(in: match, to: 0)
        }
        XCTAssertEqual(servers, [MatchPlayer.playerOne.id, MatchPlayer.playerTwo.id, MatchPlayer.playerTwo.id,
                                 MatchPlayer.playerOneB.id, MatchPlayer.playerOneB.id, MatchPlayer.playerTwoB.id, MatchPlayer.playerTwoB.id])
        XCTAssertEqual(game.points.allObjectsOfType(GamePoint.self).map { $0.servedBy.id }, servers)
        XCTAssertEqual(try h.repository.servingPlayer(in: match).id, MatchPlayer.playerTwo.id)
        let saves = h.context.saveCount
        try h.repository.deleteLastPoint(in: match)
        XCTAssertEqual(h.context.saveCount, saves + 1)
        XCTAssertEqual(match.sets.count, 1)
        XCTAssertEqual(game.points.count, 6)
        XCTAssertNil(set.winner)
        XCTAssertEqual(try h.repository.servingPlayer(in: match).id, MatchPlayer.playerTwoB.id)
    }

    @MainActor func testPointAndUndoCommitOnceAtGameBoundary() throws {
        let h = try Harness(), match = try h.create()
        for _ in 0..<3 { try h.repository.awardPoint(in: match, to: 0) }
        let saves = h.context.saveCount
        try h.repository.awardPoint(in: match, to: 0)
        XCTAssertEqual(h.context.saveCount, saves + 1)
        let set = try XCTUnwrap(match.sets.firstObject as? MatchSet)
        XCTAssertEqual(set.games.count, 2)
        try h.repository.deleteLastPoint(in: match)
        XCTAssertEqual(h.context.saveCount, saves + 2)
        XCTAssertEqual(set.games.count, 1)
        XCTAssertEqual((set.games.firstObject as? Game)?.points.count, 3)
        XCTAssertNil((set.games.firstObject as? Game)?.winner)
    }

    @MainActor func testSaveFailureRollsBackWholeWinningPoint() throws {
        let h = try Harness(), match = try h.create()
        for _ in 0..<23 { try h.repository.awardPoint(in: match, to: 0) }
        let revision = match.revision
        h.context.failSave = true
        XCTAssertThrowsError(try h.repository.awardPoint(in: match, to: 0))
        XCTAssertNil(match.winner)
        XCTAssertEqual(match.revision, revision)
        XCTAssertEqual(try h.context.count(for: GamePoint.fetchRequest()), 23)
        XCTAssertEqual((match.teams.firstObject as? Team)?.finalScore, 0)
        XCTAssertFalse(h.context.hasChanges)
        h.context.failSave = false
        try h.repository.awardPoint(in: match, to: 0)
        XCTAssertNotNil(match.winner)
    }

    @MainActor func testUndoFailureRestoresSetBoundary() throws {
        let h = try Harness(), match = try h.create(bestOf: 3)
        try h.winSet(match, team: 0)
        h.context.failSave = true
        XCTAssertThrowsError(try h.repository.deleteLastPoint(in: match))
        XCTAssertEqual(match.sets.count, 2)
        XCTAssertEqual(try h.context.count(for: GamePoint.fetchRequest()), 24)
        XCTAssertEqual((match.teams.firstObject as? Team)?.finalScore, 1)
    }

    @MainActor func testDeletingSharedRuleKeepsOtherMatchAndPrunesOrphans() throws {
        let h = try Harness(), a = try h.create(), b = try h.create()
        let originalBRule = b.rule
        b.rule = a.rule // A legacy database shares the same standard rule.
        h.context.delete(originalBRule)
        try h.context.save()
        let shared = b.rule
        try h.repository.deleteMatches([a])
        XCTAssertFalse(shared.isDeleted)
        XCTAssertEqual(b.rule, shared)
        XCTAssertEqual(try h.context.count(for: Match.fetchRequest()), 1)
        try h.repository.deleteMatches([b])
        XCTAssertEqual(try h.context.count(for: Rule.fetchRequest()), 0)
        _ = try h.create()
    }

    @MainActor func testCommandsKeepOrderAndDuplicateDoesNotScoreTwice() throws {
        let h = try Harness()
        _ = try h.create()
        let score = h.command(.teamAScored)
        let first = h.receive(score)
        let status = h.receive(h.command(.currentStatus))
        let duplicate = h.receive(score)
        XCTAssertNil(first["error"])
        XCTAssertNil(status["error"])
        XCTAssertNil(duplicate["error"])
        XCTAssertEqual(h.service.matchState?.team1.points, "15")
        XCTAssertEqual(h.service.match?.revision, 1)
        XCTAssertEqual(try h.context.count(for: GamePoint.fetchRequest()), 1)
    }

    @MainActor func testFailedWatchCommandCanBeRetriedWithoutPartialScore() throws {
        let h = try Harness()
        _ = try h.create()
        let command = h.command(.teamAScored)
        h.context.failSave = true
        XCTAssertNotNil(h.receive(command)["error"])
        XCTAssertEqual(h.service.matchState?.team1.points, "0")
        XCTAssertEqual(try h.context.count(for: GamePoint.fetchRequest()), 0)
        h.context.failSave = false
        XCTAssertNil(h.receive(command)["error"])
        XCTAssertEqual(h.service.matchState?.team1.points, "15")
    }

    @MainActor func testMalformedRequestAlwaysReceivesAnErrorReply() throws {
        let h = try Harness()
        let response = h.receive(["request": "invalid", "requestID": "request"])
        XCTAssertNotNil(response["error"])
        XCTAssertEqual(response["requestID"] as? String, "request")
    }

    @MainActor func testStaleCommandAfterRelaunchIsRejected() throws {
        let h = try Harness(), match = try h.create()
        let command = h.command(.teamAScored)
        h.receive(command)
        let transport = ConnectivityManager(defaults: h.defaults, activate: false)
        let restored = MatchService(context: h.context, coreDataManager: h.repository, connectivityManager: transport, defaults: h.defaults)
        XCTAssertEqual(restored.matchState?.team1.points, "15")
        var response: [String: Any] = [:]
        transport.receive(command) { response = $0 }
        XCTAssertNotNil(response["error"])
        XCTAssertEqual(match.revision, 1)
    }

    @MainActor func testCloseThenCreateFromWatchAndRejectOldMatchCommand() throws {
        let h = try Harness()
        let original = try h.create()
        let oldScore = h.command(.teamAScored)
        XCTAssertNil(h.receive(h.command(.endMatch))["error"])
        XCTAssertNil(h.service.match)
        XCTAssertNil(h.defaults.string(forKey: "com.gamesetmatch.displayedMatchIdKey"))
        XCTAssertNil(h.receive(h.command(.createTennisMatch))["error"])
        XCTAssertNotEqual(h.service.match?.id, original.id)
        XCTAssertNotNil(h.receive(oldScore)["error"])
        XCTAssertEqual(h.service.matchState?.team1.points, "0")
    }

    @MainActor func testHistoryUpdatesFromWatchAndDismissesOnClose() throws {
        let h = try Harness()
        _ = try h.create()
        let history = ScoreHistoryViewModel(matchService: h.service)
        XCTAssertEqual(history.sections.first?.games.first?.scores.count, 0)
        h.receive(h.command(.teamAScored))
        XCTAssertEqual(history.sections.first?.games.first?.scores.count, 1)
        h.receive(h.command(.endMatch))
        XCTAssertTrue(history.dismiss)
    }

    @MainActor func testHistoryUsesRecordedServer() throws {
        let h = try Harness(), match = try h.create()
        h.service.pointWonByTeam1()
        let point = try XCTUnwrap((match.sets.firstObject as? MatchSet)?.games.firstObject as? Game).points.firstObject as! GamePoint
        point.servedBy = (match.teams.lastObject as! Team).players.firstObject as! Player
        try h.context.save()
        let history = ScoreHistoryViewModel(matchService: h.service)
        guard case .servingPlayer(let server) = history.sections[0].games[0].title else { return XCTFail("Missing recorded server") }
        XCTAssertEqual(server?.playerName, MatchPlayer.playerTwo.name.uppercased())
    }

    @MainActor func testHistoryGroupingIgnoresTranslatedRuleNames() throws {
        let h = try Harness(), a = try h.create(), b = try h.create()
        a.rule.name = "Custom"
        b.rule.name = "Свои правила"
        let groups = MatchesHistoryView.groupedMatches([a, b])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].1.count, 2)
    }

    @MainActor func testPresetEditsKeepCustomValuesSynchronously() {
        let rules = CustomRule()
        rules.duration = 5
        XCTAssertEqual(rules.matchType, .custom)
        XCTAssertEqual(rules.duration, 5)
        rules.matchType = .padel
        XCTAssertTrue(rules.goldenRule)
        XCTAssertEqual(rules.duration, 1)
        XCTAssertEqual(rules.playMode, .double)
        rules.goldenRule = false
        XCTAssertEqual(rules.matchType, .custom)
        XCTAssertFalse(rules.goldenRule)
    }

    @MainActor func testGoldenPointPersistsAndUndoRestoresDeuce() throws {
        let h = try Harness(), match = try h.create(golden: true)
        for _ in 0..<3 { try h.repository.awardPoint(in: match, to: 0); try h.repository.awardPoint(in: match, to: 1) }
        h.service.match = match
        XCTAssertTrue(h.service.matchState?.isGoldenPoint == true)
        h.service.pointWonByTeam2()
        XCTAssertEqual((match.sets.firstObject as? MatchSet)?.games.count, 2)
        h.service.undoLastPoint()
        XCTAssertEqual(h.service.matchState?.team1.points, "40")
        XCTAssertTrue(h.service.matchState?.isGoldenPoint == true)
    }

    @MainActor func testInvalidDurationsAreRejected() throws {
        let h = try Harness()
        XCTAssertThrowsError(try h.create(bestOf: 2))
        XCTAssertEqual(try h.context.count(for: Match.fetchRequest()), 0)
    }

    @MainActor func testMigrationFromShippedModelPreservesSharedRules() throws {
        let bundle = Bundle(for: Match.self)
        let directory = try XCTUnwrap(bundle.url(forResource: "GameSetMatch", withExtension: "momd"))
        let oldModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory.appendingPathComponent("GameSetMatch.mom")))
        let newModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory))
        let storeDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }
        let url = storeDirectory.appendingPathComponent("legacy.sqlite")
        let oldCoordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        let oldStore = try oldCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let oldContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        oldContext.persistentStoreCoordinator = oldCoordinator
        let rule = Rule(entity: NSEntityDescription.entity(forEntityName: "Rule", in: oldContext)!, insertInto: oldContext)
        rule.name = "Теннис"
        rule.playMode = MatchType.tennis.rawValue
        for id in ["first", "second"] {
            let match = Match(entity: NSEntityDescription.entity(forEntityName: "Match", in: oldContext)!, insertInto: oldContext)
            match.id = id
            match.createdAt = Date()
            match.rule = rule
        }
        try oldContext.save()
        oldContext.reset()
        try oldCoordinator.remove(oldStore)
        let newCoordinator = NSPersistentStoreCoordinator(managedObjectModel: newModel)
        let newStore = try newCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url,
            options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = newCoordinator
        let repository = CoreDataManager(context: context)
        let matches = try context.fetch(Match.fetchRequest())
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].revision, 0)
        XCTAssertEqual(matches[0].rule, matches[1].rule)
        try repository.deleteMatches([matches[0]])
        XCTAssertEqual(try context.fetch(Match.fetchRequest()).first?.rule.name, "Теннис")
        context.reset()
        try newCoordinator.remove(newStore)
    }
}
