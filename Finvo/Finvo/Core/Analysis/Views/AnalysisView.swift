import SwiftUI
import Charts

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
    @State private var pendingDebtAmount: Double = 0
    @State private var categorySummaries: [CategorySummary] = []
    
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
                            pendingDebtAmount: pendingDebtAmount,
                            biggestTransaction: biggestTransaction
                        )
                        
                        AnalysisCategoryCard(
                            categorySummaries: categorySummaries
                        )
                        
                    }
                    .padding(.horizontal, 20)
                    .safeAreaPadding(.bottom, 60)
                }
            }
            .navigationTitle("Analiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        withAnimation(.spring()) {
                            isLineGraph.toggle()
                        }
                    }) {
                        Image(systemName: isLineGraph ? "chart.bar.fill" : "chart.xyaxis.line")
                            .foregroundColor(theme.brandPrimary)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Filtreleme ekranı/sheet açılacak
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(theme.brandPrimary)
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
            let value = tx.type == .income ? tx.amount : -tx.amount
            if let index = newFlowData.firstIndex(where: {
                calendar.isDate($0.date, equalTo: tx.date, toGranularity: chartUnit)
            }) {
                newFlowData[index].netAmount += value
            }
        }
            
        // 3. Mini Kart Verileri
        let biggest = filteredTxs.filter { $0.type == .expense }.max(by: { $0.amount < $1.amount })
        let pendingAmount = allTxs.filter { $0.isDebt }.reduce(0) { $0 + $1.amount }
        let samplePending = pendingAmount > 0 ? pendingAmount : 4250.0 
        
        // 4. Kategori Verileri
        var catDict: [String: (amount: Double, icon: String, count: Int)] = [:]
        let expenseTxs = filteredTxs.filter { $0.type == .expense }
        let totalExpense = expenseTxs.reduce(0) { $0 + $1.amount }
        
        for tx in expenseTxs {
            let cat = tx.mainCategoryName
            let current = catDict[cat] ?? (amount: 0, icon: tx.categoryIcon, count: 0)
            catDict[cat] = (amount: current.amount + tx.amount, icon: tx.categoryIcon, count: current.count + 1)
        }
        let newCatSums = catDict.map { 
            CategorySummary(
                name: $0.key, amount: $0.value.amount, icon: $0.value.icon,
                percentage: totalExpense > 0 ? ($0.value.amount / totalExpense) * 100 : 0,
                transactionCount: $0.value.count
            ) 
        }.sorted(by: { $0.amount > $1.amount })
        
        // State Ataması
        self.flowData = newFlowData
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            self.biggestTransaction = biggest
            self.pendingDebtAmount = samplePending
            self.categorySummaries = newCatSums
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
}

#Preview {
    AnalysisView()
        .environment(\.theme, DefaultTheme())
}
