import SwiftUI

struct CreateSavingsAccountSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @State private var accountName: String = ""
    @State private var goalAmount: String = ""
    @State private var selectedColor: String = "blue"
    
    let availableColors: [(name: String, value: Color, hex: String)] = [
        ("Mavi", .blue, "blue"),
        ("Yeşil", .green, "green"),
        ("Mor", .purple, "purple"),
        ("Turuncu", .orange, "orange"),
        ("Kırmızı", .red, "red"),
        ("Camgöbeği", .mint, "mint")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(spacing: 24) {
                        // Birikim İsmi - Capsule & Başlıksız
                        TextField("Birikim Adı (Örn: Araç Peşinatı)", text: $accountName)
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
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.prepare()
                        
                        createAccount()
                        
                        feedback.impactOccurred()
                    } label: {
                        Text("Oluştur")
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
            .navigationTitle("Yeni Birikim Hesabı")
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
        }
    }
    
    private var selectedSwiftColor: Color {
        availableColors.first(where: { $0.hex == selectedColor })?.value ?? .blue
    }
    
    private func createAccount() {
        guard let wallet = walletManager.activeWallet else { return }
        
        let target = Double(goalAmount.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        guard target > 0 else { return }
        
        let newAccount = SavingsAccountModel(
            name: accountName,
            goalAmount: target,
            color: selectedColor
        )
        
        var updatedWallet = wallet
        if updatedWallet.savingsAccounts == nil {
            updatedWallet.savingsAccounts = []
        }
        updatedWallet.savingsAccounts?.append(newAccount)
        
        // Firestore'a kaydet (WalletManager tetikleyecek)
        walletManager.updateWallet(updatedWallet)
        
        dismiss()
    }
}
