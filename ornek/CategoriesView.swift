import SwiftUI

struct CategoriesView: View {
    @StateObject private var categoryManager = CategoryManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @EnvironmentObject var tabManager: TabManager // Injected from MainTabView, but explicit injection ensures availability
    @State private var selectedType: CategoryType = .expense
    
    // Sheet State
    @State private var showAddSheet = false
    @State private var categoryToEdit: Category?
    
    @State private var searchText = ""
    @State private var showProAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                let filteredCategories = categoryManager.getCategories(type: selectedType).filter { category in
                    if searchText.isEmpty { return true }
                    return category.name.localizedCaseInsensitiveContains(searchText) ||
                           category.subCategories.contains(where: { $0.name.localizedCaseInsensitiveContains(searchText) })
                }
                
                if filteredCategories.isEmpty {
                    VStack {
                        Spacer()
                        ContentUnavailableView("Kategori Bulunamadı", systemImage: "list.bullet", description: Text("Bu kriterlere uygun kategori bulunamadı."))
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredCategories) { category in
                            ListItem(
                                icon: category.icon,
                                iconColor: category.color,
                                title: category.name,
                                subtitle: "\(category.subCategories.count) Alt Kategori"
                            )
                            .background(
                                NavigationLink(destination: SubCategoryListView(category: category)
                                                .environmentObject(categoryManager)
                                                .environmentObject(tabManager)) { // Ensure TabManager passes down
                                    EmptyView()
                                }
                                .opacity(0)
                            )
                            // Swipe actions for parent category
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if authManager.currentUserProfile?.isPro ?? false {
                                    Button(role: .destructive) {
                                        categoryManager.deleteCategory(category)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    
                                    Button {
                                        categoryToEdit = category
                                    } label: {
                                        Image(systemName: "pencil")
                                    }
                                    .tint(.orange)
                                    
                                    Button {
                                        categoryManager.toggleVisibility(for: category)
                                    } label: {
                                        Image(systemName: category.isVisible ? "eye.slash" : "eye")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Principal: Segmented Control
                ToolbarItem(placement: .principal) {
                    Picker("Kategori Tipi", selection: $selectedType) {
                        Text("Gider").tag(CategoryType.expense)
                        Text("Gelir").tag(CategoryType.income)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // Trailing: Add Button (Always Visible)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ekle") {
                        if authManager.currentUserProfile?.isPro == true {
                             showAddSheet = true
                        } else {
                             showProAlert = true
                        }
                    }
                }
            }
            .alert("Premium Özellik", isPresented: $showProAlert) {
                Button("Pro Ol", role: .none) {
                    tabManager.selectedTab = TabManager.settings
                }
                Button("İptal", role: .cancel) { }
            } message: {
                Text("Yeni kategori eklemek için Pro üye olmanız gerekmektedir.")
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Ara")
            .sheet(isPresented: $showAddSheet) {
                AddEditCategoryView(type: selectedType)
                    .environmentObject(categoryManager)
            }
            .sheet(item: $categoryToEdit) { category in
                AddEditCategoryView(category: category)
                    .environmentObject(categoryManager)
            }
        }
    }
}

#Preview {
    CategoriesView()
        .environmentObject(TabManager())
}
