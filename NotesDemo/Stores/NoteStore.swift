///
/// NoteStore.swift
/// NotesDemo
///
/// Manages fetching, adding, and organizing user notes by folder,
/// with server synchronization and local caching.
/// Uses a user-editable API base URL (stored under “apiURL” in UserDefaults).
///
import Foundation
import UIKit    // for UIDevice
                        
// MARK: - Network Request & Response Models

/// Payload sent to POST /add_note on the server.
private struct AddNoteRequest: Codable {
    let device_id: String    // Unique user/device identifier
    let note: String         // Note title/text
    let folder: String       // Folder name on server
    let notebook: String     // Notebook name (same as title)
}

/// Representation of a note returned by GET /get_user_notes.
private struct ServerNote: Codable {
    let folder: String       // Server-side folder name
    let id: String           // Server-generated identifier (unused locally)
    let note: String         // Note title/text
    let notebook: String     // Notebook name
}

/// Local model for a note within the app.
/// Conforms to `Identifiable` and `Hashable` for SwiftUI lists/navigation.
struct Note: Identifiable, Hashable {
    let id: UUID             // Unique local identifier
    let title: String        // Display title of the note
    var lines: [String]      // Individual lines (populated by sync)
}

/// Observable object that holds notes grouped by folder.
///
/// - Fetches initial notes from server exactly once per app run.
/// - Supports adding new notes both locally and remotely.
///
final class NoteStore: ObservableObject {
    // MARK: - Published State

    /// Maps folder names ("Notes", "Work", "Personal") to arrays of `Note`.
    @Published var notesByFolder: [String: [Note]] = [
        "Notes": [],
        "Work": [],
        "Personal": []
    ]

    // MARK: - Private Configuration

    /// Unique persistent user/device ID stored in UserDefaults.
    /// Generated once and reused for all server API calls.
    private let userID: String = {
        let key = "userID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }()

    /// Base URL for the backend API.
    /// Reads the user-editable “apiURL” key; falls back to default if unset.
    private var baseURL: URL {
        let defaultURL = "http://10.77.0.11:5000"
        let urlString = UserDefaults.standard.string(forKey: "apiURL") ?? defaultURL
        guard let url = URL(string: urlString) else {
            fatalError("Invalid `apiURL` in UserDefaults: \(urlString)")
        }
        return url
    }

    /// Ensures `fetchUserNotes` runs only once per app launch.
    private var hasFetchedNotes = false

    // MARK: - Public API Methods

    /// Fetches all user notes from the server once and updates `notesByFolder`.
    /// Subsequent calls in the same session are ignored.
    func fetchUserNotes() {
        guard !hasFetchedNotes else { return }
        hasFetchedNotes = true

        // Build URL: GET baseURL/get_user_notes?device_id=…
        let endpoint = baseURL.appendingPathComponent("get_user_notes")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            print("Invalid URLComponents for fetchUserNotes")
            return
        }
        components.queryItems = [ URLQueryItem(name: "device_id", value: userID) ]
        guard let url = components.url else {
            print("Invalid URL for fetchUserNotes")
            return
        }

        print("Fetching notes for userID: \(userID)")
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("fetchUserNotes error:", error)
                return
            }
            guard let data = data else {
                print("fetchUserNotes: no data returned")
                return
            }
            do {
                // Decode server response
                let serverNotes = try JSONDecoder().decode([ServerNote].self, from: data)
                print("fetchUserNotes: fetched \(serverNotes.count) notes")

                // Group into our local folders
                var grouped: [String: [Note]] = [
                    "Notes": [], "Work": [], "Personal": []
                ]
                for s in serverNotes {
                    let key = s.folder.lowercased() == "default" ? "Notes" : s.folder
                    let note = Note(id: UUID(), title: s.note, lines: [])
                    grouped[key, default: []].append(note)
                }

                DispatchQueue.main.async {
                    self.notesByFolder = grouped
                }
            } catch {
                print("fetchUserNotes decode error:", error)
            }
        }
        .resume()
    }

    /// Adds a new note locally and on the server.
    ///
    /// - Parameters:
    ///   - title: The note title to add.
    ///   - folder: The target folder name.
    func addNote(title: String, to folder: String) {
        // 1) Local update for immediate UI feedback
        let newNote = Note(id: UUID(), title: title, lines: [])
        notesByFolder[folder, default: []].append(newNote)

        // 2) Network request to persist on server
        let url = baseURL.appendingPathComponent("add_note")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddNoteRequest(
            device_id: userID,
            note:      title,
            folder:    folder,
            notebook:  title
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("addNote payload encoding failed:", error)
            return
        }

        URLSession.shared.dataTask(with: request).resume()
    }
}
