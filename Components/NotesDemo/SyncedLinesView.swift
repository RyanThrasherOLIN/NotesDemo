//
//  SyncedLinesView.swift
//  NotesDemo
//
//  Created by occamlab on 7/1/25.
//
import SwiftUI

/// Shows all synced lines from HiddenLineStore
struct SyncedLinesView: View {
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    var body: some View {
        List {
            ForEach(Array(hiddenStore.syncedLines).sorted(), id: \.self) { line in
                Text(line)
                    .padding(.vertical, 4)
            }
        }
        .navigationTitle("Synced Lines")
        .navigationBarTitleDisplayMode(.inline)
    }
}
