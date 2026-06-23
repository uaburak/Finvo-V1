//
//  TransactionDatePickerSheet.swift
//  Finvo
//

import SwiftUI

struct TransactionDatePickerSheet: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @Binding var selection: Date
    
    var body: some View {
        VStack(spacing: 20) {
            header
            
            DatePicker("", selection: $selection, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
            
            Button {
                dismiss()
            } label: {
                Text(L10n("Tamam"))
                    .font(.headline)
                    .foregroundStyle(theme.onBrandPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(theme.brandPrimary)
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(theme.background1)
    }
    
    private var header: some View {
        Text(L10n("Tarih Seçin"))
            .font(.headline)
            .foregroundStyle(theme.labelPrimary)
            .padding(.top)
    }
}
