import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    @StateObject private var exchangeRateManager = ExchangeRateManager.shared
    @State private var isGenerating = false
    @State private var showPaywall = false
    
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
                    NavigationLink {
                        ProfileSettingsView()
                            .environmentObject(authManager)
                            .environmentObject(walletManager)
                    } label: {
                        HStack(spacing: 12) {
                            CachedProfileImage(
                                urlString: authManager.currentUserProfile?.photoUrl,
                                width: 48,
                                height: 48,
                                fallbackIconSize: 24,
                                isCircle: false,
                                cornerRadius: 12
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.currentUserProfile?.fullName ?? "Finvo Kullanıcısı".localized)
                                    .font(.headline)
                                    .foregroundColor(theme.labelPrimary)

                                Text(authManager.currentUserProfile?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(theme.labelSecondary)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
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
                    .tint(theme.labelPrimary)
                    
                    Picker(selection: $appThemeColor) {
                        ForEach(AppThemeColor.allCases) { themeColor in
                            Text(LocalizedStringKey(themeColor.titleKey)).tag(themeColor.rawValue)
                        }
                    } label: {
                        Label("Tema Rengi", systemImage: "paintpalette")
                    }
                    .tint(theme.labelPrimary)
                    
                    Picker(selection: $appCurrency) {
                        let allowedFiatCodes = ["TRY", "USD", "EUR", "GBP", "CHF", "CAD", "RUB"]
                        ForEach(exchangeRateManager.allCurrencies.filter { allowedFiatCodes.contains($0.code) }.sorted(by: { $0.code == "TRY" ? true : $0.name < $1.name }), id: \.self) { currency in
                            Text("\(currency.symbol) \(currency.name)").tag(currency)
                        }
                    } label: {
                        Label("Para Birimi", systemImage: "coloncurrencysign.circle")
                    }
                    .tint(theme.labelPrimary)
                }
                
                // MARK: - Abonelik
                Section(header: Text("Abonelik")) {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            Label("Pro Üyelik", systemImage: "crown.fill")
                                .foregroundColor(authManager.currentUserProfile?.isPro == true ? .yellow : .gray)
                            Spacer()
                            if authManager.currentUserProfile?.isPro == true {
                                Text("Aktif")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Aboneliği Başlat")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(theme.brandPrimary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // TEST TOGGLE
                    Toggle(isOn: Binding(
                        get: { authManager.currentUserProfile?.isPro ?? false },
                        set: { newValue in
                            authManager.currentUserProfile?.isPro = newValue
                            if let profile = authManager.currentUserProfile {
                                Task {
                                    try? await FirestoreService.shared.saveUserProfile(profile)
                                }
                            }
                        }
                    )) {
                        Label("Test: Pro Modu", systemImage: "testtube.2")
                    }
                }
                
                // MARK: - Destek ve Hakkında
                Section(header: Text("Destek")) {
                    Link(destination: URL(string: "https://finvo.app/privacy")!) {
                        Label {
                            Text("Gizlilik Politikası")
                                .foregroundColor(theme.labelPrimary)
                        } icon: {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(theme.brandPrimary)
                        }
                    }
                    Link(destination: URL(string: "https://finvo.app/terms")!) {
                        Label {
                            Text("Kullanım Koşulları")
                                .foregroundColor(theme.labelPrimary)
                        } icon: {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(theme.brandPrimary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .padding(.top, -35)
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showPaywall) {
                ProSubscriptionPaywallView()
            }
        }
    }
}
    
#Preview {
    SettingsView()
        .environment(\.theme, DefaultTheme())
        .environmentObject(AuthenticationManager.shared)
        .environmentObject(WalletManager())
}
