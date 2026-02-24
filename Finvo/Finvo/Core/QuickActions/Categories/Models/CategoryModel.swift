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
}

struct CategoriesMockData {
    static var data: [CategoryModel] = [
        // Gider Kategorileri
        CategoryModel(type: .expense, name: "Faturalar", icon: "doc.plaintext.fill", color: .cyan, subCategories: [
            SubCategoryModel(name: "Elektrik", icon: "bolt.fill", color: .yellow, isOn: true),
            SubCategoryModel(name: "Su", icon: "drop.fill", color: .blue, isOn: true),
            SubCategoryModel(name: "Doğalgaz", icon: "flame.fill", color: .orange, isOn: false),
            SubCategoryModel(name: "İnternet", icon: "wifi", color: .indigo, isOn: true)
        ]),
        CategoryModel(type: .expense, name: "Market ve Gıda", icon: "cart.fill", color: .blue, subCategories: [
            SubCategoryModel(name: "Süpermarket", icon: "basket.fill", color: .green, isOn: true),
            SubCategoryModel(name: "Manav", icon: "leaf.fill", color: .green, isOn: true),
            SubCategoryModel(name: "Kasap", icon: "fork.knife", color: .red, isOn: true)
        ]),
        CategoryModel(type: .expense, name: "Kafe ve Restoran", icon: "cup.and.saucer.fill", color: .brown, subCategories: [
            SubCategoryModel(name: "Kahve", icon: "mug.fill", color: .brown, isOn: true),
            SubCategoryModel(name: "Öğle Yemeği", icon: "takeoutbag.and.cup.and.straw.fill", color: .orange, isOn: true),
            SubCategoryModel(name: "Akşam Yemeği", icon: "wineglass.fill", color: .purple, isOn: false)
        ]),
        CategoryModel(type: .expense, name: "Abonelikler", icon: "play.tv.fill", color: .red, subCategories: [
            SubCategoryModel(name: "Video Akış (Netflix vb.)", icon: "tv.fill", color: .red, isOn: true),
            SubCategoryModel(name: "Müzik (Spotify vb.)", icon: "music.note", color: .green, isOn: true),
            SubCategoryModel(name: "Yazılım ve Bulut", icon: "icloud.fill", color: .blue, isOn: true)
        ]),
        CategoryModel(type: .expense, name: "Ulaşım", icon: "car.fill", color: .orange, subCategories: [
            SubCategoryModel(name: "Akaryakıt", icon: "fuelpump.fill", color: .orange, isOn: true),
            SubCategoryModel(name: "Toplu Taşıma", icon: "bus.fill", color: .green, isOn: true),
            SubCategoryModel(name: "Taksi/VIP", icon: "car.side.fill", color: .yellow, isOn: false)
        ]),
        CategoryModel(type: .expense, name: "Sağlık", icon: "cross.case.fill", color: .red, subCategories: [
            SubCategoryModel(name: "Eczane", icon: "pills.fill", color: .blue, isOn: true),
            SubCategoryModel(name: "Hastane/Doktor", icon: "stethoscope", color: .teal, isOn: true)
        ]),
        
        // Gelir Kategorileri
        CategoryModel(type: .income, name: "Maaş", icon: "briefcase.fill", color: .green, subCategories: [
            SubCategoryModel(name: "Düzenli Maaş", icon: "banknote.fill", color: .green, isOn: true),
            SubCategoryModel(name: "Prim / İkramiye", icon: "gift.fill", color: .orange, isOn: true)
        ]),
        CategoryModel(type: .income, name: "Ek Gelir", icon: "laptopcomputer", color: .purple, subCategories: [
            SubCategoryModel(name: "Freelance", icon: "pc", color: .indigo, isOn: true),
            SubCategoryModel(name: "Kira Geliri", icon: "house.fill", color: .blue, isOn: true),
            SubCategoryModel(name: "Yatırım Getirisi", icon: "chart.line.uptrend.xyaxis", color: .green, isOn: true)
        ]),
        CategoryModel(type: .income, name: "Ödüller", icon: "arrow.triangle.swap", color: .orange, subCategories: [
            SubCategoryModel(name: "Nakit İadesi (Cashback)", icon: "creditcard.fill", color: .orange, isOn: true),
            SubCategoryModel(name: "Geri Ödemeler", icon: "arrow.uturn.left.circle.fill", color: .blue, isOn: true)
        ])
    ]
}
