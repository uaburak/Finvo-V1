import SwiftUI

struct FamilyView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        FamilyDashboardView()
    }
}

#Preview {
    FamilyView()
        .environmentObject(AuthenticationManager.shared)
        .environment(\.theme, DefaultTheme())
}
