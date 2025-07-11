import SwiftUI
import AVFoundation
import SwiftLAME

/// A streamlined overlay for audio recording.
/// Automatically starts recording on appear,
/// auto-stops after silence, and allows manual stop via button.
struct RecordingView: View {
    // MARK: - Presentation Binding
    @Binding var isPresented: Bool

    // MARK: - Environment
    @EnvironmentObject var recordingStore: RecordingStore

    // MARK: - Recording State
    @State private var recorder: AVAudioRecorder?
    @State private var tempURL: URL?
    @State private var isRecording = false
    @State private var pulse = false

    // MARK: - Silence Detection
    @State private var meterTimer: Timer?
    @State private var silenceDuration: TimeInterval = 0
    private let meterInterval: TimeInterval = 0.2
    private let silenceThreshold: TimeInterval = 2.0
    private let silenceLevel: Float = -40 // dB

    var body: some View {
        ZStack {
            // Light blurred background
            VisualEffectView(style: .systemUltraThinMaterial)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack {
                // Header with cancel/back
                HStack {
                    Button(action: cancelRecording) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.primary)
                    }
                    .accessibilityLabel("Cancel recording")
                    Spacer()
                }
                .padding()

                Spacer()

                // Recording button stops when tapped
                Button(action: finishRecording) {
                    RecordButton(isRecording: isRecording, pulse: pulse)
                }
                .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
                .accessibilityHint(isRecording ? "Double tap to stop recording" : "Recording has already started")

                Spacer()

                // Status text
                Text(isRecording ? "Recording… Tap button to stop." : "Recording stopped.")
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.bottom)
            }
        }
        .onAppear {
            // animate and start
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                pulse = true
            }
            beginRecording()
        }
        .onDisappear {
            cleanupMeters()
        }
    }

    // MARK: - Recording Control
    private func beginRecording() {
        isRecording = true
        silenceDuration = 0
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .default)
        try? session.setActive(true)

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec_\(UUID()).m4a")
        tempURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try? AVAudioRecorder(url: fileURL, settings: settings)
        recorder?.isMeteringEnabled = true
        recorder?.record()

        meterTimer = Timer.scheduledTimer(withTimeInterval: meterInterval, repeats: true) { _ in
            guard let r = recorder else { return }
            r.updateMeters()
            if r.averagePower(forChannel: 0) < silenceLevel {
                silenceDuration += meterInterval
                if silenceDuration >= silenceThreshold {
                    finishRecording()
                }
            } else {
                silenceDuration = 0
            }
        }
    }

    private func finishRecording() {
        guard isRecording else { return }
        cleanupMeters()
        recorder?.stop()
        isRecording = false
        Task { _ = await convertAndSave() }
    }

    private func cancelRecording() {
        cleanupMeters()
        recorder?.stop()
        isPresented = false
    }

    private func cleanupMeters() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func convertAndSave() async -> Recording? {
        guard let src = tempURL else {
            await MainActor.run { isPresented = false }
            return nil
        }
        let dst = src.deletingPathExtension().appendingPathExtension("mp3")
        let config = LameConfiguration(
            sampleRate: .custom(44100),
            bitrateMode: .constant(128),
            quality: .best
        )
        do {
            let encoder = try SwiftLameEncoder(
                sourceUrl: src,
                configuration: config,
                destinationUrl: dst
            )
            try await encoder.encode(priority: .userInitiated)
            let rec = Recording(url: dst, createdAt: Date())
            await MainActor.run {
                recordingStore.add(rec)
                isPresented = false
            }
            return rec
        } catch {
            print("MP3 encode failed:", error)
            await MainActor.run { isPresented = false }
            return nil
        }
    }
}

/// A UIViewRepresentable wrapper for UIKit blur effects.
private struct VisualEffectView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Record Button Subview
private struct RecordButton: View {
    let isRecording: Bool
    let pulse: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 160, height: 160)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.7), lineWidth: 12)
                        .scaleEffect(pulse ? 1.4 : 1)
                        .opacity(pulse ? 0 : 1)
                )
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
        }
    }
}

#if DEBUG
struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView(isPresented: .constant(true))
            .environmentObject(RecordingStore())
    }
}
#endif
