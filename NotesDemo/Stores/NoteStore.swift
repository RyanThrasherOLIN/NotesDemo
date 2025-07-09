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
struct NoteBook: Identifiable, Hashable, Comparable {
    let id: UUID             // Unique local identifier
    let title: String        // Display title of the note
    var notes: [Note]      // Individual lines (populated by sync)
    static func < (lhs: NoteBook, rhs: NoteBook) -> Bool {
        return lhs.title < rhs.title // Sort by title in alphabetical order
    }
}

struct Note: Identifiable, Hashable {
    let id: String
    var text: String
}

/// Observable object that holds notes grouped by folder.
///
/// - Fetches initial notes from server exactly once per app run.
/// - Supports adding new notes both locally and remotely.
///
final class NoteStore: ObservableObject {
    // MARK: - Published State

    /// Maps folder names ("Notes", "Work", "Personal") to arrays of `Note`.
    @Published var notesByFolder: [String: [String: NoteBook]] = [
        "Notes": [:],
        "Work": [:],
        "Personal": [:]
    ]

    // MARK: - Private Configuration

    /// Unique persistent user/device ID stored in UserDefaults.
    /// Generated once and reused for all server API calls.
    private var userID: String {
        // TODO: replace with a real user ID provided by Firebase authentication (if we use Apple sign-in we can share notes automatically)
        return UIDevice.current.identifierForVendor!.uuidString
    }

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
                DispatchQueue.main.async {
                    print("fetchUserNotes: fetched \(serverNotes.count) notes")
                    for s in serverNotes {
                        let key = s.folder.lowercased() == "default" ? "Notes" : s.folder
                        if var folderNotes = self.notesByFolder[key] {
                            if var notebook = folderNotes[s.notebook] {
                                print("adding a new note to a notebook \(s.note)")
                                notebook.notes.append(Note(id: s.id, text: s.note))
                                self.notesByFolder[key]![s.notebook] = notebook
                            } else {
                                print("adding a new notebook to a folder \(s.notebook)")
                                folderNotes[s.notebook] = NoteBook(id: UUID(), title: s.notebook, notes: [])
                                self.notesByFolder[key] = folderNotes
                            }
                        } else {
                            print("adding a new dictionary for a folder \(s.folder)")
                            self.notesByFolder[key] = [s.notebook: NoteBook(id: UUID(), title: s.notebook, notes: [])]
                        }
                    }
                }
            } catch {
                print("fetchUserNotes decode error:", error)
            }
        }
        .resume()
    }

    /// Adds a new notebook locally and on the server.
    ///
    /// - Parameters:
    ///   - title: The notebook title to add.
    ///   - folder: The target folder name.
    func addNoteBook(title: String, to folder: String) {
        // 1) Local update for immediate UI feedback
        let newNote = NoteBook(id: UUID(), title: title, notes: [])
        if var folderNotes = notesByFolder[folder] {
            folderNotes[title] = newNote
        } else {
            notesByFolder[folder] = [title: newNote]
        }
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
        
        // TODO: if we can get a server ID for notebook title, that would be good since it would let us edit the name eventually

        // TODO: make sure to check for errors
        URLSession.shared.dataTask(with: request).resume()
    }
    
    /// Adds a new note locally and on the server.
    ///
    /// - Parameters:
    ///   - note: the text of the note.
    ///   - title: The notebook title to add the note to.
    ///   - folder: The target folder name.
    func addNote(_ note: String, title: String, folder: String) {
        // 2) Network request to persist on server
        let url = baseURL.appendingPathComponent("add_note")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddNoteRequest(
            device_id: userID,
            note:      note,
            folder:    folder,
            notebook:  title
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("addNote payload encoding failed:", error)
            return
        }
        
        // TODO: make sure to check for errors
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("fetchUserNotes error:", error)
                return
            }
            guard let data = data else {
                print("addNote: no data returned")
                return
            }
            // TODO: parse the ID from the server and update note (when it is sent back) (e.g., let serverID = data["server_id"]
            guard let folderNotes = self.notesByFolder[folder], var notebook = folderNotes[title] else {
                print("unexpectedly didn't find notebook in local model")
                return
            }
            // TODO: id should be replaced by server ID
            notebook.notes.append(Note(id: UUID().uuidString, text: note))
            DispatchQueue.main.async {
                self.notesByFolder[folder]![title] = notebook
            }
        }.resume()
    }
    
    /// Upserts a message: if it exists, sends an update; otherwise posts and swaps the temp ID
    func syncSingleMessage(id: String, text: String, folder: String, notebook: String) {
        let url = baseURL.appendingPathComponent("update_note")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = [
            "device_id": userID,
            "note_id": id,
            "note": text
        ]
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("addNote payload encoding failed:", error)
            return
        }
        
        // TODO: make sure to check for errors
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("syncSingleMessage error:", error)
                return
            }
            guard let folderNotes = self.notesByFolder[folder], var noteBook = folderNotes[notebook] else {
                return
            }
            for (index, note) in noteBook.notes.enumerated() {
                if note.id == id {
                    noteBook.notes[index].text = text
                    break
                }
            }
            DispatchQueue.main.async {
                self.notesByFolder[folder]![notebook] = noteBook
            }
        }.resume()
    }
}
