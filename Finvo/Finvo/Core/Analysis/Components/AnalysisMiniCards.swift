import SwiftUI

struct AnalysisMiniCards: View {
    @Environment(\.theme) var theme
    let recurringTransactions: [TransactionModel]
    let biggestTransaction: TransactionModel?
    @AppStorage("appCurrency") private var appCurrencyCode: String = "TRY"
    
    private var baseCurrency: CurrencyType {
        CurrencyType(rawValue: appCurrencyCode) ?? .tryCurrency
    }
    
    var body: some View {
        HStack(spacing: 16) {
            
            // TEKRARLAYAN İŞLEMLER
            NavigationLink(destination: RecurringAnalysisDetailView(transactions: recurringTransactions)) {
                let recAmount = recurringTransactions.reduce(0) { 
                    $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency) 
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "repeat")
                            .foregroundColor(.blue) 
                        Text(L10n("Tekrarlayan"))
                            .font(.caption)
                            .foregroundColor(theme.labelSecondary)
                    }
                    Text("\(recAmount.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))) \(baseCurrency.symbol)")
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
                    let recordSymbol = biggestTransaction?.currency?.symbol ?? baseCurrency.symbol
                    Text("\((biggestTransaction?.amount ?? 0).formatted(.number.grouping(.automatic).precision(.fractionLength(0)))) \(recordSymbol)")
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
