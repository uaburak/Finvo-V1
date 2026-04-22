import SwiftUI

struct RecordTransactionDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency

    let topTransaction: TransactionModel?
    let allTransactions: [TransactionModel]

    var body: some View {
        ZStack(alignment: .top) {
            theme.background1.ignoresSafeArea()

            if allTransactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(theme.labelSecondary)
                    Text("Bu dönemde hiç işlem bulunamadı.")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(allTransactions.enumerated()), id: \.element.id) { index, tx in
                        let isFirst = index == 0

                        ZStack {
                            NavigationLink(destination: TransactionDetailView(transaction: tx)
                                .environmentObject(walletManager)
                                .environmentObject(authManager)
                                .environmentObject(transactionManager)) {
                                EmptyView()
                            }
                            .opacity(0)

                            ListItem(
                                icon: tx.resolvedIcon,
                                iconColor: tx.resolvedColor(),
                                title: LocalizedStringKey(tx.subCategoryName ?? tx.mainCategoryName),
                                subtitle: LocalizedStringKey(tx.createdBy),
                                isRecurring: tx.isRecurring,
                                value: (tx.type == .income ? "+" : "-") + (tx.currency?.symbol ?? appCurrency.symbol) + tx.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))),
                                valueColor: tx.type == .income ? theme.income : theme.expense,
                                secondaryInfo: tx.date.formatted(date: .abbreviated, time: .omitted),
                                middleView: AnyView(OverlappingAvatarsView(usernames: [tx.createdBy]))
                            )
                            .padding(.leading)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                        .listRowSeparator(.visible)
                        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .top) { Color.clear.frame(height: 120) }
                .safeAreaPadding(.bottom, 40)

                // MARK: Sticky Header
                VStack(spacing: 10) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [theme.expense.opacity(0.8), .orange],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 52, height: 52)
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("En Yüksek 10 İşlem")
                                .font(.headline)
                                .foregroundColor(theme.labelPrimary)
                            if let top = topTransaction {
                                Text("Rekor: \(top.currency?.symbol ?? appCurrency.symbol)\(top.amount.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.subheadline)
                                    .foregroundColor(theme.expense)
                            }
                        }
                        Spacer()
                    }
                }
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Rekor İşlem")
        .navigationBarTitleDisplayMode(.inline)
    }
}
