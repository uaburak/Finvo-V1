import SwiftUI

struct FamilyShoppingListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency

    @StateObject private var viewModel = FamilyShoppingViewModel()
    @State private var newItemTitle: String = ""
    @State private var newItemAmount: String = ""
    @FocusState private var isTitleFocused: Bool

    var pendingItems: [ShoppingItemModel]   { viewModel.items.filter { !$0.isPurchased } }
    var purchasedItems: [ShoppingItemModel] { viewModel.items.filter { $0.isPurchased } }

    private let stickyHeight: CGFloat = 160

    var body: some View {
        ZStack(alignment: .top) {
            theme.background1.ignoresSafeArea()

            // MARK: - List
            Group {
                if viewModel.isLoading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if viewModel.items.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    List {
                        // Alınacaklar
                        if !pendingItems.isEmpty {
                            sectionHeader(title: "Alınacaklar".localized, count: pendingItems.count)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            ForEach(Array(pendingItems.enumerated()), id: \.element.id) { index, item in
                                shoppingRow(item: item, isFirst: index == 0)
                            }
                        }

                        // Alınanlar
                        if !purchasedItems.isEmpty {
                            sectionHeader(title: "Alınanlar".localized, count: purchasedItems.count)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            ForEach(Array(purchasedItems.enumerated()), id: \.element.id) { index, item in
                                shoppingRow(item: item, isFirst: index == 0)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .safeAreaInset(edge: .top) {
                        Color.clear.frame(height: stickyHeight)
                    }
                    .safeAreaPadding(.bottom, 40)
                }
            }

            // MARK: - Sticky (Input Panel + Stats Banner)
            VStack(spacing: 12) {
                // Input Panel
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "cart")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.labelSecondary)
                        TextField("Ne alınacak?".localized, text: $newItemTitle)
                            .font(.body)
                            .focused($isTitleFocused)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .glassEffect(in: .capsule)

                    HStack(spacing: 6) {
                        Text(appCurrency.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.labelSecondary)
                        TextField("Tutar".localized, text: $newItemAmount)
                            .keyboardType(.decimalPad)
                            .font(.body)
                            .frame(width: 52)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .glassEffect(in: .capsule)

                    Button { addItem() } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty ? theme.labelSecondary.opacity(0.5) : theme.brandPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 20)

                // Stats Banner
                HStack(spacing: 0) {
                    statCell(value: "\(viewModel.items.count)", label: "Toplam".localized)
                    Divider().frame(height: 28)
                    statCell(value: "\(pendingItems.count)", label: "Alınacak".localized)
                    Divider().frame(height: 28)
                    statCell(value: "\(purchasedItems.count)", label: "Alınan".localized)
                    Divider().frame(height: 28)
                    statCell(value: "\(appCurrency.symbol)\(viewModel.totalEstimatedAmount.formatted(.number.precision(.fractionLength(0))))", label: "Tutar".localized)
                }
                .padding(.vertical, 10)
                .glassEffect(in: .capsule)
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 0)
            }
            .padding(.top, 8)
        }
        .navigationTitle("Alışveriş Listesi".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let walletId = walletManager.activeWallet?.id { viewModel.fetchItems(for: walletId) }
        }
        .onDisappear { viewModel.stopListening() }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).foregroundStyle(theme.labelPrimary).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(theme.labelSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func shoppingRow(item: ShoppingItemModel, isFirst: Bool) -> some View {
        HStack(spacing: 14) {
            // Checkbox
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(item.isPurchased ? Color.green : theme.background2)
                    .frame(width: 26, height: 26)
                if item.isPurchased {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(theme.onBrandPrimary)
                } else {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(theme.separator, lineWidth: 1.5).frame(width: 26, height: 26)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.toggleItem(item) }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.labelPrimary)
                    .strikethrough(item.isPurchased, color: theme.labelSecondary)
                    .lineLimit(2)

                Text("Ekleyen: %@".localized(with: item.addedBy))
                    .font(.caption2)
                    .foregroundStyle(theme.labelSecondary)
            }
            Spacer()
            
            HStack(spacing: 12) {
                if let amount = item.estimatedAmount {
                    Text("\(appCurrency.symbol)\(amount.formatted(.number.precision(.fractionLength(0))))")
                        .font(.caption.bold())
                        .foregroundStyle(item.isPurchased ? theme.labelSecondary : theme.brandPrimary)
                }
                Button { viewModel.deleteItem(item) } label: {
                    Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading)
        .listRowInsets(EdgeInsets(top: 14, leading: 6, bottom: 14, trailing: 20))
        .listRowSeparator(.visible)
        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
        .listRowBackground(Color.clear)
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(theme.labelSecondary)
            Spacer()
            Text("%d ürün".localized(with: count)).font(.footnote).foregroundStyle(theme.labelSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cart.badge.plus").font(.system(size: 56)).foregroundStyle(theme.brandPrimary.opacity(0.5))
            Text("Liste Tertemiz!".localized).font(.title3.bold()).foregroundStyle(theme.labelPrimary)
            Text("Yukarıdan aileniz için alınması gerekenleri listeye ekleyebilirsiniz.".localized).font(.subheadline).multilineTextAlignment(.center).foregroundStyle(theme.labelSecondary).padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private func addItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, let walletId = walletManager.activeWallet?.id, let username = authManager.currentUserProfile?.username else { return }
        let amount = Double(newItemAmount.replacingOccurrences(of: ",", with: "."))
        viewModel.addItem(title: title, amount: amount, walletId: walletId, username: username)
        newItemTitle = ""; newItemAmount = ""; isTitleFocused = false
    }
}
