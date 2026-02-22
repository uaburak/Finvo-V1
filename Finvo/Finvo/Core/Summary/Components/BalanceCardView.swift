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
    @State private var scrolledID: Int? = 500
    @State private var isDragging: Bool = false
    
    // İstediğin kadar kart ekleyebilirsin:
    let cards: [BalanceCardModel] = [
        BalanceCardModel(type: .main(balance: 12450.00, profit: 340.00, pending: 120.50, trend: 4.5)),
        BalanceCardModel(type: .savings(balance: 3200.00, goalProgress: 0.8))
        // İleride buraya virgül koyup üçüncü kartı da ekleyebilirsin! Örneğin:
        // BalanceCardModel(type: .custom(title: "Investments", amount: 5000, icon: "chart.pie.fill", color: .orange))
    ]
    
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
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Artış Yüzdesi
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("+\(String(format: "%.1f", trend))%")
                }
                .font(.caption2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Orta Kısım: Ana Bakiye
            HStack {
                Text("$\(String(format: "%.2f", balance))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Alt Kısım: Kâr ve Bekleyen (Daha kompakt tasarım)
            HStack {
                Text("Profit: +$\(String(format: "%.2f", profit))")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("Pending: $\(String(format: "%.2f", pending))")
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
                Text("Total Savings")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Image(systemName: "banknote.fill")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Orta: Birikim Tutarı
            HStack {
                Text("$\(String(format: "%.2f", balance))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            // Alt: Hedef Çubuğu
            HStack {
                Text("Monthly Goal: \(Int(goalProgress * 100))%")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                ProgressView(value: goalProgress)
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(width: 80)
            }
            .padding(.bottom, 16)
            .padding(.horizontal, 20)
        }
        .frame(height: 150)
        .background(
            Color.purple.opacity(0.8)
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
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
            
            HStack {
                Text("$\(String(format: "%.2f", amount))")
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
