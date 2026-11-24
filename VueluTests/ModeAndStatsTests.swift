import Foundation
import SwiftData
import Testing
@testable import Vuelu

@MainActor
struct ModeAndStatsTests {
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

    private func day(_ n: Double) -> Date { t0.addingTimeInterval(n * 86_400) }

    private func make(_ kind: WorkKind, mode: TrackingMode? = nil, major: Int? = nil, minor: Int = 0,
                      majorTotal: Int? = nil, minorTotal: Int? = nil, unitLength: Int? = nil) -> Work {
        let work = Work(title: "Test", kind: kind, mode: mode, major: major, minor: minor,
                        majorTotal: majorTotal, minorTotal: minorTotal, unitLength: unitLength, createdAt: t0)
        context.insert(work)
        return work
    }

    // MARK: Modes

    @Test func defaultsMatchPreviousBehaviour() {
        #expect(make(.manga).mode == .continuous)
        #expect(make(.bd).mode == .majorOnly)
        #expect(make(.book).mode == .nested)
        #expect(make(.series).mode == .nested)
    }

    @Test func seriesCannotUseTomeModes() {
        let work = make(.series, mode: .majorOnly)
        #expect(work.mode == .nested)
        work.modeRaw = TrackingMode.continuous.rawValue
        #expect(work.mode == .nested)
    }

    @Test func missingModeFallsBackToKindDefault() {
        let work = make(.manga)
        work.modeRaw = nil
        #expect(work.mode == .continuous)
    }

    @Test func mangaPerTome() {
        let work = make(.manga, mode: .majorOnly, majorTotal: 3)
        #expect(work.major == 0)
        work.advance(at: day(1))
        #expect(work.positionText == "Tome 1")
        work.advance(at: day(2))
        work.advance(at: day(3))
        #expect(work.status == .finished)
    }

    @Test func mangaTomeAndChapterRollsOver() {
        let work = make(.manga, mode: .nested, major: 2, minor: 9, minorTotal: 9)
        work.advance(at: day(1))
        #expect(work.major == 3)
        #expect(work.minor == 1)
        #expect(work.positionText == "T3 · Ch. 1")
    }

    @Test func absoluteChapterNextTomeKeepsChapterAndRelease() {
        let work = make(.manga, major: 4, minor: 37)
        work.cadence = .weekly
        work.nextReleaseAt = day(-1)
        work.advanceMajor(at: day(1))
        #expect(work.major == 5)
        #expect(work.minor == 37)
        // Changing the informative tome is not progress: the pending chapter is still pending.
        #expect(work.nextReleaseAt == day(-1))
    }

    @Test func draftSwitchingModeKeepsPositionValid() {
        var draft = WorkDraft(kind: .book)
        #expect(draft.mode == .nested)
        #expect(draft.major == 1)
        draft.adapt(to: .majorOnly)
        #expect(draft.major == 0)
        #expect(draft.minor == 0)
        draft.adapt(to: .continuous)
        #expect(draft.major == 1)
    }

    @Test func draftKindChangeKeepsModeOfExistingWork() {
        var draft = WorkDraft(work: make(.book, mode: .continuous, minor: 30))
        draft.adapt(to: .manga, isNew: false)
        #expect(draft.mode == .continuous)
        draft.adapt(to: .series, isNew: false)
        #expect(draft.mode == .nested)
    }

    @Test func draftAppliesMode() {
        let work = make(.book)
        var draft = WorkDraft(work: work)
        draft.adapt(to: .majorOnly)
        draft.major = 2
        draft.apply(to: work, now: day(1))
        #expect(work.mode == .majorOnly)
        #expect(work.positionText == "Tome 2")
    }

    // MARK: Units

    @Test func unitsPerMode() {
        #expect(TrackingMode.majorOnly.units(fromMajor: 1, fromMinor: 0, toMajor: 3, toMinor: 0) == 2)
        #expect(TrackingMode.continuous.units(fromMajor: 4, fromMinor: 30, toMajor: 5, toMinor: 33) == 3)
        #expect(TrackingMode.nested.units(fromMajor: 1, fromMinor: 3, toMajor: 1, toMinor: 5) == 2)
        #expect(TrackingMode.nested.units(fromMajor: 1, fromMinor: 12, toMajor: 2, toMinor: 1) == 1)
        #expect(TrackingMode.nested.units(fromMajor: 2, fromMinor: 1, toMajor: 1, toMinor: 12) == -1)
    }

    // MARK: Stats

    @Test func statsCountMinutesPagesAndUnits() {
        let anime = make(.anime, minor: 2, unitLength: 24)
        anime.advance(at: day(-3))
        anime.advance(at: day(-2))
        let manga = make(.manga, minor: 10, unitLength: 18)
        manga.advance(at: day(-2))
        let bd = make(.bd)
        bd.advance(at: day(-1))

        let stats = ReadingStats(works: [anime, manga, bd], period: .all, now: t0)
        #expect(stats.minutes == 48)
        #expect(stats.pages == 18)
        #expect(stats.units[.episode] == 2)
        #expect(stats.units[.chapter] == 1)
        #expect(stats.units[.tome] == 1)
        #expect(stats.activeDays == 3)
        #expect(stats.topWorks.first?.work === anime)
        #expect(stats.worksMissingLength.map(\.id) == [bd.id])
    }

    @Test func statsRespectPeriodAndCorrections() {
        let series = make(.series, unitLength: 40)
        series.advance(at: day(-60))
        series.advance(at: day(-2))
        series.advance(at: day(-1))
        series.setPosition(major: 1, minor: 2, at: day(-1))  // one step back: a correction

        let week = ReadingStats(works: [series], period: .week, now: t0)
        #expect(week.units[.episode] == 1)
        #expect(week.minutes == 40)

        let all = ReadingStats(works: [series], period: .all, now: t0)
        #expect(all.units[.episode] == 2)
    }

    @Test func undoneProgressDisappearsFromStats() {
        let book = make(.book, unitLength: 10)
        book.advance(at: day(-1))
        book.undoLast()
        #expect(ReadingStats(works: [book], period: .all, now: t0).isEmpty)
    }

    @Test func homeShowsFavoritesShelf() {
        let finished = make(.anime)
        finished.status = .finished
        finished.isFavorite = true
        let reading = make(.manga)
        reading.isFavorite = true
        let sections = HomeSections(works: [finished, reading], now: t0)
        #expect(sections.favorites.map(\.id) == [reading.id, finished.id])
        #expect(sections.resume === reading)
    }

    // MARK: Backup

    @Test func versionOneBackupStillDecodes() throws {
        let json = """
        {"version":1,"exportedAt":"2027-01-15T08:00:00Z","works":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF",
        "title":"Kitsune","kind":"manga","status":"reading","major":3,"minor":20,"cadence":"none","note":"",
        "createdAt":"2027-01-01T08:00:00Z","lastProgressAt":"2027-01-01T08:00:00Z","history":[]}]}
        """
        let payload = try BackupService.decode(Data(json.utf8))
        try BackupService.restore(payload, into: context)
        let work = try #require(try context.fetch(FetchDescriptor<Work>()).first)
        #expect(work.mode == .continuous)
        #expect(!work.isFavorite)
        #expect(work.unitLength == nil)
    }

    @Test func backupKeepsModeFavoriteAndLength() throws {
        let work = make(.book, mode: .majorOnly, major: 2, unitLength: 320)
        work.isFavorite = true
        let payload = try BackupService.decode(BackupService.encode(BackupService.makePayload(from: [work])))
        let record = try #require(payload.works.first)
        #expect(record.mode == "majorOnly")
        #expect(record.isFavorite == true)
        #expect(record.unitLength == 320)
    }
}
