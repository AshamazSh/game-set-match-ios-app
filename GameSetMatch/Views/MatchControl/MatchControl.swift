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
    @State private var endMatchAlert = false
    @State private var isSubscribed: Bool = false
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let match = matchService.match {
                    if match.isActive,
                       !match.isOver {
                        ToolbarItem(placement: .topBarLeading) {
                            undoButton
                        }
                    } else if isSubscribed {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Play again") {
                                try? coreDataManager.replayMatch(match)
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
                        if let match = matchService.match,
                           match.isActive {
                            endMatchAlert.toggle()
                        } else {
                            matchService.match = nil
                        }
                    } label: {
                        if let match = matchService.match,
                           match.isActive {
                            Image(systemName: "flag.checkered")
                        } else {
                            Image(systemName: "xmark")
                        }
                    }
                }
            }
            .alert(isPresented: $endMatchAlert) {
                Alert(
                    title: Text("End match?"),
                    primaryButton: .destructive(Text("Yes"), action: {
                        withAnimation {
                            if let match = matchService.match,
                               match.isActive {
                                try? coreDataManager.endMatch(match)
                            } else {
                                matchService.match = nil
                            }
                        }
                    }),
                    secondaryButton: .cancel()
                )
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
