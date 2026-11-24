import SwiftData
import SwiftUI

/// The search tab (iOS 26 search role: the field lives in the tab bar).
/// The field is activated (keyboard up) every time the tab is selected.
struct SearchView: View {
    /// Whether the search tab is the selected one.
    var isSelected = true
    @Query(sort: \Work.lastProgressAt, order: .reverse) private var works: [Work]
    @Namespace private var namespace
    @State private var query = ""
    @State private var isSearching = false

    private var results: [Work] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(works.prefix(8)) }
        return works.filter {
            $0.title.localizedStandardContains(trimmed) || $0.note.localizedStandardContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if query.isEmpty, !works.isEmpty {
                        SectionHeader(title: "Récemment", symbol: "clock.arrow.circlepath")
                    }
                    ForEach(results) { work in
                        NavigationLink(value: work) {
                            SearchRow(work: work)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: work.id, in: namespace)
                    }
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
                .padding(.horizontal, 16)
            }
            .canvasBackground()
            .navigationTitle("Recherche")
            .searchable(text: $query, isPresented: $isSearching, prompt: "Un titre, une note…")
            .onChange(of: isSelected, initial: true) { _, selected in
                if selected { isSearching = true }
            }
            .workDestination(in: namespace)
        }
    }
}

private struct SearchRow: View {
    let work: Work

    var body: some View {
        HStack(spacing: 12) {
            CoverView(work: work, cornerRadius: 10)
                .frame(width: 40, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text(work.title).font(.headline).lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: work.kind.symbol).foregroundStyle(work.kind.tint)
                    Text("\(work.kind.label) · \(work.status.label)")
                }
                .font(.caption)
                .foregroundStyle(Color.inkSecondary)
            }
            Spacer()
            Text(work.positionText)
                .font(.rounded(.subheadline))
                .monospacedDigit()
        }
        .surfaceCard(padding: 10)
    }
}
