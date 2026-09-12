import Foundation

/// Value types shared by scoring and persistence. No UI or managed objects.
struct MatchRules: Equatable {
    var bestOf: Int32 = 1
    var goldenPoint = false
    var tieBreak = true

    var isValid: Bool { (1...9).contains(bestOf) && bestOf % 2 == 1 }
    // Legacy even durations require a majority, so a tied match cannot have a winner.
    var setsToWin: Int32 { max(1, bestOf / 2 + 1) }
}

enum MatchEngine {
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
                             isTieBreak: Bool, rules: MatchRules) -> Outcome {
        let next = points.addingPoint(to: team)
        let won = next.value(for: team)
        let lost = next.value(for: 1 - team)
        let gameWon = isTieBreak ? won >= 7 && won - lost >= 2
            : won >= 4 && (won - lost >= 2 || rules.goldenPoint)
        let nextGames = games.addingPoint(to: team)
        let setWon = gameWon && (isTieBreak || (nextGames.value(for: team) >= 6 &&
            (!rules.tieBreak || nextGames.value(for: team) - nextGames.value(for: 1 - team) >= 2)))
        return Outcome(gameWon: gameWon, setWon: setWon,
                       matchWon: setWon && sets.value(for: team) + 1 >= rules.setsToWin,
                       nextGameIsTieBreak: gameWon && !setWon && rules.tieBreak && nextGames == Score(first: 6, second: 6))
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
