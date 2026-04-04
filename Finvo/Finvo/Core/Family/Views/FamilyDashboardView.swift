import SwiftUI

struct FamilyDashboardView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    
    @StateObject private var viewModel = FamilyDashboardViewModel()
    @State private var isAnimating = false
    
    // Aktif cüzdanın paylaşımlı olup olmadığını kontrol et
    var isSharedWalletActive: Bool {
        walletManager.activeWallet?.type == .shared
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // MARK: - Animated Background
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
                
                if isSharedWalletActive {
                    dashboardHub
                } else {
                    personalWalletWarning
                }
            }
            .navigationTitle("Aile Merkezi")
            .onAppear {
                withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            // İşlemler değiştiğinde tatlı borçları yeniden hesapla
            .onChange(of: transactionManager.transactions) { _, newTx in
                if isSharedWalletActive {
                    viewModel.calculateWholesomeDebts(from: newTx)
                }
            }
            .onAppear {
                if isSharedWalletActive {
                    viewModel.calculateWholesomeDebts(from: transactionManager.transactions)
                    
                    if let members = walletManager.activeWallet?.members {
                        viewModel.fetchMemberProfiles(uids: members)
                    }
                }
            }
        }
    }
    
    // MARK: - Paylaşımlı Cüzdan Merkezi (Hub)
    private var dashboardHub: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                
                // 1. Aktif Cüzdan Başlığı (Büyük ve Şık)
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Şu anki Cüzdan")
                            .font(.subheadline)
                            .foregroundStyle(theme.labelSecondary)
                        
                        Text(walletManager.activeWallet?.name ?? "Bilinmiyor")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(theme.labelPrimary)
                    }
                    Spacer()
                    
                    if !viewModel.memberProfiles.isEmpty {
                        HStack(spacing: 10) { // Yan yana, ufak boşluk (10px) ve border yok
                            ForEach(Array(viewModel.memberProfiles.prefix(4))) { profile in
                                if let photoUrlString = profile.photoUrl, let url = URL(string: photoUrlString) {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 44, height: 44)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(theme.brandPrimary.opacity(0.15))
                                                .frame(width: 44, height: 44)
                                        }
                                    }
                                } else {
                                    // Fallback (Fotoğrafı yoksa harfini koy)
                                    ZStack {
                                        Circle()
                                            .fill(theme.brandPrimary.opacity(0.8))
                                            .frame(width: 44, height: 44)
                                        
                                        Text(String(profile.username.prefix(1)).uppercased())
                                            .font(.subheadline.weight(.heavy))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            
                            if viewModel.memberProfiles.count > 4 {
                                ZStack {
                                    Circle()
                                        .fill(theme.background2)
                                        .frame(width: 44, height: 44)
                                    Text("+\(viewModel.memberProfiles.count - 4)")
                                        .font(.caption.bold())
                                        .foregroundStyle(theme.labelPrimary)
                                }
                            }
                        }
                    } else if let members = walletManager.activeWallet?.members, !members.isEmpty {
                        // Eğer profil yükleniyorsa gösterilecek loading/fallback
                        HStack(spacing: 10) {
                            ForEach(Array(members.prefix(4).enumerated()), id: \.element) { _, _ in
                                Circle()
                                    .fill(theme.brandPrimary.opacity(0.2))
                                    .frame(width: 44, height: 44)
                            }
                        }
                    } else {
                        // Fallback icon
                        ZStack {
                            Circle()
                                .fill(theme.brandPrimary.opacity(0.15))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "person.3.sequence.fill")
                                .foregroundStyle(theme.brandPrimary)
                                .font(.body)
                        }
                    }
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 24))
                .padding(.horizontal)
                
                // 2. Ortak Hedefler (Savings Carousel)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ailenizin Hedefleri")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.labelPrimary)
                        .padding(.horizontal)
                    
                    if let savings = walletManager.activeWallet?.savingsAccounts, !savings.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(savings) { saving in
                                    savingsCard(for: saving)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        // Boş Durum
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Henüz bir hedef yok")
                                    .font(.headline)
                                    .foregroundStyle(theme.labelPrimary)
                                Text("Ailenizle ortak birikim hedefi belirleyin.")
                                    .font(.caption)
                                    .foregroundStyle(theme.labelSecondary)
                            }
                            Spacer()
                            Image(systemName: "target")
                                .font(.title)
                                .foregroundStyle(theme.brandPrimary.opacity(0.5))
                        }
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 20))
                        .padding(.horizontal)
                    }
                }
                
                // 3. Tatlı Borçlar (Wholesome Debts Carousel)
                if !viewModel.wholesomeMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aile İçi Durumlar")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.labelPrimary)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.wholesomeMessages, id: \.self) { msg in
                                    Text(msg)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(theme.labelPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .glassEffect(in: .capsule)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // 4. Hızlı Eylemler (Grid)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Özellikler")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.labelPrimary)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        
                        // Ortak Alışveriş
                        NavigationLink {
                            FamilyShoppingListView()
                        } label: {
                            featureGridCard(
                                icon: "cart.fill",
                                title: "Alışveriş",
                                subtitle: "\(viewModel.pendingShoppingItemsCount) Bekleyen",
                                gradient: [Color.orange.opacity(0.8), Color.orange]
                            )
                        }
                        
                        // Görev Panosu
                        NavigationLink {
                            FamilyMissionsView()
                        } label: {
                            featureGridCard(
                                icon: "star.fill",
                                title: "Görevler",
                                subtitle: "\(viewModel.pendingMissionsCount) Aktif",
                                gradient: [Color.purple.opacity(0.8), Color.purple]
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Kişisel Cüzdan Uyarısı
    private var personalWalletWarning: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(theme.brandPrimary.opacity(0.8))
            
            Text("Paylaşımlı Cüzdan Gerekli")
                .font(.headline)
                .foregroundStyle(theme.labelPrimary)
            
            Text("Aile merkezini kullanabilmek için 'Özet' sayfasından paylaşımlı bir cüzdan seçmeli veya yeni bir paylaşımlı cüzdan oluşturmalısınız.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.labelSecondary)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal)
    }
    
    // MARK: - Subcomponents
    
    @ViewBuilder
    private func savingsCard(for saving: SavingsAccountModel) -> some View {
        let progress = saving.goalAmount > 0 ? (saving.currentAmount / saving.goalAmount) : 0
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                // Circular Progress
                ZStack {
                    Circle()
                        .stroke(theme.separatorSecondary, lineWidth: 4)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                        .stroke(theme.brandPrimary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "target")
                        .font(.caption.bold())
                        .foregroundStyle(theme.brandPrimary)
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(theme.brandPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.brandPrimary.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(saving.name)
                    .font(.headline)
                    .foregroundStyle(theme.labelPrimary)
                    .lineLimit(1)
                
                Text("₺\(saving.currentAmount.formatted(.number.precision(.fractionLength(0)))) / ₺\(saving.goalAmount.formatted(.number.precision(.fractionLength(0))))")
                    .font(.caption)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
        .padding(16)
        .frame(width: 160)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
    
    @ViewBuilder
    private func featureGridCard(icon: String, title: String, subtitle: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.labelPrimary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.labelSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

#Preview {
    FamilyDashboardView()
        .environment(\.theme, DefaultTheme())
        .environmentObject(WalletManager())
        .environmentObject(TransactionManager())
        .environmentObject(AuthenticationManager.shared)
}


