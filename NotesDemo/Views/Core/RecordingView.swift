import SwiftUI
import AVFoundation
import SwiftLAME
import AudioToolbox

/// Overlay for audio recording that only starts when the user taps.
/// Blinks a red dot while recording and plays system beeps on start and stop.
struct RecordingView: View {
    // MARK: - Presentation Binding
    @Binding var isPresented: Bool

    // MARK: - Environment
    @EnvironmentObject var recordingStore: RecordingStore

    // MARK: - Recording State
    @State private var recorder: AVAudioRecorder?
    @State private var tempURL: URL?
    @State private var isRecording = false
    @State private var showIndicator = false

    // MARK: - Silence Detection
    @State private var meterTimer: Timer?
    @State private var silenceDuration: TimeInterval = 0
    private let meterInterval: TimeInterval = 0.2
    private let silenceThreshold: TimeInterval = 2.0
    private let silenceLevel: Float = -40 // dB

    var body: some View {
        ZStack {
            VisualEffectView(style: .systemUltraThinMaterial)
                .edgesIgnoringSafeArea(.all)
                .accessibilityHidden(true)

            VStack(spacing: 30) {
                Spacer()

                HStack(spacing: 8) {
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .opacity(showIndicator ? 1 : 0)
                            .animation(
                                Animation.easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true),
                                value: showIndicator
                            )
                            .accessibilityHidden(true)
                    }

                    Text(isRecording
                         ? "Recording… Tap the button below to stop recording."
                         : "Tap the button below to start recording."
                    )
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isStaticText)
                }

                Button(action: {
                    if isRecording {
                        finishRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    RecordButton(isRecording: isRecording)
                }
                .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
                .accessibilityHint("Double-tap to \(isRecording ? "stop" : "start") recording")

                Spacer()
            }
            .padding()
        }
        .onAppear {
            UIAccessibility.post(notification: .announcement,
                                    argument: "Recording screen. Tap the button below to start recording.")
        }
        .onDisappear {
            cleanupMeters()
        }
    }

    private func startRecording() {
        // play start beep
        AudioServicesPlaySystemSound(1113)
        isRecording = true
        showIndicator = true
        silenceDuration = 0

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec_\(UUID()).m4a")
        tempURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.record()
        } catch {
            print("Recorder init failed: \(error)")
        }

        UIAccessibility.post(notification: .announcement,
                                argument: "Recording… Tap the button below to stop recording.")

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
        // stop meter
        cleanupMeters()
        recorder?.stop()

        // play stop beep
        AudioServicesPlaySystemSound(1114)

        restoreAudioSession()

        isRecording = false
        showIndicator = false

        UIAccessibility.post(notification: .announcement,
                                argument: "Recording stopped.")

        Task { _ = await convertAndSave() }
    }

    private func restoreAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session restore failed: \(error)")
        }
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
            print("MP3 encode failed: \(error)")
            await MainActor.run { isPresented = false }
            return nil
        }
    }
}

// Blur background visual
private struct VisualEffectView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Record button view
private struct RecordButton: View {
    let isRecording: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red)
                .frame(width: 160, height: 160)
                .shadow(radius: 8)

            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
        }
        .animation(.easeInOut(duration: 0.1), value: isRecording)
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
