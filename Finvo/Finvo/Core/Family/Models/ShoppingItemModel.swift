import Foundation
import FirebaseFirestore

struct ShoppingItemModel: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var walletId: String
    var title: String
    var estimatedAmount: Double?
    var isPurchased: Bool = false
    var addedBy: String // username
    var createdAt: Date = Date()
}
