import Foundation
import SwiftData

/// Example library for previews and for trying the app (`-seedSampleData` launch argument, DEBUG only).
enum SampleData {
    static func insertIfEmpty(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Work>())) ?? 0
        if count == 0 { insert(into: context) }
    }

    static func insert(into context: ModelContext, now: Date = .now) {
        func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }
        func inDays(_ days: Double) -> Date { now.addingTimeInterval(days * 86_400) }

        let gardiens = Work(title: "Les Gardiens du Phare", kind: .series, major: 2, minor: 6, majorTotal: 3, minorTotal: 10,
                            cadence: .weekly, nextReleaseAt: daysAgo(2), isFavorite: true, unitLength: 52,
                            createdAt: daysAgo(90), lastProgressAt: daysAgo(6))
        let lames = Work(title: "Lames d'Automne", kind: .anime, major: 1, minor: 10, minorTotal: 24,
                         cadence: .weekly, nextReleaseAt: inDays(3), unitLength: 24, createdAt: daysAgo(120))
        let kitsune = Work(title: "Kitsune Express", kind: .manga, major: 14, minor: 120, minorTotal: 135,
                           cadence: .weekly, nextReleaseAt: inDays(1.5), isFavorite: true, unitLength: 18,
                           createdAt: daysAgo(200))
        let cartographe = Work(title: "Le Cartographe", kind: .bd, major: 1, majorTotal: 6,
                               cadence: .irregular, nextReleaseAt: inDays(40), unitLength: 56, createdAt: daysAgo(300))
        let mer = Work(title: "La Mer Intérieure", kind: .book, major: 1, minor: 4, minorTotal: 32,
                       unitLength: 12, createdAt: daysAgo(40))
        let works = [
            gardiens, lames, kitsune, cartographe, mer,
            Work(title: "Station Orbitale 9", kind: .series, status: .planned, major: 1, minor: 0, minorTotal: 8,
                 createdAt: daysAgo(10)),
            Work(title: "Brume sur Kyoto", kind: .anime, status: .finished, major: 2, minor: 12, majorTotal: 2, minorTotal: 12,
                 isFavorite: true, createdAt: daysAgo(400), lastProgressAt: daysAgo(60)),
        ]
        works.forEach(context.insert)

        // A bit of history, so the statistics have something to show.
        for day in [20.0, 18, 15, 12, 9, 6, 3, 1] { lames.advance(at: daysAgo(day)) }
        for day in [28.0, 26, 22, 21, 17, 14, 12, 10, 8, 7, 5, 3] { kitsune.advance(at: daysAgo(day)) }
        for day in [25.0, 23, 19, 16, 13, 11, 9, 7, 5, 4] { mer.advance(at: daysAgo(day)) }
        for day in [80.0, 48] { cartographe.advance(at: daysAgo(day)) }
        try? context.save()
    }
}

extension ModelContainer {
    /// In-memory container filled with `SampleData`, for SwiftUI previews.
    @MainActor
    static var preview: ModelContainer {
        let container = try! ModelContainer(
            for: Work.self, ProgressEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        SampleData.insert(into: container.mainContext)
        return container
    }
}
