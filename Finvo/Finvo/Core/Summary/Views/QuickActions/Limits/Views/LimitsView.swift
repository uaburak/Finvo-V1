import SwiftUI

struct LimitsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State private var newLimitString: String = ""
    @State private var selectedLimitCategory: String? = nil // nil = Genel Limit
    @State private var showEditForm: Bool = false
    @State private var isLoading: Bool = false
    @State private var showCategoryPicker: Bool = false
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            let limit = walletManager.activeWallet?.monthlyLimit ?? 0
            let limitCurr = CurrencyType(rawValue: walletManager.activeWallet?.monthlyLimitCurrency ?? "") ?? .tryCurrency
            let generalLimitSafe = ExchangeRateManager.shared.convert(amount: limit, from: limitCurr, to: appCurrency)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    Text("Genel Limit")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    if limit == 0 && !showEditForm {
                        emptyLimitNotice
                    } else {
                        limitCard(title: "Genel Bütçe", limit: generalLimitSafe, categoryId: nil)
                    }
                    
                    // Category Limits Section
                    let catLimits = walletManager.activeWallet?.categoryLimits ?? [:]
                    if !catLimits.isEmpty {
                        Text("Kategori Limitleri")
                            .font(.headline)
                            .foregroundColor(theme.labelSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        ForEach(Array(catLimits.keys), id: \.self) { catId in
                            let catLimitVal = catLimits[catId] ?? 0.0
                            let catLimitSafe = ExchangeRateManager.shared.convert(amount: catLimitVal, from: limitCurr, to: appCurrency)
                            let catName = CategoryManager.shared.categories.first(where: { $0.id == catId })?.name ?? "Kategori"
                            limitCard(title: catName, limit: catLimitSafe, categoryId: catId)
                        }
                    }
                    
                    if !showEditForm {
                        HStack(spacing: 16) {
                            Button {
                                selectedLimitCategory = nil
                                newLimitString = limit > 0 ? String(format: "%.0f", limit) : ""
                                withAnimation { showEditForm = true }
                            } label: {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text(limit == 0 ? "Genel Limit Belirle" : "Limiti Güncelle")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(theme.labelPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .glassEffect(in: .rect(cornerRadius: 16))
                            }
                            
                            Button {
                                showCategoryPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Kategori Limiti")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(theme.labelPrimary)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .glassEffect(in: .rect(cornerRadius: 16))
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        limitEditForm
                    }
                }
                .padding(.vertical)
            }
            .id(appCurrency)
        }
        .navigationTitle("Limitler")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet { catId in
                selectedLimitCategory = catId
                newLimitString = ""
                showEditForm = true
                showCategoryPicker = false
            }
            .presentationDetents([.medium])
        }
    }
    
    private var emptyLimitNotice: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(theme.labelSecondary)
            
            Text("Aylık Harcama Limiti Yok")
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
    private func limitCard(title: String, limit: Double, categoryId: String?) -> some View {
        let now = Date()
        let currentMonthExpenses = transactionManager.transactions.filter { 
            !$0.isDebt && $0.type == .expense &&
            (categoryId == nil || $0.mainCategoryId == categoryId) &&
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
                    Text(title)
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    Text("Bu Ayki Harcama")
                        .font(.caption)
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
        .contextMenu {
            if categoryId != nil {
                Button(role: .destructive) {
                    deleteCategoryLimit(catId: categoryId!)
                } label: {
                    Label("Limiti Kaldır", systemImage: "trash")
                }
            }
        }
    }
    
    private var limitEditForm: some View {
        VStack(spacing: 16) {
            let catName = selectedLimitCategory != nil ? (CategoryManager.shared.categories.first(where: { $0.id == selectedLimitCategory })?.name ?? "Kategori") : "Genel"
            Text("\(catName) Limiti Düzenle")
                .font(.headline)
                .foregroundColor(theme.labelPrimary)
                
            HStack {
                Text(appCurrency.symbol)
                    .font(.title2.bold())
                    .foregroundColor(theme.labelSecondary)
                TextField("Yeni Limit", text: $newLimitString)
                    .keyboardType(.decimalPad)
                    .font(.title2.bold())
                    .foregroundColor(theme.labelPrimary)
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16))
            
            HStack(spacing: 12) {
                Button("İptal") {
                    withAnimation { showEditForm = false }
                }
                .font(.headline)
                .foregroundColor(theme.labelPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
                
                Button(action: saveLimit) {
                    if isLoading {
                        ProgressView().tint(theme.labelPrimary) // glass uyarınca siyah/beyaz olabilir
                    } else {
                        Text("Kaydet")
                            .font(.headline)
                            .foregroundColor(theme.labelPrimary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
                .disabled(isLoading || newLimitString.isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 24)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }
    
    private func deleteCategoryLimit(catId: String) {
        guard let activeWallet = walletManager.activeWallet else { return }
        var updated = activeWallet
        updated.categoryLimits?[catId] = nil
        
        Task {
            try? await FirestoreService.shared.updateWallet(updated)
            await MainActor.run { walletManager.activeWallet = updated }
        }
    }
    
    private func saveLimit() {
        guard let activeWallet = walletManager.activeWallet else { return }
        let cleanText = newLimitString.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        guard let val = Double(cleanText) else { return }
        
        isLoading = true
        var updated = activeWallet
        
        if let catId = selectedLimitCategory {
            if updated.categoryLimits == nil { updated.categoryLimits = [:] }
            updated.categoryLimits?[catId] = val
            // We assume category limits are stored in appCurrency (or define a currency for them if we want to be overly complex!)
            // For simplicity, we just save them assuming they correspond to monthlyLimitCurrency!
            updated.monthlyLimitCurrency = appCurrency.rawValue
        } else {
            updated.monthlyLimit = val
            updated.monthlyLimitCurrency = appCurrency.rawValue
        }
        
        Task {
            do {
                try await FirestoreService.shared.updateWallet(updated)
                await MainActor.run {
                    walletManager.activeWallet = updated // Optimistic update
                    isLoading = false
                    withAnimation { showEditForm = false }
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme
    var onSelect: (String) -> Void
    
    var body: some View {
        NavigationView {
            List {
                let expenses = CategoryManager.shared.categories.filter { $0.type == .expense }
                ForEach(expenses) { cat in
                    Button {
                        onSelect(cat.id)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: cat.icon)
                            Text(cat.name)
                        }
                    }
                }
            }
            .navigationTitle("Kategori Seç")
            .navigationBarItems(trailing: Button("Kapat") { dismiss() })
        }
    }
}
