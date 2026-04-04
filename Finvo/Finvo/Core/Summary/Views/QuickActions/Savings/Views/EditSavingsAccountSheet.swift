import SwiftUI

struct EditSavingsAccountSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    let account: SavingsAccountModel
    
    @State private var accountName: String
    @State private var goalAmount: String
    @State private var selectedColor: String
    
    let availableColors: [(name: String, value: Color, hex: String)] = [
        ("Mavi", .blue, "blue"),
        ("Yeşil", .green, "green"),
        ("Mor", .purple, "purple"),
        ("Turuncu", .orange, "orange"),
        ("Kırmızı", .red, "red"),
        ("Camgöbeği", .mint, "mint")
    ]
    
    init(account: SavingsAccountModel) {
        self.account = account
        _accountName = State(initialValue: account.name)
        _goalAmount = State(initialValue: String(format: "%.0f", account.goalAmount))
        _selectedColor = State(initialValue: account.color)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(spacing: 24) {
                        // Birikim İsmi - Capsule & Başlıksız
                        TextField("Birikim Adı", text: $accountName)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                        
                        // Hedef Tutar - Capsule & Başlıksız
                        TextField("Hedef Tutar (₺)", text: $goalAmount)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                        
                        // Renk Seçimi - Daha Sade
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Hesap Rengi")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                                .padding(.leading, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(availableColors, id: \.hex) { color in
                                        Circle()
                                            .fill(color.value)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: selectedColor == color.hex ? 3 : 0)
                                                    .padding(2)
                                            )
                                            .shadow(color: color.value.opacity(0.3), radius: selectedColor == color.hex ? 8 : 0)
                                            .onTapGesture {
                                                withAnimation(.spring) {
                                                    selectedColor = color.hex
                                                }
                                            }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.top, 10)

                    Button {
                        updateAccount()
                    } label: {
                        Text("Değişiklikleri Kaydet")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 24)
                    .disabled(accountName.isEmpty || goalAmount.isEmpty)
                    .opacity((accountName.isEmpty || goalAmount.isEmpty) ? 0.6 : 1.0)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
            }
            .navigationTitle("Birikimi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("İptal") {
                        dismiss()
                    }
                    .foregroundStyle(theme.labelPrimary)
                }
            }
        }
    }
    
    private func updateAccount() {
        guard let wallet = walletManager.activeWallet else { return }
        let target = Double(goalAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        guard target > 0 else { return }
        
        var updatedWallet = wallet
        if var accounts = updatedWallet.savingsAccounts,
           let idx = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[idx].name = accountName
            accounts[idx].goalAmount = target
            accounts[idx].color = selectedColor
            updatedWallet.savingsAccounts = accounts
            
            walletManager.updateWallet(updatedWallet)
        }
        
        dismiss()
    }
}
