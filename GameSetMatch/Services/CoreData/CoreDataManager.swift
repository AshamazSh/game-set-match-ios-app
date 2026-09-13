import CoreData

/// Repository for match commands. Each public mutation has a single commit.
@MainActor
final class CoreDataManager: ObservableObject {
    enum RepositoryError: LocalizedError {
        case invalidMatch, invalidRules
        var errorDescription: String? {
            switch self {
            case .invalidMatch: return String(localized: "The match data is incomplete.")
            case .invalidRules: return String(localized: "Choose 1, 3 or 5 sets.")
            }
        }
    }

    let context: NSManagedObjectContext
    init(context: NSManagedObjectContext) { self.context = context }

    private func transaction<T>(_ operation: () throws -> T) throws -> T {
        do {
            let result = try operation()
            if context.hasChanges { try context.save() }
            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    private func insertPlayer(_ player: MatchPlayer) -> Player {
        let object = Player(entity: NSEntityDescription.entity(forEntityName: "Player", in: context)!, insertInto: context)
        object.id = player.id
        object.name = player.name
        object.shortName = player.shortName
        return object
    }

    func createPlayer(_ player: MatchPlayer) throws -> Player {
        try transaction { insertPlayer(player) }
    }

    private func insertTeam(_ players: [MatchPlayer]) -> Team {
        let team = Team(entity: NSEntityDescription.entity(forEntityName: "Team", in: context)!, insertInto: context)
        team.id = UUID()
        players.forEach { team.addToPlayers(insertPlayer($0)) }
        return team
    }

    private func insertSet(in match: Match) -> MatchSet {
        let set = MatchSet(entity: NSEntityDescription.entity(forEntityName: "MatchSet", in: context)!, insertInto: context)
        set.previousSet = match.sets.lastObject as? MatchSet
        let teams = match.teams.allObjectsOfType(Team.self)
        let wonSets = score(match.sets.allObjectsOfType(MatchSet.self).map(\.winner), teams: teams)
        set.isSuperTieBreak = MatchEngine.shouldPlaySuperTieBreak(sets: wonSets, rules: rules(for: match))
        match.addToSets(set)
        insertGame(in: set, isTieBreak: set.isSuperTieBreak)
        return set
    }

    @discardableResult
    private func insertGame(in set: MatchSet, isTieBreak: Bool = false) -> Game {
        let game = Game(entity: NSEntityDescription.entity(forEntityName: "Game", in: context)!, insertInto: context)
        game.previousGame = set.games.lastObject as? Game
        game.isTieBreak = isTieBreak
        set.addToGames(game)
        return game
    }

    func createMatch(configuration: MatchConfiguration,
                     players1: [MatchPlayer], players2: [MatchPlayer]) throws -> Match {
        guard configuration.isValid else { throw RepositoryError.invalidRules }
        guard players1.count == configuration.format.playerCount,
              players2.count == configuration.format.playerCount else { throw RepositoryError.invalidMatch }
        let rules = MatchRules(bestOf: configuration.sets, deuceRule: configuration.deuceRule,
                               superTieBreak: configuration.superTieBreak)
        return try createMatch(.custom, rules: rules, players1: players1, players2: players2, format: configuration.format)
    }

    /// Compatibility for creation requests from older Watch versions.
    func createMatch(_ type: MatchType,
                     players1: [MatchPlayer] = [.playerOne, .playerOneB],
                     players2: [MatchPlayer] = [.playerTwo, .playerTwoB]) throws -> Match {
        let rules = MatchRules(bestOf: 1, deuceRule: type == .padel ? .golden : .advantage)
        return try createMatch(type, rules: rules, players1: players1, players2: players2)
    }

    private func createMatch(_ type: MatchType, rules: MatchRules,
                             players1: [MatchPlayer], players2: [MatchPlayer], format: MatchFormat? = nil, allowLegacyRules: Bool = false) throws -> Match {
        guard rules.isValid || allowLegacyRules else { throw RepositoryError.invalidRules }
        guard (1...2).contains(players1.count), players1.count == players2.count else { throw RepositoryError.invalidMatch }
        return try transaction {
            let match = Match(entity: NSEntityDescription.entity(forEntityName: "Match", in: context)!, insertInto: context)
            match.id = UUID().uuidString
            match.createdAt = Date()
            match.addToTeams(insertTeam(players1))
            match.addToTeams(insertTeam(players2))
            let rule = Rule(entity: NSEntityDescription.entity(forEntityName: "Rule", in: context)!, insertInto: context)
            rule.duration = rules.bestOf
            rule.playMode = type.rawValue
            rule.name = String(type.rawValue) // Persistent identity never depends on a translation.
            rule.formatCode = format?.rawValue
            rule.deuceRuleCode = rules.deuceRule.rawValue
            rule.superTieBreak = rules.superTieBreak
            rule.gameTieBreak = (rules.deuceRule == .golden ? GameTieBreak.goldenRule : .fullTieBreak).rawValue
            rule.tieBreak = (rules.tieBreak ? SetTieBreak.fullTieBreak : .firstToSix).rawValue
            match.rule = rule
            _ = insertSet(in: match)
            return match
        }
    }

    func match(byId id: String) throws -> Match? {
        let request = Match.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", Match.kId, id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func rules(for match: Match) -> MatchRules {
        MatchRules(bestOf: match.rule.duration,
                   deuceRule: DeuceRule(rawValue: match.rule.deuceRuleCode ?? "")
                    ?? (match.rule.gameTieBreak == GameTieBreak.goldenRule.rawValue ? .golden : .advantage),
                   superTieBreak: match.rule.superTieBreak,
                   tieBreak: match.rule.tieBreak == SetTieBreak.fullTieBreak.rawValue)
    }

    func score(_ winners: [Team?], teams: [Team]) -> MatchEngine.Score {
        MatchEngine.Score(first: Int32(winners.filter { $0 == teams[0] }.count),
                          second: Int32(winners.filter { $0 == teams[1] }.count))
    }

    func servingPlayer(in match: Match) throws -> Player {
        let teams = match.teams.allObjectsOfType(Team.self)
        guard teams.count == 2 else { throw RepositoryError.invalidMatch }
        let games = match.sets.allObjectsOfType(MatchSet.self).flatMap { $0.games.allObjectsOfType(Game.self) }
        guard let current = games.last else { throw RepositoryError.invalidMatch }
        let server = MatchEngine.servingPlayer(completedGames: games.dropLast().count,
                                               tieBreakPoints: current.isTieBreak ? current.points.count : nil)
        let player = server.team1ServingPlayer(players: teams[0].players.allObjectsOfType(Player.self))
            ?? server.team2ServingPlayer(players: teams[1].players.allObjectsOfType(Player.self))
        guard let player else { throw RepositoryError.invalidMatch }
        return player
    }

    @discardableResult
    func awardPoint(in match: Match, to teamIndex: Int) throws -> Bool {
        guard match.winner == nil else { return false }
        let teams = match.teams.allObjectsOfType(Team.self)
        guard teams.count == 2, teams.indices.contains(teamIndex),
              let set = match.sets.lastObject as? MatchSet,
              let game = set.games.lastObject as? Game else { throw RepositoryError.invalidMatch }
        let server = try servingPlayer(in: match)
        let outcome = MatchEngine.pointOutcome(team: teamIndex,
            points: score(game.points.allObjectsOfType(GamePoint.self).map(\.winner), teams: teams),
            games: score(set.games.allObjectsOfType(Game.self).map(\.winner), teams: teams),
            sets: score(match.sets.allObjectsOfType(MatchSet.self).map(\.winner), teams: teams),
            isTieBreak: game.isTieBreak, rules: rules(for: match), tieBreakTarget: set.isSuperTieBreak ? 10 : 7)
        let changeSides = MatchEngine.shouldChangeSides(
            completedGames: set.games.allObjectsOfType(Game.self).filter { $0.winner != nil }.count + (outcome.gameWon ? 1 : 0),
            completedPoints: game.points.count + 1, isTieBreak: game.isTieBreak,
            isSuperTieBreak: set.isSuperTieBreak, outcome: outcome)
        try transaction {
            let point = GamePoint(entity: NSEntityDescription.entity(forEntityName: "GamePoint", in: context)!, insertInto: context)
            point.servedBy = server
            point.winner = teams[teamIndex]
            point.previousPoint = game.points.lastObject as? GamePoint
            game.addToPoints(point)
            if outcome.gameWon {
                game.winner = teams[teamIndex]
                if outcome.setWon {
                    set.winner = teams[teamIndex]
                    if outcome.matchWon { match.winner = teams[teamIndex] }
                    else { _ = insertSet(in: match) }
                } else {
                    insertGame(in: set, isTieBreak: outcome.nextGameIsTieBreak)
                }
            }
            updateFinalScores(match, teams: teams)
            match.revision += 1
        }
        return changeSides
    }

    func deleteLastPoint(in match: Match) throws {
        let teams = match.teams.allObjectsOfType(Team.self)
        guard teams.count == 2 else { throw RepositoryError.invalidMatch }
        let sets = match.sets.allObjectsOfType(MatchSet.self)
        // Locate the actual last event before changing the object graph.
        guard let set = sets.last(where: { $0.games.allObjectsOfType(Game.self).contains { $0.points.count > 0 } }),
              let game = set.games.allObjectsOfType(Game.self).last(where: { $0.points.count > 0 }),
              let point = game.points.lastObject as? GamePoint else { return }
        try transaction {
            for trailingSet in sets.reversed().prefix(while: { $0 != set }) {
                match.removeFromSets(trailingSet)
                context.delete(trailingSet)
            }
            for trailingGame in set.games.allObjectsOfType(Game.self).reversed().prefix(while: { $0 != game }) {
                set.removeFromGames(trailingGame)
                context.delete(trailingGame)
            }
            game.removeFromPoints(point)
            context.delete(point)
            game.winner = nil
            set.winner = nil
            match.winner = nil
            updateFinalScores(match, teams: teams)
            match.revision += 1
        }
    }

    private func updateFinalScores(_ match: Match, teams: [Team]) {
        let result = score(match.sets.allObjectsOfType(MatchSet.self).map(\.winner), teams: teams)
        teams[0].finalScore = result.first
        teams[1].finalScore = result.second
    }

    func replayMatch(_ match: Match) throws -> Match {
        let teams = match.teams.allObjectsOfType(Team.self)
        guard teams.count == 2, let type = MatchType(rawValue: match.rule.playMode) else { throw RepositoryError.invalidMatch }
        return try createMatch(type, rules: rules(for: match),
            players1: teams[0].players.allObjectsOfType(Player.self).map(\.matchPlayer),
            players2: teams[1].players.allObjectsOfType(Player.self).map(\.matchPlayer),
            format: match.rule.formatCode.flatMap(MatchFormat.init(rawValue:)), allowLegacyRules: true)
    }

    func deleteMatches(_ matches: [Match]) throws {
        try transaction {
            let rules = Set(matches.map(\.rule))
            matches.forEach(context.delete)
            context.processPendingChanges()
            for rule in rules where rule.matches.allObjects.compactMap({ $0 as? Match }).allSatisfy(\.isDeleted) {
                context.delete(rule)
            }
        }
    }

    func migrateMatchId(_ match: Match) throws {
        guard match.id == nil else { return }
        try transaction { match.id = UUID().uuidString }
    }
}
