import SwiftUI

struct AddIBANSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var bankName: String = ""
    @State private var ibanString: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(spacing: 24) {
                        // Banka Adı - Tam Yuvarlak (Capsule) & Başlıksız
                        TextField("Banka Adı", text: $bankName)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                            .autocorrectionDisabled()
                        
                        // IBAN Numarası - Tam Yuvarlak (Capsule) & Başlıksız
                        TextField("IBAN Numarası", text: $ibanString)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                            .keyboardType(.asciiCapable)
                            .autocorrectionDisabled()
                            .onChange(of: ibanString) { oldValue, newValue in
                                let uppercased = newValue.uppercased()
                                if ibanString != uppercased {
                                    ibanString = uppercased
                                }
                            }
                    }
                    .padding(.top, 10)
                    
                    Button {
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.prepare()
                        
                        guard !bankName.isEmpty && ibanString.count >= 10 else { return }
                        
                        saveIBAN()
                        
                        feedback.impactOccurred()
                    } label: {
                        Text("Kaydet")
                            .font(.headline)
                            .foregroundStyle(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 24)
                    .disabled(bankName.isEmpty || ibanString.count < 10)
                    .opacity((bankName.isEmpty || ibanString.count < 10) ? 0.6 : 1.0)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
            }
            .navigationTitle("IBAN Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                            .foregroundStyle(theme.labelPrimary)
                    }
                }
            }
        }
    }
    
    private func saveIBAN() {
        guard var profile = authManager.currentUserProfile else { return }
        
        let newIBAN = IBANModel(id: UUID().uuidString, bankName: bankName, ibanString: ibanString)
        
        if profile.ibans == nil {
            profile.ibans = []
        }
        profile.ibans?.append(newIBAN)
        
        Task {
            do {
                try await FirestoreService.shared.saveUserProfile(profile)
                await authManager.checkUserProfile()
                dismiss()
            } catch {
                print("IBAN kaydetme hatası: \(error)")
            }
        }
    }
}

#Preview {
    AddIBANSheet()
        .environment(\.theme, DefaultTheme())
        .environmentObject(AuthenticationManager.shared)
}

