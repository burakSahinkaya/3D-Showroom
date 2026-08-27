import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Renk ve doku presetleri kütüphanesi.
struct PresetLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MaterialPreset.sortIndex) private var presets: [MaterialPreset]

    var body: some View {
        List {
            ForEach(presets) { preset in
                NavigationLink {
                    PresetEditView(preset: preset)
                } label: {
                    HStack(spacing: 12) {
                        PresetSwatchView(preset: preset, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.name)
                            Text(preset.kind == .color ? "Renk" : "Doku")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deletePresets)
        }
        .navigationTitle("Renk ve Doku Presetleri")
        .overlay {
            if presets.isEmpty {
                ContentUnavailableView("Preset yok", systemImage: "paintpalette")
            }
        }
        .toolbar {
            Menu {
                Button("Renk Preseti") { addPreset(kind: .color) }
                Button("Doku Preseti") { addPreset(kind: .texture) }
            } label: {
                Label("Ekle", systemImage: "plus")
            }
        }
    }

    private func addPreset(kind: PresetKind) {
        let nextIndex = (presets.map(\.sortIndex).max() ?? -1) + 1
        let preset = MaterialPreset(name: kind == .color ? "Yeni Renk" : "Yeni Doku",
                                    kind: kind,
                                    hex: "#C79A63",
                                    sortIndex: nextIndex)
        context.insert(preset)
        try? context.save()
    }

    private func deletePresets(at offsets: IndexSet) {
        for index in offsets {
            let preset = presets[index]
            if let fileName = preset.textureFileName {
                FileStore.deleteTexture(fileName: fileName)
            }
            context.delete(preset)
        }
        try? context.save()
    }
}

/// Tek preset düzenleme ekranı.
struct PresetEditView: View {
    @Bindable var preset: MaterialPreset
    @Environment(\.modelContext) private var context
    @Query(sort: \Model3D.createdAt, order: .reverse) private var models: [Model3D]
    @Query(sort: \BackgroundItem.sortIndex) private var backgrounds: [BackgroundItem]

    @State private var showTexturePicker = false
    @State private var textureError: String?
    @State private var previewState: ViewerState?

    /// Materyali etkileyen tüm alanların imzası — değişince canlı önizleme tazelenir.
    private var materialSignature: String {
        [preset.hex,
         "\(preset.roughness)", "\(preset.metallic)", "\(preset.specular)",
         "\(preset.clearcoat)", "\(preset.clearcoatRoughness)",
         preset.bumpKindRaw, "\(preset.bumpIntensity)", "\(preset.bumpScale)",
         "\(preset.opacity)", "\(preset.tileScale)",
         "\(preset.outlineWidth)", preset.outlineHex, "\(preset.innerLineStrength)",
         preset.textureFileName ?? ""].joined(separator: "|")
    }

    var body: some View {
        Form {
            if let previewState {
                Section {
                    ModelViewerView(state: previewState)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("Canlı Önizleme")
                } footer: {
                    Text("Aşağıdaki ayarlar bu önizlemeye anında yansır.")
                }
            }

            Section("Genel") {
                TextField("Ad", text: $preset.name)
                ColorPicker("Renk", selection: colorBinding, supportsOpacity: false)
            }

            if preset.kind == .texture {
                Section {
                    if let fileName = preset.textureFileName,
                       let image = UIImage(contentsOfFile: FileStore.textureURL(fileName).path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Button {
                        showTexturePicker = true
                    } label: {
                        Label(preset.textureFileName == nil ? "Doku Görseli Seç" : "Doku Görselini Değiştir",
                              systemImage: "photo")
                    }
                    if let textureError {
                        Text(textureError).foregroundStyle(.red).font(.caption)
                    }
                    VStack(alignment: .leading) {
                        Text("Doku Ölçeği: \(preset.tileScale, format: .number.precision(.fractionLength(1)))")
                        Slider(value: $preset.tileScale, in: 0.2...10)
                    }
                } header: {
                    Text("Doku")
                } footer: {
                    Text("Görsel seçilmezse yukarıdaki renk kullanılır.")
                }
            }

            Section("Yüzey") {
                VStack(alignment: .leading) {
                    Text("Pürüzlülük: \(preset.roughness, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $preset.roughness, in: 0...1)
                }
                VStack(alignment: .leading) {
                    Text("Metaliklik: \(preset.metallic, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $preset.metallic, in: 0...1)
                }
                VStack(alignment: .leading) {
                    Text("Yansıma Gücü: \(preset.specular, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $preset.specular, in: 0...1)
                }
            }

            Section {
                VStack(alignment: .leading) {
                    Text("Lake Miktarı: \(preset.clearcoat, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $preset.clearcoat, in: 0...1)
                }
                if preset.clearcoat > 0.001 {
                    VStack(alignment: .leading) {
                        Text("Lake Pürüzlülüğü: \(preset.clearcoatRoughness, format: .number.precision(.fractionLength(2)))")
                        Slider(value: $preset.clearcoatRoughness, in: 0...0.5)
                    }
                }
            } header: {
                Text("Lake / Vernik (Clearcoat)")
            } footer: {
                Text("Boyalı yüzeyin üstüne şeffaf cila katmanı ekler. Yüksek parlak lake için miktar 0.6+, pürüzlülük 0.05-0.10; mat lake için pürüzlülüğü artırın.")
            }

            Section {
                Picker("Desen", selection: bumpKindBinding) {
                    Text("Yok").tag(BumpKind.none)
                    Text("İnce Pürüz").tag(BumpKind.noise)
                    Text("Ahşap Damarı").tag(BumpKind.wood)
                }
                if preset.bumpKind != .none {
                    VStack(alignment: .leading) {
                        Text("Şiddet: \(preset.bumpIntensity, format: .number.precision(.fractionLength(2)))")
                        Slider(value: $preset.bumpIntensity, in: 0...1)
                    }
                    VStack(alignment: .leading) {
                        Text("Sıklık: \(preset.bumpScale, format: .number.precision(.fractionLength(0)))")
                        Slider(value: $preset.bumpScale, in: 1...20, step: 1)
                    }
                }
            } header: {
                Text("Kabartma (Bump)")
            } footer: {
                Text("İnce Pürüz: lake yüzeydeki hafif portakal kabuğu dokusu. Ahşap Damarı: dikey damar deseni. Doku dosyası gerektirmez.")
            }

            Section {
                VStack(alignment: .leading) {
                    Text(preset.outlineWidth < 0.01
                         ? "Kalınlık: Kapalı"
                         : "Kalınlık: \(preset.outlineWidth, format: .number.precision(.fractionLength(1)))")
                    Slider(value: $preset.outlineWidth, in: 0...5, step: 0.5)
                }
                VStack(alignment: .leading) {
                    Text(preset.innerLineStrength < 0.01
                         ? "İç Çizgi Hassasiyeti: Kapalı"
                         : "İç Çizgi Hassasiyeti: \(preset.innerLineStrength, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $preset.innerLineStrength, in: 0...1, step: 0.05)
                }
                if preset.outlineWidth > 0.01 || preset.innerLineStrength > 0.01 {
                    ColorPicker("Çizgi Rengi", selection: outlineColorBinding, supportsOpacity: false)
                }
            } header: {
                Text("Kontur (Dış Çizgi)")
            } footer: {
                Text("Kalınlık: modelin dış hatlarını çizer (0 = kapalı, 1-2 önerilir). İç Çizgi Hassasiyeti: profil kenarlarını ve köşeleri de çizer — düşük değerle başlayıp canlı önizlemede yavaşça artırın; çok yüksek değer yüzeyleri karalamaya başlar.")
            }

            Section {
                VStack(alignment: .leading) {
                    Text("Opaklık: \(preset.opacity, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $preset.opacity, in: 0.2...1)
                }
            } header: {
                Text("Şeffaflık")
            } footer: {
                Text("1 = opak. Cam görünümü için 0.3-0.5 aralığını deneyin.")
            }
        }
        .navigationTitle(preset.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: preparePreview)
        .onChange(of: materialSignature) {
            previewState?.materialRefreshToken += 1
        }
        .onDisappear {
            try? context.save()
        }
        .fileImporter(isPresented: $showTexturePicker,
                      allowedContentTypes: [.png, .jpeg, .heic, .image]) { result in
            switch result {
            case .success(let url):
                do {
                    if let old = preset.textureFileName {
                        FileStore.deleteTexture(fileName: old)
                    }
                    preset.textureFileName = try FileStore.importTextureFile(from: url)
                    textureError = nil
                    try? context.save()
                } catch {
                    textureError = "Görsel kopyalanamadı: \(error.localizedDescription)"
                }
            case .failure(let error):
                textureError = error.localizedDescription
            }
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: preset.hex) },
            set: { preset.hex = UIColor($0).hexString })
    }

    private var outlineColorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: preset.outlineHex) },
            set: { preset.outlineHex = UIColor($0).hexString })
    }

    private var bumpKindBinding: Binding<BumpKind> {
        Binding(
            get: { preset.bumpKind },
            set: { preset.bumpKind = $0 })
    }

    private func preparePreview() {
        guard previewState == nil, let model = models.first else { return }
        let state = ViewerState(model: model)
        state.selectedPreset = preset
        state.background = backgrounds.first { $0.id == model.backgroundID } ?? backgrounds.defaultItem
        state.clampDimensions()
        previewState = state
    }
}
