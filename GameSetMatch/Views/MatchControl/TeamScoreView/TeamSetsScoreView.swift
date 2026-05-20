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
    private var scoresSpacing: CGFloat {
        layoutDirection.isVertical ? 12 : 8
    }
    
    private var contentViews: some View {
        ForEach(Array(setScore.enumerated()), id: \.element.id) { index, item in
            let isCurrentSet = index == setScore.count - 1 && !item.won
            Text(item.value)
                .font(.body)
                .fontWeight(isCurrentSet ? .semibold : .regular)
                .foregroundStyle(item.won ? .green : (isCurrentSet ? .primary : .secondary))
            if index < setScore.count - 1 {
                Rectangle()
                    .fill(.separator)
                    .frame(width: layoutDirection.isVertical ? 1 : 18,
                           height: layoutDirection.isVertical ? 18 : 1)
            }
        }
    }
    
    var body: some View {
        if layoutDirection.isVertical {
            VStack {
                if onScreen == .topOrLeading {
                    Spacer()
                }
                HStack(spacing: scoresSpacing) {
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
