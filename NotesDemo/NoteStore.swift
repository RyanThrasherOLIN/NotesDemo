// NoteStore.swift
//  NotesDemo

import Foundation
import UIKit    // for UIDevice
import SwiftUI

// MARK: — Request & Response Models

private struct AddNoteRequest: Codable {
    let device_id: String
    let note: String
    let folder: String
    let notebook: String
}

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
    @Published var notesByFolder: [String: [Note]] = [
        "Notes": [],
        "Work": [],
        "Personal": []
    ]

    // MARK: — Single persistent user ID
    private let userID: String = {
        let key = "userID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }()

    private let baseURL = "http://10.77.0.11:5000"

    /// Initialize and immediately fetch existing notes
    init() {
        fetchUserNotes()
    }

    /// Fetch all notes for this user and merge into folders
    func fetchUserNotes() {
        guard var components = URLComponents(string: "\(baseURL)/get_user_notes") else {
            return
        }
        components.queryItems = [
            URLQueryItem(name: "device_id", value: userID)
        ]
        guard let url = components.url else {
            print("❌ Invalid URL for fetchUserNotes")
            return
        }

        print("🔄 Fetching notes for userID: \(userID)")
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("❌ fetchUserNotes error: \(error)")
                return
            }
            guard let data = data else {
                print("❌ fetchUserNotes: no data returned")
                return
            }
            do {
                let serverNotes = try JSONDecoder().decode([ServerNote].self, from: data)
                print("✅ fetchUserNotes: fetched \(serverNotes.count) notes")

                // Prepare fresh dictionary with existing UI folders
                var grouped: [String: [Note]] = [
                    "Notes": [],
                    "Work": [],
                    "Personal": []
                ]

                for s in serverNotes {
                    let folderKey = s.folder.lowercased() == "default" ? "Notes" : s.folder
                    let note = Note(id: UUID(), title: s.note, lines: [])
                    grouped[folderKey, default: []].append(note)
                }

                DispatchQueue.main.async {
                    self.notesByFolder = grouped
                }
            } catch {
                print("❌ fetchUserNotes decode error: \(error)")
            }
        }
        .resume()
    }

    /// Add a note locally and on the server
    func addNote(title: String, to folder: String) {
        // Update local cache immediately
        let newNote = Note(id: UUID(), title: title, lines: [])
        notesByFolder[folder, default: []].append(newNote)

        // Prepare request
        guard let url = URL(string: "\(baseURL)/add_note") else {
            print("❌ Invalid URL for addNote")
            return
        }
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
            print("❌ addNote payload encoding failed: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request).resume()
    }
}
