import Foundation
import SwiftUI
import FirebaseFirestore

// TransactionType, TransactionItemModel.swift'ten buraya taşındı (tek kullanılan kısımdı)
enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
    
    var localizedTitle: String {
        switch self {
        case .income: return "Gelir".localized
        case .expense: return "Gider".localized
        }
    }
}

enum RecurrenceInterval: String, Codable, CaseIterable {
    case daily = "Günlük"
    case weekly = "Haftalık"
    case monthly = "Aylık"
    case yearly = "Yıllık"

    // Firestore'da halihazırda Türkçe rawValue olarak kayıtlı olduğu için rawValue
    // değişmiyor. UI gösterimi için `title` üzerinden yerelleştirme yapılır.
    var title: String { rawValue.localized }
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
    /// Orijinal tekrarlayan işlemin son kopya üretim tarihi.
    /// Sadece orijinal işlemde tutulur; kopyalarda nil'dir.
    var lastGeneratedDate: Date?
    /// Bu kopyanın türetildiği orijinal işlemin Firestore ID'si.
    /// nil ise bu işlem orijinaldir.
    var parentRecurringId: String?

    /// true ise bu işlem bir tekrarlayan serinin kopyasıdır (orijinal değil).
    var isRecurringCopy: Bool {
        return parentRecurringId != nil
    }

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
    
    // Equatable/Hashable derleyici tarafından üretilir: elle yazılan sürüm paidInstallments,
    // dueDay, recurrenceEndDate gibi alanları atlıyordu; taksit ödemesi gibi değişiklikler
    // onChange(of: transactions) ve SwiftUI diff'lerinde fark edilmiyordu.
}

extension TransactionModel {
    /// Verilen ayın `day`. günü; ay daha kısaysa ayın son günü. Calendar.date(from:) taşan günü
    /// sonraki aya kaydırıyordu (31 Şubat -> 3 Mart) ve sonraki tüm taksitler kayıyordu.
    static func clampedMonthDate(monthOffset: Int, from base: Date, day: Int, calendar: Calendar = .current) -> Date? {
        guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: base) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: monthDate)
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components),
              let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count else { return nil }
        components.day = min(max(day, 1), daysInMonth)
        return calendar.date(from: components)
    }

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
            
            // Bu ayın ödeme günü geçtiyse (veya bugünse) bir sonraki ayın ödeme günü
            if let thisMonthPayment = Self.clampedMonthDate(monthOffset: 0, from: currentDate, day: targetDay, calendar: calendar) {
                if thisMonthPayment <= currentDate {
                    copy.date = Self.clampedMonthDate(monthOffset: 1, from: currentDate, day: targetDay, calendar: calendar) ?? thisMonthPayment
                } else {
                    copy.date = thisMonthPayment
                }
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
    
    /// Borç veya tekrarlayan işlemin tüm geçmiş ve gelecek dönemlerini sanal kopyalar olarak üretir.
    /// Geçmiş dönemler `isPaid = true`, gelecek dönemler `isPaid = false` olarak işaretlenir.
    func allPaymentOccurrences() -> [TransactionModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [TransactionModel] = []
        
        if isDebt {
            guard let total = totalInstallments, total > 1 else {
                var copy = self
                copy.id = "\(self.id ?? "debt")_occurrence"
                return [copy]
            }
            let paid = paidInstallments ?? 0
            let installmentAmount = self.amount / Double(total)
            let targetDay = self.dueDay ?? calendar.component(.day, from: self.date)
            
            // İlk taksit tarihini borcun oluşturulduğu aydan başlat
            guard Self.clampedMonthDate(monthOffset: 0, from: self.createdAt, day: targetDay, calendar: calendar) != nil else {
                var copy = self
                copy.id = "\(self.id ?? "debt")_occurrence"
                return [copy]
            }
            
            for i in 0..<total {
                var copy = self
                copy.amount = installmentAmount
                copy.installmentNumber = i + 1
                
                // Taksit tarihi: ilk tarihten i ay sonrası
                if let installmentDate = Self.clampedMonthDate(monthOffset: i, from: self.createdAt, day: targetDay, calendar: calendar) {
                    copy.date = installmentDate
                } else {
                    continue
                }
                
                // Ödenmiş taksitler
                copy.isPaid = (i < paid)
                copy.paidInstallments = paid
                copy.note = "\(i + 1). Taksit"
                
                // Benzersiz ID oluştur (SwiftUI ForEach için)
                copy.id = "\(self.id ?? "debt")_installment_\(i + 1)"
                
                results.append(copy)
            }
        } else if isRecurring {
            let component: Calendar.Component
            let value: Int = 1
            
            switch recurrenceInterval ?? .monthly {
            case .daily: component = .day
            case .weekly: component = .weekOfYear
            case .monthly: component = .month
            case .yearly: component = .year
            }
            
            // Başlangıç: işlemin kendi tarihi. Eskiden oluşturulma tarihine kadar geriye yürünüyordu;
            // ileri tarihli başlayan bir seri için başlangıçtan önce hayalet ödemeler üretiliyordu.
            let startDate = calendar.startOfDay(for: self.date)
            
            // Bitiş sınırı: recurrenceEndDate varsa o, yoksa bugünden 1 yıl sonrası
            let maxFuture = calendar.date(byAdding: .year, value: 1, to: today) ?? today
            let endLimit: Date
            if let endDate = recurrenceEndDate {
                endLimit = min(endDate, maxFuture)
            } else {
                endLimit = maxFuture
            }
            
            var currentDate = startDate
            var occurrenceIndex = 1
            let maxIterations = 500 // Güvenlik sınırı
            
            while currentDate <= endLimit && occurrenceIndex <= maxIterations {
                var copy = self
                copy.date = currentDate
                copy.installmentNumber = occurrenceIndex
                copy.note = "\(occurrenceIndex). Ödeme"
                
                // Geçmiş mi gelecek mi?
                copy.isPaid = currentDate < today
                
                // Benzersiz ID
                copy.id = "\(self.id ?? "recurring")_occurrence_\(occurrenceIndex)"
                
                results.append(copy)
                
                // Sonraki dönem
                guard let next = calendar.date(byAdding: component, value: value, to: currentDate) else { break }
                currentDate = next
                occurrenceIndex += 1
            }
        }
        
        return results
    }
}

