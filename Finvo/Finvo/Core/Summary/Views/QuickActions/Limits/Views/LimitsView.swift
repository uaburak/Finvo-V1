import SwiftUI

struct LimitsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State private var limitAmount: Double? = nil
    @State private var showEditSheet: Bool = false
    @State private var isLoading: Bool = false
    @State private var categoryLimitEditor: CategoryLimitEditorTarget?
    @ObservedObject private var categoryManager = CategoryManager.shared
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            let limit = walletManager.activeWallet?.monthlyLimit ?? 0
            let limitCurr = CurrencyType(rawValue: walletManager.activeWallet?.monthlyLimitCurrency ?? "") ?? .tryCurrency
            let generalLimitSafe = ExchangeRateManager.shared.convert(amount: limit, from: limitCurr, to: appCurrency)
            
            ScrollView {
                VStack(spacing: 24) {
                    if limit == 0 {
                        emptyLimitNotice
                        
                        // Limit cüzdan ayarıdır: sadece kurucu/yönetici değiştirebilir
                        if walletManager.canManageActiveWallet {
                        Button {
                            limitAmount = nil
                            showEditSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Genel Limit Belirle")
                            }
                            .font(.headline)
                            .foregroundColor(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.glassProminent)
                        .clipShape(Capsule())
                        .padding(.horizontal)
                        }
                    } else {
                        limitCard(limit: generalLimitSafe)
                        
                        if walletManager.canManageActiveWallet {
                        HStack(spacing: 16) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                deleteLimit()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Limiti Kaldır")
                                }
                                .font(.headline)
                                .foregroundColor(.red) // Limit kaldır kırmızı daha uygun
                                .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.glass)
                            .clipShape(Capsule())
                            
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                limitAmount = limit > 0 ? generalLimitSafe : nil
                                showEditSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("Limiti Güncelle")
                                }
                                .font(.headline)
                                .foregroundColor(theme.onBrandPrimary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.glassProminent)
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        }
                    }
                    
                    categoryLimitsSection
                }
                .padding(.vertical)
            }
            .id(appCurrency)
        }
        .navigationTitle("Limitler")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            limitEditForm
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $categoryLimitEditor) { target in
            CategoryLimitEditSheet(target: target)
                .environmentObject(walletManager)
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Kategori Limitleri
    private var expenseCategories: [CategoryModel] {
        (categoryManager.categories.isEmpty ? CategoriesMockData.data : categoryManager.categories)
            .filter { $0.type == .expense && $0.isOn }
    }
    
    @ViewBuilder
    private var categoryLimitsSection: some View {
        let limits = walletManager.activeWallet?.categoryLimits ?? [:]
        let rows = expenseCategories.filter { limits[$0.id] != nil }
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kategori Limitleri")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.labelPrimary)
                Spacer()
                if walletManager.canManageActiveWallet {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        categoryLimitEditor = CategoryLimitEditorTarget(categoryId: nil)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(theme.labelPrimary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            
            if rows.isEmpty {
                Text("Market, ulaşım gibi kategorilere ayrı aylık limit koyun; %80'e ulaşınca ve aşınca bildirim alın.")
                    .font(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .glassEffect(in: .rect(cornerRadius: 24))
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, category in
                        if let limit = limits[category.id] {
                            categoryLimitRow(category: category, limit: limit)
                            if index < rows.count - 1 {
                                Divider().padding(.leading, 62).padding(.trailing, 16)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal)
            }
        }
    }
    
    private func categoryLimitRow(category: CategoryModel, limit: CategoryLimitModel) -> some View {
        let limitCurrency = CurrencyType(rawValue: limit.currency) ?? .tryCurrency
        let limitAmount = ExchangeRateManager.shared.convert(amount: limit.amount, from: limitCurrency, to: appCurrency)
        let spent = SpendingLimitMonitor.monthlySpending(in: transactionManager.transactions, categoryId: category.id,
                                                         categoryName: category.name, currency: appCurrency)
        let progress = limitAmount > 0 ? min(spent / limitAmount, 1) : 0
        let isOver = spent > limitAmount
        let barColor: Color = isOver ? theme.expense : (progress >= 0.8 ? .orange : theme.brandPrimary)
        
        return Button {
            guard walletManager.canManageActiveWallet else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            categoryLimitEditor = CategoryLimitEditorTarget(categoryId: category.id)
        } label: {
            VStack(spacing: 10) {
                ListItem(
                    icon: category.icon,
                    iconColor: category.uiColor,
                    title: category.localizedName,
                    subtitle: LocalizedStringKey("\(appCurrency.symbol)\(spent.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))) / \(appCurrency.symbol)\(limitAmount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))"),
                    value: "%\(Int((limitAmount > 0 ? spent / limitAmount : 0) * 100))",
                    valueColor: isOver ? theme.expense : theme.labelPrimary
                )
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.separator).frame(height: 6)
                        Capsule().fill(barColor).frame(width: max(0, geo.size.width * progress), height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.leading, 46)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var emptyLimitNotice: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(theme.labelSecondary)
            
            Text(L10n("Aylık Harcama Limiti Yok"))
                .font(.title2.bold())
                .foregroundColor(theme.labelPrimary)
            
            Text("Harcamalarınızı kontrol altına almak için cüzdanınıza bir aylık limit belirleyin.")
                .font(.subheadline)
                .foregroundColor(theme.labelSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
    
    @ViewBuilder
    private func limitCard(limit: Double) -> some View {
        let now = Date()
        let currentMonthExpenses = transactionManager.transactions.filter { 
            !$0.isDebt && $0.type == .expense &&
            Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month) &&
            Calendar.current.isDate($0.date, equalTo: now, toGranularity: .year)
        }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: appCurrency)
        }
        
        let displayLimit = max(limit, 1.0)
        let progress = min(currentMonthExpenses / displayLimit, 1.0)
        let remaining = max(limit - currentMonthExpenses, 0)
        let isOverLimit = currentMonthExpenses > limit
        let percentageText = "%\(Int(progress * 100))"
        let limitColor = isOverLimit ? theme.expense : theme.brandPrimary
        
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n("Bu Ayki Harcama"))
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                }
                Spacer()
                Text("\(appCurrency.symbol)\(currentMonthExpenses.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.title3.bold())
                    .foregroundColor(isOverLimit ? theme.expense : theme.labelPrimary)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(percentageText)")
                    .font(.caption2.bold())
                    .foregroundColor(limitColor)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.separator)
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(limitColor)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 12)
                    }
                }
                .frame(height: 12)
            }
            
            HStack {
                Text("Kalan: \(appCurrency.symbol)\(remaining.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.subheadline.bold())
                    .foregroundColor(isOverLimit ? theme.expense : theme.labelPrimary)
                Spacer()
                Text("Limit: \(appCurrency.symbol)\(limit.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
            }
        }
        .padding(24)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }
    
    private var limitEditForm: some View {
        NavigationStack {
            VStack(spacing: 24) {
                HStack {
                    Text(appCurrency.symbol)
                        .font(.body)
                        .foregroundColor(theme.labelSecondary)
                    
                    TextField("Yeni Limit", value: $limitAmount, format: .number)
                        .keyboardType(.decimalPad)
                        .font(.body)
                        .foregroundColor(theme.labelPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(theme.separator, lineWidth: 1)
                )
                
                HStack(spacing: 12) {
                    Button {
                        showEditSheet = false
                    } label: {
                        Text(L10n("İptal"))
                            .font(.headline)
                            .foregroundColor(theme.labelPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glass)
                    .clipShape(Capsule())
                    
                    Button(action: saveLimit) {
                        if isLoading {
                            ProgressView().tint(theme.onBrandPrimary)
                        } else {
                            Text(L10n("Kaydet"))
                                .font(.headline)
                                .foregroundColor(theme.onBrandPrimary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .clipShape(Capsule())
                    .disabled(isLoading || (limitAmount ?? 0) <= 0)
                    .opacity((limitAmount ?? 0) <= 0 ? 0.6 : 1.0)
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Genel Limiti Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                            .foregroundStyle(theme.labelPrimary)
                    }
                }
            }
            .background(theme.background1.ignoresSafeArea())
        }
    }
    
    private func deleteLimit() {
        guard let activeWallet = walletManager.activeWallet else { return }
        var updated = activeWallet
        updated.monthlyLimit = 0
        updated.monthlyLimitCurrency = appCurrency.rawValue
        
        Task {
            try? await FirestoreService.shared.updateWallet(updated)
            await MainActor.run { walletManager.activeWallet = updated }
        }
    }
    
    private func saveLimit() {
        guard let activeWallet = walletManager.activeWallet else { return }
        guard let val = limitAmount, val > 0 else { return }
        
        isLoading = true
        var updated = activeWallet
        
        updated.monthlyLimit = val
        updated.monthlyLimitCurrency = appCurrency.rawValue
        
        Task {
            do {
                try await FirestoreService.shared.updateWallet(updated)
                await MainActor.run {
                    walletManager.activeWallet = updated // Optimistic update
                    isLoading = false
                    showEditSheet = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

