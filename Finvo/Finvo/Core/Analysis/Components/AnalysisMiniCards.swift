import SwiftUI

struct AnalysisMiniCards: View {
    @Environment(\.theme) var theme
    let pendingDebtAmount: Double
    let biggestTransaction: TransactionModel?
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.blue) 
                    Text("Bekleyen İşl.")
                        .font(.caption)
                        .foregroundColor(theme.labelSecondary)
                }
                Text("₺\(pendingDebtAmount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.labelPrimary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 20))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.red) 
                    Text("Rekor İşlem")
                        .font(.caption)
                        .foregroundColor(theme.labelSecondary)
                }
                Text("₺\((biggestTransaction?.amount ?? 0).formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(theme.labelPrimary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 20))
        }
    }
}
