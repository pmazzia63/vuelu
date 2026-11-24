import SwiftData
import SwiftUI

/// A row on the home screen: cover, title, position and a "+1" button.
struct WorkCard: View {
    let work: Work
    let namespace: Namespace.ID
    var onAdvance: ((Work) -> Void)?
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack(alignment: .trailing) {
            NavigationLink(value: work) {
                HStack(spacing: 14) {
                    CoverView(work: work, cornerRadius: 12)
                        .frame(width: 58, height: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(work.title)
                            .font(.rounded(.headline, weight: .semibold))
                            .lineLimit(2)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(work.positionText)
                                .font(.rounded(.title2))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            if let hint = work.totalHint {
                                Text(hint).font(.caption).foregroundStyle(Color.inkSecondary)
                            }
                        }
                        ProgressStamp(work: work)
                    }
                    Spacer(minLength: 56)
                }
                .surfaceCard(padding: 12)
                .contentShape(.rect(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: work.id, in: namespace)

            AdvanceButton(work: work, onAdvance: onAdvance)
                .padding(.trailing, 16)
        }
        .contextMenu { WorkActions(work: work, context: context) }
    }
}

/// Adds to / removes from the home screen's "Favoris" shelf.
struct FavoriteButton: View {
    let work: Work

    var body: some View {
        Button(
            work.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
            systemImage: work.isFavorite ? "heart.slash" : "heart"
        ) {
            withAnimation(.snappy) { work.isFavorite.toggle() }
        }
    }
}

/// Shared quick actions for a work (context menus, detail toolbar).
struct WorkActions: View {
    let work: Work
    let context: ModelContext

    var body: some View {
        FavoriteButton(work: work)
        if work.mode.showsMinor {
            Button(work.kind.nextMajorLabel, systemImage: "forward.end.fill") {
                withAnimation(.snappy) { work.advanceMajor() }
            }
        }
        if !work.history.isEmpty {
            Button("Annuler la dernière avancée", systemImage: "arrow.uturn.backward") {
                withAnimation(.snappy) { _ = work.undoLast() }
            }
        }
        Picker("Statut", systemImage: "flag", selection: Binding(
            get: { work.status },
            set: { newValue in withAnimation(.snappy) { work.status = newValue } }
        )) {
            ForEach(WorkStatus.allCases) { status in
                Label(status.label, systemImage: status.symbol).tag(status)
            }
        }
        .pickerStyle(.menu)
        Divider()
        Button("Supprimer", systemImage: "trash", role: .destructive) {
            withAnimation { context.delete(work) }
        }
    }
}
