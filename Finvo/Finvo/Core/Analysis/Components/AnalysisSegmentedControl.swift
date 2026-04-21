import SwiftUI

/// Analiz ekranının zaman dilimi seçicisi.
/// AnalysisSegmentedControl.swift - önceki boş dosya yerine yeniden oluşturuldu.
struct AnalysisSegmentedControl: View {
    @Environment(\.theme) var theme
    @Binding var selectedTab: AnalysisTimeFrame

    var body: some View {
        Picker("Zaman Dilimi", selection: $selectedTab) {
            ForEach(AnalysisTimeFrame.allCases) { frame in
                Text(frame.title).tag(frame)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AnalysisSegmentedControl(selectedTab: .constant(.month))
        .padding()
        .environment(\.theme, DefaultTheme())
}
