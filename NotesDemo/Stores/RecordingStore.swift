///
/// RecordingStore.swift
/// NotesDemo
///
/// In-memory store for managing audio recordings captured in the app.
/// Publishes updates to its recordings list for SwiftUI views to observe.
///
import Foundation

/// Model representing a single audio recording.
///
/// Conforms to Identifiable for use in SwiftUI lists.
struct Recording: Identifiable {
    /// Unique identifier for the recording.
    let id = UUID()
    /// File URL where the recording is stored on disk.
    let url: URL
    /// Timestamp indicating when the recording was created.
    let createdAt: Date
}

/// Observable store that holds a list of `Recording` objects.
///
/// - New recordings are inserted at the front of the list.
/// - Views subscribing to this store will automatically update when recordings change.
final class RecordingStore: ObservableObject {
    /// Published array of recordings, ordered newest first.
    @Published var recordings: [Recording] = []

    /// Adds a new recording to the store.
    ///
    /// - Parameter recording: The `Recording` instance to insert.
    ///
    /// Inserts the new recording at index 0 to appear at the top of lists.
    func add(_ recording: Recording) {
        recordings.insert(recording, at: 0)
    }
    
    func speechToText(_ recording: Recording) async {
        let openAIApiKey = "OPENAI_API_KEY"
        let openAiUrl = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        
        var request = URLRequest(url: openAiUrl)
        request.addValue("Bearer \(openAIApiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        do {
            let audioData = try Data(contentsOf: recording.url)
            
            var body = Data()
            
            // Add audio file
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add model parameter
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("gpt-4o-transcribe\r\n".data(using: .utf8)!)
            
            // Add optional parameters
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
            body.append("json\r\n".data(using: .utf8)!)
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
            body.append("0\r\n".data(using: .utf8)!)
            
            // Close boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status code: \(httpResponse.statusCode)")
            }
            
            print("-----> responseData \n \(String(data: responseData, encoding: .utf8) ?? "Could not decode response") \n")
            
        } catch {
            print("Error: \(error)")
        }
    }
