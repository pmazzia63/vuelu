import SwiftData
import SwiftUI

/// Everything the user tracks, as a cover grid grouped by status and filterable by kind.
struct LibraryView: View {
    @Query(sort: \Work.title) private var works: [Work]
    @Namespace private var namespace
    @State private var kindFilter: WorkKind?
    @State private var showEditor = false

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 14, alignment: .top)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    KindFilterBar(selection: $kindFilter)

                    let filtered = works.filter { kindFilter == nil || $0.kind == kindFilter }
                    if filtered.isEmpty {
                        EmptyStateView(
                            title: works.isEmpty ? "Bibliothèque vide" : "Aucune œuvre ici",
                            message: works.isEmpty
                                ? "Tout ce que tu suis apparaîtra ici."
                                : "Rien pour ce type pour l'instant.",
                            actionTitle: "Ajouter une œuvre"
                        ) { showEditor = true }
                    }

                    ForEach(WorkStatus.allCases) { status in
                        let group = filtered.filter { $0.status == status }
                        if !group.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: status.label, symbol: status.symbol, count: group.count)
                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(group) { work in
                                        NavigationLink(value: work) {
                                            LibraryTile(work: work)
                                        }
                                        .buttonStyle(.plain)
                                        .matchedTransitionSource(id: work.id, in: namespace)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.snappy, value: kindFilter)
            }
            .canvasBackground()
            .navigationTitle("Bibliothèque")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter", systemImage: "plus") { showEditor = true }
                }
            }
            .workDestination(in: namespace)
            .sheet(isPresented: $showEditor) { WorkEditorView(initialKind: kindFilter) }
        }
    }
}

struct LibraryTile: View {
    let work: Work
    var showsFavoriteBadge = true
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay { CoverView(work: work) }
                .overlay(alignment: .bottomLeading) {
                    Text(work.positionText)
                        .font(.rounded(.caption))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .capsule)
                        .padding(6)
                }
                .overlay(alignment: .topTrailing) {
                    if showsFavoriteBadge, work.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.brandDeep)
                            .padding(6)
                            .glassEffect(.regular, in: .circle)
                            .padding(6)
                            .accessibilityLabel("Favori")
                    }
                }
                .overlay(alignment: .topLeading) {
                    if work.hasNewRelease() {
                        Image(systemName: "sparkle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.brandDeep, in: .circle)
                            .padding(6)
                    }
                }
                .shadow(color: work.kind.tint.opacity(0.35), radius: 10, y: 5)
            Text(work.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
        }
        .contentShape(.rect)
        .contextMenu { WorkActions(work: work, context: context) }
    }
}

/// Horizontal glass chips: "Tout" plus one per kind.
struct KindFilterBar: View {
    @Binding var selection: WorkKind?

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip(title: "Tout", symbol: "square.grid.2x2.fill", tint: .brand, isSelected: selection == nil) {
                        selection = nil
                    }
                    ForEach(WorkKind.allCases) { kind in
                        chip(title: kind.label, symbol: kind.symbol, tint: kind.tint, isSelected: selection == kind) {
                            selection = selection == kind ? nil : kind
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func chip(title: String, symbol: String, tint: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(isSelected ? .bold : .medium))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(tint.opacity(0.7)).interactive() : .regular.interactive(), in: .capsule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    LibraryView().modelContainer(.preview)
}
