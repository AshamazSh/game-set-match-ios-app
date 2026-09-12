//
//  MainView.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var matchService: MatchService
    @Environment(\.managedObjectContext) private var context
    private var showMatch: Bool {
        matchService.matchState != nil
    }
    private var flipDegrees: CGFloat {
        showMatch ? 180.0 : 0
    }
    @State private var selectedTab = 0
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                CreateMatchView(context: context)
                    .environmentObject(matchService)
                    .tabItem {
                        Label("New match", systemImage: "figure.tennis")
                    }
                    .tag(0)
                MatchesHistoryView(matchService: matchService)
                    .tabItem {
                        Label("History", systemImage: "trophy")
                    }
                    .tag(1)
            }
            .flipRotate(flipDegrees)
            .opacity(showMatch ? 0.0 : 1.0)
            .ignoresSafeArea()
            
            MatchControl(matchService: matchService)
                .flipRotate(-180 + flipDegrees)
                .opacity(showMatch ? 1.0 : 0.0)
                .ignoresSafeArea()
        }
        .animation(.easeOut, value: showMatch)
        .alert("Unable to complete action", isPresented: Binding(
            get: { matchService.errorMessage != nil },
            set: { if !$0 { matchService.errorMessage = nil } })) {
                Button("OK") { matchService.errorMessage = nil }
            } message: { Text(matchService.errorMessage ?? "") }
    }
}

extension View {
      func flipRotate(_ degrees : Double) -> some View {
            return rotation3DEffect(Angle(degrees: degrees), axis: (x: 0.0, y: 1.0, z: 0.0))
      }
}
