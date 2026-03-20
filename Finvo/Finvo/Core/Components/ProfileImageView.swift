import SwiftUI

struct ProfileImageView: View {
    let photoURL: URL?
    
    var body: some View {
        ZStack {
            if let photoURL = photoURL {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                        )
                }
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    )
            }
        }
        // Strict Frame Enforcer
        .frame(width: 36, height: 36)
        .clipShape(Circle())
        // Remove any potential button border style from navigation links
        .contentShape(Circle())
    }
}
