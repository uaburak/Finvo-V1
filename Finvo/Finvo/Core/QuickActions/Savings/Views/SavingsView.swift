import SwiftUI

struct SavingsView: View {
    var body: some View {
        VStack {
            Image(systemName: "lanyardcard")
                .font(.system(size: 80))
                .foregroundColor(.purple)
                .padding()
            
            Text("Birikimler")
                .font(.title)
                .bold()
            
            Text("Çok Yakında")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Birikimler")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SavingsView_Previews: PreviewProvider {
    static var previews: some View {
        SavingsView()
    }
}
