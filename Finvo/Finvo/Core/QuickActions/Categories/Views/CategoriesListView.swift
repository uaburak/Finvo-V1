import SwiftUI

struct CategoriesListView: View {
    @Environment(\.theme) var theme
    @State private var selectedType: TransactionType = .expense
    // State to act as a source of truth for all categories & subcategories from mock
    @State private var categories: [CategoryModel] = CategoriesMockData.data
    
    var body: some View {
        let filteredCategories = categories.filter { $0.type == selectedType }
        List {
            ForEach($categories) { $category in
                if category.type == selectedType {
                    let isFirst = category.id == filteredCategories.first?.id
                    ZStack {
                        NavigationLink(destination: CategoryDetailView(category: $category)) {
                            EmptyView()
                        }
                        .opacity(0)
                        
                        ListItem(
                            icon: category.icon,
                            iconColor: category.color,
                            title: category.name,
                            subtitle: "\(category.subCategories.count) Alt Kategori"
                        )
                        .padding(.leading, 16)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.visible)
                    .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                    .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("İşlem Tipi", selection: $selectedType) {
                    Text("Gider").tag(TransactionType.expense)
                    Text("Gelir").tag(TransactionType.income)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // TODO: Ana kategori ekleme modalı eklenecek
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesListView()
    }
}
