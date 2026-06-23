import SwiftUI

struct ExchangeRatesListCard: View {
    @Environment(\.theme) var theme
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Piyasa Kurları")
                    .font(.headline)
                    .foregroundColor(theme.labelPrimary)
                Spacer()
                NavigationLink(destination: ExchangeRatesDetailView()) {
                    Text(L10n("Tümünü Gör"))
                        .font(.subheadline)
                        .foregroundColor(theme.brandPrimary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            HStack {
                Text("Birim")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Alış")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.labelSecondary)
                    .frame(width: 80, alignment: .trailing)
                Text("Satış")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.labelSecondary)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            
            Divider().background(theme.separator)
            
            let popularCodes = ["USD", "EUR", "GBP", "gram-altin", "gumus"]
            let filtered = exchangeRateManager.allCurrencies.filter { popularCodes.contains($0.code) }
            // Sıralamayı popularCodes dizisine göre yapalım
            let sorted = filtered.sorted { a, b in
                (popularCodes.firstIndex(of: a.code) ?? 99) < (popularCodes.firstIndex(of: b.code) ?? 99)
            }
            
            ForEach(sorted) { currency in
                if let data = exchangeRateManager.marketData[currency] {
                    HStack {
                        HStack(spacing: 8) {
                            Text(LocalizedStringKey(currency.name))
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(theme.labelPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(data.buy.formatted(.number.precision(.fractionLength(2))))
                            .font(.subheadline)
                            .foregroundColor(theme.labelPrimary)
                            .frame(width: 80, alignment: .trailing)
                        
                        Text(data.sell.formatted(.number.precision(.fractionLength(2))))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(theme.labelPrimary)
                            .frame(width: 80, alignment: .trailing)
                     }
                     .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}
