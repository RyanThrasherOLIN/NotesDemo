import SwiftUI
import AVFoundation

struct SettingsView: View {
    // MARK: - Environment
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var noteStore: NoteStore    // <-- injected NoteStore

    // MARK: - Persistent Settings
    @AppStorage("apiURL") private var apiURL: String = "http://10.77.0.11:5000"
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("notifications") private var notifications = true

    // MARK: - View State
    @State private var showingRecorder = false
    @State private var showingDeleteAllConfirmation = false    // <-- new state

    // MARK: - View Body
    var body: some View {
        Form {
            // MARK: Server Configuration
            Section("Server") {
                TextField("Server URL", text: $apiURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Server URL")
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

// RecordingListView and RecordingRowView remain unchanged.

/// View that lists all audio recordings in the store.
///
/// Displays each recording using `RecordingRowView`.
///
struct RecordingListView: View {
    /// Shared recording store
    @EnvironmentObject var recordingStore: RecordingStore

    var body: some View {
        List(recordingStore.recordings) { rec in
            RecordingRowView(recording: rec)
        }
        .navigationTitle("Recordings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Individual row representing a single audio recording.
///
/// - Shows play/stop button and file info.
/// - Manages playback state using `AVAudioPlayer`.
///
private struct RecordingRowView: View {
    /// The recording model to display
    let recording: Recording
    /// Underlying audio player for playback
    @State private var player: AVAudioPlayer?
    /// Playback state flag
    @State private var isPlaying = false

    var body: some View {
        HStack {
            // Play/stop toggle button
            Button(action: togglePlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }

            // Recording filename and timestamp
            VStack(alignment: .leading) {
                Text(recording.url.lastPathComponent)
                Text(recording.createdAt, style: .time)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        // Ensure audio stops when row disappears
        .onDisappear {
            player?.stop()
            isPlaying = false
        }
    }

    /// Toggles playback of the associated recording.
    ///
    /// - Starts playback if not playing; otherwise stops it.
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
