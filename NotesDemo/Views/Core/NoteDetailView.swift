///
/// NoteDetailView.swift
/// NotesDemo
///
/// View for displaying and editing a single note's title and body.
/// Automatically syncs new lines to the hidden store and persists content to UserDefaults.
///
import SwiftUI

/// Detail view for a specific note within a folder.
///
/// - Displays an editable title and body for the selected note.
/// - Saves text changes locally on each edit and when the view disappears.
/// - Syncs individual lines to the hidden store whenever newlines are entered or when exiting the view.
struct NoteDetailView: View {
    // MARK: - Immutable Inputs
    /// The folder in which this note resides.
    let folder: String
    /// The original title of the note (used as the storage key).
    let noteTitle: String

    // MARK: - Environment Objects
    /// Store used to sync individual lines for hidden search or storage.
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    // MARK: - Editable State
    /// The note's current title being edited.
    @State private var draftTitle: String
    /// The note's current body text being edited.
    @State private var draftBody: String
    /// Focus state for the text editor, set to true on appear to show the keyboard.
    @FocusState private var bodyFocused: Bool

    // MARK: - Initialization
    /// Initializes the detail view with a folder and note title, loading saved body text.
    ///
    /// - Parameters:
    ///   - folder: Name of the folder containing the note.
    ///   - noteTitle: The title (and storage key) of the note.
    init(folder: String, noteTitle: String) {
        self.folder = folder
        self.noteTitle = noteTitle
        // Initialize the editable title to the passed-in noteTitle
        _draftTitle = State(initialValue: noteTitle)
        // Load any previously saved body text from UserDefaults
        let savedBody = UserDefaults.standard.string(forKey: noteTitle) ?? ""
        _draftBody = State(initialValue: savedBody)
    }

    // MARK: - View Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Editable title field
            TextField("Title", text: $draftTitle)
                .font(.largeTitle.bold())
                .submitLabel(.done)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Title here")

            Divider()

            // Editable body with placeholder and sync logic
            ZStack(alignment: .topLeading) {
                // Placeholder text shown only when the body is empty
                if draftBody.isEmpty {
                    Text("Add note here…")
                        .foregroundColor(.gray)
                        .padding(8)
                        .allowsHitTesting(false)
                }

                // Multiline editable text area
                TextEditor(text: $draftBody)
                    .focused($bodyFocused)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    // Save and sync on every change
                    .onChange(of: draftBody) { newBody in
                        // Persist entire body under the current title as key
                        UserDefaults.standard.set(newBody, forKey: draftTitle)

                        // When user presses Return (newline), extract lines to sync
                        if newBody.last == "\n" {
                            let lines = newBody
                                .components(separatedBy: .newlines)
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { $0.count > 1 }

                            // Sync trimmed, non-empty lines
                            hiddenStore.sync(
                                lines,
                                folder: folder,
                                notebook: draftTitle
                            )
                        }
                    }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Note here")
            .frame(minHeight: 200)

            Spacer()
        }
        .padding()
        // Show the draft title in the navigation bar
        .navigationTitle(draftTitle)
        .navigationBarTitleDisplayMode(.inline)
        // Focus the body editor on appear
        .onAppear { bodyFocused = true }
        // Save and sync once more when the view disappears
        .onDisappear {
            let lines = draftBody
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 1 }

            hiddenStore.sync(
                lines,
                folder: folder,
                notebook: draftTitle
            )
            // Persist the final body text
            UserDefaults.standard.set(draftBody, forKey: draftTitle)
        }
    }
}

#if DEBUG
/// Preview provider for NoteDetailView
struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NoteDetailView(folder: "default", noteTitle: "Demo Note")
                .environmentObject(HiddenLineStore())
        }
    }
}
#endif
