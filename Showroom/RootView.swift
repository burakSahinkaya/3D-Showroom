import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            ShowroomHomeView()
                .tabItem { Label("Vitrin", systemImage: "square.grid.2x2") }
            AdminHomeView()
                .tabItem { Label("Yönetim", systemImage: "gearshape") }
        }
        // Önizleme üretimi için arayüzün arkasında duran render alanı.
        // background olarak eklendi: yerleşim ölçülerini ETKİLEMEZ
        // (dar ekranlarda -iPhone- içeriği genişletip kaydırmasın diye).
        .background(
            PreviewRendererHost()
                .frame(width: 640, height: 640)
                .accessibilityHidden(true)
        )
        .task { Seeder.seedIfNeeded(context: context) }
    }
}
