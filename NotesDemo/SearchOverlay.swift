// File should be good now 

import SwiftUI

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

                // top bar 
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

                // search bar
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFieldFocused = true
            }
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        responseText = ""                            // clear old result
        defer { isLoading = false }

        do {
            _ = try await fetchAIResponseStreaming(question: trimmed)
        } catch {
            responseText = "Error: \(error.localizedDescription)"
        }
    }

    private func fetchAIResponseStreaming(question: String) async throws -> String {
        let url = URL(string: "http://10.77.0.124:8000/get_response")!
        var req  = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["question": question])

        let (byteStream, _) = try await URLSession.shared.bytes(for: req)

        var accumulated = ""
        for try await line in byteStream.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            await MainActor.run {
                responseText += trimmed + "\n"
            }
            accumulated += trimmed + "\n"
        }

        return accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
