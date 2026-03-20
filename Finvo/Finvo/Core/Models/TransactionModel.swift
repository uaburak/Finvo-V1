import Foundation
import FirebaseFirestore

enum RecurrenceInterval: String, Codable, CaseIterable {
    case daily = "Günlük"
    case weekly = "Haftalık"
    case monthly = "Aylık"
    case yearly = "Yıllık"
}

struct TransactionModel: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var walletId: String
    var type: TransactionType
    var amount: Double
    var mainCategoryName: String
    var subCategoryName: String?
    var categoryIcon: String
    var categoryColor: String? // Optional hex or standard color name
    var date: Date
    var note: String?
    var createdBy: String // username
    var createdAt: Date
    
    // MARK: - Borç / Alacak (Debt)
    var isDebt: Bool = false
    var debtContact: String?
    var totalInstallments: Int?
    var paidInstallments: Int?
    var dueDay: Int?
    var isPaid: Bool = false
    
    // MARK: - Tekrarlayan (Recurring)
    var isRecurring: Bool = false
    var recurrenceInterval: RecurrenceInterval?
    var recurrenceEndDate: Date?
    
    var isIncome: Bool {
        return type == .income
    }
}
