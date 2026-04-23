import SwiftUI

struct WholesomeDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    let situation: WholesomeSituation
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Büyük İkon ve Başlık Kartı
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(theme.brandPrimary.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: situation.icon)
                            .font(.system(size: 50, weight: .black))
                            .foregroundStyle(theme.brandPrimary)
                            .shadow(color: theme.brandPrimary.opacity(0.3), radius: 10)
                    }
                    
                    VStack(spacing: 8) {
                        Text(situation.title)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(theme.labelPrimary)
                        
                        Text(situation.message)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(theme.labelSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.top, 20)
                
                // Kanıtlar Bölümü (Harçama Analizi)
                if !situation.stats.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(theme.brandPrimary)
                            Text("Verilerle Kanıtlar".localized)
                                .font(.headline.bold())
                                .foregroundStyle(theme.labelPrimary)
                        }
                        .padding(.horizontal)
                        
                        let sortedStats = situation.stats.sorted { $0.value > $1.value }
                        let maxAmount = sortedStats.first?.value ?? 1.0
                        
                        VStack(spacing: 16) {
                            ForEach(sortedStats, id: \.key) { user, amount in
                                HStack(spacing: 16) {
                                    MemberAvatarView(username: user, size: 44)
                                        .overlay(Circle().stroke(theme.separatorSecondary.opacity(0.5), lineWidth: 1))
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(user.capitalized)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(theme.labelPrimary)
                                            Spacer()
                                            Text("\(appCurrency.symbol)\(amount.formatted(.number.precision(.fractionLength(0))))")
                                                .font(.system(size: 16, weight: .heavy))
                                                .foregroundStyle(theme.labelPrimary)
                                        }
                                        
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(theme.separatorSecondary.opacity(0.2))
                                                    .frame(height: 8)
                                                
                                                Capsule()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [theme.brandPrimary, theme.brandPrimary.opacity(0.7)],
                                                            startPoint: .leading,
                                                            endPoint: .trailing
                                                        )
                                                    )
                                                    .frame(width: geo.size.width * CGFloat(amount / maxAmount), height: 8)
                                            }
                                        }
                                        .frame(height: 8)
                                    }
                                }
                                .padding(16)
                                .glassEffect(in: .rect(cornerRadius: 24))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Tavsiye Kartı
                VStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text("Finvo Tavsiyesi".localized)
                        .font(.headline.bold())
                    Text("Aile içi finansal dengeyi korumak için bu ayki harcamalarda biraz daha dengeli gitmek harika olabilir! 🤝".localized)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.labelSecondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassEffect(in: .rect(cornerRadius: 28))
                .padding(.horizontal)
                
                Spacer(minLength: 50)
            }
        }
        .background(theme.background1.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Durum Detayı".localized)
    }
}
