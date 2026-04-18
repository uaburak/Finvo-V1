import SwiftUI

// MARK: - Models & Enums
enum CalendarFilterType: String, CaseIterable {
    case weekly = "Haftalık"
    case monthly = "Aylık"
    case yearly = "Yıllık"
    case transactionsOnly = "İşlemler"
    
    var icon: String {
        switch self {
        case .weekly: return "calendar.day.timeline.left"
        case .monthly: return "calendar.badge.clock"
        case .yearly: return "calendar"
        case .transactionsOnly: return "list.bullet.indent"
        }
    }
}

struct HeaderDateEntry: Equatable {
    let date: Date
    let minY: CGFloat
}

struct HeaderDatePreferenceKey: PreferenceKey {
    static var defaultValue: [HeaderDateEntry] = []
    static func reduce(value: inout [HeaderDateEntry], nextValue: () -> [HeaderDateEntry]) {
        value.append(contentsOf: nextValue())
    }
}

// MARK: - Main Grid View
struct SummaryMetricsGridView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    
    var body: some View {
        let calendar = Calendar.current
        let today = Date()
        
        // Harcama Limiti
        let rawLimit = walletManager.activeWallet?.monthlyLimit ?? 0
        let limitCurr = CurrencyType(rawValue: walletManager.activeWallet?.monthlyLimitCurrency ?? "") ?? .tryCurrency
        let limit = ExchangeRateManager.shared.convert(amount: rawLimit, from: limitCurr, to: appCurrency)
        
        let spent = transactionManager.transactions.filter {
            !$0.isDebt && $0.type == .expense && calendar.isDate($0.date, equalTo: today, toGranularity: .month)
        }.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency) }
        
        let progress = rawLimit > 0 ? min(spent / max(limit, 1), 1.0) : 0
        
        // Diğer veriler
        let topCat = CategoryManager.shared.categories.first { $0.id == transactionManager.topExpenseCategoryId }
        let upcomingList = transactionManager.transactions.filter { $0.type == .expense || $0.isDebt }.compactMap { $0.nextPayment(after: today) }
        let upcomingTotal = upcomingList.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency) }

        LazyVGrid(columns: columns, spacing: 16) {
            MetricCardView(title: "Harcama Limiti", amount: "\(appCurrency.symbol)\(spent.formatted(.number.precision(.fractionLength(0)))) / \(appCurrency.symbol)\(limit.formatted(.number.precision(.fractionLength(0))))", iconName: "creditcard.fill", iconColor: theme.expense, progress: progress)
            
            MetricCardView(title: "En Çok Harcama", amount: LocalizedStringKey(topCat?.name ?? "Belirsiz"), iconName: topCat?.icon ?? "cart.fill", iconColor: topCat?.uiColor ?? .blue, progress: nil)
            
            NavigationLink(value: "PaymentCalendar") {
                MetricCardView(title: "Ödeme Takvimi", amount: upcomingList.count > 0 ? "\(upcomingList.count) Ödeme (\(appCurrency.symbol)\(upcomingTotal.formatted(.number.precision(.fractionLength(0)))))" : "Yaklaşan Yok", iconName: "calendar.badge.clock", iconColor: .orange, progress: upcomingList.count > 0 ? 1.0 : nil)
            }
            .buttonStyle(.plain)
            
            MetricCardView(title: "Akıllı İpuçları", amount: "Sistem Hazır", iconName: "lightbulb.fill", iconColor: .yellow, progress: nil)
        }
    }
}

// MARK: - Components
struct MetricCardView: View {
    @Environment(\.theme) var theme
    let title: LocalizedStringKey
    let amount: LocalizedStringKey
    let iconName: String
    let iconColor: Color
    let progress: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName).font(.title3.bold()).foregroundColor(iconColor)
                Spacer()
                Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(theme.labelSecondary).lineLimit(1)
            }
            Spacer()
            Text(amount).font(.system(size: 17, weight: .bold)).foregroundColor(theme.labelPrimary).lineLimit(1).minimumScaleFactor(0.7)
            
            if let safeProgress = progress {
                Capsule().fill(theme.cardBackground).frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule().fill(iconColor).frame(width: geo.size.width * CGFloat(safeProgress))
                        }
                    }
            } else {
                Color.clear.frame(height: 4)
            }
        }
        .padding(16).frame(height: 140).glassEffect(in: .rect(cornerRadius: 24))
    }
}

struct PaymentCalendarDetailView: View {
    @Environment(\.theme) var theme
    let upcomingPayments: [TransactionModel]
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State private var selectedDate = Date().startOfDay
    @State private var scrollID: Date? = Date().startOfDay
    @State private var filterType: CalendarFilterType = .yearly
    @State private var hasInitialScrolled = false
    @State private var isInternalUpdate = false
    
    // Derleyiciyi rahatlatmak için hesaplamayı parçalara böldük
    private var groupedPayments: [(Date, [TransactionModel])] {
        let calendar = Calendar.current
        let paymentsByDate = Dictionary(grouping: upcomingPayments) { calendar.startOfDay(for: $0.date) }
        
        if filterType == .transactionsOnly {
            // Sadece bu yıl içindeki işlemleri göster
            let yearStart = Date().startOfYear
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? yearStart
            return paymentsByDate.keys
                .filter { $0 >= yearStart && $0 < yearEnd }
                .sorted()
                .map { ($0, paymentsByDate[$0] ?? []) }
        }
        
        let dateRange = calendar.generateRange(for: filterType, from: Date())
        return dateRange.map { ($0, paymentsByDate[$0] ?? []) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                theme.background1.ignoresSafeArea()
                
                List {
                    ForEach(groupedPayments, id: \.0) { date, transactions in
                        Section(header: dateHeader(date)) {
                            if transactions.isEmpty {
                                emptyRow
                            } else {
                                ForEach(transactions) { tx in
                                    calendarRow(tx)
                                }
                            }
                        }
                        .id(date)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: HeaderDatePreferenceKey.self, value: [HeaderDateEntry(date: date, minY: geo.frame(in: .named("CalendarList")).minY)])
                        })
                    }
                }
                .listStyle(.plain)
                .coordinateSpace(name: "CalendarList")
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
                .onChange(of: filterType) { _, _ in
                    // Reset to today when filter changes to ensure user isn't lost
                    let today = Date().startOfDay
                    scrollID = today
                    proxy.scrollTo(today, anchor: .top)
                }
                
                // Sabit Üst Takvim Şeridi (CategoryDetailView stilinde)
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
                        Text("Bugün")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(theme.labelPrimary)
                }
                .buttonStyle(.glass)
                .padding(.trailing, 20)
                .padding(.bottom, 20) // Tabbar'ın hemen üzerinde
            }
            .navigationTitle("Ödeme Takvimi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Görünüm", selection: $filterType) {
                            ForEach(CalendarFilterType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.labelPrimary)
                    }
                }
            }
        }
    }
    
    // Helper to get proxy if needed, or I'll just keep the structure if proxy is available
    
    // Sub-renderers to help compiler
    private func dateHeader(_ date: Date) -> some View {
        Text(date.calendarHeaderString)
            .font(.caption.bold())
            .foregroundColor(date.isToday ? .black : theme.labelSecondary)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(date.isToday ? theme.brandPrimary : Color.clear, in: Capsule())
            .glassEffect(in: .capsule)
            .padding(.vertical, 8)
    }
    
    private var emptyRow: some View {
        HStack {
            Circle().fill(.gray.opacity(0.2)).frame(width: 4, height: 4)
            Text("Ödeme Yok").font(.caption2).foregroundColor(.secondary.opacity(0.5))
        }
        .listRowBackground(Color.clear).listRowSeparator(.hidden)
    }
    
    private func calendarRow(_ tx: TransactionModel) -> some View {
        let converted = ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: appCurrency)
        let days = Calendar.current.daysFromToday(to: tx.date)
        let isPastPayment = tx.isPaid
        
        // Title: Alt kategori adı (varsa), yoksa ana kategori adı
        let rowTitle = tx.resolvedSubCategoryName ?? tx.mainCategoryName
        
        // Subtitle: allPaymentOccurrences zaten installmentNumber atıyor
        var rowSubtitle = tx.mainCategoryName
        if tx.isDebt {
            let installmentNum = tx.installmentNumber ?? ((tx.paidInstallments ?? 0) + 1)
            let total = tx.totalInstallments ?? 0
            rowSubtitle = "\(installmentNum). Taksit / \(total) (\(tx.mainCategoryName))"
        } else if tx.isRecurring {
            let occurrenceNum = tx.installmentNumber ?? 1
            rowSubtitle = "\(occurrenceNum). Ödeme (\(tx.mainCategoryName))"
        }
        
        // Tarih durum bilgisi: Geçmiş ödemeler "Ödendi", gelecek olanlar gün sayısı
        let statusText: String
        let statusColor: Color
        if isPastPayment {
            statusText = "Ödendi"
            statusColor = theme.income
        } else if days == 0 {
            statusText = "Bugün"
            statusColor = theme.expense
        } else if days < 0 {
            statusText = "Gecikti"
            statusColor = theme.expense
        } else {
            statusText = "\(days) gün"
            statusColor = days <= 3 ? theme.expense : .secondary
        }
        
        return ZStack {
            NavigationLink(destination: TransactionDetailView(transaction: tx)) {
                EmptyView()
            }
            .opacity(0)
            
            ListItem(
                icon: tx.resolvedIcon,
                iconColor: tx.resolvedColor(),
                title: LocalizedStringKey(rowTitle),
                subtitle: LocalizedStringKey(rowSubtitle),
                value: "-\(tx.currency?.symbol ?? appCurrency.symbol)\(tx.amount.formatted(.number.precision(.fractionLength(0))))",
                valueColor: theme.labelPrimary,
                secondaryInfo: statusText,
                secondaryInfoColor: statusColor
            )
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 12))
    }

    private func syncToDate(_ date: Date, proxy: ScrollViewProxy) {
        isInternalUpdate = true
        selectedDate = date
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            scrollID = date
            proxy.scrollTo(date, anchor: .top)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isInternalUpdate = false }
    }
}

struct HorizontalWeekView: View {
    @Environment(\.theme) var theme
    @Binding var selectedDate: Date
    var onDateTapped: (Date) -> Void
    
    private let weekDays = ["P", "S", "Ç", "P", "C", "C", "P"]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(selectedDate.daysInWeek, id: \.self) { date in
                let isSelected = date.isSameDay(as: selectedDate)
                let dayIndex = (Calendar.current.component(.weekday, from: date) + 5) % 7
                
                VStack(spacing: 8) {
                    Text(weekDays[dayIndex]).font(.system(size: 10, weight: .medium)).foregroundColor(theme.labelSecondary)
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? .black : theme.labelPrimary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(isSelected ? theme.brandPrimary : Color.clear))
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onDateTapped(date) }
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Extensions
extension Calendar {
    func generateRange(for type: CalendarFilterType, from date: Date) -> [Date] {
        let start: Date
        let count: Int
        switch type {
        case .weekly:
            // İçinde bulunduğumuz hafta
            (start, count) = (date.startOfWeek, 7)
        case .monthly:
            // İçinde bulunduğumuz ay
            let monthStart = date.startOfMonth
            let daysInMonth = self.range(of: .day, in: .month, for: date)?.count ?? 30
            (start, count) = (monthStart, daysInMonth)
        case .yearly:
            // İçinde bulunduğumuz yıl (1 Ocak - 31 Aralık)
            let yearStart = date.startOfYear
            let daysInYear = self.range(of: .day, in: .year, for: date)?.count ?? 365
            (start, count) = (yearStart, daysInYear)
        case .transactionsOnly: return []
        }
        return (0..<count).compactMap { self.date(byAdding: .day, value: $0, to: start) }
    }
    
    func daysFromToday(to date: Date) -> Int {
        dateComponents([.day], from: startOfDay(for: Date()), to: startOfDay(for: date)).day ?? 0
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
    var startOfMonth: Date { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self }
    var startOfYear: Date { Calendar.current.date(from: Calendar.current.dateComponents([.year], from: self)) ?? self }
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    
    var startOfWeek: Date {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    var daysInWeek: [Date] {
        let start = self.startOfWeek
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }
    
    func isSameDay(as other: Date) -> Bool { Calendar.current.isDate(self, inSameDayAs: other) }
    
    var calendarHeaderString: String {
        if isToday { return "Bugün" }
        let f = DateFormatter(); f.locale = Locale(identifier: "tr_TR"); f.dateFormat = "d MMMM EEEE"
        return f.string(from: self)
    }
}
