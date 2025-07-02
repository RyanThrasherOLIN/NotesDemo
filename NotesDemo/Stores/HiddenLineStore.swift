///
/// HiddenLineStore.swift
/// NotesDemo
///
/// Manages line-by-line synchronization of note content with the backend API.
/// Tracks which lines have already been sent to avoid duplicates.
///
import Foundation
import UIKit    // for UIDevice

// MARK: - API Helper

/// Common request payload for adding a note line to the server.
private struct AddNoteRequest: Codable {
    let device_id: String   // Unique device identifier for the user
    let note: String        // The line of text to sync
    let folder: String      // The folder under which the note resides
    let notebook: String    // The notebook or note title
}

/// Simplified namespace for API calls used by the app.
enum NotesAPI {
    /// Base URL for the backend server.
    static let base = URL(string: "http://10.77.0.11:5000")!

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

        // Build payload with device ID
        let payload = AddNoteRequest(
            device_id: UIDevice.current.identifierForVendor!.uuidString,
            note: note,
            folder: folder,
            notebook: notebook
        )
        req.httpBody = try JSONEncoder().encode(payload)

        // Perform request and verify status code
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode,
              200..<300 ~= code else {
            throw URLError(.badServerResponse)
        }
    }

    /// Sends a question to the `/get_response` endpoint and returns the answer.
    /// - Parameter question: The query string.
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

        // Attempt JSON decode to dictionary for "response" or "answer"
        if let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }
        // Fallback to raw string
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - HiddenLineStore

/// Observable store that syncs new note lines to the server and tracks synced lines.
final class HiddenLineStore: ObservableObject {
    /// Set of lines already synced to avoid duplicate uploads.
    @Published private(set) var syncedLines = Set<String>()

    /// Compares provided lines against previously synced lines,
    /// sends any new lines to the server, and updates the sync tracking.
    ///
    /// - Parameters:
    ///   - allLines: Array of full note lines.
    ///   - folder: Folder name for context in API.
    ///   - notebook: Note title for context in API.
    func sync(
        _ allLines: [String],
        folder: String,
        notebook: String
    ) {
        // Determine which lines haven't been synced yet
        let newLines = Set(allLines).subtracting(syncedLines)
        guard !newLines.isEmpty else { return }

        Task {
            // Send each new line asynchronously
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
            // Merge newly synced lines into the published set
            DispatchQueue.main.async {
                self.syncedLines.formUnion(newLines)
            }
        }
    }
}
