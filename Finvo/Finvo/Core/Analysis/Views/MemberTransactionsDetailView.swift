import SwiftUI

struct MemberTransactionsDetailView: View {
    @Environment(\.theme) var theme
    let username: String
    let transactions: [TransactionModel]
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            if transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 48))
                        .foregroundColor(theme.labelSecondary)
                    Text("\(username) henüz işlem yapmadı.")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Header Profile Box
                        VStack(spacing: 12) {
                            MemberAvatarView(username: username, size: 80)
                            
                            Text(username)
                                .font(.title3.bold())
                                .foregroundColor(theme.labelPrimary)
                            
                            let total = transactions.reduce(0) { $0 + $1.amount }
                            Text("Hacim: ₺\(total.formatted(.number.precision(.fractionLength(0))))")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: .rect(cornerRadius: 24))
                        .padding(.horizontal, 20)
                        
                        // Category List (Sorted by Amount)
                        VStack(spacing: 12) {
                            HStack {
                                Text("Kategori Dağılımı")
                                    .font(.title3.bold())
                                    .foregroundColor(theme.labelPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            let grouped = Dictionary(grouping: transactions, by: { $0.mainCategoryName })
                            let categorySummaries = grouped.map { key, txs in
                                let total = txs.reduce(0) { $0 + $1.amount }
                                let icon = txs.first?.categoryIcon ?? "bag"
                                let type = txs.first?.type ?? .expense
                                return (name: key, amount: total, icon: icon, type: type, count: txs.count)
                            }.sorted(by: { $0.amount > $1.amount })
                            
                            ForEach(categorySummaries, id: \.name) { cat in
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(cat.type == .income ? theme.income.opacity(0.15) : theme.expense.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: cat.icon)
                                            .font(.title3)
                                            .foregroundColor(cat.type == .income ? theme.income : theme.expense)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cat.name)
                                            .font(.headline)
                                            .foregroundColor(theme.labelPrimary)
                                        Text("\(cat.count) İşlem")
                                            .font(.caption)
                                            .foregroundColor(theme.labelSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("\(cat.type == .income ? "+" : "-")₺\(cat.amount.formatted(.number.precision(.fractionLength(0))))")
                                        .font(.headline.bold())
                                        .foregroundColor(cat.type == .income ? theme.income : theme.labelPrimary)
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
        .navigationTitle("Üye Özeti")
        .navigationBarTitleDisplayMode(.inline)
    }
}
