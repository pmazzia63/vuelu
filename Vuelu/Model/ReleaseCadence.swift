import Foundation

/// How often new episodes / chapters / tomes come out.
nonisolated enum ReleaseCadence: String, CaseIterable, Identifiable, Codable, Sendable {
    case none, weekly, monthly, irregular

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "Aucun"
        case .weekly: "Chaque semaine"
        case .monthly: "Chaque mois"
        case .irregular: "Date ponctuelle"
        }
    }

    /// Fits a segmented control.
    var shortLabel: String {
        switch self {
        case .none: "Aucun"
        case .weekly: "Hebdo"
        case .monthly: "Mensuel"
        case .irregular: "Ponctuel"
        }
    }

    var hasReleaseDate: Bool { self != .none }

    /// The expected release after `date`, or nil when the next date is unknown
    /// (one-off dates such as a new season must be entered again by hand).
    func release(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .weekly: calendar.date(byAdding: .day, value: 7, to: date)
        case .monthly: calendar.date(byAdding: .month, value: 1, to: date)
        case .none, .irregular: nil
        }
    }

    /// A sensible default when the user picks this cadence in the editor.
    func suggestedNextRelease(from now: Date = .now, calendar: Calendar = .current) -> Date {
        let base = release(after: now, calendar: calendar) ?? calendar.date(byAdding: .day, value: 30, to: now) ?? now
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base
    }
}
