import Foundation
import Combine
import FirebaseFirestore
import SwiftUI

@MainActor
class FamilyMissionsViewModel: ObservableObject {
    @Published var missions: [MissionModel] = []
    @Published var isLoading: Bool = false
    
    // Geçici Mock Data
    func fetchMissions(for walletId: String) {
        if missions.isEmpty {
            missions = [
                MissionModel(walletId: walletId, title: "Arabayı Yıka", rewardAmount: 150.0, isCompleted: false, assignedTo: "Burak", createdBy: "Özge"),
                MissionModel(walletId: walletId, title: "Mutfak Alışverişini Yerleştir", rewardAmount: 50.0, isCompleted: true, isApproved: false, assignedTo: "Can", createdBy: "Burak")
            ]
        }
    }
    
    func addMission(title: String, reward: Double, assignedTo: String?, walletId: String, createdBy: String) {
        let newMission = MissionModel(
            walletId: walletId,
            title: title,
            rewardAmount: reward,
            assignedTo: assignedTo,
            createdBy: createdBy
        )
        missions.insert(newMission, at: 0)
    }
    
    func toggleCompletion(for mission: MissionModel) {
        if let index = missions.firstIndex(where: { $0.id == mission.id || $0.title == mission.title }) {
            missions[index].isCompleted.toggle()
        }
    }
    
    func approveMission(for mission: MissionModel) {
        if let index = missions.firstIndex(where: { $0.id == mission.id || $0.title == mission.title }) {
            missions[index].isApproved = true
            // Burada normalde TransactionManager aracılığıyla "Gider" (Ödül) işlemi yazılabilir.
        }
    }
    
    func deleteMission(_ mission: MissionModel) {
        missions.removeAll(where: { $0.id == mission.id || $0.title == mission.title })
    }
}
