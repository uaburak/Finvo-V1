//
//  Step1View.swift
//  Finvo
//

import SwiftUI

struct Step1View: View {
    let onSelect: (TransactionType) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Üst Satır: Gider & Gelir
            HStack(spacing: 12) {
                typeCard(
                    title: "Gider",
                    icon: "arrow.down.circle.fill",
                    color: .red,
                    action: { onSelect(.expense) }
                )
                
                typeCard(
                    title: "Gelir",
                    icon: "arrow.up.circle.fill",
                    color: .green,
                    action: { onSelect(.income) }
                )
            }
            
            // Alt Satır: Tara (Full Width)
            typeCard(
                title: "Belge / Fiş Tara",
                icon: "viewfinder",
                color: .indigo,
                isFullWidth: true,
                action: { /* İleride dolacak */ }
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.vertical, 14)
    }
    
    // MARK: - Tür kart bileşeni
    private func typeCard(title: String,
                          icon: String,
                          color: Color,
                          isFullWidth: Bool = false,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isFullWidth {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                    Text(title)
                        .font(.headline)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 32))
                        Text(title)
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: isFullWidth ? 54 : 100)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Step1View { _ in }
}
