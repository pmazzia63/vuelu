import SwiftData
import SwiftUI

struct WorkDetailView: View {
    @Bindable var work: Work
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                positionCard
                releaseCard
                noteCard
                historyCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(alignment: .top) { backdrop }
        .background(Color.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy) { work.isFavorite.toggle() }
                } label: {
                    Image(systemName: work.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(work.isFavorite ? Color.brandDeep : Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .sensoryFeedback(.selection, trigger: work.isFavorite)
                .accessibilityLabel(work.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifier", systemImage: "pencil") { showEditor = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Plus", systemImage: "ellipsis") {
                    Picker("Statut", selection: $work.status.animation(.snappy)) {
                        ForEach(WorkStatus.allCases) { status in
                            Label(status.label, systemImage: status.symbol).tag(status)
                        }
                    }
                    Divider()
                    Button("Supprimer", systemImage: "trash", role: .destructive) { confirmDelete = true }
                }
            }
        }
        .sheet(isPresented: $showEditor) { WorkEditorView(work: work) }
        .confirmationDialog("Supprimer « \(work.title) » ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                context.delete(work)
                dismiss()
            }
        } message: {
            Text("Ta progression et son historique seront effacés.")
        }
    }

    // MARK: Header

    private var backdrop: some View {
        ZStack {
            if let data = work.coverImage, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().blur(radius: 40).opacity(0.55)
            } else {
                LinearGradient(colors: [work.kind.tint.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
            }
        }
        .frame(height: 420)
        .frame(maxWidth: .infinity)
        .clipped()
        .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            CoverView(work: work, cornerRadius: 18, showsTitle: true)
                .frame(width: 118, height: 170)
                .shadow(color: work.kind.tint.opacity(0.5), radius: 20, y: 10)
            VStack(alignment: .leading, spacing: 8) {
                KindBadge(kind: work.kind)
                Text(work.title)
                    .font(.rounded(.title))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Label(work.status.label, systemImage: work.status.symbol)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    // MARK: Position

    private var positionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Où j'en suis").font(.subheadline.weight(.semibold)).foregroundStyle(Color.inkSecondary)
                    Text(work.positionText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    ProgressStamp(work: work)
                }
                Spacer()
                BookmarkGauge(fraction: work.progressFraction, tint: work.kind.tint)
                    .frame(width: 54, height: 66)
            }

            VStack(spacing: 10) {
                CounterRow(
                    title: work.kind.majorName,
                    value: work.major,
                    total: work.majorTotal,
                    canDecrement: work.major > work.mode.minimumMajor,
                    onDecrement: { work.setPosition(major: work.major - 1, minor: work.minor) },
                    onIncrement: { work.mode.stepsMajor ? work.advance() : work.advanceMajor() }
                )
                if work.mode.showsMinor {
                    CounterRow(
                        title: work.kind.minorName,
                        value: work.minor,
                        total: work.minorTotal,
                        canDecrement: work.minor > 0,
                        onDecrement: { work.setPosition(major: work.major, minor: work.minor - 1) },
                        onIncrement: { work.setPosition(major: work.major, minor: work.minor + 1) }
                    )
                }
            }
            .sensoryFeedback(.selection, trigger: work.lastProgressAt)

            HStack {
                Button {
                    withAnimation(.snappy) { work.advance() }
                } label: {
                    Label(work.nextActionLabel, systemImage: "plus")
                        .font(.rounded(.headline))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.brandFill)
                .controlSize(.large)
                .sensoryFeedback(.increase, trigger: work.major * 10_000 + work.minor)

                if !work.history.isEmpty {
                    Button {
                        withAnimation(.snappy) { _ = work.undoLast() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward").font(.headline)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .accessibilityLabel("Annuler la dernière avancée")
                }
            }
        }
        .surfaceCard()
    }

    // MARK: Release

    private var releaseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Prochaine sortie", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            if let date = work.nextReleaseAt {
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .font(.rounded(.title3))
                HStack(spacing: 8) {
                    if work.hasNewRelease() {
                        NewReleaseBadge(work: work)
                    } else {
                        Text(date, format: .relative(presentation: .named, unitsStyle: .wide))
                            .font(.subheadline)
                            .foregroundStyle(Color.inkSecondary)
                    }
                    if work.cadence.hasReleaseDate {
                        Text(work.cadence.label)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.brand.opacity(0.15), in: .capsule)
                    }
                }
            } else {
                Text("Pas de date prévue")
                    .font(.rounded(.title3, weight: .semibold))
                Button("Ajouter un rythme de sortie", systemImage: "bell.badge") { showEditor = true }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .surfaceCard()
    }

    // MARK: Note

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Note", systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            TextField("Un avis, où trouver la suite, un rappel…", text: $work.note, axis: .vertical)
                .lineLimit(2...8)
        }
        .surfaceCard()
    }

    // MARK: History

    @ViewBuilder
    private var historyCard: some View {
        let entries = Array(work.sortedHistory.prefix(10))
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Historique", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.inkSecondary)
                ForEach(entries) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.isForward ? "arrow.up.right" : "arrow.down.left")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(entry.isForward ? work.kind.tint : Color.inkSecondary)
                            .frame(width: 20)
                        Text(work.positionText(major: entry.toMajor, minor: entry.toMinor))
                            .font(.rounded(.subheadline, weight: .semibold))
                            .monospacedDigit()
                        Spacer()
                        Text(entry.date, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                            .font(.caption)
                            .foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            .surfaceCard()
        }
    }
}

/// "Saison 2 / 4   (−) (+)" with glass buttons.
private struct CounterRow: View {
    let title: String
    let value: Int
    let total: Int?
    let canDecrement: Bool
    let onDecrement: () -> Void
    let onIncrement: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Color.inkSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(value)")
                        .font(.rounded(.title2))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(value)))
                    if let total {
                        Text("/ \(total)").font(.subheadline).foregroundStyle(Color.inkSecondary)
                    }
                }
            }
            Spacer()
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    stepButton("minus", label: "Moins", enabled: canDecrement, action: onDecrement)
                    stepButton("plus", label: "Plus", enabled: true, action: onIncrement)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func stepButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(enabled ? Color.primary : Color.secondary)
                .frame(width: 42, height: 42)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!enabled)
        .accessibilityLabel("\(label) — \(title)")
    }
}

#Preview {
    let container = ModelContainer.preview
    let work = try! container.mainContext.fetch(FetchDescriptor<Work>()).first!
    return NavigationStack { WorkDetailView(work: work) }
        .modelContainer(container)
}
