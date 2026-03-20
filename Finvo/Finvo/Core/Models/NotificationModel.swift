import Foundation
import FirebaseFirestore

enum NotificationType: String, Codable {
    case roleRequest = "role_request"
    case system = "system"
}

enum NotificationStatus: String, Codable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}

struct NotificationModel: Identifiable, Codable {
    @DocumentID var id: String?
    var type: NotificationType
    var senderUsername: String
    var receiverUsername: String
    var walletId: String
    var walletName: String
    var status: NotificationStatus
    var createdAt: Date
}
