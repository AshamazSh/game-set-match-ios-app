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
    private let persistenceController: PersistenceController
    private let coreDataManager: CoreDataManager
    private let connectivityManager: ConnectivityManager
    private let matchService: MatchService
    
    init() {
        let persistenceController = PersistenceController.shared
        let context = persistenceController.container.viewContext
        let coreDataManager = CoreDataManager(context: context)
        let connectivityManager = ConnectivityManager()
        
        self.persistenceController = persistenceController
        self.coreDataManager = coreDataManager
        self.connectivityManager = connectivityManager
        self.matchService = MatchService(context: context,
                                         coreDataManager: coreDataManager,
                                         connectivityManager: connectivityManager)
    }
    
    var body: some Scene {
        WindowGroup {
            MainView(matchService: matchService,
                     coreDataManager: coreDataManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
   }
    }
}
