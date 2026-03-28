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
        switch self {
        case .home:     return "Özet"
        case .analysis: return "Analiz"
        case .add:      return "Ekle"
        case .family:   return "Aile"
        case .settings: return "Ayarlar"
        }
    }

    func iconName(isActive: Bool) -> String {
        "tab-\(rawValue)-\(isActive ? "fill" : "outline")"
    }
}

// MARK: - ContentView
struct ContentView: View {
    @Environment(\.theme) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab: AppTab = .home
    @State private var showAddSheet: Bool = false

    // Haptic generator'lar her çağrıda yeniden oluşturulmasın
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)

    // Uygulama dilini takip ediyoruz
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
                Text("Aile Sayfası").frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                tabLabel(for: .family)
            }

            Tab(value: AppTab.settings) {
                SettingsView()
            } label: {
                tabLabel(for: .settings)
            }
        }
        .onAppear {
            // UITabBarItem'lara selectedImage (fill) ve image (outline) set et
            TabBarConfigurator.configure(tabs: AppTab.allCases)
        }
        .onChange(of: colorScheme) { _, _ in
            TabBarConfigurator.configure(tabs: AppTab.allCases)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            guard newTab == .add else { return }
            
            // Delay the tab restoration to allow the TabView to handle the selection state correctly
            // and avoid race conditions with the NavigationStack safe area calculations.
            DispatchQueue.main.async {
                selectedTab = oldTab
            }
            
            hapticMedium.impactOccurred()
            showAddSheet = true
        }
        .onChange(of: showAddSheet) { _, newValue in
            if !newValue { hapticLight.impactOccurred() }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionsView()
                .environmentObject(walletManager)
                .environmentObject(transactionManager)
        }
        .task {
            if let walletId = walletManager.activeWallet?.id {
                CategoryManager.shared.startListening(walletId: walletId)
            }
        }
        .environment(\.locale, Locale(identifier: appLanguage))
        .tint(theme.brandPrimary)
    }

    // MARK: - Tab etiketi
    private func tabLabel(for tab: AppTab) -> some View {
        Label {
            Text(LocalizedStringKey(tab.title))
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
