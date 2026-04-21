import SwiftUI

struct ExchangeRatesDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    
    @State private var searchText = ""
    
    var filteredCurrencies: [CurrencyType] {
        var baseList = exchangeRateManager.allCurrencies
        
        if !searchText.isEmpty {
            baseList = baseList.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) || 
                $0.code.localizedCaseInsensitiveContains(searchText) 
            }
        }
        
        let priorityMap: [String: Int] = ["TRY": 0, "USD": 1, "EUR": 2]
        
        return baseList.sorted { a, b in
            let aPriority = priorityMap[a.code] ?? 99
            let bPriority = priorityMap[b.code] ?? 99
            
            if aPriority != bPriority {
                return aPriority < bPriority
            }
            return a.name < b.name
        }
    }
    
    var body: some View {
        let currentFilteredCurrencies = filteredCurrencies
        let firstCurrencyId = currentFilteredCurrencies.first?.id
        
        VStack(spacing: 0) {
            List {
                ForEach(currentFilteredCurrencies) { currency in
                    if let data = exchangeRateManager.marketData[currency] {
                        let isFirst = currency.id == firstCurrencyId
                        let isPositive = data.change.starts(with: "%-") == false && data.change != "%0,00"
                        let resolvedColor = isPositive ? theme.brandPrimary : theme.expense
                        
                        ListItem(
                            icon: currency.icon,
                            iconColor: Color(UIColor.systemGray5),
                            title: LocalizedStringKey("\(currency.name) ( \(currency.code) )"),
                            subtitle: LocalizedStringKey(currency.assetType),
                            value: data.sell.formatted(.number.precision(.fractionLength(2))),
                            valueColor: resolvedColor,
                            secondaryInfo: data.change,
                            secondaryInfoColor: resolvedColor,
                            iconForegroundColor: theme.labelPrimary
                        )
                        .padding(.leading)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                        .listRowSeparator(.visible)
                        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                        .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
                        .listRowBackground(theme.background1)
                    }
                }
            }
            .listStyle(.plain)
            .background(theme.background1)
            .searchable(text: $searchText, prompt: "Döviz, Borsa veya Maden Ara")
        }
        .navigationTitle("Tüm Kurlar")
        .navigationBarTitleDisplayMode(.inline)
    }
}
