import SwiftUI

struct LimitsView: View {
    var body: some View {
        VStack {
            Image(systemName: "doc.text")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .padding()
            
            Text("Limitler")
                .font(.title)
                .bold()
            
            Text("Çok Yakında")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Limitler")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LimitsView_Previews: PreviewProvider {
    static var previews: some View {
        LimitsView()
    }
}
