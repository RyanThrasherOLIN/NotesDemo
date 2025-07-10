// NoteStore.swift
// NoteStore.swift

import Foundation
import UIKit    // for UIDevice

// MARK: - Network Request & Response Models

/// Payload sent to POST /add_note on the server.
private struct AddNoteRequest: Codable {
    let device_id: String
    let note: String
    let folder: String
    let notebook: String
}

/// Payload sent to POST /get_response when requesting top-K answers.
private struct GetResponseRequest: Codable {
    let device_id: String
    let question: String
    let k: String
}

/// Representation of a note returned by GET /get_user_notes.
private struct ServerNote: Codable {
    let folder: String
    let id: String
    let note: String
    let notebook: String
}

/// Local model for a notebook containing multiple lines.
struct NoteBook: Identifiable, Hashable, Comparable {
    let id: UUID
    let title: String
    var notes: [Note]
    static func < (lhs: NoteBook, rhs: NoteBook) -> Bool {
        lhs.title < rhs.title
    }
}

struct Note: Identifiable, Hashable {
    let id: String
    var text: String
}

/// Manages fetching, adding, deleting, and organizing user notes by folder.
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
        let defaultURL = "http://165.1.68.217:5000"
        let urlString = UserDefaults.standard.string(forKey: "apiURL") ?? defaultURL
        guard let url = URL(string: urlString) else {
            fatalError("Invalid `apiURL` in UserDefaults: \(urlString)")
        }
        return url
    }

    private var hasFetchedNotes = false

    /// Fetches all user notes once per launch, skipping entries where note == notebook title.
    func fetchUserNotes() {
        guard !hasFetchedNotes else { return }
        hasFetchedNotes = true

        let endpoint = baseURL.appendingPathComponent("get_user_notes")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "device_id", value: userID)]
        guard let url = components?.url else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("fetchUserNotes error: ", error)
                return
            }
            guard let data = data else { return }
            do {
                let serverNotes = try JSONDecoder().decode([ServerNote].self, from: data)
                let filtered = serverNotes.filter { $0.note != $0.notebook }
                DispatchQueue.main.async {
                    for s in filtered {
                        let key = s.folder.lowercased() == "default" ? "Notes" : s.folder
                        if var folderNotes = self.notesByFolder[key] {
                            if var notebook = folderNotes[s.notebook] {
                                notebook.notes.append(Note(id: s.id, text: s.note))
                                self.notesByFolder[key]![s.notebook] = notebook
                            } else {
                                folderNotes[s.notebook] = NoteBook(
                                    id: UUID(),
                                    title: s.notebook,
                                    notes: [Note(id: s.id, text: s.note)]
                                )
                                self.notesByFolder[key] = folderNotes
                            }
                        } else {
                            let newBook = NoteBook(
                                id: UUID(),
                                title: s.notebook,
                                notes: [Note(id: s.id, text: s.note)]
                            )
                            self.notesByFolder[key] = [s.notebook: newBook]
                        }
                    }
                }
            } catch {
                print("fetchUserNotes decode error: ", error)
            }
        }.resume()
    }

    /// Adds a new notebook locally (no initial note line).
    func addNoteBook(title: String, to folder: String) {
        let newBook = NoteBook(id: UUID(), title: title, notes: [])
        if var folderNotes = notesByFolder[folder] {
            folderNotes[title] = newBook
            notesByFolder[folder] = folderNotes
        } else {
            notesByFolder[folder] = [title: newBook]
        }
    }

    /// Adds a new note line to a notebook, persists on server.
    func addNote(_ note: String, title: String, folder: String) {
        let endpoint = baseURL.appendingPathComponent("add_note")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddNoteRequest(
            device_id: userID,
            note: note,
            folder: folder,
            notebook: title
        )
        do { request.httpBody = try JSONEncoder().encode(payload) }
        catch {
            print("addNote payload encoding failed: ", error)
            return
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("addNote error: ", error)
                return
            }
            guard let data = data,
                  let returned = try? JSONDecoder().decode([String: String].self, from: data),
                  let serverID = returned["id"]
            else { return }

            DispatchQueue.main.async {
                if var folderNotes = self.notesByFolder[folder],
                   var notebook = folderNotes[title] {
                    notebook.notes.append(Note(id: serverID, text: note))
                    self.notesByFolder[folder]![title] = notebook
                }
            }
        }.resume()
    }

    /// Deletes a note by ID, both locally and on server.
    func deleteNote(id: String, notebook: String, folder: String) {
        DispatchQueue.main.async {
            if var folderNotes = self.notesByFolder[folder],
               var book = folderNotes[notebook] {
                book.notes.removeAll { $0.id == id }
                self.notesByFolder[folder]![notebook] = book
            }
        }
        let endpoint = baseURL
            .appendingPathComponent("delete_note")
            .appendingPathComponent(userID)
            .appendingPathComponent(id)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request).resume()
    }

    /// Deletes all user notes on the server and clears the local store.
    func deleteAllNotes() {
        let endpoint = baseURL
            .appendingPathComponent("delete_user_notes")
            .appendingPathComponent(userID)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("deleteAllNotes error: ", error)
                return
            }
            if let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode) {
                DispatchQueue.main.async {
                    self.notesByFolder = [
                        "Notes": [:],
                        "Work": [:],
                        "Personal": [:]
                    ]
                    self.hasFetchedNotes = false
                }
            }
        }.resume()
    }

    /// Updates an existing note text on the server and locally.
    func syncSingleMessage(
        id: String,
        text: String,
        folder: String,
        notebook: String
    ) {
        let endpoint = baseURL.appendingPathComponent("update_note")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = [
            "device_id": userID,
            "note_id": id,
            "note": text
        ]
        do { request.httpBody = try JSONEncoder().encode(payload) }
        catch {
            print("syncSingleMessage payload encoding failed: ", error)
            return
        }

        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                print("syncSingleMessage error: ", error)
                return
            }
            DispatchQueue.main.async {
                if var folderNotes = self.notesByFolder[folder],
                   var book = folderNotes[notebook],
                   let idx = book.notes.firstIndex(where: { $0.id == id }) {
                    book.notes[idx].text = text
                    self.notesByFolder[folder]![notebook] = book
                }
            }
        }.resume()
    }

    // MARK: - New: Fetch Top-K AI Responses
    /// Requests the top-K responses for a given question from `/get_response?k=...`
    func fetchTopNotes(question: String, k: Int) async throws -> [String] {
        let endpoint = baseURL.appendingPathComponent("get_response")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = GetResponseRequest(
            device_id: userID,
            question: question,
            k: String(k)
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let code = (resp as? HTTPURLResponse)?.statusCode,
              200..<300 ~= code else {
            throw URLError(.badServerResponse)
        }

        let raw = try JSONDecoder().decode([String: String].self, from: data)
        // Extract and sort answer_N entries
        let sorted = raw.compactMap { key, val -> (Int, String)? in
            guard key.hasPrefix("answer_"),
                  let num = Int(key.dropFirst("answer_".count))
            else { return nil }
            return (num, val)
        }
        .sorted { $0.0 < $1.0 }
        .map { $0.1 }

        return sorted
    }
}
