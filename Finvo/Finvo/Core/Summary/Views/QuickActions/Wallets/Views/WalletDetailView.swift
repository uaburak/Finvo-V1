import SwiftUI

struct WalletDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    let walletId: String
    
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showInviteSheet = false
    @State private var showRoleRequestSentAlert = false
    @State private var showLeaveWalletAlert = false
    
    @State private var memberProfiles: [String: UserModel] = [:]
    
    // Güvenlik için Manager'dan güncel state okunuyor
    var wallet: WalletModel? {
        walletManager.wallets.first(where: { $0.id == walletId })
    }
    
    var body: some View {
        Group {
            if let activeWallet = wallet {
                List {
                    // Cüzdan Bilgileri
                    Section {
                        HStack {
                            Text("Cüzdan Adı")
                                .foregroundStyle(theme.labelSecondary)
                            Spacer()
                            Text(activeWallet.name)
                                .foregroundStyle(theme.labelPrimary)
                        }
                        
                        HStack {
                            Text("Tür")
                                .foregroundStyle(theme.labelSecondary)
                            Spacer()
                            Text(activeWallet.type.title)
                                .foregroundStyle(theme.labelPrimary)
                        }
                        
                        HStack {
                            Text("Kullanım Amacı")
                                .foregroundStyle(theme.labelSecondary)
                            Spacer()
                            Text(activeWallet.context.title)
                                .foregroundStyle(theme.labelPrimary)
                        }
                    }
                    .listRowBackground(theme.cardBackground)
                    
                    // Paylaşımlı Cüzdan İse Üyeleri Göster
                    if activeWallet.type == .shared {
                        let currentUsername = authManager.currentUserProfile?.username ?? ""
                        
                        Section {
                            // Davetli / Mevcut Üyeleri Listeleme
                            ForEach(Array(activeWallet.permissions.keys), id: \.self) { memberId in
                                HStack {
                                    if let profileUrl = memberProfiles[memberId]?.photoUrl, let url = URL(string: profileUrl) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            ProgressView().scaleEffect(0.5)
                                        }
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(theme.separatorSecondary)
                                    }
                                    
                                    VStack(alignment: .leading) {
                                        Text(memberId == currentUsername ? "Sen (\(memberId))" : memberId)
                                            .font(.body)
                                            .foregroundStyle(theme.labelPrimary)
                                        
                                        if let roleString = activeWallet.permissions[memberId],
                                           let role = WalletRole(rawValue: roleString) {
                                            Text(role == .owner ? "Kurucu" : (role == .admin ? "Admin" : (role == .member ? "Üye" : (role == .viewer ? "Görüntüleyici" : "Davet Edildi"))))
                                                .font(.caption)
                                                .italic(role == .pending)
                                                .foregroundStyle(role == .pending ? theme.brandPrimary : theme.labelSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if memberId == currentUsername && activeWallet.ownerId != currentUsername {
                                        if activeWallet.permissions[currentUsername] != WalletRole.member.rawValue {
                                            Menu {
                                                Button("Yetki İste") {
                                        if let walletId = activeWallet.id {
                                            notificationManager.sendRoleRequest(walletId: walletId, walletName: activeWallet.name, ownerUsername: activeWallet.ownerId)
                                        }
                                                    let generator = UINotificationFeedbackGenerator()
                                                    generator.notificationOccurred(.success)
                                                    showRoleRequestSentAlert = true
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis")
                                                    .font(.body.weight(.bold))
                                                    .foregroundStyle(theme.labelSecondary)
                                                    .frame(width: 44, height: 44)
                                                    .contentShape(Rectangle())
                                            }
                                        }
                                    }
                                    
                                    if activeWallet.ownerId == currentUsername && memberId != currentUsername {
                                        Menu {
                                            Button("Admin") {
                                                walletManager.addMember(to: walletId, memberId: memberId, role: .admin)
                                            }
                                            Button("Üye") {
                                                walletManager.addMember(to: walletId, memberId: memberId, role: .member)
                                            }
                                            Button("İzleyici") {
                                                walletManager.addMember(to: walletId, memberId: memberId, role: .viewer)
                                            }
                                            Divider()
                                            Button("Üyeyi Çıkar", role: .destructive) {
                                                walletManager.removeMember(from: walletId, memberId: memberId)
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .font(.body.weight(.bold))
                                                .foregroundStyle(theme.labelSecondary)
                                                .frame(width: 44, height: 44)
                                                .contentShape(Rectangle())
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            
                            // Yeni Üye Ekle Butonu
                            if activeWallet.ownerId == currentUsername || activeWallet.permissions[currentUsername] == WalletRole.admin.rawValue {
                                Button {
                                    showInviteSheet = true
                                } label: {
                                    Label("Kullanıcı Davet Et", systemImage: "person.badge.plus")
                                        .foregroundStyle(theme.brandPrimary)
                                }
                            }
                        } footer: {
                            Text("Yalnızca Kurucu (Owner) olan kişiler yeni üyeleri yönetebilir veya cüzdanı silebilir.")
                        }
                        .listRowBackground(theme.cardBackground)
                    }
                    
                    // Tehlikeli Alan - SADECE KURUCU GÖREBİLİR
                    if activeWallet.ownerId == authManager.currentUserProfile?.username {
                        Section {
                            if walletManager.wallets.count > 1 {
                                Button(role: .destructive) {
                                    showDeleteAlert = true
                                } label: {
                                    Text("Cüzdanı Sil")
                                        .frame(maxWidth: .infinity)
                                }
                            } else {
                                Text("Tek kalan cüzdan silinemez.")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.labelSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .listRowBackground(theme.cardBackground)
                    } else {
                        // Eğer kurucu değilsek, cüzdandan ayrıl butonunu en altta gösteriyoruz
                        Section {
                            Button(role: .destructive) {
                                showLeaveWalletAlert = true
                            } label: {
                                Text("Cüzdandan Ayrıl")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .listRowBackground(theme.cardBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(theme.background1.ignoresSafeArea())
                .navigationTitle(activeWallet.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if activeWallet.ownerId == authManager.currentUserProfile?.username {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Düzenle") {
                                showEditSheet = true
                            }
                        }
                    }
                }
                .sheet(isPresented: $showEditSheet) {
                    EditWalletSheet(wallet: activeWallet)
                        .presentationDetents([.medium, .height(560)])
                        .presentationBackground(.clear)
                        .presentationDragIndicator(.hidden)
                }
                .sheet(isPresented: $showInviteSheet) {
                    InviteUserSheet(walletId: walletId)
                        .presentationDetents([.medium, .height(450)])
                        .presentationBackground(.clear)
                        .presentationDragIndicator(.hidden)
                }
                .alert("Cüzdanı Sil", isPresented: $showDeleteAlert) {
                    Button("İptal", role: .cancel) { }
                    Button("Sil", role: .destructive) {
                        walletManager.deleteWallet(id: walletId)
                        dismiss()
                    }
                } message: {
                    Text("Bu cüzdanı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.")
                }
                .alert("İstek Gönderildi", isPresented: $showRoleRequestSentAlert) {
                    Button("Tamam", role: .cancel) { }
                } message: {
                    Text("Cüzdan kurucusuna yetki isteğiniz başarıyla iletildi.")
                }
                .alert("Cüzdandan Ayrıl", isPresented: $showLeaveWalletAlert) {
                    Button("İptal", role: .cancel) { }
                    Button("Ayrıl", role: .destructive) {
                        let currentUsername = authManager.currentUserProfile?.username ?? ""
                        walletManager.removeMember(from: walletId, memberId: currentUsername)
                        dismiss()
                    }
                } message: {
                    Text("Bu cüzdandan ayrılmak istediğinize emin misiniz? Bir daha erişemeyeceksiniz.")
                }
                .onAppear {
                    loadMemberProfiles(activeWallet)
                }
                .onChange(of: activeWallet.permissions.keys) {
                    loadMemberProfiles(activeWallet)
                }
            } else {
                Text("Cüzdan bulunamadı.")
            }
        }
    }
    
    private func loadMemberProfiles(_ activeWallet: WalletModel) {
        for memberId in activeWallet.permissions.keys {
            if memberProfiles[memberId] == nil {
                Task {
                    if let profile = try? await FirestoreService.shared.getUserProfileByUsername(memberId) {
                        await MainActor.run {
                            memberProfiles[memberId] = profile
                        }
                    }
                }
            }
        }
    }
}
