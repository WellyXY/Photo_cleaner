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
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                
                Group {
                if photoManager.savedPhotos.isEmpty {
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
            groupPhotosByMonth()
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
    
    // 提取空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No saved photos")
                .font(.title2)
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
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.leading, 16)
                .padding(.top, 6)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(displayPhotos) { photo in
                    PhotoThumbnail(photo: photo)
                        .aspectRatio(1, contentMode: .fill)
                        .cornerRadius(10)
                        .onTapGesture {
                            selectedPhoto = photo
                            isShowingDetail = true
                        }
                }
            }
            .padding(.horizontal, 16)
            
            if hasMore {
                Button(action: {
                    toggleMonthExpansion(month)
                }) {
                    HStack {
                        Text(isExpanded ? "Show less" : "Show more (\(photos.count - 9) more)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
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
