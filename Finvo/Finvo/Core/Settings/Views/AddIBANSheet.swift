import SwiftUI

struct AddIBANSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var bankName: String = ""
    @State private var ibanString: String = ""
    @State private var selectedBank: String = "Akbank"
    
    let popularBanks = [
        "Akbank", "Garanti BBVA", "İş Bankası", "Yapı Kredi", 
        "Ziraat Bankası", "VakıfBank", "Halkbank", "QNB", 
        "DenizBank", "TEB", "Enpara", "Papara", "Diğer"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background1.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Banka Seçin")
                            .font(.subheadline)
                            .foregroundColor(theme.labelSecondary)
                        
                        Picker("Banka", selection: $selectedBank) {
                            ForEach(popularBanks, id: \.self) { bank in
                                Text(bank).tag(bank)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.background2)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IBAN Numarası")
                            .font(.subheadline)
                            .foregroundColor(theme.labelSecondary)
                        
                        TextField("TR...", text: $ibanString)
                            .padding()
                            .background(theme.background2)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.brandPrimary.opacity(0.3), lineWidth: 1))
                            .keyboardType(.asciiCapable)
                            .autocorrectionDisabled()
                            .onChange(of: ibanString) { oldValue, newValue in
                                // Basit bir formatlama veya otomatik TR ekleme yapılabilir
                                if !newValue.hasPrefix("TR") && newValue.count >= 2 {
                                    // Sadece rakam girildiyse başına TR ekle
                                }
                            }
                    }
                    .padding(.horizontal)
                    
                    if selectedBank == "Diğer" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Banka Adı")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                            
                            TextField("Banka adını girin", text: $bankName)
                                .padding()
                                .background(theme.background2)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    Button {
                        saveIBAN()
                    } label: {
                        Text("Kaydet")
                            .font(.headline)
                            .foregroundColor(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theme.brandPrimary)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .disabled(ibanString.count < 10)
                }
                .padding(.top)
            }
            .navigationTitle("IBAN Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveIBAN() {
        guard var profile = authManager.currentUserProfile else { return }
        
        let finalBankName = selectedBank == "Diğer" ? bankName : selectedBank
        let newIBAN = IBANModel(id: UUID().uuidString, bankName: finalBankName, ibanString: ibanString)
        
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
