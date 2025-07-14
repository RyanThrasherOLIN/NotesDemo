import SwiftUI

/// The main content view of the NotesDemo application.
struct ContentView: View {
    // ─── Shared Stores ───────────────────────────────────────
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var nav: NavigationStackHandler

    // ─── Folder Picker State ─────────────────────────────────
    @State private var folders       = ["Notes", "Work", "Personal"]
    @State private var currentFolder = "Notes"

    // ─── Overlay Flags ───────────────────────────────────────
    @State private var showingSearch  = false
    @State private var showingAdd     = false
    @State private var showingFolders = false

    var body: some View {
        ZStack {
            // ─── Main NavigationStack ──────────────────────────
            NavigationStack(path: $nav.path) {
                VStack(spacing: 0) {
                    headerBar
                    NoteList(currentFolder: $currentFolder)
                    Spacer()
                    bottomButtons
                }
                .navigationBarHidden(true)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .settings:
                        SettingsView()
                            .environmentObject(store)
                            .environmentObject(recordingStore)
                            .environmentObject(nav)

                    case .noteDetail(let folder, let noteTitle):
                        NoteDetailView(folder: folder, noteTitle: noteTitle)
                            .environmentObject(store)
                            .environmentObject(recordingStore)
                            .environmentObject(nav)
                    }
                }
            }

            // ─── Overlays ──────────────────────────────────────
            if showingSearch {
                SearchOverlay(isPresented: $showingSearch)
                    .environmentObject(store)
                    .environmentObject(recordingStore)
                    .environmentObject(nav)
            }

            if showingAdd {
                AddNoteOverlay(isPresented: $showingAdd) { title in
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addNoteBook(title: trimmed, to: currentFolder)
                }
                .environmentObject(store)
            }

            if showingFolders {
                FolderOverlay(
                    isPresented: $showingFolders,
                    selectedFolder: $currentFolder,
                    folders: $folders
                )
                .environmentObject(store)
            }
        }
    }

    // MARK: – Header Bar
    private var headerBar: some View {
        HStack {
            Button { showingFolders = true } label: {
                Image(systemName: "folder").font(.title2)
            }
            Spacer()
            Text(currentFolder)
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity)
            Spacer().frame(width: 24)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: – Note List
    private var noteList: some View {
        NoteList(currentFolder: $currentFolder)
    }

    // MARK: – Bottom Toolbar
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            // Settings
            Button { nav.pushView(.settings) } label: {
                VStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.title)
                    Text("Settings").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)

            // Search
            Button { showingSearch = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.title)
                    Text("Search").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.9, green: 0.2, blue: 0.4))

            // Add Note
            Button { showingAdd = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.title)
                    Text("Add Note").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}


/// A slimmed-down list that reads its NoteStore from the environment.
struct NoteList: View {
    @Binding private var currentFolder: String
    @EnvironmentObject private var store: NoteStore

    init(currentFolder: Binding<String>) {
        self._currentFolder = currentFolder
    }

    var body: some View {
        List {
            if let folderNotes = store.notesByFolder[currentFolder] {
                ForEach(folderNotes.sorted(by: <), id: \.key) { title, _ in
                    NavigationLink(
                        value: NavigationDestination.noteDetail(
                            folder: currentFolder,
                            noteTitle: title
                        )
                    ) {
                        Text(title)
                            .font(.title2)
                            .padding(.vertical, 6)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NoteStore())
            .environmentObject(RecordingStore())
            .environmentObject(NavigationStackHandler.shared)
    }
}
#endif
