import SwiftUI

struct IncomeExpenseCardView: View {
    @Environment(\.theme) var theme
    
    let title: String
    let amount: String
    let isIncome: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // İkon (Gelir: Aşağı Sol Ok, Gider: Yukarı Sağ Ok)
                Image(systemName: isIncome ? "arrow.down.left" : "arrow.up.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isIncome ? theme.income : theme.expense)
                
                Spacer()
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
            }
            
            Text(amount)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(theme.labelPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
}

struct IncomeExpenseCardView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            IncomeExpenseCardView(title: "Gelir", amount: "$12,450.00", isIncome: true)
            IncomeExpenseCardView(title: "Gider", amount: "$12,450.00", isIncome: false)
        }
        .padding(.horizontal)
        .previewLayout(.sizeThatFits)
    }
}
