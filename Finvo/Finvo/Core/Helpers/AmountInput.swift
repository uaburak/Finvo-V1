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

    /// Ham metni ekranda gösterilecek hâle getirir: binlik "." ve ondalık "," (cihazın bölge ayarından
    /// bağımsız). Eskiden gruplama cihaz bölgesine göre yapılıyordu; İngilizce bölgede 7000 "7,000"
    /// görünüyor, bir rakam daha yazılınca "7,0000" ondalık sanılıp 7 olarak okunuyordu.
    static func display(_ raw: String) -> String {
        guard !raw.isEmpty else { return "0" }
        let parts = raw.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let intDigits = String(parts[0]).filter(\.isNumber)
        let groupedInt = group(intDigits.isEmpty ? "0" : intDigits)
        if parts.count > 1 {
            return groupedInt + "," + parts[1]
        }
        return groupedInt
    }

    /// Gösterim alanında yapılan düzenlemeyi ham metne çevirir.
    /// - Klavyedeki "." (İngilizce bölge) yeni yazıldıysa ondalık ayırıcı kabul edilir.
    /// - Gösterimdeki binlik noktalar atılır, en fazla 2 ondalık basamak tutulur.
    static func raw(fromEdited edited: String, previousRaw: String) -> String {
        var text = edited.replacingOccurrences(of: " ", with: "")
        let previousDisplay = display(previousRaw)
        // Not: SwiftUI aynı tuş vuruşu için setter'ı bazen iki kez çağırır (ikincisinde previousRaw zaten
        // virgüllü olur); bu yüzden önceki ham metinde virgül olup olmadığına bakılmaz. Fazladan virgüller
        // aşağıda tek virgüle indirgenir.
        if text.hasSuffix("."), !previousDisplay.hasSuffix(".") {
            text.removeLast()
            text.append(",")
        }
        text = text.replacingOccurrences(of: ".", with: "").filter { $0.isNumber || $0 == "," }

        var intPart = text
        var decPart: String?
        if let commaIndex = text.firstIndex(of: ",") {
            intPart = String(text[..<commaIndex])
            decPart = String(text[text.index(after: commaIndex)...].filter(\.isNumber).prefix(2))
        }
        // Baştaki gereksiz sıfırlar ("05" -> "5"); ondalıkta "0," korunur
        while intPart.count > 1, intPart.hasPrefix("0") { intPart.removeFirst() }
        if let decPart {
            return (intPart.isEmpty ? "0" : intPart) + "," + decPart
        }
        return intPart
    }

    private static func group(_ digits: String) -> String {
        var result = ""
        for (index, char) in digits.reversed().enumerated() {
            if index > 0, index % 3 == 0 { result.append(".") }
            result.append(char)
        }
        return String(result.reversed())
    }
}
