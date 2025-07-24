// SettingsView.swift
// NotesDemo

import SwiftUI
import AVFoundation

struct SettingsView: View {
    // MARK: - Environment
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var noteStore: NoteStore

    // MARK: - Persistent Settings
    @AppStorage("apiURL") private var apiURL: String = "https://happily-complete-stinkbug.ngrok-free.app/"
    @AppStorage("darkMode") private var darkMode: Bool = false
    @AppStorage("username") private var username: String = ""

    // MARK: - Color Mode Setting
    @AppStorage("colorBlindMode") private var rawColorBlindMode: String = ColorBlindMode.normal.rawValue
    private var colorMode: ColorBlindMode { ColorBlindMode(rawValue: rawColorBlindMode) ?? .normal }

    // MARK: - View State
    @State private var showingRecorder = false
    @State private var showingDeleteAllConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                // MARK: User section
                Section("User") {
                    TextField("Enter username", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Username")
                        .accessibilityHint("Enter your display name")
                }

                // MARK: Server Configuration
                Section("Server") {
                    TextField("Server URL", text: $apiURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .accessibilityLabel("Server URL")
                        .accessibilityHint("Edit the backend server endpoint URL")
                }

                // MARK: Appearance Section
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $darkMode)
                }

                // MARK: Color Vision Section
                Section("Color Mode") {
                    Picker("Palette", selection: $rawColorBlindMode) {
                        ForEach(ColorBlindMode.allCases, id: \ .rawValue) { mode in
                            Text(mode.rawValue.capitalized.replacingOccurrences(of: "Highcontrast", with: "High Contrast"))
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

                // MARK: Back Door section
                Section("Back Door") {
                    NavigationLink("View All Synced Lines") {
                        SyncedLinesView()
                    }
                }

                // MARK: Delete Notes Section
                Section("Delete Notes") {
                    Button("Delete All Notes") {
                        showingDeleteAllConfirmation = true
                    }
                    .foregroundColor(.red)
                    .alert(
                        "Delete All Notes",
                        isPresented: $showingDeleteAllConfirmation
                    ) {
                        Button("Delete", role: .destructive) {
                            noteStore.deleteAllNotes()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Are you sure you want to delete all notes? This cannot be undone.")
                    }
                }

                // MARK: Actions Section
                Section {
                    Button("Record New Audio") {
                        showingRecorder = true
                    }
                    .accessibilityLabel("Record new note")
                    .foregroundColor(.blue)

                    Button("Log Out") {
                        // your logout logic here
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingRecorder) {
                RecordingView(isPresented: $showingRecorder)
                    .environmentObject(recordingStore)
                    .ignoresSafeArea()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(RecordingStore())
            .environmentObject(NoteStore())
    }
}
