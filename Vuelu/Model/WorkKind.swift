import SwiftUI

/// The kind of media being tracked. Drives unit names, how "+1" behaves and the tint.
///
/// Every work stores its position as two generic levels, `major` and `minor`; how they are
/// counted is the work's `TrackingMode`. Séries / animes are saison · épisode; kinds with tomes
/// default to absolute chapters (manga), tome · chapitre (livre) or tome only (BD).
nonisolated enum WorkKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case series, anime, manga, bd, book

    var id: String { rawValue }

    var label: String {
        switch self {
        case .series: "Série"
        case .anime: "Anime"
        case .manga: "Manga"
        case .bd: "BD"
        case .book: "Livre"
        }
    }

    var symbol: String {
        switch self {
        case .series: "tv.fill"
        case .anime: "sparkles.tv.fill"
        case .manga: "text.book.closed.fill"
        case .bd: "text.bubble.fill"
        case .book: "book.fill"
        }
    }

    var tint: Color {
        switch self {
        case .series: Color(hex: 0x8DB4DE)  // bleu ciel
        case .anime: Color(hex: 0xB39BE0)   // lilas
        case .manga: Color(hex: 0xE39AB4)   // rose
        case .bd: Color(hex: 0xEBA987)      // pêche
        case .book: Color(hex: 0x98BD96)    // sauge
        }
    }

    var majorName: String {
        switch self {
        case .series, .anime: "Saison"
        case .manga, .bd, .book: "Tome"
        }
    }

    var minorName: String {
        switch self {
        case .series, .anime: "Épisode"
        case .manga, .bd, .book: "Chapitre"
        }
    }

    /// Modes the user can pick. Séries and animes are always saison · épisode.
    var availableModes: [TrackingMode] {
        switch self {
        case .series, .anime: [.nested]
        case .manga, .bd, .book: [.majorOnly, .nested, .continuous]
        }
    }

    var defaultMode: TrackingMode {
        switch self {
        case .series, .anime, .book: .nested
        case .manga: .continuous
        case .bd: .majorOnly
        }
    }

    /// Watched (minutes) or read (pages): what `Work.unitLength` measures.
    var isWatched: Bool { self == .series || self == .anime }

    func positionText(major: Int, minor: Int, mode: TrackingMode) -> String {
        switch (self, mode) {
        case (.series, _), (.anime, _): "S\(major) · É\(minor)"
        case (_, .majorOnly): "Tome \(major)"
        case (_, .continuous): "Ch. \(minor)"
        case (_, .nested): major > 1 || self != .book ? "T\(major) · Ch. \(minor)" : "Ch. \(minor)"
        }
    }

    func nextActionLabel(mode: TrackingMode) -> String {
        if isWatched { return "Épisode suivant" }
        return mode.stepsMajor ? "Tome suivant" : "Chapitre suivant"
    }

    var nextMajorLabel: String {
        isWatched ? "Saison suivante" : "Tome suivant"
    }

    func newReleaseShort(mode: TrackingMode) -> String {
        if isWatched { return "Nouvel épisode" }
        return mode.stepsMajor || self == .book ? "Nouveau tome" : "Nouveau chapitre"
    }

    func newReleaseText(mode: TrackingMode) -> String { "\(newReleaseShort(mode: mode)) disponible" }

    /// Editor label for `Work.unitLength`.
    func unitLengthLabel(mode: TrackingMode) -> String {
        if isWatched { return "Durée d'un épisode" }
        return mode.stepsMajor ? "Pages par tome" : "Pages par chapitre"
    }

    /// Unit shown next to `Work.unitLength`.
    var unitLengthSuffix: String { isWatched ? "min" : "pages" }
}
