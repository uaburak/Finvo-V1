import SwiftUI
import Charts

enum TransactionTypeFilter: String, CaseIterable {
    case all = "Tümü"
    case income = "Sadece Gelirler"
    case expense = "Sadece Giderler"
}

struct AnalysisView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    // UI States
    @State private var selectedTab: AnalysisTimeFrame = .month
    
    
    // Core Data
    @State private var flowData: [FlowData] = []
    @State private var globalMaxAmount: Double = 1000
    @State private var biggestTransaction: TransactionModel? = nil
    @State private var recurringTransactions: [TransactionModel] = []
    @State private var categorySummaries: [CategorySummary] = []
    @State private var memberContributions: [MemberContribution] = []
    
    // Filter & Export States
    @State private var selectedFilterType: TransactionTypeFilter = .all
    @State private var isSharingPDF: Bool = false
    @State private var pdfURL: URL? = nil
    
    // Gelişmiş Filtre State'leri
    @State private var showFilterMenu = false
    @State private var dateFilterMode: DateFilterMode = .all
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCategory: String? = nil
    
    // Pro Limits
    @State private var showProAlert = false
    @State private var showPaywall = false
    
    private var isFilterActive: Bool {
        selectedCategory != nil || dateFilterMode != .all || selectedFilterType != .all
    }
    
    private var categoryFilterLabel: String {
        if let catId = selectedCategory {
            let availableCategories = CategoryManager.shared.categories.isEmpty ? CategoriesMockData.data : CategoryManager.shared.categories
            if let cat = availableCategories.first(where: { $0.id == catId }) {
                return cat.name.localized
            }
        }
        return "Kategoriler".localized
    }

    private var dateFilterLabel: String {
        if dateFilterMode == .custom {
            let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            formatter.locale = Locale(identifier: appLanguage)
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else {
            return dateFilterMode.title
        }
    }

    private var dateFilterLabelForToolbar: String {
        if dateFilterMode == .custom { return dateFilterLabel }
        if dateFilterMode == .all { return "Zaman Filtresi".localized }
        return dateFilterMode.title
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background1.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        AnalysisSegmentedControl(selectedTab: $selectedTab)
                            .padding(.horizontal, 20)
                        
                        AnalysisChartCard(
                            flowData: flowData,
                            chartUnit: chartUnit,
                            selectedTab: selectedTab,
                            globalMaxAmount: globalMaxAmount
                        )
                        .padding(.horizontal, 20)
                        
                        AnalysisMiniCards(
                            recurringTransactions: recurringTransactions,
                            biggestTransaction: biggestTransaction
                        )
                        .padding(.horizontal, 20)
                        AnalysisCategoryCard(
                            categorySummaries: categorySummaries
                        )
                        .padding(.horizontal, 20)
                        
                        ExchangeRatesListCard()
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        // Sadece paylaşımlı cüzdanlarda (veya üye sayısı 1'den büyükse) Liderlik tablosunu göster
                        if let wallet = walletManager.activeWallet, (wallet.type == .shared || wallet.members.count > 1) {
                            AnalysisCollaboratorCard(
                                contributions: memberContributions,
                                allTransactions: transactionManager.transactions // Filtrelenmemiş gerçek tüm veri listesi gönderiliyor ki detay ekranında tarihe göre süzebilsin
                            )
                            .padding(.horizontal, 20)
                        }
                        
                    }
                    .safeAreaPadding(.bottom, 60)
                }
            }
            .navigationTitle("Analiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // PDF Share Button
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        sharePDF()
                    }) {
                        if isSharingPDF {
                            ProgressView().tint(theme.labelPrimary)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(theme.labelPrimary)
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                }
                
                // Advanced Filter Menu
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilterMenu.toggle()
                    } label: {
                        Image(systemName: isFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(isFilterActive ? Color.accentColor : theme.labelPrimary)
                            .font(.system(size: 18))
                    }
                    .popover(isPresented: $showFilterMenu) {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            // İşlem Tipi Seçimi
                            Picker("İşlem Tipi", selection: $selectedFilterType) {
                                ForEach(TransactionTypeFilter.allCases, id: \.self) { type in
                                    Text(type.rawValue.localized).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            Divider()
                            
                            // Kategori Seçimi
                            Menu {
                                Picker("Kategori", selection: $selectedCategory) {
                                    Text("Tüm Kategoriler").tag(Optional<String>.none)
                                    let availableCategories = CategoryManager.shared.categories.isEmpty ? CategoriesMockData.data : CategoryManager.shared.categories
                                    ForEach(availableCategories) { cat in
                                        Text(LocalizedStringKey(cat.name)).tag(Optional(cat.id))
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

                            // Zaman Filtresi
                            Menu {
                                Picker("Zaman Filtresi", selection: $dateFilterMode) {
                                    Text("Tümü").tag(DateFilterMode.all)
                                    Text("Haftalık").tag(DateFilterMode.weekly)
                                    Text("Aylık").tag(DateFilterMode.monthly)
                                    Text("Yıllık").tag(DateFilterMode.yearly)
                                    if dateFilterMode == .custom {
                                        Text(dateFilterLabel).tag(DateFilterMode.custom)
                                    }
                                }
                            } label: {
                                HStack {
                                    Label(dateFilterLabelForToolbar, systemImage: "calendar.badge.clock")
                                        .foregroundStyle(theme.labelPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            // Tarih Aralığı
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Tarih Aralığı")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    DatePicker("Başlangıç", selection: $startDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .onChange(of: startDate) { _, _ in handleCustomDateSelection() }
                                    
                                    Text("-")
                                    
                                    DatePicker("Bitiş", selection: $endDate, displayedComponents: .date)
                                        .labelsHidden()
                                        .datePickerStyle(.compact)
                                        .onChange(of: endDate) { _, _ in handleCustomDateSelection() }
                                }
                            }
                            
                            if isFilterActive {
                                Divider()
                                Button(role: .destructive) {
                                    selectedCategory = nil
                                    dateFilterMode = .all
                                    selectedFilterType = .all
                                    showFilterMenu = false
                                } label: {
                                    HStack {
                                        Spacer()
                                        Label("Filtreleri Sıfırla", systemImage: "xmark.circle")
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(minWidth: 280)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .onAppear {
                updateData(startAnimation: true)
            }
            .alert("Pro Yükseltmesi Gerekli", isPresented: $showProAlert) {
                Button("Pro Ol") {
                    showPaywall = true
                }
                Button("Vazgeç", role: .cancel) { }
            } message: {
                Text("Özel tarih aralığı filtreleme ve PDF raporları oluşturma yalnızca Pro üyeler içindir.")
            }
            .fullScreenCover(isPresented: $showPaywall) {
                ProSubscriptionPaywallView()
            }

            .onChange(of: selectedTab) {
                updateData(startAnimation: true)
            }
            .onChange(of: transactionManager.transactions.count) {
                updateData(startAnimation: false)
            }
            .onChange(of: selectedFilterType) {
                updateData(startAnimation: true)
            }
            .onChange(of: selectedCategory) {
                updateData(startAnimation: true)
            }
            .onChange(of: dateFilterMode) {
                updateData(startAnimation: true)
            }
            .onChange(of: startDate) {
                updateData(startAnimation: true)
            }
            .onChange(of: endDate) {
                updateData(startAnimation: true)
            }

            .sheet(isPresented: .init(get: { pdfURL != nil }, set: { if !$0 { pdfURL = nil } })) {
                if let url = pdfURL {
                    ShareSheet(activityItems: [url])
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }
    
    // MARK: - Handlers
    private func handleCustomDateSelection() {
        if authManager.currentUserProfile?.isPro == true {
            dateFilterMode = .custom
        } else {
            // Revert changes if not pro
            dateFilterMode = .all
            showProAlert = true
        }
    }
    
    // MARK: - Data Engine
    private func updateData(startAnimation: Bool = false) {
        var range = selectedTab
        if dateFilterMode == .weekly { range = .week }
        else if dateFilterMode == .monthly { range = .month }
        else if dateFilterMode == .yearly { range = .year }
        
        var baseTxs = transactionManager.transactions
        // Seçili kategori varsa daralt
        if let catId = selectedCategory {
            baseTxs = baseTxs.filter { $0.mainCategoryId == catId || $0.mainCategoryName == catId }
        }
        
        let allTxs = baseTxs
        let calendar = Calendar.current
        let now = Date()
        
        var newFlowData: [FlowData] = []
        var filteredTxs: [TransactionModel] = []
        
        // 1. İşlemleri Filtrele ve Boş Çatıları (Slotları) Oluştur
        if dateFilterMode == .custom {
            let startOfFilter = calendar.startOfDay(for: startDate)
            let endOfFilter = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
            filteredTxs = allTxs.filter { $0.date >= startOfFilter && $0.date <= endOfFilter }
            
            let diffDays = calendar.dateComponents([.day], from: startOfFilter, to: calendar.startOfDay(for: endDate)).day ?? 0
            let maxDays = max(0, diffDays)
            for day in 0...maxDays {
                guard let d = calendar.date(byAdding: .day, value: day, to: startOfFilter) else { continue }
                newFlowData.append(FlowData(id: d, date: d, netAmount: 0))
            }
        } else {
            switch range {
            case .day:

            let startOfDay = calendar.startOfDay(for: now)
            filteredTxs = allTxs.filter { calendar.isDate($0.date, inSameDayAs: now) }
            for hour in 0..<24 {
                guard let d = calendar.date(byAdding: .hour, value: hour, to: startOfDay) else { continue }
                newFlowData.append(FlowData(id: d, date: d, netAmount: 0))
            }
        case .week:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let weekCurrent = calendar.component(.weekOfYear, from: now)
            let yearCurrent = calendar.component(.yearForWeekOfYear, from: now)
            filteredTxs = allTxs.filter {
                calendar.component(.weekOfYear, from: $0.date) == weekCurrent &&
                calendar.component(.yearForWeekOfYear, from: $0.date) == yearCurrent
            }
            for day in 0..<7 {
                guard let d = calendar.date(byAdding: .day, value: day, to: startOfWeek) else { continue }
                newFlowData.append(FlowData(id: d, date: d, netAmount: 0))
            }
        case .month:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            filteredTxs = allTxs.filter {
                calendar.isDate($0.date, equalTo: now, toGranularity: .month) &&
                calendar.isDate($0.date, equalTo: now, toGranularity: .year)
            }
            let rangeOfDays = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            for day in 0..<rangeOfDays {
                guard let d = calendar.date(byAdding: .day, value: day, to: startOfMonth) else { continue }
                newFlowData.append(FlowData(id: d, date: d, netAmount: 0))
            }
            case .year:
                let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
                filteredTxs = allTxs.filter {
                    calendar.isDate($0.date, equalTo: now, toGranularity: .year)
                }
                for month in 0..<12 {
                    guard let d = calendar.date(byAdding: .month, value: month, to: startOfYear) else { continue }
                    newFlowData.append(FlowData(id: d, date: d, netAmount: 0))
                }
            }
        }

        let baseCurrency = UserDefaults.standard.string(forKey: "appCurrency").flatMap { CurrencyType(rawValue: $0) } ?? .tryCurrency
        
        // 2. Net Nakit Akışını Yuvalara Yerleştir (Gelir - Gider)
        var monthDict: [Date: Double] = [:]
        var dayDict: [Date: Double] = [:]
        var hourDict: [Date: Double] = [:]
        
        for tx in filteredTxs {
            if tx.isDebt { continue } // Borç işlemleri grafikte hesaplanmaz, taksitleri hesaplanır.
            if selectedFilterType == .income && tx.type != .income { continue }
            if selectedFilterType == .expense && tx.type != .expense { continue }
            
            let convertedAmount = ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
            let value = tx.type == .income ? convertedAmount : -convertedAmount
            
            if let index = newFlowData.firstIndex(where: {
                calendar.isDate($0.date, equalTo: tx.date, toGranularity: chartUnit)
            }) {
                newFlowData[index].netAmount += value
            }
        }
        
        for tx in allTxs {
            if tx.isDebt { continue } 
            if selectedFilterType == .income && tx.type != .income { continue }
            if selectedFilterType == .expense && tx.type != .expense { continue }
            
            let convertedAmount = ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
            let value = tx.type == .income ? convertedAmount : -convertedAmount
            
            let monthStart = calendar.dateInterval(of: .month, for: tx.date)?.start ?? tx.date
            monthDict[monthStart, default: 0] += value
            
            let dayStart = calendar.startOfDay(for: tx.date)
            dayDict[dayStart, default: 0] += value
            
            if let hourStart = calendar.dateInterval(of: .hour, for: tx.date)?.start {
                hourDict[hourStart, default: 0] += value
            }
        }
        
        let maxMonth = monthDict.values.map { abs($0) }.max() ?? 0
        let maxDay = dayDict.values.map { abs($0) }.max() ?? 0
        let maxHour = hourDict.values.map { abs($0) }.max() ?? 0
        
        let highest = max(maxMonth, maxDay, maxHour)
        let newGlobalMax = highest == 0 ? 1000 : highest
            
        // 3. Mini Kart Verileri
        let biggestActive = filteredTxs.filter {
            !$0.isDebt && 
            ((selectedFilterType == .all && $0.type == .expense) ||
            (selectedFilterType == .income && $0.type == .income) ||
            (selectedFilterType == .expense && $0.type == .expense))
        }.max(by: {
            ExchangeRateManager.shared.convert(amount: $0.amount, from: $0.currency ?? .tryCurrency, to: baseCurrency) <
            ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency)
        })
        
        let recurring = allTxs.filter { $0.isRecurring }
        
        // 4. Kategori Verileri
        var catDict: [String: (amount: Double, icon: String, count: Int)] = [:]
        var memberDict: [String: (amount: Double, count: Int)] = [:]
        
        // Kullanıcı filtreyi gelire çekerse Kategori ve Liderlik Dağılımını sadece Gelirler ile göster!
        let targetTypeForCategories: TransactionType = selectedFilterType == .income ? .income : .expense
        let typeFilteredTxs = filteredTxs.filter { $0.type == targetTypeForCategories && !$0.isDebt }
        let totalTypeAmount = typeFilteredTxs.reduce(0) { 
            $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency)
        }
        
        for tx in typeFilteredTxs {
            let convertedAmount = ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
            // Kategori Toplama
            let cat = tx.mainCategoryName
            let currentCat = catDict[cat] ?? (amount: 0, icon: tx.categoryIcon, count: 0)
            catDict[cat] = (amount: currentCat.amount + convertedAmount, icon: tx.categoryIcon, count: currentCat.count + 1)
            
            // Kişi Toplama
            let currentMember = memberDict[tx.createdBy] ?? (0, 0)
            memberDict[tx.createdBy] = (currentMember.0 + convertedAmount, currentMember.1 + 1)
        }
        
        let newCatSums = catDict.map { 
            CategorySummary(
                name: $0.key, amount: $0.value.amount, icon: $0.value.icon,
                percentage: totalTypeAmount > 0 ? ($0.value.amount / totalTypeAmount) * 100 : 0,
                transactionCount: $0.value.count
            ) 
        }.sorted(by: { $0.amount > $1.amount })
        
        let newMemberSums = memberDict.map {
            MemberContribution(username: $0.key, amount: $0.value.amount, transactionCount: $0.value.count)
        }.sorted(by: { $0.amount > $1.amount })
        
        // State Ataması
        self.flowData = newFlowData
        self.globalMaxAmount = newGlobalMax
        self.biggestTransaction = biggestActive
        self.recurringTransactions = recurring
        self.categorySummaries = newCatSums
        self.memberContributions = newMemberSums
        
        // Yeniden yüklendiği için animasyon tetikle
        if startAnimation {
            animateGraph(fromChange: true)
        }
    }
    
    // Yüklenme (Staggered) Animasyonu
    private func animateGraph(fromChange: Bool = false) {
        for (index, _) in flowData.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * (fromChange ? 0.015 : 0.03)) {
                withAnimation(fromChange ? .easeInOut(duration: 0.6) : .interactiveSpring(response: 0.8, dampingFraction: 0.8, blendDuration: 0.8)) {
                    if index < self.flowData.count { // Crash koruması
                        self.flowData[index].animate = true
                    }
                }
            }
        }
    }
    
    private var chartUnit: Calendar.Component {
        if dateFilterMode == .custom { return .day }
        let range = (dateFilterMode != .all && dateFilterMode != .custom) ? 
                    (dateFilterMode == .weekly ? AnalysisTimeFrame.week : (dateFilterMode == .monthly ? AnalysisTimeFrame.month : AnalysisTimeFrame.year)) : selectedTab
        
        switch range {
        case .day: return .hour
        case .week: return .day
        case .month: return .day
        case .year: return .month
        }
    }

    
    // MARK: - PDF Export Engine
    @MainActor
    private func sharePDF() {
        if authManager.currentUserProfile?.isPro != true {
            showProAlert = true
            return
        }
        
        isSharingPDF = true

        
        // Raporlanacak datanın UI'ını Main Actor garantisinde yakala
        let reportDetails = AnalysisPDFReportView(
            flowData: flowData,
            categorySummaries: categorySummaries,
            biggestTransaction: biggestTransaction,
            totalRecurring: recurringTransactions.reduce(0.0) { $0 + $1.amount },
            timeFrame: selectedTab.rawValue
        )
        
        let renderer = ImageRenderer(content: reportDetails)
        
        // iOS 16 için ImageRenderer ile PDF dönüştürme
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Finvo_Analiz_\(selectedTab.rawValue).pdf")
        
        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let pdf = CGContext(tempURL as CFURL, mediaBox: &box, nil) else { return }
            
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
        }
        
        self.pdfURL = tempURL
        self.isSharingPDF = false
    }
}

// UIKit UIActivityViewController Wrapper for flawless PDF sharing
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AnalysisView()
        .environment(\.theme, DefaultTheme())
        .environmentObject(WalletManager())
        .environmentObject(TransactionManager())
}
