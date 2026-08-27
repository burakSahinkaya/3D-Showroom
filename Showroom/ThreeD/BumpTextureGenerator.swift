import CoreGraphics
import Foundation
import RealityKit
import simd

/// Prosedürel bump (normal) haritaları üretir ve önbelleğe alır.
/// Doku dosyası gerektirmez; deterministik değer gürültüsünden türetilir.
@MainActor
enum BumpTextureGenerator {
    private static var cache: [String: TextureResource] = [:]

    static func normalTexture(kind: BumpKind, scale: Double, intensity: Double) -> TextureResource? {
        guard kind != .none, intensity > 0.01 else { return nil }
        let key = "\(kind.rawValue)-\(Int(scale * 10))-\(Int(intensity * 100))"
        if let cached = cache[key] { return cached }
        guard let image = makeNormalMap(kind: kind,
                                        scale: Float(scale),
                                        intensity: Float(intensity)),
              let texture = try? TextureResource.generate(from: image,
                                                          options: .init(semantic: .normal)) else {
            return nil
        }
        cache[key] = texture
        return texture
    }

    // MARK: Üretim

    private static func makeNormalMap(kind: BumpKind, scale: Float, intensity: Float) -> CGImage? {
        let size = 256

        // Deterministik değer gürültüsü kafesi (her açılışta aynı desen).
        var rng = SeededRandom(seed: 42)
        let grid = 64
        var lattice = [Float](repeating: 0, count: grid * grid)
        for index in lattice.indices {
            lattice[index] = rng.nextFloat()
        }

        func latticeValue(_ x: Int, _ y: Int) -> Float {
            let xi = ((x % grid) + grid) % grid
            let yi = ((y % grid) + grid) % grid
            return lattice[yi * grid + xi]
        }

        func smooth(_ t: Float) -> Float { t * t * (3 - 2 * t) }

        func noise(_ x: Float, _ y: Float) -> Float {
            let xi = Int(floor(x)), yi = Int(floor(y))
            let tx = smooth(x - floor(x)), ty = smooth(y - floor(y))
            let a = latticeValue(xi, yi)
            let b = latticeValue(xi + 1, yi)
            let c = latticeValue(xi, yi + 1)
            let d = latticeValue(xi + 1, yi + 1)
            let top = a + (b - a) * tx
            let bottom = c + (d - c) * tx
            return top + (bottom - top) * ty
        }

        // Yükseklik alanı: ahşap damarında desen dikeyde uzar (x sık, y seyrek).
        let freqX: Float
        let freqY: Float
        switch kind {
        case .wood:
            freqX = scale * 3
            freqY = scale * 0.4
        default:
            freqX = scale
            freqY = scale
        }

        var heights = [Float](repeating: 0, count: size * size)
        for y in 0..<size {
            for x in 0..<size {
                let fx = Float(x) / Float(size)
                let fy = Float(y) / Float(size)
                var height = noise(fx * freqX, fy * freqY)
                height += 0.5 * noise(fx * freqX * 2 + 17, fy * freqY * 2 + 17)
                heights[y * size + x] = height / 1.5
            }
        }

        func heightAt(_ x: Int, _ y: Int) -> Float {
            heights[(((y % size) + size) % size) * size + (((x % size) + size) % size)]
        }

        // Yükseklikten normal haritası.
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let strength = intensity * 4
        for y in 0..<size {
            for x in 0..<size {
                let dx = (heightAt(x + 1, y) - heightAt(x - 1, y)) * strength
                let dy = (heightAt(x, y + 1) - heightAt(x, y - 1)) * strength
                let normal = simd_normalize(SIMD3<Float>(-dx, -dy, 1))
                let index = (y * size + x) * 4
                pixels[index] = UInt8((normal.x * 0.5 + 0.5) * 255)
                pixels[index + 1] = UInt8((normal.y * 0.5 + 0.5) * 255)
                pixels[index + 2] = UInt8((normal.z * 0.5 + 0.5) * 255)
                pixels[index + 3] = 255
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &pixels,
                                      width: size,
                                      height: size,
                                      bitsPerComponent: 8,
                                      bytesPerRow: size * 4,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        return context.makeImage()
    }
}

/// Deterministik, hafif rastgele sayı üreteci (LCG).
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func nextFloat() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Float((state >> 33) & 0xFFFFFF) / Float(0xFFFFFF)
    }
}
