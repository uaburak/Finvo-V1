//
//  NativeContentView.swift
//  Finvo
//
//  Native TabView varyantı — karşılaştırma için.
//  Add sekmesi tam ortada (3. pozisyon).
//

import SwiftUI

struct NativeContentView: View {
    @Environment(\.theme) var theme
    @Environment(\.colorScheme) var colorScheme

    func sizedIcon(_ systemName: String) -> Image {
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let uiImage = UIImage(systemName: systemName, withConfiguration: config) ?? UIImage()
        return Image(uiImage: uiImage).renderingMode(.template)
    }

    var body: some View {
        TabView {
            Tab {
                SummaryView()
            } label: {
                Label { Text("Özet").font(.system(size: 12)) } icon: { sizedIcon("house.fill") }
            }

            Tab {
                Text("Analiz Sayfası").frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                Label { Text("Analiz").font(.system(size: 12)) } icon: { sizedIcon("chart.pie.fill") }
            }

            Tab {
                NavigationStack { AddTransactionsView() }
            } label: {
                Label { Text("Ekle").font(.system(size: 12)) } icon: { sizedIcon("plus") }
            }

            Tab {
                Text("Aile Sayfası").frame(maxWidth: .infinity, maxHeight: .infinity)
            } label: {
                Label { Text("Aile").font(.system(size: 12)) } icon: { sizedIcon("person.2.fill") }
            }

            Tab {
                SettingsView()
            } label: {
                Label { Text("Ayarlar").font(.system(size: 12)) } icon: { sizedIcon("gearshape.fill") }
            }
        }
        .tint(theme.brandPrimary)
        .id(colorScheme)
    }
}

#Preview {
    NativeContentView()
        .environment(\.theme, DefaultTheme())
}
