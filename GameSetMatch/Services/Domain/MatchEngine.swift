import Foundation

/// Value types shared by scoring and persistence. No UI or managed objects.
struct MatchRules: Equatable {
    var bestOf: Int32 = 3
    var deuceRule: DeuceRule = .star
    var superTieBreak = false
    var tieBreak = true

    var isValid: Bool { MatchConfiguration.allowedSets.contains(bestOf) }
    // Legacy even durations require a majority, so a tied match cannot have a winner.
    var setsToWin: Int32 { max(1, bestOf / 2 + 1) }
}

enum MatchEngine {
    /// Counts completed points (not service attempts) and completed games in this set.
    static func shouldChangeSides(completedGames: Int, completedPoints: Int,
                                  isTieBreak: Bool, isSuperTieBreak: Bool,
                                  outcome: Outcome) -> Bool {
        guard !outcome.matchWon else { return false }
        if isTieBreak {
            // A normal tiebreak completes the thirteenth game of the set.
            if outcome.setWon { return !isSuperTieBreak }
            return isSuperTieBreak
                ? completedPoints > 0 && (completedPoints - 1) % 6 == 0
                : completedPoints > 0 && completedPoints % 6 == 0
        }
        return outcome.gameWon && completedGames % 2 == 1
    }

    struct Score: Equatable {
        var first: Int32 = 0
        var second: Int32 = 0
        func value(for team: Int) -> Int32 { team == 0 ? first : second }
        func addingPoint(to team: Int) -> Score {
            team == 0 ? Score(first: first + 1, second: second) : Score(first: first, second: second + 1)
        }
    }

    struct Outcome: Equatable {
        let gameWon: Bool
        let setWon: Bool
        let matchWon: Bool
        let nextGameIsTieBreak: Bool
    }

    static func pointOutcome(team: Int, points: Score, games: Score, sets: Score,
                             isTieBreak: Bool, rules: MatchRules, tieBreakTarget: Int32 = 7) -> Outcome {
        let next = points.addingPoint(to: team)
        let won = next.value(for: team)
        let lost = next.value(for: 1 - team)
        let gameWon = isTieBreak ? won >= tieBreakTarget && won - lost >= 2
            : won >= 4 && (won - lost >= 2 || isDecidingPoint(points, rule: rules.deuceRule))
        let nextGames = games.addingPoint(to: team)
        let setWon = gameWon && (isTieBreak || (nextGames.value(for: team) >= 6 &&
            (!rules.tieBreak || nextGames.value(for: team) - nextGames.value(for: 1 - team) >= 2)))
        return Outcome(gameWon: gameWon, setWon: setWon,
                       matchWon: setWon && sets.value(for: team) + 1 >= rules.setsToWin,
                       nextGameIsTieBreak: gameWon && !setWon && rules.tieBreak && nextGames == Score(first: 6, second: 6))
    }

    static func isDecidingPoint(_ points: Score, rule: DeuceRule) -> Bool {
        guard points.first == points.second else { return false }
        switch rule {
        case .golden: return points.first >= 3
        case .star: return points.first >= 5
        case .advantage: return false
        }
    }

    static func shouldPlaySuperTieBreak(sets: Score, rules: MatchRules) -> Bool {
        rules.superTieBreak && rules.bestOf > 1 && sets.first == sets.second
            && sets.first == rules.setsToWin - 1
    }

    /// A tiebreak counts as one service game when continuing into the next set.
    static func servingPlayer(completedGames: Int, tieBreakPoints: Int? = nil) -> ServingPlayer {
        let offset = tieBreakPoints.map { ($0 + 1) / 2 } ?? 0
        return ServingPlayer(rawValue: (completedGames + offset) % 4) ?? .t1p1
    }

    static func displayPoints(_ score: Score, isTieBreak: Bool) -> (String, String) {
        if isTieBreak { return (String(score.first), String(score.second)) }
        if max(score.first, score.second) > 3 {
            if score.first == score.second { return ("40", "40") }
            return score.first > score.second ? ("AD", "-") : ("-", "AD")
        }
        let labels = ["0", "15", "30", "40"]
        return (labels[Int(score.first)], labels[Int(score.second)])
    }
}
