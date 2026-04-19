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
    @AppStorage("appThemeColor") private var appThemeColor: String = AppThemeColor.neonGreen.rawValue
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profil Özeti
                Section {
                    Button {
                        showProfileSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            ProfileImageView(photoURL: authManager.user?.photoURL)
                                .frame(width: 50, height: 50)
                            
                            VStack(alignment: .leading, spacing: 2) {
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
                        .padding(.vertical, 2)
                    }
                }
                
                // MARK: - Uygulama Ayarları
                Section(header: Text(L10n("Uygulama Tercihleri"))) {
                    Picker(selection: $appLanguage) {
                        ForEach(languages, id: \.0) { lang in
                            Text(lang.1).tag(lang.0)
                        }
                    } label: {
                        Label {
                            Text(L10n("Uygulama Dili")).foregroundColor(theme.labelPrimary)
                        } icon: {
                            Image(systemName: "globe").foregroundColor(theme.brandPrimary)
                        }
                    }
                    
                    Picker(selection: $appThemeColor) {
                        ForEach(AppThemeColor.allCases) { themeColor in
                            Text(themeColor.title).tag(themeColor.rawValue)
                        }
                    } label: {
                        Label {
                            Text(L10n("Tema Rengi")).foregroundColor(theme.labelPrimary)
                        } icon: {
                            Image(systemName: "paintpalette").foregroundColor(theme.brandPrimary)
                        }
                    }
                    
                    Picker(selection: $appCurrency) {
                        let allowedFiatCodes = ["TRY", "USD", "EUR", "GBP", "CHF", "CAD", "RUB"]
                        ForEach(exchangeRateManager.allCurrencies.filter { allowedFiatCodes.contains($0.code) }.sorted(by: { $0.code == "TRY" ? true : $0.name < $1.name }), id: \.self) { currency in
                            Text("\(currency.symbol) \(currency.name)").tag(currency)
                        }
                    } label: {
                        Label {
                            Text(L10n("Para Birimi")).foregroundColor(theme.labelPrimary)
                        } icon: {
                            Image(systemName: "coloncurrencysign.circle").foregroundColor(theme.brandPrimary)
                        }
                    }
                }
                
                // MARK: - Abonelik
                Section(header: Text(L10n("Abonelik"))) {
                    HStack {
                        Label(L10n("Pro Üyelik"), systemImage: "crown.fill")
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
                            Text(L10n("Pro'ya Yükselt"))
                                .fontWeight(.bold)
                                .foregroundColor(theme.brandPrimary)
                        }
                    }
                }
                
                // MARK: - Destek ve Hakkında
                Section(header: Text(L10n("Destek"))) {
                    Link(destination: URL(string: "https://finvo.app/privacy")!) {
                        Label {
                            Text(L10n("Gizlilik Politikası")).foregroundColor(theme.labelPrimary)
                        } icon: {
                            Image(systemName: "hand.raised.fill").foregroundColor(theme.brandPrimary)
                        }
                    }
                    Link(destination: URL(string: "https://finvo.app/terms")!) {
                        Label {
                            Text(L10n("Kullanım Koşulları")).foregroundColor(theme.labelPrimary)
                        } icon: {
                            Image(systemName: "doc.text.fill").foregroundColor(theme.brandPrimary)
                        }
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
                            Label {
                                Text(L10n("Hesaptan Çıkış Yap")).foregroundColor(.red)
                            } icon: {
                                Image(systemName: "rectangle.portrait.and.arrow.right").foregroundColor(.red)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n("Ayarlar"))
            .sheet(isPresented: $showProfileSheet) {
                ProfileSettingsView()
                    .environmentObject(authManager)
                    .environmentObject(walletManager)
            }
            .navigationTitle(L10n("Ayarlar"))
        }
    }
}
    
#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(WalletManager())
}
