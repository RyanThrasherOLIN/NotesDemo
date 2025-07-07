///
/// NoteDetailView.swift
/// NotesDemo
///
/// Chat‐style detail view for a single note:
/// - Editable title at top
/// - Scrollable list of sent messages in blue bubbles
/// - Input bar at bottom with a rounded-border text field and send button
/// - Send by tapping button or pressing Return
/// - Clears the input field after sending
///
import SwiftUI

struct NoteDetailView: View {
    // MARK: - Inputs
    let folder: String                // Folder containing this note
    let noteTitle: String             // Storage key for this note’s messages

    // MARK: - Environment
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    // MARK: - State
    @State private var draftTitle: String
    @State private var messages: [String]
    @State private var newMessage: String = ""
    @FocusState private var inputFocused: Bool

    // MARK: - Init
    init(folder: String, noteTitle: String) {
        self.folder = folder
        self.noteTitle = noteTitle
        _draftTitle = State(initialValue: noteTitle)
        let saved = UserDefaults.standard.stringArray(forKey: noteTitle) ?? []
        _messages = State(initialValue: saved)
    }

    // MARK: - Body
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
                        ForEach(messages.indices, id: \.self) { idx in
                            HStack {
                                Spacer()
                                Text(messages[idx])
                                    .padding(12)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(16)
                            }
                            .id(idx)
                        }
                    }
                    .padding(.horizontal)
                }
                .onChange(of: messages) { _ in
                    withAnimation {
                        proxy.scrollTo(messages.count - 1, anchor: .bottom)
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
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(
                            newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? .gray : .blue
                        )
                }
                .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(UIColor.systemBackground).ignoresSafeArea(edges: .bottom))
        }
        .navigationTitle(draftTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            inputFocused = true
        }
    }

    // MARK: - Actions

    /// Sends the message, appending it to the chat, persisting locally,
    /// syncing with the server, then clearing the input field.
    private func sendMessage() {
        let trimmed = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1) Append locally and persist
        messages.append(trimmed)
        UserDefaults.standard.set(messages, forKey: noteTitle)

        // 2) Sync full message as a single note
        hiddenStore.sync([trimmed], folder: folder, notebook: noteTitle)

        // 3) Clear input and refocus
        newMessage = ""
        inputFocused = true
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
