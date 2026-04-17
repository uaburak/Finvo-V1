import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    @State private var isGenerating = false
    @State private var showProfileSheet = false
    
    // Seçilen dili cihazda System Defaults olarak saklar
    @AppStorage("appLanguage") private var appLanguage: String = "tr"
    
    let languages = [
        ("tr", "Türkçe"),
        ("en", "English"),
        ("de", "Deutsch"),
        ("ru", "Русский")
    ]
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profil Özeti
                Section {
                    Button {
                        showProfileSheet = true
                    } label: {
                        HStack(spacing: 16) {
                            ProfileImageView(photoURL: authManager.user?.photoURL)
                                .frame(width: 60, height: 60)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.currentUserProfile?.fullName ?? "Finvo Kullanıcısı")
                                    .font(.headline)
                                    .foregroundColor(theme.labelPrimary)
                                
                                Text(authManager.currentUserProfile?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(theme.labelSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(theme.labelSecondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // MARK: - Uygulama Ayarları
                Section(header: Text("Uygulama Tercihleri")) {
                    Picker(selection: $appLanguage) {
                        ForEach(languages, id: \.0) { lang in
                            Text(lang.1).tag(lang.0)
                        }
                    } label: {
                        Label("Uygulama Dili", systemImage: "globe")
                    }
                    
                    Picker(selection: $appCurrency) {
                        let allowedFiatCodes = ["TRY", "USD", "EUR", "GBP", "CHF", "CAD", "RUB"]
                        ForEach(exchangeRateManager.allCurrencies.filter { allowedFiatCodes.contains($0.code) }.sorted(by: { $0.code == "TRY" ? true : $0.name < $1.name }), id: \.self) { currency in
                            Text("\(currency.symbol) \(currency.name)").tag(currency)
                        }
                    } label: {
                        Label("Para Birimi", systemImage: "coloncurrencysign.circle")
                    }
                }
                
                // MARK: - Abonelik
                Section(header: Text("Abonelik")) {
                    HStack {
                        Label("Pro Üyelik", systemImage: "crown.fill")
                            .foregroundColor(authManager.currentUserProfile?.isPro == true ? .yellow : .gray)
                        Spacer()
                        Text(authManager.currentUserProfile?.isPro == true ? "Aktif" : "Pasif")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if authManager.currentUserProfile?.isPro == false {
                        Button {
                            // Satın alma akışı
                        } label: {
                            Text("Pro'ya Yükselt")
                                .fontWeight(.bold)
                                .foregroundColor(theme.brandPrimary)
                        }
                    }
                }
                
                // MARK: - Destek ve Hakkında
                Section(header: Text("Destek")) {
                    Link(destination: URL(string: "https://finvo.app/privacy")!) {
                        Label("Gizlilik Politikası", systemImage: "hand.raised.fill")
                    }
                    Link(destination: URL(string: "https://finvo.app/terms")!) {
                        Label("Kullanım Koşulları", systemImage: "doc.text.fill")
                    }
                }
                
                // MARK: - Çıkış Yap
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
                            Label("Hesaptan Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ayarlar")
            .sheet(isPresented: $showProfileSheet) {
                ProfileSettingsView()
                    .environmentObject(authManager)
                    .environmentObject(walletManager)
            }
            .navigationTitle("Ayarlar")
        }
    }
}
    
#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(WalletManager())
}
