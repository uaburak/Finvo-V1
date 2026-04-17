import Foundation

struct IBANModel: Codable, Identifiable, Equatable {
    var id: String
    var bankName: String
    var ibanString: String
    
    // Varsayılan bankalar ve onlara özgü renkler (UI için helper)
    var bankUIColor: String {
        switch bankName {
        case "Akbank": return "red"
        case "Garanti BBVA": return "green"
        case "İş Bankası": return "blue"
        case "Yapı Kredi": return "blue" // Koyu mavi (temada kullanılabilir)
        case "Ziraat Bankası": return "red"
        case "QNB": return "purple"
        case "VakıfBank": return "yellow"
        case "Enpara": return "gray"
        default: return "gray"
        }
    }
}
