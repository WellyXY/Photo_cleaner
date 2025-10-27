import SwiftUI
import UIKit

class FontManager {
    static func registerFonts() {
        print("🔤 Starting font registration...")

        let fontNames = [
            "Telka-Regular.otf",
            "Telka-Medium.otf",
            "Telka-Extended-Bold.otf",
            "Telka-Extended-Black.otf"
        ]

        // 先嘗試從 Fonts 子目錄加載
        var successCount = 0
        for fontName in fontNames {
            if registerFont(fontName: fontName, subdirectory: "Fonts") {
                successCount += 1
            } else if registerFont(fontName: fontName, subdirectory: nil) {
                // 如果子目錄失敗，嘗試主 bundle
                successCount += 1
            }
        }

        if successCount == 0 {
            print("⚠️ WARNING: No fonts were registered. App will use system fonts.")
        } else {
            print("✅ Successfully registered \(successCount)/\(fontNames.count) fonts")
        }
    }

    private static func registerFont(fontName: String, subdirectory: String?) -> Bool {
        let fontNameWithoutExtension = fontName.replacingOccurrences(of: ".otf", with: "")

        guard let fontURL = Bundle.main.url(
            forResource: fontNameWithoutExtension,
            withExtension: "otf",
            subdirectory: subdirectory
        ) else {
            if subdirectory != nil {
                print("❌ Font file not found in \(subdirectory ?? "bundle"): \(fontName)")
            }
            return false
        }

        guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL) else {
            print("❌ Could not create data provider for: \(fontName)")
            return false
        }

        guard let font = CGFont(fontDataProvider) else {
            print("❌ Could not create font from: \(fontName)")
            return false
        }

        var error: Unmanaged<CFError>?
        if !CTFontManagerRegisterGraphicsFont(font, &error) {
            // 檢查是否是因為字體已經註冊
            if let error = error?.takeRetainedValue() {
                let errorDescription = String(describing: error)
                if errorDescription.contains("already registered") {
                    print("ℹ️ Font already registered: \(fontName)")
                    return true
                } else {
                    print("❌ Error registering font \(fontName): \(error)")
                    return false
                }
            }
        }

        print("✅ Successfully registered font: \(fontName)")
        return true
    }
}
