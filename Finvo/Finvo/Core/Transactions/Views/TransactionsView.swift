import SwiftUI

enum TransactionsViewMode: String, CaseIterable {
    case list = "Liste"
    case calendar = "Takvim"
    
    var localizedTitle: String {
        let appLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        if let path = Bundle.main.path(forResource: appLang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: self.rawValue, value: nil, table: nil)
        }
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

enum DateFilterMode: String, CaseIterable {
    case all = "Tümü"
    case weekly = "Haftalık"
    case monthly = "Aylık"
    case yearly = "Yıllık"
    case custom = "Özel Aralık"
    
    var localizedTitle: String {
        let appLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        if let path = Bundle.main.path(forResource: appLang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: self.rawValue, value: nil, table: nil)
        }
        return NSLocalizedString(self.rawValue, comment: "")
    }
}

struct TransactionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State var selectedType: TransactionType

    @State private var transactionToEdit: TransactionModel?
    @State private var searchText = ""
    
    // Filtre State'leri
    @State private var showFilterMenu = false
    @State private var viewMode: TransactionsViewMode = .list
    @State private var dateFilterMode: DateFilterMode = .all
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCategory: String? = nil
    
    // Takvim state'leri
    @State private var selectedDate = Date().startOfDay
    @State private var scrollID: Date? = Date().startOfDay
    @State private var isInternalUpdate = false
    @State private var hasInitialScrolled = false
    
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: TransactionModel? = nil
    
    @State private var filteredItems: [TransactionModel] = []
    
    private func filterTransactions() {
        let allItems = transactionManager.transactions
        filteredItems = allItems.filter { item in
            guard item.type == selectedType else { return false }
            
            if !searchText.isEmpty {
                guard item.mainCategoryName.localizedCaseInsensitiveContains(searchText) ||
                      (item.subCategoryName ?? "").localizedCaseInsensitiveContains(searchText) ||
                      (item.note ?? "").localizedCaseInsensitiveContains(searchText) else { return false }
            }
            
            if let catId = selectedCategory {
                guard item.mainCategoryId == catId || item.mainCategoryName == catId else { return false }
            }
            
            let calendar = Calendar.current
            let itemDate = item.date
            
            switch dateFilterMode {
            case .all:
                break
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
                let start = calendar.startOfDay(for: startDate)
                let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
                if itemDate < start || itemDate > end { return false }
            }
            return true
        }
    }
    
    // Takvim İçin Tarih Aralığı Oluşturucu
    private var calendarDateRange: [Date] {
        let calendar = Calendar.current
        let today = Date().startOfDay
        switch dateFilterMode {
        case .all:
            return []
        case .weekly:
            let start = today.startOfWeek
            return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .monthly:
            let start = today.startOfMonth
            let days = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
            return (0..<days).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .yearly:
            let start = today.startOfYear
            let days = calendar.range(of: .day, in: .year, for: today)?.count ?? 365
            return (0..<days).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .custom:
            let start = calendar.startOfDay(for: startDate)
            let end = calendar.startOfDay(for: endDate)
            let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
            return (0...max(0, days)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        }
    }
    
    // Takvim İçin Gruplanmış İşlemler
    private var groupedPaymentsForCalendar: [(Date, [TransactionModel])] {
        let calendar = Calendar.current
        let paymentsByDate = Dictionary(grouping: filteredItems) { calendar.startOfDay(for: $0.date) }
        
        if dateFilterMode == .all {
            let sortedKeys = paymentsByDate.keys.sorted()
            guard let first = sortedKeys.first, let last = sortedKeys.last else { return [] }
            let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
            let fullRange = (0...days).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
            return fullRange.map { ($0, paymentsByDate[$0] ?? []) }
        } else {
            return calendarDateRange.map { ($0, paymentsByDate[$0] ?? []) }
        }
    }
    
    // UI Helpers
    private var isFilterActive: Bool {
        selectedCategory != nil || dateFilterMode != .all
    }
    
    private var categoryFilterLabel: String {
        if let catId = selectedCategory {
            let availableCategories = CategoryManager.shared.categories.isEmpty ? CategoriesMockData.data : CategoryManager.shared.categories
            if let cat = availableCategories.first(where: { $0.id == catId }) {
                return cat.name
            }
        }
        return L10n("Kategoriler")
    }
    
    private var dateFilterLabel: String {
        if dateFilterMode == .custom {
            let appLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: appLang)
            formatter.setLocalizedDateFormatFromTemplate("d MMM")
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            return dateFilterMode.localizedTitle
        }
    }

    var body: some View {
        VStack {
            if !transactionManager.hasLoaded {
                Color.clear
            } else if viewMode == .calendar {
                calendarView
            } else {
                listView
            }
        }
        .sheet(item: $transactionToEdit) { transaction in
            AddTransactionsView(transactionToEdit: transaction)
                .environmentObject(walletManager)
                .environmentObject(transactionManager)
                .environmentObject(authManager)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker(L10n("İşlem Tipi"), selection: $selectedType) {
                    Text(L10n("Gider")).tag(TransactionType.expense)
                    Text(L10n("Gelir")).tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilterMenu.toggle()
                } label: {
                    Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                        .font(.system(size: 18))
                        .foregroundStyle(isFilterActive ? Color.accentColor : theme.labelPrimary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .popover(isPresented: $showFilterMenu) {
                    // Popover içi özgür alan
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // 1. Görünüm (Açıkta kalan Segmented Control - İstediğin gibi)
                        Picker(L10n("Görünüm"), selection: $viewMode) {
                            ForEach(TransactionsViewMode.allCases, id: \.self) { mode in
                                Text(mode.localizedTitle).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        Divider()
                        
                        // 2. Kategori Seçimi (Menü içine alındı)
                        Menu {
                            Picker(L10n("Kategori"), selection: $selectedCategory) {
                                Text(L10n("Tüm Kategoriler")).tag(Optional<String>.none)
                                let availableCategories = CategoryManager.shared.categories.isEmpty ? CategoriesMockData.data : CategoryManager.shared.categories
                                ForEach(availableCategories.filter { $0.type == selectedType }) { cat in
                                    Text(cat.name).tag(Optional(cat.id))
                                }
                            }
                        } label: {
                            HStack {
                                Label(categoryFilterLabel, systemImage: "folder")
                                    .foregroundStyle(theme.labelPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // 3. Zaman Filtresi (Menü içine alındı)
                        Menu {
                            Picker(L10n("Zaman Filtresi"), selection: $dateFilterMode) {
                                Text(L10n("Tümü")).tag(DateFilterMode.all)
                                Text(L10n("Haftalık")).tag(DateFilterMode.weekly)
                                Text(L10n("Aylık")).tag(DateFilterMode.monthly)
                                Text(L10n("Yıllık")).tag(DateFilterMode.yearly)
                                if dateFilterMode == .custom {
                                    Text(dateFilterLabel).tag(DateFilterMode.custom)
                                }
                            }
                        } label: {
                            HStack {
                                Label(dateFilterMode == .custom ? dateFilterLabel : (dateFilterMode == .all ? L10n("Zaman Filtresi") : dateFilterMode.localizedTitle), systemImage: "calendar.badge.clock")
                                    .foregroundStyle(theme.labelPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // 4. Tarih Aralığı (HStack İçinde Yan Yana - İstediğin gibi bozulmadı)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n("Tarih Aralığı"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                DatePicker("Başlangıç", selection: $startDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .onChange(of: startDate) { _, _ in dateFilterMode = .custom }
                                
                                Text("-")
                                
                                DatePicker(L10n("Bitiş"), selection: $endDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                                    .onChange(of: endDate) { _, _ in dateFilterMode = .custom }
                            }
                        }
                        
                        // 5. Sıfırla
                        if isFilterActive {
                            Divider()
                            Button(role: .destructive) {
                                selectedCategory = nil
                                dateFilterMode = .all
                                showFilterMenu = false // Sıfırlayınca pencereyi kapat
                            } label: {
                                HStack {
                                    Spacer()
                                    Label(L10n("Filtreleri Sıfırla"), systemImage: "xmark.circle")
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(minWidth: 250) // Açılan pencerenin genişliği
                    .presentationCompactAdaptation(.popover) // iPhone'da tam ekran olmasını engeller
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text(L10n("Ara")))
        .confirmationDialog(L10n("İşlemi Sil"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n("Sil"), role: .destructive) {
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
        .onAppear {
            filterTransactions()
        }
        .onChange(of: transactionManager.transactions) { _, _ in filterTransactions() }
        .onChange(of: selectedType) { _, _ in filterTransactions() }
        .onChange(of: searchText) { _, _ in filterTransactions() }
        .onChange(of: selectedCategory) { _, _ in filterTransactions() }
        .onChange(of: dateFilterMode) { _, _ in filterTransactions() }
        .onChange(of: startDate) { _, _ in filterTransactions() }
        .onChange(of: endDate) { _, _ in filterTransactions() }
    }
    
    // MARK: - List View
    private var listView: some View {
        Group {
            if filteredItems.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView(L10n("İşlem Bulunamadı"), systemImage: "list.bullet",
                                          description: Text(L10n("Bu kriterlere uygun işlem bulunamadı.")))
                    Spacer()
                }
            } else {
                let sortedItems = filteredItems.sorted(by: { $0.date > $1.date })
                List {
                    ForEach(sortedItems) { transaction in
                        listRow(for: transaction, isFirst: transaction.id == sortedItems.first?.id)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    // MARK: - Calendar View
    private var calendarView: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                theme.background1.ignoresSafeArea()
                
                List {
                    ForEach(groupedPaymentsForCalendar, id: \.0) { date, transactions in
                        Section(header: dateHeader(date)) {
                            if transactions.isEmpty {
                                emptyRow
                            } else {
                                ForEach(transactions) { tx in
                                    listRow(for: tx, isFirst: false)
                                        .listRowBackground(Color.clear)
                                }
                            }
                        }
                        .id(date)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: HeaderDatePreferenceKey.self, value: [HeaderDateEntry(date: date, minY: geo.frame(in: .named("CalendarListTransactions")).minY)])
                        })
                    }
                }
                .listStyle(.plain)
                .coordinateSpace(name: "CalendarListTransactions")
                .scrollPosition(id: $scrollID, anchor: .top)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 72)
                }
                .onPreferenceChange(HeaderDatePreferenceKey.self) { entries in
                    DispatchQueue.main.async {
                        if !isInternalUpdate, let top = entries.last(where: { $0.minY <= 160 }) {
                            let adjusted = Calendar.current.date(byAdding: .day, value: 1, to: top.date) ?? top.date
                            if !selectedDate.isSameDay(as: adjusted) { selectedDate = adjusted }
                        }
                    }
                }
                
                // Sabit Üst Takvim Şeridi
                VStack {
                    HorizontalWeekView(selectedDate: $selectedDate) { date in
                        syncToDate(date, proxy: proxy)
                    }
                    .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    syncToDate(Date().startOfDay, proxy: proxy)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 14, weight: .bold))
                        Text(L10n("Bugün"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(theme.labelPrimary)
                }
                .buttonStyle(.glass)
                .padding(.trailing, 20)
                .padding(.bottom, 20) // Tabbar'ın hemen üzerinde
            }
            .onAppear {
                if !hasInitialScrolled {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        let today = Date().startOfDay
                        scrollID = today
                        proxy.scrollTo(today, anchor: .top)
                        hasInitialScrolled = true
                    }
                }
            }
        }
    }
    
    // MARK: - View Helpers
    private func listRow(for transaction: TransactionModel, isFirst: Bool) -> some View {
        let appLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        let locale = Locale(identifier: appLang)
        let mainTitle = transaction.resolvedSubCategoryName ?? transaction.resolvedMainCategoryName
        let subtitleText = transaction.resolvedSubCategoryName != nil ? transaction.resolvedMainCategoryName : transaction.date.formatted(.dateTime.locale(locale).day().month().year().hour().minute())
        
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            setupSwipeActions(for: transaction)
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
        .listRowSeparator(.visible)
        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
        .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
    }

    @ViewBuilder
    private func setupSwipeActions(for transaction: TransactionModel) -> some View {
        let currentUser = authManager.currentUserProfile?.username ?? ""
        let roleRaw = walletManager.activeWallet?.permissions[currentUser] ?? WalletRole.member.rawValue
        let role = WalletRole(rawValue: roleRaw) ?? .member
        let isOwner = walletManager.activeWallet?.ownerId == currentUser
        
        let isAdminOrOwner = isOwner || role == .admin
        let isCreator = transaction.createdBy == currentUser
        let canManage = isAdminOrOwner || (role == .member && isCreator)
        
        if canManage {
            Button(role: .destructive) {
                transactionToDelete = transaction
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .tint(.red)
            
            Button {
                transactionToEdit = transaction
            } label: {
                Image(systemName: "pencil")
            }
            .tint(.orange)
        }
    }
    
    private func dateHeader(_ date: Date) -> some View {
        Text(date.calendarHeaderString)
            .font(.caption.bold())
            .foregroundColor(date.isToday ? theme.onBrandPrimary : theme.labelSecondary)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(date.isToday ? theme.brandPrimary : Color.clear, in: Capsule())
            .glassEffect(in: .capsule)
    }
    
    private var emptyRow: some View {
        HStack(spacing: 12) {
            Circle().fill(.gray.opacity(0.2)).frame(width: 4, height: 4)
            Text(L10n("İşlem Yok")).font(.caption2).foregroundColor(.secondary.opacity(0.5))
        }
        .listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
    
    private func syncToDate(_ date: Date, proxy: ScrollViewProxy) {
        isInternalUpdate = true
        selectedDate = date
        scrollID = date
        withAnimation { proxy.scrollTo(date, anchor: .top) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isInternalUpdate = false }
    }
}

#Preview {
    NavigationStack {
        TransactionsView(selectedType: .expense)
    }
}
