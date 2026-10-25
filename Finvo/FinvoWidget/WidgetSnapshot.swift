import Foundation

/// Uygulamanın widget için App Group'a yazdığı özet veri. Hem uygulama hem widget hedefinde derlenir.
struct WidgetSnapshot: Codable, Equatable {
    struct UpcomingPayment: Codable, Equatable, Identifiable {
        var id: String
        var title: String
        var amount: Double
        var currencySymbol: String
        var date: Date
        var isIncome: Bool
    }

    var walletName: String
    var currencySymbol: String
    var monthKey: String
    var monthExpense: Double
    var monthIncome: Double
    var monthlyLimit: Double?
    var upcoming: [UpcomingPayment]
    var themeColor: String
    var updatedAt: Date

    static let appGroupId = "group.com.burakkoc.Finvo"
    static let storageKey = "widgetSnapshot"

    static func monthKey(for date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d%02d", c.year ?? 0, c.month ?? 0)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroupId)?.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() -> Bool {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = try? JSONEncoder().encode(self) else { return false }
        if defaults.data(forKey: Self.storageKey) == data { return false }
        defaults.set(data, forKey: Self.storageKey)
        return true
    }

    static func clear() {
        UserDefaults(suiteName: appGroupId)?.removeObject(forKey: storageKey)
    }

    static let placeholder = WidgetSnapshot(
        walletName: "Kişisel", currencySymbol: "₺", monthKey: monthKey(),
        monthExpense: 18_450, monthIncome: 42_000, monthlyLimit: 25_000,
        upcoming: [
            UpcomingPayment(id: "1", title: "Kira", amount: 15_000, currencySymbol: "₺", date: Date().addingTimeInterval(86_400 * 3), isIncome: false),
            UpcomingPayment(id: "2", title: "Netflix", amount: 229, currencySymbol: "₺", date: Date().addingTimeInterval(86_400 * 6), isIncome: false),
            UpcomingPayment(id: "3", title: "Maaş", amount: 42_000, currencySymbol: "₺", date: Date().addingTimeInterval(86_400 * 9), isIncome: true)
        ],
        themeColor: "neonGreen", updatedAt: Date())
}
