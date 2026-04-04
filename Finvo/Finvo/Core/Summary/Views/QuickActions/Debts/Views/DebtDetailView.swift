import SwiftUI

struct DebtDetailView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    let debt: TransactionModel
    @State private var isPaying = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Güncel borç verisini transactionManager'dan bulalım (Ödeme sonrası güncellenmiş hali için)
    private var currentDebt: TransactionModel {
        transactionManager.transactions.first(where: { $0.id == debt.id }) ?? debt
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Arka Plan
            theme.background1.ignoresSafeArea()
            
            // Taksit Listesi (Kaydırılabilir içerik)
            ScrollView {
                VStack(spacing: 16) {
                    // Üst kartın kapladığı alan kadar boşluk bırakıyoruz
                    Color.clear.frame(height: 180) 
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Taksit Planı")
                            .font(.headline)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            let totalCount = currentDebt.totalInstallments ?? 0
                            let paidCount = currentDebt.paidInstallments ?? 0
                            
                            ForEach(0..<totalCount, id: \.self) { index in
                                let isPaid = index < paidCount
                                let isNext = index == paidCount
                                
                                installmentRow(index: index, isPaid: isPaid, isNext: isNext)
                            }
                        }
                    }
                }
                .padding(16)
            }
            
            // Özet Bilgi Kartı (Sabit/Sticky ve Cam Efektli)
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentDebt.debtContact ?? currentDebt.mainCategoryName)
                            .font(.title3.bold())
                            .foregroundColor(theme.labelPrimary)
                        
                        Text("Toplam Borç")
                            .font(.subheadline)
                            .foregroundColor(theme.labelSecondary)
                    }
                    
                    Spacer()
                    
                    Text("₺\(currentDebt.amount.formatted(.number.grouping(.automatic).precision(.fractionLength(0))))")
                        .font(.title3.bold())
                        .foregroundColor(theme.expense)
                }
                
                // Progress Bar Large
                let total = Double(currentDebt.totalInstallments ?? 1)
                let paid = Double(currentDebt.paidInstallments ?? 0)
                let progress = paid / total
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Ödeme Gelişimi")
                            .font(.footnote.bold())
                            .foregroundColor(theme.labelSecondary)
                        Spacer()
                        Text("\(Int(paid)) / \(Int(total)) Taksit")
                            .font(.footnote.bold())
                            .foregroundColor(theme.brandPrimary)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(theme.separatorSecondary.opacity(0.1))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [theme.brandPrimary, theme.brandPrimary.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(20)
            .glassEffect(in: .rect(cornerRadius: 24))
            .padding(16)
        }
        .navigationTitle("Borç Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Ödeme Hatası", isPresented: $showingError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private func installmentRow(index: Int, isPaid: Bool, isNext: Bool) -> some View {
        HStack(spacing: 16) {
            ZStack {
                if isPaid {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                } else if isNext {
                    Circle()
                        .fill(theme.brandPrimary.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Text("\(index + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(theme.brandPrimary)
                } else {
                    Circle()
                        .fill(theme.separatorSecondary.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Text("\(index + 1)")
                        .font(.system(size: 14))
                        .foregroundColor(theme.labelSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(index + 1). Taksit")
                    .font(.subheadline.bold())
                    .foregroundColor(isPaid ? theme.labelSecondary : theme.labelPrimary)
                
                if isPaid {
                    Text("Ödendi")
                        .font(.caption2)
                        .foregroundColor(.green)
                } else if isNext {
                    Text("Sıradaki Ödeme")
                        .font(.caption2)
                        .foregroundColor(theme.brandPrimary)
                }
            }
            
            Spacer()
            
            if isNext {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    payInstallment()
                } label: {
                    Text("Öde")
                        .font(.subheadline.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(theme.brandPrimary)
                        .clipShape(Capsule())
                }
                .disabled(isPaying)
            } else if isPaid {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green.opacity(0.5))
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isNext ? theme.brandPrimary.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
    
    private func payInstallment() {
        let username = authManager.currentUserProfile?.username ?? "unknown"
        isPaying = true
        
        Task {
            do {
                try await transactionManager.payDebtInstallment(for: currentDebt, currentUsername: username)
                await MainActor.run {
                    isPaying = false
                    // Eğer son taksit ödendiysek ve borç kapandıysa geri çıkabiliriz
                    if (currentDebt.paidInstallments ?? 0) + 1 >= (currentDebt.totalInstallments ?? 0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPaying = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}
