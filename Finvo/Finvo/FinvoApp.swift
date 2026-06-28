//
//  FinvoApp.swift
//  Finvo
//
//  Created by Burak KOÇ on 20.02.2026.
//

import SwiftUI
import FirebaseCore
import UserNotifications
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Set local notification delegate
        UNUserNotificationCenter.current().delegate = LocalNotificationManager.shared
        Messaging.messaging().delegate = LocalNotificationManager.shared
        
        return true
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
}

@main
struct FinvoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("appLanguage") private var appLanguage: String = "tr"
    @AppStorage("appThemeColor") private var appThemeColor: String = AppThemeColor.neonGreen.rawValue
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var walletManager = WalletManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var transactionManager = TransactionManager()
    
    init() {
        // Konsoldaki gereksiz AutoLayout ve klavye uyarılarını gizlemek için
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")

        // Uygulama dilini, Bundle swizzling üzerinden uygula (çalışma zamanında dil değişimi)
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        LocalizationManager.setLanguage(savedLanguage)
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    if authManager.isProfileLoading {
                        ZStack {
                            Color(.systemBackground).ignoresSafeArea()
                            ProgressView()
                        }
                    } else if authManager.isProfileComplete {
                        ContentView()
                            .environmentObject(walletManager)
                            .environmentObject(notificationManager)
                            .environmentObject(transactionManager)
                    } else {
                        CompleteProfileView()
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .environment(\.locale, Locale(identifier: appLanguage))
            .environment(\.theme, DefaultTheme(colorIdentifier: appThemeColor))
            // Bundle.setLanguage(...) üzerinden localizedString kaynağı zaten değişiyor.
            .onChange(of: appLanguage) { _, newLanguage in
                LocalizationManager.setLanguage(newLanguage)
            }
            }
    }
}
