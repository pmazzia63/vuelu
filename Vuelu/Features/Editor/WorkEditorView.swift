import PhotosUI
import SwiftData
import SwiftUI

/// Sheet to add a new work or edit an existing one. Only the title is required.
///
/// Built from cards rather than a `Form`: every number is a large tile that starts editing
/// wherever it is tapped, and the keyboard gets an "OK" button (the number pad has no return key).
struct WorkEditorView: View {
    private let work: Work?
    @State private var draft: WorkDraft
    @State private var photoItem: PhotosPickerItem?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: EditorField?

    init(work: Work? = nil, initialKind: WorkKind? = nil) {
        self.work = work
        _draft = State(initialValue: work.map(WorkDraft.init(work:)) ?? WorkDraft(kind: initialKind ?? .series))
    }

    private var isNew: Bool { work == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    identityCard
                    positionCard
                    totalsCard
                    releaseCard
                    statusCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .canvasBackground()
            .navigationTitle(isNew ? "Nouvelle œuvre" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", systemImage: "checkmark", role: .confirm) { save() }
                        .disabled(!draft.isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { focus = nil }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: draft.kind) { _, newKind in
                draft.adapt(to: newKind, isNew: isNew)
            }
            .onChange(of: draft.cadence) { oldValue, newValue in
                if !oldValue.hasReleaseDate, newValue.hasReleaseDate {
                    draft.nextReleaseAt = newValue.suggestedNextRelease()
                }
            }
            .task(id: photoItem) { await loadPhoto() }
            .onAppear { if isNew { focus = .title } }
        }
    }

    // MARK: Identity

    private var identityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        CoverView(kind: draft.kind, title: draft.title, imageData: draft.coverImage,
                                  cornerRadius: 14, showsTitle: true)
                            .frame(width: 84, height: 120)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: draft.coverImage == nil ? "camera.fill" : "pencil")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.primary)
                                    .frame(width: 30, height: 30)
                                    .glassEffect(.regular, in: .circle)
                                    .padding(6)
                            }
                            .shadow(color: draft.kind.tint.opacity(0.4), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(draft.coverImage == nil ? "Ajouter une couverture" : "Changer la couverture")

                    if draft.coverImage != nil {
                        Button("Retirer", role: .destructive) {
                            withAnimation(.snappy) {
                                draft.coverImage = nil
                                photoItem = nil
                            }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Titre").font(.caption.weight(.semibold)).foregroundStyle(Color.inkSecondary)
                    TextField("Le nom de l'œuvre", text: $draft.title, axis: .vertical)
                        .font(.rounded(.title2))
                        .lineLimit(1...3)
                        .focused($focus, equals: .title)
                        .submitLabel(.done)
                        .onChange(of: draft.title) { _, newValue in
                            // A vertical field inserts a newline on return: treat it as "done".
                            if newValue.contains("\n") {
                                draft.title = newValue.replacingOccurrences(of: "\n", with: "")
                                focus = nil
                            }
                        }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 120, alignment: .top)
                .contentShape(.rect)
                .onTapGesture { focus = .title }
            }

            KindPicker(selection: $draft.kind)
        }
        .surfaceCard()
    }

    // MARK: Position

    private var positionCard: some View {
        EditorCard(title: "Où j'en suis", symbol: "bookmark.fill", footer: draft.kind.availableModes.count > 1 ? draft.mode.explanation : nil) {
            if draft.kind.availableModes.count > 1 {
                Picker("Suivi", selection: Binding(
                    get: { draft.mode },
                    set: { newMode in withAnimation(.snappy) { draft.adapt(to: newMode) } }
                )) {
                    ForEach(draft.kind.availableModes) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                PositionTile(
                    title: majorLabel,
                    value: $draft.major,
                    minimum: draft.mode.minimumMajor,
                    field: .major,
                    focus: $focus
                )
                if draft.mode.showsMinor {
                    PositionTile(
                        title: draft.kind.minorName,
                        value: $draft.minor,
                        minimum: 0,
                        field: .minor,
                        focus: $focus
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Totals

    private var totalsCard: some View {
        EditorCard(
            title: "Totaux",
            symbol: "number",
            footer: "Facultatif. La durée ou le nombre de pages alimente les statistiques."
        ) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                NumberTile(title: "\(draft.kind.majorName)s au total", value: $draft.majorTotal, field: .majorTotal, focus: $focus)
                if draft.mode.showsMinor {
                    NumberTile(title: minorTotalLabel, value: $draft.minorTotal, field: .minorTotal, focus: $focus)
                }
                NumberTile(
                    title: draft.kind.unitLengthLabel(mode: draft.mode),
                    value: $draft.unitLength,
                    suffix: draft.kind.unitLengthSuffix,
                    field: .unitLength,
                    focus: $focus
                )
            }
        }
    }

    // MARK: Releases

    private var releaseCard: some View {
        EditorCard(
            title: "Sorties",
            symbol: "calendar",
            footer: draft.cadence == .irregular
                ? "Pour une nouvelle saison ou un tome annoncé : une seule date, à renseigner de nouveau ensuite."
                : draft.cadence.hasReleaseDate ? "Quand la date passe, l'œuvre remonte dans « Nouveautés dispo »." : nil
        ) {
            Picker("Rythme", selection: $draft.cadence.animation(.snappy)) {
                ForEach(ReleaseCadence.allCases) { cadence in
                    Text(cadence.shortLabel).tag(cadence)
                }
            }
            .pickerStyle(.segmented)

            if draft.cadence.hasReleaseDate {
                DatePicker("Prochaine sortie", selection: $draft.nextReleaseAt)
                    .font(.subheadline.weight(.medium))
                    .transition(.opacity)
            }
        }
    }

    // MARK: Status

    private var statusCard: some View {
        EditorCard(title: "Statut", symbol: "flag.fill") {
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(WorkStatus.allCases) { status in
                            let isSelected = status == draft.status
                            Button {
                                withAnimation(.snappy) { draft.status = status }
                            } label: {
                                Label(status.label, systemImage: status.symbol)
                                    .font(.subheadline.weight(isSelected ? .bold : .medium))
                                    .foregroundStyle(Color.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .contentShape(.capsule)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(
                                isSelected ? .regular.tint(Color.brand.opacity(0.6)).interactive() : .regular.interactive(),
                                in: .capsule
                            )
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    // MARK: Labels

    /// With absolute chapters the tome is only informative.
    private var majorLabel: String {
        draft.mode == .continuous ? "\(draft.kind.majorName) actuel" : draft.kind.majorName
    }

    private var minorTotalLabel: String {
        switch draft.mode {
        case .continuous: "Dernier chapitre sorti"
        case .nested: draft.kind.isWatched ? "Épisodes dans la saison" : "Chapitres dans le tome"
        case .majorOnly: ""
        }
    }

    // MARK: Actions

    private func loadPhoto() async {
        guard let photoItem,
              let data = try? await photoItem.loadTransferable(type: Data.self),
              let jpeg = ImageDownscaler.jpegData(from: data)
        else { return }
        draft.coverImage = jpeg
    }

    private func save() {
        focus = nil
        if let work {
            draft.apply(to: work)
        } else {
            context.insert(draft.makeWork())
        }
        dismiss()
    }
}

enum EditorField: Hashable {
    case title, major, minor, majorTotal, minorTotal, unitLength
}

// MARK: - Building blocks

/// A titled surface card with an optional explanation below its content.
private struct EditorCard<Content: View>: View {
    let title: String
    let symbol: String
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
            content
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .surfaceCard()
    }
}

/// Background of an editable number: highlighted while it has focus.
private struct FieldBackground: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .background(Color.brand.opacity(isFocused ? 0.16 : 0.08), in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.brandDeep.opacity(isFocused ? 0.6 : 0), lineWidth: 1.5)
            }
            .animation(.snappy, value: isFocused)
    }
}

/// Current saison / tome / chapitre: type the number, or nudge it with − / +.
private struct PositionTile: View {
    let title: String
    @Binding var value: Int
    let minimum: Int
    let field: EditorField
    var focus: FocusState<EditorField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(1)
            TextField("0", value: Binding(
                get: { value },
                set: { newValue in value = max(newValue, minimum) }
            ), format: .number)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .keyboardType(.numberPad)
                .focused(focus, equals: field)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                step("minus", label: "Moins", enabled: value > minimum) { value -= 1 }
                step("plus", label: "Plus", enabled: true) { value += 1 }
            }
        }
        .padding(14)
        .modifier(FieldBackground(isFocused: focus.wrappedValue == field))
        .contentShape(.rect(cornerRadius: 18))
        .onTapGesture { focus.wrappedValue = field }
    }

    private func step(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(enabled ? Color.primary : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 38)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .disabled(!enabled)
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityLabel("\(label) — \(title)")
    }
}

/// An optional number (totals, length). The whole tile is the tap target.
private struct NumberTile: View {
    let title: String
    @Binding var value: Int?
    var suffix: String?
    let field: EditorField
    var focus: FocusState<EditorField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.inkSecondary)
                .lineLimit(2, reservesSpace: true)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                TextField("—", value: $value, format: .number)
                    .font(.rounded(.title2))
                    .monospacedDigit()
                    .keyboardType(.numberPad)
                    .focused(focus, equals: field)
                    .fixedSize()
                if let suffix, value != nil {
                    Text(suffix).font(.subheadline).foregroundStyle(Color.inkSecondary)
                }
                Spacer(minLength: 0)
                if value != nil {
                    Button {
                        withAnimation(.snappy) { value = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(Color.inkSecondary.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Effacer — \(title)")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FieldBackground(isFocused: focus.wrappedValue == field))
        .contentShape(.rect(cornerRadius: 18))
        .onTapGesture { focus.wrappedValue = field }
    }
}

/// Five glass tiles, one per kind.
private struct KindPicker: View {
    @Binding var selection: WorkKind

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(WorkKind.allCases) { kind in
                    let isSelected = kind == selection
                    Button {
                        withAnimation(.snappy) { selection = kind }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: kind.symbol).font(.title3)
                            Text(kind.label).font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        isSelected ? .regular.tint(kind.tint.opacity(0.75)).interactive() : .regular.interactive(),
                        in: .rect(cornerRadius: 16)
                    )
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }
}

#Preview {
    WorkEditorView().modelContainer(.preview)
}
