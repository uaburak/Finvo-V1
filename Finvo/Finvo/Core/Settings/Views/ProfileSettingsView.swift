import SwiftUI
import PhotosUI

struct ProfileSettingsView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var showSuccessAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background1.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // MARK: - Profil Resmi Alanı (Kullanıcı tarafından beğenilen kısım)
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                ZStack {
                                    if let url = authManager.currentUserProfile?.photoUrl, let photoURL = URL(string: url) {
                                        AsyncImage(url: photoURL) { image in
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            ProgressView()
                                        }
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(theme.background2)
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 60))
                                                    .foregroundColor(theme.labelSecondary)
                                            )
                                    }
                                    
                                    Circle()
                                        .fill(theme.brandPrimary)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.black)
                                        )
                                        .offset(x: 40, y: 40)
                                }
                            }
                            .onChange(of: selectedItem) { oldValue, newValue in
                                uploadProfileImage()
                            }
                            
                            VStack(spacing: 4) {
                                Text(authManager.currentUserProfile?.fullName ?? "")
                                    .font(.title3.weight(.bold))
                                    .foregroundColor(theme.labelPrimary)
                                
                                Text(authManager.currentUserProfile?.email ?? "")
                                    .font(.subheadline)
                                    .foregroundColor(theme.labelSecondary)
                            }
                        }
                        .padding(.top, 20)
                        
                        // MARK: - Standart Finvo Form Bloğu
                        VStack(spacing: 0) {
                            // Ad Satırı
                            formInputRow(icon: "person.fill", title: "Ad", text: $firstName)
                            
                            Divider().padding(.leading, 56)
                            
                            // Soyad Satırı
                            formInputRow(icon: "person.crop.rectangle.fill", title: "Soyad", text: $lastName)
                            
                            Divider().padding(.leading, 56)
                            
                            // IBAN Navigasyon Satırı (Mevcut form yapısıyla uyumlu)
                            NavigationLink {
                                IBANListView()
                                    .environmentObject(authManager)
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(theme.brandPrimary)
                                        .frame(width: 24)
                                    
                                    Text("IBAN Bilgilerim")
                                        .foregroundColor(theme.labelPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(theme.separatorSecondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                            }
                        }
                        .background(theme.background2)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        
                        // MARK: - Kaydet Butonu
                        Button {
                            updateProfile()
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(theme.onBrandPrimary)
                                } else {
                                    Text("Değişiklikleri Kaydet")
                                        .font(.headline)
                                        .foregroundColor(theme.onBrandPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(theme.brandPrimary)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .disabled(isSaving)
                        
                        // MARK: - Güvenli Çıkış
                        Button {
                            logout()
                        } label: {
                            Text("Hesaptan Çıkış Yap")
                                .foregroundColor(.red)
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Profil Ayarları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let profile = authManager.currentUserProfile {
                    firstName = profile.firstName
                    lastName = profile.lastName
                }
            }
            .alert("Başarılı", isPresented: $showSuccessAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text("Profil bilgileriniz güncellendi.")
            }
        }
    }
    
    // Uygulamanın standart input satırı yapısı
    @ViewBuilder
    private func formInputRow(icon: String, title: String, text: Binding<String>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(theme.brandPrimary)
                .frame(width: 24)
            
            TextField(title, text: text)
                .foregroundColor(theme.labelPrimary)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func updateProfile() {
        guard var profile = authManager.currentUserProfile else { return }
        isSaving = true
        
        profile.firstName = firstName
        profile.lastName = lastName
        
        Task {
            do {
                try await FirestoreService.shared.saveUserProfile(profile)
                await authManager.checkUserProfile()
                isSaving = false
                showSuccessAlert = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } catch {
                print("Profil güncelleme hatası: \(error)")
                isSaving = false
            }
        }
    }
    
    private func uploadProfileImage() {
        // Firebase Storage entegrasyonu (Planlandığı gibi hazır bekliyor)
    }
    
    private func logout() {
        do {
            try authManager.signOut()
            dismiss()
        } catch {
            print("Çıkış yapılamadı")
        }
    }
}
