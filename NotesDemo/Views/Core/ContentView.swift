import SwiftUI
import AVFoundation

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

    // Tutorial flags
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage("alwaysShowTutorial") private var alwaysShowTutorial = false
    @State private var showingTutorial = false

    private var isNormalMode: Bool {
        ColorBlindMode(rawValue: UserDefaults.standard.string(forKey: "colorBlindMode") ?? ColorBlindMode.normal.rawValue) == .normal
    }

    var body: some View {
        ZStack {
            ColorPalette.current.background.ignoresSafeArea()

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
            .onAppear {
                if alwaysShowTutorial || !hasSeenTutorial {
                    showingTutorial = true
                }
            }

            // Overlays
            if showingSearch {
                SearchOverlay(isPresented: $showingSearch)
                    .environmentObject(store)
                    .environmentObject(recordingStore)
                    .environmentObject(nav)
            }
            if showingAdd {
                AddNoteOverlay(isPresented: $showingAdd) { title in
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    store.addNoteBook(title: t, to: currentFolder)
                }
                .environmentObject(store)
            }
            if showingFolders {
                FolderOverlay(isPresented: $showingFolders, selectedFolder: $currentFolder, folders: $folders)
                    .environmentObject(store)
            }

            if showingTutorial {
                TutorialView(showingTutorial: $showingTutorial)
            }
        }
    }

    // MARK: Header Bar
    private var headerBar: some View {
        HStack {
            Button { showingFolders = true } label: { Image(systemName: "folder").font(.title) }
                .foregroundColor(isNormalMode ? .blue : ColorPalette.current.primary)
                .accessibilityLabel("Folders")
            Spacer()
            Text(currentFolder)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(isNormalMode ? .blue : ColorPalette.current.primary)
            Spacer()
            Button { nav.pushView(.settings) } label: { Image(systemName: "gearshape.fill").font(.title) }
                .foregroundColor(isNormalMode ? .blue : ColorPalette.current.primary)
                .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            Button { showingSearch = true } label: { Image(systemName: "magnifyingglass").font(.system(size: 50)).frame(maxWidth: .infinity, minHeight: 80) }
                .buttonStyle(.borderedProminent).tint(tintColor(for: .search))
            Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill").font(.system(size: 50)).frame(maxWidth: .infinity, minHeight: 80) }
                .buttonStyle(.borderedProminent).tint(tintColor(for: .add))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: TutorialView
struct TutorialView: View {
    @Binding var showingTutorial: Bool
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var currentPage = 0

    private let pages = [
        TutorialPage(image: "plus.circle.fill", title: "Add Notebook", description: "Tap the + button to create a new notebook."),
        TutorialPage(image: "trash", title: "Delete Notebook", description: "Swipe left on a notebook to delete it."),
        TutorialPage(image: "magnifyingglass", title: "Search Notes", description: "Tap the Search icon to quickly find notes."),
        TutorialPage(image: "folder", title: "Organization", description: "Notes are organized into Folders → Notebooks → Notes for easy management."),
        TutorialPage(image: "magnifyingglass.circle", title: "Search Behavior", description: "Search uses AI similarity to fetch the existing note that best matches your question—no new text is generated."),
    ]

    var body: some View {
        ZStack {
            // White blur full-screen background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            // Tutorial card
            VStack(spacing: 20) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 12) {
                            Image(systemName: pages[i].image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(ColorPalette.current.accent)

                            Text(pages[i].title)
                                .font(.title3).bold()
                                .foregroundColor(ColorPalette.current.primary)
                                .accessibilityAddTraits(.isHeader)

                            Text(pages[i].description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(ColorPalette.current.primary)
                                .accessibilityLabel(pages[i].description)
                        }
                        .tag(i)
                        .accessibilityElement(children: .combine)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 200)

                // Page Indicators
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { idx in
                        Capsule()
                            .fill(idx == currentPage ? ColorPalette.current.accent : Color.gray.opacity(0.4))
                            .frame(width: idx == currentPage ? 20 : 6, height: 6)
                    }
                }
                .accessibilityHidden(true)

                // Controls
                HStack {
                    if currentPage < pages.count - 1 {
                        Button(action: finish) {
                            Text("Skip")
                                .font(.body)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Skip tutorial")

                        Spacer()

                        Button(action: { currentPage += 1 }) {
                            Text("Next")
                                .font(.body)
                                .bold()
                                .frame(minWidth: 60, minHeight: 32)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ColorPalette.current.accent)
                        .accessibilityLabel("Next tutorial page")
                    } else {
                        Button(action: finish) {
                            Text("Done")
                                .font(.body)
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ColorPalette.current.accent)
                        .accessibilityLabel("Finish tutorial")
                    }
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.9))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func finish() {
        hasSeenTutorial = true
        showingTutorial = false
    }
}

// MARK: TutorialPage
private struct TutorialPage {
    let image: String
    let title: String
    let description: String
}

// MARK: NoteList
struct NoteList: View {
    @Binding var currentFolder: String
    @EnvironmentObject private var store: NoteStore

    private var isNormalMode: Bool {
        ColorBlindMode(rawValue: UserDefaults.standard.string(forKey: "colorBlindMode") ?? ColorBlindMode.normal.rawValue) == .normal
    }

    var body: some View {
        List {
            if let map = store.notesByFolder[currentFolder] {
                ForEach(map.keys.sorted(), id: \ .self) { title in
                    NavigationLink(value: NavigationDestination.noteDetail(folder: currentFolder, noteTitle: title)) {
                        Text(title)
                            .font(.title2)
                            .padding(.vertical, 6)
                            .foregroundColor(isNormalMode ? .black : ColorPalette.current.primary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { store.deleteNoteBook(title: title, in: currentFolder) }
                        label: { Label("Delete", systemImage: "trash") }
                        .tint(tintColor(for: .settings))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
