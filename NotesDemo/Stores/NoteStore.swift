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

/// Local model for a notebook containing multiple lines.
struct NoteBook: Identifiable, Hashable, Comparable {
    let id: UUID
    let title: String        // Display title of the notebook
    var notes: [Note]        // Individual lines
    static func < (lhs: NoteBook, rhs: NoteBook) -> Bool {
        return lhs.title < rhs.title
    }
}

struct Note: Identifiable, Hashable {
    let id: String
    var text: String
}

/// Manages fetching, adding, and organizing user notes by folder.
final class NoteStore: ObservableObject {
    @Published var notesByFolder: [String: [String: NoteBook]] = [
        "Notes": [:],
        "Work": [:],
        "Personal": [:]
    ]

    private var userID: String {
        UIDevice.current.identifierForVendor!.uuidString
    }

    private var baseURL: URL {
        let defaultURL = "http://10.77.0.11:5000"
        let urlString = UserDefaults.standard.string(forKey: "apiURL") ?? defaultURL
        guard let url = URL(string: urlString) else {
            fatalError("Invalid `apiURL` in UserDefaults: \(urlString)")
        }
        return url
    }

    private var hasFetchedNotes = false

    /// Fetches all user notes once per launch, but ignores entries where note equals notebook (i.e. skip notebook titles).
    func fetchUserNotes() {
        guard !hasFetchedNotes else { return }
        hasFetchedNotes = true

        let endpoint = baseURL.appendingPathComponent("get_user_notes")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [ URLQueryItem(name: "device_id", value: userID) ]
        guard let url = components?.url else {
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
                // Decode and filter out any server notes where note == notebook
                let serverNotes = try JSONDecoder().decode([ServerNote].self, from: data)
                let filtered = serverNotes.filter { $0.note != $0.notebook }
                DispatchQueue.main.async {
                    print("fetchUserNotes: fetched \(filtered.count) notes (excluding notebook titles)")
                    for s in filtered {
                        let key = s.folder.lowercased() == "default" ? "Notes" : s.folder
                        if var folderNotes = self.notesByFolder[key] {
                            if var notebook = folderNotes[s.notebook] {
                                notebook.notes.append(Note(id: s.id, text: s.note))
                                self.notesByFolder[key]![s.notebook] = notebook
                            } else {
                                folderNotes[s.notebook] = NoteBook(id: UUID(), title: s.notebook, notes: [Note]())
                                self.notesByFolder[key] = folderNotes
                            }
                        } else {
                            let newNotebook = NoteBook(id: UUID(), title: s.notebook, notes: [Note]())
                            self.notesByFolder[key] = [s.notebook: newNotebook]
                        }
                    }
                }
            } catch {
                print("fetchUserNotes decode error:", error)
            }
        }.resume()
    }

    /// Adds a new notebook locally (no initial note).
    func addNoteBook(title: String, to folder: String) {
        let newBook = NoteBook(id: UUID(), title: title, notes: [])
        if var folderNotes = notesByFolder[folder] {
            folderNotes[title] = newBook
            notesByFolder[folder] = folderNotes
        } else {
            notesByFolder[folder] = [title: newBook]
        }
        // TODO: call a dedicated /add_notebook endpoint when server supports it
    }

    /// Adds a new note line to a notebook.
    func addNote(_ note: String, title: String, folder: String) {
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
        do { request.httpBody = try JSONEncoder().encode(payload) } catch {
            print("addNote payload encoding failed:", error)
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("addNote error:", error)
                return
            }
            guard let data = data,
                  let returned = try? JSONDecoder().decode([String:String].self, from: data),
                  let serverID = returned["id"]
            else {
                print("addNote: unexpected response")
                return
            }
            DispatchQueue.main.async {
                if var folderNotes = self.notesByFolder[folder],
                   var notebook = folderNotes[title] {
                    notebook.notes.append(Note(id: serverID, text: note))
                    self.notesByFolder[folder]![title] = notebook
                }
            }
        }.resume()
    }

    /// Updates an existing note.
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
        do { request.httpBody = try JSONEncoder().encode(payload) } catch {
            print("syncSingleMessage payload encoding failed:", error)
            return
        }

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("syncSingleMessage error:", error)
                return
            }
            DispatchQueue.main.async {
                if var folderNotes = self.notesByFolder[folder],
                   var book = folderNotes[notebook] {
                    if let idx = book.notes.firstIndex(where: { $0.id == id }) {
                        book.notes[idx].text = text
                        self.notesByFolder[folder]![notebook] = book
                    }
                }
            }
        }.resume()
    }
}
