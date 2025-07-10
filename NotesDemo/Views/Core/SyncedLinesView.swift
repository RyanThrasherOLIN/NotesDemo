import SwiftUI

/// Shows all messages currently synced through NoteStore, grouped by notebook.
struct SyncedLinesView: View {
    @EnvironmentObject private var noteStore: NoteStore

    var body: some View {
        List {
            // Flatten all notebooks into an array, sorted by title
            ForEach(allNotebooks(), id: \.id) { notebook in
                Section(header: Text(notebook.title)
                            .font(.headline)
                            .foregroundColor(.primary)) {
                    ForEach(notebook.notes, id: \.id) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(note.text)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Synced Messages")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Pulls out every NoteBook from the store, sorted alphabetically.
    private func allNotebooks() -> [NoteBook] {
        noteStore.notesByFolder
            .flatMap { $0.value.values }
            .sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
    }
}
