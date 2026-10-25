import Foundation

/// Tutar giriş alanlarının kullandığı ham metin formatı: ondalık ayıracı virgül, binlik ayıracı yok
/// (örn. "1250" veya "12,5"). Kaydetme tarafı "."'yı binlik ayıracı sayıp sildiği için Double'dan
/// metne çevirirken asla "." yazılmamalı; eskiden "\(12.5)" -> "12.5" -> 125 olarak kaydediliyordu.
enum AmountInput {
    static func string(from value: Double) -> String {
        guard value.isFinite, value != 0 else { return "" }
        let rounded = (value * 100).rounded() / 100
        if floor(rounded) == rounded {
            return String(format: "%.0f", rounded)
        }
        var text = String(format: "%.2f", rounded)
        if text.hasSuffix("0") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    static func parse(_ text: String) -> Double {
        let normalized = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized) ?? 0
    }
}
