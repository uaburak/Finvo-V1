import Foundation
import SwiftUI
import FirebaseFirestore

enum RecurrenceInterval: String, Codable, CaseIterable {
    case daily = "Günlük"
    case weekly = "Haftalık"
    case monthly = "Aylık"
    case yearly = "Yıllık"
}

struct TransactionModel: Codable, Identifiable, Equatable, Hashable {
    @DocumentID var id: String?
    var walletId: String
    var type: TransactionType
    var amount: Double
    var currency: CurrencyType? // Yeni eklenen
    var mainCategoryName: String
    var mainCategoryId: String? // Stable ID for sync and cascade delete
    var subCategoryName: String?
    var subCategoryId: String? // Stable ID for sync and cascade delete
    var categoryIcon: String
    var categoryColor: String? // Optional hex or standard color name
    var date: Date
    var note: String?
    var createdBy: String // username
    var createdAt: Date
    
    // Varlık Takibi (Savings/Investments)
    var appCurrencyAmountAtCreation: Double?
    
    // MARK: - Borç / Alacak (Debt)
    var isDebt: Bool = false
    var debtContact: String?
    var totalInstallments: Int?
    var paidInstallments: Int?
    var dueDay: Int?
    var isPaid: Bool = false
    var parentDebtId: String? // Orijinal borcun ID'si
    var installmentNumber: Int? // Kaçıncı taksit
    
    var isInstallment: Bool {
        return parentDebtId != nil
    }
    
    // MARK: - Tekrarlayan (Recurring)
    var isRecurring: Bool = false
    var recurrenceInterval: RecurrenceInterval?
    var recurrenceEndDate: Date?
    
    var isIncome: Bool {
        return type == .income
    }
    
    var resolvedMainCategoryName: String {
        let category = CategoryManager.shared.categories.first(where: { $0.id == mainCategoryId }) ?? 
                       CategoryManager.shared.categories.first(where: { $0.name == mainCategoryName })
        return category?.name ?? mainCategoryName
    }
    
    var resolvedSubCategoryName: String? {
        let category = CategoryManager.shared.categories.first(where: { $0.id == mainCategoryId }) ?? 
                       CategoryManager.shared.categories.first(where: { $0.name == mainCategoryName })
        if let subId = subCategoryId, let sub = category?.subCategories.first(where: { $0.id == subId }) {
            return sub.name
        }
        return subCategoryName
    }
    
    // SwiftUI Color resolution
    func resolvedColor() -> Color {
        // Dinamik kontrol: CategoryManager'dan güncel rengi çekmeye çalış (Önce ID ile, sonra isimle)
        let category = CategoryManager.shared.categories.first(where: { $0.id == mainCategoryId }) ?? 
                       CategoryManager.shared.categories.first(where: { $0.name == mainCategoryName })
        
        if let category = category {
            if let subId = subCategoryId, let sub = category.subCategories.first(where: { $0.id == subId }) {
                return sub.uiColor
            }
            if let subName = subCategoryName, let sub = category.subCategories.first(where: { $0.name == subName }) {
                return sub.uiColor
            }
            return category.uiColor
        }
        
        // Bulunamazsa (veya Mock data ise) kayıtlı rengi kullan
        guard let colorStr = categoryColor else { return .blue }
        if colorStr.hasPrefix("#") {
            return Color(hex: colorStr)
        }
        
        switch colorStr.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "mint": return .mint
        case "pink": return .pink
        case "teal": return .teal
        case "indigo": return .indigo
        case "brown": return .brown
        case "cyan": return .cyan
        case "yellow": return .yellow
        case "gray": return .gray
        case "black": return .black
        default: return .blue
        }
    }
    
    // SwiftUI Icon resolution
    var resolvedIcon: String {
        let category = CategoryManager.shared.categories.first(where: { $0.id == mainCategoryId }) ?? 
                       CategoryManager.shared.categories.first(where: { $0.name == mainCategoryName })

        if let category = category {
            if let subId = subCategoryId, let sub = category.subCategories.first(where: { $0.id == subId }) {
                return sub.icon
            }
            if let subName = subCategoryName, let sub = category.subCategories.first(where: { $0.name == subName }) {
                return sub.icon
            }
            return category.icon
        }
        return categoryIcon
    }
    
    // Manual Hashable & Equatable to ensure complete data dependency coverage
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(walletId)
        hasher.combine(type)
        hasher.combine(amount)
        hasher.combine(currency)
        hasher.combine(mainCategoryId)
        hasher.combine(subCategoryId)
        hasher.combine(mainCategoryName)
        hasher.combine(subCategoryName)
        hasher.combine(categoryIcon)
        hasher.combine(categoryColor)
        hasher.combine(date)
        hasher.combine(note)
        hasher.combine(createdBy)
        hasher.combine(isDebt)
        hasher.combine(isRecurring)
        hasher.combine(isPaid)
        hasher.combine(appCurrencyAmountAtCreation)
    }

    static func == (lhs: TransactionModel, rhs: TransactionModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.walletId == rhs.walletId &&
               lhs.type == rhs.type &&
               lhs.amount == rhs.amount &&
               lhs.currency == rhs.currency &&
               lhs.mainCategoryId == rhs.mainCategoryId &&
               lhs.subCategoryId == rhs.subCategoryId &&
               lhs.mainCategoryName == rhs.mainCategoryName &&
               lhs.subCategoryName == rhs.subCategoryName &&
               lhs.categoryIcon == rhs.categoryIcon &&
               lhs.categoryColor == rhs.categoryColor &&
               lhs.date == rhs.date &&
               lhs.note == rhs.note &&
               lhs.createdBy == rhs.createdBy &&
               lhs.isDebt == rhs.isDebt &&
               lhs.isRecurring == rhs.isRecurring &&
               lhs.isPaid == rhs.isPaid &&
               lhs.appCurrencyAmountAtCreation == rhs.appCurrencyAmountAtCreation
    }
}

extension TransactionModel {
    /// Orijinal işlemi analiz edip, yaklaşan bir sonraki ödeme (taksit veya abonelik) için
    /// sanal bir TransactionModel kopyası üretir. Eğer borç kapanmışsa veya abonelik süresi geçmişse nil döner.
    func nextPayment(after currentDate: Date = Date()) -> TransactionModel? {
        let calendar = Calendar.current
        var copy = self
        
        if isDebt {
            guard let total = totalInstallments, let paid = paidInstallments, paid < total else { return nil }
            
            // Gerçek taksit tutarını ata
            copy.amount = total > 0 ? (self.amount / Double(total)) : self.amount
            
            // Sonraki ödeme tarihi hesapla (Ay sonu güvenliği ile)
            let targetDay = self.dueDay ?? calendar.component(.day, from: self.date)
            
            // Mevcut ayın targetDay gününü oluştur
            var components = calendar.dateComponents([.year, .month], from: currentDate)
            components.day = targetDay
            
            // Eğer bu ayın ödeme günü geçtiyse veya bugünse, bir sonraki aya bak
            if let thisMonthPayment = calendar.date(from: components), thisMonthPayment <= currentDate {
                // date(byAdding: .month) ay sonu (28-31) problemlerini otomatik çözer
                if let nextMonth = calendar.date(byAdding: .month, value: 1, to: thisMonthPayment) {
                    copy.date = nextMonth
                }
            } else if let thisMonthPayment = calendar.date(from: components) {
                copy.date = thisMonthPayment
            }
            
            copy.note = "\(paid + 1). Taksit Ödemesi"
            return copy
        } 
        else if isRecurring {
            let value: Int
            let component: Calendar.Component
            
            switch recurrenceInterval ?? .monthly {
            case .daily: value = 1; component = .day
            case .weekly: value = 1; component = .weekOfYear
            case .monthly: value = 1; component = .month
            case .yearly: value = 1; component = .year
            }
            
            if self.date > currentDate {
                return self // It's already in the future, no need to add intervals yet.
            }
            
            var nextDate = self.date
            var safetyCounter = 0
            while nextDate <= currentDate && safetyCounter < 1000 {
                if let next = calendar.date(byAdding: component, value: value, to: nextDate) {
                    nextDate = next
                } else {
                    break
                }
                safetyCounter += 1
            }
            
            if let end = recurrenceEndDate, nextDate > end { return nil }
            copy.date = nextDate
            return copy
        }
        
        // Eğer standart düz bir işlem ileri bir tarihe atandıysa
        if self.date > currentDate && !isDebt && !isRecurring {
            return self
        }
        
        return nil
    }
}

