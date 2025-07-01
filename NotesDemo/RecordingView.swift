//  RecordingView.swift
import SwiftUI
import AVFoundation

struct RecordingView: View {
    @Binding var isPresented: Bool

    @State private var pulse = false
    @State private var isRecording = false
    // private var recorder: AVAudioRecorder?   // your real recorder

    var body: some View {
        ZStack {
            // blur/dim background
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack {
                Spacer()

                // ⇨ tap this to start/stop
                Button(action: {
                    if isRecording {
                        stopRecording()
                        isPresented = false
                    } else {
                        startRecording()
                        isRecording = true
                    }
                }) {
                    ZStack {
                        // pulsing red circle
                        Circle()
                            .fill(Color.red)
                            .frame(width: 150, height: 150)
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.7), lineWidth: 12)
                                    .scaleEffect(pulse ? 1.3 : 1)
                                    .opacity(pulse ? 0 : 1)
                            )

                        // icon switches to stop when recording
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                }

                Spacer()
            }
        }
        .onAppear {
            // kick off pulse & auto-start
            withAnimation(.easeOut(duration: 1).repeatForever(autoreverses: false)) {
                pulse = true
            }
            startRecording()
            isRecording = true
        }
    }

    private func startRecording() {
        // TODO: AVAudioSession setup, AVAudioRecorder.record(), etc.
    }

    private func stopRecording() {
        // TODO: recorder?.stop(), save file, convert to MP3, etc.
    }
}
