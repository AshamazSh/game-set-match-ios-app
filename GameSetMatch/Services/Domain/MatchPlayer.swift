//
//  MatchPlayer.swift
//  GameSetMatch
//
//  Created by Ashamaz on 8/3/24.
//

import Foundation

struct MatchPlayer: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let shortName: String
    
    init(id: UUID = UUID(), name: String, shortName: String) {
        self.id = id
        self.name = name
        self.shortName = shortName
    }
    
    static let playerOne = MatchPlayer(name: "Player 1", shortName: "P1")
    static let playerOneB = MatchPlayer(name: "Player 1B", shortName: "P1B")
    static let playerTwo = MatchPlayer(name: "Player 2", shortName: "P2")
    static let playerTwoB = MatchPlayer(name: "Player 2B", shortName: "P2B")
}
