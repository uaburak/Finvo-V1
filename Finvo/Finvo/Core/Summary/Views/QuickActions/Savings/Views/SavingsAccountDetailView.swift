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
    @State private var amountInput: String = ""
    @State private var selectedCurrency: CurrencyType = .tryCurrency
    @State private var isAdding: Bool = true
    @State private var showDeleteConfirm = false
    @State private var isProcessing = false
    
    // MARK: - Computed Properties
    
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
    
    private var dynamicGoalAmount: Double {
        let goalCurr = CurrencyType(rawValue: account.goalCurrency ?? "") ?? .tryCurrency
        return ExchangeRateManager.shared.convert(amount: account.goalAmount, from: goalCurr, to: appCurrency)
    }
    
    private var cardColor: Color {
        Color.fromStandardName(account.color)
    }
    
    // MARK: - Helpers
    
    private func formatAmount(_ amount: Double) -> String {
        amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
    }
    
    private func formatPercentage(_ pct: Double) -> String {
        pct.formatted(.number.precision(.fractionLength(2)))
    }
    
    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
    
    private func formatAssetQuantity(_ qty: Double, type: CurrencyType) -> String {
        let fractionLen = type == .tryCurrency ? 0 : 2
        return qty.formatted(.number.precision(.fractionLength(fractionLen)))
    }
    
    private func computeProfitLoss(isDeposit: Bool, currentVal: Double, initialVal: Double?) -> (text: String, color: Color)? {
        guard isDeposit, let initial = initialVal, initial > 0 else { return nil }
        let diff = currentVal - initial
        let pct = (diff / initial) * 100
        guard abs(pct) > 0.01 else { return ("%0.00", theme.labelSecondary) }
        let sign = pct > 0 ? "+" : ""
        return (sign + "%" + formatPercentage(pct), pct > 0 ? theme.income : theme.expense)
    }
    
    // MARK: - Header Card (sticky)
    private var headerCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(cardColor)
                        .frame(width: 52, height: 52)
                    Image(systemName: "lanyardcard.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.title3.bold())
                        .foregroundColor(theme.labelPrimary)
                    Text("Hedef: \(appCurrency.symbol)\(formatAmount(dynamicGoalAmount))")
                        .font(.caption)
                        .foregroundColor(theme.labelSecondary)
                }
                Spacer()
                let percentage: Double = dynamicGoalAmount > 0 ? (totalBalanceInAppCurrency / dynamicGoalAmount) * 100 : 0
                Text("%\(formatAmount(percentage))")
                    .font(.title3.bold())
                    .foregroundColor(theme.labelPrimary)
            }
            
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.separatorSecondary.opacity(0.2))
                        let progress = dynamicGoalAmount > 0 ? (totalBalanceInAppCurrency / dynamicGoalAmount) : 0
                        Capsule().fill(cardColor)
                            .frame(width: max(0, min(CGFloat(progress) * geo.size.width, geo.size.width)))
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(appCurrency.symbol)\(formatAmount(totalBalanceInAppCurrency))")
                        .font(.caption.bold())
                        .foregroundColor(cardColor)
                    Spacer()
                    let remaining = dynamicGoalAmount - totalBalanceInAppCurrency
                    if remaining > 0 {
                        Text("\(appCurrency.symbol)\(formatAmount(remaining)) kaldı")
                            .font(.caption)
                            .foregroundColor(theme.labelSecondary)
                    } else {
                        Text("Ulaşıldı 🎉")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                    }
                }
            }
            
            if let assets = account.assets, !assets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(assets.keys).sorted(), id: \.self) { key in
                            if let qty = assets[key], qty > 0, let type = CurrencyType(rawValue: key) {
                                HStack(spacing: 4) {
                                    Text(type.symbol)
                                        .font(.caption2.bold())
                                        .foregroundColor(theme.labelSecondary)
                                    Text(formatAssetQuantity(qty, type: type))
                                        .font(.caption.bold())
                                        .foregroundColor(theme.labelPrimary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal, 16)
    }
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .top) {
            theme.background1.ignoresSafeArea()
            
            // Scrollable content (header + button + list)
            // Birikim işlemleri için sabit kategori isimleri — yeni dil eklenirse buraya ekle
            let savingsCategoryNames: Set<String> = ["Birikim İşlemleri", "Savings Transactions", "Sparkonten-Transaktionen"]
            let accountTransactions = transactionManager.transactions.filter {
                $0.subCategoryName == account.name &&
                savingsCategoryNames.contains($0.mainCategoryName)
            }.sorted(by: { $0.date > $1.date })
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header kartın kapladığı alan kadar boşluk
                    Color.clear.frame(height: 220)
                    
                    // İşlem Yap butonu (scroll ile birlikte kayar)
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showAmountSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left.arrow.right")
                            Text("İşlem Yap")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .clipShape(Capsule())
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // İşlem listesi
                    if accountTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(theme.labelSecondary)
                            Text("Henüz işlem yok")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                        }
                        .padding(.top, 60)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(accountTransactions) { transaction in
                                transactionRow(transaction, isLast: transaction.id == accountTransactions.last?.id)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            
            // Sticky header (üstte sabit)
            headerCard
                .padding(.top, 12)
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
            SavingsDepositSheet { amountStr, currency, adding in
                amountInput = amountStr
                selectedCurrency = currency
                isAdding = adding
                handleTransaction(adding: adding)
            }
        }
        .alert("Hesabı Sil", isPresented: $showDeleteConfirm) {
            Button("İptal", role: .cancel) { }
            Button("Sil", role: .destructive) { deleteAccount() }
        } message: {
            Text("\(account.name) hesabını silmek istediğinize emin misiniz? Bu işlem geri alınamaz.")
        }
    }
    
    // MARK: - Transaction Row
    @ViewBuilder
    private func transactionRow(_ transaction: TransactionModel, isLast: Bool) -> some View {
        let isDeposit = transaction.type == .expense
        let iconName = isDeposit ? "arrow.down.left" : "arrow.up.right"
        let iconClr = isDeposit ? theme.income : theme.expense
        let assetName = transaction.currency?.name ?? transaction.resolvedSubCategoryName ?? transaction.resolvedMainCategoryName
        let currentAppVal = ExchangeRateManager.shared.convert(amount: transaction.amount, from: transaction.currency ?? appCurrency, to: appCurrency)
        let valueStr = (isDeposit ? "+" : "-") + appCurrency.symbol + formatAmount(currentAppVal)
        let profitInfo = computeProfitLoss(isDeposit: isDeposit, currentVal: currentAppVal, initialVal: transaction.appCurrencyAmountAtCreation)
        
        NavigationLink {
            TransactionDetailView(transaction: transaction)
                .environmentObject(walletManager)
                .environmentObject(authManager)
        } label: {
            ListItem(
                icon: iconName,
                iconColor: iconClr,
                title: LocalizedStringKey(assetName),
                subtitle: LocalizedStringKey(formatDate(transaction.date)),
                value: valueStr,
                valueColor: iconClr,
                secondaryInfo: profitInfo?.text,
                secondaryInfoColor: profitInfo?.color ?? theme.labelSecondary
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        
        if !isLast {
            Divider()
                .padding(.leading, 68)
                .padding(.trailing, 16)
        }
    }
    
    // MARK: - Actions
    private func handleTransaction(adding: Bool) {
        guard let wallet = walletManager.activeWallet,
              let currentUser = authManager.currentUserProfile?.username else { return }
        let rawAmount = amountInput.replacingOccurrences(of: ",", with: ".")
        guard let validAmount = Double(rawAmount), validAmount > 0 else { return }
        
        isProcessing = true
        let txType: TransactionType = adding ? .expense : .income
        let initialAppCurrencyValue = ExchangeRateManager.shared.convert(amount: validAmount, from: selectedCurrency, to: appCurrency)
        
        var qtyString = ""
        if selectedCurrency != .tryCurrency {
            qtyString = " (\(formatAmount(validAmount)) \(selectedCurrency.symbol))"
        }
        let txMsg = adding
            ? "\(account.name) fonuna eklendi\(qtyString)."
            : "\(account.name) fonundan çekildi\(qtyString)."
        
        let tx = TransactionModel(
            walletId: wallet.id ?? "",
            type: txType,
            amount: validAmount,
            currency: selectedCurrency,
            mainCategoryName: "Birikim İşlemleri",
            subCategoryName: account.name,
            categoryIcon: "lanyardcard.fill",
            categoryColor: account.color,
            date: Date(),
            note: txMsg,
            createdBy: currentUser,
            createdAt: Date(),
            appCurrencyAmountAtCreation: initialAppCurrencyValue,
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
