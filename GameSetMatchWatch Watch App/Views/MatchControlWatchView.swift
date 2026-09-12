//
//  MatchControlWatchView.swift
//  GameSetMatchWatch Watch App
//
//  Created by Ashamaz on 8/3/24.
//

import SwiftUI
import Combine

@MainActor
class MatchControlWatchViewModel: ObservableObject {
    let connectivityManager: WatchConnectivityManager
    let matchState: MatchState
    let team1: TeamScoreViewModel
    let team2: TeamScoreViewModel

    init(connectivityManager: WatchConnectivityManager, matchState: MatchState) {
        self.connectivityManager = connectivityManager
        self.matchState = matchState
        self.team1 = TeamScoreViewModel(teamInfo: matchState.team1, isGoldenPoint: matchState.isGoldenPoint, onScored: { [weak connectivityManager] in connectivityManager?.sendRequest(.teamAScored) })
        self.team2 = TeamScoreViewModel(teamInfo: matchState.team2, isGoldenPoint: matchState.isGoldenPoint, onScored: { [weak connectivityManager] in connectivityManager?.sendRequest(.teamBScored) })
    }
}

struct MatchControlWatchView: View {
    @ObservedObject var viewModel: MatchControlWatchViewModel

    private var teamScore1: TeamScoreView {
        TeamScoreView(viewModel: viewModel.team1,
                      onScreen: .top)
    }

    private var teamScore2: TeamScoreView {
        TeamScoreView(viewModel: viewModel.team2,
                      onScreen: .bottom)
    }

    @State private var crownValue: Double = 0
    @State private var prevCrownValue: Double = 0
    @State private var selectedTab = 0
    @State private var lastSentRequestDate = Date.now
    var body: some View {
        TabView(selection: $selectedTab) {
            VStack {
                if viewModel.matchState.isSuperTieBreak == true {
                    Text("Super tiebreak").font(.caption)
                } else if let rule = viewModel.matchState.decidingPointRule {
                    Text(rule.title).font(.caption)
                }
                teamScore1
                Divider()
                teamScore2
            }
            .focusable(true)
//            .digitalCrownRotation($crownValue, from: -100, through: 100, sensitivity: .low)
//            .onChange(of: crownValue, perform: { newValue in
//                guard !viewModel.connectivityManager.isSendingRequest else { return }
//                let diff = prevCrownValue - newValue
//                prevCrownValue = newValue
//                let timeDiff = Date.now.timeIntervalSince(lastSentRequestDate)
//                guard timeDiff > 3 else { return }
//                lastSentRequestDate = .now
//                if diff < 0 {
//                    viewModel.connectivityManager.sendRequest(.teamBScored)
//                } else if diff > 0 {
//                    viewModel.connectivityManager.sendRequest(.teamAScored)
//                }
//            })
            .gesture(DragGesture(minimumDistance: 40, coordinateSpace: .local)
                                .onEnded({ value in
                                    if value.translation.height < -40 {
                                        viewModel.connectivityManager.sendRequest(.teamAScored)
                                    }

                                    if value.translation.height > 40 {
                                        viewModel.connectivityManager.sendRequest(.teamBScored)
                                    }
                                }))
            .tag(0)
            
            VStack {
                Spacer()
                Group {
                    Button("Undo") {
                        viewModel.connectivityManager.sendRequest(.undo)
                        withAnimation {
                            selectedTab = 0
                        }
                    }
                    Spacer()
                }
                Button(viewModel.matchState.isCompleted ? "Quit" : "End match") {
                    withAnimation {
                        viewModel.connectivityManager.sendRequest(.endMatch)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)
            .tag(1)
        }
    }
}
