import SwiftUI

enum QuickDataType: String, CaseIterable {
    case categories = "Kategoriler"
    case debts = "Borçlar"
    case wallets = "Cüzdanlar"
    case limits = "Limitler"
    case savings = "Birikimler"
    case recurring = "Tekrarlayan"
    
    var icon: String {
        switch self {
        case .categories: return "square.grid.2x2"
        case .debts: return "creditcard"
        case .wallets: return "wallet.bifold"
        case .limits: return "doc.text"
        case .savings: return "lanyardcard"
        case .recurring: return "repeat.circle"
        }
    }
}

// Hızlı İşlemler Görünümü
struct QuickActionRowView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(QuickDataType.allCases, id: \.self) { type in
                    NavigationLink {
                        destinationView(for: type)
                    } label: {
                        actionContent(icon: type.icon, title: LocalizedStringKey(type.rawValue))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .scrollClipDisabled()
    }
    
    @ViewBuilder
    private func destinationView(for type: QuickDataType) -> some View {
        switch type {
        case .categories: CategoriesListView()
            .environmentObject(walletManager)
            .environmentObject(authManager)
            .environmentObject(transactionManager)
        case .debts: DebtsView().environmentObject(walletManager).environmentObject(authManager).environmentObject(transactionManager)
        case .wallets: WalletsView().environmentObject(walletManager).environmentObject(authManager)
        case .limits: LimitsView().environmentObject(walletManager).environmentObject(authManager)
        case .savings: SavingsView().environmentObject(walletManager).environmentObject(authManager).environmentObject(transactionManager)
        case .recurring: RecurringTransactionsView().environmentObject(walletManager).environmentObject(authManager).environmentObject(transactionManager)
        }
    }
    
    @ViewBuilder
    private func actionContent(icon: String, title: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(theme.labelPrimary)
                    .frame(width: 64, height: 64)
                    .glassEffect(in: .rect(cornerRadius: 20.0))
            }
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.labelPrimary)
        }
    }
}

struct QuickActionRowView_Previews: PreviewProvider {
    static var previews: some View {
        QuickActionRowView()
            .environmentObject(TransactionManager())
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
