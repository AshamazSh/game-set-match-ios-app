import SwiftUI
import CoreData

@MainActor
final class AppDependencies: ObservableObject {
    let persistence: PersistenceController
    let repository: CoreDataManager
    let connectivity: ConnectivityManager
    let matchService: MatchService

    init() {
        #if DEBUG
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        let isUITesting = false
        #endif
        let defaults = isUITesting ? UserDefaults(suiteName: "UITests.\(UUID().uuidString)")! : .standard
        persistence = isUITesting ? PersistenceController(inMemory: true) : .shared
        repository = CoreDataManager(context: persistence.container.viewContext)
        connectivity = ConnectivityManager(defaults: defaults, activate: !isUITesting)
        matchService = MatchService(context: persistence.container.viewContext,
                                    coreDataManager: repository, connectivityManager: connectivity, defaults: defaults)
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
