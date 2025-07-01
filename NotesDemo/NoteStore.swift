// NoteStore.swift

import Foundation
import UIKit       // for UIDevice
import SwiftUI

// Payload you send when adding a note
private struct AddNoteRequest: Codable {
    let device_id: String
    let note: String
    let folder: String
    let notebook: String
}

// Mirror of the JSON you get back from GET /get_user_notes
private struct ServerNote: Codable {
    let folder: String
    let id: String
    let note: String
    let notebook: String
}

struct Note: Identifiable, Hashable {
    let id: UUID
    let title: String
    var lines: [String]
}

class NoteStore: ObservableObject {
    @Published var notesByFolder: [String:[Note]] = [:]

    private let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    private let baseURL   = "http://10.77.0.11:5000"

    /// Fetches all notes for this device and groups them by folder
    func fetchUserNotes() {
        guard var components = URLComponents(string: "\(baseURL)/get_user_notes") else {
            return
        }
        components.queryItems = [
            URLQueryItem(name: "device_id", value: deviceID)
        ]
        guard let url = components.url else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil,
                  let data = data,
                  let serverNotes = try? JSONDecoder().decode([ServerNote].self, from: data)
            else {
                print("❌ fetchUserNotes failed:", error ?? "invalid data")
                return
            }

            // Group by `folder` field
            var grouped: [String:[Note]] = [:]
            for s in serverNotes {
                let localNote = Note(
                    id: UUID(),
                    title: s.note,
                    lines: []
                )
                grouped[s.folder, default: []].append(localNote)
            }

            DispatchQueue.main.async {
                self.notesByFolder = grouped
            }
        }
        .resume()
    }

    /// Adds a new note both locally and on your server, including folder & notebook
    func addNote(title: String, to folder: String) {
        // 1) Update local cache immediately
        let newNote = Note(id: UUID(), title: title, lines: [])
        notesByFolder[folder, default: []].append(newNote)

        // 2) Fire off the POST
        guard let url = URL(string: "\(baseURL)/add_note") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddNoteRequest(
            device_id: deviceID,
            note:      title,
            folder:    folder,
            notebook:  title    // if your “notebook” field should differ, swap this out
        )

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            print("❌ addNote payload encoding failed:", error)
            return
        }

        URLSession.shared.dataTask(with: request).resume()
    }
}
