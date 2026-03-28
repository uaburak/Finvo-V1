import SwiftUI
import FirebaseAuth

struct AddCategorySheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    var categoryToEdit: CategoryModel?
    @State private var categoryName: String = ""
    @State private var selectedType: TransactionType
    @State private var selectedIcon: String = "cart.fill"
    @State private var selectedColor: Color = .blue
    @State private var showDuplicateAlert: Bool = false
    
    let icons = CategoryIconLibrary.icons
    let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .teal, .indigo, .brown, .mint, .cyan, .gray, .black]
    
    init(type: TransactionType, categoryToEdit: CategoryModel? = nil) {
        _selectedType = State(initialValue: categoryToEdit?.type ?? type)
        self.categoryToEdit = categoryToEdit
        
        if let category = categoryToEdit {
            _categoryName = State(initialValue: category.name)
            _selectedIcon = State(initialValue: category.icon)
            _selectedColor = State(initialValue: category.uiColor)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(spacing: 24) {
                        
                        TextField("Kategori Adı", text: $categoryName)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                        
                        Picker("Kategori Tipi", selection: $selectedType) {
                            Text("Gider").tag(TransactionType.expense)
                            Text("Gelir").tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        
                        // İkon Seçimi
                        VStack(alignment: .leading, spacing: 12) {
                            Text("İkon Seçin")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                                .padding(.leading, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(icons, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.title2)
                                                .foregroundColor(selectedIcon == icon ? .white : theme.labelPrimary)
                                                .frame(width: 50, height: 50)
                                                .background(selectedIcon == icon ? theme.brandPrimary : Color.white.opacity(0.05))
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // Renk Seçimi
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Renk Seçin")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                                .padding(.leading, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(colors, id: \.self) { color in
                                        Button {
                                            selectedColor = color
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                                        .padding(2)
                                                )
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.top, 10)

                    Button {
                        handleSave()
                    } label: {
                        if categoryManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(categoryToEdit == nil ? "Oluştur" : "Güncelle")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 24)
                    .disabled(categoryName.isEmpty || categoryManager.isLoading)
                    .opacity(categoryName.isEmpty ? 0.6 : 1.0)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
            }
            .navigationTitle(categoryToEdit == nil ? "Yeni Kategori" : "Kategoriyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Kategori Mevcut", isPresented: $showDuplicateAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("'\(categoryName)' adında bir kategori zaten mevcut. Lütfen farklı bir isim seçin.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                            .foregroundStyle(theme.labelPrimary)
                    }
                }
            }
        }
    }
    
    private func handleSave() {
        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.prepare()
        
        guard let uid = authManager.user?.uid else { return }
        
        // Benzersizlik Kontrolü
        let isDuplicate = categoryManager.categories.contains { cat in
            cat.name.lowercased() == categoryName.lowercased() && cat.id != categoryToEdit?.id && cat.type == selectedType
        }
        
        if isDuplicate {
            showDuplicateAlert = true
            return
        }
        let newCategory = CategoryModel(
            firestoreId: categoryToEdit?.firestoreId,
            type: selectedType,
            name: categoryName,
            icon: selectedIcon,
            color: selectedColor.toHex(),
            subCategories: categoryToEdit?.subCategories ?? []
        )
        
        Task {
            do {
                try await categoryManager.saveCategory(uid: uid, category: newCategory)
                feedback.impactOccurred()
                dismiss()
            } catch {
                print("Kategori kaydedilemedi: \(error)")
            }
        }
    }
}
