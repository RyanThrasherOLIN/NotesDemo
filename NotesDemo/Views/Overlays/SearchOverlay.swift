import SwiftUI
import UIKit  // for UIAccessibility

struct SearchOverlay: View {
    // MARK: - Presentation Binding
    @Binding var isPresented: Bool

    // MARK: - Search State
    @State private var query: String = ""
    @State private var responseText: String = ""
    @State private var isLoading: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @AccessibilityFocusState private var isResultFocused: Bool  // For VoiceOver focus

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
                    // Display result bubble with refresh button
                    List {
                        ForEach([responseText], id: \.self) { resp in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(resp)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(UIColor.systemGray5))
                                    )
                                    .accessibilityLabel("Search result")
                                    .accessibilityValue(resp)
                                    .accessibilityFocused($isResultFocused)

                                Button(action: {
                                    print("Note bad, refreshing note")
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.headline)
                                        Text("Refresh Note")
                                            .font(.headline)
                                    }
                                }
                                .accessibilityLabel("Refresh note")
                                .accessibilityHint("Press to get a new note")
                                .tint(.blue)
                            }
                            .padding(.vertical, 8)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
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
            // Focus search field on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isSearchFieldFocused = true
                UIAccessibility.post(notification: .layoutChanged, argument: nil)
            }
        }
    }

    // MARK: - Networking
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
                // Move VoiceOver focus to the result text
                isResultFocused = true
            }
        } catch {
            await MainActor.run { responseText = "Error: \(error.localizedDescription)" }
        }
    }

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

        if let dict = try? JSONDecoder().decode([String:String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }
}

#if DEBUG
struct SearchOverlay_Previews: PreviewProvider {
    static var previews: some View {
        SearchOverlay(isPresented: .constant(true))
    }
}
#endif
