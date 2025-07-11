import SwiftUI
import UIKit  // for UIAccessibility

struct SearchOverlay: View {
    // MARK: - Presentation Binding
    @Binding var isPresented: Bool

    // MARK: - Injected Stores
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore

    // MARK: - Configuration
    private let kResults = 5

    // MARK: - Search State
    @State private var query: String = ""
    @State private var answers: [String] = []
    @State private var currentIndex: Int = 0
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false
    @State private var showingRecorder: Bool = false

    // MARK: - Feedback State
    @State private var feedbackGiven: Bool = false
    @State private var selectedFeedback: Int? = nil

    // MARK: - Focus
    @FocusState private var isSearchFieldFocused: Bool
    @AccessibilityFocusState private var isResultFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Dimmed, blurred background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .accessibilityHidden(true)

                VStack(spacing: 20) {
                    // Top bar with back button
                    HStack {
                        Button { isPresented = false } label: {
                            Image(systemName: "chevron.backward")
                                .font(.title2)
                                .padding(8)
                        }
                        .accessibilityLabel("Close search")
                        Spacer()
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 20)

                    // Search field with enhanced contrast
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
                        .accessibilityHint("Tap to record and transcribe your question")
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

                    // Results or loading indicator
                    if isLoading {
                        ProgressView()
                            .accessibilityLabel("Loading")
                    } else if !responseText.isEmpty {
                        List {
                            VStack(alignment: .leading, spacing: 12) {
                                // Result text
                                Text(responseText)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(UIColor.systemGray6))
                                    )
                                    .accessibilityLabel("Search result")
                                    .accessibilityValue(responseText)
                                    .accessibilityFocused($isResultFocused)
                                    .onTapGesture { /* no-op */ }

                                // Refresh button
                                Button(action: refreshNextAnswer) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.headline)
                                        Text("Refresh Note")
                                            .font(.headline)
                                    }
                                }
                                .accessibilityLabel("Refresh note")
                                .accessibilityHint("Load the next relevant result")
                                .tint(.blue)

                                // Feedback buttons
                                HStack(spacing: 30) {
                                    feedbackButton(
                                        icon: "hand.thumbsup",
                                        filledIcon: "hand.thumbsup.fill",
                                        label: "Thumbs Up",
                                        rating: 1,
                                        color: .green
                                    )
                                    feedbackButton(
                                        icon: "hand.thumbsdown",
                                        filledIcon: "hand.thumbsdown.fill",
                                        label: "Thumbs Down",
                                        rating: 0,
                                        color: .red
                                    )
                                }
                                .padding(.top, 20)
                            }
                            .padding(.vertical, 8)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                        .frame(maxHeight: 300)
                        .accessibilityElement(children: .contain)
                    }

                    Spacer()
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isSearchFieldFocused = true
                        UIAccessibility.post(notification: .layoutChanged, argument: nil)
                    }
                }
                // Voice recorder cover
                .fullScreenCover(isPresented: $showingRecorder, onDismiss: handleVoiceQuery) {
                    RecordingView(isPresented: $showingRecorder)
                        .environmentObject(recordingStore)
                        .ignoresSafeArea()
                }
            }
        }
    }

    // MARK: - Search & Refresh Logic
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        feedbackGiven = false
        selectedFeedback = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await noteStore.fetchTopNotes(question: trimmed, k: kResults)
            await MainActor.run {
                answers = fetched
                currentIndex = 0
                responseText = fetched.first ?? "No results found."
                isResultFocused = true
            }
        } catch {
            await MainActor.run {
                responseText = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func refreshNextAnswer() {
        guard currentIndex + 1 < answers.count else { return }
        feedbackGiven = false
        selectedFeedback = nil
        currentIndex += 1
        responseText = answers[currentIndex]
    }

    // MARK: - Feedback Integration
    private func submitFeedback(_ rating: Int) {
        let isPair = (rating == 1)
        noteStore.submitFeedback(question: query, answer: responseText, isPair: isPair)
        print("Feedback request sent → username: \(UserDefaults.standard.string(forKey: "username") ?? "[none]"), question: \"\(query)\", answer: \"\(responseText)\", is_pair: \(isPair)")
    }

    private func feedbackButton(icon: String, filledIcon: String, label: String, rating: Int, color: Color) -> some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedFeedback = rating
                feedbackGiven = true
            }
            submitFeedback(rating)
        }) {
            HStack {
                Image(systemName: selectedFeedback == rating ? filledIcon : icon)
                    .font(.headline)
                Text(label)
                    .font(.headline)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .scaleEffect(selectedFeedback == rating ? 1.2 : 1.0)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .disabled(feedbackGiven)
        .opacity(feedbackGiven ? 0.5 : 1.0)
        .accessibilityLabel(label)
        .accessibilityHint("Send \(label.lowercased()) feedback")
    }

    // MARK: - Voice Handling
    private func handleVoiceQuery() {
        guard let rec = recordingStore.recordings.first else { return }
        Task {
            if let text = await recordingStore.speechToText(rec) {
                await MainActor.run {
                    query = text
                    isSearchFieldFocused = true
                }
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
    }
}
#endif
