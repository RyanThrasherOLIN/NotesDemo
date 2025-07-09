import SwiftUI

/// Shows all messages currently synced through HiddenLineStore
// TODO: Shows all messages from NotesStore instead of HiddenLineStore
struct SyncedLinesView: View {
    //@EnvironmentObject var hiddenStore: HiddenLineStore
    
    @EnvironmentObject private var notesStore: NoteStore

    private func getAllSyncedNotes()->[String: [Note]] {
        var allNotes: [String: [Note]] = [:]
        for (folderName, folderNotes) in notesStore.notesByFolder {
            for (noteBookTitle, noteBook) in folderNotes {
                allNotes[noteBookTitle] = noteBook.notes
            }
        }
        return allNotes
    }
    
    var body: some View {
        let allNotes = getAllSyncedNotes()
        ScrollView {
            VStack {
                ForEach(allNotes.keys.sorted(by: <), id: \.self) { noteBookTitle in
                    Text(noteBookTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    List(allNotes[noteBookTitle] ?? [], id: \.id) { msg in
                        HStack(alignment: .top, spacing: 8) {
                            // Display the server-provided note ID
                            Text(msg.id)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(msg.text)
                        }
                        .padding(.vertical, 4)
                    }.frame(height: 100)
                }
            }
        }
        .navigationTitle("Synced Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
struct SyncedLinesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SyncedLinesView()
        }
    }
}
#endif
