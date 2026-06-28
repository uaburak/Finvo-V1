import Foundation
import UserNotifications
import SwiftUI
import Combine
import FirebaseMessaging
import FirebaseAuth
import FirebaseFirestore

@MainActor
class LocalNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = LocalNotificationManager()
    
    @Published var isAuthorized = false
    @Published var showNotificationsScreen = false
    
    // Notification Preferences stored locally
    @AppStorage("localNotificationsEnabled") var localNotificationsEnabled: Bool = true
    @AppStorage("expenseNotificationDays") var expenseNotificationDays: Int = 2 // 0: Aynı Gün, 1: 1 Gün Önce, vb.
    @AppStorage("incomeNotificationDays") var incomeNotificationDays: Int = 2
    @AppStorage("notificationHour") var notificationHour: Int = 9
    @AppStorage("notificationMinute") var notificationMinute: Int = 0
    @AppStorage("expenseNotificationsEnabled") var expenseNotificationsEnabled: Bool = true
    @AppStorage("incomeNotificationsEnabled") var incomeNotificationsEnabled: Bool = true
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
        setupAuthListener()
    }
    
    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self, user != nil else { return }
            Task { @MainActor in
                if let currentToken = Messaging.messaging().fcmToken {
                    self.updateFcmTokenInFirestore(token: currentToken)
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            await MainActor.run {
                self.isAuthorized = false
            }
            return false
        }
    }
    
    // MARK: - MessagingDelegate (FCM Token)
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else { return }
        print("Firebase registration token: \(fcmToken)")
        
        Task {
            await LocalNotificationManager.shared.updateFcmTokenInFirestore(token: fcmToken)
        }
    }
    
    func updateFcmTokenInFirestore(token: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).setData(["fcmToken": token], merge: true)
    }
    
    func scheduleNotifications(for transactions: [TransactionModel]) {
        // Clear existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        guard localNotificationsEnabled && isAuthorized else { return }
        
        let calendar = Calendar.current
        let today = Date()
        
        for tx in transactions {
            guard let txId = tx.id else { continue }
            
            // Determine transaction next payment / occurrence date
            let paymentDate: Date
            if tx.isDebt || tx.isRecurring {
                guard let next = tx.nextPayment(after: today) else { continue }
                paymentDate = next.date
            } else if tx.date > today {
                paymentDate = tx.date
            } else {
                continue
            }
            
            let isExpense = tx.type == .expense
            let isEnabled = isExpense ? expenseNotificationsEnabled : incomeNotificationsEnabled
            guard isEnabled else { continue }
            
            let daysBefore = isExpense ? expenseNotificationDays : incomeNotificationDays
            
            // 1. Schedule Due Date Notification
            var dueComponents = calendar.dateComponents([.year, .month, .day], from: paymentDate)
            dueComponents.hour = notificationHour
            dueComponents.minute = notificationMinute
            
            if let dueTriggerDate = calendar.date(from: dueComponents), dueTriggerDate > today {
                let content = UNMutableNotificationContent()
                content.title = isExpense ? L10n("Ödeme Günü!") : L10n("Gelir Günü!")
                
                let amountStr = String(format: "%.2f", tx.amount)
                let currencySymbol = tx.currency?.symbol ?? ""
                let categoryName = tx.resolvedMainCategoryName
                
                if isExpense {
                    content.body = String(format: L10n("Bugün %@ ödeme günü! %@ %@ tutarındaki ödemeniz gerçekleşti."), categoryName, amountStr, currencySymbol)
                } else {
                    content.body = String(format: L10n("Bugün %@ günü! %@ %@ tutarındaki geliriniz hesabınıza ulaştı."), categoryName, amountStr, currencySymbol)
                }
                
                content.sound = .default
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dueComponents, repeats: false)
                let request = UNNotificationRequest(identifier: "\(txId)_due", content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Error scheduling due notification: \(error)")
                    }
                }
            }
            
            // 2. Schedule Advance Reminder Notification (if daysBefore > 0)
            if daysBefore > 0 {
                if let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: paymentDate) {
                    var reminderComponents = calendar.dateComponents([.year, .month, .day], from: reminderDate)
                    reminderComponents.hour = notificationHour
                    reminderComponents.minute = notificationMinute
                    
                    if let reminderTriggerDate = calendar.date(from: reminderComponents), reminderTriggerDate > today {
                        let content = UNMutableNotificationContent()
                        content.title = isExpense ? L10n("Yaklaşan Ödeme!") : L10n("Yaklaşan Gelir!")
                        
                        let amountStr = String(format: "%.2f", tx.amount)
                        let currencySymbol = tx.currency?.symbol ?? ""
                        let categoryName = tx.resolvedMainCategoryName
                        
                        if isExpense {
                            content.body = String(format: L10n("%@ ödemenize %d gün kaldı! (%@ %@)"), categoryName, daysBefore, amountStr, currencySymbol)
                        } else {
                            content.body = String(format: L10n("%@ gelirinize %d gün kaldı! (%@ %@)"), categoryName, daysBefore, amountStr, currencySymbol)
                        }
                        
                        content.sound = .default
                        
                        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
                        let request = UNNotificationRequest(identifier: "\(txId)_reminder", content: content, trigger: trigger)
                        
                        UNUserNotificationCenter.current().add(request) { error in
                            if let error = error {
                                print("Error scheduling reminder notification: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Instant/Remote Notification Trigger
    func triggerInstantNotification(title: String, body: String, userInfo: [String: Any] = [:]) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        
        // Trigger with a 1 second delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling instant notification: \(error)")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate (Foreground notifications)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, play sound, and update badge even if the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - UNUserNotificationCenterDelegate (Notification Tapped)
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            LocalNotificationManager.shared.showNotificationsScreen = true
            NotificationCenter.default.post(name: NSNotification.Name("ShowNotificationsTab"), object: nil)
        }
        completionHandler()
    }
}
