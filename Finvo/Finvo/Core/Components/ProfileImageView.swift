import SwiftUI

struct ProfileImageView: View {
    let photoURLString: String?

    var body: some View {
        CachedProfileImage(
            urlString: photoURLString,
            width: 36,
            height: 36,
            fallbackIconSize: 18
        )
    }
}

// MARK: - CachedProfileImage Component
struct CachedProfileImage: View {
    let urlString: String?
    let width: CGFloat
    let height: CGFloat
    let fallbackIconSize: CGFloat
    
    @State private var image: UIImage? = nil
    @State private var isLoading: Bool = false
    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(Circle())
            } else if isLoading {
                ProgressView()
                    .frame(width: width, height: height)
            } else {
                Circle()
                    .fill(theme.background2)
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: fallbackIconSize))
                            .foregroundColor(theme.labelSecondary)
                    )
            }
        }
        .frame(width: width, height: height)
        .clipShape(Circle())
        .onAppear {
            loadImage()
        }
        .onChange(of: urlString) { _, _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let urlString = urlString, !urlString.isEmpty else {
            self.image = nil
            return
        }
        
        // 1. Önce önbellekten (hafıza veya disk) deneyelim
        if let cachedImage = ImageCacheManager.shared.getImage(for: urlString) {
            self.image = cachedImage
            return
        }
        
        // 2. Yoksa internetten indirelim
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let downloadedImage = UIImage(data: data) {
                    ImageCacheManager.shared.saveImage(image: downloadedImage, for: urlString)
                    
                    await MainActor.run {
                        self.image = downloadedImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run { isLoading = false }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run { isLoading = false }
                }
            }
        }
    }
}
