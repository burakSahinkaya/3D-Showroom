import SwiftUI
import SwiftData

@main
struct ShowroomApp: App {
    let container: ModelContainer

    init() {
        FileStore.ensureDirectories()
        do {
            container = try ModelContainer(for: ModelFolder.self,
                                           Model3D.self,
                                           MaterialPreset.self,
                                           BackgroundItem.self)
        } catch {
            fatalError("Veri deposu oluşturulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
