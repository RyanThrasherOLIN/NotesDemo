// NotesDemoApp.swift

import SwiftUI

@main
struct NotesDemoApp: App {
    @StateObject private var store       = NoteStore()
    @StateObject private var hiddenStore = HiddenLineStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
              .environmentObject(store)
              .environmentObject(hiddenStore)
              .task {
                  // On launch, pull down the user's notes
                  store.fetchUserNotes()
              }
        }
    }
}
