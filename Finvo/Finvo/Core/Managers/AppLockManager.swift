import Foundation
import LocalAuthentication
import SwiftUI
import Combine

/// Face ID / Touch ID / cihaz şifresi ile uygulama kilidi.
/// Kilit açıkken uygulama arka plana gidince kilitlenir; uygulama değiştiricideki önizlemede de
/// finansal veriler görünmez.
@MainActor
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    @AppStorage("appLockEnabled") var isEnabled: Bool = false {
        willSet { objectWillChange.send() }
    }
    @Published private(set) var isLocked: Bool = false
    @Published private(set) var isAuthenticating = false

    private init() {
        isLocked = isEnabled
    }

    /// Cihazın sunduğu biyometri türü (ayar etiketleri için)
    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometryTitle: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Cihaz Şifresi".localized
        }
    }

    var biometryIcon: String {
        switch biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock.fill"
        }
    }

    /// Cihazda şifre/biyometri tanımlı mı? Tanımlı değilse kilit açılamayacağı için özellik sunulmaz.
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lockIfNeeded() {
        if isEnabled { isLocked = true }
    }

    /// Kilidi açmayı dener. Biyometri başarısız olursa cihaz şifresine düşer.
    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        if await authenticate(reason: "Finvo'yu açmak için kimliğinizi doğrulayın.".localized) {
            isLocked = false
        }
    }

    /// Ayarlardan kilidi açarken/kapatırken kimlik doğrulaması ister.
    func setEnabled(_ enabled: Bool) async -> Bool {
        let reason = enabled
            ? "Uygulama kilidini açmak için kimliğinizi doğrulayın.".localized
            : "Uygulama kilidini kapatmak için kimliğinizi doğrulayın.".localized
        guard await authenticate(reason: reason) else { return false }
        isEnabled = enabled
        isLocked = false
        return true
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Vazgeç".localized
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Cihazdan şifre kaldırıldıysa kullanıcıyı uygulamanın dışında bırakmayalım
            if isLocked { isLocked = false }
            return false
        }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}

/// Kilitliyken uygulamanın üzerini kapatan ekran
struct AppLockView: View {
    @Environment(\.theme) var theme
    @ObservedObject var lockManager = AppLockManager.shared

    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(theme.brandPrimary)
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(theme.onBrandPrimary)
                }

                VStack(spacing: 8) {
                    Text("Finvo Kilitli")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(theme.labelPrimary)
                    Text("Devam etmek için kimliğinizi doğrulayın.")
                        .font(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    Task { await lockManager.unlock() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: lockManager.biometryIcon)
                        Text("Kilidi Aç")
                    }
                    .font(.headline)
                    .foregroundStyle(theme.onBrandPrimary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glassProminent)
                .clipShape(Capsule())
                .tint(theme.brandPrimary)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .disabled(lockManager.isAuthenticating)
            }
        }
        .task {
            await lockManager.unlock()
        }
    }
}
