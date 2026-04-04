import SwiftUI

struct RecurringTransactionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
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
                let sortedRecurringTxs = recurringTxs.sorted(by: { $0.date > $1.date })
                List {
                    ForEach(sortedRecurringTxs) { transaction in
                        let isFirst = transaction.id == sortedRecurringTxs.first?.id
                        let displayTitle = (transaction.note?.isEmpty == false) ? transaction.note! : (transaction.resolvedSubCategoryName ?? transaction.resolvedMainCategoryName)
                        let subtitleText = "\(transaction.recurrenceInterval?.rawValue ?? "") Tekrar • " + (transaction.resolvedSubCategoryName != nil ? transaction.resolvedMainCategoryName : transaction.date.formatted(date: .abbreviated, time: .shortened))

                        ZStack {
                            NavigationLink(destination: TransactionDetailView(transaction: transaction)) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            ListItem(
                                icon: transaction.resolvedIcon,
                                iconColor: transaction.resolvedColor(),
                                title: LocalizedStringKey(displayTitle),
                                subtitle: LocalizedStringKey(subtitleText),
                                value: (transaction.type == .income ? "+\(transaction.currency?.symbol ?? appCurrency.symbol)" : "-\(transaction.currency?.symbol ?? appCurrency.symbol)") + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))),
                                valueColor: transaction.type == .income ? theme.income : theme.expense, // özet ekranı uyumu için
                                secondaryInfo: transaction.date.formatted(date: .abbreviated, time: .shortened)
                            )
                            .padding(.leading)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                        .listRowSeparator(.visible)
                        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                        .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Tekrarlayan İşlemler")
        .navigationBarTitleDisplayMode(.inline)
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
