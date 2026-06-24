import SwiftUI
import FirebaseAuth

struct CategoriesListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var notificationManager: NotificationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @State private var categoryToEdit: CategoryModel?
    @State private var selectedType: TransactionType = .expense
    @State private var showAddSheet = false
    @State private var showPermissionAlert = false
    @State private var showRoleRequestSentAlert = false
    
    @State private var categoryToDelete: CategoryModel?
    @State private var showDeleteConfirmation = false
    @State private var impactSummary: String = ""
    @EnvironmentObject var transactionManager: TransactionManager
    
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotification = UINotificationFeedbackGenerator()
    
    // Segmented control için Int index ↔ TransactionType dönüşümü
    private var selectedTypeIndex: Binding<Int> {
        Binding(
            get: { selectedType == .expense ? 0 : 1 },
            set: { selectedType = $0 == 0 ? .expense : .income }
        )
    }
    
    var filteredCategories: [CategoryModel] {
        categoryManager.categories.filter { $0.type == selectedType }
    }
    
    var body: some View {
        let segmentItems = [L10n("Gider"), L10n("Gelir")]
        
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
        .navigationSegmentedControl(
            selection: selectedTypeIndex,
            items: segmentItems,
            width: 160
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addCategoryButton
            }
        }
        .onAppear {
            if let walletId = walletManager.activeWallet?.id {
                categoryManager.startListening(walletId: walletId)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCategorySheet(type: selectedType)
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
        .sheet(item: $categoryToEdit) { category in
            AddCategorySheet(type: selectedType, categoryToEdit: category)
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
        .alert("Pro Üyelik Gerekli", isPresented: $categoryManager.showProAlert) {
            Button(L10n("Tamam"), role: .cancel) { }
            Button("Pro'ya Geç") {
                // Ileride pro ekrani eklenecek
            }
        } message: {
            Text("Kategori ekleme, silme ve düzenleme işlemleri sadece Pro üyelerimiz içindir.")
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
            Text("Kategori eklemek için bu cüzdanda 'Admin' veya 'Kurucu' yetkisine sahip olmanız gerekmektedir.")
        }
        .alert("İstek Gönderildi", isPresented: $showRoleRequestSentAlert) {
            Button(L10n("Tamam"), role: .cancel) { }
        } message: {
            Text("Yönetici yetkisi isteğiniz cüzdan sahibine iletildi.")
        }
        .alert(L10n("Kategoriyi Sil?"), isPresented: $showDeleteConfirmation) {
            Button("Vazgeç", role: .cancel) { }
            Button(L10n("Sil"), role: .destructive) {
                if let cat = categoryToDelete {
                    confirmDelete(cat)
                }
            }
        } message: {
            Text("'\(categoryToDelete?.name ?? "")' kategorisini ve ona bağlı tüm verileri silmek istediğinizden emin misiniz?\n\n\(impactSummary)")
        }
    }
    
    private var addCategoryButton: some View {
        Button {
            if authManager.currentUserProfile?.isPro == false {
                hapticNotification.notificationOccurred(.warning)
                categoryManager.showProAlert = true
            } else if !categoryManager.checkPermission(authManager: authManager, walletManager: walletManager) {
                hapticNotification.notificationOccurred(.warning)
                showPermissionAlert = true
            } else {
                hapticMedium.impactOccurred()
                showAddSheet = true
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
    
    @ViewBuilder
    private func categoryRow(_ category: CategoryModel) -> some View {
        let isFirst = category.id == filteredCategories.first?.id
        
        ZStack {
            NavigationLink(destination: CategoryDetailView(category: category)) {
                EmptyView()
            }
            .opacity(0)
            
            ListItem(
                icon: category.icon,
                iconColor: category.uiColor,
                title: category.localizedName,
                subtitle: LocalizedStringKey("\(category.subCategories.count) Alt Kategori")
            )
            .padding(.leading, 16)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if categoryManager.checkPermission(authManager: authManager, walletManager: walletManager) {
                Button {
                    if authManager.currentUserProfile?.isPro == true {
                        let impact = transactionManager.getImpact(mainCategoryId: category.id)
                        impactSummary = "\(impact.transactionCount) işlem girişi ve \(impact.recurringCount) tekrarlayan işleminiz silinecek."
                        categoryToDelete = category
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
                        categoryToEdit = category
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
    
    private func confirmDelete(_ category: CategoryModel) {
        guard let walletId = walletManager.activeWallet?.id else { return }
        Task {
            try? await categoryManager.deleteCategory(walletId: walletId, category: category)
        }
    }
}
