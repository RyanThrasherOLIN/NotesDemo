//  AddNoteOverlay.swift
//  NotesDemo
//
//  Simple modal that returns a single note via onSubmit
//

import SwiftUI

struct AddNoteOverlay: View {
    @Binding var isPresented: Bool
    var onSubmit: (String) -> Void

    @State private var draft = ""

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                // top actions
                HStack {
                    Button("Cancel") { isPresented = false }
                    Spacer()
                    Button("Save") {
                        commitAndDismiss()
                    }
                    .fontWeight(.bold)
                }
                .padding(.horizontal)

                // text field
                TextField("Type a new note…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .submitLabel(.done)
                    .onSubmit { commitAndDismiss() }
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)
            .padding()
        }
    }

    private func commitAndDismiss() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { onSubmit(trimmed) }
        isPresented = false
    }
}


#if DEBUG
struct AddNoteOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            AddNoteOverlay(isPresented: .constant(true)) { _ in }
        }
    }
}
#endif
