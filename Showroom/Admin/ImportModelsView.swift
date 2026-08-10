import SwiftUI
import SwiftData
import RealityKit
import UniformTypeIdentifiers

/// Files'tan çoklu USDZ seçip içe aktarma ekranı.
struct ImportModelsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ModelFolder.sortIndex) private var folders: [ModelFolder]
    @Query(sort: \MaterialPreset.sortIndex) private var presets: [MaterialPreset]
    @Query(sort: \BackgroundItem.sortIndex) private var backgrounds: [BackgroundItem]

    @State private var selectedFolderID: UUID?
    @State private var showPicker = false
    @State private var importing = false
    @State private var items: [ImportItem] = []

    struct ImportItem: Identifiable {
        let id = UUID()
        let name: String
        var status: Status

        enum Status {
            case copying
            case analyzing
            case rendering(Int, Int)
            case done
            case failed(String)
        }
    }

    var body: some View {
        Form {
            Section("Hedef Klasör") {
                Picker("Klasör", selection: $selectedFolderID) {
                    Text("Klasörsüz").tag(UUID?.none)
                    ForEach(folders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
            }

            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("USDZ Dosyaları Seç", systemImage: "square.and.arrow.down")
                }
                .disabled(importing)
            } footer: {
                Text("Files veya iCloud Drive'dan bir ya da birden fazla .usdz dosyası seçebilirsiniz. Her model için tüm renk önizlemeleri otomatik üretilir.")
            }

            if !items.isEmpty {
                Section("Durum") {
                    ForEach(items) { item in
                        HStack {
                            Text(item.name)
                                .lineLimit(1)
                            Spacer()
                            statusView(for: item.status)
                        }
                    }
                }
            }
        }
        .navigationTitle("Model Yükle")
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: [.usdz],
                      allowsMultipleSelection: true) { result in
            Task { await handle(result) }
        }
    }

    @ViewBuilder
    private func statusView(for status: ImportItem.Status) -> some View {
        switch status {
        case .copying:
            Text("Kopyalanıyor…").foregroundStyle(.secondary)
        case .analyzing:
            Text("İnceleniyor…").foregroundStyle(.secondary)
        case .rendering(let done, let total):
            Text("Önizleme \(done)/\(total)").foregroundStyle(.secondary)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed(let message):
            Text("Hata: \(message)")
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    private func handle(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result else { return }
        importing = true
        defer { importing = false }

        for url in urls {
            let index = items.count
            items.append(ImportItem(name: url.lastPathComponent, status: .copying))
            do {
                let fileName = try FileStore.importModelFile(from: url)
                items[index].status = .analyzing

                let root = try await Entity(contentsOf: FileStore.modelURL(fileName))
                let parts = EntityTools.collectParts(of: root)
                let dims = EntityTools.sizeCM(of: root)

                let model = Model3D(name: url.deletingPathExtension().lastPathComponent,
                                    fileName: fileName)
                model.realWidthCM = max((dims.x).rounded(), 1)
                model.realHeightCM = max((dims.y).rounded(), 1)
                model.realDepthCM = max((dims.z * 10).rounded() / 10, 0.1)
                model.minWidthCM = max((model.realWidthCM * 0.5).rounded(), 1)
                model.maxWidthCM = (model.realWidthCM * 1.5).rounded()
                model.minHeightCM = max((model.realHeightCM * 0.5).rounded(), 1)
                model.maxHeightCM = (model.realHeightCM * 1.5).rounded()
                model.partNames = parts.map(\.name)
                model.paintableParts = model.partNames
                model.folder = folders.first { $0.id == selectedFolderID }
                context.insert(model)
                try? context.save()

                items[index].status = .rendering(0, presets.count + 1)
                let background = backgrounds.first { $0.id == model.backgroundID } ?? backgrounds.first
                await PreviewRenderer.shared.generateQueued(for: model,
                                                            presets: presets,
                                                            background: background) { done, total in
                    items[index].status = .rendering(done, total)
                }
                items[index].status = .done
            } catch {
                items[index].status = .failed(error.localizedDescription)
            }
        }
    }
}
