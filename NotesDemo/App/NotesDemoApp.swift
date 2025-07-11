///
/// NotesDemoApp.swift
/// NotesDemo
///
/// Entry point of the NotesDemo application.
/// Sets up shared data stores, injects environment objects, and
/// triggers initial data fetch on launch.
///
import SwiftUI

/// Main application struct conforming to the SwiftUI `App` protocol.
///
/// - Initializes and provides shared `ObservableObject`s for:
///   - `NoteStore`: manages notes and server sync
///   - `RecordingStore`: holds audio recordings
/// - Injects these stores into the root `ContentView`.
/// - Initiates a data fetch of user notes upon launch.
@main
struct NotesDemoApp: App {
    // MARK: - Shared Data Stores
    /// Primary store for notes, grouped by folders.
    @StateObject private var store = NoteStore()
    /// Store for managing audio recordings within the app.
    @StateObject private var recordingStore = RecordingStore()

    // MARK: - Scene Definition
    var body: some Scene {
        WindowGroup {
            // Root content view with environment object injection
            ContentView()
                .environmentObject(store)
                .environmentObject(recordingStore)
                // Perform an initial fetch of user notes when the view appears
                .task {
                    store.fetchUserNotes()
                }
        }
    }
}
