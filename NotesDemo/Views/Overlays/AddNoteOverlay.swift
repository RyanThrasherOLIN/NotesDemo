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
    @EnvironmentObject private var recordingStore: RecordingStore  // for voice notes
    @State private var showingRecorder = false

    var body: some View {
        ZStack {
            // Blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)

            // Compact card container
            VStack(spacing: 16) {
                // Header with close (✕) and save
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                    }
                    .accessibilityLabel("Close add notebook")

                    Spacer()

                    Text("Add Notebook")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Button(action: commitAndDismiss) {
                        Text("Save")
                            .fontWeight(.bold)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)

                // Input with send + mic
                HStack(spacing: 12) {
                    TextField("Enter Notebook Title", text: $draft)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .focused($textFieldFocused)
                        .submitLabel(.done)
                        .onSubmit { commitAndDismiss() }

                    Button(action: commitAndDismiss) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Save notebook")

                    Button(action: { showingRecorder = true }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Record voice notebook title")
                    .accessibilityHint("Record and transcribe a new notebook title")
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    textFieldFocused = true
                    UIAccessibility.post(notification: .layoutChanged, argument: nil)
                }
            }
            .fullScreenCover(isPresented: $showingRecorder, onDismiss: handleVoiceNoteDismiss) {
                RecordingView(isPresented: $showingRecorder)
                    .environmentObject(recordingStore)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Commit
    private func commitAndDismiss() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onSubmit(trimmed)
        }
        isPresented = false
    }

    // MARK: - Handle Voice Note
    private func handleVoiceNoteDismiss() {
        guard let rec = recordingStore.recordings.first else { return }
        Task {
            if let text = await recordingStore.speechToText(rec) {
                await MainActor.run {
                    draft = text
                    textFieldFocused = true
                }
            }
        }
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
