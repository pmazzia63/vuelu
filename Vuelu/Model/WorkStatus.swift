import Foundation

nonisolated enum WorkStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case reading, planned, paused, finished, dropped

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reading: "En cours"
        case .planned: "À commencer"
        case .paused: "En pause"
        case .finished: "Terminé"
        case .dropped: "Abandonné"
        }
    }

    var symbol: String {
        switch self {
        case .reading: "play.fill"
        case .planned: "clock"
        case .paused: "pause.fill"
        case .finished: "checkmark"
        case .dropped: "xmark"
        }
    }

    /// Works the user still follows: they get release reminders and appear on the home screen.
    var isTracked: Bool {
        switch self {
        case .reading, .planned, .paused: true
        case .finished, .dropped: false
        }
    }
}
