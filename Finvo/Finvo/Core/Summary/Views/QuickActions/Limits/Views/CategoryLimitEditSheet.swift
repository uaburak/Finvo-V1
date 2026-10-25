import SwiftUI

/// Kategori limiti düzenleyicisinin hedefi: categoryId nil ise yeni limit eklenir
struct CategoryLimitEditorTarget: Identifiable {
    let categoryId: String?
    var id: String { categoryId ?? "new" }
}

struct CategoryLimitEditSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @ObservedObject private var categoryManager = CategoryManager.shared
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency

    let target: CategoryLimitEditorTarget

    @State private var selectedCategoryId: String?
    @State private var amountText: String = ""

    private var isEditing: Bool { target.categoryId != nil }

    private var existingLimits: [String: CategoryLimitModel] {
        walletManager.activeWallet?.categoryLimits ?? [:]
    }

    /// Seçilebilir gider kategorileri (yeni eklemede limiti olmayanlar)
    private var selectableCategories: [CategoryModel] {
        (categoryManager.categories.isEmpty ? CategoriesMockData.data : categoryManager.categories)
            .filter { $0.type == .expense && $0.isOn }
            .filter { isEditing ? $0.id == target.categoryId : existingLimits[$0.id] == nil }
    }

    private var selectedCategory: CategoryModel? {
        selectableCategories.first(where: { $0.id == selectedCategoryId })
    }

    private var parsedAmount: Double { AmountInput.parse(amountText) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Kategori seçimi
                Menu {
                    ForEach(selectableCategories) { category in
                        Button {
                            selectedCategoryId = category.id
                        } label: {
                            Label(category.name.localized, systemImage: category.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let category = selectedCategory {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(category.uiColor)
                                    .frame(width: 36, height: 36)
                                Image(systemName: category.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(category.localizedName)
                                .font(.headline)
                                .foregroundStyle(theme.labelPrimary)
                        } else {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(theme.brandPrimary)
                                .frame(width: 36, height: 36)
                            Text("Kategori Seçin")
                                .font(.headline)
                                .foregroundStyle(theme.labelSecondary)
                        }
                        Spacer()
                        if !isEditing {
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.labelSecondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(in: .rect(cornerRadius: 20))
                }
                .disabled(isEditing)

                // Tutar
                HStack {
                    Text(appCurrency.symbol)
                        .foregroundStyle(theme.labelSecondary)
                    TextField("Aylık Limit", text: Binding(
                        get: { amountText.isEmpty ? "" : AmountInput.display(amountText) },
                        set: { amountText = AmountInput.raw(fromEdited: $0, previousRaw: amountText) }
                    ))
                    .keyboardType(.decimalPad)
                    .foregroundStyle(theme.labelPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.separator, lineWidth: 1))

                HStack(spacing: 12) {
                    if isEditing {
                        Button(role: .destructive) {
                            save(amount: nil)
                        } label: {
                            Text("Limiti Kaldır")
                                .font(.headline)
                                .foregroundStyle(theme.expense)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.glass)
                        .clipShape(Capsule())
                    }

                    Button {
                        save(amount: parsedAmount)
                    } label: {
                        Text(L10n("Kaydet"))
                            .font(.headline)
                            .foregroundStyle(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .clipShape(Capsule())
                    .disabled(selectedCategoryId == nil || parsedAmount <= 0)
                    .opacity(selectedCategoryId == nil || parsedAmount <= 0 ? 0.6 : 1)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(isEditing ? "Kategori Limitini Düzenle" : "Kategori Limiti Ekle")
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
            .background(theme.background1.ignoresSafeArea())
        }
        .tint(theme.brandPrimary)
        .onAppear {
            selectedCategoryId = target.categoryId
            if let id = target.categoryId, let limit = existingLimits[id] {
                let limitCurrency = CurrencyType(rawValue: limit.currency) ?? .tryCurrency
                let converted = ExchangeRateManager.shared.convert(amount: limit.amount, from: limitCurrency, to: appCurrency)
                amountText = AmountInput.string(from: converted.rounded())
            }
        }
    }

    private func save(amount: Double?) {
        guard var wallet = walletManager.activeWallet, let categoryId = selectedCategoryId else { return }
        var limits = wallet.categoryLimits ?? [:]
        if let amount, amount > 0 {
            limits[categoryId] = CategoryLimitModel(amount: amount, currency: appCurrency.rawValue)
        } else {
            limits.removeValue(forKey: categoryId)
        }
        wallet.categoryLimits = limits
        walletManager.updateWallet(wallet)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
