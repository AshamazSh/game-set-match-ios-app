import Foundation
import CoreData

enum MatchStatistic: String, CaseIterable, Identifiable {
    case serve, serveRight, serveLeft, breakPoints, deuceGames, miniBreaks
    var id: Self { self }
    var title: String {
        switch self {
        case .serve: return String(localized: "Own serve")
        case .serveRight: return String(localized: "Serve from right")
        case .serveLeft: return String(localized: "Serve from left")
        case .breakPoints: return String(localized: "Break points")
        case .deuceGames: return String(localized: "Games from 40:40")
        case .miniBreaks: return String(localized: "Mini-breaks")
        }
    }
    static let personal: [Self] = [.serve, .serveRight, .serveLeft]
}

struct StatisticCount: Equatable {
    var won = 0
    var total = 0
    mutating func record(won: Bool) {
        total += 1
        if won { self.won += 1 }
    }
    var percentage: String {
        guard total > 0 else { return "—" }
        return (Double(won) / Double(total)).formatted(.percent.precision(.fractionLength(0)))
    }
    func hasBetterPercentage(than other: Self) -> Bool {
        guard total > 0, other.total > 0 else { return false }
        return Int64(won) * Int64(other.total) > Int64(other.won) * Int64(total)
    }
}

struct ParticipantStatistics: Identifiable {
    let id: String
    let name: String
    let team: Int
    var counts: [MatchStatistic: StatisticCount] = [:]
    subscript(_ metric: MatchStatistic) -> StatisticCount { counts[metric, default: .init()] }
    mutating func record(_ metric: MatchStatistic, won: Bool) {
        counts[metric, default: .init()].record(won: won)
    }
    mutating func add(_ other: Self) {
        for metric in MatchStatistic.allCases {
            counts[metric, default: .init()].won += other[metric].won
            counts[metric, default: .init()].total += other[metric].total
        }
    }
}

struct MatchStatisticsPage: Identifiable {
    /// Zero is the complete match; subsequent pages are one-based set numbers.
    let id: Int
    var teams: [ParticipantStatistics]
    var players: [ParticipantStatistics]
    var title: String { id == 0 ? String(localized: "Whole match") : String(localized: "Set \(id)") }
    var isDoubles: Bool { players.count > teams.count }
}

/// Pure input: indices refer to participants, independent of managed object identity.
struct StatisticsInput {
    struct Point {
        let server: Int?
        let winningTeam: Int
    }
    struct Game {
        let isTieBreak: Bool
        let winningTeam: Int?
        let points: [Point]
    }
    let teams: [ParticipantStatistics]
    let players: [ParticipantStatistics]
    let sets: [[Game]]
    let rules: MatchRules
}

enum MatchStatisticsCalculator {
    static func pages(for input: StatisticsInput) -> [MatchStatisticsPage] {
        guard input.teams.count == 2 else { return [] }
        var overall = MatchStatisticsPage(id: 0, teams: input.teams, players: input.players)
        var sets: [MatchStatisticsPage] = []
        for (setIndex, games) in input.sets.enumerated() {
            var page = MatchStatisticsPage(id: setIndex + 1, teams: input.teams, players: input.players)
            for game in games {
                var score = MatchEngine.Score()
                var reachedDeuce = false
                for (pointIndex, point) in game.points.enumerated() {
                    // All conditions refer to the score BEFORE this rally was played.
                    let isChoiceOfSide = !game.isTieBreak && MatchEngine.isDecidingPoint(score, rule: input.rules.deuceRule)
                    if let server = point.server, input.players.indices.contains(server) {
                        let servingTeam = input.players[server].team
                        let receivingTeam = 1 - servingTeam
                        let wonServe = point.winningTeam == servingTeam
                        page.teams[servingTeam].record(.serve, won: wonServe)
                        page.players[server].record(.serve, won: wonServe)
                        if !isChoiceOfSide {
                            // Numbering continues across server changes in both kinds of tiebreak.
                            let side: MatchStatistic = pointIndex % 2 == 0 ? .serveRight : .serveLeft
                            page.teams[servingTeam].record(side, won: wonServe)
                            page.players[server].record(side, won: wonServe)
                        }
                        if game.isTieBreak {
                            page.teams[receivingTeam].record(.miniBreaks, won: point.winningTeam == receivingTeam)
                        } else {
                            let couldBreak = MatchEngine.pointOutcome(team: receivingTeam, points: score,
                                games: .init(), sets: .init(), isTieBreak: false, rules: input.rules).gameWon
                            if couldBreak {
                                page.teams[receivingTeam].record(.breakPoints, won: point.winningTeam == receivingTeam)
                            }
                        }
                    }
                    score = score.addingPoint(to: point.winningTeam)
                    if !game.isTieBreak, score.first == score.second, score.first >= 3 {
                        reachedDeuce = true
                    }
                }
                // Count each completed deuce game once, regardless of the number of returns to deuce.
                if reachedDeuce, let winner = game.winningTeam {
                    for team in page.teams.indices { page.teams[team].record(.deuceGames, won: winner == team) }
                }
            }
            if !page.isDoubles {
                // Singles team statistics are also the player's personal statistics.
                for player in page.players.indices {
                    page.players[player].counts = page.teams[page.players[player].team].counts
                }
            }
            for team in overall.teams.indices { overall.teams[team].add(page.teams[team]) }
            for player in overall.players.indices { overall.players[player].add(page.players[player]) }
            sets.append(page)
        }
        return [overall] + sets
    }
}

/// Read-only adapter. Existing history is sufficient; no schema changes or stored counters.
@MainActor
extension MatchStatisticsCalculator {
    static func pages(for match: Match, rules: MatchRules) -> [MatchStatisticsPage] {
        let teams = match.teams.allObjectsOfType(Team.self)
        let players = teams.flatMap { $0.players.allObjectsOfType(Player.self) }
        guard teams.count == 2 else { return [] }
        let teamStatistics = teams.enumerated().map { index, team in
            ParticipantStatistics(id: team.objectID.uriRepresentation().absoluteString,
                name: team.players.allObjectsOfType(Player.self).map(\.name).joined(separator: " / "), team: index)
        }
        let playerStatistics = players.map { player in
            ParticipantStatistics(id: player.objectID.uriRepresentation().absoluteString,
                name: player.name, team: teams[0].players.contains(player) ? 0 : 1)
        }
        let sets = match.sets.allObjectsOfType(MatchSet.self).map { set in
            set.games.allObjectsOfType(Game.self).map { game in
                StatisticsInput.Game(isTieBreak: game.isTieBreak,
                    winningTeam: game.winner.flatMap { teams.firstIndex(of: $0) },
                    points: game.points.allObjectsOfType(GamePoint.self).compactMap { point in
                        guard let winner = teams.firstIndex(of: point.winner) else { return nil }
                        return StatisticsInput.Point(server: players.firstIndex(of: point.servedBy), winningTeam: winner)
                    })
            }
        }
        return pages(for: StatisticsInput(teams: teamStatistics, players: playerStatistics, sets: sets, rules: rules))
    }
}
