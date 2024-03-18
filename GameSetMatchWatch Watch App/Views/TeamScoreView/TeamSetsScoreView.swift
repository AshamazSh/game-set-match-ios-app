//
//  TeamSetsScoreView.swift
//  GameSetMatchWatch Watch App
//
//  Created by Ashamaz on 11/3/24.
//

import SwiftUI

struct TeamSetsScoreView: View {
    let setScore: [MatchState.TeamInfo.SetScore]
    let onScreen: TeamScoreView.OnScreenPosition
    
    private var contentViews: some View {
        ForEach(setScore) { item in
            Text(item.value)
                .font(.caption)
                .foregroundStyle(item.won
                                 ? .green
                                 : .secondary)
        }
    }
    
    var body: some View {
        VStack {
            if onScreen == .top {
                Spacer()
            }
            HStack(spacing: 8) {
                contentViews
                Spacer()
            }
            if onScreen == .bottom {
                Spacer()
            }
        }
    }
}

#Preview {
    TeamSetsScoreView(setScore: [MatchState.TeamInfo.SetScore(value: "6", won: true), MatchState.TeamInfo.SetScore(value: "3", won: false)],
                      onScreen: .top)
}
