//  NoteStore.swift
//  NotesDemo

import Foundation

struct Note: Identifiable, Hashable, Codable {
    let id = UUID()
    var title: String
    var lines: [String] = []
}

@MainActor
final class NoteStore: ObservableObject {
    // Folder → [Note]
    @Published var notesByFolder: [String: [Note]] = [
        "Notes": [],
        "Work":  [],
        "Personal": []
    ]

    // MARK: - Create a new (empty-body) note
    func addNote(title: String, to folder: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        notesByFolder[folder, default: []].append(Note(title: trimmed))
        Task { await sendSingleLine(trimmed) }            // still ping titles if you want
    }

    // MARK: - Append a line to a note + sync it
    func appendLine(_ line: String, to noteID: UUID, in folder: String) {
        guard var list = notesByFolder[folder] else { return }
        guard let idx = list.firstIndex(where: { $0.id == noteID }) else { return }

        list[idx].lines.append(line)
        notesByFolder[folder] = list                     // trigger @Published update
        Task { await sendSingleLine(line) }              // send to /get_response
    }

    // MARK: - One-time batch sync (all note bodies) on launch
    func syncAllNotesToServer() async {
        let allLines = notesByFolder.values
            .flatMap { $0 }
            .flatMap(\.lines)

        guard !allLines.isEmpty else { return }

        let url = URL(string: "http://10.77.0.124:8000/sync_database")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["notes": allLines])

        do { _ = try await URLSession.shared.data(for: req) }
        catch { print("Batch sync failed:", error.localizedDescription) }
    }

    // MARK: - PRIVATE helper to push one line
    private func sendSingleLine(_ text: String) async {
        let url = URL(string: "http://10.77.0.124:8000/get_response")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["question": text])
        _ = try? await URLSession.shared.data(for: req)
    }
}
