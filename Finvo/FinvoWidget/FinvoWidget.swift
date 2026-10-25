import WidgetKit
import SwiftUI

struct FinvoEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct FinvoProvider: TimelineProvider {
    func placeholder(in context: Context) -> FinvoEntry {
        FinvoEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FinvoEntry) -> Void) {
        completion(FinvoEntry(date: Date(), snapshot: context.isPreview ? .placeholder : (WidgetSnapshot.load() ?? .placeholder)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FinvoEntry>) -> Void) {
        let entry = FinvoEntry(date: Date(), snapshot: WidgetSnapshot.load())
        // Uygulama veri değişince widget'ı kendisi yeniler; bu saatlik yenileme ay dönümü ve
        // "x gün kaldı" metinleri için.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Yardımcılar
private extension WidgetSnapshot {
    /// Ay değiştiyse eski ayın tutarlarını gösterme
    var isCurrentMonth: Bool { monthKey == WidgetSnapshot.monthKey() }
    var expense: Double { isCurrentMonth ? monthExpense : 0 }
    var income: Double { isCurrentMonth ? monthIncome : 0 }
    var limitProgress: Double? {
        guard let monthlyLimit, monthlyLimit > 0 else { return nil }
        return expense / monthlyLimit
    }
    var brandColor: Color {
        switch themeColor {
        case "blue": return Color(red: 0, green: 0.533, blue: 1)
        case "pink": return Color(red: 1, green: 0.176, blue: 0.333)
        case "orange": return Color(red: 1, green: 0.584, blue: 0)
        default: return Color(red: 0.51, green: 0.93, blue: 0)
        }
    }
    func money(_ value: Double) -> String {
        "\(currencySymbol)\(value.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))"
    }
}

private func daysText(until date: Date) -> String {
    let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                               to: Calendar.current.startOfDay(for: date)).day ?? 0
    if days <= 0 { return "Bugün" }
    if days == 1 { return "Yarın" }
    return "\(days) gün"
}

// MARK: - Görünümler
struct FinvoWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: FinvoEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCircular: CircularView(snapshot: snapshot)
            case .accessoryRectangular: RectangularView(snapshot: snapshot)
            case .systemMedium: MediumView(snapshot: snapshot)
            default: SmallView(snapshot: snapshot)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.title2)
                Text("Finvo'yu açın")
                    .font(.headline)
                Text("Özetiniz burada görünecek.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

private struct SpendingSummary: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(snapshot.brandColor)
                Text(snapshot.walletName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("Bu ay harcanan")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(snapshot.money(snapshot.expense))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let progress = snapshot.limitProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: min(progress, 1))
                        .tint(progress >= 1 ? .red : (progress >= 0.8 ? .orange : snapshot.brandColor))
                    Text(progress >= 1 ? "Limit aşıldı" : "Limitin %\(Int(progress * 100))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(progress >= 1 ? .red : .secondary)
                }
            } else {
                Text("Gelir \(snapshot.money(snapshot.income))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct SmallView: View {
    let snapshot: WidgetSnapshot
    var body: some View {
        SpendingSummary(snapshot: snapshot)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumView: View {
    let snapshot: WidgetSnapshot
    var body: some View {
        HStack(spacing: 16) {
            SpendingSummary(snapshot: snapshot)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Yaklaşan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if snapshot.upcoming.isEmpty {
                    Spacer(minLength: 0)
                    Text("Yaklaşan ödeme yok")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                } else {
                    ForEach(snapshot.upcoming.prefix(3)) { payment in
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(payment.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(daysText(until: payment.date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Text("\(payment.isIncome ? "+" : "-")\(payment.currencySymbol)\(payment.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(payment.isIncome ? .green : .primary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct CircularView: View {
    let snapshot: WidgetSnapshot
    var body: some View {
        if let progress = snapshot.limitProgress {
            Gauge(value: min(progress, 1)) {
                Image(systemName: "wallet.bifold.fill")
            } currentValueLabel: {
                Text("%\(Int(progress * 100))")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "wallet.bifold.fill").font(.caption)
                    Text(snapshot.expense.formatted(.number.notation(.compactName).precision(.fractionLength(0))))
                        .font(.caption.weight(.bold))
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }
}

private struct RectangularView: View {
    let snapshot: WidgetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Bu ay", systemImage: "wallet.bifold.fill")
                .font(.caption2.weight(.semibold))
            Text(snapshot.money(snapshot.expense))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let progress = snapshot.limitProgress {
                Text(progress >= 1 ? "Limit aşıldı" : "Limitin %\(Int(progress * 100))")
                    .font(.caption2)
            } else if let next = snapshot.upcoming.first {
                Text("\(next.title) · \(daysText(until: next.date))")
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Widget
struct FinvoSummaryWidget: Widget {
    let kind = "FinvoSummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FinvoProvider()) { entry in
            FinvoWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Aylık Özet")
        .description("Bu ayki harcamanız, limitiniz ve yaklaşan ödemeler.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct FinvoWidgetBundle: WidgetBundle {
    var body: some Widget {
        FinvoSummaryWidget()
    }
}

#Preview(as: .systemMedium) {
    FinvoSummaryWidget()
} timeline: {
    FinvoEntry(date: Date(), snapshot: .placeholder)
}
