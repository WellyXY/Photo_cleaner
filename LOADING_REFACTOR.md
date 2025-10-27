# 照片加載邏輯重構說明

## 🎯 重構目標

根據用戶反饋的兩個主要問題：
1. **只顯示一個月份資料夾**：打開 APP 後只看到 2025 年 10 月的資料夾，其他月份消失
2. **Saved/Deleted 頁面卡頓**：切換到 Saved/Deleted 標籤時，頁面卡住，需要等待才能顯示

## 📋 問題分析

### 問題 1：月份資料夾缺失

**根本原因**：
- 初始只加載 150 張照片並顯示
- 剩餘照片在背景處理，但處理後的數據被丟棄
- `processRemainingPhotos()` 方法只是緩存照片到局部變量，從未更新 UI
- `calculateAvailableMonths()` 只基於前 150 張照片計算，導致月份不完整

**代碼位置**：
- `PhotoModel.swift` 第 561 行：使用錯誤的 `dropFirst(10)` 而非 `dropFirst(initialLoadCount)`
- `PhotoModel.swift` 第 568-617 行：`processRemainingPhotos()` 方法處理後未更新 UI

### 問題 2：Saved/Deleted 頁面響應慢

**根本原因**：
- `.onAppear` 時同步調用 `groupPhotosByMonth()`
- `groupPhotosByMonth()` 在主線程執行，處理大量照片時阻塞 UI
- 用戶切換標籤後需要等待所有照片處理完成才能看到頁面

**代碼位置**：
- `SavedPhotosView.swift` 第 56-62 行：`.onAppear` 同步調用
- `DeletedPhotosView.swift` 第 209-222 行：`.onAppear` 同步調用

---

## ✅ 已實施的修復

### 修復 1：PhotoModel.swift - 照片加載邏輯

#### 1.1 修正批量處理起始點

**文件**：`PhotoModel.swift` 第 558-563 行

**改動前**：
```swift
// 在后台处理剩余的照片（包括视频）
if fetchedAssets.count > priorityAssets.count {
    DispatchQueue.global(qos: .utility).async {
        self.processRemainingPhotos(Array(fetchedAssets.dropFirst(10)), savedIds: savedIds, deletedIds: deletedIds)
    }
}
```

**改動後**：
```swift
// 在后台处理剩余的照片（包括视频）
if fetchedAssets.count > initialLoadCount {
    DispatchQueue.global(qos: .utility).async {
        self.processRemainingPhotos(Array(fetchedAssets.dropFirst(initialLoadCount)), savedIds: savedIds, deletedIds: deletedIds)
    }
}
```

**效果**：
- ✅ 正確地處理剩餘照片，避免重複處理前 140 張（10-150）
- ✅ 使用動態的 `initialLoadCount` 而非硬編碼的 `10`

#### 1.2 重構 processRemainingPhotos() 方法

**文件**：`PhotoModel.swift` 第 568-617 行

**改動前**：
```swift
private func processRemainingPhotos(_ assets: [PHAsset], savedIds: [String], deletedIds: [String]) {
    var additionalPhotos: [Photo] = []

    // 分批处理，但只是緩存到局部變量
    let batchSize = 50
    for i in stride(from: 0, to: assets.count, by: batchSize) {
        // ... 處理照片
        additionalPhotos.append(contentsOf: batchPhotos)
        // ⚠️ 沒有更新 UI
    }

    print("All remaining photos processed: \(additionalPhotos.count)")
    // ⚠️ 局部變量被丟棄，照片數據丟失
}
```

**改動後**：
```swift
private func processRemainingPhotos(_ assets: [PHAsset], savedIds: [String], deletedIds: [String]) {
    var additionalPending: [Photo] = []
    var additionalSaved: [Photo] = []
    var additionalDeleted: [Photo] = []

    // 分批处理剩余照片，每批100张（在背景处理，可以用较大批次）
    let batchSize = 100
    for i in stride(from: 0, to: assets.count, by: batchSize) {
        let end = min(i + batchSize, assets.count)
        let batchAssets = Array(assets[i..<end])

        // 处理这批照片，按狀態分類
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
```

**效果**：
- ✅ 按狀態分類照片（pending/saved/deleted）
- ✅ 處理完所有照片後，一次性更新三個數組
- ✅ 重新計算 `availableMonths`，包含所有照片的月份
- ✅ 只觸發一次 UI 更新，避免性能問題
- ✅ 批次大小從 50 增加到 100，提高處理效率

---

### 修復 2：SavedPhotosView.swift - 異步加載

#### 2.1 添加加載狀態

**文件**：`SavedPhotosView.swift` 第 13 行

**改動**：
```swift
@State private var isLoadingPhotos = false
```

#### 2.2 添加加載視圖

**文件**：`SavedPhotosView.swift` 第 75-85 行

**新增**：
```swift
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
```

#### 2.3 更新 body 顯示邏輯

**文件**：`SavedPhotosView.swift` 第 42-50 行

**改動前**：
```swift
Group {
    if photoManager.savedPhotos.isEmpty {
        emptyStateView
    } else {
        photoGridContent
    }
}
```

**改動後**：
```swift
Group {
    if isLoadingPhotos {
        loadingView
    } else if photoManager.savedPhotos.isEmpty {
        emptyStateView
    } else {
        photoGridContent
    }
}
```

**效果**：
- ✅ 加載時顯示進度指示器
- ✅ 用戶立即看到反饋，不會感覺卡住

#### 2.4 實現異步加載

**文件**：`SavedPhotosView.swift` 第 173-192 行

**新增方法**：
```swift
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
```

**改動 onAppear**：
```swift
// 改動前
.onAppear {
    print("SavedPhotosView出现")
    groupPhotosByMonth()
}

// 改動後
.onAppear {
    print("SavedPhotosView出现")
    loadPhotosAsync()
}
```

**效果**：
- ✅ 頁面立即顯示，不等待數據處理
- ✅ 背景線程處理照片分組，不阻塞 UI
- ✅ 使用緩存機制，避免重複處理
- ✅ 處理完成後自動更新 UI

---

### 修復 3：DeletedPhotosView.swift - 異步加載

#### 3.1 添加加載狀態

**文件**：`DeletedPhotosView.swift` 第 15 行

**改動**：
```swift
@State private var isLoadingPhotos = false
```

#### 3.2 更新 body 顯示邏輯

**文件**：`DeletedPhotosView.swift` 第 41-66 行

**改動前**：
```swift
ZStack {
    if photoManager.deletedPhotos.isEmpty {
        // 空狀態視圖
    } else {
        // 照片網格
    }
}
```

**改動後**：
```swift
ZStack {
    if isLoadingPhotos {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading photos...")
                .font(.telkaSubheadline)
                .foregroundColor(.gray)
        }
    } else if photoManager.deletedPhotos.isEmpty {
        // 空狀態視圖
    } else {
        // 照片網格
    }
}
```

#### 3.3 實現異步加載

**文件**：`DeletedPhotosView.swift` 第 235-254 行

**新增方法**：
```swift
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
```

**改動 onAppear**：
```swift
// 改動前
.onAppear {
    print("DeletedPhotosView appeared")
    groupPhotosByMonth()
}

// 改動後
.onAppear {
    print("DeletedPhotosView appeared")
    loadPhotosAsync()
}
```

**效果**：與 SavedPhotosView 相同

---

## 📊 性能對比

### 之前（有問題）：

```
場景 1：APP 啟動
T+0.0s  - APP 啟動
T+0.1s  - 加載前 150 張照片
T+0.3s  - 顯示第一個月份資料夾（僅 2025 Oct）
T+0.5s  - 開始批量處理剩餘照片
T+1.0s  - 批量處理完成，但數據被丟棄 ❌
T+永遠  - 其他月份永遠不會顯示 ❌

場景 2：切換到 Saved 標籤
T+0.0s  - 點擊 Saved 標籤
T+0.0s  - 開始同步處理照片分組（主線程） ⚠️
T+0.5s  - 照片分組完成，頁面才顯示 ❌
用戶體驗：頁面卡住 0.5 秒
```

### 之後（已修復）：

```
場景 1：APP 啟動
T+0.0s  - APP 啟動
T+0.1s  - 加載前 150 張照片
T+0.3s  - 顯示多個月份資料夾（基於前 150 張）
T+0.5s  - 開始批量處理剩餘照片（背景）
T+1.0s  - 批量處理完成，一次性更新 UI ✅
T+1.0s  - 所有月份資料夾顯示完整 ✅

場景 2：切換到 Saved 標籤
T+0.0s  - 點擊 Saved 標籤
T+0.0s  - 立即顯示加載指示器 ✅
T+0.0s  - 開始異步處理照片分組（背景線程） ✅
T+0.5s  - 照片分組完成，更新網格內容 ✅
用戶體驗：頁面立即響應，無卡頓
```

---

## 🎯 技術要點

### 1. 單次 UI 更新策略

**原則**：批量處理時，在背景累積所有變更，最後一次性更新 UI

**實現**：
```swift
// ❌ 錯誤：每批都更新，觸發多次重繪
for batch in batches {
    process(batch)
    DispatchQueue.main.async {
        self.photos.append(contentsOf: batch)  // 多次觸發 @Published
    }
}

// ✅ 正確：累積後一次更新
var allBatches: [Photo] = []
for batch in batches {
    let processed = process(batch)
    allBatches.append(contentsOf: processed)
}
DispatchQueue.main.async {
    self.photos.append(contentsOf: allBatches)  // 只觸發一次 @Published
}
```

### 2. 異步加載模式

**原則**：頁面立即顯示 → 背景加載數據 → 更新 UI

**實現**：
```swift
// 1. 添加加載狀態
@State private var isLoading = false

// 2. 根據狀態顯示不同 UI
if isLoading {
    ProgressView()  // 立即顯示
} else {
    ContentView()
}

// 3. 異步加載
func loadAsync() {
    isLoading = true  // 立即更新 UI
    DispatchQueue.global().async {
        // 耗時操作
        let data = processData()

        DispatchQueue.main.async {
            self.data = data
            self.isLoading = false  // 更新完成
        }
    }
}
```

### 3. 緩存機制

**原則**：避免重複處理已經處理過的數據

**實現**：
```swift
func loadPhotosAsync() {
    // 如果已有數據，直接返回
    if !groupedPhotos.isEmpty {
        return
    }

    // 否則執行加載
    // ...
}
```

---

## 🧪 測試建議

### 1. 月份資料夾測試

- [ ] 啟動 APP，檢查是否顯示所有月份資料夾
- [ ] 觀察控制台日誌，確認看到 "✅ UI updated with all photos"
- [ ] 檢查月份數量是否與實際照片庫匹配
- [ ] 滾動查看每個月份的照片是否正確

### 2. Saved 頁面測試

- [ ] 點擊 Saved 標籤，頁面是否立即響應
- [ ] 是否顯示加載指示器
- [ ] 照片加載完成後是否正確顯示
- [ ] 多次切換標籤，檢查緩存是否生效（第二次應該更快）

### 3. Deleted 頁面測試

- [ ] 點擊 Deleted 標籤，頁面是否立即響應
- [ ] 是否顯示加載指示器
- [ ] 照片加載完成後是否正確顯示
- [ ] 刪除照片後，頁面是否正確更新

### 4. 性能測試

- [ ] 使用 Instruments 檢查 CPU 使用情況
- [ ] 檢查主線程是否有長時間阻塞
- [ ] 觀察內存使用是否正常
- [ ] 測試大量照片（1000+ 張）的情況

---

## 📝 開發者筆記

### SwiftUI 性能優化經驗

1. **@Published 更新開銷很大**
   - 每次更新都會觸發 View 重繪
   - 批量操作時應該累積後一次性更新
   - 使用 `objectWillChange.send()` 可以手動控制更新時機

2. **主線程必須保持響應**
   - 任何耗時操作都應該在背景線程
   - UI 更新必須在主線程，但要快速完成
   - 使用 DispatchQueue 分離計算和 UI 更新

3. **用戶體驗優先**
   - 即使數據未準備好，也要先顯示 UI 結構
   - 使用 ProgressView 提供反饋
   - 實現緩存機制，避免重複加載

4. **調試技巧**
   - 使用 `print` 追蹤關鍵節點
   - 記錄時間戳，計算操作耗時
   - 使用 Instruments 分析性能瓶頸

---

## ⚠️ 已知限制

1. **大量照片的情況**
   - 如果有數千張照片，初始加載仍需要幾秒
   - 可以考慮進一步優化：只加載最新 N 個月的照片
   - 實現虛擬化滾動

2. **月份計算可能延遲**
   - 所有照片處理完才能看到完整的月份列表
   - 可以考慮增量更新月份列表

3. **內存使用**
   - 一次性加載所有照片可能佔用較多內存
   - 可以考慮實現分頁加載

---

## 🔜 未來優化建議

### 短期（1-2 天）：
1. 實現增量月份更新（不等所有照片處理完）
2. 優化初始加載數量（根據設備性能動態調整）
3. 添加錯誤處理和重試機制

### 中期（1 週）：
1. 實現虛擬化滾動（LazyVStack 優化）
2. 使用 Combine 優化狀態管理
3. 實現智能緩存策略

### 長期（1 個月）：
1. 使用 Core Data 持久化
2. 實現增量同步
3. 支持後台刷新

---

## 📞 需要幫助？

如果遇到問題，請提供：

1. ✅ 完整的控制台日誌
2. ✅ 照片庫中的照片數量和月份分布
3. ✅ 具體的操作步驟和觀察到的行為
4. ✅ 診斷腳本的輸出（運行 `./diagnose.sh`）

---

## 📄 相關文件

- `PERFORMANCE_FIX.md` - 之前的性能修復文檔
- `diagnose.sh` - 診斷腳本
- `CRASH_LOG_GUIDE.md` - 崩潰日誌收集指南
