import Foundation
import RealityKit
import SwiftData
import SwiftUI
import UIKit

/// Model × preset kombinasyonları için PNG önizlemeleri üretir.
/// Snapshot alabilmek için ARView'un pencere hiyerarşisinde olması gerekir;
/// bu yüzden RootView, `PreviewRendererHost`'u ana arayüzün arkasına yerleştirir.
@MainActor
final class PreviewRenderer: ObservableObject {
    static let shared = PreviewRenderer()

    let hostView = UIView(frame: CGRect(x: 0, y: 0, width: 640, height: 640))
    private var arView: ARView?
    private var outlineProcessor: OutlinePostProcessor?
    private var chain: Task<Void, Never>?
    private var attemptedAutoGeneration = Set<UUID>()

    @Published var isBusy = false

    private init() {}

    /// AR ekranı açıkken arka plandaki render görünümünü kaldırır (kamera beslemesiyle çakışmasın).
    /// Bir sonraki önizleme üretiminde görünüm yeniden oluşturulur.
    func suspendRendering() {
        arView?.removeFromSuperview()
        arView = nil
    }

    private func ensureView() -> ARView {
        if let view = arView { return view }
        let view = ARView(frame: hostView.bounds,
                          cameraMode: .nonAR,
                          automaticallyConfigureSession: false)
        outlineProcessor = OutlinePostProcessor()
        outlineProcessor?.attach(to: view)
        hostView.addSubview(view)
        arView = view
        return view
    }

    // MARK: Sıralı iş kuyruğu

    private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
        let previous = chain
        chain = Task { @MainActor in
            await previous?.value
            await operation()
        }
    }

    /// Kuyruk üzerinden üretim yapar ve bitmesini bekler.
    func generateQueued(for model: Model3D,
                        presets: [MaterialPreset],
                        background: BackgroundItem?,
                        progress: (@MainActor (Int, Int) -> Void)? = nil) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            enqueue { [weak self] in
                await self?.generatePreviews(for: model,
                                             presets: presets,
                                             background: background,
                                             progress: progress)
                continuation.resume()
            }
        }
    }

    /// Eksik önizlemesi olan modeller için arka planda üretim başlatır (grid'de placeholder görünürse).
    func generateMissingIfNeeded(for model: Model3D) {
        guard !attemptedAutoGeneration.contains(model.id) else { return }
        attemptedAutoGeneration.insert(model.id)
        enqueue { [weak self] in
            guard let self, let context = model.modelContext else { return }
            let presets = (try? context.fetch(FetchDescriptor<MaterialPreset>())) ?? []
            let backgrounds = (try? context.fetch(FetchDescriptor<BackgroundItem>())) ?? []
            let background = backgrounds.first { $0.id == model.backgroundID } ?? backgrounds.defaultItem

            var missing = !FileManager.default.fileExists(
                atPath: FileStore.previewURL(modelID: model.id, presetID: nil).path)
            if !missing {
                missing = presets.contains { preset in
                    !FileManager.default.fileExists(
                        atPath: FileStore.previewURL(modelID: model.id, presetID: preset.id).path)
                }
            }
            guard missing else { return }
            await self.generatePreviews(for: model, presets: presets, background: background)
        }
    }

    // MARK: Üretim

    private func generatePreviews(for model: Model3D,
                                  presets: [MaterialPreset],
                                  background: BackgroundItem?,
                                  progress: (@MainActor (Int, Int) -> Void)? = nil) async {
        isBusy = true
        defer { isBusy = false }

        let url = FileStore.modelURL(model.fileName)
        guard let root = try? await Entity(contentsOf: url) else { return }

        let parts = EntityTools.collectParts(of: root)
        let originals = EntityTools.snapshotMaterials(parts)
        let paintable = Set(model.paintableParts)

        try? FileManager.default.createDirectory(at: FileStore.previewDir(modelID: model.id),
                                                 withIntermediateDirectories: true)

        let view = ensureView()
        view.environment.background = .color(UIColor(hex: background?.hex ?? "#EDEDED"))
        view.scene.anchors.removeAll()

        // Sahne: model merkezde, hafif çapraz açıdan bakan kamera + yönlü ışık.
        let bounds = root.visualBounds(relativeTo: nil)
        let holder = Entity()
        holder.addChild(root)
        root.position = -bounds.center
        holder.orientation = simd_quatf(angle: 0.55, axis: SIMD3<Float>(0, 1, 0))
        let radius = max(simd_length(bounds.extents) * 0.5, 0.001)

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(holder)

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 40
        camera.look(at: .zero,
                    from: SIMD3<Float>(0, radius * 0.5, radius * 2.9),
                    relativeTo: nil)
        anchor.addChild(camera)

        // Viewer ile aynı ışık düzeni: yandan-üstten, gölgeli, ayarlardan okunur.
        view.environment.lighting.intensityExponent =
            Float(DisplaySettings.shared.ambientExponent)
        let light = DirectionalLight()
        light.light.intensity = Float(DisplaySettings.shared.lightIntensity)
        light.light.color = DisplaySettings.shared.lightColor
        light.shadow = DisplaySettings.shared.shadowsEnabled
            ? DirectionalLightComponent.Shadow(maximumDistance: 20, depthBias: 5)
            : nil
        light.look(at: .zero, from: DisplaySettings.shared.lightPosition, relativeTo: nil)
        anchor.addChild(light)

        view.scene.addAnchor(anchor)

        var jobs: [(UUID?, MaterialPreset?)] = [(nil, nil)]
        jobs.append(contentsOf: presets.map { ($0.id, $0) })

        for (index, job) in jobs.enumerated() {
            EntityTools.apply(preset: job.1, paintable: paintable, parts: parts, originals: originals)
            outlineProcessor?.configure(preset: job.1)
            // Materyal değişiminin ekrana yansıması için kısa bekleme.
            try? await Task.sleep(nanoseconds: 200_000_000)
            let image: UIImage? = await withCheckedContinuation { continuation in
                view.snapshot(saveToHDR: false) { continuation.resume(returning: $0) }
            }
            if let data = image?.pngData() {
                try? data.write(to: FileStore.previewURL(modelID: model.id, presetID: job.0))
            }
            progress?(index + 1, jobs.count)
        }

        view.scene.anchors.removeAll()
        model.previewVersion += 1
        try? model.modelContext?.save()
    }
}

/// Renderer'ın ARView'unu pencere hiyerarşisinde tutan görünmez host.
struct PreviewRendererHost: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = PreviewRenderer.shared.hostView
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
