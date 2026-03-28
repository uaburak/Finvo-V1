import SwiftUI

struct TransactionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @State var selectedType: TransactionType

    @State private var transactionToEdit: TransactionModel?
    @State private var searchText = ""
    
    // Fitre State'leri
    @State private var useDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCategory: String? = nil
    
    @State private var showDeleteConfirmation = false
    @State private var transactionToDelete: TransactionModel? = nil

    var body: some View {
        Group {
            let allItems: [TransactionModel] = transactionManager.transactions
            let filteredItems: [TransactionModel] = allItems.filter { item in
                guard item.type == selectedType else { return false }
                
                if !searchText.isEmpty {
                    guard item.mainCategoryName.localizedCaseInsensitiveContains(searchText) ||
                          (item.subCategoryName ?? "").localizedCaseInsensitiveContains(searchText) ||
                          (item.note ?? "").localizedCaseInsensitiveContains(searchText) else { return false }
                }
                
                if let catId = selectedCategory {
                    guard item.mainCategoryId == catId || item.mainCategoryName == catId else { return false }
                }
                
                if useDateRange {
                    let calendar = Calendar.current
                    let start = calendar.startOfDay(for: startDate)
                    let end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
                    
                    if item.date < start || item.date > end {
                        return false
                    }
                }
                
                return true
            }

            if !transactionManager.hasLoaded {
                // Veri henüz yüklenmedi — boş state gösterme
                Color.clear
            } else if filteredItems.isEmpty {
                VStack {
                    Spacer()
                    ContentUnavailableView("İşlem Bulunamadı", systemImage: "list.bullet",
                                          description: Text("Bu kriterlere uygun işlem bulunamadı."))
                    Spacer()
                }
            } else {
                let sortedItems = filteredItems.sorted(by: { $0.date > $1.date })
                List {
                    ForEach(sortedItems) { transaction in
                        let isFirst = transaction.id == sortedItems.first?.id
                        let mainTitle = transaction.resolvedSubCategoryName ?? transaction.resolvedMainCategoryName
                        let subtitleText = transaction.resolvedSubCategoryName != nil ? transaction.resolvedMainCategoryName : transaction.date.formatted(date: .abbreviated, time: .shortened)

                        NavigationLink(value: transaction) {
                            ListItem(
                                icon: transaction.resolvedIcon,
                                iconColor: transaction.resolvedColor(),
                                title: LocalizedStringKey(mainTitle),
                                subtitle: LocalizedStringKey(subtitleText),
                                value: (transaction.type == .income ? "+₺" : "-₺") + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))),
                                valueColor: transaction.type == .income ? theme.income : theme.expense,
                                secondaryInfo: transaction.date.formatted(date: .abbreviated, time: .shortened)
                            )
                            .padding(.leading)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            
                            let currentUser = authManager.currentUserProfile?.username ?? ""
                            let roleRaw = walletManager.activeWallet?.permissions[currentUser] ?? WalletRole.member.rawValue
                            let role = WalletRole(rawValue: roleRaw) ?? .member
                            let isOwner = walletManager.activeWallet?.ownerId == currentUser
                            
                            let isAdminOrOwner = isOwner || role == .admin
                            let isCreator = transaction.createdBy == currentUser
                            let canManage = isAdminOrOwner || (role == .member && isCreator)
                            
                            if canManage {
                                Button(role: .destructive) {
                                    transactionToDelete = transaction
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(.red)
                                
                                Button { 
                                    transactionToEdit = transaction 
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 20))
                        .listRowSeparator(.visible)
                        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
                        .listSectionSeparator(isFirst ? .hidden : .visible, edges: .top)
                    }
                }
                .listStyle(.plain)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 8) // Küçük bir boşluk bırakarak tepedeki overlap'i önlüyoruz
                }
                .safeAreaPadding(.bottom, 40)
                .sheet(item: $transactionToEdit) { transaction in
                    AddTransactionsView(transactionToEdit: transaction)
                        .environmentObject(walletManager)
                        .environmentObject(transactionManager)
                        .environmentObject(authManager)
                }
            }
        }
        .navigationTitle(selectedType == .income ? "Gelir" : "Gider")
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
                Menu {
                    Menu {
                        DatePicker("Başlangıç", selection: $startDate, displayedComponents: .date)
                        DatePicker("Bitiş", selection: $endDate, displayedComponents: .date)
                        
                        Divider()
                        
                        Button {
                            useDateRange.toggle()
                        } label: {
                            Label(useDateRange ? "Tarih Filtresini Kapat" : "Tarih Filtresini Aç", 
                                  systemImage: useDateRange ? "calendar.badge.minus" : "calendar.badge.plus")
                        }
                    } label: {
                        Label("Tarih Aralığı Seç", systemImage: "calendar")
                    }

                    Divider()

                    Picker("Kategori", selection: $selectedCategory) {
                        Text("Tüm Kategoriler").tag(Optional<String>.none)
                        let availableCategories = CategoryManager.shared.categories.isEmpty ? CategoriesMockData.data : CategoryManager.shared.categories
                        ForEach(availableCategories.filter { $0.type == selectedType }) { cat in
                            Label(cat.name, systemImage: cat.icon).tag(Optional(cat.id))
                        }
                    }

                    Divider()

                    if useDateRange || selectedCategory != nil {
                        Button(role: .destructive) {
                            useDateRange = false
                            selectedCategory = nil
                            startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                            endDate = Date()
                        } label: {
                            Label("Filtreleri Sıfırla", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: (useDateRange || selectedCategory != nil)
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease")
                        .foregroundStyle((useDateRange || selectedCategory != nil) ? Color.accentColor : theme.labelPrimary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Ara")
        .confirmationDialog("İşlemi Sil", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Sil", role: .destructive) {
                if let transaction = transactionToDelete, let id = transaction.id {
                    Task {
                        try? await FirestoreService.shared.deleteTransaction(walletId: transaction.walletId, transactionId: id)
                    }
                }
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("Bu işlemi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.")
        }
    }
}

#Preview {
    NavigationStack {
        TransactionsView(selectedType: .expense)
    }
}
