import Foundation
import SwiftUI

struct TransactionsMockData {
    static let items: [TransactionItemModel] = {
        let now = Date()
        let calendar = Calendar.current
        
        func makeDate(daysAgo: Int) -> Date {
            calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        }
        
        return [
            TransactionItemModel(type: .income, icon: "laptopcomputer", color: .purple, title: "Freelance", subtitle: "Ek Gelir", amount: 5998.1, date: "Bugün 11:45", timestamp: makeDate(daysAgo: 0)),
            TransactionItemModel(type: .expense, icon: "cart.fill", color: .blue, title: "Market Alışverişi", subtitle: "Temel İhtiyaçlar", amount: 223.49, date: "Bugün 20:00", timestamp: makeDate(daysAgo: 0)),
            TransactionItemModel(type: .income, icon: "laptopcomputer", color: .purple, title: "Freelance", subtitle: "Ek Gelir", amount: 1406.74, date: "Bugün 12:45", timestamp: makeDate(daysAgo: 0)),
            
            TransactionItemModel(type: .expense, icon: "cart.fill", color: .blue, title: "Market Alışverişi", subtitle: "Temel İhtiyaçlar", amount: 1125.35, date: "Dün 12:15", timestamp: makeDate(daysAgo: 1)),
            TransactionItemModel(type: .expense, icon: "cup.and.saucer.fill", color: .brown, title: "Kahve", subtitle: "Kafe", amount: 57.56, date: "Dün 20:00", timestamp: makeDate(daysAgo: 1)),
            TransactionItemModel(type: .expense, icon: "cart.fill", color: .blue, title: "Market Alışverişi", subtitle: "Temel İhtiyaçlar", amount: 1228.43, date: "Dün 16:15", timestamp: makeDate(daysAgo: 1)),
            
            TransactionItemModel(type: .expense, icon: "cart.fill", color: .blue, title: "Market Alışverişi", subtitle: "Temel İhtiyaçlar", amount: 531.77, date: "Geçen Hafta", timestamp: makeDate(daysAgo: 5)),
            TransactionItemModel(type: .expense, icon: "play.tv.fill", color: .red, title: "Netflix", subtitle: "Abonelikler", amount: 189.06, date: "Geçen Hafta", timestamp: makeDate(daysAgo: 6)),
            TransactionItemModel(type: .income, icon: "arrow.triangle.swap", color: .orange, title: "Nakit İadesi", subtitle: "Kredi Kartı", amount: 384.23, date: "Geçen Hafta", timestamp: makeDate(daysAgo: 7)),
            
            TransactionItemModel(type: .income, icon: "briefcase.fill", color: .green, title: "Maaş", subtitle: "Ana Gelir", amount: 42558.76, date: "Geçen Ay", timestamp: makeDate(daysAgo: 15)),
            TransactionItemModel(type: .income, icon: "briefcase.fill", color: .green, title: "Maaş", subtitle: "Ana Gelir", amount: 38742.55, date: "Geçen Ay", timestamp: makeDate(daysAgo: 20)),
            TransactionItemModel(type: .income, icon: "arrow.triangle.swap", color: .orange, title: "Nakit İadesi", subtitle: "Kredi Kartı", amount: 446.76, date: "Geçen Ay", timestamp: makeDate(daysAgo: 25)),
            
            TransactionItemModel(type: .income, icon: "arrow.triangle.swap", color: .orange, title: "Nakit İadesi", subtitle: "Kredi Kartı", amount: 475.98, date: "Geçen Yıl", timestamp: makeDate(daysAgo: 60)),
            TransactionItemModel(type: .income, icon: "briefcase.fill", color: .green, title: "Maaş", subtitle: "Ana Gelir", amount: 36772.87, date: "Geçen Yıl", timestamp: makeDate(daysAgo: 90)),
            TransactionItemModel(type: .income, icon: "laptopcomputer", color: .purple, title: "Freelance", subtitle: "Ek Gelir", amount: 1931.93, date: "Geçen Yıl", timestamp: makeDate(daysAgo: 120))
        ]
    }()
}
