import SwiftUI

// Tekil buton modeli
struct QuickActionItem: Identifiable {
    let id = UUID()
    let icon: String // SF Symbol adı
    let title: LocalizedStringKey
}

// Hızlı İşlemler Görünümü
struct QuickActionRowView: View {
    @Environment(\.theme) var theme
    
    // Tasarımdaki ikonlara benzer SF Symbol'ler
    let actions = [
        QuickActionItem(icon: "square.grid.2x2", title: "Kategoriler"),
        QuickActionItem(icon: "creditcard", title: "Borçlar"),
        QuickActionItem(icon: "wallet.bifold", title: "Cüzdanlar"),
        QuickActionItem(icon: "doc.text", title: "Limitler"),
        QuickActionItem(icon: "lanyardcard", title: "Birikimler"),
        QuickActionItem(icon: "ellipsis", title: "Daha Fazla")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(actions) { action in
                        if action.title == "Kategoriler" {
                            NavigationLink(destination: CategoriesListView()) {
                                actionContent(action)
                            }
                            .buttonStyle(.plain)
                        } else {
                            actionContent(action)
                        }
                }
            }
            .padding(.horizontal)
            
        }
        .scrollClipDisabled()
        // ScrollView'un kenar boşluklarını sıfırlamak yerine dışarıdan margin vereceğiz.
        // Ana görünümdeki padding'i iptal etmemek için negatif padding verebiliriz (SummaryView içinde).
    }
    
    @ViewBuilder
    private func actionContent(_ action: QuickActionItem) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Image(systemName: action.icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.labelPrimary)
                    .frame(width: 64, height: 64)
                    .glassEffect(in: .rect(cornerRadius: 20.0))
            }
            Text(action.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.labelPrimary)
        }
    }
}

struct QuickActionRowView_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionRowView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
