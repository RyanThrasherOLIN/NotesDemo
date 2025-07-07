///
/// Navigation.swift
/// NotesDemo
///
/// Defines destinations for navigation and manages a shared navigation stack handler.
/// Enables type-safe view routing within a SwiftUI NavigationStack.
///
import SwiftUI

/// Enumerates all possible navigation destinations in the app.
///
/// Conforms to `Hashable` for use in `NavigationPath`.
enum NavigationDestination: Hashable {
    /// Detail view for a specific note within a folder.
    /// - `folder`: the folder containing the note.
    /// - `noteTitle`: the title (and storage key) of the note.
    case noteDetail(folder: String, noteTitle: String)
    /// Settings screen.
    case settings

    /// Converts each destination case into its corresponding SwiftUI view.
    ///
    /// - Note: Ensures that environment objects are injected at the call site.
    @ViewBuilder
    var asView: some View {
        switch self {
        case let .noteDetail(folder, noteTitle):
            NoteDetailView(folder: folder, noteTitle: noteTitle)
        case .settings:
            SettingsView()
        }
    }
}

/// Singleton handler for managing a `NavigationStack` path.
///
/// Provides methods to push and pop `NavigationDestination` values.
/// Observed by the root `ContentView` to control navigation.
final class NavigationStackHandler: ObservableObject {
    /// Shared single instance of the handler.
    static let shared = NavigationStackHandler()

    /// Published navigation path representing the current stack of destinations.
    @Published var path = NavigationPath()

    /// Private initializer to enforce singleton usage.
    private init() {}

    /// Pushes a new destination onto the navigation stack.
    ///
    /// - Parameter destination: The `NavigationDestination` to navigate to.
    func pushView(_ destination: NavigationDestination) {
        path.append(destination)
    }

    /// Pops the last destination off the navigation stack.
    ///
    /// If the stack is empty, no action is taken.
    func popView() {
        path.removeLast()
    }
}
