//
//  AmountInputSheet.swift
//  Finvo
//

import SwiftUI

struct AmountInputSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @Binding var amount: String
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Tutar Girin")
                .font(.headline)
                .foregroundStyle(theme.labelPrimary)
                .padding(.top)
            
            TextField("0,00", text: $amount)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(theme.brandPrimary)
                .padding(.horizontal)
            
            Button {
                dismiss()
            } label: {
                Text("Tamam")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(theme.brandPrimary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .background(theme.background1)
    }
}
