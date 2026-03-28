import Foundation
import SwiftUI
import FirebaseFirestore

struct SubCategoryModel: Identifiable, Equatable, Codable {
    var id: String = UUID().uuidString
    let name: String
    let icon: String // SF Symbol
    let color: String // Hex or Name
    var isOn: Bool = true // toggle state
}

struct CategoryModel: Identifiable, Equatable, Codable {
    @DocumentID var firestoreId: String?
    var id: String { firestoreId ?? safeId }
    
    let type: TransactionType
    let name: String
    let icon: String // SF Symbol
    let color: String // Hex or Name
    var subCategories: [SubCategoryModel]
    var isOn: Bool = true
}

// Extending for UI Layer
extension CategoryModel {
    var safeId: String {
        return name.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "&", with: "n")
    }
    
    var uiColor: Color {
        self.color.hasPrefix("#") ? Color(hex: self.color) : getColorFromName(self.color)
    }
    
    var localizedName: LocalizedStringKey {
        LocalizedStringKey(self.name)
    }

    private func getColorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "indigo": return .indigo
        case "brown": return .brown
        case "cyan": return .cyan
        case "gray": return .gray
        case "black": return .black
        case "mint": return .mint
        default: return .blue
        }
    }
}

extension SubCategoryModel {
    var uiColor: Color {
        self.color.hasPrefix("#") ? Color(hex: self.color) : getColorFromName(self.color)
    }
    
    var localizedName: LocalizedStringKey {
        LocalizedStringKey(self.name)
    }

    private func getColorFromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue": return .blue
        case "green": return .green
        case "red": return .red
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "teal": return .teal
        case "indigo": return .indigo
        case "brown": return .brown
        case "cyan": return .cyan
        case "gray": return .gray
        case "black": return .black
        case "mint": return .mint
        default: return .blue
        }
    }
}

struct CategoriesMockData {
    static var data: [CategoryModel] = [
        // MARK: - GİDER KATEGORİLERİ (EXPENSES)
        
        // 1. DİJİTAL ABONELİKLER (Tümü Tek Çatıda)
        CategoryModel(type: .expense, name: "Abonelikler", icon: "repeat.circle.fill", color: "purple", subCategories: [
            SubCategoryModel(name: "Netflix", icon: "play.tv.fill", color: "red"),
            SubCategoryModel(name: "Disney+", icon: "sparkles.tv.fill", color: "blue"),
            SubCategoryModel(name: "YouTube Premium", icon: "play.rectangle.fill", color: "red"),
            SubCategoryModel(name: "Amazon Prime", icon: "cart.fill", color: "cyan"),
            SubCategoryModel(name: "BluTV", icon: "play.circle.fill", color: "indigo"),
            SubCategoryModel(name: "MUBI", icon: "film.stack.fill", color: "black"),
            SubCategoryModel(name: "Gain / Exxen", icon: "tv.fill", color: "yellow"),
            SubCategoryModel(name: "Spotify", icon: "music.note.house.fill", color: "green"),
            SubCategoryModel(name: "Apple Music", icon: "apple.logo", color: "pink"),
            SubCategoryModel(name: "Tidal / Deezer", icon: "waveform", color: "cyan"),
            SubCategoryModel(name: "PlayStation Plus", icon: "playstation.logo", color: "blue"),
            SubCategoryModel(name: "Xbox Game Pass", icon: "xbox.logo", color: "green"),
            SubCategoryModel(name: "Nintendo Online", icon: "gamecontroller.fill", color: "red"),
            SubCategoryModel(name: "EA Play", icon: "logo.xbox", color: "orange"),
            SubCategoryModel(name: "Gemini Advanced", icon: "brain.head.profile", color: "purple"),
            SubCategoryModel(name: "ChatGPT Plus", icon: "message.and.waveform.fill", color: "teal"),
            SubCategoryModel(name: "Claude Pro", icon: "shimmer", color: "orange"),
            SubCategoryModel(name: "GitHub Copilot", icon: "terminal.fill", color: "black"),
            SubCategoryModel(name: "Midjourney", icon: "paintpalette.fill", color: "indigo"),
            SubCategoryModel(name: "Cursor IDE", icon: "chevron.left.forwardslash.chevron.right", color: "blue"),
            SubCategoryModel(name: "Adobe Creative Cloud", icon: "paintbrush.fill", color: "red"),
            SubCategoryModel(name: "Figma Pro", icon: "square.grid.2x2.fill", color: "purple"),
            SubCategoryModel(name: "Canva Pro", icon: "wand.and.stars", color: "blue"),
            SubCategoryModel(name: "Notion", icon: "doc.text.fill", color: "black"),
            SubCategoryModel(name: "iCloud+", icon: "icloud.fill", color: "blue"),
            SubCategoryModel(name: "Google One", icon: "g.circle.fill", color: "red"),
            SubCategoryModel(name: "Dropbox", icon: "archivebox.fill", color: "blue"),
            SubCategoryModel(name: "Vercel / Supabase", icon: "triangle.fill", color: "black")
        ]),
        
        CategoryModel(type: .expense, name: "Banka & Finans", icon: "building.columns.fill", color: "gray", subCategories: [
            SubCategoryModel(name: "Kredi Kartı Ödemesi", icon: "creditcard.fill", color: "blue"),
            SubCategoryModel(name: "İhtiyaç Kredisi", icon: "banknote.fill", color: "red"),
            SubCategoryModel(name: "Araç / Konut Kredisi", icon: "house.and.flag.fill", color: "indigo"),
            SubCategoryModel(name: "KMH / Artı Para", icon: "plus.circle.fill", color: "orange"),
            SubCategoryModel(name: "EFT / Havale Ücreti", icon: "arrow.right.arrow.left", color: "teal"),
            SubCategoryModel(name: "Banka Aidatı", icon: "percent", color: "gray")
        ]),
        
        CategoryModel(type: .expense, name: "Araba & Ulaşım", icon: "car.fill", color: "orange", subCategories: [
            SubCategoryModel(name: "Akaryakıt / LPG", icon: "fuelpump.fill", color: "orange"),
            SubCategoryModel(name: "Periyodik Bakım & Servis", icon: "wrench.and.screwdriver.fill", color: "blue"),
            SubCategoryModel(name: "Trafik Sigortası & Kasko", icon: "shield.checkerboard", color: "red"),
            SubCategoryModel(name: "Otopark & HGS", icon: "parkingsign.circle.fill", color: "gray"),
            SubCategoryModel(name: "Oto Yıkama", icon: "bubbles.and.sparkles.fill", color: "cyan"),
            SubCategoryModel(name: "Taksi & Toplu Taşıma", icon: "bus.fill", color: "green")
        ]),
        
        CategoryModel(type: .expense, name: "Konut & Faturalar", icon: "house.fill", color: "indigo", subCategories: [
            SubCategoryModel(name: "Kira", icon: "key.fill", color: "indigo"),
            SubCategoryModel(name: "Elektrik", icon: "bolt.fill", color: "yellow"),
            SubCategoryModel(name: "Su", icon: "drop.circle.fill", color: "blue"),
            SubCategoryModel(name: "Doğalgaz / Isınma", icon: "flame.fill", color: "orange"),
            SubCategoryModel(name: "İnternet", icon: "wifi", color: "cyan"),
            SubCategoryModel(name: "Telefon Faturası", icon: "iphone", color: "green"),
            SubCategoryModel(name: "Aidat", icon: "building.2.fill", color: "gray")
        ]),
        
        CategoryModel(type: .expense, name: "Market & Mutfak", icon: "cart.fill", color: "blue", subCategories: [
            SubCategoryModel(name: "Süpermarket", icon: "basket.fill", color: "blue"),
            SubCategoryModel(name: "Kasap & Manav", icon: "leaf.fill", color: "green"),
            SubCategoryModel(name: "Damacana Su", icon: "drop.fill", color: "cyan"),
            SubCategoryModel(name: "Temizlik Malzemeleri", icon: "bubbles.and.sparkles.fill", color: "teal"),
            SubCategoryModel(name: "Tekel & Atıştırmalık", icon: "wineglass.fill", color: "purple")
        ]),
        
        CategoryModel(type: .expense, name: "Yeme İçme & Sosyal", icon: "cup.and.saucer.fill", color: "brown", subCategories: [
            SubCategoryModel(name: "Restoran & Yemek", icon: "fork.knife.circle.fill", color: "orange"),
            SubCategoryModel(name: "Kahve & Çay", icon: "mug.fill", color: "brown"),
            SubCategoryModel(name: "Fast Food", icon: "hamburger.fill", color: "yellow"),
            SubCategoryModel(name: "Dışarıda Eğlence & Bar", icon: "party.popper.fill", color: "indigo")
        ]),
        
        CategoryModel(type: .expense, name: "Teknoloji & Yazılım", icon: "laptopcomputer", color: "black", subCategories: [
            SubCategoryModel(name: "Uygulama İçi Satın Alma", icon: "app.badge.fill", color: "blue"),
            SubCategoryModel(name: "Domain & Hosting (Yıllık)", icon: "globe", color: "cyan"),
            SubCategoryModel(name: "Asset & Plugin Alımı", icon: "puzzlepiece.fill", color: "purple"),
            SubCategoryModel(name: "Elektronik Cihaz", icon: "desktopcomputer", color: "gray")
        ]),
        
        CategoryModel(type: .expense, name: "Oyun & Donanım", icon: "gamecontroller.fill", color: "indigo", subCategories: [
            SubCategoryModel(name: "Konsol Oyunu Satın Alma", icon: "dpad.fill", color: "blue"),
            SubCategoryModel(name: "Steam / Epic Alışverişi", icon: "desktopcomputer", color: "gray"),
            SubCategoryModel(name: "Oyun İçi Satın Alma", icon: "cart.badge.plus", color: "orange"),
            SubCategoryModel(name: "Aksesuar (Kol, Kulaklık)", icon: "headset", color: "purple")
        ]),

        CategoryModel(type: .expense, name: "Ev & Yaşam", icon: "sofa.fill", color: "teal", subCategories: [
            SubCategoryModel(name: "Mobilya & Dekorasyon", icon: "lamp.floor.fill", color: "teal"),
            SubCategoryModel(name: "Akıllı Ev Cihazları", icon: "homekit", color: "orange"),
            SubCategoryModel(name: "Ev Tamirat & Tadilat", icon: "hammer.fill", color: "gray")
        ]),

        CategoryModel(type: .expense, name: "Sağlık & Bakım", icon: "heart.fill", color: "red", subCategories: [
            SubCategoryModel(name: "Eczane & İlaç", icon: "pills.fill", color: "red"),
            SubCategoryModel(name: "Hastane & Doktor", icon: "stethoscope", color: "teal"),
            SubCategoryModel(name: "Kuaför & Berber", icon: "scissors", color: "brown"),
            SubCategoryModel(name: "Kişisel Bakım & Kozmetik", icon: "face.smiling", color: "purple")
        ]),
        
        CategoryModel(type: .expense, name: "Giyim & Aksesuar", icon: "tshirt.fill", color: "pink", subCategories: [
            SubCategoryModel(name: "Kıyafet", icon: "tshirt.fill", color: "pink"),
            SubCategoryModel(name: "Ayakkabı", icon: "shoeprints.fill", color: "orange"),
            SubCategoryModel(name: "Çanta & Takı", icon: "bag.fill", color: "purple")
        ]),
        
        CategoryModel(type: .expense, name: "Eğitim & Gelişim", icon: "graduationcap.fill", color: "indigo", subCategories: [
            SubCategoryModel(name: "Kurs & Udemy", icon: "book.closed.fill", color: "indigo"),
            SubCategoryModel(name: "Kitap & Dergi", icon: "book.fill", color: "brown"),
            SubCategoryModel(name: "Seminer & Etkinlik", icon: "ticket.fill", color: "orange")
        ]),
        
        CategoryModel(type: .expense, name: "Seyahat & Tatil", icon: "airplane", color: "blue", subCategories: [
            SubCategoryModel(name: "Uçak / Otobüs Bileti", icon: "ticket.fill", color: "blue"),
            SubCategoryModel(name: "Otel / Konaklama", icon: "bed.double.fill", color: "indigo"),
            SubCategoryModel(name: "Vize & Pasaport", icon: "passport.fill", color: "brown"),
            SubCategoryModel(name: "Yolculuk Harcamaları", icon: "map.fill", color: "green")
        ]),
        
        CategoryModel(type: .expense, name: "Hobi & Müzik", icon: "guitars.fill", color: "orange", subCategories: [
            SubCategoryModel(name: "Enstrüman Ekipmanı", icon: "guitars.fill", color: "orange"),
            SubCategoryModel(name: "Konser & Etkinlik", icon: "music.mic", color: "purple"),
            SubCategoryModel(name: "Diğer Hobiler", icon: "paintpalette.fill", color: "pink")
        ]),
        
        CategoryModel(type: .expense, name: "Hediye & Bağış", icon: "heart.circle.fill", color: "pink", subCategories: [
            SubCategoryModel(name: "Hediye Alımları", icon: "gift.fill", color: "pink"),
            SubCategoryModel(name: "Bağış & Yardımlaşma", icon: "heart.fill", color: "red")
        ]),

        // MARK: - GELİR KATEGORİLERİ (INCOMES)
        
        CategoryModel(type: .income, name: "Maaş & Ana Gelir", icon: "banknote.fill", color: "green", subCategories: [
            SubCategoryModel(name: "Maaş", icon: "dollarsign.circle.fill", color: "green"),
            SubCategoryModel(name: "Prim / Bonus", icon: "gift.fill", color: "orange"),
            SubCategoryModel(name: "Yol / Yemek Yardımı", icon: "creditcard.fill", color: "blue")
        ]),
        
        CategoryModel(type: .income, name: "Freelance & Projeler", icon: "laptopcomputer", color: "purple", subCategories: [
            SubCategoryModel(name: "App Store / IAP Geliri", icon: "app.badge.fill", color: "blue"),
            SubCategoryModel(name: "Dış Proje / Web Tasarım", icon: "desktopcomputer", color: "purple"),
            SubCategoryModel(name: "UI/UX Tasarım Satışı", icon: "fountainpen.tip", color: "pink")
        ]),

        CategoryModel(type: .income, name: "Pasif & Diğer", icon: "plus.circle.fill", color: "mint", subCategories: [
            SubCategoryModel(name: "Cashback / İadeler", icon: "arrow.uturn.left", color: "cyan"),
            SubCategoryModel(name: "İkinci El Satış", icon: "tag.fill", color: "gray"),
            SubCategoryModel(name: "Hediye / Diğer", icon: "heart.fill", color: "pink")
        ])
    ]
}
