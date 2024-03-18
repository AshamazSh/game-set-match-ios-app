//
//  MatchState.swift
//  GameSetMatch
//
//  Created by Ashamaz on 8/3/24.
//

import Foundation

struct MatchState: Codable {
    struct TeamInfo: Codable {
        struct SetScore: Identifiable, Hashable, Codable {
            var id = UUID()
            var value: String
            var won: Bool
        }
        
        var name: String
        var setScore: [SetScore]
        var points: String
        var players: [MatchPlayer]
        var servingPlayer: MatchPlayer?
        var isMatchWinner: Bool
    }
    
    var team1: TeamInfo
    var team2: TeamInfo
    var isTieBreak: Bool
    var isGoldenPoint: Bool
    var isCompleted: Bool
    
    static let empty = MatchState(team1: TeamInfo(name: "", setScore: [], points: "", players: [], isMatchWinner: false), 
                                  team2: TeamInfo(name: "", setScore: [], points: "", players: [], isMatchWinner: false),
                                  isTieBreak: false,
                                  isGoldenPoint: false,
                                  isCompleted: true)
}
