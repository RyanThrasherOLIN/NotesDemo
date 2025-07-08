import SwiftUI

/// Shows all messages currently synced through HiddenLineStore
struct SyncedLinesView: View {
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    var body: some View {
        List(hiddenStore.syncedMessages) { msg in
            HStack(alignment: .top, spacing: 8) {
                // Display the server-provided note ID (now a String)
                Text(msg.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(msg.text)
            }
            .padding(.vertical, 4)
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
