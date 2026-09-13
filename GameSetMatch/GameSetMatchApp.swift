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
        #if DEBUG
        if isUITesting, ProcessInfo.processInfo.arguments.contains("--ui-statistics-fixture") {
            matchService.perform {
                let doubles = ProcessInfo.processInfo.arguments.contains("--ui-statistics-doubles")
                let match = try repository.createMatch(
                    configuration: MatchConfiguration(format: doubles ? .doubles : .singles),
                    players1: doubles ? [.playerOne, .playerOneB] : [.playerOne],
                    players2: doubles ? [.playerTwo, .playerTwoB] : [.playerTwo])
                try repository.selectFirstServingTeam(in: match, teamIndex: 0)
                let finished = ProcessInfo.processInfo.arguments.contains("--ui-statistics-finished")
                // Seed through normal scoring in the isolated in-memory store.
                for _ in 0..<(finished ? 48 : 24) { try repository.awardPoint(in: match, to: 0) }
                if !finished { try repository.awardPoint(in: match, to: 1) }
                matchService.match = match
            }
        }
        #endif
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
