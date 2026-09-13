import SwiftUI

struct MatchControlWatchView: View {
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @State private var selectedTab = 0

    private var matchState: MatchState { connectivityManager.matchState ?? .empty }

    private var teamScore1: some View {
        TeamScoreView(viewModel: TeamScoreViewModel(teamInfo: matchState.team1,
            isGoldenPoint: matchState.isGoldenPoint,
            onScored: { connectivityManager.sendRequest(.teamAScored) }), onScreen: .top)
    }

    private var teamScore2: some View {
        TeamScoreView(viewModel: TeamScoreViewModel(teamInfo: matchState.team2,
            isGoldenPoint: matchState.isGoldenPoint,
            onScored: { connectivityManager.sendRequest(.teamBScored) }), onScreen: .bottom)
    }

    var body: some View {
        Group {
            if matchState.isAwaitingFirstServer {
                // Selection is a separate screen, never a cached score page inside TabView.
                VStack(spacing: 0) {
                    FirstServeTeamButton(team: matchState.team1, number: 1) {
                        connectivityManager.sendRequest(.teamAServesFirst)
                    }
                    Divider()
                    FirstServeTeamButton(team: matchState.team2, number: 2) {
                        connectivityManager.sendRequest(.teamBServesFirst)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { connectivityManager.sendRequest(.endMatch) } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("End match")
                    }
                }
            } else {
                TabView(selection: $selectedTab) {
                    VStack {
                        if matchState.isSuperTieBreak == true {
                            Text("Super tiebreak").font(.caption)
                        } else if let rule = matchState.decidingPointRule, rule != .star {
                            Text(rule.title).font(.caption)
                        }
                        teamScore1
                        Divider()
                        teamScore2
                    }
                    .focusable(true)
                    .gesture(DragGesture(minimumDistance: 40, coordinateSpace: .local)
                        .onEnded { value in
                            guard !matchState.isAwaitingFirstServer else { return }
                            if value.translation.height < -40 { connectivityManager.sendRequest(.teamAScored) }
                            if value.translation.height > 40 { connectivityManager.sendRequest(.teamBScored) }
                        })
                    .tag(0)

                    VStack {
                        Spacer()
                        Button("Undo") {
                            connectivityManager.sendRequest(.undo)
                            withAnimation { selectedTab = 0 }
                        }
                        Spacer()
                        Button(matchState.isCompleted ? "Quit" : "End match") {
                            connectivityManager.sendRequest(.endMatch)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .tag(1)
                }
            }
        }
        .onChange(of: matchState.matchID) { _ in selectedTab = 0 }
        .onChange(of: matchState.isAwaitingFirstServer) { _ in selectedTab = 0 }
    }
}
