import SwiftUI
import Combine

// Mock User Search Model
struct MockUserResult: Identifiable {
    let id = UUID().uuidString
    let username: String
    let fullName: String
    let systemImage: String = "person.circle.fill"
}

struct InviteUserSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    
    let walletId: String
    
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResult: MockUserResult? = nil
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
                    if let user = searchResult {
                        userCard(user)
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
    
    private func userCard(_ user: MockUserResult) -> some View {
        HStack(spacing: 16) {
            Image(systemName: user.systemImage)
                .font(.system(size: 40))
                .foregroundStyle(theme.brandPrimary.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.fullName)
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
                
                // Cüzdana MOCK olarak yeni üyeyi Ekle (Viewer yetkisinde)
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
            searchResult = nil
            return
        }
        
        isSearching = true
        searchCompleted = false
        searchResult = nil
        
        searchTask = Task {
            // Arama simülasyonu için yarım saniye gecikme
            try? await Task.sleep(nanoseconds: 700_000_000)
            
            guard !Task.isCancelled else { return }
            
            // Eğer "burak" veya "test" yazarsa sahte bir kullanıcı dön, yoksa nil dön
            if trimmedQuery.lowercased() == "burak" || trimmedQuery.lowercased() == "test" {
                searchResult = MockUserResult(username: trimmedQuery.lowercased(), fullName: "Test Kullanıcısı")
            } else {
                searchResult = nil
            }
            
            isSearching = false
            searchCompleted = true
        }
    }
}
