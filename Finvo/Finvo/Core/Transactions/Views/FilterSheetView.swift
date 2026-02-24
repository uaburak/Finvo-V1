import SwiftUI

// MARK: - Filter Models

struct TransactionFilter: Equatable {
    var selectedPeriod: FilterPeriod = .all
    var selectedCategories: Set<FilterCategory> = []
    var minAmount: Double? = nil
    var maxAmount: Double? = nil

    var isActive: Bool {
        selectedPeriod != .all || !selectedCategories.isEmpty || minAmount != nil || maxAmount != nil
    }
}

enum FilterPeriod: String, CaseIterable, Identifiable {
    case all   = "Tümü"
    case today = "Bugün"
    case week  = "Bu Hafta"
    case month = "Bu Ay"
    case year  = "Bu Yıl"
    var id: String { rawValue }
}

enum FilterCategory: String, CaseIterable, Identifiable {
    case market    = "Market"
    case kafe      = "Kafe"
    case abonelik  = "Abonelikler"
    case maas      = "Maaş"
    case freelance = "Freelance"
    case fatura    = "Faturalar"
    case alisveris = "Alışveriş"
    case nakit     = "Nakit İadesi"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .market:    return "cart.fill"
        case .kafe:      return "cup.and.saucer.fill"
        case .abonelik:  return "play.tv.fill"
        case .maas:      return "briefcase.fill"
        case .freelance: return "laptopcomputer"
        case .fatura:    return "drop.fill"
        case .alisveris: return "bag.fill"
        case .nakit:     return "arrow.triangle.swap"
        }
    }

    var color: Color {
        switch self {
        case .market:    return .blue
        case .kafe:      return .brown
        case .abonelik:  return .red
        case .maas:      return .green
        case .freelance: return .purple
        case .fatura:    return .cyan
        case .alisveris: return .orange
        case .nakit:     return .orange
        }
    }
}

// MARK: - FilterMenuView

struct FilterMenuView: View {
    @Binding var filter: TransactionFilter
    @Binding var isShowing: Bool

    @State private var local: TransactionFilter

    init(filter: Binding<TransactionFilter>, isShowing: Binding<Bool>) {
        self._filter = filter
        self._isShowing = isShowing
        self._local = State(initialValue: filter.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Header
            HStack {
                Text("Filtrele")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                if local.isActive {
                    Button("Sıfırla") {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            local = TransactionFilter()
                        }
                    }
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 10)

            // MARK: Dönem
            VStack(alignment: .leading, spacing: 6) {
                Text("Dönem")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(FilterPeriod.allCases) { p in
                            MenuPill(label: p.rawValue, isSelected: local.selectedPeriod == p) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                                    local.selectedPeriod = p
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 10)

            // MARK: Kategori
            VStack(alignment: .leading, spacing: 6) {
                Text("Kategori")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(FilterCategory.allCases) { cat in
                            MenuCategoryPill(
                                category: cat,
                                isSelected: local.selectedCategories.contains(cat)
                            ) {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                                    if local.selectedCategories.contains(cat) {
                                        local.selectedCategories.remove(cat)
                                    } else {
                                        local.selectedCategories.insert(cat)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 10)

            // MARK: Miktar
            VStack(alignment: .leading, spacing: 6) {
                Text("Miktar Aralığı")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    CompactAmountField(placeholder: "Min ₺", value: $local.minAmount)
                    Text("–").foregroundStyle(.secondary)
                    CompactAmountField(placeholder: "Max ₺", value: $local.maxAmount)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 10)

            // MARK: Apply
            Button {
                filter = local
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isShowing = false
                }
            } label: {
                Text("Uygula")
                    .font(.subheadline).fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.14), radius: 20, y: 6)
        )
    }
}

// MARK: - Pill sub-views

private struct MenuPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption).fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }
}

private struct MenuCategoryPill: View {
    let category: FilterCategory
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? .white : category.color)
                Text(category.rawValue)
                    .font(.caption).fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? category.color : Color(uiColor: .tertiarySystemFill))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: isSelected)
    }
}

private struct CompactAmountField: View {
    let placeholder: String
    @Binding var value: Double?
    @State private var text = ""
    var body: some View {
        TextField(placeholder, text: $text)
            .font(.caption)
            .keyboardType(.decimalPad)
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
            .onChange(of: text) { _, v in
                value = Double(v.replacingOccurrences(of: ",", with: "."))
            }
            .onAppear { if let v = value { text = String(v) } }
    }
}
