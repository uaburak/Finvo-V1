import SwiftUI
import FirebaseAuth

struct CategoryDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @Binding var category: CategoryModel
    @State private var subCategoryToEdit: SubCategoryModel?
    @State private var showAddSubSheet = false
    
    var body: some View {
        ZStack(alignment: .top) {
            List {
                ForEach(category.subCategories) { sub in
                    let index = category.subCategories.firstIndex(where: { $0.id == sub.id }) ?? 0
                    let isFirst = index == 0
                    
                    ListItem(
                        icon: sub.icon,
                        iconColor: sub.uiColor,
                        title: sub.localizedName,
                        subtitle: category.localizedName,
                        isOn: Binding(
                            get: { category.subCategories[index].isOn },
                            set: { category.subCategories[index].isOn = $0; saveChanges() }
                        )
                    )
                    .padding(.leading)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            categoryManager.checkProAndExecute(authManager: authManager) {
                                category.subCategories.remove(at: index)
                                saveChanges()
                            }
                        } label: {
                            Image(systemName: "trash")
                        }.tint(.red)
                        
                        Button {
                            categoryManager.checkProAndExecute(authManager: authManager) {
                                subCategoryToEdit = sub
                                showAddSubSheet = true
                            }
                        } label: {
                            Image(systemName: "pencil")
                        }.tint(.orange)
                    }
                    .listRowSeparator(.visible)
                    .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
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
                        .fill(category.uiColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(category.uiColor)
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
                    .onChange(of: category.isOn) { _ in
                        saveChanges()
                    }
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
                    categoryManager.checkProAndExecute(authManager: authManager) {
                        subCategoryToEdit = nil
                        showAddSubSheet = true
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
        .sheet(isPresented: $showAddSubSheet) {
            AddSubCategorySheet(mainCategory: $category, subCategoryToEdit: subCategoryToEdit)
                .presentationDetents([.medium, .large])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
        .alert("Pro Üyelik Gerekli", isPresented: $categoryManager.showProAlert) {
            Button("Tamam", role: .cancel) { }
            Button("Pro'ya Geç") {
                // Ileride pro ekrani eklenecek
            }
        } message: {
            Text("Alt kategori ekleme, silme ve düzenleme işlemleri sadece Pro üyelerimiz içindir.")
        }
    }
    
    private func saveChanges() {
        guard let uid = authManager.user?.uid else { return }
        Task {
            try? await categoryManager.saveCategory(uid: uid, category: category)
        }
    }
}

// EnvironmentObject'ten AuthenticationManager'ı güvenli almak için sarmalayıcı gerekebilir
// Mevcut yapıda authManager doğrudan AuthenticationManager tipinde enjekte ediliyor olabilir.
// Önceki dosyalarda @EnvironmentObject var authManager: AuthenticationManager olarak görmüştüm.
// Burayı ona göre düzelteyim.
