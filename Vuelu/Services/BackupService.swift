import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// JSON backup of the whole library. Without a server this is the only way to move data
/// between devices or survive a reinstall.
nonisolated struct BackupPayload: Codable, Sendable {
    /// 2 added `mode`, `isFavorite` and `unitLength` (optional, so version 1 files still decode).
    var version = 2
    var exportedAt: Date
    var works: [WorkRecord]
}

nonisolated struct WorkRecord: Codable, Sendable, Equatable {
    var id: UUID
    var title: String
    var kind: String
    var mode: String?
    var status: String
    var major: Int
    var minor: Int
    var majorTotal: Int?
    var minorTotal: Int?
    var cadence: String
    var nextReleaseAt: Date?
    var note: String
    var isFavorite: Bool?
    var unitLength: Int?
    var coverImage: Data?
    var createdAt: Date
    var lastProgressAt: Date
    var history: [EntryRecord]
}

nonisolated struct EntryRecord: Codable, Sendable, Equatable {
    var date: Date
    var fromMajor: Int
    var fromMinor: Int
    var toMajor: Int
    var toMinor: Int
    var previousStatus: String
    var previousNextReleaseAt: Date?
    var previousLastProgressAt: Date
}

enum BackupService {
    static func makePayload(from works: [Work], now: Date = .now) -> BackupPayload {
        BackupPayload(exportedAt: now, works: works.map(record(for:)))
    }

    nonisolated static func encode(_ payload: BackupPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    nonisolated static func decode(_ data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupPayload.self, from: data)
    }

    /// Inserts every work from the backup. A work already present (same id) is replaced.
    @discardableResult
    static func restore(_ payload: BackupPayload, into context: ModelContext) throws -> Int {
        for record in payload.works {
            let id = record.id
            let existing = try context.fetch(FetchDescriptor<Work>(predicate: #Predicate { $0.id == id }))
            existing.forEach(context.delete)
            context.insert(makeWork(from: record))
        }
        try context.save()
        return payload.works.count
    }

    static func defaultFilename(now: Date = .now) -> String {
        "vuelu-sauvegarde-\(now.formatted(.iso8601.year().month().day()))"
    }

    private static func record(for work: Work) -> WorkRecord {
        WorkRecord(
            id: work.id,
            title: work.title,
            kind: work.kindRaw,
            mode: work.mode.rawValue,
            status: work.statusRaw,
            major: work.major,
            minor: work.minor,
            majorTotal: work.majorTotal,
            minorTotal: work.minorTotal,
            cadence: work.cadenceRaw,
            nextReleaseAt: work.nextReleaseAt,
            note: work.note,
            isFavorite: work.isFavorite,
            unitLength: work.unitLength,
            coverImage: work.coverImage,
            createdAt: work.createdAt,
            lastProgressAt: work.lastProgressAt,
            history: work.sortedHistory.map { entry in
                EntryRecord(
                    date: entry.date,
                    fromMajor: entry.fromMajor,
                    fromMinor: entry.fromMinor,
                    toMajor: entry.toMajor,
                    toMinor: entry.toMinor,
                    previousStatus: entry.previousStatusRaw,
                    previousNextReleaseAt: entry.previousNextReleaseAt,
                    previousLastProgressAt: entry.previousLastProgressAt
                )
            }
        )
    }

    private static func makeWork(from record: WorkRecord) -> Work {
        let work = Work(
            id: record.id,
            title: record.title,
            kind: WorkKind(rawValue: record.kind) ?? .series,
            mode: record.mode.flatMap(TrackingMode.init(rawValue:)),
            status: WorkStatus(rawValue: record.status) ?? .reading,
            major: record.major,
            minor: record.minor,
            majorTotal: record.majorTotal,
            minorTotal: record.minorTotal,
            cadence: ReleaseCadence(rawValue: record.cadence) ?? .none,
            nextReleaseAt: record.nextReleaseAt,
            note: record.note,
            isFavorite: record.isFavorite ?? false,
            unitLength: record.unitLength,
            coverImage: record.coverImage,
            createdAt: record.createdAt,
            lastProgressAt: record.lastProgressAt
        )
        work.history = record.history.map { entry in
            ProgressEntry(
                date: entry.date,
                fromMajor: entry.fromMajor,
                fromMinor: entry.fromMinor,
                toMajor: entry.toMajor,
                toMinor: entry.toMinor,
                previousStatus: WorkStatus(rawValue: entry.previousStatus) ?? .reading,
                previousNextReleaseAt: entry.previousNextReleaseAt,
                previousLastProgressAt: entry.previousLastProgressAt
            )
        }
        return work
    }
}

/// Wraps the backup JSON for `fileExporter`.
nonisolated struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
