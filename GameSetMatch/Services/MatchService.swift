//
//  MatchService.swift
//  GameSetMatch
//
//  Created by Ashamaz on 4/3/24.
//

import Combine
import CoreData

extension ServingPlayer {
    func team1ServingPlayer(players: [Player]) -> Player? {
        switch self {
        case .t1p1:
            return players.first
        case .t2p1:
            return nil
        case .t1p2:
            return players.count > 1 ? players[1] : players.first
        case .t2p2:
            return nil
        }
    }
    
    func team2ServingPlayer(players: [Player]) -> Player? {
        switch self {
        case .t1p1:
            return nil
        case .t2p1:
            return players.first
        case .t1p2:
            return nil
        case .t2p2:
            return players.count > 1 ? players[1] : players.first
        }
    }
    
}

class MatchService: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    @Published var matchState: MatchState? = nil {
        didSet {
            connectivityManager.sendState(matchState)
        }
    }
    @Published var match: Match? {
        didSet {
            matchDidChange()
        }
    }
    private var teams: [Team] {
        match?.teams.allObjectsOfType(Team.self) ?? []
    }
    private var players: [UUID: [MatchPlayer]] {
        var players = [UUID: [MatchPlayer]]()
        for team in teams {
            var current = [MatchPlayer]()
            for player in team.players.allObjectsOfType(Player.self) {
                current.append(MatchPlayer(id: player.id, name: player.name, shortName: player.shortName.uppercased()))
            }
            players[team.id] = current
        }
        
        return players
    }
    private var teamNames: [String] {
        var result = [String]()
        for team in teams {
            if let currentPlayers = players[team.id] {
                result.append(currentPlayers.map { $0.shortName.uppercased() }.joined(separator: " / "))
            }
        }
        return result
    }
    private let coreDataManager: CoreDataManager
    private var pointsFetchedResultsController: NSFetchedResultsController<GamePoint>?
    private let connectivityManager: ConnectivityManager
    private var cancellables = Set<AnyCancellable>()
    private let context: NSManagedObjectContext
    private let displayedMatchIdKey = "com.gamesetmatch.displayedMatchIdKey"
    
    init(context: NSManagedObjectContext, coreDataManager: CoreDataManager, connectivityManager: ConnectivityManager) {
        self.coreDataManager = coreDataManager
        self.connectivityManager = connectivityManager
        self.context = context
        super.init()
        if let matchId = UserDefaults.standard.string(forKey: displayedMatchIdKey) {
            match = coreDataManager.match(byId: matchId)
        } else {
            match = nil
        }
        subscribeToConnectivityManager()
    }
    
    private func subscribeToConnectivityManager() {
        connectivityManager
            .$requestedAction
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] action in
                guard let self else { return }
                defer {
                    self.connectivityManager.sendState(self.matchState)
                    self.connectivityManager.requestedAction = nil
                }
                switch action {
                case .createTennisMatch:
                    guard self.match == nil else { return }
                    self.createMatch(.tennis, players1: [.playerOne], players2: [.playerTwo])
                case .createTennis2x2Match:
                    guard self.match == nil else { return }
                    self.createMatch(.tennis2x2)
                case .createPadelMatch:
                    guard self.match == nil else { return }
                    self.createMatch(.padel)
                case .undo:
                    guard let matchState = self.matchState,
                          !matchState.isCompleted else { return }
                    self.undoLastPoint()
                case .teamAScored:
                    guard let matchState = self.matchState,
                          !matchState.isCompleted else { return }
                    self.pointWonByTeam1()
                case .teamBScored:
                    guard let matchState = self.matchState,
                          !matchState.isCompleted else { return }
                    self.pointWonByTeam2()
                case .endMatch:
                    guard self.matchState != nil else { return }
                    self.matchState = nil
                case .none, .newState, .resetMatch, .ignored, .currentStatus:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    func createMatch(
        _ type: MatchType,
        customRule: CustomRule? = nil,
        players1: [MatchPlayer] = [.playerOne, .playerOneB],
        players2: [MatchPlayer] = [.playerTwo, .playerTwoB]
    ) {
        do {
            match = try coreDataManager.createMatch(type, customRule: customRule, players1: players1, players2: players2)
        } catch {
            coreDataManager.rollback()
        }
    }
    
    func replayMatch(_ match: Match) {
        do {
            self.match = try coreDataManager.replayMatch(match)
        } catch {
            coreDataManager.rollback()
        }
    }
    
    private func matchDidChange() {
        if let match {
            if match.id == nil {
                coreDataManager.migrateMatchId(match)
            }
            UserDefaults.standard.setValue(match.id, forKey: displayedMatchIdKey)
            let fetchRequest = GamePoint.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "%K.%K.%K == %@", GamePoint.kGame, Game.kInverseMatchSet, MatchSet.kMatch, match)
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \GamePoint.objectID, ascending: true)]
            pointsFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: nil)
            pointsFetchedResultsController?.delegate = self
            try? pointsFetchedResultsController?.performFetch()
            calculateCurrentSituation()
        } else {
            UserDefaults.standard.removeObject(forKey: displayedMatchIdKey)
            pointsFetchedResultsController = nil
            matchState = nil
        }
    }
    
    func undoLastPoint() {
        if let match {
            do {
                try coreDataManager.deleteLastPoint(in: match)
            } catch {
                coreDataManager.rollback()
            }
        }
    }
    
    private func matchCurrentScore(in match: Match) -> (Int32, Int32) {
        var team1WonSets: Int32 = 0
        var team2WonSets:Int32 = 0
        for aSet in match.sets.allObjectsOfType(MatchSet.self) {
            if let wonBy = aSet.winner {
                switch teams.firstIndex(of: wonBy) {
                case 0:
                    team1WonSets += 1
                case 1:
                    team2WonSets += 1
                default:
                    break
                }
            }
        }
        
        return (team1WonSets, team2WonSets)
    }
    
    private func teamsSetScore(in matchSet: MatchSet) -> (Int32, Int32) {
        var team1CurrentSetScore: Int32 = 0
        var team2CurrentSetScore: Int32 = 0
        for game in matchSet.games.allObjectsOfType(Game.self) {
            if let wonBy = game.winner {
                switch teams.firstIndex(of: wonBy) {
                case 0:
                    team1CurrentSetScore += 1
                case 1:
                    team2CurrentSetScore += 1
                default:
                    break
                }
            }
        }
        return (team1CurrentSetScore, team2CurrentSetScore)
    }
    
    private func teamsGameScore(in game: Game) -> (Int32, Int32) {
        var team1Score: Int32 = 0
        var team2Score: Int32 = 0
        for point in game.points.allObjectsOfType(GamePoint.self) {
            switch teams.firstIndex(of: point.winner) {
            case 0:
                team1Score += 1
            case 1:
                team2Score += 1
            default:
                break
            }
        }
        
        return (team1Score, team2Score)
    }
    
    private func calculateCurrentSituation() {
        if let match {
            var state = MatchState(team1: MatchState.TeamInfo(name: teamNames[0], setScore: [], points: "", players: players[teams[0].id]!, isMatchWinner: match.winner == teams[0]),
                                   team2: MatchState.TeamInfo(name: teamNames[1], setScore: [], points: "", players: players[teams[1].id]!, isMatchWinner: match.winner == teams[1]),
                                   isTieBreak: false,
                                   isGoldenPoint: false,
                                   isCompleted: match.winner != nil)
            for matchSet in match.sets.allObjectsOfType(MatchSet.self) {
                let (team1CurrentSetScore, team2CurrentSetScore) = teamsSetScore(in: matchSet)
                state.team1.setScore.append(MatchState.TeamInfo.SetScore(value: String(team1CurrentSetScore), won: matchSet.winner == teams[0]))
                state.team2.setScore.append(MatchState.TeamInfo.SetScore(value: String(team2CurrentSetScore), won: matchSet.winner == teams[1]))
            }
            
            guard let lastSet = match.sets.lastObject as? MatchSet,
                  let lastGame = lastSet.games.lastObject as? Game else {
                self.matchState = state
                return
            }
            
            let (team1Score, team2Score) = teamsGameScore(in: lastGame)
            var servedByIndex = match.sets.count - 1
            servedByIndex += lastSet.games.count - 1
            for (number, _) in lastGame.points.allObjectsOfType(GamePoint.self).enumerated() {
                if lastGame.isTieBreak {
                    if number == 0 {
                        servedByIndex += 1
                    } else if number%2 == 0 {
                        servedByIndex += 1
                    }
                }
            }
            
            if match.winner == nil {
                if lastGame.isTieBreak {
                    state.team1.points = String(team1Score)
                    state.team2.points = String(team2Score)
                    state.isGoldenPoint = false
                    state.isTieBreak = true
                } else {
                    state.isGoldenPoint = match.rule.gameTieBreak == GameTieBreak.goldenRule.rawValue && team1Score == 3 && team2Score == 3
                    if max(team1Score, team2Score) > 3 {
                        if team1Score == team2Score {
                            state.team1.points = "40"
                            state.team2.points = "40"
                        } else if team1Score > team2Score {
                            state.team1.points = "AD"
                            state.team2.points = "-"
                        } else {
                            state.team1.points = "-"
                            state.team2.points = "AD"
                        }
                    } else {
                        state.team1.points = pointsString(for: team1Score)
                        state.team2.points = pointsString(for: team2Score)
                    }
                }
                
                servedByIndex = servedByIndex % ServingPlayer.allCases.count
                let servingPlayer = ServingPlayer(rawValue: servedByIndex) ?? .t1p1
                if let player = servingPlayer.team1ServingPlayer(players: teams[0].players.allObjectsOfType(Player.self)) {
                    state.team1.servingPlayer = MatchPlayer(id: player.id, name: player.name, shortName: player.shortName.uppercased())
                }
                if let player = servingPlayer.team2ServingPlayer(players: teams[1].players.allObjectsOfType(Player.self)) {
                    state.team2.servingPlayer = MatchPlayer(id: player.id, name: player.name, shortName: player.shortName.uppercased())
                }
            } else {
                state.team1.points = match.winner == teams[0] ? "🏆" :  "-"
                state.team2.points = match.winner == teams[1] ? "🏆" :  "-"
            }
            
            matchState = state
        }
    }
    
    private func pointsString(for points: Int32) -> String {
        switch points {
        case 0:
            return "0"
        case 1:
            return "15"
        case 2:
            return "30"
        default:
            return "40"
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if controller == pointsFetchedResultsController {
            calculateCurrentSituation()
        }
    }
    
    private func pointWon(byTeamIndex winnerTeamIndex: Int) {
        guard let matchState,
              let match,
              match.winner == nil,
              teams.indices.contains(winnerTeamIndex),
              let lastSet = match.sets.lastObject as? MatchSet,
              let lastGame = lastSet.games.lastObject as? Game else {
            return
        }
        let winnerTeam = teams[winnerTeamIndex]
        
        var (wonTeamScore, lostTeamScore) = teamsGameScore(in: lastGame)
        if winnerTeamIndex == 1 {
            swap(&wonTeamScore, &lostTeamScore)
        }
        wonTeamScore += 1
        let gameIsOver = matchState.isGoldenPoint ||
        (matchState.isTieBreak && wonTeamScore - lostTeamScore > 1 && wonTeamScore > 6) ||
        (!matchState.isTieBreak && wonTeamScore - lostTeamScore > 1 && wonTeamScore > 3)
        if gameIsOver {
            var (wonTeamSetScore, lostTeamSetScore) = teamsSetScore(in: lastSet)
            if winnerTeamIndex == 1 {
                swap(&wonTeamSetScore, &lostTeamSetScore)
            }
            wonTeamSetScore += 1
            let setIsOver = matchState.isTieBreak || wonTeamSetScore > 5 &&
            (wonTeamSetScore - lostTeamSetScore > 1 || match.rule.tieBreak == SetTieBreak.firstToSix.rawValue)
            if setIsOver {
                var (wonTeamTotalSets, lostTeamTotalSets) = matchCurrentScore(in: match)
                if winnerTeamIndex == 1 {
                    swap(&wonTeamTotalSets, &lostTeamTotalSets)
                }
                wonTeamTotalSets += 1
                do {
                    try coreDataManager.setFinalScore(wonTeamTotalSets, team: teams[winnerTeamIndex])
                    try coreDataManager.setFinalScore(lostTeamTotalSets, team: teams[winnerTeamIndex == 1 ? 0 : 1])
                    if wonTeamTotalSets > match.rule.duration - wonTeamTotalSets + lostTeamTotalSets ||
                        match.rule.duration <= wonTeamTotalSets + lostTeamTotalSets {
                        try coreDataManager.matchOver(match, withWinner: winnerTeam)
                    } else {
                        try coreDataManager.addNewMatchSet(in: match)
                    }
                    try coreDataManager.setWon(lastSet, by: winnerTeam)
                } catch {
                    coreDataManager.rollback()
                    return
                }
            } else {
                let nextGameIsTieBreak = match.rule.tieBreak == SetTieBreak.fullTieBreak.rawValue && wonTeamSetScore == 6 && lostTeamSetScore == 6
                
                do {
                    try coreDataManager.addNewGame(in: lastSet, isTieBreak: nextGameIsTieBreak)
                } catch {
                    coreDataManager.rollback()
                    return
                }
            }
            do {
                try coreDataManager.gameWon(lastGame, by: winnerTeam)
            } catch {
                coreDataManager.rollback()
                return
            }
        }
        
        guard let servingPlayer = currentServingPlayer(in: matchState) else { return }
        do {
            try coreDataManager.addNewPoint(in: lastGame, servedBy: servingPlayer, wonBy: winnerTeam)
        } catch {
            coreDataManager.rollback()
        }
    }
    
    func pointWonByTeam1() {
        pointWon(byTeamIndex: 0)
    }
    
    func pointWonByTeam2() {
        pointWon(byTeamIndex: 1)
    }
    
    private func currentServingPlayer(in matchState: MatchState) -> Player? {
        if let servingPlayerId = matchState.team1.servingPlayer?.id {
            return player(inTeam: teams[0], byId: servingPlayerId)
        } else {
            return player(inTeam: teams[1], byId: matchState.team2.servingPlayer?.id)
        }
    }
    
    private func player(inTeam team: Team, byId id: UUID?) -> Player? {
        let players = team.players.allObjectsOfType(Player.self)
        return players.first { $0.id == id } ?? players.first
    }
}
