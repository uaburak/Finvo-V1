import SwiftUI

// MARK: - Card Models
enum BalanceCardType {
    case main(balance: Double, profit: Double, pending: Double, trend: Double)
    case custom(title: String, amount: Double, icon: String, color: Color, goalAmount: Double)
}

struct BalanceCardModel: Identifiable {
    let id = UUID()
    let type: BalanceCardType
}

struct BalanceCardView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @State private var scrolledID: Int? = 50
    @State private var isDragging: Bool = false
    @State private var showSavingsGoalSheet = false
    @State private var showSpendingLimitSheet = false
    
    // Dinamik kart verileri:
    var cards: [BalanceCardModel] {
        var totalBalance = transactionManager.totalIncome - transactionManager.totalExpense
        
        // Net Varlık: Ana bakiye + Tüm birikim hesaplarındaki farklı birimlerin o anki kurla toplamı
        if let savingsAccounts = walletManager.activeWallet?.savingsAccounts {
            for account in savingsAccounts {
                // Dinamik bakiye hesapla
                let dynamicAmount = account.assets?.reduce(0.0) { sum, assetKV in
                    let curr = CurrencyType(rawValue: assetKV.key) ?? .tryCurrency
                    return sum + ExchangeRateManager.shared.convert(amount: assetKV.value, from: curr, to: appCurrency)
                } ?? 0.0
                
                totalBalance += dynamicAmount
            }
        }
        
        var allCards: [BalanceCardModel] = [
            BalanceCardModel(type: .main(balance: totalBalance, profit: transactionManager.todaysProfit, pending: 0.0, trend: 0.0))
        ]
        
        if let savingsAccounts = walletManager.activeWallet?.savingsAccounts {
            for account in savingsAccounts {
                let dynamicAmount = account.assets?.reduce(0.0) { sum, assetKV in
                    let curr = CurrencyType(rawValue: assetKV.key) ?? .tryCurrency
                    return sum + ExchangeRateManager.shared.convert(amount: assetKV.value, from: curr, to: appCurrency)
                } ?? 0.0
                
                let goalCurr = CurrencyType(rawValue: account.goalCurrency ?? "") ?? .tryCurrency
                let dynamicGoalAmount = ExchangeRateManager.shared.convert(amount: account.goalAmount, from: goalCurr, to: appCurrency)
                
                allCards.append(BalanceCardModel(type: .custom(
                    title: account.name,
                    amount: dynamicAmount,
                    icon: "lanyardcard.fill",
                    color: getSwiftColor(from: account.color),
                    goalAmount: dynamicGoalAmount
                )))
            }
        }
        
        return allCards
    }
    
    private func getSwiftColor(from stringRaw: String) -> Color {
        Color.fromStandardName(stringRaw)
    }
    
    @AppStorage("appCurrency") private var appCurrency: CurrencyType = .tryCurrency
    
    var body: some View {
        ZStack {
            // Ana Kapsayıcı Arka Planı
            Color.clear
                .glassEffect(in: .rect(cornerRadius: 24.0))
                .scaleEffect(isDragging ? 1.01 : 1.0)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            // İçerik
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if cards.count > 1 {
                        // Sonsuz kayma hissi — 20 döngü LazyVStack + paging ile yeterli
                        ForEach(0..<20, id: \.self) { index in
                            let cardIndex = index % cards.count
                            let card = cards[cardIndex]
                            
                            cardView(for: card)
                                .id(index)
                                .scrollTransition(.interactive.animation(.easeInOut), axis: .vertical) { content, phase in
                                    content
                                        .scaleEffect(1.0 - (abs(phase.value) * 0.1))
                                        .opacity(1.0 - (abs(phase.value) * 0.2))
                                }
                        }
                    } else if let firstCard = cards.first {
                        // Tek kart varsa sonsuz döngüye gerek yok
                        cardView(for: firstCard)
                            .id(0)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledID)
            .scrollTargetBehavior(.paging)
            .scrollDisabled(cards.count <= 1)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(height: 150)
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    if cards.count > 1 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isDragging = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDragging = false
                    }
                }
        )
        .onAppear {
            if cards.count > 1 && (scrolledID == nil || scrolledID == 0) {
                scrolledID = 50
            } else if cards.count <= 1 {
                scrolledID = 0
            }
        }
        // İndikatörler
        .overlay(alignment: .trailing) {
            if cards.count > 1 {
                VStack(spacing: 6) {
                    ForEach(0..<cards.count, id: \.self) { indicatorIndex in
                        let activeIndex = (cards.count > 0) ? ((scrolledID ?? 0) % cards.count) : 0
                        let isActive = (indicatorIndex == activeIndex)
                        
                        Circle()
                            .fill(isActive ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                }
                .offset(x: 10)
                .opacity(isDragging ? 1.0 : 0.0)
                .animation(isDragging ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.5).delay(1.0), value: isDragging)
            }
        }
        .sheet(isPresented: $showSavingsGoalSheet) {
            CreateSavingsAccountSheet()
                .environmentObject(walletManager)
                .environmentObject(transactionManager)
                .presentationDetents([.height(480)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showSpendingLimitSheet) {
            SetSpendingLimitSheet()
                .environmentObject(walletManager)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(.clear)
        }
    }
    
    // MARK: - Shared Action Menu
    private var settingsMenuButton: some View {
        Menu {
            Button(L10n("Harcama Limiti Belirle")) { showSpendingLimitSheet = true }
            Button("Birikim Hesabı Oluştur") { showSavingsGoalSheet = true }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.onBrandPrimary)
        }
    }
    
    // MARK: - Dynamic Card Router
    @ViewBuilder
    private func cardView(for model: BalanceCardModel) -> some View {
        switch model.type {
        case .main(let balance, let profit, let pending, let trend):
            mainBalanceCard(balance: balance, profit: profit, pending: pending, trend: trend)
        case .custom(let title, let amount, let icon, let color, let goalAmount):
            customCard(title: title, amount: amount, icon: icon, color: color, goalAmount: goalAmount)
        }
    }
    
    // MARK: - Main Balance Card
    private func mainBalanceCard(balance: Double, profit: Double, pending: Double, trend: Double) -> some View {
        VStack(spacing: 0) {
            // Üst Kısım: Başlık ve Yüzde
            HStack {
                Text(L10n("Toplam Bakiye"))
                    .font(.subheadline)
                    .foregroundColor(theme.onBrandPrimary.opacity(0.8))
                
                Spacer()
                
                settingsMenuButton
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Orta Kısım: Ana Bakiye
            HStack {
                Text("\(appCurrency.symbol)\(balance.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(theme.onBrandPrimary)
                    .contentTransition(.numericText())
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Alt Kısım: Kâr ve Bekleyen (Daha kompakt tasarım)
            HStack {
                HStack(spacing: 0) {
                    Text(L10n("Bugünün Kârı"))
                    Text(": +\(appCurrency.symbol)\(profit.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                }
                .font(.footnote)
                .foregroundColor(theme.onBrandPrimary.opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 0) {
                    Text(L10n("Bekleyen"))
                    Text(": \(appCurrency.symbol)\(pending.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                }
                .font(.footnote)
                .foregroundColor(theme.onBrandPrimary.opacity(0.8))
            }
            .padding(.bottom, 16)
            .padding(.horizontal, 20)
        }
        .frame(height: 150)
        .background(
            theme.brandPrimary.opacity(1)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        ) // Liquid efekti için ufak bir saydamlık iyi gider
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
    

    
    // MARK: - Custom Card Template
    private func customCard(title: String, amount: Double, icon: String, color: Color, goalAmount: Double) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                settingsMenuButton
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            HStack {
                Text("\(appCurrency.symbol)\(amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Spacer()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // İlerleme Çubuğu ve Yüzde
            let progressRaw = goalAmount > 0 ? (amount / goalAmount) : 0
            let progress = min(max(progressRaw, 0), 1)
            let percentageText = "%\(Int(progress * 100))"
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(percentageText) \(L10n("Ulaşıldı"))")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.9))
                
                HStack {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(Color.white)
                                .frame(width: CGFloat(progress) * geometry.size.width, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 20)
        }
        .frame(height: 150)
        .background(
            color.opacity(1)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
}

struct BalanceCardView_Previews: PreviewProvider {
    static var previews: some View {
        BalanceCardView()
            .padding()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}



struct SetSpendingLimitSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @State private var amountString: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Spacer()
                Text(L10n("Harcama Limiti Belirle"))
                    .font(.headline)
                Spacer()
            }
            .padding(.top, 24)
            .overlay(alignment: .leading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(theme.labelSecondary)
                }
                .padding(.top, 24)
                .padding(.leading, 20)
            }
            
            Text(L10n("Aylık harcama limitini belirleyerek bütçenin dışına çıkma riskini en aza indir."))
                .font(.footnote)
                .foregroundColor(theme.labelSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Input
            HStack {
                Text("₺")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(theme.labelSecondary)
                
                TextField(L10n("Eklenecek Tutar"), text: $amountString)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.labelPrimary)
                    .keyboardType(.decimalPad)
            }
            .padding()
            .background(theme.background2)
            .cornerRadius(16)
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Kaydet
            Button {
                saveLimit()
            } label: {
                Text(L10n("Kaydet"))
                    .font(.headline.bold())
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.expense)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .disabled(amountString.isEmpty)
        }
        .background(theme.background1.ignoresSafeArea())
        .onAppear {
            if let existing = walletManager.activeWallet?.monthlyLimit, existing > 0 {
                amountString = String(format: "%.0f", existing)
            }
        }
    }
    
    private func saveLimit() {
        guard var wallet = walletManager.activeWallet else { return }
        
        let cleaned = amountString.replacingOccurrences(of: ",", with: ".")
        if let val = Double(cleaned) {
            wallet.monthlyLimit = val
            walletManager.updateWallet(wallet)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            dismiss()
        }
    }
}
