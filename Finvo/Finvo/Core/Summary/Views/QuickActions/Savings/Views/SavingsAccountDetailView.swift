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
    
    // MARK: - Helpers
    
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
        let text = sign + "%" + formatPercentage(pct)
        let color = pct > 0 ? theme.income : theme.expense
        return (text, color)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            let cardColor = getSwiftColor(from: account.color)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    
                    // MARK: Header Card
                    VStack(spacing: 24) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(cardColor.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "lanyardcard.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(cardColor)
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
                        
                        // Progress Bar
                        VStack(spacing: 8) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(theme.separatorSecondary)
                                    let progress = dynamicGoalAmount > 0 ? (totalBalanceInAppCurrency / dynamicGoalAmount) : 0
                                    Capsule().fill(cardColor)
                                        .frame(width: max(0, min(CGFloat(progress) * geo.size.width, geo.size.width)))
                                }
                            }
                            .frame(height: 12)
                            
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
                        
                        // Asset badges
                        if let assets = account.assets, !assets.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
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
                    .padding(24)
                    .glassEffect(in: .rect(cornerRadius: 28))
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    
                    // MARK: Action Buttons
                    HStack(spacing: 20) {
                        Button {
                            isAdding = false
                            amountInput = ""
                            showAmountSheet = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "minus.circle.fill").font(.title2)
                                Text("Para Çıkar").font(.headline)
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
                                Image(systemName: "plus.circle.fill").font(.title2)
                                Text("Para Ekle").font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(cardColor)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // MARK: Transaction List
                    let accountTransactions = transactionManager.transactions.filter {
                        $0.subCategoryName == account.name &&
                        ($0.mainCategoryName == "Birikim İşlemleri" || $0.mainCategoryName == "Savings Transactions")
                    }.sorted(by: { $0.date > $1.date })
                    
                    if !accountTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(accountTransactions) { transaction in
                                transactionRow(transaction, isLast: transaction.id == accountTransactions.last?.id)
                            }
                        }
                        .padding(.top, 8)
                    }
                    
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
        .padding(.vertical, 4)
        .padding(.horizontal, 24)
        
        if !isLast {
            Divider()
                .padding(.leading, 80)
                .padding(.trailing, 24)
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
