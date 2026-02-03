// NoteDetailView.swift

import SwiftUI
import UIKit // for UIAccessibility

/// Displays and edits a list of Note objects in a chat-style UI
struct NoteDetailView: View {
    // MARK: - Inputs
    let folder: String
    let noteTitle: String

    // MARK: - Environment
    @EnvironmentObject private var notesStore: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var nav: NavigationStackHandler

    // MARK: - State
    @State private var newMessage: String = ""
    @State private var editingId: String? = nil
    @State private var editingText: String = ""
    @State private var showingRecorder: Bool = false
    @FocusState private var inputFocused: Bool
    @FocusState private var editingFocused: Bool

    // MARK: - Computed
    private var folderKey: String {
        folder.lowercased() == "default" ? "Notes" : folder.capitalized
    }
    private var messages: [Note] {
        notesStore.notesByFolder[folderKey]?[noteTitle]?.notes ?? []
    }

    var body: some View {
        ZStack {
            ColorPalette.current.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if messages.isEmpty {
                                Text("No notes yet.")
                                    .foregroundColor(ColorPalette.current.secondary)
                                    .padding(.top, 20)
                            } else {
                                ForEach(messages) { msg in
                                    HStack {
                                        Spacer()
                                        messageRow(msg)
                                            .padding(.trailing, 16)
                                    }
                                    .id(msg.id)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onAppear { scrollToBottom(proxy) }
                    .onChange(of: messages) { _ in scrollToBottom(proxy) }
                }

                Divider()

                // only show the bottom input when NOT editing an existing message
                if editingId == nil {
                    inputArea
                }
            }
        }
        .onAppear {
            notesStore.fetchUserNotes()
            inputFocused = true
        }
        .fullScreenCover(isPresented: $showingRecorder) {
            RecordingView(isPresented: $showingRecorder)
                .environmentObject(recordingStore)
                .ignoresSafeArea()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button(action: { nav.popView() }) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .padding(8)
            }
            .accessibilityLabel("Close notebook")

            Spacer()

            Text(noteTitle)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(ColorPalette.current.primary)

            Spacer()
            Spacer().frame(width: 32)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    // MARK: - Input Area
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Type a note here…", text: $newMessage)
                .font(.title3)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color(UIColor.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(ColorPalette.current.accent, lineWidth: 2)
                )
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(sendMessage)
                .accessibilityLabel("New note input field")

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(ColorPalette.current.accent)
            }
            .accessibilityLabel("Send note")
            .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
//
//            Button(action: { showingRecorder = true }) {
//                Image(systemName: "mic.circle.fill")
//                    .font(.system(size: 34))
//                    .foregroundColor(ColorPalette.current.accent)
//            }
//            .accessibilityLabel("Record voice note")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(ColorPalette.current.background.ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Message Row
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
                // EDIT MODE: pill-style text field
                TextField("", text: $editingText)
                    .font(.title3)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color(UIColor.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(ColorPalette.current.accent, lineWidth: 2)
                    )
                    .focused($editingFocused)
                    .submitLabel(.done)
                    .onSubmit(saveEdit)

                Button(action: saveEdit) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(palette.accent)
                }
                .accessibilityLabel("Save edits")

                Button(role: .destructive, action: { deleteMessage(id: msg.id) }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                }
                .accessibilityLabel("Delete message")
            }
            .padding(.horizontal)
        } else {
            Text(msg.text)
                .font(.title3)
                .padding(16)
                .background(bubbleColor)
                .foregroundColor(palette.background)
                .cornerRadius(16)
                .accessibilityHint("Double tap to edit message")
                .onTapGesture {
                    editingId = msg.id
                    editingText = msg.text
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        editingFocused = true
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteMessage(id: msg.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    // MARK: - Helpers
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

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
                .environmentObject(NavigationStackHandler.shared)
        }
    }
}
#endif
