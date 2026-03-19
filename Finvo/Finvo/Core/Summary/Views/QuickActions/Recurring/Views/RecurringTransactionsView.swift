import SwiftUI

// MARK: - Mock Models
struct RecurringTransactionModel: Identifiable {
    let id = UUID()
    let title: String
    let amount: Double
    let type: TransactionType
    let frequency: String
    let nextDate: Date
}

@Observable
class RecurringTransactionsViewModel {
    var autoTransactions: [RecurringTransactionModel] = [
        RecurringTransactionModel(title: "Netflix Aboneliği", amount: 120.0, type: .expense, frequency: "Aylık", nextDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!),
        RecurringTransactionModel(title: "Maaş (Düzenli)", amount: 35000.0, type: .income, frequency: "Aylık", nextDate: Calendar.current.date(byAdding: .day, value: 12, to: Date())!),
        RecurringTransactionModel(title: "Spor Salonu", amount: 450.0, type: .expense, frequency: "Aylık", nextDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!)
    ]
}

struct RecurringTransactionsView: View {
    @Environment(\.theme) var theme
    @State private var viewModel = RecurringTransactionsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.autoTransactions.isEmpty {
                    ContentUnavailableView("Kayıtlı İşlem Yok", systemImage: "repeat", description: Text("Düzenli tekrar eden bir işlem bulunmuyor."))
                } else {
                    ForEach(viewModel.autoTransactions) { transaction in
                        recurringCard(for: transaction)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Abonelikler ve Düzenli İşlemler")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func recurringCard(for transaction: RecurringTransactionModel) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(transaction.type == .income ? theme.income.opacity(0.1) : theme.expense.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "repeat")
                    .foregroundColor(transaction.type == .income ? theme.income : theme.expense)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.headline)
                    .foregroundColor(theme.labelPrimary)
                
                Text("\(transaction.frequency) - Sonraki Eğitim: \(transaction.nextDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text((transaction.type == .income ? "+₺" : "-₺") + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))
                .font(.subheadline.bold())
                .foregroundColor(transaction.type == .income ? theme.income : theme.expense)
        }
        .padding()
        .background(theme.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
    }
}

#Preview {
    NavigationStack {
        RecurringTransactionsView()
    }
}
