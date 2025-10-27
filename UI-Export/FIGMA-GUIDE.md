# 如何在 Figma 中使用 PhotoCleaner UI 設計稿

## 🎯 推薦方法：使用截圖導入

這是最簡單且效果最好的方法！

### 步驟 1：在瀏覽器中打開設計稿

1. 找到並雙擊打開 `index.html` 文件
2. 文件會在瀏覽器中打開，顯示完整的 UI

### 步驟 2：設置移動設備視圖

1. 在瀏覽器中按 `F12` 或右鍵選擇 "檢查" 打開開發者工具
2. 點擊工具欄中的 **"Toggle device toolbar"** 圖標（或按 `Ctrl+Shift+M` / `Cmd+Shift+M`）
3. 在頂部選擇設備類型，推薦：
   - **iPhone 14 Pro** (393 x 852)
   - **iPhone 14 Pro Max** (430 x 932)

4. 或者手動設置尺寸：
   - 寬度：393px
   - 高度：852px（或更長，取決於內容）

### 步驟 3：截取各個組件

#### 方法 A - 使用瀏覽器截圖（推薦）

**Chrome / Edge:**
1. 開發者工具打開的狀態下
2. 按 `Ctrl+Shift+P` (Windows) 或 `Cmd+Shift+P` (Mac)
3. 輸入 "screenshot"
4. 選擇 **"Capture full size screenshot"** 或 **"Capture screenshot"**
5. 圖片會自動下載

**Firefox:**
1. 按 `Shift+F2` 打開開發者工具命令行
2. 輸入 `screenshot --fullpage`
3. 按 Enter

#### 方法 B - 使用第三方截圖工具

- **Mac**: 按 `Cmd+Shift+4` 然後選擇區域
- **Windows**: 使用 Snipping Tool 或 `Win+Shift+S`

### 步驟 4：將截圖導入 Figma

1. 打開 Figma
2. 創建新文件或打開現有項目
3. 將截圖直接拖放到 Figma 畫布上
4. 或者按 `Ctrl+Shift+K` (Windows) / `Cmd+Shift+K` (Mac) 選擇圖片導入

### 步驟 5：設置設計規範

在 Figma 中創建設計系統：

#### 5.1 創建顏色樣式

1. 在 Figma 右側面板點擊 "Local styles" 旁的 **"+"**
2. 選擇 "Color style"
3. 添加以下顏色：

```
Primary Background: #FFFFFF
Secondary Background: #F2F2F7 (50% opacity)
Primary Text: #000000 (87% opacity)
Secondary Text: #000000 (60% opacity)
Blue Accent: #007AFF
Red Accent: #FF3B30
Green Accent: #34C759
Gray Light: #8E8E93
```

#### 5.2 設置文字樣式

1. 點擊 "Text" 旁的 **"+"**
2. 添加以下文字樣式：

| 名稱 | 字體 | 大小 | 粗細 |
|------|------|------|------|
| Title | Telka | 28px | Bold (700) |
| Title 2 | Telka | 22px | Bold (700) |
| Title 3 | Telka | 20px | Medium (500) |
| Headline | Telka | 17px | Medium (500) |
| Body | Telka | 17px | Regular (400) |
| Subheadline | Telka | 15px | Regular (400) |
| Caption | Telka | 12px | Regular (400) |

#### 5.3 創建組件（Components）

根據截圖創建以下可重用組件：

1. **Filter Card** (120x80px)
   - 帶圓角 (8px)
   - 背景圖片
   - 漸變疊加層
   - 文字標籤

2. **Photo Card** (393x524px)
   - 圓角 20px
   - 陰影效果
   - 日期標籤
   - 大小標籤

3. **Action Button** (80x80px)
   - 圓形
   - 漸變背景
   - 圖標

4. **Photo Thumbnail**
   - 正方形
   - 圓角 8px

---

## 📱 方法 2：使用 Figma 插件（進階）

### 使用 HTML to Figma 插件

1. 在 Figma 中，點擊菜單 **Plugins → Find more plugins**
2. 搜索 "HTML to Figma" 或 "Figma to Code"
3. 安裝插件（推薦插件：**"html.to.design"** 或 **"Figma to Code"**）

4. 運行插件：
   - 點擊 **Plugins → HTML to Figma**
   - 複製 `index.html` 的完整內容
   - 粘貼到插件界面
   - 點擊 "Import"

**注意**: 此方法可能需要調整，因為並非所有 CSS 效果都能完美轉換。

---

## 🎨 方法 3：手動重建（最精確）

使用 CSS 文件作為設計規範，在 Figma 中手動重建 UI。

### 讀取設計規範

打開 `styles.css` 文件，參考以下部分：

#### 間距系統
```css
--spacing-4: 4px
--spacing-8: 8px
--spacing-12: 12px
--spacing-16: 16px
--spacing-20: 20px
```

#### 圓角
```css
--radius-small: 8px
--radius-medium: 12px
--radius-large: 20px
```

#### 陰影
- 小陰影: 0px 1px 3px rgba(0,0,0,0.1)
- 中陰影: 0px 4px 6px rgba(0,0,0,0.1)
- 大陰影: 0px 8px 24px rgba(0,0,0,0.15)

### 創建佈局

1. 創建 Frame (按 `F`)
2. 設置尺寸為 393x852 (iPhone 14 Pro)
3. 使用 Auto Layout (按 `Shift+A`) 創建響應式設計
4. 根據 CSS 設置間距和對齊

---

## 🔧 導入 Design Tokens

使用 `figma-tokens.json` 文件：

1. 安裝 **"Figma Tokens"** 插件
2. 打開插件：Plugins → Figma Tokens
3. 點擊 "Import"
4. 選擇 `figma-tokens.json` 文件
5. 所有顏色、間距、文字樣式會自動導入

---

## 📸 最佳實踐建議

### 1. 分別截取各個部分

建議分別截取以下部分：
- HomeView 標題欄
- Filter 滾動條
- Photo Card
- Action Buttons
- SavedPhotosView 網格
- DeletedPhotosView 網格

### 2. 使用合適的命名

在 Figma 中為圖層命名：
```
📱 HomeView
  ├─ Title Bar
  ├─ Filter Scroll
  │  └─ Filter Card × 4
  ├─ Photo Card
  │  ├─ Image
  │  ├─ Date Badge
  │  └─ Size Badge
  └─ Action Buttons
     ├─ Delete Button
     └─ Save Button
```

### 3. 創建組件變體

為不同狀態創建變體：
- Filter Card: Selected / Unselected
- Photo Card: Loading / Loaded / Error
- Action Button: Normal / Pressed

### 4. 設置 Auto Layout

使用 Auto Layout 讓設計響應式：
- Photo Grid: 固定 3 列，間距 4px
- Action Buttons: 水平排列，間距 20px
- Month Section: 垂直排列，間距 20px

---

## 🎯 快速開始檢查清單

- [ ] 在瀏覽器中打開 index.html
- [ ] 設置移動設備視圖 (393x852)
- [ ] 截取完整頁面截圖
- [ ] 在 Figma 中創建新文件
- [ ] 導入截圖
- [ ] 設置顏色樣式
- [ ] 安裝 Telka 字體（如果有）
- [ ] 設置文字樣式
- [ ] 創建組件庫

---

## ❓ 常見問題

### Q: 字體無法在 Figma 中顯示？
A: 需要先安裝 Telka 字體文件到系統中。字體文件在 `../PhotoCleaner/Fonts/` 目錄下。

### Q: 截圖模糊？
A: 在開發者工具中設置設備像素比為 2x 或 3x（Device Pixel Ratio）。

### Q: 想要互動原型？
A: 在 Figma 中使用 Prototype 模式，連接各個畫面並設置動畫。

### Q: 如何更新設計？
A: 修改 CSS 文件後，重新在瀏覽器中截圖，然後在 Figma 中替換圖片。

---

## 📞 需要幫助？

如果在導入過程中遇到問題，請檢查：
1. 瀏覽器是否正確顯示 UI
2. 字體文件路徑是否正確
3. 截圖解析度是否足夠高

祝你設計順利！ 🎉
