import SwiftUI
import Combine
import FirebaseFirestore

/// Aile içi yapılan bir ödeşme kaydı (ör. @ali, @ayse'ye 300 ₺ verdi)
struct SettlementModel: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var fromUser: String
    var toUser: String
    var amount: Double
    var currency: String
    var monthKey: String     // "202610" — hangi ayın hesaplaşması
    var createdBy: String
    var createdAt: Date = Date()
}

/// Kimin kime ne kadar borçlu olduğunu hesaplar.
/// Kural: Ayın ortak giderleri aktif üyeler arasında eşit bölünür; fazla ödeyen alacaklı, az ödeyen borçludur.
/// Kaydedilen ödeşmeler bakiyelere yansır.
struct SettleUpCalculator {
    struct Balance: Identifiable {
        let username: String
        let paid: Double
        let balance: Double   // + alacaklı, - borçlu
        var id: String { username }
    }

    struct Transfer: Identifiable {
        let from: String
        let to: String
        let amount: Double
        var id: String { "\(from)->\(to)" }
    }

    let total: Double
    let share: Double
    let balances: [Balance]
    let transfers: [Transfer]

    init(transactions: [TransactionModel], members: [String], settlements: [SettlementModel],
         month: Date, currency: CurrencyType) {
        let calendar = Calendar.current
        var paid: [String: Double] = Dictionary(uniqueKeysWithValues: members.map { ($0, 0) })
        let savingsNames: Set<String> = ["Birikim İşlemleri", "Savings Transactions", "Sparkonten-Transaktionen"]

        for tx in transactions where tx.type == .expense && !tx.isDebt && !savingsNames.contains(tx.mainCategoryName)
            && calendar.isDate(tx.date, equalTo: month, toGranularity: .month) && paid[tx.createdBy] != nil {
            paid[tx.createdBy, default: 0] += ExchangeRateManager.shared.convert(amount: tx.amount, from: tx.currency ?? .tryCurrency, to: currency)
        }

        let totalPaid = paid.values.reduce(0, +)
        let perPerson = members.isEmpty ? 0 : totalPaid / Double(members.count)
        total = totalPaid
        share = perPerson

        var balanceMap = paid.mapValues { $0 - perPerson }
        for settlement in settlements {
            let value = ExchangeRateManager.shared.convert(amount: settlement.amount,
                                                           from: CurrencyType(rawValue: settlement.currency) ?? .tryCurrency,
                                                           to: currency)
            // Borçlu ödeme yapınca borcu azalır, alacaklının alacağı azalır
            if balanceMap[settlement.fromUser] != nil { balanceMap[settlement.fromUser, default: 0] += value }
            if balanceMap[settlement.toUser] != nil { balanceMap[settlement.toUser, default: 0] -= value }
        }

        let memberBalances = members.map { Balance(username: $0, paid: paid[$0] ?? 0, balance: balanceMap[$0] ?? 0) }
            .sorted { $0.balance > $1.balance }
        balances = memberBalances

        // En az transferle dengeleme: en çok borçlu en çok alacaklıya öder
        var creditors = memberBalances.filter { $0.balance > 0.5 }.map { ($0.username, $0.balance) }
        var debtors = memberBalances.filter { $0.balance < -0.5 }.map { ($0.username, -$0.balance) }
        var result: [Transfer] = []
        var c = 0, d = 0
        while c < creditors.count && d < debtors.count {
            let amount = min(creditors[c].1, debtors[d].1)
            if amount > 0.5 {
                result.append(Transfer(from: debtors[d].0, to: creditors[c].0, amount: amount))
            }
            creditors[c].1 -= amount
            debtors[d].1 -= amount
            if creditors[c].1 <= 0.5 { c += 1 }
            if debtors[d].1 <= 0.5 { d += 1 }
        }
        transfers = result
    }
}

@MainActor
final class FamilySettleUpViewModel: ObservableObject {
    @Published var settlements: [SettlementModel] = []
    private var listener: ListenerRegistration?
    private var listeningKey: String?

    func listen(walletId: String, monthKey: String) {
        let key = "\(walletId)_\(monthKey)"
        guard key != listeningKey else { return }
        listener?.remove()
        listeningKey = key
        settlements = []
        listener = Firestore.firestore()
            .collection("wallets").document(walletId).collection("settlements")
            .whereField("monthKey", isEqualTo: monthKey)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, self.listeningKey == key else { return }
                if let error { print("Settlements listen error: \(error)"); return }
                self.settlements = (snapshot?.documents.compactMap { try? $0.data(as: SettlementModel.self) } ?? [])
                    .sorted { $0.createdAt > $1.createdAt }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        listeningKey = nil
    }

    func record(_ transfer: SettleUpCalculator.Transfer, walletId: String, monthKey: String, currency: CurrencyType, by username: String) {
        let settlement = SettlementModel(fromUser: transfer.from, toUser: transfer.to, amount: transfer.amount.rounded(),
                                         currency: currency.rawValue, monthKey: monthKey, createdBy: username)
        do {
            try Firestore.firestore().collection("wallets").document(walletId).collection("settlements").document()
                .setData(from: settlement)
        } catch {
            print("Settlement save error: \(error)")
        }
    }

    func delete(_ settlement: SettlementModel, walletId: String) {
        guard let id = settlement.id else { return }
        Firestore.firestore().collection("wallets").document(walletId).collection("settlements").document(id).delete()
    }
}

struct FamilySettleUpView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    @StateObject private var viewModel = FamilySettleUpViewModel()

    @State private var month: Date = Date()
    @State private var transferToConfirm: SettleUpCalculator.Transfer?

    private var currentUsername: String { authManager.currentUserProfile?.username ?? "" }

    private var activeMembers: [String] {
        guard let wallet = walletManager.activeWallet else { return [] }
        return wallet.members.filter { wallet.permissions[$0] != WalletRole.pending.rawValue }
    }

    private var monthKey: String {
        let c = Calendar.current.dateComponents([.year, .month], from: month)
        return String(format: "%04d%02d", c.year ?? 0, c.month ?? 0)
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private var calculator: SettleUpCalculator {
        SettleUpCalculator(transactions: transactionManager.transactions, members: activeMembers,
                           settlements: viewModel.settlements, month: month, currency: appCurrency)
    }

    private func money(_ value: Double) -> String {
        "\(appCurrency.symbol)\(abs(value).formatted(.number.grouping(.automatic).precision(.fractionLength(0))))"
    }

    var body: some View {
        let calc = calculator
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                monthSelector
                summaryCard(calc)
                balancesSection(calc)
                transfersSection(calc)
                if !viewModel.settlements.isEmpty { historySection }
            }
            .padding(.vertical)
        }
        .background(theme.background1.ignoresSafeArea())
        .navigationTitle("Hesaplaşma")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startListening() }
        .onChange(of: monthKey) { _, _ in startListening() }
        .onDisappear { viewModel.stop() }
        .alert("Ödeme Yapıldı mı?", isPresented: Binding(
            get: { transferToConfirm != nil },
            set: { if !$0 { transferToConfirm = nil } }
        )) {
            Button(L10n("Vazgeç"), role: .cancel) { }
            Button("Ödendi") {
                if let transfer = transferToConfirm, let walletId = walletManager.activeWallet?.id {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    viewModel.record(transfer, walletId: walletId, monthKey: monthKey, currency: appCurrency, by: currentUsername)
                }
            }
        } message: {
            if let transfer = transferToConfirm {
                Text(String(format: L10n("@%@, @%@ kişisine %@ ödedi olarak kaydedilecek."), transfer.from, transfer.to, money(transfer.amount)))
            }
        }
    }

    private func startListening() {
        guard let walletId = walletManager.activeWallet?.id else { return }
        viewModel.listen(walletId: walletId, monthKey: monthKey)
    }

    // MARK: - Ay Seçici
    private var monthSelector: some View {
        let appLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
        return HStack {
            Button {
                month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.left").font(.headline).frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .clipShape(Circle())

            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: appLang))).capitalized)
                .font(.headline)
                .foregroundStyle(theme.labelPrimary)
            Spacer()

            Button {
                month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
            } label: {
                Image(systemName: "chevron.right").font(.headline).frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .clipShape(Circle())
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.4 : 1)
        }
        .foregroundStyle(theme.labelPrimary)
        .padding(.horizontal)
    }

    // MARK: - Özet
    private func summaryCard(_ calc: SettleUpCalculator) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ortak Harcama")
                    .font(.caption)
                    .foregroundStyle(theme.labelSecondary)
                Text(money(calc.total))
                    .font(.title2.bold())
                    .foregroundStyle(theme.labelPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Kişi Başı")
                    .font(.caption)
                    .foregroundStyle(theme.labelSecondary)
                Text(money(calc.share))
                    .font(.title2.bold())
                    .foregroundStyle(theme.brandPrimary)
            }
        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }

    // MARK: - Üye Bakiyeleri
    private func balancesSection(_ calc: SettleUpCalculator) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Üye Bakiyeleri")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.labelPrimary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(calc.balances.enumerated()), id: \.element.id) { index, balance in
                    HStack(spacing: 12) {
                        MemberAvatarView(username: balance.username, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(balance.username)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.labelPrimary)
                            Text(String(format: L10n("%@ ödedi"), money(balance.paid)))
                                .font(.system(size: 12))
                                .foregroundStyle(theme.labelSecondary)
                        }
                        Spacer()
                        if abs(balance.balance) < 0.5 {
                            Text("Dengede")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(theme.labelSecondary)
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text((balance.balance > 0 ? "+" : "-") + money(balance.balance))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(balance.balance > 0 ? theme.income : theme.expense)
                                Text(balance.balance > 0 ? "Alacaklı" : "Borçlu")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.labelSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < calc.balances.count - 1 {
                        Divider().padding(.leading, 64).padding(.trailing, 16)
                    }
                }
            }
            .padding(.vertical, 4)
            .glassEffect(in: .rect(cornerRadius: 24))
            .padding(.horizontal)
        }
    }

    // MARK: - Önerilen Ödemeler
    private func transfersSection(_ calc: SettleUpCalculator) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Önerilen Ödemeler")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.labelPrimary)
                .padding(.horizontal)

            if calc.transfers.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(theme.brandPrimary)
                    Text(calc.total > 0 ? "Herkes dengede, ödeşilecek bir şey yok." : "Bu ay henüz ortak harcama yok.")
                        .font(.subheadline)
                        .foregroundStyle(theme.labelSecondary)
                    Spacer()
                }
                .padding(20)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(calc.transfers.enumerated()), id: \.element.id) { index, transfer in
                        HStack(spacing: 10) {
                            MemberAvatarView(username: transfer.from, size: 32)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.labelSecondary)
                            MemberAvatarView(username: transfer.to, size: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(transfer.from) → @\(transfer.to)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.labelPrimary)
                                    .lineLimit(1)
                                Text(money(transfer.amount))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(theme.expense)
                            }
                            Spacer(minLength: 4)
                            if canRecord(transfer) {
                                Button {
                                    transferToConfirm = transfer
                                } label: {
                                    Text("Ödendi")
                                        .font(.caption.bold())
                                        .foregroundStyle(theme.onBrandPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(theme.brandPrimary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < calc.transfers.count - 1 {
                            Divider().padding(.leading, 16).padding(.trailing, 16)
                        }
                    }
                }
                .padding(.vertical, 4)
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal)
            }
        }
    }

    /// Ödemeyi borçlu, alacaklı veya cüzdan yöneticisi işaretleyebilir
    private func canRecord(_ transfer: SettleUpCalculator.Transfer) -> Bool {
        transfer.from == currentUsername || transfer.to == currentUsername || walletManager.canManageActiveWallet
    }

    // MARK: - Geçmiş
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Yapılan Ödemeler")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.labelPrimary)
                .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(viewModel.settlements.enumerated()), id: \.element.id) { index, settlement in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.income)
                                .frame(width: 36, height: 36)
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("@\(settlement.fromUser) → @\(settlement.toUser)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.labelPrimary)
                            Text(settlement.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundStyle(theme.labelSecondary)
                        }
                        Spacer()
                        Text("\(CurrencyType(rawValue: settlement.currency)?.symbol ?? appCurrency.symbol)\(settlement.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(theme.income)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contextMenu {
                        if settlement.createdBy == currentUsername || walletManager.canManageActiveWallet,
                           let walletId = walletManager.activeWallet?.id {
                            Button(role: .destructive) {
                                viewModel.delete(settlement, walletId: walletId)
                            } label: {
                                Label(L10n("Geri Al"), systemImage: "arrow.uturn.backward")
                            }
                        }
                    }

                    if index < viewModel.settlements.count - 1 {
                        Divider().padding(.leading, 64).padding(.trailing, 16)
                    }
                }
            }
            .padding(.vertical, 4)
            .glassEffect(in: .rect(cornerRadius: 24))
            .padding(.horizontal)
        }
    }
}
