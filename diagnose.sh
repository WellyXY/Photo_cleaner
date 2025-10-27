#!/bin/bash

# PhotoCleaner 快速診斷腳本
# 用於收集崩潰信息和系統狀態

echo "🔍 PhotoCleaner 診斷工具"
echo "=========================="
echo ""

# 輸出文件
OUTPUT_FILE="PhotoCleaner_Diagnostic_$(date +%Y%m%d_%H%M%S).txt"

{
    echo "診斷報告 - $(date)"
    echo "========================================"
    echo ""

    # 1. 系統信息
    echo "📱 系統信息:"
    echo "  macOS 版本: $(sw_vers -productVersion)"
    echo "  Xcode 版本: $(xcodebuild -version | head -1)"
    echo ""

    # 2. 檢查設備
    echo "📲 已連接的設備:"
    instruments -s devices | grep -E "iPhone|iPad" | head -5
    echo ""

    # 3. 查找崩潰報告
    echo "🚨 最近的崩潰報告:"

    # Mac 崩潰報告
    if [ -d ~/Library/Logs/DiagnosticReports/ ]; then
        echo "  Mac 崩潰報告:"
        ls -lt ~/Library/Logs/DiagnosticReports/ | grep PhotoCleaner | head -5
        echo ""
    fi

    # iOS 模擬器崩潰報告
    if [ -d ~/Library/Logs/CoreSimulator/ ]; then
        echo "  模擬器崩潰報告:"
        find ~/Library/Logs/CoreSimulator -name "*PhotoCleaner*.crash" -mtime -1 | head -5
        echo ""
    fi

    # 4. 檢查項目結構
    echo "📁 項目文件檢查:"
    PROJ_PATH="/Users/welly/Downloads/Photo_cleaner-main/PhotoCleaner"

    if [ -d "$PROJ_PATH" ]; then
        echo "  ✅ 項目目錄存在"

        # 檢查字體文件
        if [ -d "$PROJ_PATH/Fonts" ]; then
            echo "  ✅ Fonts 目錄存在"
            echo "    字體文件:"
            ls -la "$PROJ_PATH/Fonts/"*.otf 2>/dev/null || echo "    ❌ 沒有找到 .otf 字體文件"
        else
            echo "  ❌ Fonts 目錄不存在"
        fi

        # 檢查關鍵文件
        echo ""
        echo "  關鍵文件檢查:"
        [ -f "$PROJ_PATH/PhotoCleanerApp.swift" ] && echo "    ✅ PhotoCleanerApp.swift" || echo "    ❌ PhotoCleanerApp.swift"
        [ -f "$PROJ_PATH/FontManager.swift" ] && echo "    ✅ FontManager.swift" || echo "    ❌ FontManager.swift"
        [ -f "$PROJ_PATH/FontExtension.swift" ] && echo "    ✅ FontExtension.swift" || echo "    ❌ FontExtension.swift"
        [ -f "$PROJ_PATH/PhotoModel.swift" ] && echo "    ✅ PhotoModel.swift" || echo "    ❌ PhotoModel.swift"
    else
        echo "  ❌ 項目目錄不存在: $PROJ_PATH"
    fi
    echo ""

    # 5. 檢查 Xcode 項目配置
    echo "🔧 Xcode 項目配置:"
    XCODEPROJ="/Users/welly/Downloads/Photo_cleaner-main/PhotoCleaner.xcodeproj"
    if [ -d "$XCODEPROJ" ]; then
        echo "  ✅ Xcode 項目文件存在"
    else
        echo "  ❌ Xcode 項目文件不存在"
    fi
    echo ""

    # 6. 嘗試編譯項目
    echo "🔨 嘗試編譯項目:"
    cd /Users/welly/Downloads/Photo_cleaner-main
    if [ -d "$XCODEPROJ" ]; then
        echo "  執行 clean build..."
        xcodebuild clean -project "$XCODEPROJ" -scheme PhotoCleaner 2>&1 | tail -10
        echo ""
        echo "  執行 build (僅語法檢查)..."
        xcodebuild build -project "$XCODEPROJ" -scheme PhotoCleaner -dry-run 2>&1 | tail -20
    fi
    echo ""

    # 7. 檢查最近的 Console 日誌
    echo "📝 最近的 Console 日誌 (如果有):"
    log show --predicate 'process == "PhotoCleaner"' --last 10m --info 2>/dev/null | tail -20
    echo ""

    # 8. 檢查 UserDefaults 中的崩潰信息
    echo "💾 檢查保存的崩潰信息:"
    defaults read com.welly.PhotoCleaner LastCrashInfo 2>/dev/null || echo "  沒有找到保存的崩潰信息"
    echo ""

    echo "========================================"
    echo "診斷完成"
    echo "報告已保存到: $OUTPUT_FILE"

} | tee "$OUTPUT_FILE"

echo ""
echo "✅ 診斷完成！"
echo ""
echo "📄 完整報告已保存到:"
echo "   $(pwd)/$OUTPUT_FILE"
echo ""
echo "請將此文件發送給開發者進行分析。"
echo ""

# 自動打開報告
open "$OUTPUT_FILE"
