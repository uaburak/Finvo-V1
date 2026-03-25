import SwiftUI

struct AnalysisSegmentedControl: View {
    @Binding var selectedTab: AnalysisTimeFrame
    
    var body: some View {
        Picker("Zaman Aralığı", selection: $selectedTab) {
            ForEach(AnalysisTimeFrame.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 8)
    }
}
