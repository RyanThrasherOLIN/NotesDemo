// SearchOverlay.swift
// NotesDemo

import SwiftUI
import UIKit  // for UIDevice

struct SearchOverlay: View {
    @Binding var isPresented: Bool

    @State private var query        = ""
    @State private var responseText = ""
    @State private var isLoading    = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }
                .accessibilityHidden(true)

            VStack(spacing: 20) {
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
        .accessibilityAddTraits(.isModal)
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
        responseText = ""
        defer { isLoading = false }

        do {
            let result = try await fetchAIResponse(question: trimmed)
            // Display as a single line without brackets
            await MainActor.run {
                responseText = result
            }
        } catch {
            await MainActor.run {
                responseText = "Error: \(error.localizedDescription)"
            }
        }
    }

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

        // Decode JSON response into a dictionary
        if let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }

        // Fallback to raw string
        return String(decoding: data, as: UTF8.self)
    }
}
