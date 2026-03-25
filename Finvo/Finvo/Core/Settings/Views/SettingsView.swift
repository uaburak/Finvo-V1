import SwiftUI

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
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Test Verisi Üretici
    private func generateTestTransactions() {
        guard let walletId = walletManager.activeWallet?.id,
              let currentUsername = authManager.currentUserProfile?.username else { return }
        
        isGenerating = true
        
        let categories: [(String, String, TransactionType)] = [
            ("Market & Gıda", "cart.fill", .expense),
            ("Ulaşım", "car.fill", .expense),
            ("Eğlence", "popcorn.fill", .expense),
            ("Faturalar", "doc.text.fill", .expense),
            ("Eğitim", "book.fill", .expense),
            ("Maaş", "banknote.fill", .income),
            ("Serbest Çalışma", "laptopcomputer", .income),
            ("Yatırım Getirisi", "chart.line.uptrend.xyaxis", .income)
        ]
        
        Task {
            for i in 1...100 {
                let randomCat = categories.randomElement()!
                let randomAmount = Double.random(in: 50...5000)
                // Son 6 ay içinde rastgele tarih (0'dan 180 güne kadar geriye)
                let randomDays = Int.random(in: 0...180)
                let randomDate = Calendar.current.date(byAdding: .day, value: -randomDays, to: Date()) ?? Date()
                
                let tx = TransactionModel(
                    walletId: walletId,
                    type: randomCat.2,
                    amount: randomAmount,
                    mainCategoryName: randomCat.0,
                    subCategoryName: "Test #\(i)",
                    categoryIcon: randomCat.1,
                    date: randomDate,
                    note: "Bu işlem analiz ekranını test etmek için otomatik üretildi.",
                    createdBy: currentUsername,
                    createdAt: Date()
                )
                
                try? await FirestoreService.shared.createTransaction(tx)
            }
            
            await MainActor.run {
                isGenerating = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager.shared)
}
