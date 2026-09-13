//
//  Enums.swift
//  GameSetMatch
//
//  Created by Ashamaz on 8/3/24.
//

import Foundation

enum LayoutDirection: CaseIterable {
    case vertical
    case horizontal
    
    var isVertical: Bool {
        self == .vertical
    }
    
    var isHorizontal: Bool {
        self == .horizontal
    }
}

enum MatchType: Int32, CaseIterable, Hashable, Identifiable {
    var id: Self { self }

    case tennis = 1
    case tennis2x2
    case padel
    case custom
    
    var name: String {
        switch self {
        case .tennis:
            return String(localized: "Tennis")
        case .tennis2x2:
            return String(localized: "Tennis 2x2")
        case .padel:
            return String(localized: "Padel")
        case .custom:
            return String(localized: "Custom")
        }
    }
}

enum SetTieBreak: Int32 {
    case firstToSix = 1
    case fullTieBreak
}

enum GameTieBreak: Int32 {
    case goldenRule = 1
    case fullTieBreak
}

enum ServingPlayer: Int, CaseIterable {
    case t1p1 = 0
    case t2p1
    case t1p2
    case t2p2
}

enum AppRequest: String, CaseIterable, Identifiable {
    var id: String {
        self.rawValue
    }
    
    case createMatch
    case createTennisMatch
    case createTennis2x2Match
    case createPadelMatch
    case undo
    case teamAScored
    case teamBScored
    case teamAServesFirst
    case teamBServesFirst
    case endMatch
    
    case newState
    case resetMatch
    case currentStatus
    case ignored
    
    var isWatchRequest: Bool {
        switch self {
        case .createMatch, .createTennisMatch,
                .createTennis2x2Match,
                .createPadelMatch,
                .undo,
                .teamAScored,
                .teamBScored,
                .teamAServesFirst,
                .teamBServesFirst,
                .endMatch,
                .currentStatus:
            return true
        case .newState,
                .resetMatch,
                .ignored:
            return false
        }
    }
}

/// Stable stored/wire values, independent of translated labels.
enum MatchFormat: String, CaseIterable, Codable, Identifiable {
    case singles, doubles
    var id: Self { self }
    var title: String { self == .singles ? "1×1" : "2×2" }
    var playerCount: Int { self == .singles ? 1 : 2 }
}

enum DeuceRule: String, CaseIterable, Codable, Identifiable {
    case star, golden, advantage
    var id: Self { self }
    var decidingPointScore: String { self == .star ? "SP" : "40" }
    var title: String {
        switch self {
        case .star: return "Star point"
        case .golden: return "Golden point"
        case .advantage: return "Adv"
        }
    }
    var explanation: String {
        switch self {
        case .star: return String(localized: "Two rounds of advantage. At the third deuce, the next point wins the game.")
        case .golden: return String(localized: "At 40:40, the next point wins the game.")
        case .advantage: return String(localized: "At 40:40, win two consecutive points to win the game.")
        }
    }
}

struct MatchConfiguration: Codable, Equatable {
    var format: MatchFormat = .doubles
    var sets: Int32 = 3
    var superTieBreak = false
    var deuceRule: DeuceRule = .star
    static let allowedSets: [Int32] = [1, 3, 5]
    var isValid: Bool { Self.allowedSets.contains(sets) }
    var decidingSetExplanation: String {
        superTieBreak
            ? String(localized: "At equal sets, play the deciding set as a tiebreak to 10, with a two-point lead.")
            : String(localized: "Play the deciding set normally, with a tiebreak to 7 at 6:6.")
    }
}
