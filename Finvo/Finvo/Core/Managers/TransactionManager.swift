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
    @Published var topExpenseCategory: String = "-"
    
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
                    self.topExpenseCategory = "-"
                    return
                }
                
                // Arkaplan Thread'inde (Detached) ağır parsing ve hesaplamaları yap
                Task.detached {
                    let parsed = documents.compactMap { try? $0.data(as: TransactionModel.self) }
                    
                    let income = parsed.filter { $0.type == .income && !$0.isDebt }.reduce(0) { $0 + $1.amount }
                    let expense = parsed.filter { $0.type == .expense && !$0.isDebt }.reduce(0) { $0 + $1.amount }
                    
                    let expenseDict = Dictionary(grouping: parsed.filter { $0.type == .expense }, by: { $0.mainCategoryName })
                    let topCat = expenseDict.max(by: { a, b in a.value.reduce(0) { $0 + $1.amount } < b.value.reduce(0) { $0 + $1.amount } })?.key ?? "-"
                    
                    // Sonuçları Main Thread'e (UI'a) yay!
                    await MainActor.run {
                        self.transactions = parsed
                        self.totalIncome = income
                        self.totalExpense = expense
                        self.topExpenseCategory = topCat
                        self.hasLoaded = true
                    }
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
        topExpenseCategory = "-"
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
}
