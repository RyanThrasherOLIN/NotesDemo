//
//  RecordingStore.swift
//  NotesDemo
//
import Foundation

/// Represents a single audio recording.
struct Recording: Identifiable {
    let id = UUID()
    let url: URL
    let createdAt: Date
}

/// Stores recordings in memory and publishes changes.
final class RecordingStore: ObservableObject {
    @Published var recordings: [Recording] = []

    func add(_ recording: Recording) {
        recordings.insert(recording, at: 0)
    }
}
