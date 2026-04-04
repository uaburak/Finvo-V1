import SwiftUI

// MARK: - Debts View
struct DebtsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var isPaying = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var activeDebts: [TransactionModel] {
        transactionManager.transactions.filter { $0.isDebt && !$0.isPaid }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if activeDebts.isEmpty {
                    ContentUnavailableView("Kayıtlı Borç Yok", systemImage: "checkmark.seal", description: Text("Tüm borçlarınızı sıfırladınız."))
                } else {
                    ForEach(activeDebts) { debt in
                        debtCard(for: debt)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Borçlar ve Taksitler")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ödeme Hatası", isPresented: $showingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private func debtCard(for debt: TransactionModel) -> some View {
        let total = Double(debt.totalInstallments ?? 1)
        let paid = Double(debt.paidInstallments ?? 0)
        let progress = paid / total
        
        NavigationLink(destination: DebtDetailView(debt: debt)) {
            HStack(spacing: 16) {
                // Icon / Avatar
                ZStack {
                    Circle()
                        .fill(theme.expense.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(theme.expense)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.debtContact ?? debt.mainCategoryName)
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text("₺\(debt.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                        .font(.subheadline.bold())
                        .foregroundColor(theme.labelSecondary)
                }
                
                Spacer()
                
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(theme.separatorSecondary.opacity(0.2), lineWidth: 3)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(theme.expense, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: -2) {
                        Text("\(Int(paid))/\(Int(total))")
                            .font(.system(size: 10, weight: .bold))
                        Text("Taksit")
                            .font(.system(size: 6))
                            .textCase(.uppercase)
                    }
                    .foregroundColor(theme.labelSecondary)
                }
                .frame(width: 44, height: 44)
            }
            .padding(16)
            .contentShape(Rectangle())
            .glassEffect(in: .rect(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        DebtsView()
    }
}
