import SwiftUI

struct CreateWalletSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var walletName: String = ""
    @State private var selectedType: WalletType = .personal
    @State private var selectedContext: WalletContext = .general
    
    @State private var showLimitAlert = false
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(spacing: 24) {
                        
                        // Cüzdan İsmi - Tam Yuvarlak (Capsule) & Başlıksız
                        TextField("Cüzdan Adı", text: $walletName)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                        
                        // Cüzdan Tipi - Başlıksız & Daha Büyük Segmented Control
                        Picker("Cüzdan Tipi", selection: $selectedType) {
                            ForEach(WalletType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        
                        // Kullanım Amacı - Başlıksız & Daha Büyük Segmented Control
                        Picker("Kullanım Amacı", selection: $selectedContext) {
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
                        
                        if let user = authManager.currentUserProfile, !user.isPro {
                            let ownedWallets = walletManager.wallets.filter { $0.ownerId == user.username }
                            let isOverTotalLimit = ownedWallets.count >= 2
                            let isOverSharedLimit = selectedType == .shared && ownedWallets.contains(where: { $0.type == .shared })
                            
                            if isOverTotalLimit || isOverSharedLimit {
                                showLimitAlert = true
                                return
                            }
                        }
                        
                        // Cüzdanı oluştur
                        walletManager.createWallet(
                            name: walletName,
                            type: selectedType,
                            context: selectedContext
                        )
                        
                        feedback.impactOccurred()
                        dismiss()
                    } label: {
                        Text("Oluştur")
                            .font(.headline)
                            .foregroundStyle(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 24)
                    .disabled(walletName.isEmpty)
                    .opacity(walletName.isEmpty ? 0.6 : 1.0)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
            }
            .navigationTitle("Yeni Cüzdan")
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
        .alert("Pro Yükseltmesi Gerekli", isPresented: $showLimitAlert) {
            Button("Pro Ol") {
                showPaywall = true
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            if selectedType == .shared && walletManager.wallets.contains(where: { $0.ownerId == authManager.currentUserProfile?.username && $0.type == .shared }) {
                Text("En fazla 1 adet paylaşımlı cüzdan oluşturabilirsiniz. Daha fazlası için Pro'ya geçin.")
            } else {
                Text("Ücretsiz sürümde en fazla 2 adet cüzdan oluşturabilirsiniz. Daha fazlası için Pro'ya geçin.")
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            ProSubscriptionPaywallView()
        }
    }
}

#Preview {
    CreateWalletSheet()
        .environment(\.theme, DefaultTheme())
        .environmentObject(WalletManager())
        .environmentObject(AuthenticationManager.shared)
}
