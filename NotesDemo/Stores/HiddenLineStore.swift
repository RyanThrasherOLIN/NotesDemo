//  HiddenLineStore.swift
//  NotesDemo
//
import Foundation
import UIKit    // for UIDevice

/// Shared payload for POST /add_note
private struct AddNoteRequest: Codable {
    let device_id: String
    let note: String
    let folder: String
    let notebook: String
}

/// Async helper to call your endpoints
enum NotesAPI {
    static let base = URL(string: "http://10.77.0.11:5000")!

    static func ping() async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: base)
        return String(decoding: data, as: UTF8.self)
    }

    static func addNote(
        _ note: String,
        folder: String,
        notebook: String
    ) async throws {
        let url = base.appendingPathComponent("add_note")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = AddNoteRequest(
            device_id: UIDevice.current.identifierForVendor!.uuidString,
            note:      note,
            folder:    folder,
            notebook:  notebook
        )
        req.httpBody = try JSONEncoder().encode(payload)

        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode,
              200..<300 ~= code else {
            throw URLError(.badServerResponse)
        }
    }

    static func getResponse(to question: String) async throws -> String {
        let url = base.appendingPathComponent("get_response")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["question": question]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode,
              200..<300 ~= code else {
            throw URLError(.badServerResponse)
        }
        if let dict = try? JSONDecoder().decode([String:String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Syncs new lines to the server as notes
final class HiddenLineStore: ObservableObject {
    @Published private(set) var syncedLines = Set<String>()

    /// Now requires folder & notebook to route lines correctly
    func sync(
        _ allLines: [String],
        folder: String,
        notebook: String
    ) {
        let newLines = Set(allLines).subtracting(syncedLines)
        guard !newLines.isEmpty else { return }

        Task {
            for line in newLines {
                do {
                    try await NotesAPI.addNote(
                        line,
                        folder: folder,
                        notebook: notebook
                    )
                } catch {
                    print("Failed to add “\(line)”: \(error)")
                }
            }
            DispatchQueue.main.async {
                self.syncedLines.formUnion(newLines)
            }
        }
    }
}
