//
//  Step4View.swift
//  Finvo
//

import SwiftUI

struct Step4View: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)
            Text("İşlem detaylarını girin")
                .font(.title3).fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("Tutar, tarih ve not ekleyebilirsiniz.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#Preview {
    Step4View()
}
