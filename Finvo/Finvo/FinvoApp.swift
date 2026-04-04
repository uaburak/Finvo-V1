//
//  FinvoApp.swift
//  Finvo
//
//  Created by Burak KOÇ on 20.02.2026.
//

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct FinvoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("appLanguage") private var appLanguage: String = "tr"
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var walletManager = WalletManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var transactionManager = TransactionManager()
    
    init() {
        // Konsoldaki gereksiz AutoLayout ve klavye uyarılarını gizlemek için
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
        
        // Segment Control: Seçili segmentin rengi neon green, metin siyah okunaklı olsun.
        let brandColor = UIColor(Color(hex: "AEFF23"))
        UISegmentedControl.appearance().selectedSegmentTintColor = brandColor
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.black], for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: UIColor.label], for: .normal
        )
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
        }
    }
}
