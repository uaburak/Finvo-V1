import SwiftUI

struct AnalysisCollaboratorCard: View {
    @Environment(\.theme) var theme
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    let contributions: [MemberContribution]
    let allTransactions: [TransactionModel] // Needed for detail view routing

    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Aile Üyeleri")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(theme.labelPrimary)
                Spacer()
                Image(systemName: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(theme.labelSecondary)
            }
            
            if contributions.isEmpty {
                Text("Bu dönemde kişi verisi bulunamadı.")
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                let maxAmount = contributions.map { $0.amount }.max() ?? 1.0
                
                VStack(spacing: 16) {
                    ForEach(contributions.prefix(5)) { member in
                        NavigationLink(destination: MemberTransactionsDetailView(
                            username: member.username,
                            transactions: allTransactions.filter { $0.createdBy == member.username }
                                .sorted(by: { $0.amount > $1.amount }),
                            allTransactions: allTransactions
                        )) {
                            HStack(spacing: 12) {
                                // Avatar
                                MemberAvatarView(username: member.username, size: 40)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(member.username)
                                            .font(.subheadline.bold())
                                            .foregroundColor(theme.labelPrimary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text("\(appCurrency.symbol)\(member.amount.formatted(.number.precision(.fractionLength(0))))")
                                            .font(.subheadline.bold())
                                            .foregroundColor(theme.labelPrimary)

                                    }
                                    
                                    // Progress Bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(height: 6)
                                            
                                            let ratio = maxAmount > 0 ? (member.amount / maxAmount) : 0
                                            Capsule()
                                                .fill(theme.brandPrimary)
                                                .frame(width: geo.size.width * CGFloat(ratio), height: 6)
                                        }
                                    }
                                    .frame(height: 6)
                                }
                            }
                            .contentShape(Rectangle()) // Makes the whole row tappable
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
}

struct MemberAvatarView: View {
    @Environment(\.theme) var theme
    let username: String
    let size: CGFloat
    
    @State private var photoUrl: String? = nil
    
    var body: some View {
        ZStack {
            if let photoUrl = photoUrl, let _ = URL(string: photoUrl) {
                CachedProfileImage(
                    urlString: photoUrl,
                    width: size,
                    height: size,
                    fallbackIconSize: size * 0.4
                )
            } else {
                Circle()
                    .fill(theme.brandPrimary.opacity(0.15))
                    .frame(width: size, height: size)
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(theme.brandPrimary)
            }
        }
        .task {
            self.photoUrl = await MemberProfileCacheManager.shared.getPhotoUrl(username: username)
        }
    }
}

class MemberProfileCacheManager {
    static let shared = MemberProfileCacheManager()
    private var photoUrlCache: [String: String?] = [:]
    
    func getPhotoUrl(username: String) async -> String? {
        if let cached = photoUrlCache[username] {
            return cached
        }
        
        let url = (try? await FirestoreService.shared.getUserProfileByUsername(username))?.photoUrl
        photoUrlCache[username] = url
        return url
    }
}
