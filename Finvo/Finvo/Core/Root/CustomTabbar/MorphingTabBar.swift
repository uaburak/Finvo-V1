import SwiftUI

protocol MorphingTabProtocol: CaseIterable, Hashable {
    var symbolImage: String { get }
    var title: String { get }
}

struct MorphingTabBar<Tab: MorphingTabProtocol, ExpandedContent: View>: View {
    @Binding var activeTab: Tab
    @Binding var isExpanded: Bool
    var activeIconTint: Color = .blue
    var inactiveIconTint: Color = .gray
    @ViewBuilder var expandedContent: ExpandedContent
    /// View Properties
    @State private var viewWidth: CGFloat?
    var body: some View {
        ZStack {
            let symbols = Array(Tab.allCases).compactMap({ $0.symbolImage })
            let selectedIndex = Binding {
                return symbols.firstIndex(of: activeTab.symbolImage) ?? 0
            } set: { index in
                activeTab = Array(Tab.allCases)[index]
            }

            if let viewWidth {
                let progress: CGFloat = isExpanded ? 1 : 0
                // burası artı (+) butonunun genişliği ve yüksekliği
                let labelSize: CGSize = CGSize(width: viewWidth, height: 62)
                let cornerRadius: CGFloat = labelSize.height / 2
                
                ExpandableGlassEffect(alignment: .center, progress: progress, labelSize: labelSize, cornerRadius: cornerRadius) {
                    expandedContent
                } label: {
                    let tabsData = Array(Tab.allCases).map { (icon: $0.symbolImage, title: $0.title) }
                    CustomTabBarIndicator(activeIconTint: activeIconTint, inactiveIconTint: inactiveIconTint, tabs: tabsData, index: selectedIndex) { icon, title, color in
                        return createTabIcon(icon: icon, title: title, color: color)
                    }
                    // burası iç kısımdaki ikonları taşıyan alanın yüksekliği
                    .frame(height: 58)
                    .padding(.horizontal, 2)
                    // burası ikonların dikey (y ekseninde) ortalanma ince ayarı
                    .offset(y: -1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width
        } action: { newValue in
            viewWidth = newValue
        }
        // burası kapalı durumdaki tab bar dış çerçevenin yüksekliği
        .frame(height: viewWidth == nil ? 62 : nil)
    }
}

fileprivate struct CustomTabBarIndicator: UIViewRepresentable {
    var tint: Color = .gray.opacity(0.15)
    var activeIconTint: Color
    var inactiveIconTint: Color
    var tabs: [(icon: String, title: String)]
    @Binding var index: Int
    var image: (String, String, UIColor) -> UIImage?
    func makeUIView(context: Context) -> UISegmentedControl {
        let items = tabs.map { $0.title }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = index
        control.selectedSegmentTintColor = UIColor(tint)
        
        for (i, tab) in tabs.enumerated() {
            let color = (i == index) ? UIColor(activeIconTint) : UIColor(inactiveIconTint)
            if let img = image(tab.icon, tab.title, color) {
                control.setImage(img.withRenderingMode(.alwaysOriginal), forSegmentAt: i)
            }
        }
        
        control.addTarget(context.coordinator, action: #selector(context.coordinator.didSelect(_:)), for: .valueChanged)
        
        /// Removing Background Color
        DispatchQueue.main.async {
            for view in control.subviews.dropLast() {
                if view is UIImageView {
                    view.alpha = 0
                }
            }
        }
        
        return control
    }
    
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != index {
            uiView.selectedSegmentIndex = index
        }
        
        // Yeni seçime göre ikonların renklerini güncelle
        for (i, tab) in tabs.enumerated() {
            let color = (i == index) ? UIColor(activeIconTint) : UIColor(inactiveIconTint)
            if let img = image(tab.icon, tab.title, color) {
                uiView.setImage(img.withRenderingMode(.alwaysOriginal), forSegmentAt: i)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject {
        var parent: CustomTabBarIndicator
        init(parent: CustomTabBarIndicator) {
            self.parent = parent
        }
        
        @objc
        func didSelect(_ control: UISegmentedControl) {
            parent.index = control.selectedSegmentIndex
        }
    }
    
    /// Free size!
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISegmentedControl, context: Context) -> CGSize? {
        return proposal.replacingUnspecifiedDimensions()
    }
}

fileprivate func createTabIcon(icon: String, title: String, color: UIColor) -> UIImage? {
    let font = UIFont.systemFont(ofSize: 20)
    let config = UIImage.SymbolConfiguration(font: font)
    guard let symbolImage = UIImage(systemName: icon, withConfiguration: config) else { return nil }
    
    let textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10, weight: .medium),
        .foregroundColor: color
    ]
    let textSize = title.size(withAttributes: textAttributes)
    
    let spacing: CGFloat = 4
    let width = max(symbolImage.size.width, textSize.width)
    let height = symbolImage.size.height + spacing + textSize.height
    
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
    return renderer.image { context in
        let iconRect = CGRect(x: (width - symbolImage.size.width) / 2, y: 0, width: symbolImage.size.width, height: symbolImage.size.height)
        symbolImage.withTintColor(color).draw(in: iconRect)
        
        let textRect = CGRect(x: (width - textSize.width) / 2, y: symbolImage.size.height + spacing, width: textSize.width, height: textSize.height)
        title.draw(in: textRect, withAttributes: textAttributes)
    }
}
