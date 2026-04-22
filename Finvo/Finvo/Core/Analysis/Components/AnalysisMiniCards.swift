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
        let recAmount = recurringTransactions.reduce(0) { 
            $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency) 
        }
        
        HStack(spacing: 16) {
            // TEKRARLAYAN İŞLEMLER
            NavigationLink(destination: RecurringAnalysisDetailView(transactions: recurringTransactions)) {
                miniCard(
                    icon: "repeat",
                    iconColor: .blue,
                    label: "Tekrarlayan",
                    amount: recAmount,
                    currencySymbol: baseCurrency.symbol
                )
            }
            .buttonStyle(.plain)
            
            // REKOR İŞLEM
            NavigationLink(destination: RecordTransactionDetailView(transaction: biggestTransaction)) {
                miniCard(
                    icon: "flame.fill",
                    iconColor: .red,
                    label: "Rekor İşlem",
                    amount: biggestTransaction?.amount ?? 0,
                    currencySymbol: biggestTransaction?.currency?.symbol ?? baseCurrency.symbol
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func miniCard(icon: String, iconColor: Color, label: String, amount: Double, currencySymbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(iconColor)
                    .frame(width: 20, height: 20)
                
                Text(LocalizedStringKey(label))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.labelSecondary)
            }
            
            Text("\(amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))) \(currencySymbol)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(theme.labelPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .padding(.horizontal, 16)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}


