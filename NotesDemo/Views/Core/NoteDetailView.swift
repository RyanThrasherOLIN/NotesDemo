// NoteDetailView.swift

import SwiftUI

/// Displays and edits a list of Note objects in a chat-style UI
struct NoteDetailView: View {
    // MARK: Inputs
    let folder: String
    let noteTitle: String

    // MARK: Environment Stores
    @EnvironmentObject private var notesStore: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore

    // MARK: Local State
    @State private var newMessage: String      = ""
    @State private var editingId: String?      = nil
    @State private var showingRecorder         = false
    @FocusState private var inputFocused: Bool

    /// Normalize “default” → “Notes”, else capitalize
    private var folderKey: String {
        folder.lowercased() == "default" ? "Notes" : folder.capitalized
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text(noteTitle)
                .font(.largeTitle.bold())
                .padding()

            Divider()

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if let folderNotes = notesStore.notesByFolder[folderKey],
                           let noteBook    = folderNotes[noteTitle],
                           !noteBook.notes.isEmpty {
                            ForEach(noteBook.notes) { msg in
                                messageRow(for: msg)
                                    .id(msg.id)
                            }
                        } else {
                            Text("No notes yet.")
                                .foregroundColor(.secondary)
                                .padding(.top, 20)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: notesStore.notesByFolder) { _ in
                    if let last = notesStore.notesByFolder[folderKey]?[noteTitle]?.notes.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input bar
            HStack(spacing: 8) {
                TextField("Type a message…", text: $newMessage)
                    .textFieldStyle(.roundedBorder)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)

                Button(action: { showingRecorder = true }) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 28))
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground)
                            .ignoresSafeArea(edges: .bottom))
        }
        .onAppear {
            notesStore.fetchUserNotes()
            DispatchQueue.main.async {
                inputFocused = true
            }
        }
        .fullScreenCover(isPresented: $showingRecorder) {
            RecordingView(isPresented: $showingRecorder)
                .environmentObject(recordingStore)
                .ignoresSafeArea()
        }
    }

    /// **Simplified** row just to verify your data
    @ViewBuilder
    private func messageRow(for msg: Note) -> some View {
        HStack {
            Text(msg.text)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding(.horizontal)
    }

    private func sendMessage() {
        let text = newMessage.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        notesStore.addNote(text, title: noteTitle, folder: folderKey)
        newMessage = ""
        inputFocused = true
    }
}

#if DEBUG
struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NoteDetailView(folder: "Notes", noteTitle: "Sample")
                .environmentObject(NoteStore())
                .environmentObject(RecordingStore())
        }
    }
}
#endif
