import SwiftData
import SwiftUI

/// "En cours": what to pick up next, grouped so forgotten series stand out.
struct HomeView: View {
    @Query(sort: \Work.lastProgressAt, order: .reverse) private var works: [Work]
    @Namespace private var namespace
    @State private var showEditor = false
    @State private var showSettings = false
    @State private var editedWork: Work?
    @State private var undoTarget: Work?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            let sections = HomeSections(works: works, now: .now)
            ScrollView {
                if sections.isEmpty {
                    EmptyStateView(
                        title: "Rien en cours",
                        message: "Ajoute une série, un manga ou un livre\npour garder ta page.",
                        actionTitle: "Ajouter une œuvre"
                    ) { showEditor = true }
                    .padding(.top, 80)
                } else {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        if let hero = sections.resume {
                            ResumeHero(work: hero, namespace: namespace, onAdvance: showUndo)
                        }
                        favorites(sections.favorites)
                        section("Nouveautés dispo", symbol: "sparkles", works: sections.fresh)
                        upcoming(sections.upcoming)
                        section("En cours", symbol: "bookmark.fill", works: sections.reading)
                        section("À commencer", symbol: "clock", works: sections.planned)
                        section("Délaissées", symbol: "moon.zzz.fill", works: sections.stale,
                                footer: "Pas touchées depuis plus d'un mois.")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .canvasBackground()
            .navigationTitle("En cours")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Réglages", systemImage: "gearshape") { showSettings = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter", systemImage: "plus") { showEditor = true }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let undoTarget {
                    UndoToast(work: undoTarget) {
                        withAnimation(.snappy) {
                            undoTarget.undoLast()
                            self.undoTarget = nil
                        }
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .workDestination(in: namespace)
            .sheet(isPresented: $showEditor) { WorkEditorView() }
            .sheet(item: $editedWork) { WorkEditorView(work: $0) }
            #if DEBUG
            .onAppear {
                // `-openEditor new|edit` opens the editor sheet (handy for simulator screenshots).
                let args = ProcessInfo.processInfo.arguments
                guard let index = args.firstIndex(of: "-openEditor"), args.indices.contains(index + 1) else { return }
                if args[index + 1] == "edit" { editedWork = works.first { $0.kind == .manga } } else { showEditor = true }
            }
            #endif
            .sheet(isPresented: $showSettings) { SettingsView() }
        }
    }

    @ViewBuilder
    private func section(_ title: String, symbol: String, works: [Work], footer: String? = nil) -> some View {
        if !works.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: title, symbol: symbol, count: works.count)
                ForEach(works) { work in
                    WorkCard(work: work, namespace: namespace, onAdvance: showUndo)
                }
                if let footer {
                    Text(footer).font(.footnote).foregroundStyle(Color.inkSecondary).padding(.leading, 4)
                }
            }
        }
    }

    /// Horizontal cover shelf. A shortcut row: favourites also keep their place in the sections below.
    @ViewBuilder
    private func favorites(_ works: [Work]) -> some View {
        if !works.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Favoris", symbol: "heart.fill", count: works.count)
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(works) { work in
                            NavigationLink(value: work) {
                                LibraryTile(work: work, showsFavoriteBadge: false)
                                    .frame(width: 100)
                            }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(id: work.id, in: namespace)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    @ViewBuilder
    private func upcoming(_ works: [Work]) -> some View {
        if !works.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Cette semaine", symbol: "calendar", count: works.count)
                ScrollView(.horizontal) {
                    GlassEffectContainer(spacing: 10) {
                        HStack(spacing: 10) {
                            ForEach(works) { work in
                                NavigationLink(value: work) {
                                    UpcomingChip(work: work)
                                }
                                .buttonStyle(.plain)
                                .matchedTransitionSource(id: work.id, in: namespace)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
        }
    }

    private func showUndo(_ work: Work) {
        withAnimation(.snappy) { undoTarget = work }
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { undoTarget = nil }
        }
    }
}

/// Splits the library into the home screen's sections. Each work appears at most once,
/// except in `favorites`, a shortcut shelf that also lists finished works.
struct HomeSections {
    var resume: Work?
    var favorites: [Work] = []
    var fresh: [Work] = []
    var upcoming: [Work] = []
    var reading: [Work] = []
    var planned: [Work] = []
    var stale: [Work] = []

    /// `works` is expected sorted by most recent progress first.
    init(works: [Work], now: Date) {
        // Followed works first (most recent progress first), then finished / dropped ones.
        let favs = works.filter(\.isFavorite)
        favorites = favs.filter { $0.status.isTracked } + favs.filter { !$0.status.isTracked }
        let tracked = works.filter { $0.status.isTracked }
        fresh = tracked
            .filter { $0.hasNewRelease(at: now) }
            .sorted { ($0.nextReleaseAt ?? now) < ($1.nextReleaseAt ?? now) }
        let active = tracked.filter { $0.status == .reading && !$0.hasNewRelease(at: now) }
        let recent = active.filter { !$0.isStale(at: now) }
        resume = recent.first
        reading = Array(recent.dropFirst())
        stale = active.filter { $0.isStale(at: now) }
        planned = tracked.filter { $0.status == .planned && !$0.hasNewRelease(at: now) }
        let weekAhead = now.addingTimeInterval(7 * 86_400)
        upcoming = tracked
            .filter { work in work.nextReleaseAt.map { $0 > now && $0 <= weekAhead } ?? false }
            .sorted { ($0.nextReleaseAt ?? now) < ($1.nextReleaseAt ?? now) }
    }

    var isEmpty: Bool {
        resume == nil && favorites.isEmpty && fresh.isEmpty && upcoming.isEmpty && reading.isEmpty && planned.isEmpty && stale.isEmpty
    }
}

struct SectionHeader: View {
    let title: String
    let symbol: String
    var count: Int?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(Color.brand)
            Text(title).font(.rounded(.title3))
            if let count {
                Text("\(count)")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
            }
        }
        .padding(.leading, 4)
    }
}

private struct UpcomingChip: View {
    let work: Work

    var body: some View {
        HStack(spacing: 10) {
            CoverView(work: work, cornerRadius: 8)
                .frame(width: 28, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(work.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                if let date = work.nextReleaseAt {
                    Text(date, format: .dateTime.weekday(.wide).hour().minute())
                        .font(.caption)
                        .foregroundStyle(Color.inkSecondary)
                }
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(work.kind.tint.opacity(0.3)).interactive(), in: .capsule)
    }
}

private struct UndoToast: View {
    let work: Work
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BookmarkShape().fill(work.kind.tint).frame(width: 12, height: 15)
            Text("\(work.title) · \(work.positionText)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .contentTransition(.numericText())
            Button("Annuler", action: onUndo)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.brandDeep)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .capsule)
    }
}

#Preview {
    HomeView().modelContainer(.preview)
}
