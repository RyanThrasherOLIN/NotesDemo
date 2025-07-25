// NoteDetailView.swift
// NotesDemo

// Andrea: Change the narrative of the app to take notes by sending messages, change the notebooks to "Listeners" so from the mental perspective this becomes a different type of interaction.
// Every thing in the UI tells the story so make sure there is a full UI story
// Adjentic model - what does this mean?
// Consistency in the langauge used aswell as navigation techniques
// Or if there are different agents tie it to the notebook: look into this furthur.
// Simplify the settings app.
// Building a narative for the UI, this is in the language and in the navigation(Andrea + Caitrin feedback)
// Consise to where we can get feedback very quicly as are project is in the end stage where we have to find the metaphors and stories we need to decide.
// Multi Model, think about the model from this perspective(voice assistant, where each voice is its own notebook)
// Have an agent shop with premade info like JAWS key commads.
// Joke, the agents can have children, what is the context.

// Astetics feedbacks, get a designer to create consistancy in the app and langauge.



import SwiftUI
import UIKit   // for UIAccessibility

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
    @AccessibilityFocusState private var a11yFieldFocused: Bool
    @FocusState private var editingFocused: Bool
    @AccessibilityFocusState private var a11yEditingFieldFocused: Bool

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
                ScrollView {
                    VStack(spacing: 8) {
                        if messages.isEmpty {
                            // say type a message
                            Text("No notes yet.")
                                .foregroundColor(ColorPalette.current.secondary)
                                .padding(.top, 20)
                        } else {
                            ForEach(messages) { msg in
                                HStack {
                                    Spacer()
                                    messageRow(msg)
                                }
                                .id(msg.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onAppear { scrollToBottom(proxy) }
                .onChange(of: messages) { _ in scrollToBottom(proxy) }

                Divider()

                if editingId == nil {
                    HStack(spacing: 8) {
                        TextField("Type a message…", text: $newMessage)
                            .textFieldStyle(.roundedBorder)
                            .focused($inputFocused)
                            .submitLabel(.send)
                            .onSubmit { sendMessage() }
                            .accessibilityLabel("New note input field")
                            .accessibilityFocused($a11yFieldFocused)

                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(ColorPalette.current.accent)
                        }
                        .accessibilityLabel("Send note")
                        .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(action: { showingRecorder = true }) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(ColorPalette.current.accent)
                        }
                        .accessibilityLabel("Record voice note")
                    }
                    .padding()
                    .background(ColorPalette.current.background
                                    .ignoresSafeArea(edges: .bottom))
                }
            }
        }
        .onAppear {
            notesStore.fetchUserNotes()
            inputFocused = true
            let announcement = "Now viewing notebook \"\(noteTitle)\" in folder \"\(folderKey)\"."
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            a11yFieldFocused = true
            inputFocused = true
        }
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
                    .foregroundColor(ColorPalette.current.primary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ msg: Note) -> some View {
        let palette = ColorPalette.current
        let raw = UserDefaults.standard.string(forKey: "colorBlindMode") ?? ColorBlindMode.normal.rawValue
        let mode = ColorBlindMode(rawValue: raw) ?? .normal
        let isHighlighted = msg.id == notesStore.highlightedNoteID
        let bubbleColor: Color = mode == .normal
            ? (isHighlighted ? palette.accent : Color.blue)
            : (isHighlighted ? palette.accent : palette.secondary)

        if editingId == msg.id {
            HStack(spacing: 8) {
                TextField("", text: $editingText)
                    .padding(12)
                    .background(palette.background)
                    .cornerRadius(16)
                    .focused($editingFocused)
                    .submitLabel(.done)
                    .onSubmit { saveEdit() }
                    .accessibilityLabel("Editing message field")
                    .accessibilityValue(editingText)
                    .accessibilityFocused($a11yEditingFieldFocused)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            UIAccessibility.post(notification: .layoutChanged, argument: nil)
                            a11yEditingFieldFocused = true
                            editingFocused = true
                        }
                    }

                Button(action: saveEdit) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(palette.accent)
                }
                .accessibilityLabel("Save edits")
                .accessibilityHint("Double tap to save changes")

                Button(role: .destructive) { deleteMessage(id: msg.id) } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Delete message")
                .accessibilityHint("Double tap to remove this message")
            }
        } else {
            HStack(spacing: 8) {
                Text(msg.text)
                    .padding(12)
                    .background(bubbleColor)
                    .foregroundColor(palette.background)
                    .cornerRadius(16)
                    .scaleEffect(isHighlighted ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: notesStore.highlightedNoteID)
                    .onAppear {
                        if isHighlighted {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                notesStore.highlightedNoteID = nil
                            }
                        }
                    }

                Button(action: {
                    UIAccessibility.post(notification: .announcement, argument: "Editing message")
                    editingId = msg.id
                    editingText = msg.text
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        editingFocused = true
                    }
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(palette.accent)
                }
                .accessibilityLabel("Edit message")
                .accessibilityHint("Double tap to start editing")
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button { editingId = msg.id; editingText = msg.text; DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { editingFocused = true } } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(palette.accent)

                Button(role: .destructive) { deleteMessage(id: msg.id) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
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
        if let id = editingId {
            notesStore.syncSingleMessage(id: id, text: editingText, folder: folderKey, notebook: noteTitle)
            editingId = nil
            editingText = ""
            inputFocused = true
        }
    }

    private func deleteMessage(id: String) {
        editingId = nil
        editingText = ""
        inputFocused = true
        notesStore.deleteNote(id: id, notebook: noteTitle, folder: folderKey)
    }

    private func handleVoiceNoteDismiss() {
        if let rec = recordingStore.recordings.first {
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
