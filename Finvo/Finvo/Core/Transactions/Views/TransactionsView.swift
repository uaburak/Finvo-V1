import SwiftUI

struct TransactionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State var selectedType: TransactionType

    @State private var transactionToEdit: TransactionModel?
    @State private var searchText = ""
    
    // Fitre State'leri
    @State private var useDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCategory: FilterCategory? = nil

    var body: some View {
        VStack {
            let allItems: [TransactionModel] = transactionManager.transactions
            let filteredItems: [TransactionModel] = allItems.filter { item in
                guard item.type == selectedType else { return false }
                
                if !searchText.isEmpty {
                    guard item.mainCategoryName.localizedCaseInsensitiveContains(searchText) ||
                          (item.subCategoryName ?? "").localizedCaseInsensitiveContains(searchText) ||
                          (item.note ?? "").localizedCaseInsensitiveContains(searchText) else { return false }
                }
                
                if let cat = selectedCategory {
                    guard item.mainCategoryName.localizedCaseInsensitiveContains(cat.rawValue) else { return false }
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

            if filteredItems.isEmpty {
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
                        let subtitleText = transaction.subCategoryName != nil ? "\(transaction.subCategoryName!) • Ekleyen: @\(transaction.createdBy)" : "Ekleyen: @\(transaction.createdBy)"
                        
                        ListItem(
                            icon: transaction.categoryIcon,
                            iconColor: theme.brandPrimary,
                            title: LocalizedStringKey(transaction.mainCategoryName),
                            subtitle: LocalizedStringKey(subtitleText),
                            value: (transaction.type == .income ? "+₺" : "-₺") + transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))),
                            valueColor: transaction.type == .income ? theme.income : theme.expense,
                            secondaryInfo: transaction.date.formatted(date: .abbreviated, time: .shortened)
                        )
                        .padding(.leading)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            
                            let isOwner = walletManager.activeWallet?.ownerId == authManager.currentUserProfile?.username
                            let role = walletManager.activeWallet?.permissions[authManager.currentUserProfile?.username ?? ""]
                            let isCreator = transaction.createdBy == authManager.currentUserProfile?.username
                            let canDelete = isOwner || (role == WalletRole.member.rawValue && isCreator)
                            
                            if canDelete {
                                Button(role: .destructive) {
                                    Task {
                                        if let id = transaction.id {
                                            try? await FirestoreService.shared.deleteTransaction(walletId: transaction.walletId, transactionId: id)
                                        }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(.red)
                                
                                Button { transactionToEdit = transaction } label: {
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
            }
        }
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
                        Text("Tüm Kategoriler").tag(Optional<FilterCategory>.none)
                        ForEach(FilterCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(Optional(cat))
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
    }
}

#Preview {
    NavigationStack {
        TransactionsView(selectedType: .expense)
    }
}
