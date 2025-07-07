///
/// FolderOverlay.swift
/// NotesDemo
///
/// A modal overlay that allows users to view, select, add, or delete note folders.
/// Provides a blurred backdrop and a card interface for folder management.
///
import SwiftUI

/// Overlay view for managing note folders.
///
/// - Displays existing folders with selection and swipe-to-delete support.
/// - Allows creation of new folders via a text input.
/// - Dismisses itself when tapping outside the overlay.
struct FolderOverlay: View {
    // MARK: - Presentation Bindings
    /// Controls visibility of this overlay.
    @Binding var isPresented: Bool
    /// The currently selected folder name.
    @Binding var selectedFolder: String
    /// The list of all folder names.
    @Binding var folders: [String]

    // MARK: - Local State
    /// Draft name for creating a new folder.
    @State private var newFolderName: String = ""

    // MARK: - View Body
    var body: some View {
        ZStack {
            // Background: blurred and dismissible
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss overlay when tapping outside
                    isPresented = false
                }

            // Main card container
            VStack(spacing: 20) {
                // Title
                Text("Folders")
                    .font(.largeTitle.bold())

                // List of folders
                List {
                    ForEach(folders, id: \.self) { folder in
                        Button(action: {
                            // Update selection and close overlay
                            selectedFolder = folder
                            isPresented = false
                        }) {
                            HStack {
                                Text(folder)
                                    .font(.title2)
                                Spacer()
                                // Indicate current selection
                                if folder == selectedFolder {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    // Swipe-to-delete support
                    .onDelete { indexSet in
                        for index in indexSet {
                            let removed = folders[index]
                            // If removing the selected folder, pick another
                            if selectedFolder == removed {
                                selectedFolder = folders.first(where: { $0 != removed }) ?? ""
                            }
                            folders.remove(at: index)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .listStyle(PlainListStyle())

                // New folder creation row
                HStack {
                    TextField("New folder", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)

                    Button(action: addNewFolder) {
                        Text("Add")
                            .font(.title3.bold())
                    }
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(20)
            .padding(30)
        }
    }

    // MARK: - Helper Methods
    /// Adds a new folder if the name is non-empty and unique, then clears the input.
    private func addNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !folders.contains(trimmed) else { return }
        folders.append(trimmed)
        newFolderName = ""
    }
}

#if DEBUG
/// Preview provider for FolderOverlay
struct FolderOverlay_Previews: PreviewProvider {
    static var previews: some View {
        FolderOverlay(
            isPresented: .constant(true),
            selectedFolder: .constant("Notes"),
            folders: .constant(["Notes", "Work", "Personal"]))
    }
}
#endif
