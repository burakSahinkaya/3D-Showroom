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

    @State private var showTexturePicker = false
    @State private var textureError: String?

    var body: some View {
        Form {
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
            }
        }
        .navigationTitle(preset.name)
        .navigationBarTitleDisplayMode(.inline)
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
}
