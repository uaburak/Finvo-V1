import SwiftUI
import FirebaseAuth

struct SummaryView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showCreateWalletSheet = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Mavi Bakiye Kartı
                    BalanceCardView()
                        .padding(.horizontal)
                    
                    // Gelir / Gider Alanı
                    HStack(spacing: 16) {
                        NavigationLink(destination: TransactionsView(selectedType: .income)) {
                            IncomeExpenseCardView(title: "Gelir", amount: "₺0,00", isIncome: true)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: TransactionsView(selectedType: .expense)) {
                            IncomeExpenseCardView(title: "Gider", amount: "₺0,00", isIncome: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    // Hızlı Butonlar Alanı
                    QuickActionRowView()

                    // Esnek 4'lü Metrik Kartları
                    SummaryMetricsGridView()
                        .padding(.horizontal)
                }
                // Mavi kart ve Gelir/Gider HStack'i için padding'i doğrudan içeri taşıdık,
                // Hızlı butonların ekran kenarına kadar kayabilmesi için VStack'deki yatay paddingi kaldırıyoruz.
            }
            .safeAreaPadding(.bottom, 120)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .scrollBounceBehavior(.always, axes: .vertical)
            .navigationTitle(walletManager.activeWallet?.name ?? "Cüzdan Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                ForEach(walletManager.wallets) { wallet in
                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        walletManager.selectWallet(wallet)
                    } label: {
                        HStack {
                            Text(wallet.name)
                            if walletManager.activeWallet?.id == wallet.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    // _UIReparentingView hatasını önlemek için Menü kapandıktan sonra sheet'i açıyoruz
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        showCreateWalletSheet = true
                    }
                } label: {
                    Label("Yeni Cüzdan Oluştur", systemImage: "plus.circle")
                }
            }
            .toolbar {
                summaryToolbar()
            }
            .sheet(isPresented: $showCreateWalletSheet) {
                CreateWalletSheet()
                    .presentationDetents([.medium, .height(500)])
                    .presentationBackground(.clear)
                    .presentationDragIndicator(.hidden)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
    
    @ToolbarContentBuilder
    private func summaryToolbar() -> some ToolbarContent {
        // Sol Bölüm (Bildirim / Notification)
        ToolbarItem(placement: .navigationBarLeading) {
            NavigationLink(destination: NotificationsView()) {
                Image(systemName: "bell")
                    .font(.system(size: 16))
                    .foregroundColor(theme.labelPrimary)
            }
        }
        
        // Orta Bölüm (Wallet Switcher) yerine Native Navigation Title ve Title Menu
        // (Bunu .toolbar parantezinin dışında navigation modifier'ı olarak çağırırdık ama
        // SwiftUI 16'da TitleMenu destekleniyor. Önceki principal item'ı siliyoruz)
        // Sağ Bölüm (Profil / Avatar)
        ToolbarItem(placement: .topBarTrailing) {
            ProfileImageView(photoURL: authManager.user?.photoURL)
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSettings = true
                }
        }
    }
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView()
    }
}
