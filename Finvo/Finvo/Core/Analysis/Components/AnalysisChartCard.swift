import SwiftUI
import Charts

struct AnalysisChartCard: View {
    @Environment(\.theme) var theme
    let flowData: [FlowData]
    let chartUnit: Calendar.Component
    @Binding var isLineGraph: Bool
    let selectedTab: AnalysisTimeFrame
    
    @State private var currentActiveItem: FlowData? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header: Total Net Kazanç
            let totalValue = flowData.reduce(0.0) { $0 + $1.netAmount }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Net Akış")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                    
                    Text("\(totalValue >= 0 ? "+" : "")₺\(totalValue.formatted(.number.precision(.fractionLength(0))))")
                        .font(.title2.bold())
                        .foregroundColor(totalValue >= 0 ? theme.income : theme.expense)
                        .contentTransition(.numericText())
                }
                Spacer()
            }
            
            if flowData.isEmpty {
                Text("Bu dönem için akış verisi yok.")
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 180)
            } else {
                Chart {
                    chartMarks
                    
                    if let active = currentActiveItem {
                        RuleMark(x: .value("Tarih", active.date, unit: chartUnit))
                            .lineStyle(.init(lineWidth: 1, miterLimit: 2, dash: [4], dashPhase: 5))
                            .foregroundStyle(theme.labelSecondary)
                            .annotation(
                                position: .top,
                                spacing: 0,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                            ) {
                                let amount = active.netAmount
                                let bgColor: Color = amount > 0 ? theme.income : (amount < 0 ? theme.expense : Color.gray)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(xAxisLabel(for: active.date, isTooltip: true))
                                        .font(.caption2)
                                        .foregroundColor(Color.white.opacity(0.8))
                                    
                                    Text("\(amount > 0 ? "+" : "")₺\(amount.formatted(.number.precision(.fractionLength(0))))")
                                        .font(.subheadline.bold())
                                        .foregroundColor(Color.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(bgColor, in: RoundedRectangle(cornerRadius: 12))
                                .shadow(color: bgColor.opacity(0.4), radius: 8, y: 4)
                            }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { innerProxy in
                        // CATCH TOUCH
                        Rectangle()
                            .fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let locationX = max(0, min(value.location.x, proxy.plotAreaSize.width))
                                        if let date: Date = proxy.value(atX: locationX) {
                                            if let closest = findClosestItem(to: date) {
                                                if self.currentActiveItem?.date != closest.date {
                                                    UISelectionFeedbackGenerator().selectionChanged()
                                                    self.currentActiveItem = closest
                                                }
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            self.currentActiveItem = nil
                                        }
                                    }
                            )
                    }
                }
                .frame(height: 240)
                .chartYAxis { yAxisMarks }
                .chartXAxis { xAxisMarks }
                .zIndex(1)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
    
    // MARK: - Chart Builders
    
    @ChartContentBuilder
    private var chartMarks: some ChartContent {
        ForEach(flowData) { item in
            if isLineGraph {
                LineMark(
                    x: .value("Tarih", item.date, unit: chartUnit),
                    y: .value("Tutar", item.animate ? item.netAmount : 0)
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                AreaMark(
                    x: .value("Tarih", item.date, unit: chartUnit),
                    yStart: .value("Sıfır", 0),
                    yEnd: .value("Tutar", item.animate ? item.netAmount : 0)
                )
                .foregroundStyle(LinearGradient(colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            } else {
                BarMark(
                    x: .value("Tarih", item.date, unit: chartUnit),
                    y: .value("Tutar", item.animate ? item.netAmount : 0)
                )
                .foregroundStyle(item.netAmount >= 0 ? theme.income.gradient : theme.expense.gradient)
                .cornerRadius(4)
            }
        }
    }
    
    // MARK: - Axis Builders
    
    @AxisContentBuilder
    private var yAxisMarks: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
            if let raw = value.as(Double.self) {
                let formattedValue = "\(raw >= 0 ? "+" : "-")\(abs(raw / 1000).formatted(.number.precision(.fractionLength(0))))K"
                AxisValueLabel { Text(formattedValue).font(.caption2).foregroundColor(theme.labelSecondary) }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
    }
    
    @AxisContentBuilder
    private var xAxisMarks: some AxisContent {
        let markCount = (selectedTab == .month || selectedTab == .day) ? 4 : 1
        AxisMarks(values: .stride(by: chartUnit, count: markCount)) { value in
            if let date = value.as(Date.self) {
                AxisValueLabel {
                    Text(xAxisLabel(for: date))
                        .font(.caption2)
                        .foregroundStyle(theme.labelSecondary)
                        .fixedSize()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func findClosestItem(to date: Date) -> FlowData? {
        flowData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    private func xAxisLabel(for date: Date, isTooltip: Bool = false) -> String {
        let calendar = Calendar.current
        switch selectedTab {
        case .day: 
            return isTooltip ? date.formatted(.dateTime.hour().minute()) : "\(calendar.component(.hour, from: date))"
        case .week: 
            return isTooltip ? date.formatted(.dateTime.weekday().day()) : calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        case .month: 
            return isTooltip ? date.formatted(.dateTime.month().day()) : "\(calendar.component(.day, from: date))"
        case .year: 
            return isTooltip ? date.formatted(.dateTime.month(.wide).year()) : calendar.shortMonthSymbols[calendar.component(.month, from: date) - 1]
        }
    }
}

// MARK: - Preview Generator
#Preview {
    let calendar = Calendar.current
    let today = Date()
    
    let fakeData: [FlowData] = (0..<7).map { i in
        let date = calendar.date(byAdding: .day, value: -6 + i, to: today)!
        let net = Double.random(in: -5000...20000)
        return FlowData(id: date, date: date, netAmount: net, animate: true)
    }
    
    return AnalysisChartCard(
        flowData: fakeData,
        chartUnit: .day,
        isLineGraph: .constant(true),
        selectedTab: .week
    )
    .environment(\.theme, DefaultTheme())
    .padding()
    .background(Color.black.ignoresSafeArea())
}
