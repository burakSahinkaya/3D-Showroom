import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        ZStack {
            // Önizleme üretimi için arayüzün arkasında duran render alanı.
            PreviewRendererHost()
                .frame(width: 640, height: 640)
                .accessibilityHidden(true)

            TabView {
                ShowroomHomeView()
                    .tabItem { Label("Vitrin", systemImage: "square.grid.2x2") }
                AdminHomeView()
                    .tabItem { Label("Yönetim", systemImage: "gearshape") }
            }
            .background(Color(uiColor: .systemBackground))
        }
        .task { Seeder.seedIfNeeded(context: context) }
    }
}
