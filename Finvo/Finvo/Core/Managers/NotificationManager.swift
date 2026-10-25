import Foundation
import Combine
import FirebaseFirestore
import UIKit

@MainActor
class NotificationManager: ObservableObject {
    @Published var notifications: [NotificationModel] = []
    
    private var listener: ListenerRegistration?
    private var listeningUsername: String?
    /// İlk snapshot geçmişteki bekleyen tüm bildirimleri getirir; onlar için yerel bildirim atmıyoruz.
    private var hasLoadedInitialSnapshot = false
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
        // Aynı kullanıcı için zaten dinliyorsak tekrar kurma; kullanıcı değiştiyse eskisini kapat.
        if listeningUsername == username, listener != nil { return }
        stopListening()
        listeningUsername = username

        listener = Firestore.firestore().collection("notifications")
            .whereField("receiverUsername", isEqualTo: username)
            .whereField("status", isEqualTo: NotificationStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.notifications = []
                    }
                    return
                }

                let newNotifications = documents.compactMap { try? $0.data(as: NotificationModel.self) }
                    .sorted(by: { $0.createdAt > $1.createdAt })

                Task { @MainActor in
                    let oldNotifications = self.notifications
                    self.notifications = newNotifications

                    // İlk snapshot uygulama açılışındaki eski bekleyen kayıtları getirir; onlar için bildirim atma.
                    // (Liste boş olup olmamasına bakılamaz: ilk snapshot boşsa sonraki ilk davet de atlanıyordu.)
                    guard self.hasLoadedInitialSnapshot else {
                        self.hasLoadedInitialSnapshot = true
                        return
                    }

                    // Eski listede olmayan yeni gelen bildirimleri bul
                    let addedNotifications = newNotifications.filter { newNotif in
                        !oldNotifications.contains(where: { $0.id == newNotif.id })
                    }

                    // Eğer uygulama arka plandaysa/aktif değilse yerel bildirim gönder
                    if UIApplication.shared.applicationState != .active {
                        for notif in addedNotifications {
                            let title = notif.type == .invitation ? L10n("Cüzdan Daveti") : L10n("Yetki İsteği")
                            let body: String
                            if notif.type == .invitation {
                                body = String(format: L10n("@%@ seni %@ cüzdanına davet etti."), notif.senderUsername, notif.walletName)
                            } else {
                                body = String(format: L10n("@%@, %@ cüzdanı için yetki istiyor."), notif.senderUsername, notif.walletName)
                            }
                            LocalNotificationManager.shared.triggerInstantNotification(
                                title: title,
                                body: body,
                                userInfo: ["type": notif.type == .invitation ? "invitation" : "role_request",
                                           "walletId": notif.walletId]
                            )
                        }
                    }
                }
            }
    }
    
    private func stopListening() {
        listener?.remove()
        listener = nil
        listeningUsername = nil
        hasLoadedInitialSnapshot = false
        notifications = []
    }
    
    func sendRoleRequest(walletId: String, walletName: String, ownerUsername: String, requestedRole: WalletRole = .admin) {
        guard let myUsername = AuthenticationManager.shared.currentUserProfile?.username else { return }
        
        let notification = NotificationModel(
            type: .roleRequest,
            senderUsername: myUsername,
            receiverUsername: ownerUsername,
            walletId: walletId,
            walletName: walletName,
            requestedRole: requestedRole,
            status: .pending,
            createdAt: Date()
        )
        
        Task {
            try? await FirestoreService.shared.sendNotification(notification)
        }
    }
    
    func sendInvitation(walletId: String, walletName: String, receiverUsername: String, role: WalletRole = .member) {
        guard let myUsername = AuthenticationManager.shared.currentUserProfile?.username else { return }
        
        let notification = NotificationModel(
            type: .invitation,
            senderUsername: myUsername,
            receiverUsername: receiverUsername,
            walletId: walletId,
            walletName: walletName,
            requestedRole: role,
            status: .pending,
            createdAt: Date()
        )
        
        Task {
            try? await FirestoreService.shared.sendNotification(notification)
        }
    }
    
    func approveRequest(_ notification: NotificationModel) {
        Task {
            if notification.type == .invitation {
                // Davet Kabul Edildi: Rolü .pending'den davet edilen role çevir.
                // Davet bu arada geri çekildiyse (kullanıcı cüzdandan çıkarıldıysa) eski bildirimle tekrar eklenmemeli.
                let stillInvited = await FirestoreService.shared.isPendingMember(walletId: notification.walletId, username: notification.receiverUsername)
                guard stillInvited else {
                    if let id = notification.id {
                        try? await FirestoreService.shared.updateNotificationStatus(id: id, status: .rejected)
                    }
                    return
                }
                let role = notification.requestedRole ?? .member
                try? await FirestoreService.shared.addMember(walletId: notification.walletId, userId: notification.receiverUsername, role: role)
            } else {
                // Yetki İsteği Onaylandı: Talep edilen role çevir
                let role = notification.requestedRole ?? .member
                try? await FirestoreService.shared.addMember(walletId: notification.walletId, userId: notification.senderUsername, role: role)
            }
            
            // Bildirimi Onaylandı Olarak İşaretle
            if let id = notification.id {
                try? await FirestoreService.shared.updateNotificationStatus(id: id, status: .approved)
            }
        }
    }
    
    func rejectRequest(_ notification: NotificationModel) {
        Task {
            if notification.type == .invitation {
                // Davet Reddedildi: Kullanıcıyı cüzdandan tamamen çıkar
                try? await FirestoreService.shared.removeMember(walletId: notification.walletId, userId: notification.receiverUsername)
            }
            
            if let id = notification.id {
                try? await FirestoreService.shared.updateNotificationStatus(id: id, status: .rejected)
            }
        }
    }
}
