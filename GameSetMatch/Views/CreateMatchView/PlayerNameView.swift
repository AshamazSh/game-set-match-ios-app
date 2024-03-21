//
//  PlayerNameView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 20/3/24.
//

import SwiftUI

struct PlayerNameViewModel {
    let name: String
    let shortName: String
    
    init(name: String, shortName: String) {
        self.name = name
        self.shortName = shortName
    }
    
    init(player: Player) {
        self.name = player.name
        self.shortName = player.shortName
    }
    
    init(matchPlayer: MatchPlayer) {
        self.name = matchPlayer.name
        self.shortName = matchPlayer.shortName
    }
}

struct PlayerNameView: View {
    let viewModel: PlayerNameViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.name)
            Text(viewModel.shortName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PlayerNameView(viewModel: PlayerNameViewModel(name: "James Hunt", shortName: "HUN"))
}
