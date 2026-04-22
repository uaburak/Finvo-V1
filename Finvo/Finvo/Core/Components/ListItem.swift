import SwiftUI
struct ListItem: View {
    // Left Icon Configuration
    let icon: String
    let iconColor: Color
    
    // Main Content
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let username: String?
    let isRecurring: Bool
    
    // Right Side Content (Optional)
    var value: String? = nil
    var valueColor: Color = .primary
    var secondaryInfo: String? = nil
    var secondaryInfoColor: Color = .gray
    var isOn: Binding<Bool>? = nil
    var iconForegroundColor: Color = .white
    
    // Flexible Additions
    var middleView: AnyView? = nil
    var customTrailingView: AnyView? = nil
    
    init(icon: String, iconColor: Color, title: LocalizedStringKey, subtitle: LocalizedStringKey, username: String? = nil, isRecurring: Bool = false, value: String? = nil, valueColor: Color = .primary, secondaryInfo: String? = nil, secondaryInfoColor: Color = .gray, isOn: Binding<Bool>? = nil, iconForegroundColor: Color = .white, middleView: AnyView? = nil, customTrailingView: AnyView? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.username = username
        self.isRecurring = isRecurring
        self.value = value
        self.valueColor = valueColor
        self.secondaryInfo = secondaryInfo
        self.secondaryInfoColor = secondaryInfoColor
        self.isOn = isOn
        self.iconForegroundColor = iconForegroundColor
        self.middleView = middleView
        self.customTrailingView = customTrailingView
    }
    
    var body: some View {
        HStack(spacing: 10) { 
            // Icon Box
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconForegroundColor)
                }
                
                if isRecurring {
                    Circle()
                        .fill(Color(UIColor.systemBackground))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "repeat")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(iconColor)
                        )
                        .offset(x: 3, y: -3)
                        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let user = username {
                    Text("@\(user)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let customMiddle = middleView {
                customMiddle
            }
            
            // Right: Value & Info OR Toggle
            if let customTrailing = customTrailingView {
                customTrailing
            } else if let isOn = isOn {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(.blue)
                    .scaleEffect(0.95)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    if let value = value {
                        Text(value)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(valueColor)
                    }
                    
                    if let info = secondaryInfo {
                        Text(info)
                            .font(.system(size: 11))
                            .foregroundColor(secondaryInfoColor)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
#Preview {
    List {
        ListItem(
            icon: "gift.fill",
            iconColor: .pink,
            title: "Gift",
            subtitle: "Partner Expenses",
            value: "₺1,500",
            valueColor: .red,
            secondaryInfo: "10 Ekim 2025"
        )
        
        ListItem(
            icon: "person.crop.circle.fill.badge.checkmark",
            iconColor: .green,
            title: "Courses & Certifications",
            subtitle: "Education",
            value: "₺5,500",
            valueColor: .red,
            secondaryInfo: "10 Ekim 2025"
        )
    }
    .listStyle(.plain)
}
