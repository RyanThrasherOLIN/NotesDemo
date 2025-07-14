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

    /// “default” → “Notes”, else capitalized folder name
    private var folderKey: String {
        folder.lowercased() == "default" ? "Notes" : folder.capitalized
    }

    /// Current list of messages in this notebook
    private var messages: [Note] {
        notesStore.notesByFolder[folderKey]?[noteTitle]?.notes ?? []
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // MARK: Messages list
                ScrollView {
                    VStack(spacing: 8) {
                        if messages.isEmpty {
                            Text("No notes yet.")
                                .foregroundColor(.secondary)
                                .padding(.top, 20)
                        } else {
                            ForEach(messages) { msg in
                                messageRow(for: msg)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onAppear {
                    scrollToBottom(proxy)
                }
                .onChange(of: messages) { _ in
                    scrollToBottom(proxy)
                }

                Divider()

                // MARK: Input bar
                if editingId == nil {
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
            }
        }
        .onAppear {
            notesStore.fetchUserNotes()
        }
        .task(id: noteTitle) {
            if editingId == nil {
                inputFocused = true
            }
        }
        // ← here’s the important bit: pass your handler
        .fullScreenCover(isPresented: $showingRecorder,
                         onDismiss: handleVoiceNoteDismiss) {
            RecordingView(isPresented: $showingRecorder)
                .environmentObject(recordingStore)
                .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(noteTitle)
                    .font(.system(size: 28, weight: .bold))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func messageRow(for msg: Note) -> some View {
        Group {
            if editingId == msg.id {
                // EDIT MODE
                HStack {
                    Spacer()
                    editRow(for: msg)
                }
                .accessibilityElement(children: .contain)
            } else {
                // DISPLAY MODE
                HStack {
                    Spacer()
                    displayRow(for: msg)
                }
                .accessibilityElement(children: .contain)
            }
        }
        .accessibilityHidden(editingId != nil && editingId != msg.id)
    }

    private func editRow(for msg: Note) -> some View {
        HStack(spacing: 8) {
            TextField("", text: $editingText)
                .padding(12)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16)
                .focused($editingFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        UIAccessibility.post(notification: .layoutChanged,
                                             argument: nil)
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

    private func displayRow(for msg: Note) -> some View {
        HStack(spacing: 8) {
            Text(msg.text)
                .padding(12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(16)
                .accessibilityLabel("Message")
                .accessibilityValue(msg.text)

            Button(action: {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Editing message")
                editingId = msg.id
                editingText = msg.text
            }) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 20))
            }
            .accessibilityLabel("Edit message")
            .accessibilityHint("Double tap to start editing")
        }
        .padding(.trailing, 16)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Editing message")
                editingId = msg.id
                editingText = msg.text
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)

            Button(role: .destructive) {
                UIAccessibility.post(notification: .announcement,
                                     argument: "Message deleted")
                deleteMessage(id: msg.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: Actions

    private func sendMessage() {
        let text = newMessage.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        notesStore.addNote(text, title: noteTitle, folder: folderKey)
        newMessage = ""
        inputFocused = true
    }

    private func saveEdit() {
        guard let id = editingId else { return }
        notesStore.syncSingleMessage(
            id: id,
            text: editingText,
            folder: folderKey,
            notebook: noteTitle
        )
        editingId = nil
        editingText = ""
        inputFocused = true
    }

    private func deleteMessage(id: String) {
        editingId = nil
        editingText = ""
        inputFocused = true
        notesStore.deleteNote(
            id: id,
            notebook: noteTitle,
            folder: folderKey
        )
    }

    private func handleVoiceNoteDismiss() {
        // pull the last recording, transcribe, and insert into the input field
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
            NoteDetailView(folder: "default", noteTitle: "Sample")
                .environmentObject(NoteStore())
                .environmentObject(RecordingStore())
        }
    }
}
#endif
