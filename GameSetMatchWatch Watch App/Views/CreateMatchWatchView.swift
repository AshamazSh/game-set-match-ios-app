//
//  CreateMatchWatchView.swift
//  GameSetMatchWatch Watch App
//
//  Created by Ashamaz on 8/3/24.
//

import SwiftUI

struct CreateMatchWatchView: View {
    @State private var matchType: AppRequest = .createTennisMatch
    @ObservedObject var connectivityManager: WatchConnectivityManager
    private let options = [AppRequest.createTennisMatch, AppRequest.createTennis2x2Match, AppRequest.createPadelMatch]

    var body: some View {
        VStack {
            TabView(selection: $matchType) {
                Text("New tennis match")
                    .tag(AppRequest.createTennisMatch)
                Text("New tennis 2x2 match")
                    .tag(AppRequest.createTennis2x2Match)
                Text("New padel match")
                    .tag(AppRequest.createPadelMatch)
            }
            Button {
                connectivityManager.sendRequest(matchType)
            } label: {
                Text("Create")
            }
            .padding(.top)
        }
    }
}
