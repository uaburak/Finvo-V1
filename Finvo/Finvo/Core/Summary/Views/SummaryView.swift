import SwiftUI

struct SummaryView: View {
    @Environment(\.theme) var theme
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Mavi Bakiye Kartı
                    BalanceCardView()
                        .padding(.horizontal)
                    
                    // Gelir / Gider Alanı
                    HStack(spacing: 16) {
                        NavigationLink(destination: TransactionsView(selectedType: .income)) {
                            IncomeExpenseCardView(title: "Gelir", amount: "₺12,450.00", isIncome: true)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: TransactionsView(selectedType: .expense)) {
                            IncomeExpenseCardView(title: "Gider", amount: "₺4,250.00", isIncome: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    // Hızlı Butonlar Alanı
                    QuickActionRowView()

                    // Esnek 4'lü Metrik Kartları
                    SummaryMetricsGridView()
                        .padding(.horizontal)
                }
                // Mavi kart ve Gelir/Gider HStack'i için padding'i doğrudan içeri taşıdık,
                // Hızlı butonların ekran kenarına kadar kayabilmesi için VStack'deki yatay paddingi kaldırıyoruz.
            }
            .safeAreaPadding(.bottom, 120)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .scrollBounceBehavior(.always, axes: .vertical)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                summaryToolbar()
            }
        }
    }
    
    @ToolbarContentBuilder
    private func summaryToolbar() -> some ToolbarContent {
        // Sol Bölüm (Bildirim / Notification)
        ToolbarItem(placement: .navigationBarLeading) {
            NavigationLink(destination: NotificationsView()) {
                Image(systemName: "bell")
                    .font(.system(size: 16))
                    .foregroundColor(theme.labelPrimary)
            }
        }
        
        // Orta Bölüm (Wallet Switcher)
        ToolbarItem(placement: .principal) {
            Menu {
                Button("Cüzdan 1") { }
                Button("Cüzdan 2") { }
                Button("Cüzdan 3") { }
                Button("Cüzdan 4") { }
                Button("Cüzdan 5") { }
            } label: {
                HStack(spacing: 6) {
                    Text("Cüzdanım")
                        .font(.headline)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                }
                .foregroundColor(theme.labelPrimary)
            }
        }
        
        // Sağ Bölüm (Profil / Avatar)
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink(destination: ProfileView()) {
                Text("B")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.labelPrimary)
            }
        }
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView()
    }
}
