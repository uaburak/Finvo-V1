import SwiftUI
import FirebaseAuth

struct AddSubCategorySheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @Binding var mainCategory: CategoryModel
    var subCategoryToEdit: SubCategoryModel?
    
    @State private var subCategoryName: String = ""
    @State private var selectedIcon: String = "tag.fill"
    @State private var selectedColor: Color = .blue
    @State private var showDuplicateAlert: Bool = false
    
    let icons = CategoryIconLibrary.icons
    let colors: [Color] = [.blue, .green, .orange, .red, .purple, .pink, .teal, .indigo, .brown, .mint, .cyan, .gray, .black]
    
    init(mainCategory: Binding<CategoryModel>, subCategoryToEdit: SubCategoryModel? = nil) {
        self._mainCategory = mainCategory
        self.subCategoryToEdit = subCategoryToEdit
        
        if let sub = subCategoryToEdit {
            _subCategoryName = State(initialValue: sub.name)
            _selectedIcon = State(initialValue: sub.icon)
            _selectedColor = State(initialValue: sub.uiColor)
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    VStack(spacing: 20) {
                        TextField("Alt Kategori Adı", text: $subCategoryName)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                        
                        
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
                    .padding(.top, 4)

                    Button {
                        handleSave()
                    } label: {
                        if categoryManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(subCategoryToEdit == nil ? "Oluştur" : "Güncelle")
                                .font(.headline)
                                .foregroundStyle(theme.onBrandPrimary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 24)
                    .disabled(subCategoryName.isEmpty || categoryManager.isLoading)
                    .opacity(subCategoryName.isEmpty ? 0.6 : 1.0)
                }
                .padding(.top, 12)
                .padding(.horizontal, 24)
            }
            .navigationTitle(subCategoryToEdit == nil ? "Yeni Alt Kategori" : "Alt Kategoriyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Alt Kategori Mevcut", isPresented: $showDuplicateAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("'\(subCategoryName)' adında bir alt kategori bu grupta zaten mevcut.")
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
        
        guard let walletId = walletManager.activeWallet?.id else { return }
        
        // Benzersizlik Kontrolü (Aynı ana kategori içinde)
        let isDuplicate = mainCategory.subCategories.contains { sub in
            sub.name.lowercased() == subCategoryName.lowercased() && sub.id != subCategoryToEdit?.id
        }
        
        if isDuplicate {
            showDuplicateAlert = true
            return
        }
        let newSubCategory = SubCategoryModel(
            id: subCategoryToEdit?.id ?? UUID().uuidString,
            name: subCategoryName,
            icon: selectedIcon,
            color: selectedColor.toHex(),
            isOn: subCategoryToEdit?.isOn ?? true
        )
        
        if let sub = subCategoryToEdit, let index = mainCategory.subCategories.firstIndex(where: { $0.id == sub.id }) {
            mainCategory.subCategories[index] = newSubCategory
        } else {
            mainCategory.subCategories.append(newSubCategory)
        }
        
        Task {
            do {
                try await categoryManager.saveCategory(walletId: walletId, category: mainCategory)
                feedback.impactOccurred()
                dismiss()
            } catch {
                print("Alt kategori kaydedilemedi: \(error)")
            }
        }
    }
}
