import SwiftUI
import UIKit

/// Diskteki önizleme PNG'sini gösterir; yoksa placeholder gösterip arka planda üretim tetikler.
struct PreviewImage: View {
    let model: Model3D
    let presetID: UUID?

    @State private var image: UIImage?

    private static let cache = NSCache<NSString, UIImage>()

    private var cacheKey: NSString {
        "\(model.id.uuidString)-\(presetID?.uuidString ?? "original")-\(model.previewVersion)" as NSString
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                Rectangle()
                    .fill(Color(uiColor: .secondarySystemBackground))
                Image(systemName: "cube.transparent")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: image)
        .task(id: cacheKey) { await load() }
    }

    private func load() async {
        if let cached = Self.cache.object(forKey: cacheKey) {
            image = cached
            return
        }
        let url = FileStore.previewURL(modelID: model.id, presetID: presetID)
        if let data = try? Data(contentsOf: url), let loaded = UIImage(data: data) {
            Self.cache.setObject(loaded, forKey: cacheKey)
            image = loaded
        } else {
            image = nil
            PreviewRenderer.shared.generateMissingIfNeeded(for: model)
        }
    }
}
