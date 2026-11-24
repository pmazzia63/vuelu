import Foundation
import SwiftData
import Testing
@testable import Vuelu

@MainActor
struct WorkTests {
    let container: ModelContainer
    let context: ModelContext
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        container = try ModelContainer(
            for: Work.self, ProgressEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = container.mainContext
    }

    private func make(_ kind: WorkKind, status: WorkStatus = .reading, major: Int? = nil, minor: Int = 0,
                      majorTotal: Int? = nil, minorTotal: Int? = nil,
                      cadence: ReleaseCadence = .none, nextReleaseAt: Date? = nil) -> Work {
        let work = Work(title: "Test", kind: kind, status: status, major: major, minor: minor,
                        majorTotal: majorTotal, minorTotal: minorTotal, cadence: cadence,
                        nextReleaseAt: nextReleaseAt, createdAt: t0)
        context.insert(work)
        return work
    }

    private func day(_ n: Double) -> Date { t0.addingTimeInterval(n * 86_400) }

    @Test func advanceIncrementsEpisode() {
        let work = make(.series, major: 1, minor: 3)
        work.advance(at: day(1))
        #expect(work.major == 1)
        #expect(work.minor == 4)
        #expect(work.lastProgressAt == day(1))
        #expect(work.history.count == 1)
    }

    @Test func advanceRollsOverSeason() {
        let work = make(.series, major: 1, minor: 12, minorTotal: 12)
        work.advance(at: day(1))
        #expect(work.major == 2)
        #expect(work.minor == 1)
        #expect(work.status == .reading)
    }

    @Test func bdAdvancesTome() {
        let work = make(.bd)
        #expect(work.major == 0)
        work.advance(at: day(1))
        work.advance(at: day(2))
        #expect(work.major == 2)
        #expect(work.positionText == "Tome 2")
    }

    @Test func mangaChaptersNeverRollOverOrFinish() {
        let work = make(.manga, major: 10, minor: 100, minorTotal: 100)
        work.advance(at: day(1))
        #expect(work.major == 10)
        #expect(work.minor == 101)
        #expect(work.status == .reading)
    }

    @Test func reachingLastEpisodeOfLastSeasonFinishes() {
        let work = make(.series, major: 3, minor: 9, majorTotal: 3, minorTotal: 10)
        work.advance(at: day(1))
        #expect(work.status == .finished)
    }

    @Test func reachingLastBdTomeFinishes() {
        let work = make(.bd, major: 5, majorTotal: 6)
        work.advance(at: day(1))
        #expect(work.status == .finished)
    }

    @Test func advancingPlannedWorkStartsIt() {
        let work = make(.anime, status: .planned)
        work.advance(at: day(1))
        #expect(work.status == .reading)
    }

    @Test func movingBackDoesNotChangeStatusOrConsumeRelease() {
        let work = make(.series, status: .paused, major: 1, minor: 5,
                        cadence: .weekly, nextReleaseAt: day(-1))
        work.setPosition(major: 1, minor: 4, at: day(1))
        #expect(work.status == .paused)
        #expect(work.nextReleaseAt == day(-1))
    }

    @Test func positionCannotGoBelowMinimum() {
        let work = make(.series, major: 1, minor: 0)
        work.setPosition(major: 0, minor: -3, at: day(1))
        #expect(work.major == 1)
        #expect(work.minor == 0)
        #expect(work.history.isEmpty)
    }

    @Test func undoRestoresEverything() throws {
        let work = make(.series, status: .planned, major: 3, minor: 9, majorTotal: 3, minorTotal: 10,
                        cadence: .weekly, nextReleaseAt: day(-1))
        work.advance(at: day(1))
        #expect(work.status == .finished)

        #expect(work.undoLast())
        #expect(work.major == 3)
        #expect(work.minor == 9)
        #expect(work.status == .planned)
        #expect(work.nextReleaseAt == day(-1))
        #expect(work.lastProgressAt == t0)
        #expect(work.history.isEmpty)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ProgressEntry>()) == 0)
        #expect(!work.undoLast())
    }

    @Test func undoOnlyRevertsLatestStep() {
        let work = make(.manga, minor: 10)
        work.advance(at: day(1))
        work.advance(at: day(2))
        work.undoLast()
        #expect(work.minor == 11)
        #expect(work.lastProgressAt == day(1))
    }

    @Test func eachAdvanceConsumesOneWeeklyRelease() {
        // Three weekly episodes came out while the user was away.
        let now = day(0)
        let work = make(.anime, minor: 4, cadence: .weekly, nextReleaseAt: day(-15))
        #expect(work.hasNewRelease(at: now))

        work.advance(at: now)
        #expect(work.nextReleaseAt == day(-8))
        #expect(work.hasNewRelease(at: now))

        work.advance(at: now)
        #expect(work.nextReleaseAt == day(-1))
        #expect(work.hasNewRelease(at: now))

        work.advance(at: now)
        #expect(work.nextReleaseAt == day(6))
        #expect(!work.hasNewRelease(at: now))

        // Watching ahead of schedule leaves the upcoming release alone.
        work.advance(at: now)
        #expect(work.nextReleaseAt == day(6))
    }

    @Test func oneOffReleaseIsClearedOnceConsumed() {
        let work = make(.series, major: 1, minor: 10, minorTotal: 10, cadence: .irregular, nextReleaseAt: day(-2))
        work.advance(at: day(0))
        #expect(work.major == 2)
        #expect(work.nextReleaseAt == nil)
    }

    @Test func untrackedWorksHaveNoNewRelease() {
        let work = make(.series, status: .dropped, cadence: .weekly, nextReleaseAt: day(-1))
        #expect(!work.hasNewRelease(at: day(0)))
    }

    @Test func staleAfterThirtyDays() {
        let work = make(.book)
        #expect(!work.isStale(at: day(29)))
        #expect(work.isStale(at: day(31)))
        work.status = .paused
        #expect(!work.isStale(at: day(31)))
    }

    @Test func homeSectionsPlaceEachWorkOnce() {
        let now = day(100)
        let fresh = make(.series, cadence: .weekly, nextReleaseAt: day(99))
        let stale = make(.book)
        stale.lastProgressAt = day(10)
        let recent = make(.manga)
        recent.lastProgressAt = day(99)
        let older = make(.anime)
        older.lastProgressAt = day(95)
        _ = make(.bd, status: .finished)

        let sections = HomeSections(works: [recent, fresh, older, stale], now: now)
        #expect(sections.resume === recent)
        #expect(sections.fresh.map(\.id) == [fresh.id])
        #expect(sections.reading.map(\.id) == [older.id])
        #expect(sections.stale.map(\.id) == [stale.id])
    }
}
