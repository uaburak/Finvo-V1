import SwiftUI

struct FamilyMissionsView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency

    @StateObject private var viewModel = FamilyMissionsViewModel()
    @State private var newMissionTitle: String = ""
    @State private var newMissionReward: String = ""
    @State private var selectedAssignee: String? = nil
    @FocusState private var isTitleFocused: Bool

    private let inputHeight: CGFloat = 46
    // Sticky panel yüksekliği: Üst boşluk(8) + İçerik(yaklaşık 160) + Gap(12) = 180
    private let stickyHeight: CGFloat = 200

    var body: some View {
        ZStack(alignment: .top) {
            theme.background1.ignoresSafeArea()

            // MARK: - List
            Group {
                if viewModel.isLoading {
                    ProgressView().frame(maxHeight: .infinity)
                } else if viewModel.missions.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    List {
                        // Devam Eden
                        if !viewModel.pendingMissions.isEmpty {
                            sectionHeader(title: "Devam Eden Görevler", count: viewModel.pendingMissions.count)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            ForEach(Array(viewModel.pendingMissions.enumerated()), id: \.element.id) { index, item in
                                missionRow(item: item, section: .pending, isFirst: index == 0)
                            }
                        }

                        // Tamamlanan
                        if !viewModel.completedMissions.isEmpty {
                            sectionHeader(title: "Tamamlanan Görevler", count: viewModel.completedMissions.count)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            ForEach(Array(viewModel.completedMissions.enumerated()), id: \.element.id) { index, item in
                                missionRow(item: item, section: .completed, isFirst: index == 0)
                            }
                        }

                        // Ödül Verildi
                        if !viewModel.paidMissions.isEmpty {
                            sectionHeader(title: "Ödül Verildi", count: viewModel.paidMissions.count)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            ForEach(Array(viewModel.paidMissions.enumerated()), id: \.element.id) { index, item in
                                missionRow(item: item, section: .paid, isFirst: index == 0)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .safeAreaInset(edge: .top) {
                        Color.clear.frame(height: stickyHeight)
                    }
                    .safeAreaPadding(.bottom, 40)
                }
            }

            // MARK: - Sticky (Input Panel + Stats Banner)
            VStack(spacing: 12) {
                // Input Panel
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        TextField("Görev nedir?", text: $newMissionTitle)
                            .font(.body)
                            .focused($isTitleFocused)
                            .padding(.horizontal, 14)
                            .frame(height: inputHeight)
                            .glassEffect(in: .capsule)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                    HStack(spacing: 6) {
                        // Üye Seçici (Kişi Seçme Sorunu Çözümü)
                        Menu {
                            Button { selectedAssignee = nil } label: { Label("Herkes", systemImage: selectedAssignee == nil ? "checkmark" : "person.3") }
                            
                            if let members = walletManager.activeWallet?.members {
                                Divider()
                                ForEach(members, id: \.self) { username in
                                    Button { selectedAssignee = username } label: {
                                        if selectedAssignee == username { Label(username, systemImage: "checkmark") } else { Text(username) }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(selectedAssignee == nil ? theme.labelSecondary : theme.brandPrimary)
                                Text(selectedAssignee ?? "Herkes")
                                    .font(.subheadline)
                                    .foregroundStyle(selectedAssignee == nil ? theme.labelSecondary : theme.labelPrimary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(theme.labelSecondary)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: inputHeight)
                            .glassEffect(in: .capsule)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 6) {
                            Text(appCurrency.symbol)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(theme.labelSecondary)
                            TextField("Ödül", text: $newMissionReward)
                                .keyboardType(.decimalPad)
                                .font(.body)
                                .frame(width: 52)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: inputHeight)
                        .glassEffect(in: .capsule)

                        Button { addMission() } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundStyle(newMissionTitle.trimmingCharacters(in: .whitespaces).isEmpty ? theme.labelSecondary.opacity(0.5) : theme.brandPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(newMissionTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
                }
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal, 20)

                // Stats Banner
                HStack(spacing: 0) {
                    statCell(value: "\(viewModel.missions.count)", label: "Toplam")
                    Divider().frame(height: 28)
                    statCell(value: "\(viewModel.pendingMissions.count)", label: "Aktif")
                    Divider().frame(height: 28)
                    statCell(value: "\(viewModel.completedMissions.count)", label: "Biten")
                    Divider().frame(height: 28)
                    statCell(value: "\(appCurrency.symbol)\(viewModel.totalRewardGiven.formatted(.number.precision(.fractionLength(0))))", label: "Ödül")
                }
                .padding(.vertical, 10)
                .glassEffect(in: .capsule)
                .padding(.horizontal, 20)
                
                Spacer().frame(height: 0) // Padding kontrolü için
            }
            .padding(.top, 8)
        }
        .navigationTitle("Görev Panosu")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let walletId = walletManager.activeWallet?.id { viewModel.fetchMissions(for: walletId) }
        }
        .onDisappear { viewModel.stopListening() }
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).foregroundStyle(theme.labelPrimary).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(theme.labelSecondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(theme.labelSecondary)
            Spacer()
            Text("\(count) görev").font(.footnote).foregroundStyle(theme.labelSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    enum MissionSection { case pending, completed, paid }

    @ViewBuilder
    private func missionRow(item: MissionModel, section: MissionSection, isFirst: Bool) -> some View {
        HStack(spacing: 14) {
            // Checkbox (ZStack + onTapGesture ile SwiftUI'ın otomatik 'disabled' opaklık düşürmesini engelliyoruz)
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(section == .paid ? Color.green : (item.isCompleted ? theme.brandPrimary : theme.background2))
                    .frame(width: 26, height: 26)
                if item.isCompleted || section == .paid {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(theme.onBrandPrimary)
                } else {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(theme.separator, lineWidth: 1.5).frame(width: 26, height: 26)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if section == .pending || section == .completed {
                    let currentUsername = authManager.currentUserProfile?.username ?? "Bilinmiyor"
                    viewModel.toggleCompletion(for: item, by: currentUsername)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.labelPrimary)
                    .strikethrough(section == .paid, color: theme.labelSecondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    // Görev Atanan / Tamamlayan Bilgisi (Herkes seçeneği mantığı çözüldü)
                    let displayUser = item.isCompleted ? (item.completedBy ?? "Bilinmiyor") : (item.assignedTo ?? "Herkes")
                    
                    Text(displayUser)
                        .font(.caption.bold())
                        .foregroundStyle(item.assignedTo == nil && !item.isCompleted ? theme.labelSecondary : theme.brandPrimary)

                    if item.rewardAmount > 0 {
                        Text("•").font(.caption).foregroundStyle(theme.labelSecondary)
                        Text("\(appCurrency.symbol)\(item.rewardAmount.formatted(.number.precision(.fractionLength(0)))) ödül")
                            .font(.caption.bold())
                            .foregroundStyle(section == .paid ? .green : theme.brandPrimary)
                    }
                }
                
                Text("Oluşturan: \(item.createdBy)")
                    .font(.caption2)
                    .foregroundStyle(theme.labelSecondary)
            }
            Spacer()
            trailingAction(for: item, section: section)
        }
        .padding(.leading)
        .listRowInsets(EdgeInsets(top: 14, leading: 6, bottom: 14, trailing: 20))
        .listRowSeparator(.visible)
        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
        .listRowBackground(section == .completed ? AnyView(HStack(spacing: 0) { Rectangle().fill(theme.brandPrimary).frame(width: 3); Color.clear }) : AnyView(Color.clear))
    }

    @ViewBuilder
    private func trailingAction(for item: MissionModel, section: MissionSection) -> some View {
        switch section {
        case .pending:
            Button { viewModel.deleteMission(item) } label: { Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(.red.opacity(0.7)) }.buttonStyle(.plain)
        case .completed:
            VStack(spacing: 6) {
                Button { viewModel.approveMission(for: item) } label: {
                    Text("ÖDE")
                        .font(.caption.bold())
                        .foregroundStyle(theme.onBrandPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(theme.brandPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                if item.rewardAmount > 0 {
                    Text("\(appCurrency.symbol)\(item.rewardAmount.formatted(.number.precision(.fractionLength(0))))")
                        .font(.caption2).foregroundStyle(theme.labelSecondary)
                }
            }
        case .paid:
            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.title3)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "star.fill").font(.system(size: 56)).foregroundStyle(theme.brandPrimary.opacity(0.5))
            Text("Görev Panosu Boş").font(.title3.bold()).foregroundStyle(theme.labelPrimary)
            Text("Aile üyelerine ödüllü görevler tanımlayarak motivasyonu artırın.").font(.subheadline).multilineTextAlignment(.center).foregroundStyle(theme.labelSecondary).padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private func addMission() {
        let title = newMissionTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, let walletId = walletManager.activeWallet?.id, let username = authManager.currentUserProfile?.username else { return }
        let reward = Double(newMissionReward.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        viewModel.addMission(title: title, reward: reward, assignedTo: selectedAssignee, walletId: walletId, createdBy: username)
        newMissionTitle = ""; newMissionReward = ""; selectedAssignee = nil; isTitleFocused = false
    }
}
