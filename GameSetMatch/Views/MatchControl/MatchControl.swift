//
//  MatchControl.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//

import SwiftUI

struct MatchControl: View {
    @ObservedObject var matchService: MatchService
    @EnvironmentObject private var coreDataManager: CoreDataManager
    private var layoutDirection: LayoutDirection {
        layout ?? .vertical
    }
    @State private var layout: LayoutDirection?
    @State private var showMatchLog: Bool = false
    private var matchState: MatchState? {
        matchService.matchState
    }
    
    var undoButton: some View {
        Button {
            matchService.undoLastPoint()
        } label: {
            Image(systemName: "arrow.counterclockwise")
        }
    }
    
    @ViewBuilder private var teamScore1: some View {
        if let matchState {
            if matchState.isAwaitingFirstServer {
                FirstServeTeamButton(team: matchState.team1, number: 1) { matchService.selectFirstServingTeam(0) }
            } else {
                TeamScoreView(viewModel: TeamScoreViewModel(teamInfo: matchState.team1, isGoldenPoint: matchState.isGoldenPoint,
                    onScored: { matchService.pointWonByTeam1() }), layoutDirection: layoutDirection, onScreen: .topOrLeading)
            }
        }
    }

    @ViewBuilder private var teamScore2: some View {
        if let matchState {
            if matchState.isAwaitingFirstServer {
                FirstServeTeamButton(team: matchState.team2, number: 2) { matchService.selectFirstServingTeam(1) }
            } else {
                TeamScoreView(viewModel: TeamScoreViewModel(teamInfo: matchState.team2, isGoldenPoint: matchState.isGoldenPoint,
                    onScored: { matchService.pointWonByTeam2() }), layoutDirection: layoutDirection, onScreen: .bottomOrTrailing)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if layoutDirection.isHorizontal {
                    HStack {
                        teamScore1
                        Divider()
                        teamScore2
                    }
                } else {
                    VStack {
                        teamScore1
                        Divider()
                        teamScore2
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if matchState?.isSuperTieBreak == true {
                    ToolbarItem(placement: .principal) { Text("Super tiebreak").font(.caption) }
                } else if let rule = matchState?.decidingPointRule, rule != .star {
                    ToolbarItem(placement: .principal) { Text(rule.title).font(.caption) }
                }
                if let match = matchService.match {
                    ToolbarItem(placement: .topBarLeading) {
                        undoButton.disabled(matchState?.isAwaitingFirstServer == true)
                    }
                    if match.winner != nil {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Play again") {
                                matchService.perform { matchService.match = try coreDataManager.replayMatch(match) }
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMatchLog.toggle()
                    } label: {
                        Image(systemName: "list.bullet.clipboard")
                    }
                    .accessibilityIdentifier("matchDetails")
                    .disabled(matchState?.isAwaitingFirstServer == true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        matchService.closeMatch()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                updateLayoutDirection(with: UIDevice.current.orientation)
            }
            .sheet(isPresented: $showMatchLog) {
                ScoreHistoryView(matchService: matchService)
                    .modifier(SideChangeNotification(event: matchService.sideChangeEvent))
            }

            .onRotate { newOrientation in
                updateLayoutDirection(with: newOrientation)
            }
        }
    }
    
    private func updateLayoutDirection(with orientation: UIDeviceOrientation) {
        switch orientation {
        case .portrait:
            layout = .vertical
        case .landscapeLeft, .landscapeRight:
            layout = .horizontal
        default:
            if layout == nil {
                layout = .vertical
            }
        }
        
    }
}
