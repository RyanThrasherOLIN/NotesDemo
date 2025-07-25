import SwiftUI
import UIKit

/// Simplified search overlay; focus on a clean results page with integrated controls and visual feedback.
struct SearchOverlay: View {
    // MARK: - Bindings
    @Binding var isPresented: Bool

    // MARK: - Environment
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var nav: NavigationStackHandler

    // MARK: - State
    @State private var query: String = ""
    @State private var answers: [AIResponse] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading: Bool = false
    @State private var showingRecorder: Bool = false
    @State private var feedbackGiven: Bool = false
    @State private var selectedFeedback: Int? = nil

    @FocusState private var isSearchFieldFocused: Bool
    @AccessibilityFocusState private var isResultFocused: Bool

    private let kResults = 5

    private var currentAnswer: AIResponse? {
        answers.indices.contains(currentIndex) ? answers[currentIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // backdrop
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .accessibilityHidden(true)

                VStack(spacing: 20) {
                    header
                    searchField
                    resultsView()
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 24)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isSearchFieldFocused = true
                        UIAccessibility.post(notification: .screenChanged, argument: nil)
                    }
                }
                .fullScreenCover(isPresented: $showingRecorder, onDismiss: handleVoiceQuery) {
                    RecordingView(isPresented: $showingRecorder)
                        .environmentObject(recordingStore)
                        .ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button(action: { isPresented = false }) {
                Image(systemName: "chevron.backward")
                    .font(.title2)
                    .padding(8)
            }
            .accessibilityLabel("Close search")

            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .first?.windows.first?.safeAreaInsets.top ?? 20)
    }

    // MARK: - Search Field (original design)
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Ask your question…", text: $query)
                .focused($isSearchFieldFocused)
                .submitLabel(.go)
                .onSubmit { Task { await performSearch() }}
                .accessibilityLabel("Search field")
                .accessibilityHint("Type your question and press Go")

            Button(action: { Task { await performSearch() } }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Submit search")

            Button(action: { showingRecorder = true }) {
                Image(systemName: "mic.circle.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Record voice query")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemGray5).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.systemGray3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Results View
    @ViewBuilder
    private func resultsView() -> some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding()
        } else if let resp = currentAnswer {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    HStack(alignment: .top, spacing: 16) {
                        // Tappable answer bubble
                        Text(resp.answer)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(UIColor.systemBackground).opacity(0.9))
                            )
                            .onTapGesture {
                                noteStore.highlightedNoteID = resp.id
                                nav.pushView(.noteDetail(folder: resp.folder, noteTitle: resp.notebook))
                                isPresented = false
                            }

                        // Integrated refresh button (larger hit area)
                        Button(action: refreshNextAnswer) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 34))
                                .padding(12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ColorPalette.current.accent)
                        .controlSize(.large)
                        .accessibilityLabel("Next answer")
                    }

                    // Enlarged feedback buttons
                    HStack(spacing: 32) {
                        Button(action: { giveFeedback(1) }) {
                            Image(systemName: selectedFeedback == 1 ? "hand.thumbsup.fill" : "hand.thumbsup")
                                .font(.system(size: 36))
                                .padding(12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                        .disabled(feedbackGiven)
                        .accessibilityLabel("Thumbs up")

                        Button(action: { giveFeedback(0) }) {
                            Image(systemName: selectedFeedback == 0 ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                .font(.system(size: 36))
                                .padding(12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                        .disabled(feedbackGiven)
                        .accessibilityLabel("Thumbs down")
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)
        }
    }

    // MARK: - Actions
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
            print("Search error: \(error)")
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
            noteStore.submitFeedback(question: query, answer: resp.answer, isPair: rating == 1)
        }
    }

    private func handleVoiceQuery() {
        guard let rec = recordingStore.recordings.first else { return }
        Task {
            if let text = await recordingStore.speechToText(rec) {
                query = text; isSearchFieldFocused = true
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
