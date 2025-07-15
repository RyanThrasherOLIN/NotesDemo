// SearchOverlay.swift

import SwiftUI
import UIKit

struct SearchOverlay: View {
    // MARK: - Presentation
    @Binding var isPresented: Bool

    // MARK: - Environment
    @EnvironmentObject private var noteStore: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var nav: NavigationStackHandler

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
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
                    .accessibilityHidden(true)

                VStack(spacing: 20) {
                    header
                    searchField
                    results()
                    Spacer()
                }
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isSearchFieldFocused = true
                        UIAccessibility.post(notification: .screenChanged,
                                             argument: nil)
                    }
                }
                .fullScreenCover(isPresented: $showingRecorder,
                                 onDismiss: handleVoiceQuery) {
                    RecordingView(isPresented: $showingRecorder)
                        .environmentObject(recordingStore)
                        .ignoresSafeArea()
                }
            }
        }
    }

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
        .padding(.horizontal, 30)
        .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 20)
    }

    private var searchField: some View {
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
    }

    @ViewBuilder
    private func results() -> some View {
        if isLoading {
            ProgressView()
                .accessibilityLabel("Loading results")
        } else if let resp = currentAnswer {
            VStack(alignment: .leading, spacing: 20) {
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
                        // Highlight the tapped note
                        noteStore.highlightedNoteID = resp.id
                        nav.pushView(.noteDetail(
                            folder: resp.folder,
                            noteTitle: resp.notebook
                        ))
                        isPresented = false
                    }

                Button(action: refreshNextAnswer) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Note")
                    }
                    .font(.headline)
                }
                .accessibilityLabel("Refresh note")

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

                HStack(spacing: 20) {
                    Button("New Question") {
                        query = ""
                        answers = []
                        currentIndex = 0
                        isLoading = false
                        isSearchFieldFocused = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            UIAccessibility.post(notification: .layoutChanged,
                                                 argument: nil)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.headline)
                    .accessibilityLabel("Type a new question")

                    Button("Close") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.headline)
                    .accessibilityLabel("Close search overlay")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground).opacity(0.95))
            )
            .padding(.horizontal)
        }
    }

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isResultFocused = true
                UIAccessibility.post(notification: .layoutChanged, argument: nil)
            }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isResultFocused = true
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        }
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
                noteStore.submitFeedback(question: query, answer: resp.answer, isPair: rating == 1)
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
            .environmentObject(NavigationStackHandler.shared)
    }
}
#endif
