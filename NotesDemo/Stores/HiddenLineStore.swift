import Foundation
import UIKit // for UIDevice

/// Model returned by the server on GET and POST
private struct NoteResponse: Codable {
    let folder: String
    let id: String
    let note: String
    let notebook: String
}

final class HiddenLineStore: ObservableObject {
    @Published private(set) var syncedIDs = Set<String>()
    @Published private(set) var syncedMessages: [ChatMessage] = []

    // MARK: - API Client
    private enum NotesAPI {
        static var base: URL { Config.baseURL }

        /// Generic JSON send & ignore response body
        private static func send<T: Encodable>(_ payload: T, to endpoint: String, method: String) async throws {
            let url = base.appendingPathComponent(endpoint)
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let code = (response as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
                throw URLError(.badServerResponse)
            }
        }

        /// Adds a new note on the server and returns the server’s object (with real ID)
        static func addMessage(
            id: String,
            text: String,
            folder: String,
            notebook: String
        ) async throws -> NoteResponse {
            let payload = [
                "id": id,
                "device_id": UIDevice.current.identifierForVendor!.uuidString,
                "note": text,
                "folder": folder,
                "notebook": notebook
            ]
            let url = base.appendingPathComponent("add_note")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let code = (response as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
                throw URLError(.badServerResponse)
            }
            return try JSONDecoder().decode(NoteResponse.self, from: data)
        }

        /// Updates an existing note by ID
        static func updateNote(id: String, text: String) async throws {
            let payload = [
                "device_id": UIDevice.current.identifierForVendor!.uuidString,
                "note_id": id,
                "note": text
            ]
            try await send(payload, to: "update_note", method: "PUT")
        }

        /// Deletes a note on the server
        static func deleteNote(id: String) async throws {
            let payload = [
                "id": id,
                "device_id": UIDevice.current.identifierForVendor!.uuidString
            ]
            try await send(payload, to: "delete_note", method: "POST")
        }

        /// Fetches all notes for this device/folder/notebook
        static func fetchNotes(folder: String, notebook: String) async throws -> [NoteResponse] {
            var comps = URLComponents(url: base.appendingPathComponent("get_user_notes"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "device_id", value: UIDevice.current.identifierForVendor!.uuidString),
                URLQueryItem(name: "folder",     value: folder),
                URLQueryItem(name: "notebook",   value: notebook)
            ]
            let (data, response) = try await URLSession.shared.data(from: comps.url!)
            guard let code = (response as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
                throw URLError(.badServerResponse)
            }
            return try JSONDecoder().decode([NoteResponse].self, from: data)
        }
    }

    // MARK: - Public API

    /// Fetch latest notes from server and replace local cache
    @MainActor
    func fetchMessages(folder: String, notebook: String) async {
        do {
            let list = try await NotesAPI.fetchNotes(folder: folder, notebook: notebook)
            syncedIDs = Set(list.map { $0.id })
            syncedMessages = list.map { ChatMessage(id: $0.id, text: $0.note) }
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }

    /// Upserts a message: adds if new, updates if already synced
    func syncSingleMessage(id: String, text: String, folder: String, notebook: String) {
        Task { @MainActor in
            do {
                if syncedIDs.contains(id) {
                    try await NotesAPI.updateNote(id: id, text: text)
                    if let idx = syncedMessages.firstIndex(where: { $0.id == id }) {
                        syncedMessages[idx].text = text
                    }
                } else {
                    // create new on server, get real ID
                    let resp = try await NotesAPI.addMessage(id: id, text: text, folder: folder, notebook: notebook)
                    // replace any temp with server ID
                    let tempIndex = syncedMessages.firstIndex(where: { $0.id == id })
                    if let tempIndex {
                        syncedMessages[tempIndex].id = resp.id
                        syncedMessages[tempIndex].text = resp.note
                    } else {
                        syncedMessages.append(ChatMessage(id: resp.id, text: resp.note))
                    }
                    syncedIDs.insert(resp.id)
                }
            } catch {
                print("Failed to sync message \(id): \(error)")
            }
        }
    }

    /// Deletes an existing message by ID, both locally and on server
    func deleteMessage(id: String) {
        Task { @MainActor in
            do {
                try await NotesAPI.deleteNote(id: id)
                syncedIDs.remove(id)
                syncedMessages.removeAll { $0.id == id }
            } catch {
                print("Failed to delete message \(id): \(error)")
            }
        }
    }
}
