import Foundation
import SwiftUI
import Photos
import CoreLocation
import AVFoundation

// MARK: - Lightweight timestamp helper for logging
private let appStartTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
@inline(__always) private func ts() -> String {
    return String(format: "[T+%.3fs]", CFAbsoluteTimeGetCurrent() - appStartTime)
}

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
    case thisWeek // 新增：本週
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

    // Metrics
    private let metricsQueue = DispatchQueue(label: "PhotoManager.metrics")
    private var inFlightImageRequests: Int = 0
    private func incInFlight(_ delta: Int, context: String) {
        metricsQueue.sync {
            inFlightImageRequests += delta
            print("\(ts()) InFlightImageRequests=\(inFlightImageRequests) (\(context))")
        }
    }
    
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
        print("\(ts()) Starting initial photo load")
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
            let start = CFAbsoluteTimeGetCurrent()
            // 创建一个超时计时器，确保加载操作不会无限期挂起
            let initialLoadTimeout = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if self.isLoading {
                    print("\(ts()) 初始照片加载超时，强制结束加载状态")
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

            print("\(ts()) Dispatched loadPhotosInBatches (since start: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent()-start))s)")
        }
    }
    
    // 修改loadPhotosInBatches方法，增加超时参数
    private func loadPhotosInBatches(savedIds: [String], deletedIds: [String], fetchOptions: PHFetchOptions, timeout: DispatchWorkItem? = nil) {
        // 第一步：快速加载照片资产
        var fetchedAssets: [PHAsset] = []
        let phaseStart = CFAbsoluteTimeGetCurrent()
        // 异步进行照片获取，并设置更高的优先级
        let photoFetchGroup = DispatchGroup()
        
        // 仅首次加载图片，视频改为后台处理，避免首开过慢
        photoFetchGroup.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            let photoAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            photoAssets.enumerateObjects { (asset, _, _) in fetchedAssets.append(asset) }
            photoFetchGroup.leave()
        }
        
        photoFetchGroup.notify(queue: .global(qos: .userInteractive)) {
            let fetchDuration = CFAbsoluteTimeGetCurrent() - phaseStart
            print("\(ts()) Assets fetched: \(fetchedAssets.count) in \(String(format: "%.3f", fetchDuration))s")
            // 排序照片，最新的在前面
            fetchedAssets.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }

            // 🔄 優化：初始加載最新的150張照片（足夠顯示多個月份）
            // 而不是只加載10張，這樣能看到多個月份的照片
            let initialLoadCount = min(150, fetchedAssets.count)
            let priorityAssets = fetchedAssets.prefix(initialLoadCount)

            // 使用线程安全的队列来收集照片
            let serialQueue = DispatchQueue(label: "com.photocleaner.photobuilder")
            var loadedPhotos: [Photo] = []
            var savedPhotosList: [Photo] = []
            var deletedPhotosList: [Photo] = []

            // 并行处理照片
            let buildStart = CFAbsoluteTimeGetCurrent()
            print("\(ts()) Starting concurrent photo processing for \(priorityAssets.count) photos")

            DispatchQueue.concurrentPerform(iterations: priorityAssets.count) { i in
                let asset = priorityAssets[i]
                let photo = Photo(asset: asset)

                // 使用串行队列保证线程安全，不使用 async，直接同步添加
                serialQueue.sync {
                    if savedIds.contains(photo.id) {
                        photo.status = .saved
                        savedPhotosList.append(photo)
                    } else if deletedIds.contains(photo.id) {
                        photo.status = .deleted
                        deletedPhotosList.append(photo)
                    } else {
                        loadedPhotos.append(photo)
                    }
                }
            }

            print("\(ts()) Finished concurrent photo processing")
            
            // 第三步：计算月份并更新UI，加载初始筛选器
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let buildDuration = CFAbsoluteTimeGetCurrent() - buildStart
                print("\(ts()) Built photo models: pending=\(loadedPhotos.count) saved=\(savedPhotosList.count) deleted=\(deletedPhotosList.count) in \(String(format: "%.3f", buildDuration))s")
                
                // 计算可用月份 (调用修改后的方法，只考虑未处理的照片)
                let months = self.calculateAvailableMonths(from: loadedPhotos)
                
                self.allPhotos = loadedPhotos + savedPhotosList + deletedPhotosList
                self.savedPhotos = savedPhotosList
                self.deletedPhotos = deletedPhotosList
                self.availableMonths = months
                
                print("\(ts()) Initial photos loaded: \(loadedPhotos.count) pending, \(savedPhotosList.count) saved, \(deletedPhotosList.count) deleted")
                print("\(ts()) Available months calculated: \(months.count)")
                
                // 取消超时计时器
                timeout?.cancel()
                
                // 设置默认筛选器，优先选择 This Week（如果有数据）
                // isLoading 将由 loadPhotos 管理，不在这里设置为 false
                
                // 检查 This Week 是否有待处理照片
                let calendar = Calendar.current
                let now = Date()
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
                let hasThisWeekPhotos = loadedPhotos.contains { photo in
                    guard let date = photo.creationDate else { return false }
                    return date >= startOfWeek && date <= now
                }
                
                if hasThisWeekPhotos {
                    print("\(ts()) 默认选择 This Week")
                    self.currentFilter = .thisWeek
                    self.loadPhotos(for: .thisWeek)
                } else if let firstMonth = months.first {
                    print("\(ts()) 默认选择最新月份: \(firstMonth.year)-\(firstMonth.month)")
                    self.currentFilter = .monthYear(data: firstMonth)
                    self.loadPhotos(for: .monthYear(data: firstMonth))
                } else if !loadedPhotos.isEmpty {
                    // 如果没有可用月份但有未处理照片，显示全部照片
                    print("\(ts()) 没有可用月份，显示全部照片")
                    self.currentFilter = .all
                    self.loadPhotos(for: .all)
                } else {
                    // 如果真的没有任何照片，设置 isLoading = false
                    print("\(ts()) 没有任何照片可显示")
                    self.isLoading = false
                }
                
                // 在后台处理剩余的照片（包括视频）
                if fetchedAssets.count > initialLoadCount {
                    DispatchQueue.global(qos: .utility).async {
                        self.processRemainingPhotos(Array(fetchedAssets.dropFirst(initialLoadCount)), savedIds: savedIds, deletedIds: deletedIds)
                    }
                }
            }
        }
    }
    
    // 添加处理剩余照片的方法
    private func processRemainingPhotos(_ assets: [PHAsset], savedIds: [String], deletedIds: [String]) {
        var additionalPending: [Photo] = []
        var additionalSaved: [Photo] = []
        var additionalDeleted: [Photo] = []

        // 分批处理剩余照片，每批100张（在背景处理，可以用较大批次）
        let batchSize = 100
        for i in stride(from: 0, to: assets.count, by: batchSize) {
            let end = min(i + batchSize, assets.count)
            let batchAssets = Array(assets[i..<end])

            // 处理这批照片
            for asset in batchAssets {
                let photo = Photo(asset: asset)

                if savedIds.contains(photo.id) {
                    photo.status = .saved
                    additionalSaved.append(photo)
                } else if deletedIds.contains(photo.id) {
                    photo.status = .deleted
                    additionalDeleted.append(photo)
                } else {
                    additionalPending.append(photo)
                }
            }

            print("Additional batch processed: \(end)/\(assets.count) photos")
        }

        print("All remaining photos processed: \(additionalPending.count) pending, \(additionalSaved.count) saved, \(additionalDeleted.count) deleted")

        // ✅ 一次性更新 UI，避免多次重繪
        // 所有照片處理完成後，只觸發一次 UI 更新
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 添加到現有數組
            self.allPhotos.append(contentsOf: additionalPending)
            self.savedPhotos.append(contentsOf: additionalSaved)
            self.deletedPhotos.append(contentsOf: additionalDeleted)

            // 重新計算可用月份（包含所有照片）
            let allPendingPhotos = self.allPhotos.filter { $0.status == .pending }
            let updatedMonths = self.calculateAvailableMonths(from: allPendingPhotos)
            self.availableMonths = updatedMonths

            print("✅ UI updated with all photos. Total: \(self.allPhotos.count) photos, \(updatedMonths.count) months available")
        }
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
        print("🔥🔥🔥 NEW CODE LOADED - Loading photos for filter: \(filter)")
        print("🔥🔥🔥 allPhotos.count = \(self.allPhotos.count)")
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

        // 立即在當前線程執行過濾，避免異步塊被卡住
        var resultPhotos: [Photo] = []

        // 修改：加载所有状态的照片，不仅仅是待处理的
        let allAvailablePhotos = self.allPhotos

        print("Starting to filter photos, allPhotos count: \(allAvailablePhotos.count)")

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
        case .thisWeek:
            let calendar = Calendar.current
            let now = Date()
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
            // 只保留本週且 pending 的照片
            resultPhotos = allAvailablePhotos.filter { photo in
                guard let date = photo.creationDate else { return false }
                return (date >= startOfWeek && date <= now) && photo.status == .pending
            }
            resultPhotos.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
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

        // 立即更新 UI，不等待预加载完成
        DispatchQueue.main.async {
            loadingTimeout.cancel() // 取消超时

            withAnimation(.easeInOut(duration: 0.3)) {
                self.filteredPhotos = resultPhotos
            }
            self.isLoading = false
            print("Filtered photos loaded: \(resultPhotos.count) for filter \(filter)")

            // 在后台异步预加载照片，不阻塞 UI
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) {
                let preloadCount = min(resultPhotos.count, 2)
                let screenWidth = UIScreen.main.bounds.width
                let cardSize = CGSize(width: screenWidth - 40, height: UIScreen.main.bounds.height * 0.6)

                for i in 0..<preloadCount {
                    if i < resultPhotos.count {
                        let delay = Double(i) * 0.5 // 错开预加载时间
                        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                            self.loadImage(for: resultPhotos[i], size: cardSize) { image in
                                if image != nil {
                                    print("Photo \(i + 1) preloaded successfully")
                                }
                            }
                        }
                    }
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
        // Preload next batch of photos from filteredPhotos（减少预加载数量，提升性能）
        let cardWidth = UIScreen.main.bounds.width - 40
        let cardHeight = UIScreen.main.bounds.height * 0.6
        let preloadCount = min(filteredPhotos.count, 3)
        let photosToPreload = Array(filteredPhotos.prefix(preloadCount))
        
        print("Preload next batch of FILTERED photos, count: \(photosToPreload.count)")
        
        for (index, photo) in photosToPreload.enumerated() {
            let delay = Double(index) * 0.3 // 增加延迟到0.3秒，避免同时加载太多
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                // 所有预加载都使用后台队列，避免阻塞主线程
                self.loadImage(for: photo, size: CGSize(width: cardWidth, height: cardHeight)) { _ in
                    print("Preloaded photo \(index + 1)/\(photosToPreload.count)")
                }
            }
        }
    }
    
    // 改进保存照片方法，确保当处理任何照片时检查清除空标签
    func savePhoto(_ photo: Photo) {
        print("Saving photo: \(photo.id)")

        // 確保在主線程執行，避免線程安全問題
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.savePhoto(photo)
            }
            return
        }

        var didUpdate = false
        // 从 filteredPhotos 移除 - 添加安全檢查
        guard let index = filteredPhotos.firstIndex(where: { $0.id == photo.id }) else {
            print("Photo save failed: photo not found in filtered list")
            return
        }

        guard index < filteredPhotos.count else {
            print("Photo save failed: index out of bounds")
            return
        }

        let updatedPhoto = filteredPhotos.remove(at: index)
        updatedPhoto.status = .saved
        savedPhotos.append(updatedPhoto)
        didUpdate = true

        // Increment photo count for free users
        // TEMPORARILY DISABLED FOR TESTING
        // Task { @MainActor in
        //     PurchaseManager.shared.incrementPhotoCount()
        // }
         
        if didUpdate {
            print("Photo saved, remaining filtered photos: \(filteredPhotos.count), saved photos: \(savedPhotos.count)")
            saveAppState() // 保存状态
            
            // 不管是否是当前筛选器的最后一张照片，都检查是否需要移除此标签
            removeEmptyMonths()
            
            // 原行為：若本月處理完畢自動切換月份
            // 需求更新：不再自動跳轉，讓 UI 顯示完成頁面與刪除按鈕
            if filteredPhotos.isEmpty {
                // 停留在當前月份，由 HomeView 的 completionView 呈現
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

        // 確保在主線程執行，避免線程安全問題
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.deletePhoto(photo)
            }
            return
        }

        var didUpdate = false
        // 从 filteredPhotos 移除 - 添加安全檢查
        guard let index = filteredPhotos.firstIndex(where: { $0.id == photo.id }) else {
            print("Photo delete failed: photo not found in filtered list")
            return
        }

        guard index < filteredPhotos.count else {
            print("Photo delete failed: index out of bounds")
            return
        }

        let updatedPhoto = filteredPhotos.remove(at: index)
        updatedPhoto.status = .deleted
        deletedPhotos.append(updatedPhoto)
        didUpdate = true

        // Increment photo count for free users
        // TEMPORARILY DISABLED FOR TESTING
        // Task { @MainActor in
        //     PurchaseManager.shared.incrementPhotoCount()
        // }
        
        if didUpdate {
            print("Photo deleted, remaining filtered photos: \(filteredPhotos.count), deleted photos: \(deletedPhotos.count)")
            saveAppState() // 保存状态
            
            // 不管是否是当前筛选器的最后一张照片，都检查是否需要移除此标签
            removeEmptyMonths()
            
            // 原行為：若本月處理完畢自動切換月份
            // 需求更新：不再自動跳轉，讓 UI 顯示完成頁面與刪除按鈕
            if filteredPhotos.isEmpty {
                // 停留在當前月份，由 HomeView 的 completionView 呈現
            } else {
                preloadNextFilteredPhotos() // 预加载下一批
            }
        } else {
            print("Photo delete failed: photo not found in filtered list.")
        }
    }
    
    // 修改月份自动选择方法，改为选择上一个月份
    func autoSelectNextMonth() {
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

        // Don't clear all cache - keep recent photos cached for better performance
        // Only clear if cache is too large
        if imageCache.totalCostLimit > 100 {
            print("Cache size large, doing partial cleanup")
            // Keep cache but reduce limit temporarily
            let oldLimit = imageCache.countLimit
            imageCache.countLimit = 50
            imageCache.countLimit = oldLimit
        }
        print("Preparing to load saved photos list")
        
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

        // Don't clear all cache - keep recent photos cached for better performance
        // Only clear if cache is too large
        if imageCache.totalCostLimit > 100 {
            print("Cache size large, doing partial cleanup")
            // Keep cache but reduce limit temporarily
            let oldLimit = imageCache.countLimit
            imageCache.countLimit = 50
            imageCache.countLimit = oldLimit
        }
        print("Preparing to load deleted photos list")
        
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
        // 第一次加载使用快速模式，优先显示缩略图
        options.deliveryMode = .opportunistic
        // 允许从iCloud下载，但设置超时处理
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.version = .current
        // 允许降质图片，先显示低质量的，再加载高质量的
        options.resizeMode = .fast
        
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
            print("\(ts()) Loading photo timed out: \(photo.id)")
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
        
        // 20秒后超时（第一次加载需要更长时间，特别是从iCloud下载时）
        DispatchQueue.main.asyncAfter(deadline: .now() + 20.0, execute: timeoutTimer)
        
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
            
            print("\(ts()) requestImage cb id=\(photo.id) degraded=\(isDegraded) inCloud=\(isCloudAsset) hasError=\(error != nil)")
            
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
                if let image = image {
                    // 先显示任何可用的图片（包括降质版本）
                    completion(image)
                    
                    // 只缓存高质量的图片
                    if !isDegraded {
                        self.imageCache.setObject(image, forKey: cacheKey)
                    }
                    
                    // 如果是降质图片，不缓存，让下次重新加载高质量版本
                    // 但不要在这里立即重试，避免额外的网络请求
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
        print("\(ts()) Checking for empty months...")
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