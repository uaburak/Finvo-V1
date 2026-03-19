import SwiftUI

struct CreateWalletSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var walletManager: WalletManager
    
    @State private var walletName: String = ""
    @State private var selectedType: WalletType = .personal
    @State private var selectedContext: WalletContext = .general
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(spacing: 24) {
                        
                        // Cüzdan İsmi - Tam Yuvarlak (Capsule) & Başlıksız
                        TextField("Cüzdan Adı", text: $walletName)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(theme.separator, lineWidth: 1)
                            )
                        
                        // Cüzdan Tipi - Başlıksız & Daha Büyük Segmented Control
                        Picker("Cüzdan Tipi", selection: $selectedType) {
                            ForEach(WalletType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        
                        // Kullanım Amacı - Başlıksız & Daha Büyük Segmented Control
                        Picker("Kullanım Amacı", selection: $selectedContext) {
                            ForEach(WalletContext.allCases, id: \.self) { context in
                                Text(context.title).tag(context)
                            }
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)
                        
                    }
                    .padding(.top, 10)

                    Button {
                        let feedback = UIImpactFeedbackGenerator(style: .medium)
                        feedback.prepare()
                        
                        guard !walletName.isEmpty else { return }
                        
                        // Cüzdanı oluştur
                        walletManager.createWallet(
                            name: walletName,
                            type: selectedType,
                            context: selectedContext
                        )
                        
                        feedback.impactOccurred()
                        dismiss()
                    } label: {
                        Text("Oluştur")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 24)
                    .disabled(walletName.isEmpty)
                    .opacity(walletName.isEmpty ? 0.6 : 1.0)
                }
                .padding(.top, 20)
                .padding(.horizontal, 24)
            }
            .navigationTitle("Yeni Cüzdan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .fontWeight(.bold)
                            .foregroundStyle(theme.labelPrimary)
                    }
                }
            }
        }
    }
}

#Preview {
    CreateWalletSheet()
        .environment(\.theme, DefaultTheme())
        .environmentObject(WalletManager())
}
