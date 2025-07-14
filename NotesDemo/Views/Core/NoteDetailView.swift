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
    @State private var editingText: String     = ""
    @State private var showingRecorder: Bool   = false
    @FocusState private var inputFocused: Bool
    @FocusState private var editingFocused: Bool

    /// Normalize “default” → “Notes”, else capitalize
    private var folderKey: String {
        folder.lowercased() == "default" ? "Notes" : folder.capitalized
    }

    var body: some View {
        VStack(spacing: 0) {
            // Notebook title
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

            // New message input (enabled only when not editing)
            if editingId == nil {
                HStack(spacing: 8) {
                    TextField("Type a message…", text: $newMessage)
                        .textFieldStyle(.roundedBorder)
                        .focused($inputFocused)
                        .accessibilityLabel("New message input field")
                        .accessibilityHint("Type a new message, then double tap Send")
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .accessibilityLabel("Send message")
                            .accessibilityHint(newMessage.trimmingCharacters(in: .whitespaces).isEmpty
                                ? "Disabled until you type a message"
                                : "Double tap to send message")
                    }
                    .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(action: { showingRecorder = true }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 28))
                            .accessibilityLabel("Record voice note")
                            .accessibilityHint("Record and transcribe voice note")
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground)
                                .ignoresSafeArea(edges: .bottom))
                .accessibilityElement(children: .contain)
                .accessibilitySortPriority(0)
            }
        }
        .onAppear {
            notesStore.fetchUserNotes()
        }
        .task(id: noteTitle) {
            DispatchQueue.main.async {
                if editingId == nil {
                    inputFocused = true
                }
            }
        }
        .fullScreenCover(isPresented: $showingRecorder, onDismiss: handleVoiceNoteDismiss) {
            RecordingView(isPresented: $showingRecorder)
                .environmentObject(recordingStore)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func messageRow(for msg: Note) -> some View {
        Group {
            if editingId == msg.id {
                // EDIT MODE
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        TextField("", text: $editingText)
                            .padding(12)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(16)
                            .focused($editingFocused)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    UIAccessibility.post(notification: .layoutChanged, argument: nil)
                                    editingFocused = true
                                }
                            }
                            .accessibilityLabel("Editing message field")
                            .accessibilityValue(editingText)

                        Button(action: saveEdit) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                        }
                        .accessibilityLabel("Save edits")
                        .accessibilityHint("Double tap to save changes")

                        Button(role: .destructive) {
                            deleteMessage(id: msg.id)
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 22))
                        }
                        .accessibilityLabel("Delete message")
                        .accessibilityHint("Double tap to remove this message")
                    }
                    .padding(.trailing, 16)
                }
                .accessibilityElement(children: .contain)
            } else {
                // DISPLAY MODE
                HStack {
                    Spacer()

                    HStack(spacing: 8) {
                        Text(msg.text)
                            .padding(12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .accessibilityLabel("Message")
                            .accessibilityValue(msg.text)

                        Button(action: {
                            UIAccessibility.post(notification: .announcement, argument: "Editing message")
                            editingId = msg.id
                            editingText = msg.text
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                        }
                        .accessibilityLabel("Edit message")
                        .accessibilityHint("Double tap to start editing this message")
                    }
                    .padding(.trailing, 16)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            UIAccessibility.post(notification: .announcement, argument: "Editing message")
                            editingId = msg.id
                            editingText = msg.text
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            UIAccessibility.post(notification: .announcement, argument: "Message deleted")
                            deleteMessage(id: msg.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
        .accessibilityHidden(editingId != nil && editingId != msg.id)
    }

    // MARK: - Actions
    private func sendMessage() {
        let text = newMessage.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        notesStore.addNote(text, title: noteTitle, folder: folderKey)
        newMessage = ""
        inputFocused = true
    }

    private func saveEdit() {
        guard let id = editingId else { return }
        notesStore.syncSingleMessage(id: id, text: editingText, folder: folderKey, notebook: noteTitle)
        editingId = nil
        editingText = ""
        inputFocused = true
    }

    private func deleteMessage(id: String) {
        editingId = nil
        editingText = ""
        inputFocused = true
        notesStore.deleteNote(id: id, notebook: noteTitle, folder: folderKey)
    }

    private func handleVoiceNoteDismiss() {
        guard let rec = recordingStore.recordings.first else { return }
        Task {
            if let text = await recordingStore.speechToText(rec) {
                await MainActor.run {
                    newMessage = text
                    inputFocused = true
                }
            }
        }
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
