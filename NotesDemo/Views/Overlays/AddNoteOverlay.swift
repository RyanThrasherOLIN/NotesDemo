import SwiftUI
import UIKit  // for UIAccessibility

/// Overlay for adding a new notebook, with centered card and pill-style input.
struct AddNoteOverlay: View {
    // MARK: - Presentation
    @Binding var isPresented: Bool
    var onSubmit: (String) -> Void

    // MARK: - State
    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool
    @EnvironmentObject private var recordingStore: RecordingStore
    @State private var showingRecorder: Bool = false

    var body: some View {
        ZStack {
            // Blurred backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)

            // Centered card container
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .padding(8)
                    }
                    .accessibilityLabel("Close add notebook")

                    Spacer()

                    Text("Add Notebook")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(ColorPalette.current.primary)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()
                    // Placeholder for symmetry
                    Spacer().frame(width: 32)
                }
                .padding(.top, 10)
                .padding(.horizontal, 32)

                // Input & actions
                HStack(spacing: 16) {
                    TextField("Notebook name…", text: $draft)
                        .font(.title3)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(UIColor.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(ColorPalette.current.accent, lineWidth: 2)
                        )
                        .focused($inputFocused)
                        .submitLabel(.done)
                        .onSubmit(commitAndDismiss)
                        .accessibilityLabel("Notebook name input field")

                    Button(action: commitAndDismiss) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(ColorPalette.current.accent)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save notebook")

                    Button(action: { showingRecorder = true }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(ColorPalette.current.accent)
                    }
                    .accessibilityLabel("Record voice notebook title")
                }
                .padding(.horizontal, 32)

            }
            .frame(maxWidth: 360)
            .padding(.vertical, 32)
            .background(.regularMaterial)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    inputFocused = true
                    UIAccessibility.post(notification: .layoutChanged, argument: "Add Notebook overlay")
                }
            }
            .fullScreenCover(isPresented: $showingRecorder) {
                RecordingView(isPresented: $showingRecorder)
                    .environmentObject(recordingStore)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Actions
    private func commitAndDismiss() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { onSubmit(trimmed) }
        isPresented = false
    }
}

#if DEBUG
struct AddNoteOverlay_Previews: PreviewProvider {
    static var previews: some View {
        AddNoteOverlay(isPresented: .constant(true)) { _ in }
            .environmentObject(RecordingStore())
    }
}
#endif
