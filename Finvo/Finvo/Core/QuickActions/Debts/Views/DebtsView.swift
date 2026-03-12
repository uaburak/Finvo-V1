import SwiftUI

struct DebtsView: View {
    var body: some View {
        VStack {
            Image(systemName: "creditcard")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .padding()
            
            Text("Borçlar")
                .font(.title)
                .bold()
            
            Text("Çok Yakında")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Borçlar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DebtsView_Previews: PreviewProvider {
    static var previews: some View {
        DebtsView()
    }
}
