///
/// ContentView.swift
/// NotesDemo
///
/// The main content view of the NotesDemo application.
/// Presents the folder navigation, list of notes, and bottom toolbar,
/// and manages presentation of overlays for searching, adding notes,
/// switching folders, and recording audio notes.
///
import SwiftUI

/// The primary view for displaying and interacting with notes.
///
/// - Displays a header bar with the current folder name and folder picker.
/// - Shows a list of notes in the selected folder.
/// - Provides a bottom toolbar for settings, recording, search, and add-note actions.
/// - Manages full-screen and overlay presentations for auxiliary views.
struct ContentView: View {
    // MARK: - Navigation
    /// Shared navigation stack handler for pushing new view destinations.
    @ObservedObject private var nav = NavigationStackHandler.shared

    // MARK: - Shared Data Stores
    /// Central store holding all notes, keyed by folder.
    @EnvironmentObject private var store: NoteStore
    /// Store managing audio recordings.
    @EnvironmentObject private var recordingStore: RecordingStore

    // MARK: - Folder Picker State
    /// Available note folders (e.g., user categories).
    @State private var folders       = ["Notes", "Work", "Personal"]
    /// Currently selected folder name.
    @State private var currentFolder = "Notes"
    // MARK: - Overlay Presentation Flags
    /// Controls presentation of the search overlay.
    @State private var showingSearch   = false
    /// Controls presentation of the add-note overlay.
    @State private var showingAdd      = false
    /// Controls presentation of the folder selection overlay.
    @State private var showingFolders  = false
    /// Controls presentation of the full-screen recording view.
    @State private var showingRecorder = false

    // MARK: - View Body
    var body: some View {
        ZStack {
            // Main navigation stack
            NavigationStack(path: $nav.path) {
                VStack(spacing: 0) {
                    headerBar    // Top header with folder picker
                    NoteList(currentFolder: $currentFolder, store: store)
                    // notesList    // List of notes in folder
                    Spacer()
                    bottomButtons
                        .accessibilityHidden(showingAdd)
                        // Bottom toolbar for actions
                }
                .navigationBarHidden(true)
                // Define navigation destinations for pushing other views
                .navigationDestination(for: NavigationDestination.self) { destination in
                    destination.asView
                        .environmentObject(store)
                        .environmentObject(recordingStore)
                }
            }
            .environmentObject(store)
            .environmentObject(recordingStore)

            // Overlays for search, add-note, and folder selection
            if showingSearch {
                SearchOverlay(isPresented: $showingSearch)
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
        // Full-screen cover for audio recording
        .fullScreenCover(isPresented: $showingRecorder) {
            RecordingView(isPresented: $showingRecorder)
                .environmentObject(recordingStore)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header Bar
    /// A horizontal bar at the top displaying the folder picker and title.
    private var headerBar: some View {
        HStack {
            Button {
                // Open folder selection overlay
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

            // Maintain symmetrical layout
            Spacer().frame(width: 24)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Notes List
    /// A scrollable list of notes for the current folder.
//    private var notesList: some View {
//        List {
//            ForEach(store.notesByFolder[currentFolder] ?? [], id: \.id) { note in
//                NavigationLink(
//                    value: NavigationDestination.noteDetail(
//                        folder: currentFolder,
//                        noteTitle: note.title
//                    )
//                ) {
//                    Text(note.title)
//                        .font(.title2)
//                        .padding(.vertical, 6)
//                }
//                .listRowSeparator(.hidden)
//                .listRowBackground(Color.clear)
//            }
//            .onDelete(perform: deleteRows)
//        }
//        .listStyle(.plain)
//        .scrollContentBackground(.hidden)
//    }

    // MARK: - Bottom Toolbar
    /// A row of circular buttons for settings, recording, search, and add actions.
    private var bottomButtons: some View {
        HStack(spacing: 30) {
            CircleButton(image: "person", bg: .indigo,
                         accessibilityLabel: "Settings") {
                nav.pushView(.settings)
            }

            CircleButton(image: "mic", bg: .pink,
                         accessibilityLabel: "Record note") {
                showingRecorder = true
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


}

struct NoteList: View {
    @Binding var currentFolder: String
    @ObservedObject var store: NoteStore
    
    var body: some View {
        List {
            if let folderNotes = store.notesByFolder[currentFolder] {
                ForEach(folderNotes.sorted(by: <), id: \.key) { noteBookTitle, noteBook in
                    NavigationLink(
                        value: NavigationDestination.noteDetail(
                            folder: currentFolder,
                            noteTitle: noteBookTitle)
                    ) {
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
/// Preview provider for ContentView, injecting mock environment objects.
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(NoteStore())
            .environmentObject(RecordingStore())
    }
}
#endif
