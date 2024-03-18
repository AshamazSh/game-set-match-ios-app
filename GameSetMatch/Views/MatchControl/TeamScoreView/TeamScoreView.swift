//
//  TeamScoreView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 11/3/24.
//

import SwiftUI

struct TeamScoreViewModel {
    let teamInfo: MatchState.TeamInfo
    let isGoldenPoint: Bool
    let onScored: () -> Void
}

struct TeamScoreView: View {
    enum OnScreenPosition {
        case topOrLeading
        case bottomOrTrailing
    }
    
    let viewModel: TeamScoreViewModel
    let layoutDirection: LayoutDirection
    let onScreen: OnScreenPosition
    
    private var scoreButton: some View {
        Button {
            viewModel.onScored()
        } label: {
            Text(viewModel.teamInfo.points)
                .font(.system(size: 80))
        }
        .foregroundStyle(viewModel.isGoldenPoint
                         ? .yellow
                         : Color(uiColor: .systemBlue))
    }

    private var teamName: some View {
        HStack(spacing: 0) {
            ForEach(Array(viewModel.teamInfo.players.enumerated()), id: \.offset) { index, player in
                if player.id == viewModel.teamInfo.servingPlayer?.id {
                    Label(player.shortName, systemImage: "tennisball.fill")
                        .foregroundStyle(.white)
                        .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .background(.yellow)
                        .clipShape(Capsule())
                } else {
                    Text(player.shortName)
                }
                if index < viewModel.teamInfo.players.count - 1 {
                    Text("|")
                        .padding(.horizontal, 8)
                }
            }
        }
        .frame(height: 50)
    }
    
    var body: some View {
        ZStack {
            scoreButton
            
            teamName
                .offset(y: (layoutDirection.isVertical && onScreen == .bottomOrTrailing) ? -80 : 80)

            TeamSetsScoreView(setScore: viewModel.teamInfo.setScore,
                              layoutDirection: layoutDirection,
                              onScreen: onScreen)
            .padding(layoutDirection.isHorizontal ? .vertical : .horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let setsScore = [MatchState.TeamInfo.SetScore(value: "6", won: true), MatchState.TeamInfo.SetScore(value: "4", won: false)]
    let player = MatchPlayer(name: "Player A", shortName: "PLA")
    return TeamScoreView(viewModel: TeamScoreViewModel(teamInfo: MatchState.TeamInfo(name: "A", setScore: setsScore, points: "40", players: [player, MatchPlayer(name: "Player B", shortName: "PLB")], servingPlayer: player, isMatchWinner: false), isGoldenPoint: true, onScored: {}),
                         layoutDirection: .horizontal,
                         onScreen: .topOrLeading)
}
