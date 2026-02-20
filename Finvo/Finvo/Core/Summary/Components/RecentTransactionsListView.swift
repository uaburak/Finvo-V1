import SwiftUI

struct RecentTransactionsListView: View {
    @Environment(\.theme) var theme
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Başlık Alanı
            HStack {
                Text("Son İşlemler")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.labelPrimary)
                
                Spacer()
                
                Button(action: {
                    // "Tümü" buton aksiyonu
                }) {
                    Text("Tümü")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.brandPrimary)
                }
            }
            .padding(.horizontal)
            
            // Liste Kartı
            VStack(spacing: 0) {
                ForEach(0..<5) { index in
                    TransactionRowView(
                        icon: "wifi",
                        title: "Internet",
                        subtitle: "@burakkoc",
                        amount: "₺ 900,00",
                        date: "9 Mar 2025",
                        isExpense: true
                    )
                    .padding(.horizontal, 16)
                    
                    // Son eleman değilse ayırıcı çizgi koy
                    if index < 4 {
                        Divider()
                            .background(theme.separatorSecondary)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 8)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.separatorSecondary, lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }
}

struct RecentTransactionsListView_Previews: PreviewProvider {
    static var previews: some View {
        RecentTransactionsListView()
    }
}
