import SwiftUI
import SwiftData
import ARKit

/// Model detay ekranı: dikeyde üstte 3D + altta kontroller,
/// yatayda solda 3D (≥%60) + sağda kontrol paneli.
struct ModelDetailView: View {
    private let model: Model3D
    private let initialPresetID: UUID?

    @StateObject private var state: ViewerState
    @Query(sort: \MaterialPreset.sortIndex) private var presets: [MaterialPreset]
    @Query(sort: \BackgroundItem.sortIndex) private var backgrounds: [BackgroundItem]
    @State private var showAR = false
    @State private var configured = false

    init(model: Model3D, initialPresetID: UUID?) {
        self.model = model
        self.initialPresetID = initialPresetID
        _state = StateObject(wrappedValue: ViewerState(model: model))
    }

    private var allowedPresets: [MaterialPreset] {
        model.allowedPresetIDs.isEmpty
            ? presets
            : presets.filter { model.allowedPresetIDs.contains($0.id) }
    }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                HStack(spacing: 0) {
                    viewerSection
                        .frame(width: geo.size.width * 0.62)
                    Divider()
                    ScrollView {
                        ViewerControlsPanel(state: state, presets: allowedPresets)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    viewerSection
                        .frame(height: geo.size.height * 0.55)
                    Divider()
                    ScrollView {
                        ViewerControlsPanel(state: state, presets: allowedPresets)
                    }
                }
            }
        }
        .navigationTitle(model.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: configure)
        .fullScreenCover(isPresented: $showAR) {
            ARPlacementScreen(state: state)
        }
    }

    private var viewerSection: some View {
        // AR açıkken alttaki RealityKit görünümünü tamamen kaldır:
        // aynı anda birden fazla ARView, AR kamera görüntüsünün çizilmesini engelleyebiliyor.
        Group {
            if showAR {
                Color(uiColor: .systemBackground)
            } else {
                ModelViewerView(state: state)
            }
        }
            .overlay {
                if state.isLoading && !state.loadFailed {
                    ProgressView("Model yükleniyor…")
                }
                if state.loadFailed {
                    ContentUnavailableView("Model açılamadı", systemImage: "exclamationmark.triangle")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if ARWorldTrackingConfiguration.isSupported && !state.loadFailed {
                    Button {
                        // AR açılmadan ÖNCE arka plandaki tüm RealityKit görünümlerini kapat.
                        PreviewRenderer.shared.suspendRendering()
                        showAR = true
                    } label: {
                        Label("AR'da Gör", systemImage: "arkit")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                }
            }
    }

    private func configure() {
        guard !configured else { return }
        configured = true
        if let presetID = initialPresetID {
            state.selectedPreset = presets.first { $0.id == presetID }
        } else if let defaultID = model.defaultPresetID {
            state.selectedPreset = presets.first { $0.id == defaultID }
        }
        state.background = backgrounds.first { $0.id == model.backgroundID } ?? backgrounds.first
        state.clampDimensions()
    }
}

/// Renk daireleri, En/Boy slider'ları ve açıklama.
struct ViewerControlsPanel: View {
    @ObservedObject var state: ViewerState
    let presets: [MaterialPreset]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Renk / Doku")
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        originalSwatch
                        ForEach(presets) { preset in
                            VStack(spacing: 6) {
                                PresetSwatchView(preset: preset,
                                                 size: 44,
                                                 isSelected: state.selectedPreset?.id == preset.id)
                                    .onTapGesture { state.selectedPreset = preset }
                                Text(preset.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            VStack(alignment: .leading, spacing: 18) {
                Text("Ölçüler")
                    .font(.headline)

                VStack(spacing: 6) {
                    HStack {
                        Text("En")
                        Spacer()
                        Text("\(Int(state.widthCM.rounded())) cm")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $state.widthCM, in: state.widthRange)
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("Boy")
                        Spacer()
                        Text("\(Int(state.heightCM.rounded())) cm")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $state.heightCM, in: state.heightRange)
                }

                HStack {
                    Text("Seçilen ölçü: \(Int(state.widthCM.rounded())) × \(Int(state.heightCM.rounded())) cm")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Sıfırla") {
                        state.resetDimensions()
                        state.resetCounter += 1
                    }
                }
            }

            if !state.model.notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Açıklama")
                        .font(.headline)
                    Text(state.model.notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }

    private var originalSwatch: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "#D9D2C5"), Color(hex: "#A38F73")],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .overlay(
                Circle().strokeBorder(state.selectedPreset == nil ? Color.accentColor : Color.black.opacity(0.12),
                                      lineWidth: state.selectedPreset == nil ? 3 : 1))
            .onTapGesture { state.selectedPreset = nil }
            Text("Orijinal")
                .font(.caption2)
        }
        .frame(width: 60)
    }
}
