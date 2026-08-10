import SwiftUI
import SwiftData

/// 3D sahne arka planları (düz renk) kütüphanesi.
struct BackgroundLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \BackgroundItem.sortIndex) private var backgrounds: [BackgroundItem]

    var body: some View {
        List {
            ForEach(backgrounds) { background in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(hex: background.hex))
                        .frame(width: 44, height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.black.opacity(0.1)))
                    VStack(alignment: .leading, spacing: 2) {
                        TextField("Ad", text: nameBinding(for: background))
                        if background.isDefault {
                            Text("Varsayılan")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Button {
                        setDefault(background)
                    } label: {
                        Image(systemName: background.isDefault ? "star.fill" : "star")
                            .foregroundStyle(background.isDefault ? .orange : .secondary)
                    }
                    .buttonStyle(.plain)
                    ColorPicker("", selection: colorBinding(for: background), supportsOpacity: false)
                        .labelsHidden()
                }
            }
            .onDelete(perform: deleteBackgrounds)
        }
        .navigationTitle("Arka Planlar")
        .toolbar {
            Button {
                addBackground()
            } label: {
                Label("Ekle", systemImage: "plus")
            }
        }
        .overlay {
            if backgrounds.isEmpty {
                ContentUnavailableView("Arka plan yok", systemImage: "photo")
            }
        }
    }

    private func nameBinding(for background: BackgroundItem) -> Binding<String> {
        Binding(
            get: { background.name },
            set: { background.name = $0 })
    }

    private func colorBinding(for background: BackgroundItem) -> Binding<Color> {
        Binding(
            get: { Color(hex: background.hex) },
            set: { background.hex = UIColor($0).hexString })
    }

    private func setDefault(_ background: BackgroundItem) {
        for item in backgrounds {
            item.isDefault = (item.id == background.id)
        }
        try? context.save()
    }

    private func addBackground() {
        let nextIndex = (backgrounds.map(\.sortIndex).max() ?? -1) + 1
        context.insert(BackgroundItem(name: "Yeni Arka Plan", hex: "#EDEDED", sortIndex: nextIndex))
        try? context.save()
    }

    private func deleteBackgrounds(at offsets: IndexSet) {
        for index in offsets {
            context.delete(backgrounds[index])
        }
        try? context.save()
    }
}
