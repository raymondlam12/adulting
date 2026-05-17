import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @State private var archives: [URL] = []
    @State private var showResetConfirm = false
    @State private var showRestoreConfirm: URL?
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset Everything", systemImage: "trash")
                    }
                } footer: {
                    Text("Archives all data to local storage first, then clears expenses and payments. Your people list is preserved. Photos are kept.")
                }

                Section("Archives") {
                    if archives.isEmpty {
                        Text("No archives yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(archives, id: \.absoluteString) { url in
                            archiveRow(url)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { reload() }
            .confirmationDialog(
                "Reset Everything?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Archive & Reset", role: .destructive) { performReset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All expenses and payments will be archived to a local file, then cleared. Your people list is kept. You can restore from the Archives list. Receipt photos are not deleted.")
            }
            .confirmationDialog(
                "Restore this archive?",
                isPresented: Binding(
                    get: { showRestoreConfirm != nil },
                    set: { if !$0 { showRestoreConfirm = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    if let url = showRestoreConfirm { performRestore(from: url) }
                }
                Button("Cancel", role: .cancel) { showRestoreConfirm = nil }
            } message: {
                Text("Current data will be auto-archived, then replaced with the selected archive.")
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Done", isPresented: Binding(
                get: { successMessage != nil },
                set: { if !$0 { successMessage = nil } }
            )) {
                Button("OK") { successMessage = nil }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func archiveRow(_ url: URL) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(archiveDisplayName(url))
                    .font(.subheadline)
                Text(url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore") { showRestoreConfirm = url }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                try? ArchiveManager.deleteArchive(at: url)
                reload()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func archiveDisplayName(_ url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        let stripped = name.replacingOccurrences(of: "archive-", with: "")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        if let date = formatter.date(from: stripped) {
            return DateFormatter.sessionDisplay.string(from: date)
        }
        return stripped
    }

    private func reload() {
        archives = ArchiveManager.listArchives()
    }

    private func performReset() {
        do {
            try ArchiveManager.reset(context: context)
            reload()
            successMessage = "Data archived and reset. You can restore it from the Archives list."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performRestore(from url: URL) {
        do {
            try ArchiveManager.restore(from: url, context: context)
            reload()
            successMessage = "Data restored successfully."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
