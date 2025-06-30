import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var hiddenStore: HiddenLineStore
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("notifications") private var notifications = true

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Dark Mode", isOn: $darkMode)
            }
            Section("Alerts") {
                Toggle("Enable Notifications", isOn: $notifications)
            }
            Section("Back Door") {
                NavigationLink("View All Synced Lines") {
                    SyncedLinesView()
                        .environmentObject(hiddenStore)
                }
            }
            Section {
                Button("Log Out") {
                    // your logout logic
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

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

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(HiddenLineStore())
        }
    }
}
#endif
