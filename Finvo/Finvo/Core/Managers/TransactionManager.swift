import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

@MainActor
class TransactionManager: ObservableObject {
    @Published var transactions: [TransactionModel] = []
    @Published var hasLoaded = false
    
    @Published var totalIncome: Double = 0.0
    @Published var totalExpense: Double = 0.0
    @Published var todaysProfit: Double = 0.0 // Yeni Eklenen
    @Published var topExpenseCategoryId: String? = nil
    @Published var topExpenseCategoryName: String = "-"
    
    private var isEvaluatingRecurring = false
    
    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()
    
    private var currentWalletId: String?
    
    // MARK: - Task iptal mekanizması (Bug #1 fix)
    private var recurringTask: Task<Void, Never>?
    
    // Geçerli cüzdanın ID'si ile işlemleri dinlemeye başla
    func startListening(walletId: String) {
        // Aynı cüzdan için zaten dinliyorsak tekrar başlatma
        guard walletId != currentWalletId else { return }
        stopListening()
        currentWalletId = walletId
        
        listener = db.collection("wallets").document(walletId).collection("transactions")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching transactions: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.transactions = []
                    self.totalIncome = 0
                    self.totalExpense = 0
                    self.topExpenseCategoryId = nil
                    self.topExpenseCategoryName = "-"
                    return
                }
                
                // Swift 6: Firestore callback farklı thread'den gelir.
                // @Published değişkenlere assignment'ı Main Actor'da guarantee etmek için:
                Task { @MainActor in
                    let parsed = documents.compactMap { try? $0.data(as: TransactionModel.self) }
                    
                    let baseCurrency = UserDefaults.standard.string(forKey: "appCurrency").flatMap { CurrencyType(rawValue: $0) } ?? .tryCurrency
                    
                    let income = parsed.filter { $0.type == .income && !$0.isDebt }.reduce(0) { total, tx in
                        total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
                    }
                    let expense = parsed.filter { $0.type == .expense && !$0.isDebt }.reduce(0) { total, tx in
                        total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
                    }
                    
                    let today = Date()
                    let calendar = Calendar.current
                    let todaysTx = parsed.filter { calendar.isDate($0.date, inSameDayAs: today) }
                    
                    let tIncome = todaysTx.filter { $0.type == .income && !$0.isDebt }.reduce(0) { total, tx in
                        total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
                    }
                    let tExpense = todaysTx.filter { $0.type == .expense && !$0.isDebt }.reduce(0) { total, tx in
                        total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
                    }
                    let profit = tIncome - tExpense
                    
                    let expenseOnly = parsed.filter { $0.type == .expense && !$0.isDebt }
                    let expenseDict = Dictionary(grouping: expenseOnly, by: { $0.mainCategoryId ?? $0.mainCategoryName })
                    let topEntry = expenseDict.max(by: { a, b in
                        a.value.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency) } <
                        b.value.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency) }
                    })
                    let topId = topEntry?.key
                    let topName = topEntry?.value.first?.mainCategoryName ?? "-"
                    
                    // Verileri güncelle (Main Actor garantili)
                    self.transactions = parsed
                    self.totalIncome = income
                    self.totalExpense = expense
                    self.todaysProfit = profit
                    self.topExpenseCategoryId = topId
                    self.topExpenseCategoryName = topName
                    self.hasLoaded = true
                    
                    self.evaluateRecurringTransactions(parsed, walletId: walletId)
                }
            }
    }
    
    func stopListening() {
        // Bug #1 fix: Devam eden recurring Task'ı iptal et
        recurringTask?.cancel()
        recurringTask = nil
        isEvaluatingRecurring = false
        
        listener?.remove()
        listener = nil
        currentWalletId = nil
        hasLoaded = false
        transactions = []
        totalIncome = 0
        totalExpense = 0
        topExpenseCategoryName = "-"
        isEvaluatingRecurring = false
    }
    
    @MainActor func recalculateTotals(for currency: CurrencyType) {
        let baseCurrency = currency
        
        let income = transactions.filter { $0.type == .income && !$0.isDebt }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
        }
        let expense = transactions.filter { $0.type == .expense && !$0.isDebt }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
        }
        
        let today = Date()
        let calendar = Calendar.current
        let todaysTx = transactions.filter { calendar.isDate($0.date, inSameDayAs: today) }
        
        let tIncome = todaysTx.filter { $0.type == .income && !$0.isDebt }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
        }
        let tExpense = todaysTx.filter { $0.type == .expense && !$0.isDebt }.reduce(0) { total, tx in
            total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: baseCurrency)
        }
        let profit = tIncome - tExpense
        
        let expenseOnly = transactions.filter { $0.type == .expense && !$0.isDebt }
        let expenseDict = Dictionary(grouping: expenseOnly, by: { $0.mainCategoryId ?? $0.mainCategoryName })
        let topEntry = expenseDict.max(by: { a, b in 
            a.value.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency) } < 
            b.value.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: baseCurrency) } 
        })
        let topId = topEntry?.key
        let topName = topEntry?.value.first?.mainCategoryName ?? "-"
        
        self.totalIncome = income
        self.totalExpense = expense
        self.todaysProfit = profit
        self.topExpenseCategoryId = topId
        self.topExpenseCategoryName = topName
    }
    
    // MARK: - Wallet-agnostic: Tüm Cüzdanlar İçin Değerlendirme
    /// Uygulama ön plana geldiğinde (scenePhase = .active) tüm cüzdanları tara.
    /// Her cüzdanın tekrarlayan işlemlerini retroaktif catch-up ile günceller.
    /// UI thread'ini bloklamaz (background priority).
    func evaluateAllWalletsRecurring(walletIds: [String]) {
        guard !walletIds.isEmpty else { return }
        
        Task.detached(priority: .background) {
            for walletId in walletIds {
                guard !Task.isCancelled else { break }
                do {
                    // Orijinal tekrarlayan işlemleri çek (parentRecurringId alanı olmayan)
                    let snapshot = try await Firestore.firestore()
                        .collection("wallets").document(walletId)
                        .collection("transactions")
                        .whereField("isRecurring", isEqualTo: true)
                        .getDocuments()
                    
                    let allRecurring = await MainActor.run {
                        snapshot.documents.compactMap { try? $0.data(as: TransactionModel.self) }
                    }
                    let originals = allRecurring.filter { $0.parentRecurringId == nil }
                    guard !originals.isEmpty else { continue }
                    
                    // Mevcut kopyaları çek (duplicate önleme için)
                    let copiesSnapshot = try await Firestore.firestore()
                        .collection("wallets").document(walletId)
                        .collection("transactions")
                        .whereField("isRecurring", isEqualTo: false)
                        .getDocuments()
                    let existingCopies = await MainActor.run {
                        copiesSnapshot.documents.compactMap { try? $0.data(as: TransactionModel.self) }
                    }
                    .filter { $0.parentRecurringId != nil }
                    
                    await Self.processRecurringOriginals(originals, existingCopies: existingCopies, walletId: walletId)
                } catch {
                    print("evaluateAllWalletsRecurring error for wallet \(walletId): \(error)")
                }
            }
        }
    }
    
    // MARK: - Aktif Cüzdan İçin Değerlendirme (Snapshot listener'dan tetiklenir)
    private func evaluateRecurringTransactions(_ parsed: [TransactionModel], walletId: String) {
        guard !isEvaluatingRecurring else { return }
        isEvaluatingRecurring = true
        
        // Orijinal tekrarlayan işlemler: parentRecurringId nil ise orijinaldir
        let originals = parsed.filter { $0.isRecurring && !$0.isRecurringCopy }
        guard !originals.isEmpty else {
            isEvaluatingRecurring = false
            return
        }
        
        let existingCopies = parsed.filter { $0.isRecurringCopy }
        
        recurringTask?.cancel()
        recurringTask = Task {
            defer {
                Task { @MainActor in
                    self.isEvaluatingRecurring = false
                    self.recurringTask = nil
                }
            }
            await Self.processRecurringOriginals(originals, existingCopies: existingCopies, walletId: walletId)
        }
    }
    
    // MARK: - Retroaktif Catch-Up Motoru
    /// Orijinal tekrarlayan işlemleri işler, eksik kopyaları üretir.
    ///
    /// Davranış:
    /// - Orijinal işlem HİÇ DEĞİŞTİRİLMEZ (isRecurring=true olarak kalır, o dönemin kaydıdır).
    /// - Kopyalar orijinal tarihinden 1 dönem SONRADAN başlar (örn. Şubat 15 → Mart 15, Nisan 15...).
    /// - Sadece tarihi bugünden geçmiş kopyalar üretilir (retroaktif catch-up, ileriye yazma yok).
    /// - Her kopya parentRecurringId ile orijinaline bağlıdır → "Ana İşleme Git" özelliği için.
    /// - lastGeneratedDate sayesinde sadece eksik olan dönemler işlenir → Firestore'a hafif yük.
    private static func processRecurringOriginals(
        _ originals: [TransactionModel],
        existingCopies: [TransactionModel],
        walletId: String
    ) async {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        // Mevcut kopya imza seti: "parentRecurringId|dayTimestamp"
        var existingSignatures = Set<String>(
            existingCopies.compactMap { copy -> String? in
                guard let pid = copy.parentRecurringId else { return nil }
                let dayStart = calendar.startOfDay(for: copy.date)
                return "\(pid)|\(dayStart.timeIntervalSince1970)"
            }
        )
        
        for tx in originals {
            guard !Task.isCancelled else { break }
            guard let txId = tx.id else { continue }
            
            let value: Int = 1
            let component: Calendar.Component
            switch tx.recurrenceInterval ?? .monthly {
            case .daily:   component = .day
            case .weekly:  component = .weekOfYear
            case .monthly: component = .month
            case .yearly:  component = .year
            }
            
            // Başlangıç noktası: lastGeneratedDate varsa oradan devam et;
            // yoksa orijinal tarihinden başla (ilk kopya = orijinal + 1 interval).
            let baseDate = tx.lastGeneratedDate ?? tx.date
            guard var nextCopyDate = calendar.date(byAdding: component, value: value, to: baseDate) else {
                continue
            }
            
            var newLastGeneratedDate: Date? = nil
            var safetyCounter = 0
            
            // Sadece geçmiş dönemleri üret
            while nextCopyDate <= startOfToday && safetyCounter < 500 {
                guard !Task.isCancelled else { break }
                safetyCounter += 1
                
                // Bitiş tarihi kontrolü
                if let endDate = tx.recurrenceEndDate, nextCopyDate > endDate { break }
                
                let dayStart = calendar.startOfDay(for: nextCopyDate)
                let signature = "\(txId)|\(dayStart.timeIntervalSince1970)"
                
                if !existingSignatures.contains(signature) {
                    var copy = tx
                    copy.id = nil                    // Firestore yeni ID atar
                    copy.date = nextCopyDate
                    copy.isRecurring = false         // Kopya tekrarlayan değil
                    copy.parentRecurringId = txId    // Orijinale bağla
                    copy.lastGeneratedDate = nil     // Sadece orijinalde tutulur
                    copy.recurrenceInterval = nil
                    copy.recurrenceEndDate = nil
                    
                    do {
                        try FirestoreService.shared.createTransaction(copy)
                        existingSignatures.insert(signature)
                        newLastGeneratedDate = nextCopyDate
                    } catch {
                        print("Recurring copy create error: \(error)")
                    }
                } else {
                    // Zaten var, ilerleme kaydedilsin
                    newLastGeneratedDate = nextCopyDate
                }
                
                guard let next = calendar.date(byAdding: component, value: value, to: nextCopyDate) else { break }
                nextCopyDate = next
            }
            
            // Orijinal işlemin lastGeneratedDate'ini güncelle (sadece ilerleme olduysa)
            if let newDate = newLastGeneratedDate, newDate != tx.lastGeneratedDate {
                var updatedOriginal = tx
                updatedOriginal.lastGeneratedDate = newDate
                try? FirestoreService.shared.updateTransaction(updatedOriginal)
            }
        }
    }
    
    // MARK: - Borç Ödeme Operasyonu
    @MainActor func payDebtInstallment(for debtTransaction: TransactionModel, currentUsername: String) async throws {
        guard let total = debtTransaction.totalInstallments,
              let paid = debtTransaction.paidInstallments,
              paid < total else { return }
        
        let currentInstallmentNum = paid + 1
        let installmentAmount = debtTransaction.amount / Double(total)
        
        let isLendingMoney = (debtTransaction.type == .expense && debtTransaction.mainCategoryName.lowercased().contains("borç"))
        let newTxType: TransactionType = isLendingMoney ? .income : .expense
        
        let displayTitle = debtTransaction.subCategoryName ?? debtTransaction.mainCategoryName
        
        let newInstallment = TransactionModel(
            walletId: debtTransaction.walletId,
            type: newTxType,
            amount: installmentAmount,
            currency: debtTransaction.currency,
            mainCategoryName: displayTitle,
            mainCategoryId: nil,
            subCategoryName: "\(currentInstallmentNum). Taksit",
            subCategoryId: nil,
            categoryIcon: debtTransaction.categoryIcon,
            categoryColor: debtTransaction.categoryColor,
            date: Date(),
            note: debtTransaction.note,
            createdBy: currentUsername,
            createdAt: Date(),
            isDebt: false,
            debtContact: debtTransaction.debtContact,
            totalInstallments: debtTransaction.totalInstallments,
            paidInstallments: currentInstallmentNum,
            isPaid: true,
            parentDebtId: debtTransaction.id,
            installmentNumber: currentInstallmentNum
        )
        
        var updatedDebt = debtTransaction
        updatedDebt.paidInstallments = currentInstallmentNum
        if updatedDebt.paidInstallments == total {
            updatedDebt.isPaid = true
        }
        
        let debtToSave = updatedDebt
        async let step1: Void = FirestoreService.shared.createTransaction(newInstallment)
        async let step2: Void = FirestoreService.shared.updateTransaction(debtToSave)
        _ = try await (step1, step2)
    }
    
    // MARK: - Deletion Impact Assessment
    func getImpact(mainCategoryId: String, subCategoryId: String? = nil) -> (transactionCount: Int, recurringCount: Int) {
        let filtered: [TransactionModel]
        if let subId = subCategoryId {
            filtered = transactions.filter { $0.mainCategoryId == mainCategoryId && $0.subCategoryId == subId }
        } else {
            filtered = transactions.filter { $0.mainCategoryId == mainCategoryId }
        }
        let txCount = filtered.count
        let recurringCount = filtered.filter { $0.isRecurring }.count
        return (txCount, recurringCount)
    }
}

