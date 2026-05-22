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

enum FortyAllRule: Int32, CaseIterable, Identifiable {
    var id: Self { self }
    
    case goldenPoint = 1
    case startPoint
    case advantages
    
    var title: String {
        switch self {
        case .goldenPoint:
            return "Golden point"
        case .startPoint:
            return "Star point"
        case .advantages:
            return "Advantages"
        }
    }
}

enum DeciderSetRule: Int32, CaseIterable, Identifiable {
    var id: Self { self }
    
    case fullSet = 1
    case superTiebreak
    
    var title: String {
        switch self {
        case .fullSet:
            return "Full set"
        case .superTiebreak:
            return "Super tiebreak"
        }
    }
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
    
    case createTennisMatch
    case createTennis2x2Match
    case createPadelMatch
    case undo
    case teamAScored
    case teamBScored
    case endMatch
    
    case newState
    case resetMatch
    case currentStatus
    case ignored
    
    var isWatchRequest: Bool {
        switch self {
        case .createTennisMatch,
                .createTennis2x2Match,
                .createPadelMatch,
                .undo,
                .teamAScored,
                .teamBScored,
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
