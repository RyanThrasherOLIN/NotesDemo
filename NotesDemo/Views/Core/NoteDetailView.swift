import SwiftUI

/// Displays and edits a list of ChatMessage objects (with server String IDs) in a chat-style UI
struct NoteDetailView: View {
    // MARK: Inputs
    let folder: String
    let noteTitle: String            // key for this notebook

    // MARK: Environment Store
    // @EnvironmentObject private var hiddenStore: HiddenLineStore
    @EnvironmentObject private var notesStore: NoteStore

    // MARK: Local State
    @State private var newMessage: String = ""
    @State private var editingId: String? = nil
    @State private var editingText: String = ""
    @FocusState private var inputFocused: Bool
    @FocusState private var editingFocused: Bool

    // drive messages off the store directly
//    private var messages: [Note] {
//        if let folderNotes = notesStore.notesByFolder[folder], let noteBook = folderNotes[noteTitle] {
//            return noteBook.notes
//        } else {
//            return []
//        }
//    }

    var body: some View {
        VStack(spacing: 0) {
            // Editable notebook title
            Text(noteTitle)
                .font(.largeTitle.bold())
                .padding()

            Divider()

            // Chat bubbles
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        if let folderNotes = notesStore.notesByFolder[folder], let noteBook = folderNotes[noteTitle] {
                            ForEach(noteBook.notes, id: \.id) { msg in
                                messageRow(for: msg)
                                    .id(msg.id)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
//                .onChange(of: messages) { _ in
//                    if let last = messages.last {
//                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
//                    }
//                }
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
                        .foregroundColor(newMessage.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
            .background(Color(UIColor.systemBackground).ignoresSafeArea(edges: .bottom))
        }
        .navigationTitle(noteTitle)
        .navigationBarTitleDisplayMode(.inline)
        // fetch when the view first appears or the notebook changes
        .task(id: noteTitle) {
            DispatchQueue.main.async { inputFocused = true }
        }
    }

    // MARK: Message Row
    @ViewBuilder
    private func messageRow(for msg: Note) -> some View {
        if editingId == msg.id {
            // Inline editing
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
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 22))
                    }
                    .accessibilityLabel("Save edits")

                    Button(role: .destructive) { deleteMessage(id: msg.id) } label: {
                        Image(systemName: "trash.circle.fill").font(.system(size: 22))
                    }
                    .accessibilityLabel("Delete message")
                }
                .padding(.trailing, 16)
            }
        } else {
            // Display
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
                        Image(systemName: "pencil.circle.fill").font(.system(size: 20))
                    }
                }
                .padding(.trailing, 16)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button { editingId = msg.id; editingText = msg.text } label: {
                        Label("Edit", systemImage: "pencil")
                    }.tint(.blue)
                    Button(role: .destructive) { deleteMessage(id: msg.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: Actions
    private func sendMessage() {
        let text = newMessage.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        notesStore.addNote(text, title: noteTitle, folder: folder)
        newMessage = ""
        inputFocused = true
    }

    private func saveEdit() {
        guard let id = editingId else { return }
        notesStore.syncSingleMessage(id: id, text: editingText, folder: folder, notebook: noteTitle)
        editingId = nil
        editingText = ""
        inputFocused = true
    }

    private func deleteMessage(id: String) {
        print("BROKEN")
        // hiddenStore.deleteMessage(id: id)
        if editingId == id { editingId = nil }
        inputFocused = true
    }
}

#if DEBUG
struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NoteDetailView(folder: "default", noteTitle: "Sample")
        }
    }
}
#endif
