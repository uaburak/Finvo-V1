import SwiftUI

struct TransactionDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var transactionManager: TransactionManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency

    let transaction: TransactionModel

    @State private var showEditSheet = false
    
    // Yetki kontrolü
    private var canEdit: Bool {
        let username = authManager.currentUserProfile?.username ?? ""
        let wallet = walletManager.activeWallet
        let roleRaw = wallet?.permissions[username] ?? WalletRole.member.rawValue
        let role = WalletRole(rawValue: roleRaw) ?? .member
        
        let isOwner = wallet?.ownerId == username
        let isAdmin = role == .admin
        let isCreator = transaction.createdBy == username
        
        return isOwner || isAdmin || (role == .member && isCreator)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // MARK: - Tutar Kartı
                amountCard

                // MARK: - Detay Kartı
                detailCard

                // MARK: - Borç Kartı
                if transaction.isDebt || transaction.isInstallment {
                    debtCard
                }

                // MARK: - Tekrarlayan Kartı
                if transaction.isRecurring {
                    recurringCard
                }

                // MARK: - Not
                if let note = transaction.note, !note.isEmpty {
                    noteCard(note)
                }

                // MARK: - Sil Butonu
                if canEdit {
                    deleteButton
                }
            }
            .padding()
        }
        .safeAreaPadding(.bottom, 20)
        .navigationTitle("İşlem Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if canEdit {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showEditSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(theme.labelPrimary)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            AddTransactionsView(transactionToEdit: transaction)
                .environmentObject(walletManager)
                .environmentObject(authManager)
                .environmentObject(transactionManager)
        }
    }

    // MARK: - Tutar Kartı
    private var amountCard: some View {
        VStack(spacing: 12) {
            // İkon
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(transaction.resolvedColor())
                    .frame(width: 56, height: 56)

                Image(systemName: transaction.resolvedIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .center, spacing: 4) {
                Text(transaction.resolvedSubCategoryName ?? transaction.resolvedMainCategoryName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(theme.labelPrimary)
                
                if transaction.resolvedSubCategoryName != nil {
                    Text(transaction.resolvedMainCategoryName)
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                }
            }

            // Tutar
            Text("\(transaction.isIncome ? "+" : "-")\(transaction.currency?.symbol ?? appCurrency.symbol)\(transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(transaction.resolvedColor())
            
            let txCurrency = transaction.currency ?? .tryCurrency
            if txCurrency.code != appCurrency.code {
                let converted = ExchangeRateManager.shared.convert(amount: transaction.amount, from: txCurrency, to: appCurrency)
                Text("≈ \(appCurrency.symbol)\(converted.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(theme.labelSecondary)
                    
                if !transaction.isIncome, let initialVal = transaction.appCurrencyAmountAtCreation, initialVal > 0 {
                    let diff = converted - initialVal
                    let pct = (diff / initialVal) * 100
                    if abs(pct) > 0.01 {
                        let isPositive = pct > 0
                        let sign = isPositive ? "+" : ""
                        let pctStr = "\(sign)%\(pct.formatted(.number.precision(.fractionLength(2))))"
                        let diffStr = "\(sign)\(appCurrency.symbol)\(abs(diff).formatted(.number.grouping(.automatic).precision(.fractionLength(0))))"
                        
                        Text("\(pctStr) (\(diffStr))")
                            .font(.subheadline.bold())
                            .foregroundColor(isPositive ? theme.income : theme.expense)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }

    // MARK: - Detay Kartı
    private var detailCard: some View {
        VStack(spacing: 0) {
            detailRow(icon: "calendar", title: "Tarih",
                      value: transaction.date.formatted(date: .long, time: .shortened))

            Divider().padding(.horizontal)

            detailRow(icon: "person.fill", title: "Ekleyen",
                      value: "@\(transaction.createdBy)")

            Divider().padding(.horizontal)

            detailRow(icon: "clock", title: "Oluşturulma",
                      value: transaction.createdAt.formatted(date: .abbreviated, time: .shortened))

            Divider().padding(.horizontal)

            detailRow(icon: transaction.isIncome ? "arrow.down.left" : "arrow.up.right",
                      title: "Tür",
                      value: transaction.type.localizedTitle)
        }
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }

    // MARK: - Borç Kartı
    private var debtCard: some View {
        VStack(spacing: 0) {
            if let contact = transaction.debtContact {
                detailRow(icon: "person.2.fill", title: "Kişi", value: contact)
                Divider().padding(.horizontal)
            }

            if let total = transaction.totalInstallments, let paid = transaction.paidInstallments {
                detailRow(icon: "number", title: "Taksit",
                          value: "\(paid)/\(total) \("ödendi".localized)")
                Divider().padding(.horizontal)

                // İlerleme çubuğu
                HStack {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.cardBackground).frame(height: 6)
                            Capsule().fill(theme.brandPrimary)
                                .frame(width: max(0, min(CGFloat(paid) / CGFloat(total) * geo.size.width, geo.size.width)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().padding(.horizontal)
            }

            if let dueDay = transaction.dueDay {
                detailRow(icon: "calendar.badge.clock", title: "Vade Günü",
                          value: "Her ayın %@. günü".localized(with: String(dueDay)))
                Divider().padding(.horizontal)
            }

            detailRow(icon: transaction.isPaid ? "checkmark.seal.fill" : "hourglass",
                      title: "Durum",
                      value: transaction.isPaid ? "\("Ödendi".localized) ✓" : "Devam Ediyor".localized)
        }
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }

    // MARK: - Tekrarlayan Kartı
    private var recurringCard: some View {
        VStack(spacing: 0) {
            if let interval = transaction.recurrenceInterval {
                detailRow(icon: "repeat", title: "Tekrar Sıklığı", value: interval.title)
                Divider().padding(.horizontal)
            }

            if let endDate = transaction.recurrenceEndDate {
                detailRow(icon: "calendar.badge.minus", title: "Bitiş Tarihi",
                          value: endDate.formatted(date: .long, time: .omitted))
            } else {
                detailRow(icon: "infinity", title: "Bitiş", value: "Süresiz".localized)
            }
        }
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }

    // MARK: - Not Kartı
    private func noteCard(_ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Not", systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(theme.labelSecondary)

            Text(note)
                .font(.body)
                .foregroundColor(theme.labelPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }

    // MARK: - Sil Butonu
    private var deleteButton: some View {
        Button(role: .destructive) {
            if let id = transaction.id {
                FirestoreService.shared.deleteTransaction(
                    walletId: transaction.walletId, transactionId: id)
                dismiss()
            }
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("İşlemi Sil")
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(Color.red)
        }
        .buttonStyle(.glass)
    }

    // MARK: - Detay Satırı Helper
    private func detailRow(icon: String, title: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(transaction.resolvedColor())
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundColor(theme.labelSecondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(theme.labelPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        TransactionDetailView(transaction: TransactionModel(
            walletId: "preview",
            type: .expense,
            amount: 1250.50,
            mainCategoryName: "Market",
            subCategoryName: "Gıda",
            categoryIcon: "cart.fill",
            date: Date(),
            note: "Haftalık alışveriş",
            createdBy: "burak",
            createdAt: Date()
        ))
        .environment(\.theme, DefaultTheme())
    }
}
