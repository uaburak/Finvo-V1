import SwiftUI

struct SavingsAccountDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    let account: SavingsAccountModel
    
    @State private var showAmountSheet = false
    @State private var showEditSheet = false
    @State private var isAdding = true
    @State private var amountInput: String = ""
    @State private var selectedCurrency: CurrencyType = .tryCurrency
    @State private var showDeleteConfirm = false
    @State private var isProcessing = false
    
    // Uygulama para birimi (TL vs) cinsinden toplam sepet değeri
    private var totalBalanceInAppCurrency: Double {
        var total: Double = 0
        if let assets = account.assets {
            for (key, qty) in assets {
                if let type = CurrencyType(rawValue: key) {
                    total += ExchangeRateManager.shared.convert(amount: qty, from: type, to: appCurrency)
                }
            }
        }
        return total
    }
    
    // Uygulama para birimi cinsinden dinamik hedef
    private var dynamicGoalAmount: Double {
        let goalCurr = CurrencyType(rawValue: account.goalCurrency ?? "") ?? .tryCurrency
        return ExchangeRateManager.shared.convert(amount: account.goalAmount, from: goalCurr, to: appCurrency)
    }
    
    private func getSwiftColor(from stringRaw: String) -> Color {
        switch stringRaw.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "mint": return .mint
        default: return theme.brandPrimary
        }
    }
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            let cardColor = getSwiftColor(from: account.color)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    
                    // İkon ve Başlık Bölümü
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(cardColor.opacity(0.15))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "lanyardcard.fill")
                                .font(.system(size: 44))
                                .foregroundColor(cardColor)
                        }
                        
                        VStack(spacing: 8) {
                            Text(account.name)
                                .font(.title.bold())
                                .foregroundColor(theme.labelPrimary)
                            
                            Text("Hedef: \(appCurrency.symbol)\(dynamicGoalAmount.formatted(.number.precision(.fractionLength(0))))")
                                .font(.headline)
                                .foregroundColor(theme.labelSecondary)
                        }
                    }
                    .padding(.top, 20)
                    
                    // İlerleme Kartı
                    VStack(spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Biriken Tutar")
                                    .font(.subheadline)
                                    .foregroundColor(theme.labelSecondary)
                                    
                                Text("\(appCurrency.symbol)\(totalBalanceInAppCurrency.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.title2.bold())
                                    .foregroundColor(cardColor)
                            }
                            Spacer()
                            
                            let percentage: Double = {
                                return dynamicGoalAmount > 0 ? (totalBalanceInAppCurrency / dynamicGoalAmount) * 100 : 0
                            }()
                            
                            Text("%\(percentage.formatted(.number.precision(.fractionLength(0))))")
                                .font(.title3.bold())
                                .foregroundColor(theme.labelPrimary)
                        }
                        
                        // Alt varlıkların detayları (örn: 15 Gr Altın, 100 USD)
                        if let assets = account.assets, !assets.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(assets.keys).sorted(), id: \.self) { key in
                                        if let qty = assets[key], qty > 0, let type = CurrencyType(rawValue: key) {
                                            HStack(spacing: 4) {
                                                Text(type.symbol)
                                                    .font(.caption2.bold())
                                                    .foregroundColor(theme.labelSecondary)
                                                Text("\(qty.formatted(.number.precision(.fractionLength(type == .tryCurrency ? 0 : 2))))")
                                                    .font(.caption.bold())
                                                    .foregroundColor(theme.labelPrimary)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(theme.background2)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(theme.separatorSecondary)
                                let progress = dynamicGoalAmount > 0 ? (totalBalanceInAppCurrency / dynamicGoalAmount) : 0
                                Capsule().fill(cardColor)
                                    .frame(width: max(0, min(CGFloat(progress) * geo.size.width, geo.size.width)))
                            }
                        }
                        .frame(height: 12)
                        
                        let remaining: Double = {
                            return dynamicGoalAmount - totalBalanceInAppCurrency
                        }()
                        
                        if remaining > 0 {
                            Text("Hedefe \(appCurrency.symbol)\(remaining.formatted(.number.precision(.fractionLength(0)))) kaldı")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Text("Hedefe ulaştınız! 🎉")
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(24)
                    .glassEffect(in: .rect(cornerRadius: 28))
                    .padding(.horizontal, 24)
                    
                    // İşlem Butonları
                    HStack(spacing: 20) {
                        Button {
                            isAdding = false
                            amountInput = ""
                            showAmountSheet = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                Text("Para Çıkar")
                                    .font(.headline)
                            }
                            .foregroundColor(theme.labelPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .glassEffect(in: .rect(cornerRadius: 24))
                        }
                        .disabled(totalBalanceInAppCurrency <= 0)
                        .opacity(totalBalanceInAppCurrency <= 0 ? 0.5 : 1.0)
                        
                        Button {
                            isAdding = true
                            amountInput = ""
                            showAmountSheet = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Para Ekle")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(cardColor)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // İşlem Geçmişi
                    VStack(alignment: .leading, spacing: 16) {
                        Text("İşlem Geçmişi")
                            .font(.headline)
                            .foregroundColor(theme.labelPrimary)
                            .padding(.horizontal, 24)
                        
                        let accountTransactions = transactionManager.transactions.filter { 
                            $0.subCategoryName == account.name && ($0.mainCategoryName == "Birikim İşlemleri" || $0.mainCategoryName == "Savings Transactions")
                        }.sorted(by: { $0.date > $1.date })
                        
                        if accountTransactions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "list.bullet.rectangle.portrait")
                                    .font(.largeTitle)
                                    .foregroundColor(theme.labelSecondary.opacity(0.5))
                                Text("Henüz işlem yapılmadı")
                                    .font(.subheadline)
                                    .foregroundColor(theme.labelSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(accountTransactions) { transaction in
                                    ListItem(
                                        icon: transaction.categoryIcon,
                                        iconColor: transaction.type == .income ? theme.expense : .blue,
                                        title: LocalizedStringKey(transaction.type == .income ? "Para Çıkarıldı" : "Para Eklendi"),
                                        subtitle: LocalizedStringKey(transaction.date.formatted(date: .abbreviated, time: .shortened)),
                                        value: (transaction.type == .income ? "+\(transaction.currency?.symbol ?? appCurrency.symbol)" : "-\(transaction.currency?.symbol ?? appCurrency.symbol)") + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))),
                                        valueColor: transaction.type == .income ? theme.expense : theme.income
                                    )
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 24)
                                    
                                    if transaction.id != accountTransactions.last?.id {
                                        Divider()
                                            .padding(.leading, 80)
                                            .padding(.trailing, 24)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Birikim Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { showEditSheet = true }) {
                    Image(systemName: "pencil")
                        .foregroundColor(theme.labelPrimary)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditSavingsAccountSheet(account: account)
                .environmentObject(walletManager)
                .environmentObject(transactionManager)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showAmountSheet) {
            SavingsDepositSheet(isAdding: isAdding) { amountStr, currency in
                amountInput = amountStr
                selectedCurrency = currency
                handleTransaction(adding: isAdding)
            }
        }
        .alert("Hesabı Sil", isPresented: $showDeleteConfirm) {
            Button("İptal", role: .cancel) { }
            Button("Sil", role: .destructive) { deleteAccount() }
        } message: {
            Text("\(account.name) hesabını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.")
        }
    }
    
    private func handleTransaction(adding: Bool) {
        guard let wallet = walletManager.activeWallet, let currentUser = authManager.currentUserProfile?.username else { return }
        let rawAmount = amountInput.replacingOccurrences(of: ",", with: ".")
        guard let validAmount = Double(rawAmount), validAmount > 0 else { return }
        
        isProcessing = true
        
        let txType: TransactionType = adding ? .expense : .income // Mevduattan para çıkıyor (Gider)
        
        var qtyString = ""
        if selectedCurrency != .tryCurrency {
            qtyString = " (\(validAmount.formatted(.number.precision(.fractionLength(0)))) \(selectedCurrency.symbol))"
        }
        
        let txMsg = adding ? "\(account.name) fonuna eklendi\(qtyString)." : "\(account.name) fonundan çekildi\(qtyString)."
        
        let tx = TransactionModel(
            walletId: wallet.id ?? "",
            type: txType,
            amount: validAmount, // Gerçek birim
            currency: selectedCurrency, // Native para birimini transaction'a işle!
            mainCategoryName: "Birikim İşlemleri",
            subCategoryName: account.name,
            categoryIcon: "lanyardcard.fill",
            categoryColor: account.color,
            date: Date(),
            note: txMsg,
            createdBy: currentUser,
            createdAt: Date(),
            isDebt: false
        )
        
        Task {
            try? FirestoreService.shared.createTransaction(tx)
            
            await MainActor.run {
                var updatedWallet = wallet
                if var accounts = updatedWallet.savingsAccounts,
                   let idx = accounts.firstIndex(where: { $0.id == account.id }) {
                    
                    var updatedAssets = accounts[idx].assets ?? [:]
                    let currentQty = updatedAssets[selectedCurrency.rawValue] ?? 0
                    
                    if adding {
                        updatedAssets[selectedCurrency.rawValue] = currentQty + validAmount
                    } else {
                        updatedAssets[selectedCurrency.rawValue] = max(0, currentQty - validAmount)
                    }
                    
                    accounts[idx].assets = updatedAssets
                    updatedWallet.savingsAccounts = accounts
                    walletManager.updateWallet(updatedWallet)
                }
                isProcessing = false
                amountInput = ""
            }
        }
    }
    
    private func deleteAccount() {
        guard let wallet = walletManager.activeWallet else { return }
        var updatedWallet = wallet
        updatedWallet.savingsAccounts?.removeAll(where: { $0.id == account.id })
        walletManager.updateWallet(updatedWallet)
        dismiss()
    }
}
