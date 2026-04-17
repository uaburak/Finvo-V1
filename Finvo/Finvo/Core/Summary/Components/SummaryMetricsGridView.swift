import SwiftUI

struct SummaryMetricsGridView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    // Düzenli 2 kolonlu yapı (Esnek)
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let rawLimit = walletManager.activeWallet?.monthlyLimit ?? 0
        let limitCurr = CurrencyType(rawValue: walletManager.activeWallet?.monthlyLimitCurrency ?? "") ?? .tryCurrency
        let limit = ExchangeRateManager.shared.convert(amount: rawLimit, from: limitCurr, to: appCurrency)
        
        // Sadece İÇİNDE BULUNDUĞUMUZ AYIN harcamalarını topla (Harcama Limiti için)
        let currentMonthExpenses = transactionManager.transactions.filter {
            !$0.isDebt && $0.type == .expense &&
            calendar.isDate($0.date, equalTo: today, toGranularity: .month) &&
            calendar.isDate($0.date, equalTo: today, toGranularity: .year)
        }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: appCurrency)
        }
        
        let limitProgress = rawLimit > 0 ? min(currentMonthExpenses / max(limit, 1), 1.0) : 0.0
        
        let topCategoryId = transactionManager.topExpenseCategoryId
        let topCategoryName = transactionManager.topExpenseCategoryName
        let resolvedTopCategory = CategoryManager.shared.categories.first(where: { $0.id == topCategoryId }) ??
                                  CategoryManager.shared.categories.first(where: { $0.name == topCategoryName })
        
        let upcomingPayments = transactionManager.transactions.filter { $0.type == .expense || $0.isDebt }.compactMap { $0.nextPayment(after: today) }
        let upcomingCount = upcomingPayments.count
        let upcomingTotal = upcomingPayments.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: appCurrency)
        }
        
        let paymentCalendarText: String
        if upcomingCount > 0 {
            paymentCalendarText = "\(upcomingCount) Ödeme (\(appCurrency.symbol)\(upcomingTotal.formatted(.number.precision(.fractionLength(0)))))"
        } else {
            paymentCalendarText = "Yaklaşan Yok"
        }

        return LazyVGrid(columns: columns, spacing: 16) {
            // Harcama Limiti
            MetricCardView(title: "Harcama Limiti", amount: "\(appCurrency.symbol)\(currentMonthExpenses.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))) / \(appCurrency.symbol)\(limit.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))", iconName: "creditcard.fill", iconColor: theme.expense, progress: limitProgress)
            MetricCardView(title: "En Çok Harcama",
                           amount: LocalizedStringKey(resolvedTopCategory?.name ?? topCategoryName),
                           iconName: resolvedTopCategory?.icon ?? "cart.fill",
                           iconColor: resolvedTopCategory?.uiColor ?? .blue,
                           progress: 0.0)
            
            NavigationLink(value: "PaymentCalendar") {
                MetricCardView(title: "Ödeme Takvimi", amount: LocalizedStringKey(paymentCalendarText), iconName: "calendar.badge.clock", iconColor: .orange, progress: upcomingCount > 0 ? 1.0 : nil)
            }
            .buttonStyle(.plain)
            
            MetricCardView(title: "Akıllı İpuçları", amount: "Yok", iconName: "lightbulb.fill", iconColor: .yellow, progress: nil)
        }
        .navigationDestination(for: String.self) { value in
            if value == "PaymentCalendar" {
                PaymentCalendarDetailView(upcomingPayments: upcomingPayments)
            }
        }
    }
}

// Genel Metrik Kartı - IncomeExpenseCardView stili ile birebir
struct MetricCardView: View {
    @Environment(\.theme) var theme
    
    let title: LocalizedStringKey
    let amount: LocalizedStringKey
    let iconName: String
    let iconColor: Color
    let progress: Double? // Artık opsiyonel, her kartta bar olmak zorunda değil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                // İkon
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold)) // Boyutu biraz büyütülerek denge sağlandı (14->20)
                    .foregroundColor(iconColor)
                
                Spacer()
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.labelSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            
            // Üstten ortaya itmek için esnek boşluk
            Spacer(minLength: 0)
            
            Text(amount)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.labelPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Ortadan alta itmek için ikinci esnek boşluk
            Spacer(minLength: 0)
            
            // Progress Bar (İlerleme Çubuğu) - Eğer progress gönderildiyse çiz
            if let safeProgress = progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Arkaplan Pisti
                        Capsule()
                            .fill(theme.cardBackground)
                            .frame(height: 3)
                        
                        // Dolan Kısım
                        Capsule()
                            .fill(iconColor)
                            .frame(width: max(0, min(CGFloat(safeProgress) * geometry.size.width, geometry.size.width)), height: 3)
                    }
                }
                .frame(height: 3)
            } else {
                // Progress bar olmayan kartlarda tasarım eşitliği (yükseklik kayması olmaması) için görünmez bir alan:
                Spacer()
                    .frame(height: 3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 150)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
}

struct SummaryMetricsGridView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryMetricsGridView()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

// MARK: - Navigation Destination (Added here to guarantee inclusion in Xcode target)
struct PaymentCalendarDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    
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
    
    let upcomingPayments: [TransactionModel]
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var scrollID: Date? // Native scroll position tracking
    @State private var isInternalUpdate: Bool = false
    @State private var isFirstLoad: Bool = true // Prevents jumping during back-navigation
    @State private var filterType: CalendarFilterType = .yearly
    @State private var cachedGroupedPayments: [(Date, [TransactionModel])] = []
    
    // MARK: - Data Processing Helper
    private static func processPayments(upcomingPayments: [TransactionModel], filterType: CalendarFilterType) -> [(Date, [TransactionModel])] {
        let calendar = Calendar.current
        let now = Date()
        
        let paymentsByDate = Dictionary(grouping: upcomingPayments) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        
        if filterType == .transactionsOnly {
            return paymentsByDate.keys.sorted().map { date in
                (date, paymentsByDate[date] ?? [])
            }
        }
        
        let rangeStart: Date
        let rangeEnd: Date
        
        switch filterType {
        case .weekly:
            rangeStart = now.startOfWeek
            rangeEnd = calendar.date(byAdding: .day, value: 6, to: rangeStart) ?? now
        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: now)
            rangeStart = calendar.date(from: comps) ?? now
            rangeEnd = calendar.date(byAdding: .month, value: 1, to: rangeStart)?.addingTimeInterval(-1) ?? now
        case .yearly:
            let comps = calendar.dateComponents([.year], from: now)
            rangeStart = calendar.date(from: comps) ?? now
            rangeEnd = calendar.date(byAdding: .year, value: 1, to: rangeStart)?.addingTimeInterval(-1) ?? now
        case .transactionsOnly:
            rangeStart = now
            rangeEnd = now
        }
        
        var dates: [Date] = []
        var currentDate = calendar.startOfDay(for: rangeStart)
        let finalDate = calendar.startOfDay(for: rangeEnd)
        
        while currentDate <= finalDate {
            dates.append(currentDate)
            if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDate
            } else { break }
        }
        
        return dates.map { date in
            (date, paymentsByDate[date] ?? [])
        }
    }
    
    init(upcomingPayments: [TransactionModel]) {
        self.upcomingPayments = upcomingPayments
        
        // 1. Pre-calculate initial data with default .yearly filter
        let initialData = Self.processPayments(upcomingPayments: upcomingPayments, filterType: .yearly)
        _cachedGroupedPayments = State(initialValue: initialData)
        
        // 2. Identify the initial scroll target (Today or first available)
        let today = Calendar.current.startOfDay(for: Date())
        let initialDate = initialData.first(where: { Calendar.current.isDate($0.0, inSameDayAs: today) })?.0 ?? initialData.first?.0
        
        _scrollID = State(initialValue: initialDate)
        _selectedDate = State(initialValue: initialDate ?? today)
        _filterType = State(initialValue: .yearly)
    }

    private func updateCachedPayments() {
        cachedGroupedPayments = Self.processPayments(upcomingPayments: upcomingPayments, filterType: filterType)
    }
    
    private func dateHeaderLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Bugün" }
        if calendar.isDateInTomorrow(date) { return "Yarın" }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            ScrollViewReader { proxy in
                List {
                    ForEach(cachedGroupedPayments, id: \.0) { date, transactions in
                        Section(header:
                            HStack {
                                let isToday = Calendar.current.isDateInToday(date)
                                Text(dateHeaderLabel(for: date))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isToday ? .black : theme.labelSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        isToday ? theme.brandPrimary : Color.clear,
                                        in: Capsule()
                                    )
                                    .glassEffect(in: .capsule)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                            .listRowBackground(Color.clear)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: HeaderDatePreferenceKey.self, value: [HeaderDateEntry(date: date, minY: geo.frame(in: .named("CalendarList")).minY)])
                                }
                            )
                        ) {
                            if transactions.isEmpty {
                                HStack {
                                    Circle()
                                        .fill(theme.labelSecondary.opacity(0.1))
                                        .frame(width: 4, height: 4)
                                    Text("Ödeme Yok")
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.labelSecondary.opacity(0.3))
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            } else {
                                ForEach(transactions) { tx in
                                    let titleStr = tx.note?.isEmpty == false ? tx.note! : tx.mainCategoryName
                                    let converted = ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: appCurrency)
                                    let daysCount = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: tx.date)).day ?? 0
                                    let dayText = daysCount == 0 ? "Bugün" : (daysCount < 0 ? "Gecikti" : "\(daysCount) gün kaldı")
                                    let amountStr = "-\(appCurrency.symbol)\(converted.formatted(.number.precision(.fractionLength(0))))"
                                    let statusColor = daysCount <= 3 ? theme.expense : .secondary

                                    ZStack {
                                        NavigationLink(destination: TransactionDetailView(transaction: tx)) {
                                            EmptyView()
                                        }
                                        .opacity(0)
                                        
                                        ListItem(
                                            icon: tx.resolvedIcon,
                                            iconColor: tx.resolvedColor(),
                                            title: LocalizedStringKey(titleStr),
                                            subtitle: LocalizedStringKey(tx.mainCategoryName),
                                            value: amountStr,
                                            valueColor: theme.labelPrimary,
                                            secondaryInfo: dayText,
                                            secondaryInfoColor: statusColor
                                        )
                                        .padding(.vertical, 4)
                                    }
                                    .listRowBackground(theme.background1.opacity(0.01))
                                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 12))
                                }
                            }
                        }
                        .id(date)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .coordinateSpace(name: "CalendarList")
                .scrollPosition(id: $scrollID, anchor: .top)
                .onPreferenceChange(HeaderDatePreferenceKey.self) { entries in
                    // Sync logic for Vertical -> Horizontal
                    if !isInternalUpdate {
                        // Find the header closest to the top
                        // Apply +1 day offset as requested by the user for perfect sync
                        if let topHeader = entries.last(where: { $0.minY <= 170 }) {
                            let adjustedDate = Calendar.current.date(byAdding: .day, value: 1, to: topHeader.date) ?? topHeader.date
                            if !selectedDate.isSameDay(as: adjustedDate) {
                                selectedDate = adjustedDate
                            }
                        }
                    }
                }
                .onChange(of: scrollID) { _, newValue in
                    if let newValue, !isInternalUpdate {
                        if !selectedDate.isSameDay(as: newValue) {
                            selectedDate = newValue
                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    HorizontalWeekView(selectedDate: $selectedDate) { date in
                        isInternalUpdate = true
                        selectedDate = date
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            scrollID = date
                            proxy.scrollTo(date, anchor: .top)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isInternalUpdate = false
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
                    .glassEffect(in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.background1)
                }
                .onChange(of: filterType) { _, _ in
                    updateCachedPayments()
                    
                    let today = Calendar.current.startOfDay(for: Date())
                    let targetDate = cachedGroupedPayments.first(where: { Calendar.current.isDate($0.0, inSameDayAs: today) })?.0 ?? cachedGroupedPayments.first?.0 ?? today
                    
                    isInternalUpdate = true
                    selectedDate = targetDate
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring()) {
                            scrollID = targetDate
                            proxy.scrollTo(targetDate, anchor: .top)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            isInternalUpdate = false
                        }
                    }
                }
                .task {
                    // Hybrid initial load: ONLY runs on the first time the view appears in the stack
                    guard isFirstLoad else { return }
                    
                    let today = Calendar.current.startOfDay(for: Date())
                    let targetDate = cachedGroupedPayments.first(where: { Calendar.current.isDate($0.0, inSameDayAs: today) })?.0 ?? cachedGroupedPayments.first?.0
                    
                    if let targetDate {
                        // Small delay to ensure List is ready to receive scrollTo
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                        await MainActor.run {
                            withAnimation(.none) {
                                scrollID = targetDate
                                proxy.scrollTo(targetDate, anchor: .top)
                                isFirstLoad = false // Mark as initialized
                            }
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        let today = Calendar.current.startOfDay(for: Date())
                        isInternalUpdate = true
                        selectedDate = today
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            scrollID = today
                            proxy.scrollTo(today, anchor: .top)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isInternalUpdate = false
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.up.chevron.down")
                            Text("Bugün")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(theme.labelPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(in: .capsule)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
            }
        }

        .navigationTitle("Ödeme Takvimi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Filtre", selection: $filterType) {
                        ForEach(CalendarFilterType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .foregroundColor(theme.labelPrimary)
                }
            }
        }
    }
}

// MARK: - Teams-style Horizontal Week Strip Component (Refined)
struct HorizontalWeekView: View {
    @Environment(\.theme) var theme
    @Binding var selectedDate: Date
    var onDateTapped: (Date) -> Void
    
    private let weekDays = ["P", "S", "Ç", "P", "C", "C", "P"]
    
    private var currentWeekDays: [Date] {
        selectedDate.daysInWeek
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let date = currentWeekDays[index]
                let isSelected = date.isSameDay(as: selectedDate)
                
                VStack(spacing: 8) {
                    Text(weekDays[index])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.labelSecondary)
                    
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isSelected ? .black : theme.labelPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(isSelected ? theme.brandPrimary : Color.clear)
                        )
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onDateTapped(date)
                }
            }
        }
        .padding(.horizontal, 4) // Further reduced internal padding
        .padding(.vertical, 12)
    }
}

// MARK: - Date Extensions for Calendar Logic
extension Date {
    /// Returns the start of the week for the receiver, considering Monday as the first day.
    var startOfWeek: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        components.weekday = 2 // Monday (In Turkish/Teams context, weeks start on Monday)
        return calendar.date(from: components) ?? self
    }
    
    /// Returns an array of dates representing the 7 days of the week containing the receiver.
    var daysInWeek: [Date] {
        let calendar = Calendar.current
        let start = self.startOfWeek
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: start)
        }
    }
    
    /// Checks if the receiver is on the same day as another date.
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}

// MARK: - PreferenceKey and Models for Sticky Header Sync
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
