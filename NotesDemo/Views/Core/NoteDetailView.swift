///
/// NoteDetailView.swift
/// NotesDemo
///
/// Chat-style detail view for a single note:
/// - Editable title at top
/// - Scrollable list of sent messages in blue bubbles
/// - Inline edit & delete on each bubble
/// - Input bar at bottom with a rounded-border text field and send button
///
import SwiftUI

// MARK: - Model
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
}

// MARK: - View
struct NoteDetailView: View {
    // MARK: Inputs
    let folder: String
    let noteTitle: String             // key for storing this note’s messages

    // MARK: Environment
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    // MARK: State
    @State private var draftTitle: String
    @State private var messages: [ChatMessage]
    @State private var newMessage: String = ""

    // Focus states
    @FocusState private var inputFocused: Bool
    @FocusState private var editingFocused: Bool

    // Inline editing state
    @State private var editingId: UUID? = nil
    @State private var editingText: String = ""

    // MARK: Init
    init(folder: String, noteTitle: String) {
        self.folder = folder
        self.noteTitle = noteTitle
        _draftTitle = State(initialValue: noteTitle)
        if let data = UserDefaults.standard.data(forKey: noteTitle),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            _messages = State(initialValue: saved)
        } else {
            _messages = State(initialValue: [])
        }
    }

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {
            // Editable title
            TextField("Title", text: $draftTitle)
                .font(.largeTitle.bold())
                .padding()
                .accessibilityLabel("Note title")

            Divider()

            // Chat bubbles list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(messages) { msg in
                            messageRow(for: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: messages) { _ in
                    withAnimation {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
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
                        .foregroundColor(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(UIColor.systemBackground).ignoresSafeArea(edges: .bottom))
        }
        .navigationTitle(draftTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { inputFocused = true }
    }

    // MARK: Message Row
    @ViewBuilder
    private func messageRow(for msg: ChatMessage) -> some View {
        HStack {
            Spacer(minLength: 16)

            if editingId == msg.id {
                // Inline edit mode
                HStack(spacing: 8) {
                    TextField("", text: $editingText)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(16)
                        .focused($editingFocused)
                        .onAppear { editingFocused = true }

                    Button(action: saveEdit) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel("Save edits")

                    Button(role: .destructive) {
                        deleteMessage(id: msg.id)
                    } label: {
                        Image(systemName: "trash.circle")
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel("Delete message")
                }
                .padding(.horizontal)

            } else {
                // Normal display mode
                HStack(spacing: 4) {
                    Text(msg.text)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                        .accessibilityLabel(Text(msg.text))

                    Button(action: {
                        editingId = msg.id
                        editingText = msg.text
                    }) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 18))
                            .opacity(0.6)
                    }
                    .accessibilityLabel("Edit message")
                }
                .padding(.horizontal)
            }

            Spacer(minLength: 16)
        }
    }

    // MARK: Actions
    private func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let msg = ChatMessage(id: UUID(), text: trimmed)
        messages.append(msg)
        persistMessages()

        hiddenStore.syncSingleMessage(
            id: msg.id.uuidString,
            text: msg.text,
            folder: folder,
            notebook: noteTitle
        )

        newMessage = ""
        inputFocused = true
    }

    private func saveEdit() {
        guard let id = editingId,
              let idx = messages.firstIndex(where: { $0.id == id })
        else { return }

        messages[idx].text = editingText
        persistMessages()

        // Updated to match HiddenLineStore signature
        hiddenStore.updateMessage(
            id: id.uuidString,
            newText: editingText
        )

        editingId = nil
        editingText = ""
        inputFocused = true
    }

    private func deleteMessage(id: UUID) {
        messages.removeAll { $0.id == id }
        persistMessages()

        // Updated to match HiddenLineStore signature
        hiddenStore.deleteMessage(id: id.uuidString)

        if editingId == id { editingId = nil }
        inputFocused = true
    }

    private func persistMessages() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: noteTitle)
        }
    }
}

#if DEBUG
struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NoteDetailView(folder: "default", noteTitle: "Chat Note")
                .environmentObject(HiddenLineStore())
        }
    }
}
#endif
