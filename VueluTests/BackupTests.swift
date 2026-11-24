import Foundation
import SwiftData
import Testing
@testable import Vuelu

@MainActor
final class BackupTests {
    /// A context does not retain its container: keep them alive for the whole test.
    private var containers: [ModelContainer] = []

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Work.self, ProgressEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        containers.append(container)
        return container.mainContext
    }

    @Test func roundTripPreservesWorksAndHistory() throws {
        let source = try makeContext()
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let work = Work(title: "Lames d'Automne", kind: .anime, minor: 3, minorTotal: 12,
                        cadence: .weekly, nextReleaseAt: t0, note: "VOSTFR", coverImage: Data([1, 2, 3]),
                        createdAt: t0)
        source.insert(work)
        work.advance(at: t0.addingTimeInterval(60))
        work.advance(at: t0.addingTimeInterval(120))

        let payload = BackupService.makePayload(from: [work], now: t0)
        let decoded = try BackupService.decode(BackupService.encode(payload))
        #expect(decoded.works == payload.works)

        let target = try makeContext()
        #expect(try BackupService.restore(decoded, into: target) == 1)
        let restored = try #require(try target.fetch(FetchDescriptor<Work>()).first)
        #expect(restored.id == work.id)
        #expect(restored.positionText == "S1 · É5")
        #expect(restored.note == "VOSTFR")
        #expect(restored.coverImage == Data([1, 2, 3]))
        #expect(restored.history.count == 2)

        // The restored history still supports undo.
        restored.undoLast()
        #expect(restored.minor == 4)
    }

    @Test func restoringTwiceReplacesInsteadOfDuplicating() throws {
        let source = try makeContext()
        let work = Work(title: "Le Cartographe", kind: .bd, major: 2)
        source.insert(work)
        let payload = BackupService.makePayload(from: [work])

        let target = try makeContext()
        try BackupService.restore(payload, into: target)
        try BackupService.restore(payload, into: target)
        #expect(try target.fetchCount(FetchDescriptor<Work>()) == 1)
    }
}
