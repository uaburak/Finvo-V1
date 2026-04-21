import SwiftUI
import FirebaseAuth

struct CategoryDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var transactionManager: TransactionManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @Binding var category: CategoryModel
    @State private var subCategoryToEdit: SubCategoryModel?
    @State private var showAddSubSheet = false
    @State private var subCategoryToDelete: SubCategoryModel?
    @State private var showDeleteConfirmation = false
    @State private var showPermissionAlert = false
    @State private var showRoleRequestSentAlert = false
    @State private var impactSummary: String = ""
    
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotification = UINotificationFeedbackGenerator()
    
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
                            get: { category.subCategories.first(where: { $0.id == sub.id })?.isOn ?? false },
                            set: { newValue in
                                if let idx = category.subCategories.firstIndex(where: { $0.id == sub.id }) {
                                    category.subCategories[idx].isOn = newValue
                                    saveChanges()
                                }
                            }
                        )
                    )
                    .padding(.leading)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if categoryManager.checkPermission(authManager: authManager, walletManager: walletManager) {
                            Button(role: .destructive) {
                                if authManager.currentUserProfile?.isPro == true {
                                    let impact = transactionManager.getImpact(mainCategoryId: category.id, subCategoryId: sub.id)
                                    impactSummary = "\(impact.transactionCount) işlem girişi ve \(impact.recurringCount) tekrarlayan işleminiz silinecek."
                                    subCategoryToDelete = sub
                                    showDeleteConfirmation = true
                                } else {
                                    categoryManager.showProAlert = true
                                }
                            } label: {
                                Image(systemName: "trash")
                            }.tint(.red)
                            
                            Button {
                                if authManager.currentUserProfile?.isPro == true {
                                    hapticMedium.impactOccurred()
                                    subCategoryToEdit = sub
                                    showAddSubSheet = true
                                } else {
                                    hapticNotification.notificationOccurred(.warning)
                                    categoryManager.showProAlert = true
                                }
                            } label: {
                                Image(systemName: "pencil")
                            }.tint(.orange)
                        }
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
                    Text(category.localizedName)
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text("\(category.subCategories.count) \(L10n("Alt Kategori")) • \(category.type == .expense ? L10n("Gider") : L10n("Gelir"))")
                        .font(.footnote)
                        .foregroundColor(theme.labelSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $category.isOn)
                    .labelsHidden()
                    .onChange(of: category.isOn) {
                        saveChanges()
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 24.0))
            .padding(.horizontal, 16)
        }
        .navigationTitle(category.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if authManager.currentUserProfile?.isPro == false {
                        hapticNotification.notificationOccurred(.warning)
                        categoryManager.showProAlert = true
                    } else if !categoryManager.checkPermission(authManager: authManager, walletManager: walletManager) {
                        hapticNotification.notificationOccurred(.warning)
                        showPermissionAlert = true
                    } else {
                        hapticMedium.impactOccurred()
                        subCategoryToEdit = nil
                        showAddSubSheet = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        if authManager.currentUserProfile?.isPro == false {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(theme.labelSecondary)
                        }
                        Image(systemName: "plus")
                            .foregroundColor(theme.labelPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSubSheet) {
            AddSubCategorySheet(mainCategory: $category, subCategoryToEdit: subCategoryToEdit)
                .presentationDetents([.height(450)])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
        .alert("Pro Üyelik Gerekli", isPresented: $categoryManager.showProAlert) {
            Button(L10n("Tamam"), role: .cancel) { }
            Button("Pro'ya Geç") {
                // Ileride pro ekrani eklenecek
            }
        } message: {
            Text("Alt kategori ekleme, silme ve düzenleme işlemleri sadece Pro üyelerimiz içindir.")
        }
        .alert("Yetki Gerekli", isPresented: $showPermissionAlert) {
            Button("Vazgeç", role: .cancel) { }
            Button("Yetki İste (Admin)") {
                if let activeWallet = walletManager.activeWallet, let walletId = activeWallet.id {
                    notificationManager.sendRoleRequest(walletId: walletId, walletName: activeWallet.name, ownerUsername: activeWallet.ownerId, requestedRole: .admin)
                    hapticNotification.notificationOccurred(.success)
                    showRoleRequestSentAlert = true
                }
            }
        } message: {
            Text("Alt kategori eklemek için bu cüzdanda 'Admin' veya 'Kurucu' yetkisine sahip olmanız gerekmektedir.")
        }
        .alert("İstek Gönderildi", isPresented: $showRoleRequestSentAlert) {
            Button(L10n("Tamam"), role: .cancel) { }
        } message: {
            Text("Yönetici yetkisi isteğiniz cüzdan sahibine iletildi.")
        }
        .alert("Alt Kategoriyi Sil?", isPresented: $showDeleteConfirmation) {
            Button("Vazgeç", role: .cancel) { }
            Button(L10n("Sil"), role: .destructive) {
                if let sub = subCategoryToDelete {
                    performDelete(sub)
                }
            }
        } message: {
            Text("'\(subCategoryToDelete?.name ?? "")' alt kategorisini ve ona bağlı tüm verileri silmek istediğinizden emin misiniz?\n\n\(impactSummary)")
        }
    }
    
    private func performDelete(_ sub: SubCategoryModel) {
        guard let walletId = walletManager.activeWallet?.id else { return }
        
        let subId = sub.id
        let subName = sub.name
        
        if let index = category.subCategories.firstIndex(where: { $0.id == subId }) {
            withAnimation {
                _ = category.subCategories.remove(at: index)
            }
            
            Task {
                do {
                    // Veritabanını güncelle
                    try await categoryManager.saveCategory(walletId: walletId, category: category)
                    
                    // Cascade Delete: Bu alt kategoriye ait işlemleride sil
                    try await FirestoreService.shared.deleteTransactionsBySubCategory(
                        walletId: walletId,
                        mainCategoryId: category.id,
                        subCategoryId: subId,
                        subCategoryName: subName
                    )
                } catch {
                    print("Error during subcategory deletion: \(error)")
                }
            }
        }
    }
    
    private func saveChanges() {
        guard let walletId = walletManager.activeWallet?.id else { return }
        Task {
            try? await categoryManager.saveCategory(walletId: walletId, category: category)
        }
    }
}

// EnvironmentObject'ten AuthenticationManager'ı güvenli almak için sarmalayıcı gerekebilir
// Mevcut yapıda authManager doğrudan AuthenticationManager tipinde enjekte ediliyor olabilir.
// Önceki dosyalarda @EnvironmentObject var authManager: AuthenticationManager olarak görmüştüm.
// Burayı ona göre düzelteyim.
