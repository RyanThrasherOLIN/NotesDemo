// SearchOverlay.swift

import SwiftUI
import UIKit

/// Simplified search overlay; clean, centered results pop-up with lighter backdrop and true modal VoiceOver.
struct SearchOverlay: View {
    // Bindings
    @Binding var isPresented: Bool

    // Environment
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var nav: NavigationStackHandler

    // State
    @State private var query: String = ""
    @State private var answers: [AIResponse] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading: Bool = false
    @State private var showingRecorder: Bool = false
    @State private var feedbackGiven: Bool = false
    @State private var selectedFeedback: Int? = nil
    
    @AppStorage("username") var username: String?

    @FocusState private var isSearchFieldFocused: Bool

    private let kResults = 5
    private var currentAnswer: AIResponse? {
        answers.indices.contains(currentIndex) ? answers[currentIndex] : nil
    }

    var body: some View {
        ZStack {
            // Lighter, semi-opaque backdrop
            Color.white.opacity(1)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                header

                // search input bubble
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(ColorPalette.current.secondary)
                    TextField("Ask your question…", text: $query)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.go)
                        .onSubmit { Task { await performSearch() } }
                        .font(.title3)
                    Button(action: { Task { await performSearch() } }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button(action: { showingRecorder = true }) {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                    }
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(.regularMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(ColorPalette.current.accent, lineWidth: 2)
                )
                .padding(.horizontal, 16)

                if isLoading {
                    ProgressView()
                        .padding()
                } else if let resp = currentAnswer {
                    resultCard(resp)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 24)
            // trap VoiceOver focus inside this overlay
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .fullScreenCover(isPresented: $showingRecorder, onDismiss: handleVoiceQuery) {
                RecordingView(isPresented: $showingRecorder)
                    .environmentObject(recordingStore)
                    .ignoresSafeArea()
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isSearchFieldFocused = true
                }
            }
        }
        // also mark the entire ZStack as modal so background doesn’t get VoiceOver focus
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: – Header
    private var header: some View {
        HStack {
            Button { isPresented = false } label: {
                Image(systemName: "xmark")
                    .font(.title2)
                    .padding(8)
            }
            .accessibilityLabel("Close search")
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows.first?.safeAreaInsets.top ?? 20)
    }

    // MARK: – Result Card Bubble
    private func resultCard(_ resp: AIResponse) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                Text(resp.answer)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .onTapGesture {
                        noteStore.highlightedNoteID = resp.id
                        nav.pushView(.noteDetail(folder: resp.folder, noteTitle: resp.notebook))
                        isPresented = false
                    }
                Spacer()
                Button(action: refreshNextAnswer) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                }
                .accessibilityLabel("Next answer")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(ColorPalette.current.accent, lineWidth: 2)
            )
            .frame(maxWidth: 360)

            HStack(spacing: 40) {
                Button(action: { giveFeedback(1) }) {
                    Image(systemName: selectedFeedback == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .font(.system(size: 36))
                        .padding(12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(feedbackGiven)
                .accessibilityLabel("Mark as helpful")

                Button(action: { giveFeedback(0) }) {
                    Image(systemName: selectedFeedback == 0 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                        .font(.system(size: 36))
                        .padding(12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(feedbackGiven)
                .accessibilityLabel("Mark as unhelpful")
            }

            Button("New Question") {
                query = ""
                answers = []
                currentIndex = 0
                feedbackGiven = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFieldFocused = true
                }
            }
            .font(.headline)
            .padding(.vertical, 12)
            .frame(maxWidth: 200)
            .buttonStyle(.borderedProminent)
            .tint(ColorPalette.current.accent)
            .accessibilityLabel("Ask a new question")
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.regularMaterial)
        )
        .shadow(radius: 12)
        .padding(.horizontal, 16)
    }

    // MARK: – Actions
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true; feedbackGiven = false; selectedFeedback = nil
        defer { isLoading = false }
        do {
            answers = try await noteStore.fetchTopNotes(question: trimmed, k: kResults)
            currentIndex = 0
        } catch {
            answers = []
        }
    }

    private func refreshNextAnswer() {
        guard currentIndex + 1 < answers.count else { return }
        currentIndex += 1; feedbackGiven = false; selectedFeedback = nil
    }

    private func giveFeedback(_ rating: Int) {
        selectedFeedback = rating
        feedbackGiven = true
        if let resp = currentAnswer {
            noteStore.submitFeedback(username: username ?? noteStore.deviceID, question: query, answer: resp.answer, isPair: rating == 1)
        }
    }

    private func handleVoiceQuery() {
        guard let rec = recordingStore.recordings.first else { return }
        Task {
            if let text = await recordingStore.speechToText(rec) {
                query = text
                isSearchFieldFocused = true
            }
        }
    }
}

#if DEBUG
struct SearchOverlay_Previews: PreviewProvider {
    static var previews: some View {
        SearchOverlay(isPresented: .constant(true))
            .environmentObject(NoteStore())
            .environmentObject(RecordingStore())
            .environmentObject(NavigationStackHandler.shared)
    }
}
#endif
