import SwiftUI

struct DebtsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    private var activeDebts: [TransactionModel] {
        transactionManager.transactions.filter { $0.isDebt && !$0.isPaid }
    }
    
    var body: some View {
        Group {
            if activeDebts.isEmpty {
                ZStack {
                    theme.background1.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(theme.labelSecondary)
                        Text("Kayıtlı Borç Yok")
                            .font(.headline)
                            .foregroundColor(theme.labelPrimary)
                        Text("Tüm borçlarınızı sıfırladınız.")
                            .font(.subheadline)
                            .foregroundColor(theme.labelSecondary)
                    }
                }
            } else {
                List {
                    ForEach(activeDebts) { debt in
                        ZStack {
                            NavigationLink(destination: DebtDetailView(debt: debt)
                                .environmentObject(transactionManager)
                                .environmentObject(authManager)
                            ) {
                                EmptyView()
                            }
                            .opacity(0)
                            
                            debtRow(for: debt)
                        }
                        .listRowBackground(theme.cardBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background1.ignoresSafeArea())
        .navigationTitle("Borçlar ve Taksitler")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func debtRow(for debt: TransactionModel) -> some View {
        let total = Double(debt.totalInstallments ?? 1)
        let paid = Double(debt.paidInstallments ?? 0)
        let progress = total > 0 ? paid / total : 0
        let pct = Int(progress * 100)
        
        HStack(spacing: 16) {
            // ListItem-style icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(theme.expense)
                    .frame(width: 36, height: 36)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(debt.debtContact ?? debt.mainCategoryName)
                    .font(.body.weight(.medium))
                    .foregroundColor(theme.labelPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text("\(debt.currency?.symbol ?? "₺")\(debt.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                        .font(.caption.bold())
                        .foregroundColor(theme.expense)
                    Text("• \(Int(paid))/\(Int(total)) taksit")
                        .font(.caption)
                        .foregroundColor(theme.labelSecondary)
                }
            }
            
            Spacer()
            
            // Yüzde badge
            Text("%\(pct)")
                .font(.caption.bold())
                .foregroundStyle(theme.expense)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.expense.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        DebtsView()
            .environmentObject(TransactionManager())
            .environment(\.theme, DefaultTheme())
    }
}
