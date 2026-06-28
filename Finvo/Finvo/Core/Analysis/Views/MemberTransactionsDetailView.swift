import SwiftUI

struct MemberTransactionsDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency

    let username: String
    let transactions: [TransactionModel]   // Bu üyenin işlemleri
    let allTransactions: [TransactionModel] // Tüm cüzdanın işlemleri

    @State private var userModel: UserModel? = nil
    @State private var selectedType: TransactionType = .expense
    
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
        transactions.filter { $0.type == type }
    }

    private func categorySummaries(for type: TransactionType) -> [(name: String, amount: Double, icon: String, type: TransactionType, count: Int, color: Color)] {
        let grouped = Dictionary(grouping: filteredTransactions(for: type), by: { $0.resolvedMainCategoryName })
        return grouped.map { key, txs in
            let total = txs.reduce(0) {
                $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency)
            }
            let icon = txs.first?.resolvedIcon ?? "bag"
            let catType = txs.first?.type ?? .expense
            let color = txs.first?.resolvedColor() ?? theme.brandPrimary
            return (name: key, amount: total, icon: icon, type: catType, count: txs.count, color: color)
        }.sorted(by: { $0.amount > $1.amount })
    }

    /// Bu üyenin seçili türdeki toplam tutarı
    private func memberTotal(for type: TransactionType) -> Double {
        transactions.filter { $0.type == type }.reduce(0) {
            $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency)
        }
    }

    /// Tüm cüzdanın seçili türdeki toplam tutarı
    private func walletTotal(for type: TransactionType) -> Double {
        allTransactions.filter { $0.type == type }.reduce(0) {
            $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency)
        }
    }

    private func contributionRatio(for type: TransactionType) -> Double {
        let wTotal = walletTotal(for: type)
        return wTotal > 0 ? min(memberTotal(for: type) / wTotal, 1.0) : 0
    }

    @ViewBuilder
    private func memberTransactionsContent(for type: TransactionType) -> some View {
        let summaries = categorySummaries(for: type)
        let fTransactions = filteredTransactions(for: type)
        let mTotal = memberTotal(for: type)
        let ratio = contributionRatio(for: type)
        
        ZStack(alignment: .top) {
            theme.background1.ignoresSafeArea()

            if transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 48))
                        .foregroundColor(theme.labelSecondary)
                    Text("\(username) henüz işlem yapmadı.")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                if summaries.isEmpty {
                    Text("Bu türde işlem yok.")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .safeAreaInset(edge: .top) { Color.clear.frame(height: stickyHeaderHeight) }
                } else {
                    List {
                        ForEach(Array(summaries.enumerated()), id: \.element.name) { index, cat in
                            let isFirst = index == 0
                            let catTxs = fTransactions.filter { $0.resolvedMainCategoryName == cat.name }

                            ZStack {
                                NavigationLink(destination: CategoryDistributionTransactionsView(
                                    categoryName: cat.name,
                                    transactions: catTxs
                                )) {
                                    EmptyView()
                                }
                                .opacity(0)

                                ListItem(
                                    icon: cat.icon,
                                    iconColor: cat.color,
                                    title: LocalizedStringKey(cat.name),
                                    subtitle: LocalizedStringKey("\(cat.count) İşlem"),
                                    value: (cat.type == .income ? "+" : "-") + "\(appCurrency.symbol)\(cat.amount.formatted(.number.precision(.fractionLength(0))))",
                                    valueColor: cat.type == .income ? theme.income : theme.expense
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
                    .safeAreaInset(edge: .top) { Color.clear.frame(height: stickyHeaderHeight) }
                    .safeAreaPadding(.bottom, 40)
                }

                // MARK: Sticky Header
                VStack(spacing: 0) {
                    // Profile row: photo left, name+username right
                    HStack(spacing: 14) {
                        MemberAvatarView(username: username, size: 60)

                        VStack(alignment: .leading, spacing: 3) {
                            if let user = userModel {
                                Text(user.fullName)
                                    .font(.headline)
                                    .foregroundColor(theme.labelPrimary)
                                    .lineLimit(1)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundColor(theme.labelSecondary)
                                    .lineLimit(1)
                            } else {
                                Text("@\(username)")
                                    .font(.headline)
                                    .foregroundColor(theme.labelPrimary)
                                Text("Yükleniyor...")
                                    .font(.caption)
                                    .foregroundColor(theme.labelSecondary)
                            }
                        }
                        Spacer()
                    }

                    // Progress bar row
                    VStack(spacing: 6) {
                        HStack {
                            Text(type == .expense ? "Gider Katkısı" : "Gelir Katkısı")
                                .font(.caption)
                                .foregroundColor(theme.labelSecondary)
                            Spacer()
                            Text("\(appCurrency.symbol)\(mTotal.formatted(.number.precision(.fractionLength(0)))) — %\((ratio * 100).formatted(.number.precision(.fractionLength(1))))")
                                .font(.caption.bold())
                                .foregroundColor(theme.labelPrimary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(type == .expense ? theme.expense : theme.income)
                                    .frame(width: geo.size.width * CGFloat(ratio), height: 8)
                                    .animation(.easeInOut(duration: 0.5), value: ratio)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.top, 14)
                }
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedType) {
            memberTransactionsContent(for: .expense)
                .tag(TransactionType.expense)
            
            memberTransactionsContent(for: .income)
                .tag(TransactionType.income)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .navigationTitle("Üye Özeti")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSegmentedControl(
            selection: selectedTypeIndex,
            items: segmentItems,
            width: 160
        )
        .task {
            userModel = try? await FirestoreService.shared.getUserProfileByUsername(username)
        }
    }

    // Sticky card height estimate (photo 60 + paddings + progress section)
    private var stickyHeaderHeight: CGFloat { 160 }
}
