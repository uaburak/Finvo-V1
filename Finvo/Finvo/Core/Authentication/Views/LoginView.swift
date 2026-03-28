import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(\.theme) var theme
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Head Bölümü (Logo & Slogan)
                VStack(spacing: 16) {
                    Image(systemName: "wallet.pass.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.brandPrimary, theme.brandPrimary.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: theme.brandPrimary.opacity(0.3), radius: 10, y: 5)
                    
                    Text("Finvo")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(theme.labelPrimary)
                    
                    Text("Kişisel & Paylaşımlı Cüzdan Yönetimi")
                        .font(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
                
                Spacer()
                
                // Butonlar Bölümü
                VStack(spacing: 16) {
                    if let error = errorMessage ?? authManager.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Native Apple Giriş Butonu
                    SignInWithAppleButton(.signIn) { request in
                        authManager.currentNonce = authManager.randomNonceString()
                        request.requestedScopes = [.fullName, .email]
                        if let nonce = authManager.currentNonce {
                            request.nonce = authManager.sha256(nonce)
                        }
                    } onCompletion: { result in
                        handleAppleLogin(result: result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
                    
                    // Custom Google Giriş Butonu
                    Button {
                        handleGoogleLogin()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                                .foregroundStyle(theme.labelPrimary)
                            
                            Text("Google ile Giriş Yap")
                                .font(.headline)
                                .foregroundStyle(theme.labelPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(theme.separator, lineWidth: 1))
                    }
                    .padding(.horizontal, 24)
                }
                .disabled(isLoading)
                .overlay {
                    if isLoading {
                        ProgressView()
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                
                Spacer()
                    .frame(height: 40)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleAppleLogin(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = authManager.currentNonce else { return }
                guard let appleIDToken = appleIDCredential.identityToken else { return }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else { return }
                
                isLoading = true
                errorMessage = nil
                
                Task {
                    do {
                        try await authManager.signInWithApple(
                            idToken: idTokenString,
                            nonce: nonce,
                            fullName: appleIDCredential.fullName
                        )
                        isLoading = false
                    } catch {
                        isLoading = false
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            if (error as NSError).code != 1001 { // 1001 = Kullanıcı iptal etti uyarısını görmezden gel
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func handleGoogleLogin() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signInWithGoogle()
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
