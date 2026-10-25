import SwiftUI

struct ProSubscriptionPaywallView: View {
    @Environment(\.theme) var theme
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var authManager = AuthenticationManager.shared

    private var isPro: Bool { authManager.currentUserProfile?.isPro == true }

    // Ücretsiz plan sınırları uygulamadaki kontrollerle birebir aynı
    // (CreateWalletSheet, InviteUserSheet, kategori ekranları, AnalysisView).
    private struct PlanFeature: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let free: String?   // nil = ücretsiz planda yok
        let pro: String?    // nil = sadece onay işareti
    }

    private var planFeatures: [PlanFeature] {
        [
            PlanFeature(icon: "wallet.bifold.fill", color: .blue, title: "Cüzdan Sayısı", free: "2", pro: "Sınırsız"),
            PlanFeature(icon: "person.2.fill", color: .purple, title: "Paylaşımlı Cüzdan", free: "1", pro: "Sınırsız"),
            PlanFeature(icon: "person.3.fill", color: .orange, title: "Cüzdan Üyesi", free: "2", pro: "Sınırsız"),
            PlanFeature(icon: "square.grid.2x2.fill", color: .teal, title: "Kategori Yönetimi", free: nil, pro: nil),
            PlanFeature(icon: "calendar", color: .pink, title: "Özel Tarih Aralığı", free: nil, pro: nil),
            PlanFeature(icon: "doc.richtext.fill", color: .indigo, title: "PDF ve CSV Dışa Aktarma", free: nil, pro: nil)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ücretsiz ve Pro")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.labelPrimary)
                            .padding(.horizontal)

                        comparisonCard
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Neler Kazanırsınız?")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.labelPrimary)
                            .padding(.horizontal)

                        benefitsCard
                    }
                }
                .padding(.vertical)
            }
            .background(theme.background1.ignoresSafeArea())
            // safeAreaBar: içerik altından kayarken iOS 26 yumuşak kenar efekti uygulanır
            .safeAreaBar(edge: .bottom) {
                bottomBar
            }
            .navigationTitle("Finvo Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                            .foregroundStyle(theme.labelPrimary)
                    }
                }
            }
        }
        // fullScreenCover ana görünümün tint'ini devralmıyor; buton marka renginde olsun
        .tint(theme.brandPrimary)
    }

    // MARK: - Hero
    private var heroCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.brandPrimary)
                    .frame(width: 72, height: 72)

                Image(systemName: "crown.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(theme.onBrandPrimary)
            }

            VStack(spacing: 8) {
                Text("Finvo Pro")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(theme.labelPrimary)

                Text(isPro
                     ? "Pro üyeliğiniz aktif. Tüm özellikler sizin için açık."
                     : "Ailenizle paylaşımlı cüzdanlar oluşturun, bütçenizi sınırsız şekilde beraber yönetin.")
                    .font(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if isPro {
                Label("Aktif", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.brandPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }

    // MARK: - Ücretsiz / Pro Karşılaştırma
    private var comparisonCard: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("Ücretsiz")
                    .frame(width: 64)
                Text("Pro")
                    .foregroundStyle(theme.brandPrimary)
                    .frame(width: 64)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(theme.labelSecondary)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)

            ForEach(Array(planFeatures.enumerated()), id: \.element.id) { index, feature in
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(feature.color)
                            .frame(width: 36, height: 36)
                        Image(systemName: feature.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text(LocalizedStringKey(feature.title))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.labelPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    planValue(feature.free, included: false)
                        .frame(width: 64)
                    planValue(feature.pro, included: true)
                        .frame(width: 64)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                if index < planFeatures.count - 1 {
                    Divider()
                        .padding(.leading, 62)
                        .padding(.trailing, 16)
                }
            }
        }
        .padding(.bottom, 8)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func planValue(_ value: String?, included: Bool) -> some View {
        if let value {
            Text(LocalizedStringKey(value))
                .font(.footnote.weight(included ? .bold : .regular))
                .foregroundStyle(included ? theme.brandPrimary : theme.labelSecondary)
                .lineLimit(1)
        } else if included {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(theme.brandPrimary)
        } else {
            Image(systemName: "minus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.labelSecondary.opacity(0.6))
        }
    }

    // MARK: - Avantajlar
    private var benefitsCard: some View {
        VStack(spacing: 0) {
            benefitRow(icon: "person.3.fill", color: .orange, title: "Sınırsız Aile Üyesi", subtitle: "Ailenizdeki herkesi ortak cüzdanlara davet edin.")
            benefitDivider
            benefitRow(icon: "shield.lefthalf.filled", color: .green, title: "Rol ve Yetki Yönetimi", subtitle: "Üyelere Görme, Ekleme veya Yönetici yetkileri atayın.")
            benefitDivider
            benefitRow(icon: "chart.pie.fill", color: .blue, title: "Gelişmiş Analizler", subtitle: "Ailenizin toplam finansal durumunu detaylı şekilde görün.")
        }
        .padding(.vertical, 6)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }

    private var benefitDivider: some View {
        Divider()
            .padding(.leading, 62)
            .padding(.trailing, 16)
    }

    private func benefitRow(icon: String, color: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        ListItem(icon: icon, iconColor: color, title: title, subtitle: subtitle)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }

    // MARK: - Alt Buton
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if isPro {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    dismiss()
                } label: {
                    Text("Tamam")
                        .font(.headline)
                        .foregroundStyle(theme.onBrandPrimary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glassProminent)
                .clipShape(Capsule())
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    // TODO: Gerçek satın alma akışı (StoreKit / RevenueCat) bağlanınca değiştirilecek
                    if let url = URL(string: "https://apps.apple.com") {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                        Text("Aboneliği Başlat")
                    }
                    .font(.headline)
                    .foregroundStyle(theme.onBrandPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glassProminent)
                .clipShape(Capsule())

                Text("Aylık yenilenir. İstediğiniz zaman iptal edebilirsiniz.")
                    .font(.caption2)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

#Preview {
    ProSubscriptionPaywallView()
        .environment(\.theme, DefaultTheme())
}
