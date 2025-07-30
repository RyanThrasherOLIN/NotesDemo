import SwiftUI
import AVFoundation

// MARK: - SettingsView (updated)
struct SettingsView: View {
    // MARK: - Environment
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var noteStore: NoteStore

    // MARK: - Persistent Settings
    @AppStorage("apiURL") private var apiURL: String = "https://happily-complete-stinkbug.ngrok-free.app/"
    @AppStorage("username") private var username: String = ""
    @AppStorage("colorBlindMode") private var rawColorBlindMode: String = ColorBlindMode.normal.rawValue
    @AppStorage("alwaysShowTutorial") private var alwaysShowTutorial = false
    private var colorMode: ColorBlindMode { ColorBlindMode(rawValue: rawColorBlindMode) ?? .normal }

    // MARK: - View State
    @State private var showingRecorder = false
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        Form {
            Section("User") {
                TextField("Enter username", text: $username)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Username")
                    .accessibilityHint("Enter your display name")
            }

            Section("Server") {
                TextField("Server URL", text: $apiURL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .accessibilityLabel("Server URL")
                    .accessibilityHint("Edit the backend server endpoint URL")
            }

            Section("Color Mode") {
                Picker("Color Mode", selection: $rawColorBlindMode) {
                    ForEach(ColorBlindMode.allCases, id: \ .rawValue) { mode in
                        Text(
                            mode.rawValue
                                .capitalized
                                .replacingOccurrences(of: "Highcontrast", with: "High Contrast")
                        )
                        .tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Color mode selection")
                .accessibilityHint("Select a color or contrast mode for the app")

                // Palette Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Palette Preview")
                        .font(.subheadline).bold()
                    HStack {
                        Text("Primary")
                            .frame(width: 80, alignment: .leading)
                        Rectangle()
                            .fill(ColorPalette.current.primary)
                            .frame(width: 30, height: 30)
                            .cornerRadius(4)
                    }
                    HStack {
                        Text("Secondary")
                            .frame(width: 80, alignment: .leading)
                        Rectangle()
                            .fill(ColorPalette.current.secondary)
                            .frame(width: 30, height: 30)
                            .cornerRadius(4)
                    }
                    HStack {
                        Text("Accent")
                            .frame(width: 80, alignment: .leading)
                        Rectangle()
                            .fill(ColorPalette.current.accent)
                            .frame(width: 30, height: 30)
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 8)
            }

            // New Tutorial Section
            Section("Tutorial") {
                Toggle("Show tutorial every launch", isOn: $alwaysShowTutorial)
                    .accessibilityLabel("Always show tutorial")
                    .accessibilityHint("Toggle to see tutorial every time the app launches")
            }

            Section("Back Door") {
                NavigationLink("View All Synced Lines") {
                    SyncedLinesView()
                }
            }

            Section("Delete Notes") {
                Button("Delete All Notes") {
                    showingDeleteAllConfirmation = true
                }
                .foregroundColor(.red)
                .alert(
                    "Delete All Notes", isPresented: $showingDeleteAllConfirmation,
                    actions: {
                        Button("Delete", role: .destructive) {
                            noteStore.deleteAllNotes()
                        }
                        Button("Cancel", role: .cancel) {}
                    },
                    message: {
                        Text("Are you sure you want to delete all notes? This cannot be undone.")
                    }
                )
            }

            Section {
                Button("Record New Audio") {
                    showingRecorder = true
                }
                .accessibilityLabel("Record new note")

                Button("Log Out") {
                    // your logout logic here
                }
                .foregroundColor(.red)
            }
        }
        .fullScreenCover(isPresented: $showingRecorder) {
            RecordingView(isPresented: $showingRecorder)
                .environmentObject(recordingStore)
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environmentObject(RecordingStore())
                .environmentObject(NoteStore())
        }
        .navigationViewStyle(.stack)
    }
}
#endif
