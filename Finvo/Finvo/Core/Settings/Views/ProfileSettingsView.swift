import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseAuth

// MARK: - Red Glass Theme for Destructive Actions
struct RedGlassTheme: AppTheme {
    let base: any AppTheme
    var brandPrimary: Color { .red }
    var onBrandPrimary: Color { .white }
    var background1: Color { base.background1 }
    var background2: Color { base.background2 }
    var cardBackground: Color { base.cardBackground }
    var labelPrimary: Color { base.labelPrimary }
    var labelSecondary: Color { base.labelSecondary }
    var separator: Color { base.separator }
    var separatorSecondary: Color { base.separatorSecondary }
    var income: Color { base.income }
    var expense: Color { base.expense }
}

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
    @State private var isUploadingPhoto = false
    @State private var photoUploadError: String?
    
    // Hesap silme state
    @State private var showDeleteAccountAlert = false
    @State private var showDeleteConfirmSheet = false
    @State private var deleteConfirmText = ""
    @State private var isDeletingAccount = false
    @State private var deletionError: String? = nil
    @State private var showDeletionError = false
    
    private var hasChanges: Bool {
        guard let profile = authManager.currentUserProfile else { return false }
        return firstName != profile.firstName || lastName != profile.lastName || previewImage != nil
    }
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
                
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Profil Resmi Alanı (Kullanıcı tarafından beğenilen kısım)
                    VStack(spacing: 16) {
                        let preview = previewImage
                        let photoUrl = authManager.currentUserProfile?.photoUrl
                        let uploading = isUploadingPhoto
                        let brandPrimary = theme.brandPrimary
                        let background2 = theme.background2
                        let labelSecondary = theme.labelSecondary
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ProfilePhotoLabelView(
                                previewImage: preview,
                                photoUrl: photoUrl,
                                isUploadingPhoto: uploading,
                                brandPrimary: brandPrimary,
                                background2: background2,
                                labelSecondary: labelSecondary
                            )
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
                    .padding(.bottom, 8)
                    
                    // MARK: - Standart Finvo Form Bloğu (Kullanıcı Adı, Ad, Soyad ve IBAN)
                    formReadOnlyRow(icon: "at", title: "Kullanıcı Adı", value: authManager.currentUserProfile?.username ?? "")
                        .padding(.horizontal)
                    
                    formInputRow(icon: "person.fill", title: "Ad", text: $firstName)
                        .padding(.horizontal)
                    
                    formInputRow(icon: "person.crop.rectangle.fill", title: "Soyad", text: $lastName)
                        .padding(.horizontal)
                    
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
                    .padding(.horizontal)
                    
                    // MARK: - Eylemler (Çıkış Yap ve Hesap Sil)
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        logout()
                    } label: {
                        Text("Hesaptan Çıkış Yap")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                    .environment(\.theme, RedGlassTheme(base: theme))
                    .padding(.horizontal)
                    
                    Button(role: .destructive) {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        showDeleteAccountAlert = true
                    } label: {
                        HStack {
                            if isDeletingAccount {
                                ProgressView().tint(.red)
                                Text("Siliniyor...")
                            } else {
                                Text("Hesabı Kalıcı Olarak Sil")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glass)
                    .disabled(isDeletingAccount)
                    .padding(.horizontal)
                    
                    Text("Bu işlem geri alınamaz. Tüm verileriniz, cüzdan ve işlemleriniz kalıcı olarak silinir.")
                        .font(.caption2)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
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
        .onDisappear {
            saveProfileSilently()
        }
        .onSubmit {
            saveProfileSilently()
        }
        // 1. Onay: Genel uyarı
        .alert("Hesabı Sil", isPresented: $showDeleteAccountAlert) {
            Button("Devam Et", role: .destructive) {
                deleteConfirmText = ""
                showDeleteConfirmSheet = true
            }
            Button("Vazgeç", role: .cancel) { }
        } message: {
            Text("Tüm verileriniz (cüzdan, işlem, profil) kalıcı olarak silinecek. Sahibi olduğunuz paylaşımlı cüzdan ve içerikleri de dahil olmak üzere hiçbir şekilde geri getirilemez.")
        }
        // 2. Onay: Metin doğrulama
        .alert("Emin misiniz?", isPresented: $showDeleteConfirmSheet) {
            TextField("HESABI SİL", text: $deleteConfirmText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
            Button("Kalıcı Olarak Sil", role: .destructive) {
                guard deleteConfirmText == "HESABI SİL" else { return }
                isDeletingAccount = true
                Task {
                    do {
                        try await authManager.deleteAccount(wallets: walletManager.wallets)
                        // Başarılı: Auth listener otomatik olarak kullanıcıyı çıkarır
                    } catch {
                        await MainActor.run {
                            isDeletingAccount = false
                            deletionError = error.localizedDescription
                            showDeletionError = true
                        }
                    }
                }
            }
            .disabled(deleteConfirmText != "HESABI SİL")
            Button("Vazgeç", role: .cancel) { deleteConfirmText = "" }
        } message: {
            Text("Onaylamak için 'HESABI SİL' yazın. Bu işlem geri alınamaz.")
        }
        // Hata alertı
        .alert("Silme Hatası", isPresented: $showDeletionError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(deletionError ?? "Bilinmeyen bir hata oluştu.")
        }
    }
    
// MARK: - Profile Photo Label View (Fix Swift 6 isolation warning)
struct ProfilePhotoLabelView: View {
    let previewImage: UIImage?
    let photoUrl: String?
    let isUploadingPhoto: Bool
    let brandPrimary: Color
    let background2: Color
    let labelSecondary: Color
    
    var body: some View {
        ZStack {
            // Seçilen yeni resim göster, yoksa Firestore'daki URL'yi kullan
            if let preview = previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else if let urlStr = photoUrl {
                CachedProfileImage(
                    urlString: urlStr,
                    width: 120,
                    height: 120,
                    fallbackIconSize: 60
                )
            } else {
                Circle()
                    .fill(background2)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundColor(labelSecondary)
                    )
            }

            // Yükleme veya kamera ikonu
            Circle()
                .fill(brandPrimary)
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
    
    @ViewBuilder
    private func formReadOnlyRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(theme.brandPrimary)
                .frame(width: 24)
            
            Text(value.isEmpty ? title : "@\(value)")
                .foregroundColor(theme.labelSecondary)
            
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundColor(theme.labelSecondary.opacity(0.4))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.03))
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(theme.separator.opacity(0.8), lineWidth: 1)
        )
    }
    
    @MainActor
    private func saveProfileSilently() {
        guard var profile = authManager.currentUserProfile else { return }
        guard firstName != profile.firstName || lastName != profile.lastName else { return }
        
        profile.firstName = firstName
        profile.lastName = lastName
        
        Task {
            do {
                try await FirestoreService.shared.saveUserProfile(profile)
                await authManager.checkUserProfile()
            } catch {
                print("Profil otomatik güncelleme hatası: \(error)")
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
            previewImage = nil
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
        } catch {
            print("Çıkış yapılamadı")
        }
    }
}
