import SwiftUI

struct SettingsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    
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
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthenticationManager.shared)
}
