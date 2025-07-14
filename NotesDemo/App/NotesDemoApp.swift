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
///   - `NavigationStackHandler`: manages navigation stack
/// - Injects these stores into the root `ContentView`.
/// - Initiates a data fetch of user notes upon launch.
@main
struct NotesDemoApp: App {
    // MARK: - Shared Data Stores
    /// Primary store for notes, grouped by folders.
    @StateObject private var store = NoteStore()
    /// Store for managing audio recordings within the app.
    @StateObject private var recordingStore = RecordingStore()
    /// Shared navigation stack handler.
    @StateObject private var nav = NavigationStackHandler.shared

    // MARK: - Scene Definition
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(recordingStore)
                .environmentObject(nav)           // ← inject nav here
                .task {
                    store.fetchUserNotes()
                }
        }
    }
}
