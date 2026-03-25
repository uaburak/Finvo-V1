import SwiftUI

struct TransactionDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var authManager: AuthenticationManager

    let transaction: TransactionModel

    // Yetki kontrolü
    private var canEdit: Bool {
        let username = authManager.currentUserProfile?.username ?? ""
        let isOwner = walletManager.activeWallet?.ownerId == username
        let role = walletManager.activeWallet?.permissions[username]
        let isCreator = transaction.createdBy == username
        return isOwner || (role == WalletRole.member.rawValue && isCreator)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // MARK: - Tutar Kartı
                amountCard

                // MARK: - Detay Kartı
                detailCard

                // MARK: - Borç Kartı
                if transaction.isDebt {
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
    }

    // MARK: - Tutar Kartı
    private var amountCard: some View {
        VStack(spacing: 12) {
            // İkon
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(transaction.isIncome ? theme.income : theme.expense)
                    .frame(width: 56, height: 56)

                Image(systemName: transaction.categoryIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Kategori
            Text(transaction.mainCategoryName)
                .font(.headline)
                .foregroundColor(theme.labelPrimary)

            if let sub = transaction.subCategoryName {
                Text(sub)
                    .font(.subheadline)
                    .foregroundColor(theme.labelSecondary)
            }

            // Tutar
            Text("\(transaction.isIncome ? "+" : "-")₺\(transaction.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(transaction.isIncome ? theme.income : theme.expense)
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
                      value: transaction.isIncome ? "Gelir" : "Gider")
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
                          value: "\(paid)/\(total) ödendi")
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
                          value: "Her ayın \(dueDay). günü")
                Divider().padding(.horizontal)
            }

            detailRow(icon: transaction.isPaid ? "checkmark.seal.fill" : "hourglass",
                      title: "Durum",
                      value: transaction.isPaid ? "Ödendi ✓" : "Devam Ediyor")
        }
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }

    // MARK: - Tekrarlayan Kartı
    private var recurringCard: some View {
        VStack(spacing: 0) {
            if let interval = transaction.recurrenceInterval {
                detailRow(icon: "repeat", title: "Tekrar Sıklığı", value: interval.rawValue)
                Divider().padding(.horizontal)
            }

            if let endDate = transaction.recurrenceEndDate {
                detailRow(icon: "calendar.badge.minus", title: "Bitiş Tarihi",
                          value: endDate.formatted(date: .long, time: .omitted))
            } else {
                detailRow(icon: "infinity", title: "Bitiş", value: "Süresiz")
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
            Task {
                if let id = transaction.id {
                    try? await FirestoreService.shared.deleteTransaction(
                        walletId: transaction.walletId, transactionId: id)
                    dismiss()
                }
            }
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("İşlemi Sil")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Detay Satırı Helper
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(theme.brandPrimary)
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
