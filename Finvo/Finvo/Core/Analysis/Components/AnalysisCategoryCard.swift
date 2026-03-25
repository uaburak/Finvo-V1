import SwiftUI
import Charts

struct AnalysisCategoryCard: View {
    @Environment(\.theme) var theme
    let categorySummaries: [CategorySummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Kategori Dağılımı")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.labelPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.labelSecondary)
            }
            
            if categorySummaries.isEmpty {
                Text("Seçili dönemde gider verisi yok.")
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                HStack(spacing: 16) {
                    NativeDonutChart(data: categorySummaries)
                        .frame(width: 120, height: 120)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(categorySummaries.prefix(4)) { summary in
                            HStack {
                                Image(systemName: summary.icon)
                                    .font(.caption)
                                    .foregroundColor(theme.brandPrimary)
                                    .frame(width: 20)
                                Text(summary.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .foregroundColor(theme.labelPrimary)
                                Spacer()
                                Text("%\(summary.percentage.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.labelPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
}

// MARK: - iOS 16 Compatible Native Donut Chart
struct NativeDonutChart: View {
    let data: [CategorySummary]
    // Distinct vibrant colors for categories
    let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .indigo, .red
    ]
    
    var body: some View {
        let total = data.reduce(0) { $0 + $1.amount }
        
        ZStack {
            if total == 0 {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 16)
            } else {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    let startRatio = data.prefix(upTo: index).reduce(0) { $0 + $1.amount } / total
                    let itemRatio = item.amount / total
                    
                    // Küçük bir estetik boşluk (gaps) bırak
                    let gap = data.count > 1 ? min(0.008, itemRatio / 2) : 0.0
                    
                    Circle()
                        .trim(from: CGFloat(startRatio), to: CGFloat(startRatio + itemRatio - gap))
                        .stroke(
                            // Theme renkleri yerine kendi vibrant dizimizden fallback
                            index < colors.count ? colors[index] : .gray,
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .padding(9)
    }
}
