//
//  ContentView.swift
//  Finvo
//
//  Created by Burak KOÇ on 20.02.2026.
//

import SwiftUI

enum Tab: String, CaseIterable {
    case home = "home"
    case analytics = "analytics"
    case settings = "settings"
    
    var symbolImage: String {
        switch self {
        case .home: return "house.fill"
        case .analytics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"

        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .home: return "Özet"
        case .analytics: return "Analiz"
        case .settings: return "Ayarlar"
        }
    }
}

struct ContentView: View {
    @Environment(\.theme) var theme
    @State private var activeTab: Tab = .home
    @State private var isExpanded: Bool = false
    
    var body: some View {
        TabView(selection: $activeTab) {
            SummaryView()
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.symbolImage)
                }
                .tag(Tab.home)
            
            Text("Analiz Sayfası")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .tabItem {
                    Label(Tab.analytics.title, systemImage: Tab.analytics.symbolImage)
                }
                .tag(Tab.analytics)
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.symbolImage)
                }
                .tag(Tab.settings)
        }
        .tint(theme.brandPrimary)
    }
}

#Preview {
    ContentView()
}
