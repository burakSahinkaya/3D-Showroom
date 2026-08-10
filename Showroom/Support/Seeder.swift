import Foundation
import SwiftData

/// İlk açılışta varsayılan renk presetlerini ve arka planları oluşturur.
@MainActor
enum Seeder {
    static func seedIfNeeded(context: ModelContext) {
        let presetCount = (try? context.fetchCount(FetchDescriptor<MaterialPreset>())) ?? 0
        if presetCount == 0 {
            let defaults: [(String, String, Double)] = [
                ("Beyaz", "#F2F1EC", 0.5),
                ("Krem", "#E6D9C3", 0.55),
                ("Açık Meşe", "#C79A63", 0.6),
                ("Ceviz", "#6E4B2F", 0.6),
                ("Duman Grisi", "#9B9B9B", 0.5),
                ("Antrasit", "#3B3B3D", 0.5),
            ]
            for (index, item) in defaults.enumerated() {
                context.insert(MaterialPreset(name: item.0,
                                              kind: .color,
                                              hex: item.1,
                                              roughness: item.2,
                                              sortIndex: index))
            }
        }

        let bgCount = (try? context.fetchCount(FetchDescriptor<BackgroundItem>())) ?? 0
        if bgCount == 0 {
            let defaults: [(String, String)] = [
                ("Açık Gri", "#EDEDED"),
                ("Beyaz", "#FFFFFF"),
                ("Bej", "#EFE7DA"),
                ("Koyu", "#2B2B2E"),
            ]
            for (index, item) in defaults.enumerated() {
                context.insert(BackgroundItem(name: item.0, hex: item.1, sortIndex: index))
            }
        }

        try? context.save()
    }
}
