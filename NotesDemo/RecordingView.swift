import SwiftUI
import AVFoundation
import SwiftLAME

/// Overlay view that records audio (m4a), converts to MP3, and saves to RecordingStore.
struct RecordingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var recordingStore: RecordingStore

    @State private var recorder: AVAudioRecorder?
    @State private var tempURL: URL?
    @State private var isRecording = false
    @State private var pulse = false

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack {
                Spacer()
                Button {
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
        .onAppear {
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                pulse = true
            }
            startRecording()
            isRecording = true
        }
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)

        let tmpDir = FileManager.default.temporaryDirectory
        let fileURL = tmpDir.appendingPathComponent("rec_\(UUID()).m4a")
        tempURL = fileURL

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try? AVAudioRecorder(url: fileURL, settings: settings)
        recorder?.record()
    }

    private func stopAndConvert() {
        recorder?.stop()
        guard let src = tempURL else {
            isPresented = false
            return
        }
        let dst = src.deletingPathExtension().appendingPathExtension("mp3")
        let config = LameConfiguration(
            sampleRate: .custom(44100),
            bitrateMode: .constant(128),
            quality: .best
        )
        Task {
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
            } catch {
                print("MP3 encode failed:", error)
                await MainActor.run { isPresented = false }
            }
        }
    }
}

private struct RecordButton: View {
    let isRecording: Bool
    let pulse: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(.red)
                .frame(width: 150, height: 150)
                .overlay(
                    Circle()
                        .stroke(.red.opacity(0.7), lineWidth: 12)
                        .scaleEffect(pulse ? 1.3 : 1)
                        .opacity(pulse ? 0 : 1)
                )
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 60))
                .foregroundColor(.white)
        }
    }
}

