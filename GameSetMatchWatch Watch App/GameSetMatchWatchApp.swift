//
//  GameSetMatchWatchApp.swift
//  GameSetMatchWatch Watch App
//
//  Created by Ashamaz on 8/3/24.
//

import SwiftUI

@main
struct GameSetMatchWatch_Watch_AppApp: App {
    let connectivityManager = WatchConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            MainWatchView(connectivityManager: connectivityManager)
        }
    }
}
