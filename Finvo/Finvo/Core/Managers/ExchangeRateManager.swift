//
//  ExchangeRateManager.swift
//  Finvo
//

import Foundation
import Combine

struct CurrencyType: RawRepresentable, Codable, Hashable, Identifiable {
    var id: String { code }
    let code: String
    let customName: String?
    let customSymbol: String?
    let assetType: String
    
    var rawValue: String { code }
    
    var name: String {
        if let n = customName, !n.isEmpty { return n }
        return code
    }
    
    var symbol: String {
        if let s = customSymbol, !s.isEmpty { return s }
        let map: [String: String] = ["TRY": "₺", "USD": "$", "EUR": "€", "GBP": "£", "CHF": "₣", "CAD": "$", "AUD": "$", "JPY": "¥", "gram-altin": "gr", "gumus": "gr"]
        if let staticSymbol = map[code] { return staticSymbol }
        if code.contains("altin") || code.contains("gumus") { return "gr" }
        return code // Fallback
    }
    
    var icon: String {
        switch code {
        case "TRY": return "turkishlirasign"
        case "USD", "CAD", "AUD": return "dollarsign"
        case "EUR": return "eurosign"
        case "GBP": return "sterlingsign"
        case "CHF": return "francsign"
        case "JPY": return "yensign"
        case "RUB": return "rublesign"
        case "gram-altin", "ceyrek-altin", "yarim-altin", "tam-altin", "cumhuriyet-altini", "ata-altin": return "medal.fill"
        case "gumus": return "circle.hexagongrid.fill"
        default: return "globe"
        }
    }
    
    init(code: String, name: String? = nil, symbol: String? = nil, assetType: String = "Döviz") {
        self.code = code
        self.customName = name
        self.customSymbol = symbol
        self.assetType = assetType
    }
    
    init?(rawValue: String) {
        self.code = rawValue
        self.customName = nil
        self.customSymbol = nil
        self.assetType = "Döviz"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.code)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self.code = rawValue
        self.customName = nil
        self.customSymbol = nil
        self.assetType = "Döviz"
    }
    
    static let tryCurrency = CurrencyType(code: "TRY", name: "Türk Lirası", symbol: "₺")
    static let usd = CurrencyType(code: "USD", name: "Amerikan Doları", symbol: "$")
    static let eur = CurrencyType(code: "EUR", name: "Euro", symbol: "€")
    static let gbp = CurrencyType(code: "GBP", name: "İngiliz Sterlini", symbol: "£")
    static let gold = CurrencyType(code: "gram-altin", name: "Gram Altın", symbol: "gr")
    static let silver = CurrencyType(code: "gumus", name: "Gümüş", symbol: "gr")
    
    // Yalnızca eski uyumluluk için, dinamik listeyi manager'dan çekin
    static let allCases: [CurrencyType] = [.tryCurrency, .usd, .eur, .gbp, .gold, .silver]
}

@MainActor
class ExchangeRateManager: ObservableObject {
    static let shared = ExchangeRateManager()
    
    @Published var rates: [CurrencyType: Double] = [
        .tryCurrency: 1.0,
        .usd: 32.0,
        .eur: 34.5,
        .gbp: 40.0,
        .gold: 2400.0,
        .silver: 30.0
    ]
    
    @Published var marketData: [CurrencyType: (buy: Double, sell: Double, change: String)] = [:]
    @Published var allCurrencies: [CurrencyType] = CurrencyType.allCases
    
    private let apiURL = "https://finans.truncgil.com/today.json"
    
    private init() {
        Task {
            await fetchRates()
        }
    }
    
    func fetchRates() async {
        guard let url = URL(string: apiURL) else { return }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                var newRates: [CurrencyType: Double] = [.tryCurrency: 1.0]
                var newMarketData: [CurrencyType: (buy: Double, sell: Double, change: String)] = [:]
                var loadedCurrencies: [CurrencyType] = [.tryCurrency]
                
                let symbolMap: [String: String] = [
                    "USD": "$", "EUR": "€", "GBP": "£", "CHF": "₣", "CAD": "$", "AUD": "$", "JPY": "¥"
                ]
                
                for (key, value) in json {
                    // Update_Date atla
                    if key == "Update_Date" { continue }
                    
                    if let dict = value as? [String: String],
                       let satisStr = dict["Satış"],
                       let alisStr = dict["Alış"] {
                        
                        let cleanSatis = satisStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                        let cleanAlis = alisStr.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                        
                        if let sellVal = Double(cleanSatis), let buyVal = Double(cleanAlis) {
                            // Tur, vb. çek
                            let nameMap: [String: String] = [
                                "USD": "Amerikan Doları", "EUR": "Euro", "GBP": "İngiliz Sterlini", "CHF": "İsviçre Frangı",
                                "CAD": "Kanada Doları", "RUB": "Rus Rublesi", "AED": "BAE Dirhemi", "AUD": "Avustralya Doları",
                                "DKK": "Danimarka Kronu", "SEK": "İsveç Kronu", "NOK": "Norveç Kronu", "JPY": "Japon Yeni",
                                "KWD": "Kuveyt Dinarı", "ZAR": "Güney Afrika Randı", "BHD": "Bahreyn Dinarı", "LYD": "Libya Dinarı",
                                "SAR": "Suudi Arabistan Riyali", "IQD": "Irak Dinarı", "ILS": "İsrail Şekeli", "INR": "Hindistan Rupisi",
                                "MXN": "Meksika Pesosu", "HUF": "Macar Forinti", "NZD": "Yeni Zelanda Doları", "BRL": "Brezilya Reali",
                                "IDR": "Endonezya Rupisi", "CZK": "Çek Korunası", "PLN": "Polonya Zlotisi", "RON": "Rumen Leyi",
                                "CNY": "Çin Yuanı", "ARS": "Arjantin Pesosu", "ALL": "Arnavutluk Leki", "AZN": "Azerbaycan Manatı",
                                "BAM": "Bosna Hersek Markı", "CLP": "Şili Pesosu", "COP": "Kolombiya Pesosu", "CRC": "Kosta Rika Kolonu",
                                "DZD": "Cezayir Dinarı", "EGP": "Mısır Lirası", "HKD": "Hong Kong Doları", "ISK": "İzlanda Kronu",
                                "KRW": "Güney Kore Wonu", "KZT": "Kazak Tengesi", "LBP": "Lübnan Lirası", "LKR": "Sri Lanka Rupisi",
                                "MAD": "Fas Dirhemi", "MDL": "Moldova Leyi", "MKD": "Makedon Dinarı", "MYR": "Malezya Ringgiti",
                                "OMR": "Umman Riyali", "PEN": "Peru Solü", "PHP": "Filipinler Pesosu", "PKR": "Pakistan Rupisi",
                                "QAR": "Katar Riyali", "RSD": "Sırp Dinarı", "SGD": "Singapur Doları", "SYP": "Suriye Lirası",
                                "THB": "Tayland Bahtı", "TWD": "Yeni Tayvan Doları", "UAH": "Ukrayna Grivnası", "UYU": "Uruguay Pesosu",
                                "GEL": "Gürcistan Larisi", "TND": "Tunus Dinarı", "BGN": "Bulgar Levası", "GRA": "Gram Altın",
                                "gram-altin": "Gram Altın", "XU100": "BIST 100 Endeksi", "DBITCOIN": "Bitcoin (Dijital)",
                                "GUMUS": "Gümüş", "gumus": "Gümüş", "BRENT": "Brent Petrol", "ONS": "Ons Altın", "HAS": "Has Altın (24 Ayar)",
                                "CEYREKALTIN": "Çeyrek Altın", "ceyrek-altin": "Çeyrek Altın", "YARIMALTIN": "Yarım Altın", "yarim-altin": "Yarım Altın",
                                "TAMALTIN": "Tam Altın", "tam-altin": "Tam Altın", "CUMHURIYETALTINI": "Cumhuriyet Altını", "cumhuriyet-altini": "Cumhuriyet Altını",
                                "ATAALTIN": "Ata Altın", "ata-altin": "Ata Altın", "14AYARALTIN": "14 Ayar Altın", "18AYARALTIN": "18 Ayar Altın",
                                "YIA": "Yeni İstanbul Altını", "IKIBUCUKALTIN": "İki Buçuklu Altın", "BESLIALTIN": "Beşli Altın",
                                "GREMSEALTIN": "Gremse Altın", "RESATALTIN": "Reşat Altın", "HAMITALTIN": "Hamit Altın",
                                "GPL": "Platin", "PAL": "Paladyum"
                            ]
                            let typeStr = dict["Tür"] ?? "Döviz"
                            let mappedName = nameMap[key] ?? key.replacingOccurrences(of: "-", with: " ").capitalized
                            let sym = key.contains("altin") || key.contains("gumus") ? "gr" : (symbolMap[key] ?? key)
                            
                            let curr = CurrencyType(code: key, name: mappedName, symbol: sym, assetType: typeStr)
                            newRates[curr] = sellVal
                            
                            let changeStr = dict["Değişim"] ?? "%0"
                            newMarketData[curr] = (buy: buyVal, sell: sellVal, change: changeStr)
                            
                            if !loadedCurrencies.contains(where: { $0.code == curr.code }) {
                                loadedCurrencies.append(curr)
                            }
                        }
                    }
                }
                
                self.marketData = newMarketData
                self.allCurrencies = loadedCurrencies
                
                // Set USD, EUR, Gold etc directly for compatibility
                if let usd = newRates.keys.first(where: { $0.code == "USD" }) { newRates[.usd] = newRates[usd] }
                if let eur = newRates.keys.first(where: { $0.code == "EUR" }) { newRates[.eur] = newRates[eur] }
                if let gold = newRates.keys.first(where: { $0.code == "gram-altin" }) { newRates[.gold] = newRates[gold] }
                if let gbp = newRates.keys.first(where: { $0.code == "GBP" }) { newRates[.gbp] = newRates[gbp] }
                if let silver = newRates.keys.first(where: { $0.code == "gumus" }) { newRates[.silver] = newRates[silver] }
                
                // Uygulamanın kullandığı güncel listeyi set et
                self.rates = newRates
            }
        } catch {
            print("Exchange Rate Fetch Error: \(error)")
        }
    }
    
    // Calculates value of amount in inputCurrency converted to targetCurrency.
    // E.g. convert(amount: 100, from: .usd, to: .tryCurrency) -> 3200
    // E.g. convert(amount: 3200, from: .tryCurrency, to: .usd) -> 100
    func convert(amount: Double, from inputCurrency: CurrencyType, to targetCurrency: CurrencyType) -> Double {
        if inputCurrency == targetCurrency { return amount }
        
        // Find input rate dynamically
        var inputRateToTry = 1.0
        if let exact = rates.keys.first(where: { $0.code == inputCurrency.code }) {
            inputRateToTry = rates[exact] ?? 1.0
        } else {
            inputRateToTry = rates[inputCurrency] ?? 1.0
        }
        
        var targetRateToTry = 1.0
        if let exact = rates.keys.first(where: { $0.code == targetCurrency.code }) {
            targetRateToTry = rates[exact] ?? 1.0
        } else {
            targetRateToTry = rates[targetCurrency] ?? 1.0
        }
        
        // Convert input to TRY first
        let amountInTry = amount * inputRateToTry
        
        // Convert TRY to target
        return amountInTry / targetRateToTry
    }
}
