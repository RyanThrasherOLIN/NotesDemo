///
/// HiddenLineStore.swift
/// NotesDemo
///
/// Manages add, update, and delete of individual chat messages via the backend API.
/// Uses POST for add/delete and PUT for update, with minimal payloads.
///
import Foundation
import UIKit // for UIDevice.device

// MARK: - API Models

/// Payload to add a message
private struct AddMessageRequest: Codable {
    let id: String
    let device_id: String
    let note: String
    let folder: String
    let notebook: String
}

/// Payload to update a message
private struct UpdateNoteRequest: Codable {
    let device_id: String
    let note_id: String
    let note: String
}

/// Payload to delete a message
private struct DeleteMessageRequest: Codable {
    let id: String
    let device_id: String
}

// MARK: - API Client

enum NotesAPI {
    static var base: URL { Config.baseURL }

    /// Sends a JSON payload to the given endpoint using the specified HTTP method.
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

    /// Add a new message via POST /add_note
    static func addMessage(id: String, text: String, folder: String, notebook: String) async throws {
        let payload = AddMessageRequest(
            id: id,
            device_id: UIDevice.current.identifierForVendor!.uuidString,
            note: text,
            folder: folder,
            notebook: notebook
        )
        try await send(payload, to: "add_note", method: "POST")
    }

    /// Update an existing message via PUT /update_note
    static func updateNote(id: String, text: String) async throws {
        let payload = UpdateNoteRequest(
            device_id: UIDevice.current.identifierForVendor!.uuidString,
            note_id: id,
            note: text
        )
        try await send(payload, to: "update_note", method: "PUT")
    }

    /// Delete a message via POST /delete_note
    static func deleteNote(id: String) async throws {
        let payload = DeleteMessageRequest(
            id: id,
            device_id: UIDevice.current.identifierForVendor!.uuidString
        )
        try await send(payload, to: "delete_note", method: "POST")
    }
}

// MARK: - Store

/// Observable store that syncs chat messages with the server.
/// Tracks which IDs have been successfully added to avoid duplicates.
final class HiddenLineStore: ObservableObject {
    @Published private(set) var syncedIDs = Set<String>()

    /// Add a message if not already added
    func syncSingleMessage(id: String, text: String, folder: String, notebook: String) {
        guard !syncedIDs.contains(id) else { return }
        Task {
            do {
                try await NotesAPI.addMessage(id: id, text: text, folder: folder, notebook: notebook)
                DispatchQueue.main.async { [weak self] in
                    self?.syncedIDs.insert(id)
                }
            } catch {
                print("Failed to add message \(id): \(error)")
            }
        }
    }

    /// Update an existing message
    func updateMessage(id: String, newText: String) {
        Task {
            do {
                try await NotesAPI.updateNote(id: id, text: newText)
            } catch {
                print("Failed to update message \(id): \(error)")
            }
        }
    }

    /// Delete a message
    func deleteMessage(id: String) {
        Task {
            do {
                try await NotesAPI.deleteNote(id: id)
            } catch {
                print("Failed to delete message \(id): \(error)")
            }
        }
    }
}
