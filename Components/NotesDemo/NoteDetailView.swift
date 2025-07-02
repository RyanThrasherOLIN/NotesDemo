// NoteDetailView.swift
// NotesDemo

import SwiftUI

struct NoteDetailView: View {
    // Now receive both folder and noteTitle
    let folder: String
    let noteTitle: String

    @EnvironmentObject private var hiddenStore: HiddenLineStore
    @State private var draftTitle: String
    @State private var draftBody: String
    @FocusState private var bodyFocused: Bool

    init(folder: String, noteTitle: String) {
        self.folder = folder
        self.noteTitle = noteTitle
        // Initialize title and body from stored values
        _draftTitle = State(initialValue: noteTitle)
        let savedBody = UserDefaults.standard.string(forKey: noteTitle) ?? ""
        _draftBody = State(initialValue: savedBody)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Editable note title
            TextField("Title", text: $draftTitle)
                .font(.largeTitle.bold())
                .submitLabel(.done)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .accessibilityLabel("Title here")

            Divider()

            // Editable note body with placeholder
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
                        // Always save locally under the updated title key
                        UserDefaults.standard.set(newBody, forKey: draftTitle)

                        // Sync new lines on newline
                        if newBody.last == "\n" {
                            let lines = newBody
                                .components(separatedBy: .newlines)
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { $0.count > 1 }

                            hiddenStore.sync(
                                lines,
                                folder: folder,
                                notebook: draftTitle
                            )
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
            let lines = draftBody
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count > 1 }

            hiddenStore.sync(
                lines,
                folder: folder,
                notebook: draftTitle
            )
            UserDefaults.standard.set(draftBody, forKey: draftTitle)
        }
    }
}

#if DEBUG
struct NoteDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NoteDetailView(folder: "default", noteTitle: "Demo Note")
                .environmentObject(HiddenLineStore())
        }
    }
}
#endif
