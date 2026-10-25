import Foundation

/// İşlemleri Excel'in doğrudan açabileceği CSV dosyasına yazar.
/// Türkçe Excel uyumu için ayırıcı ";" ondalık "," ve UTF-8 BOM kullanılır.
enum CSVExporter {
    static func export(transactions: [TransactionModel], walletName: String, currency: CurrencyType) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "tr_TR")
        dateFormatter.dateFormat = "dd.MM.yyyy HH:mm"

        let header = [
            L10n("Tarih"), L10n("Tür"), L10n("Kategori"), L10n("Alt Kategori"),
            L10n("Tutar"), L10n("Para Birimi"), String(format: L10n("Tutar (%@)"), currency.code),
            L10n("Not"), L10n("Ekleyen")
        ]
        var lines = [header.map(escape).joined(separator: ";")]

        for tx in transactions.sorted(by: { $0.date > $1.date }) {
            let txCurrency = tx.currency ?? .tryCurrency
            let converted = ExchangeRateManager.shared.convert(amount: tx.amount, from: txCurrency, to: currency)
            let typeTitle: String
            if tx.isDebt {
                typeTitle = L10n("Borç")
            } else {
                typeTitle = tx.type == .income ? L10n("Gelir") : L10n("Gider")
            }
            let row = [
                dateFormatter.string(from: tx.date),
                typeTitle,
                tx.resolvedMainCategoryName.localized,
                tx.resolvedSubCategoryName?.localized ?? "",
                number(tx.amount),
                txCurrency.code,
                number(converted),
                tx.note ?? "",
                tx.createdBy
            ]
            lines.append(row.map(escape).joined(separator: ";"))
        }

        let safeName = walletName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "_")
        let stamp = Date().formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Finvo_\(safeName.isEmpty ? "Cuzdan" : safeName)_\(stamp).csv")
        let content = "\u{FEFF}" + lines.joined(separator: "\r\n")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Ayırıcı, tırnak veya satır sonu içeren alanları tırnak içine alır
    private static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == ";" || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
