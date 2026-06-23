import SwiftUI

struct EditWalletSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    
    let wallet: WalletModel
    
    @State private var walletName: String
    @State private var selectedType: WalletType
    @State private var selectedContext: WalletContext
    @State private var showDeleteAlert = false
    
    init(wallet: WalletModel) {
        self.wallet = wallet
        _walletName = State(initialValue: wallet.name)
        _selectedType = State(initialValue: wallet.type)
        _selectedContext = State(initialValue: wallet.context)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(spacing: 24) {
                        
                        // Cüzdan İsmi
                        TextField("Cüzdan Adı", text: $walletName)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                        
                        // Cüzdan Tipi
                        Picker("Cüzdan Tipi", selection: $selectedType) {
                            ForEach(WalletType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        
                        // Kullanım Amacı
                        Picker(L10n("Kullanım Amacı"), selection: $selectedContext) {
                            ForEach(WalletContext.allCases, id: \.self) { context in
                                Text(context.title).tag(context)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        
                    }
                    .padding(.top, 10)

                    Button {
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.prepare()
                        guard !walletName.isEmpty else { return }
                        
                        var updatedWallet = wallet
                        updatedWallet.name = walletName
                        updatedWallet.type = selectedType
                        updatedWallet.context = selectedContext
                        
                        walletManager.updateWallet(updatedWallet)
                        
                        feedback.impactOccurred()
                        dismiss()
                    } label: {
                        Text(L10n("Kaydet"))
                            .font(.headline)
                            .foregroundStyle(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 24)
                    .disabled(walletName.isEmpty)
                    .opacity(walletName.isEmpty ? 0.6 : 1.0)
                    
                    // Silme Butonu (En az 1 cüzdan kalması şartıyla)
                    if walletManager.wallets.count > 1 {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            Text("Cüzdanı Sil")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(theme.expense)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
            }
            .navigationTitle("Cüzdanı Düzenle")
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
            .alert("Cüzdanı Sil", isPresented: $showDeleteAlert) {
                Button(L10n("İptal"), role: .cancel) { }
                Button(L10n("Sil"), role: .destructive) {
                    if let id = wallet.id {
                        walletManager.deleteWallet(id: id)
                    }
                    dismiss()
                }
            } message: {
                Text("Bu cüzdanı silmek istediğinize emin misiniz? (Şimdilik mock veridir)")
            }
        }
    }
}
