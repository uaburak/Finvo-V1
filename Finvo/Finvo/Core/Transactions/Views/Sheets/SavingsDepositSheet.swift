import SwiftUI

struct SavingsDepositSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    
    let isAdding: Bool
    let onComplete: (String, CurrencyType) -> Void
    
    enum Step {
        case category, asset, amount
    }
    
    enum AssetCategory: String {
        case fiat = "Döviz"
        case metal = "Değerli Maden"
    }
    
    @State private var currentStep: Step = .category
    @State private var selectedCategory: AssetCategory?
    @State private var selectedAsset: CurrencyType?
    @State private var amount: String = ""
    @State private var searchText = ""
    
    var filteredAssets: [CurrencyType] {
        guard let category = selectedCategory else { return [] }
        var list: [CurrencyType] = []
        
        if category == .fiat {
            let allowedFiatCodes = ["TRY", "USD", "EUR", "GBP", "CHF", "CAD", "RUB"]
            list = exchangeRateManager.allCurrencies.filter { allowedFiatCodes.contains($0.code) }
        } else {
            // Include Gold & Silver etc
            list = exchangeRateManager.allCurrencies.filter { $0.assetType != "Döviz" || $0.code.contains("altin") || $0.code.contains("gumus") }
        }
        
        if searchText.isEmpty {
            return list.sorted { $0.name < $1.name }
        } else {
            return list.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) || 
                $0.code.localizedCaseInsensitiveContains(searchText) 
            }.sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                switch currentStep {
                case .category:
                    categorySelectionView
                case .asset:
                    assetSelectionView
                case .amount:
                    amountInputView
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep != .category {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if currentStep == .amount { currentStep = .asset }
                            else if currentStep == .asset { currentStep = .category }
                        } label: {
                            Image(systemName: "chevron.left")
                                .fontWeight(.bold)
                                .foregroundStyle(theme.labelPrimary)
                        }
                    }
                }
                
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
        .presentationDetents(currentStep == .amount ? [.height(350)] : [.large])
        .presentationDragIndicator(.visible)
        // Background matching style
        .background(theme.background1)
    }
    
    var navTitle: String {
        switch currentStep {
        case .category: return "Varlık Türü"
        case .asset: return selectedCategory?.rawValue ?? "Varlık Seç"
        case .amount: return "Miktar Girin"
        }
    }
    
    // 1. Kategori Seçimi
    private var categorySelectionView: some View {
        VStack(spacing: 16) {
            Button {
                selectedCategory = .fiat
                currentStep = .asset
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "banknote")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    Text("Para Ekle (Döviz)")
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.labelSecondary)
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
            }
            
            Button {
                selectedCategory = .metal
                currentStep = .asset
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("Değerli Maden (Altın, Gümüş)")
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(theme.labelSecondary)
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
            }
            
            Spacer()
        }
        .padding(24)
    }
    
    // 2. Varlık Seçimi
    private var assetSelectionView: some View {
        VStack {
            List {
                ForEach(filteredAssets) { currency in
                    Button {
                        selectedAsset = currency
                        currentStep = .amount
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
                                Text(currency.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(theme.labelPrimary)
                                Text(currency.code)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.labelSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(theme.labelSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(theme.background1)
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Varlık Ara")
        }
    }
    
    // 3. Miktar
    private var amountInputView: some View {
        VStack(spacing: 24) {
            
            HStack {
                Text("Seçilen Varlık:")
                    .foregroundColor(theme.labelSecondary)
                Spacer()
                Text("\(selectedAsset?.name ?? "") (\(selectedAsset?.code ?? ""))")
                    .fontWeight(.semibold)
                    .foregroundColor(theme.labelPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            HStack(spacing: 16) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    adjustAmount(by: -1)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.expense)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.glass)
                
                ZStack {
                    Text(formatAmountText())
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.labelPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: amount)
                        .allowsHitTesting(false)
                    
                    TextField("", text: $amount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.clear)
                        .tint(theme.brandPrimary)
                }
                .frame(minWidth: 120)
                
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    adjustAmount(by: 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.income)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 16)
            
            if selectedCategory == .fiat {
                HStack(spacing: 16) {
                    Button { adjustAmount(by: -50) } label: { Text("-50").fontWeight(.bold).foregroundStyle(theme.expense).frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(.glass)
                    Button { adjustAmount(by: 50) } label: { Text("+50").fontWeight(.bold).foregroundStyle(theme.income).frame(maxWidth: .infinity, minHeight: 48) }.buttonStyle(.glass)
                }
                .padding(.horizontal, 16)
            }
            
            Button {
                if !amount.isEmpty, let validAsset = selectedAsset {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onComplete(amount, validAsset)
                    dismiss()
                }
            } label: {
                Text(isAdding ? "Ekle" : "Çıkar")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .disabled(amount.isEmpty)
        }
        .padding(.top, 8)
    }
    
    private func adjustAmount(by value: Double) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            var current: Double = 0
            let normalized = amount.replacingOccurrences(of: ",", with: ".")
            if let parsed = Double(normalized) {
                current = parsed
            }
            current += value
            if current < 0 { current = 0 }
            if current == 0 {
                amount = ""
            } else {
                amount = String(format: "%.0f", current)
            }
        }
    }
    
    private func formatAmountText() -> String {
        if amount.isEmpty { return "0" }
        let normalized = amount.replacingOccurrences(of: ",", with: ".")
        if let parsed = Double(normalized) {
            let hasDecimal = amount.contains(",") || amount.contains(".")
            if hasDecimal {
                let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
                let intPart = parts.first ?? ""
                let decPart = parts.count > 1 ? parts[1] : ""
                if let intVal = Double(intPart) {
                    let formattedInt = intVal.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
                    return "\(formattedInt),\(decPart)"
                }
            } else {
                return parsed.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
            }
        }
        return amount
    }
}
