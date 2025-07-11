import SwiftUI

/// The main content view of the NotesDemo application.
struct ContentView: View {
    // MARK: - Navigation
    @ObservedObject private var nav = NavigationStackHandler.shared

    // MARK: - Shared Data Stores
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore

    // MARK: - Folder Picker State
    @State private var folders = ["Notes", "Work", "Personal"]
    @State private var currentFolder = "Notes"

    // MARK: - Overlay Presentation Flags
    @State private var showingSearch = false
    @State private var showingAdd = false
    @State private var showingFolders = false

    var body: some View {
        ZStack {
            NavigationStack(path: $nav.path) {
                VStack(spacing: 0) {
                    headerBar
                    NoteList(currentFolder: $currentFolder, store: store)
                    Spacer()
                    bottomButtons
                }
                .navigationBarHidden(true)
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destination.asView
                        .environmentObject(store)
                        .environmentObject(recordingStore)
                }
            }
            .environmentObject(store)
            .environmentObject(recordingStore)

            if showingSearch {
                SearchOverlay(isPresented: $showingSearch)
                    .environmentObject(store)
                    .environmentObject(recordingStore)
            }
            if showingAdd {
                AddNoteOverlay(isPresented: $showingAdd) { title in
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addNoteBook(title: trimmed, to: currentFolder)
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

    // MARK: - Header Bar
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

    // MARK: - Bottom Toolbar
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            settingsButton
            searchButton
            addButton
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.bottom, 8)
    }

    private var settingsButton: some View {
        Button(action: { nav.pushView(.settings) }) {
            VStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.title)            // increased icon size
                Text("Settings")
                    .font(.subheadline)      // increased label size
            }
            .frame(maxWidth: .infinity, minHeight: 70)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.purple)
        .buttonBorderShape(.roundedRectangle)
        .controlSize(.large)
    }

    private var searchButton: some View {
        Button(action: { showingSearch = true }) {
            VStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.title)            // increased icon size
                Text("Search")
                    .font(.subheadline)      // increased label size
            }
            .frame(maxWidth: .infinity, minHeight: 70)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.9, green: 0.2, blue: 0.4))
        .buttonBorderShape(.roundedRectangle)
        .controlSize(.large)
    }

    private var addButton: some View {
        Button(action: { showingAdd = true }) {
            VStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)            // increased icon size
                Text("Add Note")
                    .font(.subheadline)      // increased label size
            }
            .frame(maxWidth: .infinity, minHeight: 70)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.green)
        .buttonBorderShape(.roundedRectangle)
        .controlSize(.large)
    }
}

struct NoteList: View {
    @Binding var currentFolder: String
    @ObservedObject var store: NoteStore

    var body: some View {
        List {
            if let folderNotes = store.notesByFolder[currentFolder] {
                ForEach(folderNotes.sorted(by: <), id: \.key) { noteBookTitle, _ in
                    NavigationLink(value: NavigationDestination.noteDetail(
                        folder: currentFolder,
                        noteTitle: noteBookTitle
                    )) {
                        Text(noteBookTitle)
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
    }
}
#endif
