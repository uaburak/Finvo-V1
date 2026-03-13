import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.primary)
                .padding()
            
            Text("Profil ve Ayarlar")
                .font(.title)
                .bold()
            
            Text("Çok Yakında")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
