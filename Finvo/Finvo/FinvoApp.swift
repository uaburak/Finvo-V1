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

        // Segment Control: Başlangıç temasına göre ayarla
        let themeStr = UserDefaults.standard.string(forKey: "appThemeColor") ?? AppThemeColor.neonGreen.rawValue
        let selectedTheme = AppThemeColor(rawValue: themeStr) ?? .neonGreen

        UISegmentedControl.appearance().selectedSegmentTintColor = selectedTheme.uiColor
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: selectedTheme.uiOnBrandPrimary], for: .selected
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
            .environment(\.theme, DefaultTheme(colorIdentifier: appThemeColor))
            // appLanguage değişince tüm view hiyerarşisi yeniden kurulsun.
            // Bundle.setLanguage(...) üzerinden localizedString kaynağı zaten değişiyor.
            .id(appLanguage)
            .onChange(of: appLanguage) { newLanguage in
                LocalizationManager.setLanguage(newLanguage)
            }
            .onChange(of: appThemeColor) { newValue in
                let newTheme = AppThemeColor(rawValue: newValue) ?? .neonGreen
                UISegmentedControl.appearance().selectedSegmentTintColor = newTheme.uiColor
                UISegmentedControl.appearance().setTitleTextAttributes(
                    [.foregroundColor: newTheme.uiOnBrandPrimary], for: .selected
                )
            }
        }
    }
}
