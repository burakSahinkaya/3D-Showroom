import SwiftUI
import SwiftData

/// Klasör oluşturma, yeniden adlandırma, sıralama ve silme.
struct FolderManageView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ModelFolder.sortIndex) private var folders: [ModelFolder]

    @State private var showAddAlert = false
    @State private var newFolderName = ""
    @State private var renamingFolder: ModelFolder?
    @State private var renameText = ""

    var body: some View {
        List {
            ForEach(folders) { folder in
                Button {
                    renamingFolder = folder
                    renameText = folder.name
                } label: {
                    HStack {
                        Label(folder.name, systemImage: "folder")
                        Spacer()
                        Text("\(folder.models.count) model")
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }
            .onDelete(perform: deleteFolders)
            .onMove(perform: moveFolders)
        }
        .navigationTitle("Klasörler")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newFolderName = ""
                    showAddAlert = true
                } label: {
                    Label("Ekle", systemImage: "plus")
                }
            }
        }
        .overlay {
            if folders.isEmpty {
                ContentUnavailableView(
                    "Klasör yok",
                    systemImage: "folder",
                    description: Text("Sağ üstteki + ile klasör oluşturun."))
            }
        }
        .alert("Yeni Klasör", isPresented: $showAddAlert) {
            TextField("Klasör adı", text: $newFolderName)
            Button("Ekle") { addFolder() }
            Button("Vazgeç", role: .cancel) {}
        }
        .alert("Klasörü Yeniden Adlandır",
               isPresented: Binding(
                   get: { renamingFolder != nil },
                   set: { if !$0 { renamingFolder = nil } })) {
            TextField("Klasör adı", text: $renameText)
            Button("Kaydet") {
                if let folder = renamingFolder, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    folder.name = renameText.trimmingCharacters(in: .whitespaces)
                    try? context.save()
                }
                renamingFolder = nil
            }
            Button("Vazgeç", role: .cancel) { renamingFolder = nil }
        }
    }

    private func addFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let nextIndex = (folders.map(\.sortIndex).max() ?? -1) + 1
        context.insert(ModelFolder(name: name, sortIndex: nextIndex))
        try? context.save()
    }

    private func deleteFolders(at offsets: IndexSet) {
        // Silinen klasördeki modeller "Klasörsüz" durumuna geçer (deleteRule .nullify).
        for index in offsets {
            context.delete(folders[index])
        }
        try? context.save()
    }

    private func moveFolders(from source: IndexSet, to destination: Int) {
        var reordered = folders
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, folder) in reordered.enumerated() {
            folder.sortIndex = index
        }
        try? context.save()
    }
}
