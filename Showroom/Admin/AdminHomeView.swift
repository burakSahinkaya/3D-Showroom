import SwiftUI
import SwiftData

/// Yönetim ana ekranı.
struct AdminHomeView: View {
    @Query private var models: [Model3D]
    @Query(sort: \MaterialPreset.sortIndex) private var presets: [MaterialPreset]
    @Query(sort: \BackgroundItem.sortIndex) private var backgrounds: [BackgroundItem]

    @State private var regenProgress: (done: Int, total: Int)?

    var body: some View {
        NavigationStack {
            List {
                Section("Modeller") {
                    NavigationLink {
                        ImportModelsView()
                    } label: {
                        Label("Model Yükle", systemImage: "square.and.arrow.down")
                    }
                    NavigationLink {
                        AdminModelListView()
                    } label: {
                        Label("Model Listesi", systemImage: "list.bullet.rectangle")
                    }
                    NavigationLink {
                        FolderManageView()
                    } label: {
                        Label("Klasörler", systemImage: "folder")
                    }
                }

                Section("Kütüphaneler") {
                    NavigationLink {
                        PresetLibraryView()
                    } label: {
                        Label("Renk ve Doku Presetleri", systemImage: "paintpalette")
                    }
                    NavigationLink {
                        BackgroundLibraryView()
                    } label: {
                        Label("Arka Planlar", systemImage: "photo")
                    }
                    NavigationLink {
                        DisplaySettingsView()
                    } label: {
                        Label("Görüntüleme Ayarları", systemImage: "sun.max")
                    }
                }

                Section {
                    Button {
                        regenerateAllPreviews()
                    } label: {
                        if let progress = regenProgress {
                            Label("Önizlemeler yenileniyor… \(progress.done)/\(progress.total)",
                                  systemImage: "arrow.clockwise")
                        } else {
                            Label("Tüm Önizlemeleri Yenile", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(regenProgress != nil)
                } header: {
                    Text("Bakım")
                } footer: {
                    Text("Toplam \(models.count) model, \(presets.count) preset.")
                }
            }
            .navigationTitle("Yönetim")
        }
    }

    private func regenerateAllPreviews() {
        let targets = models
        guard !targets.isEmpty else { return }
        regenProgress = (0, targets.count)
        Task {
            for (index, model) in targets.enumerated() {
                let background = backgrounds.first { $0.id == model.backgroundID } ?? backgrounds.defaultItem
                await PreviewRenderer.shared.generateQueued(for: model,
                                                            presets: presets,
                                                            background: background)
                regenProgress = (index + 1, targets.count)
            }
            regenProgress = nil
        }
    }
}
