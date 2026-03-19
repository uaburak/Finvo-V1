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
                
                NavigationLink(destination: TransactionsView(selectedType: .expense)) {
                    Text("Tümü")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.brandPrimary)
                }
            }
            // Başlık ve metrik kartları ile hizalı olması için yatay padding eklendi
            .padding(.horizontal)
            
            // Liste Kartı
            VStack(spacing: 8) {
                Text("Henüz işlem bulunmuyor.")
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
                    .padding()
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 24.0))
        }
    }
}

struct RecentTransactionsListView_Previews: PreviewProvider {
    static var previews: some View {
        RecentTransactionsListView()
    }
}
