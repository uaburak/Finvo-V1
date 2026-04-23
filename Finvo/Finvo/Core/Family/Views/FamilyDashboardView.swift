import SwiftUI

struct FamilyDashboardView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager

    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    @StateObject private var viewModel = FamilyDashboardViewModel()
    @State private var isAnimating = false

    var isSharedWalletActive: Bool {
        walletManager.activeWallet?.type == .shared
    }

    // MARK: - Bu ayın üye bazlı harcamaları (Bonus)
    private var thisMonthMemberSpending: [(username: String, amount: Double)] {
        let cal = Calendar.current
        let now = Date()
        let txs = transactionManager.transactions.filter {
            cal.isDate($0.date, equalTo: now, toGranularity: .month) &&
            $0.type == .expense && !$0.isDebt
        }
        var dict: [String: Double] = [:]
        for tx in txs {
            let converted = ExchangeRateManager.shared.convert(
                amount: tx.amount, from: tx.currency ?? .tryCurrency, to: appCurrency
            )
            dict[tx.createdBy, default: 0] += converted
        }
        return dict.map { ($0.key, $0.value) }.sorted { $0.amount > $1.amount }
    }

    private var thisMonthTotalSpend: Double {
        thisMonthMemberSpending.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background1.ignoresSafeArea()
                Circle()
                    .fill(theme.brandPrimary.opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: isAnimating ? 100 : -50, y: isAnimating ? -100 : -200)
                Circle()
                    .fill(Color.orange.opacity(0.05))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: isAnimating ? -100 : 50, y: isAnimating ? 150 : 50)

                if isSharedWalletActive { dashboardHub } else { personalWalletWarning }
            }
            .navigationTitle("Aile Merkezi")
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
                guard isSharedWalletActive else { return }
                viewModel.calculateWholesomeDebts(from: transactionManager.transactions, targetCurrency: appCurrency)
                if let members = walletManager.activeWallet?.members {
                    viewModel.fetchMemberProfiles(usernames: members)
                }
                if let walletId = walletManager.activeWallet?.id {
                    viewModel.startCountListeners(walletId: walletId)
                }
            }
            .onDisappear { viewModel.stopListeners() }
            .onChange(of: transactionManager.transactions) { _, newTx in
                if isSharedWalletActive { viewModel.calculateWholesomeDebts(from: newTx, targetCurrency: appCurrency) }
            }
        }
    }

    // MARK: - Dashboard Hub
    private var dashboardHub: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                // 1. Birleşik Cüzdan + Bu Ay Kartı
                combinedWalletCard
                
                // 2. Özellikler (Alışveriş & Görevler)
                featuresGrid

                // 3. Aile Hedefleri
                familyGoalsSection

                // 4. Üye Harcama Dağılımı (Bonus)
                if !thisMonthMemberSpending.isEmpty { memberSpendingCard }

                // 5. Aile İçi Durumlar
                if !viewModel.wholesomeSituations.isEmpty { wholesomeSection }

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Birleşik Cüzdan Kartı (1. madde: "Şu anki Cüzdan" + "Bu Ay" tek kart)
    private var combinedWalletCard: some View {
        VStack(spacing: 0) {
            // Üst: Cüzdan adı + Overlapping avatarlar
            HStack(alignment: .center) {
                Text(walletManager.activeWallet?.name ?? "Bilinmiyor")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(theme.labelPrimary)

                Spacer()

                // Profil resimleri — CachedProfileImage direkt (profile.photoUrl zaten elimizde)
                if let members = walletManager.activeWallet?.members, !members.isEmpty {
                    HStack(spacing: -10) {
                        ForEach(Array(members.prefix(4)), id: \.self) { username in
                            MemberAvatarView(username: username, size: 36)
                                .overlay(Circle().stroke(theme.background1, lineWidth: 2))
                        }
                        if members.count > 4 {
                            ZStack {
                                Circle().fill(theme.background2).frame(width: 36, height: 36)
                                    .overlay(Circle().stroke(theme.background1, lineWidth: 2))
                                Text("+\(members.count - 4)")
                                    .font(.caption.bold()).foregroundStyle(theme.labelPrimary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Ayırıcı
            if thisMonthTotalSpend > 0 {
                Divider().padding(.horizontal, 20)

                // Alt: Bu ay harcandı
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bu Ay Harcandı".localized)
                            .font(.caption)
                            .foregroundStyle(theme.labelSecondary)
                        Text("\(appCurrency.symbol)\(thisMonthTotalSpend.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                            .font(.title2.bold())
                            .foregroundStyle(theme.labelPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("%d üye".localized(with: thisMonthMemberSpending.count))
                            .font(.caption)
                            .foregroundStyle(theme.labelSecondary)
                        Text("aktif bu ay".localized)
                            .font(.caption.bold())
                            .foregroundStyle(theme.brandPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }

    // MARK: - Family Goals Section
    private var familyGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ailenizin Hedefleri".localized)
                .font(.title3.weight(.bold)).foregroundStyle(theme.labelPrimary).padding(.horizontal)

            if let savings = walletManager.activeWallet?.savingsAccounts, !savings.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(savings) { saving in
                            NavigationLink {
                                SavingsAccountDetailView(account: saving)
                                    .environmentObject(walletManager)
                                    .environmentObject(authManager)
                                    .environmentObject(transactionManager)
                            } label: {
                                savingsCard(for: saving)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .scrollClipDisabled()
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Henüz bir hedef yok".localized).font(.headline).foregroundStyle(theme.labelPrimary)
                        Text("Ailenizle ortak birikim hedefi belirleyin.".localized).font(.caption).foregroundStyle(theme.labelSecondary)
                    }
                    Spacer()
                    Image(systemName: "target").font(.title).foregroundStyle(theme.brandPrimary.opacity(0.5))
                }
                .padding().glassEffect(in: .rect(cornerRadius: 20)).padding(.horizontal)
            }
        }
    }

    // MARK: - Üye Harcama Dağılımı (Bonus)
    private var memberSpendingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Bu Ay Üye Harcamaları".localized).font(.headline.bold()).foregroundStyle(theme.labelPrimary)
                Spacer()
                Image(systemName: "person.3.fill").font(.caption).foregroundStyle(theme.labelSecondary)
            }
            let maxAmount = thisMonthMemberSpending.map(\.amount).max() ?? 1.0
            VStack(spacing: 14) {
                ForEach(thisMonthMemberSpending.prefix(5), id: \.username) { member in
                    HStack(spacing: 12) {
                        MemberAvatarView(username: member.username, size: 36)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(member.username).font(.subheadline.bold()).foregroundStyle(theme.labelPrimary).lineLimit(1)
                                Spacer()
                                Text("\(appCurrency.symbol)\(member.amount.formatted(.number.precision(.fractionLength(0))))")
                                    .font(.subheadline.bold()).foregroundStyle(theme.labelPrimary)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.gray.opacity(0.15)).frame(height: 5)
                                    let ratio = maxAmount > 0 ? (member.amount / maxAmount) : 0
                                    Capsule().fill(theme.brandPrimary)
                                        .frame(width: geo.size.width * CGFloat(ratio), height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                }
            }
        }
        .padding(16).glassEffect(in: .rect(cornerRadius: 24)).padding(.horizontal)
    }

    // MARK: - Wholesome Section
    private var wholesomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aile İçi Durumlar".localized).font(.title3.weight(.bold)).foregroundStyle(theme.labelPrimary).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.wholesomeSituations) { situation in
                        NavigationLink {
                            WholesomeDetailView(situation: situation)
                        } label: {
                            wholesomeCard(situation: situation)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .scrollClipDisabled()
        }
    }

    private func wholesomeCard(situation: WholesomeSituation) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(theme.brandPrimary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: situation.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(theme.brandPrimary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(theme.labelSecondary.opacity(0.5))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(situation.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.labelPrimary)
                
                Text(situation.message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.labelSecondary)
                    .lineLimit(2)
            }
            
            Spacer(minLength: 0)
            
            // Targets Badge Area
            if !situation.targets.isEmpty {
                HStack(spacing: -8) {
                    ForEach(situation.targets.prefix(3), id: \.self) { username in
                        MemberAvatarView(username: username, size: 24)
                            .overlay(Circle().stroke(theme.background1, lineWidth: 1))
                    }
                    if situation.targets.count > 3 {
                        ZStack {
                            Circle().fill(theme.background2).frame(width: 24, height: 24)
                            Text("+\(situation.targets.count - 3)").font(.system(size: 8, weight: .bold))
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 180, height: 180)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    // MARK: - Features Grid
    private var featuresGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            NavigationLink { FamilyShoppingListView() } label: {
                featureGridCard(icon: "cart.fill", title: "Alışveriş".localized,
                    subtitle: viewModel.pendingShoppingItemsCount == 0 ? "Liste boş".localized : "%d Bekleyen".localized(with: viewModel.pendingShoppingItemsCount),
                    gradient: [Color.orange.opacity(0.8), Color.orange])
            }
            NavigationLink { FamilyMissionsView() } label: {
                featureGridCard(icon: "star.fill", title: "Görevler".localized,
                    subtitle: viewModel.pendingMissionsCount == 0 ? "Görev yok".localized : "%d Aktif".localized(with: viewModel.pendingMissionsCount),
                    gradient: [Color.purple.opacity(0.8), Color.purple])
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Savings Card
    @ViewBuilder
    private func savingsCard(for saving: SavingsAccountModel) -> some View {
        let totalBalance: Double = {
            guard let assets = saving.assets else { return saving.currentAmount }
            return assets.reduce(0.0) { sum, pair in
                guard let type = CurrencyType(rawValue: pair.key) else { return sum }
                return sum + ExchangeRateManager.shared.convert(amount: pair.value, from: type, to: appCurrency)
            }
        }()
        let goalConverted = ExchangeRateManager.shared.convert(
            amount: saving.goalAmount,
            from: CurrencyType(rawValue: saving.goalCurrency ?? "") ?? .tryCurrency,
            to: appCurrency
        )
        let progress = goalConverted > 0 ? (totalBalance / goalConverted) : 0

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                ZStack {
                    Circle().stroke(theme.separatorSecondary, lineWidth: 4).frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                        .stroke(theme.brandPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44).rotationEffect(.degrees(-90))
                    Image(systemName: "target").font(.caption.bold()).foregroundStyle(theme.brandPrimary)
                }
                Spacer()
                Text("\(Int(min(progress * 100, 100)))%")
                    .font(.caption.bold()).foregroundStyle(theme.brandPrimary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(theme.brandPrimary.opacity(0.1)).clipShape(Capsule())
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(saving.name)).font(.headline).foregroundStyle(theme.labelPrimary).lineLimit(1)
                Text("\(appCurrency.symbol)\(totalBalance.formatted(.number.precision(.fractionLength(0)))) / \(appCurrency.symbol)\(goalConverted.formatted(.number.precision(.fractionLength(0))))")
                    .font(.caption).foregroundStyle(theme.labelSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.separatorSecondary.opacity(0.3)).frame(height: 4)
                    Capsule().fill(theme.brandPrimary)
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(16).frame(width: 180).glassEffect(in: .rect(cornerRadius: 24))
    }

    // MARK: - Feature Grid Card
    @ViewBuilder
    private func featureGridCard(icon: String, title: String, subtitle: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                Image(systemName: icon).font(.body.weight(.bold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(theme.labelPrimary)
                Text(subtitle).font(.caption).foregroundStyle(theme.labelSecondary)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    // MARK: - Personal Wallet Warning
    private var personalWalletWarning: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40))
                .foregroundStyle(theme.brandPrimary.opacity(0.8))
            Text("Paylaşımlı Cüzdan Gerekli".localized).font(.headline).foregroundStyle(theme.labelPrimary)
            Text("Aile merkezini kullanabilmek için 'Özet' sayfasından paylaşımlı bir cüzdan seçmeli veya yeni bir paylaşımlı cüzdan oluşturmalısınız.".localized)
                .font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(theme.labelSecondary).padding(.horizontal, 32)
        }
        .padding(.vertical, 32).frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 24)).padding(.horizontal)
    }
}

#Preview {
    FamilyDashboardView()
        .environment(\.theme, DefaultTheme())
        .environmentObject(WalletManager())
        .environmentObject(TransactionManager())
        .environmentObject(AuthenticationManager.shared)
}
