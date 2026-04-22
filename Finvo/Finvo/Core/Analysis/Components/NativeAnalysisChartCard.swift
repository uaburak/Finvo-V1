import SwiftUI
import Charts

struct NativeAnalysisChartCard: View {
    @Environment(\.theme) var theme
    
    let flowData: [FlowData]
    let chartUnit: Calendar.Component
    let selectedTab: AnalysisTimeFrame
    @Binding var isLineGraph: Bool
    
    @State private var selectedDate: Date? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toplam Net Akış")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    let totalValue = flowData.reduce(0.0) { $0 + $1.netAmount }
                    let defaultCurrency = UserDefaults.standard.string(forKey: "appCurrency") ?? "TRY"
                    Text("\(totalValue.formatted(.currency(code: defaultCurrency).precision(.fractionLength(0))))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.labelPrimary)
                }
                
                Spacer()
                
                // Toggle for Line/Bar
                Button(action: {
                    withAnimation {
                        isLineGraph.toggle()
                    }
                }) {
                    Image(systemName: isLineGraph ? "chart.bar.fill" : "chart.line.uptrend.xyaxis")
                        .foregroundColor(theme.brandPrimary)
                        .padding(8)
                        .background(theme.brandPrimary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            if flowData.isEmpty {
                VStack {
                    Spacer()
                    Text("Bu dönem için akış verisi yok.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            } else {
                let minVal = flowData.map { $0.netAmount }.min() ?? 0
                let maxVal = flowData.map { $0.netAmount }.max() ?? 1000
                let paddedMin = minVal < 0 ? minVal * 1.2 : 0
                let paddedMax = maxVal <= 0 ? 1000 : maxVal * 1.2
                
                Chart {
                    ForEach(flowData) { item in
                        if isLineGraph {
                            LineMark(
                                x: .value("Tarih", item.date, unit: chartUnit),
                                y: .value("Tutar", item.netAmount)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(theme.brandPrimary)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Tarih", item.date, unit: chartUnit),
                                yStart: .value("Min", paddedMin),
                                yEnd: .value("Tutar", item.netAmount)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [theme.brandPrimary.opacity(0.3), theme.brandPrimary.opacity(0.0)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        } else {
                            BarMark(
                                x: .value("Tarih", item.date, unit: chartUnit),
                                y: .value("Tutar", item.netAmount)
                            )
                            .foregroundStyle(theme.brandPrimary.gradient)
                            .cornerRadius(4)
                        }
                    }
                    
                    if let selected = selectedDate, let active = findClosestItem(to: selected) {
                        RuleMark(x: .value("Tarih", active.date, unit: chartUnit))
                            .lineStyle(.init(lineWidth: 1, dash: [4]))
                            .foregroundStyle(theme.brandPrimary)
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(xAxisLabel(for: active.date, isTooltip: true))
                                        .font(.caption)
                                        .foregroundColor(theme.labelSecondary)
                                    let defaultCurrency = UserDefaults.standard.string(forKey: "appCurrency") ?? "TRY"
                                    Text("\(active.netAmount.formatted(.currency(code: defaultCurrency).precision(.fractionLength(0))))")
                                        .font(.headline)
                                        .foregroundColor(theme.labelPrimary)
                                }
                                .padding(8)
                                .background(theme.background1)
                                .cornerRadius(8)
                                .shadow(color: theme.brandPrimary.opacity(0.15), radius: 6, x: 0, y: 3)
                            }
                    }
                }
                .chartScrollableAxes(.horizontal)
                .chartXVisibleDomain(length: visibleDomainLength)
                .chartXSelection(value: $selectedDate)
                .chartYScale(domain: [paddedMin, paddedMax])
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 5)) { value in
                        if let raw = value.as(Double.self) {
                            let formattedValue = "\(raw >= 1000 ? "\(Int(raw/1000))k" : "\(Int(raw))")"
                            AxisValueLabel() {
                                Text(formattedValue)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2]))
                                .foregroundStyle(Color.gray.opacity(0.15))
                        }
                    }
                }
                .chartXAxis {
                    let markCount = (selectedTab == .month || selectedTab == .day) ? 4 : 1
                    AxisMarks(values: .stride(by: chartUnit, count: markCount)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(xAxisLabel(for: date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2]))
                                .foregroundStyle(Color.gray.opacity(0.15))
                        }
                    }
                }
                .frame(height: 220)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(theme.background2)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    // MARK: - Handlers
    private var visibleDomainLength: TimeInterval {
        // Show limited data per screen to enable scrolling
        let pointsToShow = min(flowData.count, selectedTab == .year ? 12 : 7)
        if pointsToShow <= 1 { return 86400 * 7 }
        
        let first = flowData[0].date
        let second = flowData[1].date
        let interval = abs(second.timeIntervalSince(first))
        return (interval == 0 ? 86400 : interval) * TimeInterval(pointsToShow)
    }
    
    private func findClosestItem(to date: Date) -> FlowData? {
        flowData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    private func xAxisLabel(for date: Date, isTooltip: Bool = false) -> String {
        let formatter = DateFormatter()
        let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        formatter.locale = Locale(identifier: appLanguage)
        
        if isTooltip {
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: date)
        }
        
        let calendar = Calendar.current
        switch selectedTab {
        case .day:
            return "\(calendar.component(.hour, from: date)):00"
        case .week:
            formatter.dateFormat = "E"
            return formatter.string(from: date)
        case .month:
            return "\(calendar.component(.day, from: date))"
        case .year:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
    }
}
