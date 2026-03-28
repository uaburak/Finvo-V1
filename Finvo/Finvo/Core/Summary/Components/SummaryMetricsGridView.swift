import SwiftUI

struct SummaryMetricsGridView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @ObservedObject var categoryManager = CategoryManager.shared
    
    // Düzenli 2 kolonlu yapı (Esnek)
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        let limit = walletManager.activeWallet?.monthlyLimit ?? 0
        
        let now = Date()
        let calendar = Calendar.current
        
        // Sadece İÇİNDE BULUNDUĞUMUZ AYIN harcamalarını topla (Harcama Limiti için)
        let currentMonthExpenses = transactionManager.transactions.filter { 
            !$0.isDebt && $0.type == .expense &&
            calendar.isDate($0.date, equalTo: now, toGranularity: .month) &&
            calendar.isDate($0.date, equalTo: now, toGranularity: .year)
        }.reduce(0) { $0 + $1.amount }
        
        let limitProgress = limit > 0 ? (currentMonthExpenses / limit) : 0.0
        
        let topCategoryId = transactionManager.topExpenseCategoryId
        let topCategoryName = transactionManager.topExpenseCategoryName
        let resolvedTopCategory = CategoryManager.shared.categories.first(where: { $0.id == topCategoryId }) ?? 
                                  CategoryManager.shared.categories.first(where: { $0.name == topCategoryName })
        
        let upcomingPayments = transactionManager.transactions.compactMap { $0.nextPayment(after: now) }
        let upcomingCount = upcomingPayments.count
        let upcomingTotal = upcomingPayments.reduce(0) { $0 + $1.amount }
        
        let paymentCalendarText: String
        if upcomingCount > 0 {
            paymentCalendarText = "\(upcomingCount) Ödeme (₺\(upcomingTotal.formatted(.number.precision(.fractionLength(0)))))"
        } else {
            paymentCalendarText = "Yaklaşan Yok"
        }

        return LazyVGrid(columns: columns, spacing: 16) {
            // Harcama Limiti
            MetricCardView(title: "Harcama Limiti", amount: "₺\(currentMonthExpenses.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))) / ₺\(limit.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))", iconName: "creditcard.fill", iconColor: theme.expense, progress: limitProgress)
            MetricCardView(title: "En Çok Harcama", 
                           amount: LocalizedStringKey(resolvedTopCategory?.name ?? topCategoryName), 
                           iconName: resolvedTopCategory?.icon ?? "cart.fill", 
                           iconColor: resolvedTopCategory?.uiColor ?? .blue, 
                           progress: 0.0)
            
            NavigationLink(destination: PaymentCalendarDetailView(upcomingPayments: upcomingPayments)) {
                MetricCardView(title: "Ödeme Takvimi", amount: LocalizedStringKey(paymentCalendarText), iconName: "calendar.badge.clock", iconColor: .orange, progress: upcomingCount > 0 ? 1.0 : nil)
            }
            .buttonStyle(.plain)
            
            MetricCardView(title: "Akıllı İpuçları", amount: "Yok", iconName: "lightbulb.fill", iconColor: .yellow, progress: nil)
        }
    }
}

// Genel Metrik Kartı - IncomeExpenseCardView stili ile birebir
struct MetricCardView: View {
    @Environment(\.theme) var theme
    
    let title: LocalizedStringKey
    let amount: LocalizedStringKey
    let iconName: String
    let iconColor: Color
    let progress: Double? // Artık opsiyonel, her kartta bar olmak zorunda değil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                // İkon
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold)) // Boyutu biraz büyütülerek denge sağlandı (14->20)
                    .foregroundColor(iconColor)
                
                Spacer()
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.labelSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            
            // Üstten ortaya itmek için esnek boşluk
            Spacer(minLength: 0)
            
            Text(amount)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(theme.labelPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Ortadan alta itmek için ikinci esnek boşluk
            Spacer(minLength: 0)
            
            // Progress Bar (İlerleme Çubuğu) - Eğer progress gönderildiyse çiz
            if let safeProgress = progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Arkaplan Pisti
                        Capsule()
                            .fill(theme.cardBackground)
                            .frame(height: 3)
                        
                        // Dolan Kısım
                        Capsule()
                            .fill(iconColor)
                            .frame(width: max(0, min(CGFloat(safeProgress) * geometry.size.width, geometry.size.width)), height: 3)
                    }
                }
                .frame(height: 3)
            } else {
                // Progress bar olmayan kartlarda tasarım eşitliği (yükseklik kayması olmaması) için görünmez bir alan:
                Spacer()
                    .frame(height: 3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 150)
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
}

struct SummaryMetricsGridView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryMetricsGridView()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

// MARK: - Navigation Destination (Added here to guarantee inclusion in Xcode target)
struct PaymentCalendarDetailView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    
    let upcomingPayments: [TransactionModel]
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            if upcomingPayments.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 60))
                        .foregroundColor(theme.labelSecondary)
                    
                    Text("Yaklaşan Ödemeniz Bulunmuyor")
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text("Önümüzdeki günlerde planlanmış bir borç veya abonelik ödemeniz görünmüyor.")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Top Header
                        let total = upcomingPayments.reduce(0) { $0 + $1.amount }
                        VStack(spacing: 8) {
                            Text("Yaklaşan Toplam Yükümlülük")
                                .font(.subheadline)
                                .foregroundColor(theme.labelSecondary)
                            Text("₺\(total.formatted(.number.precision(.fractionLength(0))))")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(theme.expense)
                                .contentTransition(.numericText())
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: .rect(cornerRadius: 24))
                        .padding(.horizontal, 20)
                        
                        // Ödemeler Listesi
                        VStack(spacing: 12) {
                            HStack {
                                Text("Abonelikler ve Kesintiler")
                                    .font(.title3.bold())
                                    .foregroundColor(theme.labelPrimary)
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            
                            // Yakın bir tarihe göre sırala (En yakın tarih en üstte)
                            let sorted = upcomingPayments.sorted(by: { $0.date < $1.date })
                            
                            ForEach(sorted) { tx in
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(tx.resolvedColor().opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: tx.resolvedIcon)
                                            .font(.title3)
                                            .foregroundColor(tx.resolvedColor())
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        let title = tx.note?.isEmpty == false ? tx.note! : tx.mainCategoryName
                                        Text(title)
                                            .font(.headline)
                                            .foregroundColor(theme.labelPrimary)
                                            .lineLimit(1)
                                        HStack(spacing: 4) {
                                            if tx.isRecurring {
                                                Image(systemName: "repeat")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.orange)
                                            } else if tx.isDebt {
                                                Image(systemName: "creditcard.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.red)
                                            }
                                            Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundColor(theme.labelSecondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("-₺\(tx.amount.formatted(.number.precision(.fractionLength(0))))")
                                            .font(.headline.bold())
                                            .foregroundColor(theme.labelPrimary)
                                        
                                        // Kaç gün kaldı hesapla
                                        let daysCount = Calendar.current.dateComponents([.day], from: Date(), to: tx.date).day ?? 0
                                        Text(daysCount == 0 ? "Bugün" : (daysCount < 0 ? "Gecikti" : "\(daysCount) gün kaldı"))
                                            .font(.caption2.bold())
                                            .foregroundColor(daysCount <= 3 ? theme.expense : theme.labelSecondary)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .glassEffect(in: .rect(cornerRadius: 20))
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .padding(.top, 16)
                    .safeAreaPadding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Ödeme Takvimi")
        .navigationBarTitleDisplayMode(.inline)
    }
}
