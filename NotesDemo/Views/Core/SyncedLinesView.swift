///
/// SyncedLinesView.swift
/// NotesDemo
///
/// A debug/admin view that lists every line of text
/// that has been synced to the HiddenLineStore.
///
import SwiftUI

/// Displays all unique lines currently stored in HiddenLineStore.
///
/// - Useful for inspecting or debugging which lines have been synced.
struct SyncedLinesView: View {
    // MARK: - Environment
    /// Store containing the set of synced lines from all notes
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    // MARK: - View Body
    var body: some View {
        List {
            // Convert the set to a sorted array for consistent order
            ForEach(Array(hiddenStore.syncedLines).sorted(), id: \.self) { line in
                Text(line)
                    .padding(.vertical, 4)
                    .accessibilityLabel("Synced line: \(line)")
            }
        }
        .navigationTitle("Synced Lines")
        .navigationBarTitleDisplayMode(.inline)
    }
}
