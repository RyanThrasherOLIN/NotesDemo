// ContentView.swift

import SwiftUI

// MARK: - Global Button Tint Mapping
private enum BottomButton { case settings, search, add }
private func tintColor(for button: BottomButton) -> Color {
    let rawMode = UserDefaults.standard.string(forKey: "colorBlindMode")
                ?? ColorBlindMode.normal.rawValue
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
        case .settings: return Color(red: 0.56, green: 0.70, blue: 0.90)
        case .search:   return Color(red: 0.00, green: 0.62, blue: 0.46)
        case .add:      return Color(red: 0.94, green: 0.95, blue: 0.26)
        }
    case .deuteranopia:
        switch button {
        case .settings: return Color(red: 0.00, green: 0.45, blue: 0.70)
        case .search:   return Color(red: 0.84, green: 0.37, blue: 0.00)
        case .add:      return Color(red: 0.80, green: 0.47, blue: 0.65)
        }
    case .tritanopia:
        switch button {
        case .settings: return Color(red: 0.84, green: 0.37, blue: 0.00)
        case .search:   return Color(red: 0.90, green: 0.62, blue: 0.00)
        case .add:      return Color(red: 0.80, green: 0.47, blue: 0.65)
        }
    case .achromatopsia:
        switch button {
        case .settings: return .gray
        case .search:   return Color.gray.opacity(0.7)
        case .add:      return Color.gray.opacity(0.4)
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    // Shared stores
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var recordingStore: RecordingStore
    @EnvironmentObject private var nav: NavigationStackHandler

    // Folder picker
    @State private var folders = ["Notes", "Work", "Personal"]
    @State private var currentFolder = "Notes"

    // Overlays
    @State private var showingSearch = false
    @State private var showingAdd = false
    @State private var showingFolders = false

    // Tutorial popup
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var showingTutorial = false

    // Check if in normal mode for header styling
    private var isNormalMode: Bool {
        let raw = UserDefaults.standard.string(forKey: "colorBlindMode")
                  ?? ColorBlindMode.normal.rawValue
        return ColorBlindMode(rawValue: raw) == .normal
    }

    var body: some View {
        ZStack {
            ColorPalette.current.background
                .ignoresSafeArea()

            NavigationStack(path: $nav.path) {
                VStack(spacing: 0) {
                    headerBar
                    NoteList(currentFolder: $currentFolder)
                        .environmentObject(store)
                    Spacer(minLength: 0)
                    bottomButtons
                }
                .navigationBarHidden(true)
                .navigationDestination(for: NavigationDestination.self) { dest in
                    switch dest {
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

            // Tutorial popup
            if showingTutorial {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text("Welcome to NotesDemo!")
                            .font(.title2).bold()
                            .foregroundColor(ColorPalette.current.primary)
                        Text("""
• Tap + to add a new notebook
• Swipe to delete notebooks
• Use Search to find notes quickly
""")
                            .multilineTextAlignment(.leading)
                            .padding()
                            .foregroundColor(ColorPalette.current.primary)
                        Button("Got it!") {
                            hasSeenTutorial = true
                            showingTutorial = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ColorPalette.current.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal, 40)
                    .onAppear {
                        UIAccessibility.post(notification: .layoutChanged,
                                               argument: nil)
                    }
                }
            }
        }
        .onAppear {
            if !hasSeenTutorial {
                showingTutorial = true
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Button { showingFolders = true } label: {
                Image(systemName: "folder")
                    .font(.title)
            }
            .foregroundColor(isNormalMode ? .blue : ColorPalette.current.primary)
            .accessibilityLabel("Folders")

            Spacer()

            Text(currentFolder)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(isNormalMode ? .blue : ColorPalette.current.primary)

            Spacer()

            Button { nav.pushView(.settings) } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title)
            }
            .foregroundColor(isNormalMode ? .blue : ColorPalette.current.primary)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            Button { showingSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor(for: .search))

            Button { showingAdd = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 50))
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor(for: .add))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - NoteList
struct NoteList: View {
    @Binding var currentFolder: String
    @EnvironmentObject private var store: NoteStore

    private var isNormalMode: Bool {
        let raw = UserDefaults.standard.string(forKey: "colorBlindMode")
                  ?? ColorBlindMode.normal.rawValue
        return ColorBlindMode(rawValue: raw) == .normal
    }

    init(currentFolder: Binding<String>) {
        self._currentFolder = currentFolder
    }

    var body: some View {
        List {
            if let folderMap = store.notesByFolder[currentFolder] {
                ForEach(folderMap.keys.sorted(), id: \ .self) { title in
                    NavigationLink(value: NavigationDestination.noteDetail(
                        folder: currentFolder,
                        noteTitle: title
                    )) {
                        Text(title)
                            .font(.title2)
                            .padding(.vertical, 6)
                            .foregroundColor(isNormalMode ? .black : ColorPalette.current.primary)
                    }
                    .swipeActions(edge: .trailing) {
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

// MARK: - Preview
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
