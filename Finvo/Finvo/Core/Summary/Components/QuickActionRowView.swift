import SwiftUI

enum QuickDataType: String, CaseIterable {
    case categories = "Kategoriler"
    case debts = "Borçlar"
    case wallets = "Cüzdanlar"
    case savings = "Birikimler"
    case limits = "Limitler"
    case recurring = "Tekrarlayan"
    case marketRates = "Kurlar"
    case paymentCalendar = "Ödeme Takvimi"
    
    var icon: String {
        switch self {
        case .categories: return "square.grid.2x2"
        case .debts: return "creditcard"
        case .wallets: return "wallet.bifold"
        case .savings: return "lanyardcard"
        case .limits: return "chart.bar.xaxis"
        case .recurring: return "repeat.circle"
        case .marketRates: return "globe.europe.africa.fill"
        case .paymentCalendar: return "calendar.badge.clock"
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
        case .savings: SavingsView().environmentObject(walletManager).environmentObject(authManager).environmentObject(transactionManager)
        case .limits: LimitsView().environmentObject(walletManager).environmentObject(authManager).environmentObject(transactionManager)
        case .recurring: RecurringTransactionsView().environmentObject(walletManager).environmentObject(authManager).environmentObject(transactionManager)
        case .marketRates: ExchangeRatesDetailView()
        case .paymentCalendar:
            let allPayments = transactionManager.transactions
                .filter { $0.isDebt || $0.isRecurring }
                .flatMap { $0.allPaymentOccurrences() }
                .sorted { $0.date < $1.date }
            PaymentCalendarDetailView(upcomingPayments: allPayments)
                .environmentObject(walletManager)
                .environmentObject(authManager)
                .environmentObject(transactionManager)
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
