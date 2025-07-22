//
// SettingsView.swift
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    // MARK: - Environment
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var noteStore: NoteStore

    // MARK: - Persistent Settings
    @AppStorage("apiURL")       private var apiURL: String       = "http://64.181.230.227:5000"
    init() {
        UserDefaults.standard.set("http://64.181.230.227:5000/", forKey: "apiURL")
    }
    @AppStorage("darkMode")     private var darkMode: Bool       = false
    @AppStorage("notifications")private var notifications: Bool   = true
    @AppStorage("username")     private var username: String     = ""    // ← persisted username

    // MARK: - View State
    @State private var showingRecorder             = false
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

                // MARK: Server Configuration (Read-Only for App Store submission)
                Section("Server") {
                    HStack {
                        Text("Server URL")
                        Spacer()
                        Text(apiURL)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled) // Allow copy but no edit
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Server URL")
                    .accessibilityValue(apiURL)
                }

                // MARK: Appearance section
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $darkMode)
                }

                // MARK: Alerts section
                Section("Alerts") {
                    Toggle("Enable Notifications", isOn: $notifications)
                }

                // MARK: Back Door section
                Section("Back Door") {
                    NavigationLink("View All Synced Lines") {
                        SyncedLinesView()
                    }
                }

                // MARK: Recordings section
                Section("Recordings") {
                    NavigationLink("Your Recordings (\(recordingStore.recordings.count))") {
                        RecordingListView()
                            .environmentObject(recordingStore)
                    }
                }

                // MARK: Delete Notes section
                Section("Delete Notes") {
                    Button("Delete All Notes") {
                        showingDeleteAllConfirmation = true
                    }
                    .foregroundColor(.red)
                    .alert("Delete All Notes",
                           isPresented: $showingDeleteAllConfirmation) {
                        Button("Delete", role: .destructive) {
                            noteStore.deleteAllNotes()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("Are you sure you want to delete all notes? This cannot be undone.")
                    }
                }

                // MARK: Actions
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

// MARK: — Recording List & Row —

struct RecordingListView: View {
    @EnvironmentObject var recordingStore: RecordingStore

    var body: some View {
        List(recordingStore.recordings) { rec in
            RecordingRowView(recording: rec)
        }
        .navigationTitle("Recordings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RecordingRowView: View {
    let recording: Recording
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false

    var body: some View {
        HStack {
            Button(action: togglePlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }
            VStack(alignment: .leading) {
                Text(recording.url.lastPathComponent)
                Text(recording.createdAt, style: .time)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .onDisappear {
            player?.stop()
            isPlaying = false
        }
    }

    private func togglePlay() {
        if isPlaying {
            player?.stop()
            isPlaying = false
        } else {
            do {
                player = try AVAudioPlayer(contentsOf: recording.url)
                player?.play()
                isPlaying = true
            } catch {
                print("Playback error:", error)
            }
        }
    }
}

