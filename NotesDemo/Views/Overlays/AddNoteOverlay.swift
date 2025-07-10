import SwiftUI
import UIKit  // for UIAccessibility

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
            // 1) Dimmed, blurred background → hidden from VoiceOver
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .accessibilityHidden(true)      // ← hide the “underneath” UI
                .onTapGesture { isPresented = false }

            // 2) The card itself → a single modal element
            VStack(spacing: 16) {
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

            // ← trap VoiceOver focus inside here and mark as a modal
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            
            // 3) On appear, move VoiceOver focus into the field
            .onAppear {
                // small delay so the field is in the view hierarchy first
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    textFieldFocused = true
                    // announce the new modal to VoiceOver
                    UIAccessibility.post(
                      notification: .layoutChanged,
                      argument: nil
                    )
                }
            }
        }
    }

    private func commitAndDismiss() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { onSubmit(trimmed) }
        isPresented = false
    }
}
