import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject private var hiddenStore: HiddenLineStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @AppStorage("darkMode") private var darkMode = false
    @AppStorage("notifications") private var notifications = true
    @State private var showingRecorder = false

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
            Section("Recordings") {
                NavigationLink("Your Recordings (\(recordingStore.recordings.count))") {
                    RecordingListView()
                        .environmentObject(recordingStore)
                }
            }
            Section {
                Button("Record New Audio") {
                    showingRecorder = true
                }
                .accessibilityLabel("Record new note")
                .foregroundColor(.blue)
                Button("Log Out") {
                    // your logout logic
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

struct RecordingRowView: View {
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
