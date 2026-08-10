import SwiftUI
import SwiftData

/// Ana sayfa: model klasörleri. Dikeyde 2, yatayda 4 sütun.
struct ShowroomHomeView: View {
    @Query(sort: \ModelFolder.sortIndex) private var folders: [ModelFolder]
    @Query private var models: [Model3D]

    private var unfiledModels: [Model3D] {
        models.filter { $0.folder == nil }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let columnCount = geo.size.width > geo.size.height ? 4 : 2
                let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: columnCount)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(folders) { folder in
                            NavigationLink {
                                FolderDetailView(folder: folder)
                            } label: {
                                FolderCard(title: folder.name,
                                           models: models.filter { $0.folder?.id == folder.id })
                            }
                            .buttonStyle(.plain)
                        }
                        if !unfiledModels.isEmpty {
                            NavigationLink {
                                FolderDetailView(folder: nil)
                            } label: {
                                FolderCard(title: "Diğer", models: unfiledModels)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Showroom")
            .overlay {
                if models.isEmpty && folders.isEmpty {
                    ContentUnavailableView(
                        "Henüz model yok",
                        systemImage: "cube.transparent",
                        description: Text("Yönetim sekmesinden klasör oluşturup model yükleyin."))
                }
            }
        }
    }
}

private struct FolderCard: View {
    let title: String
    let models: [Model3D]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let first = models.first {
                    PreviewImage(model: first, presetID: first.defaultPresetID)
                } else {
                    Rectangle().fill(Color(uiColor: .secondarySystemBackground))
                    Image(systemName: "folder")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                }
            }
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(models.count) model")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3))
    }
}
