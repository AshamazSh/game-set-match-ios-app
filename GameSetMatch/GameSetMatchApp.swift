import SwiftUI
import CoreData

@MainActor
final class AppDependencies: ObservableObject {
    let persistence: PersistenceController
    let repository: CoreDataManager
    let connectivity: ConnectivityManager
    let matchService: MatchService

    init() {
        persistence = PersistenceController.shared
        repository = CoreDataManager(context: persistence.container.viewContext)
        connectivity = ConnectivityManager()
        matchService = MatchService(context: persistence.container.viewContext,
                                    coreDataManager: repository, connectivityManager: connectivity)
    }
}

@main
struct GameSetMatchApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            MainView(matchService: dependencies.matchService)
                .environment(\.managedObjectContext, dependencies.persistence.container.viewContext)
                .environmentObject(dependencies.repository)
        }
    }
}
