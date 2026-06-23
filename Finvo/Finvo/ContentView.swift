//
//  ContentView.swift
//  Finvo
//
//  Native TabView + iOS 26 Liquid Glass desteği.
//  Tab ikonları: outline (image) + fill (selectedImage)
//  UIKit seviyesinde set edilir, liquid glass efekti
//  otomatik olarak morph yapar.
//

import SwiftUI
import FirebaseAuth

// MARK: - Tab tanımları
enum AppTab: String, CaseIterable {
    case home     = "home"
    case analysis = "analysis"
    case add      = "add"
    case family   = "family"
    case settings = "setting"

    var title: String {
        let appLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        let keyText: String
        switch self {
        case .home:     keyText = "Özet"
        case .analysis: keyText = "Analiz"
        case .add:      keyText = "Ekle"
        case .family:   keyText = "Aile"
        case .settings: keyText = "Ayarlar"
        }
        
        if let path = Bundle.main.path(forResource: appLang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: keyText, value: nil, table: nil)
        }
        return NSLocalizedString(keyText, comment: "")
    }

    func iconName(isActive: Bool) -> String {
        "tab-\(rawValue)-\(isActive ? "fill" : "outline")"
    }
}

// MARK: - ContentView
struct ContentView: View {
    @Environment(\.theme) var theme
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var selectedTab: AppTab = .home
    @State private var showAddSheet: Bool = false

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)

    @AppStorage("appLanguage") private var appLanguage: String = "tr"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(value: AppTab.home) {
                SummaryView()
            } label: {
                tabLabel(for: .home)
            }

            Tab(value: AppTab.analysis) {
                AnalysisView()
            } label: {
                tabLabel(for: .analysis)
            }

            Tab(value: AppTab.add) {
                EmptyView()
            } label: {
                tabLabel(for: .add)
            }

            Tab(value: AppTab.family) {
                FamilyView()
            } label: {
                tabLabel(for: .family)
            }

            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                tabLabel(for: .settings)
            }
        }
        // MARK: UIKit-level Add tab interceptor
        // shouldSelect → return false → UIKit hiç tab geçişi yapmaz
        // SwiftUI state değişmez → NavigationStack'ler korunur
        .background {
            TabBarAddInterceptor(showAddSheet: $showAddSheet, addTabIndex: 2)
        }
        .onAppear {
            TabBarConfigurator.configure(tabs: AppTab.allCases)
        }
        .onChange(of: colorScheme) { _, _ in
            TabBarConfigurator.configure(tabs: AppTab.allCases)
        }
        .onChange(of: showAddSheet) { _, newValue in
            if !newValue { hapticLight.impactOccurred() }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionsView()
                .environmentObject(walletManager)
                .environmentObject(transactionManager)
                .environmentObject(authManager)
        }
        .task {
            if let walletId = walletManager.activeWallet?.id {
                CategoryManager.shared.startListening(walletId: walletId)
            }
        }
        // Uygulama ön plana geldiğinde tüm cüzdanları retroaktif catch-up ile tara
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                let allWalletIds = walletManager.wallets.compactMap { $0.id }
                transactionManager.evaluateAllWalletsRecurring(walletIds: allWalletIds)
            }
        }
        // Aktif cüzdan değiştiğinde tekrarlayan işlemleri tetikle
        .onChange(of: walletManager.activeWallet?.id) { _, newId in
            if let walletId = newId {
                let allWalletIds = walletManager.wallets.compactMap { $0.id }
                transactionManager.evaluateAllWalletsRecurring(walletIds: [walletId])
                _ = allWalletIds // Tüm cüzdanlar zaten scenePhase'de taranıyor
            }
        }
        .environment(\.locale, Locale(identifier: appLanguage))
        .tint(theme.brandPrimary)
    }

    // MARK: - Tab etiketi
    private func tabLabel(for tab: AppTab) -> some View {
        Label {
            Text(tab.title)
        } icon: {
            Image(tab.iconName(isActive: false))
                .renderingMode(.template)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.theme, DefaultTheme())
}
