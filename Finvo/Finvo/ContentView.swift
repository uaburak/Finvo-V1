//
//  ContentView.swift
//  Finvo
//
//  Created by Burak KOÇ on 20.02.2026.
//

import SwiftUI

enum AppTab: String, CaseIterable {
    case home = "home"
    case analytics = "analytics"
    case add = "add"
    case settings = "settings"
    
    var symbolImage: String {
        switch self {
        case .home: return "house.fill"
        case .analytics: return "chart.bar.fill"
        case .add: return "plus"
        case .settings: return "gearshape.fill"
        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .home: return "Özet"
        case .analytics: return "Analiz"
        case .add: return "Ekle"
        case .settings: return "Ayarlar"
        }
    }
}

struct ContentView: View {
    @Environment(\.theme) var theme
    @State private var activeTab: AppTab = .home
    @State private var isExpanded: Bool = false
    @State private var showAddSheet: Bool = false // Sheet'i kontrol edecek state
    
    // Tıklamaları araya girip yakaladığımız özel Binding
    var tabSelection: Binding<AppTab> {
        Binding(
            get: { self.activeTab },
            set: { newValue in
                if newValue == .add {
                    // Eğer '+' butonuna basıldıysa, sekmeyi DEĞİŞTİRME, sadece sheet'i aç
                    self.showAddSheet = true
                } else {
                    // Diğer sekmelere basıldıysa normal şekilde sekmeyi değiştir
                    self.activeTab = newValue
                }
            }
        )
    }
    
    var body: some View {
        // TabView'a artık kendi yazdığımız tabSelection binding'ini veriyoruz
        TabView(selection: tabSelection) {
            
            Tab(AppTab.home.title, systemImage: AppTab.home.symbolImage, value: .home) {
                SummaryView()
            }
            
            Tab(AppTab.analytics.title, systemImage: AppTab.analytics.symbolImage, value: .analytics) {
                Text("Analiz Sayfası")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Tab(AppTab.settings.title, systemImage: AppTab.settings.symbolImage, value: .settings) {
                SettingsView()
            }
            
            // Bu tab aslında hiç render edilmeyecek, çünkü binding'de araya giriyoruz
            Tab(AppTab.add.title, systemImage: AppTab.add.symbolImage, value: .add, role: .search) {
                Color.clear
            }
        }
        .tint(theme.brandPrimary)
        // Sheet'i burada tetikliyoruz
        .sheet(isPresented: $showAddSheet) {
            // Buraya yeni gelir/gider ekleme sayfanın View'ını koyabilirsin
            Text("Yeni Harcama / Gelir Ekleme Ekranı")
                .presentationDetents([.medium, .large]) // İsteğe bağlı: yarım sayfa açılması için
        }
    }
}

#Preview {
    ContentView()
}
