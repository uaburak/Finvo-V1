import SwiftUI

struct CurrencySelectionSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    
    @Binding var selectedCurrency: CurrencyType
    @State private var searchText = ""
    
    var filteredCurrencies: [CurrencyType] {
        let allowedFiatCodes = ["TRY", "USD", "EUR", "GBP", "CHF", "CAD", "RUB"]
        let baseList = exchangeRateManager.allCurrencies.filter { allowedFiatCodes.contains($0.code) }
        if searchText.isEmpty {
            return baseList.sorted { $0.name < $1.name }
        } else {
            return baseList.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) || 
                $0.code.localizedCaseInsensitiveContains(searchText) 
            }.sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCurrencies) { currency in
                    Button {
                        selectedCurrency = currency
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(width: 36, height: 36)
                                
                                Image(systemName: currency.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.labelPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LocalizedStringKey(currency.name))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.labelPrimary)
                                
                                Text(currency.code)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.labelSecondary)
                            }
                            
                            Spacer()
                            
                            if selectedCurrency == currency {
                                Image(systemName: "checkmark")
                                    .foregroundColor(theme.brandPrimary)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Para Birimi Ara (Dolar, Euro vb.)")
            .navigationTitle("Para Birimi Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
    }
}
