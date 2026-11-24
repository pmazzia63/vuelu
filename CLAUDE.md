# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Product

Vuelu is a personal iOS app for tracking progress through serialized media: comics (BD), books, manga, TV series and anime. The core problem: with seasons, weekly releases and irregular schedules, it's easy to forget where you stopped. The UI is in French.

Hard constraints:
- **Local-only.** No backend, no server, no account. All data lives on the device (SwiftData); the JSON export/import in Settings is the only backup path.
- iOS 26 minimum, iPhone only. SwiftUI + SwiftData, no third-party dependencies.
- Visual identity comes from `logo.png` (violet bookmark on lavender): colours in `Vuelu/Theme/Palette.swift`, the bookmark silhouette in `BookmarkShape`. Liquid Glass (`glassEffect`, `.glass`/`.glassProminent` button styles) for floating controls.

## Commands

`xcode-select` points at the CommandLineTools, so prefix every command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` (or export it).

```sh
# Build
xcodebuild -project Vuelu.xcodeproj -scheme Vuelu -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath .build/DerivedData build
# All tests (Swift Testing, VueluTests target)
xcodebuild ... test
# One test
xcodebuild ... test -only-testing:VueluTests/WorkTests/advanceRollsOverSeason
```

Run in the simulator with sample data (DEBUG launch arguments handled in `VueluApp.swift`):

```sh
xcrun simctl install booted .build/DerivedData/Build/Products/Debug-iphonesimulator/Vuelu.app
xcrun simctl launch --terminate-running-process booted com.vuelu.app -inMemoryStore -seedSampleData -AppleLanguages "(fr)" -AppleLocale fr_FR [-initialTab library|search]
xcrun simctl io booted screenshot out.png
```

## Project setup

`Vuelu.xcodeproj` was written by hand and uses **folder-synchronized groups**: any file added under `Vuelu/` or `VueluTests/` is compiled automatically; don't edit `project.pbxproj` to add files. Build settings use Swift 6 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so everything is main-actor by default: types that must conform to non-isolated protocols (`Shape`, `FileDocument`, `Codable` payloads, enums used from `Color` helpers) are marked `nonisolated`.

## Architecture

- `Model/Work.swift` is the core. Every work stores its position as two generic levels, `major`/`minor`, whose meaning depends on `WorkKind` (saison/épisode, tome/chapitre, BD = tome only). All progress logic lives on the model and is what the tests cover:
  - `advance()` is the "+1" (rolls to the next saison when `minorTotal` is reached for kinds where `minorResetsPerMajor`; BD step `major`).
  - Every position change goes through `setPosition`, which records a `ProgressEntry` holding enough state (previous status, `nextReleaseAt`, `lastProgressAt`) for `undoLast()` to revert it exactly. Don't mutate `major`/`minor` directly from views.
  - Moving forward consumes **one** pending release: `nextReleaseAt` advances by one cadence step only if it was already past. This is how a user three weekly episodes behind stays in "Nouveautés" until caught up.
- Enums are persisted as raw strings (`kindRaw`, `statusRaw`, `cadenceRaw`) with typed computed accessors, so they work in `#Predicate` and survive renames.
- `Features/Home/HomeView.swift` → `HomeSections` decides which section each work appears in (resume hero, nouveautés, cette semaine, en cours, à commencer, délaissées); it's a pure struct and is unit-tested.
- `Features/Editor/WorkDraft` is an editable copy so the editor sheet can be cancelled; `apply(to:)` routes position changes through `setPosition`.
- `Services/ReminderScheduler` rebuilds all local notifications from `RootView` whenever release-relevant data changes (`.task(id:)` on a signature). `Services/BackupService` maps models to Codable records and restores by upserting on `Work.id`.
- Navigation: each tab owns a `NavigationStack` and uses `.workDestination(in:)` (zoom transition) to push `WorkDetailView`.

## Testing notes

- Tests create their own in-memory `ModelContainer`. A `ModelContext` does not retain its container: keep the container alive for the whole test (see `BackupTests`), or the test process crashes.
- When running under XCTest, the host app also uses an in-memory store.
