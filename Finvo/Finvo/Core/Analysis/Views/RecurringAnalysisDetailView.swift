import SwiftUI

struct RecurringAnalysisDetailView: View {
    @Environment(\.theme) var theme
    let transactions: [TransactionModel]
    @State private var selectedType: TransactionType = .expense
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            if transactions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "repeat.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.blue)
                    Text("Tekrarlayan (Abonelik) işlem verisi yok.")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                VStack(spacing: 0) {
                    // Segmented Control
                    Picker("İşlem Türü", selection: $selectedType) {
                        Text("Giderler").tag(TransactionType.expense)
                        Text("Gelirler").tag(TransactionType.income)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            let typeTxs = transactions.filter { $0.type == selectedType }
                            
                            if typeTxs.isEmpty {
                                Text(verbatim: "\(selectedType.localizedTitle) \("türünde abonelik işlemi yok.".localized)")
                                    .font(.subheadline)
                                    .foregroundColor(theme.labelSecondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 60)
                            } else {
                                // Top Header
                                let total = typeTxs.reduce(0) { $0 + $1.amount }
                                VStack(spacing: 8) {
                                    Text(selectedType == .expense ? "Aboneliklere Ödenen Toplam" : "Düzenli Gelir Toplamı")
                                        .font(.subheadline)
                                        .foregroundColor(theme.labelSecondary)
                                        .multilineTextAlignment(.center)
                                    Text("\(selectedType == .income ? "+" : "")₺\(total.formatted(.number.precision(.fractionLength(0))))")
                                        .font(.system(size: 40, weight: .bold, design: .rounded))
                                        .foregroundColor(selectedType == .expense ? theme.expense : theme.income)
                                }
                                .padding(.vertical, 32)
                                .frame(maxWidth: .infinity)
                                .glassEffect(in: .rect(cornerRadius: 24))
                                .padding(.horizontal, 20)
                                
                                // Category Sum List
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Abonelik Özeti")
                                            .font(.title3.bold())
                                            .foregroundColor(theme.labelPrimary)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    
                                    // Alt kategoriye göre öncelikli, yoksa ana kategoriye göre grupla
                                    let grouped = Dictionary(grouping: typeTxs, by: { $0.subCategoryName ?? $0.mainCategoryName })
                                    let subCategorySums = grouped.map { key, txs in
                                        let amount = txs.reduce(0) { $0 + $1.amount }
                                        let count = txs.count
                                        let icon = txs.first?.categoryIcon ?? "bag"
                                        return (name: key, amount: amount, count: count, icon: icon, type: txs.first!.type)
                                    }.sorted(by: { $0.amount > $1.amount })
                                    
                                    ForEach(subCategorySums, id: \.name) { cat in
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
                                                Text(LocalizedStringKey(cat.name))
                                                    .font(.headline)
                                                    .foregroundColor(theme.labelPrimary)
                                                Text("\(cat.count) İşlem")
                                                    .font(.caption)
                                                    .foregroundColor(theme.labelSecondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Text("\(cat.type == .income ? "+" : "-")₺\(cat.amount.formatted(.number.precision(.fractionLength(0))))")
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
                        }
                        .padding(.top, 16)
                        .safeAreaPadding(.bottom, 40)
                    }
                }
            }
        }
        .navigationTitle("Tekrarlayan İşlemler")
        .navigationBarTitleDisplayMode(.inline)
    }
}
