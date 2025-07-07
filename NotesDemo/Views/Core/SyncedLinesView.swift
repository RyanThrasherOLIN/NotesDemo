import SwiftUI

/// Displays all unique message IDs currently synced in HiddenLineStore.
/// Useful for inspecting/debugging which message IDs have been synced.
struct SyncedLinesView: View {
    // MARK: - Environment
    @EnvironmentObject private var hiddenStore: HiddenLineStore

    // MARK: - View Body
    var body: some View {
        List {
            // Convert the set of syncedIDs to a sorted array for consistent order
            ForEach(Array(hiddenStore.syncedIDs).sorted(), id: \.self) { id in
                Text(id)
                    .padding(.vertical, 4)
                    .accessibilityLabel("Synced ID: \(id)")
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
