import Foundation

// MARK: - Enums
enum AnalysisTimeFrame: String, CaseIterable, Identifiable {
    case day = "Gün"
    case week = "Haftalık"
    case month = "Ay"
    case year = "Yıl"
    var id: String { self.rawValue }
}

// MARK: - Models
struct FlowData: Identifiable, Equatable {
    let id: Date
    let date: Date
    var netAmount: Double
    var animate: Bool = false
}

struct CategorySummary: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let amount: Double
    let icon: String
    let percentage: Double
    let transactionCount: Int
}

struct MemberContribution: Identifiable, Equatable {
    var id: String { username }
    let username: String
    let amount: Double
    let transactionCount: Int
}
