# 📸 PhotoCleaner

A powerful iOS photo management app with AI-powered organization and premium monetization features.

**🔗 GitHub Repository**: [https://github.com/WellyXY/Photo_cleaner](https://github.com/WellyXY/Photo_cleaner)

## ✨ Features

### 🎯 Core Functionality
- **Smart Photo Management**: Swipe-based photo organization with intuitive gestures
- **Monthly Organization**: Automatically groups photos by month for easy browsing
- **Full-Screen Viewer**: High-quality photo and video viewing with zoom and pan gestures
- **Dual Action System**: Save or delete photos with beautiful animations

### 💰 Monetization (Freemium Model)
- **Free Tier**: 10 photos per day processing limit
- **Pro Subscriptions**: 
  - Monthly: $2.99/month
  - Yearly: $19.99/year (Save 44%)
  - Lifetime: One-time purchase
- **Premium Features**: Unlimited processing, advanced AI sorting, batch operations, cloud backup

### 🎨 User Experience
- **Modern SwiftUI Design**: Clean, intuitive interface
- **Smooth Animations**: Fluid transitions and micro-interactions
- **Responsive Layout**: Optimized for all iPhone screen sizes
- **Dark/Light Mode**: Automatic theme adaptation

## 🛠 Technical Stack

- **Language**: Swift 5.9+
- **Framework**: SwiftUI
- **Minimum iOS**: 18.4+
- **Architecture**: MVVM with ObservableObject
- **Monetization**: StoreKit 2 with transaction verification
- **Photo Access**: Photos Framework with privacy compliance
- **Location**: CoreLocation for photo metadata

## 📱 Screenshots

*Coming soon - Add screenshots of your app here*

## 🚀 Getting Started

### Prerequisites
- Xcode 16.0+
- iOS 18.4+ device or simulator
- Apple Developer Account (for IAP testing)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/WellyXY/Photo_cleaner.git
   ```

2. Open the project in Xcode:
   ```bash
   cd Photo_cleaner
   open PhotoCleaner.xcodeproj
   ```

3. Configure your development team in project settings

4. Build and run on your device or simulator

### App Store Connect Setup
For IAP functionality, configure these products in App Store Connect:

- `com.local.photocleaner.monthly_pro` - Monthly Subscription ($2.99)
- `com.local.photocleaner.yearly_pro` - Yearly Subscription ($19.99)  
- `com.local.photocleaner.lifetime_pro` - Non-Consumable ($49.99)

## 🏗 Project Structure

```
PhotoCleaner/
├── Models/
│   ├── PurchaseManager.swift      # IAP and subscription management
│   ├── PhotoModel.swift           # Core photo data model
│   └── PressableButtonStyle.swift # Custom UI components
├── Views/
│   ├── HomeView.swift             # Main photo browsing interface
│   ├── SavedPhotosView.swift      # Saved photos grid
│   ├── DeletedPhotosView.swift    # Deleted photos management
│   ├── PhotoDetailView.swift      # Full-screen photo viewer
│   ├── PaywallView.swift          # Subscription upgrade screen
│   ├── SubscriptionManagementView.swift # User subscription settings
│   ├── LimitReachedView.swift     # Free tier limit notification
│   └── SettingsView.swift         # App settings and preferences
├── Assets.xcassets/               # App icons and images
└── Supporting Files/
```

## 🔧 Key Components

### PurchaseManager
Handles all IAP functionality including:
- Product loading and caching
- Purchase processing with StoreKit 2
- Transaction verification
- Subscription status management
- Free tier usage tracking

### PhotoModel
Core data management for:
- Photos Framework integration
- Image caching and optimization
- Location metadata handling
- Background processing

### PaywallView
Premium upgrade interface featuring:
- Beautiful gradient design
- Feature comparison
- Multiple subscription options
- Free trial promotion

## 🎯 Monetization Strategy

### Free Tier
- 10 photos per day processing limit
- Basic photo organization
- Standard viewing features

### Pro Features
- ✅ Unlimited photo processing
- ✅ Advanced AI sorting algorithms
- ✅ Batch operations
- ✅ Cloud backup integration
- ✅ Priority customer support
- ✅ Ad-free experience

## 🔒 Privacy & Permissions

The app requests the following permissions:
- **Photos**: Required for photo access and management
- **Location**: Optional, for photo metadata and organization

All data processing happens locally on device. No photos are uploaded to external servers.

## 🧪 Testing

### Unit Tests
```bash
# Run unit tests
cmd + U in Xcode
```

### IAP Testing
1. Create sandbox tester accounts in App Store Connect
2. Sign out of App Store on test device
3. Test purchase flows with sandbox accounts

## 📈 Performance

- **Image Caching**: Efficient NSCache implementation
- **Lazy Loading**: Photos load on-demand for smooth scrolling
- **Memory Management**: Automatic cache cleanup and weak references
- **Background Processing**: Non-blocking photo operations

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support, email support@photocleaner.app or create an issue in this repository.

## 🙏 Acknowledgments

- SwiftUI community for inspiration
- Apple's Photos Framework documentation
- StoreKit 2 best practices

---

**Made with ❤️ by WellyXY**

*Transform your photo library with intelligent organization and seamless management.*
