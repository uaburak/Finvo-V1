import Foundation
import SwiftUI

enum TransactionType: String, Codable, CaseIterable {
    case income
    case expense
}

struct TransactionItemModel: Identifiable, Equatable {
    let id = UUID()
    let type: TransactionType
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let amount: Double
    let date: String
    let timestamp: Date
    
    static func == (lhs: TransactionItemModel, rhs: TransactionItemModel) -> Bool {
        lhs.id == rhs.id
    }
}
