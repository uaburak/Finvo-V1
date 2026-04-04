import Foundation
import FirebaseFirestore

struct MissionModel: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var walletId: String
    var title: String
    var rewardAmount: Double
    var isCompleted: Bool = false
    var isApproved: Bool = false // Approved by the assigner
    var assignedTo: String? // username
    var createdBy: String // username
    var createdAt: Date = Date()
}
