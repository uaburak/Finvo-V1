//
//  AddTransactionsView.swift
//  Finvo
//

import SwiftUI

struct AddTransactionsView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager

    let transactionToEdit: TransactionModel?

    @State private var selectedType: TransactionType = .expense
    @State private var selectedMainCategory: CategoryModel?
    @State private var selectedSubCategory: SubCategoryModel?
    @State private var selectedDate: Date = Date()
    @State private var amount: String = ""
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
    
    @State private var currentStep: TransactionStep
    @State private var selectedDetent: PresentationDetent
    
    init(transactionToEdit: TransactionModel? = nil) {
        self.transactionToEdit = transactionToEdit
        
        let type = transactionToEdit?.type ?? .expense
        _selectedType = State(initialValue: type)
        _selectedDate = State(initialValue: transactionToEdit?.date ?? Date())
        _amount = State(initialValue: transactionToEdit != nil ? String(format: "%.0f", transactionToEdit!.amount) : "")
        
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
        
        var title: String {
            switch self {
            case .type: return "İşlem Türü"
            case .category: return "Kategori Seçin"
            case .subcategory: return "Alt Kategori Seçin"
            case .details: return "İşlem Detayları"
            }
        }
    }

    enum ActiveSheet: Identifiable {
        case category, amount
        var id: Int { hashValue }
    }

    private var categoryRowValue: String {
        if let sub = selectedSubCategory { return sub.name }
        if let main = selectedMainCategory { return main.name }
        return "Seçin"
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            stepContent
                                .padding(.top, 20)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                } // Ends VStack
                .navigationTitle(currentStep.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if currentStep != .type && transactionToEdit == nil {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                if let prev = TransactionStep(rawValue: currentStep.rawValue - 1) {
                                    // İçerik (currentStep) anında değişir:
                                    currentStep = prev
                                    // Sheet boyutu (selectedDetent) animasyonlu değişir:
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        selectedDetent = prev == .type ? .height(280) : .height(650)
                                    }
                                }
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
            } // Ends NavigationStack
            // Dinamik Sheet Yüksekliği (Animasyonla Geçiş)
            .presentationDetents([.height(280), .height(650)], selection: $selectedDetent)
            .presentationDragIndicator(.hidden)
            // Bütün steplerde hiçbir arka plan rengi yok (Tamamen Şeffaf)
            .presentationBackground(.clear) 
            .onAppear {
                UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(theme.brandPrimary)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
                UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor(theme.labelSecondary)], for: .normal)
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .category:
                    CategorySelectionSheet(
                        categories: (categoryManager.categories.isEmpty ? CategoriesMockData.data : categoryManager.categories).filter { $0.type == selectedType },
                        selectedMainCategory: $selectedMainCategory,
                        selectedSubCategory: $selectedSubCategory
                    )
                case .amount:
                    AmountInputSheet(amount: $amount)
                        .presentationDetents([.height(300)])
                        .presentationBackground(.clear)
                }
            }
            .alert("Yetki İste", isPresented: $showPermissionErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Görüntüleyici rolüne sahip olduğunuz için cüzdana işlem ekleyemezsiniz. Lütfen kurucudan yetki isteyin.")
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
    }

    private var categorySelectionView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            let filteredCategories = CategoryManager.shared.categories.isEmpty ? CategoriesMockData.data.filter { $0.type == selectedType } : CategoryManager.shared.categories.filter { $0.type == selectedType }
            ForEach(filteredCategories) { category in
                SelectionCard(title: category.name, icon: category.icon, color: category.uiColor) {
                    selectedMainCategory = category
                    nextStep()
                }
            }
        }
    }

    private var subcategorySelectionView: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            if let subCategories = selectedMainCategory?.subCategories {
                ForEach(subCategories) { sub in
                    SelectionCard(title: sub.name, icon: sub.icon, color: sub.uiColor) {
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
            HStack {
                summaryItem(icon: selectedMainCategory?.icon ?? "", color: selectedMainCategory?.color, text: selectedMainCategory?.name ?? "")
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.labelSecondary)
                summaryItem(icon: selectedSubCategory?.icon ?? "", color: selectedSubCategory?.color, text: selectedSubCategory?.name ?? "")
            }
            .padding(.vertical, 8)

            VStack(spacing: 0) {
                formRow("turkishlirasign.circle", "Tutar", amount.isEmpty ? "0,00 ₺" : "₺\(amount)") { activeSheet = .amount }
                Divider().padding(.leading, 56)
                
                HStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.brandPrimary)
                        .frame(width: 24)
                    DatePicker("Tarih", selection: $selectedDate, displayedComponents: .date)
                        .foregroundStyle(theme.labelPrimary)
                        .tint(theme.brandPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.separator, lineWidth: 1))

            // Not Alanı
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 20))
                        .foregroundStyle(theme.brandPrimary)
                        .frame(width: 24)
                    TextField("Not Ekle (İsteğe bağlı)", text: $note)
                        .foregroundStyle(theme.labelPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(theme.separator, lineWidth: 1))

            VStack(spacing: 0) {
                toggleRow("person.2.fill", "Borç / Alacak İşlemi", isOn: $isDebt)
                
                if isDebt {
                    Divider().padding(.leading, 56)
                    
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.brandPrimary)
                            .frame(width: 24)
                        TextField("Kişi veya Kurum (Örn: Ahmet)", text: $debtContact)
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
                        
                        TextField("Toplam Taksit", text: $installmentCount)
                            .keyboardType(.numberPad)
                            .foregroundStyle(theme.labelPrimary)
                        
                        Divider().frame(height: 20)
                        
                        TextField("Ödenen", text: $paidInstallments)
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
                        Text("Son Ödeme Günü")
                            .foregroundStyle(theme.labelPrimary)
                        Spacer()
                        Text("Her ayın")
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
                
                toggleRow("arrow.2.squarepath", "Tekrarlayan İşlem", isOn: $isRecurring)
                
                if isRecurring {
                    Divider().padding(.leading, 56)
                    HStack(spacing: 16) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.system(size: 20))
                            .foregroundStyle(theme.brandPrimary)
                            .frame(width: 24)
                        Text("Sıklık:")
                            .foregroundStyle(theme.labelPrimary)
                        Spacer()
                        Picker("", selection: $recurringFrequency) {
                            ForEach(RecurrenceInterval.allCases, id: \.self) { interval in
                                Text(interval.rawValue).tag(interval)
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
                        Text("Bitiş Tarihi")
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
                Text(isSaving ? "Kaydediliyor..." : "Kaydet")
                    .font(.headline)
                    .foregroundStyle(.white)
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

    private func summaryItem(icon: String, color: String?, text: String) -> some View {
        let resolvedColor = color != nil ? Color(hex: color!) : .gray
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(resolvedColor)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(theme.labelPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(resolvedColor.opacity(0.1))
        .clipShape(Capsule())
    }

    private func nextStep() {
        UISelectionFeedbackGenerator().selectionChanged()
        if let next = TransactionStep(rawValue: currentStep.rawValue + 1) {
            // İçerik anında değişir
            currentStep = next
            // Sheet'in yüksekliği animasyonla büyür
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                selectedDetent = next == .type ? .height(280) : .height(650)
            }
        }
    }

    private func formRow(_ icon: String, _ title: String, _ value: String, action: @escaping () -> Void) -> some View {
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
    
    private func toggleRow(_ icon: String, _ title: String, isOn: Binding<Bool>) -> some View {
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
        
        // Parse Amount safely
        let cleanAmount = amount.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        let parsedAmount = Double(cleanAmount) ?? 0.0
        
        isSaving = true
        
        let categoryColorHex = selectedSubCategory?.color ?? selectedMainCategory?.color
        
        let newTransaction = TransactionModel(
            walletId: activeWallet.id ?? "",
            type: selectedType,
            amount: parsedAmount,
            mainCategoryName: selectedMainCategory?.name ?? "Bilinmeyen",
            mainCategoryId: selectedMainCategory?.id,
            subCategoryName: selectedSubCategory?.name,
            subCategoryId: selectedSubCategory?.id,
            categoryIcon: selectedSubCategory?.icon ?? selectedMainCategory?.icon ?? "questionmark",
            categoryColor: categoryColorHex,
            date: selectedDate,
            note: note.isEmpty ? nil : note,
            createdBy: currentUser,
            createdAt: Date(),
            isDebt: isDebt,
            debtContact: isDebt ? debtContact : nil,
            totalInstallments: isDebt ? Int(installmentCount) : nil,
            paidInstallments: isDebt ? Int(paidInstallments) : nil,
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
                    try await FirestoreService.shared.updateTransaction(updated)
                } else {
                    try await FirestoreService.shared.createTransaction(newTransaction)
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
    
    private func colorName(for color: Color) -> String {
        switch color {
        case .blue: return "blue"
        case .green: return "green"
        case .red: return "red"
        case .orange: return "orange"
        case .purple: return "purple"
        case .pink: return "pink"
        case .teal: return "teal"
        case .indigo: return "indigo"
        case .brown: return "brown"
        case .cyan: return "cyan"
        case .yellow: return "yellow"
        case .gray: return "gray"
        case .mint: return "mint"
        default: return "blue"
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
    let title: String
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
