import SwiftUI

struct SummaryMetricsGridView: View {
    @Environment(\.theme) var theme
    
    // Düzenli 2 kolonlu yapı (Esnek)
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            // Harcama Limiti
            MetricCardView(title: "Harcama Limiti", amount: "₺0,00", iconName: "creditcard.fill", iconColor: theme.expense, progress: 0.0)
            MetricCardView(title: "En Çok Harcama", amount: "-", iconName: "cart.fill", iconColor: .blue, progress: 0.0)
            MetricCardView(title: "Ödeme Takvimi", amount: "-", iconName: "calendar.badge.clock", iconColor: .orange, progress: nil)
            MetricCardView(title: "Akıllı İpuçları", amount: "Yok", iconName: "lightbulb.fill", iconColor: .yellow, progress: nil)
        }
    }
}

// Genel Metrik Kartı - IncomeExpenseCardView stili ile birebir
struct MetricCardView: View {
    @Environment(\.theme) var theme
    
    let title: LocalizedStringKey
    let amount: LocalizedStringKey
    let iconName: String
    let iconColor: Color
    let progress: Double? // Artık opsiyonel, her kartta bar olmak zorunda değil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                // İkon
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold)) // Boyutu biraz büyütülerek denge sağlandı (14->20)
                    .foregroundColor(iconColor)
                
                Spacer()
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.labelSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            
            // Üstten ortaya itmek için esnek boşluk
            Spacer(minLength: 0)
            
            Text(amount)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.labelPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Ortadan alta itmek için ikinci esnek boşluk
            Spacer(minLength: 0)
            
            // Progress Bar (İlerleme Çubuğu) - Eğer progress gönderildiyse çiz
            if let safeProgress = progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Arkaplan Pisti
                        Capsule()
                            .fill(theme.cardBackground)
                            .frame(height: 3)
                        
                        // Dolan Kısım
                        Capsule()
                            .fill(iconColor)
                            .frame(width: max(0, min(CGFloat(safeProgress) * geometry.size.width, geometry.size.width)), height: 3)
                    }
                }
                .frame(height: 3)
            } else {
                // Progress bar olmayan kartlarda tasarım eşitliği (yükseklik kayması olmaması) için görünmez bir alan:
                Spacer()
                    .frame(height: 3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 150)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
}

struct SummaryMetricsGridView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryMetricsGridView()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
