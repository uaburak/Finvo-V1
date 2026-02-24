import os
import random

model_content = """import Foundation
import SwiftUI

enum TransactionType {
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
    
    static func == (lhs: TransactionItemModel, rhs: TransactionItemModel) -> Bool {
        lhs.id == rhs.id
    }
}

enum TransactionTimeGroup: String, CaseIterable, Identifiable {
    case today = "Bugün"
    case yesterday = "Dün"
    case thisWeek = "Bu Hafta"
    case thisMonth = "Bu Ay"
    case thisYear = "Bu Yıl"
    case lastYear = "Geçen Yıl"
    
    var id: String { rawValue }
    
    var title: LocalizedStringKey {
        switch self {
        case .today: return "Bugün"
        case .yesterday: return "Dün"
        case .thisWeek: return "Bu Hafta"
        case .thisMonth: return "Bu Ay"
        case .thisYear: return "Bu Yıl"
        case .lastYear: return "Geçen Yıl"
        }
    }
}

struct TransactionGroup: Identifiable {
    let id: TransactionTimeGroup
    var transactions: [TransactionItemModel]
}
"""

with open("/Users/burak/Desktop/Burak/Finvo V1/Kod/Finvo V1/Finvo/Finvo/Core/Transactions/Models/TransactionItemModel.swift", "w", encoding="utf-8") as f:
    f.write(model_content)

titles_expense = [("Market Alışverişi", "Temel İhtiyaçlar", "cart.fill", ".blue", 100, 1500),
                  ("Su Faturası", "Faturalar", "drop.fill", ".cyan", 100, 300),
                  ("Amazon", "Alışveriş", "bag.fill", ".orange", 200, 5000),
                  ("Netflix", "Abonelikler", "play.tv.fill", ".red", 50, 250),
                  ("Kahve", "Kafe", "cup.and.saucer.fill", ".brown", 40, 150)]
titles_income = [("Maaş", "Ana Gelir", "briefcase.fill", ".green", 20000, 50000),
                 ("Nakit İadesi", "Kredi Kartı", "arrow.triangle.swap", ".orange", 50, 500),
                 ("Freelance", "Ek Gelir", "laptopcomputer", ".purple", 1000, 10000)]

def gen_group(enum_val, count, inc_chance):
    items = []
    for _ in range(count):
        is_inc = random.random() < inc_chance
        pool = titles_income if is_inc else titles_expense
        c = random.choice(pool)
        amt = round(random.uniform(c[4], c[5]), 2)
        type_str = ".income" if is_inc else ".expense"
        time_str = f"{random.randint(10, 23)}:{random.choice(['00', '15', '30', '45'])}"
        
        if enum_val == ".today":
            date_str = f"Bugün {time_str}"
        elif enum_val == ".yesterday":
            date_str = f"Dün {time_str}"
        elif enum_val == ".thisWeek":
            date_str = f"{random.randint(1, 7)} Eki 2025"
        elif enum_val == ".thisMonth":
            date_str = f"{random.randint(1, 30)} Eki 2025"
        elif enum_val == ".thisYear":
            date_str = f"{random.randint(1, 28)} Eyl 2025"
        elif enum_val == ".lastYear":
            date_str = f"{random.randint(1, 28)} Eyl 2024"
        else:
            date_str = time_str
            
        items.append(f'            TransactionItemModel(type: {type_str}, icon: "{c[2]}", color: {c[3]}, title: "{c[0]}", subtitle: "{c[1]}", amount: {amt}, date: "{date_str}")')
    
    return f"        TransactionGroup(id: {enum_val}, transactions: [\n" + ",\n".join(items) + "\\n        ])"

groups = [
    gen_group(".today", 3, 0.2),
    gen_group(".yesterday", 3, 0.2),
    gen_group(".thisWeek", 3, 0.3),
    gen_group(".thisMonth", 3, 0.3),
    gen_group(".thisYear", 3, 0.3),
    gen_group(".lastYear", 15, 0.3)
]

join_str = ",\\n"
mock_data_content = f"""import Foundation

struct TransactionsMockData {{
    static let groups: [TransactionGroup] = [
{join_str.join(groups)}
    ]
}}
"""

with open("/Users/burak/Desktop/Burak/Finvo V1/Kod/Finvo V1/Finvo/Finvo/Core/Transactions/Models/TransactionsMockData.swift", "w", encoding="utf-8") as f:
    f.write(mock_data_content)

print("Models Generated.")
