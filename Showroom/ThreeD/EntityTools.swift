import Foundation
import RealityKit
import UIKit

/// USDZ entity hiyerarşisi üzerinde parça listeleme, materyal uygulama ve ölçü hesaplama araçları.
@MainActor
enum EntityTools {
    struct Part {
        let name: String
        let entity: ModelEntity
    }

    /// Kontur (outline) için üretilen kabuk kopyaların ad öneki.
    private static let outlinePrefix = "__outline__"

    /// Mesh içeren tüm alt parçaları kararlı bir sırayla toplar.
    /// Adı olmayan parçalara gezinme sırasına göre "Parça N" adı verilir;
    /// bu sıra aynı dosya için her yüklemede aynıdır.
    static func collectParts(of root: Entity) -> [Part] {
        var parts: [Part] = []
        var usedNames = Set<String>()
        var counter = 0

        func walk(_ entity: Entity) {
            // Outline kabukları gerçek parça değildir; atla.
            if entity.name.hasPrefix(outlinePrefix) { return }
            if let modelEntity = entity as? ModelEntity, modelEntity.model != nil {
                counter += 1
                var name = entity.name.isEmpty ? "Parça \(counter)" : entity.name
                if usedNames.contains(name) {
                    var suffix = 2
                    while usedNames.contains("\(name) \(suffix)") { suffix += 1 }
                    name = "\(name) \(suffix)"
                }
                usedNames.insert(name)
                parts.append(Part(name: name, entity: modelEntity))
            }
            for child in entity.children {
                walk(child)
            }
        }

        walk(root)
        return parts
    }

    /// Yükleme anındaki orijinal materyalleri saklar (preset kaldırılınca geri dönmek için).
    static func snapshotMaterials(_ parts: [Part]) -> [String: [any RealityKit.Material]] {
        var result: [String: [any RealityKit.Material]] = [:]
        for part in parts {
            if let component = part.entity.model {
                result[part.name] = component.materials
            }
        }
        return result
    }

    static func makeMaterial(preset: MaterialPreset) -> any RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        switch preset.kind {
        case .color:
            material.baseColor = .init(tint: UIColor(hex: preset.hex))
        case .texture:
            if let fileName = preset.textureFileName,
               let texture = try? TextureResource.load(contentsOf: FileStore.textureURL(fileName)) {
                material.baseColor = .init(texture: .init(texture))
                let scale = Float(max(preset.tileScale, 0.01))
                material.textureCoordinateTransform.scale = SIMD2<Float>(scale, scale)
            } else {
                // Doku görseli yoksa/açılamazsa renge düş.
                material.baseColor = .init(tint: UIColor(hex: preset.hex))
            }
        }
        material.roughness = .init(floatLiteral: Float(preset.roughness))
        material.metallic = .init(floatLiteral: Float(preset.metallic))
        material.specular = .init(floatLiteral: Float(preset.specular))

        // Lake/vernik katmanı.
        if preset.clearcoat > 0.001 {
            material.clearcoat = .init(floatLiteral: Float(preset.clearcoat))
            material.clearcoatRoughness = .init(floatLiteral: Float(preset.clearcoatRoughness))
        }

        // Prosedürel kabartma (portakal kabuğu / ahşap damarı).
        if let normalTexture = BumpTextureGenerator.normalTexture(kind: preset.bumpKind,
                                                                  scale: preset.bumpScale,
                                                                  intensity: preset.bumpIntensity) {
            material.normal = .init(texture: .init(normalTexture))
        }

        // Cam vb. için şeffaflık.
        if preset.opacity < 0.999 {
            material.blending = .transparent(opacity: .init(floatLiteral: Float(preset.opacity)))
        }

        return material
    }

    /// Preset'i boyanabilir parçalara uygular; preset nil ise ya da parça boyanamazsa orijinale döner.
    static func apply(preset: MaterialPreset?,
                      paintable: Set<String>,
                      parts: [Part],
                      originals: [String: [any RealityKit.Material]]) {
        for part in parts {
            guard var component = part.entity.model else { continue }
            if let preset, paintable.contains(part.name) {
                let material = makeMaterial(preset: preset)
                component.materials = Array(repeating: material, count: max(component.materials.count, 1))
            } else if let original = originals[part.name] {
                component.materials = original
            }
            part.entity.model = component
        }
        updateOutlines(parts: parts, preset: preset)
    }

    /// "Inverted hull" kontur: her parçanın hafifçe büyütülmüş, ters yüz edilmiş
    /// (ön yüzleri kırpılmış) düz renk bir kopyası eklenir; silüet çizgisi verir.
    private static func updateOutlines(parts: [Part], preset: MaterialPreset?) {
        for part in parts {
            for child in part.entity.children where child.name.hasPrefix(outlinePrefix) {
                child.removeFromParent()
            }
            guard let preset, preset.outlineWidth > 0.01,
                  let component = part.entity.model else { continue }

            var outlineMaterial = UnlitMaterial(color: UIColor(hex: preset.outlineHex))
            outlineMaterial.faceCulling = .front

            let hull = ModelEntity(mesh: component.mesh,
                                   materials: Array(repeating: outlineMaterial,
                                                    count: max(component.materials.count, 1)))
            hull.name = outlinePrefix + part.name
            // Parçayı kendi merkezinden büyüt: p' = s*p + c*(1-s)
            let scale = Float(1 + preset.outlineWidth * 0.01)
            hull.scale = SIMD3<Float>(repeating: scale)
            hull.position = component.mesh.bounds.center * (1 - scale)
            part.entity.addChild(hull)
        }
    }

    /// Modelin doğal ölçülerini cm olarak döndürür (x: en, y: boy, z: derinlik).
    static func sizeCM(of entity: Entity) -> SIMD3<Double> {
        let bounds = entity.visualBounds(relativeTo: nil)
        return SIMD3<Double>(Double(bounds.extents.x) * 100,
                             Double(bounds.extents.y) * 100,
                             Double(bounds.extents.z) * 100)
    }
}
