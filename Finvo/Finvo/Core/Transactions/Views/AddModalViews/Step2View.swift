//
//  Step2View.swift
//  Finvo
//

import SwiftUI

struct Step2View: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)
            Text("Ana kategoriyi seçin")
                .font(.title3).fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("İşlemin hangi ana kategoriye ait olduğunu seçin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#Preview {
    Step2View()
}
