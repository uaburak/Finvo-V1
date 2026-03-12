import Foundation
import SwiftUI

struct SubCategoryModel: Identifiable {
    let id = UUID()
    let name: LocalizedStringKey
    let icon: String // SF Symbol
    let color: Color
    var isOn: Bool = true // toggle state
}

struct CategoryModel: Identifiable {
    let id = UUID()
    let type: TransactionType
    let name: LocalizedStringKey
    let icon: String // SF Symbol
    let color: Color
    var subCategories: [SubCategoryModel]
    var isOn: Bool = true
}

struct CategoriesMockData {
    static var data: [CategoryModel] = [
        // MARK: - GİDER KATEGORİLERİ (EXPENSES)
                
                // 1. Market ve Gıda
                CategoryModel(type: .expense, name: "Market ve Gıda", icon: "cart.fill", color: .blue, subCategories: [
                    SubCategoryModel(name: "Süpermarket", icon: "basket.fill", color: .blue),
                    SubCategoryModel(name: "Manav", icon: "leaf.fill", color: .green),
                    SubCategoryModel(name: "Kasap", icon: "fork.knife", color: .red),
                    SubCategoryModel(name: "Fırın & Pastane", icon: "mouth.fill", color: .orange),
                    SubCategoryModel(name: "İçecek & Tekel", icon: "wineglass.fill", color: .purple),
                    SubCategoryModel(name: "Su Siparişi (Damacana)", icon: "drop.fill", color: .cyan),
                    SubCategoryModel(name: "Temizlik Malzemeleri", icon: "bubbles.and.sparkles.fill", color: .teal)
                ]),
                
                // 2. Dışarıda Yemek ve Sosyal
                CategoryModel(type: .expense, name: "Yeme İçme & Sosyal", icon: "cup.and.saucer.fill", color: .brown, subCategories: [
                    SubCategoryModel(name: "Kahve & Çay", icon: "mug.fill", color: .brown),
                    SubCategoryModel(name: "Restoran & Akşam Yemeği", icon: "fork.knife.circle.fill", color: .orange),
                    SubCategoryModel(name: "Öğle Yemeği (İş)", icon: "bag.fill", color: .yellow),
                    SubCategoryModel(name: "Fast Food & Atıştırmalık", icon: "hamburger.fill", color: .red),
                    SubCategoryModel(name: "Bar & Gece Hayatı", icon: "party.popper.fill", color: .indigo),
                    SubCategoryModel(name: "Etkinlik & Konser", icon: "music.mic", color: .pink)
                ]),
                
                // 3. Konut ve Ev Giderleri
                CategoryModel(type: .expense, name: "Konut ve Ev", icon: "house.fill", color: .indigo, subCategories: [
                    SubCategoryModel(name: "Kira / Kredi Ödemesi", icon: "key.fill", color: .indigo),
                    SubCategoryModel(name: "Aidat", icon: "building.2.fill", color: .gray),
                    SubCategoryModel(name: "Ev Tamirat & Tadilat", icon: "hammer.fill", color: .orange),
                    SubCategoryModel(name: "Mobilya & Dekorasyon", icon: "lamp.floor.fill", color: .teal),
                    SubCategoryModel(name: "Bahçe & Dış Mekan", icon: "camera.macro", color: .green),
                    SubCategoryModel(name: "Emlak Vergisi", icon: "doc.text.fill", color: .red)
                ]),
                
                // 4. Faturalar ve Abonelikler
                CategoryModel(type: .expense, name: "Sabit Ödemeler", icon: "doc.plaintext.fill", color: .cyan, subCategories: [
                    SubCategoryModel(name: "Elektrik", icon: "bolt.fill", color: .yellow),
                    SubCategoryModel(name: "Su", icon: "drop.circle.fill", color: .blue),
                    SubCategoryModel(name: "Doğalgaz", icon: "flame.fill", color: .orange),
                    SubCategoryModel(name: "İnternet", icon: "wifi", color: .indigo),
                    SubCategoryModel(name: "Telefon/GSM", icon: "iphone", color: .gray),
                    SubCategoryModel(name: "Dijital Platform (Netflix/Spotify)", icon: "play.tv.fill", color: .red),
                    SubCategoryModel(name: "Yazılım / iCloud / Google One", icon: "icloud.fill", color: .blue)
                ]),
                
                // 5. Ulaşım ve Araç
                CategoryModel(type: .expense, name: "Ulaşım", icon: "car.fill", color: .orange, subCategories: [
                    SubCategoryModel(name: "Akaryakıt", icon: "fuelpump.fill", color: .orange),
                    SubCategoryModel(name: "Toplu Taşıma (Akbil vb.)", icon: "bus.fill", color: .green),
                    SubCategoryModel(name: "Taksi & Martı & Uber", icon: "car.side.fill", color: .yellow),
                    SubCategoryModel(name: "Araç Bakım & Servis", icon: "wrench.and.screwdriver.fill", color: .blue),
                    SubCategoryModel(name: "Otopark & Köprü/Yol", icon: "parkingsign.circle.fill", color: .gray),
                    SubCategoryModel(name: "Trafik Sigortası & Kasko", icon: "shield.checkerboard", color: .red)
                ]),
                
                // 6. Alışveriş ve Kişisel Bakım
                CategoryModel(type: .expense, name: "Alışveriş & Bakım", icon: "bag.fill", color: .pink, subCategories: [
                    SubCategoryModel(name: "Giyim & Ayakkabı", icon: "tshirt.fill", color: .pink),
                    SubCategoryModel(name: "Aksesuar & Takı", icon: "sparkles", color: .yellow),
                    SubCategoryModel(name: "Elektronik & Gadget", icon: "laptopcomputer", color: .blue),
                    SubCategoryModel(name: "Kozmetik & Parfüm", icon: "face.smiling", color: .purple),
                    SubCategoryModel(name: "Kuaför & Berber", icon: "scissors", color: .brown),
                    SubCategoryModel(name: "Kuru Temizleme", icon: "washer.fill", color: .cyan)
                ]),
                
                // 7. Sağlık ve Spor
                CategoryModel(type: .expense, name: "Sağlık ve Spor", icon: "heart.fill", color: .red, subCategories: [
                    SubCategoryModel(name: "Eczane & İlaç", icon: "pills.fill", color: .red),
                    SubCategoryModel(name: "Doktor & Hastane", icon: "stethoscope", color: .teal),
                    SubCategoryModel(name: "Diş Randevusu", icon: "mouth", color: .white),
                    SubCategoryModel(name: "Spor Salonu Üyeliği", icon: "figure.run", color: .orange),
                    SubCategoryModel(name: "Vitamin & Takviye", icon: "leaf.arrow.triangle.circlepath", color: .green),
                    SubCategoryModel(name: "Terapi & Danışmanlık", icon: "brain.head.profile", color: .purple)
                ]),
                
                // 8. Eğitim ve Gelişim
                CategoryModel(type: .expense, name: "Eğitim", icon: "graduationcap.fill", color: .indigo, subCategories: [
                    SubCategoryModel(name: "Kurs & Eğitim Ücreti", icon: "graduationcap.fill", color: .indigo),
                    SubCategoryModel(name: "Kitap & Dergi", icon: "book.fill", color: .brown),
                    SubCategoryModel(name: "Kırtasiye", icon: "pencil.and.ruler.fill", color: .blue),
                    SubCategoryModel(name: "Sınav Başvuruları", icon: "doc.text.badge.plus", color: .gray),
                    SubCategoryModel(name: "Dil Eğitimi", icon: "character.bubble.fill", color: .orange)
                ]),
                
                // 9. Çocuk ve Aile
                CategoryModel(type: .expense, name: "Çocuk ve Aile", icon: "figure.and.child.holdinghands", color: .mint, subCategories: [
                    SubCategoryModel(name: "Okul Taksitleri", icon: "building.columns.fill", color: .indigo),
                    SubCategoryModel(name: "Oyuncak & Oyun", icon: "puzzlepiece.fill", color: .orange),
                    SubCategoryModel(name: "Bebek Bezi & Mama", icon: "stroller.fill", color: .blue),
                    SubCategoryModel(name: "Harçlık", icon: "hand.waves.fill", color: .green)
                ]),
                
                // 10. Evcil Hayvan
                CategoryModel(type: .expense, name: "Evcil Hayvan", icon: "pawprint.fill", color: .orange, subCategories: [
                    SubCategoryModel(name: "Mama & Kum", icon: "shippingbox.fill", color: .brown),
                    SubCategoryModel(name: "Veteriner & Aşı", icon: "cross.case.fill", color: .red),
                    SubCategoryModel(name: "Oyuncak & Aksesuar", icon: "tennisball.fill", color: .green)
                ]),
                
                // 11. Finansal Giderler
                CategoryModel(type: .expense, name: "Finansal Giderler", icon: "dollarsign.circle.fill", color: .gray, subCategories: [
                    SubCategoryModel(name: "Borç Ödemesi", icon: "arrow.right.arrow.left.circle.fill", color: .red),
                    SubCategoryModel(name: "Banka Komisyon & Ücret", icon: "building.columns", color: .gray),
                    SubCategoryModel(name: "Bağış & Yardımlaşma", icon: "heart.circle.fill", color: .pink),
                    SubCategoryModel(name: "Cezalar (Trafik vb.)", icon: "exclamationmark.triangle.fill", color: .orange)
                ]),
                
                // 12. Seyahat ve Tatil
                CategoryModel(type: .expense, name: "Seyahat", icon: "airplane", color: .blue, subCategories: [
                    SubCategoryModel(name: "Uçak & Otobüs Bileti", icon: "ticket.fill", color: .blue),
                    SubCategoryModel(name: "Konaklama / Otel", icon: "bed.double.fill", color: .indigo),
                    SubCategoryModel(name: "Vize & Pasaport", icon: "passport.fill", color: .brown),
                    SubCategoryModel(name: "Tur & Gezi", icon: "map.fill", color: .green)
                ]),

                // MARK: - GELİR KATEGORİLERİ (INCOMES)
                
                // 1. İş ve Maaş
                CategoryModel(type: .income, name: "Maaş ve İş", icon: "briefcase.fill", color: .green, subCategories: [
                    SubCategoryModel(name: "Ana Maaş", icon: "banknote.fill", color: .green),
                    SubCategoryModel(name: "Prim & İkramiye", icon: "gift.fill", color: .orange),
                    SubCategoryModel(name: "Freelance Proje", icon: "laptopcomputer", color: .purple),
                    SubCategoryModel(name: "Yemek Kartı Yüklemesi", icon: "creditcard.fill", color: .blue)
                ]),
                
                // 2. Yatırım Getirileri
                CategoryModel(type: .income, name: "Yatırım Getirisi", icon: "chart.line.uptrend.xyaxis", color: .teal, subCategories: [
                    SubCategoryModel(name: "Borsa / Temettü", icon: "chart.line.trend.up", color: .green),
                    SubCategoryModel(name: "Kripto Kar Satışı", icon: "bitcoinsign.circle.fill", color: .orange),
                    SubCategoryModel(name: "Faiz Getirisi", icon: "percent", color: .teal),
                    SubCategoryModel(name: "Döviz Kuru Farkı", icon: "eurosign.arrow.circlepath", color: .blue)
                ]),
                
                // 3. Pasif ve Diğer Gelirler
                CategoryModel(type: .income, name: "Diğer Gelirler", icon: "plus.circle.fill", color: .mint, subCategories: [
                    SubCategoryModel(name: "Kira Geliri", icon: "house.fill", color: .blue),
                    SubCategoryModel(name: "Eşya Satışı (İkinci El)", icon: "tag.fill", color: .gray),
                    SubCategoryModel(name: "Cashback & İadeler", icon: "arrow.uturn.left.circle.fill", color: .cyan),
                    SubCategoryModel(name: "Hediye Geliri", icon: "heart.fill", color: .pink),
                    SubCategoryModel(name: "Vergi İadesi", icon: "doc.text.magnifyingglass", color: .gray)
                ])
    ]
}
