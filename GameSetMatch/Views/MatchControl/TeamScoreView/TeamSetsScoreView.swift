//
//  TeamSetsScoreView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 11/3/24.
//

import SwiftUI

struct TeamSetsScoreView: View {
    let setScore: [MatchState.TeamInfo.SetScore]
    let layoutDirection: LayoutDirection
    let onScreen: TeamScoreView.OnScreenPosition
    
    private var contentViews: some View {
        ForEach(setScore) { item in
            Text(item.value)
                .font(.body)
                .foregroundStyle(item.won
                                 ? .green
                                 : .secondary)
        }
    }
    
    var body: some View {
        if layoutDirection.isVertical {
            VStack {
                if onScreen == .topOrLeading {
                    Spacer()
                }
                HStack(spacing: 8) {
                    contentViews
                    Spacer()
                }
                if onScreen == .bottomOrTrailing {
                    Spacer()
                }
            }
        } else {
            HStack {
                if onScreen == .topOrLeading {
                    Spacer()
                }
                VStack(spacing: 8) {
                    contentViews
                    Spacer()
                }
                if onScreen == .bottomOrTrailing {
                    Spacer()
                }
            }
        }
    }
}

#Preview {
    TeamSetsScoreView(setScore: [MatchState.TeamInfo.SetScore(value: "6", won: true), MatchState.TeamInfo.SetScore(value: "3", won: false)],
                      layoutDirection: .horizontal,
                      onScreen: .topOrLeading)
}
