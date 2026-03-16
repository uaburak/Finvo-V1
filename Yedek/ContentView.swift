//
//  ContentView.swift
//  Finvo
//
//  Created by Burak KOÇ on 20.02.2026.
//

import SwiftUI
import UIKit // UIKit'in nimetlerinden faydalanmak için eklendi

enum AppTab: String, CaseIterable {
    case home = "home"
    case analytics = "analytics"
    case family = "family"
    case add = "add"
    case settings = "settings"
    
    var symbolImage: String {
        switch self {
        case .home: return "house.fill"
        case .analytics: return "chart.pie.fill"
        case .family: return "person.2.fill"
        case .add: return "plus"
        case .settings: return "gearshape.fill"
        }
    }
    
    var title: LocalizedStringKey {
        switch self {
        case .home: return "Özet"
        case .analytics: return "Analiz"
        case .family: return "Aile"
        case .add: return "Ekle"
        case .settings: return "Ayarlar"
        }
    }
}

struct ContentView: View {
    @Environment(\.theme) var theme
    @Environment(\.colorScheme) var colorScheme
    @State private var activeTab: AppTab = .home

    // SwiftUI'ın ikon boyutunu ezmesini engelleyen UIKit hilesi fonksiyonumuz
    func sizedIcon(for tab: AppTab) -> Image {
        // İkonu UIKit seviyesinde tam 18 point olarak render ediyoruz
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        let uiImage = UIImage(systemName: tab.symbolImage, withConfiguration: config) ?? UIImage()
        // SwiftUI'a artık değişmez bir görsel olarak veriyoruz
        return Image(uiImage: uiImage).renderingMode(.template)
    }

    var body: some View {
        TabView(selection: $activeTab) {

            // 1. ÖZET SEKMESİ
            Tab(value: .home) {
                SummaryView()
            } label: {
                Label {
                    Text(AppTab.home.title)
                        .font(.system(size: 12))
                } icon: {
                    sizedIcon(for: .home)
                }
            }

            // 2. ANALİZ SEKMESİ
            Tab(value: .analytics) {
                Text("Analiz Sayfası")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                Label {
                    Text(AppTab.analytics.title)
                        .font(.system(size: 12))
                } icon: {
                    sizedIcon(for: .analytics)
                }
            }

            // 3. AİLE SEKMESİ
            Tab(value: .family) {
                Text("Aile Sayfası")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                Label {
                    Text(AppTab.family.title)
                        .font(.system(size: 12))
                } icon: {
                    sizedIcon(for: .family)
                }
            }

            // 4. AYARLAR SEKMESİ
            Tab(value: .settings) {
                SettingsView()
            } label: {
                Label {
                    Text(AppTab.settings.title)
                        .font(.system(size: 12))
                } icon: {
                    sizedIcon(for: .settings)
                }
            }

            // 5. EKLE SEKMESİ
            Tab(AppTab.add.title, systemImage: AppTab.add.symbolImage, value: .add, role: .search) {
                NavigationStack {
                    AddTransactionsView()
                }
            }
        }
        .tint(theme.brandPrimary)
        .id(colorScheme)
    }
}


#Preview {
    ContentView()
}
