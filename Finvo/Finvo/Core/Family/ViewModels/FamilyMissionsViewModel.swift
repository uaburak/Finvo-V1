import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

@MainActor
class FamilyMissionsViewModel: ObservableObject {
    @Published var missions: [MissionModel] = []
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentWalletId: String?

    // MARK: - Computed Properties
    /// Devam eden: Tamamlanmamış görevler
    var pendingMissions: [MissionModel]   { missions.filter { !$0.isCompleted && !$0.isApproved } }
    /// Tamamlanan: Biten ama henüz ödülü ödenmeyenler
    var completedMissions: [MissionModel] { missions.filter { $0.isCompleted && !$0.isApproved } }
    /// Ödülü Verildi: Hem biten hem onaylananlar
    var paidMissions: [MissionModel]      { missions.filter { $0.isApproved } }

    /// Toplam bekleyen iş yükü (Devam eden + Ödeme bekleyen)
    var pendingMissionsCount: Int { pendingMissions.count + completedMissions.count }
    var totalRewardGiven: Double  { paidMissions.reduce(0) { $0 + $1.rewardAmount } }

    // MARK: - Fetch (Real-time)
    func fetchMissions(for walletId: String) {
        guard walletId != currentWalletId else { return }
        currentWalletId = walletId
        listener?.remove()
        isLoading = true

        listener = db.collection("wallets")
            .document(walletId)
            .collection("missions")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                self.isLoading = false
                if let error { print("⭐️ Missions fetch error: \(error)"); return }
                self.missions = snapshot?.documents.compactMap {
                    try? $0.data(as: MissionModel.self)
                } ?? []
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        currentWalletId = nil
    }

    // MARK: - Write Operations
    func addMission(title: String, reward: Double, assignedTo: String?, walletId: String, createdBy: String) {
        let newMission = MissionModel(
            walletId: walletId,
            title: title,
            rewardAmount: reward,
            assignedTo: assignedTo,
            createdBy: createdBy
        )
        try? db.collection("wallets")
            .document(walletId)
            .collection("missions")
            .addDocument(from: newMission)
    }

    func toggleCompletion(for mission: MissionModel, by username: String) {
        guard let id = mission.id, let walletId = currentWalletId else { return }
        
        let newValue = !mission.isCompleted
        var updateData: [String: Any] = [
            "isCompleted": newValue
        ]
        
        if newValue {
            // Tamamlanınca kimin yaptığı kaydedilir
            updateData["completedBy"] = username
        } else {
            // Geri alınırsa silinir
            updateData["completedBy"] = FieldValue.delete()
        }
        
        db.collection("wallets")
            .document(walletId)
            .collection("missions")
            .document(id)
            .updateData(updateData)
    }

    func approveMission(for mission: MissionModel) {
        guard let id = mission.id, let walletId = currentWalletId else { return }
        db.collection("wallets")
            .document(walletId)
            .collection("missions")
            .document(id)
            .updateData(["isApproved": true])
    }

    func deleteMission(_ mission: MissionModel) {
        guard let id = mission.id, let walletId = currentWalletId else { return }
        db.collection("wallets")
            .document(walletId)
            .collection("missions")
            .document(id)
            .delete()
    }
}
