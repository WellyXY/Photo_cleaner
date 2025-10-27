import SwiftUI
import Photos

struct PhotoDetailView: View {
    let photo: Photo
    @EnvironmentObject var photoManager: PhotoManager
    @Environment(\.presentationMode) var presentationMode
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var showInfo = true
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var showingSaveAlert = false
    @State private var saveSuccess = false
    
    var isFromDeletedPhotos: Bool {
        return photo.status == .deleted
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // 图片视图
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = min(max(scale * delta, 1), 4)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                scale = scale > 1 ? 1 : 2
                                if scale == 1 {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                } else {
                    Image(systemName: "photo.fill")
                        .font(.telkaRegular(size: 40))
                        .foregroundColor(.gray)
                }
                
                // 信息覆盖层
                VStack {
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.telkaTitle2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(.leading)
                        
                        Spacer()
                        
                        if isFromDeletedPhotos {
                            Button(action: {
                                savePhotoFromDeleted()
                            }) {
                                Image(systemName: "arrow.uturn.backward.circle")
                                    .font(.telkaTitle2)
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Circle().fill(Color.green.opacity(0.7)))
                            }
                            .padding(.trailing, 8)
                        }
                        
                        Button(action: {
                            withAnimation {
                                showInfo.toggle()
                            }
                        }) {
                            Image(systemName: showInfo ? "info.circle.fill" : "info.circle")
                                .font(.telkaTitle2)
                                .foregroundColor(.white)
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .padding(.trailing)
                    }
                    .padding(.top, geometry.safeAreaInsets.top)
                    
                    Spacer()
                    
                    if showInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(photo.formattedDate)
                                .font(.telkaMedium(size: 16))
                            Text(photo.formattedLocation)
                                .font(.telkaRegular(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.black.opacity(0.7),
                                    Color.black.opacity(0)
                                ]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .transition(.move(edge: .bottom))
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .onAppear {
            // 确保位置信息已加载
            photoManager.loadPhotoLocation(for: photo)
            loadFullImage()
        }
        .alert(isPresented: $showingSaveAlert) {
            if saveSuccess {
                return Alert(
                    title: Text("已恢复"),
                    message: Text("照片已从已删除列表恢复"),
                    dismissButton: .default(Text("确定")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            } else {
                return Alert(
                    title: Text("恢复失败"),
                    message: Text("无法恢复该照片"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
    
    private func savePhotoFromDeleted() {
        if isFromDeletedPhotos {
            // 将照片从已删除列表移动到已保存列表
            photoManager.movePhotoFromDeletedToSaved(photo)
            saveSuccess = true
            showingSaveAlert = true
        }
    }
    
    private func loadFullImage() {
        isLoading = true
        
        // 使用屏幕尺寸的2倍作为高质量图片尺寸，避免 PHImageManagerMaximumSize 的缓存问题
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(
            width: max(screenSize.width, screenSize.height) * 2,
            height: max(screenSize.width, screenSize.height) * 2
        )
        
        // 使用 PhotoManager 的缓存加载方法
        photoManager.loadImage(for: photo, size: targetSize) { image in
            DispatchQueue.main.async {
                if let image = image {
                    self.image = image
                    self.isLoading = false
                } else {
                    // 如果第一次加载失败，尝试强制重新加载
                    print("First load failed for photo \(self.photo.id), attempting force reload...")
                    self.photoManager.forceReloadImage(for: self.photo, size: targetSize) { retryImage in
                        DispatchQueue.main.async {
                            if let retryImage = retryImage {
                                self.image = retryImage
                            } else {
                                // 如果还是失败，显示占位图
                                self.image = UIImage(systemName: "photo.fill")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                            }
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }
} 