// AddNoteOverlay.swift
// NotesDemo
//
// A modal overlay allowing users to enter a new note title.
// Returns the submitted note string via the provided callback.
// Dismisses itself on background tap, Cancel, or Save.

import SwiftUI
import UIKit  // for UIAccessibility

/// Overlay presenting a text field for creating a new note.
///
/// - Binds to an external `isPresented` flag to control visibility.
/// - Calls `onSubmit` with the trimmed input when the user saves.
struct AddNoteOverlay: View {
    // MARK: - Presentation Binding
    @Binding var isPresented: Bool

    // MARK: - Submission Handler
    var onSubmit: (String) -> Void

    // MARK: - Internal State
    @State private var draft = ""
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed, blurred background that dismisses on tap, but hidden from VoiceOver
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture { isPresented = false }

            // Card-like container for input and actions
            VStack(spacing: 16) {
                // Top action bar with Cancel and Save buttons
                HStack {
                    Button("Cancel") {
                        isPresented = false
                    }
                    Spacer()
                    Button("Save") {
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
                    .focused($textFieldFocused)
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)
            .padding()
            // Trap VoiceOver focus inside this card
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .onAppear {
                // send VoiceOver cursor to the text field
                textFieldFocused = true
                UIAccessibility.post(
                    notification: .screenChanged,
                    argument: UIAccessibility.focusedElement(using: .notificationVoiceOver) ?? nil
                )
            }
        }
    }

    // MARK: - Helper Methods
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
