import SwiftUI
import SwiftData

/// 3D sahne ışık ayarları — canlı önizlemeli.
struct DisplaySettingsView: View {
    @ObservedObject private var settings = DisplaySettings.shared
    @Query(sort: \Model3D.createdAt, order: .reverse) private var models: [Model3D]
    @Query(sort: \MaterialPreset.sortIndex) private var presets: [MaterialPreset]
    @Query(sort: \BackgroundItem.sortIndex) private var backgrounds: [BackgroundItem]

    @State private var previewState: ViewerState?

    var body: some View {
        Form {
            if let previewState {
                Section {
                    ModelViewerView(state: previewState, showsLightGizmo: true)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                } header: {
                    Text("Canlı Önizleme")
                } footer: {
                    Text("Sarı küre ışığın konumunu gösterir; ayarları değiştirdikçe modelin etrafında hareket eder. Bu işaret yalnızca bu ekranda görünür.")
                }
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Işık Şiddeti")
                        Spacer()
                        Text("\(Int(settings.lightIntensity))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.lightIntensity, in: 200...2500, step: 50)
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text("Ortam Işığı")
                        Spacer()
                        Text(settings.ambientExponent, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.ambientExponent, in: 0.3...1.2, step: 0.05)
                }
                Toggle("Gölgeler", isOn: $settings.shadowsEnabled)
                VStack(alignment: .leading) {
                    HStack {
                        Text("Işık Sıcaklığı")
                        Spacer()
                        Text("\(Int(settings.lightTemperature)) K")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.lightTemperature, in: 2700...8000, step: 100)
                    HStack {
                        Text("Sıcak")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("Soğuk")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                    }
                }
            } header: {
                Text("Işık")
            } footer: {
                Text("Işık Şiddeti: modele vuran ana ışığın gücü. Ortam Işığı: her yönden gelen genel aydınlatma. Sıcaklık: 2700K sıcak sarı (akkor ampul), 6500K nötr gün ışığı, 8000K soğuk beyaz.")
            }

            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Işık Yönü")
                        Spacer()
                        Text("\(Int(settings.lightAzimuth))°")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.lightAzimuth, in: -180...180, step: 5)
                }
                VStack(alignment: .leading) {
                    HStack {
                        Text("Işık Yüksekliği")
                        Spacer()
                        Text("\(Int(settings.lightElevation))°")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $settings.lightElevation, in: 5...85, step: 5)
                }
                Button("Varsayılana Dön") {
                    settings.resetToDefaults()
                }
            } header: {
                Text("Işık Konumu")
            } footer: {
                Text("Yön: 0° tam karşıdan, sağa/sola kaydıkça ışık yandan gelir. Yükseklik: 90°'ye yaklaştıkça tepeden vurur. Değişiklikler 3D ekranlarında anında geçerlidir; ızgara kartlarındaki görseller için Yönetim > Tüm Önizlemeleri Yenile'yi çalıştırın.")
            }
        }
        .navigationTitle("Görüntüleme Ayarları")
        .onAppear(perform: preparePreview)
    }

    private func preparePreview() {
        guard previewState == nil, let model = models.first else { return }
        let state = ViewerState(model: model)
        if let defaultID = model.defaultPresetID {
            state.selectedPreset = presets.first { $0.id == defaultID }
        }
        state.background = backgrounds.first { $0.id == model.backgroundID } ?? backgrounds.defaultItem
        state.clampDimensions()
        previewState = state
    }
}
