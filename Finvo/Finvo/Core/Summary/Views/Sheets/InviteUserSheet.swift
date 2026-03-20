import SwiftUI
import Combine

struct InviteUserSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    let walletId: String
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [UserModel] = []
    @State private var searchCompleted = false
    @State private var searchTask: Task<Void, Never>? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Arama Kutusu
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(theme.labelSecondary)
                    
                    TextField("Kullanıcı adı veya e-posta", text: $searchText)
                        .foregroundStyle(theme.labelPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: searchText) { _, newValue in
                            performSearch(query: newValue)
                        }
                    
                    if isSearching {
                        ProgressView()
                            .tint(theme.brandPrimary)
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(theme.separator, lineWidth: 1))
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                // Sonuç Alanı
                if searchCompleted {
                    if !searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(searchResults, id: \.uid) { user in
                                    userCard(user)
                                }
                            }
                        }
                    } else if !searchText.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 40))
                                .foregroundStyle(theme.labelSecondary)
                            Text("Kullanıcı bulunamadı")
                                .font(.subheadline)
                                .foregroundStyle(theme.labelSecondary)
                        }
                        .padding(.top, 32)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Davet Gönder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                            .foregroundStyle(theme.labelPrimary)
                    }
                }
            }
        }
    }
    
    private func userCard(_ user: UserModel) -> some View {
        HStack(spacing: 16) {
            if let photoUrl = user.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().scaleEffect(0.5)
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.brandPrimary.opacity(0.8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(user.firstName) \(user.lastName)")
                    .font(.headline)
                    .foregroundStyle(theme.labelPrimary)
                Text("@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(theme.labelSecondary)
            }
            
            Spacer()
            
            Button {
                let feedback = UIImpactFeedbackGenerator(style: .medium)
                feedback.prepare()
                
                // Cüzdana yeni üyeyi Ekle (Viewer yetkisinde)
                walletManager.addMember(to: walletId, memberId: user.username, role: .viewer)
                
                feedback.impactOccurred()
                dismiss()
            } label: {
                Text("Davet Et")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.brandPrimary)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.separator, lineWidth: 1))
        .padding(.horizontal, 24)
    }
    
    // Anlık Sorgu (Debounce with Task) Mock
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            isSearching = false
            searchCompleted = false
            searchResults = []
            return
        }
        
        isSearching = true
        searchCompleted = false
        searchResults = []
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            
            do {
                let results = try await FirestoreService.shared.searchUsers(query: trimmedQuery)
                
                await MainActor.run {
                    let currentUsername = self.authManager.currentUserProfile?.username ?? ""
                    let walletMembers = self.walletManager.wallets.first(where: { $0.id == self.walletId })?.members ?? []
                    
                    self.searchResults = results.filter { $0.username != currentUsername && !walletMembers.contains($0.username) }
                    self.isSearching = false
                    self.searchCompleted = true
                }
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    self.searchCompleted = true
                }
            }
        }
    }
}
