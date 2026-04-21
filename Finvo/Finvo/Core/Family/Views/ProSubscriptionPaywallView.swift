import SwiftUI

struct ProSubscriptionPaywallView: View {
    @Environment(\.theme) var theme
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    @State private var isAnimating: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Animated Background
                theme.background1.ignoresSafeArea()
                
                Circle()
                    .fill(theme.brandPrimary.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: isAnimating ? 100 : -50, y: isAnimating ? -100 : -200)
                
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: isAnimating ? -100 : 50, y: isAnimating ? 150 : 50)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // MARK: - Hero Icon
                        ZStack {
                            Circle()
                                .fill(theme.brandPrimary.opacity(0.1))
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [theme.brandPrimary, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: theme.brandPrimary.opacity(0.3), radius: 10, y: 5)
                        }
                        .padding(.top, 40)
                        
                        // MARK: - Title & Subtitle
                        VStack(spacing: 12) {
                            Text("Finvo Pro")
                                .font(.title.weight(.black))
                                .foregroundStyle(theme.labelPrimary)
                            
                            Text("Ailenizle Finansal Özgürlük")
                                .font(.headline)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [theme.brandPrimary, theme.brandPrimary.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Finvo Pro'ya geçerek ailenizle paylaşımlı cüzdanlar oluşturun, bütçenizi beraber yönetin.")
                                .font(.subheadline)
                                .foregroundStyle(theme.labelSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // MARK: - Features List
                        VStack(spacing: 20) {
                            featureRow(icon: "person.3.fill", title: "Sınırsız Aile Üyesi", subtitle: "Ailenizdeki herkesi ortak cüzdanlara davet edin.")
                            featureRow(icon: "wallet.pass.fill", title: "Paylaşımlı Cüzdanlar", subtitle: "Ortak gelir ve giderlerinizi tek bir yerden takip edin.")
                            featureRow(icon: "shield.lefthalf.filled", title: "Rol ve Yetki Yönetimi", subtitle: "Üyelere Görme, Ekleme veya Yönetici yetkileri atayın.")
                            featureRow(icon: "chart.pie.fill", title: "Gelişmiş Analizler", subtitle: "Ailenizin toplam finansal durumunu detaylı şekilde görün.")
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(theme.background2.opacity(0.3))
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(theme.separator, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                        
                        // MARK: - CTA Button
                        Button {
                            // TODO: Replace with real RevenueCat paywall trigger or App Store ID
                            if let url = URL(string: "https://apps.apple.com") {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Text("Aboneliği Başlat")
                                    .font(.headline.weight(.bold))
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            .foregroundStyle(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [theme.brandPrimary, theme.brandPrimary.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: theme.brandPrimary.opacity(0.3), radius: 15, y: 5)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        
                        // Subscription disclaimer
                        Text("Aylık yenilenir. İstediğiniz zaman iptal edebilirsiniz.")
                            .font(.caption2)
                            .foregroundStyle(theme.labelSecondary.opacity(0.8))
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Aile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(theme.labelSecondary)
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(theme.brandPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.brandPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.labelPrimary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

#Preview {
    ProSubscriptionPaywallView()
        .environment(\.theme, DefaultTheme())
}
