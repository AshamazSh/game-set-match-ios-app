//
//  GameSetMatchApp.swift
//  GameSetMatch
//
//  Created by Ashamaz on 4/3/24.
//

import SwiftUI
import CoreData

@main
struct GameSetMatchApp: App {
    let persistenceController = PersistenceController.shared
    let connectivityManager = ConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            MainView(matchService: MatchService(context: persistenceController.container.viewContext, 
                                                coreDataManager: CoreDataManager(context: persistenceController.container.viewContext),
                                                connectivityManager: ConnectivityManager()))
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
   }
    }
}
