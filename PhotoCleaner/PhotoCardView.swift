import SwiftUI
import Photos
import UIKit
import AVKit

struct PhotoCardView: View {
    let photo: Photo
    let onSave: () -> Void
    let onDelete: () -> Void
    
    @EnvironmentObject var photoManager: PhotoManager
    @State private var offset = CGSize.zero
    @State private var image: UIImage?
    @State private var videoURL: URL?
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var scale: CGFloat = 1.0
    @State private var swipeOverlayOpacity: CGFloat = 0
    @State private var cardRotation: Double = 0
    @State private var showFullScreen = false
    @State private var videoPlayer: AVPlayer?
    @State private var isVideoPlaying = false
    @State private var isVisible = false
    @State private var videoLoadTimer: DispatchWorkItem?
    @State private var player: AVPlayer?
    @State private var durationText = ""
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width - 40
    private let cardHeight: CGFloat = UIScreen.main.bounds.height * 0.6
    private let threshold: CGFloat = 100
    private let rotationMax: Double = 12.0
    private let scaleRange: CGFloat = 0.08
    
    // 计算属性用于图片大小
    private var size: CGSize {
        return CGSize(width: cardWidth, height: cardHeight)
    }
    
    // 添加 init 检查传入的 Photo
    init(photo: Photo, onSave: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.photo = photo
        self.onSave = onSave
        self.onDelete = onDelete
        // 确保初始状态是加载中
        _isLoading = State(initialValue: true)
        _loadError = State(initialValue: nil)
        _image = State(initialValue: nil)
        _videoURL = State(initialValue: nil)
        _videoPlayer = State(initialValue: nil)
        _isVideoPlaying = State(initialValue: false)
        _isVisible = State(initialValue: false)
        _offset = State(initialValue: .zero)
        _scale = State(initialValue: 1.0)
        _swipeOverlayOpacity = State(initialValue: 0)
        _cardRotation = State(initialValue: 0)
        _showFullScreen = State(initialValue: false)
        _videoLoadTimer = State(initialValue: nil)
        _player = State(initialValue: nil)
        _durationText = State(initialValue: "")

        // ⚠️ 移除重複的日誌，減少控制台輸出
        // print("PhotoCardView init for photo ID: \(photo.id)")
    }
    
    private var swipeDirection: SwipeDirection {
        if offset.width > threshold {
            return .right
        } else if offset.width < -threshold {
            return .left
        } else {
            return .none
        }
    }
    
    private enum SwipeDirection {
        case left, right, none
    }
    
    var body: some View {
        // 移除調試日誌以提升性能
        // let _ = print("PhotoCardView body for photo ID: \(photo.id) - isLoading: \(isLoading), loadError: \(loadError != nil), image is nil: \(image == nil), videoURL is nil: \(videoURL == nil), isVideoPlaying: \(isVideoPlaying)")

        ZStack {
            if isLoading {
                loadingView
            } else if loadError != nil {
                errorView
            } else if let image = image {
                if photo.mediaType == .video {
                    videoCardView()
                } else {
                    cardView(image: image)
                }
            }
        }
        .onAppear {
            isVisible = true
            loadMedia()
            
            // 启动视频加载计时器
            if photo.mediaType == .video {
                videoLoadTimer = DispatchWorkItem {
                    if isVisible {
                        loadVideoContent()
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: videoLoadTimer!)
            }
        }
        .onDisappear {
            resetState()
        }
        .onChange(of: photo.id) { oldId, newId in
            print("PhotoCardView photo ID changed from \(oldId) to \(newId)")
            // 重置状态并重新加载
            resetStateAndLoad()
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let image = image, photo.mediaType == .photo {
                FullScreenPhotoView(image: image, photo: photo)
            } else if photo.mediaType == .video, let videoURL = videoURL {
                FullScreenVideoView(url: videoURL, photo: photo)
            }
        }
    }
    
    // 新增：重置状态并加载新照片的方法
    private func resetStateAndLoad() {
        print("PhotoCardView resetting state for photo ID: \(photo.id)")
        // 重置所有相关状态
        offset = .zero
        image = nil
        videoURL = nil
        isLoading = true
        loadError = nil
        scale = 1.0
        swipeOverlayOpacity = 0
        cardRotation = 0
        showFullScreen = false
        videoPlayer?.pause()
        videoPlayer = nil
        isVideoPlaying = false
        videoLoadTimer?.cancel()
        videoLoadTimer = nil
        player?.pause()
        player = nil
        durationText = ""
        
        // 重新加载媒体
        loadMedia()
        
        // 重新设置视频加载计时器，减少延迟时间
        if photo.mediaType == .video {
            videoLoadTimer = DispatchWorkItem {
                if isVisible {
                    loadVideoContent()
                }
            }
            // 减少延迟时间到0.1秒，接近即时加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: videoLoadTimer!)
        }
    }
    
    private func loadMedia() {
        isLoading = true
        loadError = nil
        
        if photo.mediaType == .video {
            print("为视频加载缩略图: \(photo.id), \(photo.asset.localIdentifier)")
            loadVideo()
        } else {
            print("为照片加载图片: \(photo.id), \(photo.asset.localIdentifier)")
            loadImage()
        }
    }
    
    private func loadImage() {
        // 先检查缓存，如果已有缓存则立即显示，避免重新加载
        let cacheKey = NSString(string: "\(photo.id)_\(Int(size.width))x\(Int(size.height))")
        if let cachedImage = photoManager.imageCache.object(forKey: cacheKey) {
            print("PhotoCardView found cached image immediately for: \(photo.id)")
            // 直接設置，不使用 async，避免狀態延遲
            self.image = cachedImage
            self.isLoading = false
            return
        }

        // 使用缓存友好的加载方式，先显示缩略图，随后逐步提升清晰度
        // 捕获当前 photo id，避免在闭包中直接访问 self
        let currentPhotoId = photo.id
        let currentSize = self.size

        photoManager.loadImage(for: photo, size: currentSize) { image in
            DispatchQueue.main.async {
                // 再次检查缓存，防止重复加载
                if let cachedImage = self.photoManager.imageCache.object(forKey: cacheKey) {
                    self.image = cachedImage
                    self.isLoading = false
                    return
                }

                if let image = image {
                    self.image = image
                    self.isLoading = false
                } else {
                    self.loadError = "加载失败"
                    self.isLoading = false
                }
            }

            // 确保下一张照片也开始加载 - 在後台執行
            DispatchQueue.global(qos: .utility).async {
                if self.photoManager.filteredPhotos.count > 1 {
                    let index = self.photoManager.filteredPhotos.firstIndex { $0.id == currentPhotoId } ?? 0
                    let nextIndex = (index + 1) % self.photoManager.filteredPhotos.count
                    if nextIndex < self.photoManager.filteredPhotos.count {
                        let nextPhoto = self.photoManager.filteredPhotos[nextIndex]
                        // 预加载下一张
                        self.photoManager.loadImage(for: nextPhoto, size: currentSize) { _ in }
                    }
                }
            }
        }
    }
    
    private func loadVideo() {
        // 先检查缓存，如果已有缓存则立即显示
        let cacheKey = NSString(string: "video_\(photo.id)_\(Int(size.width))x\(Int(size.height))")
        if let cachedImage = photoManager.imageCache.object(forKey: cacheKey) {
            print("PhotoCardView found cached video thumbnail immediately for: \(photo.id)")
            // 直接設置，不使用 async
            self.image = cachedImage
            self.durationText = photo.formattedDuration
            self.isLoading = false
            self.loadVideoURL()
            return
        }

        // 使用强制重载机制加载视频缩略图，绕过缓存问题
        let currentSize = self.size
        let formattedDuration = photo.formattedDuration

        photoManager.loadThumbnailForVideo(photo, size: currentSize) { image in
            DispatchQueue.main.async {
                if let image = image {
                    withAnimation {
                        self.image = image
                        self.durationText = formattedDuration
                        // 继续加载视频URL
                        self.loadVideoURL()
                    }
                } else {
                    withAnimation {
                        self.loadError = "加载失败"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func loadVideoURL() {
        // 不需要guard，因为photo不是可选类型
        
        photoManager.loadVideoURL(for: photo) { url in
            DispatchQueue.main.async {
                if let url = url {
                    self.videoURL = url
                    if self.isVisible {
                        self.setupPlayer() // 修改为已存在的方法名
                    }
                }
                self.isLoading = false
            }
        }
    }
    
    private func setupPlayer() {
        if let url = videoURL {
            let player = AVPlayer(url: url)
            self.player = player
            player.automaticallyWaitsToMinimizeStalling = false
            player.volume = 0
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem,
                queue: .main
            ) { _ in
                player.seek(to: .zero)
                player.play()
            }
            
            if isVisible {
                player.play()
                isVideoPlaying = true
            }
        }
    }
    
    private func loadVideoContent() {
        guard photo.mediaType == .video, videoURL == nil, isVisible else { 
            print("PhotoCardView loadVideoContent skipped for ID: \(photo.id). Reason: isVideo=\(photo.mediaType == .video), videoURLNil=\(videoURL == nil), isVisible=\(isVisible)")
            return 
        }
        
        print("PhotoCardView loadVideoContent - Loading video URL for ID: \(photo.id)")
        DispatchQueue.global(qos: .userInteractive).async {
            self.photoManager.loadVideoURL(for: self.photo) { url in
                guard self.isVisible else { 
                    print("PhotoCardView loadVideoContent (URL) - Stale request or view not visible for ID: \(self.photo.id)")
                    return 
                }
                
                DispatchQueue.main.async {
                    if let url = url {
                        print("PhotoCardView loadVideoContent (URL) - URL loaded successfully for ID: \(self.photo.id): \(url)")
                        self.videoURL = url
                        
                        let playerItem = AVPlayerItem(url: url)
                        let player = AVPlayer(playerItem: playerItem)
                        self.player = player
                        player.automaticallyWaitsToMinimizeStalling = false
                        player.volume = 0
                        
                        playerItem.preferredForwardBufferDuration = 1.0
                        
                        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: playerItem)
                        NotificationCenter.default.addObserver(
                            forName: .AVPlayerItemDidPlayToEndTime,
                            object: playerItem,
                            queue: .main
                        ) { _ in
                            guard self.isVisible else { return }
                            print("PhotoCardView video loop for ID: \(self.photo.id)")
                            player.seek(to: .zero)
                            player.play()
                        }
                        
                        print("PhotoCardView loadVideoContent - Auto playing video for ID: \(self.photo.id)")
                        if self.isVisible {
                            player.play()
                            self.isVideoPlaying = true
                        }
                        
                        self.isLoading = false
                    } else {
                        print("PhotoCardView loadVideoContent (URL) - URL loading failed for ID: \(self.photo.id)")
                        self.loadError = "URL加载失败"
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func resetSwipeState() {
        offset = .zero
        scale = 1.0
        swipeOverlayOpacity = 0
        cardRotation = 0
    }
    
    private func resetState() {
        videoPlayer?.pause()
        videoPlayer = nil
        resetSwipeState()
        
        photoManager.removeCacheForPhoto(photo)
    }
    
    private var loadingView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(width: cardWidth, height: cardHeight)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle())
        }
    }
    
    private var errorView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.secondarySystemBackground))
                .frame(width: cardWidth, height: cardHeight)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                    .font(.telkaRegular(size: 40))
                .foregroundColor(.orange)
                
                Text(loadError ?? "加载失败")
                    .font(.telkaHeadline)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private func deleteIconView(offsetWidth: CGFloat) -> some View {
        Group {
            if offsetWidth < -5 {
                HStack {
                    Spacer()
                    SwipeActionView(
                        actionType: .archive,
                        opacity: min(abs(offsetWidth) / threshold, 1.0)
                    )
                    .padding(.trailing, 20)
                }
                .frame(width: cardWidth + 120)
            }
        }
    }
    
    private func saveIconView(offsetWidth: CGFloat) -> some View {
        Group {
            if offsetWidth > 5 {
                HStack {
                    SwipeActionView(
                        actionType: .keep,
                        opacity: min(abs(offsetWidth) / threshold, 1.0)
                    )
                    .padding(.leading, 20)
                    Spacer()
                }
                .frame(width: cardWidth + 120)
            }
        }
    }

    private func cardView(image: UIImage) -> some View {
        let dragGesture = DragGesture()
            .onChanged { gesture in
                offset = gesture.translation
                
                let dragWidth = gesture.translation.width
                cardRotation = min(max((dragWidth / 600) * rotationMax, -rotationMax), rotationMax)
                
                let progress = min(abs(dragWidth) / threshold, 1.0)
                scale = 1.0 + (scaleRange * 0.5 * progress)
                
                swipeOverlayOpacity = progress * 0.6
            }
            .onEnded { gesture in
                let swipeWidth = gesture.translation.width
                
                if abs(swipeWidth) > threshold {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = CGSize(width: swipeWidth > 0 ? cardWidth * 1.5 : -cardWidth * 1.5, height: 0)
                        cardRotation = swipeWidth > 0 ? rotationMax : -rotationMax
                        scale = 0.9
                        swipeOverlayOpacity = 0
                    }
                    
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if swipeWidth > 0 {
                            onSave()
                        } else {
                            onDelete()
                        }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = .zero
                        cardRotation = 0
                        scale = 1.0
                        swipeOverlayOpacity = 0
                    }
                }
            }
        
        let mainCardView = ZStack(alignment: .center) {
            // 主圖片層：固定卡片尺寸，鋪滿並裁切
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                )
                .overlay(
                    ZStack {
                        if swipeDirection == .left {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.red.opacity(swipeOverlayOpacity))
                        } else if swipeDirection == .right {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.green.opacity(swipeOverlayOpacity))
                        }
                    }
                )
                
            if photo.mediaType == .video {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(.white)
                            .font(.telkaMedium(size: 16))
                        
                        Text(photo.formattedDuration)
                            .font(.telkaMedium(size: 14))
                            .foregroundColor(.white)
                            
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(16)
                    .padding([.horizontal, .bottom], 12)
                }
            }
        }
        
        return mainCardView
            .overlay(deleteIconView(offsetWidth: offset.width))
            .overlay(saveIconView(offsetWidth: offset.width))
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            .offset(x: offset.width, y: offset.height)
            .scaleEffect(scale)
            .rotationEffect(.degrees(cardRotation), anchor: .bottom)
            .gesture(dragGesture)
            .onTapGesture {
                showFullScreen = true
            }
    }
    
    private func videoCardView() -> some View {
        let dragGesture = DragGesture()
            .onChanged { gesture in
                offset = gesture.translation
                let dragWidth = gesture.translation.width
                cardRotation = min(max((dragWidth / 600) * rotationMax, -rotationMax), rotationMax)
                let progress = min(abs(dragWidth) / threshold, 1.0)
                scale = 1.0 + (scaleRange * 0.5 * progress)
                swipeOverlayOpacity = progress * 0.6
            }
            .onEnded { gesture in
                let swipeWidth = gesture.translation.width
                
                if abs(swipeWidth) > threshold {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = CGSize(width: swipeWidth > 0 ? cardWidth * 1.5 : -cardWidth * 1.5, height: 0)
                        cardRotation = swipeWidth > 0 ? rotationMax : -rotationMax
                        scale = 0.9
                        swipeOverlayOpacity = 0
                    }
                    
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if swipeWidth > 0 {
                            onSave()
                        } else {
                            onDelete()
                        }
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        offset = .zero
                        cardRotation = 0
                        scale = 1.0
                        swipeOverlayOpacity = 0
                    }
                }
            }
        
        let videoContentView = ZStack(alignment: .center) {
            if let player = player {
                // VideoPlayer 固定卡片尺寸
                VideoPlayer(player: player)
                    .frame(width: cardWidth, height: cardHeight)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .overlay(
                        ZStack {
                            if swipeDirection == .left {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.red.opacity(swipeOverlayOpacity))
                            } else if swipeDirection == .right {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.green.opacity(swipeOverlayOpacity))
                            }
                        }
                    )

                // 視頻信息覆蓋層
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                        Text(durationText)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        Spacer()
                        Text(photo.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding([.horizontal, .bottom], 12)
                }
            } else if let image = image {
                // 視頻縮略圖：固定卡片尺寸，鋪滿並裁切
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                    .overlay(
                        ZStack {
                            if swipeDirection == .left {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.red.opacity(swipeOverlayOpacity))
                            } else if swipeDirection == .right {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.green.opacity(swipeOverlayOpacity))
                            }
                        }
                    )
                    .overlay(
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 60, height: 60)
                            Image(systemName: "play.fill")
                                .font(.telkaRegular(size: 24))
                                .foregroundColor(.white)
                        }
                    )

                // 視頻信息
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "video.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 14))
                        Text(durationText)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                        Spacer()
                        Text(photo.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding([.horizontal, .bottom], 12)
                }
            }
        }
        
        return videoContentView
            .overlay(deleteIconView(offsetWidth: offset.width))
            .overlay(saveIconView(offsetWidth: offset.width))
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
            .offset(x: offset.width, y: offset.height)
            .scaleEffect(scale)
            .rotationEffect(.degrees(cardRotation), anchor: .bottom)
            .gesture(dragGesture)
            .onTapGesture {
                showFullScreen = true
            }
    }
    
    private func getSwipeShadowColor() -> Color {
        switch swipeDirection {
        case .left:
            return Color.red.opacity(0.5)
        case .right:
            return Color.green.opacity(0.5)
        case .none:
            return Color.black.opacity(0.1)
        }
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
} 