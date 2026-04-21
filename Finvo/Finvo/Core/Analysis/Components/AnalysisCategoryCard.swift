import SwiftUI
import Charts
import Charts

struct AnalysisCategoryCard: View {
    @Environment(\.theme) var theme
    let categorySummaries: [CategorySummary]
    
    var body: some View {
        NavigationLink(destination: CategoryDistributionDetailView(categorySummaries: categorySummaries)) {
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
                                    Text(LocalizedStringKey(summary.name))
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
        .buttonStyle(.plain)
    }
}

// MARK: - iOS 16 Compatible Native Donut Chart
struct NativeDonutChart: View {
    let data: [CategorySummary]
    // Distinct vibrant colors for categories
    static let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .indigo, .red, .teal, .mint, .yellow
    ]
    
    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                SectorMark(
                    angle: .value("Tutar", item.amount),
                    innerRadius: .ratio(0.65),
                    outerRadius: .ratio(1.0),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(index < Self.colors.count ? Self.colors[index] : .gray)
            }
        }
    }
}
