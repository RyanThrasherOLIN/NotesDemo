import SwiftUI

// NoteDetailView.swift
// Displays and edits a list of ChatMessage objects (with String IDs) in a chat-style UI

struct NoteDetailView: View {
    // MARK: Inputs
    let folder: String
    let noteTitle: String            // key for storing this note’s messages

    // MARK: Environment
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    // MARK: State
    @State private var draftTitle: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var newMessage: String = ""

    // Focus states
    @FocusState private var inputFocused: Bool
    @FocusState private var editingFocused: Bool

    // Inline editing state
    @State private var editingId: String? = nil
    @State private var editingText: String = ""

    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {
            // Editable title
            TextField("Title", text: $draftTitle)
                .font(.largeTitle.bold())
                .padding()
                .accessibilityLabel("Note title")

            Divider()

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(messages, id: \.id) { msg in
                            messageRow(for: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: messages) { _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
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
                        .foregroundColor(
                            newMessage.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue
                        )
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(
                Color(UIColor.systemBackground)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .navigationTitle(draftTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draftTitle = noteTitle
            loadLocalMessages()
            inputFocused = true
            Task {
                // fetch actual server notes & IDs
                await hiddenStore.fetchMessages(folder: folder, notebook: noteTitle)
            }
        }
        // whenever store updates, replace local messages
        .onReceive(hiddenStore.$syncedMessages) { fetched in
            messages = fetched
        }
    }

    // MARK: - Message Row
    @ViewBuilder
    private func messageRow(for msg: ChatMessage) -> some View {
        if editingId == msg.id {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    TextField("", text: $editingText)
                        .padding(12)
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(16)
                        .focused($editingFocused)
                        .onAppear { editingFocused = true }

                    Button(action: saveEdit) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel("Save edits")

                    Button(role: .destructive) { deleteMessage(id: msg.id) } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel("Delete message")
                }
                .padding(.trailing, 16)
            }
        } else {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Text(msg.text)
                        .padding(12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)

                    Button(action: {
                        editingId = msg.id
                        editingText = msg.text
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20))
                    }
                }
                .padding(.trailing, 16)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button { editingId = msg.id; editingText = msg.text } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)

                    Button(role: .destructive) { deleteMessage(id: msg.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Actions
    private func loadLocalMessages() {
        if let data = UserDefaults.standard.data(forKey: noteTitle),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = saved
        }
    }

    private func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let temp = ChatMessage(id: UUID().uuidString, text: trimmed)
        messages.append(temp)
        persistAndSyncAllMessages()
        newMessage = ""
        inputFocused = true
    }

    private func saveEdit() {
        guard let id = editingId,
              let idx = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[idx].text = editingText
        persistAndSyncAllMessages()
        editingId = nil
        editingText = ""
        inputFocused = true
    }

    private func deleteMessage(id: String) {
        messages.removeAll { $0.id == id }
        persistAndSyncAllMessages()
        if editingId == id { editingId = nil }
        inputFocused = true
    }

    // MARK: - Helper
    private func persistAndSyncAllMessages() {
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: noteTitle)
        }
        for msg in messages {
            hiddenStore.syncSingleMessage(
                id: msg.id,
                text: msg.text,
                folder: folder,
                notebook: noteTitle
            )
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
