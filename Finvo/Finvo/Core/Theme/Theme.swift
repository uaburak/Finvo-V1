import SwiftUI
import Combine

// MARK: - Theme Management
// İleride uygulama içinden temanın değiştirilebilmesi (örn. Mavi Tema, Turuncu Tema) için bir yönetici.
class ThemeManager: ObservableObject {
    @Published var currentTheme: any AppTheme = DefaultTheme()
}

// MARK: - App Theme Color
enum AppThemeColor: String, CaseIterable, Identifiable {
    case neonGreen = "neonGreen"
    case blue = "blue"
    case pink = "pink"
    case orange = "orange"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .neonGreen: return "Finvo"
        case .blue: return "Mavi"
        case .pink: return "Pembe"
        case .orange: return "Turuncu"
        }
    }

    var title: String { titleKey.localized }
    var color: Color {
        switch self {
        case .neonGreen: 
            return Color(uiColor: UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "AEFF23")) : UIColor(Color(hex: "82ED00"))
            })
        case .blue: return Color(hex: "0088FF")
        case .pink: return Color(hex: "FF2D55")
        case .orange: return Color(hex: "FF9500")
        }
    }
    
    var onBrandPrimary: Color {
        switch self {
        case .neonGreen: return .black
        case .blue: return .white
        case .pink: return .white
        case .orange: return .white
        }
    }
    
    var uiOnBrandPrimary: UIColor {
        switch self {
        case .neonGreen: return .black
        case .blue: return .white
        case .pink: return .white
        case .orange: return .white
        }
    }
    
    var uiColor: UIColor {
 
        switch self {
        case .neonGreen: 
            return UIColor { traitCollection in
                return traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "AEFF23")) : UIColor(Color(hex: "82ED00"))
            }
        case .blue: return UIColor(Color(hex: "0088FF"))
        case .pink: return UIColor(Color(hex: "FF2D55"))
        case .orange: return UIColor(Color(hex: "FF9500"))
        }
    }
}

// MARK: - Theme Protocol
// Tüm temaların sağlaması gereken renk tanımları
protocol AppTheme {
    var brandPrimary: Color { get }
    var onBrandPrimary: Color { get }
    
    var background1: Color { get }
    var background2: Color { get }
    
    var cardBackground: Color { get }
    
    var labelPrimary: Color { get }
    var labelSecondary: Color { get }
    
    var separator: Color { get }
    var separatorSecondary: Color { get }
    
    var income: Color { get }
    var expense: Color { get }
}

// MARK: - Default Theme (Figma Tasarımı)
struct DefaultTheme: AppTheme {
    var colorIdentifier: String = AppThemeColor.neonGreen.rawValue
    
    var brandPrimary: Color {
        AppThemeColor(rawValue: colorIdentifier)?.color ?? Color(uiColor: UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(Color(hex: "AEFF23")) : UIColor(Color(hex: "82ED00"))
        })
    }
    
    var onBrandPrimary: Color {
        AppThemeColor(rawValue: colorIdentifier)?.onBrandPrimary ?? .black
    }
    
    // Background 1 (Native system background, Light: White, Dark: Black)
    let background1 = Color(uiColor: .systemBackground)
    
    // Background 2 (Adaptive secondary background)
    let background2 = Color(uiColor: .secondarySystemBackground)
    
    // Card Background (Figma - Light: Black 4%, Dark: White 6%)
    let cardBackground = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.06) : UIColor(white: 0.0, alpha: 0.04)
    })
    
    // Labels (Native primary/secondary)
    let labelPrimary = Color.primary
    let labelSecondary = Color.secondary
    
    // Separator (Figma - Light: Black 8%, Dark: White 12%)
    let separator = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.12) : UIColor(white: 0.0, alpha: 0.08)
    })
    
    // Separator 2 (Figma - Light: Black 4%, Dark: White 6%)
    let separatorSecondary = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ? UIColor(white: 1.0, alpha: 0.06) : UIColor(white: 0.0, alpha: 0.04)
    })
    
    // Fonksiyonel renkler
    let income = Color.green
    let expense = Color.red
}

// MARK: - Environment Extension
// View'larda `@Environment(\.theme) var theme` şeklinde kullanabilmek için:
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any AppTheme = DefaultTheme()
}

extension EnvironmentValues {
    var theme: any AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
