import SwiftUI

// MARK: - Mock Models
struct DebtModel: Identifiable {
    let id = UUID()
    let name: String
    let totalAmount: Double
    let totalInstallments: Int
    var paidInstallments: Int
    
    var progress: Double {
        return Double(paidInstallments) / Double(totalInstallments)
    }
}

@Observable
class DebtsViewModel {
    var activeDebts: [DebtModel] = [
        DebtModel(name: "KYK Kredisi", totalAmount: 12000, totalInstallments: 12, paidInstallments: 4),
        DebtModel(name: "MacBook Pro Taksidi", totalAmount: 45000, totalInstallments: 9, paidInstallments: 2)
    ]
    
    func payInstallment(for debtID: UUID) {
        if let index = activeDebts.firstIndex(where: { $0.id == debtID }) {
            if activeDebts[index].paidInstallments < activeDebts[index].totalInstallments {
                withAnimation {
                    activeDebts[index].paidInstallments += 1
                }
            }
        }
    }
}

// MARK: - Debts View
struct DebtsView: View {
    @Environment(\.theme) var theme
    @State private var viewModel = DebtsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.activeDebts.isEmpty {
                    ContentUnavailableView("Kayıtlı Borç Yok", systemImage: "checkmark.seal", description: Text("Tüm borçlarınızı sıfırladınız."))
                } else {
                    ForEach(viewModel.activeDebts) { debt in
                        debtCard(for: debt)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Borçlar ve Taksitler")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func debtCard(for debt: DebtModel) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(debt.name)
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text("Toplam: ₺\(debt.totalAmount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(theme.cardBackground, lineWidth: 4)
                    
                    Circle()
                        .trim(from: 0, to: debt.progress)
                        .stroke(theme.expense, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(debt.paidInstallments)/\(debt.totalInstallments)")
                        .font(.caption.bold())
                }
                .frame(width: 48, height: 48)
            }
            
            Divider()
            
            // Checklists (Taksitler)
            VStack(spacing: 12) {
                ForEach(0..<debt.totalInstallments, id: \.self) { index in
                    let isPaid = index < debt.paidInstallments
                    let isNext = index == debt.paidInstallments
                    
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
                                viewModel.payInstallment(for: debt.id)
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.brandPrimary)
                            .clipShape(Capsule())
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
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

#Preview {
    NavigationStack {
        DebtsView()
    }
}
