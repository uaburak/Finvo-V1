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
        
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.debtContact ?? debt.mainCategoryName)
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text("Toplam: ₺\(debt.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(theme.cardBackground, lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(theme.expense, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(paid))/\(Int(total))")
                        .font(.caption.bold())
                }
                .frame(width: 48, height: 48)
            }
            
            Divider()
            
            // Checklists (Taksitler)
            VStack(spacing: 12) {
                let totalCount = debt.totalInstallments ?? 0
                let paidCount = debt.paidInstallments ?? 0
                
                ForEach(0..<totalCount, id: \.self) { index in
                    let isPaid = index < paidCount
                    let isNext = index == paidCount
                    
                    HStack {
                        Image(systemName: isPaid ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isPaid ? .green : (isNext ? theme.brandPrimary : .secondary))
                            .font(.system(size: 20))
                        
                        Text("\(index + 1). Taksit")
                            .font(.subheadline)
                            .foregroundColor(isPaid ? .secondary : theme.labelPrimary)
                            .strikethrough(isPaid)
                        
                        Spacer()
                        
                        if isNext {
                            Button("Öde") {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                payInstallment(debt)
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.brandPrimary)
                            .clipShape(Capsule())
                            .disabled(isPaying)
                        } else if isPaid {
                            Text("Ödendi")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
    
    private func payInstallment(_ debt: TransactionModel) {
        let username = authManager.currentUserProfile?.username ?? "unknown"
        isPaying = true
        
        Task {
            do {
                try await transactionManager.payDebtInstallment(for: debt, currentUsername: username)
                await MainActor.run {
                    isPaying = false
                }
            } catch {
                await MainActor.run {
                    isPaying = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DebtsView()
    }
}
