// FolderOverlay.swift

import SwiftUI
import UIKit  // for UIAccessibility

/// Modal overlay for selecting and managing folders.
/// Uses a centered card with pill-style input, matching other overlays.
struct FolderOverlay: View {
    // MARK: - Bindings
    @Binding var isPresented: Bool
    @Binding var selectedFolder: String
    @Binding var folders: [String]

    // MARK: - State
    @State private var newFolderName: String = ""
    @FocusState private var newFolderFocused: Bool
    @State private var showingRecorder: Bool = false
    @EnvironmentObject private var recordingStore: RecordingStore

    var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Card container
            VStack(spacing: 24) {
                // Header
                ZStack {
                    Text("Folders")
                        .font(.largeTitle.bold())
                        .foregroundColor(ColorPalette.current.primary)
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(ColorPalette.current.secondary)
                                .padding(8)
                        }
                        .accessibilityLabel("Close folders overlay")
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }

                // Folder list
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
                                            .font(.title2)
                                            .foregroundColor(ColorPalette.current.accent)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(ColorPalette.current.background)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)    // prevent pills touching edges
                }
                .frame(maxHeight: 300)

                Divider()

                // New folder input row
                HStack(spacing: 8) {               // gap between text field & button group
                    TextField("New folder…", text: $newFolderName)
                        .font(.title3)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(UIColor.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(ColorPalette.current.accent, lineWidth: 2)
                        )
                        .focused($newFolderFocused)
                        .submitLabel(.send)
                        .onSubmit(addNewFolder)
                        .accessibilityLabel("New folder name")

                    HStack(spacing: 0) {         // send & mic flush together
                        Button(action: addNewFolder) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(ColorPalette.current.accent)
                                .padding(8)
                        }
                        .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Save folder")

                        Button(action: { showingRecorder = true }) {
                            Image(systemName: "mic.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(ColorPalette.current.accent)
                                .padding(8)
                        }
                        .accessibilityLabel("Record folder name")
                        .accessibilityHint("Record and transcribe a new folder name")
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: 360)
            .padding(.vertical, 24)
            .background(.regularMaterial)
            .cornerRadius(20)
            .padding(.horizontal, 16)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .onAppear {
                // announce the overlay, but do NOT auto-focus the input field
                UIAccessibility.post(notification: .screenChanged, argument: "Folders overlay")
            }
            .fullScreenCover(isPresented: $showingRecorder) {
                RecordingView(isPresented: $showingRecorder)
                    .environmentObject(recordingStore)
                    .ignoresSafeArea()
            }
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
