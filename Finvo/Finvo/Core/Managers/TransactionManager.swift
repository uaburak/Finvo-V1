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
                
                // Swift 6 hatasını önlemek için Main Actor üzerinde çalıştır (Parsing MainActor-isolated olabilir)
                Task {
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
                    
                    // Verileri güncelle
                    self.transactions = parsed
                    self.totalIncome = income
                    self.totalExpense = expense
                    self.todaysProfit = profit
                    self.topExpenseCategoryId = topId
                    self.topExpenseCategoryName = topName
                    self.hasLoaded = true
                    
                    self.evaluateRecurringTransactions(parsed)
                }
            }
    }
    
    func stopListening() {
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
    
    private func evaluateRecurringTransactions(_ parsed: [TransactionModel]) {
        guard !isEvaluatingRecurring else { return }
        
        let now = Date()
        let calendar = Calendar.current
        // Bugünün başlangıcı — bugün oluşturulan tekrarlayan işlemler henüz vadesi gelmemiş sayılır
        let startOfToday = calendar.startOfDay(for: now)
        let dueTransactions = parsed.filter { $0.isRecurring && $0.date < startOfToday }
        
        guard !dueTransactions.isEmpty else { return }
        
        isEvaluatingRecurring = true
        
        Task {
            for tx in dueTransactions {
                let currentTx = tx
                
                let value: Int
                let component: Calendar.Component
                switch currentTx.recurrenceInterval ?? .monthly {
                case .daily: value = 1; component = .day
                case .weekly: value = 1; component = .weekOfYear
                case .monthly: value = 1; component = .month
                case .yearly: value = 1; component = .year
                }
                
                guard let nextDate = calendar.date(byAdding: component, value: value, to: currentTx.date) else { continue }
                
                if let end = currentTx.recurrenceEndDate, nextDate > end {
                    var finishedTx = currentTx
                    finishedTx.isRecurring = false
                    try? FirestoreService.shared.updateTransaction(finishedTx)
                    continue
                }
                
                var oldTx = currentTx
                oldTx.isRecurring = false
                try? FirestoreService.shared.updateTransaction(oldTx)
                
                var nextTx = currentTx
                nextTx.id = nil
                nextTx.date = nextDate
                nextTx.createdAt = Date()
                
                try? FirestoreService.shared.createTransaction(nextTx)
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.isEvaluatingRecurring = false
            }
        }
    }
    
    // Borç ödeme operasyonu
    func payDebtInstallment(for debtTransaction: TransactionModel, currentUsername: String) async throws {
        guard debtTransaction.isDebt, let total = debtTransaction.totalInstallments, let paid = debtTransaction.paidInstallments, paid < total else {
            throw NSError(domain: "TransactionManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geçersiz borç işlemi veya borç zaten kapalı."])
        }
        
        let installmentAmount = debtTransaction.amount / Double(total)
        
        // Eğer ben KREDİ aldıysam (Orijinal type: Income), taksit ödemek benim için GİDER'dir.
        // Eğer ben televizyon aldıysam taksitli (Orijinal type: Expense), taksit ödemek yine GİDER'dir. (Alışveriş kredisi)
        // Eğer ben arkadaşıma borç VERDİYSEM (Orijinal type: Expense, mainCategory: Borç), bana o parayı GERİ ÖEDİYORSA bu benim için GELİR'dir.
        // Finvo yapısında genel kullanım olarak: Kredi ödemesi de, Alışveriş ödemesi de çoğunlukla "Gider" oluşturur.
        // Sadece "Verilen Borcun Geri Alınması" gelirdir. O yüzden isimden / nota bakmak gerekebilir, ancak
        // basitçe: Eğer type == .expense ise (Birine para verdin / Mal aldın), bu ödemeyi "Gider" olarak basmak alışverişte mantıklıdır, 
        // ancak arkadaşından para geliyorsa "Gelir" basılmalıdır.
        // En sağlam yöntem: original type ne olursa olsun taksit ödemesini "Gider" yazmak TV vs için doğrudur ama 
        // kullanıcı "Verdiğim Borcu Geri Aldım" diyebilmelidir. Finvo V1'de borç sistemi "Finansal Giderler"e sabitlenmiş.
        // Biz bunu daha esnek yapmak için: Eğer kategori "Borç & Kredi" ise ve type Expense ise (Borç Verdim), geri ödeme Income'dır.
        
        let isLendingMoney = (debtTransaction.type == .expense && debtTransaction.mainCategoryName.lowercased().contains("borç"))
        
        let newTxType: TransactionType = isLendingMoney ? .income : .expense
        let newMainCategory = isLendingMoney ? "Diğer Gelirler" : "Finansal Giderler"
        let newSubCategory = isLendingMoney ? "Borç Tahsilatı" : "Borç Ödemesi"
        let newColor = isLendingMoney ? "green" : "red"
        
        // 1. Yeni bir taksit işlemi yarat
        let newInstallment = TransactionModel(
            walletId: debtTransaction.walletId,
            type: newTxType,
            amount: installmentAmount,
            mainCategoryName: newMainCategory,
            subCategoryName: newSubCategory,
            categoryIcon: "arrow.right.arrow.left.circle.fill",
            categoryColor: newColor,
            date: Date(),
            note: "\(debtTransaction.debtContact ?? "Bilinmeyen Kişi") için \(paid + 1). Taksit İşlemi",
            createdBy: currentUsername,
            createdAt: Date(),
            isDebt: false
        )
        
        // 2. Kök borç işleminin taksitini +1 artır ve isPaid kontrolü yap
        var updatedDebt = debtTransaction
        updatedDebt.paidInstallments = paid + 1
        if updatedDebt.paidInstallments == total {
            updatedDebt.isPaid = true
        }
        
        // 3. İki işlemi de Firestore'a yaz
        let debtToSave = updatedDebt
        async let step1: Void = FirestoreService.shared.createTransaction(newInstallment)
        async let step2: Void = FirestoreService.shared.updateTransaction(debtToSave)
        
        _ = try await (step1, step2)
    }
    
    // Deletion Impact Assessment
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
