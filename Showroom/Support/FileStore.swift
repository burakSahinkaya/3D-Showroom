import Foundation

/// Model, doku ve önizleme dosyalarının sandbox içindeki yerleşimini yönetir.
enum FileStore {
    static let base: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShowroomData", isDirectory: true)
    }()

    static var modelsDir: URL { base.appendingPathComponent("Models", isDirectory: true) }
    static var texturesDir: URL { base.appendingPathComponent("Textures", isDirectory: true) }
    static var previewsDir: URL { base.appendingPathComponent("Previews", isDirectory: true) }

    static func ensureDirectories() {
        for dir in [modelsDir, texturesDir, previewsDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: İçe aktarma

    /// Files'tan seçilen dosyayı sandbox'a kopyalar, saklanan dosya adını döndürür.
    private static func importFile(from source: URL, into dir: URL) throws -> String {
        let ext = source.pathExtension.isEmpty ? "dat" : source.pathExtension.lowercased()
        let name = UUID().uuidString + "." + ext
        let dest = dir.appendingPathComponent(name)
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        try FileManager.default.copyItem(at: source, to: dest)
        return name
    }

    static func importModelFile(from source: URL) throws -> String {
        try importFile(from: source, into: modelsDir)
    }

    static func importTextureFile(from source: URL) throws -> String {
        try importFile(from: source, into: texturesDir)
    }

    // MARK: Yollar

    static func modelURL(_ fileName: String) -> URL {
        modelsDir.appendingPathComponent(fileName)
    }

    static func textureURL(_ fileName: String) -> URL {
        texturesDir.appendingPathComponent(fileName)
    }

    static func previewDir(modelID: UUID) -> URL {
        previewsDir.appendingPathComponent(modelID.uuidString, isDirectory: true)
    }

    /// presetID nil = orijinal materyallerle üretilen önizleme.
    static func previewURL(modelID: UUID, presetID: UUID?) -> URL {
        previewDir(modelID: modelID)
            .appendingPathComponent((presetID?.uuidString ?? "original") + ".png")
    }

    // MARK: Silme

    static func deleteModelData(fileName: String, modelID: UUID) {
        try? FileManager.default.removeItem(at: modelURL(fileName))
        try? FileManager.default.removeItem(at: previewDir(modelID: modelID))
    }

    static func deleteTexture(fileName: String) {
        try? FileManager.default.removeItem(at: textureURL(fileName))
    }
}
