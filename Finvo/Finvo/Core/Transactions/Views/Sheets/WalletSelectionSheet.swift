//
//  WalletSelectionSheet.swift
//  Finvo
//

import SwiftUI

struct WalletSelectionSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @Binding var selectedWallet: String
    
    let wallets = ["Ana Cüzdan", "Kredi Kartı", "Nakit"] // Bu ileride modelden çekilebilir
    
    var body: some View {
        NavigationStack {
            List(wallets, id: \.self) { wallet in
                Button {
                    selectedWallet = wallet
                    dismiss()
                } label: {
                    HStack {
                        Text(wallet)
                            .foregroundStyle(theme.labelPrimary)
                        Spacer()
                        if selectedWallet == wallet {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.brandPrimary)
                        }
                    }
                }
                .listRowBackground(theme.cardBackground)
            }
            .scrollContentBackground(.hidden)
            .background(theme.background1)
            .navigationTitle(L10n("Cüzdan Seçin"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n("Kapat")) { dismiss() }
                }
            }
        }
    }
}
