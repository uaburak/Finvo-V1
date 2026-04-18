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
                
                // Çoğaltma işlemindeki kök tarihi (gerçek zincir başlangıcını) koruyalım
                let trueStartDate = min(currentTx.createdAt, currentTx.date)
                
                // Mevcut (geçmişte kalmış) işlemi kapatıyoruz
                var originalTx = currentTx
                originalTx.isRecurring = false
                try? FirestoreService.shared.updateTransaction(originalTx)
                
                var generatingDate = currentTx.date
                var safetyCounter = 0
                
                while generatingDate < startOfToday && safetyCounter < 500 {
                    safetyCounter += 1
                    guard let nextDate = calendar.date(byAdding: component, value: value, to: generatingDate) else { break }
                    
                    if let end = currentTx.recurrenceEndDate, nextDate > end {
                        break
                    }
                    
                    var newTx = currentTx
                    newTx.id = nil
                    newTx.date = nextDate
                    newTx.createdAt = trueStartDate // Zincirin başını işaret ediyoruz
                    
                    if nextDate < startOfToday {
                        newTx.isRecurring = false
                    } else {
                        newTx.isRecurring = true
                    }
                    
                    try? FirestoreService.shared.createTransaction(newTx)
                    
                    generatingDate = nextDate
                    
                    if nextDate >= startOfToday {
                        break
                    }
                }
            }
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await MainActor.run {
                self.isEvaluatingRecurring = false
            }
        }
    }
    
    // Borç ödeme operasyonu
    @MainActor func payDebtInstallment(for debtTransaction: TransactionModel, currentUsername: String) async throws {
        guard let total = debtTransaction.totalInstallments, let paid = debtTransaction.paidInstallments, paid < total else { return }
        
        let currentInstallmentNum = paid + 1
        let installmentAmount = debtTransaction.amount / Double(total)
        
        // Mantık: Borç ilk oluşturulduğunda kullanılan kategori ve ikonları aynen koruyoruz.
        // Ama tipini (Income/Expense) duruma göre belirliyoruz.
        let isLendingMoney = (debtTransaction.type == .expense && debtTransaction.mainCategoryName.lowercased().contains("borç"))
        let newTxType: TransactionType = isLendingMoney ? .income : .expense
        
        // 1. Yeni bir taksit işlemi yarat (Daha zengin veriyle)
        // Kullanıcı isteği: Ana kategori değil alt kategori adıyla oluşsun (Başlık alt kategori olsun)
        let displayTitle = debtTransaction.subCategoryName ?? debtTransaction.mainCategoryName
        
        let newInstallment = TransactionModel(
            walletId: debtTransaction.walletId,
            type: newTxType,
            amount: installmentAmount,
            currency: debtTransaction.currency, // Dövizini koru
            mainCategoryName: displayTitle,
            mainCategoryId: nil, // Root kategori adının (örn: Konut) başlığı ezmemesi için nil veriyoruz
            subCategoryName: "\(currentInstallmentNum). Taksit",
            subCategoryId: nil, // Subtitle kısmına taksit bilgisini yazdığımız için ID boşa çıkıyor
            categoryIcon: debtTransaction.categoryIcon,
            categoryColor: debtTransaction.categoryColor,
            date: Date(),
            note: debtTransaction.note, // Orijinal notu koru
            createdBy: currentUsername,
            createdAt: Date(),
            isDebt: false, // Bu bir borç değil, borcun taksit ödemesi
            debtContact: debtTransaction.debtContact,
            totalInstallments: debtTransaction.totalInstallments,
            paidInstallments: currentInstallmentNum, // Kaçıncı taksit ödendi bilgisini snapshot olarak tut
            isPaid: true, // Taksit işleminin kendisi "Ödendi" durumundadır
            parentDebtId: debtTransaction.id,
            installmentNumber: currentInstallmentNum
        )
        
        // 2. Kök borç işleminin taksitini +1 artır ve isPaid kontrolü yap
        var updatedDebt = debtTransaction
        updatedDebt.paidInstallments = currentInstallmentNum
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
