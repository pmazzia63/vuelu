import Foundation
import SwiftData

/// One change of position. Stores everything needed to undo it exactly.
@Model
final class ProgressEntry {
    var date: Date = Date.now
    var fromMajor: Int = 0
    var fromMinor: Int = 0
    var toMajor: Int = 0
    var toMinor: Int = 0
    var previousStatusRaw: String = WorkStatus.reading.rawValue
    var previousNextReleaseAt: Date?
    var previousLastProgressAt: Date = Date.now
    var work: Work?

    init(
        date: Date,
        fromMajor: Int,
        fromMinor: Int,
        toMajor: Int,
        toMinor: Int,
        previousStatus: WorkStatus,
        previousNextReleaseAt: Date?,
        previousLastProgressAt: Date
    ) {
        self.date = date
        self.fromMajor = fromMajor
        self.fromMinor = fromMinor
        self.toMajor = toMajor
        self.toMinor = toMinor
        self.previousStatusRaw = previousStatus.rawValue
        self.previousNextReleaseAt = previousNextReleaseAt
        self.previousLastProgressAt = previousLastProgressAt
    }

    var previousStatus: WorkStatus {
        WorkStatus(rawValue: previousStatusRaw) ?? .reading
    }

    var isForward: Bool {
        (toMajor, toMinor) > (fromMajor, fromMinor)
    }
}
