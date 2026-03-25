//
//  TabBarConfigurator.swift
//  [Proje Adı]
//
//  UITabBar'ı window view hiyerarşisinde bulup her UITabBarItem'a
//  image (outline) ve selectedImage (fill) set eder.
//  iOS 26 liquid glass efekti bu iki variant arasında morph yapar.
//
//  KULLANIM:
//  ContentView.swift ile birlikte projeye ekle.
//  .onAppear { TabBarConfigurator.configure(tabs: AppTab.allCases) }
//

import SwiftUI
import UIKit

// MARK: - Tab bar item konfigürasyonu
enum TabBarConfigurator {

    /// Tüm window'ları tarayarak UITabBar'ı bulur ve selectedImage set eder.
    static func configure(tabs: [AppTab], attempt: Int = 0) {
        guard attempt < 10 else { return }

        let delay = attempt == 0 ? 0.3 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for scene in UIApplication.shared.connectedScenes {
                guard let ws = scene as? UIWindowScene else { continue }
                for window in ws.windows {
                    if let tabBar = findTabBar(in: window) {
                        applyImages(to: tabBar, tabs: tabs)
                        return
                    }
                }
            }
            configure(tabs: tabs, attempt: attempt + 1)
        }
    }

    // MARK: Helpers

    private static func applyImages(to tabBar: UITabBar, tabs: [AppTab]) {
        guard let items = tabBar.items else { return }
        for (index, tab) in tabs.enumerated() where index < items.count {
            items[index].image = UIImage(named: tab.iconName(isActive: false))?
                .withRenderingMode(.alwaysTemplate)
            items[index].selectedImage = UIImage(named: tab.iconName(isActive: true))?
                .withRenderingMode(.alwaysTemplate)
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
