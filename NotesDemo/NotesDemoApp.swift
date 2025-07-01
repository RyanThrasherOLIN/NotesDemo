//
//  NotesDemoApp.swift
//  NotesDemo
//

import SwiftUI

@main
struct NotesDemoApp: App {
    @StateObject private var store          = NoteStore()
    @StateObject private var hiddenStore    = HiddenLineStore()
    @StateObject private var recordingStore = RecordingStore()   // ← added

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(hiddenStore)
                .environmentObject(recordingStore)   // ← inject here
                .task {
                    store.fetchUserNotes()
                }
        }
    }
}
