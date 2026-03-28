import SwiftUI

struct RecordTransactionDetailView: View {
    @Environment(\.theme) var theme
    let transaction: TransactionModel?
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            if let tx = transaction {
                VStack(spacing: 32) {
                    
                    // Kupa / Ateş İkonu Alanı
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [theme.expense.opacity(0.8), .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 120, height: 120)
                            .shadow(color: theme.expense.opacity(0.5), radius: 24, x: 0, y: 12)
                        
                        Image(systemName: "flame.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 40)
                    
                    // Ana Bilgi
                    VStack(spacing: 12) {
                        Text("Rekor Harcama")
                            .font(.headline)
                            .foregroundColor(theme.labelSecondary)
                        
                        Text("₺\(tx.amount.formatted(.number.precision(.fractionLength(0))))")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundColor(theme.labelPrimary)
                            .shadow(color: theme.expense.opacity(0.2), radius: 10, y: 5)
                            
                        Text((tx.note ?? "").isEmpty ? tx.mainCategoryName : tx.note!)
                            .font(.title2.bold())
                            .foregroundColor(theme.labelPrimary)
                            .padding(.top, 8)
                    }
                    
                    // Detay Kartı
                    VStack(spacing: 0) {
                        DetailRow(icon: tx.categoryIcon, title: "Kategori", value: tx.mainCategoryName, color: theme.brandPrimary)
                        Divider().padding(.leading, 56)
                        DetailRow(icon: "calendar", title: "Tarih", value: tx.date.formatted(date: .abbreviated, time: .omitted), color: .blue)
                        Divider().padding(.leading, 56)
                        DetailRow(icon: "creditcard.fill", title: "Tip", value: tx.type == .expense ? "Gider" : "Gelir", color: tx.type == .expense ? theme.expense : theme.income)
                    }
                    .padding(.vertical, 8)
                    .glassEffect(in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(theme.labelSecondary)
                    Text("Bu dönemde hiç işlem bulunamadı.")
                        .font(.headline)
                        .foregroundColor(theme.labelSecondary)
                }
            }
        }
        .navigationTitle("Rekor İşlem")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailRow: View {
    @Environment(\.theme) var theme
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.subheadline.bold())
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(theme.labelSecondary)
            
            Spacer()
            
            Text(value)
                .font(.body.bold())
                .foregroundColor(theme.labelPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
