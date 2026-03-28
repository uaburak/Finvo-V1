import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    @State private var isGenerating = false
    
    // Seçilen dili cihazda System Defaults olarak saklar
    @AppStorage("appLanguage") private var appLanguage: String = "tr"
    
    let languages = [
        ("tr", "Türkçe 🇹🇷"),
        ("en", "English 🇺🇸"),
        ("de", "Deutsch 🇩🇪"),
        ("ru", "Русский 🇷🇺")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Üyelik Durumu (Test)")) {
                    Toggle(isOn: Binding(
                        get: { authManager.currentUserProfile?.isPro ?? false },
                        set: { newValue in
                            updateProStatus(newValue)
                        }
                    )) {
                        HStack {
                            Label("Pro Üyelik", systemImage: "crown.fill")
                                .foregroundColor(authManager.currentUserProfile?.isPro == true ? .yellow : .gray)
                            Spacer()
                            Text(authManager.currentUserProfile?.isPro == true ? "Aktif" : "Pasif")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Dil Ayarları")) {
                    Picker("Uygulama Dili", selection: $appLanguage) {
                        ForEach(languages, id: \.0) { lang in
                            Text(lang.1).tag(lang.0)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                Section {
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        do {
                            try authManager.signOut()
                        } catch {
                            print("Çıkış hatası: \(error)")
                        }
                    } label: {
                        HStack {
                            Text("Hesaptan Çıkış Yap")
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                
                Section(header: Text("Geliştirici Araçları")) {
                    Button {
                        generateTestTransactions()
                    } label: {
                        HStack {
                            Text(isGenerating ? "İşlemler Üretiliyor..." : "Test Verisi Üret (100 İşlem)")
                            Spacer()
                            if isGenerating {
                                ProgressView()
                            } else {
                                Image(systemName: "hammer.fill")
                            }
                        }
                    }
                    .disabled(isGenerating)
                    .foregroundStyle(theme.brandPrimary)
                    
                    Button(role: .destructive) {
                        resetCategories()
                    } label: {
                        HStack {
                            Text("Kategorileri Sıfırla (Düzeltme)")
                            Spacer()
                            Image(systemName: "arrow.counterclockwise.circle")
                        }
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Gelişmiş Test Verisi Üretici
    private func generateTestTransactions() {
        guard let walletId = walletManager.activeWallet?.id,
              let currentUsername = authManager.currentUserProfile?.username else { return }
        
        isGenerating = true
        
        Task {
            var testTransactions: [TransactionModel] = []
            let calendar = Calendar.current
            let now = Date()
            
            // 1. Düzenli Maaş (Son 5 Ay - Geçmiş)
            for i in 1...5 {
                if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                    testTransactions.append(createTestTransaction(
                        walletId: walletId, type: .income, amount: 45000,
                        mainCategoryName: "Maaş", subCategoryName: "Düzenli Maaş",
                        categoryIcon: "banknote.fill", isRecurring: true,
                        date: date, note: "Otomatik Maaş Ödemesi",
                        createdBy: currentUsername, createdAt: now))
                }
            }
            
            // 2. Düzenli İnternet (Son 7 Ay - Geçmiş)
            for i in 1...7 {
                if let date = calendar.date(byAdding: .month, value: -i, to: now) {
                    testTransactions.append(createTestTransaction(
                        walletId: walletId, type: .expense, amount: 650,
                        mainCategoryName: "Faturalar", subCategoryName: "İnternet",
                        categoryIcon: "wifi", isRecurring: true,
                        date: date, note: "Turkcell Superonline",
                        createdBy: currentUsername, createdAt: now))
                }
            }
            
            // 3. Yaklaşan Abonelik/Tekrarlayan İşlemler (Gelecek - 10 gün ve 20 gün sonra)
            if let f1 = calendar.date(byAdding: .day, value: 5, to: now) {
                testTransactions.append(createTestTransaction(walletId: walletId, type: .expense, amount: 200, mainCategoryName: "Eğlence", subCategoryName: "Netflix", categoryIcon: "play.tv.fill", isRecurring: true, date: f1, note: "Gelecek Netflix Kesintisi", createdBy: currentUsername, createdAt: now))
            }
            if let f2 = calendar.date(byAdding: .day, value: 12, to: now) {
                testTransactions.append(createTestTransaction(walletId: walletId, type: .expense, amount: 80, mainCategoryName: "Eğlence", subCategoryName: "Spotify", categoryIcon: "music.note", isRecurring: true, date: f2, note: "Gelecek Spotify Kesintisi", createdBy: currentUsername, createdAt: now))
            }
            if let f3 = calendar.date(byAdding: .day, value: 2, to: now) {
                testTransactions.append(createTestTransaction(walletId: walletId, type: .income, amount: 15000, mainCategoryName: "Diğer Gelirler", subCategoryName: "Kira", categoryIcon: "house.fill", isRecurring: true, date: f3, note: "Yaklaşan Kira Geliri", createdBy: currentUsername, createdAt: now))
            }
            
            // 4. Gelecek Tarihli Borç Ödemeleri (Bekleyen İşlemler - Gelecek)
            if let d1 = calendar.date(byAdding: .day, value: 8, to: now) {
                testTransactions.append(createTestTransaction(walletId: walletId, type: .expense, amount: 2500, mainCategoryName: "Borç & Kredi", subCategoryName: "Kredi Kartı", categoryIcon: "creditcard.fill", isDebt: true, date: d1, note: "Ekstre Ödemesi", createdBy: currentUsername, createdAt: now))
            }
            if let d2 = calendar.date(byAdding: .day, value: 18, to: now) {
                testTransactions.append(createTestTransaction(walletId: walletId, type: .expense, amount: 450, mainCategoryName: "Borç & Kredi", subCategoryName: "Arkadaşa Borç", categoryIcon: "person.2.fill", isDebt: true, date: d2, note: "Ahmet'e olan borç taksidi", createdBy: currentUsername, createdAt: now))
            }
            
            // 5. Rastgele Çerez İşlemler (Yeni Kategori Sistemiyle Uyumlu)
            for i in 1...80 {
                if let randomCat = CategoriesMockData.data.randomElement() {
                    let randomSub = randomCat.subCategories.randomElement()
                    let randomAmount = Double.random(in: 100...2500)
                    let randomDays = Int.random(in: 1...60)
                    let rDate = calendar.date(byAdding: .day, value: -randomDays, to: now) ?? now
                    
                    testTransactions.append(createTestTransaction(
                        walletId: walletId, 
                        type: randomCat.type, 
                        amount: randomAmount,
                        mainCategoryName: randomCat.name, 
                        subCategoryName: randomSub?.name,
                        categoryIcon: randomSub?.icon ?? randomCat.icon,
                        categoryColor: randomSub?.color ?? randomCat.color,
                        date: rDate, 
                        note: "Test Harcaması #\(i)",
                        createdBy: currentUsername, 
                        createdAt: now
                    ))
                }
            }
            
            // Firestore'a gönder
            for tx in testTransactions {
                try? await FirestoreService.shared.createTransaction(tx)
            }
            
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    // Doğrudan Swift'in varsayılan init'iyle güvenli TransactionModel üretme metodu.
    private func createTestTransaction(
        walletId: String,
        type: TransactionType,
        amount: Double,
        mainCategoryName: String,
        subCategoryName: String? = nil,
        categoryIcon: String,
        categoryColor: String? = nil,
        isRecurring: Bool = false,
        isDebt: Bool = false,
        date: Date,
        note: String? = nil,
        createdBy: String,
        createdAt: Date
    ) -> TransactionModel {
        return TransactionModel(
            id: UUID().uuidString,
            walletId: walletId,
            type: type,
            amount: amount,
            mainCategoryName: mainCategoryName,
            subCategoryName: subCategoryName,
            categoryIcon: categoryIcon,
            categoryColor: categoryColor,
            date: date,
            note: note,
            createdBy: createdBy,
            createdAt: createdAt,
            isDebt: isDebt,
            debtContact: nil,
            totalInstallments: nil,
            paidInstallments: nil,
            dueDay: nil,
            isPaid: false,
            isRecurring: isRecurring,
            recurrenceInterval: nil,
            recurrenceEndDate: nil
        )
    }

    private func updateProStatus(_ isPro: Bool) {
        guard var profile = authManager.currentUserProfile else { return }
        profile.isPro = isPro
        
        Task {
            try? await FirestoreService.shared.saveUserProfile(profile)
            await authManager.checkUserProfile()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    private func resetCategories() {
        guard let walletId = walletManager.activeWallet?.id else { return }
        Task {
            do {
                // 1. Her şeyi sil (Raw delete)
                try await FirestoreService.shared.deleteAllCategories(walletId: walletId)
                
                // 2. Varsayılanları deterministik ID ve koruma ile yükle
                // initializeDefaultCategories direkt çağrılmalı ki CategoryManager'ın load'uyla çakışmasın
                try await FirestoreService.shared.initializeDefaultCategories(walletId: walletId, categories: CategoriesMockData.data)
                
                // 3. Manager'ı güncelle
                CategoryManager.shared.startListening(walletId: walletId)
                
                print("DEBUG: Categories successfully reset and re-initialized for wallet \(walletId)")
            } catch {
                print("DEBUG: Error resetting categories: \(error)")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager.shared)
}
