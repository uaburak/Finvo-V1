import SwiftUI

// MARK: - Tab Seçenekleri
enum FinvoTab: String, CaseIterable {
    case dashboard = "chart.pie.fill"
    case transactions = "list.bullet"
    case add = "plus" // Merkez buton
    case analytics = "chart.bar.xaxis"
    case settings = "gearshape.fill"
}

struct FinvoTabBar: View {
    @Binding var activeTab: FinvoTab
    @State private var isExpanded: Bool = false
    
    // Tema Renkleri
    var activeTint: Color = .blue
    var inActiveTint: Color = .gray
    
    // Artı butonunun menü animasyonu için namespace
    @Namespace private var animation
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // 1. AÇILIR MENÜ (Slide-Up)
            if isExpanded {
                VStack(spacing: 16) {
                    ActionMenuItem(icon: "arrow.up.circle.fill", title: "Gelir", color: .green) {
                        isExpanded = false
                        // TODO: Gelir Ekleme Sayfasını Aç
                    }
                    
                    ActionMenuItem(icon: "arrow.down.circle.fill", title: "Gider", color: .red) {
                        isExpanded = false
                        // TODO: Gider Ekleme Sayfasını Aç
                    }
                }
                .padding(.bottom, 90) // Tab barın üstünde görünmesi için
                // Sadece aşağıdan yukarı kayma ve şeffaflık animasyonu
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .zIndex(0)
            }
            
            // 2. ANA TAB BAR (CustomTabBar Görünümü)
            HStack(spacing: 0) {
                ForEach(FinvoTab.allCases, id: \.rawValue) { tab in
                    Button {
                        if tab == .add {
                            // Artı butonuna basılınca sadece menüyü aç/kapat
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                                isExpanded.toggle()
                            }
                        } else {
                            // Diğer tablara basılınca menüyü kapat ve taba geç
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                activeTab = tab
                                isExpanded = false
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.rawValue)
                                .font(.system(size: tab == .add ? 24 : 20, weight: tab == .add ? .bold : .regular))
                                // Seçili tab ve artı butonu renklendirmesi
                                .foregroundColor(activeTab == tab || (tab == .add && isExpanded) ? activeTint : inActiveTint)
                                // Artı butonuysa ve menü açıksa ikon çarpıya dönsün
                                .rotationEffect(.degrees(tab == .add && isExpanded ? 45 : 0))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background {
                            // Seçili Tabın Arkasındaki Kapsül Animasyonu (Segmented Control Efekti)
                            if activeTab == tab && tab != .add {
                                Capsule()
                                    .fill(activeTint.opacity(0.15))
                                    .matchedGeometryEffect(id: "ACTIVETAB", in: animation)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial) // Cam (Glass) Efekti
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)
            .zIndex(1)
        }
    }
}

// MARK: - Açılır Menü Butonları Tasarımı
struct ActionMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Önizleme (Kullanımı Görmek İçin)
struct FinvoTabBar_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var activeTab: FinvoTab = .dashboard
        
        var body: some View {
            ZStack {
                // Arka planı görmek için temsili bir renk
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("Seçili Sayfa: \(activeTab.rawValue)")
                        .font(.title2)
                    Spacer()
                    
                    FinvoTabBar(activeTab: $activeTab)
                }
            }
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
    }
}