import SwiftUI

struct LimitsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State private var limitAmount: Double? = nil
    @State private var showEditSheet: Bool = false
    @State private var isLoading: Bool = false
    
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
                        
                        Button {
                            limitAmount = nil
                            showEditSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus")
                                Text("Genel Limit Belirle")
                            }
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.glassProminent)
                        .clipShape(Capsule())
                        .padding(.horizontal)
                    } else {
                        limitCard(limit: generalLimitSafe)
                        
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
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, minHeight: 48)
                            }
                            .buttonStyle(.glassProminent)
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
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
                    Text("Bu Ayki Harcama")
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
                        Text("İptal")
                            .font(.headline)
                            .foregroundColor(theme.labelPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glass)
                    .clipShape(Capsule())
                    
                    Button(action: saveLimit) {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("Kaydet")
                                .font(.headline)
                                .foregroundColor(.black)
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

