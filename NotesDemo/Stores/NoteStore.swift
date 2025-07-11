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

/// New response model for `/get_response` endpoint.
struct AIResponse: Codable, Identifiable {
    let id: String
    let answer: String
    let folder: String
    let notebook: String
}

/// Payload sent to POST /submit_feedback for user feedback.
private struct SubmitFeedbackRequest: Codable {
    let username: String
    let question: String
    let answer: String
    let is_pair: Bool
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
        var comps = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "device_id", value: userID)]
        guard let url = comps?.url else { return }

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
    func addNoteBook(title: String, to folder: String) { /* unchanged */ }
    func addNote(_ note: String, title: String, folder: String) { /* unchanged */ }
    func deleteNote(id: String, notebook: String, folder: String) { /* unchanged */ }
    func deleteAllNotes() { /* unchanged */ }
    func syncSingleMessage(id: String, text: String, folder: String, notebook: String) { /* unchanged */ }

    // MARK: - Updated: Fetch Top-K AI Responses
    /// Requests the top-K responses for a given question from `/get_response`.
    func fetchTopNotes(question: String, k: Int) async throws -> [AIResponse] {
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
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }

        // Decode the new array of AIResponse objects
        let responses = try JSONDecoder().decode([AIResponse].self, from: data)
        return responses
    }

    /// Sends a single feedback event to `/submit_feedback`.
    func submitFeedback(question: String, answer: String, isPair: Bool) { /* unchanged */ }
}
