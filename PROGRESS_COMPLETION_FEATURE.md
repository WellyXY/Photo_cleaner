# 進度顯示和完成頁面功能說明

## 🎯 新增功能概述

根據用戶需求，在每個 album folder 選中時添加了兩個主要功能：

1. **進度信息顯示**：在滑動照片上方展示處理進度
2. **完成頁面**：當 folder 的照片全部處理完後，展示祝賀頁面和刪除確認

---

## ✅ 功能 1：進度信息條

### 位置
在照片卡片上方，月份選擇器下方

### 顯示內容

**左側 - 剩餘照片數量**：
- 圖標：📸 photo.stack
- 文字：`X Remaining`
- 樣式：藍色背景，圓角矩形

**右側 - 完成百分比**：
- 文字：`X% Complete`
- 樣式：綠色背景，圓角矩形
- 計算公式：`已處理數量 / 總數量 × 100`

### 實現位置
**文件**：`HomeView.swift` 第 268-309 行

```swift
private var progressInfoBar: some View {
    let progressInfo = getCurrentFilterProgress()

    return HStack(spacing: 12) {
        // 剩餘數量
        HStack(spacing: 6) {
            Image(systemName: "photo.stack")
                .font(.telkaRegular(size: 14))
                .foregroundColor(.blue)

            Text("\(progressInfo.remaining) Remaining")
                .font(.telkaMedium(size: 14))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        )

        Spacer()

        // 完成百分比
        HStack(spacing: 6) {
            Text("\(progressInfo.percentage)%")
                .font(.telkaBold(size: 16))
                .foregroundColor(.green)

            Text("Complete")
                .font(.telkaMedium(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green.opacity(0.1))
        )
    }
}
```

### 進度計算邏輯

**文件**：`HomeView.swift` 第 1130-1167 行

```swift
private func getCurrentFilterProgress() -> (remaining: Int, total: Int, percentage: Int) {
    guard let currentFilter = photoManager.currentFilter else {
        return (0, 0, 0)
    }

    let calendar = Calendar.current
    var totalPhotosInFilter = 0
    var remainingPhotos = 0

    switch currentFilter {
    case .all:
        // All filter: 計算所有照片
        totalPhotosInFilter = photoManager.allPhotos.count
        remainingPhotos = photoManager.filteredPhotos.count

    case .monthYear(let data):
        // Month filter: 只計算該月份的照片
        let year = data.year
        let month = data.month

        // 找出該月份的所有照片（包括 pending, saved, deleted）
        let monthPhotos = photoManager.allPhotos.filter { photo in
            guard let date = photo.creationDate else { return false }
            return calendar.component(.year, from: date) == year &&
                   calendar.component(.month, from: date) == month
        }

        totalPhotosInFilter = monthPhotos.count
        // 剩餘待處理的照片
        remainingPhotos = monthPhotos.filter { $0.status == .pending }.count
    }

    // 計算百分比
    let percentage = totalPhotosInFilter > 0 ?
        Int((Double(totalPhotosInFilter - remainingPhotos) / Double(totalPhotosInFilter)) * 100) : 0

    return (remainingPhotos, totalPhotosInFilter, percentage)
}
```

**計算說明**：
- **總數量**：當前 filter 中的所有照片（包括 pending、saved、deleted 狀態）
- **剩餘數量**：當前 filter 中狀態為 `pending` 的照片數量
- **已處理數量** = 總數量 - 剩餘數量
- **完成百分比** = (已處理數量 / 總數量) × 100

---

## ✅ 功能 2：完成頁面

### 觸發條件
當前 filter 的所有照片都已處理完畢（沒有剩餘 pending 照片）時自動顯示

### 頁面內容

#### 1. 祝賀區域
- **圖標**：綠藍漸變圓圈內的白色 ✓ 圖標
- **主標題**：`Congrats!!` (32pt, Telka Bold)
- **副標題**：`All photos are complete.` (18pt, Telka Regular)

#### 2. 被刪除照片預覽
- **標題**：`Photos to Delete (X)` - 顯示刪除照片數量
- **網格佈局**：4 列縮略圖
- **顯示數量**：最多顯示 20 張
- **標記**：每張照片右上角有紅色垃圾桶圖標
- **超出提示**：如果超過 20 張，顯示 `+ X more`

#### 3. 刪除按鈕
- **文字**：`Delete Archive Photos`
- **樣式**：紅色漸變背景，白色文字，圓角
- **尺寸**：全寬，高度 56pt
- **圖標**：垃圾桶 icon

### 實現位置
**文件**：`HomeView.swift` 第 311-430 行

```swift
private var completionView: some View {
    let deletedPhotosInFilter = getDeletedPhotosInCurrentFilter()

    return ScrollView {
        VStack(spacing: 24) {
            // 祝賀圖標和文字
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.6), Color.blue.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                }

                Text("Congrats!!")
                    .font(.telkaBold(size: 32))

                Text("All photos are complete.")
                    .font(.telkaRegular(size: 18))
            }

            // 被刪除照片的縮略圖網格
            if !deletedPhotosInFilter.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Photos to Delete (\(deletedPhotosInFilter.count))")
                        .font(.telkaHeadline)

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4),
                        GridItem(.flexible(), spacing: 4)
                    ], spacing: 4) {
                        ForEach(deletedPhotosInFilter.prefix(20)) { photo in
                            PhotoThumbnail(photo: photo)
                                .aspectRatio(1, contentMode: .fill)
                                .cornerRadius(8)
                                .overlay(
                                    // 紅色垃圾桶標記
                                )
                        }
                    }
                }
            }

            // 刪除按鈕
            Button(action: {
                deleteArchivePhotos()
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete Archive Photos")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
            }
        }
    }
}
```

### 完成判斷邏輯

**文件**：`HomeView.swift` 第 1169-1198 行

```swift
private func isCurrentFilterCompleted() -> Bool {
    guard let currentFilter = photoManager.currentFilter else {
        return false
    }

    let calendar = Calendar.current

    switch currentFilter {
    case .all:
        // All filter: 檢查是否有任何待處理照片
        let pendingPhotos = photoManager.allPhotos.filter { $0.status == .pending }
        return pendingPhotos.isEmpty && !photoManager.allPhotos.isEmpty

    case .monthYear(let data):
        // Month filter: 檢查該月份是否還有待處理照片
        let year = data.year
        let month = data.month

        let monthPhotos = photoManager.allPhotos.filter { photo in
            guard let date = photo.creationDate else { return false }
            return calendar.component(.year, from: date) == year &&
                   calendar.component(.month, from: date) == month
        }

        // 該月份有照片，但沒有待處理的照片 = 已完成
        let pendingInMonth = monthPhotos.filter { $0.status == .pending }
        return !monthPhotos.isEmpty && pendingInMonth.isEmpty
    }
}
```

**判斷條件**：
- 當前 filter 中有照片（不是空的）
- 當前 filter 中沒有狀態為 `pending` 的照片
- 即：所有照片都已被標記為 saved 或 deleted

### 獲取刪除照片邏輯

**文件**：`HomeView.swift` 第 1200-1225 行

```swift
private func getDeletedPhotosInCurrentFilter() -> [Photo] {
    guard let currentFilter = photoManager.currentFilter else {
        return []
    }

    let calendar = Calendar.current

    switch currentFilter {
    case .all:
        // All filter: 返回所有刪除的照片
        return photoManager.allPhotos.filter { $0.status == .deleted }

    case .monthYear(let data):
        // Month filter: 只返回該月份被刪除的照片
        let year = data.year
        let month = data.month

        return photoManager.allPhotos.filter { photo in
            guard let date = photo.creationDate else { return false }
            return calendar.component(.year, from: date) == year &&
                   calendar.component(.month, from: date) == month &&
                   photo.status == .deleted
        }
    }
}
```

---

## 🗑️ 刪除功能

### 刪除流程

**文件**：`HomeView.swift` 第 1227-1267 行

#### 1. 用戶點擊 "Delete Archive Photos" 按鈕

#### 2. 顯示確認對話框
```swift
UIAlertController(
    title: "Delete Photos",
    message: "Are you sure you want to permanently delete X photo(s)? This action cannot be undone.",
    preferredStyle: .alert
)
```

**選項**：
- **Cancel**：取消操作
- **Delete** (紅色警告樣式)：確認刪除

#### 3. 執行刪除
```swift
photoManager.permanentlyDeletePhotos(photoIds: photoIds) { success in
    if success {
        print("✅ Successfully deleted \(photoIds.count) photos")

        // 刪除成功後，自動切換到下一個月份
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.photoManager.autoSelectNextMonth()
        }
    } else {
        print("❌ Failed to delete photos")
    }
}
```

#### 4. 自動切換月份
刪除成功後，延遲 0.5 秒自動切換到下一個有照片的月份

### 安全措施
- ✅ 雙重確認：需要用戶在對話框中確認才能刪除
- ✅ 明確提示：顯示將要刪除的照片數量
- ✅ 不可撤銷警告：提醒用戶操作無法撤銷
- ✅ 分離邏輯：先標記為 deleted 狀態，再統一永久刪除
- ✅ 回調處理：確保刪除完成後才進行下一步操作

---

## 📊 UI/UX 流程

### 正常處理流程

```
1. 選擇月份 folder
   ↓
2. 顯示進度條
   [5 Remaining | 80% Complete]
   ↓
3. 滑動處理照片
   - 左滑 Save
   - 右滑 Delete
   ↓
4. 進度實時更新
   [3 Remaining | 90% Complete]
   [1 Remaining | 95% Complete]
   [0 Remaining | 100% Complete]
   ↓
5. 自動顯示完成頁面
   ✓ Congrats!!
   📸 被刪除照片預覽
   🗑️ Delete Archive Photos 按鈕
   ↓
6. 點擊刪除按鈕
   ↓
7. 確認對話框
   ↓
8. 執行刪除
   ↓
9. 自動切換到下一個月份
```

### 視圖切換邏輯

```swift
// HomeView.swift 第 152-202 行
if !photoManager.isLoading && photoManager.filteredPhotos.isEmpty {
    if isCurrentFilterCompleted() {
        // ✅ 已完成 → 顯示完成頁面
        completionView
    } else {
        // 真正的空視圖
        emptyStateView
    }
} else {
    // 有照片 → 顯示照片卡片 + 進度條
    VStack {
        progressInfoBar  // 進度信息
        photosView      // 照片卡片
    }
}
```

---

## 🎨 設計細節

### 進度條設計
- **藍色系**：剩餘照片數量（表示待處理）
- **綠色系**：完成百分比（表示已完成）
- **圓角矩形**：8pt 圓角，輕微透明背景
- **間距**：左右分布，中間 Spacer()

### 完成頁面設計
- **視覺層次**：
  1. 祝賀圖標（最突出）
  2. 文字提示
  3. 照片預覽網格
  4. 刪除按鈕

- **顏色方案**：
  - 圖標：綠藍漸變（積極、完成）
  - 文字：系統主色
  - 按鈕：紅色漸變（警告、刪除）

- **佈局**：
  - ScrollView 支持內容滾動
  - 照片網格：4 列，間距 4pt
  - 按鈕：固定底部，全寬

### 動畫和過渡
- 進度條：實時更新，無動畫
- 視圖切換：`.transition(.opacity)` 淡入淡出
- 刪除後：延遲 0.5 秒切換月份（給用戶反應時間）

---

## 🧪 測試建議

### 1. 進度條測試
- [ ] 切換不同月份，檢查進度計算是否正確
- [ ] 處理照片後，檢查進度是否實時更新
- [ ] 檢查百分比計算是否準確
- [ ] 測試邊界情況：0 張照片、1 張照片、大量照片

### 2. 完成頁面測試
- [ ] 處理完所有照片後，是否自動顯示完成頁面
- [ ] 檢查被刪除照片是否正確顯示
- [ ] 測試照片數量超過 20 張的情況
- [ ] 檢查沒有刪除照片時的顯示

### 3. 刪除功能測試
- [ ] 點擊按鈕，是否顯示確認對話框
- [ ] 點擊 Cancel，是否取消操作
- [ ] 點擊 Delete，是否正確刪除照片
- [ ] 刪除後，是否自動切換到下一個月份
- [ ] 測試最後一個月份刪除後的行為

### 4. 邊界情況測試
- [ ] 月份沒有照片時的行為
- [ ] 所有照片都是 saved，沒有 deleted 的情況
- [ ] 快速連續處理多張照片
- [ ] 網絡延遲或刪除失敗的情況

---

## 📝 代碼結構總結

### 新增文件
無，所有修改在現有的 `HomeView.swift` 中

### 修改的代碼區域

**1. 視圖顯示邏輯** (第 152-202 行)
- 添加完成頁面判斷
- 添加進度條顯示

**2. 進度信息條視圖** (第 268-309 行)
- `progressInfoBar`

**3. 完成頁面視圖** (第 311-430 行)
- `completionView`

**4. 輔助函數** (第 1128-1267 行)
- `getCurrentFilterProgress()` - 計算進度
- `isCurrentFilterCompleted()` - 判斷是否完成
- `getDeletedPhotosInCurrentFilter()` - 獲取刪除照片
- `deleteArchivePhotos()` - 刪除操作

### 依賴的現有組件
- `PhotoManager` - 照片管理器
- `PhotoThumbnail` - 照片縮略圖組件
- `FilterType` - 過濾器類型枚舉
- `Photo` - 照片模型

---

## 🔜 未來優化建議

### 短期（1-2 天）：
1. ✅ 添加刪除進度指示器
2. ✅ 添加刪除成功的提示動畫
3. ✅ 支持批量選擇要刪除的照片

### 中期（1 週）：
1. 添加撤銷刪除功能（垃圾桶）
2. 實現刪除照片的預覽模式
3. 添加統計數據（總共處理了多少照片）

### 長期（1 個月）：
1. 導出處理報告
2. 雲端同步刪除狀態
3. 智能推薦要刪除的照片

---

## 💡 使用提示

### 給用戶的提示
1. **進度追蹤**：隨時查看頂部進度條，了解當前處理進度
2. **完成確認**：完成一個月份後，會自動顯示完成頁面
3. **批量刪除**：在完成頁面可以一次性刪除所有標記的照片
4. **安全刪除**：刪除前會二次確認，避免誤操作
5. **自動切換**：刪除後會自動切換到下一個月份

### 給開發者的提示
1. **狀態管理**：進度和完成狀態基於 `PhotoManager.filteredPhotos` 和 `currentFilter`
2. **實時更新**：當照片狀態改變時，視圖會自動更新
3. **線程安全**：所有 UI 更新都在主線程執行
4. **錯誤處理**：刪除操作有回調處理成功和失敗情況
5. **可擴展性**：可以輕鬆添加更多統計信息或功能

---

## 🎉 總結

本次更新為 PhotoCleaner APP 添加了完整的進度追蹤和完成確認功能：

✅ **進度可視化**：用戶可以清楚地看到還有多少照片需要處理
✅ **完成儀式感**：處理完成後的祝賀頁面提升用戶體驗
✅ **批量刪除**：方便快捷地刪除已標記的照片
✅ **安全保障**：雙重確認機制防止誤操作
✅ **自動流轉**：刪除後自動切換到下一個月份，流程順暢

這些功能顯著提升了用戶在整理照片時的體驗，讓整個流程更加直觀和高效！
