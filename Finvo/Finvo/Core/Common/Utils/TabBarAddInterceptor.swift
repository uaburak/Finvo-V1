import SwiftUI
import UIKit

// MARK: - TabBarAddInterceptor
// UITabBarController delegate'ini UIKit seviyesinde intercept eder.
// Kullanıcı Add tabına bastığında:
//   1. shouldSelect → return false → UIKit hiç seçim yapmaz
//   2. SwiftUI state değişmez → NavigationStack'ler korunur
//   3. onAddTapped() → sheet açılır
//
// Orijinal SwiftUI delegate forwarding ile tam uyumlu.

struct TabBarAddInterceptor: UIViewRepresentable {
    @Binding var showAddSheet: Bool
    var addTabIndex: Int = 2 // AppTab sıralamasında "add" (0-indexed)

    func makeCoordinator() -> Coordinator {
        Coordinator(addTabIndex: addTabIndex)
    }

    func makeUIView(context: Context) -> TriggerView {
        let view = TriggerView(coordinator: context.coordinator)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: TriggerView, context: Context) {
        // Binding her güncellendiğinde closure'ı taze tut
        context.coordinator.onAddTapped = {
            showAddSheet = true
        }
    }
}

// MARK: - TriggerView
// View hiyerarşisine girince UITabBarController'ı bulup delegate kurar.
extension TabBarAddInterceptor {
    class TriggerView: UIView {
        let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            // SwiftUI kendi delegate kurulumunu bitirsin diye bir tik bekle
            DispatchQueue.main.async { [weak self] in
                self?.coordinator.install(from: self)
            }
        }
    }
}

// MARK: - Coordinator
extension TabBarAddInterceptor {
    final class Coordinator: NSObject, UITabBarControllerDelegate {
        let addTabIndex: Int
        var onAddTapped: (() -> Void)?

        private weak var originalDelegate: UITabBarControllerDelegate?
        private weak var managedTBC: UITabBarController?

        init(addTabIndex: Int) {
            self.addTabIndex = addTabIndex
        }

        // MARK: Install
        func install(from view: UIView?) {
            guard let tbc = findTabBarController(from: view) else { return }
            guard managedTBC !== tbc else { return } // zaten kurulu

            // SwiftUI'nin mevcut delegate'ini sakla → forwarding için
            if !(tbc.delegate is Coordinator) {
                originalDelegate = tbc.delegate
            }
            tbc.delegate = self
            managedTBC = tbc
        }

        // MARK: - UITabBarControllerDelegate

        /// UIKit, kullanıcı tab'a bastığında bunu çağırır.
        /// `false` döndürmek seçimi tamamen engeller — UIKit state değişmez.
        func tabBarController(_ tabBarController: UITabBarController,
                              shouldSelect viewController: UIViewController) -> Bool {
            if let index = tabBarController.viewControllers?.firstIndex(of: viewController),
               index == addTabIndex {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onAddTapped?()
                return false // ← UIKit tab geçişini engelle
            }
            return originalDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
        }

        func tabBarController(_ tabBarController: UITabBarController,
                              didSelect viewController: UIViewController) {
            originalDelegate?.tabBarController?(tabBarController, didSelect: viewController)
        }

        // Orijinal delegate'in diğer methodlarını şeffaf olarak yönlendir
        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if let orig = originalDelegate, orig.responds(to: aSelector) { return orig }
            return super.forwardingTarget(for: aSelector)
        }

        // MARK: - UITabBarController Finder

        private func findTabBarController(from view: UIView?) -> UITabBarController? {
            // 1. Responder chain'den yukarı çık
            var responder: UIResponder? = view
            while let r = responder {
                if let tbc = r as? UITabBarController { return tbc }
                responder = r.next
            }

            // 2. Window hierarchy
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                let windows = scene.windows.filter { !$0.isHidden }
                for window in windows {
                    if let tbc = findTBC(in: window.rootViewController) { return tbc }
                }
            }
            return nil
        }

        private func findTBC(in vc: UIViewController?) -> UITabBarController? {
            guard let vc else { return nil }
            if let tbc = vc as? UITabBarController { return tbc }
            for child in vc.children {
                if let found = findTBC(in: child) { return found }
            }
            return findTBC(in: vc.presentedViewController)
        }
    }
}
