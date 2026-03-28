import SwiftUI
import FirebaseAuth

struct CategoriesListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @State private var categoryToEdit: CategoryModel?
    @State private var selectedType: TransactionType = .expense
    @State private var showAddSheet = false
    
    var filteredCategories: [CategoryModel] {
        categoryManager.categories.filter { $0.type == selectedType }
    }
    
    var body: some View {
        List {
            if categoryManager.isLoading && categoryManager.categories.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredCategories) { category in
                    categoryRow(category)
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
                    categoryManager.checkProAndExecute(authManager: authManager) {
                        showAddSheet = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        if authManager.currentUserProfile?.isPro != true {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                        }
                        Image(systemName: "plus")
                    }
                    .foregroundColor(theme.labelPrimary)
                }
            }
        }
        .task {
            if let uid = authManager.user?.uid {
                await categoryManager.loadCategories(uid: uid)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCategorySheet(type: selectedType)
                .presentationDetents([.height(550)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
        .sheet(item: $categoryToEdit) { category in
            AddCategorySheet(type: selectedType, categoryToEdit: category)
                .presentationDetents([.height(550)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
        .alert("Pro Üyelik Gerekli", isPresented: $categoryManager.showProAlert) {
            Button("Tamam", role: .cancel) { }
            Button("Pro'ya Geç") {
                // Ileride pro ekrani eklenecek
            }
        } message: {
            Text("Kategori ekleme, silme ve düzenleme işlemleri sadece Pro üyelerimiz içindir.")
        }
    }
    
    @ViewBuilder
    private func categoryRow(_ category: CategoryModel) -> some View {
        let isFirst = category.id == filteredCategories.first?.id
        
        ZStack {
            // Binding bulma mantığı:
            if let index = categoryManager.categories.firstIndex(where: { $0.id == category.id }) {
                NavigationLink(destination: CategoryDetailView(category: $categoryManager.categories[index])) {
                    EmptyView()
                }
                .opacity(0)
            }
            
            ListItem(
                icon: category.icon,
                iconColor: category.uiColor,
                title: category.localizedName,
                subtitle: LocalizedStringKey("\(category.subCategories.count) Alt Kategori")
            )
            .padding(.leading, 16)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                categoryManager.checkProAndExecute(authManager: authManager) {
                    handleDelete(category)
                }
            } label: {
                Image(systemName: "trash")
            }.tint(.red)
            
            Button {
                categoryManager.checkProAndExecute(authManager: authManager) {
                    categoryToEdit = category
                }
            } label: {
                Image(systemName: "pencil")
            }.tint(.orange)
        }
        .listRowSeparator(.visible)
        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
    }
    
    private func handleDelete(_ category: CategoryModel) {
        guard let uid = authManager.user?.uid else { return }
        let id = category.id
        Task {
            try? await categoryManager.deleteCategory(uid: uid, categoryId: id)
        }
    }
}
