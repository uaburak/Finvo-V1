//
//  Step3View.swift
//  Finvo
//

import SwiftUI

struct Step3View: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)
            Text("Alt kategoriyi seçin")
                .font(.title3).fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("Daha ayrıntılı bir sınıflandırma yapın.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

#Preview {
    Step3View()
}
