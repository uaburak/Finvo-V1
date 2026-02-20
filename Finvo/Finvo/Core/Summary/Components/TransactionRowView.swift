import SwiftUI

struct TransactionRowView: View {
    @Environment(\.theme) var theme
    
    let icon: String // SF Symbol
    let title: String
    let subtitle: String
    let amount: String
    let date: String
    let isExpense: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // İkon Alanı
            ZStack {
                Circle()
                    .fill(theme.brandPrimary)
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Metinler
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.labelPrimary)
                
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(theme.labelSecondary)
            }
            
            Spacer()
            
            // Tutar ve Tarih
            VStack(alignment: .trailing, spacing: 4) {
                Text(amount)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(isExpense ? theme.expense : theme.income)
                
                Text(date)
                    .font(.footnote)
                    .foregroundColor(theme.labelSecondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct TransactionRowView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionRowView(
            icon: "wifi",
            title: "Internet",
            subtitle: "@burakkoc",
            amount: "₺ 900,00",
            date: "9 Mar 2025",
            isExpense: true
        )
        .padding()
        .background(Color.black) // Dark mode görünümü için
        .previewLayout(.sizeThatFits)
    }
}
