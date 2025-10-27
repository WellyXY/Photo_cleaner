import SwiftUI
import Photos

struct PhotoThumbnail: View {
    let photo: Photo
    @State private var image: UIImage?
    @State private var isLoading = true
    @EnvironmentObject var photoManager: PhotoManager
    
    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: (UIScreen.main.bounds.width - 40) / 3, height: (UIScreen.main.bounds.width - 40) / 3)
                    .cornerRadius(8)
                    .clipped()
                
                // 视频指示器（如果是视频）
                if photo.mediaType == .video {
                    VStack {
                            Spacer()
                        HStack {
                            Image(systemName: "video.fill")
                                .font(.telkaRegular(size: 10))
                                .foregroundColor(.white)
                            Text(photo.formattedDuration)
                                .font(.telkaRegular(size: 10))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(4)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: (UIScreen.main.bounds.width - 40) / 3, height: (UIScreen.main.bounds.width - 40) / 3)
                    .cornerRadius(8)
                
                if isLoading {
                ProgressView()
                        .scaleEffect(0.7)
                }
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        isLoading = true
        
        // 首先检查缓存
        let size = CGSize(width: 200, height: 200)
        let cacheKey = NSString(string: "\(photo.asset.localIdentifier)_200x200")
        
        if let cachedImage = photoManager.imageCache.object(forKey: cacheKey) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        // 如果缓存中没有，使用更可靠的加载方式
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .exact
        
        manager.requestImage(
            for: photo.asset,
            targetSize: CGSize(width: size.width * UIScreen.main.scale, 
                              height: size.height * UIScreen.main.scale),
            contentMode: .aspectFill,
            options: options
        ) { result, info in
            DispatchQueue.main.async {
            if let image = result {
                    // 缓存图片
                    photoManager.imageCache.setObject(image, forKey: cacheKey)
                self.image = image
                }
                self.isLoading = false
            }
        }
    }
} 