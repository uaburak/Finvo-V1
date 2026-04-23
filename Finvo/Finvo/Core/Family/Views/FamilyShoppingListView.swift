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

    private let stickyHeight: CGFloat = 96 // 8(top) + 76(content) + 12(gap)

    var body: some View {
        ZStack(alignment: .top) {
            theme.background1.ignoresSafeArea()

            // MARK: - List
            Group {
                if viewModel.isLoading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    List {
                        // Tahmini Toplam Banner
                        if viewModel.totalEstimatedAmount > 0 {
                            HStack {
                                Label("Yaklaşık Toplam", systemImage: "tag.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.labelSecondary)
                                Spacer()
                                Text("\(appCurrency.symbol)\(viewModel.totalEstimatedAmount.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(theme.brandPrimary)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }

                        // Alınacaklar
                        if !pendingItems.isEmpty {
                            sectionHeader(title: "Alınacaklar", count: pendingItems.count)
                            ForEach(Array(pendingItems.enumerated()), id: \.element.id) { index, item in
                                shoppingRow(item: item, isMuted: false, isFirst: index == 0)
                            }
                        }

                        // Alınanlar
                        if !purchasedItems.isEmpty {
                            sectionHeader(title: "Alınanlar", count: purchasedItems.count)
                            ForEach(Array(purchasedItems.enumerated()), id: \.element.id) { index, item in
                                shoppingRow(item: item, isMuted: true, isFirst: index == 0)
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

            // MARK: - Sticky Glass Input Panel
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "cart")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(theme.labelSecondary)
                        TextField("Ne alınacak?", text: $newItemTitle)
                            .font(.body)
                            .focused($isTitleFocused)
                    }
                    .padding(.horizontal, 14).frame(height: 46)
                    .glassEffect(in: .capsule)

                    HStack(spacing: 6) {
                        Text(appCurrency.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.labelSecondary)
                        TextField("Tutar", text: $newItemAmount)
                            .keyboardType(.decimalPad)
                            .font(.body)
                            .frame(width: 60)
                    }
                    .padding(.horizontal, 12).frame(height: 46)
                    .glassEffect(in: .capsule)

                    Button {
                        addItem()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty ? theme.labelSecondary : theme.brandPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 20)
                
                // İstenen 12px boşluk
                Spacer().frame(height: 12)
            }
            .padding(.top, 8)
        }
        .navigationTitle("Ailenin Alışveriş Listesi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let walletId = walletManager.activeWallet?.id { viewModel.fetchItems(for: walletId) }
        }
        .onDisappear { viewModel.stopListening() }
    }

    @ViewBuilder
    private func shoppingRow(item: ShoppingItemModel, isMuted: Bool, isFirst: Bool) -> some View {
        ZStack {
            Button { viewModel.toggleItem(item) } label: { EmptyView() }.opacity(0)
            ListItem(
                icon: item.isPurchased ? "checkmark.circle.fill" : "circle",
                iconColor: item.isPurchased ? Color.green : theme.brandPrimary,
                title: LocalizedStringKey(item.title),
                subtitle: LocalizedStringKey("Ekleyen: \(item.addedBy)"),
                value: item.estimatedAmount.map { "\(appCurrency.symbol)\($0.formatted(.number.precision(.fractionLength(0))))" },
                valueColor: isMuted ? theme.labelSecondary : theme.brandPrimary,
                customTrailingView: AnyView(HStack(spacing: 12) {
                    if let amount = item.estimatedAmount { Text("\(appCurrency.symbol)\(amount.formatted(.number.precision(.fractionLength(0))))").font(.system(size: 14, weight: .bold)).foregroundStyle(isMuted ? theme.labelSecondary : theme.brandPrimary) }
                    Button { viewModel.deleteItem(item) } label: { Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(.red.opacity(0.7)) }.buttonStyle(.plain)
                })
            )
            .padding(.leading).contentShape(Rectangle()).onTapGesture { viewModel.toggleItem(item) }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
        .listRowSeparator(.visible)
        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
        .listRowBackground(Color.clear)
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(theme.labelSecondary)
            Spacer()
            Text("\(count) ürün").font(.footnote).foregroundStyle(theme.labelSecondary)
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
            Spacer(); Image(systemName: "cart.badge.plus").font(.system(size: 56)).foregroundStyle(theme.brandPrimary.opacity(0.5))
            Text("Liste Tertemiz!").font(.title3.bold()).foregroundStyle(theme.labelPrimary)
            Text("Yukarıdan aileniz için alınması gerekenleri listeye ekleyebilirsiniz.").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(theme.labelSecondary).padding(.horizontal, 32); Spacer()
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
