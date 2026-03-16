//
//  AddTransactionsView.swift
//  Finvo
//

import SwiftUI

struct AddTransactionsView: View {
    @Environment(\.theme) var theme

    @State private var selectedType: TransactionType = .expense
    @State private var selectedMainCategory: CategoryModel?
    @State private var selectedSubCategory: SubCategoryModel?
    @State private var selectedDate: Date = Date()
    @State private var amount: String = ""
    @State private var selectedWallet: String = "Ana Cüzdan"
    @State private var activeSheet: ActiveSheet?

    enum ActiveSheet: Identifiable {
        case category, date, wallet, amount
        var id: Int { hashValue }
    }

    private var categoryRowValue: LocalizedStringKey {
        if let sub = selectedSubCategory { return sub.name }
        if let main = selectedMainCategory { return main.name }
        return "Seçin"
    }

    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Yeni İşlem")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(theme.labelPrimary)
                        Text("Harcamalarını veya gelirlerini kaydet.")
                            .font(.subheadline)
                            .foregroundStyle(theme.labelSecondary)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // MARK: Form
                    VStack(spacing: 0) {
                        Picker("İşlem Türü", selection: Binding(
                            get: { selectedType },
                            set: { v in
                                UISelectionFeedbackGenerator().selectionChanged()
                                withAnimation(.spring()) {
                                    selectedType = v
                                    selectedMainCategory = nil
                                    selectedSubCategory = nil
                                }
                            }
                        )) {
                            Text("Gider").tag(TransactionType.expense)
                            Text("Gelir").tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        .padding(.top, 20)
                        .padding(.horizontal, 16)

                        VStack(spacing: 0) {
                            formRow("square.grid.2x2", "Kategori", categoryRowValue) { activeSheet = .category }

                            Divider().padding(.leading, 56)
                            formRow("calendar", "Tarih", LocalizedStringKey(selectedDate.formatted(date: .long, time: .omitted))) { activeSheet = .date }

                            Divider().padding(.leading, 56)
                            formRow("creditcard", "Cüzdan", LocalizedStringKey(selectedWallet)) { activeSheet = .wallet }

                            Divider().padding(.leading, 56)
                            formRow("turkishlirasign.circle", "Tutar", LocalizedStringKey(amount.isEmpty ? "0,00 ₺" : "₺\(amount)")) { activeSheet = .amount }
                        }
                        .padding(.top, 8)

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Text("Kaydet")
                                .font(.headline).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(theme.brandPrimary)
                                .clipShape(Capsule())
                        }
                        .padding(16)
                    }
                    .glassEffect(in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 16)

                   
                    let recentItems = Array(TransactionsMockData.items.prefix(3))
                    List {
                        ForEach(recentItems) { item in
                            let isFirst = item.id == recentItems.first?.id
                            ListItem(
                                icon: item.icon,
                                iconColor: item.color,
                                title: item.title,
                                subtitle: item.subtitle,
                                value: (item.type == .income ? "+₺" : "-₺") + String(format: "%.2f", item.amount),
                                valueColor: item.type == .income ? theme.income : theme.expense,
                                secondaryInfo: item.date
                            )
                            .padding(.leading)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { } label: {
                                    Image(systemName: "trash")
                                }.tint(.red)
                                Button { } label: {
                                    Image(systemName: "pencil")
                                }.tint(.orange)
                            }
                            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                            .listRowSeparator(.visible)
                            .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                            .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
                        }
                    }
                    .listStyle(.plain)
                    .frame(height: 3 * 80)
                    .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(theme.brandPrimary)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(theme.labelSecondary)], for: .normal)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .category:
                CategorySelectionSheet(
                    categories: CategoriesMockData.data.filter { $0.type == selectedType },
                    selectedMainCategory: $selectedMainCategory,
                    selectedSubCategory: $selectedSubCategory
                )
            case .date:
                TransactionDatePickerSheet(selection: $selectedDate)
                    .presentationDetents([.height(500)])
            case .wallet:
                WalletSelectionSheet(selectedWallet: $selectedWallet)
                    .presentationDetents([.medium])
            case .amount:
                AmountInputSheet(amount: $amount)
                    .presentationDetents([.height(350)])
            }
        }
    }

    private func formRow(_ icon: String, _ title: String, _ value: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(theme.brandPrimary)
                    .frame(width: 24)
                Text(title).foregroundStyle(theme.labelPrimary)
                Spacer()
                Text(value).foregroundStyle(theme.labelSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.separatorSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

#Preview {
    AddTransactionsView()
        .environment(\.theme, DefaultTheme())
}
