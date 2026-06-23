import SwiftUI

struct SavingsDepositSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    
    let onComplete: (String, CurrencyType, Bool) -> Void
    
    enum Step {
        case direction  // Para Ekle / Para Çıkar
        case type       // Para (fiat) / Değerli Maden
        case asset      // Varlık listesi
        case amount     // Miktar girişi
    }
    
    enum DepositType {
        case fiat   // Döviz (TRY, USD, EUR...)
        case metal  // Değerli Maden (Altın, Gümüş...)
    }
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    @State private var currentStep: Step = .direction
    @State private var isAdding: Bool = true
    @State private var depositType: DepositType?
    @State private var selectedAsset: CurrencyType?
    @State private var amount: String = ""
    @State private var searchText = ""
    @State private var selectedDetent: PresentationDetent = .height(280)
    
    var filteredAssets: [CurrencyType] {
        guard let type = depositType else { return [] }
        var list: [CurrencyType] = []
        if type == .fiat {
            let allowedFiatCodes = ["TRY", "USD", "EUR", "GBP", "CHF", "CAD", "RUB"]
            list = exchangeRateManager.allCurrencies.filter { allowedFiatCodes.contains($0.code) }
        } else {
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
                case .direction:
                    directionSelectionView
                case .type:
                    typeSelectionView
                case .asset:
                    assetSelectionView
                case .amount:
                    amountInputView
                }
            }
            .navigationTitle(LocalizedStringKey(navTitleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep != .direction {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .fontWeight(.bold)
                                .foregroundStyle(theme.labelPrimary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                            .foregroundStyle(theme.labelPrimary)
                    }
                }
            }
        }
        .presentationDetents([.height(280), .height(350), .medium], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(.clear)
    }
    
    var navTitleKey: String {
        switch currentStep {
        case .direction: return L10n("İşlem Yap")
        case .type:   return isAdding ? L10n("Para Ekle") : L10n("Para Çıkar")
        case .asset:  return depositType == .fiat ? "Döviz Seç" : "Maden Seç"
        case .amount: return "Miktar Girin"
        }
    }
    
    private func goBack() {
        switch currentStep {
        case .amount:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDetent = .medium }
            currentStep = .asset
        case .asset:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDetent = .height(280) }
            currentStep = .type
        case .type:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDetent = .height(280) }
            currentStep = .direction
        case .direction:
            break
        }
    }
    
    // MARK: - Step 0: Para Ekle / Para Çıkar
    private var directionSelectionView: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            SelectionCard(
                title: L10n("Para Ekle"),
                icon: "arrow.down.circle.fill",
                color: theme.income
            ) {
                UISelectionFeedbackGenerator().selectionChanged()
                isAdding = true
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDetent = .height(280) }
                currentStep = .type
            }
            SelectionCard(
                title: L10n("Para Çıkar"),
                icon: "arrow.up.circle.fill",
                color: theme.expense
            ) {
                UISelectionFeedbackGenerator().selectionChanged()
                isAdding = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDetent = .height(280) }
                currentStep = .type
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Step 1: Para / Değerli Maden
    private var typeSelectionView: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            SelectionCard(
                title: isAdding ? L10n("Para Ekle") : L10n("Para Çıkar"),
                icon: "banknote.fill",
                color: isAdding ? theme.income : theme.expense
            ) {
                UISelectionFeedbackGenerator().selectionChanged()
                depositType = .fiat
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDetent = .medium }
                currentStep = .asset
            }
            
            SelectionCard(
                title: "Değerli Maden",
                icon: "medal.fill",
                color: .orange
            ) {
                UISelectionFeedbackGenerator().selectionChanged()
                depositType = .metal
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDetent = .medium }
                currentStep = .asset
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
    
    // MARK: - Step 2: Varlık Listesi
    private var assetSelectionView: some View {
        List {
            ForEach(filteredAssets) { currency in
                Button {
                    selectedAsset = currency
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selectedDetent = .height(350) }
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
                            Text(LocalizedStringKey(currency.name))
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
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(theme.separator)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: LocalizedStringKey("Varlık Ara"))
    }
    
    // MARK: - Step 3: Miktar
    private var amountInputView: some View {
        VStack(spacing: 24) {
            if let asset = selectedAsset {
                HStack {
                    Text(LocalizedStringKey("Seçilen Varlık:"))
                        .foregroundColor(theme.labelSecondary)
                    Spacer()
                    Text("\(asset.name.localized) (\(asset.code))")
                        .fontWeight(.semibold)
                        .foregroundColor(theme.labelPrimary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            
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
            
            HStack(spacing: 16) {
                Button { adjustAmount(by: -50) } label: {
                    Text("-50").fontWeight(.bold).foregroundStyle(theme.expense).frame(maxWidth: .infinity, minHeight: 48)
                }.buttonStyle(.glass)
                Button { adjustAmount(by: 50) } label: {
                    Text("+50").fontWeight(.bold).foregroundStyle(theme.income).frame(maxWidth: .infinity, minHeight: 48)
                }.buttonStyle(.glass)
            }
            .padding(.horizontal, 16)
            
            Button {
                if !amount.isEmpty, let validAsset = selectedAsset {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onComplete(amount, validAsset, isAdding)
                    dismiss()
                }
            } label: {
                Text(LocalizedStringKey(isAdding ? "Ekle" : "Çıkar"))
                    .font(.headline)
                    .foregroundStyle(theme.onBrandPrimary)
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
            if let parsed = Double(normalized) { current = parsed }
            current += value
            if current < 0 { current = 0 }
            amount = current == 0 ? "" : String(format: "%.0f", current)
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
