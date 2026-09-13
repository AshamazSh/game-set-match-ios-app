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

    func create(bestOf: Int32 = 1, golden: Bool = false, doubles: Bool = false, deuce: DeuceRule? = nil, superTieBreak: Bool = false) throws -> Match {
        let match = try repository.createMatch(
            configuration: MatchConfiguration(format: doubles ? .doubles : .singles, sets: bestOf,
                superTieBreak: superTieBreak, deuceRule: deuce ?? (golden ? .golden : .advantage)),
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
        XCTAssertTrue(MatchEngine.pointOutcome(team: 1, points: deuce, games: .init(), sets: .init(), isTieBreak: false, rules: .init(bestOf: 1, deuceRule: .golden)).gameWon)
    }

    func testTieBreakNeedsTwoPointLead() {
        XCTAssertFalse(MatchEngine.pointOutcome(team: 0, points: .init(first: 6, second: 6), games: .init(first: 6, second: 6), sets: .init(), isTieBreak: true, rules: .init()).gameWon)
        XCTAssertTrue(MatchEngine.pointOutcome(team: 0, points: .init(first: 7, second: 6), games: .init(first: 6, second: 6), sets: .init(), isTieBreak: true, rules: .init(bestOf: 1)).matchWon)
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

    @MainActor func testNewConfigurationDefaultsAndIndependentOptions() {
        let rules = CustomRule()
        XCTAssertEqual(rules.configuration.format, .singles)
        XCTAssertEqual(rules.configuration.sets, 3)
        XCTAssertEqual(rules.configuration.deuceRule, .star)
        XCTAssertFalse(rules.configuration.superTieBreak)
        rules.configuration.sets = 5
        rules.configuration.format = .doubles
        rules.configuration.superTieBreak = true
        rules.configuration.deuceRule = .golden
        XCTAssertEqual(rules.configuration.sets, 5)
        XCTAssertEqual(rules.configuration.format.playerCount, 2)
        XCTAssertTrue(rules.configuration.superTieBreak)
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
        for count: Int32 in [0, 2, 4, 7, 9] { XCTAssertThrowsError(try h.create(bestOf: count)) }
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
        XCTAssertNil(matches[0].rule.deuceRuleCode)
        XCTAssertNil(matches[0].rule.formatCode)
        XCTAssertFalse(matches[0].rule.superTieBreak)
        XCTAssertEqual(repository.rules(for: matches[0]).deuceRule, .advantage)
        XCTAssertEqual(matches[0].rule, matches[1].rule)
        try repository.deleteMatches([matches[0]])
        XCTAssertEqual(try context.fetch(Match.fetchRequest()).first?.rule.name, "Теннис")
        context.reset()
        try newCoordinator.remove(newStore)
    }
    @MainActor func testStarPointDecidesOnlyAtThirdDeuceAndUndoRestoresIt() throws {
        let h = try Harness(), match = try h.create(deuce: .star)
        for round in 0..<5 {
            h.service.pointWonByTeam1()
            h.service.pointWonByTeam2()
            XCTAssertNil((match.sets.firstObject as? MatchSet)?.games.firstObject.flatMap { ($0 as? Game)?.winner })
            XCTAssertEqual(h.service.matchState?.isGoldenPoint, round == 4)
        }
        XCTAssertEqual(h.service.matchState?.decidingPointRule, .star)
        XCTAssertEqual(h.service.matchState?.team1.points, "40")
        let history = ScoreHistoryViewModel(matchService: h.service)
        guard case .decidingPoint(.star) = history.sections[0].games[0].scores.last else { return XCTFail("Missing Star point label") }
        h.service.pointWonByTeam2()
        XCTAssertEqual((match.sets.firstObject as? MatchSet)?.games.count, 2)
        h.service.undoLastPoint()
        XCTAssertEqual(h.service.matchState?.decidingPointRule, .star)
        h.service.pointWonByTeam1()
        XCTAssertEqual(((match.sets.firstObject as? MatchSet)?.games.firstObject as? Game)?.winner, match.teams.firstObject as? Team)
    }

    @MainActor func testStarPointCanEndOnAdvantageBeforeThirdDeuce() throws {
        let h = try Harness(), match = try h.create(deuce: .star)
        for _ in 0..<3 { h.service.pointWonByTeam1(); h.service.pointWonByTeam2() }
        h.service.pointWonByTeam1()
        XCTAssertEqual(h.service.matchState?.team1.points, "AD")
        h.service.pointWonByTeam1()
        XCTAssertEqual((match.sets.firstObject as? MatchSet)?.games.count, 2)
    }

    @MainActor func testAdvantageHasNoDeuceLimit() throws {
        let h = try Harness(), match = try h.create(deuce: .advantage)
        for _ in 0..<10 { h.service.pointWonByTeam1(); h.service.pointWonByTeam2() }
        XCTAssertFalse(h.service.matchState?.isGoldenPoint ?? true)
        XCTAssertEqual((match.sets.firstObject as? MatchSet)?.games.count, 1)
        h.service.pointWonByTeam1(); h.service.pointWonByTeam1()
        XCTAssertEqual((match.sets.firstObject as? MatchSet)?.games.count, 2)
    }

    @MainActor func testSuperTieBreakStartsAtOneAllAndEndsWithTwoPointLead() throws {
        let h = try Harness(), match = try h.create(bestOf: 3, doubles: true, superTieBreak: true)
        try h.winSet(match, team: 0)
        XCTAssertFalse((match.sets.lastObject as! MatchSet).isSuperTieBreak)
        try h.winSet(match, team: 1)
        h.service.match = match
        let finalSet = match.sets.lastObject as! MatchSet
        XCTAssertTrue(finalSet.isSuperTieBreak)
        XCTAssertEqual(finalSet.games.count, 1)
        XCTAssertTrue(h.service.matchState?.isSuperTieBreak == true)
        // Starts with the next player in the fixed service order after 12 games.
        XCTAssertEqual(try h.repository.servingPlayer(in: match).id, MatchPlayer.playerOne.id)
        for _ in 0..<9 { h.service.pointWonByTeam1(); h.service.pointWonByTeam2() }
        XCTAssertNil(match.winner)
        h.service.pointWonByTeam1() // 10:9 is not a winning margin.
        XCTAssertNil(match.winner)
        h.service.pointWonByTeam1()
        XCTAssertEqual(match.winner, match.teams.firstObject as? Team)
        XCTAssertEqual(h.service.matchState?.team1.setScore.last?.value, "11")
        XCTAssertEqual(h.service.matchState?.team2.setScore.last?.value, "9")
        let history = ScoreHistoryViewModel(matchService: h.service)
        XCTAssertEqual(history.sections.last?.games.last?.finalScore?.0.value, "11")
        XCTAssertEqual(history.sections.last?.games.last?.finalScore?.1.value, "9")
        h.service.undoLastPoint()
        XCTAssertNil(match.winner)
        XCTAssertEqual(h.service.matchState?.team1.points, "10")
        XCTAssertTrue(finalSet.isSuperTieBreak)
        h.service.pointWonByTeam1()
        XCTAssertNotNil(match.winner)
        let replay = try h.repository.replayMatch(match)
        XCTAssertEqual(h.repository.rules(for: replay), h.repository.rules(for: match))
        XCTAssertFalse((replay.sets.firstObject as! MatchSet).isSuperTieBreak)
    }

    @MainActor func testSuperTieBreakCanWinTenZeroAndBoundaryUndoRecreatesIt() throws {
        let h = try Harness(), match = try h.create(bestOf: 3, superTieBreak: true)
        try h.winSet(match, team: 0); try h.winSet(match, team: 1)
        try h.repository.deleteLastPoint(in: match)
        XCTAssertEqual(match.sets.count, 2)
        try h.repository.awardPoint(in: match, to: 1)
        XCTAssertTrue((match.sets.lastObject as! MatchSet).isSuperTieBreak)
        for _ in 0..<7 { try h.repository.awardPoint(in: match, to: 0) }
        XCTAssertNil(match.winner)
        for _ in 0..<3 { try h.repository.awardPoint(in: match, to: 0) }
        XCTAssertNotNil(match.winner)
    }

    @MainActor func testSuperTieBreakAtTwoAllButNotStraightSetsOrSingleSet() throws {
        let h = try Harness(), match = try h.create(bestOf: 5, superTieBreak: true)
        try h.winSet(match, team: 0); try h.winSet(match, team: 1)
        XCTAssertFalse((match.sets.lastObject as! MatchSet).isSuperTieBreak)
        try h.winSet(match, team: 0); try h.winSet(match, team: 1)
        XCTAssertTrue((match.sets.lastObject as! MatchSet).isSuperTieBreak)
        let straight = try h.create(bestOf: 3, superTieBreak: true)
        try h.winSet(straight, team: 0); try h.winSet(straight, team: 0)
        XCTAssertNotNil(straight.winner)
        XCTAssertEqual(straight.sets.count, 2)
        let single = try h.create(bestOf: 1, superTieBreak: true)
        XCTAssertFalse((single.sets.firstObject as! MatchSet).isSuperTieBreak)
        try h.winSet(single, team: 0)
        XCTAssertNotNil(single.winner)
    }

    @MainActor func testWatchCreationCarriesAllFourRulesAndRejectsBadConfiguration() throws {
        let h = try Harness()
        var message = h.command(.createMatch)
        let config = MatchConfiguration(format: .doubles, sets: 5, superTieBreak: true, deuceRule: .star)
        message["configuration"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(config))
        XCTAssertNil(h.receive(message)["error"])
        let match = try XCTUnwrap(h.service.match)
        XCTAssertEqual((match.teams.firstObject as? Team)?.players.count, 2)
        XCTAssertEqual(h.repository.rules(for: match), MatchRules(bestOf: 5, deuceRule: .star, superTieBreak: true))
        h.service.closeMatch()
        var bad = h.command(.createMatch)
        bad["configuration"] = ["format": "doubles", "sets": 7, "superTieBreak": true, "deuceRule": "star"]
        XCTAssertNotNil(h.receive(bad)["error"])
        XCTAssertNil(h.service.match)
    }

    @MainActor func testMigrationV1V2V3PreservesPlayableLegacyDeuceRules() throws {
        for version in ["GameSetMatch", "GameSetMatchV2", "GameSetMatchV3"] {
            for golden in [false, true] {
                try verifyLegacyMigration(version: version, golden: golden)
            }
        }
    }

    @MainActor private func verifyLegacyMigration(version: String, golden: Bool) throws {
        let directory = try XCTUnwrap(Bundle(for: Match.self).url(forResource: "GameSetMatch", withExtension: "momd"))
        let oldModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory.appendingPathComponent("\(version).mom")))
        let newModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: directory))
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        let url = temp.appendingPathComponent("old.sqlite")
        let oldCoordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
        let oldStore = try oldCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let oldContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        oldContext.persistentStoreCoordinator = oldCoordinator
        let match = NSEntityDescription.insertNewObject(forEntityName: "Match", into: oldContext) as! Match
        match.id = "legacy"
        match.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let rule = NSEntityDescription.insertNewObject(forEntityName: "Rule", into: oldContext) as! Rule
        rule.name = "Старые правила"
        rule.playMode = MatchType.custom.rawValue
        rule.duration = 7
        rule.tieBreak = SetTieBreak.firstToSix.rawValue
        rule.gameTieBreak = (golden ? GameTieBreak.goldenRule : .fullTieBreak).rawValue
        if version == "GameSetMatchV3" {
            rule.formatCode = MatchFormat.singles.rawValue
            rule.deuceRuleCode = (golden ? DeuceRule.golden : .advantage).rawValue
            rule.superTieBreak = true
        }
        match.rule = rule
        for index in 0..<2 {
            let team = NSEntityDescription.insertNewObject(forEntityName: "Team", into: oldContext) as! Team
            team.id = UUID()
            let player = NSEntityDescription.insertNewObject(forEntityName: "Player", into: oldContext) as! Player
            player.id = UUID(); player.name = "Player \(index)"; player.shortName = "P\(index)"
            team.addToPlayers(player); match.addToTeams(team)
        }
        let set = NSEntityDescription.insertNewObject(forEntityName: "MatchSet", into: oldContext) as! MatchSet
        let game = NSEntityDescription.insertNewObject(forEntityName: "Game", into: oldContext) as! Game
        match.addToSets(set); set.addToGames(game)
        for index in 0..<6 {
            let point = NSEntityDescription.insertNewObject(forEntityName: "GamePoint", into: oldContext) as! GamePoint
            point.winner = match.teams[index % 2] as! Team
            point.servedBy = (match.teams[0] as! Team).players[0] as! Player
            point.previousPoint = game.points.lastObject as? GamePoint
            game.addToPoints(point)
        }
        try oldContext.save(); oldContext.reset(); try oldCoordinator.remove(oldStore)
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: newModel)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url,
            options: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let repository = CoreDataManager(context: context)
        let restored = try XCTUnwrap(repository.match(byId: "legacy"))
        XCTAssertEqual(restored.createdAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(try context.count(for: GamePoint.fetchRequest()), 6)
        XCTAssertEqual(restored.rule.deuceRuleCode, version == "GameSetMatchV3" ? (golden ? DeuceRule.golden : .advantage).rawValue : nil)
        XCTAssertEqual(restored.rule.formatCode, version == "GameSetMatchV3" ? MatchFormat.singles.rawValue : nil)
        XCTAssertFalse(restored.rule.notifySideChanges)
        XCTAssertEqual(restored.rule.superTieBreak, version == "GameSetMatchV3")
        XCTAssertFalse((restored.sets.firstObject as! MatchSet).isSuperTieBreak)
        let expected = MatchRules(bestOf: 7, deuceRule: golden ? .golden : .advantage, superTieBreak: version == "GameSetMatchV3", tieBreak: false)
        XCTAssertEqual(repository.rules(for: restored), expected)
        XCTAssertEqual(try repository.awardPoint(in: restored, to: 0), golden)
        XCTAssertEqual((restored.sets.firstObject as! MatchSet).games.count, golden ? 2 : 1)
        if !golden { XCTAssertTrue(try repository.awardPoint(in: restored, to: 0)) }
        let replay = try repository.replayMatch(restored)
        XCTAssertEqual(repository.rules(for: replay), expected)
        XCTAssertEqual(replay.rule.duration, 7)
        XCTAssertEqual(replay.rule.formatCode, restored.rule.formatCode)
        context.reset(); try coordinator.remove(store)
    }

    func testSideChangeSchedulesAndMatchCompletion() {
        let point = MatchEngine.Outcome(gameWon: false, setWon: false, matchWon: false, nextGameIsTieBreak: false)
        let game = MatchEngine.Outcome(gameWon: true, setWon: false, matchWon: false, nextGameIsTieBreak: false)
        let finished = MatchEngine.Outcome(gameWon: true, setWon: true, matchWon: true, nextGameIsTieBreak: false)
        for count in 0...25 {
            XCTAssertEqual(MatchEngine.shouldChangeSides(completedGames: 0, completedPoints: count,
                isTieBreak: true, isSuperTieBreak: false, outcome: point), [6, 12, 18, 24].contains(count))
            XCTAssertEqual(MatchEngine.shouldChangeSides(completedGames: 0, completedPoints: count,
                isTieBreak: true, isSuperTieBreak: true, outcome: point), [1, 7, 13, 19, 25].contains(count))
        }
        for count in 1...12 {
            XCTAssertEqual(MatchEngine.shouldChangeSides(completedGames: count, completedPoints: 4,
                isTieBreak: false, isSuperTieBreak: false, outcome: game), count % 2 == 1)
            XCTAssertFalse(MatchEngine.shouldChangeSides(completedGames: count, completedPoints: 4,
                isTieBreak: false, isSuperTieBreak: false, outcome: point))
            XCTAssertFalse(MatchEngine.shouldChangeSides(completedGames: count, completedPoints: 6,
                isTieBreak: true, isSuperTieBreak: false, outcome: finished))
        }
    }

    func testConfigurationIgnoresRetiredNotificationSetting() throws {
        let old = Data(#"{"format":"singles","sets":3,"superTieBreak":false,"deuceRule":"star","notifySideChanges":false}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(MatchConfiguration.self, from: old), MatchConfiguration())
        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(MatchConfiguration())) as! [String: Any]
        XCTAssertNil(object["notifySideChanges"])
    }

    @MainActor func testNotificationOnCommittedOddGameUndoAndReplay() throws {
        let h = try Harness(), match = try h.create()
        for _ in 0..<3 { h.service.pointWonByTeam1(); XCTAssertNil(h.service.sideChangeEvent) }
        h.context.failSave = true
        h.service.pointWonByTeam1()
        XCTAssertNil(h.service.sideChangeEvent)
        h.context.failSave = false
        h.service.pointWonByTeam1()
        let first = try XCTUnwrap(h.service.sideChangeEvent)
        XCTAssertEqual(h.service.matchState?.sideChangeEvent, first)
        h.service.undoLastPoint()
        XCTAssertNil(h.service.sideChangeEvent)
        h.service.pointWonByTeam1()
        XCTAssertNotEqual(h.service.sideChangeEvent?.id, first.id)
        h.service.match = match
        XCTAssertNil(h.service.sideChangeEvent)
        for _ in 0..<4 { h.service.pointWonByTeam1(); XCTAssertNil(h.service.sideChangeEvent) }
        let replay = try h.repository.replayMatch(match)
        h.service.match = replay
        for _ in 0..<4 { h.service.pointWonByTeam1() }
        XCTAssertNotNil(h.service.sideChangeEvent)
    }

    @MainActor func testNotificationsAlwaysEnabledAndWatchCommandDeduplicated() throws {
        let h = try Harness()
        _ = try h.create()
        for _ in 0..<4 { h.service.pointWonByTeam1() }
        XCTAssertNotNil(h.service.sideChangeEvent)
        _ = try h.create()
        for _ in 0..<3 { h.service.pointWonByTeam1() }
        let command = h.command(.teamAScored)
        h.receive(command)
        let event = try XCTUnwrap(h.service.sideChangeEvent)
        h.receive(command)
        XCTAssertEqual(h.service.sideChangeEvent, event)
        h.receive(h.command(.currentStatus))
        XCTAssertEqual(h.service.sideChangeEvent, event)
    }

    @MainActor func testRepositoryTiebreakAndSuperTiebreakNotifications() throws {
        let h = try Harness(), match = try h.create(bestOf: 3)
        for _ in 0..<6 { try h.winGame(match, team: 0); try h.winGame(match, team: 1) }
        for point in 1...12 {
            XCTAssertEqual(try h.repository.awardPoint(in: match, to: point % 2), point % 6 == 0)
        }
        XCTAssertFalse(try h.repository.awardPoint(in: match, to: 0))
        // At 7:6 games the normal set ends with an odd game total.
        XCTAssertTrue(try h.repository.awardPoint(in: match, to: 0))
        let superMatch = try h.create(bestOf: 3, superTieBreak: true)
        try h.winSet(superMatch, team: 0); try h.winSet(superMatch, team: 1)
        for point in 1...18 {
            XCTAssertEqual(try h.repository.awardPoint(in: superMatch, to: point % 2), [1, 7, 13].contains(point))
        }
        XCTAssertTrue(try h.repository.awardPoint(in: superMatch, to: 0)) // point 19
        XCTAssertFalse(try h.repository.awardPoint(in: superMatch, to: 0)) // match over
        XCTAssertNotNil(superMatch.winner)
    }

}
