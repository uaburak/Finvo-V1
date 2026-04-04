import SwiftUI
import FirebaseAuth

struct SummaryView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var transactionManager: TransactionManager
    @State private var showCreateWalletSheet = false
    @State private var showSettings = false
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Mavi Bakiye Kartı
                    BalanceCardView()
                        .padding(.horizontal)
                    
                    // Gelir / Gider Alanı
                    HStack(spacing: 16) {
                        NavigationLink {
                            TransactionsView(selectedType: .income)
                                .environmentObject(walletManager)
                                .environmentObject(authManager)
                                .environmentObject(transactionManager)
                        } label: {
                            IncomeExpenseCardView(title: "Gelir", amount: "\(appCurrency.symbol)\(transactionManager.totalIncome.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))", isIncome: true)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink {
                            TransactionsView(selectedType: .expense)
                                .environmentObject(walletManager)
                                .environmentObject(authManager)
                                .environmentObject(transactionManager)
                        } label: {
                            IncomeExpenseCardView(title: "Gider", amount: "\(appCurrency.symbol)\(transactionManager.totalExpense.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))", isIncome: false)
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
            .onAppear {
                if let walletId = walletManager.activeWallet?.id {
                    transactionManager.startListening(walletId: walletId)
                    CategoryManager.shared.startListening(walletId: walletId)
                }
            }
            .onChange(of: walletManager.activeWallet) { _, newValue in
                if let walletId = newValue?.id {
                    transactionManager.startListening(walletId: walletId)
                    CategoryManager.shared.startListening(walletId: walletId)
                } else {
                    transactionManager.stopListening()
                    CategoryManager.shared.stopListening()
                }
            }
            .navigationDestination(for: TransactionModel.self) { transaction in
                TransactionDetailView(transaction: transaction)
                    .environmentObject(walletManager)
                    .environmentObject(authManager)
            }
            .navigationDestination(for: TransactionType.self) { type in
                TransactionsView(selectedType: type)
                    .environmentObject(walletManager)
                    .environmentObject(authManager)
                    .environmentObject(transactionManager)
            }
        }
    }
    
    @ToolbarContentBuilder
    private func summaryToolbar() -> some ToolbarContent {
        // Sol Bölüm (Bildirim / Notification)
        ToolbarItem(placement: .navigationBarLeading) {
            NavigationLink(destination: NotificationsView()
                .environmentObject(notificationManager)
                .environmentObject(walletManager)
            ) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 16))
                        .foregroundColor(theme.labelPrimary)
                    
                    if !notificationManager.notifications.isEmpty {
                        Circle()
                            .fill(theme.expense)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
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

#Preview {
    SummaryView()
        .environment(\.theme, DefaultTheme())
        .environmentObject(WalletManager())
        .environmentObject(NotificationManager())
        .environmentObject(TransactionManager())
}
