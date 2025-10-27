# PhotoCleaner UI Export for Figma

這個文件夾包含了 PhotoCleaner APP 的 UI 設計導出為 CSS/HTML 格式，方便在 Figma 或網頁瀏覽器中查看。

## 📁 文件說明

- **index.html** - 主要的 HTML 展示文件，包含所有 UI 組件
- **styles.css** - 完整的 CSS 樣式文件，包含所有組件樣式
- **README.md** - 本說明文件

## 🎨 包含的 UI 組件

### 1. HomeView（主頁面）
- 標題欄 (Title Bar)
- 篩選器滾動視圖 (Filter Scroll View)
- 照片卡片 (Photo Card)
- 操作按鈕 (Action Buttons)
- 載入狀態 (Loading State)

### 2. SavedPhotosView（已保存照片）
- 導航欄
- 照片網格（3列響應式佈局）
- 月份分組
- 展開/收起按鈕

### 3. DeletedPhotosView（已刪除照片）
- 導航欄
- 照片網格（帶刪除標記）
- 移除項目按鈕

### 4. 其他組件
- 啟動畫面 (Splash Screen)
- 空狀態視圖 (Empty State)

## 🚀 使用方法

### 方法一：在瀏覽器中查看

1. 打開 `index.html` 文件
2. 直接在瀏覽器中查看完整的 UI 設計
3. 所有交互效果都已實現（點擊、懸停等）

### 方法二：在 Figma 中使用

#### 選項 A - 使用 Figma 的 HTML to Figma 插件

1. 在 Figma 中安裝 "HTML to Figma" 插件
2. 運行插件
3. 複製 `index.html` 的完整內容
4. 粘貼到插件中
5. 點擊 "Import" 導入

#### 選項 B - 手動導入樣式

1. 在 Figma 中創建新文件
2. 打開 `styles.css` 文件
3. 根據 CSS 樣式手動創建 Figma 組件：

**顏色變量：**
```
Primary BG: #FFFFFF
Secondary BG: rgba(242, 242, 247, 0.5)
Primary Text: rgba(0, 0, 0, 0.87)
Blue Accent: #007AFF
Red Accent: #FF3B30
Green Accent: #34C759
```

**字體：**
```
Telka Regular - 400
Telka Medium - 500
Telka Bold - 700
Telka Black - 900
```

**圓角：**
```
Small: 8px
Medium: 12px
Large: 20px
```

**間距：**
```
4px, 8px, 12px, 16px, 20px
```

#### 選項 C - 使用截圖

1. 在瀏覽器中打開 `index.html`
2. 使用瀏覽器開發工具切換到移動設備視圖（推薦 iPhone 14 Pro: 393x852）
3. 截取各個組件的圖片
4. 在 Figma 中導入圖片作為參考

## 📱 響應式設計

CSS 已包含響應式斷點：
- 小屏幕：< 375px
- 平板：≥ 768px

在瀏覽器中可以調整視窗大小來查看響應式效果。

## 🎯 設計規範

### 字體大小
- Title: 28px (Bold)
- Title 2: 22px (Bold)
- Headline: 17px (Medium)
- Body: 17px (Regular)
- Subheadline: 15px (Regular)
- Caption: 12px (Regular)

### 網格系統
- 照片網格：3列（移動端）/ 4列（平板）
- 間距：4px
- 外邊距：16px

### 陰影
- 小：0 1px 3px rgba(0,0,0,0.1)
- 中：0 4px 6px rgba(0,0,0,0.1)
- 大：0 8px 24px rgba(0,0,0,0.15)

### 動畫
- 按鈕點擊：scale(0.92) - 0.2s
- 頁面過渡：0.3s ease

## 🔧 自定義

### 修改顏色
在 `styles.css` 中找到 `:root` 部分，修改 CSS 變量：

```css
:root {
    --primary-bg: #FFFFFF;
    --blue-accent: #007AFF;
    /* ... 其他顏色 */
}
```

### 修改間距
調整 `--spacing-*` 變量：

```css
:root {
    --spacing-4: 4px;
    --spacing-8: 8px;
    /* ... */
}
```

### 修改字體
如果需要使用不同的字體，修改 `@font-face` 聲明和 `font-family`。

## 📸 截圖建議

推薦的截圖尺寸：
- iPhone 14 Pro: 393 x 852
- iPhone 14 Pro Max: 430 x 932
- iPad: 768 x 1024

## ⚡ 互動功能

HTML 文件包含以下互動功能：
- ✅ 篩選器卡片選擇
- ✅ 操作按鈕動畫
- ✅ 刷新按鈕旋轉
- ✅ 展開/收起按鈕
- ✅ 載入狀態顯示
- ✅ 照片縮放點擊效果

## 💡 提示

1. **在線預覽**：可以使用 VS Code 的 Live Server 擴展來實時預覽
2. **調試工具**：使用瀏覽器開發者工具來檢查和修改樣式
3. **導出資源**：可以使用瀏覽器截圖工具批量導出各個組件
4. **Figma 自動佈局**：CSS 的 flexbox 和 grid 可以對應到 Figma 的 Auto Layout

## 📝 注意事項

- 字體文件需要與 CSS 文件保持正確的相對路徑關係
- 圖片使用了 placeholder，實際使用時需要替換為真實圖片
- 部分 iOS 特有的視覺效果（如毛玻璃）在網頁中可能呈現不同

## 🤝 反饋

如果需要調整任何樣式或添加新組件，請告訴我！
