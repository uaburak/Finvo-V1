import SwiftUI

struct RecurringTransactionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            let recurringTxs = transactionManager.transactions.filter { $0.isRecurring }
            
            if recurringTxs.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "repeat.circle")
                        .font(.system(size: 60))
                        .foregroundColor(theme.labelSecondary)
                    Text("Kayıtlı İşlem Yok")
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                        .padding(.top, 10)
                    Text("Düzenli tekrar eden bir abonelik veya işleminiz bulunmuyor.")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(recurringTxs) { transaction in
                            NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                recurringCard(for: transaction)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Tekrarlayan İşlemler")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func recurringCard(for transaction: TransactionModel) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(transaction.type == .income ? theme.income.opacity(0.15) : theme.expense.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: transaction.categoryIcon)
                    .foregroundColor(transaction.type == .income ? theme.income : theme.expense)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                let displayTitle = (transaction.note?.isEmpty == false) ? transaction.note! : transaction.mainCategoryName
                Text(displayTitle)
                    .font(.headline)
                    .foregroundColor(theme.labelPrimary)
                    .lineLimit(1)
                
                if let interval = transaction.recurrenceInterval {
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Text("\(interval.rawValue) Tekrar")
                            .font(.caption)
                            .foregroundColor(theme.labelSecondary)
                    }
                }
            }
            
            Spacer()
            
            Text((transaction.type == .income ? "+₺" : "-₺") + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))
                .font(.headline.bold())
                .foregroundColor(theme.labelPrimary) // Tutarı label rengi yaptık özet ekranındaki gibi tutarlılık açısından
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
        .padding(.horizontal, 4) // Shadow taşması olmaması için
    }
}

#Preview {
    NavigationStack {
        RecurringTransactionsView()
            .environment(\.theme, DefaultTheme())
            .environmentObject(TransactionManager())
            .environmentObject(WalletManager())
    }
}
