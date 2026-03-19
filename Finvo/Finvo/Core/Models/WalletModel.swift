import Foundation

enum WalletType: String, Codable, CaseIterable {
    case personal = "personal"
    case shared = "shared"
    
    var title: String {
        switch self {
        case .personal: return "Kişisel"
        case .shared: return "Paylaşımlı"
        }
    }
}

enum WalletContext: String, Codable, CaseIterable {
    case general = "general"
    case business = "business"
    case savings = "savings"
    
    var title: String {
        switch self {
        case .general: return "Genel Kullanım"
        case .business: return "İş / Ticari"
        case .savings: return "Birikim"
        }
    }
}

enum WalletRole: String, Codable {
    case owner = "owner"
    case member = "member"   // İşlem ekleme/silme yetkisi
    case viewer = "viewer"   // Sadece okuma yetkisi
}

struct WalletModel: Identifiable, Codable, Equatable {
    var id: String? // Firestore entegrasyonunda @DocumentID olacak
    var name: String
    var ownerId: String
    var type: WalletType
    var context: WalletContext
    var members: [String]
    var permissions: [String: String] // UID -> WalletRole (e.g. "owner")
    var monthlyLimit: Double?
    var savingsGoal: Double?
    
    // Geçici Mock Fonksiyonu (Firestore öncesi UI testleri için)
    static func createEmpty() -> WalletModel {
        WalletModel(
            id: UUID().uuidString,
            name: "",
            ownerId: "current_user_id",
            type: .personal,
            context: .general,
            members: ["current_user_id"],
            permissions: ["current_user_id": WalletRole.owner.rawValue]
        )
    }
}
