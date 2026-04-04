import SwiftUI

struct RecentTransactionsListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Başlık Alanı
            HStack {
                Text("Son İşlemler")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.labelPrimary)
                
                Spacer()
                
                NavigationLink {
                    TransactionsView(selectedType: .expense)
                        .environmentObject(walletManager)
                        .environmentObject(transactionManager)
                        .environmentObject(authManager)
                } label: {
                    Text("Tümü")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(theme.brandPrimary)
                }
            }
            // Başlık ve metrik kartları ile hizalı olması için yatay padding eklendi
            .padding(.horizontal)
            
            // Liste Kartı
            VStack(spacing: 0) {
                let transactions = transactionManager.transactions.prefix(5)
                
                if transactions.isEmpty {
                    Text("Henüz işlem bulunmuyor.")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .padding()
                } else {
                    ForEach(transactions) { transaction in
                        let index = transactions.firstIndex(where: { $0.id == transaction.id }) ?? 0
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                                .environmentObject(walletManager)
                                .environmentObject(authManager)
                        } label: {
                            ListItem(
                                icon: transaction.resolvedIcon,
                                iconColor: transaction.resolvedColor(),
                                title: LocalizedStringKey(transaction.resolvedSubCategoryName ?? transaction.resolvedMainCategoryName),
                                subtitle: LocalizedStringKey(transaction.date.formatted(date: .abbreviated, time: .shortened)),
                                value: (transaction.isIncome ? "+\(transaction.currency?.symbol ?? appCurrency.symbol)" : "-\(transaction.currency?.symbol ?? appCurrency.symbol)") + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))),
                                valueColor: transaction.isIncome ? theme.income : theme.expense
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if index < transactions.count - 1 {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .glassEffect(in: .rect(cornerRadius: 24.0))
            .padding(.horizontal)
        }
    }
}

struct RecentTransactionsListView_Previews: PreviewProvider {
    static var previews: some View {
        RecentTransactionsListView()
    }
}
