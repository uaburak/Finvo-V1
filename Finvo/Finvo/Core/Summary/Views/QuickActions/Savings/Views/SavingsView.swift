import SwiftUI

struct SavingsView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @State private var showCreateSheet = false
    @State private var selectedAccount: SavingsAccountModel?
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    // Yardımcı Func: Hesabın rengini Hex->Color veya isim->"Color" olarak çöz
    private func getSwiftColor(from stringRaw: String) -> Color {
        switch stringRaw.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "mint": return .mint
        default: return theme.brandPrimary
        }
    }
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            let savings = walletManager.activeWallet?.savingsAccounts ?? []
            
            if savings.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 70))
                        .foregroundColor(theme.labelSecondary)
                    
                    Text("Birikim Hesabınız Yok")
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text("Araba, tatil veya acil durum fonu gibi hedefleriniz için farklı birikim hesapları oluşturabilirsiniz.")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button {
                        showCreateSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Yeni Hesap Oluştur")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 10)
                    .padding(.horizontal, 30)
                    
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(savings) { account in
                            NavigationLink(destination: SavingsAccountDetailView(account: account)) {
                                savingsCard(for: account)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .safeAreaPadding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Birikimler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !(walletManager.activeWallet?.savingsAccounts?.isEmpty ?? true) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(theme.labelPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateSavingsAccountSheet()
                .environmentObject(walletManager)
                .environmentObject(authManager)
                .environmentObject(transactionManager)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
    }
    
    @ViewBuilder
    private func savingsCard(for account: SavingsAccountModel) -> some View {
        let cardColor = getSwiftColor(from: account.color)
        
        // Dinamik Varlık (Bakiye) Hesaplaması
        let totalBalanceInAppCurrency: Double = account.assets?.reduce(0.0) { sum, assetKV in
            let curr = CurrencyType(rawValue: assetKV.key) ?? .tryCurrency
            return sum + ExchangeRateManager.shared.convert(amount: assetKV.value, from: curr, to: appCurrency)
        } ?? 0.0
        
        // Dinamik Hedef Hesaplaması
        let goalCurr = CurrencyType(rawValue: account.goalCurrency ?? "") ?? .tryCurrency
        let dynamicGoalAmount = ExchangeRateManager.shared.convert(amount: account.goalAmount, from: goalCurr, to: appCurrency)
        
        let progressRaw = dynamicGoalAmount > 0 ? (totalBalanceInAppCurrency / dynamicGoalAmount) : 0.0
        let progress = min(max(progressRaw, 0.0), 1.0)
        
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(cardColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "lanyardcard.fill")
                    .foregroundColor(cardColor)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(account.name)
                    .font(.headline)
                    .foregroundColor(theme.labelPrimary)
                    .lineLimit(1)
                
                HStack {
                    Text("\(appCurrency.symbol)\(totalBalanceInAppCurrency.formatted(.number.precision(.fractionLength(0))))")
                        .font(.subheadline.bold())
                        .foregroundColor(cardColor)
                    
                    Text("/ \(appCurrency.symbol)\(dynamicGoalAmount.formatted(.number.precision(.fractionLength(0))))")
                        .font(.caption)
                        .foregroundColor(theme.labelSecondary)
                }
                
                // Mini Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.separatorSecondary)
                        Capsule().fill(cardColor)
                            .frame(width: max(0, min(CGFloat(progress) * geo.size.width, geo.size.width)))
                    }
                }
                .frame(height: 6)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(theme.labelSecondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

#Preview {
    NavigationStack {
        SavingsView()
            .environmentObject(WalletManager())
            .environment(\.theme, DefaultTheme())
    }
}
