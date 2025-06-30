//
//  HiddenLineStore.swift
//  NotesDemo
//
//  Created by occamlab on 6/27/25.
//
import Foundation

final class HiddenLineStore: ObservableObject {
    @Published private(set) var syncedLines = Set<String>()

    func sync(_ allLines: [String]) {
        let newLines = Set(allLines).subtracting(syncedLines)
        guard !newLines.isEmpty else { return }

        Task {
            for line in newLines {
                do {
                    try await NotesAPI.addNote(line)
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
// NotesAPI.swift (original version)
import Foundation

enum NotesAPI {
    static let base = URL(string: "http://10.77.0.124:8000")!

    static func ping() async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: base)
        return String(decoding: data, as: UTF8.self)
    }

    static func addNote(_ note: String) async throws {
        let url = base.appendingPathComponent("add_note")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["note": note]
        req.httpBody = try JSONEncoder().encode(body)
        let (_, resp) = try await URLSession.shared.data(for: req)
        guard let code = (resp as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
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
        guard let code = (resp as? HTTPURLResponse)?.statusCode, 200..<300 ~= code else {
            throw URLError(.badServerResponse)
        }
        if let dict = try? JSONDecoder().decode([String:String].self, from: data),
           let text = dict["response"] ?? dict["answer"] {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }
}
