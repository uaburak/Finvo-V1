import SwiftUI

struct SavingsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @State private var showCreateSheet = false
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    private func cardColor(for account: SavingsAccountModel) -> Color {
        switch account.color.lowercased() {
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
        let savings = walletManager.activeWallet?.savingsAccounts ?? []
        
        Group {
            if savings.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(savings) { account in
                        ZStack {
                            NavigationLink(destination: SavingsAccountDetailView(account: account)
                                .environmentObject(walletManager)
                                .environmentObject(authManager)
                                .environmentObject(transactionManager)
                            ) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            savingsRow(for: account)
                        }
                        .listRowBackground(theme.cardBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background1.ignoresSafeArea())
        .navigationTitle("Birikimler")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.labelPrimary)
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
    
    // MARK: - Empty State
    private var emptyStateView: some View {
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
    }
    
    // MARK: - Row
    @ViewBuilder
    private func savingsRow(for account: SavingsAccountModel) -> some View {
        let color = cardColor(for: account)
        let totalBalance: Double = account.assets?.reduce(0.0) { sum, kv in
            let curr = CurrencyType(rawValue: kv.key) ?? .tryCurrency
            return sum + ExchangeRateManager.shared.convert(amount: kv.value, from: curr, to: appCurrency)
        } ?? 0.0
        let goalCurr = CurrencyType(rawValue: account.goalCurrency ?? "") ?? .tryCurrency
        let goalAmount = ExchangeRateManager.shared.convert(amount: account.goalAmount, from: goalCurr, to: appCurrency)
        let balanceStr = totalBalance.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
        let goalStr = goalAmount.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
        let pct = goalAmount > 0 ? Int(min((totalBalance / goalAmount) * 100, 100)) : 0
        
        HStack(spacing: 16) {
            // ListItem-style icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color)
                    .frame(width: 36, height: 36)
                Image(systemName: "lanyardcard.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body.weight(.medium))
                    .foregroundColor(theme.labelPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("\(appCurrency.symbol)\(balanceStr)")
                        .font(.caption.bold())
                        .foregroundColor(color)
                    Text("/ \(appCurrency.symbol)\(goalStr)")
                        .font(.caption)
                        .foregroundColor(theme.labelSecondary)
                }
            }
            
            Spacer()
            
            Text("%\(pct)")
                .font(.caption.bold())
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        SavingsView()
            .environmentObject(WalletManager())
            .environment(\.theme, DefaultTheme())
    }
}
