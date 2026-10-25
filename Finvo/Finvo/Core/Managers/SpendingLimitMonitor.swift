import Foundation

/// Bu ayki harcamaları genel ve kategori limitleriyle karşılaştırır, eşik aşılınca yerel bildirim gönderir.
/// Her eşik (%80 ve %100) için ayda bir kez bildirim atılır.
@MainActor
enum SpendingLimitMonitor {
    static let thresholds: [Double] = [0.8, 1.0]

    /// Bu ay, verilen kategoriye (ID ya da eski kayıtlarda isimle) ait harcama toplamı
    static func monthlySpending(in transactions: [TransactionModel], categoryId: String? = nil, categoryName: String? = nil,
                                currency: CurrencyType, now: Date = Date()) -> Double {
        let calendar = Calendar.current
        return transactions.reduce(0) { total, tx in
            guard tx.type == .expense, !tx.isDebt,
                  calendar.isDate(tx.date, equalTo: now, toGranularity: .month) else { return total }
            if let categoryId {
                let matches = tx.mainCategoryId == categoryId || (tx.mainCategoryId == nil && tx.mainCategoryName == categoryName)
                guard matches else { return total }
            }
            return total + ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: currency)
        }
    }

    static func evaluate(transactions: [TransactionModel], walletId: String) {
        guard let wallet = FirestoreService.shared.wallets.first(where: { $0.id == walletId }) else { return }
        let appCurrency = UserDefaults.standard.string(forKey: "appCurrency").flatMap { CurrencyType(rawValue: $0) } ?? .tryCurrency
        let monthKey = Self.monthKey()

        // Genel aylık limit
        if let rawLimit = wallet.monthlyLimit, rawLimit > 0 {
            let limitCurrency = CurrencyType(rawValue: wallet.monthlyLimitCurrency ?? "") ?? .tryCurrency
            let limit = ExchangeRateManager.shared.convert(amount: rawLimit, from: limitCurrency, to: appCurrency)
            let spent = monthlySpending(in: transactions, currency: appCurrency)
            notifyIfNeeded(spent: spent, limit: limit, key: "\(walletId)_general_\(monthKey)",
                           name: wallet.name, isGeneral: true, currency: appCurrency)
        }

        // Kategori limitleri
        let categories = CategoryManager.shared.categories
        for (categoryId, categoryLimit) in wallet.categoryLimits ?? [:] where categoryLimit.amount > 0 {
            let category = categories.first(where: { $0.id == categoryId })
            let limitCurrency = CurrencyType(rawValue: categoryLimit.currency) ?? .tryCurrency
            let limit = ExchangeRateManager.shared.convert(amount: categoryLimit.amount, from: limitCurrency, to: appCurrency)
            let spent = monthlySpending(in: transactions, categoryId: categoryId, categoryName: category?.name, currency: appCurrency)
            notifyIfNeeded(spent: spent, limit: limit, key: "\(walletId)_\(categoryId)_\(monthKey)",
                           name: category?.name.localized ?? categoryId, isGeneral: false, currency: appCurrency)
        }
    }

    private static func notifyIfNeeded(spent: Double, limit: Double, key: String, name: String, isGeneral: Bool, currency: CurrencyType) {
        guard limit > 0 else { return }
        let ratio = spent / limit
        // Sadece ulaşılan en yüksek eşik için bildirim (aynı anda %80 ve %100 geçilirse tek bildirim)
        guard let threshold = thresholds.last(where: { ratio >= $0 }) else { return }
        let defaultsKey = "limitAlert_\(key)_\(Int(threshold * 100))"
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        // Daha düşük eşikleri de işaretle ki sonradan tekrar gelmesin
        for t in thresholds where t <= threshold {
            UserDefaults.standard.set(true, forKey: "limitAlert_\(key)_\(Int(t * 100))")
        }

        let spentText = "\(currency.symbol)\(spent.formatted(.number.precision(.fractionLength(0))))"
        let limitText = "\(currency.symbol)\(limit.formatted(.number.precision(.fractionLength(0))))"
        let title: String
        let body: String
        if threshold >= 1.0 {
            title = L10n("Limit Aşıldı")
            body = isGeneral
                ? String(format: L10n("%@ cüzdanında bu ay %@ harcadın, aylık limitin %@."), name, spentText, limitText)
                : String(format: L10n("%@ kategorisinde bu ay %@ harcadın, limitin %@."), name, spentText, limitText)
        } else {
            title = L10n("Limite Yaklaşıyorsun")
            body = isGeneral
                ? String(format: L10n("%@ cüzdanında aylık limitinin %%%d kadarını kullandın (%@ / %@)."), name, Int(threshold * 100), spentText, limitText)
                : String(format: L10n("%@ kategorisinde limitinin %%%d kadarını kullandın (%@ / %@)."), name, Int(threshold * 100), spentText, limitText)
        }
        LocalNotificationManager.shared.triggerInstantNotification(title: title, body: body, userInfo: ["type": "limit"])
    }

    private static func monthKey(for date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d%02d", c.year ?? 0, c.month ?? 0)
    }
}
