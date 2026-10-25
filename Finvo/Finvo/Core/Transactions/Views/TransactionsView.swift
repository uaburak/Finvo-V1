import SwiftUI


enum DateFilterMode: String, CaseIterable {
    case all = "Tümü"
    case daily = "Günlük"
    case weekly = "Haftalık"
    case monthly = "Aylık"
    case yearly = "Yıllık"
    case custom = "Özel Aralık"

    var title: String { rawValue.localized }
}

enum TransactionSortOrder: String, CaseIterable {
    case newest = "Yeniden Eskiye"
    case oldest = "Eskiden Yeniye"
    case amountDescending = "Tutar (Yüksekten)"
    case amountAscending = "Tutar (Düşükten)"

    var title: String { rawValue.localized }
}

struct TransactionsView: View {
    @Environment(\.theme) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State var selectedType: TransactionType

    @State private var transactionToEdit: TransactionModel?
    @State private var searchText = ""
    
    @State private var dateFilterMode: DateFilterMode = .all
    @State private var sortOrder: TransactionSortOrder = .newest
    @State private var memberFilter: String? = nil
    
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: TransactionModel? = nil
    
    private func filteredItems(for type: TransactionType) -> [TransactionModel] {
        let allItems = transactionManager.transactions
        return allItems.filter { item in
            guard item.type == type else { return false }
            
            if let memberFilter, item.createdBy != memberFilter { return false }
            
            if !searchText.isEmpty {
                guard matchesSearch(item, query: searchText) else { return false }
            }
            
            let calendar = Calendar.current
            let itemDate = item.date
            
            switch dateFilterMode {
            case .all:
                break
            case .daily:
                let start = Date().startOfDay
                let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
                if itemDate < start || itemDate >= end { return false }
            case .weekly:
                let start = Date().startOfWeek
                let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
                if itemDate < start || itemDate >= end { return false }
            case .monthly:
                let start = Date().startOfMonth
                let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
                if itemDate < start || itemDate >= end { return false }
            case .yearly:
                let start = Date().startOfYear
                let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start
                if itemDate < start || itemDate >= end { return false }
            case .custom:
                break
            }
            return true
        }
    }
    
    
    /// Arama: kategori (kayıtlı ve çevrilmiş adıyla), not, ekleyen kişi ve tutar
    private func matchesSearch(_ item: TransactionModel, query rawQuery: String) -> Bool {
        let query = rawQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        let texts = [
            item.mainCategoryName, item.mainCategoryName.localized,
            item.resolvedMainCategoryName, item.resolvedMainCategoryName.localized,
            item.subCategoryName ?? "", (item.subCategoryName ?? "").localized,
            item.resolvedSubCategoryName ?? "",
            item.note ?? "", item.createdBy, item.debtContact ?? ""
        ]
        if texts.contains(where: { $0.localizedCaseInsensitiveContains(query) }) { return true }
        // Tutar araması: "250" veya "1.250,50" gibi girişler
        let digitsQuery = query.filter { $0.isNumber || $0 == "," || $0 == "." }
        if !digitsQuery.isEmpty, digitsQuery.contains(where: \.isNumber) {
            let queryValue = AmountInput.parse(digitsQuery)
            let amountText = AmountInput.display(AmountInput.string(from: item.amount))
            if amountText.contains(digitsQuery) || abs(item.amount - queryValue) < 0.005 { return true }
        }
        return false
    }
    
    private func sorted(_ items: [TransactionModel]) -> [TransactionModel] {
        switch sortOrder {
        case .newest: return items.sorted { $0.date > $1.date }
        case .oldest: return items.sorted { $0.date < $1.date }
        case .amountDescending: return items.sorted { converted($0) > converted($1) }
        case .amountAscending: return items.sorted { converted($0) < converted($1) }
        }
    }
    
    private func converted(_ tx: TransactionModel) -> Double {
        ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: appCurrency)
    }
    
    private var isFiltering: Bool {
        !searchText.isEmpty || dateFilterMode != .all || memberFilter != nil
    }
    
    /// Paylaşımlı cüzdanda filtrelenebilecek üyeler
    private var filterableMembers: [String] {
        guard let wallet = walletManager.activeWallet, wallet.members.count > 1 else { return [] }
        return wallet.members.filter { wallet.permissions[$0] != WalletRole.pending.rawValue }.sorted()
    }
    
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
    
    private var filterMenuButton: some View {
        Menu {
            Picker(L10n("Zaman Filtresi"), selection: $dateFilterMode) {
                ForEach([DateFilterMode.all, .daily, .weekly, .monthly, .yearly], id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            
            Menu {
                Picker(L10n("Sıralama"), selection: $sortOrder) {
                    ForEach(TransactionSortOrder.allCases, id: \.self) { order in
                        Text(order.title).tag(order)
                    }
                }
            } label: {
                Label(L10n("Sıralama"), systemImage: "arrow.up.arrow.down")
            }
            
            if !filterableMembers.isEmpty {
                Menu {
                    Picker(L10n("Ekleyen"), selection: $memberFilter) {
                        Text(L10n("Herkes")).tag(String?.none)
                        ForEach(filterableMembers, id: \.self) { member in
                            Text("@\(member)").tag(String?.some(member))
                        }
                    }
                } label: {
                    Label(L10n("Ekleyen"), systemImage: "person.2")
                }
            }
            
            if dateFilterMode != .all || memberFilter != nil || sortOrder != .newest {
                Button(role: .destructive) {
                    dateFilterMode = .all
                    memberFilter = nil
                    sortOrder = .newest
                } label: {
                    Label(L10n("Filtreleri Temizle"), systemImage: "xmark.circle")
                }
            }
        } label: {
            let isActive = dateFilterMode != .all || memberFilter != nil || sortOrder != .newest
            Image(systemName: isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 18))
                .foregroundStyle(isActive ? theme.brandPrimary : theme.labelPrimary)
        }
    }

    @ViewBuilder
    private func transactionsList(for type: TransactionType) -> some View {
        let items = filteredItems(for: type)
        
        List {
            if !transactionManager.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .listRowBackground(Color.clear)
            } else if items.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView(L10n("İşlem Bulunamadı"), systemImage: "list.bullet",
                                          description: Text(L10n("Bu kriterlere uygun işlem bulunamadı.")))
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .listRowBackground(Color.clear)
            } else {
                let sortedItems = sorted(items)
                if isFiltering {
                    // Filtrelenen işlemlerin özeti
                    let total = items.reduce(0) { $0 + converted($1) }
                    HStack {
                        Text(String(format: L10n("%d işlem"), items.count))
                            .font(.subheadline)
                            .foregroundStyle(theme.labelSecondary)
                        Spacer()
                        Text("\(appCurrency.symbol)\(total.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                            .font(.subheadline.bold())
                            .foregroundStyle(type == .income ? theme.income : theme.expense)
                    }
                    .padding(.horizontal, 20)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowSeparator(.hidden)
                }
                ForEach(sortedItems) { transaction in
                    listRow(for: transaction, isFirst: transaction.id == sortedItems.first?.id)
                }
            }
        }
        .listStyle(.plain)
    }

    var body: some View {
        TabView(selection: $selectedType) {
            transactionsList(for: .expense)
                .tag(TransactionType.expense)
            
            transactionsList(for: .income)
                .tag(TransactionType.income)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .sheet(item: $transactionToEdit) { transaction in
            AddTransactionsView(transactionToEdit: transaction)
                .environmentObject(walletManager)
                .environmentObject(transactionManager)
                .environmentObject(authManager)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSegmentedControl(
            selection: selectedTypeIndex,
            items: segmentItems,
            width: 160
        )
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Ara")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenuButton
            }
        }
        .alert("İşlemi Sil", isPresented: $showDeleteConfirmation) {
            Button("Sil", role: .destructive) {
                if let transaction = transactionToDelete, let id = transaction.id {
                    Task {
                        FirestoreService.shared.deleteTransaction(walletId: transaction.walletId, transactionId: id)
                    }
                }
            }
            Button(L10n("Vazgeç"), role: .cancel) { }
        } message: {
            Text(L10n("Bu işlemi silmek istediğinize emin misiniz? Bu işlem geri alınamaz."))
        }
    }
    
    // MARK: - View Helpers
    private func listRow(for transaction: TransactionModel, isFirst: Bool) -> some View {
        let appLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        let locale = Locale(identifier: appLang)
        let mainTitle = transaction.resolvedSubCategoryName ?? transaction.resolvedMainCategoryName
        let subtitleText = transaction.resolvedSubCategoryName != nil ? transaction.resolvedMainCategoryName : transaction.date.formatted(.dateTime.locale(locale).day().month().year().hour().minute())
        
        let currentUser = authManager.currentUserProfile?.username ?? ""
        let roleRaw = walletManager.activeWallet?.permissions[currentUser] ?? WalletRole.viewer.rawValue
        let role = WalletRole(rawValue: roleRaw) ?? .viewer
        let isOwner = walletManager.activeWallet?.ownerId == currentUser
        
        let isAdminOrOwner = isOwner || role == .admin
        let isCreator = transaction.createdBy == currentUser
        let canManage = isAdminOrOwner || (role == .member && isCreator)
        
        return ZStack {
            NavigationLink(destination: TransactionDetailView(transaction: transaction)
                .environmentObject(walletManager)
                .environmentObject(authManager)
                .environmentObject(transactionManager)) {
                EmptyView()
            }
            .opacity(0)
            
            ListItem(
                icon: transaction.resolvedIcon,
                iconColor: transaction.resolvedColor(),
                title: LocalizedStringKey(mainTitle),
                subtitle: LocalizedStringKey(subtitleText),
                value: (transaction.type == .income ? "+" : "-") + (transaction.currency?.symbol ?? appCurrency.symbol) + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))),
                valueColor: transaction.type == .income ? theme.income : theme.expense,
                secondaryInfo: transaction.date.formatted(.dateTime.locale(locale).day().month().year().hour().minute())
            )
            .padding(.leading)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
        .listRowSeparator(.visible)
        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
        .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
        .contextMenu {
            if canManage {
                Button {
                    transactionToEdit = transaction
                } label: {
                    Text(L10n("Düzenle"))
                }
                
                Button(role: .destructive) {
                    transactionToDelete = transaction
                    showDeleteConfirmation = true
                } label: {
                    Text(L10n("Sil"))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TransactionsView(selectedType: .expense)
    }
}
