import SwiftUI
import FirebaseAuth

struct CompleteProfileView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var step: Int = 1
    
    // Profile States
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var username: String = ""
    
    // Wallet States
    @State private var walletName: String = ""
    @State private var selectedType: WalletType = .personal
    @State private var selectedContext: WalletContext = .general
    
    @State private var isCheckingUsername = false
    @State private var isUsernameAvailable: Bool? = nil
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    
    // Timer to debounce username API checks
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.background1.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        if step == 1 {
                            // Header Illustration
                            VStack(spacing: 8) {
                                if let urlString = authManager.user?.photoURL?.absoluteString, let url = URL(string: urlString) {
                                AsyncImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    ProgressView()
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                            } else {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundStyle(theme.brandPrimary)
                            }
                            
                            Text("Aramıza Hoş Geldin!")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(theme.labelPrimary)
                            Text("Devam etmeden önce profilini tamamlayalım.")
                                .font(.subheadline)
                                .foregroundStyle(theme.labelSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        
                        // Forms
                        VStack(spacing: 16) {
                            formField(title: "Ad", text: $firstName, placeholder: "Örn: Burak")
                            formField(title: "Soyad", text: $lastName, placeholder: "Örn: Koç")
                            
                            // Username Field with Validation
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Kullanıcı Adı")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.labelSecondary)
                                
                                HStack {
                                    Text("@")
                                        .foregroundStyle(theme.labelSecondary)
                                    
                                    TextField("finvokullanicisi", text: $username)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .onChange(of: username) { _, newValue in
                                            checkUsername(newValue)
                                        }
                                    
                                    if isCheckingUsername {
                                        ProgressView().scaleEffect(0.8)
                                    } else if let available = isUsernameAvailable {
                                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(available ? theme.income : theme.expense)
                                    }
                                }
                                .padding()
                                .background(theme.cardBackground)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(theme.separator, lineWidth: 1))
                                
                                if isUsernameAvailable == false {
                                    Text("Bu kullanıcı adı daha önce alınmış.")
                                        .font(.caption)
                                        .foregroundStyle(theme.expense)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(theme.expense)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Submit Button
                        Button {
                            completeProfile()
                        } label: {
                            Group {
                                if isSaving {
                                    Text("Kaydediliyor...")
                                } else {
                                    Text("Devam Et")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(isFormValid ? theme.brandPrimary : theme.brandPrimary.opacity(0.5))
                            .clipShape(Capsule())
                        }
                        .disabled(!isFormValid || isSaving)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    } else {
                        // WALLET CREATION STEP
                        VStack(spacing: 8) {
                            Image(systemName: "wallet.pass.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(theme.brandPrimary)
                            
                            Text("İlk Cüzdanını Oluştur")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(theme.labelPrimary)
                            Text("Finvo'yu kullanmaya başlamak için bir cüzdana ihtiyacın var.")
                                .font(.subheadline)
                                .foregroundStyle(theme.labelSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        
                        VStack(spacing: 24) {
                            TextField("Cüzdan Adı (Örn: Ana Cüzdan)", text: $walletName)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(theme.cardBackground)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(theme.separator, lineWidth: 1))
                            
                            Picker("Cüzdan Tipi", selection: $selectedType) {
                                ForEach(WalletType.allCases, id: \.self) { type in
                                    Text(type.title).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.large)
                            
                            Picker("Kullanım Amacı", selection: $selectedContext) {
                                ForEach(WalletContext.allCases, id: \.self) { context in
                                    Text(context.title).tag(context)
                                }
                            }
                            .pickerStyle(.segmented)
                            .controlSize(.large)
                        }
                        .padding(.horizontal, 24)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(theme.expense)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            completeWallet()
                        } label: {
                            Group {
                                if isSaving {
                                    Text("Oluşturuluyor...")
                                } else {
                                    Text("Tamamla ve Başla")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(theme.onBrandPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(walletName.isEmpty ? theme.brandPrimary.opacity(0.5) : theme.brandPrimary)
                            .clipShape(Capsule())
                        }
                        .disabled(walletName.isEmpty || isSaving)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Ön doldurma
                if let fullName = authManager.user?.displayName {
                    let parts = fullName.components(separatedBy: " ")
                    if parts.count > 1 {
                        firstName = parts.dropLast().joined(separator: " ")
                        lastName = parts.last ?? ""
                    } else {
                        firstName = fullName
                    }
                }
            }
        }
    }
}
    
    // Reusable TextField
    private func formField(title: LocalizedStringKey, text: Binding<String>, placeholder: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(theme.labelSecondary)

            TextField(placeholder, text: text)
                .padding()
                .background(theme.cardBackground)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.separator, lineWidth: 1))
        }
    }
    
    // Computed Validation
    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        username.count >= 3 &&
        isUsernameAvailable == true
    }
    
    // Debounce Username API Call
    private func checkUsername(_ value: String) {
        searchTask?.cancel()
        
        // Sadece alfasayısal ve alt çizgi
        let cleaned = value.lowercased().filter { "abcdefghijklmnopqrstuvwxyz0123456789_".contains($0) }
        if cleaned != value {
            username = cleaned
        }
        
        isUsernameAvailable = nil
        
        if cleaned.count < 3 {
            isCheckingUsername = false
            return
        }
        
        isCheckingUsername = true
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }
            
            do {
                let taken = try await FirestoreService.shared.isUsernameTaken(cleaned)
                isUsernameAvailable = !taken
                isCheckingUsername = false
            } catch {
                isCheckingUsername = false
            }
        }
    }
    
    // Send to Firebase
    private func completeProfile() {
        guard let firebaseUser = authManager.user else { return }
        isSaving = true
        errorMessage = nil
        
        let newUser = UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            username: username.lowercased(),
            photoUrl: firebaseUser.photoURL?.absoluteString,
            isPro: false
        )
        
        Task {
            do {
                try await FirestoreService.shared.saveUserProfile(newUser)
                
                await MainActor.run {
                    withAnimation {
                        self.isSaving = false
                        self.step = 2
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = "\("Profil kaydedilirken hata oluştu".localized): \(error.localizedDescription)"
                }
            }
        }
    }

    // Send Wallet to Firebase
    private func completeWallet() {
        guard authManager.user != nil else { return }
        isSaving = true
        errorMessage = nil

        Task {
            let initialWallet = WalletModel(
                name: walletName,
                ownerId: self.username,
                type: selectedType,
                context: selectedContext,
                members: [self.username],
                permissions: [self.username: WalletRole.owner.rawValue]
            )

            do {
                try await FirestoreService.shared.createWallet(initialWallet)
                await authManager.checkUserProfile()
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = "\("Cüzdan oluşturulamadı".localized): \(error.localizedDescription)"
                }
            }
        }
    }
}
