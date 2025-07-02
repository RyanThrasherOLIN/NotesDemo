///
/// SearchOverlay.swift
/// NotesDemo
///
/// A modal overlay that allows users to enter a query, sends it to a backend AI service,
/// and displays the asynchronous response. Designed for quick question-and-answer interactions.
///
import SwiftUI
import UIKit  // for obtaining device identifier

/// Overlay view presenting a search field, loading indicator, and result display.
///
/// - Dismissible by tapping outside or using the back button.
/// - Automatically focuses the search field on appear.
/// - Manages async network requests and error handling.
struct SearchOverlay: View {
    // MARK: - Presentation Binding
    /// Controls visibility of this overlay.
    @Binding var isPresented: Bool

    // MARK: - Search State
    /// The user's current query text.
    @State private var query = ""
    /// The AI service response text to display.
    @State private var responseText = ""
    /// Loading state while waiting for the response.
    @State private var isLoading = false
    /// Focus state for automatically focusing the text field.
    @FocusState private var isSearchFieldFocused: Bool

    // MARK: - View Body
    var body: some View {
        ZStack {
            // Dimmed, blurred background that dismisses on tap
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)

            VStack(spacing: 20) {
                // Top bar with back button
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
                // Account for safe area inset on top
                .padding(.top, UIApplication.shared.windows.first?.safeAreaInsets.top ?? 20)

                // Search input field
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Ask your question…", text: $query)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await performSearch() }
                        }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.horizontal)

                // Loading indicator or response display
                if isLoading {
                    ProgressView()
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
                }

                Spacer()
            }
        }
        .accessibilityAddTraits(.isModal)
        // Auto-focus the search field shortly after appearing
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFieldFocused = true
            }
        }
    }

    // MARK: - Networking Methods
    /// Trims the query and, if non-empty, sends it to the AI API,
    /// updating the UI with a loading state and the returned text.
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        responseText = ""
        defer { isLoading = false }

        do {
            let result = try await fetchAIResponse(question: trimmed)
            await MainActor.run {
                responseText = result
            }
        } catch {
            await MainActor.run {
                responseText = "Error: \(error.localizedDescription)"
            }
        }
    }

    /// Sends a POST request to the AI backend with device ID and question,
    /// decodes the response, and returns the answer text.
    /// - Parameter question: The user-entered query string.
    /// - Throws: URLError or decoding errors on failure.
    /// - Returns: The response string from the server.
    private func fetchAIResponse(question: String) async throws -> String {
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        guard let url = URL(string: "http://10.77.0.11:5000/get_response") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["device_id": deviceID, "question": question]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        // Attempt to decode standard JSON response
        if let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }

        // Fallback: return raw string data
        return String(decoding: data, as: UTF8.self)
    }
}
