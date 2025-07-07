///
/// RecordingView.swift
/// NotesDemo
///
/// Full-screen overlay for recording audio, converting the recording to MP3,
/// and saving it into the application's RecordingStore.
///
import SwiftUI
import AVFoundation
import SwiftLAME

/// A view that manages audio recording in M4A format,
/// converts the file to MP3 upon stopping, and
/// persists the result in `RecordingStore`.
struct RecordingView: View {
    // MARK: - Presentation Binding
    /// Binding to control the presentation of this overlay.
    @Binding var isPresented: Bool

    // MARK: - Environment Objects
    /// Shared store where completed recordings are saved.
    @EnvironmentObject var recordingStore: RecordingStore

    // MARK: - Recording State
    /// Underlying AVAudioRecorder instance for capturing audio.
    @State private var recorder: AVAudioRecorder?
    /// Temporary file URL for M4A recording.
    @State private var tempURL: URL?
    /// Flag tracking whether recording is active.
    @State private var isRecording = false
    /// Animation trigger for the pulsing record button.
    @State private var pulse = false

    // MARK: - Initializer
    /// Initializes the view with a binding controlling its presentation.
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    // MARK: - View Body
    var body: some View {
        ZStack {
            // Background dimming with blur effect
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack {
                Spacer()
                // Main record/stop button
                Button {
                    // Toggle recording state and perform appropriate action
                    if isRecording {
                        stopAndConvert()
                    } else {
                        startRecording()
                    }
                    isRecording.toggle()
                } label: {
                    RecordButton(isRecording: isRecording, pulse: pulse)
                }
                Spacer()
            }
        }
        // Start pulsing animation and auto-begin recording on appear
        .onAppear {
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                pulse = true
            }
            startRecording()
            isRecording = true
        }
    }

    // MARK: - Recording Control Methods
    /// Configures and starts the AVAudioRecorder, saving to a temporary M4A file.
    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)

        // Generate a unique temporary file URL
        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("rec_\(UUID()).m4a")
        tempURL = fileURL

        // Recorder settings: AAC format, 12 kHz sample rate, mono channel, high quality
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try? AVAudioRecorder(url: fileURL, settings: settings)
        recorder?.record()
    }

    /// Stops the recorder, converts the M4A file to MP3 using SwiftLAME,
    /// and saves the resulting recording to `RecordingStore`.
    private func stopAndConvert() {
        recorder?.stop()
        guard let src = tempURL else {
            // If no source URL, dismiss without saving
            isPresented = false
            return
        }

        // Destination URL: same base name with `.mp3` extension
        let dst = src.deletingPathExtension().appendingPathExtension("mp3")

        // Configure MP3 encoding: 44.1 kHz, constant 128 kbps, best quality
        let config = LameConfiguration(
            sampleRate: .custom(44100),
            bitrateMode: .constant(128),
            quality: .best
        )

        Task {
            do {
                // Perform asynchronous MP3 encoding
                let encoder = try SwiftLameEncoder(
                    sourceUrl: src,
                    configuration: config,
                    destinationUrl: dst
                )
                try await encoder.encode(priority: .userInitiated)

                // Create a Recording model and add it to the store on the main thread
                let rec = Recording(url: dst, createdAt: Date())
                await MainActor.run {
                    recordingStore.add(rec)
                    isPresented = false
                }
            } catch {
                print("MP3 encode failed:", error)
                // On failure, simply dismiss the overlay
                await MainActor.run { isPresented = false }
            }
        }
    }
}

// MARK: - Record Button Subview
/// A circular button with animated pulsing effect,
/// displaying either a mic or stop icon based on recording state.
private struct RecordButton: View {
    /// Whether recording is currently active
    let isRecording: Bool
    /// Controls pulsing animation scale and opacity
    let pulse: Bool

    var body: some View {
        ZStack {
            // Static red circle background
            Circle()
                .fill(.red)
                .frame(width: 150, height: 150)
                .overlay(
                    // Animated stroke for pulsing effect
                    Circle()
                        .stroke(.red.opacity(0.7), lineWidth: 12)
                        .scaleEffect(pulse ? 1.3 : 1)
                        .opacity(pulse ? 0 : 1)
                )
            // Icon toggles between stop and mic
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
        }
    }
}
