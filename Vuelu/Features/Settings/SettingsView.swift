import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var works: [Work]
    @AppStorage(ReminderScheduler.enabledKey) private var remindersEnabled = false
    @State private var exportDocument: BackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        BookmarkShape()
                            .fill(Color.brand.gradient)
                            .frame(width: 40, height: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Vuelu").font(.rounded(.title2))
                            Text("Tes lectures et tes séries, là où tu les as laissées.")
                                .font(.subheadline)
                                .foregroundStyle(Color.inkSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Toggle("Me prévenir des sorties", systemImage: "bell.badge", isOn: $remindersEnabled)
                } header: {
                    Text("Rappels")
                } footer: {
                    Text("Une notification à la date de prochaine sortie de chaque œuvre suivie.")
                }

                Section {
                    Button("Exporter mes données", systemImage: "square.and.arrow.up") { export() }
                        .disabled(works.isEmpty)
                    Button("Importer une sauvegarde", systemImage: "square.and.arrow.down") { isImporting = true }
                } header: {
                    Text("Sauvegarde")
                } footer: {
                    Text("Tout reste sur ton iPhone, sans compte ni serveur. Exporte un fichier de temps en temps pour ne rien perdre.")
                }

                #if DEBUG
                Section("Développement") {
                    Button("Ajouter des exemples", systemImage: "wand.and.stars") {
                        SampleData.insert(into: context)
                    }
                }
                #endif

                Section {
                    LabeledContent("Œuvres suivies", value: "\(works.count)")
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .scrollContentBackground(.hidden)
            .canvasBackground()
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
            .onChange(of: remindersEnabled) { _, enabled in
                guard enabled else { return }
                Task {
                    if !(await ReminderScheduler.requestAuthorization()) {
                        remindersEnabled = false
                        alertMessage = "Autorise les notifications pour Vuelu dans l'app Réglages."
                    }
                }
            }
            .fileExporter(
                isPresented: $isExporting,
                document: exportDocument,
                contentType: .json,
                defaultFilename: BackupService.defaultFilename()
            ) { result in
                if case .failure(let error) = result { alertMessage = error.localizedDescription }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .alert("Vuelu", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func export() {
        do {
            let data = try BackupService.encode(BackupService.makePayload(from: works))
            exportDocument = BackupDocument(data: data)
            isExporting = true
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let payload = try BackupService.decode(Data(contentsOf: url))
            let count = try BackupService.restore(payload, into: context)
            alertMessage = count == 1 ? "1 œuvre importée." : "\(count) œuvres importées."
        } catch {
            alertMessage = "Import impossible : \(error.localizedDescription)"
        }
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
