import SwiftUI

struct WalletsView: View {
    var body: some View {
        VStack {
            Image(systemName: "wallet.bifold")
                .font(.system(size: 80))
                .foregroundColor(.green)
                .padding()
            
            Text("Cüzdanlar")
                .font(.title)
                .bold()
            
            Text("Çok Yakında")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Cüzdanlar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct WalletsView_Previews: PreviewProvider {
    static var previews: some View {
        WalletsView()
    }
}
