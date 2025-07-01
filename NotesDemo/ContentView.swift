//  ContentView.swift
//  NotesDemo

import SwiftUI

struct ContentView: View {
    // Navigation
    @ObservedObject private var nav = NavigationStackHandler.shared

    // Shared data stores
    @EnvironmentObject private var store: NoteStore
    @StateObject private var hiddenStore = HiddenLineStore()

    // Folder picker state
    @State private var folders       = ["Notes", "Work", "Personal"]
    @State private var currentFolder = "Notes"

    // Overlay state
    @State private var showingSearch  = false
    @State private var showingAdd     = false
    @State private var showingFolders = false

    var body: some View {
        ZStack {
            NavigationStack(path: $nav.path) {
                VStack(spacing: 0) {
                    headerBar
                    notesList
                    Spacer()
                    bottomButtons
                }
                .navigationBarHidden(true)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destination.asView
                        .environmentObject(store)
                        .environmentObject(hiddenStore)
                }
            }
            .environmentObject(store)
            .environmentObject(hiddenStore)

            if showingSearch {
                SearchOverlay(isPresented: $showingSearch)
            }

            if showingAdd {
                AddNoteOverlay(isPresented: $showingAdd) { title in
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addNote(title: trimmed, to: currentFolder)
                }
            }

            if showingFolders {
                FolderOverlay(
                    isPresented: $showingFolders,
                    selectedFolder: $currentFolder,
                    folders: $folders
                )
            }
        }
    }

    // MARK: Header
    private var headerBar: some View {
        HStack {
            Button {
                showingFolders = true
            } label: {
                Image(systemName: "folder")
                    .font(.title2)
            }
            .accessibilityLabel("Notes folders")

            Spacer()

            Text(currentFolder)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity)

            Spacer().frame(width: 24)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: Notes List
    private var notesList: some View {
        List {
            ForEach(store.notesByFolder[currentFolder] ?? [], id: \.id) { note in
                NavigationLink(
                    value: NavigationDestination.noteDetail(
                        folder: currentFolder,
                        noteTitle: note.title
                    )
                ) {
                    Text(note.title)
                        .font(.title2)
                        .padding(.vertical, 6)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteRows)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: Bottom Toolbar
    private var bottomButtons: some View {
        HStack(spacing: 30) {
            CircleButton(image: "person", bg: .indigo,
                         accessibilityLabel: "Settings") {
                nav.pushView(.settings)
            }

            CircleButton(image: "mic", bg: .pink,
                         accessibilityLabel: "Record note") {
                // voice-memo hook
            }

            CircleButton(image: "magnifyingglass", bg: .orange,
                         accessibilityLabel: "Search for note") {
                showingSearch = true
            }

            CircleButton(image: "plus", bg: .green,
                         accessibilityLabel: "Add note") {
                showingAdd = true
            }
        }
        .padding(.bottom)
    }

    // MARK: Helpers
    private func deleteRows(_ offsets: IndexSet) {
        guard var list = store.notesByFolder[currentFolder] else { return }
        list.remove(atOffsets: offsets)
        store.notesByFolder[currentFolder] = list
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NoteStore())
            .environmentObject(HiddenLineStore())
    }
}
#endif
