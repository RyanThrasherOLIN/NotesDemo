///
/// NoteStore.swift
/// NotesDemo
///
/// Manages fetching, adding, and organizing user notes by folder,
/// with server synchronization and local caching.
///
import Foundation
import UIKit    // for device identifier

// MARK: - Network Request & Response Models

/// Payload structure for adding a note on the server.
private struct AddNoteRequest: Codable {
    let device_id: String    // Unique user/device identifier
    let note: String         // Note title/text
    let folder: String       // Folder name
    let notebook: String     // Notebook name (same as title)
}

/// Representation of a note returned by the server.
private struct ServerNote: Codable {
    let folder: String       // Server-side folder name
    let id: String           // Server-generated identifier (unused locally)
    let note: String         // Note title/text
    let notebook: String     // Notebook name
}

/// Local model for a note within the app.
///
/// Conforms to `Identifiable` and `Hashable` for SwiftUI lists and navigation.
struct Note: Identifiable, Hashable {
    let id: UUID             // Unique local identifier
    let title: String        // Display title of the note
    var lines: [String]      // Individual lines (populated during sync)
}

/// Observable object that holds notes grouped by folder.
///
/// - Fetches initial notes from server exactly once per app run.
/// - Supports adding new notes both locally and remotely.
final class NoteStore: ObservableObject {
    // MARK: - Published State

    /// Dictionary mapping folder names to arrays of `Note` objects.
    /// Default folders: "Notes", "Work", "Personal".
    @Published var notesByFolder: [String: [Note]] = [
        "Notes": [],
        "Work": [],
        "Personal": []
    ]

    // MARK: - Private Configuration

    /// Unique persistent user/device ID stored in UserDefaults.
    /// Generated once and reused for server API calls.
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
    private let baseURL = "http://10.77.0.11:5000"

    /// Flag to ensure notes are fetched only once per session.
    private var hasFetchedNotes = false

    // MARK: - Public API Methods

    /// Fetches all user notes from the server once and updates `notesByFolder`.
    /// Subsequent calls will be no-ops.
    func fetchUserNotes() {
        // Prevent duplicate network calls
        guard !hasFetchedNotes else { return }
        hasFetchedNotes = true

        // Construct URL with query parameter
        guard var components = URLComponents(string: "\(baseURL)/get_user_notes") else {
            print("Invalid URLComponents for fetchUserNotes")
            return
        }
        components.queryItems = [
            URLQueryItem(name: "device_id", value: userID)
        ]
        guard let url = components.url else {
            print("Invalid URL for fetchUserNotes")
            return
        }

        print("Fetching notes for userID: \(userID)")
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("fetchUserNotes error: \(error)")
                return
            }
            guard let data = data else {
                print("fetchUserNotes: no data returned")
                return
            }
            do {
                // Decode server notes
                let serverNotes = try JSONDecoder().decode([ServerNote].self, from: data)
                print("fetchUserNotes: fetched \(serverNotes.count) notes")

                // Group notes by folder, resetting existing data
                var grouped: [String: [Note]] = [
                    "Notes": [],
                    "Work": [],
                    "Personal": []
                ]

                for s in serverNotes {
                    // Map "default" to "Notes" folder
                    let folderKey = s.folder.lowercased() == "default" ? "Notes" : s.folder
                    let note = Note(id: UUID(), title: s.note, lines: [])
                    grouped[folderKey, default: []].append(note)
                }

                // Update published state on main thread
                DispatchQueue.main.async {
                    self.notesByFolder = grouped
                }
            } catch {
                print("fetchUserNotes decode error: \(error)")
            }
        }
        .resume()
    }

    /// Adds a new note both locally (UI) and remotely (server API).
    ///
    /// - Parameters:
    ///   - title: The note title to add.
    ///   - folder: The target folder name.
    func addNote(title: String, to folder: String) {
        // 1) Local update for immediate UI feedback
        let newNote = Note(id: UUID(), title: title, lines: [])
        notesByFolder[folder, default: []].append(newNote)

        // 2) Prepare network request to add on server
        guard let url = URL(string: "\(baseURL)/add_note") else {
            print("Invalid URL for addNote")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create payload
        let payload = AddNoteRequest(
            device_id: userID,
            note:      title,
            folder:    folder,
            notebook:  title
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("addNote payload encoding failed: \(error)")
            return
        }

        // Fire-and-forget server API call
        URLSession.shared.dataTask(with: request).resume()
    }
}
