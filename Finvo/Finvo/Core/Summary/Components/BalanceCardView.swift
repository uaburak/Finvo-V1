import SwiftUI

struct BalanceCardView: View {
    @Environment(\.theme) var theme
    
    var body: some View {
        VStack(spacing: 20) {
            // Üst Kısım: Başlık ve Yüzde
            HStack {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Artış Yüzdesi Pili
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("+4.5%")
                }
                .font(.caption.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
            }
            
            // Orta Kısım: Ana Bakiye
            HStack {
                Text("$12,450.00")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Ayırıcı Çizgi
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Alt Kısım: Bugünün Karı ve Bekleyen
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Profit")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                    Text("+$340.00")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Dikey Ayırıcı Modeli
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 30)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Pending")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                    Text("$120.50")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .background(theme.brandPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: theme.brandPrimary.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

struct BalanceCardView_Previews: PreviewProvider {
    static var previews: some View {
        BalanceCardView()
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
