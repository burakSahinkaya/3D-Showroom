import SwiftUI
import RealityKit
import ARKit
import AVFoundation

/// Modeli gerçek ortama gerçek ölçüsünde yerleştiren AR ekranı.
struct ARPlacementScreen: View {
    @ObservedObject var state: ViewerState
    @Environment(\.dismiss) private var dismiss

    @State private var cameraDenied = false
    @State private var sessionError: String?
    @State private var trackingInfo: String?
    @State private var pitchLocked = false
    @State private var scaleLocked = false

    var body: some View {
        ZStack(alignment: .top) {
            ARPlacementContainer(state: state,
                                 cameraDenied: $cameraDenied,
                                 sessionError: $sessionError,
                                 trackingInfo: $trackingInfo,
                                 pitchLocked: pitchLocked,
                                 scaleLocked: scaleLocked)
                .ignoresSafeArea()

            HStack {
                Text("Yüzeye dokunun / sürükleyin • İki parmakla çevirin ve eğin • Pinch ile boyutlandırın")
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("Kapat", systemImage: "xmark")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding()

            if cameraDenied {
                cameraDeniedOverlay
            } else if let sessionError {
                bottomNote("AR oturumu hatası: \(sessionError)", extraBottomPadding: 80)
            } else if let trackingInfo {
                bottomNote(trackingInfo, extraBottomPadding: 80)
            }
        }
        .overlay(alignment: .bottom) {
            if !cameraDenied {
                HStack(spacing: 12) {
                    lockButton(title: "Dikey Döndürme",
                               icon: "rotate.3d",
                               locked: $pitchLocked)
                    lockButton(title: "Boyut",
                               icon: "arrow.up.left.and.arrow.down.right",
                               locked: $scaleLocked)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            // Arka plandaki önizleme render görünümü kamera beslemesiyle çakışmasın.
            PreviewRenderer.shared.suspendRendering()
        }
    }

    private func bottomNote(_ text: String, extraBottomPadding: CGFloat) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, extraBottomPadding)
        }
    }

    private func lockButton(title: String, icon: String, locked: Binding<Bool>) -> some View {
        Button {
            locked.wrappedValue.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                Image(systemName: locked.wrappedValue ? "lock.fill" : "lock.open")
                    .foregroundStyle(locked.wrappedValue ? .orange : .secondary)
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .tint(.primary)
    }

    private var cameraDeniedOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.largeTitle)
                Text("Kamera izni gerekli")
                    .font(.headline)
                Text("AR görünümü için Ayarlar'dan Showroom'a kamera izni verin.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Ayarları Aç") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ARPlacementContainer: UIViewRepresentable {
    @ObservedObject var state: ViewerState
    @Binding var cameraDenied: Bool
    @Binding var sessionError: String?
    @Binding var trackingInfo: String?
    let pitchLocked: Bool
    let scaleLocked: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> ARView {
        // Oturumu biz başlatacağız (izin geldikten sonra) — otomatik başlatma kapalı.
        let arView = ARView(frame: .zero,
                            cameraMode: .ar,
                            automaticallyConfigureSession: false)
        context.coordinator.setup(arView: arView,
                                  state: state,
                                  cameraDenied: $cameraDenied,
                                  sessionError: $sessionError,
                                  trackingInfo: $trackingInfo)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.pitchLocked = pitchLocked
        context.coordinator.scaleLocked = scaleLocked
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    @MainActor
    final class Coordinator: NSObject, ARSessionDelegate, UIGestureRecognizerDelegate {
        private weak var arView: ARView?
        private var state: ViewerState?
        private var cameraDenied: Binding<Bool>?
        private var sessionError: Binding<String?>?
        private var trackingInfo: Binding<String?>?

        private var wrapper: ModelEntity?
        private var placedAnchor: AnchorEntity?
        private var yawAngle: Float = 0
        private var pitchAngle: Float = 0
        private var scaleFactor: Float = 1

        var pitchLocked = false
        var scaleLocked = false

        func setup(arView: ARView,
                   state: ViewerState,
                   cameraDenied: Binding<Bool>,
                   sessionError: Binding<String?>,
                   trackingInfo: Binding<String?>) {
            self.arView = arView
            self.state = state
            self.cameraDenied = cameraDenied
            self.sessionError = sessionError
            self.trackingInfo = trackingInfo

            arView.session.delegate = self

            let coaching = ARCoachingOverlayView()
            coaching.session = arView.session
            coaching.goal = .horizontalPlane
            coaching.frame = arView.bounds
            coaching.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            arView.addSubview(coaching)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tap)

            let movePan = UIPanGestureRecognizer(target: self, action: #selector(handleMovePan(_:)))
            movePan.maximumNumberOfTouches = 1
            movePan.delegate = self
            arView.addGestureRecognizer(movePan)

            let twist = UIRotationGestureRecognizer(target: self, action: #selector(handleTwist(_:)))
            twist.delegate = self
            arView.addGestureRecognizer(twist)

            let pitchPan = UIPanGestureRecognizer(target: self, action: #selector(handlePitchPan(_:)))
            pitchPan.minimumNumberOfTouches = 2
            pitchPan.maximumNumberOfTouches = 2
            pitchPan.delegate = self
            arView.addGestureRecognizer(pitchPan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            arView.addGestureRecognizer(pinch)

            Task { await startSessionIfAuthorized() }
            Task { await load() }
        }

        // MARK: Kamera izni ve oturum

        private func startSessionIfAuthorized() async {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                runSession()
            case .notDetermined:
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                if granted {
                    runSession()
                } else {
                    cameraDenied?.wrappedValue = true
                }
            default:
                cameraDenied?.wrappedValue = true
            }
        }

        private func runSession() {
            guard let arView else { return }
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal, .vertical]
            config.environmentTexturing = .automatic
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            // Kamera beslemesini açıkça arka plan yap.
            arView.environment.background = .cameraFeed()
            cameraDenied?.wrappedValue = false
        }

        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor in
                let nsError = error as NSError
                if nsError.domain == ARError.errorDomain,
                   nsError.code == ARError.Code.cameraUnauthorized.rawValue {
                    self.cameraDenied?.wrappedValue = true
                } else {
                    self.sessionError?.wrappedValue = error.localizedDescription
                }
            }
        }

        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor in
                self.trackingInfo?.wrappedValue = nil
                self.runSession()
            }
        }

        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor in
                self.trackingInfo?.wrappedValue =
                    "Oturum kesintide — uygulama tam ekran değilse (Split View / Stage Manager) kamera çalışmaz."
            }
        }

        nonisolated func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let text: String?
            switch camera.trackingState {
            case .normal:
                text = nil
            case .notAvailable:
                text = "Kamera izleme kullanılamıyor"
            case .limited(let reason):
                switch reason {
                case .initializing: text = "Başlatılıyor…"
                case .excessiveMotion: text = "Cihazı daha yavaş hareket ettirin"
                case .insufficientFeatures: text = "Ortam çok karanlık ya da desensiz"
                case .relocalizing: text = "Konum yeniden bulunuyor…"
                @unknown default: text = "İzleme kısıtlı"
                }
            }
            Task { @MainActor in
                self.trackingInfo?.wrappedValue = text
            }
        }

        // MARK: Model hazırlama

        private func load() async {
            guard let state else { return }
            let url = FileStore.modelURL(state.model.fileName)
            guard let root = try? await Entity(contentsOf: url) else { return }

            let parts = EntityTools.collectParts(of: root)
            let originals = EntityTools.snapshotMaterials(parts)
            EntityTools.apply(preset: state.selectedPreset,
                              paintable: Set(state.model.paintableParts),
                              parts: parts,
                              originals: originals)

            let bounds = root.visualBounds(relativeTo: nil)
            let inner = Entity()
            inner.addChild(root)
            // Merkezle ve alt kenarı zemine oturt.
            root.position = -bounds.center + SIMD3<Float>(0, bounds.extents.y / 2, 0)

            // Admin'in girdiği gerçek ölçüye göre mutlak ölçek.
            var baseScale: Float = 1
            if state.model.realWidthCM > 0, bounds.extents.x > 0 {
                baseScale = Float(state.model.realWidthCM / 100) / bounds.extents.x
            }
            inner.scale = SIMD3<Float>(baseScale * state.widthScale,
                                       baseScale * state.heightScale,
                                       baseScale)

            let entity = ModelEntity()
            entity.addChild(inner)
            wrapper = entity
        }

        // MARK: Yerleştirme ve jestler

        /// Önce gerçekten algılanmış düzlemleri dener; bulunamazsa tahmini yüzeye düşer.
        /// (LiDAR'sız cihazlarda "havada durma" sorununu azaltır.)
        private func bestHit(at point: CGPoint) -> ARRaycastResult? {
            guard let arView else { return nil }
            if let hit = arView.raycast(from: point,
                                        allowing: .existingPlaneGeometry,
                                        alignment: .any).first {
                return hit
            }
            if let hit = arView.raycast(from: point,
                                        allowing: .existingPlaneInfinite,
                                        alignment: .any).first {
                return hit
            }
            return arView.raycast(from: point,
                                  allowing: .estimatedPlane,
                                  alignment: .any).first
        }

        private func placeOrMove(to point: CGPoint) {
            guard let arView, let wrapper, let hit = bestHit(at: point) else { return }
            let column = hit.worldTransform.columns.3
            let position = SIMD3<Float>(column.x, column.y, column.z)

            if placedAnchor == nil {
                // Dünya orijinine sabit anchor; obje dünya koordinatında konumlanır.
                let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
                anchor.addChild(wrapper)
                arView.scene.addAnchor(anchor)
                placedAnchor = anchor
            }
            wrapper.position = position
            applyTransform()
        }

        private func applyTransform() {
            guard let wrapper else { return }
            wrapper.orientation = simd_quatf(angle: yawAngle, axis: SIMD3<Float>(0, 1, 0))
                * simd_quatf(angle: pitchAngle, axis: SIMD3<Float>(1, 0, 0))
            wrapper.scale = SIMD3<Float>(repeating: scaleFactor)
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            placeOrMove(to: gesture.location(in: gesture.view))
        }

        @objc private func handleMovePan(_ gesture: UIPanGestureRecognizer) {
            guard placedAnchor != nil else { return }
            placeOrMove(to: gesture.location(in: gesture.view))
        }

        @objc private func handleTwist(_ gesture: UIRotationGestureRecognizer) {
            guard placedAnchor != nil, gesture.state == .changed else { return }
            yawAngle -= Float(gesture.rotation)
            gesture.rotation = 0
            applyTransform()
        }

        @objc private func handlePitchPan(_ gesture: UIPanGestureRecognizer) {
            guard placedAnchor != nil, !pitchLocked else { return }
            let translation = gesture.translation(in: gesture.view)
            gesture.setTranslation(.zero, in: gesture.view)
            pitchAngle = max(-1.6, min(1.6, pitchAngle + Float(translation.y) * 0.008))
            applyTransform()
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard placedAnchor != nil, !scaleLocked, gesture.state == .changed else { return }
            scaleFactor = max(0.25, min(4, scaleFactor * Float(gesture.scale)))
            gesture.scale = 1
            applyTransform()
        }

        nonisolated func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
