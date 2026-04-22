import SwiftUI
import Charts

struct AnalysisChartCard: View {
    @Environment(\.theme) var theme
    let flowData: [FlowData]
    let chartUnit: Calendar.Component
    let selectedTab: AnalysisTimeFrame
    let globalMaxAmount: Double
    
    @State private var currentActiveItem: FlowData? = nil
    @State private var rawSelectedDate: Date? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header: Total Net Kazanç (Placeholder)
            HStack(alignment: .top) {
                dynamicHeader(for: nil)
                    .opacity(0)
                Spacer()
            }
            .zIndex(0)
            
            if flowData.isEmpty {
                Text("Bu dönem için akış verisi yok.")
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 180)
            } else {
                let maxAbs = globalMaxAmount
                let paddedMax = maxAbs == 0 ? 1000 : maxAbs * 1.2
                
                ZStack {
                    // 1. MASKED GRADIENT KATMANI (Asıl Görsel Renkli Çizim)
                    Rectangle()
                        .fill(absoluteGradient)
                        .mask {
                            Chart {
                                chartMarks(isMask: true)
                            }
                            .frame(height: 240)
                            .chartYScale(domain: [-paddedMax, paddedMax])
                            .chartYAxis { yAxisMarksTransparent }
                            .chartXAxis { xAxisMarksTransparent }
                        }
                        .allowsHitTesting(false)
                    
                    // 2. BASE CHART KATMANI
                    Chart {
                        chartMarks(isMask: false)
                        
                        // RuleMark line pointing to selected bar
                        if let active = currentActiveItem {
                            RuleMark(x: .value("Tarih", active.date, unit: chartUnit))
                                .lineStyle(.init(lineWidth: 1, miterLimit: 2, dash: [4], dashPhase: 5))
                                .foregroundStyle(theme.labelSecondary)
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            let isActive = currentActiveItem != nil
                            
                            let barCenter: CGFloat = {
                                guard let active = currentActiveItem else { return 0 }
                                return proxy.position(forX: active.date) ?? 0
                            }()
                            
                            ZStack(alignment: .leading) {
                                Color.clear.frame(width: geo.size.width, height: 1)
                                
                                // 👇 MANUEL ALIGNMENT (İNCE AYAR) 👇
                                // Tooltip'in merkezini kesik çizgiye göre hizalamak için her sekmeye özel değerler.
                                let manualTooltipOffset: CGFloat = {
                                    switch selectedTab {
                                    case .day: return 32
                                    case .week: return 48
                                    case .month: return 30
                                    case .year: return 36
                                    }
                                }()
                                
                                dynamicHeader(for: currentActiveItem)
                                    .fixedSize(horizontal: true, vertical: true)
                                    .alignmentGuide(.leading) { d in
                                        if isActive {
                                            let wCenter = d.width / 2
                                            let targetCenter = barCenter + manualTooltipOffset
                                            // Limit the tooltip center so its left edge doesn't go below X=0, and right doesn't go off-screen
                                            let clampedCenter = min(max(targetCenter, wCenter), geo.size.width - wCenter)
                                            return -(clampedCenter - wCenter)
                                        } else {
                                            return 0
                                        }
                                    }
                            }
                            .offset(y: -84)
                        }
                    }
                    .chartXSelection(value: $rawSelectedDate)
                    .onChange(of: rawSelectedDate) { _, newValue in
                        if let date = newValue {
                            if let closest = findClosestItem(to: date) {
                                if self.currentActiveItem?.date != closest.date {
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    // If already active, jump instantly (no lag). Otherwise, slide smoothly.
                                    if self.currentActiveItem == nil {
                                        withAnimation(.snappy(duration: 0.4)) {
                                            self.currentActiveItem = closest
                                        }
                                    } else {
                                        self.currentActiveItem = closest
                                    }
                                }
                            }
                        } else {
                            withAnimation(.snappy(duration: 0.4)) {
                                self.currentActiveItem = nil
                            }
                        }
                    }
                    .frame(height: 240)
                    .chartYScale(domain: [-paddedMax, paddedMax])
                    .chartYAxis { yAxisMarks }
                    .chartXAxis { xAxisMarks }
                }
                .zIndex(1)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
    
    // MARK: - Chart Builders
    
    @ChartContentBuilder
    private func chartMarks(isMask: Bool) -> some ChartContent {
        ForEach(flowData) { item in
            let isPositive = item.netAmount >= 0
            let microOffset: Double = item.animate ? (isPositive ? 0.001 : -0.001) : 0.001
            BarMark(
                x: .value("Tarih", item.date, unit: chartUnit),
                yStart: .value("Taban", microOffset),
                yEnd: .value("Tutar", item.animate ? item.netAmount : microOffset)
            )
            .foregroundStyle(isMask ? Color.black : Color.clear)
            .cornerRadius(100)
        }
    }
    
    // MARK: - Gradients
    
    private var absoluteGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: theme.income, location: 0.0),       // En Tepe (+Maksimum Bakiye)
                .init(color: theme.income, location: 0.40),      // Güvenli Pozitif Bölgesi
                .init(color: .orange, location: 0.5),            // Nötr Sıfır Çizgisi Geçişi
                .init(color: theme.expense, location: 0.60),     // Güvenli Negatif Bölgesi
                .init(color: theme.expense, location: 1.0)       // En Alt (-Maksimum Bakiye)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }
    
    // MARK: - Axis Builders
    
    // 👇 X EKSENİ YAZILARI İÇİN İNCE AYAR 👇
    // Grafiğin altındaki tarih, ay, yıl yazılarının sağa/sola kaydırılmasını sağlar.
    // Pozitif değer sağa, Negatif değer sola kaydırır.
    private var xAxisLabelOffset: CGFloat {
        switch selectedTab {
        case .day: return -2
        case .week: return 0
        case .month: return -2
        case .year: return 0
        }
    }
    
    // 👇 ÇİFT HANELİ RAKAM (10 ve ÜZERİ) İÇİN MİKRO KAYDIRMA 👇
    // Sadece Gün ve Ay sekmelerinde çift haneli rakamlar gelince yazıyı fazladan kaç pixel sola kaydıracağımızı belirler.
    private func doubleDigitOffset(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        if selectedTab == .day {
            let hour = calendar.component(.hour, from: date)
            return hour >= 10 ? -3.5 : 0 // -3.5 sola kaydır
        } else if selectedTab == .month {
            let day = calendar.component(.day, from: date)
            return day >= 10 ? -3.5 : 0 // -3.5 sola kaydır
        }
        return 0
    }
    
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
        let isCentered = (selectedTab == .week || selectedTab == .year)
        
        AxisMarks(values: .stride(by: chartUnit, count: markCount)) { value in
            if let date = value.as(Date.self) {
                if isCentered {
                    AxisValueLabel(centered: true) {
                        Text(xAxisLabel(for: date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(theme.labelSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .offset(x: xAxisLabelOffset + doubleDigitOffset(for: date))
                    }
                } else {
                    AxisValueLabel(centered: false) {
                        Text(xAxisLabel(for: date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(theme.labelSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .offset(x: xAxisLabelOffset + doubleDigitOffset(for: date))
                    }
                }
            }
        }
    }
    
    // Y ekseninin ve iç iskeletin şeffaf (hayalet) kopyası (Mükemmel hizalama garantisi için)
    @AxisContentBuilder
    private var yAxisMarksTransparent: some AxisContent {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
            if let raw = value.as(Double.self) {
                let formattedValue = "\(raw >= 0 ? "+" : "-")\(abs(raw / 1000).formatted(.number.precision(.fractionLength(0))))K"
                AxisValueLabel { Text(formattedValue).font(.caption2).foregroundColor(.clear) }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.clear)
            }
        }
    }
    
    // X ekseninin ve iç iskeletin şeffaf (hayalet) kopyası (Mükemmel hizalama garantisi için)
    @AxisContentBuilder
    private var xAxisMarksTransparent: some AxisContent {
        let markCount = (selectedTab == .month || selectedTab == .day) ? 4 : 1
        let isCentered = (selectedTab == .week || selectedTab == .year)
        
        AxisMarks(values: .stride(by: chartUnit, count: markCount)) { value in
            if let date = value.as(Date.self) {
                if isCentered {
                    AxisValueLabel(centered: true) {
                        Text(xAxisLabel(for: date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.clear)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .offset(x: xAxisLabelOffset + doubleDigitOffset(for: date))
                    }
                } else {
                    AxisValueLabel(centered: false) {
                        Text(xAxisLabel(for: date))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.clear)
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .offset(x: xAxisLabelOffset + doubleDigitOffset(for: date))
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func findClosestItem(to date: Date) -> FlowData? {
        let calendar = Calendar.current
        if let exactMatch = flowData.first(where: { calendar.isDate($0.date, equalTo: date, toGranularity: chartUnit) }) {
            return exactMatch
        }
        return flowData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    private func xAxisLabel(for date: Date, isTooltip: Bool = false) -> String {
        let appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        let locale = Locale(identifier: appLanguage)
        var calendar = Calendar.current
        calendar.locale = locale
        
        switch selectedTab {
        case .day: 
            return isTooltip ? date.formatted(.dateTime.hour().minute().locale(locale)) : "\(calendar.component(.hour, from: date))"
        case .week: 
            return isTooltip ? date.formatted(.dateTime.weekday().day().locale(locale)) : calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        case .month: 
            return isTooltip ? date.formatted(.dateTime.day().month(.wide).locale(locale)) : "\(calendar.component(.day, from: date))"
        case .year: 
            return isTooltip ? date.formatted(.dateTime.month(.wide).locale(locale)) : calendar.shortMonthSymbols[calendar.component(.month, from: date) - 1]
        }
    }
    
    @ViewBuilder
    private func dynamicHeader(for activeItem: FlowData?) -> some View {
        let isTooltip = activeItem != nil
        let amount = activeItem?.netAmount ?? flowData.reduce(0.0) { $0 + $1.netAmount }
        let title = isTooltip ? xAxisLabel(for: activeItem!.date, isTooltip: true) : "Net Akış".localized
        
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(theme.labelSecondary)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.4), value: title)
            
            Text("\(amount >= 0 ? "+" : "")₺\(amount.formatted(.number.precision(.fractionLength(0))))")
                .font(.title2.bold())
                .foregroundColor(amount >= 0 ? theme.income : theme.expense)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.4), value: amount)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(in: .rect(cornerRadius: 12))
        .geometryGroup()
        .animation(.snappy(duration: 0.4), value: amount)
        .animation(.snappy(duration: 0.4), value: title)
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
        selectedTab: .week,
        globalMaxAmount: 20000
    )
    .environment(\.theme, DefaultTheme())
    .padding()
    .background(Color.black.ignoresSafeArea())
}
