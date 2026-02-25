import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct CategoryDetailView: View {
    @Environment(\.theme) var theme
    @State private var subCategoryToEdit: SubCategoryModel?
    @Binding var category: CategoryModel
    
    var body: some View {
        ZStack(alignment: .top) {
            List {
                ForEach($category.subCategories) { $sub in
                    let isFirst = sub.id == category.subCategories.first?.id
                    ListItem(
                        icon: sub.icon,
                        iconColor: sub.color,
                        title: sub.name,
                        subtitle: category.name, // Parent title
                        isOn: $sub.isOn
                    )
                    .padding(.leading)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            // TODO: Alt kategori silme
                        } label: {
                            Image(systemName: "trash")
                        }.tint(.red)
                        Button { subCategoryToEdit = sub } label: {
                            Image(systemName: "pencil")
                        }.tint(.orange)
                    }
                    .listRowSeparator(.visible)
                    .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                    .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                }
            }
            .listStyle(.plain)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: 80)
            }
            
            // Sabit Üst Kart
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(category.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(category.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.name)
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text("\(category.subCategories.count) Alt Kategori • \(category.type == .expense ? "Gider" : "Gelir")")
                        .font(.footnote)
                        .foregroundColor(theme.labelSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $category.isOn)
                    .labelsHidden()
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 24.0))
            .padding(.horizontal, 16)
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // TODO: Alt kategori ekleme modalı eklenecek
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoryDetailView(category: .constant(CategoriesMockData.data[0]))
    }
}
