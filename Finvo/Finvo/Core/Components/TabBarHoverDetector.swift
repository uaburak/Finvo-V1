//
//  TabBarImageConfigurator.swift
//  Finvo
//
//  UITabBar'ı window view hiyerarşisinde bulup her UITabBarItem'a
//  image (outline) ve selectedImage (fill) set eder.
//  iOS 26 liquid glass efekti bu iki variant arasında morph yapar.
//

import SwiftUI
import UIKit

// MARK: - Tab bar item konfigürasyonu
/// ContentView'dan .onAppear ile çağrılır.
enum TabBarConfigurator {

    /// Tüm window'ları tarayarak UITabBar'ı bulur ve selectedImage set eder.
    /// Bulamazsa otomatik retry yapar (max 10 deneme).
    static func configure(tabs: [AppTab], attempt: Int = 0) {
        guard attempt < 10 else {
            print("❌ TabBarConfigurator: UITabBar bulunamadı (\(attempt) deneme)")
            return
        }

        let delay = attempt == 0 ? 0.3 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Tüm sahnelerdeki tüm pencereleri tara
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                for window in ws.windows {
                    if let tabBar = findTabBar(in: window) {
                        applyImages(to: tabBar, tabs: tabs)
                        return
                    }
                }
            }
            // Bulunamadı, tekrar dene
            print("⏳ TabBarConfigurator: UITabBar henüz yok, retry \(attempt + 1)")
            configure(tabs: tabs, attempt: attempt + 1)
        }
    }

    // MARK: Helpers

    private static func applyImages(to tabBar: UITabBar, tabs: [AppTab]) {
        guard let items = tabBar.items else {
            print("❌ TabBarConfigurator: tabBar.items nil")
            return
        }
        print("ℹ️ TabBarConfigurator: \(items.count) item bulundu")

        for (index, tab) in tabs.enumerated() where index < items.count {
            let outline = UIImage(named: tab.iconName(isActive: false))?
                .withRenderingMode(.alwaysTemplate)
            let fill = UIImage(named: tab.iconName(isActive: true))?
                .withRenderingMode(.alwaysTemplate)

            items[index].image = outline
            items[index].selectedImage = fill

            print("  ✅ [\(index)] \(tab.rawValue) → outline: \(outline != nil), fill: \(fill != nil)")
        }
    }

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar { return tabBar }
        for sub in view.subviews {
            if let found = findTabBar(in: sub) { return found }
        }
        return nil
    }
}
