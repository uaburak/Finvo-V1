//
//  FilterCategory.swift
//  Finvo
//

import SwiftUI

enum FilterCategory: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    case market = "Market"
    case faturalar = "Faturalar"
    case ulasim = "Ulaşım"
    case eglence = "Eğlence"
    case saglik = "Sağlık"
    case giyim = "Giyim"
    case yemek = "Yemek"
    case diger = "Diğer"
    
    var icon: String {
        switch self {
        case .market: return "cart.fill"
        case .faturalar: return "doc.text.fill"
        case .ulasim: return "car.fill"
        case .eglence: return "gamecontroller.fill"
        case .saglik: return "cross.fill"
        case .giyim: return "tshirt.fill"
        case .yemek: return "fork.knife"
        case .diger: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .market: return .blue
        case .faturalar: return .orange
        case .ulasim: return .gray
        case .eglence: return .purple
        case .saglik: return .red
        case .giyim: return .pink
        case .yemek: return .green
        case .diger: return .secondary
        }
    }
}
