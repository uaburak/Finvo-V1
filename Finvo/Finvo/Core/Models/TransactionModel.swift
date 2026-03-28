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
    
    // SwiftUI Color resolution
    var resolvedColor: Color {
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
    
    // Manual Hashable & Equatable to ensure compiler satisfaction
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(walletId)
        hasher.combine(type)
        hasher.combine(amount)
        hasher.combine(date)
        hasher.combine(createdBy)
    }

    static func == (lhs: TransactionModel, rhs: TransactionModel) -> Bool {
        return lhs.id == rhs.id &&
               lhs.walletId == rhs.walletId &&
               lhs.type == rhs.type &&
               lhs.amount == rhs.amount &&
               lhs.date == rhs.date &&
               lhs.createdBy == rhs.createdBy
    }
}

extension TransactionModel {
    /// Orijinal işlemi analiz edip, yaklaşan bir sonraki ödeme (taksit veya abonelik) için
    /// sanal bir TransactionModel kopyası üretir. Eğer borç kapanmışsa veya abonelik süresi geçmişse nil döner.
    func nextPayment(after currentDate: Date = Date()) -> TransactionModel? {
        let calendar = Calendar.current
        var copy = self
        
        let currentDay = calendar.component(.day, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        if isDebt {
            guard let total = totalInstallments, let paid = paidInstallments, paid < total else { return nil }
            
            // Gerçek taksit tutarını ata
            copy.amount = self.amount / Double(total)
            
            // Sonraki ödeme tarihi hesapla
            let targetDay = self.dueDay ?? calendar.component(.day, from: self.date)
            var components = DateComponents(year: currentYear, month: currentMonth, day: targetDay)
            
            if targetDay <= currentDay {
                components.month = currentMonth + 1 // Gelecek ay
            }
            if let nextDate = calendar.date(from: components) {
                copy.date = nextDate
                copy.note = "\(paid + 1). Taksit Ödemesi"
                return copy
            }
        } 
        else if isRecurring {
            let targetDay = calendar.component(.day, from: self.date)
            var components = DateComponents(year: currentYear, month: currentMonth, day: targetDay)
            
            if targetDay <= currentDay {
                components.month = currentMonth + 1
            }
            if let nextDate = calendar.date(from: components) {
                if let end = recurrenceEndDate, nextDate > end { return nil }
                copy.date = nextDate
                return copy
            }
        }
        
        // Eğer standart düz bir işlem ileri bir tarihe atandıysa
        if self.date > currentDate && !isDebt && !isRecurring {
            return self
        }
        
        return nil
    }
}

