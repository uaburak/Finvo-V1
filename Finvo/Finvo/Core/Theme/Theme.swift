import SwiftUI
import Combine

// MARK: - Theme Management
// İleride uygulama içinden temanın değiştirilebilmesi (örn. Mavi Tema, Turuncu Tema) için bir yönetici.
class ThemeManager: ObservableObject {
    @Published var currentTheme: any AppTheme = DefaultTheme()
}

// MARK: - Theme Protocol
// Tüm temaların sağlaması gereken renk tanımları
protocol AppTheme {
    var brandPrimary: Color { get }
    
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
    // Tasarımdaki canlı mavi (#007AFF / #0084FF vb.)
    let brandPrimary = Color(red: 0.0, green: 0.52, blue: 1.0)
    
    // Background 1 (Native system background, Light: White, Dark: Black)
    let background1 = Color(uiColor: .systemBackground)
    
    // Background 2 (Inverted native background, Light: Black, Dark: White)
    let background2 = Color(uiColor: UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark ? .white : .black
    })
    
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
