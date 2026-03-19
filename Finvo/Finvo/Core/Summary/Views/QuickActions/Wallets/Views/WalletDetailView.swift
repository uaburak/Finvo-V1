import SwiftUI

struct WalletDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    
    let walletId: String
    
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var showInviteSheet = false
    
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
                        Section {
                            // Mock Üye Listeleme (Permissions tablosuna göre)
                            ForEach(Array(activeWallet.permissions.keys), id: \.self) { memberId in
                                HStack {
                                    Image(systemName: "person.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(theme.separatorSecondary)
                                    
                                    VStack(alignment: .leading) {
                                        Text(memberId == "current_user_id" ? "Sen" : memberId)
                                            .font(.body)
                                            .foregroundStyle(theme.labelPrimary)
                                        
                                        if let roleString = activeWallet.permissions[memberId],
                                           let role = WalletRole(rawValue: roleString) {
                                            Text(role == .owner ? "Kurucu" : (role == .member ? "Üye" : "Görüntüleyici"))
                                                .font(.caption)
                                                .foregroundStyle(theme.labelSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if activeWallet.ownerId == "current_user_id" && memberId != "current_user_id" {
                                        Menu {
                                            Button("Rolü Değiştir (Üye)") { /* Action */ }
                                            Button("Rolü Değiştir (İzleyici)") { /* Action */ }
                                            Divider()
                                            Button("Üyeyi Çıkar", role: .destructive) { /* Action */ }
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
                            if activeWallet.ownerId == "current_user_id" || activeWallet.permissions["current_user_id"] == WalletRole.member.rawValue {
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
                    
                    // Tehlikeli Alan
                    Section {
                        if walletManager.wallets.count > 1 {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Text("Cüzdanı Sil")
                            }
                        } else {
                            Text("Tek kalan cüzdan silinemez.")
                                .font(.subheadline)
                                .foregroundStyle(theme.labelSecondary)
                        }
                    }
                    .listRowBackground(theme.cardBackground)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(theme.background1.ignoresSafeArea())
                .navigationTitle(activeWallet.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Düzenle") {
                            showEditSheet = true
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
            } else {
                Text("Cüzdan bulunamadı.")
            }
        }
    }
}
