import SwiftUI
import RealityKit
import UIKit

/// Model detay ekranındaki 3D görüntüleyicinin paylaşılan durumu.
@MainActor
final class ViewerState: ObservableObject {
    let model: Model3D

    @Published var selectedPreset: MaterialPreset?
    @Published var background: BackgroundItem?
    @Published var widthCM: Double
    @Published var heightCM: Double
    /// Artırıldığında kamera/döndürme sıfırlanır.
    @Published var resetCounter = 0
    /// Artırıldığında seçili preset aynı kalsa bile materyal yeniden uygulanır
    /// (preset düzenleme ekranındaki canlı önizleme için).
    @Published var materialRefreshToken = 0
    @Published var isLoading = true
    @Published var loadFailed = false

    init(model: Model3D) {
        self.model = model
        self.widthCM = max(model.realWidthCM, 1)
        self.heightCM = max(model.realHeightCM, 1)
    }

    var widthScale: Float {
        model.realWidthCM > 0 ? Float(widthCM / model.realWidthCM) : 1
    }

    var heightScale: Float {
        model.realHeightCM > 0 ? Float(heightCM / model.realHeightCM) : 1
    }

    var widthRange: ClosedRange<Double> {
        if model.minWidthCM > 0, model.maxWidthCM > model.minWidthCM {
            return model.minWidthCM...model.maxWidthCM
        }
        let real = max(model.realWidthCM, 1)
        return (real * 0.5)...(real * 1.5)
    }

    var heightRange: ClosedRange<Double> {
        if model.minHeightCM > 0, model.maxHeightCM > model.minHeightCM {
            return model.minHeightCM...model.maxHeightCM
        }
        let real = max(model.realHeightCM, 1)
        return (real * 0.5)...(real * 1.5)
    }

    func clampDimensions() {
        widthCM = min(max(widthCM, widthRange.lowerBound), widthRange.upperBound)
        heightCM = min(max(heightCM, heightRange.lowerBound), heightRange.upperBound)
    }

    func resetDimensions() {
        widthCM = min(max(max(model.realWidthCM, 1), widthRange.lowerBound), widthRange.upperBound)
        heightCM = min(max(max(model.realHeightCM, 1), heightRange.lowerBound), heightRange.upperBound)
    }
}

/// Döndürülebilir / yakınlaştırılabilir 3D model görüntüleyici (AR dışı).
struct ModelViewerView: UIViewRepresentable {
    @ObservedObject var state: ViewerState
    /// true ise ışığın konumunu gösteren güneş işareti çizilir (yalnızca ayar ekranı).
    var showsLightGizmo: Bool = false
    // Işık ayarları değişince görünüm güncellensin diye gözlemlenir.
    @ObservedObject private var displaySettings = DisplaySettings.shared

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero,
                            cameraMode: .nonAR,
                            automaticallyConfigureSession: false)
        context.coordinator.showsLightGizmo = showsLightGizmo
        context.coordinator.setup(arView: arView, state: state)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.sync(with: state)
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var arView: ARView?
        private var stateRef: ViewerState?

        private var worldAnchor: AnchorEntity?
        private var orbit = Entity()
        private var stretch = Entity()
        private var camera = PerspectiveCamera()
        private var parts: [EntityTools.Part] = []
        private var originals: [String: [any RealityKit.Material]] = [:]
        private var paintable: Set<String> = []
        private var light: DirectionalLight?
        private var outlineProcessor: OutlinePostProcessor?
        var showsLightGizmo = false
        private var lightGizmo: Entity?
        private var modelRadius: Float = 0.5

        private var yaw: Float = 0.55
        private var pitch: Float = -0.15
        private var camDistance: Float = 1
        private var baseDistance: Float = 1

        private var isLoaded = false
        private var needsMaterialRefresh = true
        private var lastPresetID: UUID?
        private var lastResetCounter = 0
        private var lastMaterialToken = 0

        func setup(arView: ARView, state: ViewerState) {
            self.arView = arView
            self.stateRef = state
            arView.environment.background = .color(UIColor(hex: state.background?.hex ?? "#EDEDED"))
            outlineProcessor = OutlinePostProcessor()
            outlineProcessor?.attach(to: arView)
            addGestures(to: arView)
            Task { await load() }
        }

        private func load() async {
            guard let arView, let state = stateRef else { return }
            state.isLoading = true
            let url = FileStore.modelURL(state.model.fileName)
            guard let root = try? await Entity(contentsOf: url) else {
                state.isLoading = false
                state.loadFailed = true
                return
            }

            parts = EntityTools.collectParts(of: root)
            originals = EntityTools.snapshotMaterials(parts)
            paintable = Set(state.model.paintableParts)

            let bounds = root.visualBounds(relativeTo: nil)
            let radius = max(simd_length(bounds.extents) * 0.5, 0.001)

            let inner = Entity()
            inner.addChild(root)
            root.position = -bounds.center

            stretch = Entity()
            stretch.addChild(inner)
            orbit = Entity()
            orbit.addChild(stretch)

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(orbit)

            camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 45
            baseDistance = radius * 2.6
            camDistance = baseDistance
            anchor.addChild(camera)

            // Işık yandan-üstten gelsin: düz bakışta yüzey patlamasın, profil gölgeleri okunsun.
            arView.environment.lighting.intensityExponent =
                Float(DisplaySettings.shared.ambientExponent)
            let light = DirectionalLight()
            light.light.intensity = Float(DisplaySettings.shared.lightIntensity)
            light.light.color = DisplaySettings.shared.lightColor
            // Geniş menzil + yüksek bias: model eğilince yüzeye düşen gri gölge bandını önler.
            light.shadow = DisplaySettings.shared.shadowsEnabled
                ? DirectionalLightComponent.Shadow(maximumDistance: 20, depthBias: 5)
                : nil
            light.look(at: .zero, from: DisplaySettings.shared.lightPosition, relativeTo: nil)
            anchor.addChild(light)
            self.light = light

            modelRadius = radius
            if showsLightGizmo {
                buildLightGizmo(in: anchor, radius: radius)
            }

            arView.scene.addAnchor(anchor)
            worldAnchor = anchor
            isLoaded = true

            applyOrbit()
            updateCamera()
            state.isLoading = false
            sync(with: state)
        }

        func sync(with state: ViewerState) {
            stateRef = state
            arView?.environment.background = .color(UIColor(hex: state.background?.hex ?? "#EDEDED"))
            guard isLoaded else { return }

            // Işık ayarlarını canlı uygula (Görüntüleme Ayarları ekranı için).
            light?.light.intensity = Float(DisplaySettings.shared.lightIntensity)
            light?.light.color = DisplaySettings.shared.lightColor
            light?.shadow = DisplaySettings.shared.shadowsEnabled
                ? DirectionalLightComponent.Shadow(maximumDistance: 20, depthBias: 5)
                : nil
            light?.look(at: .zero, from: DisplaySettings.shared.lightPosition, relativeTo: nil)
            arView?.environment.lighting.intensityExponent =
                Float(DisplaySettings.shared.ambientExponent)
            updateLightGizmo()

            let presetID = state.selectedPreset?.id
            if needsMaterialRefresh || presetID != lastPresetID
                || state.materialRefreshToken != lastMaterialToken {
                EntityTools.apply(preset: state.selectedPreset,
                                  paintable: paintable,
                                  parts: parts,
                                  originals: originals)
                lastPresetID = presetID
                lastMaterialToken = state.materialRefreshToken
                needsMaterialRefresh = false
            }
            outlineProcessor?.configure(preset: state.selectedPreset)

            stretch.scale = SIMD3<Float>(state.widthScale, state.heightScale, 1)

            if state.resetCounter != lastResetCounter {
                lastResetCounter = state.resetCounter
                resetView()
            }
        }

        // MARK: Işık gizmosu (yalnızca ayar ekranı)

        /// Işığın konumunu gösteren güneş küresi + modele uzanan iz noktaları.
        private func buildLightGizmo(in anchor: Entity, radius: Float) {
            let gizmo = Entity()
            let sun = ModelEntity(mesh: .generateSphere(radius: radius * 0.1),
                                  materials: [UnlitMaterial(color: .systemYellow)])
            sun.name = "gizmoSun"
            gizmo.addChild(sun)
            for index in 1...3 {
                let dot = ModelEntity(mesh: .generateSphere(radius: radius * 0.028),
                                      materials: [UnlitMaterial(color: .systemOrange)])
                dot.name = "gizmoDot\(index)"
                gizmo.addChild(dot)
            }
            anchor.addChild(gizmo)
            lightGizmo = gizmo
            updateLightGizmo()
        }

        private func updateLightGizmo() {
            guard let gizmo = lightGizmo else { return }
            let direction = simd_normalize(DisplaySettings.shared.lightPosition)
            let sunPosition = direction * (modelRadius * 1.7)
            gizmo.findEntity(named: "gizmoSun")?.position = sunPosition
            for (index, t) in [Float(0.45), 0.65, 0.85].enumerated() {
                gizmo.findEntity(named: "gizmoDot\(index + 1)")?.position = sunPosition * t
            }
        }

        // MARK: Kamera / döndürme

        private func applyOrbit() {
            orbit.orientation = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
                * simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        }

        private func updateCamera() {
            // Model her zaman merkezde: kamera yalnızca uzaklaşıp yakınlaşır.
            camera.look(at: .zero, from: SIMD3<Float>(0, 0, camDistance), relativeTo: nil)
        }

        private func resetView() {
            yaw = 0.55
            pitch = -0.15
            camDistance = baseDistance
            applyOrbit()
            updateCamera()
        }

        // MARK: Jestler

        private func addGestures(to view: ARView) {
            let orbitPan = UIPanGestureRecognizer(target: self, action: #selector(handleOrbit(_:)))
            orbitPan.maximumNumberOfTouches = 1
            view.addGestureRecognizer(orbitPan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            view.addGestureRecognizer(pinch)

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            view.addGestureRecognizer(doubleTap)
        }

        @objc private func handleOrbit(_ gesture: UIPanGestureRecognizer) {
            guard isLoaded else { return }
            let translation = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            yaw += Float(translation.x) * 0.008
            pitch = max(-1.3, min(1.3, pitch + Float(translation.y) * 0.008))
            applyOrbit()
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard isLoaded, gesture.state == .changed else { return }
            camDistance /= Float(gesture.scale)
            gesture.scale = 1
            camDistance = max(baseDistance * 0.25, min(baseDistance * 4, camDistance))
            updateCamera()
        }

        @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard isLoaded else { return }
            resetView()
        }

        nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
