import SwiftUI

struct CategoryDistributionDetailView: View {
    @Environment(\.theme) var theme
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    let transactions: [TransactionModel]
    @State private var selectedType: TransactionType = .expense
    
    // Compute summaries based on selection
    private var categorySummaries: [CategorySummary] {
        var catDict: [String: (amount: Double, icon: String, count: Int, color: Color, members: Set<String>)] = [:]
        
        let typeFilteredTxs = transactions.filter { $0.type == selectedType }
        let totalTypeAmount = typeFilteredTxs.reduce(0) { 
            $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency)
        }
        
        for tx in typeFilteredTxs {
            let convertedAmount = ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: appCurrency)
            let cat = tx.mainCategoryName
            let currentCat = catDict[cat] ?? (amount: 0, icon: tx.categoryIcon, count: 0, color: tx.resolvedColor(), members: [])
            var currentMembers = currentCat.members
            currentMembers.insert(tx.createdBy)
            catDict[cat] = (amount: currentCat.amount + convertedAmount, icon: tx.categoryIcon, count: currentCat.count + 1, color: currentCat.color, members: currentMembers)
        }
        
        return catDict.map { 
            CategorySummary(
                name: $0.key, amount: $0.value.amount, icon: $0.value.icon,
                percentage: totalTypeAmount > 0 ? ($0.value.amount / totalTypeAmount) * 100 : 0,
                transactionCount: $0.value.count,
                color: $0.value.color,
                members: Array($0.value.members).sorted()
            ) 
        }.sorted(by: { $0.amount > $1.amount })
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            theme.background1.ignoresSafeArea()
            
            let summaries = categorySummaries // compute once for the view
            
            if summaries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 56))
                        .foregroundColor(theme.labelSecondary)
                    Text("Bu dönemde veri yok")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                        let isFirst = index == 0
                        let catTxs = transactions.filter {
                            $0.mainCategoryName == summary.name && $0.type == selectedType
                        }
                        
                        ZStack {
                            NavigationLink(destination: CategoryDistributionTransactionsView(
                                categoryName: summary.name,
                                transactions: catTxs
                            )) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            ListItem(
                                icon: summary.icon,
                                iconColor: summary.color,
                                title: LocalizedStringKey(summary.name),
                                subtitle: LocalizedStringKey("\(summary.transactionCount) İşlem"),
                                value: (selectedType == .income ? "+" : "-") + "\(appCurrency.symbol)\(summary.amount.formatted(.number.precision(.fractionLength(0))))",
                                valueColor: theme.labelPrimary,
                                secondaryInfo: "%\(summary.percentage.formatted(.number.precision(.fractionLength(1))))",
                                middleView: AnyView(OverlappingAvatarsView(usernames: summary.members))
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
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 250) // Sticky header clearance
                }
                .safeAreaPadding(.bottom, 40)
                
                // Sticky Top Header
                VStack(spacing: 16) {
                    Text(selectedType == .expense ? "Gider Dağılımı" : "Gelir Dağılımı")
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    NativeDonutChart(data: summaries)
                        .frame(width: 140, height: 140)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Dağılım Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if !transactions.isEmpty {
                    Picker("İşlem Türü", selection: $selectedType) {
                        Text("Gider").tag(TransactionType.expense)
                        Text("Gelir").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
        }
    }
}



#Preview {
    NavigationStack {
        CategoryDistributionDetailView(transactions: [])
        .environment(\.theme, DefaultTheme())
    }
}

// MARK: - Category Transactions Detail
struct CategoryDistributionTransactionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager

    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency

    let categoryName: String
    let transactions: [TransactionModel]

    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()

            if transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 48))
                        .foregroundColor(theme.labelSecondary)
                    Text("İşlem bulunamadı")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(transactions.sorted(by: { $0.date > $1.date })) { tx in
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
                                value: (tx.type == .income ? "+" : "-") + (tx.currency?.symbol ?? appCurrency.symbol) + tx.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))),
                                valueColor: tx.type == .income ? theme.income : theme.expense,
                                secondaryInfo: tx.date.formatted(date: .abbreviated, time: .shortened)
                            )
                            .padding(.leading)
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                        .listRowSeparator(.visible)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .safeAreaPadding(.bottom, 40)
            }
        }
        .navigationTitle(LocalizedStringKey(categoryName))
        .navigationBarTitleDisplayMode(.inline)
    }
}
