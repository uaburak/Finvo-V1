import SwiftUI

struct CategoryDetailView: View {
    @Environment(\.theme) var theme
    @Binding var category: CategoryModel
    
    var body: some View {
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
                .listRowBackground(Color.clear)
                .listRowSeparator(.visible)
                .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
            }
        }
        .listStyle(.plain)
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
