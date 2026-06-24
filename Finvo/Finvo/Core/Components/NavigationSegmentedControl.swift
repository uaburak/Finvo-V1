import SwiftUI

// MARK: - NavigationSegmentedControl
// iOS 26 liquid glass ghost text bug'ını bypass eden segmented control.
// SwiftUI toolbar yerine UIKit'in navigationItem.titleView özelliğini kullanır.
// Apple'ın Telefon uygulamasıyla aynı mekanizma.
//
// Kullanım:
//   .navigationSegmentedControl(
//       selection: $selectedIndex,
//       items: ["Gider", "Gelir"]
//   )

// MARK: - View Modifier
extension View {
    /// Navigation bar'a liquid glass uyumlu segmented control ekler.
    /// SwiftUI toolbar yerine UIKit'in navigationItem.titleView'ını kullanır.
    func navigationSegmentedControl(
        selection: Binding<Int>,
        items: [String],
        width: CGFloat? = nil
    ) -> some View {
        self.background(
            NavigationSegmentedConfigurator(
                selectedIndex: selection,
                items: items,
                width: width
            )
        )
    }
}

// MARK: - Configurator
struct NavigationSegmentedConfigurator: UIViewRepresentable {
    @Binding var selectedIndex: Int
    let items: [String]
    let width: CGFloat?
    
    func makeUIView(context: Context) -> SegmentedAnchorView {
        let view = SegmentedAnchorView()
        view.onLayoutOrMove = { [weak view] in
            guard let view = view else { return }
            installOrRefresh(in: view, context: context)
        }
        return view
    }
    
    func updateUIView(_ uiView: SegmentedAnchorView, context: Context) {
        // En son durumu zorla uygula
        if let vc = uiView.findHostingVC(), let control = context.coordinator.segmentedControl {
            let targetVC = updateTitleView(on: vc, with: control)
            context.coordinator.observeTitleView(on: targetVC, control: control)
        }
        
        guard let control = context.coordinator.segmentedControl else { return }
        
        // Segment başlıklarını güncelle (dil değişimi için)
        for (i, title) in items.enumerated() {
            if i < control.numberOfSegments {
                control.setTitle(title, forSegmentAt: i)
            }
        }
        
        // Seçili index'i güncelle
        if control.selectedSegmentIndex != selectedIndex {
            control.selectedSegmentIndex = selectedIndex
        }
    }
    
    @discardableResult
    private func updateTitleView(on vc: UIViewController, with control: UISegmentedControl) -> UIViewController {
        var targetVC = vc
        var current: UIViewController? = vc
        while let c = current {
            if c is UINavigationController || c is UITabBarController {
                break
            }
            if c.navigationItem.titleView !== control {
                c.navigationItem.titleView = control
            }
            targetVC = c
            current = c.parent
        }
        return targetVC
    }
    
    private func installOrRefresh(in view: UIView, context: Context) {
        guard let vc = view.findHostingVC() else { return }
        
        let control: UISegmentedControl
        if let existing = context.coordinator.segmentedControl {
            control = existing
        } else {
            let segmented = UISegmentedControl(items: items)
            segmented.selectedSegmentIndex = selectedIndex
            segmented.addTarget(
                context.coordinator,
                action: #selector(Coordinator.valueChanged(_:)),
                for: .valueChanged
            )
            
            if let width = width {
                segmented.translatesAutoresizingMaskIntoConstraints = false
                segmented.widthAnchor.constraint(equalToConstant: width).isActive = true
            }
            
            context.coordinator.segmentedControl = segmented
            control = segmented
        }
        
        let targetVC = updateTitleView(on: vc, with: control)
        context.coordinator.observeTitleView(on: targetVC, control: control)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: NavigationSegmentedConfigurator
        var segmentedControl: UISegmentedControl?
        private var observation: NSKeyValueObservation?
        
        init(_ parent: NavigationSegmentedConfigurator) {
            self.parent = parent
        }
        
        deinit {
            observation?.invalidate()
        }
        
        @objc func valueChanged(_ sender: UISegmentedControl) {
            parent.selectedIndex = sender.selectedSegmentIndex
        }
        
        func observeTitleView(on vc: UIViewController, control: UISegmentedControl) {
            // Sadece gözlem değiştiğinde veya kurulmadığında çalıştır
            observation?.invalidate()
            observation = vc.navigationItem.observe(\.titleView, options: [.new]) { [weak vc, weak control] _, _ in
                guard let vc = vc, let control = control else { return }
                if vc.navigationItem.titleView !== control {
                    DispatchQueue.main.async {
                        if vc.navigationItem.titleView !== control {
                            vc.navigationItem.titleView = control
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Anchor View
// didMoveToWindow() ve layoutSubviews() tetiklendiğinde çalışır, 
// böylece SwiftUI view yapısını değiştirdiğinde veya arama çubuğu açıldığında 
// titleView'ı otomatik olarak geri yükler.
class SegmentedAnchorView: UIView {
    var onLayoutOrMove: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: .zero)
        isHidden = true
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onLayoutOrMove?()
            
            // Push geçiş animasyonu tamamlanırken veya parent hierarchy oturduktan sonra 
            // titleView'ın yeniden ayarlanmasını garantiye almak için kısa gecikmeli tetiklemeler:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.onLayoutOrMove?()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.onLayoutOrMove?()
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if window != nil {
            onLayoutOrMove?()
        }
    }
}

// MARK: - UIView Extension
private extension UIView {
    func findHostingVC() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController {
                return vc
            }
            responder = r.next
        }
        return nil
    }
}
