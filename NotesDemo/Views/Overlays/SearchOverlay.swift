import SwiftUI
import UIKit  // for UIAccessibility

struct SearchOverlay: View {
    // MARK: - Presentation
    @Binding var isPresented: Bool

    // MARK: - Environment
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var nav: NavigationStackHandler  // ← re-added

    // MARK: - Config
    private let kResults = 5

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

    private var currentAnswer: AIResponse? {
        answers.indices.contains(currentIndex) ? answers[currentIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dimmed background just dismisses the overlay
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .accessibilityHidden(true)

                VStack(spacing: 20) {
                    // Top bar with close button
                    HStack {
                        Button(action: { isPresented = false }) {
                            Image(systemName: "chevron.backward")
                                .font(.title2)
                                .padding(8)
                        }
                        .accessibilityLabel("Close search")
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 20)

                    // Search field
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Ask your question…", text: $query)
                            .focused($isSearchFieldFocused)
                            .submitLabel(.go)
                            .onSubmit { Task { await performSearch() } }
                            .accessibilityLabel("Search field")
                            .accessibilityHint("Type your question and press Go")
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

                    // Results
                    if isLoading {
                        ProgressView()
                            .accessibilityLabel("Loading results")
                    } else if let resp = currentAnswer {
                        VStack(alignment: .leading, spacing: 20) {
                            // Tappable result bubble
                            Text(resp.answer)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color(UIColor.systemGray6))
                                )
                                .accessibilityLabel("Search result")
                                .accessibilityValue(resp.answer)
                                .accessibilityFocused($isResultFocused)
                                .onTapGesture {
                                    // Navigate into the selected notebook
                                    nav.pushView(.noteDetail(
                                        folder: resp.folder,
                                        noteTitle: resp.notebook
                                    ))
                                    isPresented = false
                                }

                            // Refresh button
                            Button(action: refreshNextAnswer) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Refresh Note")
                                }
                                .font(.headline)
                            }
                            .accessibilityLabel("Refresh note")

                            // Feedback buttons
                            HStack(spacing: 20) {
                                feedbackButton(
                                    icon: "hand.thumbsup",
                                    filledIcon: "hand.thumbsup.fill",
                                    label: "Good Search",
                                    rating: 1,
                                    color: .green
                                )
                                feedbackButton(
                                    icon: "hand.thumbsdown",
                                    filledIcon: "hand.thumbsdown.fill",
                                    label: "Bad Search",
                                    rating: 0,
                                    color: .red
                                )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(UIColor.systemBackground).opacity(0.95))
                        )
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .accessibilityAddTraits(.isModal)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isSearchFieldFocused = true
                        UIAccessibility.post(notification: .layoutChanged, argument: nil)
                    }
                }
                // Voice recorder sheet
                .fullScreenCover(isPresented: $showingRecorder, onDismiss: handleVoiceQuery) {
                    RecordingView(isPresented: $showingRecorder)
                        .environmentObject(recordingStore)
                        .ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - Business Logic

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        feedbackGiven = false
        selectedFeedback = nil
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
        currentIndex += 1
        feedbackGiven = false
        selectedFeedback = nil
    }

    private func feedbackButton(icon: String,
                                filledIcon: String,
                                label: String,
                                rating: Int,
                                color: Color) -> some View {
        Button {
            selectedFeedback = rating
            feedbackGiven = true
            if let resp = currentAnswer {
                noteStore.submitFeedback(
                    question: query,
                    answer: resp.answer,
                    isPair: rating == 1
                )
            }
        } label: {
            HStack {
                Image(systemName: selectedFeedback == rating ? filledIcon : icon)
                Text(label)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .font(.headline)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .disabled(feedbackGiven)
        .opacity(feedbackGiven ? 0.5 : 1.0)
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
            .environmentObject(NavigationStackHandler.shared)  // ← supply nav here too
    }
}
#endif
