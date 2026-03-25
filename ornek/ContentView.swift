//
//  ContentView.swift
//  [Proje Adı]
//
//  Yeniden kullanılabilir TabView şablonu.
//  iOS 26 Liquid Glass desteği: outline (image) + fill (selectedImage)
//  UIKit seviyesinde set edilir, liquid glass efekti otomatik morph yapar.
//
//  KULLANIM:
//  1. Bu dosyayı projeye ekle
//  2. TabBarConfigurator.swift dosyasını projeye ekle
//  3. Asset catalog'a her tab için iki ikon ekle:
//     - tab-[isim]-outline  (varsayılan)
//     - tab-[isim]-fill     (seçili)
//  4. AppTab enum'unu kendi tab'larına göre düzenle
//

import SwiftUI

// MARK: - Tab tanımları
/// Her yeni proje için bu enum'u düzenle.
/// rawValue, asset catalog'daki ikon adının ortasına gelir:
/// "tab-\(rawValue)-outline" ve "tab-\(rawValue)-fill"
enum AppTab: String, CaseIterable {
    case home     = "home"
    case search   = "search"
    case profile  = "profile"
    case settings = "setting"

    /// Tab bar'da gösterilecek metin
    var title: String {
        switch self {
        case .home:     return "Ana Sayfa"
        case .search:   return "Keşfet"
        case .profile:  return "Profil"
        case .settings: return "Ayarlar"
        }
    }

    /// Asset catalog'daki ikon adını döndürür
    func iconName(isActive: Bool) -> String {
        "tab-\(rawValue)-\(isActive ? "fill" : "outline")"
    }
}

// MARK: - ContentView
struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    // Haptic generator'lar (isteğe bağlı — kullanmıyorsan kaldır)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        TabView(selection: $selectedTab) {

            Tab(value: AppTab.home) {
                Text("Ana Sayfa")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                tabLabel(for: .home)
            }

            Tab(value: AppTab.search) {
                Text("Keşfet")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                tabLabel(for: .search)
            }

            Tab(value: AppTab.profile) {
                Text("Profil")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                tabLabel(for: .profile)
            }

            Tab(value: AppTab.settings) {
                Text("Ayarlar")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                tabLabel(for: .settings)
            }
        }
        .onAppear {
            TabBarConfigurator.configure(tabs: AppTab.allCases)
        }
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

// MARK: - Opsiyonel: Sheet açan tab örneği
// Eğer bir tab'a tıklandığında sayfa yerine sheet açmak istersen:
//
// 1. AppTab'a yeni case ekle:  case add = "add"
// 2. @State private var showSheet = false  ekle
// 3. .onChange(of: selectedTab) { oldTab, newTab in
//        guard newTab == .add else { return }
//        selectedTab = oldTab
//        hapticMedium.impactOccurred()
//        showSheet = true
//    }
// 4. .sheet(isPresented: $showSheet) { ... }

#Preview {
    ContentView()
}
