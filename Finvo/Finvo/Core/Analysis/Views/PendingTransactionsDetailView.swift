import SwiftUI

struct PendingTransactionsDetailView: View {
    @Environment(\.theme) var theme
    let transactions: [TransactionModel]
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            if transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.green)
                    Text("Ödenmemiş borç veya bekleyen işlem yok.")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Top Header
                        let total = transactions.reduce(0) { $0 + $1.amount }
                        VStack(spacing: 8) {
                            Text("Toplam Bekleyen")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                            Text("₺\(total.formatted(.number.precision(.fractionLength(0))))")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(theme.expense)
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: .rect(cornerRadius: 24))
                        .padding(.horizontal, 20)
                        
                        // List
                        VStack(spacing: 12) {
                            HStack {
                                Text("İşlemler (\(transactions.count))")
                                    .font(.title3.bold())
                                    .foregroundColor(theme.labelPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            ForEach(transactions) { tx in
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(theme.expense.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: tx.categoryIcon)
                                            .font(.title3)
                                            .foregroundColor(theme.expense)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text((tx.note ?? "").isEmpty ? tx.mainCategoryName : tx.note!)
                                            .font(.headline)
                                            .foregroundColor(theme.labelPrimary)
                                        Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundColor(theme.labelSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(tx.type == .income ? "+" : "-")₺\(tx.amount.formatted(.number.precision(.fractionLength(0))))")
                                        .font(.headline.bold())
                                        .foregroundColor(theme.labelPrimary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .glassEffect(in: .rect(cornerRadius: 20))
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 16)
                    .safeAreaPadding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Bekleyen İşlemler")
        .navigationBarTitleDisplayMode(.inline)
    }
}
