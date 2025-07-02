///
/// HiddenLineStore.swift
/// NotesDemo
///
/// Manages line-by-line synchronization of note content with the backend API.
/// Reads the user-editable base URL from UserDefaults (“apiURL”).
///
import Foundation
import UIKit    // for UIDevice

// MARK: - API Helper

/// Common request payload for adding a single line to a note on the server.
private struct AddNoteRequest: Codable {
    let device_id: String   // Unique device identifier for the user
    let note: String        // The line of text to sync
    let folder: String      // Folder under which the note resides
    let notebook: String    // Notebook or note title
}

/// Simplified namespace for API calls used by the app.
/// Always reads the latest server URL from `Config.baseURL`.
enum NotesAPI {
    /// Dynamically read base URL from UserDefaults via `Config`.
    static var base: URL { Config.baseURL }

    /// Sends a simple GET to the base URL to check connectivity.
    static func ping() async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: base)
        return String(decoding: data, as: UTF8.self)
    }

    /// Sends a single line note to the `/add_note` endpoint.
    ///
    /// - Parameters:
    ///   - note: The text line to upload.
    ///   - folder: Folder name for context.
    ///   - notebook: Notebook (noteTitle) for context.
    static func addNote(
        _ note: String,
        folder: String,
        notebook: String
    ) async throws {
        let url = base.appendingPathComponent("add_note")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddNoteRequest(
            device_id: UIDevice.current.identifierForVendor!.uuidString,
            note: note,
            folder: folder,
            notebook: notebook
        )
        req.httpBody = try JSONEncoder().encode(payload)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode,
              200..<300 ~= code else {
            throw URLError(.badServerResponse)
        }
    }

    /// Sends a question to the `/get_response` endpoint and returns the answer.
    ///
    /// - Parameter question: The query string to send.
    static func getResponse(to question: String) async throws -> String {
        let url = base.appendingPathComponent("get_response")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["question": question])

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode,
              200..<300 ~= code else {
            throw URLError(.badServerResponse)
        }

        // Decode JSON {"response": "..."} or {"answer": "..."}
        if let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - HiddenLineStore

/// Observable store that syncs new note lines to the server and tracks synced lines.
///
/// - Filters out duplicates by maintaining a set of already-synced lines.
/// - Performs network calls on background tasks, then updates `syncedLines` on the main thread.
final class HiddenLineStore: ObservableObject {
    /// Set of lines already synced to avoid duplicate uploads.
    @Published private(set) var syncedLines = Set<String>()

    /// Compares provided `allLines` against previously synced lines,
    /// sends any new lines to the server, and updates the sync tracking.
    ///
    /// - Parameters:
    ///   - allLines: Full array of note lines (including previous lines).
    ///   - folder: Folder name for API context.
    ///   - notebook: Note title for API context.
    func sync(
        _ allLines: [String],
        folder: String,
        notebook: String
    ) {
        let newLines = Set(allLines).subtracting(syncedLines)
        guard !newLines.isEmpty else { return }

        Task {
            for line in newLines {
                do {
                    try await NotesAPI.addNote(
                        line,
                        folder: folder,
                        notebook: notebook
                    )
                } catch {
                    print("Failed to add “\(line)”: \(error)")
                }
            }
            DispatchQueue.main.async {
                self.syncedLines.formUnion(newLines)
            }
        }
    }
}
