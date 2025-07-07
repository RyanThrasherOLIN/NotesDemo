///
/// SearchOverlay.swift
/// NotesDemo
///
/// A true modal overlay that lets users enter a query, sends it to a backend AI service,
/// and displays the async response.
/// Hides all background content from VoiceOver and moves focus to the search field.
///
/// - Dismissible by tapping outside or tapping the back button.
/// - Automatically focuses and announces the search field on appear.
/// - Treats itself as a modal to block underlying UI for accessibility.
///
import SwiftUI
import UIKit  // for UIAccessibility

struct SearchOverlay: View {
    // MARK: - Presentation Binding

    /// Controls whether this overlay is shown.
    @Binding var isPresented: Bool

    // MARK: - Search State

    /// The user's current search query.
    @State private var query: String = ""
    /// The AI response text.
    @State private var responseText: String = ""
    /// Whether a request is in progress.
    @State private var isLoading: Bool = false
    /// Focus binding for the TextField.
    @FocusState private var isSearchFieldFocused: Bool

    // MARK: - View Body

    var body: some View {
        ZStack {
            // MARK: Background
            // Dimmed, blurred tap‐to‐dismiss background, hidden from VoiceOver
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)

            // MARK: Main Container
            VStack(spacing: 20) {
                // Top bar with Close button
                HStack {
                    Button {
                        isPresented = false
                    } label: {
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

                // Loading indicator or results
                if isLoading {
                    ProgressView()
                        .accessibilityLabel("Loading")
                } else if !responseText.isEmpty {
                    ScrollView {
                        Text(responseText)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                    .background(.thickMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .accessibilityLabel("Search results")
                }

                Spacer()
            }
            // Treat the VStack as one modal accessibility element
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
        // On appear, focus the search field and notify VoiceOver
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isSearchFieldFocused = true
                UIAccessibility.post(notification: .layoutChanged, argument: nil)
            }
        }
    }

    // MARK: - Networking

    /// Performs the search: trims input, shows loading, calls the API, then updates UI.
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        responseText = ""
        defer { isLoading = false }

        do {
            let result = try await fetchAIResponse(question: trimmed)
            await MainActor.run { responseText = result }
        } catch {
            await MainActor.run { responseText = "Error: \(error.localizedDescription)" }
        }
    }

    /// Sends a POST to `/get_response` with `device_id` and `question`, returns the answer.
    private func fetchAIResponse(question: String) async throws -> String {
        let endpoint = Config.baseURL.appendingPathComponent("get_response")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let body = ["device_id": deviceID, "question": question]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
            throw URLError(.badServerResponse)
        }

        // Try decoding JSON {"response":...} or {"answer":...}
        if let dict = try? JSONDecoder().decode([String:String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }
        // Fallback to raw string
        return String(decoding: data, as: UTF8.self)
    }
}
