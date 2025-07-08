import Foundation
import UIKit // for UIDevice

/// Model returned by the server on GET and POST
private struct NoteResponse: Codable {
    let folder: String
    let id: String
    let note: String
    let notebook: String
}

/// Manages syncing ChatMessage objects (String IDs) with a backend API
final class HiddenLineStore: ObservableObject {
    @Published private(set) var syncedIDs = Set<String>()
    @Published private(set) var syncedMessages: [ChatMessage] = []

    /// Tracks the current notebook context to prevent cross-notebook bleed and duplicate fetches
    private var currentContext: (folder: String, notebook: String)?

    // MARK: - API Client
    private enum NotesAPI {
        static var base: URL { Config.baseURL }

        private static func send<T: Encodable>(_ payload: T, to endpoint: String, method: String) async throws {
            let url = base.appendingPathComponent(endpoint)
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(payload)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let code = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
                throw URLError(.badServerResponse)
            }
        }

        static func fetchNotes(folder: String, notebook: String) async throws -> [NoteResponse] {
            var comps = URLComponents(url: base.appendingPathComponent("get_user_notes"), resolvingAgainstBaseURL: false)!
            comps.queryItems = [
                URLQueryItem(name: "device_id", value: UIDevice.current.identifierForVendor!.uuidString),
                URLQueryItem(name: "folder",     value: folder),
                URLQueryItem(name: "notebook",   value: notebook)
            ]
            let (data, response) = try await URLSession.shared.data(from: comps.url!)
            guard let code = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
                throw URLError(.badServerResponse)
            }
            return try JSONDecoder().decode([NoteResponse].self, from: data)
        }

        static func addMessage(
            tempID: String,
            text: String,
            folder: String,
            notebook: String
        ) async throws -> NoteResponse {
            let payload = [
                "id": tempID,
                "device_id": UIDevice.current.identifierForVendor!.uuidString,
                "note": text,
                "folder": folder,
                "notebook": notebook
            ]
            let url = base.appendingPathComponent("add_note")
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let code = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(code) else {
                throw URLError(.badServerResponse)
            }
            return try JSONDecoder().decode(NoteResponse.self, from: data)
        }

        static func updateNote(id: String, text: String) async throws {
            let payload = [
                "device_id": UIDevice.current.identifierForVendor!.uuidString,
                "note_id": id,
                "note": text
            ]
            try await send(payload, to: "update_note", method: "PUT")
        }

        static func deleteNote(id: String) async throws {
            let payload = [
                "id": id,
                "device_id": UIDevice.current.identifierForVendor!.uuidString
            ]
            try await send(payload, to: "delete_note", method: "POST")
        }
    }

    // MARK: - Public API

    /// Clears stale data (if context changed) and fetches notes for the given notebook
    @MainActor
    func fetchMessages(folder: String, notebook: String) async {
        // clear if switching notebooks
        if currentContext?.folder != folder || currentContext?.notebook != notebook {
            currentContext = (folder, notebook)
            syncedIDs.removeAll()
            syncedMessages.removeAll()
        }
        do {
            let list = try await NotesAPI.fetchNotes(folder: folder, notebook: notebook)
            syncedIDs = Set(list.map { $0.id })
            syncedMessages = list.map { ChatMessage(id: $0.id, text: $0.note) }
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }

    /// Upserts a message: if it exists, sends an update; otherwise posts and swaps the temp ID
    func syncSingleMessage(id tempID: String, text: String, folder: String, notebook: String) {
        // ignore outside current context
        guard let ctx = currentContext,
              ctx.folder == folder,
              ctx.notebook == notebook else { return }

        Task { @MainActor in
            // existing note?
            if syncedIDs.contains(tempID) {
                do {
                    try await NotesAPI.updateNote(id: tempID, text: text)
                    if let idx = syncedMessages.firstIndex(where: { $0.id == tempID }) {
                        syncedMessages[idx].text = text
                    }
                } catch {
                    print("Failed to update message \(tempID): \(error)")
                }
            } else {
                // new note: optimistically append then swap ID
                syncedMessages.append(ChatMessage(id: tempID, text: text))
                syncedIDs.insert(tempID)
                do {
                    let resp = try await NotesAPI.addMessage(tempID: tempID, text: text, folder: folder, notebook: notebook)
                    if let idx = syncedMessages.firstIndex(where: { $0.id == tempID }) {
                        syncedMessages[idx] = ChatMessage(id: resp.id, text: resp.note)
                        syncedIDs.remove(tempID)
                        syncedIDs.insert(resp.id)
                    }
                } catch {
                    print("Failed to add message \(tempID): \(error)")
                }
            }
        }
    }

    /// Deletes a message both locally and on the server
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
