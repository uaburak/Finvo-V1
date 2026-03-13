import SwiftUI

struct NotificationsView: View {
    var body: some View {
        VStack {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .padding()
            
            Text("Bildirimler")
                .font(.title)
                .bold()
            
            Text("Henüz yeni bildiriminiz yok.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsView()
    }
}
