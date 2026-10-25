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
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Kurlar ağdan geç gelir; ilk hesaplama varsayılan (eski) kurlarla yapıldığı için
        // kurlar güncellenince toplamları yeniden hesapla.
        ExchangeRateManager.shared.$rates
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.hasLoaded else { return }
                self.recalculateTotals(for: Self.appCurrency)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Task iptal mekanizması (Bug #1 fix)
    private var recurringTask: Task<Void, Never>?
    @MainActor private static var generatedSignatures = Set<String>()
    
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
                    // Cüzdan değiştiyse eski listener'dan geç gelen snapshot'ı yok say
                    guard self.currentWalletId == walletId else { return }
                    let parsed = documents.compactMap { try? $0.data(as: TransactionModel.self) }
                    
                    self.transactions = parsed
                    self.recalculateTotals(for: Self.appCurrency)
                    self.hasLoaded = true
                    
                    self.evaluateRecurringTransactions(parsed, walletId: walletId)
                    LocalNotificationManager.shared.scheduleNotifications(for: parsed)
                    SpendingLimitMonitor.evaluate(transactions: parsed, walletId: walletId)
                }
            }
    }
    
    private static var appCurrency: CurrencyType {
        UserDefaults.standard.string(forKey: "appCurrency").flatMap { CurrencyType(rawValue: $0) } ?? .tryCurrency
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
        todaysProfit = 0
        topExpenseCategoryId = nil
        topExpenseCategoryName = "-"
        
        // Clear notifications on stop
        LocalNotificationManager.shared.scheduleNotifications(for: [])
    }
    
    @MainActor func recalculateTotals(for currency: CurrencyType) {
        let rates = ExchangeRateManager.shared
        let calendar = Calendar.current
        let today = Date()
        
        var income = 0.0
        var expense = 0.0
        var todayIncome = 0.0
        var todayExpense = 0.0
        var expenseByCategory: [String: (total: Double, name: String)] = [:]
        
        // Tek geçişte tüm toplamlar (eskiden aynı liste 6+ kez filtrelenip dönüştürülüyordu)
        for tx in transactions where !tx.isDebt {
            let converted = rates.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: currency)
            let isToday = calendar.isDate(tx.date, inSameDayAs: today)
            switch tx.type {
            case .income:
                income += converted
                if isToday { todayIncome += converted }
            case .expense:
                expense += converted
                if isToday { todayExpense += converted }
                let key = tx.mainCategoryId ?? tx.mainCategoryName
                let current = expenseByCategory[key]
                expenseByCategory[key] = ((current?.total ?? 0) + converted, current?.name ?? tx.mainCategoryName)
            }
        }
        
        let topEntry = expenseByCategory.max(by: { $0.value.total < $1.value.total })
        
        self.totalIncome = income
        self.totalExpense = expense
        self.todaysProfit = todayIncome - todayExpense
        self.topExpenseCategoryId = topEntry?.key
        self.topExpenseCategoryName = topEntry?.value.name ?? "-"
    }
    
    // MARK: - Wallet-agnostic: Tüm Cüzdanlar İçin Değerlendirme
    /// Uygulama ön plana geldiğinde (scenePhase = .active) tüm cüzdanları tara.
    /// Her cüzdanın tekrarlayan işlemlerini retroaktif catch-up ile günceller.
    /// UI thread'ini bloklamaz (background priority).
    func evaluateAllWalletsRecurring(walletIds: [String]) {
        // Aktif cüzdan zaten canlı dinleniyor ve snapshot geldikçe değerlendiriliyor; tekrar sorgulamaya gerek yok.
        // Kopyalar en fazla günde bir üretildiği için her cüzdanı günde bir kez taramak yeterli.
        // (Eskiden uygulama her ön plana geldiğinde her cüzdanın TÜM işlemleri okunuyordu.)
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let defaults = UserDefaults.standard
        let pending = walletIds.filter { walletId in
            walletId != currentWalletId &&
            defaults.double(forKey: "recurringEvaluatedAt_\(walletId)") < today
        }
        guard !pending.isEmpty else { return }
        
        Task.detached(priority: .background) {
            for walletId in pending {
                guard !Task.isCancelled else { break }
                do {
                    // Sadece orijinal tekrarlayan işlemleri çek. Kopyalar isRecurring=false olduğundan bu sorguya girmez.
                    let snapshot = try await Firestore.firestore()
                        .collection("wallets").document(walletId)
                        .collection("transactions")
                        .whereField("isRecurring", isEqualTo: true)
                        .getDocuments()
                    
                    let allRecurring = await MainActor.run {
                        snapshot.documents.compactMap { try? $0.data(as: TransactionModel.self) }
                    }
                    let originals = allRecurring.filter { $0.parentRecurringId == nil }
                    
                    // Mevcut kopyaları okumak yerine lastGeneratedDate + deterministik kopya ID'leri ile
                    // mükerrer kayıt önleniyor (aynı dönem iki kez yazılsa bile aynı dokümana yazılır).
                    if !originals.isEmpty {
                        // lastGeneratedDate alanı olmayan eski serilerin kopyaları rastgele ID'lerle üretilmiş
                        // olabilir; sadece bu seriler için mevcut kopyaları (seri bazında) oku.
                        var existingCopies: [TransactionModel] = []
                        for original in originals where original.lastGeneratedDate == nil {
                            guard let id = original.id else { continue }
                            let copies = try await Firestore.firestore()
                                .collection("wallets").document(walletId)
                                .collection("transactions")
                                .whereField("parentRecurringId", isEqualTo: id)
                                .getDocuments()
                            let parsedCopies = await MainActor.run {
                                copies.documents.compactMap { try? $0.data(as: TransactionModel.self) }
                            }
                            existingCopies.append(contentsOf: parsedCopies)
                        }
                        await Self.processRecurringOriginals(originals, existingCopies: existingCopies, walletId: walletId)
                    }
                    defaults.set(today, forKey: "recurringEvaluatedAt_\(walletId)")
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
    @MainActor
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
        
        let db = Firestore.firestore()
        var batch = db.batch()
        var batchCount = 0
        // Bu batch ile yazılmayı bekleyen imzalar. Commit başarısız olursa geri alınmalı,
        // aksi halde kopyalar "üretildi" sayılıp bu oturumda bir daha hiç oluşturulmaz.
        var pendingSignatures: [String] = []

        /// Batch'i commit eder ve sonucundan bağımsız olarak yeni bir batch'e geçer.
        /// (Eskiden hata durumunda batch sıfırlanmadığı için aynı başarısız batch büyüyerek
        /// tekrar tekrar commit edilmeye çalışılıyor ve 500 limitine takılıyordu.)
        func commitBatch() async {
            guard batchCount > 0 else { return }
            do {
                try await batch.commit()
            } catch {
                print("Error committing recurring batch: \(error)")
                for signature in pendingSignatures {
                    generatedSignatures.remove(signature)
                    existingSignatures.remove(signature)
                }
            }
            batch = db.batch()
            batchCount = 0
            pendingSignatures.removeAll()
        }

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
                
                if !existingSignatures.contains(signature) && !generatedSignatures.contains(signature) {
                    var copy = tx
                    copy.id = nil                    // Firestore yeni ID atar
                    copy.date = nextCopyDate
                    copy.isRecurring = false         // Kopya tekrarlayan değil
                    copy.parentRecurringId = txId    // Orijinale bağla
                    copy.lastGeneratedDate = nil     // Sadece orijinalde tutulur
                    copy.recurrenceInterval = nil
                    copy.recurrenceEndDate = nil
                    
                    // Deterministik ID: aynı dönem iki cihazdan / iki tetiklemeden üretilse bile
                    // tek dokümana yazılır, mükerrer kopya oluşmaz.
                    let docRef = db.collection("wallets").document(walletId).collection("transactions")
                        .document(Self.recurringCopyId(parentId: txId, date: dayStart, calendar: calendar))
                    do {
                        try batch.setData(from: copy, forDocument: docRef)
                        generatedSignatures.insert(signature)
                        existingSignatures.insert(signature)
                        pendingSignatures.append(signature)
                        newLastGeneratedDate = nextCopyDate
                        batchCount += 1
                    } catch {
                        print("Error adding copy to batch: \(error)")
                    }
                } else {
                    // Zaten var (veritabanında veya bellekte), ilerleme kaydedilsin
                    newLastGeneratedDate = nextCopyDate
                }

                // Eğer batch limiti dolmaya yakınsa commit et ve yeni batch oluştur (Firestore limiti 500'dür)
                if batchCount >= 450 {
                    await commitBatch()
                }

                guard let next = calendar.date(byAdding: component, value: value, to: nextCopyDate) else { break }
                nextCopyDate = next
            }
            
            // Orijinal işlemin lastGeneratedDate'ini güncelle (sadece ilerleme olduysa)
            if let newDate = newLastGeneratedDate, newDate != tx.lastGeneratedDate {
                // Sadece ilgili alanı güncelle; tüm dokümanı yeniden yazmak, bu arada başka bir
                // cihazda yapılmış düzenlemeleri eski değerlerle ezebiliyordu.
                let originalRef = db.collection("wallets").document(walletId).collection("transactions").document(txId)
                batch.updateData(["lastGeneratedDate": Timestamp(date: newDate)], forDocument: originalRef)
                batchCount += 1

                if batchCount >= 450 {
                    await commitBatch()
                }
            }
        }

        await commitBatch()
    }
    
    private static func recurringCopyId(parentId: String, date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%@_r%04d%02d%02d", parentId, c.year ?? 0, c.month ?? 0, c.day ?? 0)
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
        
        // Taksit kaydı ve borç güncellemesi tek batch'te: biri yazılıp diğeri yazılmazsa
        // taksit sayısı ile ödeme kayıtları birbirini tutmuyordu.
        guard let debtId = updatedDebt.id else { return }
        let transactionsRef = db.collection("wallets").document(debtTransaction.walletId).collection("transactions")
        let batch = db.batch()
        try batch.setData(from: newInstallment, forDocument: transactionsRef.document())
        try batch.setData(from: updatedDebt, forDocument: transactionsRef.document(debtId), merge: true)
        // Sunucu onayı beklenmez: çevrimdışıyken "Öde" butonu kilitli kalıyordu. Yazma yerelde anında uygulanır.
        batch.commit { error in
            if let error { print("Error paying installment: \(error)") }
        }
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

