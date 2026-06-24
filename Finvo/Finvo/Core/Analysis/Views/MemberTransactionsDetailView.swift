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

    private var filteredTransactions: [TransactionModel] {
        transactions.filter { $0.type == selectedType }
    }

    private var categorySummaries: [(name: String, amount: Double, icon: String, type: TransactionType, count: Int, color: Color)] {
        let grouped = Dictionary(grouping: filteredTransactions, by: { $0.resolvedMainCategoryName })
        return grouped.map { key, txs in
            let total = txs.reduce(0) {
                $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency)
            }
            let icon = txs.first?.resolvedIcon ?? "bag"
            let type = txs.first?.type ?? .expense
            let color = txs.first?.resolvedColor() ?? theme.brandPrimary
            return (name: key, amount: total, icon: icon, type: type, count: txs.count, color: color)
        }.sorted(by: { $0.amount > $1.amount })
    }

    /// Bu üyenin seçili türdeki toplam tutarı
    private var memberTotal: Double {
        transactions.filter { $0.type == selectedType }.reduce(0) {
            $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency)
        }
    }

    /// Tüm cüzdanın seçili türdeki toplam tutarı
    private var walletTotal: Double {
        allTransactions.filter { $0.type == selectedType }.reduce(0) {
            $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency)
        }
    }

    private var contributionRatio: Double {
        walletTotal > 0 ? min(memberTotal / walletTotal, 1.0) : 0
    }

    var body: some View {
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
                if categorySummaries.isEmpty {
                    Text("Bu türde işlem yok.")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .safeAreaInset(edge: .top) { Color.clear.frame(height: stickyHeaderHeight) }
                } else {
                    List {
                        ForEach(Array(categorySummaries.enumerated()), id: \.element.name) { index, cat in
                            let isFirst = index == 0
                            let catTxs = filteredTransactions.filter { $0.resolvedMainCategoryName == cat.name }

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
                            Text(selectedType == .expense ? "Gider Katkısı" : "Gelir Katkısı")
                                .font(.caption)
                                .foregroundColor(theme.labelSecondary)
                            Spacer()
                            Text("\(appCurrency.symbol)\(memberTotal.formatted(.number.precision(.fractionLength(0)))) — %\((contributionRatio * 100).formatted(.number.precision(.fractionLength(1))))")
                                .font(.caption.bold())
                                .foregroundColor(theme.labelPrimary)
                        }

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(selectedType == .expense ? theme.expense : theme.income)
                                    .frame(width: geo.size.width * CGFloat(contributionRatio), height: 8)
                                    .animation(.easeInOut(duration: 0.5), value: contributionRatio)
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
