// NoteStore.swift

import Foundation
import UIKit    // for UIDevice
import Combine  // for ObservableObject & @Published

// MARK: — Networking Models

/// Payload for POST /add_note
private struct AddNoteRequest: Codable {
    let device_id: String
    let note:      String
    let folder:    String
    let notebook:  String
}

/// Response from POST /add_note
private struct AddNoteResponse: Codable {
    let id: String
}

/// Payload for POST /get_response
private struct GetResponseRequest: Codable {
    let device_id: String
    let question:  String
    let k:         String
}

/// Model for GET /get_response
struct AIResponse: Codable, Identifiable {
    let id:       String
    let answer:   String
    let folder:   String
    let notebook: String
}

/// Payload for POST /submit_feedback
private struct SubmitFeedbackRequest: Codable {
    let username: String
    let question: String
    let answer:   String
    let is_pair:  Bool
}

/// Model returned by GET /get_user_notes
private struct ServerNote: Codable {
    let folder:   String
    let id:       String
    let note:     String
    let notebook: String
}

/// Payload for PUT /update_note
private struct UpdateNotePayload: Codable {
    let device_id: String
    let note_id:   String
    let note:      String
    enum CodingKeys: String, CodingKey {
        case device_id, note_id, note
    }
}

// MARK: — Local Models

struct NoteBook: Identifiable, Hashable, Comparable {
    let id:    UUID
    let title: String
    var notes: [Note]
    static func < (lhs: NoteBook, rhs: NoteBook) -> Bool { lhs.title < rhs.title }
}

struct Note: Identifiable, Hashable {
    let id:   String
    var text: String
}

// MARK: — The Store

final class NoteStore: ObservableObject {
    @Published var notesByFolder: [String: [String: NoteBook]] = [
        "Notes":    [:],
        "Work":     [:],
        "Personal": [:]
    ]

    // MARK: — Highlighting
    /// ID of the note to highlight when opening a detail view
    @Published var highlightedNoteID: String? = nil

    private var userID: String {
        UIDevice.current.identifierForVendor!.uuidString
    }

    private var baseURL: URL {
        let defaultURL = "https://happily-complete-stinkbug.ngrok-free.app/"
        let urlString = UserDefaults.standard.string(forKey: "apiURL") ?? defaultURL
        guard let url = URL(string: urlString) else {
            fatalError("Invalid `apiURL` in UserDefaults: \(urlString)")
        }
        return url
    }

    private var hasFetchedNotes = false

    func prepopulateNotes(completion: (() -> Void)? = nil) {
        let endpoint = baseURL.appendingPathComponent("prepopulate_notes")
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "device_id", value: userID), URLQueryItem(name: "notes_file", value: "chat_gpt_assistive_notes.csv")]
        guard let url = comps?.url else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("prepopulateUserNotes error:", error)
                return
            }
            DispatchQueue.main.async {
                self.hasFetchedNotes = false
                self.fetchUserNotes()
                if let completion = completion {
                    completion()
                }
            }
        }
        .resume()
    }
    
    /// Fetches all user notes once per app launch.
    func fetchUserNotes() {
        guard !hasFetchedNotes else { return }
        hasFetchedNotes = true

        let endpoint = baseURL.appendingPathComponent("get_user_notes")
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "device_id", value: userID)]
        guard let url = comps?.url else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("fetchUserNotes error:", error)
                return
            }
            guard let data = data else { return }
            do {
                let serverNotes = try JSONDecoder().decode([ServerNote].self, from: data)
                let filtered = serverNotes.filter { $0.note != $0.notebook }
                DispatchQueue.main.async {
                    var updated = self.notesByFolder
                    for s in filtered {
                        let folderKey = s.folder.lowercased() == "default" ? "Notes" : s.folder.capitalized
                        var folderMap = updated[folderKey] ?? [:]
                        if var book = folderMap[s.notebook] {
                            book.notes.append(Note(id: s.id, text: s.note))
                            folderMap[s.notebook] = book
                        } else {
                            folderMap[s.notebook] = NoteBook(
                                id: UUID(),
                                title: s.notebook,
                                notes: [Note(id: s.id, text: s.note)]
                            )
                        }
                        updated[folderKey] = folderMap
                    }
                    self.notesByFolder = updated
                }
            } catch {
                print("fetchUserNotes decode error:", error)
            }
        }
        .resume()
    }

    /// Creates a new, empty notebook under the given folder.
    func addNoteBook(title: String, to folder: String) {
        DispatchQueue.main.async {
            var fm = self.notesByFolder[folder] ?? [:]
            guard fm[title] == nil else { return }
            fm[title] = NoteBook(id: UUID(), title: title, notes: [])
            self.notesByFolder[folder] = fm
        }
    }

    /// Sends a new note to POST /add_note, decodes the server’s new `id`, then updates UI.
    func addNote(_ text: String, title: String, folder: String) {
        let endpoint = baseURL.appendingPathComponent("add_note")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddNoteRequest(device_id: userID, note: text, folder: folder, notebook: title)
        guard let body = try? JSONEncoder().encode(payload) else {
            print("addNote encoding error")
            return
        }
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { data, resp, error in
            if let error = error {
                print("addNote network error:", error)
                return
            }
            guard let data = data,
                  let http = resp as? HTTPURLResponse,
                  200..<300 ~= http.statusCode else {
                print("addNote bad response")
                return
            }
            do {
                let created = try JSONDecoder().decode(AddNoteResponse.self, from: data)
                DispatchQueue.main.async {
                    let folderKey = folder.lowercased() == "default" ? "Notes" : folder.capitalized
                    var all = self.notesByFolder
                    var folderMap = all[folderKey] ?? [:]
                    if var book = folderMap[title] {
                        book.notes.append(Note(id: created.id, text: text))
                        folderMap[title] = book
                    } else {
                        folderMap[title] = NoteBook(
                            id: UUID(), title: title,
                            notes: [Note(id: created.id, text: text)]
                        )
                    }
                    all[folderKey] = folderMap
                    self.notesByFolder = all
                }
            } catch {
                print("addNote decode error:", error)
            }
        }
        .resume()
    }

    /// Sends only the required fields to update a note on the server, then patches the local store on success.
    func syncSingleMessage(id: String, text: String, folder: String, notebook: String) {
        let endpoint = baseURL.appendingPathComponent("update_note")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "PUT"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = UpdateNotePayload(device_id: userID, note_id: id, note: text)
        guard let body = try? JSONEncoder().encode(payload) else {
            print("syncSingleMessage encoding error")
            return
        }
        req.httpBody = body

        URLSession.shared.dataTask(with: req) { data, resp, error in
            if let error = error {
                print("syncSingleMessage network error:", error)
                return
            }
            guard let http = resp as? HTTPURLResponse else {
                print("syncSingleMessage: no HTTPURLResponse")
                return
            }
            if !(200..<300 ~= http.statusCode) {
                let bodyStr = data.flatMap { String(data: $0, encoding: .utf8) } ?? "—empty—"
                print("syncSingleMessage bad response: \(http.statusCode) — \(bodyStr)")
                return
            }
            DispatchQueue.main.async {
                var all = self.notesByFolder
                var fm = all[folder] ?? [:]
                if var book = fm[notebook], let idx = book.notes.firstIndex(where: { $0.id == id }) {
                    book.notes[idx].text = text
                    fm[notebook] = book
                    all[folder] = fm
                    self.notesByFolder = all
                }
            }
        }
        .resume()
    }

    /// Deletes a single note via DELETE /delete_note/{device_id}/{note_id}, then removes it locally.
    func deleteNote(id: String, notebook: String, folder: String) {
        let endpoint = baseURL
            .appendingPathComponent("delete_note")
            .appendingPathComponent(userID)
            .appendingPathComponent(id)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: req) { _, resp, error in
            if let error = error {
                print("deleteNote network error:", error)
                return
            }
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                print("deleteNote bad response")
                return
            }
            DispatchQueue.main.async {
                var all = self.notesByFolder
                var fm = all[folder] ?? [:]
                if var book = fm[notebook] {
                    book.notes.removeAll { $0.id == id }
                    fm[notebook] = book
                    all[folder] = fm
                    self.notesByFolder = all
                }
            }
        }
        .resume()
    }

    /// Deletes all notes via DELETE /delete_user_notes/{device_id}, then clears locally.
    func deleteAllNotes() {
        let endpoint = baseURL
            .appendingPathComponent("delete_user_notes")
            .appendingPathComponent(userID)
        var req = URLRequest(url: endpoint)
        req.httpMethod = "DELETE"

        URLSession.shared.dataTask(with: req) { _, resp, error in
            if let error = error {
                print("deleteAllNotes network error:", error)
                return
            }
            guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                print("deleteAllNotes bad response")
                return
            }
            DispatchQueue.main.async {
                self.notesByFolder = ["Notes": [:], "Work": [:], "Personal": [:]]
                self.hasFetchedNotes = false
            }
        }
        .resume()
    }

    /// Deletes an entire notebook: fires DELETE for each note in it, then removes the notebook.
    func deleteNoteBook(title: String, in folder: String) {
        guard let folderMap = notesByFolder[folder], let book = folderMap[title] else { return }
        let ids = book.notes.map { $0.id }
        ids.forEach { noteID in
            let endpoint = baseURL
                .appendingPathComponent("delete_note")
                .appendingPathComponent(userID)
                .appendingPathComponent(noteID)
            var req = URLRequest(url: endpoint)
            req.httpMethod = "DELETE"
            URLSession.shared.dataTask(with: req).resume()
        }
        DispatchQueue.main.async {
            var all = self.notesByFolder
            var fm = all[folder] ?? [:]
            fm.removeValue(forKey: title)
            all[folder] = fm
            self.notesByFolder = all
        }
    }

    // MARK: — AI / Feedback

    func fetchTopNotes(question: String, k: Int) async throws -> [AIResponse] {
        let endpoint = baseURL.appendingPathComponent("get_response")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = GetResponseRequest(device_id: userID, question: question, k: String(k))
        request.httpBody = try JSONEncoder().encode(payload)
        let (data, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([AIResponse].self, from: data)
    }

    func submitFeedback(question: String, answer: String, isPair: Bool) {
        let endpoint = baseURL.appendingPathComponent("submit_feedback")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = SubmitFeedbackRequest(username: userID, question: question, answer: answer, is_pair: isPair)
        request.httpBody = try? JSONEncoder().encode(payload)
        URLSession.shared.dataTask(with: request).resume()
    }
}
