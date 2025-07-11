// SearchOverlay.swift

import SwiftUI
import UIKit  // for UIAccessibility

struct SearchOverlay: View {
    // MARK: - Presentation Binding
    @Binding var isPresented: Bool

    // MARK: - Injected Stores
    @EnvironmentObject private var noteStore: NoteStore

    // MARK: - Configuration
    private let kResults = 5

    // MARK: - Search State
    @State private var query: String = ""
    @State private var answers: [String] = []
    @State private var currentIndex: Int = 0
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false

    // MARK: - Focus
    @FocusState private var isSearchFieldFocused: Bool
    @AccessibilityFocusState private var isResultFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                // Top bar
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

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Ask your question…", text: $query)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.go)
                        .onSubmit { Task { await performSearch() } }
                        .accessibilityLabel("Search field")
                        .accessibilityHint("Type your question and press Go")
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
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
                                        .fill(Color(UIColor.systemGray5))
                                )
                                .accessibilityLabel("Search result")
                                .accessibilityValue(responseText)
                                .accessibilityFocused($isResultFocused)

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
                                // Thumbs Up (green)
                                Button(action: {
                                    submitFeedback(1)
                                }) {
                                    HStack {
                                        Image(systemName: "hand.thumbsup")
                                            .font(.headline)
                                        Text("Thumbs Up")
                                            .font(.headline)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .accessibilityLabel("Thumbs up")
                                .accessibilityHint("Send positive feedback")

                                // Thumbs Down (red)
                                Button(action: {
                                    submitFeedback(0)
                                }) {
                                    HStack {
                                        Image(systemName: "hand.thumbsdown")
                                            .font(.headline)
                                        Text("Thumbs Down")
                                            .font(.headline)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .accessibilityLabel("Thumbs down")
                                .accessibilityHint("Send negative feedback")
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
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isSearchFieldFocused = true
                UIAccessibility.post(notification: .layoutChanged, argument: nil)
            }
        }
    }

    // MARK: - Search & Refresh Logic
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await noteStore.fetchTopNotes(
                question: trimmed,
                k: kResults
            )
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
        currentIndex += 1
        responseText = answers[currentIndex]
    }

    // MARK: - Feedback Integration
    private func submitFeedback(_ rating: Int) {
        let isPair = rating == 1
        noteStore.submitFeedback(
            question: query,
            answer: responseText,
            isPair: isPair
        )
        // console confirmation
        print("Feedback request sent → username: \(UserDefaults.standard.string(forKey: "username") ?? "[none]"), question: \"\(query)\", answer: \"\(responseText)\", is_pair: \(isPair)")
    }
}

#if DEBUG
struct SearchOverlay_Previews: PreviewProvider {
    static var previews: some View {
        SearchOverlay(isPresented: .constant(true))
            .environmentObject(NoteStore())
    }
}
#endif
