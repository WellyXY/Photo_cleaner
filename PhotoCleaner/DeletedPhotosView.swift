import SwiftUI
import Photos

struct DeletedPhotosView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var selectedPhoto: Photo?
    @State private var isShowingDetail = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @Environment(\.scrollToTop) private var scrollToTop
    @State private var previousScrollToTop = false
    @State private var showDeletedMessage = false
    @State private var groupedPhotos: [String: [Photo]] = [:]
    @State private var sortedMonths: [String] = []
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                if photoManager.deletedPhotos.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "trash.slash")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                            .padding(.bottom, 8)
                        
                        Text("No Deleted Photos")
                            .font(.title2.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Text("Items you delete will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(sortedMonths, id: \.self) { month in
                                if let photos = groupedPhotos[month], !photos.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(month)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .padding(.leading, 16)
                                            .padding(.top, 6)
                                        
                                        LazyVGrid(columns: columns, spacing: 12) {
                                            ForEach(photos) { photo in
                                PhotoThumbnail(photo: photo)
                                                    .aspectRatio(1, contentMode: .fill)
                                                    .cornerRadius(12)
                                                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                                    )
                                    .onTapGesture {
                                        selectedPhoto = photo
                                        isShowingDetail = true
                                    }
                                    .overlay(
                                                        ZStack {
                                                            Circle()
                                                                .fill(Color.red)
                                                                .frame(width: 28, height: 28)
                                                            
                                        Image(systemName: "trash.fill")
                                                                .font(.system(size: 12))
                                            .foregroundColor(.white)
                                                        }
                                                        .padding(6),
                                        alignment: .topTrailing
                                    )
                            }
                        }
                                        .padding(.horizontal, 16)
                                    }
                                    .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
                                    .cornerRadius(12)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        // Add pull-to-refresh capability
                        photoManager.loadDeletedPhotos {
                            groupPhotosByMonth()
                        }
                    }
                }
                
                if isDeleting {
                    BlurView(style: .systemMaterial)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.bottom, 8)
                        
                        Text("Deleting...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .frame(width: 150, height: 150)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(20)
                        .shadow(radius: 10)
                }
                
                if showDeletedMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text("Successfully deleted")
                            .font(.subheadline.weight(.medium))
            }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color(.secondarySystemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        // Auto-hide after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation(.easeInOut) {
                                showDeletedMessage = false
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                
                // Bottom Remove Items button
                if !photoManager.deletedPhotos.isEmpty {
                    VStack {
                        Spacer()
                        
                        Button {
                            // Check if we already have deletion permission
                            let hasDeletePermission = UserDefaults.standard.bool(forKey: "PhotoDeletePermissionGranted")
                            if hasDeletePermission {
                                // Direct delete if we have permission
                                deleteAllPhotos()
                            } else {
                                // First use, show confirmation
                                showingDeleteConfirmation = true
                            }
                        } label: {
                            Text("Remove Items")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 34) // Safe area padding
                    }
                }
            }
            .navigationTitle("Deleted")
            .sheet(isPresented: $isShowingDetail) {
                if let photo = selectedPhoto {
                    PhotoDetailView(photo: photo)
                }
            }
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Confirm Deletion"),
                    message: Text("Are you sure you want to permanently delete these photos? This action cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        deleteAllPhotos()
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            }
        }
        .onAppear {
            print("DeletedPhotosView appeared")
            groupPhotosByMonth()
        }
        .onChange(of: photoManager.deletedPhotos) { _, _ in
            groupPhotosByMonth()
        }
        .onChange(of: scrollToTop) { oldValue, newValue in
            if newValue != previousScrollToTop {
                previousScrollToTop = newValue
                // Logic to scroll to top could be added here
                print("DeletedPhotosView scroll to top")
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
        
        for photo in photoManager.deletedPhotos {
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
    
    private func deleteAllPhotos() {
        // If no photos, just return
        if photoManager.deletedPhotos.isEmpty {
            return
        }
        
        isDeleting = true
        // Extract all deleted photo IDs
        let photoIds = photoManager.deletedPhotos.map { $0.id }
        
        photoManager.permanentlyDeletePhotos(photoIds: photoIds) { success in
            isDeleting = false
            if success {
                // Show success indicator
                withAnimation(.spring()) {
                    showDeletedMessage = true
                }
                print("All photos permanently deleted")
                // 清空分组
                self.groupedPhotos = [:]
                self.sortedMonths = []
            } else {
                // Error handling could be added here
                print("Error deleting photos")
            }
        }
    }
}

// Blur view helper for overlay effects
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}



