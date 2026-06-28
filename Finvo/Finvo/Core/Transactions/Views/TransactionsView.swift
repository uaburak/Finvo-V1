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
    
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: TransactionModel? = nil
    
    private func filteredItems(for type: TransactionType) -> [TransactionModel] {
        let allItems = transactionManager.transactions
        return allItems.filter { item in
            guard item.type == type else { return false }
            
            if !searchText.isEmpty {
                guard item.mainCategoryName.localizedCaseInsensitiveContains(searchText) ||
                      (item.subCategoryName ?? "").localizedCaseInsensitiveContains(searchText) ||
                      (item.note ?? "").localizedCaseInsensitiveContains(searchText) else { return false }
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
        } label: {
            Image(systemName: dateFilterMode == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(dateFilterMode != .all ? Color.accentColor : theme.labelPrimary)
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
                let sortedItems = items.sorted(by: { $0.date > $1.date })
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
        let roleRaw = walletManager.activeWallet?.permissions[currentUser] ?? WalletRole.member.rawValue
        let role = WalletRole(rawValue: roleRaw) ?? .member
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
