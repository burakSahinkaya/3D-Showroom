import Foundation
import SwiftData

// MARK: - Klasör

@Model
final class ModelFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortIndex: Int
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Model3D.folder)
    var models: [Model3D] = []

    init(name: String, sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortIndex = sortIndex
        self.createdAt = .now
    }
}

// MARK: - 3D Model

@Model
final class Model3D {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Uygulama sandbox'ındaki USDZ dosya adı.
    var fileName: String
    var folder: ModelFolder?
    var tags: [String]
    var notes: String

    // Gerçek ölçüler (cm)
    var realWidthCM: Double
    var realHeightCM: Double
    var realDepthCM: Double
    var minWidthCM: Double
    var maxWidthCM: Double
    var minHeightCM: Double
    var maxHeightCM: Double

    /// Modeldeki tüm parça adları (içe aktarma sırasında çıkarılır).
    var partNames: [String]
    /// Renk/doku uygulanabilecek parçalar. Camlı kapaklarda cam parçası buradan çıkarılır.
    var paintableParts: [String]

    var defaultPresetID: UUID?
    /// Boş dizi = tüm presetler izinli.
    var allowedPresetIDs: [UUID]
    var backgroundID: UUID?

    /// Önizleme görselleri yenilendiğinde artar; görsel cache'ini tazeler.
    var previewVersion: Int
    var createdAt: Date

    init(name: String, fileName: String) {
        self.id = UUID()
        self.name = name
        self.fileName = fileName
        self.folder = nil
        self.tags = []
        self.notes = ""
        self.realWidthCM = 0
        self.realHeightCM = 0
        self.realDepthCM = 0
        self.minWidthCM = 0
        self.maxWidthCM = 0
        self.minHeightCM = 0
        self.maxHeightCM = 0
        self.partNames = []
        self.paintableParts = []
        self.defaultPresetID = nil
        self.allowedPresetIDs = []
        self.backgroundID = nil
        self.previewVersion = 0
        self.createdAt = .now
    }
}

// MARK: - Renk / Doku Preseti

enum PresetKind: String {
    case color
    case texture
}

/// Prosedürel kabartma (bump) çeşidi.
enum BumpKind: String {
    case none
    /// İnce pürüz — lake yüzeydeki hafif "portakal kabuğu" dokusu.
    case noise
    /// Dikey ahşap damarı.
    case wood
}

@Model
final class MaterialPreset {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var hex: String
    var roughness: Double
    var metallic: Double
    /// Doku presetlerinde sandbox'taki görsel dosya adı.
    var textureFileName: String?
    var tileScale: Double
    var sortIndex: Int

    // Gelişmiş materyal alanları (eski kayıtlar için varsayılan değerlerle gelir).
    /// Yansıma gücü (0-1). Corona'daki IOR'un gerçek zamanlı karşılığı.
    var specular: Double = 0.15
    /// Lake/vernik katmanı miktarı (0 = yok).
    var clearcoat: Double = 0
    /// Lake katmanının pürüzlülüğü (düşük = ayna gibi cila).
    var clearcoatRoughness: Double = 0.1
    var bumpKindRaw: String = BumpKind.none.rawValue
    /// Kabartma şiddeti (0-1).
    var bumpIntensity: Double = 0.3
    /// Kabartma deseni sıklığı (büyük = daha ince desen).
    var bumpScale: Double = 6
    /// 1 = opak; düşük değerler cam görünümü için.
    var opacity: Double = 1
    /// Kontur (outline) kalınlığı; 0 = kapalı. Model boyutunun yüzdesi olarak uygulanır.
    var outlineWidth: Double = 0
    var outlineHex: String = "#1C1C1E"
    /// İç çizgi (derinlik kenarı) hassasiyeti; 0 = kapalı, 1 = en duyarlı.
    var innerLineStrength: Double = 0

    var kind: PresetKind {
        get { PresetKind(rawValue: kindRaw) ?? .color }
        set { kindRaw = newValue.rawValue }
    }

    var bumpKind: BumpKind {
        get { BumpKind(rawValue: bumpKindRaw) ?? .none }
        set { bumpKindRaw = newValue.rawValue }
    }

    init(name: String,
         kind: PresetKind,
         hex: String,
         roughness: Double = 0.55,
         metallic: Double = 0,
         textureFileName: String? = nil,
         tileScale: Double = 1,
         sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.hex = hex
        self.roughness = roughness
        self.metallic = metallic
        self.textureFileName = textureFileName
        self.tileScale = tileScale
        self.sortIndex = sortIndex
    }
}

// MARK: - Arka Plan

@Model
final class BackgroundItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var hex: String
    var sortIndex: Int
    /// Arka plan atanmamış modellerde kullanılacak varsayılan.
    var isDefault: Bool = false

    init(name: String, hex: String, sortIndex: Int = 0, isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.hex = hex
        self.sortIndex = sortIndex
        self.isDefault = isDefault
    }
}

extension Array where Element == BackgroundItem {
    /// Varsayılan işaretli arka plan; yoksa sıradaki ilk öğe.
    var defaultItem: BackgroundItem? {
        first { $0.isDefault } ?? first
    }
}
