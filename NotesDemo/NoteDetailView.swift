import SwiftUI

struct NoteDetailView: View {
    let note: String

    @EnvironmentObject private var hiddenStore: HiddenLineStore
    @State private var draftTitle: String
    @State private var draftBody: String
    @FocusState private var bodyFocused: Bool

    init(note: String) {
        self.note = note
        _draftTitle = State(initialValue: note)
        let saved = UserDefaults.standard.string(forKey: note) ?? ""
        _draftBody = State(initialValue: saved)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title field with accessibility label
            TextField("Title", text: $draftTitle)
                .font(.largeTitle.bold())
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Title here")

            Divider()

            // Note body with placeholder and TextEditor
            ZStack(alignment: .topLeading) {
                if draftBody.isEmpty {
                    Text("Add note here…")
                        .foregroundColor(.gray)
                        .padding(8)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draftBody)
                    .focused($bodyFocused)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .onChange(of: draftBody) { newBody in
                        // always save locally
                        UserDefaults.standard.set(newBody, forKey: note)

                        // only sync when the user just hit Return
                        if newBody.last == "\n" {
                            let lines = newBody
                                .components(separatedBy: .newlines)
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                // skip any stray 1-character lines
                                .filter { $0.count > 1 }

                            hiddenStore.sync(lines)
                        }
                    }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Note here")
            .frame(minHeight: 200)

            Spacer()
        }
        .padding()
        .navigationTitle(draftTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { bodyFocused = true }
        .onDisappear {
            // final push of any full lines left when closing
            let lines = draftBody
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 1 }

            hiddenStore.sync(lines)
            UserDefaults.standard.set(draftBody, forKey: note)
        }
    }
}

#if DEBUG
struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NoteDetailView(note: "Demo Note")
                .environmentObject(HiddenLineStore())
        }
    }
}
#endif
