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
    @State private var selectedTab: AppTab = .home
    @State private var showAddSheet: Bool = false

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
                Text("Analiz Sayfası").frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                tabLabel(for: .analysis)
            }

            Tab(value: AppTab.add) {
                Color.clear
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
            // Tema değişince UITabBar item'larını tekrar konfigüre et
            TabBarConfigurator.configure(tabs: AppTab.allCases)
        }
        .onChange(of: showAddSheet) { _, newValue in
            if !newValue {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionsView()
        }
        .environment(\.locale, Locale(identifier: appLanguage))
        .tint(theme.brandPrimary)
        .id("\(colorScheme)-\(appLanguage)")
        .overlay(alignment: .bottom) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showAddSheet = true
            } label: {
                Color.black.opacity(0.001)
                    .frame(width: 75, height: 85)
            }
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }

    // MARK: - Tab etiketi
    /// Daima outline ikonu gösterir (UITabBarItem.image olur).
    /// Fill, UIKit seviyesinde selectedImage olarak set edilir.
    @ViewBuilder
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
