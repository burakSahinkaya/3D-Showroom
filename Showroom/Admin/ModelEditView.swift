import SwiftUI
import SwiftData
import RealityKit

/// Tek modelin tüm ayarları: ad, klasör, etiketler, ölçüler, boyanabilir parçalar,
/// varsayılan renk, izinli renkler, arka plan ve silme.
struct ModelEditView: View {
    @Bindable var model: Model3D

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ModelFolder.sortIndex) private var folders: [ModelFolder]
    @Query(sort: \MaterialPreset.sortIndex) private var presets: [MaterialPreset]
    @Query(sort: \BackgroundItem.sortIndex) private var backgrounds: [BackgroundItem]

    @State private var tagsText = ""
    @State private var regenBusy = false
    @State private var rescanBusy = false
    @State private var confirmDelete = false

    var body: some View {
        Form {
            Section("Önizleme") {
                HStack(alignment: .top, spacing: 16) {
                    PreviewImage(model: model, presetID: model.defaultPresetID)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            regeneratePreviews()
                        } label: {
                            if regenBusy {
                                HStack {
                                    ProgressView()
                                    Text("Üretiliyor…")
                                }
                            } else {
                                Label("Önizlemeleri Yenile", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(regenBusy)
                        Text("Arka plan veya boyanabilir parça ayarını değiştirdikten sonra yenileyin.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Bilgiler") {
                TextField("Ad", text: $model.name)
                Picker("Klasör", selection: folderBinding) {
                    Text("Klasörsüz").tag(UUID?.none)
                    ForEach(folders) { folder in
                        Text(folder.name).tag(Optional(folder.id))
                    }
                }
                TextField("Etiketler (virgülle ayırın)", text: $tagsText)
                    .autocorrectionDisabled()
                    .onChange(of: tagsText) {
                        model.tags = tagsText
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    }
                TextField("Açıklama", text: $model.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Gerçek Ölçüler (cm)") {
                dimensionField("En", value: $model.realWidthCM)
                dimensionField("Boy", value: $model.realHeightCM)
                dimensionField("Derinlik", value: $model.realDepthCM)
            }

            Section("Ölçü Aralığı (cm)") {
                dimensionField("En – en az", value: $model.minWidthCM)
                dimensionField("En – en çok", value: $model.maxWidthCM)
                dimensionField("Boy – en az", value: $model.minHeightCM)
                dimensionField("Boy – en çok", value: $model.maxHeightCM)
            }

            Section("Görsel Ayarlar") {
                Picker("Varsayılan Renk", selection: $model.defaultPresetID) {
                    Text("Orijinal").tag(UUID?.none)
                    ForEach(presets) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                }
                Picker("Arka Plan", selection: $model.backgroundID) {
                    Text("Varsayılan").tag(UUID?.none)
                    ForEach(backgrounds) { background in
                        Text(background.name).tag(Optional(background.id))
                    }
                }
            }

            Section {
                Toggle("Tüm renkler kullanılabilir", isOn: allPresetsAllowedBinding)
                if !model.allowedPresetIDs.isEmpty || !allPresetsAllowedBinding.wrappedValue {
                    ForEach(presets) { preset in
                        Toggle(preset.name, isOn: allowedPresetBinding(preset.id))
                    }
                }
            } header: {
                Text("İzinli Renkler")
            } footer: {
                Text("Kapalıyken bu modelde yalnızca işaretli renkler gösterilir.")
            }

            Section {
                if model.partNames.isEmpty {
                    Text("Parça bilgisi yok. \"Parçaları Yeniden Tara\" ile deneyin.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.partNames, id: \.self) { name in
                        Toggle(name, isOn: paintablePartBinding(name))
                    }
                }
                Button {
                    rescanParts()
                } label: {
                    if rescanBusy {
                        HStack {
                            ProgressView()
                            Text("Taranıyor…")
                        }
                    } else {
                        Label("Parçaları Yeniden Tara", systemImage: "magnifyingglass")
                    }
                }
                .disabled(rescanBusy)
            } header: {
                Text("Boyanabilir Parçalar")
            } footer: {
                Text("Camlı kapaklarda cam parçasının işaretini kaldırın; renk yalnızca işaretli parçalara uygulanır.")
            }

            Section {
                Button("Modeli Sil", role: .destructive) {
                    confirmDelete = true
                }
            }
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tagsText = model.tags.joined(separator: ", ")
        }
        .onDisappear {
            try? context.save()
        }
        .confirmationDialog("\"\(model.name)\" silinsin mi? Bu işlem geri alınamaz.",
                            isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Sil", role: .destructive) { deleteModel() }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    // MARK: Alt görünümler

    private func dimensionField(_ title: String, value: Binding<Double>) -> some View {
        LabeledContent(title) {
            TextField(title, value: value, format: .number)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .frame(maxWidth: 120)
        }
    }

    // MARK: Bindings

    private var folderBinding: Binding<UUID?> {
        Binding(
            get: { model.folder?.id },
            set: { newValue in
                model.folder = folders.first { $0.id == newValue }
            })
    }

    private var allPresetsAllowedBinding: Binding<Bool> {
        Binding(
            get: { model.allowedPresetIDs.isEmpty },
            set: { allowAll in
                model.allowedPresetIDs = allowAll ? [] : presets.map(\.id)
            })
    }

    private func allowedPresetBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { model.allowedPresetIDs.contains(id) },
            set: { allowed in
                if allowed {
                    if !model.allowedPresetIDs.contains(id) {
                        model.allowedPresetIDs.append(id)
                    }
                } else {
                    model.allowedPresetIDs.removeAll { $0 == id }
                }
            })
    }

    private func paintablePartBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { model.paintableParts.contains(name) },
            set: { paintable in
                if paintable {
                    if !model.paintableParts.contains(name) {
                        model.paintableParts.append(name)
                    }
                } else {
                    model.paintableParts.removeAll { $0 == name }
                }
            })
    }

    // MARK: İşlemler

    private func regeneratePreviews() {
        regenBusy = true
        try? context.save()
        Task {
            let background = backgrounds.first { $0.id == model.backgroundID } ?? backgrounds.first
            await PreviewRenderer.shared.generateQueued(for: model,
                                                        presets: presets,
                                                        background: background)
            regenBusy = false
        }
    }

    private func rescanParts() {
        rescanBusy = true
        Task {
            defer { rescanBusy = false }
            let url = FileStore.modelURL(model.fileName)
            guard let root = try? await Entity(contentsOf: url) else { return }
            let parts = EntityTools.collectParts(of: root)
            let names = parts.map(\.name)
            let previouslyUnpainted = Set(model.partNames).subtracting(model.paintableParts)
            model.partNames = names
            model.paintableParts = names.filter { !previouslyUnpainted.contains($0) }
            try? context.save()
        }
    }

    private func deleteModel() {
        FileStore.deleteModelData(fileName: model.fileName, modelID: model.id)
        context.delete(model)
        try? context.save()
        dismiss()
    }
}
