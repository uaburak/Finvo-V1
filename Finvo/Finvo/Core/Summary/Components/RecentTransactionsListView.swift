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
            VStack(spacing: 8) {
                // Burada örnek verilerle yeni entegre ettiğimiz ListItem bileşenini kullanıyoruz
                ListItem(
                    icon: "wifi",
                    iconColor: theme.brandPrimary,
                    title: "Internet",
                    subtitle: "Fatura",
                    username: "burakkoc",
                    value: "-₺900,00",
                    valueColor: theme.expense,
                    secondaryInfo: "9 Mar 2025"
                )
                .padding(.horizontal, 16)
                
                Divider()
                    .background(theme.separatorSecondary)
                    .padding(.horizontal, 16)
                    
                ListItem(
                    icon: "cart.fill",
                    iconColor: Color.blue,
                    title: "Amazon",
                    subtitle: "Alışveriş",
                    value: "-₺120,00",
                    valueColor: theme.expense,
                    secondaryInfo: "8 Mar 2025"
                )
                .padding(.horizontal, 16)
                
                Divider()
                    .background(theme.separatorSecondary)
                    .padding(.horizontal, 16)
                    
                ListItem(
                    icon: "briefcase.fill",
                    iconColor: Color.green,
                    title: "Maaş",
                    subtitle: "Aylık Gelir",
                    value: "+₺14.500,00",
                    valueColor: theme.income,
                    secondaryInfo: "1 Mar 2025"
                )
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
            .glassEffect(in: .rect(cornerRadius: 24.0))
            .padding(.horizontal)
        }
    }
}

struct RecentTransactionsListView_Previews: PreviewProvider {
    static var previews: some View {
        RecentTransactionsListView()
    }
}
