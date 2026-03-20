import SwiftUI

// MARK: - Card Models
enum BalanceCardType {
    case main(balance: Double, profit: Double, pending: Double, trend: Double)
    case savings(balance: Double, goalProgress: Double)
    case custom(title: String, amount: Double, icon: String, color: Color)
}

struct BalanceCardModel: Identifiable {
    let id = UUID()
    let type: BalanceCardType
}

struct BalanceCardView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var walletManager: WalletManager
    @State private var scrolledID: Int? = 500
    @State private var isDragging: Bool = false
    
    // Dinamik kart verileri:
    var cards: [BalanceCardModel] {
        let totalBalance = transactionManager.totalIncome - transactionManager.totalExpense
        let savingsTotal = transactionManager.transactions
            .filter { $0.mainCategoryName == "Yatırım Getirisi" || $0.mainCategoryName == "Diğer Gelirler" } // Basit bir kural, geliştirilebilir
            .reduce(0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
        
        // Hedef ilerlemesi (WalletModel'den)
        let savingsGoal = walletManager.activeWallet?.savingsGoal ?? 10000.0
        let progress = savingsGoal > 0 ? (savingsTotal / savingsGoal) : 0.0

        return [
            BalanceCardModel(type: .main(balance: totalBalance, profit: transactionManager.totalIncome, pending: 0.0, trend: 0.0)),
            BalanceCardModel(type: .savings(balance: savingsTotal, goalProgress: progress))
        ]
    }
    
    var body: some View {
        ZStack {
            // Ana Kapsayıcı Arka Planı: Sadece kapsayıcı 1.03 büyür
            Color.clear
                .glassEffect(in: .rect(cornerRadius: 24.0))
                .scaleEffect(isDragging ? 1.01 : 1.0)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            // İçerik: Kaydırma sırasında ana çerçeveden bağımsız çalışır
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Sonsuz kayma (Smart Stack) hissi vermek için geniş bir döngü
                    ForEach(0..<1000, id: \.self) { index in
                        // Hangi kartın gösterileceğini modüler aritmetikle bul (Sonsuz Döngü)
                        let cardIndex = index % cards.count
                        let card = cards[cardIndex]
                        
                        cardView(for: card)
                            .id(index) // iOS 17 ScrollPosition için ID
                            .scrollTransition(
                                .interactive.animation(.easeInOut),
                                axis: .vertical
                            ) { content, phase in
                                content
                                    // Yavaşça (adım adım) küçülmesi için phase.value hesaplaması
                                    .scaleEffect(1.0 - (abs(phase.value) * 0.1))
                                    .opacity(1.0 - (abs(phase.value) * 0.2))
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledID)
            .scrollTargetBehavior(.paging)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(height: 150)
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDragging = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isDragging = false
                    }
                }
        )
        .onAppear {
            if scrolledID == nil || scrolledID == 0 {
                scrolledID = 500
            }
        }
        // İndikatörler (Absolute gibi fiziksel yer kaplamaz, dışarıda durur)
        .overlay(alignment: .trailing) {
            VStack(spacing: 6) {
                // Dizideki eleman sayısı kadar nokta oluşturur
                ForEach(0..<cards.count, id: \.self) { indicatorIndex in
                    // Geçerli aktif olan kartı hesapla
                    let activeIndex = (scrolledID ?? 0) % cards.count
                    let isActive = (indicatorIndex == activeIndex)
                    
                    Circle()
                        .fill(isActive ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
            }
            // Kartın sağına (dışarıya) itilir, sola yaklaşması için offset kısıldı
            .offset(x: 10)
            // Sadece kapsayıcı büyüdüğünde ekrana gelsin
            .opacity(isDragging ? 1.0 : 0.0)
            // Çıkarken (isDragging == false) 1 sn bekler, gelirken anında gelir
            .animation(isDragging ? .easeInOut(duration: 0.2) : .easeInOut(duration: 0.5).delay(1.0), value: isDragging)
        }
    }
    
    // MARK: - Shared Action Menu
    private var settingsMenuButton: some View {
        Menu {
            Button("Harcama limiti belirle") { }
            Button("Birikim hedefi belirle") { }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Dynamic Card Router
    @ViewBuilder
    private func cardView(for model: BalanceCardModel) -> some View {
        switch model.type {
        case .main(let balance, let profit, let pending, let trend):
            mainBalanceCard(balance: balance, profit: profit, pending: pending, trend: trend)
        case .savings(let balance, let goalProgress):
            savingsCard(balance: balance, goalProgress: goalProgress)
        case .custom(let title, let amount, let icon, let color):
            customCard(title: title, amount: amount, icon: icon, color: color)
        }
    }
    
    // MARK: - Main Balance Card
    private func mainBalanceCard(balance: Double, profit: Double, pending: Double, trend: Double) -> some View {
        VStack(spacing: 0) {
            // Üst Kısım: Başlık ve Yüzde
            HStack {
                Text("Toplam Bakiye")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                settingsMenuButton
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Orta Kısım: Ana Bakiye
            HStack {
                Text("₺\(balance.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Alt Kısım: Kâr ve Bekleyen (Daha kompakt tasarım)
            HStack {
                HStack(spacing: 0) {
                    Text("Bugünün Kârı")
                    Text(": +₺\(profit.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                }
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                HStack(spacing: 0) {
                    Text("Bekleyen")
                    Text(": ₺\(pending.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                }
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
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
    
    // MARK: - Savings Card
    private func savingsCard(balance: Double, goalProgress: Double) -> some View {
        VStack(spacing: 0) {
            // Üst: Başlık ve İkon
            HStack {
                Text("Toplam Birikim")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                settingsMenuButton
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Orta: Birikim Tutarı
            HStack {
                Text("₺\(balance.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Alt: Hedef Çubuğu (Daha kalın ve şık)
            HStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Arka Plan Pisti
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 8)
                        
                        // Dolan Kısım
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(CGFloat(goalProgress) * geometry.size.width, geometry.size.width)), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(.bottom, 20)
            .padding(.horizontal, 20)
        }
        .frame(height: 150)
        .background(
            Color.orange.opacity(1)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        ) // Birikim için opsiyonel mor tonu
        .glassEffect(in: .rect(cornerRadius: 24.0))
    }
    
    // MARK: - Custom Card Template
    private func customCard(title: String, amount: Double, icon: String, color: Color) -> some View {
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
                Text("₺\(amount.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            HStack {
                Text("Custom Card Model")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
            .padding(.bottom, 16)
            .padding(.horizontal, 20)
        }
        .frame(height: 150)
        .background(
            color.opacity(0.8)
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
