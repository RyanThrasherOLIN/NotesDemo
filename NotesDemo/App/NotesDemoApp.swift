// NotesDemoApp.swift
// NotesDemo
import SwiftUI

@main
struct NotesDemoApp: App {
    @StateObject private var store = NoteStore()
    @StateObject private var recordingStore = RecordingStore()
    @StateObject private var nav = NavigationStackHandler.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(recordingStore)
                .environmentObject(nav)
                .task { store.fetchUserNotes() }
                .accentColor(ColorPalette.current.accent)
                .background(ColorPalette.current.background.ignoresSafeArea())
        }
    }
}
