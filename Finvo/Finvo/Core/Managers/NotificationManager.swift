import Foundation
import Combine
import FirebaseFirestore

@MainActor
class NotificationManager: ObservableObject {
    @Published var notifications: [NotificationModel] = []
    
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        AuthenticationManager.shared.$currentUserProfile
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                if let username = profile?.username, !username.isEmpty {
                    self?.startListening(for: username)
                } else {
                    self?.stopListening()
                }
            }
            .store(in: &cancellables)
    }
    
    private func startListening(for username: String) {
        if listener != nil { return }
        
        listener = Firestore.firestore().collection("notifications")
            .whereField("receiverUsername", isEqualTo: username)
            .whereField("status", isEqualTo: NotificationStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    self?.notifications = []
                    return
                }
                
                self?.notifications = documents.compactMap { try? $0.data(as: NotificationModel.self) }
                    .sorted(by: { $0.createdAt > $1.createdAt })
            }
    }
    
    private func stopListening() {
        listener?.remove()
        listener = nil
        notifications = []
    }
    
    func sendRoleRequest(walletId: String, walletName: String, ownerUsername: String) {
        guard let myUsername = AuthenticationManager.shared.currentUserProfile?.username else { return }
        
        let notification = NotificationModel(
            type: .roleRequest,
            senderUsername: myUsername,
            receiverUsername: ownerUsername,
            walletId: walletId,
            walletName: walletName,
            status: .pending,
            createdAt: Date()
        )
        
        Task {
            try? await FirestoreService.shared.sendNotification(notification)
        }
    }
    
    func approveRequest(_ notification: NotificationModel) {
        Task {
            // Cüzdan Yetkisini Güncelle (.member)
            try? await FirestoreService.shared.addMember(walletId: notification.walletId, userId: notification.senderUsername, role: .member)
            // Bildirimi Onaylandı Olarak İşaretle
            if let id = notification.id {
                try? await FirestoreService.shared.updateNotificationStatus(id: id, status: .approved)
            }
        }
    }
    
    func rejectRequest(_ notification: NotificationModel) {
        Task {
            if let id = notification.id {
                try? await FirestoreService.shared.updateNotificationStatus(id: id, status: .rejected)
            }
        }
    }
}
