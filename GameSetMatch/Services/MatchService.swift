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
                    self.match = nil
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
        if match?.scoringVersion == 2 {
            calculateCurrentSituationV2()
            return
        }
        if let match {
            guard teams.count > 1,
                  teamNames.count > 1,
                  let team1Players = players[teams[0].id],
                  let team2Players = players[teams[1].id] else { return }
            var state = MatchState(team1: MatchState.TeamInfo(name: teamNames[0], setScore: [], points: "", players: team1Players, isMatchWinner: match.winner == teams[0]),
                                   team2: MatchState.TeamInfo(name: teamNames[1], setScore: [], points: "", players: team2Players, isMatchWinner: match.winner == teams[1]),
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
        if match?.scoringVersion == 2 {
            pointWonV2(byTeamIndex: winnerTeamIndex)
            return
        }
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
    
    private var servingSequence: [ServingPlayer] {
        guard teams.count > 1 else { return [.t1p1, .t2p1] }
        let isDoubles = teams[0].players.count > 1 || teams[1].players.count > 1
        return isDoubles ? ServingPlayer.allCases : [.t1p1, .t2p1]
    }
    
    private func servingPlayer(at index: Int) -> ServingPlayer {
        let sequence = servingSequence
        guard !sequence.isEmpty else { return .t1p1 }
        return sequence[index % sequence.count]
    }
    
    private func servingIndexForCurrentGame(in match: Match, lastSet: MatchSet, lastGame: Game) -> Int {
        var serverIndex = 0
        for matchSet in match.sets.allObjectsOfType(MatchSet.self) {
            for game in matchSet.games.allObjectsOfType(Game.self) {
                if game == lastGame {
                    if game.isTieBreak {
                        let pointsCount = game.points.count
                        serverIndex += pointsCount == 0 ? 0 : (pointsCount + 1) / 2
                    }
                    return serverIndex
                }
                if game.winner != nil,
                   !game.isTieBreak {
                    serverIndex += 1
                }
            }
            if matchSet == lastSet {
                break
            }
        }
        return serverIndex
    }
    
    private func currentServingPlayerV2(match: Match, lastSet: MatchSet, lastGame: Game) -> Player? {
        let servingPlayer = servingPlayer(at: servingIndexForCurrentGame(in: match, lastSet: lastSet, lastGame: lastGame))
        switch servingPlayer {
        case .t1p1, .t1p2:
            return servingPlayer.team1ServingPlayer(players: teams[0].players.allObjectsOfType(Player.self))
        case .t2p1, .t2p2:
            return servingPlayer.team2ServingPlayer(players: teams[1].players.allObjectsOfType(Player.self))
        }
    }
    
    private func isSuperTiebreak(_ game: Game, in match: Match) -> Bool {
        game.isTieBreak &&
        match.rule.deciderSetRule == DeciderSetRule.superTiebreak.rawValue &&
        match.rule.duration > 1 &&
        Int32(match.sets.count) == match.rule.duration
    }
    
    private func shouldStartSuperTiebreakAfterCurrentSet(in match: Match, wonTeamTotalSets: Int32, lostTeamTotalSets: Int32) -> Bool {
        match.rule.duration > 1 &&
        match.rule.deciderSetRule == DeciderSetRule.superTiebreak.rawValue &&
        Int32(match.sets.count + 1) == match.rule.duration &&
        wonTeamTotalSets == lostTeamTotalSets
    }
    
    private func gameScoreStringsV2(team1Score: Int32, team2Score: Int32, fortyAllRule: FortyAllRule) -> (String, String, Bool) {
        switch fortyAllRule {
        case .goldenPoint:
            let isGoldenPoint = team1Score == 3 && team2Score == 3
            return (pointsString(for: team1Score), pointsString(for: team2Score), isGoldenPoint)
        case .advantages:
            if max(team1Score, team2Score) > 3 {
                if team1Score == team2Score {
                    return ("40", "40", false)
                } else if team1Score > team2Score {
                    return ("AD", "-", false)
                } else {
                    return ("-", "AD", false)
                }
            }
            return (pointsString(for: team1Score), pointsString(for: team2Score), false)
        case .startPoint:
            if max(team1Score, team2Score) > 3 {
                if team1Score == team2Score {
                    if team1Score == 4 {
                        return ("D2", "D2", false)
                    } else if team1Score >= 5 {
                        return ("SP", "SP", false)
                    }
                    return ("40", "40", false)
                } else if team1Score > team2Score {
                    return ("AD", "-", false)
                } else {
                    return ("-", "AD", false)
                }
            }
            return (pointsString(for: team1Score), pointsString(for: team2Score), false)
        }
    }
    
    private func gameIsOverV2(isTieBreak: Bool, isSuperTiebreak: Bool, fortyAllRule: FortyAllRule, wonTeamScore: Int32, lostTeamScore: Int32) -> Bool {
        if isTieBreak {
            let minimumPoints: Int32 = isSuperTiebreak ? 10 : 7
            return wonTeamScore >= minimumPoints && wonTeamScore - lostTeamScore > 1
        }
        switch fortyAllRule {
        case .goldenPoint:
            return wonTeamScore >= 4 && (wonTeamScore - lostTeamScore > 1 || lostTeamScore == 3)
        case .advantages:
            return wonTeamScore >= 4 && wonTeamScore - lostTeamScore > 1
        case .startPoint:
            return (wonTeamScore >= 4 && wonTeamScore - lostTeamScore > 1) ||
            (wonTeamScore >= 6 && wonTeamScore - lostTeamScore > 0)
        }
    }
    
    private func calculateCurrentSituationV2() {
        guard let match,
              teams.count > 1,
              teamNames.count > 1,
              let team1Players = players[teams[0].id],
              let team2Players = players[teams[1].id] else { return }
        var state = MatchState(team1: MatchState.TeamInfo(name: teamNames[0], setScore: [], points: "", players: team1Players, isMatchWinner: match.winner == teams[0]),
                               team2: MatchState.TeamInfo(name: teamNames[1], setScore: [], points: "", players: team2Players, isMatchWinner: match.winner == teams[1]),
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
            matchState = state
            return
        }
        
        let (team1Score, team2Score) = teamsGameScore(in: lastGame)
        if match.winner == nil {
            if lastGame.isTieBreak {
                state.team1.points = String(team1Score)
                state.team2.points = String(team2Score)
                state.isTieBreak = true
            } else {
                let fortyAllRule = FortyAllRule(rawValue: match.rule.fortyAllRule) ?? .advantages
                let scoreStrings = gameScoreStringsV2(team1Score: team1Score, team2Score: team2Score, fortyAllRule: fortyAllRule)
                state.team1.points = scoreStrings.0
                state.team2.points = scoreStrings.1
                state.isGoldenPoint = scoreStrings.2
            }
            if let player = currentServingPlayerV2(match: match, lastSet: lastSet, lastGame: lastGame) {
                let matchPlayer = MatchPlayer(id: player.id, name: player.name, shortName: player.shortName.uppercased())
                if player.team == teams[0] {
                    state.team1.servingPlayer = matchPlayer
                } else {
                    state.team2.servingPlayer = matchPlayer
                }
            }
        } else {
            state.team1.points = match.winner == teams[0] ? "🏆" : "-"
            state.team2.points = match.winner == teams[1] ? "🏆" : "-"
        }
        matchState = state
    }
    
    private func pointWonV2(byTeamIndex winnerTeamIndex: Int) {
        guard let match,
              match.winner == nil,
              teams.indices.contains(winnerTeamIndex),
              let lastSet = match.sets.lastObject as? MatchSet,
              let lastGame = lastSet.games.lastObject as? Game,
              let servingPlayer = currentServingPlayerV2(match: match, lastSet: lastSet, lastGame: lastGame) else { return }
        let winnerTeam = teams[winnerTeamIndex]
        var (wonTeamScore, lostTeamScore) = teamsGameScore(in: lastGame)
        if winnerTeamIndex == 1 {
            swap(&wonTeamScore, &lostTeamScore)
        }
        wonTeamScore += 1
        
        let isSuperTiebreak = isSuperTiebreak(lastGame, in: match)
        let fortyAllRule = FortyAllRule(rawValue: match.rule.fortyAllRule) ?? .advantages
        let gameIsOver = gameIsOverV2(isTieBreak: lastGame.isTieBreak,
                                      isSuperTiebreak: isSuperTiebreak,
                                      fortyAllRule: fortyAllRule,
                                      wonTeamScore: wonTeamScore,
                                      lostTeamScore: lostTeamScore)
        if gameIsOver {
            var (wonTeamSetScore, lostTeamSetScore) = teamsSetScore(in: lastSet)
            if winnerTeamIndex == 1 {
                swap(&wonTeamSetScore, &lostTeamSetScore)
            }
            wonTeamSetScore += 1
            let setIsOver = lastGame.isTieBreak || (wonTeamSetScore >= 6 && wonTeamSetScore - lostTeamSetScore > 1)
            do {
                if setIsOver {
                    var (wonTeamTotalSets, lostTeamTotalSets) = matchCurrentScore(in: match)
                    if winnerTeamIndex == 1 {
                        swap(&wonTeamTotalSets, &lostTeamTotalSets)
                    }
                    wonTeamTotalSets += 1
                    try coreDataManager.setFinalScore(wonTeamTotalSets, team: teams[winnerTeamIndex])
                    try coreDataManager.setFinalScore(lostTeamTotalSets, team: teams[winnerTeamIndex == 1 ? 0 : 1])
                    if wonTeamTotalSets > match.rule.duration / 2 {
                        try coreDataManager.matchOver(match, withWinner: winnerTeam)
                    } else {
                        let startsWithTieBreak = shouldStartSuperTiebreakAfterCurrentSet(in: match,
                                                                                         wonTeamTotalSets: wonTeamTotalSets,
                                                                                         lostTeamTotalSets: lostTeamTotalSets)
                        try coreDataManager.addNewMatchSet(in: match, startsWithTieBreak: startsWithTieBreak)
                    }
                    try coreDataManager.setWon(lastSet, by: winnerTeam)
                } else {
                    let nextGameIsTieBreak = wonTeamSetScore == 6 && lostTeamSetScore == 6
                    try coreDataManager.addNewGame(in: lastSet, isTieBreak: nextGameIsTieBreak)
                }
                try coreDataManager.gameWon(lastGame, by: winnerTeam)
                try coreDataManager.addNewPoint(in: lastGame, servedBy: servingPlayer, wonBy: winnerTeam)
            } catch {
                coreDataManager.rollback()
            }
        } else {
            do {
                try coreDataManager.addNewPoint(in: lastGame, servedBy: servingPlayer, wonBy: winnerTeam)
            } catch {
                coreDataManager.rollback()
            }
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
