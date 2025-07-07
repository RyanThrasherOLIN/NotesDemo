///
/// SettingsView.swift
/// NotesDemo
///
/// Provides user-accessible settings and navigation for:
/// - Configuring application appearance and notifications
/// - Viewing synced hidden lines
/// - Managing audio recordings
/// - Specifying the server endpoint URL
///
import SwiftUI
import AVFoundation

/// Main settings screen for configuring app preferences and
/// accessing advanced views.
///
/// - Toggles dark mode, notifications, and server endpoint URL.
/// - Provides a "Back Door" to view all synced lines.
/// - Lists recorded audio notes and allows creating new recordings.
///
struct SettingsView: View {
    // MARK: - Environment
    /// Store for synced hidden lines
    @EnvironmentObject private var hiddenStore: HiddenLineStore
    /// Store for audio recordings
    @EnvironmentObject private var recordingStore: RecordingStore

    // MARK: - Persistent Settings
    /// Base URL for your backend API (stored in UserDefaults)
    @AppStorage("apiURL") private var apiURL: String = "http://10.77.0.11:5000"
    /// Toggle for dark mode preference (stored in UserDefaults)
    @AppStorage("darkMode") private var darkMode = false
    /// Toggle for enabling/disabling notifications (stored in UserDefaults)
    @AppStorage("notifications") private var notifications = true

    // MARK: - View State
    /// Controls presentation of the full-screen recording overlay
    @State private var showingRecorder = false

    // MARK: - View Body
    var body: some View {
        Form {
            // MARK: Server Configuration
            Section("Server") {
                // Allow user to enter custom API URL or IP address
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
                        .environmentObject(hiddenStore)
                }
            }

            // MARK: Recordings section
            Section("Recordings") {
                NavigationLink("Your Recordings (\(recordingStore.recordings.count))") {
                    RecordingListView()
                        .environmentObject(recordingStore)
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
        // Present the full-screen recording overlay when requested
        .fullScreenCover(isPresented: $showingRecorder) {
            RecordingView(isPresented: $showingRecorder)
                .environmentObject(recordingStore)
                .ignoresSafeArea()
        }
    }
}

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
