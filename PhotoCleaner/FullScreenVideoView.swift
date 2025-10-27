import SwiftUI
import Photos
import AVKit

struct FullScreenVideoView: View {
    let url: URL
    let photo: Photo
    @Environment(\.presentationMode) var presentationMode
    @State private var player: AVPlayer?
    @State private var isControlsVisible = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VideoPlayer(player: player ?? AVPlayer(url: url))
                .aspectRatio(contentMode: .fit)
                .edgesIgnoringSafeArea(.all)
                .onAppear {
                    // 创建播放器并自动播放
                    let playerItem = AVPlayerItem(url: url)
                    player = AVPlayer(playerItem: playerItem)
                    
                    // 设置播放器属性
                    player?.automaticallyWaitsToMinimizeStalling = false
                    
                    // 预加载并播放视频
                    Task {
                        do {
                            try await playerItem.asset.load(.isPlayable)
                            if playerItem.asset.isPlayable {
                                player?.play()
                            }
                        } catch {
                            print("视频加载失败: \(error.localizedDescription)")
                        }
                    }
                    
                    // 添加播放结束通知，实现循环播放
                    NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: playerItem,
                        queue: .main
                    ) { [weak player] _ in
                        player?.seek(to: .zero)
                        player?.play()
                    }
                    
                    // 3秒后隐藏控制界面
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            isControlsVisible = false
                        }
                    }
                }
                .onDisappear {
                    // 移除通知观察者
                    NotificationCenter.default.removeObserver(
                        self,
                        name: .AVPlayerItemDidPlayToEndTime,
                        object: player?.currentItem
                    )
                    player?.pause()
                    player = nil
                }
                .onTapGesture {
                    withAnimation {
                        isControlsVisible.toggle()
                    }
                    
                    // 如果显示控制界面，3秒后自动隐藏
                    if isControlsVisible {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                isControlsVisible = false
                            }
                        }
                    }
                }
            
            // 控制界面
            if isControlsVisible {
                VStack {
                    HStack {
                        Button(action: {
                            // 停止播放并关闭视图
                            player?.pause()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.telkaBold(size: 20))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        Text(photo.formattedDuration)
                            .font(.telkaMedium(size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(15)
                            .padding(.trailing, 20)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(photo.formattedDate)
                            .font(.telkaMedium(size: 16))
                            .foregroundColor(.white)
                        
                        Text(photo.formattedLocation)
                            .font(.telkaMedium(size: 16))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.7), .black.opacity(0)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
                .transition(.opacity)
            }
        }
    }
} 