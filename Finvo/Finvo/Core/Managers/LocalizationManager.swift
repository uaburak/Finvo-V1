import Foundation
import SwiftUI
import ObjectiveC

// MARK: - LocalizationManager
// Uygulama dili çalışma zamanında değiştirilebilsin diye Bundle swizzling yapıyoruz.
// Böylece Bundle.main.localizedString(forKey:) çağrıları seçilen dildeki .lproj
// klasöründen okur. Bu yaklaşım hem Text("literal") hem de NSLocalizedString() için çalışır.
enum LocalizationManager {
    static func setLanguage(_ language: String) {
        // Sistem tarafına da uygula (iOS Alert, NSError vb. bazı yerler AppleLanguages'a bakar)
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        Bundle.setLanguage(language)
    }
}

private var bundleKey: UInt8 = 0

extension Bundle {
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, FinvoLocalizedBundle.self)
        }
        let path = Bundle.main.path(forResource: language, ofType: "lproj")
        let localizedBundle = path.flatMap { Bundle(path: $0) }
        objc_setAssociatedObject(
            Bundle.main,
            &bundleKey,
            localizedBundle,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

private final class FinvoLocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - String Convenience
extension String {
    /// xcstrings'den okunmuş, uygulamada seçili dildeki karşılığını döndürür.
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Format argümanlı kullanım için: "Merhaba %@".localized(with: name)
    func localized(with arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
}
