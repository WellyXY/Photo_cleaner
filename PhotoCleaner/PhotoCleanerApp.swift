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
                            // Hide splash screen after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation {
                                    showSplash = false
                                }
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(photoManager)
                        .onAppear {
                            print("App appeared, loading photos")
                            if photoManager.hasPermission {
                                // 调用新的初始化加载方法
                                photoManager.loadInitialPhotos()
                            }
                        }
                }
            }
        }
    }
}
