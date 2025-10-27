# 如何獲取和導出 APP Crash Log

## 🚨 情況：APP 一打開就崩潰

如果 APP 每次打開就立即崩潰，請按照以下方法獲取 crash logs。

---

## 方法 1：從 Xcode 獲取 Crash Log（最推薦）

### 步驟：

1. **連接設備到電腦**
   - 用 USB 線連接 iPhone/iPad 到 Mac

2. **打開 Xcode**
   - 啟動 Xcode

3. **訪問設備和模擬器窗口**
   - 菜單：`Window` → `Devices and Simulators`
   - 或快捷鍵：`Shift + Cmd + 2`

4. **選擇你的設備**
   - 在左側列表中點擊你的設備

5. **查看 Crash Logs**
   - 點擊 **"View Device Logs"** 按鈕（在右側面板）
   - 會看到所有的崩潰報告列表

6. **找到 PhotoCleaner 的崩潰報告**
   - 在列表中找到 `PhotoCleaner` 開頭的條目
   - 按時間排序，最新的在上面
   - 崩潰報告會顯示為 `PhotoCleaner-2025-10-26-xxx.crash`

7. **導出崩潰報告**
   - 右鍵點擊崩潰報告
   - 選擇 **"Export Log..."**
   - 保存到桌面或 Downloads 文件夾

8. **發送給我**
   - 找到導出的 `.crash` 文件
   - 發送給我分析

---

## 方法 2：從設備設置中獲取（不需要電腦）

### 步驟：

1. **打開 iPhone 設置**

2. **進入隱私與安全**
   - `設置` → `隱私與安全性`

3. **找到分析與改進**
   - 點擊 `分析與改進`

4. **查看分析數據**
   - 點擊 `分析資料`
   - 滾動找到 `PhotoCleaner` 開頭的條目
   - 最新的會在上面

5. **打開崩潰報告**
   - 點擊 `PhotoCleaner-xxx.ips`
   - 會顯示完整的崩潰日誌

6. **分享崩潰報告**
   - 點擊右上角的 **分享** 按鈕（方框帶箭頭圖標）
   - 選擇：
     - **AirDrop** 傳到電腦
     - **郵件** 發送給自己
     - **儲存到檔案** 保存到 iCloud Drive

7. **發送給我**
   - 將文件發送給我

---

## 方法 3：從 Console.app 獲取（Mac 用戶）

### 步驟：

1. **連接設備到 Mac**

2. **打開 Console App**
   - 方法 1：`Spotlight` 搜索 "Console"
   - 方法 2：路徑 `/Applications/Utilities/Console.app`

3. **選擇你的設備**
   - 在左側 **"Devices"** 下找到你的 iPhone/iPad
   - 點擊設備名稱

4. **篩選 PhotoCleaner 日誌**
   - 在右上角搜索框輸入：`PhotoCleaner`
   - 或輸入：`process:PhotoCleaner`

5. **運行 APP 並查看崩潰**
   - 在設備上打開 PhotoCleaner
   - Console 會實時顯示日誌
   - 崩潰時會顯示大量紅色錯誤信息

6. **保存日誌**
   - 右鍵點擊日誌區域
   - 選擇 **"Select All"**
   - 複製（`Cmd + C`）
   - 粘貼到文本文件中

7. **發送給我**
   - 保存為 `.txt` 文件
   - 發送給我

---

## 方法 4：從 APP 內部獲取（如果能打開 APP）

如果 APP 能短暫打開，可以使用 APP 內建的崩潰日誌：

### 步驟：

1. **查看 Console 輸出**
   - 在 Xcode 中運行 APP
   - 查看底部的控制台輸出
   - 尋找以下訊息：
     ```
     🔍 Previous crash detected at [時間]
     Crash info:
     [崩潰信息]
     ```

2. **從 APP 文件中獲取**
   - 崩潰日誌已保存到：
     ```
     APP Documents/crash_logs/crash_[時間].txt
     ```

3. **使用 Xcode 導出**
   - 在 Xcode 中：`Window` → `Devices and Simulators`
   - 選擇設備
   - 點擊設備名稱下的 ⚙️ 圖標
   - 選擇 **"Download Container..."**
   - 選擇 `PhotoCleaner`
   - 保存到桌面
   - 右鍵點擊下載的 `.xcappdata` 文件
   - 選擇 **"Show Package Contents"**
   - 進入 `AppData/Documents/crash_logs/`
   - 找到崩潰日誌文件

---

## 方法 5：使用終端命令（進階）

### 從 Mac 獲取設備上的崩潰報告：

```bash
# 列出所有崩潰報告
instruments -s crashes

# 或者使用
defaults read ~/Library/Logs/DiagnosticReports
```

### 從模擬器獲取：

```bash
# 查看模擬器崩潰報告
open ~/Library/Logs/DiagnosticReports/

# 篩選 PhotoCleaner
ls -lt ~/Library/Logs/DiagnosticReports/ | grep PhotoCleaner
```

---

## 📋 Crash Log 檢查清單

在發送 Crash Log 之前，請確認：

- [ ] 日誌包含 `PhotoCleaner` 關鍵字
- [ ] 日誌顯示崩潰時間
- [ ] 日誌包含錯誤訊息或 Exception
- [ ] 日誌包含 Call Stack（堆疊追蹤）
- [ ] 如果有多個崩潰，發送最新的那個

---

## 🔍 Crash Log 應該包含的信息

一個完整的 crash log 應該包含：

```
Incident Identifier: xxx
CrashReporter Key: xxx
Hardware Model: iPhone14,2
Process: PhotoCleaner [1234]
Path: /private/var/containers/Bundle/Application/xxx/PhotoCleaner.app/PhotoCleaner
Identifier: com.welly.PhotoCleaner
Version: 1.0 (1)
Code Type: ARM-64
Parent Process: launchd [1]

Date/Time: 2025-10-26 xx:xx:xx
OS Version: iOS 17.x
Report Version: xxx

Exception Type: EXC_CRASH (SIGABRT)
Exception Codes: 0x0000000000000000, 0x0000000000000000
Triggered by Thread: 0

Application Specific Information:
*** Terminating app due to uncaught exception 'xxx', reason: 'xxx'

Thread 0 Crashed:
0  libsystem_kernel.dylib ...
1  PhotoCleaner ...
...
```

---

## ⚠️ 如果所有方法都失敗

### 臨時解決方案：

1. **刪除並重新安裝 APP**
   ```
   長按 APP 圖標 → 刪除 APP → 重新從 Xcode 安裝
   ```

2. **清除所有數據**
   - 刪除 APP
   - 重新啟動設備
   - 重新安裝

3. **檢查 Xcode 編譯錯誤**
   - 在 Xcode 中 Build APP
   - 查看是否有編譯警告或錯誤
   - 發送編譯日誌給我

4. **使用調試模式運行**
   ```bash
   # 在 Xcode 中按 Cmd + R 運行
   # 查看控制台輸出
   # 截圖所有錯誤信息
   ```

---

## 📞 發送 Crash Log 的方式

請通過以下任一方式發送：

1. **複製文本內容** - 直接貼在對話中
2. **上傳文件** - 上傳 `.crash` 或 `.txt` 文件
3. **截圖** - 如果日誌很短，可以截圖
4. **壓縮打包** - 如果有多個文件，打包成 `.zip`

---

## 🎯 重要提示

- **盡快獲取** - 設備會定期清理舊的崩潰報告
- **多次嘗試** - 如果第一次沒找到，多運行幾次 APP
- **連接電腦** - 最好的方式是連接電腦用 Xcode 查看
- **完整日誌** - 盡量發送完整的日誌，不要只發送部分

---

## 💡 常見崩潰原因（供參考）

根據我添加的代碼，可能的崩潰原因：

1. **字體載入失敗** - Telka 字體文件沒有正確添加
2. **PhotoManager 初始化失敗** - 照片權限問題
3. **並行處理錯誤** - 線程安全問題
4. **內存問題** - 載入太多照片

請盡快發送 crash log，我會幫你快速定位問題！
