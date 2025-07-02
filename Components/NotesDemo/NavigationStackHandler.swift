import SwiftUI

enum NavigationDestination: Hashable {
    case noteDetail(folder: String, noteTitle: String)
    case settings

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

final class NavigationStackHandler: ObservableObject {
    static let shared = NavigationStackHandler()
    @Published var path = NavigationPath()
    private init() {}

    func pushView(_ destination: NavigationDestination) {
        path.append(destination)
    }

    func popView() {
        path.removeLast()
    }
}
