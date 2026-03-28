import SwiftUI

struct AnalysisMiniCards: View {
    @Environment(\.theme) var theme
    let recurringTransactions: [TransactionModel]
    let biggestTransaction: TransactionModel?
    
    var body: some View {
        HStack(spacing: 16) {
            
            // TEKRARLAYAN İŞLEMLER
            NavigationLink(destination: RecurringAnalysisDetailView(transactions: recurringTransactions)) {
                let recAmount = recurringTransactions.reduce(0) { $0 + $1.amount }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .foregroundColor(.blue) 
                        Text("Tekrarlayan")
                            .font(.caption)
                            .foregroundColor(theme.labelSecondary)
                    }
                    Text("₺\(recAmount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(theme.labelPrimary)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            
            // REKOR İŞLEM
            NavigationLink(destination: RecordTransactionDetailView(transaction: biggestTransaction)) {
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
            .buttonStyle(.plain)
        }
    }
}
