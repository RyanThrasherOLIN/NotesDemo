import SwiftUI

enum NavigationDestination: Hashable {
    case noteDetail(note: String)
    case settings

    @ViewBuilder
    var asView: some View {
        switch self {
        case let .noteDetail(note):
            NoteDetailView(note: note)
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
