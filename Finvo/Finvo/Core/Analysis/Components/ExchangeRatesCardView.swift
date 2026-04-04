import SwiftUI

struct ExchangeRatesCardView: View {
    @Environment(\.theme) var theme
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Piyasa Kurları (TCMB)")
                .font(.headline)
                .foregroundColor(theme.labelPrimary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(CurrencyType.allCases.filter { $0 != appCurrency }, id: \.self) { currency in
                        // Seçili ana para birimine karşılık değeri
                        let rate = exchangeRateManager.convert(amount: 1, from: currency, to: appCurrency)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(currency.rawValue)
                                    .font(.subheadline.bold())
                                    .foregroundColor(theme.labelSecondary)
                                Spacer()
                                Image(systemName: getIcon(for: currency))
                                    .font(.subheadline)
                                    .foregroundColor(theme.brandPrimary)
                                    .padding(8)
                                    .background(theme.background2)
                                    .clipShape(Circle())
                            }
                            
                            Text("\(appCurrency.symbol)\(rate.formatted(.number.precision(.fractionLength(2))))")
                                .font(.title3.bold())
                                .foregroundColor(theme.labelPrimary)
                        }
                        .padding(16)
                        .frame(width: 140)
                        .background(Color.white.opacity(0.05))
                        .glassEffect(in: .rect(cornerRadius: 20))
                        // .overlay(RoundedRectangle(cornerRadius: 20).stroke(theme.separator, lineWidth: 1))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
    
    private func getIcon(for currency: CurrencyType) -> String {
        switch currency {
        case .tryCurrency: return "turkishlirasign"
        case .usd: return "dollarsign"
        case .eur: return "eurosign"
        case .gold: return "medal.fill"
        default: return "globe"
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ExchangeRatesCardView()
            .environment(\.theme, DefaultTheme())
    }
}
