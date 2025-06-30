// File should be good now 

import SwiftUI

/// Modal that lets the user type (or soon, dictate) a question and shows the AI reply.
struct SearchOverlay: View {
    @Binding var isPresented: Bool

    @State private var query        = ""
    @State private var responseText = ""
    @State private var isLoading    = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        ZStack {
            // Blurred backdrop
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }      // dismiss on tap
                .accessibilityHidden(true)

            VStack(spacing: 20) {

                // ───── top bar ─────
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

                // ───── search bar ─────
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Ask your question…", text: $query)
                        .focused($isSearchFieldFocused)
                        .submitLabel(.go)
                        .onSubmit { Task { await performSearch() } }
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.horizontal)

                // ───── loader or result ─────
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
        .accessibilityAddTraits(.isModal)            // trap VoiceOver in the modal
        .onAppear {
            // auto-focus search field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFieldFocused = true
            }
        }
    }

    // MARK: – high-level helper
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        responseText = ""                            // clear old result
        defer { isLoading = false }

        do {
            // the streaming fetch updates responseText line-by-line
            _ = try await fetchAIResponseStreaming(question: trimmed)
        } catch {
            responseText = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: – streaming network call
    /// Reads the server’s reply line-by-line so we don’t get the “text pyramid”.
    private func fetchAIResponseStreaming(question: String) async throws -> String {
        let url = URL(string: "http://10.77.0.124:8000/get_response")!
        var req  = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["question": question])

        // bytes(for:) gives an AsyncSequence of the body as it arrives
        let (byteStream, _) = try await URLSession.shared.bytes(for: req)

        var accumulated = ""
        // `.lines` splits the stream by newlines, giving us full chunks
        for try await line in byteStream.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // update UI incrementally on the main thread
            await MainActor.run {
                responseText += trimmed + "\n"
            }
            accumulated += trimmed + "\n"
        }

        return accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
