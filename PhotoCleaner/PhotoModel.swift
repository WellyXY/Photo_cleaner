import Foundation
import SwiftUI
import Photos
import CoreLocation
import AVFoundation

enum PhotoStatus {
    case pending
    case saved
    case deleted
}

enum MediaType {
    case photo
    case video
}

// 定义年月结构体，使其 Hashable 和 Identifiable
struct MonthYear: Hashable, Identifiable {
    let year: Int
    let month: Int
    
    // 实现 Identifiable
    var id: String { "\(year)-\(month)" }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(year)
        hasher.combine(month)
    }
    
    static func == (lhs: MonthYear, rhs: MonthYear) -> Bool {
        return lhs.year == rhs.year && lhs.month == rhs.month
    }
}

// 定义筛选器类型
enum FilterType: Hashable {
    case all // 可能暂时不用，但保留
    case monthYear(data: MonthYear) // 使用新的 struct
}

// 静态缓存和限流控制
private class GeocodingManager {
    static let shared = GeocodingManager()
    private var geocoder = CLGeocoder()
    private var locationCache = [String: String]() // 使用字符串键来存储坐标
    private var requestQueue = [(CLLocation, (String) -> Void)]() // 使用数组而不是字典
    private var isProcessingQueue = false
    private var lastRequestTime: Date?
    private let requestInterval: TimeInterval = 0.2 // 增加间隔到0.2秒，更保守
    
    // 获取坐标的唯一字符串标识
    private func coordinateKey(_ coordinate: CLLocationCoordinate2D) -> String {
        // 保留5位小数，足够精确同时允许小误差
        return "\(String(format: "%.5f", coordinate.latitude)),\(String(format: "%.5f", coordinate.longitude))"
    }
    
    // 检查缓存
    private func getCachedLocation(for coordinate: CLLocationCoordinate2D) -> String? {
        return locationCache[coordinateKey(coordinate)]
    }
    
    // 添加请求到队列
    func requestGeocoding(for location: CLLocation, completion: @escaping (String) -> Void) {
        // 1. 先检查缓存
        if let cachedName = getCachedLocation(for: location.coordinate) {
            DispatchQueue.main.async {
                completion(cachedName)
            }
            return
        }
        
        // 2. 添加到队列
        requestQueue.append((location, completion))
        
        // 3. 开始处理队列
        processQueue()
    }
    
    // 处理队列
    private func processQueue() {
        if isProcessingQueue || requestQueue.isEmpty {
            return
        }
        
        isProcessingQueue = true
        
        // 控制请求间隔
        let now = Date()
        if let lastTime = lastRequestTime, now.timeIntervalSince(lastTime) < requestInterval {
            // 如果距离上次请求时间不足，则延迟执行
            let delayTime = requestInterval - now.timeIntervalSince(lastTime)
            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) { [weak self] in
                self?.processQueue()
            }
            isProcessingQueue = false
            return
        }
        
        // 取出一个请求处理
        let (location, completion) = requestQueue.removeFirst()
        
        // 再次检查缓存（可能在队列等待期间已被其他请求缓存）
        if let cachedName = getCachedLocation(for: location.coordinate) {
            DispatchQueue.main.async {
                completion(cachedName)
            }
            isProcessingQueue = false
            DispatchQueue.main.async { [weak self] in
                self?.processQueue()
            }
            return
        }
        
        lastRequestTime = now
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            var locationName = "Unknown Location"
            
            if let placemark = placemarks?.first, error == nil {
                let city = placemark.locality ?? ""
                let area = placemark.subLocality ?? ""
                locationName = area.isEmpty ? city : "\(city) \(area)"
                
                // 防止空结果
                if locationName.isEmpty {
                    locationName = "Unknown Location"
                }
                
                // 添加到缓存
                self.locationCache[self.coordinateKey(location.coordinate)] = locationName
            }
            
            // 执行回调
            DispatchQueue.main.async {
                completion(locationName)
            }
            
            // 继续处理队列
            self.isProcessingQueue = false
            
            // 延迟一点时间再处理下一个，确保不会触发限流
            DispatchQueue.main.asyncAfter(deadline: .now() + self.requestInterval) { [weak self] in
                self?.processQueue()
            }
        }
    }
}

class Photo: Identifiable, Equatable {
    let id: String
    let asset: PHAsset
    let mediaType: MediaType
    let duration: TimeInterval
    private(set) var creationDate: Date?
    private(set) var modificationDate: Date?
    
    var status: PhotoStatus = .pending
    private(set) var locationName: String = "Unknown Location"
    private var isLocationLoaded: Bool = false
    
    init(asset: PHAsset) {
        self.id = asset.localIdentifier
        self.asset = asset
        
        // If it's a video, get the duration
        if asset.mediaType == .video {
            self.duration = asset.duration
        } else {
            self.duration = 0
        }
        
        // Set media type
        if asset.mediaType == .video {
            self.mediaType = .video
        } else {
            self.mediaType = .photo
        }
        
        // Set initial status to pending
        self.status = .pending
        
        // Set dates
        self.creationDate = asset.creationDate
        self.modificationDate = asset.modificationDate
        
        // 不在初始化时加载位置信息，而是根据需要延迟加载
    }
    
    // 实现Equatable协议所需的静态方法
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Load location information as needed
    func loadLocationIfNeeded() {
        if isLocationLoaded || asset.location == nil {
            return
        }
        
        isLocationLoaded = true
        
        // If location information is available, get geocoding
        if let location = asset.location {
            // Use geocoding manager to process the request
            GeocodingManager.shared.requestGeocoding(for: location) { [weak self] locationName in
                guard let self = self else { return }
                self.locationName = locationName
                NotificationCenter.default.post(
                    name: Notification.Name("UpdateLocationName"),
                    object: nil,
                    userInfo: [
                        "photoId": self.id,
                        "locationName": locationName
                    ]
                )
            }
        }
    }
    
    // Update location name
    func updateLocationName(_ name: String) {
        locationName = name
    }
    
    // Format date
    var formattedDate: String {
        guard let date = creationDate else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy HH:mm"
        return formatter.string(from: date)
    }
    
    // Format location
    var formattedLocation: String {
        return locationName
    }
    
    // Format video duration
    var formattedDuration: String {
        if mediaType == .photo { return "" }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

class Album: Identifiable {
    let id: String
    let title: String
    let album: PHAssetCollection
    var count: Int = 0
    var coverImage: UIImage?
    var isLoading: Bool = false
    
    init(album: PHAssetCollection) {
        self.id = album.localIdentifier
        self.title = album.localizedTitle ?? "Unnamed Album"
        self.album = album
        
        // Get the number of media in the album
        let fetchOptions = PHFetchOptions()
        let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
        self.count = assets.count
    }
}

class PhotoManager: ObservableObject {
    // 保留原始照片列表，改为可访问
    var allPhotos: [Photo] = []
    @Published var savedPhotos: [Photo] = []
    @Published var deletedPhotos: [Photo] = []
    @Published var isLoading: Bool = false
    @Published var hasPermission: Bool = false
    // 移除 albums 和 selectedAlbum，因为 HomeView 不再使用
    // @Published var albums: [Album] = [] 
    // @Published var selectedAlbum: Album?
    
    // 新增状态
    @Published var filteredPhotos: [Photo] = [] // 当前筛选器下的照片
    @Published var availableMonths: [MonthYear] = [] // 可用的年月列表
    @Published var currentFilter: FilterType? = nil // 当前选中的筛选器
    
    // 修改 imageCache 的访问权限，使其公开可访问
    var imageCache = NSCache<NSString, UIImage>()
    
    // Last processed position date
    private let lastPositionKey = "LastProcessedPhotoDate"
    private let savedPhotosKey = "SavedPhotosIDs"
    private let deletedPhotosKey = "DeletedPhotosIDs"
    private let appStateKey = "AppStateVersion"
    private let currentAppStateVersion = "1.0"
    
    init() {
        print("PhotoManager initialized")
        // Check current permission status
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        hasPermission = (status == .authorized || status == .limited)
        print("Initial permission status: \(status.rawValue), hasPermission: \(hasPermission)")
        
        // Set cache capacity
        imageCache.countLimit = 100
        
        // Listen for location name updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocationNameUpdate(_:)),
            name: Notification.Name("UpdateLocationName"),
            object: nil
        )
        
        // Listen for app entering background events, save state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveAppState),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleLocationNameUpdate(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let photoId = userInfo["photoId"] as? String,
              let locationName = userInfo["locationName"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            // Update location names in all photo lists
            // 同时更新 allPhotos 和 filteredPhotos
             if let index = self.allPhotos.firstIndex(where: { $0.id == photoId }) {
                 self.allPhotos[index].updateLocationName(locationName)
             }
             if let index = self.filteredPhotos.firstIndex(where: { $0.id == photoId }) {
                 self.filteredPhotos[index].updateLocationName(locationName)
            }
            
            if let index = self.savedPhotos.firstIndex(where: { $0.id == photoId }) {
                self.savedPhotos[index].updateLocationName(locationName)
            }
            
            if let index = self.deletedPhotos.firstIndex(where: { $0.id == photoId }) {
                self.deletedPhotos[index].updateLocationName(locationName)
            }
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        // 首先检查是否已经授权
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized {
            print("照片权限已授权")
            completion(true)
            return
        }
        
        // 明确请求readWrite级别的权限，包括删除权限
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async { [weak self] in // 添加 weak self
                let granted = status == .authorized
                print("照片权限请求结果: \(granted)")
                self?.hasPermission = granted // 更新权限状态
                completion(granted)
                
                // 保存权限状态，避免重复请求
                UserDefaults.standard.set(granted, forKey: "PhotoPermissionGranted")
            }
        }
    }
    
    // 修改：加载所有照片到 allPhotos，计算可用月份，并加载默认筛选结果
    func loadInitialPhotos() {
        print("Starting initial photo load")
        isLoading = true
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status != .authorized && status != .limited {
            requestPermission { [weak self] granted in
                if granted {
                    self?.loadInitialPhotosAfterPermissionGranted()
                } else {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                }
            }
            return
        }
        
        loadInitialPhotosAfterPermissionGranted()
    }
    
    // 修改loadInitialPhotosAfterPermissionGranted方法，确保选择最新月份
    private func loadInitialPhotosAfterPermissionGranted() {
        // 使用更高优先级的队列
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // 创建一个超时计时器，确保加载操作不会无限期挂起
            let initialLoadTimeout = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.isLoading {
                    print("初始照片加载超时，强制结束加载状态")
                    DispatchQueue.main.async {
                        // 如果还处于加载状态，则强制结束
                        self.isLoading = false
                    }
                }
            }
            
            // 30秒超时
            DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: initialLoadTimeout)
            
            // 先加载缓存中的已保存/已删除照片列表
            let savedIds = UserDefaults.standard.array(forKey: self.savedPhotosKey) as? [String] ?? []
            let deletedIds = UserDefaults.standard.array(forKey: self.deletedPhotosKey) as? [String] ?? []
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.includeAssetSourceTypes = [.typeUserLibrary]
            fetchOptions.includeAllBurstAssets = false
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            // 限制初始加载只处理最近12个月的照片，提高速度
            let calendar = Calendar.current
            if let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date()) {
                let predicate = NSPredicate(format: "creationDate > %@", oneYearAgo as NSDate)
                fetchOptions.predicate = predicate
            }
            
            // 分批异步处理照片加载
            self.loadPhotosInBatches(
                savedIds: savedIds,
                deletedIds: deletedIds,
                fetchOptions: fetchOptions,
                timeout: initialLoadTimeout
            )
        }
    }
    
    // 修改loadPhotosInBatches方法，增加超时参数
    private func loadPhotosInBatches(savedIds: [String], deletedIds: [String], fetchOptions: PHFetchOptions, timeout: DispatchWorkItem? = nil) {
        // 第一步：快速加载照片资产
        var fetchedAssets: [PHAsset] = []
        
        // 异步进行照片获取，并设置更高的优先级
        let photoFetchGroup = DispatchGroup()
        
        photoFetchGroup.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            let photoAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            photoAssets.enumerateObjects { (asset, _, _) in fetchedAssets.append(asset) }
            photoFetchGroup.leave()
        }
        
        photoFetchGroup.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            let videoAssets = PHAsset.fetchAssets(with: .video, options: fetchOptions)
            videoAssets.enumerateObjects { (asset, _, _) in fetchedAssets.append(asset) }
            photoFetchGroup.leave()
        }
        
        photoFetchGroup.notify(queue: .global(qos: .userInteractive)) {
            // 排序照片，最新的在前面
            fetchedAssets.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            
            // 优先处理最近的200张照片
            let priorityAssets = fetchedAssets.prefix(200)
            var loadedPhotos: [Photo] = []
            var savedPhotosList: [Photo] = []
            var deletedPhotosList: [Photo] = []
            
            // 并行处理照片
            DispatchQueue.concurrentPerform(iterations: priorityAssets.count) { i in
                let asset = priorityAssets[i]
                let photo = Photo(asset: asset)
                
                if savedIds.contains(photo.id) {
                    photo.status = .saved
                    DispatchQueue.main.async {
                        savedPhotosList.append(photo)
                    }
                } else if deletedIds.contains(photo.id) {
                    photo.status = .deleted
                    DispatchQueue.main.async {
                        deletedPhotosList.append(photo)
                    }
                } else {
                    DispatchQueue.main.async {
                        loadedPhotos.append(photo)
                    }
                }
            }
            
            // 第三步：计算月份并更新UI，加载初始筛选器
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // 计算可用月份 (调用修改后的方法，只考虑未处理的照片)
                let months = self.calculateAvailableMonths(from: loadedPhotos)
                
                self.allPhotos = loadedPhotos + savedPhotosList + deletedPhotosList
                self.savedPhotos = savedPhotosList
                self.deletedPhotos = deletedPhotosList
                self.availableMonths = months
                
                print("Initial photos loaded: \(loadedPhotos.count) pending, \(savedPhotosList.count) saved, \(deletedPhotosList.count) deleted")
                print("Available months calculated: \(months.count)")
                
                // 取消超时计时器
                timeout?.cancel()
                
                // 设置默认筛选器，选择最新月份（即第一个月份，因为已经按时间降序排序）
                if let firstMonth = months.first {
                    print("默认选择最新月份: \(firstMonth.year)-\(firstMonth.month)")
                    self.currentFilter = .monthYear(data: firstMonth)
                    self.loadPhotos(for: .monthYear(data: firstMonth))
                } else {
                    // 如果没有可用月份但有未处理照片，显示全部照片
                    self.currentFilter = .all
                    self.loadPhotos(for: .all)
                }
                self.isLoading = false
                
                // 在后台处理剩余的照片
                if fetchedAssets.count > priorityAssets.count {
                    DispatchQueue.global(qos: .utility).async {
                        self.processRemainingPhotos(Array(fetchedAssets.dropFirst(200)), savedIds: savedIds, deletedIds: deletedIds)
                    }
                }
            }
        }
    }
    
    // 添加处理剩余照片的方法
    private func processRemainingPhotos(_ assets: [PHAsset], savedIds: [String], deletedIds: [String]) {
        var additionalPhotos: [Photo] = []
        
        // 分批处理剩余照片，每批100张
        let batchSize = 100
        for i in stride(from: 0, to: assets.count, by: batchSize) {
            let end = min(i + batchSize, assets.count)
            let batchAssets = Array(assets[i..<end])
            
            var batchPhotos: [Photo] = []
            
            // 处理这批照片
            for asset in batchAssets {
                let photo = Photo(asset: asset)
                
                if savedIds.contains(photo.id) {
                    photo.status = .saved
                } else if deletedIds.contains(photo.id) {
                    photo.status = .deleted
                }
                
                batchPhotos.append(photo)
            }
            
            // 将这批照片添加到总列表中
            additionalPhotos.append(contentsOf: batchPhotos)
            
            // 每处理完一批，就更新UI
            if !batchPhotos.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // 更新allPhotos
                    self.allPhotos.append(contentsOf: batchPhotos.filter { $0.status == .pending })
                    
                    // 更新savedPhotos和deletedPhotos
                    self.savedPhotos.append(contentsOf: batchPhotos.filter { $0.status == .saved })
                    self.deletedPhotos.append(contentsOf: batchPhotos.filter { $0.status == .deleted })
                    
                    // 重新计算可用月份
                    self.availableMonths = self.calculateAvailableMonths(from: self.allPhotos.filter { $0.status == .pending })
                    
                    print("Additional batch processed: \(batchPhotos.count) photos, total now: \(self.allPhotos.count)")
                }
            }
            
            // 稍微暂停一下，以免占用太多系统资源
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        print("All remaining photos processed: \(additionalPhotos.count)")
    }
    
    // 新增：后台预加载照片元数据
    private func preloadPhotosMetadata(_ photos: [Photo]) {
        // 每次处理20张照片，避免一次加载太多
        let batchSize = 20
        for i in stride(from: 0, to: min(100, photos.count), by: batchSize) {
            let end = min(i + batchSize, photos.count)
            let batch = Array(photos[i..<end])
            
            // 预加载这批照片的元数据
            for photo in batch {
                if photo.mediaType == .video {
                    // 只获取视频的基本信息，不预加载缩略图
                    _ = photo.formattedDuration
                }
                // 预加载位置信息
        photo.loadLocationIfNeeded()
    }
    
            // 每批次间隔一点时间
            if end < photos.count {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }
    
    // 修改：计算可用月份，返回 [MonthYear]，只考虑状态为pending的照片
    private func calculateAvailableMonths(from photos: [Photo]) -> [MonthYear] {
        let calendar = Calendar.current
        var monthSet = Set<String>()
        var monthList: [MonthYear] = []
        
        // 只考虑状态为pending的照片
        for photo in photos {
            if photo.status != .pending { continue }
            guard let date = photo.creationDate else { continue }
            
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let key = "\(year)-\(month)"
            if !monthSet.contains(key) {
                monthSet.insert(key)
                // 创建 MonthYear 实例
                monthList.append(MonthYear(year: year, month: month))
            }
        }
        
        // 已保存和已删除的照片不再考虑，因为它们不会在月份筛选中显示
        
        // 按年月降序排序 (最新在前)
        monthList.sort { (m1, m2) -> Bool in
            if m1.year != m2.year {
                return m1.year > m2.year
            }
            return m1.month > m2.month
        }
        
        return monthList
    }
    
    // 修改：根据筛选器加载照片，显示所有照片而不仅仅是待处理的
    func loadPhotos(for filter: FilterType) {
        print("Loading photos for filter: \(filter)")
        isLoading = true
        currentFilter = filter // 更新当前筛选器状态
        
        // 创建一个超时计时器，确保加载操作不会无限期挂起
        let loadingTimeout = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.isLoading {
                print("照片加载超时，强制结束加载状态")
                DispatchQueue.main.async {
                    // 如果还处于加载状态，则强制结束
                    self.isLoading = false
                    
                    // 如果筛选后的照片为空，也尝试加载一些照片以避免空白界面
                    if self.filteredPhotos.isEmpty {
                        // 尝试显示全部未处理照片
                        let pendingPhotos = self.allPhotos.filter { $0.status == .pending }
                        if !pendingPhotos.isEmpty {
                            self.filteredPhotos = Array(pendingPhotos.prefix(20))
                        }
                    }
                }
            }
        }
        
        // 15秒超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: loadingTimeout)
        
        // 保存当前筛选的照片，不立即清空，确保平滑过渡
        _ = filteredPhotos
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { 
                loadingTimeout.cancel()
                return 
            }
            
            var resultPhotos: [Photo] = []
            
            // 修改：加载所有状态的照片，不仅仅是待处理的
            let allAvailablePhotos = self.allPhotos
            
            switch filter {
            case .all:
                resultPhotos = allAvailablePhotos.filter { $0.status == .pending }
            case .monthYear(let data):
                let year = data.year
                let month = data.month
                let calendar = Calendar.current
                
                // 加载所有在该月份的照片，不过滤状态
                let allMonthPhotos = allAvailablePhotos.filter { photo in
                    guard let date = photo.creationDate else { return false }
                    return calendar.component(.year, from: date) == year && 
                           calendar.component(.month, from: date) == month
                }
                
                // 然后只保留待处理状态的照片
                resultPhotos = allMonthPhotos.filter { $0.status == .pending }
                
                // 月份内部按降序显示
                resultPhotos.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
                
                // 检查这个月份是否已经空了，如果是则移除
                if resultPhotos.isEmpty {
                    DispatchQueue.main.async {
                        self.removeEmptyMonths()
                    }
                }
            }
            
            // 如果筛选后没有照片，取消加载并自动切换月份
            if resultPhotos.isEmpty && filter != .all {
                DispatchQueue.main.async {
                    print("当前筛选条件下没有照片，自动尝试切换月份")
                    self.isLoading = false
                    loadingTimeout.cancel()
                    self.autoSelectNextMonth()
                }
                return
            }
            
            // 预加载结果照片的缩略图，然后再更新 UI
            let preloadCount = min(resultPhotos.count, 5) // 提高预加载数量到5张
            let preloadGroup = DispatchGroup()
            
            // 创建合适的尺寸
            let screenWidth = UIScreen.main.bounds.width
            let cardSize = CGSize(width: screenWidth - 40, height: UIScreen.main.bounds.height * 0.6)
            
            // 预加载
            for i in 0..<preloadCount {
                if i < resultPhotos.count {
                    preloadGroup.enter()
                    self.loadImage(for: resultPhotos[i], size: cardSize) { _ in
                        preloadGroup.leave()
                    }
                }
            }
            
            // 主线程更新 UI，使用短延迟确保平滑过渡
            preloadGroup.notify(queue: .main) {
                loadingTimeout.cancel() // 成功加载，取消超时
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.filteredPhotos = resultPhotos
                    }
                    self.isLoading = false
                    print("Filtered photos loaded: \(resultPhotos.count) for filter \(filter)")
                    self.preloadNextFilteredPhotos() // 继续预加载其他照片
                }
            }
        }
    }
    
    // 添加预加载方法
    func preloadImages(for photos: [Photo], size: CGSize) {
        // 增加预加载数量和效率
        let preloadCount = min(photos.count, 15) // 从10张增加到15张
        let preloadPhotos = Array(photos.prefix(preloadCount))
        
        let preloadGroup = DispatchGroup()
        for photo in preloadPhotos {
            preloadGroup.enter()
            
            // 使用并行队列加速加载
            DispatchQueue.global(qos: .userInitiated).async {
                self.loadImage(for: photo, size: size) { _ in
                    preloadGroup.leave()
                }
            }
        }
        
        // 所有预加载完成后的处理
        preloadGroup.notify(queue: .main) {
            print("Preload completed \(preloadPhotos.count) photos")
        }
    }
    
    // 添加在已保存/已删除视图中加载单张照片的方法
    func preloadSavedDeletedPhoto(photo: Photo, size: CGSize, completion: @escaping () -> Void) {
        // 使用更可靠的缓存键，基于asset的localIdentifier
        let cacheKey = NSString(string: "\(photo.asset.localIdentifier)_\(Int(size.width))x\(Int(size.height))")
        
        // 只清除当前照片的缓存，而不是所有缓存
        imageCache.removeObject(forKey: cacheKey)
        
        print("Starting forced photo load: \(photo.id), cache key: \(cacheKey)")
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false  // 使用异步加载，但确保回调正确执行
        options.version = .current
        
        if photo.mediaType == .video {
            // 视频处理 - 使用AVAsset生成更可靠的缩略图
            let videoOptions = PHVideoRequestOptions()
            videoOptions.version = .original
            videoOptions.deliveryMode = .highQualityFormat
            videoOptions.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(
                forVideo: photo.asset,
                options: videoOptions
            ) { [weak self] avAsset, _, _ in
                guard let self = self, let avAsset = avAsset else {
                    DispatchQueue.main.async { completion() }
                    return
                }
                
                let generator = AVAssetImageGenerator(asset: avAsset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: size.width * UIScreen.main.scale, 
                                              height: size.height * UIScreen.main.scale)
                
                generator.generateCGImageAsynchronously(for: CMTime.zero) { cgImage, _, error in
                    if let error = error {
                        print("Video thumbnail generation error: \(error.localizedDescription)")
                        DispatchQueue.main.async { completion() }
                        return
                    }
                    
                    guard let cgImage = cgImage else {
                        print("Failed to generate video thumbnail")
                        DispatchQueue.main.async { completion() }
                        return
                    }
                    
                    let thumbnail = UIImage(cgImage: cgImage)
                    self.imageCache.setObject(thumbnail, forKey: cacheKey)
                    print("Video thumbnail generated successfully: \(photo.id)")
                    
                    DispatchQueue.main.async { completion() }
                }
            }
        } else {
            // 照片处理 - 直接请求图像
            PHImageManager.default().requestImage(
                for: photo.asset,
                targetSize: CGSize(width: size.width * UIScreen.main.scale, height: size.height * UIScreen.main.scale),
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, info in
                guard let self = self else {
                    DispatchQueue.main.async { completion() }
                    return
                }
                
                if let image = image {
                    // 缓存图片
                    self.imageCache.setObject(image, forKey: cacheKey)
                    print("Photo loaded successfully: \(photo.id)")
                } else {
                    print("Failed to load photo: \(photo.id)")
                }
                
                // 无论成功与否都调用完成回调
                DispatchQueue.main.async { completion() }
            }
        }
    }
    
    // 检查照片是否正在加载
    func isPhotoLoading(_ photo: Photo) -> Bool {
        let loadingKey = "loading_\(photo.id)"
        return UserDefaults.standard.bool(forKey: loadingKey)
    }
    
    // 移除指定缓存
    func removeCacheForPhoto(_ photo: Photo, size: CGSize? = nil) {
        if let size = size {
            // 移除特定尺寸的缓存
            let cacheKey = NSString(string: "\(photo.id)_\(Int(size.width))x\(Int(size.height))")
            imageCache.removeObject(forKey: cacheKey)
            
            // 如果是视频，也移除视频缓存
            if photo.mediaType == .video {
                let videoCacheKey = NSString(string: "video_\(photo.id)_\(Int(size.width))x\(Int(size.height))")
                imageCache.removeObject(forKey: videoCacheKey)
            }
            
            print("Removed cached photo \(photo.id)")
        } else {
            // 只移除与该照片ID相关的所有缓存
            // 通过创建常见尺寸的缓存键来删除
            let commonSizes: [CGSize] = [
                CGSize(width: 100, height: 100),
                CGSize(width: 200, height: 200),
                CGSize(width: 300, height: 300),
                CGSize(width: 400, height: 400),
                CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width),
                CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            ]
            
            for size in commonSizes {
                let cacheKey = NSString(string: "\(photo.id)_\(Int(size.width))x\(Int(size.height))")
                imageCache.removeObject(forKey: cacheKey)
                
                if photo.mediaType == .video {
                    let videoCacheKey = NSString(string: "video_\(photo.id)_\(Int(size.width))x\(Int(size.height))")
                    imageCache.removeObject(forKey: videoCacheKey)
                }
            }
            
            print("Attempted to remove cached photos for \(photo.id) in all sizes")
        }
    }
    
    // 强制刷新图片加载
    func forceReloadImage(for photo: Photo, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        // 清除此照片的缓存
        let cacheKey = NSString(string: "\(photo.id)_\(Int(size.width))x\(Int(size.height))")
        imageCache.removeObject(forKey: cacheKey)
        
        // 如果是视频，清除视频缩略图缓存
        if photo.mediaType == .video {
            let videoCacheKey = NSString(string: "video_\(photo.id)_\(Int(size.width))x\(Int(size.height))")
            imageCache.removeObject(forKey: videoCacheKey)
        }
        
        // 重新加载 - 使用自动重试机制
        let retryCount = 3
        
        // 先声明闭包变量
        var loadWithRetry: ((Int) -> Void)!
        
        // 然后再定义闭包
        loadWithRetry = { (attempt: Int) in
            print("Loading photo \(photo.id) attempt \(attempt)")
            
            if photo.mediaType == .video {
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false
                options.version = .current
                
                // 添加iCloud错误处理
                options.progressHandler = { (progress, error, stop, info) in
                    if let error = error {
                        // 特别处理iCloud错误
                        let nsError = error as NSError
                        if nsError.domain.contains("CloudPhotoLibrary") || nsError.domain.contains("CKErrorDomain") {
                            print("Detected iCloud error: \(error.localizedDescription)")
                            // 如果是iCloud验证问题，显示占位图并立即返回
                            DispatchQueue.main.async {
                                let placeholder = UIImage(systemName: "exclamationmark.icloud")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                                completion(placeholder)
                                stop.pointee = true
                            }
                        }
                    }
                }
                
                PHImageManager.default().requestImage(
                    for: photo.asset,
                    targetSize: CGSize(width: size.width * UIScreen.main.scale, height: size.height * UIScreen.main.scale),
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    let error = info?[PHImageErrorKey] as? Error
                    
                    // 处理iCloud错误
                    if let error = error {
                        let nsError = error as NSError
                        if nsError.domain.contains("CloudPhotoLibrary") || nsError.domain.contains("CKErrorDomain") {
                            print("iCloud error: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                let placeholder = UIImage(systemName: "exclamationmark.icloud")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                                completion(placeholder)
                            }
                            return
                        }
                    }
                    
                    if let image = image {
                        // 成功获取图片，保存到缓存并完成
                        self.imageCache.setObject(image, forKey: NSString(string: "video_\(photo.id)_\(Int(size.width))x\(Int(size.height))"))
                        DispatchQueue.main.async {
                            completion(image)
                        }
                    } else if attempt < retryCount {
                        // 失败但还有重试次数，延迟后重试
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            loadWithRetry(attempt + 1)
                        }
                    } else {
                        // 重试次数用完，返回占位图
                        DispatchQueue.main.async {
                            let placeholder = UIImage(systemName: "video")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                            completion(placeholder)
                        }
                    }
                }
            } else {
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false
                options.version = .current
                
                // 添加iCloud错误处理
                options.progressHandler = { (progress, error, stop, info) in
                    if let error = error {
                        // 特别处理iCloud错误
                        let nsError = error as NSError
                        if nsError.domain.contains("CloudPhotoLibrary") || nsError.domain.contains("CKErrorDomain") {
                            print("Detected iCloud error: \(error.localizedDescription)")
                            // 如果是iCloud验证问题，显示占位图并立即返回
                            DispatchQueue.main.async {
                                let placeholder = UIImage(systemName: "exclamationmark.icloud")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                                completion(placeholder)
                                stop.pointee = true
                            }
                        }
                    }
                }
                
                PHImageManager.default().requestImage(
                    for: photo.asset,
                    targetSize: CGSize(width: size.width * UIScreen.main.scale, height: size.height * UIScreen.main.scale),
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    let error = info?[PHImageErrorKey] as? Error
                    
                    // 处理iCloud错误
                    if let error = error {
                        let nsError = error as NSError
                        if nsError.domain.contains("CloudPhotoLibrary") || nsError.domain.contains("CKErrorDomain") {
                            print("iCloud error: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                let placeholder = UIImage(systemName: "exclamationmark.icloud")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                                completion(placeholder)
                            }
                            return
                        }
                    }
                    
                    if let image = image {
                        // 成功获取图片，保存到缓存并完成
                        self.imageCache.setObject(image, forKey: cacheKey)
                        DispatchQueue.main.async {
                            completion(image)
                        }
                    } else if attempt < retryCount {
                        // 失败但还有重试次数，延迟后重试
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            loadWithRetry(attempt + 1)
                        }
                    } else {
                        // 重试次数用完，返回占位图
                        DispatchQueue.main.async {
                            let placeholder = UIImage(systemName: "photo")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                            completion(placeholder)
                        }
                    }
                }
            }
        }
        
        // 开始第一次尝试
        loadWithRetry(1)
    }
    
    // Save app state
    @objc func saveAppState() {
        print("Saving app state")
        
        // Save current position
        saveLastPosition()
        
        // Save IDs of saved photos
        let savedIDs = savedPhotos.map { $0.id }
        UserDefaults.standard.set(savedIDs, forKey: savedPhotosKey)
        
        // Save IDs of deleted photos
        let deletedIDs = deletedPhotos.map { $0.id }
        UserDefaults.standard.set(deletedIDs, forKey: deletedPhotosKey)
        
        // Save app version
        UserDefaults.standard.set(currentAppStateVersion, forKey: appStateKey)
        
        print("State saved: \(savedIDs.count) saved photos, \(deletedIDs.count) deleted photos")
    }
    
    // Save last processed position
    private func saveLastPosition() {
        if let firstPhoto = filteredPhotos.first, let date = firstPhoto.creationDate {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: lastPositionKey)
            print("Saved last processed position: \(date)")
        }
    }
    
    // Load last position and state
    func loadLastPosition() {
        // Check if there is a saved state
        let savedVersion = UserDefaults.standard.string(forKey: appStateKey)
        if savedVersion == nil || savedVersion != currentAppStateVersion {
            print("No valid saved state found or version mismatch")
            return
        }
        
        // Restore saved and deleted photo states
        if let savedIDs = UserDefaults.standard.array(forKey: savedPhotosKey) as? [String],
           let deletedIDs = UserDefaults.standard.array(forKey: deletedPhotosKey) as? [String],
           !savedIDs.isEmpty || !deletedIDs.isEmpty {
            
            print("Found saved state: \(savedIDs.count) saved photos, \(deletedIDs.count) deleted photos")
            
            // Remove processed photos from the photo list
            var processedPhotos: [Photo] = []
            
            // Process saved photos
            for id in savedIDs {
                if let index = filteredPhotos.firstIndex(where: { $0.id == id }) {
                    let photo = filteredPhotos[index]
                    photo.status = .saved
                    processedPhotos.append(photo)
                }
            }
            
            // Process deleted photos
            for id in deletedIDs {
                if let index = filteredPhotos.firstIndex(where: { $0.id == id }) {
                    let photo = filteredPhotos[index]
                    photo.status = .deleted
                    processedPhotos.append(photo)
                }
            }
            
            // Remove processed photos from the main list
            for photo in processedPhotos {
                if let index = filteredPhotos.firstIndex(where: { $0.id == photo.id }) {
                    filteredPhotos.remove(at: index)
                    
                    if photo.status == .saved {
                        savedPhotos.append(photo)
                    } else if photo.status == .deleted {
                        deletedPhotos.append(photo)
                    }
                }
            }
            
            print("State restored: \(filteredPhotos.count) pending photos, \(savedPhotos.count) saved photos, \(deletedPhotos.count) deleted photos")
        }
        
        // Restore last browsing position
        if let timestamp = UserDefaults.standard.object(forKey: lastPositionKey) as? TimeInterval {
            let date = Date(timeIntervalSince1970: timestamp)
            print("Loading last processed position: \(date)")
            
            // Find the last processed photo position
            let index = filteredPhotos.firstIndex { photo in
                if let photoDate = photo.creationDate {
                    return photoDate <= date
                }
                return false
            }
            
            if let index = index {
                print("Found last processed position, skipping \(index) photos")
                // Remove processed photos
                let processedPhotos = Array(filteredPhotos[0..<index])
                filteredPhotos.removeFirst(index)
                
                // Mark processed photos as pending
                for photo in processedPhotos {
                    photo.status = .pending
                }
                
                print("Remaining pending photos: \(filteredPhotos.count)")
            } else {
                print("Last processed position not found, starting from the beginning")
            }
        } else {
            print("No last processed position record, starting from the beginning")
        }
        
        // Preload the first batch of photos
        preloadNextFilteredPhotos()
    }
    
    // Optimize preload next batch of photos
    func preloadNextFilteredPhotos() {
        // Preload next batch of photos from filteredPhotos
        let cardWidth = UIScreen.main.bounds.width - 40
        let cardHeight = UIScreen.main.bounds.height * 0.6
        let preloadCount = min(filteredPhotos.count, 8)
        let photosToPreload = Array(filteredPhotos.prefix(preloadCount))
        
        print("Preload next batch of FILTERED photos, count: \(photosToPreload.count)")
        
        for (index, photo) in photosToPreload.enumerated() {
            let delay = Double(index) * 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if index < 3 {
                    self.loadImage(for: photo, size: CGSize(width: cardWidth, height: cardHeight)) { _ in }
                } else {
                    DispatchQueue.global(qos: .utility).async {
                        self.loadImage(for: photo, size: CGSize(width: cardWidth, height: cardHeight)) { _ in }
                    }
                }
            }
        }
    }
    
    // 改进保存照片方法，确保当处理任何照片时检查清除空标签
    func savePhoto(_ photo: Photo) {
        print("Saving photo: \(photo.id)")
        var didUpdate = false
        // 从 filteredPhotos 移除
        if let index = filteredPhotos.firstIndex(where: { $0.id == photo.id }) {
            let updatedPhoto = filteredPhotos.remove(at: index)
            updatedPhoto.status = .saved
            savedPhotos.append(updatedPhoto)
            didUpdate = true
            
            // Increment photo count for free users
            Task { @MainActor in
                PurchaseManager.shared.incrementPhotoCount()
            }
        }
         
        if didUpdate {
            print("Photo saved, remaining filtered photos: \(filteredPhotos.count), saved photos: \(savedPhotos.count)")
            saveAppState() // 保存状态
            
            // 不管是否是当前筛选器的最后一张照片，都检查是否需要移除此标签
            removeEmptyMonths()
            
            // 如果当前筛选器的照片已经处理完毕，自动切换到下一个月份
            if filteredPhotos.isEmpty {
                autoSelectNextMonth()
            } else {
                preloadNextFilteredPhotos() // 预加载下一批
            }
        } else {
            print("Photo save failed: photo not found in filtered list.")
        }
    }
    
    // 改进删除照片方法，确保当处理任何照片时检查清除空标签
    func deletePhoto(_ photo: Photo) {
        print("Deleting photo: \(photo.id)")
        var didUpdate = false
        // 从 filteredPhotos 移除
        if let index = filteredPhotos.firstIndex(where: { $0.id == photo.id }) {
            let updatedPhoto = filteredPhotos.remove(at: index)
            updatedPhoto.status = .deleted
            deletedPhotos.append(updatedPhoto)
            didUpdate = true
            
            // Increment photo count for free users
            Task { @MainActor in
                PurchaseManager.shared.incrementPhotoCount()
            }
        }
        
        if didUpdate {
            print("Photo deleted, remaining filtered photos: \(filteredPhotos.count), deleted photos: \(deletedPhotos.count)")
            saveAppState() // 保存状态
            
            // 不管是否是当前筛选器的最后一张照片，都检查是否需要移除此标签
            removeEmptyMonths()
            
            // 如果当前筛选器的照片已经处理完毕，自动切换到下一个月份
            if filteredPhotos.isEmpty {
                autoSelectNextMonth()
            } else {
                preloadNextFilteredPhotos() // 预加载下一批
            }
        } else {
            print("Photo delete failed: photo not found in filtered list.")
        }
    }
    
    // 修改月份自动选择方法，改为选择上一个月份
    private func autoSelectNextMonth() {
        print("当前月份照片已处理完毕，尝试自动切换到上一个月份")
        
        // 如果当前没有筛选器或不是月份筛选器，直接选择第一个可用月份
        guard case .monthYear(let currentMonthYear) = currentFilter else {
            if let firstMonth = availableMonths.first {
                print("没有当前筛选器，选择第一个可用月份: \(firstMonth.year)-\(firstMonth.month)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.loadPhotos(for: .monthYear(data: firstMonth))
                }
            }
            return
        }
        
        // 找到当前月份在可用月份列表中的索引
        if let currentIndex = availableMonths.firstIndex(where: { $0.year == currentMonthYear.year && $0.month == currentMonthYear.month }) {
            // 如果还有上一个月份，选择上一个（注意：availableMonths是按照最新在前排序的）
            if currentIndex + 1 < availableMonths.count {
                let previousMonth = availableMonths[currentIndex + 1]
                print("自动切换到上一个月份: \(previousMonth.year)-\(previousMonth.month)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.loadPhotos(for: .monthYear(data: previousMonth))
                }
            } 
            // 如果是最早的一个月份，选择最新的月份形成循环
            else if !availableMonths.isEmpty {
                let newestMonth = availableMonths[0]
                print("当前是最早的月份，循环回到最新月份: \(newestMonth.year)-\(newestMonth.month)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.loadPhotos(for: .monthYear(data: newestMonth))
                }
            }
            // 如果没有可用月份但还有待处理照片，切换到全部视图
            else if !allPhotos.filter({ $0.status == .pending }).isEmpty {
                print("没有可用月份，但有待处理照片，切换到全部照片视图")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.loadPhotos(for: .all)
                }
            } else {
                print("没有更多照片可处理")
            }
        } else {
            // 当前月份不在列表中，选择第一个可用月份
            if let firstMonth = availableMonths.first {
                print("当前月份不在可用列表中，选择第一个可用月份: \(firstMonth.year)-\(firstMonth.month)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.loadPhotos(for: .monthYear(data: firstMonth))
                }
            } else if !allPhotos.filter({ $0.status == .pending }).isEmpty {
                print("没有可用月份，但有待处理照片，切换到全部照片视图")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.loadPhotos(for: .all)
                }
            }
        }
    }
    
    // Move photo from deleted list to saved list
    func movePhotoFromDeletedToSaved(_ photo: Photo) {
        if let index = deletedPhotos.firstIndex(where: { $0.id == photo.id }) {
            let photo = deletedPhotos[index]
            deletedPhotos.remove(at: index)
            savedPhotos.append(photo)
            savePhotoLists()
            }
        }
        
    // 永久删除照片
    func permanentlyDeletePhotos(photoIds: [String], completion: @escaping (Bool) -> Void) {
        guard !photoIds.isEmpty else {
            completion(true)
            return
        }
        
        // 检查是否已经获得了照片删除权限
        let hasDeletePermission = UserDefaults.standard.bool(forKey: "PhotoDeletePermissionGranted")
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if status == .authorized || hasDeletePermission {
            // 已经有完整权限，直接执行删除
            print("已有删除权限，直接执行删除")
            performPhotosDeletion(photoIds: photoIds) { success in
                // 删除后从deletedPhotos数组中清除这些照片
                if success {
                    DispatchQueue.main.async { [weak self] in // 添加 weak self
                         guard let self = self else { return } // 检查 self
                        for photoId in photoIds {
                            if let index = self.deletedPhotos.firstIndex(where: { $0.id == photoId }) {
                                self.deletedPhotos.remove(at: index)
                            }
                        }
                    self.savePhotoLists()
                    }
                }
                completion(success)
            }
        } else {
            // 需要请求权限
            print("请求照片删除权限")
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
            DispatchQueue.main.async { [weak self] in // 添加 weak self
                     guard let self = self else { return } // 检查 self
                    if newStatus == .authorized {
                        // 保存权限状态，避免重复请求
                        UserDefaults.standard.set(true, forKey: "PhotoDeletePermissionGranted")
                        
                        // 授权成功，执行删除
                        self.performPhotosDeletion(photoIds: photoIds) { success in
                            // 删除后从deletedPhotos数组中清除这些照片
                            if success {
                                for photoId in photoIds {
                                    if let index = self.deletedPhotos.firstIndex(where: { $0.id == photoId }) {
                                        self.deletedPhotos.remove(at: index)
                                    }
                                }
                                self.savePhotoLists()
                            }
                            completion(success)
                        }
                    } else {
                        // 用户拒绝了权限
                        print("用户未授予照片删除权限")
                        completion(false)
                    }
                }
            }
        }
    }
    
    // 执行实际的照片删除操作
    private func performPhotosDeletion(photoIds: [String], completion: @escaping (Bool) -> Void) {
        // 使用photoIds直接获取PHAsset对象
        let fetchOptions = PHFetchOptions()
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: photoIds, options: fetchOptions)
            
        var assetsToDelete = [PHAsset]()
        fetchResult.enumerateObjects { (asset, _, _) in
            assetsToDelete.append(asset)
        }
        
        // 检查是否找到要删除的资源
        guard !assetsToDelete.isEmpty else {
            print("没有找到要删除的照片资源")
            completion(true)
            return
        }
        
        print("准备删除 \(assetsToDelete.count) 张照片")
        
        // 执行删除操作
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSFastEnumeration)
        }) { success, error in
                DispatchQueue.main.async {
                if success {
                    print("成功删除了 \(assetsToDelete.count) 张照片")
                    completion(true)
                } else {
                    print("删除照片失败：\(error?.localizedDescription ?? "未知错误")")
                    completion(false)
    }
            }
        }
    }
    
    // 保存照片列表到UserDefaults
    func savePhotoLists() {
        // 保存已保存照片的ID列表
        let savedPhotoIds = savedPhotos.map { $0.id }
        UserDefaults.standard.set(savedPhotoIds, forKey: savedPhotosKey)
        
        // 保存已删除照片的ID列表
        let deletedPhotoIds = deletedPhotos.map { $0.id }
        UserDefaults.standard.set(deletedPhotoIds, forKey: deletedPhotosKey)
        
        // 保存应用状态版本
        UserDefaults.standard.set(currentAppStateVersion, forKey: appStateKey)
        UserDefaults.standard.synchronize()
        
        print("已保存照片列表: 已保存照片 \(savedPhotoIds.count), 已删除照片 \(deletedPhotoIds.count)")
    }
    
    // Get saved photos list method improved
    func loadSavedPhotos(completion: @escaping () -> Void) {
        if savedPhotos.isEmpty {
            completion()
            return
        }
        
        isLoading = true
        
        // Clear all photo cache, force reload
        imageCache.removeAllObjects()
        print("Cleared all cache, preparing to load saved photos list")
        
        // Preload first 15 saved photos thumbnails
        let preloadGroup = DispatchGroup()
        let preloadCount = min(savedPhotos.count, 15)
        
        for (index, photo) in savedPhotos.prefix(preloadCount).enumerated() {
            preloadGroup.enter()
            
            // Create smaller size for preload
            let previewSize = CGSize(width: 200, height: 200)
            
            // Offset load time, avoid requesting too many resources at once
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                // Load preview based on media type
                if photo.mediaType == .video {
                    self.loadThumbnailForVideo(photo, size: previewSize) { _ in
                        preloadGroup.leave()
                    }
                } else {
                    self.loadImage(for: photo, size: previewSize) { _ in
                        preloadGroup.leave()
                    }
                }
            }
        }
        
        // All preload completed call callback
        preloadGroup.notify(queue: .main) {
            self.isLoading = false
            print("Saved photos list preload completed")
            completion()
        }
    }
    
    // Get deleted photos list method improved
    func loadDeletedPhotos(completion: @escaping () -> Void) {
        if deletedPhotos.isEmpty {
            completion()
            return
        }
        
        isLoading = true
        
        // Clear all photo cache, force reload
        imageCache.removeAllObjects()
        print("Cleared all cache, preparing to load deleted photos list")
        
        // Preload first 15 deleted photos thumbnails
        let preloadGroup = DispatchGroup()
        let preloadCount = min(deletedPhotos.count, 15)
        
        for (index, photo) in deletedPhotos.prefix(preloadCount).enumerated() {
            preloadGroup.enter()
            
            // Create smaller size for preload
            let previewSize = CGSize(width: 200, height: 200)
            
            // Offset load time, avoid requesting too many resources at once
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.1) {
                // Load preview based on media type
                if photo.mediaType == .video {
                    self.loadThumbnailForVideo(photo, size: previewSize) { _ in
                        preloadGroup.leave()
                    }
                } else {
                    self.loadImage(for: photo, size: previewSize) { _ in
                        preloadGroup.leave()
                    }
                }
            }
        }
        
        // All preload completed call callback
        preloadGroup.notify(queue: .main) {
            self.isLoading = false
            print("Deleted photos list preload completed")
            completion()
        }
    }
    
    // Get video thumbnail
    func loadThumbnailForVideo(_ photo: Photo, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard photo.mediaType == .video else {
            completion(nil)
            return
        }
        
        // Generate cache key
        let cacheKey = NSString(string: "video_\(photo.id)_\(Int(size.width))x\(Int(size.height))")
        
        // Check cache for image
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            print("Using cached video thumbnail: \(photo.id)")
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current
        
        // Create a timer, if load time is too long, return placeholder
        let timeoutTimer = DispatchWorkItem { [weak self] in // 添加 weak self
             guard let self = self else { return } // 检查 self
            print("Loading video thumbnail timed out: \(photo.id)")
            DispatchQueue.main.async {
                // Return placeholder
                let placeholderImage = UIImage(systemName: "video")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                completion(placeholderImage)
                
                // 2 seconds later try to reload
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.imageCache.removeObject(forKey: cacheKey)
                }
            }
        }
        
        // 3 seconds later timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: timeoutTimer)
        
        PHImageManager.default().requestImage(
            for: photo.asset,
            targetSize: CGSize(width: size.width * UIScreen.main.scale, height: size.height * UIScreen.main.scale),
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in // 添加 weak self
            // Cancel timeout timer
            timeoutTimer.cancel()
            
             guard let self = self else { return } // 检查 self
            
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCloudAsset = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            let error = info?[PHImageErrorKey] as? Error
            
            if let error = error {
                print("Loading video thumbnail failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    // Return placeholder
                    let placeholderImage = UIImage(systemName: "video")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                    completion(placeholderImage)
                }
                return
            }
            
            DispatchQueue.main.async {
                if let image = image, !isDegraded {
                    // Cache non-degraded image
                    self.imageCache.setObject(image, forKey: cacheKey)
                    completion(image)
                } else if let image = image {
                    // Even if degraded, display it first
                    completion(image)
                    
                    // If cloud asset and degraded, try again later
                    if isCloudAsset && isDegraded {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.imageCache.removeObject(forKey: cacheKey)
                        }
                    }
                } else {
                    // Return placeholder
                    let placeholderImage = UIImage(systemName: "video")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                    completion(placeholderImage)
                }
            }
        }
    }
    
    // 加载视频缩略图
    func loadVideoThumbnail(for photo: Photo, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        loadThumbnailForVideo(photo, size: size, completion: completion)
    }
    
    // 加载视频URL
    func loadVideoURL(for photo: Photo, completion: @escaping (URL?) -> Void) {
        guard photo.mediaType == .video else {
            completion(nil)
            return
        }
        
        requestPermission { [weak self] granted in
            guard granted, let self = self else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            self.loadVideoURLAfterPermissionGranted(for: photo, completion: completion)
        }
    }
    
    private func loadVideoURLAfterPermissionGranted(for photo: Photo, completion: @escaping (URL?) -> Void) {
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: photo.asset, options: options) { asset, _, _ in
            DispatchQueue.main.async {
                if let urlAsset = asset as? AVURLAsset {
                    completion(urlAsset.url)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    // 清除远处照片的缓存，用于内存警告时调用
    func clearDistantPhotoCache() {
        // 保留前3张照片的缓存，清除其他缓存
        let currentPhotos = filteredPhotos.prefix(3).map { $0.id } // 基于 filteredPhotos
        let currentSavedPhotos = savedPhotos.prefix(5).map { $0.id }
        let currentDeletedPhotos = deletedPhotos.prefix(5).map { $0.id }
        
        // 列出所有要保留的照片ID
        let photosToKeep = Set(currentPhotos + currentSavedPhotos + currentDeletedPhotos)
        
        print("内存警告：保留 \(photosToKeep.count) 张照片缓存，清除其他照片缓存")
        
        // 清除其他所有照片的缓存
        let allPhotosInManager = allPhotos + savedPhotos + deletedPhotos // 从所有来源收集
        for photo in allPhotosInManager {
            if !photosToKeep.contains(photo.id) {
                removeCacheForPhoto(photo)
            }
        }
        
        // 降低缓存容量
        imageCache.countLimit = 30
    }
    
    // 获取往年今日的照片
    func getPhotosFromPreviousYears(month: Int, day: Int, completion: @escaping ([Photo]) -> Void) {
        // 这个方法现在可以直接在 loadPhotos(for: .onThisDay) 中实现，或者保持独立供外部调用
        // 这里保持独立，但注意它操作的是 self.allPhotos
        let photosToFilter = self.allPhotos 
        
        DispatchQueue.global(qos: .userInitiated).async {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            
            // 筛选往年同月同日的照片
            let filteredPhotos = photosToFilter.filter { photo in
                guard let date = photo.creationDate else { return false }
                
                let photoYear = calendar.component(.year, from: date)
                let photoMonth = calendar.component(.month, from: date)
                let photoDay = calendar.component(.day, from: date)
                
                // 匹配月和日，但年份不是当前年
                return photoMonth == month && photoDay == day && photoYear != currentYear
            }
             // 按日期降序
             let sortedResult = filteredPhotos.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
            
            DispatchQueue.main.async {
                completion(sortedResult)
            }
        }
    }
    
    // 恢复 loadImage 方法
    func loadImage(for photo: Photo, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        // 在加载图片的同时，触发位置信息加载
        loadPhotoLocation(for: photo)
        
        // 确保有权限
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status != .authorized && status != .limited {
            requestPermission { [weak self] granted in
                if granted {
                    self?.loadImageAfterPermissionGranted(for: photo, size: size, completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
            return
        }
        
        loadImageAfterPermissionGranted(for: photo, size: size, completion: completion)
    }
    
    // 恢复 loadImageAfterPermissionGranted 方法
    private func loadImageAfterPermissionGranted(for photo: Photo, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        // 生成缓存键
        let cacheKey = NSString(string: "\(photo.id)_\(Int(size.width))x\(Int(size.height))")
        
        // 检查缓存中是否有图片
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            print("Using cached image: \(photo.id)")
            // 立即返回缓存的图片，不显示加载状态
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        // 允许从iCloud下载，但设置超时处理
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current
        
        // 添加iCloud错误处理
        options.progressHandler = { (progress, error, stop, info) in
            if let error = error {
                // 特别处理iCloud错误
                let nsError = error as NSError
                if nsError.domain.contains("CloudPhotoLibrary") || nsError.domain.contains("CKErrorDomain") {
                    print("Detected iCloud error: \(error.localizedDescription)")
                    // 如果是iCloud验证问题，显示占位图并立即返回
                    DispatchQueue.main.async {
                        let placeholder = UIImage(systemName: "exclamationmark.icloud")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                        completion(placeholder)
                        stop.pointee = true
                    }
                }
            }
        }
        
        // 创建一个计时器，如果图片加载时间过长，则返回占位图
        let timeoutTimer = DispatchWorkItem { [weak self] in // 添加 weak self
             guard let self = self else { return } // 检查 self 是否存在
            print("Loading photo timed out: \(photo.id)")
            DispatchQueue.main.async {
                // 使用占位图而不是返回nil
                let placeholderImage = UIImage(systemName: "photo")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                completion(placeholderImage)
                
                // 标记为需要重新加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // 从缓存中移除，下次点击时会重新加载
                    self.imageCache.removeObject(forKey: cacheKey)
                }
            }
        }
        
        // 3秒后超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: timeoutTimer)
        
        PHImageManager.default().requestImage(
            for: photo.asset,
            targetSize: CGSize(width: size.width * UIScreen.main.scale, height: size.height * UIScreen.main.scale),
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in // 添加 weak self
            // 取消超时计时器
            timeoutTimer.cancel()
            
             guard let self = self else { return } // 检查 self 是否存在
             
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let isCloudAsset = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
            let error = info?[PHImageErrorKey] as? Error
            
            print("Loading photo \(photo.id), is degraded: \(isDegraded), is in cloud: \(isCloudAsset), has error: \(error != nil ? "Yes" : "No")")
            
            // 处理iCloud错误
            if let error = error {
                let nsError = error as NSError
                if nsError.domain.contains("CloudPhotoLibrary") || nsError.domain.contains("CKErrorDomain") {
                    print("iCloud error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        let placeholder = UIImage(systemName: "exclamationmark.icloud")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                        completion(placeholder)
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                if let image = image, !isDegraded {
                    // 缓存非降质图片
                    self.imageCache.setObject(image, forKey: cacheKey)
                    completion(image)
                } else if let image = image {
                    // 即使是降质图片也先显示
                    completion(image)
                    
                    // 如果是云端资产且是降质图片，我们稍后尝试再次加载高质量版本
                    if isCloudAsset && isDegraded {
                        // 不缓存降质的云端图片，2秒后重试
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.imageCache.removeObject(forKey: cacheKey)
                        }
                    }
                } else {
                    // 如果没有图片，显示占位符
                    let placeholderImage = UIImage(systemName: "photo")?.withTintColor(.gray, renderingMode: .alwaysOriginal)
                    completion(placeholderImage)
                }
            }
        }
    }
    
    func loadPhotoLocation(for photo: Photo) {
        photo.loadLocationIfNeeded()
    }
    
    // 改进移除空标签方法 - 检查月份是否还有照片
    func removeEmptyMonths() {
        print("Checking for empty months...")
        var monthsToKeep: [MonthYear] = []
        
        for month in availableMonths {
            // 检查这个月份是否有任何照片未被处理
            let hasPhotos = allPhotos.contains { photo in
                guard let date = photo.creationDate, 
                      photo.status == .pending else { return false }
                
                let calendar = Calendar.current
                let photoYear = calendar.component(.year, from: date)
                let photoMonth = calendar.component(.month, from: date)
                
                return photoYear == month.year && photoMonth == month.month
            }
            
            if hasPhotos {
                monthsToKeep.append(month)
                print("Month \(month.year)-\(month.month) still has pending photos")
            } else {
                print("Month \(month.year)-\(month.month) has no pending photos, removing")
            }
        }
        
        // 更新可用月份列表
        if monthsToKeep.count != availableMonths.count {
            print("Updating available months from \(availableMonths.count) to \(monthsToKeep.count)")
            DispatchQueue.main.async {
                self.availableMonths = monthsToKeep
                
                // 如果当前筛选器是一个已移除的月份，切换到另一个筛选器
                if case .monthYear(let data) = self.currentFilter, 
                   !monthsToKeep.contains(where: { $0.year == data.year && $0.month == data.month }) {
                    print("Current filter month \(data.year)-\(data.month) was removed, switching to another filter")
                    // 如果还有其他月份，选择第一个月份
                    if let firstMonth = monthsToKeep.first {
                        print("Switching to month \(firstMonth.year)-\(firstMonth.month)")
                        self.loadPhotos(for: .monthYear(data: firstMonth))
                    } else if !self.allPhotos.filter({ $0.status == .pending }).isEmpty {
                        print("No months left with photos, switching to all photos")
                        self.loadPhotos(for: .all)
                    } else {
                        print("No pending photos left at all")
                    }
                }
            }
        } else {
            print("No changes to available months needed")
        }
    }
    
    // 增强版本的视频加载函数，支持自动播放
    func loadVideoForAutoPlay(for photo: Photo, size: CGSize, completion: @escaping (URL?, UIImage?) -> Void) {
        guard photo.mediaType == .video else {
            completion(nil, nil)
            return
        }
        
        // 首先尝试加载缩略图，以便快速显示
        let thumbnailCacheKey = NSString(string: "video_\(photo.id)_\(Int(size.width))x\(Int(size.height))")
        
        // 检查是否有缓存的缩略图
        let cachedThumbnail = imageCache.object(forKey: thumbnailCacheKey)
        
        // 同时加载URL用于播放
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: photo.asset, options: options) { [weak self] asset, _, _ in
            guard let self = self else {
                completion(nil, cachedThumbnail)
                return
            }
            
            if let urlAsset = asset as? AVURLAsset {
                DispatchQueue.main.async {
                    completion(urlAsset.url, cachedThumbnail)
                }
            } else {
                // 加载URL失败，至少返回缩略图
                DispatchQueue.main.async {
                    completion(nil, cachedThumbnail)
                }
                
                // 尝试后台刷新加载
                DispatchQueue.global(qos: .utility).async {
                    self.loadThumbnailForVideo(photo, size: size) { _ in }
                }
            }
        }
        
        // 如果没有缓存的缩略图，立即开始加载
        if cachedThumbnail == nil {
            loadThumbnailForVideo(photo, size: size) { _ in }
        }
    }
    
    // Get saved photos by month for grouped display
    func getSavedPhotosByMonth() -> [(month: String, photos: [Photo])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        // Group saved photos by month
        var photosByMonth: [String: [Photo]] = [:]
        
        for photo in savedPhotos {
            guard let date = photo.creationDate else { continue }
            
            let components = calendar.dateComponents([.year, .month], from: date)
            if let monthDate = calendar.date(from: components) {
                let monthKey = formatter.string(from: monthDate)
                
                if photosByMonth[monthKey] == nil {
                    photosByMonth[monthKey] = []
                }
                
                photosByMonth[monthKey]?.append(photo)
            }
        }
        
        // Sort each month's photos by date (newest first)
        for (month, photos) in photosByMonth {
            photosByMonth[month] = photos.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        }
        
        // Convert to array and sort by date (newest month first)
        let sortedMonths = photosByMonth.keys.sorted { monthKey1, monthKey2 in
            formatter.date(from: monthKey1)! > formatter.date(from: monthKey2)!
        }
        
        return sortedMonths.map { month in
            (month: month, photos: photosByMonth[month]!)
        }
    }
    
    // Get deleted photos by month for grouped display
    func getDeletedPhotosByMonth() -> [(month: String, photos: [Photo])] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        // Group deleted photos by month
        var photosByMonth: [String: [Photo]] = [:]
        
        for photo in deletedPhotos {
            guard let date = photo.creationDate else { continue }
            
            let components = calendar.dateComponents([.year, .month], from: date)
            if let monthDate = calendar.date(from: components) {
                let monthKey = formatter.string(from: monthDate)
                
                if photosByMonth[monthKey] == nil {
                    photosByMonth[monthKey] = []
                }
                
                photosByMonth[monthKey]?.append(photo)
            }
        }
        
        // Sort each month's photos by date (newest first)
        for (month, photos) in photosByMonth {
            photosByMonth[month] = photos.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        }
        
        // Convert to array and sort by date (newest month first)
        let sortedMonths = photosByMonth.keys.sorted { monthKey1, monthKey2 in
            formatter.date(from: monthKey1)! > formatter.date(from: monthKey2)!
        }
        
        return sortedMonths.map { month in
            (month: month, photos: photosByMonth[month]!)
        }
    }
} 