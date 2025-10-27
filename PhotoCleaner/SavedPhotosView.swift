import SwiftUI
import Photos

struct SavedPhotosView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var selectedPhoto: Photo?
    @State private var isShowingDetail = false
    @Environment(\.scrollToTop) private var scrollToTop
    @State private var previousScrollToTop = false
    @State private var groupedPhotos: [String: [Photo]] = [:]
    @State private var sortedMonths: [String] = []
    @State private var expandedMonths: Set<String> = []
    @State private var isLoadingPhotos = false

    // 使用響應式網格，根據可用空間自動調整
    private let spacing: CGFloat = 4
    private let horizontalPadding: CGFloat = 16

    // 計算每個圖片的尺寸
    private var itemSize: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let totalHorizontalPadding = horizontalPadding * 2
        let totalSpacing = spacing * 2 // 3列需要2個間距
        let availableWidth = screenWidth - totalHorizontalPadding - totalSpacing
        return availableWidth / 3
    }

    private var columns: [GridItem] {
        [
            GridItem(.fixed(itemSize), spacing: spacing),
            GridItem(.fixed(itemSize), spacing: spacing),
            GridItem(.fixed(itemSize), spacing: spacing)
        ]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                Group {
                    if isLoadingPhotos {
                        loadingView
                    } else if photoManager.savedPhotos.isEmpty {
                        emptyStateView
                    } else {
                        photoGridContent
                    }
                }
            }
            .navigationTitle("Saved")
            .sheet(isPresented: $isShowingDetail) {
                if let photo = selectedPhoto {
                    PhotoDetailView(photo: photo)
                }
            }
        }
        .onAppear {
            print("SavedPhotosView出现")
            loadPhotosAsync()
        }
        .onChange(of: photoManager.savedPhotos) { _, _ in
            groupPhotosByMonth()
        }
        .onChange(of: scrollToTop) { oldValue, newValue in
            if newValue != previousScrollToTop {
                previousScrollToTop = newValue
                // 这里可以添加滚动到顶部的逻辑
                print("SavedPhotosView滚动到顶部")
            }
        }
    }
    
    // 加载视图
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading photos...")
                .font(.telkaSubheadline)
                .foregroundColor(.gray)
        }
    }

    // 提取空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.telkaRegular(size: 80))
                .foregroundColor(.gray)

            Text("No saved photos")
                .font(.telkaTitle2)
                .foregroundColor(.gray)
        }
    }
    
    // 提取照片网格内容
    private var photoGridContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(sortedMonths, id: \.self) { month in
                    if let photos = groupedPhotos[month], !photos.isEmpty {
                        monthSection(month: month, photos: photos)
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // 提取月份部分
    private func monthSection(month: String, photos: [Photo]) -> some View {
        let isExpanded = expandedMonths.contains(month)
        let displayPhotos = isExpanded ? photos : Array(photos.prefix(9))
        let hasMore = photos.count > 9
        
        return VStack(alignment: .leading, spacing: 8) {
            Text(month)
                .font(.telkaHeadline)
                .foregroundColor(.primary)
                .padding(.top, 12)

            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(displayPhotos) { photo in
                    PhotoThumbnail(photo: photo)
                        .frame(width: itemSize, height: itemSize)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedPhoto = photo
                            isShowingDetail = true
                        }
                }
            }

            if hasMore {
                Button(action: {
                    toggleMonthExpansion(month)
                }) {
                    HStack {
                        Text(isExpanded ? "Show less" : "Show more (\(photos.count - 9) more)")
                            .font(.telkaSubheadline)
                            .foregroundColor(.blue)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.telkaCaption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                .padding(.bottom, 12)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    private func toggleMonthExpansion(_ month: String) {
        if expandedMonths.contains(month) {
            expandedMonths.remove(month)
        } else {
            expandedMonths.insert(month)
        }
    }

    // ✅ 異步加載照片，不阻塞 UI
    private func loadPhotosAsync() {
        // 如果已經有數據，直接使用，不需要重新加載
        if !groupedPhotos.isEmpty {
            return
        }

        // 設置加載狀態
        isLoadingPhotos = true

        // 在背景線程處理照片分組
        DispatchQueue.global(qos: .userInitiated).async {
            self.groupPhotosByMonth()

            // 完成後更新 UI
            DispatchQueue.main.async {
                self.isLoadingPhotos = false
            }
        }
    }

    private func groupPhotosByMonth() {
        // 创建并配置日期格式化器（只创建一次）
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        
        // 按月份分组照片
        var groups: [String: [Photo]] = [:]
        
        for photo in photoManager.savedPhotos {
            if let date = photo.creationDate {
                let monthStr = formatter.string(from: date)
                if groups[monthStr] == nil {
                    groups[monthStr] = []
                }
                groups[monthStr]?.append(photo)
            }
        }
        
        // 对每个月内的照片按日期排序（从新到旧），并增加稳定性
        for (month, photos) in groups {
            groups[month] = photos.sorted { photo1, photo2 -> Bool in
                let date1 = photo1.creationDate ?? Date.distantPast
                let date2 = photo2.creationDate ?? Date.distantPast
                
                if date1 == date2 {
                    // 如果时间相同，使用ID保证排序稳定性
                    return photo1.id > photo2.id
                }
                return date1 > date2
            }
        }
        
        // 对月份进行排序（从新到旧），使用同一个格式化器解析日期
        let allMonths = Array(groups.keys)
        let sortedKeys = allMonths.sorted { key1, key2 -> Bool in
            // 如果格式化符合预期，月份格式一定是"yyyy年MM月"
            if let date1 = formatter.date(from: key1),
               let date2 = formatter.date(from: key2) {
                return date1 > date2
            }
            // 如果不能解析，退回到字符串比较
            return key1 > key2
        }
        
        DispatchQueue.main.async {
            self.groupedPhotos = groups
            self.sortedMonths = sortedKeys
        }
    }
}
