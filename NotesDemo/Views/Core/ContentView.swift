// ContentView.swift
// NotesDemo
//
// The main content view of the NotesDemo application, now with a first-launch tutorial popup
// and palette-adapted colors from ColorPalette.

import SwiftUI

// MARK: - Global Button Tint Mapping
private enum BottomButton { case settings, search, add }
private func tintColor(for button: BottomButton) -> Color {
    let rawMode = UserDefaults.standard.string(forKey: "colorBlindMode") ?? ColorBlindMode.normal.rawValue
    let mode = ColorBlindMode(rawValue: rawMode) ?? .normal
    switch mode {
    case .normal:
        switch button {
        case .settings: return .purple
        case .search:   return .pink
        case .add:      return .green
        }
    case .protanopia:
        switch button {
        case .settings: return Color(red: 0.0, green: 0.45, blue: 0.70) // #0072B2
        case .search:   return Color(red: 0.00, green: 0.62, blue: 0.46) // #009E73
        case .add:      return Color(red: 0.94, green: 0.95, blue: 0.26) // #F0E442
        }
    case .deuteranopia:
        switch button {
        case .settings: return Color(red: 0.00, green: 0.45, blue: 0.70) // #0072B2
        case .search:   return Color(red: 0.84, green: 0.37, blue: 0.00) // #D55E00
        case .add:      return Color(red: 0.80, green: 0.47, blue: 0.65) // #CC79A7
        }
    case .tritanopia:
        switch button {
        case .settings: return Color(red: 0.84, green: 0.37, blue: 0.00) // #D55E00
        case .search:   return Color(red: 0.90, green: 0.62, blue: 0.00) // #E69F00
        case .add:      return Color(red: 0.80, green: 0.47, blue: 0.65) // #CC79A7
        }
    case .achromatopsia:
        switch button {
        case .settings: return .gray
        case .search:   return Color.gray.opacity(0.7)
        case .add:      return Color.gray.opacity(0.4)
        }
    }
}

struct ContentView: View {
    // ─── Shared Stores ───────────────────────────────────────
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var nav: NavigationStackHandler

    // ─── Folder Picker State ─────────────────────────────────
    @State private var folders       = ["Notes", "Work", "Personal"]
    @State private var currentFolder = "Notes"

    // ─── Overlay Flags ───────────────────────────────────────
    @State private var showingSearch   = false
    @State private var showingAdd      = false
    @State private var showingFolders  = false

    // ─── Tutorial Popup State ───────────────────────────────
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial: Bool = false
    @State private var showingTutorial: Bool = false

    var body: some View {
        ZStack {
            // Background from palette
            ColorPalette.current.background
                .ignoresSafeArea()

            // Main navigation
            NavigationStack(path: $nav.path) {
                VStack(spacing: 0) {
                    headerBar
                    NoteList(currentFolder: $currentFolder)
                        .environmentObject(store)
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
                    }
                }
            }
            .accessibilityHidden(showingSearch || showingTutorial)

            // Overlays
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
                FolderOverlay(isPresented: $showingFolders,
                              selectedFolder: $currentFolder,
                              folders: $folders)
                    .environmentObject(store)
            }

            // Tutorial Overlay
            if showingTutorial {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Welcome to NotesDemo!")
                        .font(.title2).bold()
                        .foregroundColor(ColorPalette.current.primary)
                    Text("• Tap + to add a new notebook\n• Swipe to delete notebooks\n• Use Search to find notes quickly")
                        .multilineTextAlignment(.leading)
                        .padding()
                        .foregroundColor(ColorPalette.current.primary)
                    Button(action: {
                        hasSeenTutorial = true
                        showingTutorial = false
                    }) {
                        Text("Got it!")
                            .fontWeight(.semibold)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ColorPalette.current.accent)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .padding(.horizontal, 40)
                .onAppear {
                    UIAccessibility.post(notification: .layoutChanged, argument: nil)
                }
            }
        }
        .onAppear {
            if !hasSeenTutorial {
                showingTutorial = true
            }
        }
    }

    // MARK: – Header Bar
    private var headerBar: some View {
        HStack {
            Button {
                showingFolders = true
            } label: {
                Image(systemName: "folder")
                    .font(.title2)
            }
            .foregroundColor(ColorPalette.current.primary)

            Spacer()

            Text(currentFolder)
                .font(.largeTitle.bold())
                .foregroundColor(ColorPalette.current.primary)
                .frame(maxWidth: .infinity)

            Spacer().frame(width: 24)
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: – Bottom Toolbar
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            Button { nav.pushView(.settings) } label: {
                VStack(spacing: 6) {
                    Image(systemName: "person.fill").font(.title)
                    Text("User Settings").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor(for: .settings))

            Button { showingSearch = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").font(.title)
                    Text("Search Notes").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor(for: .search))

            Button { showingAdd = true } label: {
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.title)
                    Text("Add Notebook").font(.subheadline)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor(for: .add))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct NoteList: View {
    @Binding var currentFolder: String
    @EnvironmentObject private var store: NoteStore

    init(currentFolder: Binding<String>) {
        self._currentFolder = currentFolder
    }

    var body: some View {
        List {
            if let folderNotes = store.notesByFolder[currentFolder] {
                let sorted = folderNotes.sorted { $0.key < $1.key }
                ForEach(sorted, id: \.key) { title, _ in
                    NavigationLink(
                        value: NavigationDestination.noteDetail(
                            folder: currentFolder,
                            noteTitle: title
                        )
                    ) {
                        Text(title)
                            .font(.title2)
                            .padding(.vertical, 6)
                            .foregroundColor(ColorPalette.current.primary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            store.deleteNoteBook(title: title, in: currentFolder)
                        } label: {
                            Label("Delete Notebook", systemImage: "trash")
                        }
                        .tint(tintColor(for: .settings))
                    }
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
