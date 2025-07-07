///
/// AddNoteOverlay.swift
/// NotesDemo
///
/// A modal overlay allowing users to enter a new note title.
/// Returns the submitted note string via the provided callback.
/// Dismisses itself on background tap, Cancel, or Save.
///
import SwiftUI

/// Overlay presenting a text field for creating a new note.
///
/// - Binds to an external `isPresented` flag to control visibility.
/// - Calls `onSubmit` with the trimmed input when the user saves.
struct AddNoteOverlay: View {
    // MARK: - Presentation Binding
    /// Binding to control whether the overlay is shown.
    @Binding var isPresented: Bool

    // MARK: - Submission Handler
    /// Callback invoked with the new note text when the user saves.
    var onSubmit: (String) -> Void

    // MARK: - Internal State
    /// Editable text for the new note draft.
    @State private var draft = ""

    // MARK: - View Body
    var body: some View {
        ZStack {
            // Dimmed, blurred background that dismisses on tap
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Card-like container for input and actions
            VStack(spacing: 16) {
                // Top action bar with Cancel and Save buttons
                HStack {
                    Button("Cancel") {
                        // Dismiss without saving
                        isPresented = false
                    }
                    Spacer()
                    Button("Save") {
                        // Commit the draft and dismiss
                        commitAndDismiss()
                    }
                    .fontWeight(.bold)
                }
                .padding(.horizontal)

                // Text field for entering the note title
                TextField("Type a new note…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .submitLabel(.done)
                    .onSubmit { commitAndDismiss() }
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)
            .padding()
        }
    }

    // MARK: - Helper Methods
    /// Trims whitespace/newlines and calls `onSubmit` if non-empty,
    /// then dismisses the overlay.
    private func commitAndDismiss() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onSubmit(trimmed)
        }
        isPresented = false
    }
}

#if DEBUG
/// Preview provider for AddNoteOverlay
struct AddNoteOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            AddNoteOverlay(isPresented: .constant(true)) { _ in }
        }
    }
}
#endif
