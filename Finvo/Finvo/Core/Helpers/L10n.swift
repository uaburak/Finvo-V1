//
//  L10n.swift
//  Finvo
//
//  Centralized localization helper that always respects the user's
//  chosen appLanguage (stored in UserDefaults) rather than the iOS
//  system language. Call L10n("key") anywhere to get the correct translation.
//

import Foundation

/// Resolves a localization key against the user-selected language bundle.
/// Falls back to `NSLocalizedString` if the bundle cannot be loaded.
func L10n(_ key: String) -> String {
    let appLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
    if let path = Bundle.main.path(forResource: appLang, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    return NSLocalizedString(key, comment: "")
}
