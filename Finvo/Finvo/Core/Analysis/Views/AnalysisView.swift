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
    
    // UI States
    @State private var selectedTab: AnalysisTimeFrame = .month
    
    // Chart Toggles
    @State private var isLineGraph: Bool = true
    
    // Core Data
    @State private var flowData: [FlowData] = []
    @State private var biggestTransaction: TransactionModel? = nil
    @State private var recurringTransactions: [TransactionModel] = []
    @State private var categorySummaries: [CategorySummary] = []
    @State private var memberContributions: [MemberContribution] = []
    
    // Filter & Export States
    @State private var selectedFilterType: TransactionTypeFilter = .all
    @State private var isSharingPDF: Bool = false
    @State private var pdfURL: URL? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background1.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        AnalysisSegmentedControl(selectedTab: $selectedTab)
                        
                        AnalysisChartCard(
                            flowData: flowData,
                            chartUnit: chartUnit,
                            isLineGraph: $isLineGraph,
                            selectedTab: selectedTab
                        )
                        
                        AnalysisMiniCards(
                            recurringTransactions: recurringTransactions,
                            biggestTransaction: biggestTransaction
                        )
                        
                        AnalysisCategoryCard(
                            categorySummaries: categorySummaries
                        )
                        
                        // Sadece paylaşımlı cüzdanlarda (veya üye sayısı 1'den büyükse) Liderlik tablosunu göster
                        if let wallet = walletManager.activeWallet, (wallet.type == .shared || wallet.members.count > 1) {
                            AnalysisCollaboratorCard(
                                contributions: memberContributions,
                                allTransactions: transactionManager.transactions // Filtrelenmemiş gerçek tüm veri listesi gönderiliyor ki detay ekranında tarihe göre süzebilsin
                            )
                        }
                        
                    }
                    .padding(.horizontal, 20)
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
                    Menu {
                        Picker("İşlem Tipi", selection: $selectedFilterType) {
                            ForEach(TransactionTypeFilter.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    } label: {
                        Image(systemName: selectedFilterType == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                            .foregroundColor(theme.labelPrimary)
                            .font(.system(size: 18))
                    }
                }
            }
            .onAppear {
                updateData(startAnimation: true)
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
            .sheet(isPresented: .init(get: { pdfURL != nil }, set: { if !$0 { pdfURL = nil } })) {
                if let url = pdfURL {
                    ShareSheet(activityItems: [url])
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }
    
    // MARK: - Data Engine
    private func updateData(startAnimation: Bool = false) {
        let range = selectedTab
        let allTxs = transactionManager.transactions
        let calendar = Calendar.current
        let now = Date()
        
        var newFlowData: [FlowData] = []
        var filteredTxs: [TransactionModel] = []
        
        // 1. Seçili Zamana Göre Boş Çatıları (Slotları) Oluştur ve İşlemleri Filtrele
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
        
        // 2. Net Nakit Akışını Yuvalara Yerleştir (Gelir - Gider)
        for tx in filteredTxs {
            if tx.isDebt { continue } // Borç işlemleri grafikte hesaplanmaz, taksitleri hesaplanır.
            if selectedFilterType == .income && tx.type != .income { continue }
            if selectedFilterType == .expense && tx.type != .expense { continue }
            
            let value = tx.type == .income ? tx.amount : -tx.amount
            if let index = newFlowData.firstIndex(where: {
                calendar.isDate($0.date, equalTo: tx.date, toGranularity: chartUnit)
            }) {
                newFlowData[index].netAmount += value
            }
        }
            
        // 3. Mini Kart Verileri
        let biggestActive = filteredTxs.filter {
            !$0.isDebt && 
            ((selectedFilterType == .all && $0.type == .expense) ||
            (selectedFilterType == .income && $0.type == .income) ||
            (selectedFilterType == .expense && $0.type == .expense))
        }.max(by: { $0.amount < $1.amount })
        
        let recurring = allTxs.filter { $0.isRecurring }
        
        // 4. Kategori Verileri
        var catDict: [String: (amount: Double, icon: String, count: Int)] = [:]
        var memberDict: [String: (amount: Double, count: Int)] = [:]
        
        // Kullanıcı filtreyi gelire çekerse Kategori ve Liderlik Dağılımını sadece Gelirler ile göster!
        let targetTypeForCategories: TransactionType = selectedFilterType == .income ? .income : .expense
        let typeFilteredTxs = filteredTxs.filter { $0.type == targetTypeForCategories && !$0.isDebt }
        let totalTypeAmount = typeFilteredTxs.reduce(0) { $0 + $1.amount }
        
        for tx in typeFilteredTxs {
            // Kategori Toplama
            let cat = tx.mainCategoryName
            let currentCat = catDict[cat] ?? (amount: 0, icon: tx.categoryIcon, count: 0)
            catDict[cat] = (amount: currentCat.amount + tx.amount, icon: tx.categoryIcon, count: currentCat.count + 1)
            
            // Kişi Toplama
            let currentMember = memberDict[tx.createdBy] ?? (0, 0)
            memberDict[tx.createdBy] = (currentMember.0 + tx.amount, currentMember.1 + 1)
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
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            self.biggestTransaction = biggestActive
            self.recurringTransactions = recurring
            self.categorySummaries = newCatSums
            self.memberContributions = newMemberSums
        }
        
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
        switch selectedTab {
        case .day: return .hour
        case .week: return .day
        case .month: return .day
        case .year: return .month
        }
    }
    
    // MARK: - PDF Export Engine
    @MainActor
    private func sharePDF() {
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
