import Foundation

/// How a work's two position levels (`major`/`minor`) are counted.
///
/// Séries and animes are always `nested` (saison · épisode). Works with tomes (manga, BD, livre)
/// can use any mode, so the same manga can be followed per tome, per chapter within each tome,
/// or by its absolute chapter number.
nonisolated enum TrackingMode: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Only `major` counts ("Tome 3"); "+1" moves to the next tome. `major == 0` means not started.
    case majorOnly
    /// `minor` restarts at each new `major` (saison · épisode, tome · chapitre).
    case nested
    /// `minor` is numbered continuously across `major`s; `major` is only informative (current tome).
    case continuous

    var id: String { rawValue }

    /// Name shown in the editor's mode picker (only offered for kinds with tomes).
    var label: String {
        switch self {
        case .majorOnly: "Par tome"
        case .nested: "Tome + chapitre"
        case .continuous: "Chapitre absolu"
        }
    }

    var explanation: String {
        switch self {
        case .majorOnly: "« +1 » passe au tome suivant."
        case .nested: "Les chapitres repartent à 1 à chaque tome."
        case .continuous: "Les chapitres sont numérotés à la suite, le tome est indicatif."
        }
    }

    /// "+1" advances `major` instead of `minor`.
    var stepsMajor: Bool { self == .majorOnly }

    var showsMinor: Bool { self != .majorOnly }

    /// Whether `minor` restarts at each new `major`.
    var minorResetsPerMajor: Bool { self == .nested }

    /// Lowest valid `major`: tome 0 means "not started" when tomes are the unit, otherwise
    /// the work is always in some saison / tome.
    var minimumMajor: Int { stepsMajor ? 0 : 1 }

    /// Units consumed by one position change (negative when moving back), used by the statistics.
    ///
    /// For `nested`, crossing into another `major` counts the units reached in the new one
    /// (S1·É12 → S2·É1 is one épisode): the size of the previous saison is not known afterwards.
    func units(fromMajor: Int, fromMinor: Int, toMajor: Int, toMinor: Int) -> Int {
        switch self {
        case .majorOnly:
            return toMajor - fromMajor
        case .continuous:
            return toMinor - fromMinor
        case .nested:
            if toMajor == fromMajor { return toMinor - fromMinor }
            return toMajor > fromMajor ? toMinor : -fromMinor
        }
    }
}
