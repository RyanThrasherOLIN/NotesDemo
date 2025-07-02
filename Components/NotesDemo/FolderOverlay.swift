import SwiftUI

struct FolderOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedFolder: String
    @Binding var folders: [String]
    @State private var newFolderName: String = ""

    var body: some View {
        ZStack {
            // Full screen blurred background
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Main overlay card
            VStack(spacing: 20) {
                Text("Folders")
                    .font(.largeTitle.bold())

                // Folder list with delete support
                List {
                    ForEach(folders, id: \.self) { folder in
                        Button(action: {
                            selectedFolder = folder
                            isPresented = false
                        }) {
                            HStack {
                                Text(folder)
                                    .font(.title2)
                                Spacer()
                                if folder == selectedFolder {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let folder = folders[index]
                            if selectedFolder == folder {
                                selectedFolder = folders.first(where: { $0 != folder }) ?? ""
                            }
                            folders.remove(at: index)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .listStyle(PlainListStyle())

                // New folder input
                HStack {
                    TextField("New folder", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                    Button(action: {
                        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty, !folders.contains(trimmed) else { return }
                        folders.append(trimmed)
                        newFolderName = ""
                    }) {
                        Text("Add")
                            .font(.title3.bold())
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(20)
            .padding(30)
        }
    }
}

#if DEBUG
struct FolderOverlay_Previews: PreviewProvider {
    static var previews: some View {
        FolderOverlay(
            isPresented: .constant(true),
            selectedFolder: .constant("Notes"),
            folders: .constant(["Notes", "Work", "Personal"]))
    }
}
#endif
