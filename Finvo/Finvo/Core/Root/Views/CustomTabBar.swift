import SwiftUI

enum Tab: String, CaseIterable {
    case home = "Ev"
    case analytics = "Analiz"
    case settings = "Ayarlar"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .analytics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct CustomTabBar: View {
    @Environment(\.theme) var theme
    @State private var selectedTab: Tab = .home
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Ana İçerik
            Group {
                switch selectedTab {
                case .home:
                    SummaryView()
                case .analytics:
                    Text("Analiz Sayfası").frame(maxWidth: .infinity, maxHeight: .infinity)
                case .settings:
                    Text("Ayarlar Sayfası").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Alt Menü Barı
            HStack(spacing: 20) {
                
                // Sol Taraftaki Kapsül Menü
                HStack {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 24))
                                Text(tab.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(selectedTab == tab ? theme.brandPrimary : theme.labelSecondary)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(theme.cardBackground)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.separatorSecondary, lineWidth: 1)
                )
                
                // Sağ Taraftaki Ekle Butonu
                Button(action: {
                    // Ekleme aksiyonu
                }) {
                    ZStack {
                        Circle()
                            .fill(theme.brandPrimary)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(theme.background1.ignoresSafeArea())
    }
}

struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        CustomTabBar()
    }
}
