import SwiftUI

struct IBANListView: View {
    @Environment(\.theme) var theme
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showAddIBAN = false
    @State private var showCopyToast = false
    
    var body: some View {
        ZStack {
            theme.background1.ignoresSafeArea()
            
            if let ibans = authManager.currentUserProfile?.ibans, !ibans.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(ibans) { iban in
                            ibanRow(iban: iban)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 60))
                        .foregroundColor(theme.labelSecondary)
                    
                    Text("Kayıtlı IBAN Yok")
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text("Transferlerinizde hızlıca paylaşmak için\nIBAN bilgilerinizi ekleyin.")
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showAddIBAN = true
                    } label: {
                        Text("İlk IBAN'ı Ekle")
                            .font(.headline)
                            .foregroundColor(theme.onBrandPrimary)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(theme.brandPrimary)
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            
            if showCopyToast {
                VStack {
                    Spacer()
                    Text("IBAN Kopyalandı")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50)
                }
                .zIndex(1)
            }
        }
        .navigationTitle("IBAN Bilgilerim")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showAddIBAN = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(theme.labelPrimary)
                }
            }
        }
        .sheet(isPresented: $showAddIBAN) {
            AddIBANSheet()
                .environmentObject(authManager)
                .presentationDetents([.medium, .height(500)])
                .presentationBackground(.clear)
                .presentationDragIndicator(.hidden)
        }
    }
    
    @ViewBuilder
    private func ibanRow(iban: IBANModel) -> some View {
        Button {
            copyToClipboard(iban.ibanString)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(iban.bankName)
                        .font(.headline)
                        .foregroundColor(theme.labelPrimary)
                    
                    Text(formatIBAN(iban.ibanString))
                        .font(.subheadline)
                        .foregroundColor(theme.labelSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "doc.on.doc")
                    .foregroundColor(theme.brandPrimary)
                    .font(.system(size: 14))
            }
            .padding()
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteIBAN(iban)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation {
            showCopyToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopyToast = false
            }
        }
    }
    
    private func formatIBAN(_ iban: String) -> String {
        // TRXX XXXX XXXX XXXX XXXX... formatına sokabiliriz
        return iban
    }
    
    private func deleteIBAN(_ iban: IBANModel) {
        guard var profile = authManager.currentUserProfile else { return }
        profile.ibans?.removeAll(where: { $0.id == iban.id })
        
        Task {
            do {
                try await FirestoreService.shared.saveUserProfile(profile)
                await authManager.checkUserProfile()
            } catch {
                print("IBAN silme hatası: \(error)")
            }
        }
    }
}
