import SwiftUI

struct NotificationsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var walletManager: WalletManager
    
    var body: some View {
        List {
            if notificationManager.notifications.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(theme.separatorSecondary)
                    Text("Henüz yeni bildiriminiz yok.")
                        .font(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .listRowBackground(Color.clear)
            } else {
                ForEach(notificationManager.notifications) { notification in
                    notificationRow(notification)
                }
            }
        }
        .listStyle(.plain)
        .background(theme.background1.ignoresSafeArea())
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @ViewBuilder
    private func notificationRow(_ notification: NotificationModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.title)
                    .foregroundStyle(theme.brandPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("@\(notification.senderUsername)")
                        .font(.headline)
                        .foregroundStyle(theme.labelPrimary)
                    
                    Text("**\(notification.walletName)** cüzdanı için işlem yetkisi (üye) istiyor.")
                        .font(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    let feedback = UIImpactFeedbackGenerator(style: .medium)
                    feedback.impactOccurred()
                    notificationManager.rejectRequest(notification)
                } label: {
                    Text("Reddet")
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.expense)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(theme.expense.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button {
                    let feedback = UIImpactFeedbackGenerator(style: .medium)
                    feedback.impactOccurred()
                    notificationManager.approveRequest(notification)
                } label: {
                    Text("Onayla")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(theme.income)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
    }
}
