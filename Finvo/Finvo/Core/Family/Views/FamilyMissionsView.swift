import SwiftUI

struct FamilyMissionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @StateObject private var viewModel = FamilyMissionsViewModel()
    @State private var newMissionTitle: String = ""
    @State private var newMissionReward: String = ""
    @State private var assignedTo: String = ""
    
    var activeMissions: [MissionModel] {
        viewModel.missions.filter { !$0.isApproved }
    }
    
    var completedMissions: [MissionModel] {
        viewModel.missions.filter { $0.isApproved }
    }
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Eklenti Alanı
                quickAddSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        if viewModel.missions.isEmpty {
                            emptyStateView
                        } else {
                            // Aktif & Onay Bekleyen
                            if !activeMissions.isEmpty {
                                missionsListSection(title: "Devam Eden Görevler", items: activeMissions)
                            }
                            
                            // Tamamlandı
                            if !completedMissions.isEmpty {
                                missionsListSection(title: "Ödülü Verildi", items: completedMissions, isMuted: true)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Görev Panosu")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let walletId = walletManager.activeWallet?.id {
                viewModel.fetchMissions(for: walletId)
            }
        }
    }
    
    // MARK: - Sections
    
    private var quickAddSection: some View {
        VStack(spacing: 12) {
            TextField("Görev nedir? (Örn: Arabayı Yıkama)", text: $newMissionTitle)
                .font(.body)
                .padding()
                .background(theme.background2.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            HStack(spacing: 12) {
                TextField("Kime? (Opsiyonel)", text: $assignedTo)
                    .font(.body)
                    .padding()
                    .background(theme.background2.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                TextField("Ödül (₺)", text: $newMissionReward)
                    .keyboardType(.decimalPad)
                    .font(.body)
                    .frame(width: 100)
                    .padding()
                    .background(theme.background2.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button {
                guard !newMissionTitle.trimmingCharacters(in: .whitespaces).isEmpty,
                      let walletId = walletManager.activeWallet?.id,
                      let username = authManager.currentUserProfile?.username else { return }
                
                let amount = Double(newMissionReward.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                let assignee = assignedTo.trimmingCharacters(in: .whitespaces).isEmpty ? nil : assignedTo
                
                viewModel.addMission(title: newMissionTitle, reward: amount, assignedTo: assignee, walletId: walletId, createdBy: username)
                
                newMissionTitle = ""
                newMissionReward = ""
                assignedTo = ""
                
            } label: {
                Text("Görev Atama")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.black)
                    .background(theme.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(newMissionTitle.isEmpty)
            .opacity(newMissionTitle.isEmpty ? 0.6 : 1.0)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 0))
    }
    
    @ViewBuilder
    private func missionsListSection(title: String, items: [MissionModel], isMuted: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isMuted ? theme.labelSecondary : theme.labelPrimary)
                .padding(.horizontal)
            
            ForEach(items) { item in
                HStack(spacing: 16) {
                    // Tamamlandı Checkbox (Sadece görevi yapan işaretler)
                    Button {
                         viewModel.toggleCompletion(for: item)
                    } label: {
                        Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundStyle(item.isCompleted ? .green : theme.separator)
                    }
                    .disabled(isMuted) // Zaten onaylanmışsa değiştirilemez
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isMuted ? theme.labelSecondary : theme.labelPrimary)
                            .strikethrough(isMuted)
                        
                        HStack {
                            if let assignee = item.assignedTo {
                                Text("\(assignee) yapacak")
                            } else {
                                Text("Genel Görev")
                            }
                            Text(" • Ödül: ₺\(item.rewardAmount.formatted(.number.precision(.fractionLength(0))))")
                                .foregroundStyle(theme.brandPrimary)
                        }
                        .font(.caption)
                        .foregroundStyle(theme.labelSecondary)
                    }
                    
                    Spacer()
                    
                    if item.isCompleted && !item.isApproved {
                        // Onay Bekliyor statüsü (Görev verene görünür normalde)
                        Button {
                            viewModel.approveMission(for: item)
                        } label: {
                            Text("ÖDE")
                                .font(.caption2.bold())
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(theme.brandPrimary)
                                .clipShape(Capsule())
                        }
                    } else if item.isApproved {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        // Silme Butonu
                        Button {
                            viewModel.deleteMission(item)
                        } label: {
                            Image(systemName: "trash")
                                .tint(.red.opacity(0.8))
                        }
                    }
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
                // Onay beklerken kart biraz vurgulanır
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(item.isCompleted && !item.isApproved ? theme.brandPrimary.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
                .padding(.horizontal)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 60)
            
            Image(systemName: "star.fill")
                .font(.system(size: 60))
                .foregroundStyle(theme.brandPrimary.opacity(0.5))
            
            Text("Görev Panosu Boş")
                .font(.title3.bold())
                .foregroundStyle(theme.labelPrimary)
            
            Text("Aile üyelerine veya kendinize ödüllü görevler tanımlayarak motivasyonu artırın.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.labelSecondary)
                .padding(.horizontal, 32)
        }
    }
}

#Preview {
    NavigationView {
        FamilyMissionsView()
            .environment(\.theme, DefaultTheme())
            .environmentObject(WalletManager())
            .environmentObject(AuthenticationManager.shared)
    }
}
