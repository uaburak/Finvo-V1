import SwiftUI

struct RecurringAnalysisDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    let transactions: [TransactionModel]
    @State private var selectedType: TransactionType = .expense
    @State private var selectedUser: String? = nil
    
    // Segmented control için Int index ↔ TransactionType dönüşümü
    private var selectedTypeIndex: Binding<Int> {
        Binding(
            get: { selectedType == .expense ? 0 : 1 },
            set: { selectedType = $0 == 0 ? .expense : .income }
        )
    }
    
    private var segmentItems: [String] {
        [L10n("Gider"), L10n("Gelir")]
    }
    
    private func filteredTransactions(for type: TransactionType) -> [TransactionModel] {
        let typeTxs = transactions.filter { $0.type == type }
        if let user = selectedUser {
            return typeTxs.filter { $0.createdBy == user }
        }
        return typeTxs
    }

    @ViewBuilder
    private func recurringContent(for type: TransactionType) -> some View {
        let typeTxs = filteredTransactions(for: type)
        
        ZStack(alignment: .top) {
            theme.background1.ignoresSafeArea()
            
            if transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.blue)
                    Text("Tekrarlayan (Abonelik) işlem verisi yok.")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxHeight: .infinity)
            } else {
                if typeTxs.isEmpty {
                    Text(verbatim: "\(type.localizedTitle) \("türünde seçili kullanıcıya ait abonelik işlemi yok.".localized)")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        // Alt kategoriye göre öncelikli, yoksa ana kategoriye göre grupla
                        let grouped = Dictionary(grouping: typeTxs, by: { $0.subCategoryName ?? $0.mainCategoryName })
                        let subCategorySums = grouped.map { key, txs in
                            let amount = txs.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency) }
                            let count = txs.count
                            let icon = txs.first?.categoryIcon ?? "bag"
                            let catType = txs.first!.type
                            let uniqueMembers = Array(Set(txs.map { $0.createdBy })).sorted()
                            return (name: key, amount: amount, count: count, icon: icon, type: catType, members: uniqueMembers, transactions: txs)
                        }.sorted(by: { $0.amount > $1.amount })
                        
                        ForEach(subCategorySums, id: \.name) { cat in
                            let isFirst = cat.name == subCategorySums.first?.name
                            
                            ZStack {
                                NavigationLink(destination: CategoryRecurringTransactionsView(categoryName: cat.name, transactions: cat.transactions)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                let catColor = cat.transactions.first?.resolvedColor() ?? theme.brandPrimary
                                ListItem(
                                    icon: cat.icon,
                                    iconColor: catColor,
                                    title: LocalizedStringKey(cat.name),
                                    subtitle: LocalizedStringKey("\(cat.count) İşlem"),
                                    value: "\(cat.type == .income ? "+" : "-")\(appCurrency.symbol)\(cat.amount.formatted(.number.precision(.fractionLength(0))))",
                                    valueColor: theme.labelPrimary,
                                    middleView: AnyView(OverlappingAvatarsView(usernames: cat.members))
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
                        Color.clear.frame(height: 120) // Sticky header clearance
                    }
                    .safeAreaPadding(.bottom, 40)
                    
                    // Sticky Top Header
                    let total = typeTxs.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency) }
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type == .expense ? "Aboneliklere Ödenen Toplam" : "Düzenli Gelir Toplamı")
                                .font(.footnote)
                                .foregroundColor(theme.labelSecondary)
                            Text("\(type == .income ? "+" : "")\(appCurrency.symbol)\(total.formatted(.number.precision(.fractionLength(0))))")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(type == .expense ? theme.expense : theme.income)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .glassEffect(in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedType) {
            recurringContent(for: .expense)
                .tag(TransactionType.expense)
            
            recurringContent(for: .income)
                .tag(TransactionType.income)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .navigationTitle(L10n("Tekrarlayan İşlemler"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationSegmentedControl(
            selection: selectedTypeIndex,
            items: segmentItems,
            width: 160
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Kullanıcı", selection: $selectedUser) {
                        Text("Tüm Üyeler").tag(Optional<String>.none)
                        let members = walletManager.activeWallet?.members ?? []
                        ForEach(members, id: \.self) { member in
                            Text(member).tag(Optional(member))
                        }
                    }
                } label: {
                    Image(systemName: selectedUser == nil ? "person.2.badge.gearshape" : "person.2.badge.gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(selectedUser == nil ? theme.labelPrimary : Color.accentColor)
                }
                .opacity(transactions.isEmpty ? 0 : 1)
                .disabled(transactions.isEmpty)
            }
        }
    }
}

struct OverlappingAvatarsView: View {
    let usernames: [String]
    var body: some View {
        HStack(spacing: -8) {
            ForEach(usernames.prefix(3), id: \.self) { username in
                MemberAvatarView(username: username, size: 24)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 1))
            }
            if usernames.count > 3 {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .overlay(Text("+\(usernames.count - 3)").font(.system(size: 8, weight: .bold)))
            }
        }
    }
}

struct CategoryRecurringTransactionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    let categoryName: String
    let transactions: [TransactionModel]
    
    private func getSecondaryInfo(for tx: TransactionModel) -> String {
        if tx.isPaid {
            return tx.date.formatted(date: .abbreviated, time: .shortened)
        } else {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let txDate = calendar.startOfDay(for: tx.date)
            let days = calendar.dateComponents([.day], from: today, to: txDate).day ?? 0
            
            if days > 0 {
                return String(format: L10n("%d gün kaldı"), days)
            } else if days == 0 {
                return L10n("Bugün")
            } else {
                return String(format: L10n("%d gün geçti"), abs(days))
            }
        }
    }
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
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
                            valueColor: tx.isPaid ? (tx.type == .income ? theme.income : theme.expense) : .gray,
                            secondaryInfo: getSecondaryInfo(for: tx)
                        )
                        .padding(.leading)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                    .listRowSeparator(.visible)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(LocalizedStringKey(categoryName))
        .navigationBarTitleDisplayMode(.inline)
    }
}
