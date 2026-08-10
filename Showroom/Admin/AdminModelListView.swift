import SwiftUI
import SwiftData

/// Model listesi: arama, klasör/etiket filtresi, çoklu seçimle toplu silme/taşıma.
struct AdminModelListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Model3D.createdAt, order: .reverse) private var models: [Model3D]
    @Query(sort: \ModelFolder.sortIndex) private var folders: [ModelFolder]

    @State private var searchText = ""
    @State private var folderFilterID: UUID?
    @State private var filterUnfiled = false
    @State private var tagFilter: String?
    @State private var selection = Set<UUID>()
    @State private var editMode: EditMode = .inactive
    @State private var confirmBulkDelete = false

    private var filteredModels: [Model3D] {
        models.filter { model in
            if !searchText.isEmpty && !model.name.localizedCaseInsensitiveContains(searchText) {
                return false
            }
            if filterUnfiled && model.folder != nil {
                return false
            }
            if let folderFilterID, model.folder?.id != folderFilterID {
                return false
            }
            if let tagFilter, !model.tags.contains(tagFilter) {
                return false
            }
            return true
        }
    }

    private var allTags: [String] {
        Array(Set(models.flatMap(\.tags))).sorted()
    }

    var body: some View {
        List(selection: $selection) {
            ForEach(filteredModels) { model in
                NavigationLink {
                    ModelEditView(model: model)
                } label: {
                    HStack(spacing: 12) {
                        PreviewImage(model: model, presetID: model.defaultPresetID)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.name)
                                .font(.body)
                            HStack(spacing: 6) {
                                Text(model.folder?.name ?? "Klasörsüz")
                                if !model.tags.isEmpty {
                                    Text("• " + model.tags.joined(separator: ", "))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        delete(model)
                    } label: {
                        Label("Sil", systemImage: "trash")
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .searchable(text: $searchText, prompt: "Model ara")
        .navigationTitle("Model Listesi")
        .overlay {
            if filteredModels.isEmpty {
                ContentUnavailableView("Model bulunamadı", systemImage: "cube.transparent")
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(editMode.isEditing ? "Bitti" : "Seç") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                        selection.removeAll()
                    }
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                if editMode.isEditing {
                    Text("\(selection.count) seçili")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu("Taşı") {
                        Button("Klasörsüz") { moveSelection(to: nil) }
                        ForEach(folders) { folder in
                            Button(folder.name) { moveSelection(to: folder) }
                        }
                    }
                    .disabled(selection.isEmpty)
                    Button("Sil", role: .destructive) {
                        confirmBulkDelete = true
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
        .confirmationDialog("\(selection.count) model silinsin mi? Bu işlem geri alınamaz.",
                            isPresented: $confirmBulkDelete,
                            titleVisibility: .visible) {
            Button("Sil", role: .destructive) { deleteSelection() }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Klasör") {
                Button {
                    folderFilterID = nil
                    filterUnfiled = false
                } label: {
                    labelRow("Tümü", selected: folderFilterID == nil && !filterUnfiled)
                }
                Button {
                    folderFilterID = nil
                    filterUnfiled = true
                } label: {
                    labelRow("Klasörsüz", selected: filterUnfiled)
                }
                ForEach(folders) { folder in
                    Button {
                        folderFilterID = folder.id
                        filterUnfiled = false
                    } label: {
                        labelRow(folder.name, selected: folderFilterID == folder.id)
                    }
                }
            }
            if !allTags.isEmpty {
                Section("Etiket") {
                    Button {
                        tagFilter = nil
                    } label: {
                        labelRow("Tümü", selected: tagFilter == nil)
                    }
                    ForEach(allTags, id: \.self) { tag in
                        Button {
                            tagFilter = tag
                        } label: {
                            labelRow(tag, selected: tagFilter == tag)
                        }
                    }
                }
            }
        } label: {
            Label("Filtre", systemImage: "line.3.horizontal.decrease.circle")
        }
    }

    @ViewBuilder
    private func labelRow(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    private func delete(_ model: Model3D) {
        FileStore.deleteModelData(fileName: model.fileName, modelID: model.id)
        context.delete(model)
        try? context.save()
    }

    private func deleteSelection() {
        for model in models where selection.contains(model.id) {
            FileStore.deleteModelData(fileName: model.fileName, modelID: model.id)
            context.delete(model)
        }
        selection.removeAll()
        try? context.save()
    }

    private func moveSelection(to folder: ModelFolder?) {
        for model in models where selection.contains(model.id) {
            model.folder = folder
        }
        selection.removeAll()
        try? context.save()
    }
}
