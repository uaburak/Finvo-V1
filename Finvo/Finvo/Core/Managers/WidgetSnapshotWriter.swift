import Foundation
import WidgetKit

/// Aktif cüzdanın özetini widget'a aktarır. Veri değişmediyse widget yenilenmez (sistem kotası korunur).
@MainActor
enum WidgetSnapshotWriter {
    static func update(transactions: [TransactionModel], walletId: String) {
        guard let wallet = FirestoreService.shared.wallets.first(where: { $0.id == walletId }) else { return }
        let currency = UserDefaults.standard.string(forKey: "appCurrency").flatMap { CurrencyType(rawValue: $0) } ?? .tryCurrency
        let rates = ExchangeRateManager.shared
        let calendar = Calendar.current
        let now = Date()

        var expense = 0.0
        var income = 0.0
        for tx in transactions where !tx.isDebt && calendar.isDate(tx.date, equalTo: now, toGranularity: .month) {
            let value = rates.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: currency)
            if tx.type == .expense { expense += value } else { income += value }
        }

        var limit: Double?
        if let rawLimit = wallet.monthlyLimit, rawLimit > 0 {
            let limitCurrency = CurrencyType(rawValue: wallet.monthlyLimitCurrency ?? "") ?? .tryCurrency
            limit = rates.convert(amount: rawLimit, from: limitCurrency, to: currency)
        }

        let upcoming = transactions
            .filter { $0.isDebt || $0.isRecurring }
            .compactMap { $0.nextPayment(after: now) }
            .filter { $0.date > now }
            .sorted { $0.date < $1.date }
            .prefix(3)
            .map { tx in
                WidgetSnapshot.UpcomingPayment(
                    id: (tx.id ?? UUID().uuidString) + "\(tx.date.timeIntervalSince1970)",
                    title: (tx.resolvedSubCategoryName ?? tx.resolvedMainCategoryName).localized,
                    amount: tx.amount,
                    currencySymbol: tx.currency?.symbol ?? currency.symbol,
                    date: tx.date,
                    isIncome: tx.type == .income && !(tx.isDebt && tx.mainCategoryName.lowercased().contains("borç"))
                )
            }

        let snapshot = WidgetSnapshot(
            walletName: wallet.name.localized,
            currencySymbol: currency.symbol,
            monthKey: WidgetSnapshot.monthKey(for: now),
            monthExpense: expense.rounded(),
            monthIncome: income.rounded(),
            monthlyLimit: limit?.rounded(),
            upcoming: Array(upcoming),
            themeColor: UserDefaults.standard.string(forKey: "appThemeColor") ?? AppThemeColor.neonGreen.rawValue,
            updatedAt: calendar.startOfDay(for: now)   // gün içinde değişmeyen alan; gereksiz yenilemeyi önler
        )
        if snapshot.save() {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Çıkışta önceki kullanıcının verisi widget'ta kalmasın
    static func clear() {
        WidgetSnapshot.clear()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
