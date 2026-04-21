import Foundation
import FirebaseFirestore

enum WalletType: String, Codable, CaseIterable {
    case personal = "personal"
    case shared = "shared"

    // xcstrings'deki Türkçe key. Görüntüde LocalizationManager üzerinden çevrilir.
    var titleKey: String {
        switch self {
        case .personal: return "Kişisel"
        case .shared: return "Paylaşımlı"
        }
    }

    var title: String { titleKey.localized }
}

enum WalletContext: String, Codable, CaseIterable {
    case general = "general"
    case business = "business"
    case savings = "savings"

    var titleKey: String {
        switch self {
        case .general: return "Genel Kullanım"
        case .business: return "İş / Ticari"
        case .savings: return "Birikim"
        }
    }

    var title: String { titleKey.localized }
}

enum WalletRole: String, Codable {
    case owner = "owner"
    case admin = "admin"     // Kurucu ile aynı yetkiler
    case member = "member"   // İşlem ekleme/silme (Sadece kendi işlemleri)
    case viewer = "viewer"   // Sadece okuma yetkisi
    case pending = "pending" // Davet bekleyen kullanıcı

    var displayNameKey: String {
        switch self {
        case .owner: return "Kurucu"
        case .admin: return "Yönetici"
        case .member: return "Üye"
        case .viewer: return "Görüntüleyici"
        case .pending: return "Davet Bekleniyor"
        }
    }

    var displayName: String { displayNameKey.localized }
}

struct SavingsAccountModel: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var name: String
    var goalAmount: Double
    var goalCurrency: String? // Hangi para biriminde hedefleniyor
    var currentAmount: Double = 0.0 // Geriye dönük uyumluluk veya son hesaplanan limit cache için.
    var assets: [String: Double]? // [CurrencyType.rawValue: Double] formatında
    var color: String // e.g. "blue", "green", "purple"
    var createdAt: Date = Date()
}

struct WalletModel: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var ownerId: String
    var type: WalletType
    var context: WalletContext
    var members: [String]
    var permissions: [String: String] // UID -> WalletRole (e.g. "owner")
    var monthlyLimit: Double?
    var monthlyLimitCurrency: String? // Limitin ana para birimi
    var savingsGoal: Double? // Eski tekil birikim hedefi (geriye dönük uyumluluk için tutulabilir)
    var savingsAccounts: [SavingsAccountModel]? // Yeni çoklu birikim hesapları listesi
}

