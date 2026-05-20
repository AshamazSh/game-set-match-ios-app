//
//  MatchControl.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//

import SwiftUI

struct MatchControl: View {
    @ObservedObject var matchService: MatchService
    private var layoutDirection: LayoutDirection {
        layout ?? .vertical
    }
    @State private var layout: LayoutDirection?
    @State private var isSubscribed: Bool = false
    @State private var showMatchLog: Bool = false
    private var matchState: MatchState? {
        matchService.matchState
    }
    private var isSuperTiebreak: Bool {
        guard let match = matchService.match,
              match.scoringVersion == 2,
              match.rule.deciderSetRule == DeciderSetRule.superTiebreak.rawValue,
              let lastSet = match.sets.lastObject as? MatchSet,
              let lastGame = lastSet.games.lastObject as? Game else { return false }
        return lastGame.isTieBreak && Int32(match.sets.count) == match.rule.duration
    }
    
    var undoButton: some View {
        Button {
            matchService.undoLastPoint()
        } label: {
            Image(systemName: "arrow.counterclockwise")
        }
    }
    
    private var teamScore1: TeamScoreView? {
        guard let matchState else { return nil }
        return TeamScoreView(viewModel: TeamScoreViewModel(teamInfo: matchState.team1, isGoldenPoint: matchState.isGoldenPoint, onScored: { matchService.pointWonByTeam1() }),
                             layoutDirection: layoutDirection,
                             onScreen: .topOrLeading)
    }
    
    private var teamScore2: TeamScoreView? {
        guard let matchState else { return nil }
        return TeamScoreView(viewModel: TeamScoreViewModel(teamInfo: matchState.team2, isGoldenPoint: matchState.isGoldenPoint, onScored: { matchService.pointWonByTeam2() }),
                             layoutDirection: layoutDirection,
                             onScreen: .bottomOrTrailing)
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
            .navigationTitle(isSuperTiebreak ? "Super tiebreak" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let match = matchService.match {
                    ToolbarItem(placement: .topBarLeading) {
                        undoButton
                    }
                    if match.winner != nil,
                       isSubscribed {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Play again") {
                                matchService.replayMatch(match)
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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        matchService.match = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                updateLayoutDirection(with: UIDevice.current.orientation)
            }
            .sheet(isPresented: $showMatchLog) {
                ScoreHistoryView(viewModel: ScoreHistoryViewModel(matchService: matchService))
            }
            .subscriptionStatusTask(for: SubscriptionsService.passGroupId) { taskState in
                if let statuses = taskState.value {
                    isSubscribed = SubscriptionsService.hasSubscription(in: statuses)
                }
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
