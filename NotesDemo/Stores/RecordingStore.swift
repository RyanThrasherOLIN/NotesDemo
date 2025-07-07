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
}
