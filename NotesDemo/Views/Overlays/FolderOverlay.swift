// FolderOverlay.swift
// NotesDemo
//
// A modal overlay that allows users to view, select, add, or delete note folders.
// Provides a blurred backdrop and a card interface for folder management.

import SwiftUI
import UIKit  // for UIAccessibility

/// Overlay view for managing note folders.
///
/// - Displays existing folders with selection and swipe-to-delete support.
/// - Allows creation of new folders via a text input.
/// - Dismisses itself when tapping outside the overlay.
struct FolderOverlay: View {
    // MARK: - Presentation Bindings
    @Binding var isPresented: Bool
    @Binding var selectedFolder: String
    @Binding var folders: [String]

    // MARK: - Local State
    @State private var newFolderName: String = ""

    var body: some View {
        ZStack {
            // Background: blurred and dismissible but hidden from accessibility
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onTapGesture {
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
                            selectedFolder = folder
                            isPresented = false
                        }) {
                            HStack {
                                Text(folder)
                                    .font(.title2)
                                Spacer()
                                if folder == selectedFolder {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let removed = folders[index]
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
            // MARK: Accessibility
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)         // <-- mark as modal
            .onAppear {
                // Move VoiceOver focus to the heading
                UIAccessibility.post(notification: .screenChanged, argument: "Folders")
            }
        }
    }

    // MARK: - Helper Methods
    private func addNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
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
    }
}
#endif
