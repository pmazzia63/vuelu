import SwiftData
import SwiftUI

@main
struct VueluApp: App {
    private let container: ModelContainer

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let inMemory = isTesting || arguments.contains("-inMemoryStore")
        do {
            container = try ModelContainer(
                for: Work.self, ProgressEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            fatalError("Impossible d'ouvrir la base de données : \(error)")
        }
        #if DEBUG
        if arguments.contains("-seedSampleData") {
            SampleData.insertIfEmpty(into: container.mainContext)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Color.brandDeep)
        }
        .modelContainer(container)
    }
}

enum AppTab: Hashable {
    case home, library, stats, search
}

struct RootView: View {
    @Query private var works: [Work]
    @AppStorage(ReminderScheduler.enabledKey) private var remindersEnabled = false
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("En cours", systemImage: "bookmark.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Bibliothèque", systemImage: "books.vertical.fill", value: AppTab.library) {
                LibraryView()
            }
            Tab("Statistiques", systemImage: "chart.bar.fill", value: AppTab.stats) {
                StatsView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView(isSelected: selection == .search)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        #if DEBUG
        .onAppear {
            // `-initialTab library|stats|search` opens a given tab (handy for simulator screenshots).
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-initialTab"), args.indices.contains(index + 1) {
                selection = ["library": .library, "stats": .stats, "search": .search][args[index + 1]] ?? .home
            }
        }
        #endif
        .task(id: reminderSignature) {
            await ReminderScheduler.reschedule(works: works, enabled: remindersEnabled)
        }
    }

    /// Changes whenever a reminder would change, so notifications are rescheduled only then.
    private var reminderSignature: [String] {
        [String(remindersEnabled)] + works.compactMap { work in
            guard work.status.isTracked, let date = work.nextReleaseAt else { return nil }
            return "\(work.id)|\(date.timeIntervalSince1970)|\(work.title)|\(work.positionText)"
        }
    }
}

#Preview {
    RootView().modelContainer(.preview)
}
