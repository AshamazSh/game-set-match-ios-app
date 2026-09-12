//
//  MainWatchView.swift
//  GameSetMatchWatch Watch App
//
//  Created by Ashamaz on 8/3/24.
//

import SwiftUI

struct MainWatchView: View {
    @ObservedObject var connectivityManager: WatchConnectivityManager
    private var matchState: MatchState? {
        connectivityManager.matchState
    }
    private var hasConnection: Bool {
        connectivityManager.isConnected && connectivityManager.didRecieveMatchState
    }
    private var isLoading: Bool {
        connectivityManager.isSendingRequest
    }
    
    var body: some View {
        ZStack {
            NavigationView {
                if !hasConnection {
                    Text("Please back to GameSetMach on your device")
                } else if let matchState = matchState {
                    MatchControlWatchView(viewModel: MatchControlWatchViewModel(connectivityManager: connectivityManager, matchState: matchState))
                } else {
                    CreateMatchWatchView(connectivityManager: connectivityManager)
                }
            }
            if isLoading {
                ZStack {
                    Color.white.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                }
                .ignoresSafeArea()
            }
        }
        .alert("Unable to complete action", isPresented: Binding(get: { connectivityManager.errorMessage != nil }, set: { if !$0 { connectivityManager.errorMessage = nil } })) {
            Button("OK") { connectivityManager.errorMessage = nil }
        } message: { Text(connectivityManager.errorMessage ?? "") }
        .onAppear {
            connectivityManager.sendRequest(.currentStatus)
        }
    }
}
