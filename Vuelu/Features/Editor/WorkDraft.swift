import Foundation
import SwiftData

/// Editable copy of a `Work`, so the editor can be cancelled without touching the store.
struct WorkDraft {
    var title = ""
    var kind: WorkKind = .series
    var mode: TrackingMode = .nested
    var status: WorkStatus = .reading
    var major = 1
    var minor = 0
    var majorTotal: Int?
    var minorTotal: Int?
    var cadence: ReleaseCadence = .none
    var nextReleaseAt: Date = ReleaseCadence.weekly.suggestedNextRelease()
    var note = ""
    var unitLength: Int?
    var coverImage: Data?

    init(kind: WorkKind = .series) {
        self.kind = kind
        self.mode = kind.defaultMode
        self.major = mode.minimumMajor
    }

    init(work: Work) {
        title = work.title
        kind = work.kind
        mode = work.mode
        status = work.status
        major = work.major
        minor = work.minor
        majorTotal = work.majorTotal
        minorTotal = work.minorTotal
        cadence = work.cadence
        nextReleaseAt = work.nextReleaseAt ?? work.cadence.suggestedNextRelease()
        note = work.note
        unitLength = work.unitLength
        coverImage = work.coverImage
    }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedTitle.isEmpty }

    /// Called when the kind changes: a new work takes the kind's default mode, an existing one
    /// keeps its mode when the new kind allows it.
    mutating func adapt(to newKind: WorkKind, isNew: Bool) {
        let newMode = !isNew && newKind.availableModes.contains(mode) ? mode : newKind.defaultMode
        if newMode != mode {
            adapt(to: newMode)
        }
    }

    /// Keeps the position meaningful when the counting mode changes.
    mutating func adapt(to newMode: TrackingMode) {
        let wasUntouched = minor == 0 && major <= 1
        mode = newMode
        major = max(major, newMode.minimumMajor)
        if !newMode.showsMinor { minor = 0 }
        if wasUntouched, newMode.minimumMajor == 0 { major = 0 }
    }

    func makeWork(now: Date = .now) -> Work {
        Work(
            title: trimmedTitle,
            kind: kind,
            mode: mode,
            status: status,
            major: major,
            minor: minor,
            majorTotal: majorTotal,
            minorTotal: minorTotal,
            cadence: cadence,
            nextReleaseAt: cadence.hasReleaseDate ? nextReleaseAt : nil,
            note: note,
            unitLength: unitLength,
            coverImage: coverImage,
            createdAt: now
        )
    }

    /// Writes the draft back. A position change goes through `setPosition` so it lands in the history.
    func apply(to work: Work, now: Date = .now) {
        work.title = trimmedTitle
        work.kind = kind
        work.mode = mode
        work.majorTotal = majorTotal
        work.minorTotal = minorTotal
        work.cadence = cadence
        work.nextReleaseAt = cadence.hasReleaseDate ? nextReleaseAt : nil
        work.note = note
        work.unitLength = unitLength
        work.coverImage = coverImage
        work.status = status
        if (major, minor) != (work.major, work.minor) {
            work.setPosition(major: major, minor: minor, at: now)
            // An explicit status picked in the editor wins over the automatic one.
            work.status = status
        }
    }
}
