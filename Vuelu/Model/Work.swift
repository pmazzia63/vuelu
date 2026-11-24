import Foundation
import SwiftData

/// A tracked comic, book, manga, TV series or anime, with the user's current position.
///
/// `major`/`minor` hold the last unit consumed (see `TrackingMode` for how they are counted).
/// `minor == 0` means nothing consumed yet in the current `major`.
@Model
final class Work {
    var id: UUID = UUID()
    var title: String = ""
    var kindRaw: String = WorkKind.series.rawValue
    /// `TrackingMode` raw value; nil (works created before modes existed) means the kind's default.
    var modeRaw: String?
    var statusRaw: String = WorkStatus.reading.rawValue
    var major: Int = 1
    var minor: Int = 0
    /// Total number of saisons / tomes, when known.
    var majorTotal: Int?
    /// Épisodes in the current saison, chapitres in the current tome, or (manga) latest chapter out.
    var minorTotal: Int?
    var cadenceRaw: String = ReleaseCadence.none.rawValue
    /// Next expected release. Once it is in the past, a new unit is waiting for the user.
    var nextReleaseAt: Date?
    var note: String = ""
    var isFavorite: Bool = false
    /// Minutes per épisode, or pages per chapitre / tome (per `mode`), for the statistics.
    var unitLength: Int?
    @Attribute(.externalStorage) var coverImage: Data?
    var createdAt: Date = Date.now
    var lastProgressAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \ProgressEntry.work)
    var history: [ProgressEntry] = []

    init(
        id: UUID = UUID(),
        title: String,
        kind: WorkKind,
        mode: TrackingMode? = nil,
        status: WorkStatus = .reading,
        major: Int? = nil,
        minor: Int = 0,
        majorTotal: Int? = nil,
        minorTotal: Int? = nil,
        cadence: ReleaseCadence = .none,
        nextReleaseAt: Date? = nil,
        note: String = "",
        isFavorite: Bool = false,
        unitLength: Int? = nil,
        coverImage: Data? = nil,
        createdAt: Date = .now,
        lastProgressAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        let mode = mode.flatMap { kind.availableModes.contains($0) ? $0 : nil } ?? kind.defaultMode
        self.kindRaw = kind.rawValue
        self.modeRaw = mode.rawValue
        self.statusRaw = status.rawValue
        self.major = major ?? mode.minimumMajor
        self.minor = minor
        self.majorTotal = majorTotal
        self.minorTotal = minorTotal
        self.cadenceRaw = cadence.rawValue
        self.nextReleaseAt = nextReleaseAt
        self.note = note
        self.isFavorite = isFavorite
        self.unitLength = unitLength
        self.coverImage = coverImage
        self.createdAt = createdAt
        self.lastProgressAt = lastProgressAt ?? createdAt
    }

    // MARK: Typed accessors

    var kind: WorkKind {
        get { WorkKind(rawValue: kindRaw) ?? .series }
        set { kindRaw = newValue.rawValue }
    }

    /// Always one of `kind.availableModes`.
    var mode: TrackingMode {
        get {
            guard let raw = modeRaw, let mode = TrackingMode(rawValue: raw), kind.availableModes.contains(mode) else {
                return kind.defaultMode
            }
            return mode
        }
        set { modeRaw = newValue.rawValue }
    }

    var status: WorkStatus {
        get { WorkStatus(rawValue: statusRaw) ?? .reading }
        set { statusRaw = newValue.rawValue }
    }

    var cadence: ReleaseCadence {
        get { ReleaseCadence(rawValue: cadenceRaw) ?? .none }
        set { cadenceRaw = newValue.rawValue }
    }

    // MARK: Derived state

    var positionText: String { positionText(major: major, minor: minor) }

    func positionText(major: Int, minor: Int) -> String {
        kind.positionText(major: major, minor: minor, mode: mode)
    }

    var nextActionLabel: String { kind.nextActionLabel(mode: mode) }

    /// "sur 12" style hint for the current unit, when a total is known.
    var totalHint: String? {
        if mode.stepsMajor { return majorTotal.map { "sur \($0)" } }
        guard let total = minorTotal else { return nil }
        return mode == .continuous ? "dernier : \(total)" : "sur \(total)"
    }

    /// Progress through the current saison / tome (or through the whole series when counted per tome).
    var progressFraction: Double? {
        let (value, total) = mode.stepsMajor ? (major, majorTotal) : (minor, minorTotal)
        guard let total, total > 0 else { return nil }
        return min(max(Double(value) / Double(total), 0), 1)
    }

    func hasNewRelease(at now: Date = .now) -> Bool {
        guard status.isTracked, let next = nextReleaseAt else { return false }
        return next <= now
    }

    /// In progress but untouched for more than `days`.
    func isStale(at now: Date = .now, days: Int = 30) -> Bool {
        status == .reading && now.timeIntervalSince(lastProgressAt) > Double(days) * 86_400
    }

    /// Whether the current position is the very end of the work (used to mark it finished).
    var isAtEnd: Bool {
        switch mode {
        case .majorOnly:
            guard let total = majorTotal else { return false }
            return major >= total
        case .nested:
            guard let units = minorTotal, minor >= units else { return false }
            return major >= (majorTotal ?? (kind == .book ? 1 : .max))
        case .continuous:
            // `minorTotal` is the latest chapter out: reaching it means caught up, not finished.
            return false
        }
    }

    var sortedHistory: [ProgressEntry] {
        history.sorted { $0.date > $1.date }
    }

    // MARK: Progress

    /// The "+1" action: next épisode / chapitre, or next tome when counted per tome.
    /// Rolls over to the next saison / tome when the current one is complete.
    func advance(at now: Date = .now) {
        if mode.stepsMajor {
            setPosition(major: major + 1, minor: 0, at: now)
        } else if mode.minorResetsPerMajor, let total = minorTotal, minor >= total {
            setPosition(major: major + 1, minor: 1, at: now)
        } else {
            setPosition(major: major, minor: minor + 1, at: now)
        }
    }

    /// Jumps to the start of the next saison / tome. With absolute chapters the chapter is kept:
    /// only the informative tome changes.
    func advanceMajor(at now: Date = .now) {
        setPosition(major: major + 1, minor: mode == .continuous ? minor : 0, at: now)
    }

    /// Moves to an explicit position and records it in the history.
    /// Moving forward consumes one pending release, starts a planned/paused work,
    /// and marks the work finished when its end is reached.
    func setPosition(major newMajor: Int, minor newMinor: Int, at now: Date = .now) {
        let target = (max(newMajor, mode.minimumMajor), max(newMinor, 0))
        guard target != (major, minor) else { return }

        let entry = ProgressEntry(
            date: now,
            fromMajor: major,
            fromMinor: minor,
            toMajor: target.0,
            toMinor: target.1,
            previousStatus: status,
            previousNextReleaseAt: nextReleaseAt,
            previousLastProgressAt: lastProgressAt
        )
        history.append(entry)

        major = target.0
        minor = target.1
        lastProgressAt = now

        // With absolute chapters, changing only the informative tome is not progress.
        let consumedSomething = mode == .continuous ? target.1 > entry.fromMinor : entry.isForward
        if consumedSomething {
            consumeRelease(at: now)
            if status == .planned || status == .paused { status = .reading }
            if isAtEnd { status = .finished }
        }
    }

    /// Épisodes / chapitres / tomes consumed by one history entry (negative when moving back).
    func units(in entry: ProgressEntry) -> Int {
        mode.units(fromMajor: entry.fromMajor, fromMinor: entry.fromMinor, toMajor: entry.toMajor, toMinor: entry.toMinor)
    }

    /// Reverts the most recent position change, including its side effects.
    @discardableResult
    func undoLast() -> Bool {
        guard let last = history.max(by: { $0.date < $1.date }) else { return false }
        major = last.fromMajor
        minor = last.fromMinor
        status = last.previousStatus
        nextReleaseAt = last.previousNextReleaseAt
        lastProgressAt = last.previousLastProgressAt
        history.removeAll { $0 === last }
        modelContext?.delete(last)
        return true
    }

    /// Each unit consumed uses up one pending release: if the user is three weekly
    /// episodes behind, the work stays in "Nouveautés" until they have caught up.
    private func consumeRelease(at now: Date) {
        guard let next = nextReleaseAt, next <= now else { return }
        nextReleaseAt = cadence.release(after: next)
    }
}
