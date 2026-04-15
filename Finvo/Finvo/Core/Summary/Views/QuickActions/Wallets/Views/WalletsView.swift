import SwiftUI

struct WalletsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var showCreateSheet = false
    
    var body: some View {
        List {
            ForEach(walletManager.wallets) { wallet in
                NavigationLink(destination: WalletDetailView(walletId: wallet.id ?? "")) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.brandPrimary)
                                .frame(width: 36, height: 36)
                            Image(systemName: wallet.type == .shared ? "person.3.fill" : "wallet.pass.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(wallet.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(theme.labelPrimary)
                            
                            HStack(spacing: 6) {
                                Text(wallet.type.title)
                                Text("•")
                                Text(wallet.context.title)
                            }
                            .font(.caption)
                            .foregroundStyle(theme.labelSecondary)
                        }
                        
                        Spacer()
                        
                        if walletManager.activeWallet?.id == wallet.id {
                            Text("AKTİF")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(theme.cardBackground)
                                .foregroundStyle(theme.brandPrimary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(theme.cardBackground)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(theme.background1.ignoresSafeArea())
        .navigationTitle("Cüzdanlarım")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.labelPrimary)
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateWalletSheet()
                .presentationDetents([.medium, .height(500)])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
    }
}
