import Combine
import CoreData

extension ServingPlayer {
    func team1ServingPlayer(players: [Player]) -> Player? {
        guard let first = players.first else { return nil }
        switch self {
        case .t1p1: return first
        case .t1p2: return players.count > 1 ? players[1] : first
        default: return nil
        }
    }
    func team2ServingPlayer(players: [Player]) -> Player? {
        guard let first = players.first else { return nil }
        switch self {
        case .t2p1: return first
        case .t2p2: return players.count > 1 ? players[1] : first
        default: return nil
        }
    }
}

/// Owns the active match and publishes only committed snapshots.
@MainActor
final class MatchService: ObservableObject {
    @Published private(set) var matchState: MatchState?
    @Published var match: Match? { didSet { refresh() } }
    @Published var errorMessage: String?
    let coreDataManager: CoreDataManager
    private let connectivityManager: MatchTransport
    private let defaults: UserDefaults
    private let displayedMatchIdKey = "com.gamesetmatch.displayedMatchIdKey"

    init(context: NSManagedObjectContext, coreDataManager: CoreDataManager,
         connectivityManager: MatchTransport, defaults: UserDefaults = .standard) {
        self.coreDataManager = coreDataManager
        self.connectivityManager = connectivityManager
        self.defaults = defaults
        connectivityManager.onCommand = { [weak self] command in
            guard let self else { return }
            do { try self.handle(command) }
            catch {
                self.errorMessage = error.localizedDescription
                throw error
            }
        }
        do {
            if let id = defaults.string(forKey: displayedMatchIdKey) {
                match = try coreDataManager.match(byId: id)
            }
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func perform(_ operation: () throws -> Void) {
        do { try operation() }
        catch { errorMessage = error.localizedDescription }
    }

    func closeMatch() { match = nil }

    private func handle(_ command: WatchCommand) throws {
        // Modern commands target the exact state shown when the user tapped.
        // This also rejects a duplicate after the phone process restarts.
        if command.action != .currentStatus, command.requestID != nil {
            guard command.matchID == match?.id,
                  command.revision == match?.revision else { throw CommandError.staleState }
        }
        switch command.action {
        case .createTennisMatch, .createTennis2x2Match, .createPadelMatch:
            guard match == nil else { throw CommandError.staleState }
            let type: MatchType = command.action == .createTennisMatch ? .tennis
                : command.action == .createPadelMatch ? .padel : .tennis2x2
            match = try coreDataManager.createMatch(type,
                players1: type == .tennis ? [.playerOne] : [.playerOne, .playerOneB],
                players2: type == .tennis ? [.playerTwo] : [.playerTwo, .playerTwoB])
        case .teamAScored, .teamBScored:
            guard let match, match.winner == nil else { throw CommandError.staleState }
            try coreDataManager.awardPoint(in: match, to: command.action == .teamAScored ? 0 : 1)
            refresh()
        case .undo:
            guard let match else { throw CommandError.staleState }
            try coreDataManager.deleteLastPoint(in: match)
            refresh()
        case .endMatch: closeMatch()
        case .currentStatus: break
        default: throw CommandError.invalidRequest
        }
    }

    func undoLastPoint() {
        guard let match else { return }
        perform { try coreDataManager.deleteLastPoint(in: match); refresh() }
    }
    func pointWonByTeam1() { awardPoint(to: 0) }
    func pointWonByTeam2() { awardPoint(to: 1) }
    private func awardPoint(to team: Int) {
        guard let match else { return }
        perform { try coreDataManager.awardPoint(in: match, to: team); refresh() }
    }

    func deleteMatches(_ matches: [Match]) {
        perform {
            let closesActive = match.map { matches.contains($0) } ?? false
            try coreDataManager.deleteMatches(matches)
            if closesActive { closeMatch() }
        }
    }

    private func refresh() {
        guard let match, !match.isDeleted else {
            defaults.removeObject(forKey: displayedMatchIdKey)
            matchState = nil
            connectivityManager.sendState(nil)
            return
        }
        do {
            try coreDataManager.migrateMatchId(match)
            let teams = match.teams.allObjectsOfType(Team.self)
            guard teams.count == 2, teams.allSatisfy({ $0.players.count > 0 }) else {
                throw CoreDataManager.RepositoryError.invalidMatch
            }
            defaults.set(match.id, forKey: displayedMatchIdKey)
            func info(_ team: Team) -> MatchState.TeamInfo {
                let players = team.players.allObjectsOfType(Player.self).map(\.matchPlayer)
                return MatchState.TeamInfo(name: players.map { $0.shortName.uppercased() }.joined(separator: " / "),
                    setScore: [], points: "0", players: players, isMatchWinner: match.winner == team)
            }
            var state = MatchState(team1: info(teams[0]), team2: info(teams[1]),
                isTieBreak: false, isGoldenPoint: false, isCompleted: match.winner != nil)
            state.matchID = match.id
            state.revision = match.revision
            for set in match.sets.allObjectsOfType(MatchSet.self) {
                let score = coreDataManager.score(set.games.allObjectsOfType(Game.self).map(\.winner), teams: teams)
                state.team1.setScore.append(.init(value: String(score.first), won: set.winner == teams[0]))
                state.team2.setScore.append(.init(value: String(score.second), won: set.winner == teams[1]))
            }
            if let set = match.sets.lastObject as? MatchSet, let game = set.games.lastObject as? Game {
                let points = coreDataManager.score(game.points.allObjectsOfType(GamePoint.self).map(\.winner), teams: teams)
                (state.team1.points, state.team2.points) = MatchEngine.displayPoints(points, isTieBreak: game.isTieBreak)
                state.isTieBreak = game.isTieBreak
                state.isGoldenPoint = !game.isTieBreak && coreDataManager.rules(for: match).goldenPoint
                    && points == MatchEngine.Score(first: 3, second: 3)
                if match.winner == nil {
                    let server = try coreDataManager.servingPlayer(in: match)
                    if teams[0].players.contains(server) { state.team1.servingPlayer = server.matchPlayer }
                    else { state.team2.servingPlayer = server.matchPlayer }
                }
            }
            if match.winner != nil {
                state.team1.points = match.winner == teams[0] ? "🏆" : "-"
                state.team2.points = match.winner == teams[1] ? "🏆" : "-"
            }
            matchState = state
            connectivityManager.sendState(state)
        } catch {
            errorMessage = error.localizedDescription
            matchState = nil
            connectivityManager.sendState(nil)
        }
    }
}
