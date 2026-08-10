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

    /// Mesh içeren tüm alt parçaları kararlı bir sırayla toplar.
    /// Adı olmayan parçalara gezinme sırasına göre "Parça N" adı verilir;
    /// bu sıra aynı dosya için her yüklemede aynıdır.
    static func collectParts(of root: Entity) -> [Part] {
        var parts: [Part] = []
        var usedNames = Set<String>()
        var counter = 0

        func walk(_ entity: Entity) {
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
        switch preset.kind {
        case .color:
            return SimpleMaterial(color: UIColor(hex: preset.hex),
                                  roughness: MaterialScalarParameter(floatLiteral: Float(preset.roughness)),
                                  isMetallic: preset.metallic > 0.5)
        case .texture:
            var material = PhysicallyBasedMaterial()
            if let fileName = preset.textureFileName,
               let texture = try? TextureResource.load(contentsOf: FileStore.textureURL(fileName)) {
                material.baseColor = .init(texture: .init(texture))
                let scale = Float(max(preset.tileScale, 0.01))
                material.textureCoordinateTransform.scale = SIMD2<Float>(scale, scale)
            } else {
                // Doku görseli yoksa/açılamazsa renge düş.
                material.baseColor = .init(tint: UIColor(hex: preset.hex))
            }
            material.roughness = .init(floatLiteral: Float(preset.roughness))
            material.metallic = .init(floatLiteral: Float(preset.metallic))
            return material
        }
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
    }

    /// Modelin doğal ölçülerini cm olarak döndürür (x: en, y: boy, z: derinlik).
    static func sizeCM(of entity: Entity) -> SIMD3<Double> {
        let bounds = entity.visualBounds(relativeTo: nil)
        return SIMD3<Double>(Double(bounds.extents.x) * 100,
                             Double(bounds.extents.y) * 100,
                             Double(bounds.extents.z) * 100)
    }
}
