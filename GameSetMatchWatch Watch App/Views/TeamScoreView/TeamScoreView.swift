//
//  TeamScoreView.swift
//  GameSetMatchWatch Watch App
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
        case top
        case bottom
    }
    
    let viewModel: TeamScoreViewModel
    let onScreen: OnScreenPosition
    
    private var deviceWidth: CGFloat {
        WKInterfaceDevice.current().screenBounds.size.width
    }
    
    private var scoreButton: some View {
        Button {
            viewModel.onScored()
        } label: {
            Text(viewModel.teamInfo.points)
                .font(.system(size: deviceWidth > 324.0/2.0 ? 60 : 50))
        }
        .foregroundStyle(viewModel.isGoldenPoint
                         ? .yellow
                         : .primary)
        .buttonStyle(.plain)
    }

    private var teamName: some View {
        HStack {
            if let servingPlayer = viewModel.teamInfo.servingPlayer {
                Spacer()
                VStack {
                    if onScreen == .top {
                        Spacer()
                        Label(servingPlayer.shortName, systemImage: "tennisball.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    } else {
                        Label(servingPlayer.shortName, systemImage: "tennisball.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Spacer()
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            scoreButton
            
            teamName

            TeamSetsScoreView(setScore: viewModel.teamInfo.setScore,
                              onScreen: onScreen)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let setsScore = [MatchState.TeamInfo.SetScore(value: "6", won: true), MatchState.TeamInfo.SetScore(value: "4", won: false)]
    let player = MatchPlayer(name: "Player A", shortName: "PLA")
    return TeamScoreView(viewModel: TeamScoreViewModel(teamInfo: MatchState.TeamInfo(name: "A", setScore: setsScore, points: "40", players: [player, MatchPlayer(name: "Player B", shortName: "PLB")], servingPlayer: player, isMatchWinner: false), isGoldenPoint: true, onScored: {}),
                         onScreen: .top)
}
