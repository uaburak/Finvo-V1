//
//  FinvoApp.swift
//  Finvo
//
//  Created by Burak KOÇ on 20.02.2026.
//

import SwiftUI

@main
struct FinvoApp: App {
    @AppStorage("appLanguage") private var appLanguage: String = "tr"
    
    init() {
        // Konsoldaki gereksiz AutoLayout ve klavye uyarılarını gizlemek için
        UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Seçilen dile göre tüm uygulama arayüzünü anında render eder
                .environment(\.locale, Locale(identifier: appLanguage))
        }
    }
}
