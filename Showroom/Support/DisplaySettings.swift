import Foundation
import SwiftUI
import UIKit

/// 3D sahne ışık ayarları — Yönetim > Görüntüleme Ayarları'ndan değiştirilir,
/// UserDefaults'ta saklanır ve viewer + önizleme üreticide ortak kullanılır.
@MainActor
final class DisplaySettings: ObservableObject {
    static let shared = DisplaySettings()

    static let defaultLightIntensity: Double = 1100
    static let defaultAmbientExponent: Double = 0.85
    /// Yatay açı (derece): 0 = tam karşıdan, + sağdan, - soldan.
    static let defaultLightAzimuth: Double = 68
    /// Yükseklik açısı (derece): 0 = model hizası, 90 = tepeden.
    static let defaultLightElevation: Double = 48
    /// Işık sıcaklığı (Kelvin): 2700 sıcak sarı, 6500 nötr beyaz, 8000 soğuk beyaz.
    static let defaultLightTemperature: Double = 6500

    @Published var lightIntensity: Double {
        didSet { UserDefaults.standard.set(lightIntensity, forKey: "display.lightIntensity") }
    }

    @Published var ambientExponent: Double {
        didSet { UserDefaults.standard.set(ambientExponent, forKey: "display.ambientExponent") }
    }

    @Published var lightAzimuth: Double {
        didSet { UserDefaults.standard.set(lightAzimuth, forKey: "display.lightAzimuth") }
    }

    @Published var lightElevation: Double {
        didSet { UserDefaults.standard.set(lightElevation, forKey: "display.lightElevation") }
    }

    @Published var lightTemperature: Double {
        didSet { UserDefaults.standard.set(lightTemperature, forKey: "display.lightTemperature") }
    }

    @Published var shadowsEnabled: Bool {
        didSet { UserDefaults.standard.set(shadowsEnabled, forKey: "display.shadowsEnabled") }
    }

    private init() {
        let defaults = UserDefaults.standard
        lightIntensity = defaults.object(forKey: "display.lightIntensity") as? Double
            ?? Self.defaultLightIntensity
        ambientExponent = defaults.object(forKey: "display.ambientExponent") as? Double
            ?? Self.defaultAmbientExponent
        lightAzimuth = defaults.object(forKey: "display.lightAzimuth") as? Double
            ?? Self.defaultLightAzimuth
        lightElevation = defaults.object(forKey: "display.lightElevation") as? Double
            ?? Self.defaultLightElevation
        lightTemperature = defaults.object(forKey: "display.lightTemperature") as? Double
            ?? Self.defaultLightTemperature
        shadowsEnabled = defaults.object(forKey: "display.shadowsEnabled") as? Bool ?? true
    }

    /// Kelvin değerinden ışık rengi (Tanner Helland yaklaşımı).
    var lightColor: UIColor {
        let temp = lightTemperature / 100
        let red: Double
        let green: Double
        let blue: Double
        if temp <= 66 {
            red = 255
            green = 99.4708025861 * log(temp) - 161.1195681661
            blue = temp <= 19 ? 0 : 138.5177312231 * log(temp - 10) - 305.0447927307
        } else {
            red = 329.698727446 * pow(temp - 60, -0.1332047592)
            green = 288.1221695283 * pow(temp - 60, -0.0755148492)
            blue = 255
        }
        func clamp(_ value: Double) -> CGFloat {
            CGFloat(min(255, max(0, value)) / 255)
        }
        return UIColor(red: clamp(red), green: clamp(green), blue: clamp(blue), alpha: 1)
    }

    /// Açılardan hesaplanan ışık konumu (model merkezine bakar).
    var lightPosition: SIMD3<Float> {
        let distance: Float = 4
        let azimuth = Float(lightAzimuth * .pi / 180)
        let elevation = Float(lightElevation * .pi / 180)
        return SIMD3<Float>(distance * cos(elevation) * sin(azimuth),
                            distance * sin(elevation),
                            distance * cos(elevation) * cos(azimuth))
    }

    func resetToDefaults() {
        lightIntensity = Self.defaultLightIntensity
        ambientExponent = Self.defaultAmbientExponent
        lightAzimuth = Self.defaultLightAzimuth
        lightElevation = Self.defaultLightElevation
        lightTemperature = Self.defaultLightTemperature
        shadowsEnabled = true
    }
}
