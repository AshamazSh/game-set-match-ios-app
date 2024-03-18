//
//  MatchPlayer.swift
//  GameSetMatch
//
//  Created by Ashamaz on 8/3/24.
//

import Foundation

struct MatchPlayer: Identifiable, Codable {
    let id: UUID
    let name: String
    let shortName: String
    
    init(id: UUID = UUID(), name: String, shortName: String) {
        self.id = id
        self.name = name
        self.shortName = shortName
    }
    
    static let playerA = MatchPlayer(name: "Player A", shortName: "PLA")
    static let playerB = MatchPlayer(name: "Player B", shortName: "PLB")
}
