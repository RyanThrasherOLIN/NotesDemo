import SwiftUI
import UIKit  // for UIAccessibility

/// Modal overlay for selecting and managing folders.
/// Uses a card-style design, consistent colors/fonts, and a blurred backdrop.
struct FolderOverlay: View {
    // MARK: - Bindings
    @Binding var isPresented: Bool
    @Binding var selectedFolder: String
    @Binding var folders: [String]

    // MARK: - Local State
    @State private var newFolderName: String = ""
    @FocusState private var newFolderFocused: Bool
    @State private var showingRecorder: Bool = false
    @EnvironmentObject private var recordingStore: RecordingStore

    var body: some View {
        ZStack {
            // Dark semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Card container
            VStack(spacing: 20) {
                // Header with centered title and left-aligned close button
                ZStack {
                    Text("Folders")
                        .font(.largeTitle.bold())
                        .foregroundColor(ColorPalette.current.primary)
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(ColorPalette.current.secondary)
                        }
                        .accessibilityLabel("Close folders overlay")
                        Spacer()
                    }
                }

                // Scrollable list of existing folders
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(folders, id: \.self) { folder in
                            Button(action: {
                                selectedFolder = folder
                                isPresented = false
                            }) {
                                HStack {
                                    Text(folder)
                                        .font(.title3)
                                        .foregroundColor(ColorPalette.current.primary)
                                    Spacer()
                                    if folder == selectedFolder {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(ColorPalette.current.accent)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal)
                                .background(ColorPalette.current.background)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)

                Divider()

                // New folder creation row with send & record buttons
                HStack(spacing: 12) {
                    TextField("New folder", text: $newFolderName)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(UIColor.secondarySystemBackground))
                        )
                        .font(.title3)
                        .focused($newFolderFocused)
                        .submitLabel(.send)
                        .onSubmit { addNewFolder() }
                        .accessibilityLabel("New folder name")

                    Button(action: addNewFolder) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save folder")

                    Button(action: { showingRecorder = true }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Record folder name")
                    .accessibilityHint("Record and transcribe a new folder name")
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(20)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .onAppear {
                UIAccessibility.post(notification: .screenChanged, argument: "Folders overlay")
                newFolderFocused = true
            }
        }
        .fullScreenCover(isPresented: $showingRecorder) {
            RecordingView(isPresented: $showingRecorder)
                .environmentObject(recordingStore)
                .ignoresSafeArea()
        }
    }

    // MARK: - Helpers
    private func addNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !folders.contains(trimmed) else { return }
        folders.append(trimmed)
        newFolderName = ""
    }
}

#if DEBUG
struct FolderOverlay_Previews: PreviewProvider {
    static var previews: some View {
        FolderOverlay(
            isPresented: .constant(true),
            selectedFolder: .constant("Notes"),
            folders: .constant(["Notes", "Work", "Personal"])
        )
        .environmentObject(RecordingStore())
    }
}
#endif
