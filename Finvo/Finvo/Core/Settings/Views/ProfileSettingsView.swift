import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseAuth

@MainActor
struct ProfileSettingsView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isSaving = false
    @State private var isUploadingPhoto = false
    @State private var showSuccessAlert = false
    @State private var photoUploadError: String?
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // MARK: - Profil Resmi Alanı (Kullanıcı tarafından beğenilen kısım)
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                profilePhotoLabel
                            }
                            .onChange(of: selectedItem) { _, _ in
                                Task { @MainActor in await uploadProfileImage() }
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
                        VStack(spacing: 16) {
                            // Ad Satırı
                            formInputRow(icon: "person.fill", title: "Ad", text: $firstName)
                            
                            // Soyad Satırı
                            formInputRow(icon: "person.crop.rectangle.fill", title: "Soyad", text: $lastName)
                            
                            // IBAN Navigasyon Satırı
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
                                .background(Color.white.opacity(0.05))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(theme.separator, lineWidth: 1)
                                )
                            }
                        }
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
                                        .foregroundStyle(theme.onBrandPrimary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.glassProminent)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .disabled(isSaving)
                        .opacity(isSaving ? 0.6 : 1.0)
                        
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
    


    // MARK: - Profil Fotoğraf Label'ı (Ayrı @ViewBuilder olarak tanımlandı)
    // Fix: PhotosPicker label closure'ı nonisolated çalışıyor (iOS 26 / Swift 6 strict concurrency).
    // @State ve @Environment property'lere erişmek için closure içeriği buraya taşındı.
    @ViewBuilder @MainActor
    private var profilePhotoLabel: some View {
        ZStack {
            // Seçilen yeni resim göster, yoksa Firestore'daki URL'yi kullan
            if let preview = previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else if let urlStr = authManager.currentUserProfile?.photoUrl {
                CachedProfileImage(
                    urlString: urlStr,
                    width: 120,
                    height: 120,
                    fallbackIconSize: 60
                )
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

            // Yükleme veya kamera ikonu
            Circle()
                .fill(theme.brandPrimary)
                .frame(width: 32, height: 32)
                .overlay(
                    Group {
                        if isUploadingPhoto {
                            ProgressView()
                                .tint(.black)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                        }
                    }
                )
                .offset(x: 40, y: 40)
        }
    }

    // Uygulamanın capsule input satırı yapısı
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
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(theme.separator, lineWidth: 1)
        )
    }
    
    @MainActor private func updateProfile() {
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
    
    @MainActor
    private func uploadProfileImage() async {
        guard let item = selectedItem else { return }
        guard let uid = authManager.user?.uid else { return }

        // PhotosPickerItem'den ham veri al
        guard let data = try? await item.loadTransferable(type: Data.self),
              let originalImage = UIImage(data: data) else { return }

        // ── 1. Resize: En boy oranını koruyarak (aspect ratio) küçült ──────────
        let maxDimension: CGFloat = 300 // Maksimum kenar uzunluğu
        let originalSize = originalImage.size
        
        let ratio = maxDimension / max(originalSize.width, originalSize.height)
        let targetSize = ratio < 1.0 ? CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio) : originalSize
        
        let resized: UIImage = {
            if ratio < 1.0 {
                let renderer = UIGraphicsImageRenderer(size: targetSize)
                return renderer.image { _ in
                    originalImage.draw(in: CGRect(origin: .zero, size: targetSize))
                }
            } else {
                return originalImage
            }
        }()

        // ── 2. Compress: Max 100 KB'a düşene kadar kaliteyi azalt ──────────
        let maxBytes = 50_000 // 50 KB limit
        var quality: CGFloat = 0.85
        var jpegData: Data?
        repeat {
            jpegData = resized.jpegData(compressionQuality: quality)
            quality -= 0.10
        } while (jpegData?.count ?? 0) > maxBytes && quality > 0.05
        guard let finalData = jpegData else { return }

        // Önizleme resmi hemen göster
        previewImage = resized
        isUploadingPhoto = true

        let storageRef = Storage.storage().reference()
            .child("users/\(uid)/profile.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await storageRef.putDataAsync(finalData, metadata: metadata)
            let downloadURL = try await storageRef.downloadURL()
            let urlString = downloadURL.absoluteString

            // Firestore'da photoUrl'i güncelle
            try await FirestoreService.shared.updateUserPhoto(uid: uid, url: urlString)

            // ── Resmi Önbelleğe (Mevcut cihaza) kaydet ──────
            ImageCacheManager.shared.saveImage(image: resized, for: urlString)

            // ── Anında in-memory güncelle → tüm ekranlar hemen yansır ──────
            authManager.currentUserProfile?.photoUrl = urlString

            // Firestore ile senkronu koru
            await authManager.checkUserProfile()

            isUploadingPhoto = false
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            print("Profil resmi yüklenemedi: \(error)")
            isUploadingPhoto = false
            previewImage = nil
            photoUploadError = "Resim yüklenemedi. Lütfen tekrar deneyin."
        }
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
