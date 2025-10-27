import SwiftUI
import UIKit

struct MainTabView: View {
    // 移除重复的 PhotoManager 实例，使用从 App 传递的实例
    // @StateObject private var photoManager = PhotoManager()
    @State private var selectedTab = 0

    // 添加滚动控制变量
    @State private var homeScrollToTop = false
    @State private var savedScrollToTop = false
    @State private var deletedScrollToTop = false

    // 使用靜態變量確保只設置一次
    private static var hasConfiguredTabBar = false

    init() {
        // ⚠️ 移除重複的日誌，減少控制台輸出
        // print("MainTabView初始化")

        // 只在第一次初始化時設置 TabBar 外觀
        if !Self.hasConfiguredTabBar {
            Self.hasConfiguredTabBar = true
            Self.configureTabBarAppearance()
        }
    }

    private static func configureTabBarAppearance() {
        // 自定义TabBar外观
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor.systemBackground

        // 添加阴影
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.1)

        // 设置选中和未选中的颜色
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.gray
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
        itemAppearance.selected.iconColor = UIColor.systemBlue
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        print("✅ TabBar appearance configured")
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(0)
                .tabItem {
                    Label("Filter", systemImage: "photo.stack")
                }
                .onAppear {
                    print("HomeView已显示")
                }
                .environment(\.scrollToTop, homeScrollToTop)
            
            SavedPhotosView()
                .tag(1)
                .tabItem {
                    Label("Saved", systemImage: "heart.fill")
                }
                .onAppear {
                    print("SavedPhotosView已显示")
                }
                .environment(\.scrollToTop, savedScrollToTop)
            
            DeletedPhotosView()
                .tag(2)
                .tabItem {
                    Label("Deleted", systemImage: "trash.fill")
                }
                .onAppear {
                    print("DeletedPhotosView已显示")
                }
                .environment(\.scrollToTop, deletedScrollToTop)
                
            SettingsView()
                .tag(3)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .onAppear {
                    print("SettingsView已显示")
                }
        }
        .accentColor(.blue)
        // 使用从 App 传递的 photoManager
        // .environmentObject(photoManager)
        .onAppear {
            print("TabView已加载")
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // 添加标签切换动画
            let impactMed = UIImpactFeedbackGenerator(style: .medium)
            impactMed.impactOccurred()
            
            if oldValue == newValue {
                switch selectedTab {
                case 0:
                    homeScrollToTop.toggle()
                case 1:
                    savedScrollToTop.toggle()
                case 2:
                    deletedScrollToTop.toggle()
                default:
                    break
                }
            }
        }
    }
}

// 添加滚动到顶部的环境键
private struct ScrollToTopKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var scrollToTop: Bool {
        get { self[ScrollToTopKey.self] }
        set { self[ScrollToTopKey.self] = newValue }
    }
} 