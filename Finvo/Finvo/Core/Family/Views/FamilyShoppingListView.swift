import SwiftUI

struct FamilyShoppingListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @StateObject private var viewModel = FamilyShoppingViewModel()
    @State private var newItemTitle: String = ""
    @State private var newItemAmount: String = ""
    
    var pendingItems: [ShoppingItemModel] {
        viewModel.items.filter { !$0.isPurchased }
    }
    
    var purchasedItems: [ShoppingItemModel] {
        viewModel.items.filter { $0.isPurchased }
    }
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Eklenti Alanı (Quick Add)
                quickAddSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.items.isEmpty {
                            emptyStateView
                        } else {
                            // Alınacaklar
                            if !pendingItems.isEmpty {
                                shoppingListSection(title: "Alınacaklar", items: pendingItems)
                            }
                            
                            // Tamamlananlar
                            if !purchasedItems.isEmpty {
                                shoppingListSection(title: "Alınanlar", items: purchasedItems, isMuted: true)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Ailenin Alışveriş Listesi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let walletId = walletManager.activeWallet?.id {
                viewModel.fetchItems(for: walletId)
            }
        }
    }
    
    // MARK: - Sections
    
    private var quickAddSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                TextField("Ne alınacak?", text: $newItemTitle)
                    .font(.body)
                    .padding()
                    .background(theme.background2.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                TextField("Tutar (Ops..)", text: $newItemAmount)
                    .keyboardType(.decimalPad)
                    .font(.body)
                    .frame(width: 100)
                    .padding()
                    .background(theme.background2.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button {
                guard !newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty,
                      let walletId = walletManager.activeWallet?.id,
                      let username = authManager.currentUserProfile?.username else { return }
                
                let amount = Double(newItemAmount.replacingOccurrences(of: ",", with: "."))
                viewModel.addItem(title: newItemTitle, amount: amount, walletId: walletId, username: username)
                
                // Formu temizle
                newItemTitle = ""
                newItemAmount = ""
                
            } label: {
                Text("Ekle")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(theme.onBrandPrimary)
                    .background(theme.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(newItemTitle.isEmpty)
            .opacity(newItemTitle.isEmpty ? 0.6 : 1.0)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 0))
    }
    
    @ViewBuilder
    private func shoppingListSection(title: String, items: [ShoppingItemModel], isMuted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isMuted ? theme.labelSecondary : theme.labelPrimary)
                .padding(.horizontal)
            
            ForEach(items) { item in
                HStack(spacing: 16) {
                    // Checkbox
                    Button {
                        viewModel.toggleItem(item)
                    } label: {
                        Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(item.isPurchased ? .green : theme.separator)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isMuted ? theme.labelSecondary : theme.labelPrimary)
                            .strikethrough(item.isPurchased)
                        
                        HStack {
                            Text("Ekleyen: \(item.addedBy)")
                            if let amount = item.estimatedAmount {
                                Text(" • Ykl: ₺\(amount.formatted(.number.precision(.fractionLength(0))))")
                                    .foregroundStyle(theme.brandPrimary)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(theme.labelSecondary)
                    }
                    
                    Spacer()
                    
                    // Silme Butonu
                    Button {
                        viewModel.deleteItem(item)
                    } label: {
                        Image(systemName: "trash")
                            .tint(.red.opacity(0.8))
                    }
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(theme.brandPrimary.opacity(0.5))
            
            Text("Liste Tertemiz!")
                .font(.title3.bold())
                .foregroundStyle(theme.labelPrimary)
            
            Text("Yukarıdan aileniz için alınması gerekenleri listeye ekleyebilirsiniz.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.labelSecondary)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    NavigationView {
        FamilyShoppingListView()
            .environment(\.theme, DefaultTheme())
            .environmentObject(WalletManager())
            .environmentObject(AuthenticationManager.shared)
    }
}
