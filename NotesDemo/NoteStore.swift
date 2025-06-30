// NoteStore.swift

import Foundation
import SwiftUI

// Mirrors exactly what your GET /get_user_notes returns
private struct ServerNote: Decodable {
    let folder: String
    let id: String
    let note: String
    let notebook: String
}

// Your local Note model—unchanged
struct Note: Identifiable, Hashable {
    let id: UUID
    let title: String
    var lines: [String]
}

class NoteStore: ObservableObject {
    @Published var notesByFolder: [String:[Note]] = [:]

    private let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    private let baseURL   = "http://<YOUR_IP>:8000"

    // Call me on app launch to pull everything down
    func fetchUserNotes() {
        guard
            var comp = URLComponents(string: "\(baseURL)/get_user_notes")
        else { return }
        comp.queryItems = [ URLQueryItem(name: "device_id", value: deviceID) ]

        guard let url = comp.url else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard
                error == nil,
                let data = data,
                let serverNotes = try? JSONDecoder().decode([ServerNote].self, from: data)
            else {
                print("fetchUserNotes failed:", error ?? "invalid data")
                return
            }

            // Map each ServerNote → your local Note, grouped by folder
            var newDict: [String:[Note]] = [:]
            for s in serverNotes {
                let local = Note(
                    id: UUID(),          // or hash s.id however you prefer
                    title: s.note,
                    lines: []
                )
                newDict[s.folder, default: []].append(local)
            }

            DispatchQueue.main.async {
                self.notesByFolder = newDict
            }
        }
        .resume()
    }

    // Update this to POST device_id & note to your add_note endpoint
    func addNote(title: String, to folder: String) {
        // 1) update local cache
        let new = Note(id: UUID(), title: title, lines: [])
        notesByFolder[folder, default: []].append(new)

        // 2) fire off to server
        guard let url = URL(string: "\(baseURL)/add_note") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String:String] = [
            "device_id": deviceID,
            "note": title
        ]
        req.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: req).resume()
    }
}
