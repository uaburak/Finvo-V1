//
//  NativeContentView.swift
//  Finvo
//
//  Native TabView varyantı — karşılaştırma için.
//  Add sekmesi tam ortada (3. pozisyon).
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

    func iconName(isSelected: Bool) -> String {
        "tab-\(rawValue)-\(isSelected ? "fill" : "outline")"
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
                Color.clear // "Add" sekmesi için içerik artık sheet üzerinden gösterilecek
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
        .onChange(of: showAddSheet) { oldValue, newValue in
            if !newValue {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTransactionsView()
        }
        .environment(\.locale, Locale(identifier: appLanguage)) // Seçili dile göre labelları günceller
        .tint(theme.brandPrimary)
        .id("\(colorScheme)-\(appLanguage)") // Dil veya tema değiştiğinde görünümü yenilemeye zorlar
        .overlay(alignment: .bottom) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showAddSheet = true
            } label: {
                Color.black.opacity(0.001)
                    // Tüm ekran genişliğinin 5'te 1'i kadar (sadece ortadaki Ekle sekmesini kaplar)
                    // Yükseklik 85 civarı seçilerek sekme barının tamamını örtmesi sağlanır.
                    .frame(width: UIScreen.main.bounds.width / 5, height: 85)
            }
            // Safe area insets'i yoksayarak tamamen ekranın altına yaslanmasını sağlarız
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }

    // MARK: - Tab etiketi
    @ViewBuilder
    private func tabLabel(for tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        Label {
            Text(LocalizedStringKey(tab.title)) // Yerelleştirilmiş metin
        } icon: {
            Image(tab.iconName(isSelected: isSelected))
                .renderingMode(.template)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.theme, DefaultTheme())
}
