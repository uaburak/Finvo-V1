import Foundation
import FirebaseFirestore

struct MissionModel: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var walletId: String
    var title: String
    var rewardAmount: Double
    var isCompleted: Bool = false
    var isApproved: Bool = false // Approved by the assigner
    var assignedTo: String?  // username — görevi yapacak kişi (nil = herkes)
    var completedBy: String? // username — görevi fiilen tamamlayan kişi
    var createdBy: String    // username — görevi oluşturan kişi (ödülü ödeyen)
    var createdAt: Date = Date()
}
