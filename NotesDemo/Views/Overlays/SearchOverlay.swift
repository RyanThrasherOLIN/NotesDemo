///
/// SearchOverlay.swift
/// NotesDemo
///
/// A modal overlay that allows users to enter a query, sends it to a backend AI service,
/// and displays the asynchronous response. The request URL is built from `Config.baseURL`,
/// which reads the user-editable `apiURL` setting.
///
/// - Dismissible by tapping outside or tapping the back button.
/// - Automatically focuses the search field when appearing.
/// - Shows a loading indicator while awaiting the response.
///
import SwiftUI
import UIKit  // for obtaining device identifier

/// Overlay view presenting a search field, loading indicator, and result display.
///
/// - Uses `Config.baseURL` to build the `/get_response` endpoint dynamically.
/// - Manages async network requests and error handling.
///
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

    /// Sends a POST request to the AI backend at `/get_response`,
    /// including the device ID and question, then decodes and returns
    /// the answer text.
    ///
    /// - Parameter question: The user-entered query string.
    /// - Throws: `URLError` or decoding errors on failure.
    /// - Returns: The response string from the server.
    private func fetchAIResponse(question: String) async throws -> String {
        // Build endpoint dynamically from user-editable API URL
        let endpoint = Config.baseURL.appendingPathComponent("get_response")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include device identifier for server-side tracking
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let body = ["device_id": deviceID, "question": question]
        request.httpBody = try JSONEncoder().encode(body)

        // Perform network call
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        // Try decoding { "response": "..."} or { "answer": "..."}
        if let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }

        // Fallback: return raw text
        return String(decoding: data, as: UTF8.self)
    }
}
