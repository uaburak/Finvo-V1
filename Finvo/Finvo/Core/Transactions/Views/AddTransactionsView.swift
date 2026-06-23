//
//  AddTransactionsView.swift
//  Finvo
//

import SwiftUI
import UIKit

struct AddTransactionsView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency

    let transactionToEdit: TransactionModel?

    @State private var selectedType: TransactionType = .expense
    @State private var selectedMainCategory: CategoryModel?
    @State private var selectedSubCategory: SubCategoryModel?
    @State private var selectedDate: Date = Date()
    @State private var amount: String = ""
    @State private var selectedCurrency: CurrencyType = .tryCurrency
    @ObservedObject var categoryManager = CategoryManager.shared
    @State private var activeSheet: ActiveSheet?
    @State private var isDebt: Bool = false
    @State private var debtContact: String = ""
    @State private var installmentCount: String = ""
    @State private var paidInstallments: String = ""
    @State private var dueDay: Int = 1
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: RecurrenceInterval = .monthly
    @State private var hasRecurrenceEndDate: Bool = false
    @State private var recurrenceEndDate: Date = Date().addingTimeInterval(86400 * 30) // +1 Month default
    
    @State private var note: String = ""
    
    // OCR Receipt Scanner States
    @State private var showImagePicker: Bool = false
    @State private var selectedSourceType: UIImagePickerController.SourceType = .camera
    @State private var isScanningReceipt: Bool = false
    @State private var showOcrErrorAlert: Bool = false
    @State private var ocrErrorMessage: String = ""
    
    @State private var currentStep: TransactionStep
    @State private var selectedDetent: PresentationDetent
    
    init(transactionToEdit: TransactionModel? = nil) {
        self.transactionToEdit = transactionToEdit
        
        let type = transactionToEdit?.type ?? .expense
        _selectedType = State(initialValue: type)
        _selectedDate = State(initialValue: transactionToEdit?.date ?? Date())
        
        if let edit = transactionToEdit {
            var displayAmount = edit.amount
            if edit.isDebt, let totalInt = edit.totalInstallments, totalInt > 0 {
                displayAmount = edit.amount / Double(totalInt)
            }
            let isInteger = floor(displayAmount) == displayAmount
            _amount = State(initialValue: isInteger ? String(format: "%.0f", displayAmount) : "\(displayAmount)")
        } else {
            _amount = State(initialValue: "")
        }
        
        _selectedCurrency = State(initialValue: transactionToEdit?.currency ?? (UserDefaults.standard.string(forKey: "appCurrency").flatMap { CurrencyType(rawValue: $0) } ?? .tryCurrency))
        
        // Kategori eşleştirme (ID bazlı öncelik, isim fallback)
        let categories = CategoryManager.shared.categories.isEmpty ? CategoriesMockData.data : CategoryManager.shared.categories
        let mainCat = categories.first { cat in
            if let targetId = transactionToEdit?.mainCategoryId {
                return cat.id == targetId
            }
            return cat.name == transactionToEdit?.mainCategoryName
        }
        _selectedMainCategory = State(initialValue: mainCat)
        
        let subCat = mainCat?.subCategories.first { sub in
            if let targetId = transactionToEdit?.subCategoryId {
                return sub.id == targetId
            }
            return sub.name == transactionToEdit?.subCategoryName
        }
        _selectedSubCategory = State(initialValue: subCat)
        
        _note = State(initialValue: transactionToEdit?.note ?? "")
        
        _isDebt = State(initialValue: transactionToEdit?.isDebt ?? false)
        _debtContact = State(initialValue: transactionToEdit?.debtContact ?? "")
        _installmentCount = State(initialValue: transactionToEdit?.totalInstallments != nil ? "\(transactionToEdit!.totalInstallments!)" : "")
        _paidInstallments = State(initialValue: transactionToEdit?.paidInstallments != nil ? "\(transactionToEdit!.paidInstallments!)" : "")
        _dueDay = State(initialValue: transactionToEdit?.dueDay ?? 1)
        
        _isRecurring = State(initialValue: transactionToEdit?.isRecurring ?? false)
        _recurringFrequency = State(initialValue: transactionToEdit?.recurrenceInterval ?? .monthly)
        _hasRecurrenceEndDate = State(initialValue: transactionToEdit?.recurrenceEndDate != nil)
        _recurrenceEndDate = State(initialValue: transactionToEdit?.recurrenceEndDate ?? Date().addingTimeInterval(86400 * 30))
        
        if transactionToEdit != nil {
            _currentStep = State(initialValue: .details)
            _selectedDetent = State(initialValue: .height(650))
        } else {
            _currentStep = State(initialValue: .type)
            _selectedDetent = State(initialValue: .height(280))
        }
    }
    
    @State private var isSaving = false
    @State private var showPermissionErrorAlert = false

    enum TransactionStep: Int, CaseIterable {
        case type = 1
        case category = 2
        case subcategory = 3
        case details = 4

        var titleKey: String {
            switch self {
            case .type: return L10n("İşlem Türü")
            case .category: return L10n("Kategori Seçin")
            case .subcategory: return L10n("Alt Kategori Seçin")
            case .details: return L10n("İşlem Detayları")
            }
        }

        var title: String { titleKey.localized }
    }

    @State private var showPaywall = false

    enum ActiveSheet: Identifiable {
        case category, amount, currency
        var id: Int { hashValue }
    }

    private var categoryRowValue: String {
        if let sub = selectedSubCategory { return sub.name.localized }
        if let main = selectedMainCategory { return main.name.localized }
        return "Seçin".localized
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var isLocked: Bool {
        if let wallet = walletManager.activeWallet, wallet.type == .shared {
            // Fix #6: Pending (daveti kabul etmemiş) üyeleri saymıyoruz
            let activeMembers = wallet.members.filter {
                wallet.permissions[$0] != WalletRole.pending.rawValue
            }
            if activeMembers.count > 2 {
                // Kendi profilime bak: Ben Pro isem kilit açık
                if authManager.currentUserProfile?.isPro == true { return false }
                
                // Benim dışımdaki aktif üyelere bak: Biri bile Pro ise kilit açık
                let hasProMember = activeMembers.contains { memberUsername in
                    if memberUsername == authManager.currentUserProfile?.username { return false }
                    return walletManager.usersProStatus[memberUsername] == true
                }
                
                return !hasProMember
            }
        }
        return false
    }

    var body: some View {
        NavigationStack {
            if isLocked {
                lockedWalletView
            } else {
                VStack(spacing: 0) {

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            stepContent
                                .padding(.top, 0)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                } // Ends VStack

                .navigationTitle(LocalizedStringKey(currentStep.titleKey))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if currentStep != .type && transactionToEdit == nil {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                prevStep()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .fontWeight(.bold)
                                    .foregroundStyle(theme.labelPrimary)
                            }
                        }
                    }
                    
                    // Sağ tarafta her zaman "Kapat" butonu olacak
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
            } // Ends else
        } // Ends NavigationStack
            .fullScreenCover(isPresented: $showPaywall) {
                ProSubscriptionPaywallView()
            }
            // Dinamik Sheet Yüksekliği (Animasyonla Geçiş)
            .presentationDetents([.height(280), .height(650)], selection: $selectedDetent)
            .presentationDragIndicator(.hidden)
            // Bütün steplerde hiçbir arka plan rengi yok (Tamamen Şeffaf)
            .presentationBackground(.clear) 
            .onAppear {
                // Global UISegmentedControl renkleri FinvoApp.swift'te merkezi olarak ayarlandı.
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .category:
                    CategorySelectionSheet(
                        categories: (categoryManager.categories.isEmpty ? CategoriesMockData.data : categoryManager.categories).filter { $0.type == selectedType && $0.isOn },
                        selectedMainCategory: $selectedMainCategory,
                        selectedSubCategory: $selectedSubCategory
                    )
                case .amount:
                    AmountInputSheet(amount: $amount)
                        .presentationDetents([.height(300)])
                        .presentationBackground(.clear)
                case .currency:
                    CurrencySelectionSheet(selectedCurrency: $selectedCurrency)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }

            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: selectedSourceType) { image in
                    processReceiptImage(image)
                }
            }
            .alert("Yetki İste", isPresented: $showPermissionErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(L10n("Görüntüleyici rolüne sahip olduğunuz için cüzdana işlem ekleyemezsiniz. Lütfen kurucudan yetki isteyin."))
            }
            .alert("Tarama Hatası", isPresented: $showOcrErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(ocrErrorMessage)
            }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .type:
            typeSelectionView
        case .category:
            categorySelectionView
        case .subcategory:
            subcategorySelectionView
        case .details:
            detailsFormView
        }
    }

    private var typeSelectionView: some View {
        Group {
            if isScanningReceipt {
                inlineScanningView
            } else {
                VStack(spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 16) {
                        SelectionCard(title: "Gider", icon: "arrow.down.circle.fill", color: theme.expense) {
                            selectedType = .expense
                            nextStep()
                        }
                        SelectionCard(title: "Gelir", icon: "arrow.up.circle.fill", color: theme.income) {
                            selectedType = .income
                            nextStep()
                        }
                    }
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            selectedSourceType = .camera
                        } else {
                            selectedSourceType = .photoLibrary
                        }
                        showImagePicker = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 28))
                                .foregroundStyle(theme.brandPrimary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fatura / Fiş Tara")
                                    .font(.headline)
                                    .foregroundStyle(theme.labelPrimary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(theme.separatorSecondary)
                        }
                        .padding(.horizontal, 24)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(theme.separator, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var categorySelectionView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            let filteredCategories = (CategoryManager.shared.categories.isEmpty ? CategoriesMockData.data : CategoryManager.shared.categories).filter { $0.type == selectedType && $0.isOn }
            ForEach(filteredCategories) { category in
                SelectionCard(title: LocalizedStringKey(category.name), icon: category.icon, color: category.uiColor) {
                    selectedMainCategory = category
                    selectedSubCategory = nil // Fix #2: Kategori değişince alt kategori sıfırlanıyor
                    nextStep()
                }
            }
        }
    }

    private var subcategorySelectionView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            if let subCategories = selectedMainCategory?.subCategories.filter({ $0.isOn }) {
                ForEach(subCategories) { sub in
                    SelectionCard(title: LocalizedStringKey(sub.name), icon: sub.icon, color: sub.uiColor) {
                        selectedSubCategory = sub
                        nextStep()
                    }
                }
            }
        }
    }

    private var detailsFormView: some View {
        VStack(spacing: 24) {
            // Selected Path Summary
            VStack(spacing: 0) {
                ListItem(
                    icon: selectedSubCategory?.icon ?? selectedMainCategory?.icon ?? "questionmark",
                    iconColor: selectedSubCategory?.uiColor ?? selectedMainCategory?.uiColor ?? Color.gray,
                    title: LocalizedStringKey(selectedSubCategory?.name ?? selectedMainCategory?.name ?? L10n("Kategori Seçilmedi")),
                    subtitle: LocalizedStringKey(selectedMainCategory?.name ?? ""),
                    iconForegroundColor: .white
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.separator, lineWidth: 1))

            VStack(spacing: 0) {
                formRow("turkishlirasign.circle", LocalizedStringKey(L10n("Tutar")), formatAmountText()) { activeSheet = .amount }
                Divider().padding(.leading, 56)
                
                HStack(spacing: 16) {
                    Image(systemName: "banknote")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.brandPrimary)
                        .frame(width: 24)
                    Text(L10n("Para Birimi"))
                        .foregroundStyle(theme.labelPrimary)
                    Spacer()
                    Text(selectedCurrency.code)  // Show abbreviation here! "USD" 
                        .foregroundStyle(theme.labelSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.separatorSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle()) // To make tapping it accurate
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    activeSheet = .currency
                }
                
                Divider().padding(.leading, 56)
                
                HStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.brandPrimary)
                        .frame(width: 24)
                    DatePicker(L10n("Tarih"), selection: $selectedDate, displayedComponents: .date)
                        .foregroundStyle(theme.labelPrimary)
                        .tint(theme.brandPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.separator, lineWidth: 1))
            
            budgetWarningView

            // Not Alanı
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.brandPrimary)
                        .frame(width: 24)
                    TextField(L10n("Not Ekle (İsteğe bağlı)"), text: $note)
                        .foregroundStyle(theme.labelPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.separator, lineWidth: 1))

            VStack(spacing: 0) {
                toggleRow("person.2.fill", "Borç / Alacak İşlemi", isOn: Binding(
                    get: { isDebt },
                    set: { newVal in
                        isDebt = newVal
                        if newVal { isRecurring = false } // Mutex: ikisi aynı anda aktif olamaz
                    }
                ))
                
                if isDebt {
                    Divider().padding(.leading, 56)
                    
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.brandPrimary)
                            .frame(width: 24)
                        TextField(L10n("Kişi veya Kurum (Örn: Ahmet)"), text: $debtContact)
                            .foregroundStyle(theme.labelPrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    Divider().padding(.leading, 56)
                    
                    HStack(spacing: 16) {
                        Image(systemName: "number.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.brandPrimary)
                            .frame(width: 24)
                        
                        TextField(L10n("Toplam Taksit"), text: $installmentCount)
                            .keyboardType(.numberPad)
                            .foregroundStyle(theme.labelPrimary)
                        
                        Divider().frame(height: 20)
                        
                        TextField(L10n("Ödenen"), text: $paidInstallments)
                            .keyboardType(.numberPad)
                            .foregroundStyle(theme.labelPrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    
                    Divider().padding(.leading, 56)
                    
                    HStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.brandPrimary)
                            .frame(width: 24)
                        Text(L10n("Son Ödeme Günü"))
                            .foregroundStyle(theme.labelPrimary)
                        Spacer()
                        Text(L10n("Her ayın"))
                            .font(.subheadline)
                            .foregroundStyle(theme.labelSecondary)
                        Picker("", selection: $dueDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                        .tint(theme.labelSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                
                Divider()
                
                toggleRow("arrow.2.squarepath", "Tekrarlayan İşlem", isOn: Binding(
                    get: { isRecurring },
                    set: { newVal in
                        isRecurring = newVal
                        if newVal { isDebt = false } // Mutex: ikisi aynı anda aktif olamaz
                    }
                ))
                
                if isRecurring {
                    Divider().padding(.leading, 56)
                    HStack(spacing: 16) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.brandPrimary)
                            .frame(width: 24)
                        Text(L10n("Sıklık:"))
                            .foregroundStyle(theme.labelPrimary)
                        Spacer()
                        Picker("", selection: $recurringFrequency) {
                            ForEach(RecurrenceInterval.allCases, id: \.self) { interval in
                                Text(interval.title).tag(interval)
                            }
                        }
                        .tint(theme.labelSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    
                    Divider().padding(.leading, 56)
                    HStack(spacing: 16) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.brandPrimary)
                            .frame(width: 24)
                        Text(L10n("Bitiş Tarihi"))
                            .foregroundStyle(theme.labelPrimary)
                        Spacer()
                        
                        Toggle("", isOn: $hasRecurrenceEndDate)
                            .labelsHidden()
                            .tint(theme.brandPrimary)
                        
                        if hasRecurrenceEndDate {
                            DatePicker("", selection: $recurrenceEndDate, displayedComponents: .date)
                                .labelsHidden()
                                .tint(theme.brandPrimary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.separator, lineWidth: 1))

            Button {
                if validateForm() {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    saveTransaction()
                }
            } label: {
                Group {
                    if isSaving {
                        Text("Kaydediliyor...")
                    } else {
                        Text("Kaydet")
                    }
                }
                .font(.headline)
                .foregroundStyle(theme.onBrandPrimary)
                .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 8)
            .disabled(isSaving || !isFormValid)
        }
    }

    private var isFormValid: Bool {
        if amount.isEmpty || selectedMainCategory == nil { return false }
        if isDebt {
            if debtContact.isEmpty || installmentCount.isEmpty { return false }
        }
        return true
    }

    private func validateForm() -> Bool {
        if !isFormValid { return false }
        return true
    }


    private func nextStep() {
        UISelectionFeedbackGenerator().selectionChanged()
        guard let next = TransactionStep(rawValue: currentStep.rawValue + 1) else { return }
        
        // Fix #1: Alt kategorisi olmayan veya aktif alt kategorisi bulunmayan kategorilerde subcategory adımını atla
        if next == .subcategory, (selectedMainCategory?.subCategories ?? []).filter({ $0.isOn }).isEmpty {
            guard let skip = TransactionStep(rawValue: next.rawValue + 1) else { return }
            currentStep = skip
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedDetent = .height(650)
            }
            return
        }
        
        // Normal adım geçişi
        currentStep = next
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedDetent = next == .type ? .height(280) : .height(650)
        }
    }
    
    /// Geri navigasyon — nextStep() ile simetrik çalışır.
    /// Alt kategorisi olmayan kategorilerde .details'ten geri gidince
    /// boş .subcategory ekranı yerine direkt .category'e döner.
    private func prevStep() {
        guard let prev = TransactionStep(rawValue: currentStep.rawValue - 1) else { return }
        
        // .details'ten geri gidiyoruz ve kategorinin alt kategorisi yoksa veya aktif alt kategorisi bulunmuyorsa .subcategory'yi atla
        if prev == .subcategory, (selectedMainCategory?.subCategories ?? []).filter({ $0.isOn }).isEmpty {
            guard let skip = TransactionStep(rawValue: prev.rawValue - 1) else { return }
            currentStep = skip
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedDetent = skip == .type ? .height(280) : .height(650)
            }
            return
        }
        
        // Normal geri geçiş
        currentStep = prev
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedDetent = prev == .type ? .height(280) : .height(650)
        }
    }
    
    private func formatAmountText() -> String {
        if amount.isEmpty { return "0,00 \(selectedCurrency.symbol)" }
        var parsedAmount: Double = 0.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let number = formatter.number(from: amount) {
            parsedAmount = number.doubleValue
        } else {
            let normalized = amount.replacingOccurrences(of: ",", with: ".")
            parsedAmount = Double(normalized) ?? 0.0
        }
        
        let hasDecimal = amount.contains(",") || amount.contains(".")
        if hasDecimal {
            let parts = amount.replacingOccurrences(of: ",", with: ".").split(separator: ".", omittingEmptySubsequences: false)
            let decPart = parts.count > 1 ? parts[1] : ""
            let intVal = floor(parsedAmount)
            let formattedInt = intVal.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
            return "\(formattedInt),\(decPart) \(selectedCurrency.symbol)"
        } else {
            let formatted = parsedAmount.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
            return "\(formatted) \(selectedCurrency.symbol)"
        }
    }

    private func formRow(_ icon: String, _ title: LocalizedStringKey, _ value: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(theme.brandPrimary)
                    .frame(width: 24)
                Text(title).foregroundStyle(theme.labelPrimary)
                Spacer()
                Text(value).foregroundStyle(theme.labelSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.separatorSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private func toggleRow(_ icon: String, _ title: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(theme.brandPrimary)
                .frame(width: 24)
            Toggle(isOn: isOn) {
                Text(title).foregroundStyle(theme.labelPrimary)
            }
            .tint(theme.brandPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .alert(L10n("Yetki Hatası"), isPresented: $showPermissionErrorAlert) {
            Button(L10n("Tamam"), role: .cancel) { }
        } message: {
            Text(L10n("Bu işlemi düzenleme yetkiniz bulunmamaktadır. Sadece kendi eklediğiniz işlemleri düzenleyebilirsiniz."))
        }
    }
    
    @ViewBuilder
    private var budgetWarningView: some View {
        if let limit = walletManager.activeWallet?.monthlyLimit, selectedType == .expense {
            let thisMonthTransactions = transactionManager.transactions.filter {
                $0.type == .expense &&
                !$0.isDebt &&
                Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
            }
            let thisMonthExpense = thisMonthTransactions.reduce(0) { $0 + ExchangeRateManager.shared.convert(amount: $1.amount, from: $1.currency ?? .tryCurrency, to: appCurrency) }
            
            // Fix #10: Locale-safe parse — virgül ve nokta normalleştiriliyor
            let normalized = amount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            let parsedAmount = Double(normalized) ?? 0.0
            let amountInBase = ExchangeRateManager.shared.convert(amount: parsedAmount, from: selectedCurrency, to: appCurrency)
            
            if thisMonthExpense + amountInBase > limit {
                // Fix #9: Kalan bütçe negatife düşebilir, max(0,...) ile koruma
                let remaining = max(0, limit - thisMonthExpense)
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Dikkat: Bu harcama, kalan aylık bütçenizi (\(appCurrency.symbol)\(remaining.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))) aşmaktadır.")
                        .font(.caption)
                    Spacer(minLength: 0)
                }
                .foregroundColor(.white)
                .padding(12)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - OCR Scanner Processing
    private func processReceiptImage(_ image: UIImage) {
        isScanningReceipt = true
        Task {
            let result = await ReceiptScannerManager.scanReceipt(image: image)
            await MainActor.run {
                isScanningReceipt = false
                
                guard let result = result else {
                    // Gemini OCR failed, stop processing and show error alert
                    self.ocrErrorMessage = "Fatura veya fiş okunamadı. Lütfen görüntünün net olduğundan emin olun ve tekrar deneyin."
                    self.showOcrErrorAlert = true
                    return
                }
                
                // Determine if it's an installment transaction (mapped to isDebt in Finvo)
                if result.isInstallment == true {
                    self.isDebt = true
                    self.debtContact = result.merchantName ?? ""
                    if let count = result.installmentCount {
                        self.installmentCount = String(count)
                    } else {
                        self.installmentCount = ""
                    }
                    self.paidInstallments = "0"
                } else {
                    self.isDebt = false
                    self.debtContact = ""
                    self.installmentCount = ""
                    self.paidInstallments = ""
                }
                
                // Populate fields from extraction
                if let amountVal = result.amount {
                    var finalAmount = amountVal
                    if result.isInstallment == true, let count = result.installmentCount, count > 0 {
                        // For installment transactions, the amount input field expects the installment amount (taksit tutarı)
                        // because saveTransaction() will multiply this by the installment count.
                        finalAmount = (amountVal / Double(count)).rounded()
                    }
                    let isInteger = floor(finalAmount) == finalAmount
                    self.amount = isInteger ? String(format: "%.0f", finalAmount) : "\(finalAmount)"
                }
                
                if let dateVal = result.date {
                    self.selectedDate = dateVal
                } else {
                    self.selectedDate = Date()
                }
                
                var noteContent = ""
                if let merchant = installmentNoteName(result: result) {
                    noteContent = merchant
                }
                if let items = result.itemsList, !items.isEmpty {
                    if !noteContent.isEmpty {
                        noteContent += "\n\nÜrünler:\n\(items)"
                    } else {
                        noteContent = "Ürünler:\n\(items)"
                    }
                }
                self.note = noteContent
                
                if let mainCat = result.suggestedCategory {
                    self.selectedMainCategory = mainCat
                    self.selectedSubCategory = result.suggestedSubCategory
                    
                    // Instantly navigate to detail screen
                    self.currentStep = .details
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.selectedDetent = .height(650)
                    }
                } else {
                    self.selectedMainCategory = nil
                    self.selectedSubCategory = nil
                    
                    // Category couldn't be matched. Let user select it directly (step 2)
                    self.currentStep = .category
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        self.selectedDetent = .height(650)
                    }
                }
                
                // OCR scanned transactions are always expenses
                self.selectedType = .expense
            }
        }
    }
    
    private func installmentNoteName(result: ScannedReceiptResult) -> String? {
        guard let merchant = result.merchantName else { return nil }
        if result.isInstallment == true, let count = result.installmentCount {
            return "\(merchant) (\(count) Taksit)"
        }
        return merchant
    }
    
    private var inlineScanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.brandPrimary))
                .scaleEffect(1.3)
                .padding(.bottom, 8)
            
            Text("Fiş Taranıyor...")
                .font(.headline)
                .foregroundStyle(theme.labelPrimary)
            
            Text("Bilgiler otomatik okunuyor, lütfen bekleyin.")
                .font(.subheadline)
                .foregroundStyle(theme.labelSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Save Logic
    private func saveTransaction() {
        guard let activeWallet = walletManager.activeWallet, 
              let walletId = activeWallet.id,
              !walletId.isEmpty,
              let currentUser = authManager.currentUserProfile?.username else { 
            print("DEBUG: Wallet ID or Current User is missing. ActiveWallet ID: \(String(describing: walletManager.activeWallet?.id))")
            return 
        }
        
        let roleRaw = activeWallet.permissions[currentUser]
        if roleRaw == WalletRole.viewer.rawValue {
            showPermissionErrorAlert = true
            return
        }
        
        // Fix #10: Locale-safe parse — önce NumberFormatter dene, sonra normalize et
        var parsedAmount: Double = 0.0
        let normalizedAmount = amount
            .replacingOccurrences(of: " ", with: "")   // boşlukları temizle
            .replacingOccurrences(of: ".", with: "")   // binlik ayıraçları çıkar
            .replacingOccurrences(of: ",", with: ".")  // ondalık virgülü noktaya çevir
        parsedAmount = Double(normalizedAmount) ?? 0.0
        
        // Fix #3: Borç amount hesabı
        // Yeni işlem: kullanıcı taksit başı tutarı girer → toplam = taksit * sayı
        // Düzenleme (mevcut borç, taksitli): init() zaten bölmüş → tekrar çarp
        // Düzenleme (mevcut borç, taksitsiz): init() bölmemiş → taksit eklendiyse ÇARPMa
        if isDebt {
            let count = Double(installmentCount) ?? 1.0
            let isNewDebt = transactionToEdit == nil
            let editingDebtWithExistingInstallments = transactionToEdit?.isDebt == true
                && (transactionToEdit?.totalInstallments ?? 0) > 0
            
            if isNewDebt || editingDebtWithExistingInstallments {
                // Yeni borç veya taksitli borç düzenleniyor: taksit başı × sayı = toplam
                parsedAmount = parsedAmount * count
            }
            // Taksitsiz borç düzenleniyorsa parsedAmount zaten toplam tutardır
        }
        
        isSaving = true
        
        let categoryColorHex = selectedSubCategory?.color ?? selectedMainCategory?.color
        
        let newTransaction = TransactionModel(
            walletId: walletId,
            type: selectedType,
            amount: parsedAmount,
            currency: selectedCurrency,
            mainCategoryName: selectedMainCategory?.name ?? "Bilinmeyen",
            mainCategoryId: selectedMainCategory?.id,
            subCategoryName: selectedSubCategory?.name,
            subCategoryId: selectedSubCategory?.id,
            categoryIcon: selectedSubCategory?.icon ?? selectedMainCategory?.icon ?? "questionmark",
            categoryColor: categoryColorHex,
            date: selectedDate,
            note: note.isEmpty ? nil : note,
            createdBy: transactionToEdit?.createdBy ?? currentUser,
            createdAt: transactionToEdit?.createdAt ?? Date(),
            isDebt: isDebt,
            debtContact: isDebt ? debtContact : nil,
            totalInstallments: isDebt ? Int(installmentCount) : nil,
            paidInstallments: isDebt ? (Int(paidInstallments) ?? 0) : nil,  // Bug #9 fix: nil yerine 0
            dueDay: isDebt ? dueDay : nil,
            isPaid: false,
            isRecurring: isRecurring,
            recurrenceInterval: isRecurring ? recurringFrequency : nil,
            recurrenceEndDate: (isRecurring && hasRecurrenceEndDate) ? recurrenceEndDate : nil
        )
        
        Task {
            do {
                if let editing = transactionToEdit, let id = editing.id {
                    var updated = newTransaction
                    updated.id = id
                    try FirestoreService.shared.updateTransaction(updated)
                } else {
                    try FirestoreService.shared.createTransaction(newTransaction)
                }
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("Error saving: \(error)")
                }
            }
        }
    }
    
    // MARK: - Locked View
    private var lockedWalletView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("Cüzdan Kilitli")
                .font(.title2.weight(.bold))
            
            Text("Bu paylaşımlı cüzdanda 2'den fazla üye olduğu için işlem ekleme özelliği devre dışı bırakıldı. Devam etmek için Pro'ya geçin veya üye sayısını azaltın.")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal, 32)
            
            Button {
                showPaywall = true
            } label: {
                Text("Pro'ya Yükselt")
                    .fontWeight(.bold)
                    .foregroundStyle(theme.onBrandPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.brandPrimary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if transactionToEdit == nil {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(theme.labelPrimary)
                    }
                }
            }
        }
    }
}

extension LocalizedStringKey {
    var stringValue: String {
        let mirrored = Mirror(reflecting: self)
        for child in mirrored.children {
            if child.label == "key" {
                return child.value as? String ?? ""
            }
        }
        return ""
    }
}

struct SelectionCard: View {
    @Environment(\.theme) var theme
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.labelPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(theme.separator, lineWidth: 1)
            )
        }
    }
}

#Preview {
    AddTransactionsView()
        .environment(\.theme, DefaultTheme())
}
