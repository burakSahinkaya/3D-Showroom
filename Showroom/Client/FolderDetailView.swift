import SwiftUI
import SwiftData

/// Klasör içeriği: model önizlemeleri, adları ve renk seçme daireleri.
struct FolderDetailView: View {
    /// nil = klasörsüz ("Diğer") modeller.
    let folder: ModelFolder?

    @Query private var allModels: [Model3D]
    @Query(sort: \MaterialPreset.sortIndex) private var presets: [MaterialPreset]

    private var models: [Model3D] {
        allModels
            .filter { $0.folder?.id == folder?.id }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        GeometryReader { geo in
            let columnCount = geo.size.width > geo.size.height ? 4 : 2
            let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: columnCount)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(models) { model in
                        ModelCardView(model: model, presets: allowedPresets(for: model))
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(folder?.name ?? "Diğer")
        .overlay {
            if models.isEmpty {
                ContentUnavailableView("Bu klasörde model yok", systemImage: "cube.transparent")
            }
        }
    }

    private func allowedPresets(for model: Model3D) -> [MaterialPreset] {
        model.allowedPresetIDs.isEmpty
            ? presets
            : presets.filter { model.allowedPresetIDs.contains($0.id) }
    }
}

/// Tek model kartı: önizleme + ad + renk daireleri.
struct ModelCardView: View {
    let model: Model3D
    let presets: [MaterialPreset]

    @State private var selectedPresetID: UUID?
    @State private var initialized = false

    var body: some View {
        VStack(spacing: 10) {
            NavigationLink {
                ModelDetailView(model: model, initialPresetID: selectedPresetID)
            } label: {
                PreviewImage(model: model, presetID: selectedPresetID)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Text(model.name)
                .font(.headline)
                .lineLimit(1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets) { preset in
                        PresetSwatchView(preset: preset,
                                         size: 30,
                                         isSelected: selectedPresetID == preset.id)
                            .onTapGesture {
                                withAnimation {
                                    selectedPresetID = preset.id
                                }
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 36)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 3))
        .onAppear {
            if !initialized {
                selectedPresetID = model.defaultPresetID
                initialized = true
            }
        }
    }
}

/// Renk/doku preseti için yuvarlak buton.
struct PresetSwatchView: View {
    let preset: MaterialPreset
    var size: CGFloat = 44
    var isSelected: Bool = false

    var body: some View {
        ZStack {
            if preset.kind == .texture,
               let fileName = preset.textureFileName,
               let image = UIImage(contentsOfFile: FileStore.textureURL(fileName).path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(hex: preset.hex)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.12),
                                  lineWidth: isSelected ? 3 : 1))
    }
}
