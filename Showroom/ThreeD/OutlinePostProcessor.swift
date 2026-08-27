import Foundation
import Metal
import RealityKit
import UIKit

/// Derinlik tabanlı iç çizgi (post-process) efekti.
/// ARView'un render çıktısını GPU'da işleyip derinlik kenarlarına kontur rengi basar.
final class OutlinePostProcessor {
    private let pipeline: MTLComputePipelineState

    // configure() ana thread'den yazar, render() render thread'inden okur;
    // basit değer türleri olduğu için pratikte güvenlidir.
    private var lineColor = SIMD4<Float>(0.1, 0.1, 0.1, 1)
    private var threshold: Float = 1
    private var isEnabled = false

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "edgeOutline"),
              let pipeline = try? device.makeComputePipelineState(function: function) else {
            return nil
        }
        self.pipeline = pipeline
    }

    /// Aktif preset'e göre efekti ayarlar. Hassasiyet 0 ise efekt kapalı.
    func configure(preset: MaterialPreset?) {
        let strength = preset?.innerLineStrength ?? 0
        isEnabled = strength > 0.01
        guard isEnabled, let preset else { return }
        // 0..1 hassasiyeti logaritmik eşiğe çevir (Laplacian için geniş aralık):
        // 0 → 0.1 (duyarsız), 1 → 0.0001 (çok duyarlı).
        threshold = Float(0.1 * pow(10, -3 * strength))
        let uiColor = UIColor(hex: preset.outlineHex)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        lineColor = SIMD4<Float>(Float(r), Float(g), Float(b), 1)
    }

    func attach(to arView: ARView) {
        arView.renderCallbacks.postProcess = { [weak self] context in
            self?.render(context)
        }
    }

    private func render(_ context: ARView.PostProcessContext) {
        guard isEnabled else {
            // Efekt kapalıyken görüntüyü olduğu gibi aktar.
            if let blit = context.commandBuffer.makeBlitCommandEncoder() {
                blit.copy(from: context.sourceColorTexture, to: context.targetColorTexture)
                blit.endEncoding()
            }
            return
        }
        guard let encoder = context.commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(context.sourceColorTexture, index: 0)
        encoder.setTexture(context.sourceDepthTexture, index: 1)
        encoder.setTexture(context.targetColorTexture, index: 2)
        var color = lineColor
        var thresholdValue = threshold
        encoder.setBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        encoder.setBytes(&thresholdValue, length: MemoryLayout<Float>.stride, index: 1)
        let threadgroup = MTLSize(width: 8, height: 8, depth: 1)
        let groups = MTLSize(width: (context.targetColorTexture.width + 7) / 8,
                             height: (context.targetColorTexture.height + 7) / 8,
                             depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threadgroup)
        encoder.endEncoding()
    }
}
