//
//  PhotoCleanerApp.swift
//  PhotoCleaner
//
//  Created by Welly_luo on 4/21/25.
//

import SwiftUI
import Photos
import CoreLocation

// Global variable to hold locationManager instance
var locationManagerInstance: CLLocationManager?

// Global function to request all permissions
func requestAllPermissions() {
    // Request photo library permissions with readWrite level to include deletion rights
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        print("Photo library permission status: \(status.rawValue)")
        if status == .authorized {
            print("Full photo access permission granted, including deletion rights")
            // Save authorization status to UserDefaults to avoid repeated requests
            UserDefaults.standard.set(true, forKey: "PhotoDeletePermissionGranted")
        } else {
            print("Full photo access not granted, some features may be limited")
        }
    }
    
    // Request location permissions
    locationManagerInstance = CLLocationManager()
    locationManagerInstance?.requestWhenInUseAuthorization()
}

@main
struct PhotoCleanerApp: App {
    // Use StateObject to ensure PhotoManager remains throughout app lifecycle
    @StateObject private var photoManager = PhotoManager()
    @State private var showSplash = true
    
    init() {
        print("App initialization")

        // 註冊自定義字體
        FontManager.registerFonts()

        // 設置崩潰處理器
        setupCrashHandler()

        // 打印可用字體（調試用）
        #if DEBUG
        printAvailableFonts()
        #endif

        // Check if permission was previously requested
        let hasRequestedPermission = UserDefaults.standard.bool(forKey: "PhotoDeletePermissionGranted")

        // Check current photo library permissions
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        print("Photo library permission status: \(status.rawValue)")

        // If already authorized or previously requested, don't request again
        if status == .authorized {
            print("Already have full photo permissions")
            UserDefaults.standard.set(true, forKey: "PhotoDeletePermissionGranted")
        } else if !hasRequestedPermission {
            // Request all permissions
            print("First launch, requesting all permissions")
            requestAllPermissions()
        }

        // Apply custom appearance settings
        setupAppearance()
    }

    private func setupCrashHandler() {
        // 捕獲未處理的異常
        NSSetUncaughtExceptionHandler { exception in
            let crashInfo = """
            🚨 CRASH DETECTED 🚨
            Time: \(Date())
            Exception: \(exception.name.rawValue)
            Reason: \(exception.reason ?? "Unknown")

            Call Stack:
            \(exception.callStackSymbols.joined(separator: "\n"))

            User Info:
            \(exception.userInfo ?? [:])
            """

            print(crashInfo)

            // 保存到 UserDefaults
            UserDefaults.standard.set(crashInfo, forKey: "LastCrashInfo")
            UserDefaults.standard.set(Date(), forKey: "LastCrashTime")

            // 保存到文件
            Self.saveCrashToFile(crashInfo)

            UserDefaults.standard.synchronize()
        }

        // 捕獲信號崩潰（如 SIGSEGV, SIGABRT 等）
        signal(SIGSEGV) { signal in
            Self.handleSignalCrash(signal: signal, name: "SIGSEGV")
        }
        signal(SIGABRT) { signal in
            Self.handleSignalCrash(signal: signal, name: "SIGABRT")
        }
        signal(SIGBUS) { signal in
            Self.handleSignalCrash(signal: signal, name: "SIGBUS")
        }
        signal(SIGTRAP) { signal in
            Self.handleSignalCrash(signal: signal, name: "SIGTRAP")
        }

        // 檢查是否有之前的崩潰信息
        if let lastCrashInfo = UserDefaults.standard.string(forKey: "LastCrashInfo"),
           let lastCrashTime = UserDefaults.standard.object(forKey: "LastCrashTime") as? Date {
            print("🔍 Previous crash detected at \(lastCrashTime)")
            print("Crash info:\n\(lastCrashInfo)")

            // 如果崩潰是在最近5分鐘內，顯示警告
            if Date().timeIntervalSince(lastCrashTime) < 300 {
                print("⚠️ WARNING: Recent crash detected! App may be in crash loop.")
            }
        }
    }

    static func handleSignalCrash(signal: Int32, name: String) {
        let crashInfo = """
        🚨 SIGNAL CRASH DETECTED 🚨
        Time: \(Date())
        Signal: \(name) (\(signal))

        Thread: \(Thread.current)
        Is Main Thread: \(Thread.isMainThread)

        Call Stack Symbols:
        \(Thread.callStackSymbols.joined(separator: "\n"))
        """

        print(crashInfo)

        // 保存到 UserDefaults
        UserDefaults.standard.set(crashInfo, forKey: "LastCrashInfo")
        UserDefaults.standard.set(Date(), forKey: "LastCrashTime")
        UserDefaults.standard.synchronize()

        // 保存到文件
        saveCrashToFile(crashInfo)

        // 退出
        exit(signal)
    }

    static func saveCrashToFile(_ crashInfo: String) {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let crashLogPath = documentsPath.appendingPathComponent("crash_logs")

            // 創建目錄
            try? FileManager.default.createDirectory(at: crashLogPath, withIntermediateDirectories: true)

            // 生成文件名
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let fileName = "crash_\(dateFormatter.string(from: Date())).txt"
            let filePath = crashLogPath.appendingPathComponent(fileName)

            // 寫入文件
            try crashInfo.write(to: filePath, atomically: true, encoding: .utf8)
            print("💾 Crash log saved to: \(filePath.path)")

            // 同時保存路徑到 UserDefaults
            UserDefaults.standard.set(filePath.path, forKey: "LastCrashLogPath")

        } catch {
            print("❌ Failed to save crash log: \(error)")
        }
    }
    
    private func setupAppearance() {
        // Configure the appearance for navigation bars
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        // Apply the appearance settings
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashScreen()
                        .environmentObject(photoManager)
                        .onAppear {
                            // Start loading photos during splash screen for faster perceived performance
                            print("Starting photo load during splash screen")
                            if photoManager.hasPermission {
                                photoManager.loadInitialPhotos()
                            }

                            // Hide splash screen after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showSplash = false
                                }
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(photoManager)
                        .onAppear {
                            print("App appeared")
                            // Photos are already loading/loaded from splash screen
                            // Only load if not already loading and no photos at all
                            if photoManager.hasPermission && photoManager.allPhotos.isEmpty && !photoManager.isLoading {
                                print("Photos not loaded yet, loading now")
                                photoManager.loadInitialPhotos()
                            } else {
                                print("Photos already loading or loaded: allPhotos=\(photoManager.allPhotos.count), isLoading=\(photoManager.isLoading)")
                            }
                        }
                }
            }
        }
    }
}
