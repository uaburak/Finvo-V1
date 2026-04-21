import SwiftUI

struct CategoryDistributionDetailView: View {
    @Environment(\.theme) var theme
    let categorySummaries: [CategorySummary]
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Large Donut Chart Focus
                    VStack(spacing: 16) {
                        Text("Gider Dağılımı")
                            .font(.headline)
                            .foregroundColor(theme.labelPrimary)
                        
                        if categorySummaries.isEmpty {
                            Text("Bu dönemde veri yok")
                                .foregroundColor(theme.labelSecondary)
                                .frame(height: 180)
                        } else {
                            NativeDonutChart(data: categorySummaries)
                                .frame(width: 180, height: 180)
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .glassEffect(in: .rect(cornerRadius: 24))
                    .padding(.horizontal, 20)
                    
                    // Detail List
                    VStack(spacing: 12) {
                        Text("Kategori Detayları")
                            .font(.title3.bold())
                            .foregroundColor(theme.labelPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                        
                        ForEach(Array(categorySummaries.enumerated()), id: \.element.id) { index, summary in
                            let color = NativeDonutChart.colors[safe: index] ?? .gray
                            
                            HStack(spacing: 16) {
                                // Ikon ve Yuvarlak
                                ZStack {
                                    Circle()
                                        .fill(color.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    
                                    Image(systemName: summary.icon)
                                        .font(.title3)
                                        .foregroundColor(color)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey(summary.name))
                                        .font(.headline)
                                        .foregroundColor(theme.labelPrimary)
                                    Text("\(summary.transactionCount) İşlem")
                                        .font(.subheadline)
                                        .foregroundColor(theme.labelSecondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("-₺\(summary.amount.formatted(.number.precision(.fractionLength(0))))")
                                        .font(.headline)
                                        .foregroundColor(theme.labelPrimary)
                                    
                                    Text("%\(summary.percentage.formatted(.number.precision(.fractionLength(1))))")
                                        .font(.caption.bold())
                                        .foregroundColor(color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(color.opacity(0.15), in: Capsule())
                                }
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
        .navigationTitle("Dağılım Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    NavigationStack {
        CategoryDistributionDetailView(categorySummaries: [
            CategorySummary(name: "Market", amount: 1560, icon: "cart", percentage: 45.2, transactionCount: 12),
            CategorySummary(name: "Ulaşım", amount: 800, icon: "car", percentage: 23.1, transactionCount: 5),
            CategorySummary(name: "Fatura", amount: 450, icon: "doc.text", percentage: 13.0, transactionCount: 3)
        ])
        .environment(\.theme, DefaultTheme())
    }
}
