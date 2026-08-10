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

    var kind: PresetKind {
        get { PresetKind(rawValue: kindRaw) ?? .color }
        set { kindRaw = newValue.rawValue }
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

    init(name: String, hex: String, sortIndex: Int = 0) {
        self.id = UUID()
        self.name = name
        self.hex = hex
        self.sortIndex = sortIndex
    }
}
