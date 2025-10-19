import SwiftUI
import Photos

// 导入自定义样式
import UIKit

struct HomeView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var showPermissionAlert = false
    @State private var isRefreshing = false
    @State private var showEmptyAnimation = false
    @Environment(\.scrollToTop) private var scrollToTop
    @State private var previousScrollToTop = false
    
    init() {
        print("HomeView initialized")
    }
    
    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient
            
            VStack(spacing: 0) {
                // 标题栏
                titleBar
                
                // 相簿分类滚动条
                albumScrollView
                
                if photoManager.isLoading {
                    loadingView
                } else if photoManager.photos.isEmpty {
                    emptyStateView
                } else {
                    photosView
                }
            }
        }
        .onAppear {
            print("HomeView appeared, permission status: \(photoManager.hasPermission)")
            
            // 启动空状态动画
            withAnimation {
                showEmptyAnimation = true
            }
            
            if !photoManager.hasPermission {
                print("HomeView requesting permission")
                requestPhotoAccess()
            } else {
                if photoManager.albums.isEmpty {
                    // 加载相簿
                    photoManager.loadAlbums()
                }
                
                if photoManager.photos.isEmpty {
                    print("HomeView loading photos")
                    photoManager.loadPhotos()
                }
            }
        }
        .onChange(of: scrollToTop) { oldValue, newValue in
            if newValue != previousScrollToTop {
                previousScrollToTop = newValue
                // 这里可以添加滚动到顶部的逻辑
                // 例如使用ScrollViewReader或其他方式
                print("HomeView scroll to top")
            }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Photo Access Required"),
                message: Text("Please allow access to your photos in Settings to use this app."),
                primaryButton: .default(Text("Open Settings"), action: openSettings),
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }
    
    // MARK: - 子视图组件
    
    // 背景渐变
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(UIColor.systemBackground),
                Color(UIColor.systemBackground).opacity(0.95)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // 标题栏
    private var titleBar: some View {
        HStack {
            Text("Photo Filter")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .padding(.leading)
            
            Spacer()
            
            Button(action: {
                print("Manually requesting permission")
                withAnimation {
                    isRefreshing = true
                }
                
                // 添加触觉反馈
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                
                requestPhotoAccess()
                
                // 延迟结束刷新动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation {
                        isRefreshing = false
                    }
                }
            }) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
                    .rotationEffect(Angle(degrees: isRefreshing ? 360 : 0))
                    .animation(isRefreshing ? Animation.linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: isRefreshing)
            }
            .padding(.trailing)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    // 相簿分类滚动条
    private var albumScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 遍历所有相簿
                ForEach(photoManager.albums) { album in
                    AlbumButton(
                        album: album,
                        isSelected: photoManager.selectedAlbum?.id == album.id,
                        onTap: {
                            // 处理点击事件
                            if photoManager.selectedAlbum?.id != album.id {
                                withAnimation {
                                    photoManager.loadPhotosFromAlbum(album)
                                }
                                
                                // 添加触觉反馈
                                let impactMed = UIImpactFeedbackGenerator(style: .light)
                                impactMed.impactOccurred()
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
    }
    
    // 相簿按钮
    struct AlbumButton: View {
        let album: Album
        let isSelected: Bool
        let onTap: () -> Void
        
        // 添加按压状态
        @State private var isPressed: Bool = false
        
        var body: some View {
            VStack(spacing: 4) {
                // 相簿封面
                ZStack {
                    if let coverImage = album.coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 55, height: 55)
                            .cornerRadius(8)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 55, height: 55)
                        
                        if album.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 选中指示器
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue, lineWidth: 3)
                            .frame(width: 55, height: 55)
                    }
                }
                .scaleEffect(isPressed ? 0.95 : 1.0)
                
                // 相簿名称
                Text(album.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(1)
                
                // 照片数量
                Text("\(album.count)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)
            .contentShape(Rectangle()) // 确保整个区域可点击
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in self.isPressed = true }
                    .onEnded { _ in
                        self.isPressed = false
                        self.onTap()
                    }
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
    }
    
    // 加载视图
    private var loadingView: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                
                Text("Loading Photos...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
            )
            .padding(.horizontal, 20)
            Spacer()
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack {
            Spacer()
            VStack(spacing: 24) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 80))
                    .foregroundColor(.blue.opacity(0.8))
                    .padding()
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 150, height: 150)
                    )
                    .scaleEffect(showEmptyAnimation ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: showEmptyAnimation
                    )
                
                Text(photoManager.hasPermission ? "No More Photos" : "Photo Access Needed")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(photoManager.hasPermission ? "All photos have been processed" : "Please authorize access to your photo library to start filtering")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                if !photoManager.hasPermission {
                    permissionButton
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 15, x: 0, y: 8)
            )
            .padding(.horizontal, 20)
            Spacer()
        }
    }
    
    // 权限按钮
    private var permissionButton: some View {
        Button(action: {
            print("Permission button tapped")
            
            // 添加触觉反馈
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            requestPhotoAccess()
        }) {
            Text("Authorize Photos")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(16)
                .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(PressableButtonStyle())
        .padding(.top, 10)
    }
    
    // 照片视图
    private var photosView: some View {
        ZStack {
            // 只显示最新的2张照片作为背景，减少视图层级
            ForEach(Array(photoManager.photos.prefix(2).enumerated()), id: \.element.id) { index, photo in
                // 计算zIndex，确保最上面的卡片有最高的zIndex
                let zIndex = Double(2 - index)
                
                // 减小背景卡片的视觉效果，优化性能
                let yOffset = CGFloat(index) * -15 // 减小垂直偏移量
                let scale = index == 0 ? 1.0 : 0.92 // 只有第二张照片缩放
                
                createPhotoCardView(for: photo, index: index, zIndex: zIndex, yOffset: yOffset, scale: scale)
                    // 使用简单的不透明度过渡
                    .transition(.opacity)
            }
            
            // 只有当有照片时才显示覆盖在顶部照片上的操作按钮
            if let firstPhoto = photoManager.photos.first, !photoManager.photos.isEmpty {
                VStack {
                    Spacer()
                    
                    // 操作按钮
                    HStack(spacing: 60) {
                        // 删除按钮
                        Button(action: {
                            // 使用更轻的触觉反馈
                            let impactMed = UIImpactFeedbackGenerator(style: .light)
                            impactMed.impactOccurred()
                            
                            // 使用更简单的动画
                            withAnimation(.easeInOut(duration: 0.25)) {
                                photoManager.deletePhoto(firstPhoto)
                                photoManager.preloadNextPhotos()
                            }
                        }) {
                            CircleActionButton(imageName: "trash", backgroundColor: .red, foregroundColor: .white, size: 55)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 保存按钮
                        Button(action: {
                            // 使用更轻的触觉反馈
                            let impactMed = UIImpactFeedbackGenerator(style: .light)
                            impactMed.impactOccurred()
                            
                            // 使用更简单的动画
                            withAnimation(.easeInOut(duration: 0.25)) {
                                photoManager.savePhoto(firstPhoto)
                                photoManager.preloadNextPhotos()
                            }
                        }) {
                            CircleActionButton(imageName: "heart", backgroundColor: .green, foregroundColor: .white, size: 55)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.bottom, 30)
                }
                .zIndex(10) // 确保按钮在最上层
            }
        }
        .padding(.vertical)
        .onAppear {
            // 预加载图片
            preloadImages()
        }
    }
    
    // 创建照片卡片视图
    private func createPhotoCardView(for photo: Photo, index: Int, zIndex: Double, yOffset: CGFloat, scale: CGFloat) -> some View {
        PhotoCardView(
            photo: photo,
            onSave: {
                // 使用更轻的触觉反馈
                let impactMed = UIImpactFeedbackGenerator(style: .light)
                impactMed.impactOccurred()
                
                // 使用更简单的动画
                withAnimation(.easeInOut(duration: 0.25)) {
                    photoManager.savePhoto(photo)
                }
                
                // 预加载下一张照片
                photoManager.preloadNextPhotos()
            },
            onDelete: {
                // 使用更轻的触觉反馈
                let impactMed = UIImpactFeedbackGenerator(style: .light)
                impactMed.impactOccurred()
                
                // 使用更简单的动画
                withAnimation(.easeInOut(duration: 0.25)) {
                    photoManager.deletePhoto(photo)
                }
                
                // 预加载下一张照片
                photoManager.preloadNextPhotos()
            }
        )
        .padding(.bottom, 20)
        .zIndex(zIndex) // 确保正确的堆叠顺序
        .offset(y: yOffset) // 设置垂直偏移
        .scaleEffect(scale) // 设置缩放比例
        .blur(radius: index > 0 ? 1.0 : 0) // 对背景照片添加轻微模糊效果，但减少模糊强度
    }
    
    // 预加载图片
    private func preloadImages() {
        let cardWidth = UIScreen.main.bounds.width - 40
        let cardHeight = UIScreen.main.bounds.height * 0.6
        
        // 只加载第一张照片，后续照片延迟加载
        if let firstPhoto = photoManager.photos.first {
            photoManager.forceReloadImage(for: firstPhoto, size: CGSize(width: cardWidth, height: cardHeight)) { _ in
                // 图片加载完成后通知刷新
                print("First photo loaded")
                
                // 延迟1秒后再预加载下一张照片，减轻初始加载压力
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // 预加载第二张照片，但使用较低的优先级
                    if photoManager.photos.count > 1 {
                        let secondPhoto = photoManager.photos[1]
                        photoManager.loadImage(for: secondPhoto, size: CGSize(width: cardWidth, height: cardHeight)) { _ in
                            print("Second photo preloaded")
                        }
                    }
                }
            }
        }
        
        // 监听内存警告，清除不必要的缓存
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak photoManager] _ in
            print("Memory warning received, clearing unnecessary caches")
            // 清除远处的照片缓存，只保留即将展示的照片
            photoManager?.clearDistantPhotoCache()
        }
    }
    
    private func requestPhotoAccess() {
        print("Starting to request photo library permission")
        photoManager.requestPermission { granted in
            print("Photo permission request result: \(granted)")
            if granted {
                print("Permission granted, starting to load photos")
                photoManager.loadPhotos()
            } else {
                print("Permission denied, showing alert")
                showPermissionAlert = true
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // 美化后的圆形操作按钮
    struct CircleActionButton: View {
        let imageName: String
        let backgroundColor: Color
        let foregroundColor: Color
        let size: CGFloat
        
        @State private var isPressed: Bool = false
        
        var body: some View {
            ZStack {
                // 外部阴影效果
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .shadow(color: backgroundColor.opacity(0.5), radius: 10, x: 0, y: 5)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                
                // 内部渐变效果
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [backgroundColor.opacity(0.9), backgroundColor.opacity(1.2)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size - 4, height: size - 4)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                
                // 小粒子装饰效果
                ForEach(0..<5) { i in
                    Circle()
                        .fill(foregroundColor.opacity(0.1))
                        .frame(width: size * 0.15, height: size * 0.15)
                        .offset(
                            x: sin(Double(i) * 72.0 * .pi / 180) * size * 0.35,
                            y: cos(Double(i) * 72.0 * .pi / 180) * size * 0.35
                        )
                        .scaleEffect(isPressed ? 0.8 : 1.0)
                        .opacity(isPressed ? 0.5 : 0.6)
                }
                
                // 图标
                Image(systemName: imageName)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundColor(foregroundColor)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                
                // 高光效果
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: size * 0.9, height: size * 0.9)
                    .offset(x: -size * 0.12, y: -size * 0.12)
                    .blur(radius: 6)
                    .mask(
                        Circle()
                            .frame(width: size - 4, height: size - 4)
                    )
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                    .opacity(isPressed ? 0.5 : 0.8)
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.8), Color.white.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: size, height: size)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
            )
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in self.isPressed = true }
                    .onEnded { _ in 
                        self.isPressed = false
                    }
            )
        }
    }
} 