// HiddenLineStore.swift
// Manages add, update (upsert), and delete of individual chat messages via the backend API.

import Foundation
import UIKit // for UIDevice

final class HiddenLineStore: ObservableObject {
    @Published private(set) var syncedIDs = Set<String>()
    @Published private(set) var syncedMessages: [ChatMessage] = []

    // MARK: - API Models
    private struct AddMessageRequest: Codable {
        let id: String
        let device_id: String
        let note: String
        let folder: String
        let notebook: String
    }

    private struct UpdateNoteRequest: Codable {
        let device_id: String
        let note_id: String
        let note: String
    }

    private struct DeleteMessageRequest: Codable {
        let id: String
        let device_id: String
    }

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
            guard let code = (response as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
                throw URLError(.badServerResponse)
            }
        }

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

        static func updateNote(id: String, text: String) async throws {
            let payload = UpdateNoteRequest(
                device_id: UIDevice.current.identifierForVendor!.uuidString,
                note_id: id,
                note: text
            )
            try await send(payload, to: "update_note", method: "PUT")
        }

        static func deleteNote(id: String) async throws {
            let payload = DeleteMessageRequest(
                id: id,
                device_id: UIDevice.current.identifierForVendor!.uuidString
            )
            try await send(payload, to: "delete_note", method: "POST")
        }
    }

    // MARK: - Store actions

    /// Upserts a message: adds if new, updates if already synced
    func syncSingleMessage(id: String, text: String, folder: String, notebook: String) {
        Task {
            do {
                if syncedIDs.contains(id) {
                    try await NotesAPI.updateNote(id: id, text: text)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, let uuid = UUID(uuidString: id) else { return }
                        if let idx = self.syncedMessages.firstIndex(where: { $0.id == uuid }) {
                            self.syncedMessages[idx].text = text
                        }
                    }
                } else {
                    try await NotesAPI.addMessage(id: id, text: text, folder: folder, notebook: notebook)
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, let uuid = UUID(uuidString: id) else { return }
                        self.syncedIDs.insert(id)
                        self.syncedMessages.append(ChatMessage(id: uuid, text: text))
                    }
                }
            } catch {
                print("Failed to sync message \(id): \(error)")
            }
        }
    }

    /// Deletes an existing message by ID, both locally and on server
    func deleteMessage(id: String) {
        Task {
            do {
                try await NotesAPI.deleteNote(id: id)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.syncedIDs.remove(id)
                    if let uuid = UUID(uuidString: id) {
                        self.syncedMessages.removeAll { $0.id == uuid }
                    }
                }
            } catch {
                print("Failed to delete message \(id): \(error)")
            }
        }
    }
}
