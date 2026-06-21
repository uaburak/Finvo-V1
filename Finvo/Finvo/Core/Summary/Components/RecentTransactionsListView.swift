import SwiftUI

struct RecentTransactionsListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State private var displayedLimit = 14
    @State private var isLoadingMore = false
    
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
            .padding(.horizontal)
            
            // Liste
            let transactions = transactionManager.transactions
            let transactionsToShow = Array(transactions.prefix(displayedLimit))
            
            if transactions.isEmpty {
                Text("Henüz işlem bulunmuyor.")
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(transactionsToShow) { transaction in
                        let isLast = transaction.id == transactionsToShow.last?.id
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                                .environmentObject(walletManager)
                                .environmentObject(authManager)
                                .environmentObject(transactionManager)
                        } label: {
                            ListItem(
                                icon: transaction.resolvedIcon,
                                iconColor: transaction.resolvedColor(),
                                title: LocalizedStringKey(transaction.resolvedSubCategoryName ?? transaction.resolvedMainCategoryName),
                                subtitle: LocalizedStringKey(transaction.date.formatted(date: .abbreviated, time: .shortened)),
                                value: (transaction.isIncome ? "+\(transaction.currency?.symbol ?? appCurrency.symbol)" : "-\(transaction.currency?.symbol ?? appCurrency.symbol)") + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))),
                                valueColor: transaction.isIncome ? theme.income : theme.expense
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if isLast && transactions.count > displayedLimit && !isLoadingMore {
                                isLoadingMore = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                    displayedLimit += 14
                                    isLoadingMore = false
                                }
                            }
                        }
                        
                        if !isLast || isLoadingMore {
                            Divider()
                                .padding(.leading, 56)
                                .padding(.horizontal)
                        }
                    }
                    
                    if isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
    }
}

struct RecentTransactionsListView_Previews: PreviewProvider {
    static var previews: some View {
        RecentTransactionsListView()
            .environmentObject(WalletManager())
            .environmentObject(TransactionManager())
            .environmentObject(AuthenticationManager.shared)
    }
}
