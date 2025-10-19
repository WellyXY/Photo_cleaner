import SwiftUI
import Photos
import UIKit

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

// 将 ScaleButtonStyle 移到所有视图外部，使其全局可用
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
            .brightness(configuration.isPressed ? -0.05 : 0)
    }
}

struct HomeView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showPermissionAlert = false
    @State private var isRefreshing = false
    @State private var showLimitReached = false
    @Environment(\.scrollToTop) private var scrollToTop
    @State private var previousScrollToTop = false
    @State private var showAllFiltersSheet = false // 控制显示所有筛选器页面的变量
    @State private var isFilterChanging = false // 追踪筛选器切换状态
    @State private var filterBackgroundCache: [String: UIImage] = [:] // 缓存筛选器背景
    @GestureState private var dragOffset: CGFloat = 0 // 跟踪滑动手势偏移量
    
    // 日期格式化器
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy" // 例如: Dec 2023
        return formatter
    }()
    
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
                
                // 状态栏 (仅对免费用户显示)
                if !purchaseManager.hasUnlockedPro {
                    freeUserStatusBar
                }
                
                // 新的筛选器滚动条
                filterScrollView
                
                // 主内容区域 (根据加载状态和筛选结果显示)
                if photoManager.isLoading && photoManager.filteredPhotos.isEmpty {
                    // 只有在首次加载且没有照片时才显示加载视图
                    loadingView
                } else if !photoManager.isLoading && photoManager.filteredPhotos.isEmpty {
                    // 非加载状态、没有照片时显示空视图
                    emptyStateView(isPermissionGranted: photoManager.hasPermission)
                } else {
                    // 有照片或正在切换筛选器时显示照片视图，保持原有卡片
                    ZStack {
                        photosView
                        
                        // 筛选器切换时的加载动画覆盖层
                        if photoManager.isLoading && !photoManager.filteredPhotos.isEmpty {
                            Color.black.opacity(0.3)
                                .edgesIgnoringSafeArea(.all)
                                .overlay(
                                    VStack {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .tint(.white)
                                        Text("Loading...")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.top, 8)
                                    }
                                )
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.3), value: photoManager.isLoading)
                        }
                    }
                }
            }
        }
        // 添加照片区域的滑动手势，用于切换筛选器
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    // 只有在有足够的水平滑动时才切换
                    if abs(value.translation.width) > 80 {
                        if value.translation.width < 0 {
                            // 向左滑动，切换到下一个
                            switchToNextFilter()
                        } else {
                            // 向右滑动，切换到上一个
                            switchToPreviousFilter()
                        }
                    }
                }
        )
        .onAppear {
            print("HomeView appeared, permission status: \(photoManager.hasPermission)")
            
            if !photoManager.hasPermission {
                print("HomeView requesting permission")
                requestPhotoAccess()
            } else {
                // 如果有权限，并且 filteredPhotos 为空 (可能是首次加载或之前的筛选结果为空)
                // 则调用 loadInitialPhotos (它内部会处理加载逻辑)
                if photoManager.filteredPhotos.isEmpty && photoManager.currentFilter == nil {
                    print("HomeView requesting initial photo load")
                    photoManager.loadInitialPhotos()
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
                print("Refresh button tapped")
                withAnimation { isRefreshing = true }
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                
                // 刷新逻辑：重新加载当前筛选器的数据
                if photoManager.hasPermission {
                    if let currentFilter = photoManager.currentFilter {
                        print("Refreshing filter: \(currentFilter)")
                        photoManager.loadPhotos(for: currentFilter)
                    } else {
                        print("Refreshing initial load")
                        photoManager.loadInitialPhotos() // 如果没有当前 filter，则重新初始加载
                    }
                } else {
                    requestPhotoAccess()
                }
                
                // 延迟结束刷新动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { isRefreshing = false }
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
    
    // 新的筛选器滚动条
    private var filterScrollView: some View {
        ZStack {
            VStack(spacing: 0) {
                Divider()
                    .opacity(0.5)
                
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // 年月筛选按钮
                            ForEach(photoManager.availableMonths) { monthData in
                                let filter = FilterType.monthYear(data: monthData)
                                let key = "month_\(monthData.year)_\(monthData.month)"
                                let filterId = "filter_\(key)"
                                EnhancedFilterButton(
                                    filterType: filter,
                                    title: monthYearString(year: monthData.year, month: monthData.month),
                                    isSelected: photoManager.currentFilter == filter,
                                    backgroundImage: getOrCacheFilterBackground(key: key, generator: {
                                        getFirstPhotoForMonth(year: monthData.year, month: monthData.month)
                                    }),
                                    onTap: {
                                        smoothFilterChange(to: filter)
                                    }
                                )
                                .id(filterId) // 添加ID用于滚动定位
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .frame(height: 100)
                    // 移除背景颜色
                    .onChange(of: photoManager.currentFilter) { oldValue, newValue in
                        // 当筛选器改变时，滚动到新的筛选器
                        if let filter = photoManager.currentFilter {
                            let id: String
                            switch filter {
                            case .monthYear(let data):
                                id = "filter_month_\(data.year)_\(data.month)"
                            default:
                                id = ""
                            }
                            
                            if !id.isEmpty {
                                // 平滑滚动到所选筛选器
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            // 增加 zIndex，确保筛选器接收点击事件的优先级高于下面的照片
            .zIndex(10)
            // 添加 sheet 视图
            .sheet(isPresented: $showAllFiltersSheet) {
                AllFiltersView(photoManager: photoManager, isPresented: $showAllFiltersSheet)
            }
            .sheet(isPresented: $showLimitReached) {
                LimitReachedView()
            }
        }
    }
    
    // 平滑切换筛选器
    private func smoothFilterChange(to filter: FilterType) {
        guard filter != photoManager.currentFilter else { return }
        
        isFilterChanging = true
        withAnimation(.easeInOut(duration: 0.3)) {
            // 不立即清空卡片，由 photoManager 处理过渡
            photoManager.loadPhotos(for: filter)
        }
    }
    
    // 获取或缓存筛选器背景
    private func getOrCacheFilterBackground(key: String, generator: @escaping () -> UIImage?) -> UIImage? {
        // 如果缓存中已有，直接返回
        if let cachedImage = filterBackgroundCache[key] {
            return cachedImage
        }
        
        // 异步尝试生成并缓存
        DispatchQueue.global(qos: .userInitiated).async {
            if let generatedImage = generator() {
                DispatchQueue.main.async {
                    self.filterBackgroundCache[key] = generatedImage
                }
            }
        }
        
        // 尝试立即生成
        if let newImage = generator() {
            filterBackgroundCache[key] = newImage
            return newImage
        }
        
        return nil
    }
    
    // 新的增强型筛选器按钮视图
    struct EnhancedFilterButton: View {
        let filterType: FilterType
        let title: String
        let isSelected: Bool
        let backgroundImage: UIImage?
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                ZStack {
                    // 背景层
                    if let image = backgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 80)
                            .clipped()
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                            )
                    } else {
                        // 显示渐变背景
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 80)
                    }
                    
                    // 文字层
                    VStack {
                        Text(title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }
                    
                    // 选中指示器
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 120, height: 80)
                    }
                }
                .frame(width: 120, height: 80)
            }
            .buttonStyle(ScaleButtonStyle()) 
        }
    }
    
    // 获取月份中的最早日期照片作为背景
    private func getFirstPhotoForMonth(year: Int, month: Int) -> UIImage? {
        // 从 allPhotos 中找到该月份所有状态为待处理的照片
        let calendar = Calendar.current
        let monthPhotos = photoManager.allPhotos.filter { photo in
            guard let date = photo.creationDate, photo.status == .pending else { return false }
            return calendar.component(.year, from: date) == year && 
                   calendar.component(.month, from: date) == month
        }
        
        // 按日期升序排序，获取最早的照片
        let earliestPhoto = monthPhotos.sorted { ($0.creationDate ?? .distantFuture) < ($1.creationDate ?? .distantFuture) }.first
        
        // 如果找到照片，尝试从缓存获取图像
        if let photo = earliestPhoto {
            let cacheKey = NSString(string: "\(photo.id)_120x80")
            if let cachedImage = photoManager.imageCache.object(forKey: cacheKey) {
                return cachedImage
            } else {
                // 不阻塞UI，先返回nil，然后异步加载图像
                DispatchQueue.global(qos: .userInitiated).async {
                    photoManager.loadImage(for: photo, size: CGSize(width: 120, height: 80)) { _ in }
                }
                return nil
            }
        }
        return nil
    }
    
    // 辅助函数：格式化年月字符串
    private func monthYearString(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        if let date = Calendar.current.date(from: components) {
            return monthFormatter.string(from: date)
        }
        return "\(year)-\(month)" // Fallback
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
    
    // 空状态视图 (修改为接收权限状态)
    private func emptyStateView(isPermissionGranted: Bool) -> some View {
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
                
                Text(isPermissionGranted ? "No Photos Found" : "Photo Access Needed")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                // 根据筛选器类型显示更具体的空状态消息
                Text(emptyStateMessage(for: photoManager.currentFilter, hasPermission: isPermissionGranted))
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                if !isPermissionGranted {
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
    
    // 辅助函数：获取空状态消息
    private func emptyStateMessage(for filter: FilterType?, hasPermission: Bool) -> String {
        if !hasPermission {
            return "Please authorize access to your photo library to start filtering."
        }
        switch filter {
        case .monthYear(let data):
             let dateString = monthYearString(year: data.year, month: data.month)
             return "No photos found for \(dateString)."
        default:
            return "No photos match the current filter."
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
        .buttonStyle(ScaleButtonStyle())
        .padding(.top, 10)
    }
    
    // 照片视图 (修改为使用 filteredPhotos)
    private var photosView: some View {
        ZStack {
            // 使用 filteredPhotos
            ForEach(Array(photoManager.filteredPhotos.prefix(3).enumerated()), id: \.element.id) { index, photo in
                let zIndex = Double(3 - index)
                let yOffset = CGFloat(index) * -20
                let scale = max(0.85, 1.0 - CGFloat(index) * 0.05)
                
                createPhotoCardView(for: photo, index: index, zIndex: zIndex, yOffset: yOffset, scale: scale)
                    .transition(.opacity)
            }
        }
        .padding(.vertical)
    }
    
    // 创建照片卡片视图 (修改闭包逻辑)
    private func createPhotoCardView(for photo: Photo, index: Int, zIndex: Double, yOffset: CGFloat, scale: CGFloat) -> some View {
        PhotoCardView(
            photo: photo,
            onSave: {
                // Check if user can process more photos
                if !purchaseManager.canProcessPhoto() {
                    showLimitReached = true
                    return
                }
                
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                withAnimation(.easeInOut(duration: 0.3)) {
                    photoManager.savePhoto(photo) // 调用 manager 的方法
                }
            },
            onDelete: {
                // Check if user can process more photos
                if !purchaseManager.canProcessPhoto() {
                    showLimitReached = true
                    return
                }
                
                let impactMed = UIImpactFeedbackGenerator(style: .medium)
                impactMed.impactOccurred()
                withAnimation(.easeInOut(duration: 0.3)) {
                    photoManager.deletePhoto(photo) // 调用 manager 的方法
                }
            }
        )
        .padding(.bottom, 20)
        .zIndex(zIndex)
        .scaleEffect(scale)
        .offset(y: yOffset)
        .blur(radius: index > 0 ? CGFloat(index) * 0.3 : 0)
    }
    
    private func requestPhotoAccess() {
        print("Starting to request photo library permission")
        photoManager.requestPermission { granted in
            print("Photo permission request result: \(granted)")
            if granted {
                print("Permission granted, starting to load photos")
                photoManager.loadInitialPhotos()
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
    
    // 切换到下一个筛选器
    private func switchToNextFilter() {
        // 所有月份筛选器
        let allFilters = photoManager.availableMonths.map { FilterType.monthYear(data: $0) }
        
        // 如果没有筛选器，不进行切换
        if allFilters.isEmpty {
            return
        }
        
        // 查找当前筛选器的索引
        guard let currentIndex = allFilters.firstIndex(where: { $0 == photoManager.currentFilter }) else {
            // 如果当前筛选器不在列表中，选择第一个
            if let first = allFilters.first {
                smoothFilterChange(to: first)
            }
            return
        }
        
        // 查找下一个筛选器
        let nextIndex = (currentIndex + 1) % allFilters.count
        smoothFilterChange(to: allFilters[nextIndex])
    }
    
    // 切换到上一个筛选器
    private func switchToPreviousFilter() {
        // 所有月份筛选器
        let allFilters = photoManager.availableMonths.map { FilterType.monthYear(data: $0) }
        
        // 如果没有筛选器，不进行切换
        if allFilters.isEmpty {
            return
        }
        
        // 查找当前筛选器的索引
        guard let currentIndex = allFilters.firstIndex(where: { $0 == photoManager.currentFilter }) else {
            // 如果当前筛选器不在列表中，选择第一个
            if let first = allFilters.first {
                smoothFilterChange(to: first)
            }
            return
        }
        
        // 查找上一个筛选器
        let previousIndex = (currentIndex - 1 + allFilters.count) % allFilters.count
        smoothFilterChange(to: allFilters[previousIndex])
    }
    
    // 免费用户状态栏
    private var freeUserStatusBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "photo.circle")
                    .foregroundColor(.blue)
                    .font(.subheadline)
                
                Text("\(purchaseManager.getRemainingFreePhotos()) photos left today")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            Button("Upgrade") {
                showLimitReached = true
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.8))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

// 圆角扩展，支持特定角落的圆角
extension View {
    func uniqueCornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// 添加 AllFiltersView 视图
struct AllFiltersView: View {
    @ObservedObject var photoManager: PhotoManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                    // 年月筛选按钮
                    ForEach(photoManager.availableMonths) { monthData in
                        let filter = FilterType.monthYear(data: monthData)
                        FilterGridItem(
                            filterType: filter,
                            title: monthYearString(year: monthData.year, month: monthData.month),
                            isSelected: photoManager.currentFilter == filter,
                            backgroundImage: getFirstPhotoForMonth(year: monthData.year, month: monthData.month),
                            onTap: {
                                photoManager.loadPhotos(for: filter)
                                isPresented = false
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("All Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // 为网格视图定制的筛选器项
    struct FilterGridItem: View {
        let filterType: FilterType
        let title: String
        let isSelected: Bool
        let backgroundImage: UIImage?
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                ZStack {
                    // 背景层
                    if let image = backgroundImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 100)
                            .clipped()
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.3))
                            )
                    } else {
                        // 根据筛选器类型显示不同的渐变背景
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 150, height: 100)
                    }
                    
                    // 文字层
                    VStack {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }
                    
                    // 选中指示器
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 150, height: 100)
                    }
                }
                .frame(width: 150, height: 100)
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    // 辅助函数：格式化年月字符串
    private func monthYearString(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        if let date = Calendar.current.date(from: components) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy" // 例如: Dec 2023
            return formatter.string(from: date)
        }
        return "\(year)-\(month)" // Fallback
    }
    
    // 获取月份的第一张照片（与主视图相同的函数）
    private func getFirstPhotoForMonth(year: Int, month: Int) -> UIImage? {
        // 从 allPhotos 中找到该月份的所有状态为待处理的照片
        let calendar = Calendar.current
        let monthPhotos = photoManager.allPhotos.filter { photo in
            guard let date = photo.creationDate, photo.status == .pending else { return false }
            return calendar.component(.year, from: date) == year && 
                   calendar.component(.month, from: date) == month
        }
        
        // 按日期升序排序，获取最早的照片
        let earliestPhoto = monthPhotos.sorted { ($0.creationDate ?? .distantFuture) < ($1.creationDate ?? .distantFuture) }.first
        
        // 如果找到照片，尝试从缓存获取图像
        if let photo = earliestPhoto {
            let cacheKey = NSString(string: "\(photo.id)_120x80")
            if let cachedImage = photoManager.imageCache.object(forKey: cacheKey) {
                return cachedImage
            } else {
                // 不阻塞UI，先返回nil，然后异步加载图像
                DispatchQueue.global(qos: .userInitiated).async {
                    photoManager.loadImage(for: photo, size: CGSize(width: 120, height: 80)) { _ in }
                }
                return nil
            }
        }
        return nil
    }
} 