import SwiftUI

struct FamilyView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Group {
            if let user = authManager.currentUserProfile, user.isPro {
                FamilyDashboardView()
            } else {
                ProSubscriptionPaywallView()
            }
        }
    }
}

#Preview {
    FamilyView()
        .environmentObject(AuthenticationManager.shared)
        .environment(\.theme, DefaultTheme())
}
