//
//  CoreDataManager.swift
//  GameSetMatch
//
//  Created by Ashamaz on 5/3/24.
//

import CoreData

class CoreDataManager: ObservableObject {
    enum CoreDataManagerError: Error, LocalizedError {
        case unknownError
        case saveFailed
        case deleteFailed
        case fetchFailed
        case objectCreationFailed
        
        var errorDescription: String? {
            switch self {
            case .unknownError:
                return "Some error occured. Please try again later."
            case .fetchFailed:
                return "Can not fetch objects."
            case .objectCreationFailed:
                return "Can not create object."
            case .saveFailed:
                return "Saving failed."
            case .deleteFailed:
                return "Deleting failed."
            }
        }
    }
    
    private let context: NSManagedObjectContext
    private enum EntityName {
        static let game = "Game"
        static let gamePoint = "GamePoint"
        static let match = "Match"
        static let matchSet = "MatchSet"
        static let player = "Player"
        static let rule = "Rule"
        static let team = "Team"
    }
    private var tennisRule: Rule!
    private var tennis2x2Rule: Rule!
    private var padelRule: Rule!
    
    init(context: NSManagedObjectContext) {
        self.context = context
        fetchOrCreateRules()
    }
    
    private func createTennisRule() {
        guard let rule = NSEntityDescription.insertNewObject(forEntityName: EntityName.rule, into: context) as? Rule else {
            fatalError("Can't create default rule")
        }
        let matchType = MatchType.tennis
        rule.duration = 1
        rule.playMode = matchType.rawValue
        rule.gameTieBreak = GameTieBreak.fullTieBreak.rawValue
        rule.tieBreak = SetTieBreak.fullTieBreak.rawValue
        rule.name = matchType.name
        do {
            try save()
        } catch {
            fatalError("Can't create default rule")
        }
        tennisRule = rule
    }
    
    private func createTennis2x2Rule() {
        guard let rule = NSEntityDescription.insertNewObject(forEntityName: EntityName.rule, into: context) as? Rule else {
            fatalError("Can't create default rule")
        }
        let matchType = MatchType.tennis2x2
        rule.duration = 1
        rule.playMode = matchType.rawValue
        rule.gameTieBreak = GameTieBreak.fullTieBreak.rawValue
        rule.tieBreak = SetTieBreak.fullTieBreak.rawValue
        rule.name = matchType.name
        do {
            try save()
        } catch {
            fatalError("Can't create default rule")
        }
        tennis2x2Rule = rule
    }
    
    private func createPadelRule() {
        guard let rule = NSEntityDescription.insertNewObject(forEntityName: EntityName.rule, into: context) as? Rule else {
            fatalError("Can't create default rule")
        }
        let matchType = MatchType.padel
        rule.duration = 1
        rule.playMode = matchType.rawValue
        rule.gameTieBreak = GameTieBreak.goldenRule.rawValue
        rule.tieBreak = SetTieBreak.fullTieBreak.rawValue
        rule.name = matchType.name
        do {
            try save()
        } catch {
            fatalError("Can't create default rule")
        }
        padelRule = rule
    }
    
    private func fetchOrCreateRules() {
        let request = Rule.fetchRequest()
        request.returnsObjectsAsFaults = false
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Rule.name, ascending: true)]
        guard let fetchedRules = try? context.fetch(request) else {
            createTennisRule()
            createTennis2x2Rule()
            createPadelRule()
            return
        }
        var tennisRule: Rule?
        var tennis2x2Rule: Rule?
        var padelRule: Rule?
        for rule in fetchedRules {
            switch rule.name {
            case MatchType.tennis.name:
                tennisRule = rule
            case MatchType.tennis2x2.name:
                tennis2x2Rule = rule
            case MatchType.padel.name:
                padelRule = rule
            default:
                break
            }
        }
        if tennisRule != nil {
            self.tennisRule = tennisRule
        } else {
            createTennisRule()
        }
        if tennis2x2Rule != nil {
            self.tennis2x2Rule = tennis2x2Rule
        } else {
            createTennis2x2Rule()
        }
        if padelRule != nil {
            self.padelRule = padelRule
        } else {
            createPadelRule()
        }
    }
    
    func createPlayer(_ player: MatchPlayer, autosave: Bool = true) throws -> Player {
        guard let playerObject = NSEntityDescription.insertNewObject(forEntityName: EntityName.player, into: context) as? Player else {
            context.rollback()
            throw CoreDataManagerError.objectCreationFailed
        }
        playerObject.id = player.id
        playerObject.name = player.name
        playerObject.shortName = player.shortName
        if autosave {
            try save()
        }
        
        return playerObject
    }
    
    private func createPlayers(_ players: [MatchPlayer]) throws -> [Player] {
        var result = [Player]()
        for player in players {
            result.append(try createPlayer(player, autosave: false))
        }
        return result
    }
    
    private func createTeam(_ players: [MatchPlayer]) throws -> Team {
        guard let team = NSEntityDescription.insertNewObject(forEntityName: EntityName.team, into: context) as? Team else {
            context.rollback()
            throw CoreDataManagerError.objectCreationFailed
        }
        team.id = UUID()
        try createPlayers(players)
            .forEach { player in
                team.addToPlayers(player)
            }
        return team
    }
    
    private func ruleObject(for type: MatchType) -> Rule {
        switch type {
        case .tennis, .custom:
            return tennisRule
        case .tennis2x2:
            return tennis2x2Rule
        case .padel:
            return padelRule
        }
    }
    
    private func customRuleObject(for customRule: CustomRule) throws -> Rule {
        guard let rule = NSEntityDescription.insertNewObject(forEntityName: EntityName.rule, into: context) as? Rule else {
            throw CoreDataManagerError.objectCreationFailed
        }
        rule.duration = customRule.duration
        rule.playMode = MatchType.custom.rawValue
        rule.gameTieBreak = (customRule.goldenRule
                             ? GameTieBreak.goldenRule
                             : GameTieBreak.fullTieBreak)
        .rawValue
        rule.tieBreak = (customRule.tieBreak
                         ? SetTieBreak.fullTieBreak
                         : SetTieBreak.firstToSix).rawValue
        rule.name = "Custom"
        return rule
    }
    
    private func createMatchSet(createFirstGame: Bool = true) throws -> MatchSet {
        guard let newSet = NSEntityDescription.insertNewObject(forEntityName: EntityName.matchSet, into: context) as? MatchSet else {
            throw CoreDataManagerError.objectCreationFailed
        }
        if createFirstGame {
            newSet.addToGames(try createGame())
        }
        return newSet
    }
    
    private func createGame() throws -> Game {
        guard let newGame = NSEntityDescription.insertNewObject(forEntityName: EntityName.game, into: context) as? Game else {
            throw CoreDataManagerError.objectCreationFailed
        }
        newGame.isTieBreak = false
        return newGame
    }
    
    // TODO: implement thread safety
    func createMatch(
        _ type: MatchType,
        customRule: CustomRule? = nil,
        players1: [MatchPlayer] = [.playerOne, .playerOneB],
        players2: [MatchPlayer] = [.playerTwo, .playerTwoB]
    ) throws -> Match {
        guard let newMatch = NSEntityDescription.insertNewObject(forEntityName: EntityName.match, into: context) as? Match else {
            throw CoreDataManagerError.objectCreationFailed
        }
        newMatch.id = UUID().uuidString
        newMatch.createdAt = Date()
        newMatch.addToTeams(try createTeam(players1))
        newMatch.addToTeams(try createTeam(players2))
        newMatch.addToSets(try createMatchSet())
        if let customRule {
            newMatch.rule = try customRuleObject(for: customRule)
        } else {
            newMatch.rule = ruleObject(for: type)
        }
        try save()
        
        return newMatch
    }
    
    func match(byId id: String) -> Match? {
        let request = Match.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", Match.kId, id)
        return try? context.fetch(request).first
    }
    
    func addNewMatchSet(in match: Match) throws {
        let newSet = try createMatchSet()
        newSet.previousSet = match.sets.lastObject as? MatchSet
        newSet.match = match
        try save()
    }
    
    func addNewGame(in matchSet: MatchSet, isTieBreak: Bool = false) throws {
        let newGame = try createGame()
        newGame.previousGame = matchSet.games.lastObject as? Game
        newGame.inverseMatchSet = matchSet
        newGame.isTieBreak = isTieBreak
        try save()
    }
    
    func addNewPoint(in game: Game, servedBy: Player, wonBy: Team) throws {
        guard let newPoint = NSEntityDescription.insertNewObject(forEntityName: EntityName.gamePoint, into: context) as? GamePoint else {
            throw CoreDataManagerError.objectCreationFailed
        }
        newPoint.servedBy = servedBy
        newPoint.winner = wonBy
        newPoint.previousPoint = game.points.lastObject as? GamePoint
        newPoint.game = game
        try save()
    }
    
    func deleteLastPoint(in match: Match) throws {
        guard let lastSet = match.sets.lastObject as? MatchSet,
              let lastGame = lastSet.games.lastObject as? Game else { return }
        
        if match.winner != nil {
            match.winner?.finalScore -= 1
            match.winner = nil
            lastSet.winner = nil
            lastGame.winner = nil
            if let lastPoint = lastGame.points.lastObject as? GamePoint {
                context.delete(lastPoint)
            }
        } else if lastGame.points.count == 0 {
            if lastSet.games.count == 1 {
                guard match.sets.count > 1 else { return }
                lastSet.previousSet?.winner?.finalScore -= 1
                lastSet.previousSet?.winner = nil
                (lastSet.previousSet?.games.lastObject as? Game)?.winner = nil
                context.delete(lastSet)
                try save()
                try deleteLastPoint(in: match)
            } else {
                lastGame.previousGame?.winner = nil
                context.delete(lastGame)
                try save()
                try deleteLastPoint(in: match)
            }
        } else if let lastPoint = lastGame.points.lastObject as? GamePoint {
            context.delete(lastPoint)
        }
        
        try save()
    }
    
    func matchOver(_ match: Match, withWinner team: Team) throws {
        match.winner = team
        try save()
    }
    
    func replayMatch(_ match: Match) throws -> Match? {
        guard let playMode = MatchType(rawValue: match.rule.playMode) else { return nil }
        var team1 = [MatchPlayer]()
        var team2 = [MatchPlayer]()
        for (index, team) in match.teams.allObjectsOfType(Team.self).enumerated() {
            for player in team.players.allObjectsOfType(Player.self) {
                switch index {
                case 0:
                    team1.append(MatchPlayer(name: player.name, shortName: player.shortName))
                case 1:
                    team2.append(MatchPlayer(name: player.name, shortName: player.shortName))
                default:
                    break
                }
            }
        }
        
        if playMode == .custom {
            let customRule = CustomRule(duration: match.rule.duration,
                                        goldenRule: match.rule.gameTieBreak == GameTieBreak.goldenRule.rawValue,
                                        playMode: CustomRule.PlayMode.double,
                                        tieBreak: match.rule.tieBreak == SetTieBreak.fullTieBreak.rawValue,
                                        matchType: MatchType.custom)
            return try createMatch(.custom, customRule: customRule, players1: team1, players2: team2)
        } else {
            return try createMatch(playMode, players1: team1, players2: team2)
        }
    }
    
    func gameWon(_ game: Game, by team: Team) throws {
        game.winner = team
        try save()
    }
    
    func setWon(_ matchSet: MatchSet, by team: Team) throws {
        matchSet.winner = team
        try save()
    }
    
    func setFinalScore(_ score: Int32, team: Team) throws {
        team.finalScore = score
        try save()
    }
    
    private func save(rollback: Bool = true) throws {
        do {
            try context.save()
        } catch let error {
            print(error.localizedDescription)
            if rollback {
                context.rollback()
            }
            throw CoreDataManagerError.saveFailed
        }
    }
    
    func rollback() {
        context.rollback()
    }
    
    func migrateMatchId(_ match: Match) {
        guard match.id == nil else { return }
        match.id = UUID().uuidString
        try? save()
    }
}
