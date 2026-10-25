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
    @AppStorage("monthlySummaryEnabled") var monthlySummaryEnabled: Bool = true
    
    /// Oturumu açık olan kullanıcının uid'si. Çıkış yapıldığında token'ı doğru dokümandan silebilmek için tutulur.
    private var lastKnownUid: String?

    private override init() {
        super.init()
        checkAuthorizationStatus()
        setupAuthListener()
    }

    private func setupAuthListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            Task { @MainActor in
                if let uid = user?.uid {
                    self.lastKnownUid = uid
                    if let currentToken = Messaging.messaging().fcmToken {
                        self.updateFcmTokenInFirestore(token: currentToken)
                    }
                } else if let previousUid = self.lastKnownUid {
                    // Çıkış yapıldı: cihazın token'ı eski kullanıcının dokümanında kalırsa
                    // bu cihaza artık ona ait olmayan push bildirimleri düşmeye devam eder.
                    self.lastKnownUid = nil
                    self.removeFcmTokenFromFirestore(uid: previousUid)
                }
            }
        }
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.isAuthorized = true
                default:
                    self.isAuthorized = false
                }
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
    
    /// Son başarıyla yazılan "uid|token" ikilisi. Token değişmediyse her açılışta
    /// tekrar yazıp Firestore yazma kotası harcamıyoruz.
    @AppStorage("lastSyncedFcmToken") private var lastSyncedFcmToken: String = ""

    func updateFcmTokenInFirestore(token: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        lastKnownUid = uid
        let signature = "\(uid)|\(token)"
        guard signature != lastSyncedFcmToken else { return }
        Firestore.firestore().collection("users").document(uid).setData(["fcmToken": token], merge: true) { [weak self] error in
            guard error == nil else { return }
            Task { @MainActor in self?.lastSyncedFcmToken = signature }
        }
    }

    private func removeFcmTokenFromFirestore(uid: String) {
        lastSyncedFcmToken = ""
        Firestore.firestore().collection("users").document(uid)
            .updateData(["fcmToken": FieldValue.delete()]) { error in
                if let error = error {
                    print("Error removing fcmToken on sign out: \(error)")
                }
            }
    }

    /// Çıkıştan ÖNCE çağrılır. Oturum kapandıktan sonra yazma izni olmadığından token silme
    /// isteği reddediliyor ve cihaz eski kullanıcının push bildirimlerini almaya devam ediyordu.
    /// Çevrimdışıyken çıkışı bekletmemek için en fazla 3 saniye beklenir.
    func removeFcmTokenBeforeSignOut() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        lastKnownUid = nil
        lastSyncedFcmToken = ""
        let ref = Firestore.firestore().collection("users").document(uid)
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                try? await ref.updateData(["fcmToken": FieldValue.delete()])
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
            await group.next()
            group.cancelAll()
        }
    }
    
    /// iOS uygulama başına en fazla 64 bekleyen yerel bildirim tutar; fazlası sessizce yok sayılır.
    /// Bu yüzden adayları tetiklenme tarihine göre sıralayıp en yakın olanları planlıyoruz.
    private static let pendingNotificationLimit = 64

    func scheduleNotifications(for transactions: [TransactionModel]) {
        // Clear existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        guard localNotificationsEnabled && isAuthorized else { return }

        let calendar = Calendar.current
        let today = Date()
        var candidates: [(triggerDate: Date, request: UNNotificationRequest)] = []

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
                content.userInfo = ["deeplink": "transactions"]

                let trigger = UNCalendarNotificationTrigger(dateMatching: dueComponents, repeats: false)
                let request = UNNotificationRequest(identifier: "\(txId)_due", content: content, trigger: trigger)
                candidates.append((dueTriggerDate, request))
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
                        content.userInfo = ["deeplink": "transactions"]

                        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderComponents, repeats: false)
                        let request = UNNotificationRequest(identifier: "\(txId)_reminder", content: content, trigger: trigger)
                        candidates.append((reminderTriggerDate, request))
                    }
                }
            }
        }

        // En yakın tarihli bildirimler önce planlansın; 64 üstü kalanlar bir sonraki
        // yeniden planlamada (yeni snapshot / ayar değişikliği) sıraya girer.
        // Ay sonu özeti için bir yer ayrılır
        let summaryRequest = monthlySummaryEnabled ? makeMonthlySummaryRequest(for: transactions) : nil
        let scheduled = candidates
            .sorted { $0.triggerDate < $1.triggerDate }
            .prefix(Self.pendingNotificationLimit - (summaryRequest == nil ? 0 : 1))

        if let summaryRequest {
            UNUserNotificationCenter.current().add(summaryRequest) { error in
                if let error = error {
                    print("Error scheduling monthly summary: \(error)")
                }
            }
        }

        for candidate in scheduled {
            UNUserNotificationCenter.current().add(candidate.request) { error in
                if let error = error {
                    print("Error scheduling notification \(candidate.request.identifier): \(error)")
                }
            }
        }
    }
    
    // MARK: - Aylık Özet
    /// Bu ayın özetini sonraki ayın 1'inde saat 10:00'da gösterecek bildirimi hazırlar.
    /// Her işlem değişikliğinde yeniden planlandığı için içerik son açılıştaki verilerle günceldir.
    private func makeMonthlySummaryRequest(for transactions: [TransactionModel]) -> UNNotificationRequest? {
        let calendar = Calendar.current
        let now = Date()
        guard let monthInterval = calendar.dateInterval(of: .month, for: now),
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: monthInterval.start) else { return nil }

        let currency = UserDefaults.standard.string(forKey: "appCurrency").flatMap { CurrencyType(rawValue: $0) } ?? .tryCurrency
        let rates = ExchangeRateManager.shared
        var expense = 0.0, income = 0.0, previousExpense = 0.0
        var byCategory: [String: (total: Double, name: String)] = [:]

        for tx in transactions where !tx.isDebt {
            let value = rates.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: currency)
            if monthInterval.contains(tx.date) {
                if tx.type == .expense {
                    expense += value
                    let key = tx.mainCategoryId ?? tx.mainCategoryName
                    byCategory[key] = ((byCategory[key]?.total ?? 0) + value, tx.resolvedMainCategoryName)
                } else {
                    income += value
                }
            } else if tx.type == .expense, tx.date >= previousMonthStart, tx.date < monthInterval.start {
                previousExpense += value
            }
        }
        guard expense > 0 || income > 0 else { return nil }

        func money(_ v: Double) -> String { "\(currency.symbol)\(v.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))" }

        let monthName = monthInterval.start.formatted(.dateTime.month(.wide).locale(Locale(identifier: UserDefaults.standard.string(forKey: "appLanguage") ?? "tr")))
        var lines: [String] = [String(format: L10n("Harcama %@, gelir %@."), money(expense), money(income))]
        if let top = byCategory.max(by: { $0.value.total < $1.value.total }) {
            lines.append(String(format: L10n("En çok %@ (%@)."), top.value.name.localized, money(top.value.total)))
        }
        if previousExpense > 0 {
            let change = Int(((expense - previousExpense) / previousExpense * 100).rounded())
            if change != 0 {
                lines.append(change < 0
                    ? String(format: L10n("Geçen aya göre %%%d daha az harcadın."), abs(change))
                    : String(format: L10n("Geçen aya göre %%%d daha fazla harcadın."), change))
            }
        }

        let content = UNMutableNotificationContent()
        content.title = String(format: L10n("%@ Özeti"), monthName.capitalized)
        content.body = lines.joined(separator: " ")
        content.sound = .default
        content.userInfo = ["type": "monthly_summary"]

        var trigger = calendar.dateComponents([.year, .month], from: monthInterval.end)
        trigger.day = 1
        trigger.hour = 10
        trigger.minute = 0
        return UNNotificationRequest(identifier: "monthly_summary",
                                     content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: false))
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
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String

        // Sadece davet / yetki isteği bildirimleri "Bildirimler" ekranına yönlendirilir.
        // Ödeme ve gelir hatırlatıcıları bu ekranla ilgisiz olduğu için sadece uygulamayı açar.
        guard type == "invitation" || type == "role_request" else {
            completionHandler()
            return
        }

        Task { @MainActor in
            // Önce ana sekmeye geç, sonraki runloop turunda NotificationsView'a push et.
            // Aynı turda yapılırsa hedef NavigationStack henüz görünür olmadığı için binding yutulabiliyor.
            NotificationCenter.default.post(name: NSNotification.Name("ShowNotificationsTab"), object: nil)
            try? await Task.sleep(nanoseconds: 300_000_000)
            LocalNotificationManager.shared.showNotificationsScreen = true
        }
        completionHandler()
    }
}
