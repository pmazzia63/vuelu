import Foundation

/// What one step of progress counts as in the statistics.
nonisolated enum StatUnit: String, CaseIterable, Identifiable, Sendable {
    case episode, chapter, tome

    var id: String { rawValue }

    func label(_ count: Int) -> String {
        switch self {
        case .episode: count > 1 ? "épisodes" : "épisode"
        case .chapter: count > 1 ? "chapitres" : "chapitre"
        case .tome: count > 1 ? "tomes" : "tome"
        }
    }

    var symbol: String {
        switch self {
        case .episode: "play.rectangle.fill"
        case .chapter: "doc.text.fill"
        case .tome: "books.vertical.fill"
        }
    }
}

extension Work {
    var statUnit: StatUnit {
        if kind.isWatched { return .episode }
        return mode.stepsMajor ? .tome : .chapter
    }
}

/// The time range shown on the statistics screen.
nonisolated enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case week, month, year, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "7 jours"
        case .month: "30 jours"
        case .year: "Année"
        case .all: "Tout"
        }
    }

    /// Rolling window ending now; nil for "Tout".
    func interval(now: Date, calendar: Calendar = .current) -> DateInterval? {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let days: Int
        switch self {
        case .week: days = 7
        case .month: days = 30
        case .year: days = 365
        case .all: return nil
        }
        let start = calendar.date(byAdding: .day, value: -days, to: startOfTomorrow) ?? now
        return DateInterval(start: start, end: startOfTomorrow)
    }

    /// Chart bar width.
    var bucket: Calendar.Component {
        switch self {
        case .week: .day
        case .month: .weekOfYear
        case .year, .all: .month
        }
    }
}

/// Totals computed from every work's progress history. Only progress recorded in the app counts:
/// the position a work was created at is not part of it. Minutes and pages come from each work's
/// `unitLength`; works without one still count in épisodes / chapitres / tomes.
struct ReadingStats {
    struct Event {
        let date: Date
        let workID: UUID
        let kind: WorkKind
        let unit: StatUnit
        let units: Int
        let minutes: Int
        let pages: Int
    }

    struct WorkTotal: Identifiable {
        let work: Work
        var units = 0
        var minutes = 0
        var pages = 0
        var id: UUID { work.id }
    }

    struct Bucket: Identifiable {
        let start: Date
        let kind: WorkKind
        var minutes = 0
        var pages = 0
        var units = 0
        var id: String { "\(start.timeIntervalSince1970)-\(kind.rawValue)" }
    }

    private(set) var minutes = 0
    private(set) var pages = 0
    private(set) var units: [StatUnit: Int] = [:]
    private(set) var activeDays = 0
    /// Most active works first.
    private(set) var topWorks: [WorkTotal] = []
    /// Per bucket and per kind, chronological.
    private(set) var buckets: [Bucket] = []
    /// Works without `unitLength` that had progress in the period: their time / pages is unknown.
    private(set) var worksMissingLength: [Work] = []

    init(works: [Work], period: StatsPeriod, now: Date = .now, calendar: Calendar = .current) {
        let interval = period.interval(now: now, calendar: calendar)
        var perWork: [UUID: WorkTotal] = [:]
        var perBucket: [String: Bucket] = [:]
        var days = Set<Date>()

        for work in works {
            let length = work.unitLength ?? 0
            for entry in work.history {
                guard interval?.contains(entry.date) ?? true else { continue }
                let count = work.units(in: entry)
                guard count != 0 else { continue }
                let (entryMinutes, entryPages) = work.kind.isWatched ? (count * length, 0) : (0, count * length)

                minutes += entryMinutes
                pages += entryPages
                units[work.statUnit, default: 0] += count
                if count > 0 { days.insert(calendar.startOfDay(for: entry.date)) }

                perWork[work.id, default: WorkTotal(work: work)].units += count
                perWork[work.id]?.minutes += entryMinutes
                perWork[work.id]?.pages += entryPages

                let start = calendar.dateInterval(of: period.bucket, for: entry.date)?.start ?? entry.date
                let key = "\(start.timeIntervalSince1970)-\(work.kind.rawValue)"
                perBucket[key, default: Bucket(start: start, kind: work.kind)].minutes += entryMinutes
                perBucket[key]?.pages += entryPages
                perBucket[key]?.units += count
            }
        }

        // Moving back (a correction) can cancel progress but never makes a total negative.
        minutes = max(minutes, 0)
        pages = max(pages, 0)
        units = units.mapValues { max($0, 0) }.filter { $0.value > 0 }
        activeDays = days.count
        topWorks = perWork.values
            .filter { $0.units > 0 }
            .sorted { ($0.units, $0.work.lastProgressAt) > ($1.units, $1.work.lastProgressAt) }
        buckets = perBucket.values
            .map { bucket in
                var clamped = bucket
                clamped.minutes = max(bucket.minutes, 0)
                clamped.pages = max(bucket.pages, 0)
                clamped.units = max(bucket.units, 0)
                return clamped
            }
            .sorted { ($0.start, $0.kind.rawValue) < ($1.start, $1.kind.rawValue) }
        worksMissingLength = topWorks.map(\.work).filter { $0.unitLength == nil }
    }

    var isEmpty: Bool { topWorks.isEmpty }
    var totalUnits: Int { units.values.reduce(0, +) }
}
