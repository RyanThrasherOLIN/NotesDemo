// SyncedLinesView.swift
// Displays all messages currently synced in HiddenLineStore

import SwiftUI

struct SyncedLinesView: View {
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    var body: some View {
        List {
            ForEach(hiddenStore.syncedMessages) { msg in
                HStack(alignment: .top, spacing: 8) {
                    Text(msg.id.uuidString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(msg.text)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Synced Messages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
struct SyncedLinesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SyncedLinesView()
                .environmentObject(HiddenLineStore())
        }
    }
}
#endif
